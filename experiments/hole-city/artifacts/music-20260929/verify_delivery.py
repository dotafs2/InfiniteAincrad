"""Bind music QA to the actual exported and statically served game bytes."""
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
    assert not manifest["failures"]
    assert manifest["source_sha256"] == release_web.input_hashes(), "Tested inputs changed"
    assert len(release_web.SUITES) == 51
    receipts, totals = {}, {}
    for phase, total_key in [("source", "source_checks"), ("package", "packaged_checks")]:
        total = 0
        for suite, _, minimum in release_web.SUITES:
            path = EVIDENCE / "release" / f"{phase}-{suite}.json"
            result = json.loads(path.read_text())
            log = path.with_suffix(".log")
            text = log.read_text()
            marker = release_web.REVIEW_SCRIPTS.get(suite, (None, suite.upper() + "_ACCEPTANCE"))[1]
            assert completion(text, marker) == result, path.name
            assert not result.get("failures") and result["checks"] >= minimum, path.name
            assert not release_web.unexpected_engine_errors(text, suite == "coin_skins"), log.name
            receipts[path.name] = {"sha256": sha(path), "log_sha256": sha(log), "checks": result["checks"]}
            total += result["checks"]
        assert total == manifest[total_key]
        totals[total_key] = total
    assets_path = ROOT / "assets/audio/music_manifest.json"
    music = json.loads(assets_path.read_text())
    assert sha(ROOT / music["generator"]) == music["generator_sha256"]
    tracks = {}
    for track in music["tracks"]:
        assert sha(ROOT / "assets/audio" / track["file"]) == track["sha256"]
        assert all(track["checks"].values())
        tracks[track["file"]] = {"sha256": track["sha256"], "bytes": track["bytes"], "decoded": track["decoded_vorbis"]}
    audio_review_path = EVIDENCE / "review/decoded-audio.json"
    audio_review = json.loads(audio_review_path.read_text())
    assert audio_review["pass"] and len(audio_review["tracks"]) == 2
    for track in audio_review["tracks"]:
        assert track["sha256"] == tracks[track["file"]]["sha256"]
        assert track["clipped"] == 0 and track["last_to_first_step"] < .01
    maintenance_path = EVIDENCE / "review/test-maintenance-review.json"
    maintenance = json.loads(maintenance_path.read_text())
    assert maintenance["pass"] and len(maintenance["files"]) == 11
    for entry in maintenance["files"]:
        assert entry["after_sha256"] == sha(ROOT / entry["file"]), entry["file"]
        original = EVIDENCE / "test-maintenance-before" / Path(entry["file"]).name
        assert entry["before_sha256"] == sha(original), str(original)
    recorder_log = EVIDENCE / "release/device-qa-test.log"
    recorder = completion(recorder_log.read_text(), "DEVICE_QA_TEST")
    assert not recorder.get("failures") and recorder["checks"] == manifest["device_recorder_checks"]
    version = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M).group(1)
    assert version == "0.8.6"
    delivery = {}
    assert {"index.html", "index.pck", "index.wasm", "index.js", "device-qa.js"} <= set(manifest["artifacts"])
    for name, expected in manifest["artifacts"].items():
        assert sha(ROOT / "build/web" / name) == expected, name
        request = Request("http://127.0.0.1:8768/" + quote(name), headers={"Cache-Control": "no-cache"})
        with urlopen(request, timeout=30) as response:
            body = response.read()
            assert response.headers.get("Cross-Origin-Opener-Policy") == "same-origin", name
            assert response.headers.get("Cross-Origin-Embedder-Policy") == "require-corp", name
        actual = hashlib.sha256(body).hexdigest()
        assert actual == expected, name
        delivery[name] = {"sha256": actual, "bytes": len(body)}
        if name == "index.html":
            metadata = json.loads(re.search(r"window.SINK_QA_BUILD = (\{[^\n]*\});", body.decode()).group(1))
            assert metadata["version"] == version
            for key, asset in [("pck_sha256", "index.pck"), ("wasm_sha256", "index.wasm"), ("recorder_sha256", "device-qa.js")]:
                assert metadata[key] == manifest["artifacts"][asset]
    assert manifest["source_sha256"] == release_web.input_hashes()
    assert sha(manifest_path) == manifest_sha
    return dict(version=version, failures=[], verified_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                **totals, suites_per_phase=len(release_web.SUITES), device_recorder_checks=recorder["checks"],
                release_sha256=manifest_sha, verifier_sha256=sha(Path(__file__)), music_manifest_sha256=sha(assets_path),
                independent_audio_review_sha256=sha(audio_review_path),
                independent_test_maintenance_review_sha256=sha(maintenance_path),
                tracks=tracks, receipts=receipts, http_artifacts=delivery,
                scope="Native headless scene/input/audio-state checks and static HTTP delivery; decoded waveform measurements. Browser listening, speaker output, subjective mix and iPhone performance are not certified.")


if __name__ == "__main__":
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    for filename in ["verification.json", "verification-failure.json"]:
        previous = EVIDENCE / filename
        if previous.exists(): previous.rename(previous.with_name(previous.stem + "-" + stamp + ".json"))
    try:
        result = verify()
    except Exception as error:
        (EVIDENCE / "verification-failure.json").write_text(json.dumps({"failure": str(error), "at": stamp}, indent=2) + "\n")
        raise
    (EVIDENCE / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["version", "failures", "source_checks", "packaged_checks", "suites_per_phase"]}))
