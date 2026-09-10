"""Isolated loopback contract tests. No Kimi key, real ledger or paid upstream.

Uses the existing bounded Godot runner; mock server lifetime is this process.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import uuid

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def gateway(scenario):
    calls = {"get": 0, "post": 0, "contract_errors": []}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, status, value):
            payload = json.dumps(value).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def budget(self):
            return {"ledger_id": "fixture-ledger", "halted": "", "remaining_allocatable_cny": 0 if scenario == "insufficient" else 10,
                    "allocation_cap_cny": 10, "reserved_cny": 0, "settled_cny": 0}

        def auth(self):
            if self.headers.get("Authorization") != "Bearer local-fixture-token":
                calls["contract_errors"].append("auth")
                self.reply(401, {"error": "fixture auth"})
                return False
            return True

        def do_GET(self):
            calls["get"] += 1
            if not self.auth():
                return
            if self.path != "/budget":
                calls["contract_errors"].append("GET route")
                return self.reply(404, {})
            value = self.budget()
            if scenario == "wrong-ledger":
                value["ledger_id"] = "different-ledger"
            self.reply(200, value)

        def do_POST(self):
            calls["post"] += 1
            if not self.auth():
                return
            try:
                assert self.path == "/v1/chat/completions"
                uuid.UUID(self.headers["X-Hearth-Operation"])
                assert self.headers["X-Hearth-Resident"] == "fixture:luna"
                size = int(self.headers["Content-Length"])
                assert 0 < size <= 32768
                body = json.loads(self.rfile.read(size))
                assert set(body) == {"model", "messages", "stream", "max_tokens", "thinking", "response_format"}
                assert body["model"] == "kimi-k2.6" and body["stream"] is False and body["max_tokens"] == 512
                assert body["thinking"] == {"type": "disabled"}
                assert body["response_format"] == {"type": "json_object"}
                assert len(body["messages"]) == 2
                observation = body["messages"][-1]["content"]
                assert "available_actions" in observation
                assert all(key not in observation for key in ["gm_resources", "gm_budget", "command_payloads"])
            except Exception:
                calls["contract_errors"].append("POST contract")
                return self.reply(400, {"error": "fixture contract"})
            if scenario == "uncertain":
                return self.reply(502, {"error": "fixture unknown upstream outcome"})
            self.reply(200, {"model": "kimi-k2.6", "choices": [{"message": {"role": "assistant", "content":
                json.dumps({"action": "wait", "reason": "I choose to wait."})}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 120, "completion_tokens": 15, "total_tokens": 135,
                          "prompt_tokens_details": {"cached_tokens": 30}}, "_hearth_budget": self.budget()})

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server.server_port, calls
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    cases = []
    for scenario in ["success", "insufficient", "wrong-ledger", "expired", "unsafe-endpoint", "uncertain"]:
        folder = args.out / scenario
        folder.mkdir(exist_ok=False)  # Never reset an earlier run journal to get new capacity.
        with gateway(scenario) as (port, calls):
            endpoint = folder / "endpoint.json"
            endpoint.write_text(json.dumps({"base_url": f"http://127.0.0.1:{port}/v1", "api_key": "local-fixture-token",
                "model": "kimi-k2.6", "ledger_id": "fixture-ledger"}))
            if scenario == "unsafe-endpoint":
                endpoint.write_text(json.dumps({"base_url": "https://example.invalid/v1", "api_key": "local-fixture-token",
                    "model": "kimi-k2.6", "ledger_id": "fixture-ledger"}))
            config = folder / "run.json"
            config.write_text(json.dumps({"schema_version": 1, "endpoint_path": str(endpoint.resolve()),
                "expected_ledger_id": "fixture-ledger", "run_state_path": str((folder / "state.json").resolve()),
                "deadline_utc": (datetime.now(timezone.utc) + timedelta(seconds=-1 if scenario == "expired" else 180)).isoformat(),
                "max_requests": 1, "external_liability_cny": 0, "provenance": "opengameagent_fixture"}))
            repeats = 2 if scenario in ("success", "uncertain") else 1
            for index in range(repeats):
                label = f"{scenario}-{index}"
                env = dict(os.environ, AINCRAD_GATEWAY_RUN_CONFIG=str(config.resolve()),
                           AINCRAD_GATEWAY_TEST_EXPECT="success" if scenario == "success" and index == 0 else "rejected")
                command = [sys.executable, str(ROOT / "tools/run_godot.py"), "--godot", args.godot, "--name", label,
                           "--timeout", "42", "--out", str(args.out / "runs"), "--", "--headless", "--script", "res://tests/gateway_acceptance.gd"]
                result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=50)
                (folder / f"{index}.runner.log").write_text(result.stdout + result.stderr, encoding="utf-8")
                expected_posts = 1 if scenario in ("success", "uncertain") else 0
                passed = result.returncode == 0 and calls["post"] == expected_posts and not calls["contract_errors"]
                row = {"case": label, "passed": passed, **calls}
                cases.append(row)
                print(json.dumps(row), flush=True)
                if not passed:
                    print(result.stdout[-2500:], result.stderr[-1000:])
                    (args.out / "evidence.json").write_text(json.dumps(cases, indent=2))
                    return 1
    (args.out / "evidence.json").write_text(json.dumps(cases, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
