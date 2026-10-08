#!/usr/bin/env python3
"""Compose deterministic, original instrumental loops; no samples or network.

Requires Python 3, NumPy, and ffmpeg/ffprobe with libvorbis. Outputs only the
two game assets and a measurement manifest under assets/audio (or --output).
The synthesizer, arrangement, melody and sound design are authored here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import numpy as np

RATE = 44100
BARS = 16
ROOT = Path(__file__).resolve().parents[1]
TAU = math.tau


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def db(value: float) -> float:
    return 20.0 * math.log10(max(float(value), 1e-12))


def frequency(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def envelope(t: np.ndarray, attack: float, decay: float, duration: float) -> np.ndarray:
    onset = 1.0 - np.exp(-t / attack)
    tail = np.minimum(1.0, np.maximum(0.0, (duration - t) / 0.045)) ** 2
    return onset * np.exp(-t / decay) * tail


def pitched(kind: str, midi: int, duration: float, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    f = frequency(midi)
    if kind == "mallet":
        # Rounded wooden fundamental with short, quiet inharmonic upper modes.
        wave = np.sin(TAU * f * t) * np.exp(-t / 0.46)
        wave += 0.24 * np.sin(TAU * f * 2.003 * t) * np.exp(-t / 0.22)
        wave += 0.12 * np.sin(TAU * f * 4.011 * t) * np.exp(-t / 0.095)
        wave += 0.022 * np.sin(TAU * f * 7.037 * t) * np.exp(-t / 0.038)
        wave *= envelope(t, 0.006, 1.8, duration)
    elif kind == "celeste":
        # Softer glass/wood hybrid, not an unmodulated electronic beep.
        wave = np.sin(TAU * f * t) * np.exp(-t / 0.70)
        wave += 0.18 * np.sin(TAU * f * 2.001 * t) * np.exp(-t / 0.34)
        wave += 0.13 * np.sin(TAU * f * 3.996 * t) * np.exp(-t / 0.19)
        wave += 0.035 * np.sin(TAU * f * 6.026 * t) * np.exp(-t / 0.12)
        wave *= envelope(t, 0.009, 2.8, duration)
    elif kind == "keys":
        # Gentle detuned electric-piano chord body with a tine attack.
        wave = 0.65 * np.sin(TAU * f * t)
        wave += 0.27 * np.sin(TAU * f * 1.0017 * t)
        wave += 0.20 * np.sin(TAU * f * 2 * t) * np.exp(-t / 0.28)
        wave += 0.07 * np.sin(TAU * f * 3 * t) * np.exp(-t / 0.17)
        wave *= envelope(t, 0.013, 0.43, duration)
    elif kind == "pluck":
        wave = np.zeros_like(t)
        for harmonic, amount in [(1, 0.80), (2, 0.26), (3, 0.13), (4, 0.065), (5, 0.03)]:
            wave += amount * np.sin(TAU * f * harmonic * t) * np.exp(-t * harmonic / 0.85)
        wave *= envelope(t, 0.005, 1.0, duration)
    elif kind == "bass":
        wave = np.sin(TAU * f * t)
        wave += 0.30 * np.sin(TAU * f * 2 * t) * np.exp(-t / 0.15)
        wave += 0.095 * np.sin(TAU * f * 3 * t) * np.exp(-t / 0.09)
        wave *= envelope(t, 0.010, 0.38, duration)
    else:
        raise ValueError(kind)
    return wave


def percussion(kind: str, rng: np.random.Generator) -> np.ndarray:
    duration = {"kick": 0.25, "brush": 0.13, "rim": 0.12, "shaker": 0.080}[kind]
    t = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    noise = rng.standard_normal(t.size)
    softened = np.convolve(noise, np.ones(9) / 9.0, mode="same")
    if kind == "kick":
        phase = TAU * (48.0 * t + 31.0 * 0.025 * (1 - np.exp(-t / 0.025)))
        wave = np.sin(phase) + 0.06 * softened * np.exp(-t / 0.012)
        wave *= envelope(t, 0.0035, 0.065, duration)
    elif kind == "rim":
        wave = 0.5 * np.sin(TAU * 610 * t) + 0.25 * np.sin(TAU * 840 * t)
        wave += 0.12 * softened
        wave *= envelope(t, 0.002, 0.023, duration)
    elif kind == "brush":
        wave = softened - np.convolve(softened, np.ones(65) / 65.0, mode="same")
        wave *= envelope(t, 0.006, 0.040, duration)
    else:
        wave = noise - softened
        wave *= envelope(t, 0.004, 0.019, duration) * 0.24
    return wave


# Each list is one authored four-beat phrase: (beat, MIDI pitch, length in beats).
# Rests and longer phrase endings leave space for collection sound effects.
SUNNY_MELODY = [
    [(0.5, 76, .5), (1.25, 79, .5), (2, 81, .5), (3, 79, .75)],
    [(0, 76, .75), (1.5, 72, .5), (2.5, 74, .5), (3.25, 76, .5)],
    [(0.5, 77, .75), (1.5, 81, .5), (2.5, 79, .5), (3.25, 77, .5)],
    [(0, 74, 1), (1.5, 76, .5), (2.5, 74, 1)],
    [(0.5, 79, .5), (1.25, 83, .5), (2, 81, .75), (3.25, 79, .5)],
    [(0, 76, .5), (1, 79, .5), (2.5, 81, 1)],
    [(0.5, 77, .5), (1.25, 76, .5), (2, 74, .5), (3, 72, .75)],
    [(0, 74, .75), (1.5, 71, .5), (2.5, 74, .75)],
    [(0, 76, .5), (.75, 79, .5), (1.5, 84, .75), (3, 83, .5)],
    [(0.5, 81, .75), (1.5, 79, .5), (2.5, 76, 1)],
    [(0, 77, .5), (1, 81, .5), (2, 84, .5), (3, 81, .75)],
    [(0.5, 79, .75), (1.5, 76, .5), (2.5, 74, .75)],
    [(0, 79, .75), (1.5, 76, .5), (2.25, 74, .5), (3, 76, .75)],
    [(0.5, 81, .5), (1.25, 79, .5), (2, 76, 1)],
    [(0, 77, .5), (.75, 76, .5), (1.5, 74, .75), (3, 72, .5)],
    [(0, 71, .75), (1.5, 74, .5), (2.5, 79, .5)],
]
FOOD_MELODY = [
    [(0.5, 81, .75), (1.5, 84, .5), (2.75, 86, .75)],
    [(0, 84, .75), (1.5, 79, .5), (2.5, 76, 1)],
    [(0.5, 77, .5), (1.25, 81, .75), (2.75, 79, .75)],
    [(0, 77, 1), (1.5, 74, .5), (3, 77, .5)],
    [(0.5, 79, .5), (1.5, 82, .75), (2.75, 81, .75)],
    [(0, 79, .75), (1.5, 76, .5), (2.5, 74, .75)],
    [(0.5, 77, .75), (1.75, 81, .5), (2.75, 84, .75)],
    [(0, 82, .5), (1, 79, .5), (2.5, 76, 1)],
    [(0, 81, .5), (.75, 84, .5), (1.5, 89, .75), (3, 86, .5)],
    [(0.5, 84, .75), (1.5, 79, .5), (2.75, 76, .75)],
    [(0, 81, .75), (1.25, 84, .5), (2.25, 86, .75), (3.25, 84, .5)],
    [(0.5, 82, .75), (1.5, 81, .5), (2.5, 77, 1)],
    [(0, 79, .5), (1, 82, .5), (2, 86, .75), (3, 84, .5)],
    [(0.5, 79, .75), (1.5, 76, .5), (2.5, 74, .75)],
    [(0, 77, 1), (1.5, 81, .5), (2.5, 84, 1)],
    [(0.5, 82, .5), (1.5, 79, .75), (2.75, 76, .75)],
]

TRACKS = {
    "sunny_city_loop": {
        "title": "Sunny Side Streets", "bpm": 120, "seed": 29092026,
        "key": "C major", "lead": "mallet", "melody": SUNNY_MELODY,
        "chord_names": ["Cmaj9", "Am7", "Fmaj9", "G6", "Em7", "Am7", "Dm9", "G13"],
        "chords": [[60, 64, 67, 71, 74], [57, 60, 64, 67], [57, 60, 64, 65, 67],
                   [55, 59, 62, 64], [55, 59, 62, 64], [57, 60, 64, 67],
                   [57, 60, 62, 64, 65], [55, 59, 62, 65, 69]],
        "bass": [36, 33, 29, 31, 28, 33, 38, 31],
    },
    "snack_garden_loop": {
        "title": "Sugar Stack Stroll", "bpm": 112, "seed": 29092027,
        "key": "F major", "lead": "celeste", "melody": FOOD_MELODY,
        "chord_names": ["F6", "C/E", "Dm7", "Bbmaj9", "Gm7", "C6", "Fmaj9", "C7sus4-C7"],
        "chords": [[57, 60, 65, 69], [55, 60, 64, 67], [57, 60, 62, 65],
                   [57, 60, 62, 65], [55, 58, 62, 65], [55, 57, 60, 64],
                   [57, 60, 64, 65, 67], [58, 60, 64, 67]],
        "bass": [29, 28, 38, 34, 31, 36, 29, 36],
    },
}


def compose(name: str, spec: dict) -> tuple[np.ndarray, dict]:
    beat = 60.0 / spec["bpm"]
    count = round(BARS * 4 * beat * RATE)
    dry = np.zeros((count, 2), dtype=np.float64)
    send = np.zeros_like(dry)
    rng = np.random.default_rng(spec["seed"])
    event_counts: dict[str, int] = {}
    food = name.startswith("snack")

    def add(wave: np.ndarray, at: float, gain: float, pan: float, wet: float, instrument: str) -> None:
        # Wrapped summation makes tails from bar 16 naturally precede bar 1.
        start = round(at * beat * RATE) % count
        gains = np.array([math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)])
        stereo = wave[:, None] * gain * gains[None, :]
        end = min(count - start, wave.size)
        dry[start:start + end] += stereo[:end]
        send[start:start + end] += stereo[:end] * wet
        if end < wave.size:
            dry[:wave.size - end] += stereo[end:]
            send[:wave.size - end] += stereo[end:] * wet
        event_counts[instrument] = event_counts.get(instrument, 0) + 1

    def note(kind: str, pitch: int, at: float, length: float, gain: float, pan: float, wet: float = .28) -> None:
        duration = max(.18, length * beat + (.65 if kind in ("mallet", "celeste") else .12))
        add(pitched(kind, pitch, duration, rng), at, gain, pan, wet, kind)

    for bar in range(BARS):
        base = bar * 4.0
        chord = spec["chords"][bar % 8]
        root = spec["bass"][bar % 8]
        for hit, velocity in [(0, 1), (1.5, .68), (2.5, .82), (3.5, .55)]:
            if food and hit == 3.5 and bar % 2 == 0:
                continue
            for index, pitch in enumerate(chord):
                # A few milliseconds of stagger makes a soft hand-played chord.
                actual_pitch = pitch
                if food and bar % 8 == 7 and hit < 2 and pitch == 64:
                    actual_pitch = 65
                note("keys", actual_pitch, base + hit + index * .012, .75,
                     (.105 if food else .115) * velocity, -.43 + index * .18, .21)
        for hit, interval, velocity in [(0, 0, 1), (1.5, 7, .70), (2, 12, .80), (3.25, 7, .66)]:
            note("bass", root + interval, base + hit, .60, .31 * velocity, 0, .015)
        for hit, pitch, length in spec["melody"][bar]:
            note(spec["lead"], pitch, base + hit, length, .205 if food else .235,
                 .13 + .09 * math.sin(bar * .7), .36)
        # Alternating quiet chord-tone answers fill spaces without doubling the lead.
        for hit, index in [(0.75, 0), (2.25, 2), (3.75, 1)]:
            if food and bar % 4 == 3 and hit == 3.75:
                continue
            note("pluck", chord[index] + 12, base + hit, .32,
                 .055 if food else .070, -.35, .24)
        for hit, velocity in [(0, 1), (2, .85)]:
            add(percussion("kick", rng), base + hit, (.21 if food else .29) * velocity, 0, .01, "kick")
        for hit in (1, 3):
            add(percussion("rim", rng), base + hit, .083 if food else .11, -.10, .17, "rim")
            add(percussion("brush", rng), base + hit + .012, .075 if food else .10, .17, .10, "brush")
        for eighth in range(8):
            if food and eighth % 2 == 0:
                continue
            swing = .045 if eighth % 2 else 0.0
            gain = (.035 if food else .045) * (.75 if eighth % 2 == 0 else 1)
            add(percussion("shaker", rng), base + eighth * .5 + swing,
                gain, -.32 if eighth % 2 else .32, .08, "shaker")
        if bar % 4 == 3:
            for hit, pitch in [(3.25, chord[1] + 12), (3.75, chord[2] + 12)]:
                note("pluck", pitch, base + hit, .25, .045, .30, .28)

    # Circular, decorrelated early reflections preserve a continuous room tail.
    master = dry.copy()
    for delay, gain, cross in [(0.047, .23, True), (.089, .19, False), (.137, .15, True),
                              (.211, .11, False), (.307, .075, True), (.419, .048, False)]:
        shifted = np.roll(send, round(delay * RATE), axis=0)
        master += shifted[:, ::-1] * gain if cross else shifted * gain
    # Periodic spectral shaping removes sub-bass and abrasive upper transients.
    spectrum = np.fft.rfft(master, axis=0)
    freqs = np.fft.rfftfreq(count, 1.0 / RATE)
    high_pass = freqs ** 2 / (freqs ** 2 + 32.0 ** 2)
    low_pass = 1.0 / np.sqrt(1.0 + (freqs / (6500 if food else 7200)) ** 8)
    master = np.fft.irfft(spectrum * (high_pass * low_pass)[:, None], n=count, axis=0)
    master -= np.mean(master, axis=0)
    # Gentle saturation reduces occasional chord transients without hard clipping.
    master = np.tanh(master * 1.28)
    master *= .68 / np.max(np.abs(master))
    # A 2.5 ms cosine guard suppresses independent Vorbis edge-window error.
    # It is shorter than a mallet attack, not a musical fade or silent tail.
    guard = round(.0025 * RATE)
    ramp = .5 - .5 * np.cos(np.linspace(0.0, math.pi, guard))
    master[:guard] *= ramp[:, None]
    master[-guard:] *= ramp[::-1, None]
    master = master.astype("<f4")
    return master, {
        "bars": BARS, "meter": "4/4", "bpm": spec["bpm"], "key": spec["key"],
        "seed": spec["seed"], "chord_progression": spec["chord_names"],
        "progression_repeats": 2, "unique_authored_melody_bars": len(spec["melody"]),
        "event_counts": event_counts, "loop_strategy": "Circular note tails, room reflections and master filtering, with a 2.5 ms cosine edge guard; no musical fade-out gap.",
    }


def sample_metrics(samples: np.ndarray) -> dict:
    jumps = np.abs(np.diff(samples, axis=0))
    seam = np.abs(samples[0] - samples[-1])
    boundary = np.concatenate((samples[-441:], samples[:441]))
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    return {
        "samples_per_channel": len(samples), "duration_seconds": len(samples) / RATE,
        "sample_rate": RATE, "channels": 2,
        "peak_linear": float(np.max(np.abs(samples))), "peak_dbfs": db(np.max(np.abs(samples))),
        "rms_dbfs": db(rms), "dc_max_absolute": float(np.max(np.abs(np.mean(samples, axis=0)))),
        "clipped_samples": int(np.count_nonzero(np.abs(samples) >= 1)),
        "seam_jump_per_channel": [float(value) for value in seam],
        "seam_jump_max": float(np.max(seam)),
        "interior_step_p99": float(np.quantile(jumps, .99)),
        "interior_step_max": float(np.max(jumps)),
        "boundary_20ms_rms_dbfs": db(np.sqrt(np.mean(boundary.astype(np.float64) ** 2))),
        "stereo_correlation": float(np.corrcoef(samples.T)[0, 1]),
    }


def encode_and_measure(output: Path, name: str, pcm: np.ndarray, spec: dict) -> dict:
    destination = output / f"{name}.ogg"
    with tempfile.TemporaryDirectory(prefix="hole-music-") as temp:
        encoded = Path(temp) / destination.name
        command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "f32le", "-ar", str(RATE),
                   "-ac", "2", "-i", "pipe:0", "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "3",
                   "-fflags", "+bitexact", "-flags:a", "+bitexact", "-metadata", f"title={spec['title']}",
                   "-metadata", "artist=Sink City original procedural score", "-metadata", "LOOPSTART=0",
                   "-metadata", f"LOOPEND={len(pcm)}", "-y", str(encoded)]
        subprocess.run(command, input=pcm.tobytes(), check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        raw = subprocess.check_output(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(encoded),
                                       "-f", "f32le", "-acodec", "pcm_f32le", "-ar", str(RATE), "-ac", "2", "pipe:1"])
        decoded = np.frombuffer(raw, dtype="<f4").reshape(-1, 2)
        probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(encoded)]))
        metrics = sample_metrics(decoded)
        loudness = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(encoded),
                                   "-af", "ebur128=peak=true", "-f", "null", "-"],
                                  check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stderr
        summary = loudness.rsplit("Summary:", 1)[-1]
        metrics["integrated_lufs"] = float(re.search(r"\bI:\s*(-?[\d.]+) LUFS", summary).group(1))
        metrics["true_peak_dbtp"] = float(re.search(r"Peak:\s*(-?[\d.]+) dBFS", summary).group(1))
        checks = {
            "exact_sample_count": len(decoded) == len(pcm),
            "vorbis_stereo_44100": probe["streams"][0]["codec_name"] == "vorbis" and probe["streams"][0]["channels"] == 2 and int(probe["streams"][0]["sample_rate"]) == RATE,
            "duration_20_to_40_seconds": 20 <= metrics["duration_seconds"] <= 40,
            "under_500_kib": encoded.stat().st_size < 500 * 1024,
            "no_clipping": metrics["clipped_samples"] == 0 and metrics["peak_linear"] < .85,
            "useful_dynamic_level": -26 < metrics["rms_dbfs"] < -12,
            "small_boundary_step": metrics["seam_jump_max"] < .01 and metrics["seam_jump_max"] < metrics["interior_step_p99"] * 1.5,
            "no_dc_offset": metrics["dc_max_absolute"] < .001,
            "no_silent_loop_gap": metrics["boundary_20ms_rms_dbfs"] > -45,
            "finite_samples": bool(np.all(np.isfinite(decoded))),
        }
        if not all(checks.values()):
            raise RuntimeError(json.dumps({"track": name, "checks": checks, "metrics": metrics}, indent=2))
        data = encoded.read_bytes()
        destination.write_bytes(data)
    return {
        "file": destination.name, "title": spec["title"], "bytes": len(data), "sha256": sha(data),
        "source_pcm_sha256": sha(pcm.tobytes()), "source_pcm": sample_metrics(pcm),
        "decoded_vorbis": metrics, "checks": checks,
        "encoding": "Ogg Vorbis, libvorbis quality 3, bitexact container flags",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets" / "audio")
    args = parser.parse_args()
    for executable in ("ffmpeg", "ffprobe"):
        if shutil.which(executable) is None:
            parser.error(f"Missing {executable}; install locally before running this offline tool.")
    args.output.mkdir(parents=True, exist_ok=True)
    tracks = []
    for name, spec in TRACKS.items():
        pcm, arrangement = compose(name, spec)
        result = encode_and_measure(args.output, name, pcm, spec)
        result["arrangement"] = arrangement
        tracks.append(result)
        print(json.dumps({"track": name, "bytes": result["bytes"], "metrics": result["decoded_vorbis"], "checks": result["checks"]}), flush=True)
    manifest = {
        "schema": 1, "generator": "tools/build_music.py", "generator_sha256": sha(Path(__file__).read_bytes()),
        "numpy_version": np.__version__,
        "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
        "provenance": "Original authored melody, arrangement and additive/percussive synthesis. No downloaded music, samples, external recordings or model audio generation.",
        "license": "CC0-1.0; see README.md", "tracks": tracks,
        "limitations": "Objective file, amplitude and loop-boundary checks only. No native playback, browser audition or subjective listening acceptance was performed.",
    }
    (args.output / "music_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
