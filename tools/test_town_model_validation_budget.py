"""Offline launcher contract tests: generated ledgers and a loopback fake gateway.

No user ledger/config is read, and no real provider object or model request is used.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing, contextmanager, redirect_stderr, redirect_stdout
from dataclasses import replace
import hashlib
import io
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

import run_town_model_validation as launcher
from kimi_budget import BudgetDenied, BudgetError, Ledger, Policy, encoded
from kimi_gateway import BudgetServer, UpstreamUnknown, handler_type
from town_validation_budget import CarriedLedgerGate, EvidenceGateway, read_review_pin


def request_body():
    return {'model': 'kimi-k2.6', 'messages': [{'role': 'user', 'content': 'Offline fixture: choose wait.'}],
            'max_tokens': 512, 'stream': False}


def receipt():
    return {'model': 'kimi-k2.6', 'choices': [{'message': {'role': 'assistant', 'content': '{"action":"wait"}'}}],
            'usage': {'prompt_tokens': 20, 'completion_tokens': 5, 'total_tokens': 25}}


class FakeProvider:
    def __init__(self, unknown=False, started=None, release=None):
        self.calls = 0
        self.unknown = unknown
        self.started = started
        self.release = release

    def complete(self, body):
        self.calls += 1
        if self.started:
            self.started.set()
        if self.release and not self.release.wait(5):
            raise AssertionError('Test did not release fake provider')
        if self.unknown:
            raise UpstreamUnknown('Offline injected unknown receipt')
        return receipt()


class BudgetLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='aincrad-launcher-fixture-')
        self.root = Path(self.temporary.name).resolve()
        self.policy = replace(Policy(), input_ceiling=100, concurrency=10, prior_unverified_nano=0)
        self.ledger = Ledger(self.root / 'fixture.sqlite3', self.policy)
        self.ledger.initialize()
        for index in range(6):
            self.ledger.reserve('old-unknown-' + str(index), 'old-resident-' + str(index), request_body())
            self.ledger.uncertain('old-unknown-' + str(index), 'Retained historical uncertainty')
        self.original_rows = self.rows()
        self.original_guard = self.ledger.guard.read_bytes()
        self.pin = self.make_pin()
        self.out = self.root / 'evidence'
        self.out.mkdir()
        self.provider = FakeProvider()

    def tearDown(self):
        self.temporary.cleanup()

    def rows(self):
        with self.ledger.transaction() as (db, _meta):
            return {row['id']: encoded(dict(row)) for row in db.execute('SELECT * FROM requests ORDER BY id')}

    def make_pin(self):
        return {'schema_version': 1, 'ledger_id': self.ledger.status()['ledger_id'],
                'policy_sha256': self.ledger.policy_hash,
                'guard_sha256': hashlib.sha256(self.ledger.guard.read_bytes()).hexdigest(),
                'uncertain_requests': [dict(id=key, state='uncertain', reserve_nano=json.loads(value)['reserve'])
                                       for key, value in self.rows().items()
                                       if json.loads(value)['state'] == 'uncertain']}

    def assert_original_preserved(self):
        self.assertEqual(self.original_guard, self.ledger.guard.read_bytes())
        current = self.rows()
        self.assertEqual(self.original_rows, {key: current[key] for key in self.original_rows})

    def gate(self, **kwargs):
        return CarriedLedgerGate(self.ledger, self.pin, **kwargs)

    @contextmanager
    def server(self, provider=None, **kwargs):
        gate = self.gate(**kwargs)
        gateway = EvidenceGateway(self.ledger, provider or self.provider, self.out, gate)
        server = BudgetServer(('127.0.0.1', 0), handler_type(gateway, 'fixture-local-token'))
        thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01})
        thread.start()
        try:
            yield f'http://127.0.0.1:{server.server_port}/v1/chat/completions', gate
        finally:
            server.shutdown()
            server.server_close()
            thread.join(5)
            self.assertFalse(thread.is_alive())

    def post(self, url, operation='fresh-1', resident='fixture-new-resident'):
        request = urllib.request.Request(url, data=json.dumps(request_body()).encode(), headers={
            'Authorization': 'Bearer fixture-local-token', 'Content-Type': 'application/json',
            'X-Hearth-Operation': operation, 'X-Hearth-Resident': resident})
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        try:
            with opener.open(request, timeout=5) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as response:
            return response.code, json.load(response)

    def test_valid_six_carried_rows_allow_one_call_and_preserve_all_old_facts(self):
        before = self.ledger.status()
        with self.server(max_requests=1) as (url, gate):
            code, _response = self.post(url)
            self.assertEqual(code, 200)
            self.assertEqual(self.post(url)[0], 200)  # Settled retry is cached.
            self.assertEqual(self.post(url, 'fresh-2')[0], 402)
        after = self.ledger.status()
        self.assertEqual(self.provider.calls, 1)
        self.assertEqual(gate.sent, 1)
        self.assertEqual(after['counts'], {'uncertain': 6, 'settled': 1})
        self.assertEqual(after['reserved_cny'], before['reserved_cny'])
        self.assertGreater(after['liability_cny'], before['liability_cny'])
        self.assert_original_preserved()

    def test_default_without_pin_is_closed(self):
        with self.assertRaises(BudgetDenied):
            CarriedLedgerGate(self.ledger)
        self.assertEqual(self.provider.calls, 0)
        self.assert_original_preserved()

    def test_existing_clean_ledger_needs_no_uncertainty_waiver(self):
        ledger = Ledger(self.root / 'clean.sqlite3', replace(self.policy, concurrency=2))
        ledger.initialize()
        ledger.reserve('old-settled', 'old-settled-resident', request_body())
        ledger.settle('old-settled', receipt())
        gate = CarriedLedgerGate(ledger)
        gateway = EvidenceGateway(ledger, self.provider, self.out, gate)
        self.assertEqual(gateway.complete('new-clean', 'new-clean-resident', request_body())['model'], 'kimi-k2.6')
        self.assertIsNone(gate.review)
        self.assertEqual(ledger.status()['counts'], {'settled': 2})
        self.assertEqual(self.provider.calls, 1)

    def test_pin_identity_hash_set_state_and_reserve_mismatches_make_zero_calls(self):
        changes = [lambda pin: pin.update(ledger_id='wrong-ledger'),
                   lambda pin: pin.update(policy_sha256='0' * 64),
                   lambda pin: pin.update(guard_sha256='0' * 64),
                   lambda pin: pin.update(schema_version=True),
                   lambda pin: pin.update(unreviewed=True),
                   lambda pin: pin['uncertain_requests'].pop(),
                   lambda pin: pin['uncertain_requests'].append(dict(pin['uncertain_requests'][0])),
                   lambda pin: pin['uncertain_requests'][0].update(id='wrong-operation'),
                   lambda pin: pin['uncertain_requests'][0].update(state='reserved'),
                   lambda pin: pin['uncertain_requests'][0].update(reserve_nano=1),
                   lambda pin: pin['uncertain_requests'][0].update(reserve_nano=True)]
        for index, change in enumerate(changes):
            with self.subTest(index=index):
                pin = json.loads(json.dumps(self.pin))
                change(pin)
                with self.assertRaises(BudgetDenied):
                    CarriedLedgerGate(self.ledger, pin)
        self.assertEqual(self.provider.calls, 0)
        self.assert_original_preserved()

    def test_pin_duplicate_json_fields_are_rejected(self):
        path = self.root / 'duplicate-review.json'
        path.write_text('{"schema_version":1,"schema_version":1}', encoding='utf-8')
        with self.assertRaises(BudgetDenied):
            read_review_pin(path)

    def test_new_unknown_retains_full_liability_and_does_not_extend_pin(self):
        self.provider.unknown = True
        before = self.ledger.status()
        with self.server() as (url, gate):
            self.assertEqual(self.post(url)[0], 502)
            self.assertEqual(self.post(url, 'fresh-2', 'resident-2')[0], 402)
            self.assertTrue(gate.failure)
        after = self.ledger.status()
        reserve = self.pin['uncertain_requests'][0]['reserve_nano'] / 1_000_000_000
        self.assertAlmostEqual(after['liability_cny'] - before['liability_cny'], reserve)
        self.assertEqual(after['counts'], {'uncertain': 7})
        self.assertEqual(self.provider.calls, 1)
        with self.assertRaises(BudgetDenied):
            self.gate()
        self.assert_original_preserved()

    def test_queued_request_cannot_dispatch_after_inflight_unknown(self):
        started, release, queued = threading.Event(), threading.Event(), threading.Event()
        provider = FakeProvider(unknown=True, started=started, release=release)
        with self.server(provider, concurrency=3) as (url, _gate), ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(self.post, url)
            self.assertTrue(started.wait(5))
            def second_request():
                queued.set()
                return self.post(url, 'fresh-2', 'resident-2')
            second = pool.submit(second_request)
            self.assertTrue(queued.wait(5))
            release.set()
            self.assertEqual(first.result(timeout=5)[0], 502)
            self.assertEqual(second.result(timeout=5)[0], 402)
        self.assertEqual(provider.calls, 1)  # Actual upstream in-flight bound is one.
        self.assert_original_preserved()

    def test_active_reservation_cannot_be_waived_by_uncertainty_pin(self):
        self.ledger.reserve('still-active', 'active-resident', request_body())
        with self.assertRaisesRegex(BudgetDenied, 'Active reservations'):
            self.gate()
        self.assertEqual(self.provider.calls, 0)

    def test_halt_and_unaccounted_metadata_fail_closed(self):
        with self.ledger.transaction() as (db, _meta):
            db.execute("UPDATE meta SET halted='fixture halt'")
        with self.assertRaises(BudgetDenied):
            self.gate()
        with closing(sqlite3.connect(self.ledger.path)) as db, db:
            db.execute("UPDATE meta SET halted='', liability=liability-1")
        with self.assertRaises(BudgetError):
            self.gate()
        self.assertEqual(self.provider.calls, 0)

    def test_runtime_rejects_changed_guard_or_any_changed_original_row(self):
        gate = self.gate()
        self.ledger.guard.write_bytes(self.original_guard + b'\n')
        with self.assertRaises(BudgetDenied):
            gate.check()
        self.ledger.guard.write_bytes(self.original_guard)
        with self.assertRaises(BudgetDenied):
            gate.check()  # This run does not recover after a stop condition.
        gate = self.gate()
        with self.ledger.transaction() as (db, _meta):
            db.execute("UPDATE requests SET note='Changed history' WHERE id='old-unknown-0'")
        with self.assertRaises(BudgetDenied):
            gate.check()

    def test_unknown_external_row_stops_before_new_upstream(self):
        gate = self.gate()
        self.ledger.reserve('external-operation', 'external-resident', request_body())
        self.ledger.settle('external-operation', receipt())
        gateway = EvidenceGateway(self.ledger, self.provider, self.out, gate)
        with self.assertRaises(BudgetDenied):
            gateway.complete('fresh-1', 'fresh-resident', request_body())
        self.assertEqual(self.provider.calls, 0)

    def test_external_write_between_reserve_and_send_is_detected_before_upstream(self):
        gate = self.gate()
        gateway = EvidenceGateway(self.ledger, self.provider, self.out, gate)
        reserve = self.ledger.reserve
        def reserve_then_external_write(operation, resident, body):
            result = reserve(operation, resident, body)
            reserve('external-race', 'external-resident', request_body())
            self.ledger.settle('external-race', receipt())
            return result
        with patch.object(self.ledger, 'reserve', side_effect=reserve_then_external_write):
            with self.assertRaises(UpstreamUnknown):
                gateway.complete('fresh-1', 'fresh-resident', request_body())
        self.assertEqual(self.provider.calls, 0)
        self.assertTrue(gate.failure)
        self.assertEqual(json.loads(self.rows()['fresh-1'])['state'], 'uncertain')
        self.assert_original_preserved()

    def test_invalid_billing_receipt_halts_run_and_keeps_full_reservation(self):
        self.provider.complete = lambda body: dict(receipt(), usage=None)
        with self.server() as (url, gate):
            self.assertEqual(self.post(url)[0], 502)
            self.assertEqual(self.post(url, 'fresh-2', 'resident-2')[0], 402)
        self.assertEqual(gate.sent, 1)
        self.assertTrue(self.ledger.status()['halted'])
        row = json.loads(self.rows()['fresh-1'])
        self.assertEqual(row['state'], 'uncertain')
        self.assertEqual(row['reserve'], self.pin['uncertain_requests'][0]['reserve_nano'])
        self.assertIsNone(row['charge'])
        self.assert_original_preserved()

    def test_missing_settled_billing_cannot_hide_unaccounted_row(self):
        self.ledger.reserve('fake-settled', 'fake-settled-resident', request_body())
        reserve = json.loads(self.rows()['fake-settled'])['reserve']
        with closing(sqlite3.connect(self.ledger.path)) as db, db:
            db.execute("UPDATE requests SET state='settled' WHERE id='fake-settled'")
            db.execute('UPDATE meta SET liability=liability-?', (reserve,))
        # Core aggregate accounting alone accepts SUM(NULL); the launch gate
        # additionally requires a usable, internally consistent paid receipt.
        with self.assertRaises((BudgetError, TypeError, ValueError)):
            self.gate()
        self.assertEqual(self.provider.calls, 0)

    def test_carry_cannot_lower_full_reservation_even_with_matching_pin(self):
        with closing(sqlite3.connect(self.ledger.path)) as db, db:
            db.execute("UPDATE requests SET reserve=reserve-1 WHERE id='old-unknown-0'")
            db.execute('UPDATE meta SET liability=liability-1')
        pin = self.make_pin()
        with self.assertRaisesRegex(BudgetDenied, 'full policy reservation'):
            CarriedLedgerGate(self.ledger, pin)

    def test_policy_ten_remains_immutable_and_runtime_bound_is_one_to_three(self):
        for value in (1, 2, 3):
            self.gate(concurrency=value)
        for value in (0, 4, 10, True):
            with self.subTest(value=value), self.assertRaises(BudgetDenied):
                self.gate(concurrency=value)
        for index in range(6, 8):
            self.ledger.reserve('old-unknown-' + str(index), 'old-resident-' + str(index), request_body())
            self.ledger.uncertain('old-unknown-' + str(index))
        self.pin = self.make_pin()
        self.gate(concurrency=2)
        with self.assertRaises(BudgetDenied):
            self.gate(concurrency=3)
        self.assertEqual(self.ledger.policy.concurrency, 10)
        self.assertEqual(self.original_guard, self.ledger.guard.read_bytes())

    def test_startup_pin_failure_precedes_config_read_and_any_provider(self):
        save = self.root / 'world.json'
        save.write_text('{}', encoding='utf-8')
        bad_pin = dict(self.pin, ledger_id='wrong-ledger')
        pin_path = self.root / 'wrong-review.json'
        pin_path.write_text(json.dumps(bad_pin), encoding='utf-8')
        args = ['launcher', '--godot', 'NEVER_RUN', '--ledger', str(self.ledger.path),
                '--save', str(save), '--config', str(self.root / 'does-not-exist-private-config.json'),
                '--out', str(self.root / 'new-run'), '--carried-uncertainty-pin', str(pin_path)]
        with patch.object(sys, 'argv', args), patch.object(launcher, 'KimiProvider') as provider, redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as stopped:
                launcher.main()
        self.assertEqual(stopped.exception.code, 2)
        provider.assert_not_called()
        self.assertFalse((self.root / 'new-run').exists())
        self.assert_original_preserved()

    def test_main_gm_export_scope_and_command_pass_through_without_real_engine(self):
        save = self.root / 'world.json'
        save.write_text('{"fixture":true}', encoding='utf-8')
        out = self.root / 'new-run'
        gm = out / 'gm' / 'evidence.json'
        config = self.root / 'fake-config.json'
        config.write_text('{"api_key":"fixture-must-not-appear-in-output"}', encoding='utf-8')
        pin_path = self.root / 'review.json'
        pin_path.write_text(json.dumps(self.pin), encoding='utf-8')
        args = ['launcher', '--godot', 'FAKE_GODOT', '--ledger', str(self.ledger.path),
                '--save', str(save), '--config', str(config), '--out', str(out), '--seconds', '5',
                '--max-requests', '1', '--stop-on-decision-limit',
                '--carried-uncertainty-pin', str(pin_path), '--gm-export', str(gm)]
        def fake_engine(command, **kwargs):
            self.assertIn('--town-gm-export=' + str(gm), command)
            self.assertIn('--town-stop-on-decision-limit', command)
            scope = json.loads(Path(kwargs['env']['AINCRAD_GATEWAY_RUN_CONFIG']).read_text())
            self.assertEqual(scope['concurrency'], 1)
            self.assertEqual(scope['gm_export_path'], str(gm))
            (out / 'capture').mkdir()
            (out / 'capture' / 'evidence.json').write_text('{"resident_turns":{}}', encoding='utf-8')
            gm.write_text('{"provenance":"offline fake engine"}', encoding='utf-8')
            return subprocess.CompletedProcess(command, 0, 'Offline engine stub', '')
        with patch.object(sys, 'argv', args), patch.object(launcher, 'KimiProvider', return_value=self.provider), \
                patch.object(launcher.subprocess, 'run', side_effect=fake_engine), redirect_stdout(io.StringIO()):
            self.assertEqual(launcher.main(), 0)
        self.assertTrue(gm.is_file())
        self.assertEqual(self.provider.calls, 0)
        self.assertEqual(json.loads((out / 'helper.json').read_text())['status'], 'closed')
        for path in out.rglob('*'):
            if path.is_file():
                self.assertNotIn('fixture-must-not-appear-in-output', path.read_text())
        self.assert_original_preserved()

    def test_gm_export_cannot_escape_or_replace_private_or_engine_artifacts(self):
        save = self.root / 'world.json'
        save.write_text('{}', encoding='utf-8')
        out = self.root / 'new-run'
        launcher.validate_paths(out, save, out / 'gm-evidence.json')
        for path in (save, out.parent / 'escaped.json', out / 'scope.json', out / 'capture' / 'evidence.json',
                     out / 'town-model.process.json', out / 'request-bodies' / 'body.json', out / 'evidence.txt',
                     out / '..' / 'escaped.json', out / 'SCOPE.JSON'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                launcher.validate_paths(out, save, path.resolve())
        with self.assertRaises(ValueError):
            launcher.validate_paths((launcher.ROOT / 'game' / 'private-test').resolve(), save)


if __name__ == '__main__':
    unittest.main(verbosity=2)
