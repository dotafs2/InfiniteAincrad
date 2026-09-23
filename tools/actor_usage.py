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
from datetime import datetime, timedelta, timezone
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


def file_sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def snapshot_history_sha256(snapshot):
    """Hash the complete portable history, excluding descriptive/report-only fields."""
    history = {key: snapshot.get(key) for key in ('actors', 'calls', 'revisions')}
    if any(not isinstance(history[key], list) for key in history):
        raise ValueError('Usage checkpoint needs actors, calls and revisions lists')
    return hashlib.sha256(encoded(history).encode('utf-8')).hexdigest()


def _snapshot_from_connection(db, world_id):
    actors = [dict(row) for row in db.execute('SELECT * FROM actors ORDER BY role,id')]
    calls = [dict(row) for row in db.execute('SELECT * FROM calls ORDER BY id')]
    revisions = [json.loads(row['receipt'])
                 for row in db.execute('SELECT receipt FROM revisions ORDER BY seq')]
    for row in calls:
        row['usage'] = json.loads(row['usage']) if row['usage'] else None
    for actor in actors:
        own = [row for row in calls if row['actor_id'] == actor['id']]
        measured = [row for row in own if row['status'] in ('measured', 'partial')]
        actor['usage_tag'] = world_id + '/' + actor['id']
        actor['measured_calls'] = sum(row['status'] == 'measured' for row in own)
        actor['partial_calls'] = sum(row['status'] == 'partial' for row in own)
        actor['unresolved_calls'] = sum(
            row['status'] in ('unknown', 'pending', 'partial') for row in own)
        actor['not_sent_calls'] = sum(row['status'] == 'not_sent' for row in own)
        actor['tokens'] = {
            key: sum(row['usage'].get(key) or 0 for row in measured)
            for key in FIELDS + ('total_tokens',)}
        actor['unknown_detail_calls'] = {
            key: sum(row['usage'].get(key) is None for row in measured) for key in FIELDS}
        actor['measured_charge_nano'] = sum(row['charge_nano'] or 0 for row in measured)
        actor['unpriced_measured_calls'] = sum(
            row['charge_nano'] is None for row in measured)
    return {'schema_version': 1, 'world_id': world_id, 'visibility': 'developer_only',
            'scope': 'From this world genesis; other worlds remain separate. Known subtotals include confirmed partial usage; unresolved remainders stay unknown.',
            'cached_tokens_are_part_of_input': True, 'actors': actors, 'calls': calls,
            'revisions': revisions}


def inspect_existing_book(path, world_id):
    """Read a bound UsageBook without running schema creation or another write statement."""
    path = Path(path).resolve()
    if not path.is_file():
        raise ValueError(f'Existing usage book not found: {path}')
    try:
        with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)) as db:
            db.row_factory = sqlite3.Row
            # Pin every table read below to one portable-history snapshot.  The
            # read-only connection may coexist with a WAL writer, so relying on
            # separate implicit SELECT transactions could mix revisions.
            db.execute('BEGIN')
            row = db.execute('SELECT world_id FROM meta WHERE id=1').fetchone()
            if row is None:
                raise ValueError('Existing usage book has no world identity')
            if row['world_id'] != world_id:
                raise ValueError('Existing usage book belongs to a different world')
            return _snapshot_from_connection(db, world_id)
    except sqlite3.Error as error:
        raise ValueError(f'Existing usage book is unreadable: {type(error).__name__}') from error


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

    def begin_gm(self, run_id, actor_id, phase, model='deepseek-flash'):
        self.record('gm:' + phase + ':' + run_id + ':' + actor_id, actor_id, 'native_gm',
                    model, phase, 'pending')

    def begin_npc(self, request_id, actor_id, model):
        with self.connect() as db:
            existing = db.execute('SELECT actor_id,model FROM calls WHERE id=?', ('npc:' + request_id,)).fetchone()
        if existing:
            if existing['actor_id'] != actor_id or existing['model'] != model:
                raise ValueError('NPC usage call identity conflict')
            return
        self.record('npc:' + request_id, actor_id, 'kimi_ledger', model, 'decision', 'pending')

    def settle_gm(self, run_id, actor_id, phase, attempt, sessions_root=None,
                  model='deepseek-flash'):
        # `run_codex_once` sets provider_request_started only after Popen succeeds. A local
        # executable-start failure therefore has no provider request to account for; preserve it
        # as an auditable not_sent receipt instead of poisoning the world with unknown usage.
        not_sent = bool(attempt.get('spawn_error')) \
            and attempt.get('provider_request_started') is False
        if not_sent:
            usage, status = None, 'not_sent'
        else:
            usage = attempt.get('usage') if attempt.get('usage_measured') else None
            status = 'measured' if usage is not None else 'unknown'
            if usage is None:
                usage = native_usage_lower_bound(attempt, sessions_root)
                if usage is not None:
                    status = 'partial'
        self.record('gm:' + phase + ':' + run_id + ':' + actor_id, actor_id, 'native_gm',
                    model, phase, status, usage)
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
            return _snapshot_from_connection(db, self.world_id)

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


def rebind_existing_book(world_path, gm_state_path, snapshot_path):
    """Move only a stale GM-state pointer to an already restored, identical UsageBook.

    The old book must be absent. The destination and portable snapshot are inspected read-only,
    and the authoritative GM state changes under its normal lock in one atomic replacement.
    """
    world_path = Path(world_path).resolve()
    gm_state_path = Path(gm_state_path).resolve()
    snapshot_path = Path(snapshot_path).resolve()
    if not world_path.is_file():
        raise ValueError(f'World save not found: {world_path}')
    if not gm_state_path.is_file():
        raise ValueError(f'GM state not found: {gm_state_path}')
    if not snapshot_path.is_file():
        raise ValueError(f'Usage rebind snapshot not found: {snapshot_path}')
    try:
        world = json.loads(world_path.read_text(encoding='utf-8-sig'))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError(f'World save is unreadable: {type(error).__name__}') from error
    world_id = world.get('world_id') if isinstance(world, dict) else None
    if not isinstance(world_id, str) or not world_id:
        raise ValueError('World save has no world identity')
    try:
        snapshot_bytes = snapshot_path.read_bytes()
        portable = json.loads(snapshot_bytes.decode('utf-8-sig'))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError(f'Usage rebind snapshot is unreadable: {type(error).__name__}') from error
    if not isinstance(portable, dict) or portable.get('schema_version') != 1:
        raise ValueError('Usage rebind snapshot has an unsupported schema')
    if portable.get('world_id') != world_id:
        raise ValueError('Usage rebind snapshot belongs to a different world')
    portable_history_sha = snapshot_history_sha256(portable)
    target = world_path.parent / 'developer-usage.sqlite3'
    target = target.resolve()

    # Imported lazily because gm_runner imports gm_book from this module.
    from gm_runner import StateLock
    with StateLock(gm_state_path.parent, break_lock=False):
        try:
            state = json.loads(gm_state_path.read_text(encoding='utf-8-sig'))
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise ValueError(f'GM state is unreadable: {type(error).__name__}') from error
        if not isinstance(state, dict) or state.get('world_id') != world_id:
            raise ValueError('GM state and current world identity do not match')
        prior_text = state.get('developer_usage_book')
        if not isinstance(prior_text, str) or not prior_text.strip():
            raise ValueError('GM state has no prior developer usage book binding')
        prior = Path(prior_text)
        if not prior.is_absolute():
            prior = gm_state_path.parent / prior
        prior = prior.resolve()
        if prior != target and prior.exists():
            raise ValueError(f'Prior developer usage book still exists: {prior}')

        existing = inspect_existing_book(target, world_id)
        existing_history_sha = snapshot_history_sha256(existing)
        if existing_history_sha != portable_history_sha or any(
                existing[key] != portable[key] for key in ('actors', 'calls', 'revisions')):
            raise ValueError('Existing usage book history does not match the portable snapshot')
        book_sha = file_sha256(target)
        snapshot_sha = hashlib.sha256(snapshot_bytes).hexdigest()
        counts = {key: len(existing[key]) for key in ('actors', 'calls', 'revisions')}
        audits = state.get('developer_usage_book_rebindings', [])
        if not isinstance(audits, list) or any(not isinstance(item, dict) for item in audits):
            raise ValueError('GM state usage rebind audit is malformed')

        if prior == target:
            matching = [item for item in audits
                        if item.get('new_path') == str(target)
                        and item.get('book_sha256') == book_sha
                        and item.get('snapshot_sha256') == snapshot_sha
                        and item.get('history_sha256') == existing_history_sha]
            if not matching:
                raise ValueError('GM state already points to this book without a matching immutable rebind audit')
            return {'world_id': world_id, 'old_path': matching[-1].get('old_path'),
                    'new_path': str(target), 'rebound': False, 'idempotent': True,
                    'book_sha256': book_sha, 'snapshot_sha256': snapshot_sha,
                    'history_sha256': existing_history_sha, **counts}
        audit = {'kind': 'developer_usage_book_rebind', 'world_id': world_id,
                 'old_path': str(prior), 'old_path_absent': True, 'new_path': str(target),
                 'book_sha256': book_sha, 'snapshot_path': str(snapshot_path),
                 'snapshot_sha256': snapshot_sha, 'history_sha256': existing_history_sha,
                 **counts, 'rebound_utc': datetime.now(timezone.utc).isoformat()}
        # Existing entries are copied unchanged and the new fact is appended once.
        state['developer_usage_book_rebindings'] = [*audits, audit]
        state['developer_usage_book'] = str(target)
        atomic_text(gm_state_path, json.dumps(state, ensure_ascii=False, indent=2) + '\n')
        return {'world_id': world_id, 'old_path': str(prior), 'new_path': str(target),
                'rebound': True, 'idempotent': False, 'book_sha256': book_sha,
                'snapshot_sha256': snapshot_sha, 'history_sha256': existing_history_sha,
                **counts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--world', type=Path, required=True)
    parser.add_argument('--gm-state', type=Path)
    parser.add_argument('--ledger', type=Path)
    parser.add_argument('--restore-snapshot', type=Path,
                        help='Portable developer usage JSON; only restores a missing local book')
    parser.add_argument('--rebind-existing-book-from-snapshot', type=Path,
                        help='Offline: rebind a stale absent GM-state pointer to the existing '
                             'same-world book after exact portable-history verification')
    parser.add_argument('--request-evidence-dir', type=Path,
                        help='Explicit prior episode request-bodies directory for exact call-ID attribution')
    args = parser.parse_args()
    if args.rebind_existing_book_from_snapshot:
        if not args.gm_state:
            parser.error('--rebind-existing-book-from-snapshot requires --gm-state')
        if args.restore_snapshot or args.request_evidence_dir or args.ledger:
            parser.error('usage-book rebind cannot be combined with restore or ledger backfill')
        result = rebind_existing_book(args.world, args.gm_state,
                                      args.rebind_existing_book_from_snapshot)
        print(json.dumps(result, ensure_ascii=True, sort_keys=True))
        return
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
