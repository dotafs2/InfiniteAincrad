import io
import json
import os
from pathlib import Path
import subprocess
from types import SimpleNamespace
import tempfile
import unittest

import start_user_living_session as bootstrap
from kimi_budget import Ledger, Policy


class TtyInput(io.StringIO):
    def isatty(self):
        return True


class UserLivingBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.save = self.root / "world.json"
        self.godot = self.root / "godot.exe"
        self.config = self.root / "config.json"
        self.sessions = self.root / "sessions"
        self.prior = self.root / "prior.sqlite3"
        self.save.write_text("{}", encoding="utf-8")
        self.godot.write_bytes(b"test")
        self.config.write_text(json.dumps({
            "base_url": "https://api.moonshot.cn/v1",
            "model": "kimi-k2.6",
            "thinking_mode": "disabled",
            "api_key": "test-key",
        }), encoding="utf-8")
        self.prior_session = Ledger(self.prior, Policy())
        self.prior_session.initialize()
        self.profile = self.root / "profile.json"
        self.profile.write_text(json.dumps({
            "save_path": str(self.save),
            "godot": str(self.godot),
            "config": str(self.config),
            "sessions_root": str(self.sessions),
            "prior_paid_session_records": [str(self.prior)],
        }), encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def test_unconfirmed_creates_no_new_record(self):
        output = io.StringIO()
        result = bootstrap.launch(self.profile, TtyInput("no\n"), output)
        self.assertEqual(result, 0)
        self.assertFalse(self.sessions.exists())
        self.assertIn("没有创建", output.getvalue())
        self.assertNotIn("ledger", output.getvalue().lower())

    def test_noninteractive_confirmation_is_rejected(self):
        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, io.StringIO("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_unknown_prior_record_is_rejected(self):
        self.prior.with_suffix(".guard.json").unlink()
        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_reserved_prior_request_is_rejected(self):
        self.prior_session.reserve("still-running", "resident", self._request())
        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_uncertain_prior_request_is_rejected(self):
        self.prior_session.reserve("unknown-result", "resident", self._request())
        self.prior_session.uncertain("unknown-result")
        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_halted_prior_session_is_rejected(self):
        with self.prior_session.transaction() as (db, _meta):
            db.execute("UPDATE meta SET halted='review required' WHERE id=1")
        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_active_world_writer_is_rejected_before_new_record(self):
        Path(str(self.save) + ".writer-lock").mkdir()
        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_clean_first_use_hands_off_fixed_limits(self):
        calls = []

        def no_op(command, **kwargs):
            calls.append((command, kwargs))
            return SimpleNamespace(returncode=0)

        output = io.StringIO()
        now = bootstrap.datetime(2026, 9, 18, 1, 0, 0, tzinfo=bootstrap.timezone.utc)
        result = bootstrap.launch(
            self.profile, TtyInput("START AI\n"), output, no_op, lambda: now)
        self.assertEqual(result, 0)
        self.assertEqual(len(calls), 1)
        command = calls[0][0]
        self.assertEqual(command[command.index("--seconds") + 1], "900")
        self.assertEqual(command[command.index("--max-requests") + 1], "32")
        self.assertEqual(command[command.index("--concurrency") + 1], "1")
        records = list(self.sessions.rglob("kimi-user-session.sqlite3"))
        self.assertEqual(len(records), 1)
        guard = json.loads(records[0].with_suffix(".guard.json").read_text(encoding="utf-8"))
        self.assertEqual(guard["policy"]["authorized_nano"], 3_000_000_000)
        self.assertEqual(guard["policy"]["allocatable_nano"], 2_850_000_000)
        self.assertEqual(guard["policy"]["request_limit"], 32)
        self.assertEqual(guard["policy"]["deadline_utc"], int(now.timestamp()) + 1020)
        self.assertEqual(
            guard["policy"]["price_verified"],
            "2026-09-18 https://platform.kimi.com/ K2.6 China")
        manifest = json.loads(next(self.sessions.rglob("session.json")).read_text(encoding="utf-8"))
        self.assertEqual(manifest["status"], "complete")
        self.assertEqual(manifest["cumulative_settled_before_cny"], 0.0)
        self.assertFalse((self.sessions / ".start-living-ai.lock").exists())
        self.assertIn("本地费用估算：0.000000 元", output.getvalue())
        self.assertIn("以供应商账单为准", output.getvalue())

    @unittest.skipUnless(os.name == "nt" and Path(r"C:\Program Files\dotnet\dotnet.exe").is_file(),
                         "Windows .NET host inheritance check")
    def test_cmd_child_inherits_local_dotnet_runtime_settings(self):
        shim_dir = self.root / "shim"
        shim_dir.mkdir()
        (shim_dir / "python.cmd").write_text(
            "@echo off\n"
            "echo DOTNET_ROOT=%DOTNET_ROOT%\n"
            "echo DOTNET_ROOT_X64=%DOTNET_ROOT_X64%\n"
            "echo DOTNET_ROLL_FORWARD=%DOTNET_ROLL_FORWARD%\n"
            "exit /b 0\n", encoding="utf-8")
        environment = dict(os.environ)
        for key in ("DOTNET_ROOT", "DOTNET_ROOT_X64", "DOTNET_ROLL_FORWARD"):
            environment.pop(key, None)
        environment["PATH"] = str(shim_dir) + os.pathsep + environment["PATH"]
        result = subprocess.run(
            ["cmd.exe", "/d", "/c", str(bootstrap.ROOT / "StartLivingAI.cmd")],
            cwd=bootstrap.ROOT, env=environment, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(r"DOTNET_ROOT=C:\Program Files\dotnet", result.stdout)
        self.assertIn(r"DOTNET_ROOT_X64=C:\Program Files\dotnet", result.stdout)
        self.assertIn("DOTNET_ROLL_FORWARD=LatestMajor", result.stdout)

    @staticmethod
    def _request():
        return {
            "model": "kimi-k2.6",
            "messages": [{"role": "user", "content": "test"}],
            "stream": False,
            "max_tokens": 1,
            "thinking": {"type": "disabled"},
            "response_format": {"type": "json_object"},
        }


if __name__ == "__main__":
    unittest.main()
