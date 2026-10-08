"""Archive only the final, hash-verified Web distributable, never source/evidence."""
from pathlib import Path
import hashlib
import datetime
import importlib.util
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RELEASE = ROOT / "artifacts/shop-theme-20260930/release/release.json"
VERIFY = ROOT / "artifacts/shop-theme-20260930/verification.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    destination = HERE / "SinkCity-v0.11.1-web-playtest.zip"
    old_paths = [destination, destination.with_suffix(".zip.sha256"), HERE / "web-bundle.json", destination.with_suffix(".zip.tmp")]
    if any(path.exists() for path in old_paths):
        prior = HERE / "previous-web-bundles" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        prior.mkdir(parents=True)
        for path in old_paths:
            if path.exists():
                path.rename(prior / path.name)
    spec = importlib.util.spec_from_file_location("delivery_verifier", VERIFY.with_name("verify_delivery.py"))
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    release_hash, verification_hash = sha(RELEASE.read_bytes()), sha(VERIFY.read_bytes())
    manifest = json.loads(RELEASE.read_text())
    verification = json.loads(VERIFY.read_text())
    assert not manifest["failures"] and verification["version"] == "0.11.1"
    assert verification["release_manifest_sha256"] == release_hash
    assert verification["verifier_sha256"] == sha(VERIFY.with_name("verify_delivery.py").read_bytes())
    verifier.gate.verify_inputs(manifest["source_sha256"])
    expected = manifest["artifacts"]
    assert set(expected) == verifier.EXPECTED_FILES
    assert {row["file"]: row["sha256"] for row in verification["served_artifacts"]} == expected
    source = ROOT / "build/web"
    assert not source.is_symlink() and not any(path.is_symlink() for path in source.rglob("*"))
    actual_names = {str(p.relative_to(source)) for p in source.rglob("*") if p.is_file()}
    assert actual_names == set(expected), "Unexpected or missing public files"
    temporary = destination.with_suffix(".zip.tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, digest in sorted(expected.items()):
                path = Path(name)
                assert not path.is_absolute() and ".." not in path.parts
                data = (source / name).read_bytes()
                assert sha(data) == digest, name
                item = zipfile.ZipInfo(name, (2026, 9, 30, 0, 0, 0))
                item.compress_type = zipfile.ZIP_DEFLATED
                item.external_attr = 0o100644 << 16
                archive.writestr(item, data, compresslevel=9)
        with zipfile.ZipFile(temporary) as archive:
            assert set(archive.namelist()) == set(expected)
            assert archive.testzip() is None
            for name, digest in expected.items():
                assert sha(archive.read(name)) == digest, name
        verifier.gate.verify_inputs(manifest["source_sha256"])
        assert release_hash == sha(RELEASE.read_bytes()) and verification_hash == sha(VERIFY.read_bytes())
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    receipt = {"version": "0.11.1", "archive": destination.name,
               "archive_sha256": sha(destination.read_bytes()), "bytes": destination.stat().st_size,
               "files": len(expected), "uncompressed_bytes": sum((source / name).stat().st_size for name in expected),
               "release_manifest_sha256": release_hash, "verification_sha256": verification_hash,
               "scope": "Verified local Web playtest bundle; no external publication or real-device approval."}
    (HERE / "web-bundle.json").write_text(json.dumps(receipt, indent=2) + "\n")
    destination.with_suffix(".zip.sha256").write_text(receipt["archive_sha256"] + "  " + destination.name + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
