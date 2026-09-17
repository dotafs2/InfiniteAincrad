"""Offline launcher contract tests: generated ledgers and a loopback fake gateway.

No user ledger/config is read, and no real provider object or model request is used.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing, contextmanager, redirect_stderr, redirect_stdout
from dataclasses import replace
from datetime import datetime, timedelta, timezone
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

    @staticmethod
    def rows_for(ledger):
        with ledger.transaction() as (db, _meta):
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

    def gm_snapshot(self, world_id='fixture:model-validation-world', life_seq=0,
                    godot_elapsed=0.0, world_elapsed=0.0):
        return {'kind': 'background_gm_evidence_snapshot', 'schema_version': 1,
                'world_id': world_id,
                'source_revision': {'life_seq': life_seq, 'proposal_sequence': 0,
                                    'godot_elapsed_seconds': godot_elapsed,
                                    'world_elapsed_seconds': world_elapsed},
                'boundaries': {'contains_private_reply_reason': False,
                               'contains_other_resident_memories': False},
                'counts': {'issues': 0, 'proposals': 0},
                'evidence': [], 'proposals': []}

    def world_save(self, world_id='fixture:model-validation-world', life_seq=0,
                   godot_elapsed=0.0, world_elapsed=0.0):
        return {'world_id': world_id, 'life': {'seq': life_seq},
                'godot': {'elapsed_seconds': godot_elapsed},
                'elapsed_seconds': world_elapsed}

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

    def post(self, url, operation='fresh-1', resident='fixture-new-resident', token='fixture-local-token'):
        request = urllib.request.Request(url, data=json.dumps(request_body()).encode(), headers={
            'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json',
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

    def test_expired_ledger_is_rejected_before_any_run_attempt(self):
        path = self.root / 'expired.sqlite3'
        policy = replace(self.policy, deadline_utc=100)
        ledger = Ledger(path, policy, clock=lambda: 100)
        ledger.initialize()
        guard_before = ledger.guard.read_bytes()
        rows_before = self.rows_for(ledger)
        with self.assertRaisesRegex(BudgetDenied, 'usage window has ended'):
            CarriedLedgerGate(ledger)
        self.assertEqual(ledger.guard.read_bytes(), guard_before)
        self.assertEqual(self.rows_for(ledger), rows_before)
        self.assertEqual(self.provider.calls, 0)

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

    def test_formal_validation_classification_requires_a_decision_and_upstream_call(self):
        capture = {'world_id': 'fixture:model-validation-world',
                   'validation_decisions_started': 1, 'resident_turns': {},
                   'source_seq': 8, 'life_seq': 8, 'new_events': []}
        passed = launcher.classify_validation(0, capture, {}, '', False, 1)
        self.assertEqual(passed['validation_status'], 'passed')
        self.assertTrue(passed['validation_exercised'])
        baseline = {'status': 'available', 'world_id': capture['world_id'], 'life_seq': 8,
                    'godot_elapsed_seconds': 20.0, 'world_elapsed_seconds': 20.0}
        self.assertFalse(launcher.world_progress(baseline, capture)['observed'])
        # A valid model turn may choose wait: unchanged world counters are reported,
        # but are not grounds to relabel an exercised validation as failed.
        incomplete = launcher.classify_validation(0, capture, {}, '', False, 0)
        self.assertEqual(incomplete['validation_status'], 'not_exercised')
        self.assertEqual(incomplete['classification_reasons'], ['no_upstream_requests'])
        failed = launcher.classify_validation(7, capture, {}, '', False, 1)
        self.assertEqual(failed['validation_status'], 'failed')
        self.assertEqual(failed['classification_reasons'], ['engine_exit_nonzero'])

    def test_world_progress_uses_same_world_prelaunch_delta_not_absolute_history(self):
        world_id = 'fixture:restored-world'
        baseline = {'status': 'available', 'world_id': world_id, 'life_seq': 5,
                    'godot_elapsed_seconds': 120.0, 'world_elapsed_seconds': 120.0}
        capture = {'world_id': world_id, 'source_seq': 0, 'life_seq': 5,
                   'new_events': [{'seq': 4, 'kind': 'historical_fixture_event'}]}
        unchanged = launcher.world_progress(
            baseline, capture, self.gm_snapshot(world_id, 5, 120.0, 120.0))
        self.assertEqual(unchanged['comparison_status'], 'comparable')
        self.assertFalse(unchanged['observed'])
        self.assertEqual(unchanged['absolute']['capture']['source_seq'], 0)
        self.assertEqual(unchanged['absolute']['capture']['new_event_count'], 1)
        self.assertEqual(unchanged['absolute']['gm_export']['world_elapsed_seconds'], 120.0)
        self.assertEqual(unchanged['delta']['capture_life_seq'], 0)
        self.assertEqual(unchanged['delta']['gm_world_elapsed_seconds'], 0.0)

        crossed = launcher.world_progress(
            baseline, dict(capture, world_id='fixture:other-world'),
            self.gm_snapshot('fixture:other-world', 99, 999.0, 999.0))
        self.assertEqual(crossed['comparison_status'], 'world_mismatch')
        self.assertFalse(crossed['observed'])
        self.assertEqual(crossed['delta'], {})

        unknown = launcher.world_progress({'status': 'unknown'}, capture,
                                          self.gm_snapshot(world_id, 99, 999.0, 999.0))
        self.assertEqual(unknown['comparison_status'], 'unknown')
        self.assertFalse(unknown['observed'])
        self.assertEqual(unknown['delta'], {})

    def test_time_advancing_clean_cooldown_is_idle_not_startup_failure(self):
        world_id = 'fixture:model-validation-world'
        capture = {'world_id': world_id, 'source_seq': 0, 'life_seq': 12,
                   'new_events': [], 'validation_decisions_started': 0,
                   'resident_turns': {'fixture:a': {'status': 'settled'}},
                   'shutdown': {'resolved': True, 'timed_out': False, 'exit_code': 0,
                                'in_flight': [], 'resident_requests_owed': []}}
        classification = launcher.classify_validation(0, capture, {}, '', False, 0)
        baseline = {'status': 'available', 'world_id': world_id, 'life_seq': 12,
                    'godot_elapsed_seconds': 100.0, 'world_elapsed_seconds': 100.0}
        progress = launcher.world_progress(
            baseline, capture, self.gm_snapshot(world_id, 12, 700.0, 700.0))
        shutdown = {'intake_closed': True, 'workers_accepted': 0,
                    'workers_in_flight': False, 'drained_complete': True,
                    'unresolved_workers': 0, 'engine_exited_with_workers_pending': False,
                    'worker_start_failures': 0, 'drain_error': ''}
        ledger_after = {'counts': {'settled': 84}, 'halted': ''}
        args = (classification, 0, capture, {}, '', shutdown, progress, ledger_after, 0)
        self.assertTrue(launcher.healthy_idle_segment(*args))
        self.assertEqual(classification['validation_status'], 'not_exercised')
        self.assertFalse(classification['validation_exercised'])
        with self.subTest('no-time-progress'):
            unchanged = launcher.world_progress(
                baseline, capture, self.gm_snapshot(world_id, 12, 100.0, 100.0))
            self.assertFalse(launcher.healthy_idle_segment(
                classification, 0, capture, {}, '', shutdown, unchanged, ledger_after, 0))
        with self.subTest('unresolved'):
            unresolved = dict(ledger_after, counts={'settled': 84, 'reserved': 1})
            self.assertFalse(launcher.healthy_idle_segment(
                classification, 0, capture, {}, '', shutdown, progress, unresolved, 0))
        with self.subTest('engine-error'):
            self.assertFalse(launcher.healthy_idle_segment(
                classification, 3, capture, {}, '', shutdown, progress, ledger_after, 0))

    def test_startup_fault_append_is_idempotent_and_refuses_wrong_world_or_schema(self):
        capture = {'world_id': 'fixture:model-validation-world', 'source_seq': 0,
                   'life_seq': 0, 'pending_count': 0, 'validation_decisions_started': 0}
        classification = launcher.classify_validation(0, capture, {}, '', False, 0)
        valid = self.root / 'valid-gm.json'
        valid.write_text(json.dumps(self.gm_snapshot()), encoding='utf-8')
        first = launcher.append_startup_fault(valid, capture, classification, 0, 0)
        second = launcher.append_startup_fault(valid, capture, classification, 0, 0)
        self.assertEqual(first['status'], 'appended')
        self.assertEqual(second['status'], 'already_present')
        document = json.loads(valid.read_text())
        self.assertEqual(document['counts'], {'issues': 1, 'proposals': 0})
        self.assertEqual(len(document['evidence']), 1)
        fault = document['evidence'][0]
        self.assertEqual(fault['cause'], 'unknown')
        self.assertFalse(fault['cause_identified'])
        self.assertFalse(fault['resident_demand'])
        self.assertEqual(fault['world_id'], capture['world_id'])
        self.assertIn('did not complete a valid model-decision path', fault['first']['reason'])
        self.assertNotIn('first model decision', fault['first']['reason'])

        wrong = self.root / 'wrong-world-gm.json'
        wrong.write_text(json.dumps(self.gm_snapshot('fixture:another-world')), encoding='utf-8')
        wrong_before = wrong.read_bytes()
        refused = launcher.append_startup_fault(wrong, capture, classification, 0, 0)
        self.assertEqual(refused, {'status': 'refused', 'reason': 'gm_export_world_mismatch'})
        self.assertEqual(wrong.read_bytes(), wrong_before)

        malformed = self.root / 'malformed-gm.json'
        malformed.write_text('{"provenance":"not-an-engine-snapshot"}', encoding='utf-8')
        malformed_before = malformed.read_bytes()
        refused = launcher.append_startup_fault(malformed, capture, classification, 0, 0)
        self.assertEqual(refused, {'status': 'refused', 'reason': 'gm_export_schema_invalid'})
        self.assertEqual(malformed.read_bytes(), malformed_before)

        unsafe = self.root / 'unsafe-boundaries-gm.json'
        unsafe_document = self.gm_snapshot()
        unsafe_document['boundaries']['contains_private_reply_reason'] = True
        unsafe.write_text(json.dumps(unsafe_document), encoding='utf-8')
        unsafe_before = unsafe.read_bytes()
        refused = launcher.append_startup_fault(unsafe, capture, classification, 0, 0)
        self.assertEqual(refused, {'status': 'refused', 'reason': 'gm_export_boundaries_invalid'})
        self.assertEqual(unsafe.read_bytes(), unsafe_before)

    def test_main_gm_export_scope_and_command_pass_through_without_real_engine(self):
        save = self.root / 'world.json'
        save.write_text(json.dumps(self.world_save()), encoding='utf-8')
        out = self.root / 'new-run'
        gm = out / 'gm' / 'evidence.json'
        config = self.root / 'fake-config.json'
        config.write_text('{"api_key":"fixture-must-not-appear-in-output"}', encoding='utf-8')
        pin_path = self.root / 'review.json'
        pin_path.write_text(json.dumps(self.pin), encoding='utf-8')
        gm_status = self.root / 'gm-public-status.json'
        gm_status.write_text('{"fixture":"read-only-path"}', encoding='utf-8')
        args = ['launcher', '--godot', 'FAKE_GODOT', '--ledger', str(self.ledger.path),
                '--save', str(save), '--config', str(config), '--out', str(out), '--seconds', '5',
                '--max-requests', '1', '--stop-on-decision-limit',
                '--carried-uncertainty-pin', str(pin_path), '--gm-export', str(gm),
                '--gm-status', str(gm_status)]
        def fake_engine(command, **kwargs):
            self.assertIn('--town-gm-export=' + str(gm), command)
            self.assertIn('--town-gm-status=' + str(gm_status), command)
            self.assertIn('--town-stop-on-decision-limit', command)
            scope = json.loads(Path(kwargs['env']['AINCRAD_GATEWAY_RUN_CONFIG']).read_text())
            self.assertEqual(scope['concurrency'], 1)
            self.assertEqual(scope['gm_export_path'], str(gm))
            (out / 'capture').mkdir()
            capture = {'world_id': 'fixture:model-validation-world', 'source_seq': 0,
                       'life_seq': 0, 'new_events': [], 'pending_count': 0,
                       'validation_decisions_started': 0, 'resident_turns': {}}
            (out / 'capture' / 'evidence.json').write_text(json.dumps(capture), encoding='utf-8')
            gm.write_text(json.dumps(self.gm_snapshot()), encoding='utf-8')
            return subprocess.CompletedProcess(command, 0, 'Offline engine stub', '')
        with patch.object(sys, 'argv', args), patch.object(launcher, 'KimiProvider', return_value=self.provider), \
                patch.object(launcher.subprocess, 'run', side_effect=fake_engine), redirect_stdout(io.StringIO()):
            self.assertEqual(launcher.main(), 1)
        self.assertTrue(gm.is_file())
        self.assertEqual(self.provider.calls, 0)
        result = json.loads((out / 'result.json').read_text())
        self.assertEqual(result['validation_status'], 'not_exercised')
        self.assertFalse(result['validation_passed'])
        self.assertFalse(result['validation_exercised'])
        self.assertEqual(result['validation_decisions_started'], 0)
        self.assertEqual(result['upstream_requests'], 0)
        self.assertFalse(result['world_progress_observed'])
        self.assertEqual(result['startup_fault_export']['status'], 'appended')
        gm_document = json.loads(gm.read_text())
        self.assertEqual(gm_document['counts'], {'issues': 1, 'proposals': 0})
        self.assertEqual(gm_document['evidence'][0]['evidence_kind'],
                         'model_validation_startup_fault')
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

    def test_drain_names_workers_still_pending_at_engine_exit_without_claiming_a_settlement(self):
        """A reply that lands after the engine exited is named, never inferred."""
        started, release = threading.Event(), threading.Event()
        provider = FakeProvider(started=started, release=release)
        tracker = launcher.OperationTracker()
        gateway = launcher.TrackingGateway(EvidenceGateway(self.ledger, provider, self.out, self.gate(
            concurrency=1, max_requests=1)), tracker)
        server = launcher.DrainBudgetServer(('127.0.0.1', 0), handler_type(gateway, 'fixture-local-token'),
                                            grace_seconds=5.0)
        thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{server.server_port}/v1/chat/completions'
        engine = threading.Thread(target=self.post, args=(url, 'late-turn'), daemon=True)
        engine.start()
        try:
            self.assertTrue(started.wait(5), 'the fixture request never reached the provider')
            # The engine is gone while this request is still upstream: the reply crosses
            # the engine's own cutoff, so nothing here can have applied it.
            timer = threading.Timer(0.4, release.set)
            timer.start()
            try:
                shutdown = launcher.drain_gateway(server, thread, tracker)
            finally:
                timer.cancel()
                release.set()
        finally:
            server.stop_intake()
            server.shutdown()
            server.server_close()
            thread.join(5)
            engine.join(5)
        self.assertFalse(thread.is_alive())
        self.assertTrue(shutdown['intake_closed'])
        self.assertEqual(shutdown['workers_pending_at_engine_exit'], 1)
        self.assertEqual(shutdown['operations_pending_at_engine_exit'], ['late-turn'])
        self.assertTrue(shutdown['engine_exited_with_workers_pending'])
        self.assertTrue(shutdown['drained_complete'])
        self.assertEqual(shutdown['unresolved_workers'], 0)
        # Worker lifetime is not a settlement claim: only the ledger receipt is.
        self.assertNotIn('late_settled_operations', shutdown)
        self.assertNotIn('late_reply_unapplied', shutdown)
        self.assertEqual(json.loads(self.rows()['late-turn'])['state'], 'settled')
        self.assertEqual(provider.calls, 1)
        with self.assertRaises(OSError):
            self.post(url, 'after-engine-exit')
        self.assert_original_preserved()

    def test_engine_budget_covers_the_shutdown_wait_and_an_owed_turn_is_never_a_pass(self):
        """The engine may finish a reply after --seconds; a run that did not is honest."""
        save = self.root / 'world.json'
        save.write_text(json.dumps(self.world_save()), encoding='utf-8')
        out = self.root / 'new-run'
        config = self.root / 'fake-config.json'
        config.write_text('{"api_key":"fixture-must-not-appear-in-output"}', encoding='utf-8')
        pin_path = self.root / 'review.json'
        pin_path.write_text(json.dumps(self.pin), encoding='utf-8')
        started, release = threading.Event(), threading.Event()
        provider = FakeProvider(started=started, release=release)
        outcome, engine = {}, {}
        args = ['launcher', '--godot', 'FAKE_GODOT', '--ledger', str(self.ledger.path),
                '--save', str(save), '--config', str(config), '--out', str(out), '--seconds', '5',
                '--max-requests', '1', '--shutdown-wait', '12',
                '--carried-uncertainty-pin', str(pin_path)]
        before = datetime.now(timezone.utc)

        def fake_engine(command, **kwargs):
            self.assertIn('--town-duration=5', command)
            self.assertIn('--town-shutdown-wait=12.0', command)
            self.assertEqual(command[command.index('--timeout') + 1], '62')
            scope = json.loads(Path(kwargs['env']['AINCRAD_GATEWAY_RUN_CONFIG']).read_text())
            deadline = datetime.fromisoformat(scope['deadline_utc'])
            # The authorization window must hold both the episode and its shutdown wait.
            self.assertGreaterEqual(deadline, before + timedelta(seconds=5 + 12 + 54))
            self.assertLessEqual(deadline, datetime.now(timezone.utc) + timedelta(seconds=5 + 12 + 56))
            endpoint_document = json.loads((out / 'endpoint.json').read_text())
            endpoint = endpoint_document['base_url'] + '/chat/completions'

            def engine_call():
                try:
                    outcome['response'] = self.post(endpoint, 'turn:shared:weaver:0:22', 'shared:weaver',
                                                    endpoint_document['api_key'])
                except Exception as exc:  # Named here instead of lost in a thread traceback.
                    outcome['error'] = repr(exc)

            engine['thread'] = threading.Thread(target=engine_call, daemon=True)
            engine['thread'].start()
            self.assertTrue(started.wait(5), 'the fixture request never reached the provider: ' + str(outcome))
            threading.Timer(0.4, release.set).start()
            (out / 'capture').mkdir()
            capture = {'world_id': 'fixture:model-validation-world', 'source_seq': 0, 'life_seq': 0,
                       'new_events': [], 'pending_count': 0, 'validation_decisions_started': 1,
                       'resident_turns': {'shared:weaver': {'status': 'pending',
                                                            'request_id': 'turn:shared:weaver:0:22'}}}
            (out / 'capture' / 'evidence.json').write_text(json.dumps(capture), encoding='utf-8')
            return subprocess.CompletedProcess(command, 3, 'Offline engine stub: unresolved shutdown', '')

        with patch.object(sys, 'argv', args), patch.object(launcher, 'KimiProvider', return_value=provider), \
                patch.object(launcher.subprocess, 'run', side_effect=fake_engine), redirect_stdout(io.StringIO()):
            self.assertEqual(launcher.main(), 1)
        engine['thread'].join(5)
        self.assertFalse(engine['thread'].is_alive())
        self.assertEqual(outcome['response'][0], 200, outcome)
        result = json.loads((out / 'result.json').read_text())
        self.assertEqual(result['shutdown_wait_seconds'], 12.0)
        self.assertEqual(result['validation_status'], 'failed')
        self.assertFalse(result['validation_passed'])
        self.assertIn('engine_exit_nonzero', result['classification_reasons'])
        self.assertEqual(result['model_errors'], {'shared:weaver': 'pending'})
        self.assertEqual(result['upstream_requests'], 1)
        shutdown = result['gateway_shutdown']
        self.assertEqual(shutdown['operations_pending_at_engine_exit'], ['turn:shared:weaver:0:22'])
        self.assertTrue(shutdown['engine_exited_with_workers_pending'])
        self.assertTrue(shutdown['drained_complete'])
        self.assertNotIn('late_settled_operations', shutdown)
        self.assertEqual(json.loads(self.rows()['turn:shared:weaver:0:22'])['state'], 'settled')
        self.assert_original_preserved()


if __name__ == '__main__':
    unittest.main(verbosity=2)
