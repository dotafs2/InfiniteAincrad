"""Run the isolated large-hole CPU probe only after receiving the shared CPU slot."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import math
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SPEC = importlib.util.spec_from_file_location("release_web", ROOT / "tools/release_web.py")
RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RELEASE)


def hashes(godot):
    result = RELEASE.input_hashes()
    for path in [HERE / "large_growth_profile.gd", Path(__file__), godot]:
        key = str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else "engine_binary"
        result[key] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def validate(data, map_id, before):
    if data.get("failures"):
        raise RuntimeError("Workload validation failed: " + repr(data["failures"]))
    if (data.get("marker"), data.get("map"), data.get("scenario"), data.get("headless")) != (
        "LARGE_GROWTH_PROFILE", map_id, "large-growth-real-round", True
    ):
        raise RuntimeError("Unexpected probe metadata")
    if data.get("source_sha256") != before:
        raise RuntimeError("Report did not retain the exact source manifest")
    times = data.get("frame_times_ms", [])
    if len(times) != 600 or data.get("samples") != 600 or data.get("warmup_frames") != 60:
        raise RuntimeError("Expected 60 warmup and 600 measured frames")
    if any(type(value) not in (int, float) or not math.isfinite(value) or value < 0 for value in times):
        raise RuntimeError("Invalid raw frame intervals")
    ordered = sorted(times)
    for key, quantile in [("p50_ms", .5), ("p95_ms", .95), ("p99_ms", .99), ("worst_ms", 1)]:
        if not math.isclose(data[key], ordered[min(599, int(600 * quantile))], abs_tol=.000001):
            raise RuntimeError("Percentile disagrees with raw intervals: " + key)
    if data["over_16_67_ms"] != sum(value > 16.667 for value in times):
        raise RuntimeError("Budget count disagrees with raw intervals")
    timeline = data.get("timeline", [])
    if [entry["frame"] for entry in timeline] != list(range(60, 660)):
        raise RuntimeError("Timeline must preserve all measured frames in order")
    if any(data["measured_updates"].get(key) != 600 for key in ["physics", "rivals", "camera", "reveal"]):
        raise RuntimeError("The ordinary game loop did not stay active")
    if data["measured_updates"]["food"] < 90 or data["final"]["phase"] != "playing":
        raise RuntimeError("The real admission workload stopped")
    if min(data["collections_measured"], data["player_collections_measured"], data["measured_sampled_peak_dynamic"], data["measured_sampled_peak_falling"]) <= 0:
        raise RuntimeError("The sample lacks genuine falling/collection workload")
    receipts = data["collection_receipts"]
    if len(receipts) != data["collections_total"] or sum(row["frame"] >= 60 for row in receipts) != data["collections_measured"]:
        raise RuntimeError("Collection receipt totals do not reconcile")
    if not all(row["consumed"] and not row["freeze"] for row in receipts):
        raise RuntimeError("A collection receipt did not come from a released, consumed object")
    if not .99 <= data["reveal_strength"] <= 1.0:
        raise RuntimeError("Reveal controller was inactive")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    godot = args.godot.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = hashes(godot)
    manifest = output / "source-manifest.json"
    manifest.write_text(json.dumps({"source_sha256": before}, indent=2) + "\n")
    records = {}
    for map_id in ["city", "food"]:
        report = output / (map_id + ".json")
        log = output / (map_id + ".log")
        command = [str(godot), "--headless", "--path", str(ROOT), "--fixed-fps", "60", "--script", str(HERE / "large_growth_profile.gd"), "--log-file", str(output / (map_id + ".engine.log")), "--", "--test", "--map=" + map_id, "--report=" + str(report), "--source-manifest=" + str(manifest)]
        print("Profiling large growth: " + map_id, flush=True)
        with log.open("w") as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=120)
        text = log.read_text()
        if result.returncode or RELEASE.unexpected_engine_errors(text) or "LARGE_GROWTH_PROFILE " not in text or not report.is_file():
            raise RuntimeError("Large-growth profile failed; inspect " + str(log))
        data = json.loads(report.read_text())
        validate(data, map_id, before)
        records[map_id] = {key: data[key] for key in ["p50_ms", "p95_ms", "p99_ms", "worst_ms", "over_16_67_ms", "samples", "initial", "final", "measured_updates", "collections_measured", "player_collections_measured", "measured_sampled_peak_dynamic", "measured_sampled_peak_falling"]}
        records[map_id]["native_contact_diagnostics"] = text.count("num_points >= max_clip")
        records[map_id]["combat_events"] = len(data["combat_events"])
        print(json.dumps({map_id: records[map_id]}), flush=True)
    if before != hashes(godot):
        raise RuntimeError("Source or engine changed while profiling; no summary published")
    summary = {"scope": "One bounded trace per map; Mac headless CPU wall intervals including probe overhead, not browser/phone FPS", "source_sha256": before, "inputs_unchanged": True, "samples_total": 1200, "summary": records}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    main()
