"""Offline boundary tests for the Tripo house trial CLI (2026-09-16).

These tests never read the real key file and never touch the network: they inject a fake transport
and redirect the CLI's private state into a temporary directory. Run with:

  python -X utf8 tools/test_tripo_houses_trial.py
"""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import tripo_houses_trial as trial  # noqa: E402

FAKE_KEY = "test-only-not-a-real-key-0000000000000000000000"


def glb_bytes(payload=b""):
    import struct
    body = payload or b"\x00" * 8
    total = 12 + len(body)
    return b"glTF" + struct.pack("<II", 2, total) + body


class FakeTransport:
    """Offline stand-in for HttpTransport with call counting."""

    instances = []

    def __init__(self, base_url, key, balance=150.0, post=None, task=None, download_bytes=None):
        self.base_url = base_url
        self.key = key
        self.balance = balance
        self.posts = []
        self.gets = []
        self._post = post
        self._task = task
        self._download = download_bytes
        FakeTransport.instances.append(self)

    def get_json(self, path):
        self.gets.append(path)
        if path == "/account/balance":
            return {"code": 0, "data": {"balance": self.balance, "frozen": 0.0}}
        if path.startswith("/tasks/"):
            if self._task is None:
                raise trial.TripoError("network_error", "no task configured")
            return self._task(path)
        raise AssertionError("unexpected GET %s" % path)

    def post_json(self, path, payload):
        self.posts.append(payload)
        if self._post is None:
            raise trial.TripoError("network_error", "injected transport failure")
        if isinstance(self._post, trial.TripoError):
            raise self._post
        return self._post

    def download(self, url, destination, max_bytes=trial.GLB_MAX_BYTES):
        if self._download is None:
            raise trial.TripoError("download_failed", "no download configured")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(self._download)
        validation = trial.validate_glb(destination)
        if not validation["ok"]:
            destination.unlink()
            raise trial.TripoError("invalid_glb", "rejected downloaded model: %s" % validation["reason"])
        return validation


class TripoTrialTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tripo-trial-fixture-")
        self.root = Path(self.temporary.name)
        self.saved = {name: getattr(trial, name) for name in
                      ("TMP_DIR", "STATE_PATH", "RAW_DIR", "EXPORT_DIR", "MODEL_DIR")}
        trial.TMP_DIR = self.root / "tmp"
        trial.STATE_PATH = trial.TMP_DIR / "tasks.json"
        trial.RAW_DIR = trial.TMP_DIR / "raw"
        trial.EXPORT_DIR = self.root / "exports"
        trial.MODEL_DIR = trial.EXPORT_DIR / "models"
        FakeTransport.instances = []

    def tearDown(self):
        for name, value in self.saved.items():
            setattr(trial, name, value)
        self.temporary.cleanup()

    def run_cli(self, argv, factory=FakeTransport):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = trial.main(argv, transport_factory=factory)
        return code, buffer.getvalue()

    def state(self):
        return json.loads(trial.STATE_PATH.read_text(encoding="utf-8"))

    def test_dry_run_emits_five_valid_jobs_without_key_or_network(self):
        def forbidden(*_args, **_kwargs):
            raise AssertionError("dry-run must not read the key or open a transport")

        code, output = self.run_cli(["dry-run"], factory=forbidden)
        self.assertEqual(code, 0)
        payload = json.loads(output)
        self.assertEqual(payload["jobs"], 5)
        self.assertEqual(payload["planned_credits"], 150)
        self.assertEqual(payload["maximum_creations"], 5)
        self.assertFalse(payload["key_read"])
        self.assertEqual(payload["network_calls"], 0)
        self.assertEqual(len(payload["houses"]), 5)
        plan = json.loads((trial.TMP_DIR / "jobs-plan.json").read_text(encoding="utf-8"))
        self.assertEqual(len(plan["jobs"]), 5)
        for job in plan["jobs"]:
            request = job["request"]
            self.assertEqual(request["model"], "v3.1-20260211")
            self.assertTrue(request["texture"] and request["pbr"])
            self.assertEqual(request["texture_quality"], "detailed")
            self.assertEqual(request["geometry_quality"], "standard")
            self.assertEqual(request["face_limit"], 80000)
            for banned in ("quad", "smart_low_poly", "generate_parts", "compress", "auto_size"):
                self.assertNotIn(banned, request)

    def test_uncertain_post_is_never_retried_and_duplicate_post_is_blocked(self):
        failing = lambda base, key: FakeTransport(base, key, post=None)
        code, output = self.run_cli(["submit", "--key-file", str(self._key_file())], factory=failing)
        self.assertEqual(code, 0)
        first = json.loads(output)
        self.assertEqual(sum(1 for item in first["results"] if item["action"] == "post_failed_no_retry"), 5)
        state = self.state()
        for house in state["houses"].values():
            self.assertEqual(house["state"], "uncertain")
            self.assertEqual(house["post_attempts"], 1)
            self.assertIsNone(house["task_id"])
        self.assertEqual(len(FakeTransport.instances[0].posts), 5)
        # restart: no new POST is allowed for any house
        code, output = self.run_cli(["submit", "--key-file", str(self._key_file())], factory=failing)
        second = json.loads(output)
        self.assertEqual(code, 0)
        self.assertEqual(second["post_attempts_this_run"], 0)
        self.assertTrue(all(item["action"] == "refused_repeat_post" for item in second["results"]))
        self.assertEqual(len(FakeTransport.instances[1].posts), 0)

    def test_successful_post_persists_task_id_and_is_kept_on_restart(self):
        ok = lambda base, key: FakeTransport(base, key, post={"code": 0, "data": {"task_id": "task-abc"}})
        code, output = self.run_cli(["submit", "--key-file", str(self._key_file())], factory=ok)
        self.assertEqual(code, 0)
        state = self.state()
        for house in state["houses"].values():
            self.assertEqual(house["task_id"], "task-abc")
            self.assertEqual(house["state"], "submitted")
            self.assertEqual(house["post_attempts"], 1)
        code, output = self.run_cli(["submit", "--key-file", str(self._key_file())], factory=ok)
        kept = json.loads(output)
        self.assertTrue(all(item["action"] == "kept_existing_task" for item in kept["results"]))
        self.assertEqual(len(FakeTransport.instances[1].posts), 0)

    def test_low_balance_stops_before_any_post(self):
        poor = lambda base, key: FakeTransport(base, key, balance=29.0)
        code, output = self.run_cli(["submit", "--key-file", str(self._key_file())], factory=poor)
        self.assertEqual(code, 4)
        payload = json.loads(output)
        self.assertEqual(payload["result"], "stopped_insufficient_balance")
        self.assertEqual(payload["post_attempts_this_run"], 0)
        self.assertEqual(len(FakeTransport.instances[0].posts), 0)
        self.assertEqual(self.state()["houses"]["01_woodland_cottage"]["post_attempts"], 0)

    def test_invalid_glb_is_rejected_and_no_file_is_kept(self):
        cases = {"wrong_magic": b"NOPE" + b"\x00" * 20, "too_short": b"glTF",
                 "bad_length": b"glTF" + (2).to_bytes(4, "little") + (999).to_bytes(4, "little")}
        for name, payload in cases.items():
            path = self.root / (name + ".glb")
            path.write_bytes(payload)
            self.assertFalse(trial.validate_glb(path)["ok"], name)
        good = self.root / "good.glb"
        good.write_bytes(glb_bytes())
        self.assertTrue(trial.validate_glb(good)["ok"])
        transport = FakeTransport("http://localhost", FAKE_KEY, download_bytes=b"not-a-glb")
        with self.assertRaises(trial.TripoError) as raised:
            transport.download("https://example.invalid/model.glb", self.root / "out" / "x.glb")
        self.assertEqual(raised.exception.kind, "invalid_glb")
        self.assertFalse((self.root / "out" / "x.glb").exists())

    def test_key_never_appears_in_logged_output_or_state(self):
        key_file = self._key_file()
        ok = lambda base, key: FakeTransport(base, key, post={"code": 0, "data": {"task_id": "task-key"}})
        code, output = self.run_cli(["submit", "--key-file", str(key_file)], factory=ok)
        self.assertEqual(code, 0)
        self.assertNotIn(FAKE_KEY, output)
        self.assertNotIn("Authorization", output)
        self.assertNotIn(FAKE_KEY, trial.STATE_PATH.read_text(encoding="utf-8"))
        leaked = trial.TripoError("network_error", "transport failed with %s in the message" % FAKE_KEY)
        failing = lambda base, key: FakeTransport(base, key, task=lambda path: (_ for _ in ()).throw(leaked))
        code, output = self.run_cli(["resume", "--deadline", "1", "--key-file", str(key_file)], factory=failing)
        self.assertNotIn(FAKE_KEY, output)
        self.assertNotIn(FAKE_KEY, trial.STATE_PATH.read_text(encoding="utf-8"))
        self.assertIn("poll_failed_kept_task", output)
        # An uncaught provider failure must also be reported through the sanitized error path.
        def exploding(base, key):
            raise leaked
        code, output = self.run_cli(["balance", "--key-file", str(key_file)], factory=exploding)
        self.assertEqual(code, 5)
        self.assertNotIn(FAKE_KEY, output)
        self.assertIn("network_error", output)

    def _key_file(self):
        path = self.root / "fake-key.txt"
        if not path.exists():
            path.write_text(FAKE_KEY + "\n", encoding="utf-8")
        return path


if __name__ == "__main__":
    unittest.main(verbosity=2)
