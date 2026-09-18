"""Permanent developer-only, world-scoped usage identities. Not a billing reset.

Each provider call has one durable identity and append-only revisions. Measured
totals survive restarts; unknown usage is never converted to zero. Cached tokens
are a subset of input. This store contains no prompts, replies or credentials.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import tempfile
from contextlib import contextmanager, closing
from datetime import datetime, timedelta
from pathlib import Path

FIELDS = ('input_tokens', 'output_tokens', 'cached_input_tokens', 'reasoning_output_tokens')


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def atomic_text(target, text):
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix=target.name, suffix='.tmp', delete=False) as handle:
        temporary = Path(handle.name)
    try:
        temporary.write_text(text, encoding='utf-8')
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)


def native_usage_lower_bound(attempt, sessions_root):
    """Read only exact-session counters for this invocation, never publish its transcript."""
    session = attempt.get('thread_returned')
    if not sessions_root or not re.fullmatch(r'[0-9a-f-]{36}', session or '') or not attempt.get('started_utc'):
        return None
    started = datetime.fromisoformat(attempt['started_utc'].replace('Z', '+00:00'))
    finished = (datetime.fromisoformat(attempt['finished_utc'].replace('Z', '+00:00'))
                if attempt.get('finished_utc') else None)
    candidates = []
    for offset in (-1, 0, 1):
        day = (started + timedelta(days=offset)).strftime('%Y/%m/%d')
        candidates.extend((Path(sessions_root) / day).glob('rollout-*-' + session + '.jsonl'))
    if len(candidates) != 1 or candidates[0].stat().st_size > 16_000_000:
        return None
    latest = None
    with candidates[0].open(encoding='utf-8') as handle:
        first = json.loads(handle.readline())
        if first.get('type') != 'session_meta' or first.get('payload', {}).get('id') != session:
            return None
        for line in handle:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue  # An interrupted writer can leave an incomplete final line.
            if row.get('type') != 'token_usage_record' or not row.get('timestamp'):
                continue
            stamp = datetime.fromisoformat(row['timestamp'].replace('Z', '+00:00'))
            if stamp < started or (finished is not None and stamp > finished):
                continue
            payload = row.get('payload') or {}
            if payload.get('thread_id') == session and isinstance(payload.get('turn_token_usage'), dict):
                latest = {key: payload['turn_token_usage'].get(key) for key in FIELDS}
    return latest


class UsageBook:
    def __init__(self, path, world_id, actors=None):
        self.path = Path(path).resolve()
        self.world_id = world_id
        if not self.path.exists() and actors is None:
            raise ValueError('Usage book must first be bound to this world and its actors')
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS meta (id INTEGER PRIMARY KEY CHECK(id=1), world_id TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS actors (id TEXT PRIMARY KEY, role TEXT NOT NULL, name TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS calls (id TEXT PRIMARY KEY, actor_id TEXT NOT NULL, source TEXT NOT NULL,
                    model TEXT NOT NULL, phase TEXT NOT NULL, status TEXT NOT NULL, usage TEXT, charge_nano INTEGER);
                CREATE TABLE IF NOT EXISTS revisions (seq INTEGER PRIMARY KEY, call_id TEXT NOT NULL,
                    receipt_sha256 TEXT NOT NULL, receipt TEXT NOT NULL, UNIQUE(call_id,receipt_sha256));
            ''')
            row = db.execute('SELECT world_id FROM meta WHERE id=1').fetchone()
            if row is None:
                db.execute('INSERT INTO meta VALUES(1,?)', (world_id,))
            elif row['world_id'] != world_id:
                raise ValueError('Usage book belongs to a different world')
            for actor in actors or []:
                old = db.execute('SELECT * FROM actors WHERE id=?', (actor['id'],)).fetchone()
                if old and old['role'] != actor['role']:
                    raise ValueError('Stable usage identity cannot change roles')
                db.execute('INSERT OR IGNORE INTO actors VALUES(?,?,?)',
                           (actor['id'], actor['role'], actor['name']))

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def record(self, call_id, actor_id, source, model, phase, status, usage=None, charge_nano=None):
        if status not in ('pending', 'unknown', 'partial', 'measured', 'not_sent'):
            raise ValueError('Invalid usage status')
        if status in ('measured', 'partial'):
            if not isinstance(usage, dict):
                raise ValueError('Measured usage needs provider counters')
            for field in FIELDS:
                value = usage.get(field)
                if value is not None and (type(value) is not int or value < 0):
                    raise ValueError('Invalid provider token counter')
            if any(type(usage.get(k)) is not int for k in FIELDS[:2]):
                raise ValueError('Input and output counters are required')
            if usage.get('cached_input_tokens', 0) is not None and usage.get('cached_input_tokens', 0) > usage['input_tokens']:
                raise ValueError('Cached tokens cannot exceed input')
            if usage.get('reasoning_output_tokens', 0) is not None and usage.get('reasoning_output_tokens', 0) > usage['output_tokens']:
                raise ValueError('Reasoning tokens cannot exceed output')
            usage = {key: usage.get(key) for key in FIELDS}
            usage['total_tokens'] = usage['input_tokens'] + usage['output_tokens']
        elif usage is not None or charge_nano is not None:
            raise ValueError('Unmeasured call cannot invent counters or cost')
        if charge_nano is not None and (type(charge_nano) is not int or charge_nano < 0):
            raise ValueError('Invalid measured charge')
        if status == 'partial' and charge_nano is not None:
            raise ValueError('Partial usage cannot establish a final charge')
        receipt = dict(call_id=call_id, actor_id=actor_id, source=source, model=model,
                       phase=phase, status=status, usage=usage, charge_nano=charge_nano)
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            if not db.execute('SELECT 1 FROM actors WHERE id=?', (actor_id,)).fetchone():
                raise ValueError('Unregistered actor cannot receive another identity\'s usage')
            old = db.execute('SELECT * FROM calls WHERE id=?', (call_id,)).fetchone()
            if old:
                if any(old[k] != receipt[k] for k in ('actor_id', 'source', 'model', 'phase')):
                    raise ValueError('Usage call identity conflict')
                if old['status'] in ('measured', 'not_sent'):
                    if (old['status'] != status or old['usage'] != (encoded(usage) if usage else None)
                            or old['charge_nano'] != charge_nano):
                        raise ValueError('A finalized usage receipt cannot be replaced')
                    return
                if old['status'] == 'unknown' and status in ('pending', 'not_sent'):
                    raise ValueError('Unknown usage needs a measured receipt, never a retry or zero-cost reset')
                if old['status'] == 'partial':
                    before = json.loads(old['usage'])
                    if status not in ('partial', 'measured') or any(
                            before.get(key) is not None and (usage.get(key) is None or usage[key] < before[key])
                            for key in FIELDS):
                        raise ValueError('Confirmed partial counters cannot decrease or disappear')
            data = encoded(receipt)
            db.execute('INSERT OR IGNORE INTO revisions(call_id,receipt_sha256,receipt) VALUES(?,?,?)',
                       (call_id, hashlib.sha256(data.encode()).hexdigest(), data))
            db.execute('INSERT OR REPLACE INTO calls VALUES(?,?,?,?,?,?,?,?)',
                       (call_id, actor_id, source, model, phase, status,
                        encoded(usage) if usage else None, charge_nano))

    def begin_gm(self, run_id, actor_id, phase):
        self.record('gm:' + phase + ':' + run_id + ':' + actor_id, actor_id, 'native_gm',
                    'deepseek-flash', phase, 'pending')

    def begin_npc(self, request_id, actor_id, model):
        with self.connect() as db:
            existing = db.execute('SELECT actor_id,model FROM calls WHERE id=?', ('npc:' + request_id,)).fetchone()
        if existing:
            if existing['actor_id'] != actor_id or existing['model'] != model:
                raise ValueError('NPC usage call identity conflict')
            return
        self.record('npc:' + request_id, actor_id, 'kimi_ledger', model, 'decision', 'pending')

    def settle_gm(self, run_id, actor_id, phase, attempt, sessions_root=None):
        usage = attempt.get('usage') if attempt.get('usage_measured') else None
        status = 'measured' if usage is not None else 'unknown'
        if usage is None:
            usage = native_usage_lower_bound(attempt, sessions_root)
            if usage is not None:
                status = 'partial'
        self.record('gm:' + phase + ':' + run_id + ':' + actor_id, actor_id, 'native_gm',
                    'deepseek-flash', phase, status, usage)
        self.export()

    def sync_kimi_call(self, ledger_path, request_id, actor_id=None, model='kimi-k2.6'):
        # Read only the exact already-recorded provider receipt, never the prompt/response.
        with closing(sqlite3.connect(Path(ledger_path).resolve().as_uri() + '?mode=ro', uri=True)) as db:
            db.row_factory = sqlite3.Row
            row = db.execute('SELECT id,resident,state,prompt_tokens,output_tokens,cached_tokens,charge '
                             'FROM requests WHERE id=?', (request_id,)).fetchone()
        if row is None:
            if actor_id is not None:
                self.record('npc:' + request_id, actor_id, 'kimi_ledger', model, 'decision', 'not_sent')
            return
        if actor_id is not None and row['resident'] != actor_id:
            raise ValueError('Ledger resident does not match the world usage identity')
        measured = row['state'] == 'settled'
        usage = dict(input_tokens=row['prompt_tokens'], output_tokens=row['output_tokens'],
                     cached_input_tokens=row['cached_tokens']) if measured else None
        self.record('npc:' + request_id, row['resident'], 'kimi_ledger', model, 'decision',
                    'measured' if measured else 'unknown', usage, row['charge'] if measured else None)

    def snapshot(self):
        with self.connect() as db:
            db.execute('BEGIN')
            actors = [dict(r) for r in db.execute('SELECT * FROM actors ORDER BY role,id')]
            calls = [dict(r) for r in db.execute('SELECT * FROM calls ORDER BY id')]
            revisions = [json.loads(r['receipt']) for r in db.execute('SELECT receipt FROM revisions ORDER BY seq')]
        for row in calls:
            row['usage'] = json.loads(row['usage']) if row['usage'] else None
        for actor in actors:
            own = [r for r in calls if r['actor_id'] == actor['id']]
            measured = [r for r in own if r['status'] in ('measured', 'partial')]
            actor['usage_tag'] = self.world_id + '/' + actor['id']
            actor['measured_calls'] = sum(r['status'] == 'measured' for r in own)
            actor['partial_calls'] = sum(r['status'] == 'partial' for r in own)
            actor['unresolved_calls'] = sum(r['status'] in ('unknown', 'pending', 'partial') for r in own)
            actor['not_sent_calls'] = sum(r['status'] == 'not_sent' for r in own)
            actor['tokens'] = {k: sum(r['usage'].get(k) or 0 for r in measured) for k in FIELDS + ('total_tokens',)}
            actor['unknown_detail_calls'] = {k: sum(r['usage'].get(k) is None for r in measured) for k in FIELDS}
            actor['measured_charge_nano'] = sum(r['charge_nano'] or 0 for r in measured)
            actor['unpriced_measured_calls'] = sum(r['charge_nano'] is None for r in measured)
        return {'schema_version': 1, 'world_id': self.world_id, 'visibility': 'developer_only',
                'scope': 'From this world genesis; other worlds remain separate. Known subtotals include confirmed partial usage; unresolved remainders stay unknown.',
                'cached_tokens_are_part_of_input': True, 'actors': actors, 'calls': calls, 'revisions': revisions}

    @classmethod
    def restore(cls, path, world_id, snapshot):
        """Restore a portable full-history checkpoint into a new local book only."""
        path = Path(path).resolve()
        if path.exists():
            raise ValueError('Restore cannot replace an existing permanent usage book')
        if snapshot.get('schema_version') != 1 or snapshot.get('world_id') != world_id:
            raise ValueError('Usage checkpoint schema or world mismatch')
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=path.parent, prefix='usage-restore-') as temporary:
            candidate = cls(Path(temporary) / 'book.sqlite3', world_id, snapshot['actors'])
            for receipt in snapshot['revisions']:
                candidate.record(**receipt)
            actual = candidate.snapshot()
            if any(actual[key] != snapshot[key] for key in ('actors', 'calls', 'revisions')):
                raise ValueError('Usage checkpoint counters or receipts disagree with its full history')
            # Same-filesystem hard link publishes the complete DB atomically without replacement.
            os.link(candidate.path, path)
        return cls(path, world_id)

    def export(self):
        data = self.snapshot()
        target = self.path.with_suffix('.json')
        atomic_text(target, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        lines = ['# Developer usage tags', '', '`' + self.world_id + '`', '',
                 'Permanent totals since this world began. Cached input is already included in input.',
                 'Unknown usage stays unresolved. This report is never an NPC observation or model input.', '',
                 '| Name | Role | Completed / partial usage | Input | Output | Cached input | Known subtotal | Unresolved |',
                 '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |']
        for a in data['actors']:
            t = a['tokens']
            subtotal = f"{t['total_tokens']:,}" + (' + unknown' if a['unresolved_calls'] else '')
            cached = f"{t['cached_input_tokens']:,}" + (' + unknown' if a['unknown_detail_calls']['cached_input_tokens'] else '')
            lines.append(f"| {a['name']} | {a['role']} | {a['measured_calls']} / {a['partial_calls']} | {t['input_tokens']:,} | {t['output_tokens']:,} | {cached} | {subtotal} | {a['unresolved_calls']} |")
        lines += ['', 'Stable identity tags and exact per-call receipts are in the adjacent JSON file.',
                  'Tokens do not by themselves establish a currency charge. Missing detailed counters stay marked unknown in JSON.', '']
        atomic_text(target.with_suffix('.md'), '\n'.join(lines))
        return data


def for_world(save_path, initialize_from_evidence=False):
    save = Path(save_path).resolve()
    world = json.loads(save.read_text(encoding='utf-8'))
    target = save.parent / 'developer-usage.sqlite3'
    continued = (world.get('life', {}).get('seq', 0) > 0 or
                 bool(world.get('godot', {}).get('resident_archive', {}).get('entries')))
    if not target.exists() and continued and not initialize_from_evidence:
        raise ValueError('Continued world needs its usage checkpoint or explicit evidence backfill; refusing zero totals')
    actors = [dict(id=r['stable_id'], role='NPC', name=r['name']) for r in world['residents']]
    actors += [dict(id=f'gm-{i:02}', role='GM', name=f'GM {i:02}') for i in range(1, 11)]
    return UsageBook(target, world['world_id'], actors)


def gm_book(state):
    path = state.get('developer_usage_book')
    return UsageBook(path, state['world_id']) if path else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--world', type=Path, required=True)
    parser.add_argument('--gm-state', type=Path)
    parser.add_argument('--ledger', type=Path)
    parser.add_argument('--restore-snapshot', type=Path,
                        help='Portable developer usage JSON; only restores a missing local book')
    parser.add_argument('--request-evidence-dir', type=Path,
                        help='Explicit prior episode request-bodies directory for exact call-ID attribution')
    args = parser.parse_args()
    if args.restore_snapshot:
        world = json.loads(args.world.read_text(encoding='utf-8'))
        UsageBook.restore(args.world.resolve().parent / 'developer-usage.sqlite3', world['world_id'],
                          json.loads(args.restore_snapshot.read_text(encoding='utf-8')))
    if args.request_evidence_dir and not args.ledger:
        parser.error('--ledger is required for backfill')
    book = for_world(args.world, initialize_from_evidence=bool(args.request_evidence_dir))
    if args.gm_state:
        from gm_runner import StateLock
        with StateLock(args.gm_state.parent, break_lock=False):
            state = json.loads(args.gm_state.read_text(encoding='utf-8'))
            if state.get('world_id') != book.world_id:
                raise ValueError('GM state belongs to another world')
            prior = state.get('developer_usage_book')
            if prior and Path(prior).resolve() != book.path and not args.restore_snapshot:
                raise ValueError('Refusing to replace another permanent usage book')
            state['developer_usage_book'] = str(book.path)
            atomic_text(args.gm_state, json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    if args.request_evidence_dir:
        if not args.ledger:
            parser.error('--ledger is required for backfill')
        capture = json.loads((args.request_evidence_dir.parent / 'capture/evidence.json').read_text(encoding='utf-8'))
        if capture.get('world_id') != book.world_id:
            raise ValueError('Backfill episode does not prove this world identity')
        paths = list(args.request_evidence_dir.glob('*.json'))
        if len(paths) > 1000:
            raise ValueError('Import one bounded episode at a time')
        for path in paths:
            if path.stat().st_size > 100_000:
                raise ValueError('Request evidence exceeds bounded size')
            record = json.loads(path.read_text(encoding='utf-8'))
            book.sync_kimi_call(args.ledger, record['operation'], record['resident'], record['body']['model'])
    data = book.export()
    print(json.dumps({'world_id': book.world_id, 'actors': len(data['actors']),
                      'calls': len(data['calls']), 'book': str(book.path)}))


if __name__ == '__main__':
    main()
