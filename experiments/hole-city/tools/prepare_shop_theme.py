#!/usr/bin/env python3
"""Prepare the user-selected CC0 Shop Theme from its verified original ZIP.

Requires ffmpeg/ffprobe with libvorbis. No synthesis, network or source overwrite.
The full 88-second normal recording receives constant gain and Ogg compression.
"""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_SHA = "127e5556a7ef9d944e5a44b012ffc6f833fa673c4c2091b71909159b9965c836"
MEMBER = "shop_theme/Buy Something!.ogg"
SOURCE_SHA = "fa023f1d2e3d3194136bb8f877925d5547e5489439b24658698fbbb458de5b21"
GAIN_DB = -7.1


def digest(data):
    return hashlib.sha256(data).hexdigest()


def measure(path):
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-af", "asetpts=N/SR/TB", "-f", "f32le", "-acodec", "pcm_f32le", "-"])
    samples = array.array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    assert len(samples) == 88 * 44100 * 2, "Recording length or channels changed"
    assert all(math.isfinite(value) for value in samples)
    result = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True, check=True)
    integrated = float(re.findall(r"I:\s+([-\d.]+) LUFS", result.stderr)[-1])
    peak = float(re.findall(r"Peak:\s+([-\d.]+) dBFS", result.stderr)[-1])
    block = 441 * 2
    rms = lambda data: math.sqrt(sum(value * value for value in data) / len(data))
    return {"frames": len(samples)//2, "sample_rate": 44100, "channels": 2,
            "duration_seconds": 88.0, "integrated_lufs": integrated, "true_peak_dbfs": peak,
            "sample_peak": max(abs(value) for value in samples),
            "rms_dbfs": 20 * math.log10(rms(samples)),
            "boundary_sample_jump": max(abs(samples[channel]-samples[-2+channel]) for channel in range(2)),
            "first_10ms_rms": rms(samples[:block]), "last_10ms_rms": rms(samples[-block:])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/audio")
    args = parser.parse_args()
    assert digest(args.archive.read_bytes()) == ARCHIVE_SHA, "Unexpected source archive"
    with zipfile.ZipFile(args.archive) as archive:
        original = archive.read(MEMBER)
    assert digest(original) == SOURCE_SHA, "Unexpected source recording"
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="shop-theme-") as temporary:
        source = Path(temporary) / "original.ogg"
        encoded = Path(temporary) / "shop_theme_loop.ogg"
        source.write_bytes(original)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source),
                        "-map_metadata", "-1", "-af", f"volume={GAIN_DB}dB", "-c:a", "libvorbis",
                        "-q:a", "3", "-ar", "44100", "-ac", "2",
                        "-metadata", "title=Buy Something! (Shop Theme)",
                        "-metadata", "artist=Cleyton Kauffman", "-metadata", "license=CC0-1.0",
                        "-metadata", "source=https://opengameart.org/content/shop-theme", str(encoded)], check=True)
        measurements = measure(encoded)
        assert -22.5 <= measurements["integrated_lufs"] <= -21.5
        assert measurements["true_peak_dbfs"] < -6.0
        assert measurements["boundary_sample_jump"] < 0.04
        data = encoded.read_bytes()
        assert len(data) < 1600000, "Unexpected mobile asset size"
    destination = args.output / "shop_theme_loop.ogg"
    destination.write_bytes(data)
    manifest = {"title": "Shop Theme", "recording_title": "Buy Something!", "author": "Cleyton Kauffman",
                "source_url": "https://opengameart.org/content/shop-theme",
                "license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                "source_archive_sha256": ARCHIVE_SHA, "source_member": MEMBER, "source_member_sha256": SOURCE_SHA,
                "original_metadata_artist": "Cleyton R. Xavier",
                "processing": {"constant_gain_db": GAIN_DB, "codec": "libvorbis", "quality": 3,
                               "trimmed": False, "edge_fades": False, "tempo_changed": False,
                               "note": "Full normal version; no added instruments or arrangement changes."},
                "maps": ["city", "food"], "asset": destination.name, "bytes": len(data), "sha256": digest(data),
                "measurements": measurements,
                "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                "limits": "Numerical measurements and decoder checks do not establish listening quality on a phone."}
    (args.output / "music_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
