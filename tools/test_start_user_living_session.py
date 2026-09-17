import io
from dataclasses import asdict, replace
import hashlib
import json
import os
from pathlib import Path
import subprocess
from types import SimpleNamespace
import tempfile
import unittest

import start_user_living_session as bootstrap
from kimi_budget import CityValidationPolicy, Ledger, Policy, fingerprint


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
        self.gm_status = self.root / "gm-public-status.json"
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
        self.gm_status.write_text('{"fixture":"read-only-path"}', encoding="utf-8")
        self.prior_session = Ledger(self.prior, Policy())
        self.prior_session.initialize()
        self.profile = self.root / "profile.json"
        self.profile.write_text(json.dumps({
            "save_path": str(self.save),
            "godot": str(self.godot),
            "config": str(self.config),
            "gm_status": str(self.gm_status),
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

    def test_exact_reviewed_uncertainty_is_retained_and_reported(self):
        reservation = self.prior_session.reserve("unknown-result", "resident", self._request())
        self.prior_session.uncertain("unknown-result")
        pin = self._write_pin(self.prior_session)
        self._set_review_pins([pin])

        output = io.StringIO()
        result = bootstrap.launch(
            self.profile, TtyInput("START AI\n"), output,
            lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
            lambda: bootstrap.datetime(2026, 9, 18, 1, 0, 0,
                                       tzinfo=bootstrap.timezone.utc))

        self.assertEqual(result, 0)
        retained = reservation["reserved_nano"] / 1_000_000_000
        manifest = json.loads(next(self.sessions.rglob("session.json")).read_text(encoding="utf-8"))
        self.assertEqual(manifest["retained_prior_uncertain_cny"], retained)
        self.assertEqual(manifest["prior_paid_sessions"][0]["uncertain_requests"], 1)
        self.assertEqual(
            manifest["prior_paid_sessions"][0]["uncertainty_review"]["uncertain_requests"],
            [{"id": "unknown-result", "state": "uncertain",
              "reserve_nano": reservation["reserved_nano"]}])
        self.assertIn("最大责任：%.6f 元" % retained, output.getvalue())
        self.assertIn("不会清零或重试旧请求", output.getvalue())

    def test_reviewed_expired_prior_record_is_audited_without_reopening_it(self):
        expired = self.root / "expired.sqlite3"
        expired_session = Ledger(expired, Policy(deadline_utc=1), clock=lambda: 0)
        expired_session.initialize()
        expired_session.reserve("expired-unknown", "resident", self._request())
        expired_session.uncertain("expired-unknown")
        pin = self._write_pin(expired_session)
        profile = json.loads(self.profile.read_text(encoding="utf-8"))
        profile["prior_paid_session_records"] = [str(expired)]
        profile["prior_uncertainty_review_pins"] = [str(pin)]
        self.profile.write_text(json.dumps(profile), encoding="utf-8")

        result = bootstrap.launch(
            self.profile, TtyInput("START AI\n"), io.StringIO(),
            lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
            lambda: bootstrap.datetime(2026, 9, 18, 1, 0, 0,
                                       tzinfo=bootstrap.timezone.utc))
        self.assertEqual(result, 0)

    def test_review_pin_mismatch_or_new_uncertainty_is_rejected(self):
        self.prior_session.reserve("first-unknown", "resident-a", self._request())
        self.prior_session.uncertain("first-unknown")
        pin = self._write_pin(self.prior_session)
        self.prior_session.reserve("later-unknown", "resident-b", self._request())
        self.prior_session.uncertain("later-unknown")
        self._set_review_pins([pin])

        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_exact_review_pin_never_waives_halted_prior_session(self):
        self.prior_session.reserve("unknown-result", "resident", self._request())
        self.prior_session.uncertain("unknown-result")
        pin = self._write_pin(self.prior_session)
        self._set_review_pins([pin])
        with self.prior_session.transaction() as (db, _meta):
            db.execute("UPDATE meta SET halted='arbitrary stop' WHERE id=1")

        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_exact_initialized_continuation_receipt_allows_only_reviewed_closure(self):
        continuation = self._make_continuation()
        output = io.StringIO()

        result = bootstrap.launch(
            self.profile, TtyInput("START AI\n"), output,
            lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
            lambda: bootstrap.datetime(2026, 9, 18, 1, 0, 0,
                                       tzinfo=bootstrap.timezone.utc))

        self.assertEqual(result, 0)
        manifest = json.loads(next(self.sessions.rglob("session.json")).read_text(encoding="utf-8"))
        old_entry = next(item for item in manifest["prior_paid_sessions"]
                         if item["id"] == continuation["old_id"])
        self.assertEqual(old_entry["continuation_review"]["status"], "initialized")
        self.assertEqual(old_entry["continuation_review"]["scope_tag"], "test-scope")
        self.assertEqual(
            manifest["cumulative_prior_liability_cny"],
            continuation["old_liability_nano"] / 1_000_000_000)

    def test_closed_not_initialized_continuation_is_rejected(self):
        continuation = self._make_continuation()
        receipt = json.loads(continuation["receipt"].read_text(encoding="utf-8"))
        receipt["status"] = "closed_not_initialized"
        continuation["receipt"].write_text(json.dumps(receipt), encoding="utf-8")

        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_continuation_receipt_rejects_changed_old_request_facts(self):
        continuation = self._make_continuation()
        with continuation["old"].transaction() as (db, _meta):
            db.execute("UPDATE requests SET note='changed after receipt' WHERE id='old-unknown'")

        with self.assertRaises(bootstrap.LaunchBlocked):
            bootstrap.launch(self.profile, TtyInput("START AI\n"), io.StringIO())
        self.assertFalse(self.sessions.exists())

    def test_continuation_new_unknown_still_requires_its_own_exact_pin(self):
        continuation = self._make_continuation()
        continuation["new"].reserve("new-unknown", "other-resident", self._request())
        continuation["new"].uncertain("new-unknown")

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
        self.assertTrue(Path(command[command.index("--gm-status") + 1]).samefile(self.gm_status))
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

    def test_healthy_idle_runner_is_saved_without_claiming_ai_passed(self):
        def idle_no_op(command, **_kwargs):
            run_output = Path(command[command.index("--out") + 1])
            run_output.mkdir()
            (run_output / "result.json").write_text(json.dumps({
                "idle_completed": True,
                "validation_status": "not_exercised",
                "validation_passed": False,
                "validation_exercised": False,
                "engine_exit": 0,
                "upstream_requests": 0,
                "model_errors": {},
                "budget_stop_reason": "",
                "shutdown_incomplete": False,
                "world_progress_observed": True,
                "gateway_shutdown": {"drained_complete": True, "unresolved_workers": 0},
                "startup_fault_export": {
                    "status": "not_applicable", "reason": "healthy_idle_progress"},
            }), encoding="utf-8")
            return SimpleNamespace(returncode=1)

        output = io.StringIO()
        result = bootstrap.launch(
            self.profile, TtyInput("START AI\n"), output, idle_no_op,
            lambda: bootstrap.datetime(2026, 9, 18, 1, 0, 0, tzinfo=bootstrap.timezone.utc))
        self.assertEqual(result, 0)
        manifest = json.loads(next(self.sessions.rglob("session.json")).read_text(encoding="utf-8"))
        self.assertEqual(manifest["runner_exit_code"], 1)
        self.assertEqual(manifest["status"], "not_exercised")
        self.assertTrue(manifest["idle_completed"])
        self.assertIn("本段没有新的 AI 决定，世界已保存", output.getvalue())
        self.assertIn("模型验收仍为未执行，不记作通过", output.getvalue())
        self.assertNotIn("本次运行未正常结束", output.getvalue())

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

    def _set_review_pins(self, pins):
        profile = json.loads(self.profile.read_text(encoding="utf-8"))
        profile["prior_uncertainty_review_pins"] = [str(path) for path in pins]
        self.profile.write_text(json.dumps(profile), encoding="utf-8")

    def _write_pin(self, session):
        with session.transaction() as (db, meta):
            uncertain = [
                {"id": row["id"], "state": row["state"], "reserve_nano": row["reserve"]}
                for row in db.execute(
                    "SELECT id,state,reserve FROM requests WHERE state='uncertain' ORDER BY id")
            ]
            ledger_id = meta["ledger_id"]
        pin = self.root / (session.path.stem + "-uncertainty-review.json")
        pin.write_text(json.dumps({
            "schema_version": 1,
            "ledger_id": ledger_id,
            "policy_sha256": session.policy_hash,
            "guard_sha256": hashlib.sha256(session.guard.read_bytes()).hexdigest(),
            "uncertain_requests": uncertain,
        }), encoding="utf-8")
        return pin

    def _make_continuation(self):
        old_path = self.root / "closed-old.sqlite3"
        old_policy = CityValidationPolicy(request_limit=20, concurrency=3)
        old = Ledger(old_path, old_policy)
        old.initialize()
        old.reserve("old-unknown", "resident", self._request())
        old.uncertain("old-unknown")
        pin = self._write_pin(old)
        scope = "test-scope"
        reason = "closed_for_continuation:" + scope
        with old.transaction() as (db, meta):
            rows = [dict(row) for row in db.execute("SELECT * FROM requests ORDER BY id")]
            old_id = meta["ledger_id"]
            old_liability = meta["liability"]
            old_count = meta["request_count"]
            db.execute("UPDATE meta SET halted=? WHERE id=1", (reason,))
        new_policy = replace(
            old_policy,
            prior_unverified_nano=old_liability,
            concurrency=old_policy.concurrency - 1,
            request_limit=old_policy.request_limit - old_count,
        )
        new_path = self.root / "continuation.sqlite3"
        new = Ledger(new_path, new_policy)
        new_status = new.initialize()
        receipt = self.root / "continuation-receipt.json"
        receipt.write_text(json.dumps({
            "schema_version": 1,
            "kind": "reviewed_night_continuation",
            "scope_tag": scope,
            "status": "initialized",
            "old": {
                "path": str(old_path),
                "ledger_id": old_id,
                "guard_sha256": hashlib.sha256(old.guard.read_bytes()).hexdigest(),
                "policy_sha256": old.policy_hash,
                "halted_reason": reason,
                "liability_nano": old_liability,
                "request_count": old_count,
                "requests_sha256": fingerprint(rows),
                "uncertain_requests": [{
                    "id": "old-unknown", "state": "uncertain",
                    "reserve_nano": rows[0]["reserve"],
                }],
            },
            "new": {
                "path": str(new_path),
                "ledger_id": new_status["ledger_id"],
                "guard_sha256": hashlib.sha256(new.guard.read_bytes()).hexdigest(),
                "policy_sha256": new.policy_hash,
                "policy": asdict(new_policy),
            },
        }), encoding="utf-8")
        profile = json.loads(self.profile.read_text(encoding="utf-8"))
        profile["prior_paid_session_records"] = [str(old_path), str(new_path)]
        profile["prior_uncertainty_review_pins"] = [str(pin)]
        profile["reviewed_continuation_receipts"] = [
            {"record": str(old_path), "receipt": str(receipt)}]
        self.profile.write_text(json.dumps(profile), encoding="utf-8")
        return {
            "old": old, "new": new, "receipt": receipt, "old_id": old_id,
            "old_liability_nano": old_liability,
        }


if __name__ == "__main__":
    unittest.main()
