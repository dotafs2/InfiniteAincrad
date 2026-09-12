"""Isolated loopback contract tests. No Kimi key, real ledger or paid upstream.

Uses the existing bounded Godot runner; mock server lifetime is this process.
Scenarios cover the default kimi-k2.6 run, an explicit `expected_model` pin,
endpoint/response model mismatch, request-journal replay and view projection.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]

# Only these keys may leave the host. Anything else is private-knowledge leakage.
PROJECTED = {"identity", "observations", "needs", "experiences", "memory", "inventory", "actions",
             "available_actions", "nearby_residents", "items", "skills", "contracts", "life_account",
             "wallet", "nearby_skilled_roles", "action_details", "known_rules", "unavailable_actions"}
PROJECTED |= {"known_skill_notices", "known_skill_referrals", "material_sources", "known_places"}


@contextmanager
def gateway(scenario, capture_folder=None):
    calls = {"get": 0, "post": 0, "contract_errors": []}

    def wire_model(kind):
        # pinned-model carries the run-pinned id on both sides; reply-model-mismatch
        # keeps the request pinned but answers with a different served model.
        if scenario == "pinned-model":
            return "fixture-compat-model"
        if scenario == "reply-model-mismatch":
            return "fixture-compat-model" if kind == "request" else "kimi-k2.6"
        return "kimi-k2.6"

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
                expected_actor = ("fictional:forge" if calls["post"] == 3 else "fictional:ember") if scenario == "town-history" else "fixture:luna"
                if scenario.startswith("concurrent-"):
                    assert self.headers["X-Hearth-Resident"] in ("fictional:ember", "fictional:birch")
                else:
                    assert self.headers["X-Hearth-Resident"] == expected_actor
                size = int(self.headers["Content-Length"])
                assert 0 < size <= 32768
                body = json.loads(self.rfile.read(size))
                assert set(body) == {"model", "messages", "stream", "max_tokens", "thinking", "response_format"}
                assert body["model"] == wire_model("request") and body["stream"] is False and body["max_tokens"] == 512
                assert body["thinking"] == {"type": "disabled"}
                assert body["response_format"] == {"type": "json_object"}
                assert len(body["messages"]) == 2
                observation = body["messages"][-1]["content"]
                assert "available_actions" in observation
                assert all(key not in observation for key in ["gm_resources", "gm_budget", "command_payloads"])
                personal = json.loads(observation)
                assert set(personal) <= PROJECTED, sorted(set(personal) - PROJECTED)
                assert isinstance(personal["identity"], dict), "identity must survive projection"
                assert "hidden_neighbor_wallet" not in observation
                action = "wait"
                if scenario.startswith("concurrent-"):
                    assert personal["identity"]["id"] == self.headers["X-Hearth-Resident"]
                    action = next(entry["id"] for entry in personal["action_details"] if entry["label"] == "Wait")
                    assert action in personal["available_actions"]
                if scenario == "knowledge-bounds":
                    assert [entry["seq"] for entry in personal["known_skill_notices"]] == list(range(2, 18))
                    assert [entry["seq"] for entry in personal["known_skill_referrals"]] == list(range(2, 18))
                    assert [entry["observation_event_seq"] for entry in personal["material_sources"]] == list(range(1, 9))
                    assert "nested_gm_secret" not in observation
                    assert len((body["messages"][0]["content"] + observation).encode("utf-8")) <= 24576
                if scenario == "town-history":
                    assert personal["identity"]["id"] == expected_actor
                    assert all(secret not in observation for secret in ["gm_install_secret", "neighbor_private_secret", "nested_gm_secret", "nested_neighbor_secret", "gm_internal", "other_resident_private", "development_gm:"])
                    assert "not proof of current skills, availability or stock" in body["messages"][0]["content"]
                    assert "known_places is your own sourced knowledge" in body["messages"][0]["content"]
                    if expected_actor == "fictional:ember":
                        recent = personal["experiences"]
                        assert len(recent) == 16 and all(event["type"] in ("ask_help", "cancel_help") for event in recent)
                        notices = personal["known_skill_notices"]
                        referrals = personal["known_skill_referrals"]
                        materials = personal["material_sources"]
                        assert len(notices) == len(referrals) == len(materials) == 1
                        assert notices[0]["actor_id"] == "fictional:birch" and notices[0]["skill_id"] == "wood_repair"
                        assert referrals[0]["referrer_id"] == "fictional:birch" and referrals[0]["referred_resident_id"] == "fictional:forge" and referrals[0]["skill_id"] == "metal_repair"
                        assert referrals[0]["source_seq"] < referrals[0]["seq"] < recent[0]["seq"]
                        assert notices[0]["seq"] < recent[0]["seq"] and materials[0]["observation_event_seq"] < recent[0]["seq"]
                        assert materials[0]["last_observed_stock"] == 3 and materials[0]["stock_may_have_changed"] is True
                        assert materials[0]["knowledge_source"] == "personal_proximity_observation"
                        places = personal["known_places"]
                        assert len(places) == 4, places
                        assert all(entry["source"] == "public_notice" and entry["source_id"] == "public_notice:market_exit"
                                   and entry["learned_event_id"] and entry["seq"] for entry in places), places
                        assert all(set(entry) == {"place_id", "label", "public_use", "source", "source_id", "learned_event_id", "seq"} for entry in places), places
                        assert all("nested_gm_secret" not in json.dumps(entry) and "nested_neighbor_secret" not in json.dumps(entry) for entry in places)
                    else:
                        assert personal["known_skill_notices"] == personal["known_skill_referrals"] == personal["material_sources"] == []
                        assert personal["known_places"] == [], "another resident's place knowledge never leaks"
                    if calls["post"] == 2:
                        offered = [entry for entry in personal["action_details"] if "Public iron offcuts" in entry["label"]]
                        assert len(offered) == 1
                        action = offered[0]["id"]
                    else:
                        action = next(entry["id"] for entry in personal["action_details"] if entry["label"] == "Wait")
                    assert action in personal["available_actions"]
                    if capture_folder:
                        (capture_folder / f"wire-{calls['post']}.json").write_text(json.dumps(body, ensure_ascii=False, indent=2), encoding="utf-8")
                if scenario == "continuation":
                    personal = json.loads(observation)
                    assert personal['identity']['story'].startswith('I remember my own life.')
                    assert personal['memory']['previous_decisions'][0]['reason'] == 'I previously chose to wait.'
                if scenario == "unicode-context":
                    personal = json.loads(observation)
                    assert personal['observations'] == ['树' * 4000 + ' 引号"与反斜线\\仍应正确编码。']
                    assert len(observation.encode('utf-8')) < 24576
                if scenario == "town":
                    personal = json.loads(observation)
                    assert personal["available_actions"] == ["wait", "accept:fixture-contract"]
                    assert personal["identity"]["story"] == "I prefer dependable work."
                    assert personal["contracts"][0]["id"] == "fixture-contract"
                    assert personal["known_rules"]["axe_use"] == "Both parts require 100."
                    assert personal["unavailable_actions"][0]["required_each"] == 100
                    assert "hidden_neighbor_wallet" not in observation
                    assert "wait, draw_water, drink_water" not in body["messages"][0]["content"]
            except Exception as error:
                calls["contract_errors"].append("POST contract: " + str(error))
                return self.reply(400, {"error": "fixture contract"})
            if scenario.startswith("concurrent-"):
                if capture_folder and calls["post"] == 1:
                    (capture_folder / "first-post.signal").write_text("local fixture HTTP is in flight", encoding="utf-8")
                time.sleep(0.3)  # Deterministically keep the first journal held during the second turn.
            if scenario in ("uncertain", "concurrent-uncertain"):
                return self.reply(502, {"error": "fixture unknown upstream outcome"})
            self.reply(200, {"model": wire_model("reply"), "choices": [{"message": {"role": "assistant", "content":
                json.dumps({"action": action, "reason": "Local transport fixture choice; no real model inference."})}, "finish_reason": "stop"}],
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
    parser.add_argument("--scenario", action="append", help="Run only these named scenarios (repeatable).")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    cases = []
    # Expected POST count per scenario; an absent scenario must never reach the gateway.
    posts = {"continuation": 12, "success": 1, "town": 1, "unicode-context": 1, "uncertain": 1,
             "pinned-model": 1, "reply-model-mismatch": 1, "town-history": 3, "knowledge-bounds": 1,
             "concurrent-reproduce": 1, "concurrent-success": 2, "concurrent-limit": 1, "concurrent-uncertain": 1, "concurrent-cancel": 1}
    scenarios = ["success", "town", "unicode-context", "continuation", "pinned-model", "model-mismatch",
                 "reply-model-mismatch", "insufficient", "wrong-ledger", "expired", "unsafe-endpoint", "uncertain", "town-history",
                 "knowledge-bounds", "knowledge-oversize", "knowledge-nested", "knowledge-missing-source", "knowledge-context-limit",
                 "concurrent-success", "concurrent-limit", "concurrent-uncertain", "concurrent-cancel"]
    if args.scenario and not set(args.scenario) <= set(scenarios + ["concurrent-reproduce"]):
        parser.error("Unknown scenario")
    for scenario in args.scenario or scenarios:
        folder = args.out / scenario
        folder.mkdir(exist_ok=False)  # Never reset an earlier run journal to get new capacity.
        with gateway(scenario, folder) as (port, calls):
            # A run-scoped pin may name another model, but the endpoint must advertise it.
            endpoint_model = "fixture-compat-model" if scenario in ("pinned-model", "reply-model-mismatch") else "kimi-k2.6"
            endpoint = folder / "endpoint.json"
            endpoint.write_text(json.dumps({"base_url": f"http://127.0.0.1:{port}/v1", "api_key": "local-fixture-token",
                "model": endpoint_model, "ledger_id": "fixture-ledger"}))
            if scenario == "unsafe-endpoint":
                endpoint.write_text(json.dumps({"base_url": "https://example.invalid/v1", "api_key": "local-fixture-token",
                    "model": "kimi-k2.6", "ledger_id": "fixture-ledger"}))
            run_config = {"schema_version": 1, "endpoint_path": str(endpoint.resolve()),
                "expected_ledger_id": "fixture-ledger", "run_state_path": str((folder / "state.json").resolve()),
                "deadline_utc": (datetime.now(timezone.utc) + timedelta(seconds=-1 if scenario == "expired" else 180)).isoformat(),
                "max_requests": 12 if scenario == "continuation" else 3 if scenario == "town-history" else 1, "external_liability_cny": 0, "provenance": "opengameagent_fixture"}
            if scenario == "pinned-model":
                run_config["expected_model"] = "fixture-compat-model"
            elif scenario == "model-mismatch":
                run_config["expected_model"] = "fixture-other-model"  # endpoint still advertises kimi-k2.6
            elif scenario == "reply-model-mismatch":
                run_config["expected_model"] = "fixture-compat-model"
            elif scenario == "continuation":
                run_config["expected_model"] = "kimi-k2.6"  # explicit default pin must not change behaviour
            config = folder / "run.json"
            if scenario.startswith("concurrent-"):
                run_config.update(max_requests=1 if scenario == "concurrent-limit" else 2, concurrency=2)
            config.write_text(json.dumps(run_config))
            # Replaying a fresh controller against the same journal must not mint requests.
            repeats = 2 if scenario in ("success", "uncertain", "pinned-model", "town-history") else 1
            prior_history = None
            for index in range(repeats):
                label = f"{scenario}-{index}"
                expect = "rejected" if index else {"success": "success", "town": "town", "unicode-context": "unicode-context",
                                                   "continuation": "continuation", "pinned-model": "success", "knowledge-bounds": "knowledge-bounds"}.get(scenario, "rejected")
                env = dict(os.environ, AINCRAD_GATEWAY_RUN_CONFIG=str(config.resolve()), AINCRAD_GATEWAY_TEST_EXPECT=expect,
                           AINCRAD_GATEWAY_TEST_SCENARIO=scenario)
                script = "res://tests/gateway_acceptance.gd"
                if scenario.startswith("concurrent-"):
                    script = "res://tests/town_gateway_concurrency_acceptance.gd"
                    env["AINCRAD_GATEWAY_HISTORY_SAVE"] = str((folder / "world.json").resolve())
                    env["AINCRAD_GATEWAY_FIRST_POST_SIGNAL"] = str((folder / "first-post.signal").resolve())
                if scenario == "town-history":
                    script = "res://tests/town_gateway_knowledge_acceptance.gd"
                    env.update(AINCRAD_GATEWAY_HISTORY_SAVE=str((folder / "world.json").resolve()),
                               AINCRAD_GATEWAY_HISTORY_PHASE="cold" if index else "seed")
                    if index:
                        assert hashlib.sha256((folder / "world.json").read_bytes()).hexdigest() == prior_history
                command = [sys.executable, str(ROOT / "tools/run_godot.py"), "--godot", args.godot, "--name", label,
                           "--timeout", "42", "--out", str(args.out / "runs"), "--", "--headless", "--script", script]
                result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=50)
                (folder / f"{index}.runner.log").write_text(result.stdout + result.stderr, encoding="utf-8")
                expected_posts = 1 if scenario == "town-history" and index == 0 else posts.get(scenario, 0)
                passed = result.returncode == 0 and calls["post"] == expected_posts and not calls["contract_errors"]
                if scenario.startswith("concurrent-"):
                    state = json.loads((folder / "state.json").read_text())
                    passed = passed and state["Count"] == expected_posts and state["Unknown"] is (scenario == "concurrent-uncertain")
                row = {"case": label, "passed": passed, **calls}
                if scenario == "town-history" and (folder / "world.json").exists():
                    prior_history = hashlib.sha256((folder / "world.json").read_bytes()).hexdigest()
                    row["world_sha256"] = prior_history
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
