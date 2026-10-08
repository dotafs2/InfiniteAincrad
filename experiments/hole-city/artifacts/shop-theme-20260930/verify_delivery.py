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
EXPECTED_NOTICE_FILES = {"credits.html", "notices/FREDOKA_OFL.txt", "notices/GODOT_LICENSES.txt",
                         "notices/LICENSE.txt", "notices/MBMAYER_LICENSE.txt", "notices/MUSIC_CREDITS.txt", "notices/THIRD_PARTY.md"}
EXPECTED_FILES = EXPECTED_NOTICE_FILES | {"notices/manifest.json", "device-qa.js", "index.apple-touch-icon.png",
    "index.audio.position.worklet.js", "index.audio.worklet.js", "index.html", "index.icon.png", "index.js", "index.pck", "index.png", "index.wasm"}
EXPECTED_NOTICE_SOURCES = {"LICENSE", "THIRD_PARTY.md", "assets/fonts/OFL.txt", "third_party/mbmayer/LICENSE", "assets/audio/MUSIC_CREDITS.txt"}


def main():
    previous = EVIDENCE / "verification.json"
    if previous.exists():
        previous.rename(EVIDENCE / ("verification.previous." + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + ".json"))
    release_path = EVIDENCE / "release/release.json"
    manifest_hash = gate.digest(release_path)
    manifest = json.loads(release_path.read_text())
    assert not manifest["failures"]
    assert set(manifest["artifacts"]) == EXPECTED_FILES
    assert manifest["train_asset_checks"] >= 246
    gate.verify_inputs(manifest["source_sha256"])
    counts = {}
    for phase in ("source", "package"):
        total = 0
        for suite, _, minimum in gate.SUITES:
            report = json.loads((EVIDENCE / "release" / f"{phase}-{suite}.json").read_text())
            assert not report["failures"] and report["checks"] >= minimum, (phase, suite)
            log = (EVIDENCE / "release" / f"{phase}-{suite}.log").read_text()
            assert not gate.unexpected_engine_errors(log, suite == "coin_skins"), (phase, suite)
            prefix = gate.REVIEW_SCRIPTS.get(suite, (None, suite.upper() + "_ACCEPTANCE"))[1] + " "
            markers = [line[len(prefix):] for line in log.splitlines() if line.startswith(prefix)]
            assert markers and json.loads(markers[-1]) == report, (phase, suite, "Report/log mismatch")
            total += report["checks"]
        counts[phase] = total
    assert counts["source"] == manifest["source_checks"]
    assert counts["package"] == manifest["packaged_checks"]
    assert not gate.unexpected_engine_errors((EVIDENCE / "release/export.log").read_text())
    bundle_root = ROOT / "build/web"
    assert not bundle_root.is_symlink()
    assert not any(path.is_symlink() for path in bundle_root.rglob("*"))
    assert {str(path.relative_to(bundle_root)) for path in bundle_root.rglob("*") if path.is_file()} == EXPECTED_FILES
    notices = json.loads((bundle_root / "notices/manifest.json").read_text())
    assert set(notices["files"]) == EXPECTED_NOTICE_FILES
    assert set(notices["source_sha256"]) == EXPECTED_NOTICE_SOURCES
    for name, sha in notices["files"].items():
        assert gate.digest(bundle_root / name) == sha, name
    for source, sha in notices["source_sha256"].items():
        assert gate.digest(ROOT / source) == sha, source
    html = (bundle_root / "index.html").read_text()
    assert html.count('rel="license" href="credits.html"') == 1
    assert html.count('id="sink-city-credits"') == 1
    assert '"version": "0.11.1"' in html
    assert (EVIDENCE / "release/web-notices-test.log").read_text().rstrip().endswith("OK")
    served = []
    for name, expected in manifest["artifacts"].items():
        assert gate.digest(ROOT / "build/web" / name) == expected
        request = urllib.request.Request(
            "http://127.0.0.1:8768/" + name, headers={"Cache-Control": "no-cache"}
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            assert response.headers.get("Cross-Origin-Opener-Policy") == "same-origin"
            assert response.headers.get("Cross-Origin-Embedder-Policy") == "require-corp"
            if name.endswith(".wasm"):
                assert response.headers.get_content_type() == "application/wasm"
            data = response.read()
            actual = hashlib.sha256(data).hexdigest()
            assert actual == expected and response.status == 200, name
            served.append({"file": name, "sha256": actual, "bytes": len(data), "http_status": response.status})
    version = next(
        line.split("=", 1)[1].strip('"')
        for line in (ROOT / "project.godot").read_text().splitlines()
        if line.startswith("config/version=")
    )
    assert version == "0.11.1"
    gate.verify_inputs(manifest["source_sha256"])
    assert gate.digest(release_path) == manifest_hash
    result = {
        "release_manifest_sha256": manifest_hash,
        "verifier_sha256": gate.digest(Path(__file__)),
        "version": version,
        "verified_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "suites_per_phase": len(gate.SUITES),
        "checks": counts,
        "tested_input_count": len(manifest["source_sha256"]),
        "inputs_unchanged": True,
        "train_asset_checks": manifest["train_asset_checks"],
        "notice_files_verified": len(notices["files"]),
        "served_artifacts": served,
        "limitations": [
            "Static HTTP artifact bytes only; no browser capture or runtime inspection.",
            "Headless physics, Blender asset renders and desktop controller timings do not establish iPhone GPU FPS.",
        ],
    }
    (EVIDENCE / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
