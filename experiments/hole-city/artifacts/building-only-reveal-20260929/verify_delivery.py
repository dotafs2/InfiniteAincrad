"""Verify this building-only release's receipts and static HTTP delivery, without UI access."""
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
    assert len(release_web.SUITES) == 49, "Unexpected suite registry"
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
    shader_path = EVIDENCE / "shaders/result.json"
    shader = json.loads(shader_path.read_text())
    assert not shader["failures"], "Shader probe failed"
    shader_inputs = {"fidelity/" + name for name in ["asphalt.gdshader", "facade.gdshader", "palette.gdshader", "food_glaze.gdshader", "hole_reveal_standard.gdshader", "hole_reveal.gdshaderinc"]}
    shader_inputs |= {"tools/validate_mobile_visual_shaders.py", "tools/visual_shader_probe.m"}
    assert set(shader["input_sha256"]) == shader_inputs, "Incomplete shader input provenance"
    for name, expected in shader["input_sha256"].items():
        assert sha(ROOT / name) == expected, f"Shader probe input changed: {name}"
    program_counts = {"asphalt": 0, "facade": 0, "palette": 0, "food_glaze": 0, "hole_reveal_standard": 0,
                      "reveal-coverage": 19, "adapter-albedo": 12, "selective-palette": 3,
                      "selective-food_glaze": 9, "selective-hole_reveal_standard": 2}
    assert len(shader["programs"]) == len(program_counts) and {p["name"] for p in shader["programs"]} == set(program_counts), "Missing or duplicated shader programs"
    assert all(p.get("compiled") is True and len(p["cases"]) == program_counts[p["name"]] for p in shader["programs"]), "Shader compile or case completeness failed"
    food_program = next(p for p in shader["programs"] if p["name"] == "selective-food_glaze")
    food_cases = {"ordinary_food", "ordinary_food_in_mixed_batch", "legacy_structural_tier_in_mixed_batch", "released_food_tier", "food_structure_shadow",
                  "stale_positive_standalone_uniform", "stale_positive_uniform_and_full_instance", "giant_aperture_food_stays_solid", "gloss_alpha_is_not_transparency"}
    assert {c["name"] for c in food_program["cases"]} == food_cases, "Incomplete or duplicated food shader scenarios"
    assert all(c["visible_pixels"] == c["total_pixels"] and c["total_pixels"] > 0 for c in food_program["cases"]), "Food shader cut pixels"
    # The isolated coverage wrapper writes fixed opaque output. It measures
    # discard, not the engine's alpha pipeline; separately require the actual
    # source to contain no alpha output, include or discard instruction.
    food_code = (ROOT / "fidelity/food_glaze.gdshader").read_text()
    food_code = re.sub(r"/\*.*?\*/|//[^\n]*", "", food_code, flags=re.S)
    assert not re.search(r"\b(?:ALPHA(?:_\w+)?|discard)\b|#include", food_code), "Food shader regained transparency or discard behavior"
    assert {"index.html", "index.pck", "index.wasm", "index.js", "device-qa.js"} <= set(manifest["artifacts"])
    version = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M).group(1)
    assert version == "0.8.5", "Unexpected release version"
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
                shader_receipt_sha256=sha(shader_path), shader_programs=len(shader["programs"]),
                shader_cases=sum(len(p["cases"]) for p in shader["programs"]),
                food_opacity_evidence="All nine isolated cases retain every pixel; separate source guard excludes ALPHA outputs, includes and discard. The fixed-output wrapper alone does not validate alpha blending.",
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
