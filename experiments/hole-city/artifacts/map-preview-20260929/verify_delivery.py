"""Verify this miniature release's receipts and static HTTP delivery, without UI access."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import quote
from urllib.request import Request, urlopen

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import release_web


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def completion(text, marker):
    prefix = marker + " "
    matches = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    assert matches, f"Missing completion marker: {marker}"
    return json.loads(matches[-1])


def verify():
    manifest_path = EVIDENCE / "release/release.json"
    manifest_sha = sha(manifest_path)
    manifest = json.loads(manifest_path.read_text())
    assert not manifest["failures"], "Release has failures"
    assert manifest["source_sha256"] == release_web.input_hashes(), "Tested inputs changed"
    assert len(release_web.SUITES) == 48, "Unexpected suite registry"
    receipts = {}
    totals = {}
    for phase, total_key in [("source", "source_checks"), ("package", "packaged_checks")]:
        total = 0
        for suite, _, minimum in release_web.SUITES:
            path = EVIDENCE / "release" / f"{phase}-{suite}.json"
            result = json.loads(path.read_text())
            log = path.with_suffix(".log")
            log_text = log.read_text()
            marker = release_web.REVIEW_SCRIPTS.get(suite, (None, suite.upper() + "_ACCEPTANCE"))[1]
            assert completion(log_text, marker) == result, f"Log/receipt mismatch: {path.name}"
            assert not result.get("failures"), f"Failed receipt: {path.name}"
            assert result["checks"] >= minimum, f"Incomplete receipt: {path.name}"
            assert not release_web.unexpected_engine_errors(log_text, suite == "coin_skins"), f"Engine error: {log.name}"
            receipts[path.name] = {"sha256": sha(path), "log_sha256": sha(log), "checks": result["checks"]}
            total += result["checks"]
        assert total == manifest[total_key], f"Incorrect total: {phase}"
        totals[total_key] = total
    recorder_log = EVIDENCE / "release/device-qa-test.log"
    recorder_result = completion(recorder_log.read_text(), "DEVICE_QA_TEST")
    assert not recorder_result.get("failures"), "Device recorder self-test failed"
    assert recorder_result["checks"] == manifest["device_recorder_checks"], "Device recorder count mismatch"
    assert {"index.html", "index.pck", "index.wasm", "index.js", "device-qa.js"} <= set(manifest["artifacts"])
    version = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M).group(1)
    assert version == "0.8.4", "Unexpected release version"
    delivery = {}
    for name, expected in manifest["artifacts"].items():
        assert sha(ROOT / "build/web" / name) == expected, f"Local build mismatch: {name}"
        request = Request("http://127.0.0.1:8768/" + quote(name), headers={"Cache-Control": "no-cache"})
        with urlopen(request, timeout=30) as response:
            body = response.read()
            actual = hashlib.sha256(body).hexdigest()
            headers = {key: response.headers.get(key) for key in ["Cross-Origin-Opener-Policy", "Cross-Origin-Embedder-Policy", "Cache-Control"]}
        assert actual == expected, f"HTTP mismatch: {name}"
        assert headers["Cross-Origin-Opener-Policy"] == "same-origin", f"Missing COOP: {name}"
        assert headers["Cross-Origin-Embedder-Policy"] == "require-corp", f"Missing COEP: {name}"
        delivery[name] = {"sha256": actual, "bytes": len(body), "headers": headers}
        if name == "index.html":
            metadata = json.loads(re.search(r"window.SINK_QA_BUILD = (\{[^\n]*\});", body.decode()).group(1))
            assert metadata["version"] == version
            for key, artifact in [("pck_sha256", "index.pck"), ("wasm_sha256", "index.wasm"), ("recorder_sha256", "device-qa.js")]:
                assert metadata[key] == manifest["artifacts"][artifact], f"HTML metadata mismatch: {key}"
    assert manifest["source_sha256"] == release_web.input_hashes(), "Inputs changed during verification"
    assert sha(manifest_path) == manifest_sha, "Release manifest changed during verification"
    return dict(version=version, failures=[], verified_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                **totals, suites_per_phase=len(release_web.SUITES), device_recorder_checks=manifest["device_recorder_checks"],
                device_recorder_log_sha256=sha(recorder_log),
                release_sha256=manifest_sha, verifier_sha256=sha(Path(__file__)),
                receipts=receipts, http_artifacts=delivery,
                scope="Native headless scene/UI geometry and static HTTP bytes. No browser appearance, GPU frame rate or iPhone performance acceptance.")


if __name__ == "__main__":
    # Preserve prior receipts without leaving an old success at the current path
    # if this verification attempt fails.
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    for filename in ["verification.json", "verification-failure.json"]:
        previous = EVIDENCE / filename
        if previous.exists():
            previous.rename(EVIDENCE / f"{previous.stem}-{stamp}.json")
    try:
        result = verify()
    except Exception as error:
        (EVIDENCE / "verification-failure.json").write_text(json.dumps({"failures": [str(error)]}, indent=2) + "\n")
        raise
    (EVIDENCE / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["version", "failures", "source_checks", "packaged_checks", "suites_per_phase"]}))
