"""Independent temporary-fixture verifier checks. No Godot or network calls."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import statistics
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "artifacts/audit-fixes-20260928/verify_delivery.py"
spec = importlib.util.spec_from_file_location("delivery_under_review", SOURCE)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)
checked_hash = verifier.sha(SOURCE)
CASES = []


def put_json(path, value):
    path.write_text(json.dumps(value) + "\n")


class Fixture:
    def __init__(self, root):
        self.root = root
        self.evidence = root / "artifacts/audit-fixes-20260928"
        self.release = self.evidence / "release"
        self.cpu = self.evidence / "cpu-final"
        self.web = root / "build/web"
        for d in [self.release, self.cpu, self.web, root / "tools", root / "tests"]:
            d.mkdir(parents=True)
        (root / "project.godot").write_text('config/version="0.8.1"\n')
        (root / "tools/release_web.py").write_text('''from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[1]
SUITES=[("fixture", [], 2)]
REVIEW_SCRIPTS={}
def input_hashes():
 return {"project.godot":hashlib.sha256((ROOT/"project.godot").read_bytes()).hexdigest()}
def unexpected_engine_errors(log, allow_fixture_parse=False):
 return [line for line in log.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "SHADER ERROR:", "FATAL:"))]
''')
        for name in ["tests/mobile_profile.gd", "tools/profile_maps.py", "artifacts/audit-fixes-20260928/verify_delivery.py", "artifacts/audit-fixes-20260928/profile_final.py"]:
            (root / name).write_text("fixture input\n")
        self.engine = root / "fixture-godot"
        self.engine.write_bytes(b"not an executable; fixture hash only")
        for name, data in {"index.pck": b"fixture pck", "index.wasm": b"fixture wasm", "device-qa.js": b"fixture recorder", "index.js": b"fixture js"}.items():
            (self.web / name).write_bytes(data)
        self.metadata = {"version": "0.8.1", **{field: verifier.sha(self.web / name) for field, name in [("pck_sha256", "index.pck"), ("wasm_sha256", "index.wasm"), ("recorder_sha256", "device-qa.js")]}}
        (self.web / "index.html").write_text("window.SINK_QA_BUILD = " + json.dumps(self.metadata) + ";\n")
        good = {"checks": 2, "failures": []}
        for phase in ["source", "package"]:
            put_json(self.release / f"{phase}-fixture.json", good)
            (self.release / f"{phase}-fixture.log").write_text("FIXTURE_ACCEPTANCE " + json.dumps(good) + "\n")
        (self.release / "device-qa-test.log").write_text('DEVICE_QA_TEST {"checks": 3}\n')
        self.release_data = {"failures": [], "source_sha256": {"project.godot": verifier.sha(root / "project.godot")}, "source_checks": 2, "packaged_checks": 2, "device_recorder_checks": 3, "artifacts": {p.name: verifier.sha(p) for p in self.web.iterdir()}}
        self.save_release()
        self.names = [f"{m}-{s}-{i}" for i in range(1, 4) for m in ["city", "food"] for s in ["opening", "grown"]] + ["food-rain-soak"]
        frames = [i / 100 + 1 for i in range(600)]
        self.rows = {}
        for name in self.names:
            row = {"map": name.split("-")[0], "scenario": "rain_soak" if name == "food-rain-soak" else name.split("-")[1], "version": "0.8.1", "headless": True, "physics_hz": 60, "phase": "playing", "samples": 600, "frame_times_ms": frames.copy(), "over_16_67_ms": 0, "nodes": 10, "simulation_seconds": 240 if name == "food-rain-soak" else 11, "retained_rain": 100}
            for key, q in [("p50_ms", .5), ("p95_ms", .95), ("p99_ms", .99), ("worst_ms", 1)]:
                row[key] = frames[min(599, int(600*q))]
            self.rows[name] = row
            self.write_row(name)
            (self.cpu / (name + ".engine.log")).write_text("fixture engine log\n")
        summary = {}
        for name in ["city-opening", "city-grown", "food-opening", "food-grown"]:
            row = self.rows[name + "-1"]
            summary[name] = {key: row[key] for key in ["p50_ms", "p95_ms", "p99_ms", "worst_ms", "nodes"]}
            summary[name].update(samples=1800, over_16_67_ms=0, native_contact_diagnostics=0)
        self.summary = {"repeats": 3, "summary": summary, "source_sha256": self.release_data["source_sha256"]}
        put_json(self.cpu / "summary.json", self.summary)
        inputs = dict(self.release_data["source_sha256"])
        for name in ["tests/mobile_profile.gd", "tools/profile_maps.py", "artifacts/audit-fixes-20260928/verify_delivery.py", "artifacts/audit-fixes-20260928/profile_final.py"]:
            inputs[name] = verifier.sha(root / name)
        self.provenance = {"before": inputs, "after": dict(inputs), "godot_path": str(self.engine), "godot_sha256": verifier.sha(self.engine), "raw_sha256": {}}
        self.rebind_raw()
        self.bad_header = False
        self.bad_bytes = False
        self.redirect = False

    def save_release(self):
        put_json(self.release / "release.json", self.release_data)

    def write_row(self, name):
        put_json(self.cpu / (name + ".json"), self.rows[name])
        (self.cpu / (name + ".log")).write_text("MOBILE_PROFILE " + json.dumps(self.rows[name]) + "\n")

    def rebind_raw(self):
        self.provenance["raw_sha256"] = {p.name: verifier.sha(p) for p in self.cpu.iterdir() if p.is_file() and p.name != "provenance.json"}
        put_json(self.cpu / "provenance.json", self.provenance)

    def urlopen(self, url, timeout):
        fixture = self
        name = url.rsplit("/", 1)[1]
        class Response(io.BytesIO):
            status = 200
            headers = {"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp", "Cache-Control": "public" if fixture.bad_header else "no-store", "Content-Type": "application/wasm" if name == "index.wasm" else "application/octet-stream"}
            def geturl(self):
                return "http://example.invalid/redirect" if fixture.redirect else url
        return Response(b"wrong bytes" if self.bad_bytes else (self.web / name).read_bytes())

    def run(self):
        verifier.ROOT = self.root
        verifier.urlopen = self.urlopen
        original = sys.argv
        try:
            sys.argv = [str(SOURCE), "--cpu", str(self.cpu)]
            with contextlib.redirect_stdout(io.StringIO()):
                verifier.main()
        finally:
            sys.argv = original
        return json.loads((self.evidence / "verification.json").read_text())


def case(name, edit=None, reject=True):
    with tempfile.TemporaryDirectory(prefix="hole-delivery-review-") as directory:
        fixture = Fixture(Path(directory).resolve())
        if edit:
            edit(fixture)
        try:
            result = fixture.run()
        except (AssertionError, ValueError, KeyError) as error:
            assert reject, (name, repr(error))
            CASES.append({"case": name, "result": "rejected", "error_type": type(error).__name__})
        else:
            assert not reject, "Unexpectedly accepted: " + name
            assert result["cpu_frames"] == 7800
            CASES.append({"case": name, "result": "accepted"})


def change_row(fixture, field, value, name="city-opening-1"):
    fixture.rows[name][field] = value
    fixture.write_row(name)
    fixture.rebind_raw()


case("complete valid evidence", reject=False)
case("empty source acceptance log", lambda f: (f.release / "source-fixture.log").write_text(""))
case("mismatched acceptance completion", lambda f: (f.release / "package-fixture.log").write_text('FIXTURE_ACCEPTANCE {"checks": 3, "failures": []}\n'))
case("extra stale served file", lambda f: (f.web / "old.pck").write_bytes(b"stale"))
case("wrong recorder completion count", lambda f: (f.release / "device-qa-test.log").write_text('DEVICE_QA_TEST {"checks": 2}\n'))
case("wrong HTTP cache header", lambda f: setattr(f, "bad_header", True))
case("wrong served bytes", lambda f: setattr(f, "bad_bytes", True))
case("profile helper changed after measurements", lambda f: (f.root / "tests/mobile_profile.gd").write_text("changed"))
case("engine changed after measurements", lambda f: f.engine.write_bytes(b"changed"))
case("raw data corruption", lambda f: (f.cpu / "city-opening-1.json").write_text("{}"))
case("wrong raw scenario with matching logs and hashes", lambda f: change_row(f, "scenario", "grown"))
case("wrong percentile with matching logs and hashes", lambda f: change_row(f, "p95_ms", 1))
case("wrong sample count with matching logs and hashes", lambda f: change_row(f, "samples", 599))
case("wrong version with matching logs and hashes", lambda f: change_row(f, "version", "old"))
case("insufficient soak duration", lambda f: change_row(f, "simulation_seconds", 230, "food-rain-soak"))
case("insufficient retained food rain", lambda f: change_row(f, "retained_rain", 0, "food-rain-soak"))
def wrong_summary(f):
    f.summary["summary"]["city-opening"]["p95_ms"] += 1
    put_json(f.cpu / "summary.json", f.summary)
    f.rebind_raw()
case("wrong aggregate with matching raw hash", wrong_summary)
def engine_error(f):
    p = f.cpu / "city-opening-1.log"
    p.write_text(p.read_text() + "ERROR: fixture\n")
    f.rebind_raw()
case("engine error after valid completion", engine_error)
def missing_raw(f):
    del f.provenance["raw_sha256"]["city-opening-1.engine.log"]
    put_json(f.cpu / "provenance.json", f.provenance)
case("missing raw evidence manifest member", missing_raw)
# The verifier may now explicitly reject redirects; detect whether it does.
with tempfile.TemporaryDirectory(prefix="hole-delivery-review-") as directory:
    f = Fixture(Path(directory).resolve()); f.redirect = True
    try:
        f.run()
    except AssertionError:
        CASES.append({"case": "HTTP redirect", "result": "rejected"})
    else:
        CASES.append({"case": "HTTP redirect", "result": "accepted; documented limit"})
assert verifier.sha(SOURCE) == checked_hash, "Verifier changed during fixture review"
result = {"scope": "Python fixtures only; no Godot, network, real release or CPU execution", "verifier_sha256": checked_hash, "cases": CASES}
output = Path(__file__).with_name("mock_verifier.json")
output.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"cases": len(CASES), "verifier_sha256": checked_hash, "output": str(output)}, indent=2))
