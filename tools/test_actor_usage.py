import json
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path
import sys
from contextlib import closing
sys.path.insert(0, str(Path(__file__).resolve().parent))
from actor_usage import (UsageBook, for_world, native_usage_lower_bound,
                         rebind_existing_book)
import gm_runner


class ActorUsageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.path = self.root / 'usage.sqlite3'
        self.actors = [dict(id='ari', name='Ari', role='NPC'), dict(id='gm-01', name='GM 01', role='GM')]
        self.book = UsageBook(self.path, 'world-a', self.actors)

    def tearDown(self):
        self.temp.cleanup()

    def measured(self, call='npc:1', actor='ari', model='model-a'):
        self.book.record(call, actor, 'provider', model, 'decision', 'measured',
                         dict(input_tokens=100, output_tokens=10, cached_input_tokens=40))

    def rebind_fixture(self, name='rebind'):
        root = self.root / name
        gm_dir = root / 'gm'
        gm_dir.mkdir(parents=True)
        world = root / 'world.json'
        world.write_text(json.dumps({'world_id': 'world-a', 'life': {'seq': 43},
                                     'residents': [{'stable_id': 'ari', 'name': 'Ari'}]}),
                         encoding='utf-8')
        target = root / 'developer-usage.sqlite3'
        book = UsageBook(target, 'world-a', self.actors)
        book.record('npc:kept', 'ari', 'provider', 'model-a', 'decision', 'pending')
        book.record('npc:kept', 'ari', 'provider', 'model-a', 'decision', 'measured',
                    dict(input_tokens=100, output_tokens=10, cached_input_tokens=40))
        snapshot = root / 'portable.json'
        snapshot.write_text(json.dumps(book.snapshot(), ensure_ascii=False, indent=2) + '\n',
                            encoding='utf-8')
        old = root / 'absent-old-book.sqlite3'
        state = gm_dir / gm_runner.STATE_FILE
        state.write_text(json.dumps({
            'schema_version': gm_runner.STATE_SCHEMA, 'world_id': 'world-a',
            'sessions': {}, 'issues': {}, 'sources': [],
            'developer_usage_book': str(old),
            'developer_usage_book_rebindings': [{'kind': 'older-audit', 'kept': True}],
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        return world, state, snapshot, target, old

    def test_zero_start_and_permanent_identity_after_reopen(self):
        self.assertTrue(all(a['tokens']['total_tokens'] == 0 for a in self.book.snapshot()['actors']))
        self.measured()
        again = UsageBook(self.path, 'world-a', self.actors)
        ari = next(a for a in again.snapshot()['actors'] if a['id'] == 'ari')
        self.assertEqual(ari['usage_tag'], 'world-a/ari')
        self.assertEqual(ari['tokens']['total_tokens'], 110)

    def test_cache_subset_idempotence_and_cross_model_total(self):
        self.measured()
        self.measured()
        self.measured('npc:2', model='model-b')
        ari = next(a for a in self.book.snapshot()['actors'] if a['id'] == 'ari')
        self.assertEqual(ari['measured_calls'], 2)
        self.assertEqual(ari['tokens']['total_tokens'], 220)
        self.assertEqual(ari['tokens']['cached_input_tokens'], 80)
        with self.book.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM revisions').fetchone()[0], 2)

    def test_unknown_can_only_be_resolved_with_measured_receipt_and_keeps_audit(self):
        self.book.record('npc:1', 'ari', 'provider', 'model-a', 'decision', 'pending')
        self.book.record('npc:1', 'ari', 'provider', 'model-a', 'decision', 'unknown')
        with self.assertRaises(ValueError):
            self.book.record('npc:1', 'ari', 'provider', 'model-a', 'decision', 'pending')
        with self.assertRaises(ValueError):
            self.book.record('npc:1', 'ari', 'provider', 'model-a', 'decision', 'not_sent')
        self.assertEqual(next(a for a in self.book.snapshot()['actors'] if a['id'] == 'ari')['unresolved_calls'], 1)
        self.measured()
        with self.book.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM revisions').fetchone()[0], 3)

    def test_wrong_world_actor_or_changed_measured_receipt_refused(self):
        self.measured()
        with self.assertRaises(ValueError): UsageBook(self.path, 'old-world', self.actors)
        with self.assertRaises(ValueError): self.measured(actor='gm-01')
        with self.assertRaises(ValueError): self.measured('new', actor='missing')
        with self.assertRaises(ValueError): self.measured(model='different-model')
        with self.assertRaises(ValueError):
            self.book.record('npc:1', 'ari', 'provider', 'model-a', 'decision', 'unknown')

    def test_invalid_or_missing_tokens_never_become_zero(self):
        for usage in ({}, dict(input_tokens=True, output_tokens=3),
                      dict(input_tokens=10, output_tokens=-1),
                      dict(input_tokens=10, output_tokens=1, cached_input_tokens=11)):
            with self.subTest(usage=usage), self.assertRaises(ValueError):
                self.book.record('npc:1', 'ari', 'provider', 'm', 'decision', 'measured', usage)

    def test_native_resume_counts_delta_and_new_session_keeps_actor_total(self):
        state = dict(sessions={}, issues={})
        first = dict(thread_returned='session-a', usage=dict(input_tokens=100, output_tokens=10, cached_input_tokens=0))
        gm_runner.account_native_usage(state, first, None)
        self.book.begin_gm('run-a', 'gm-01', 'observe')
        self.book.settle_gm('run-a', 'gm-01', 'observe', first)
        second = dict(thread_returned='session-a', usage=dict(input_tokens=170, output_tokens=15, cached_input_tokens=20))
        gm_runner.account_native_usage(state, second, 'session-a')
        self.book.begin_gm('run-b', 'gm-01', 'feedback')
        self.book.settle_gm('run-b', 'gm-01', 'feedback', second)
        third = dict(thread_returned='session-b', usage=dict(input_tokens=30, output_tokens=5, cached_input_tokens=0))
        gm_runner.account_native_usage(state, third, None)
        self.book.begin_gm('run-c', 'gm-01', 'code')
        self.book.settle_gm('run-c', 'gm-01', 'code', third)
        gm = next(a for a in self.book.snapshot()['actors'] if a['id'] == 'gm-01')
        self.assertEqual(gm['tokens']['total_tokens'], 220)
        self.assertEqual(gm['measured_calls'], 3)
        self.assertEqual(gm['unpriced_measured_calls'], 3)

    def test_kimi_cached_reply_attribution_does_not_charge_twice(self):
        ledger = self.root / 'ledger.sqlite3'
        with closing(sqlite3.connect(ledger)) as db, db:
            db.execute('CREATE TABLE requests(id,resident,state,prompt_tokens,output_tokens,cached_tokens,charge)')
            db.execute("INSERT INTO requests VALUES('r1','ari','settled',100,10,40,12345)")
        self.book.begin_npc('r1', 'ari', 'kimi-k2.6')
        self.book.sync_kimi_call(ledger, 'r1', 'ari')
        self.book.begin_npc('r1', 'ari', 'kimi-k2.6')
        self.book.sync_kimi_call(ledger, 'r1', 'ari')
        with self.assertRaises(ValueError): self.book.sync_kimi_call(ledger, 'r1', 'gm-01')
        ari = next(a for a in self.book.snapshot()['actors'] if a['id'] == 'ari')
        self.assertEqual(ari['measured_calls'], 1)
        self.assertEqual(ari['measured_charge_nano'], 12345)

    def test_unsent_request_and_unknown_usage_are_distinct(self):
        self.book.begin_gm('run-a', 'gm-01', 'observe')
        self.book.settle_gm('run-a', 'gm-01', 'observe', {'usage_measured': False})
        self.book.record('npc:1', 'ari', 'kimi_ledger', 'm', 'decision', 'not_sent')
        data = self.book.export()
        self.assertEqual(next(a for a in data['actors'] if a['id'] == 'gm-01')['unresolved_calls'], 1)
        self.assertEqual(next(a for a in data['actors'] if a['id'] == 'ari')['not_sent_calls'], 1)
        self.assertEqual(data['visibility'], 'developer_only')

    def test_partial_usage_is_a_persistent_monotonic_lower_bound(self):
        args = ('gm:1', 'gm-01', 'native_gm', 'deepseek-flash', 'observe')
        self.book.record(*args, 'unknown')
        self.book.record(*args, 'partial', dict(input_tokens=90, output_tokens=5))
        gm = next(a for a in self.book.export()['actors'] if a['id'] == 'gm-01')
        self.assertEqual((gm['tokens']['total_tokens'], gm['partial_calls'], gm['unresolved_calls']), (95, 1, 1))
        self.assertIn('95 + unknown', self.path.with_suffix('.md').read_text())
        for state, usage in [('unknown', None), ('not_sent', None),
                             ('measured', dict(input_tokens=89, output_tokens=5))]:
            with self.subTest(state=state), self.assertRaises(ValueError):
                self.book.record(*args, state, usage)
        self.book.record(*args, 'measured', dict(input_tokens=100, output_tokens=10))
        gm = next(a for a in self.book.snapshot()['actors'] if a['id'] == 'gm-01')
        self.assertEqual((gm['tokens']['total_tokens'], gm['unresolved_calls']), (110, 0))

    def test_native_recovery_uses_current_invocation_not_cumulative_other_turns(self):
        session = '11111111-1111-1111-1111-111111111111'
        root = self.root / 'sessions'
        directory = root / '2026/09/18'
        directory.mkdir(parents=True)
        rows = [dict(type='session_meta', payload=dict(id=session))]
        for time, count in [('09:00:00', 10000), ('10:00:01', 100), ('10:00:02', 150), ('10:02:00', 10000)]:
            rows.append(dict(type='token_usage_record', timestamp='2026-09-18T' + time + 'Z',
                payload=dict(thread_id=session, turn_token_usage=dict(input_tokens=count, output_tokens=10),
                             thread_token_usage=dict(input_tokens=count + 10000, output_tokens=1000))))
        (directory / ('rollout-fixture-' + session + '.jsonl')).write_text(
            '\n'.join(json.dumps(r) for r in rows) + '\n{"truncated":', encoding='utf-8')
        attempt = dict(thread_returned=session, started_utc='2026-09-18T10:00:00+00:00',
                       finished_utc='2026-09-18T10:01:30+00:00', usage_measured=False)
        self.assertEqual(native_usage_lower_bound(attempt, root)['input_tokens'], 150)
        self.book.begin_gm('run-partial', 'gm-01', 'observe')
        self.book.settle_gm('run-partial', 'gm-01', 'observe', attempt, root)
        gm = next(a for a in self.book.snapshot()['actors'] if a['id'] == 'gm-01')
        self.assertEqual(gm['tokens']['total_tokens'], 160)
        self.assertEqual(gm['unresolved_calls'], 1)

    def test_full_history_restore_rejects_reset_wrong_world_and_tampering(self):
        self.book.record('npc:1', 'ari', 'provider', 'model-a', 'decision', 'pending')
        self.measured()
        snapshot = self.book.snapshot()
        target = self.root / 'restored.sqlite3'
        restored = UsageBook.restore(target, 'world-a', snapshot)
        self.assertEqual(restored.snapshot(), snapshot)
        with self.assertRaises(ValueError): UsageBook.restore(target, 'world-a', snapshot)
        with self.assertRaises(ValueError): UsageBook.restore(self.root / 'wrong.sqlite3', 'world-b', snapshot)
        snapshot['calls'][0]['usage']['total_tokens'] += 1
        with self.assertRaises(ValueError): UsageBook.restore(self.root / 'bad.sqlite3', 'world-a', snapshot)
        self.assertFalse((self.root / 'bad.sqlite3').exists())

    def test_continued_world_cannot_silently_recreate_a_missing_usage_book(self):
        save = self.root / 'world.json'
        save.write_text(json.dumps(dict(world_id='world-a', life=dict(seq=43),
            residents=[dict(stable_id='ari', name='Ari')])), encoding='utf-8')
        with self.assertRaises(ValueError): for_world(save)
        self.assertFalse((self.root / 'developer-usage.sqlite3').exists())
        self.measured()
        UsageBook.restore(self.root / 'developer-usage.sqlite3', 'world-a', self.book.snapshot())
        self.assertEqual(next(a for a in for_world(save).snapshot()['actors'] if a['id']=='ari')['tokens']['total_tokens'],110)

    def test_existing_book_rebind_is_exact_audited_and_idempotent(self):
        world, state, snapshot, target, old = self.rebind_fixture()
        protected = {path: path.read_bytes() for path in (world, snapshot, target)}
        finished = subprocess.run([
            sys.executable, str(Path(__file__).with_name('actor_usage.py')),
            '--world', str(world), '--gm-state', str(state),
            '--rebind-existing-book-from-snapshot', str(snapshot),
        ], capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(finished.returncode, 0, finished.stderr)
        result = json.loads(finished.stdout)
        self.assertTrue(result['rebound'])
        self.assertFalse(result['idempotent'])
        self.assertEqual((result['actors'], result['calls'], result['revisions']), (2, 1, 2))
        saved = json.loads(state.read_text(encoding='utf-8'))
        self.assertEqual(Path(saved['developer_usage_book']), target.resolve())
        self.assertEqual(saved['developer_usage_book_rebindings'][0],
                         {'kind': 'older-audit', 'kept': True})
        audit = saved['developer_usage_book_rebindings'][1]
        self.assertEqual(audit['old_path'], str(old.resolve()))
        self.assertTrue(audit['old_path_absent'])
        self.assertEqual(audit['new_path'], str(target.resolve()))
        self.assertEqual(audit['history_sha256'], result['history_sha256'])
        self.assertEqual(audit['book_sha256'], result['book_sha256'])
        self.assertEqual(audit['snapshot_sha256'], result['snapshot_sha256'])
        for path, before in protected.items():
            self.assertEqual(path.read_bytes(), before, path)
        state_after = state.read_bytes()
        replay = rebind_existing_book(world, state, snapshot)
        self.assertFalse(replay['rebound'])
        self.assertTrue(replay['idempotent'])
        self.assertEqual(state.read_bytes(), state_after)
        self.assertEqual(json.loads(state.read_text())['developer_usage_book_rebindings'][1], audit)

    def test_existing_book_rebind_refuses_live_old_book_and_history_mismatch(self):
        world, state, snapshot, target, old = self.rebind_fixture('refusals')
        before = state.read_bytes()
        old.write_bytes(b'old book still exists')
        with self.assertRaisesRegex(ValueError, 'Prior developer usage book still exists'):
            rebind_existing_book(world, state, snapshot)
        self.assertEqual(state.read_bytes(), before)
        old.unlink()
        portable = json.loads(snapshot.read_text(encoding='utf-8'))
        portable['calls'][0]['status'] = 'unknown'
        snapshot.write_text(json.dumps(portable), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'history does not match'):
            rebind_existing_book(world, state, snapshot)
        self.assertEqual(state.read_bytes(), before)
        self.assertEqual(UsageBook(target, 'world-a').snapshot()['calls'][0]['status'], 'measured')

    def test_existing_book_rebind_honors_state_lock_and_world_identity(self):
        world, state, snapshot, _, _ = self.rebind_fixture('lock')
        before = state.read_bytes()
        with gm_runner.StateLock(state.parent, break_lock=False):
            with self.assertRaisesRegex(RuntimeError, 'a live run holds'):
                rebind_existing_book(world, state, snapshot)
        self.assertEqual(state.read_bytes(), before)
        document = json.loads(state.read_text(encoding='utf-8'))
        document['world_id'] = 'world-b'
        state.write_text(json.dumps(document), encoding='utf-8')
        mismatch = state.read_bytes()
        with self.assertRaisesRegex(ValueError, 'state and current world identity do not match'):
            rebind_existing_book(world, state, snapshot)
        self.assertEqual(state.read_bytes(), mismatch)


if __name__ == '__main__': unittest.main()
