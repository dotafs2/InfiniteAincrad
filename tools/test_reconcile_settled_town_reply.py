"""Offline fixtures for the settled-reply extraction step.

Everything is generated locally: a temporary fee ledger, a preserved request body and a
fixture world save. No provider object, no network call and no user ledger/config is touched.
These fixtures are not autonomous resident evidence; they only pin the extraction contract.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import sqlite3
import subprocess
import sys
from dataclasses import replace
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/kimi'))
import reconcile_settled_town_reply as tool
from kimi_budget import Ledger, Policy

TOOL = ROOT / 'tools' / 'reconcile_settled_town_reply.py'
OP = 'dc45d0a2-986a-4bd9-a03b-59b387dd9595'
RESIDENT = 'shared:weaver'
REQUEST = 'turn:shared:weaver:0:22'
EPOCH = 0
WORLD_ID = 'fixture:town-rules'
PROVIDER = 'opengameagent_live'
DECISION_TEXT = '{"action":"a0","reason":"fixture reasoning text"}'
FAILED_REPLY = {'ok': False, 'code': 'brain_run_failed', 'command_id': OP, 'model_returned': False,
                'assistant_text_parts': [], 'assistant_text': '', 'provider_id': PROVIDER,
                'runtime': 'OpenGameAgent', 'fixture': False, 'provenance': PROVIDER}
FORBIDDEN_TOKENS = ('urllib', 'socket', 'import requests', 'kimi_gateway', 'KimiProvider', 'Ledger(',
                    'reserve(', 'settle(', 'transaction(', 'initialize(', 'http://', 'https://')
SIDECAR_SUFFIXES = ('-shm', '-wal', '-journal')


def request_body():
    return {'model': 'kimi-k2.6', 'messages': [
                {'role': 'system', 'content': 'You are this resident.'},
                {'role': 'user', 'content': '{"available_actions":["a0"]}'}],
            'stream': False, 'max_tokens': 512, 'thinking': {'type': 'disabled'},
            'response_format': {'type': 'json_object'}}


def receipt():
    return {'model': 'kimi-k2.6',
            'choices': [{'index': 0, 'message': {'role': 'assistant', 'content': DECISION_TEXT}, 'finish_reason': 'stop'}],
            'usage': {'prompt_tokens': 80, 'completion_tokens': 12, 'total_tokens': 92,
                      'prompt_tokens_details': {'cached_tokens': 20}}}


def world_save(record_changes=None, archive_changes=None, removed=None, reply=None):
    failed = FAILED_REPLY if reply is None else reply
    record = {'status': 'provider_error', 'seen_seq': 1, 'history': [], 'reviews': [],
              'controller_epoch': EPOCH, 'controller_id': 'local:gateway', 'request_number': 22,
              'request_id': REQUEST, 'offered_actions': {'a0': 'wait'}, 'speech_actions': [],
              'provider_command_id': OP, 'error': 'brain_run_failed', 'accepted_reply': failed}
    entry = {'archive_id': REQUEST, 'world_id': WORLD_ID, 'resident_id': RESIDENT, 'request_id': REQUEST,
             'provider_id': PROVIDER, 'model_returned': False, 'assistant_text_parts': [],
             'assistant_text': '', 'original_reply': failed,
             'application': {'status': 'provider_error', 'code': 'brain_run_failed', 'effect': {},
                             'speech_delivery': {'attempted': False, 'delivered': False, 'code': 'no_world_action'}}}
    record.update(record_changes or {})
    entry.update(archive_changes or {})
    entries = {REQUEST: entry}
    for key in removed or ():
        entries.pop(key, None)
    return {'world_id': WORLD_ID, 'godot': {'resident_turns': {RESIDENT: record},
            'resident_archive': {'schema_version': 1, 'world_id': WORLD_ID, 'order': [REQUEST], 'entries': entries}}}


class ReconcileExtractionTests(unittest.TestCase):
    def setUp(self):
        base = Path(os.environ.get('AINCRAD_RECONCILE_TMP') or (ROOT / 'tmp' / 'reconcile-fixtures'))
        base.mkdir(parents=True, exist_ok=True)
        self.root = base / ('case-' + uuid.uuid4().hex)
        self.root.mkdir()
        self.policy = replace(Policy(), input_ceiling=100, prior_unverified_nano=0)
        self.ledger = Ledger(self.root / 'fixture.sqlite3', self.policy)
        self.ledger.initialize()
        self.ledger.reserve(OP, RESIDENT, request_body())
        self.ledger.settle(OP, receipt())
        self.envelope = self.root / 'request-body.json'
        self.write_json(self.envelope, {'operation': OP, 'resident': RESIDENT, 'body': request_body()})
        self.save = self.root / 'world.json'
        self.write_world(world_save())
        self.out = self.root / 'receipt.json'

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def write_json(self, path, value):
        path.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
        return path

    def write_world(self, world):
        return self.write_json(self.save, world)

    def arguments(self, **overrides):
        values = {'--ledger': str(self.ledger.path), '--operation': OP, '--resident': RESIDENT,
                  '--body': str(self.envelope), '--world-save': str(self.save), '--epoch': str(EPOCH),
                  '--provider-id': PROVIDER, '--out': str(self.out)}
        for key, value in overrides.items():
            values['--' + key.replace('_', '-')] = value
        argv = []
        for key, value in values.items():
            argv.extend([key, value])
        return argv

    def run_tool(self, **overrides):
        command = [sys.executable, '-X', 'utf8', str(TOOL)] + self.arguments(**overrides)
        # Child processes are given a candidate-local temp so a read-only user temp is never needed.
        environment = dict(os.environ, TEMP=str(self.root), TMP=str(self.root), TMPDIR=str(self.root))
        return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8',
                              errors='replace', env=environment, timeout=90)

    def stdout(self, result):
        return json.loads(result.stdout.strip().splitlines()[-1])

    def file_bytes(self):
        # A read-only SQLite connection still uses the shared-memory sidecar of a WAL journal;
        # that transient file is not billing data. Every data file is compared byte for byte.
        return {path.name: path.read_bytes() for path in sorted(self.root.iterdir())
                if path.is_file() and not path.name.endswith(SIDECAR_SUFFIXES)}

    def ledger_rows(self):
        uri = tool.readonly_uri(self.ledger.path)
        connection = sqlite3.connect(uri, uri=True)
        try:
            connection.row_factory = sqlite3.Row
            return dict(connection.execute('SELECT * FROM requests WHERE id=?', (OP,)).fetchone())
        finally:
            connection.close()

    def test_matching_settled_row_writes_private_receipt_and_changes_nothing(self):
        before = self.file_bytes()
        result = self.run_tool()
        summary = self.stdout(result)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(summary['ok'], summary)
        self.assertEqual(summary['code'], 'receipt_written')
        self.assertEqual(summary['provider_operation_id'], OP)
        self.assertEqual(summary['assistant_text_chars'], len(DECISION_TEXT))
        # The raw model text and the private reason stay out of stdout.
        self.assertNotIn('fixture reasoning text', result.stdout)
        self.assertNotIn('reason', result.stdout)
        self.assertTrue(self.out.is_file())
        receipt_document = json.loads(self.out.read_text(encoding='utf-8'))
        self.assertEqual(receipt_document['kind'], 'settled_town_reply_receipt')
        self.assertEqual(receipt_document['source']['resident_id'], RESIDENT)
        self.assertEqual(receipt_document['source']['request_id'], REQUEST)
        self.assertEqual(receipt_document['source']['controller_epoch'], EPOCH)
        self.assertEqual(receipt_document['source']['provider_operation_id'], OP)
        self.assertEqual(receipt_document['failure']['original_failed_reply'], FAILED_REPLY)
        self.assertEqual(receipt_document['archive']['application_status'], 'provider_error')
        self.assertEqual(receipt_document['archive']['replays'], 0)
        self.assertEqual(receipt_document['reply']['assistant_text'], DECISION_TEXT)
        row = self.ledger_rows()
        self.assertEqual(receipt_document['ledger']['payload_sha256'], row['payload_sha'])
        self.assertEqual(receipt_document['ledger']['response_sha256'], row['response_sha'])
        self.assertEqual(receipt_document['ledger']['charge_nano'], row['charge'])
        self.assertEqual(receipt_document['ledger']['prompt_tokens'], row['prompt_tokens'])
        self.assertEqual(receipt_document['ledger']['output_tokens'], row['output_tokens'])
        # Nothing else moved: not one ledger byte, not one save byte, no leftover file.
        after = self.file_bytes()
        self.assertEqual({k: v for k, v in before.items()}, {k: v for k, v in after.items() if k in before})
        self.assertEqual(sorted(after), sorted(list(before) + ['receipt.json']))
        # A quiescent ledger is read through an immutable snapshot: not even a sidecar appears.
        self.assertEqual([path.name for path in self.root.iterdir()
                          if path.name.endswith(SIDECAR_SUFFIXES)], [])

    def test_extract_in_process_uses_no_socket(self):
        args = tool.parse(self.arguments())
        def refuse(*_args, **_kwargs):
            raise AssertionError('the extraction step must not open a socket')
        with patch.object(socket, 'socket', refuse):
            receipt_document = tool.extract(args)
        self.assertEqual(receipt_document['source']['provider_operation_id'], OP)
        self.assertEqual(receipt_document['ledger']['state'], 'settled')
        self.assertFalse(self.out.exists())

    def test_tool_source_has_no_network_or_billing_entry_points(self):
        source = TOOL.read_text(encoding='utf-8')
        for token in FORBIDDEN_TOKENS:
            self.assertNotIn(token, source, 'unexpected token in extraction tool: ' + token)

    def test_refuses_missing_settled_row_without_any_write(self):
        other = 'ff000000-0000-0000-0000-000000000000'
        self.write_json(self.root / 'other.json', {'operation': other, 'resident': 'shared:fisher',
                                                   'body': request_body()})
        before = self.file_bytes()
        result = self.run_tool(operation=other, resident='shared:fisher',
                               body=str(self.root / 'other.json'))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.stdout(result)['code'], 'ledger_row_absent')
        self.assertEqual(self.file_bytes(), before)

    def test_refuses_unsettled_row(self):
        self.ledger.reserve('second-operation', 'shared:fisher', request_body())
        other = str(self.write_json(self.root / 'other.json',
                                    {'operation': 'second-operation', 'resident': 'shared:fisher',
                                     'body': request_body()}))
        before = self.file_bytes()
        result = self.run_tool(operation='second-operation', resident='shared:fisher',
                               body=other)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.stdout(result)['code'], 'ledger_row_not_settled:reserved')
        self.assertEqual(self.file_bytes(), before)

    def test_refuses_changed_body_bytes(self):
        changed = request_body()
        changed['messages'][1]['content'] = '{"available_actions":["a0"],"needs":{"energy":6}}'
        self.write_json(self.envelope, {'operation': OP, 'resident': RESIDENT, 'body': changed})
        before = self.file_bytes()
        result = self.run_tool()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.stdout(result)['code'], 'body_hash_mismatch')
        self.assertEqual(self.file_bytes(), before)

    def test_refuses_resident_mismatch(self):
        result = self.run_tool(resident='shared:fisher')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.stdout(result)['code'], 'body_resident_mismatch')

    def test_refuses_changed_ledger_response_or_charge(self):
        with sqlite3.connect(self.ledger.path) as connection:
            connection.execute('UPDATE requests SET charge=charge+1 WHERE id=?', (OP,))
        result = self.run_tool()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.stdout(result)['code'], 'usage_charge_mismatch')

    def test_refuses_changed_response_bytes(self):
        with sqlite3.connect(self.ledger.path) as connection:
            row = connection.execute('SELECT response FROM requests WHERE id=?', (OP,)).fetchone()
            tampered = json.loads(row[0])
            tampered['choices'][0]['message']['content'] = '{"action":"a0","reason":"other"}'
            connection.execute('UPDATE requests SET response=? WHERE id=?',
                               (json.dumps(tampered, sort_keys=True, separators=(',', ':')), OP))
        result = self.run_tool()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.stdout(result)['code'], 'response_hash_mismatch')

    def test_refuses_pending_or_applied_or_misbound_turn(self):
        cases = [
            ({'status': 'pending'}, 'turn_not_provider_error'),
            ({'error': 'invalid_decision'}, 'turn_error_not_recoverable'),
            ({'provider_command_id': 'other-operation'}, 'turn_operation_mismatch'),
            ({'controller_epoch': 3}, 'turn_epoch_mismatch'),
            ({'accepted_reply': dict(FAILED_REPLY, ok=True)}, 'turn_has_applied_reply'),
        ]
        for changes, expected in cases:
            with self.subTest(changes=changes):
                self.write_world(world_save(changes))
                before = self.file_bytes()
                result = self.run_tool()
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertEqual(self.stdout(result)['code'], expected)
                self.assertEqual(self.file_bytes(), before)

    def test_refuses_archive_that_already_records_a_reply(self):
        cases = [
            ({'application': {'status': 'settled', 'code': 'wait'}}, 'failure_archive_not_provider_error'),
            ({'replays': [{'application': {'status': 'settled'}}]}, 'failure_archive_has_replays'),
            ({'original_reply': dict(FAILED_REPLY, code='other')}, 'failure_archive_reply_mismatch'),
        ]
        for changes, expected in cases:
            with self.subTest(changes=changes):
                self.write_world(world_save(archive_changes=changes))
                before = self.file_bytes()
                result = self.run_tool()
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertEqual(self.stdout(result)['code'], expected)
                self.assertEqual(self.file_bytes(), before)

    def test_refuses_wrong_source_hash_pin_and_request_pin(self):
        before = self.file_bytes()
        pinned = self.run_tool(source_sha256='00' * 32)
        self.assertEqual(pinned.returncode, 1)
        self.assertEqual(self.stdout(pinned)['code'], 'source_hash_mismatch')
        self.assertEqual(self.file_bytes(), before)
        stale = self.run_tool(request_id='turn:shared:weaver:0:21')
        self.assertEqual(stale.returncode, 1)
        self.assertEqual(self.stdout(stale)['code'], 'turn_request_mismatch')
        self.assertEqual(self.file_bytes(), before)

    def test_refuses_receipt_target_that_would_overwrite_an_input(self):
        result = self.run_tool(out=str(self.save))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.stdout(result)['code'], 'receipt_target_would_overwrite_input')
        self.assertEqual(json.loads(self.save.read_text(encoding='utf-8'))['world_id'], WORLD_ID)

    def test_refuses_temp_or_existing_output_collisions(self):
        guarded = self.root / 'guarded.json.tmp'
        guarded.write_text(self.save.read_text(encoding='utf-8'), encoding='utf-8')
        before = self.file_bytes()
        # The fixed temporary name of this target is the world save itself.
        temp_collision = self.run_tool(out=str(self.root / 'guarded.json'), world_save=str(guarded))
        self.assertEqual(temp_collision.returncode, 2)
        self.assertEqual(self.stdout(temp_collision)['code'], 'receipt_target_would_overwrite_input')
        self.assertEqual(self.file_bytes(), before)
        # An unrelated existing output is never replaced.
        existing = self.root / 'existing.json'
        existing.write_text('{"unrelated": true}', encoding='utf-8')
        before = self.file_bytes()
        present = self.run_tool(out=str(existing))
        self.assertEqual(present.returncode, 2)
        self.assertEqual(self.stdout(present)['code'], 'receipt_target_exists')
        self.assertEqual(existing.read_text(encoding='utf-8'), '{"unrelated": true}')
        # A leftover temporary of the same target is refused too.
        stale = self.root / 'stale.json.tmp'
        stale.write_text('leftover', encoding='utf-8')
        before = self.file_bytes()
        blocked = self.run_tool(out=str(self.root / 'stale.json'))
        self.assertEqual(blocked.returncode, 2)
        self.assertEqual(self.stdout(blocked)['code'], 'receipt_temp_exists')
        self.assertEqual(stale.read_text(encoding='utf-8'), 'leftover')
        self.assertEqual(self.file_bytes(), before)

    def test_refuses_relabelled_or_missing_provenance(self):
        before = self.file_bytes()
        relabelled = self.run_tool(provider_id='opengameagent_fixture')
        self.assertEqual(relabelled.returncode, 1)
        self.assertEqual(self.stdout(relabelled)['code'], 'turn_provenance_mismatch')
        self.assertEqual(self.file_bytes(), before)
        unproven = dict(FAILED_REPLY)
        unproven.pop('provenance')
        unproven.pop('provider_id')
        self.write_world(world_save(reply=unproven))
        before = self.file_bytes()
        missing = self.run_tool()
        self.assertEqual(missing.returncode, 1)
        self.assertEqual(self.stdout(missing)['code'], 'turn_provenance_missing')
        self.assertEqual(self.file_bytes(), before)


if __name__ == '__main__':
    unittest.main(verbosity=2)
