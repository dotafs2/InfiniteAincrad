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
    """Soft, harmonic approximations of wood, nylon strings and a round bass.

    These are original synthesized timbres, not recordings of acoustic instruments.
    No detuned doubles, metallic modes or high-register bell layer are used.
    """
    t = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    f = frequency(midi)
    if kind in ("wood", "thumb_piano"):
        decay = .48 if kind == "wood" else .58
        wave = np.sin(TAU * f * t) * np.exp(-t / decay)
        wave += .16 * np.sin(TAU * f * 2 * t) * np.exp(-t / .17)
        wave += (.045 if kind == "wood" else .065) * np.sin(TAU * f * 3 * t) * np.exp(-t / .09)
        wave *= envelope(t, .016 if kind == "wood" else .020, 3.0, duration)
    elif kind == "nylon":
        wave = np.zeros_like(t)
        for harmonic, amount in [(1, .85), (2, .17), (3, .065), (4, .018)]:
            wave += amount * np.sin(TAU * f * harmonic * t) * np.exp(-t * harmonic / .95)
        wave *= envelope(t, .020, 1.8, duration)
    elif kind == "bass":
        wave = np.sin(TAU * f * t)
        wave += .16 * np.sin(TAU * f * 2 * t) * np.exp(-t / .24)
        wave *= envelope(t, .025, .50, duration)
    else:
        raise ValueError(kind)
    return wave


def percussion(kind: str, rng: np.random.Generator) -> np.ndarray:
    if kind != "brush":
        raise ValueError(kind)
    duration = .16
    t = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    noise = rng.standard_normal(t.size)
    # A quiet, low-passed breath provides pulse without clicks, rimshots or hats.
    soft = np.convolve(noise, np.ones(35) / 35.0, mode="same")
    soft -= np.convolve(soft, np.ones(180) / 180.0, mode="same")
    return soft * envelope(t, .022, .050, duration)


# A is stated twice, B rises gently, and the final phrase returns to A.
# (Beat, MIDI pitch, duration in beats). Explicit rests separate the phrases.
# The lead stays in a comfortable G4-E5 / F4-D5 register.
SUNNY_MELODY = [
    [(.5, 72, .75), (2, 76, 1)],
    [(.5, 76, .75), (2, 72, 1)],
    [(.5, 69, .75), (2, 72, 1)],
    [(.5, 71, 1.5)],
    [(.5, 72, .75), (1.75, 74, .5), (2.75, 76, .75)],
    [(.5, 76, .75), (2, 72, 1)],
    [(.5, 69, .75), (2, 74, 1)],
    [(.5, 71, 1), (2, 67, 1)],
    [(.5, 69, .75), (2, 72, 1)],
    [(.5, 76, .75), (2, 72, 1)],
    [(.5, 74, .75), (2, 69, 1)],
    [(.5, 74, .75), (2, 71, 1)],
    [(.5, 72, .75), (2, 69, 1)],
    [(.5, 71, .75), (2, 74, 1)],
    [(.5, 72, 1.75)],
    [(.5, 71, .75), (2.5, 67, 1.5)],
]
FOOD_MELODY = [
    [(.5, 69, .75), (2, 72, 1)],
    [(.5, 74, .75), (2, 69, 1)],
    [(.5, 70, .75), (2, 74, 1)],
    [(.5, 67, 1.5)],
    [(.5, 69, .75), (1.75, 67, .5), (2.75, 65, .75)],
    [(.5, 69, .75), (2, 74, 1)],
    [(.5, 70, .75), (2, 67, 1)],
    [(.5, 72, 1), (2, 67, 1)],
    [(.5, 70, .75), (2, 74, 1)],
    [(.5, 72, .75), (2, 69, 1)],
    [(.5, 70, .75), (2, 67, 1)],
    [(.5, 67, .75), (2, 72, 1)],
    [(.5, 74, .75), (2, 70, 1)],
    [(.5, 72, .75), (2, 67, 1)],
    [(.5, 65, 1.75)],
    [(.5, 72, .75), (2.5, 67, 1.5)],
]

TRACKS = {
    "sunny_city_loop": {
        "title": "A Little Sunny Walk", "bpm": 104, "seed": 30092026,
        "key": "C major", "lead": "wood", "melody": SUNNY_MELODY,
        "chord_names": ["C", "Am", "F", "G", "C", "Am", "Dm", "G",
                        "F", "C", "Dm", "G", "F", "G", "C", "G"],
        "chords": [[60,64,67], [57,60,64], [57,60,65], [55,59,62],
                   [60,64,67], [57,60,64], [57,62,65], [55,59,62],
                   [57,60,65], [60,64,67], [57,62,65], [55,59,62],
                   [57,60,65], [55,59,62], [60,64,67], [55,59,62]],
        "bass": [48,45,41,43,48,45,38,43,41,48,38,43,41,43,48,43],
    },
    "snack_garden_loop": {
        "title": "Picnic in the Garden", "bpm": 108, "seed": 30092027,
        "key": "F major", "lead": "thumb_piano", "melody": FOOD_MELODY,
        "chord_names": ["F", "Dm", "Bb", "C", "F", "Dm", "Gm", "C",
                        "Bb", "F", "Gm", "C", "Bb", "C", "F", "C"],
        "chords": [[57,60,65], [57,62,65], [58,62,65], [55,60,64],
                   [57,60,65], [57,62,65], [55,58,62], [55,60,64],
                   [58,62,65], [57,60,65], [55,58,62], [55,60,64],
                   [58,62,65], [55,60,64], [57,60,65], [55,60,64]],
        "bass": [41,38,46,48,41,38,43,48,46,41,43,48,46,48,41,48],
    },
}


def compose(name: str, spec: dict) -> tuple[np.ndarray, dict]:
    beat = 60.0 / spec["bpm"]
    count = round(BARS * 4 * beat * RATE)
    dry = np.zeros((count, 2), dtype=np.float64)
    send = np.zeros_like(dry)
    rng = np.random.default_rng(spec["seed"])
    event_counts: dict[str, int] = {}
    events = []

    def add(wave: np.ndarray, at: float, gain: float, pan: float, wet: float, instrument: str,
            pitch: int | None = None, written_length: float | None = None) -> None:
        # Circular accumulation preserves the previous phrase's quiet decay at the seam.
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
        events.append({"instrument": instrument, "beat": at, "midi": pitch,
                       "written_beats": written_length, "gain": gain, "pan": pan})

    def note(kind: str, pitch: int, at: float, length: float, gain: float, pan: float, wet: float = .12) -> None:
        duration = max(.20, length * beat + (.38 if kind in ("wood", "thumb_piano") else .16))
        add(pitched(kind, pitch, duration, rng), at, gain, pan, wet, kind, pitch, length)

    for bar in range(BARS):
        base = bar * 4.0
        chord = spec["chords"][bar]
        root = spec["bass"][bar]
        # One softly strummed triad per bar; no comping, pads or countermelody.
        for index, pitch in enumerate(chord):
            note("nylon", pitch, base + index * .032, 2.8, .090, -.25 + index * .09, .10)
        note("bass", root, base, 1.6, .15, 0, .025)
        if bar % 4 in (1, 3):
            note("bass", root + 7, base + 2.5, .85, .077, 0, .025)
        for hit, pitch, length in spec["melody"][bar]:
            note(spec["lead"], pitch, base + hit, length, .18, .10, .14)
        # One soft percussion timbre, with breathing room at phrase endings.
        for hit in ([1] if bar % 4 == 3 else [1, 3]):
            add(percussion("brush", rng), base + hit, .045, -.10, .025, "brush")

    master = dry.copy()
    # Short, very quiet room reflections; no sustained echo cloud.
    for delay, gain in [(.061, .18), (.103, .10), (.157, .045)]:
        master += np.roll(send, round(delay * RATE), axis=0)[:, ::-1] * gain
    spectrum = np.fft.rfft(master, axis=0)
    freqs = np.fft.rfftfreq(count, 1.0 / RATE)
    high_pass = freqs ** 2 / (freqs ** 2 + 45.0 ** 2)
    low_pass = 1.0 / np.sqrt(1.0 + (freqs / 3500.0) ** 8)
    master = np.fft.irfft(spectrum * (high_pass * low_pass)[:, None], n=count, axis=0)
    master -= np.mean(master, axis=0)
    # Match the two maps gently, without compression or saturation. Leave transients intact.
    target_rms = 10 ** (-24.5 / 20)
    gain = min(target_rms / np.sqrt(np.mean(master ** 2)), .42 / np.max(np.abs(master)))
    master *= gain
    guard = round(.0025 * RATE)
    ramp = .5 - .5 * np.cos(np.linspace(0.0, math.pi, guard))
    master[:guard] *= ramp[:, None]
    master[-guard:] *= ramp[::-1, None]
    master = master.astype("<f4")
    lead_events = [e for e in events if e["instrument"] == spec["lead"]]
    written_coverage = sum(e["written_beats"] for e in lead_events) / (BARS * 4)
    return master, {
        "bars": BARS, "meter": "4/4", "bpm": spec["bpm"], "key": spec["key"],
        "seed": spec["seed"], "chord_progression": spec["chord_names"],
        "progression_repeats": 1, "authored_melody_bars": len(spec["melody"]),
        "event_counts": event_counts, "events_per_second": len(events) / (count / RATE),
        "lead_midi_range": [min(e["midi"] for e in lead_events), max(e["midi"] for e in lead_events)],
        "written_lead_rest_fraction": 1 - written_coverage,
        "chord_voices": 3, "chord_strikes_per_bar": 1,
        "master_gain": float(gain), "master_rms_target_dbfs": -24.5,
        "events": events,
        "loop_strategy": "Circular note tails, short quiet room reflections and periodic filtering, with a 2.5 ms cosine edge guard; no musical fade-out gap.",
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
            "soft_dynamic_level": -26 < metrics["rms_dbfs"] < -21,
            "gentle_integrated_loudness": -26 < metrics["integrated_lufs"] < -21,
            "transient_headroom": metrics["true_peak_dbtp"] < -6,
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
        "schema": 2, "generator": "tools/build_music.py", "generator_sha256": sha(Path(__file__).read_bytes()),
        "numpy_version": np.__version__,
        "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
        "provenance": "Original authored melody, arrangement and additive/percussive synthesis. No downloaded music, samples, external recordings or model audio generation.",
        "license": "CC0-1.0; see README.md", "tracks": tracks,
        "limitations": "Objective file, amplitude and loop-boundary checks only. No native playback, browser audition or subjective listening acceptance was performed.",
    }
    (args.output / "music_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
