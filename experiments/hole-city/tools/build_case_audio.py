#!/usr/bin/env python3
"""Synthesize the original case-opening sounds using Python's standard library.

No recordings, third-party samples, network, external encoders or playback.
Default output: assets/audio/case_opening. --check regenerates in memory and
verifies exact checked-in bytes. --demo also writes a labelled review sequence
under artifacts/case-opening-20261008; it never plays that sequence.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
SEED = 20261008
TAU = math.tau
RARITIES = ("common", "uncommon", "rare", "epic", "legendary", "prismatic")


def blank(duration: float) -> list[float]:
    return [0.0] * round(duration * RATE)


def freq(note: int) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def mix(target: list[float], source: list[float], at: float, gain: float = 1.0) -> None:
    offset = round(at * RATE)
    for i, value in enumerate(source):
        index = i + offset
        if 0 <= index < len(target):
            target[index] += value * gain


def envelope(t: float, duration: float, attack: float, decay: float) -> float:
    # Smooth attack and release avoid impulse-like transient clicks.
    rise = min(1.0, t / attack)
    rise = math.sin(rise * math.pi * .5) ** 2
    release = min(1.0, max(0.0, (duration - t) / min(.055, duration * .35)))
    return rise * math.exp(-t / decay) * release * release


def wooden_note(note: int, duration: float, decay: float, seed: int) -> list[float]:
    """Rounded fundamental, quiet harmonic and a low-passed felt attack."""
    rng = random.Random(seed)
    result = blank(duration)
    f = freq(note)
    noise = 0.0
    for i in range(len(result)):
        t = i / RATE
        noise += .065 * (rng.uniform(-1.0, 1.0) - noise)
        harmonic = .16 * math.sin(TAU * f * 2 * t) * math.exp(-t / .075)
        fundamental = math.sin(TAU * f * t)
        soft_attack = .065 * noise * math.exp(-t / .022)
        result[i] = (fundamental + harmonic + soft_attack) * envelope(t, duration, .008, decay)
    return result


def breath(duration: float, seed: int) -> list[float]:
    """A quiet two-pole low-pass breath, with no white-noise hiss layer."""
    rng = random.Random(seed)
    first = second = 0.0
    result = blank(duration)
    for i in range(len(result)):
        t = i / RATE
        first += .09 * (rng.uniform(-1, 1) - first)
        second += .09 * (first - second)
        swell = math.sin(math.pi * i / max(1, len(result) - 1)) ** 2
        result[i] = second * swell * (.8 + .2 * math.sin(TAU * 3 * t))
    return result


def finish(samples: list[float], peak: float) -> list[float]:
    mean = sum(samples) / max(1, len(samples))
    out = [value - mean for value in samples]
    # Always reach exactly zero at both file boundaries; no loop is intended.
    fade = min(round(.003 * RATE), len(out) // 4)
    window = [1.0] * len(out)
    for i in range(fade):
        value = math.sin(math.pi * .5 * i / max(1, fade - 1)) ** 2
        out[i] *= value
        out[-1 - i] *= value
        window[i] = window[-1 - i] = value
    # Windowing can reintroduce a small mean in a very short tick. Remove it
    # with the same smooth window so the exact zero endpoints stay intact.
    residual = sum(out) / sum(window)
    out = [value - residual * weight for value, weight in zip(out, window)]
    loudest = max((abs(value) for value in out), default=0.0)
    return [value * peak / loudest for value in out] if loudest else out


def sounds() -> tuple[dict[str, list[float]], dict[str, dict]]:
    rendered: dict[str, list[float]] = {}
    notes: dict[str, dict] = {}
    opening = blank(4.25)
    mix(opening, wooden_note(45, .115, .030, SEED), .0, .55)
    mix(opening, wooden_note(52, .105, .027, SEED + 1), .052, .40)
    mix(opening, breath(.31, SEED + 2), .07, 2.4)
    mix(opening, wooden_note(50, .24, .080, SEED + 3), .115, .13)
    # A sparse D-major anticipation phrase spans the real4.25-second reel.
    # It is replaced, never layered again, when SKIP or the reveal fires.
    for index, (onset, note) in enumerate([(.55,50),(1.20,57),(1.95,62),(2.80,66),(3.55,69)]):
        mix(opening, wooden_note(note, min(.65,4.25-onset), .22, SEED+150+index), onset, .14)
    for index, note in enumerate([50,57,61]):
        mix(opening, wooden_note(note,.65,.25,SEED+160+index),3.58+index*.015,.035)
    rendered["open.wav"] = finish(opening, .22)
    notes["open.wav"] = {"role": "Warm latch with original4.25-second D-major anticipation phrase", "seed": SEED}

    tick = blank(.028)
    f = 330.0
    rng = random.Random(SEED + 4)
    filtered = 0.0
    for i in range(len(tick)):
        t = i / RATE
        filtered += .10 * (rng.uniform(-1, 1) - filtered)
        tick[i] = (math.sin(TAU * f * t) + .12 * filtered) * envelope(t, .028, .0025, .0065)
    rendered["tick.wav"] = finish(tick, .12)
    notes["tick.wav"] = {"role": "Short felt card tick", "seed": SEED + 4, "fundamental_hz": f}

    # Related but independently voiced reveal phrases. Extra rarity adds a
    # sparse chord color and length, not a louder crash or a piercing register.
    phrases = {
        "common": (.46, [(0.0, 50, .85), (.075, 57, .50)]),
        "uncommon": (.60, [(0.0, 50, .78), (.075, 57, .45), (.16, 62, .48)]),
        "rare": (.74, [(0.0, 50, .70), (.085, 57, .45), (.18, 66, .43)]),
        "epic": (.90, [(0.0, 50, .70), (.09, 59, .43), (.19, 64, .40), (.29, 69, .30)]),
        "legendary": (1.08, [(0.0, 50, .72), (.105, 57, .40), (.22, 62, .42), (.34, 66, .38)]),
        "prismatic": (1.24, [(0.0, 50, .70), (.11, 57, .35), (.23, 62, .40), (.36, 66, .34), (.50, 69, .26)]),
    }
    for rank, rarity in enumerate(RARITIES):
        duration, events = phrases[rarity]
        result = blank(duration)
        for index, (onset, note, gain) in enumerate(events):
            voice_duration = min(.30 + rank * .04, duration - onset)
            mix(result, wooden_note(note, voice_duration, .10 + rank * .021, SEED + 20 + rank * 10 + index), onset, gain)
        # The longest two phrases gain a low, quiet breath, not a second score.
        if rank >= 4:
            mix(result, breath(duration - .08, SEED + 100 + rank), .035, .15)
        filename = "reveal_" + rarity + ".wav"
        rendered[filename] = finish(result, .24)
        notes[filename] = {
            "role": rarity + " reveal",
            "notes_midi": [event[1] for event in events],
            "onsets_seconds": [event[0] for event in events],
            "highest_fundamental_hz": round(max(freq(event[1]) for event in events), 3),
            "seed_base": SEED + 20 + rank * 10,
        }
    return rendered, notes


def encode(samples: list[float]) -> tuple[bytes, list[int]]:
    integers = [round(max(-1.0, min(1.0, value)) * 32767) for value in samples]
    output = io.BytesIO()
    with wave.open(output, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(struct.pack("<%dh" % len(integers), *integers))
    return output.getvalue(), integers


def measures(data: bytes, samples: list[int]) -> dict:
    values = [value / 32767 for value in samples]
    peak = max(abs(value) for value in values)
    rms = math.sqrt(sum(value * value for value in values) / len(values))
    return {
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
        "frames": len(values),
        "duration_seconds": round(len(values) / RATE, 6),
        "peak_linear": round(peak, 7),
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 3),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-12)), 3),
        "dc_offset": round(sum(values) / len(values), 8),
        "clipped_samples": sum(abs(value) >= 32767 for value in samples),
        "first_sample": samples[0],
        "last_sample": samples[-1],
    }


def save_or_check(path: Path, data: bytes, check: bool) -> None:
    if check:
        if not path.is_file() or path.read_bytes() != data:
            raise SystemExit("Deterministic output mismatch: " + str(path))
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def build_demo(rendered: dict[str, list[float]]) -> tuple[bytes, dict]:
    # Six isolated openings in tier order; matching runtime attenuation is
    # baked into this review file, so the demo is not a loud normalized mix.
    starts = [0.0, 6.0, 12.0, 18.0, 24.0, 30.0]
    timeline: list[dict] = []
    output = blank(36.0)
    for start, rarity in zip(starts, RARITIES):
        timeline.append({"at_seconds": start, "rarity": rarity, "reveal_at_seconds": start + 4.25})
        mix(output, rendered["open.wav"], start, 10 ** (-5 / 20))
        for tick_at in [.4,.5,.63,.8,1.02,1.3,1.66,2.12,2.72,3.46,4.08]:
            mix(output, rendered["tick.wav"], start + tick_at, 10 ** (-9 / 20))
        mix(output, rendered["reveal_" + rarity + ".wav"], start + 4.25, 10 ** (-5 / 20))
    data, pcm = encode(output)
    return data, {"scope": "Original synthesized audio review, not gameplay capture; six tiers in catalog order.", "timeline": timeline, **measures(data, pcm)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/audio/case_opening")
    parser.add_argument("--check", action="store_true", help="Verify exact deterministic output bytes; write nothing")
    parser.add_argument("--demo", action="store_true", help="Also create/verify the36-second review WAV; never play it")
    args = parser.parse_args()
    rendered, notes = sounds()
    manifest = {"generator": "tools/build_case_audio.py", "algorithm_version": 2, "seed": SEED,
                "provenance": "Original additive and filtered-noise synthesis. No copied melodies, recordings or third-party samples.",
                "format": {"sample_rate_hz": RATE, "channels": 1, "bits_per_sample": 16, "loop": False},
                "runtime": {"max_voices": 2, "tick_interval_ms": 40, "tick_volume_db": -9, "accent_volume_db": -5}, "files": {}}
    for filename, samples in rendered.items():
        data, pcm = encode(samples)
        stats = measures(data, pcm)
        assert stats["clipped_samples"] == 0
        assert stats["peak_linear"] <= .24002
        assert stats["first_sample"] == 0 and stats["last_sample"] == 0
        assert abs(stats["dc_offset"]) < .0002
        assert stats["duration_seconds"] <= (4.25 if filename=="open.wav" else 1.24)
        save_or_check(args.output / filename, data, args.check)
        manifest["files"][filename] = {**notes[filename], **stats}
    manifest["total_wav_bytes"] = sum(entry["bytes"] for entry in manifest["files"].values())
    save_or_check(args.output / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode(), args.check)
    if args.demo:
        data, meta = build_demo(rendered)
        demo_dir = ROOT / "artifacts/music-worlds-20261008"
        save_or_check(demo_dir / "case-audio-demo.wav", data, args.check)
        save_or_check(demo_dir / "case-audio-demo.json", (json.dumps(meta, indent=2) + "\n").encode(), args.check)
    print(json.dumps({"mode": "verified" if args.check else "generated", "files": len(rendered), "total_wav_bytes": manifest["total_wav_bytes"], "max_peak_dbfs": max(entry["peak_dbfs"] for entry in manifest["files"].values()), "demo": args.demo}))


if __name__ == "__main__":
    main()
