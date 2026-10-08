"""Verify tested inputs, strict reports, and the local server's actual bytes."""
from pathlib import Path
import datetime
import hashlib
import importlib.util
import json
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("release_gate", ROOT / "tools/release_web.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def main():
    manifest = json.loads((EVIDENCE / "release/release.json").read_text())
    assert not manifest["failures"]
    gate.verify_inputs(manifest["source_sha256"])
    counts = {}
    for phase in ("source", "package"):
        total = 0
        for suite, _, minimum in gate.SUITES:
            report = json.loads((EVIDENCE / "release" / f"{phase}-{suite}.json").read_text())
            assert not report["failures"] and report["checks"] >= minimum, (phase, suite)
            log = (EVIDENCE / "release" / f"{phase}-{suite}.log").read_text()
            assert not gate.unexpected_engine_errors(log, suite == "coin_skins"), (phase, suite)
            total += report["checks"]
        counts[phase] = total
    assert counts["source"] == manifest["source_checks"]
    assert counts["package"] == manifest["packaged_checks"]
    assert not gate.unexpected_engine_errors((EVIDENCE / "release/export.log").read_text())
    served = []
    for name, expected in manifest["artifacts"].items():
        assert gate.digest(ROOT / "build/web" / name) == expected
        request = urllib.request.Request(
            "http://127.0.0.1:8768/" + name, headers={"Cache-Control": "no-cache"}
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read()
            actual = hashlib.sha256(data).hexdigest()
            assert actual == expected and response.status == 200, name
            served.append({"file": name, "sha256": actual, "bytes": len(data), "http_status": response.status})
    version = next(
        line.split("=", 1)[1].strip('"')
        for line in (ROOT / "project.godot").read_text().splitlines()
        if line.startswith("config/version=")
    )
    result = {
        "version": version,
        "verified_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "suites_per_phase": len(gate.SUITES),
        "checks": counts,
        "tested_input_count": len(manifest["source_sha256"]),
        "inputs_unchanged": True,
        "served_artifacts": served,
        "limitations": [
            "No browser screenshot or runtime inspection; static HTTP artifact bytes only.",
            "Headless scene/interaction checks and software OpenGL food-color probes do not establish iPhone GPU FPS.",
            "Native payment and rewarded-ad providers are protocol-injected test fixtures, not installed live SDKs.",
            "Retention probabilities are an initial design, not experimentally optimized retention rates.",
        ],
    }
    (EVIDENCE / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
