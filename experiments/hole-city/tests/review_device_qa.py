"""Independent local release-injection review; no browser or server is used."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_under_review", ROOT / "tools/release_web.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
checks = 0
def check(ok, label):
    global checks
    checks += 1
    assert ok, label
script = '<script src="index.js"></script>'
boot = 'const engine = new Engine(GODOT_CONFIG);'
valid = '<html><body><canvas></canvas>' + script + '<script>const GODOT_CONFIG = {args: []};' + boot + '</script></body></html>'
cases = {
    "missing script": valid.replace(script, ""),
    "duplicate script": valid.replace(script, script + script),
    "missing boot": valid.replace(boot, ""),
    "duplicate boot": valid.replace(boot, boot + boot),
    "already installed script": valid.replace(script, '<script src="device-qa.js"></script>' + script),
}
with tempfile.TemporaryDirectory(prefix="hole-qa-injection-review-") as tmp:
    target = Path(tmp)
    (target / "index.pck").write_bytes(b"Independent synthetic package; never a game export.")
    (target / "index.wasm").write_bytes(b"Independent synthetic wasm placeholder.")
    page = target / "index.html"
    for name, source in cases.items():
        page.write_text(source)
        rejected = False
        try:
            release.install_device_qa(target)
        except RuntimeError:
            rejected = True
        check(rejected, name + " must reject publication")
        check(page.read_text() == source, name + " must not partially rewrite HTML")
    page.write_text(valid)
    package_before = release.digest(target / "index.pck")
    wasm_before = release.digest(target / "index.wasm")
    release.install_device_qa(target)
    installed = page.read_text()
    check(installed.count('<script src="device-qa.js"></script>') == 1, "One recorder installation")
    check(installed.index('src="device-qa.js"') < installed.index('src="index.js"'), "Recorder enables isolation before engine boot")
    check(installed.index('GODOT_CONFIG.args = ["--", "--test", "--device-qa"];') < installed.index(boot), "Isolation flags precede Engine construction")
    metadata = json.loads(re.search(r'window.SINK_QA_BUILD = (.*?);</script>', installed).group(1))
    check(metadata["pck_sha256"] == package_before and release.digest(target / "index.pck") == package_before, "Embedded package hash matches unmodified bytes")
    check(metadata["wasm_sha256"] == wasm_before and release.digest(target / "index.wasm") == wasm_before, "Embedded wasm hash matches unmodified bytes")
    check(metadata["recorder_sha256"] == release.digest(target / "device-qa.js") == release.digest(ROOT / "tools/device_qa.js"), "Recorder metadata identifies the exact copied source")
    check(release.digest(page) != hashlib.sha256(valid.encode()).hexdigest(), "Final artifact hash includes the injected HTML")
    hook = installed[installed.index("if (window.SinkDeviceQA"):installed.index(boot) + len(boot)]
    Path("/tmp/hole-device-review-bootstrap.json").write_text(json.dumps({"hook": hook, "metadata": metadata}))
print("DEVICE_INJECTION_REVIEW " + json.dumps({"checks": checks, "failures": [], "scope": "Synthetic local HTML/package fixtures; not browser or phone evidence"}))
