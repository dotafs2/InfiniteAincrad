"""Verify exact locally served release bytes; this does not run a browser."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import statistics
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def marker(log, prefix):
    records = [json.loads(line[len(prefix):]) for line in log.splitlines() if line.startswith(prefix)]
    assert records, "Missing completion marker: " + prefix
    return records[-1]


def profile_inputs(gate):
    inputs = gate.input_hashes()
    for name in ["tests/mobile_profile.gd", "tools/profile_maps.py", "artifacts/audit-fixes-20260928/verify_delivery.py",
                 "artifacts/audit-fixes-20260928/profile_final.py"]:
        inputs[name] = sha(ROOT / name)
    return inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu", required=True, type=Path)
    args = parser.parse_args()
    evidence = ROOT / "artifacts/audit-fixes-20260928"
    release_dir = evidence / "release"
    release = json.loads((release_dir / "release.json").read_text())
    spec = importlib.util.spec_from_file_location("gate", ROOT / "tools/release_web.py")
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    assert release["failures"] == []
    assert gate.input_hashes() == release["source_sha256"], "Source changed after release"
    suites = {}
    for phase, total_key in [("source", "source_checks"), ("package", "packaged_checks")]:
        checks = 0
        for name, _, minimum in gate.SUITES:
            result = json.loads((release_dir / f"{phase}-{name}.json").read_text())
            assert not result["failures"] and result["checks"] >= minimum
            log = (release_dir / f"{phase}-{name}.log").read_text()
            assert not gate.unexpected_engine_errors(log, name == "coin_skins")
            prefix = gate.REVIEW_SCRIPTS.get(name, (None, name.upper() + "_ACCEPTANCE"))[1] + " "
            assert marker(log, prefix) == result
            checks += result["checks"]
        assert checks == release[total_key]
        suites[phase] = {"suites": len(gate.SUITES), "checks": checks}
    assert marker((release_dir / "device-qa-test.log").read_text(), "DEVICE_QA_TEST ")["checks"] == release["device_recorder_checks"]

    served = {}
    assert {str(p.relative_to(ROOT / "build/web")) for p in (ROOT / "build/web").rglob("*") if p.is_file()} == set(release["artifacts"])
    for name, expected in release["artifacts"].items():
        assert sha(ROOT / "build/web" / name) == expected
        requested_url = "http://127.0.0.1:8768/" + name
        with urlopen(requested_url, timeout=30) as response:
            assert response.status == 200
            assert response.geturl() == requested_url, "Unexpected delivery redirect"
            for header, value in [("Cross-Origin-Opener-Policy", "same-origin"),
                                  ("Cross-Origin-Embedder-Policy", "require-corp"),
                                  ("Cache-Control", "no-store")]:
                assert response.headers.get(header) == value
            digest = hashlib.sha256()
            size = 0
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                size += len(chunk)
            assert digest.hexdigest() == expected, name
            served[name] = {"sha256": expected, "bytes": size,
                            "content_type": response.headers.get("Content-Type")}
    assert served["index.wasm"]["content_type"] == "application/wasm"
    html = (ROOT / "build/web/index.html").read_text()
    metadata = json.loads(re.search(r"window\.SINK_QA_BUILD = (\{[^\n]+\});", html)[1])
    for field, filename in [("pck_sha256", "index.pck"), ("wasm_sha256", "index.wasm"),
                            ("recorder_sha256", "device-qa.js")]:
        assert metadata[field] == served[filename]["sha256"]
    version = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M)[1]
    assert metadata["version"] == version

    cpu_dir = args.cpu.resolve()
    cpu = json.loads((cpu_dir / "summary.json").read_text())
    for name, expected in cpu["source_sha256"].items():
        assert sha(ROOT / name) == expected, "Profiled input changed: " + name
    soak = json.loads((cpu_dir / "food-rain-soak.json").read_text())
    provenance = json.loads((cpu_dir / "provenance.json").read_text())
    assert provenance["before"] == provenance["after"] == profile_inputs(gate)
    assert sha(Path(provenance["godot_path"])) == provenance["godot_sha256"]
    assert cpu["repeats"] == 3
    names = [f"{m}-{s}-{i}" for i in range(1, 4) for m in ["city", "food"] for s in ["opening", "grown"]] + ["food-rain-soak"]
    expected_raw = {name + ext for name in names for ext in [".json", ".log", ".engine.log"]} | {"summary.json"}
    assert set(provenance["raw_sha256"]) == expected_raw
    for name, expected in provenance["raw_sha256"].items():
        assert sha(cpu_dir / name) == expected
    raw = {}
    for name in names:
        data = json.loads((cpu_dir / (name + ".json")).read_text())
        log = (cpu_dir / (name + ".log")).read_text()
        assert not gate.unexpected_engine_errors(log)
        assert marker(log, "MOBILE_PROFILE ") == data
        assert data["headless"] and data["physics_hz"] == 60 and data["version"] == version and data["phase"] == "playing"
        assert data["map"] == name.split("-")[0]
        assert data["scenario"] == ("rain_soak" if name == "food-rain-soak" else name.split("-")[1])
        values = sorted(data["frame_times_ms"])
        assert data["samples"] == len(values) == 600 and all(v >= 0 for v in values)
        for key, q in [("p50_ms", .5), ("p95_ms", .95), ("p99_ms", .99), ("worst_ms", 1)]:
            assert data[key] == values[min(len(values)-1, int(len(values)*q))]
        assert data["over_16_67_ms"] == sum(v > 16.667 for v in values)
        data["native_contact_diagnostics"] = log.count("num_points >= max_clip")
        raw[name] = data
    assert soak["simulation_seconds"] >= 239.9 and soak["retained_rain"] > 24
    assert set(cpu["summary"]) == {f"{m}-{s}" for m in ["city", "food"] for s in ["opening", "grown"]}
    for name, summary in cpu["summary"].items():
        rows = [raw[f"{name}-{i}"] for i in range(1, 4)]
        for key in ["p50_ms", "p95_ms", "p99_ms", "worst_ms", "nodes"]:
            assert summary[key] == statistics.median(r[key] for r in rows)
        for key in ["samples", "over_16_67_ms", "native_contact_diagnostics"]:
            assert summary[key] == sum(r[key] for r in rows)
    cpu_frames = sum(r["samples"] for r in raw.values())
    result = {"verified_at_utc": datetime.now(timezone.utc).isoformat(), "version": version,
              "scope": "Static HTTP delivery, source identity and native QA evidence; no browser or phone execution",
              "release_manifest_sha256": sha(release_dir / "release.json"),
              "guarded_inputs": len(release["source_sha256"]), "acceptance": suites,
              "served": served, "device_build_metadata": metadata,
              "cpu_evidence": str(cpu_dir.relative_to(ROOT)), "cpu_frames": cpu_frames,
              "profile_provenance_sha256": sha(cpu_dir / "provenance.json"),
              "profile_provenance_inputs": len(provenance["before"]),
              "profiled_inputs_matching_current_source": len(cpu["source_sha256"]),
              "remaining": ["Browser-rendered appearance and interaction", "Physical iPhone 14 ten active minutes per map"]}
    (evidence / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ["version", "guarded_inputs", "acceptance", "cpu_frames", "profiled_inputs_matching_current_source"]}, indent=2))
    print("All %d served artifacts match the release manifest." % len(served))


if __name__ == "__main__":
    main()
