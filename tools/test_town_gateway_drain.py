"""Offline contract tests for the loopback launcher gateway's bounded post-engine drain.

When the engine exits, ``run_town_model_validation`` stops new gateway intake and then waits a
finite grace for the request workers it already accepted, so an upstream response that arrives
after the engine died still settles its own durable reservation exactly once. A worker that
outlives the grace is reported as unresolved and its reservation is left exactly as it is.

These tests drive the real loopback HTTP path over generated temporary SQLite ledgers and a fake
upstream: no provider, no engine and no real ledger is touched. Timing is injected through the
candidate's own ``grace_seconds`` / release-event seams, so the production 40 s grace is never
waited here.
"""
import hashlib
import json
import socket
import sys
import tempfile
import threading
import time
import unittest
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools" / "kimi"))

import run_town_model_validation as launcher  # noqa: E402
from kimi_budget import Ledger, Policy, encoded  # noqa: E402
from kimi_gateway import UpstreamUnknown, handler_type  # noqa: E402
from town_validation_budget import CarriedLedgerGate, EvidenceGateway  # noqa: E402

TOKEN = "fixture-local-token"


def request_body():
    return {"model": "kimi-k2.6",
            "messages": [{"role": "user", "content": "Offline fixture: choose wait."}],
            "max_tokens": 512, "stream": False}


def receipt():
    return {"model": "kimi-k2.6",
            "choices": [{"message": {"role": "assistant", "content": '{"action":"wait"}'}}],
            "usage": {"prompt_tokens": 20, "completion_tokens": 5, "total_tokens": 25}}


class FakeUpstream:
    """Loopback fake provider: counts real HTTP-path calls, never contacts a provider."""

    def __init__(self, unknown=False):
        self.calls = 0
        self.unknown = unknown
        self.started = threading.Event()
        self.release = threading.Event()
        self._lock = threading.Lock()

    def complete(self, body):
        with self._lock:
            self.calls += 1
        self.started.set()
        if not self.release.wait(10):
            raise AssertionError("fixture never released the fake upstream")
        if self.unknown:
            raise UpstreamUnknown("Offline injected unknown receipt")
        return receipt()


class GatewayDrainTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="aincrad-drain-fixture-")
        self.root = Path(self.temporary.name).resolve()
        self.policy = replace(Policy(), input_ceiling=100, concurrency=10, prior_unverified_nano=0)
        self.ledger = Ledger(self.root / "fixture.sqlite3", self.policy)
        self.ledger.initialize()
        for index in range(6):
            self.ledger.reserve("old-unknown-%d" % index, "old-resident-%d" % index, request_body())
            self.ledger.uncertain("old-unknown-%d" % index, "Retained historical uncertainty")
        self.original_rows = self.rows()
        self.original_guard = self.ledger.guard.read_bytes()
        self.pin = {"schema_version": 1, "ledger_id": self.ledger.status()["ledger_id"],
                    "policy_sha256": self.ledger.policy_hash,
                    "guard_sha256": hashlib.sha256(self.ledger.guard.read_bytes()).hexdigest(),
                    "uncertain_requests": [
                        dict(id=key, state="uncertain", reserve_nano=json.loads(value)["reserve"])
                        for key, value in self.rows().items()
                        if json.loads(value)["state"] == "uncertain"]}
        self.out = self.root / "evidence"
        self.out.mkdir()
        self.provider = FakeUpstream()
        self.tracker = launcher.OperationTracker()
        self.servers = []

    def tearDown(self):
        # Never leave a serve_forever loop or a blocked fake upstream behind, even on failure.
        try:
            self.provider.release.set()
            for server, thread in self.servers:
                try:
                    launcher.drain_gateway(server, thread, self.tracker)
                except Exception:
                    pass
                try:
                    server.shutdown()
                    server.server_close()
                except Exception:
                    pass
                for worker in server.pending_workers():
                    worker.join(2)
                thread.join(3)
        finally:
            self.temporary.cleanup()

    def rows(self):
        with self.ledger.transaction() as (db, _meta):
            return {row["id"]: encoded(dict(row)) for row in db.execute("SELECT * FROM requests ORDER BY id")}

    def state(self, operation):
        row = self.rows().get(operation)
        return None if row is None else json.loads(row)["state"]

    def start_server(self, grace_seconds):
        gate = CarriedLedgerGate(self.ledger, self.pin)
        gateway = EvidenceGateway(self.ledger, self.provider, self.out, gate)
        # Production shape: the launcher wraps the gateway in TrackingGateway for diagnostics.
        tracking = launcher.TrackingGateway(gateway, self.tracker)
        server = launcher.DrainBudgetServer(("127.0.0.1", 0), handler_type(tracking, TOKEN),
                                           grace_seconds=grace_seconds)
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01})
        thread.start()
        self.servers.append((server, thread))
        return server, thread, gate

    def send_request(self, server, operation):
        body = json.dumps(request_body()).encode()
        head = ("POST /v1/chat/completions HTTP/1.1\r\nHost: 127.0.0.1\r\n"
                "Authorization: Bearer %s\r\nContent-Type: application/json\r\n"
                "X-Hearth-Operation: %s\r\nX-Hearth-Resident: fixture-new-resident\r\n"
                "Content-Length: %d\r\nConnection: close\r\n\r\n" % (TOKEN, operation, len(body)))
        client = socket.create_connection(("127.0.0.1", server.server_port), timeout=5)
        client.sendall(head.encode() + body)
        return client

    def assert_original_preserved(self):
        self.assertEqual(self.original_guard, self.ledger.guard.read_bytes())
        current = self.rows()
        self.assertEqual(self.original_rows, {key: current[key] for key in self.original_rows})

    def test_delayed_response_after_client_disconnect_settles_exactly_once(self):
        server, thread, gate = self.start_server(grace_seconds=4.0)
        client = self.send_request(server, "delayed-1")
        self.assertTrue(self.provider.started.wait(5), "request never reached the fake upstream")
        client.close()  # the engine/client is gone before the upstream response exists
        threading.Timer(0.4, self.provider.release.set).start()
        result = launcher.drain_gateway(server, thread, self.tracker)
        self.assertTrue(result["drained_complete"], str(result))
        self.assertFalse(result["workers_in_flight"], str(result))
        self.assertEqual(result["workers_accepted"], 1, str(result))
        self.assertEqual(self.provider.calls, 1, "upstream must be called exactly once, never replayed")
        self.assertEqual(gate.sent, 1)
        self.assertEqual(self.state("delayed-1"), "settled")
        self.assertEqual(self.ledger.status()["counts"], {"uncertain": 6, "settled": 1})
        self.assertEqual(result["unresolved_operations"], [])
        self.assert_original_preserved()

    def test_hanging_upstream_stays_unresolved_and_refuses_new_intake(self):
        server, thread, _gate = self.start_server(grace_seconds=0.4)
        client = self.send_request(server, "hang-1")
        self.assertTrue(self.provider.started.wait(5))
        started = time.monotonic()
        result = launcher.drain_gateway(server, thread, self.tracker)
        elapsed = time.monotonic() - started
        self.assertLess(elapsed, 3.0, "grace must stay finite and never wait the 40 s production bound")
        self.assertFalse(result["drained_complete"], str(result))
        self.assertEqual(result["unresolved_workers"], 1, str(result))
        self.assertEqual(result["unresolved_operations"], ["hang-1"], str(result))
        self.assertEqual(result["intake_closed"], True)
        self.assertTrue(server.intake_closed)
        self.assertEqual(self.provider.calls, 1)
        # No fabricated settlement or refund while the reservation is unresolved.
        self.assertEqual(self.state("hang-1"), "reserved")
        client.close()
        post_drain = self.ledger.status()["counts"]
        self.assertEqual(post_drain.get("settled", 0), 0)
        self.assertEqual(post_drain.get("refunded", 0), 0)
        refused = False
        try:
            probe = self.send_request(server, "hang-2")
            probe.settimeout(3)
            refused = probe.recv(64) == b""
            probe.close()
        except OSError:
            refused = True
        self.assertTrue(refused, "connection after stop_intake must be refused")
        time.sleep(0.3)
        self.assertEqual(self.provider.calls, 1, "no provider call may start after intake closed")
        self.assertIsNone(self.state("hang-2"))
        self.provider.release.set()
        for worker in server.pending_workers():
            worker.join(5)
            self.assertFalse(worker.is_alive())
        self.assertEqual(self.provider.calls, 1, "released worker must not replay the request")
        self.assertIn(self.state("hang-1"), ("reserved", "settled"))
        self.assert_original_preserved()

    def test_fast_normal_path_settles_once_and_keeps_intake_open(self):
        server, thread, gate = self.start_server(grace_seconds=0.5)
        self.provider.release.set()
        client = self.send_request(server, "fast-1")
        payload = b""
        client.settimeout(5)
        while b"\r\n\r\n" not in payload:
            chunk = client.recv(4096)
            if not chunk:
                break
            payload += chunk
        client.close()
        status_line = payload.split(b"\r\n", 1)[0]
        self.assertTrue(status_line.startswith(b"HTTP/1."), status_line[:40])
        self.assertEqual(status_line.split(b" ")[1], b"200", status_line[:40])
        self.assertFalse(server.intake_closed)
        self.assertEqual(self.provider.calls, 1)
        self.assertEqual(self.state("fast-1"), "settled")
        result = launcher.drain_gateway(server, thread, self.tracker)
        self.assertTrue(result["drained_complete"], str(result))
        self.assertEqual(result["workers_accepted"], 1, str(result))
        self.assertEqual(self.ledger.status()["counts"], {"uncertain": 6, "settled": 1})
        self.assertEqual(gate.sent, 1)
        self.assert_original_preserved()

    def test_zero_active_workers_closes_immediately(self):
        server, thread, _gate = self.start_server(grace_seconds=5.0)
        started = time.monotonic()
        result = launcher.drain_gateway(server, thread, self.tracker)
        elapsed = time.monotonic() - started
        self.assertTrue(result["drained_complete"], str(result))
        self.assertEqual(result["workers_accepted"], 0, str(result))
        self.assertEqual(result["unresolved_workers"], 0)
        self.assertLess(elapsed, 1.0, "an idle gateway must not consume the grace")
        self.assertEqual(self.ledger.status()["counts"], {"uncertain": 6})
        self.assert_original_preserved()

    def test_drain_returning_complete_does_not_settle_afterwards(self):
        """Late-accepted workers must not be able to settle after drain reports completion."""
        server, thread, _gate = self.start_server(grace_seconds=1.5)
        clients = [self.send_request(server, "race-%d" % index) for index in range(4)]
        self.assertTrue(self.provider.started.wait(5))
        threading.Timer(0.2, self.provider.release.set).start()
        result = launcher.drain_gateway(server, thread, self.tracker)
        counts_at_return = dict(self.ledger.status()["counts"])
        if result["drained_complete"]:
            time.sleep(0.5)
            self.assertEqual(dict(self.ledger.status()["counts"]), counts_at_return,
                             "a worker settled after drain reported complete")
        else:
            self.assertGreater(result["unresolved_workers"], 0)
            for worker in server.pending_workers():
                worker.join(5)
        for client in clients:
            client.close()
        self.assertLessEqual(self.provider.calls, 4)
        self.assert_original_preserved()


if __name__ == "__main__":
    unittest.main(verbosity=2)
