"""Exact world checkpoints and evidence-only resident decision reports. No model calls.

A checkpoint preserves every life sequence and the entire reply archive, including
rejected replies. It never resets a world, creates a fee ledger or exports credentials.
"""
import argparse
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def decode(raw):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate JSON field')
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=unique,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError('Non-finite JSON number')))


def validate_world(world):
    if not isinstance(world, dict) or world.get('schema_version') != 2 or not isinstance(world.get('world_id'), str):
        raise ValueError('Expected a complete schema-2 world')
    life = world.get('life', {})
    seq, events = life.get('seq'), life.get('events')
    if type(seq) is not int or seq < 0 or not isinstance(events, list):
        raise ValueError('Invalid life sequence')
    if [e.get('seq') if isinstance(e, dict) else None for e in events] != list(range(1, seq + 1)):
        raise ValueError('Full consecutive life history is required')
    residents = world.get('residents')
    if not isinstance(residents, list) or not residents or not all(isinstance(r, dict) and isinstance(r.get('stable_id'), str) for r in residents):
        raise ValueError('Missing resident identities')
    ids = [r['stable_id'] for r in residents]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate resident identities')
    if not isinstance(world.get('godot'), dict):
        raise ValueError('Missing runtime state')
    archive = world['godot'].get('resident_archive', {})
    if archive:
        entries, order = archive.get('entries'), archive.get('order')
        if archive.get('world_id') != world['world_id'] or not isinstance(entries, dict) or not isinstance(order, list):
            raise ValueError('Invalid resident archive')
        if not all(isinstance(k, str) for k in order) or len(set(order)) != len(order) or set(order) != set(entries):
            raise ValueError('Incomplete resident archive order')
        for key, entry in entries.items():
            if not isinstance(entry, dict) or entry.get('request_id') != key or entry.get('resident_id') not in ids or entry.get('world_id') != world['world_id']:
                raise ValueError('Resident archive identity mismatch')
    return world


def reject_credentials(value):
    """Fail instead of redacting a canonical checkpoint and calling it complete."""
    if isinstance(value, dict):
        for key, child in value.items():
            if key.lower() in ('api_key', 'apikey', 'authorization', 'access_token', 'refresh_token', 'client_secret'):
                raise ValueError('Credential field found; checkpoint not published')
            reject_credentials(child)
    elif isinstance(value, list):
        for child in value:
            reject_credentials(child)


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


def assert_continuation(previous, current):
    if previous['world_id'] != current['world_id']:
        raise ValueError('Different worlds must never share a checkpoint lineage')
    n = previous['life']['seq']
    if current['life']['seq'] < n or canonical(current['life']['events'][:n]) != canonical(previous['life']['events']):
        raise ValueError('Earlier life sequences were removed or changed')
    old_ids = {r['stable_id'] for r in previous['residents']}
    if not old_ids <= {r['stable_id'] for r in current['residents']}:
        raise ValueError('Earlier resident identities disappeared')
    old_archive = previous['godot'].get('resident_archive', {})
    new_archive = current['godot'].get('resident_archive', {})
    old_order = old_archive.get('order', [])
    if new_archive.get('order', [])[:len(old_order)] != old_order:
        raise ValueError('Earlier decision archive order changed')
    for key, old in old_archive.get('entries', {}).items():
        new = new_archive.get('entries', {}).get(key)
        if not isinstance(new, dict):
            raise ValueError('Earlier decision archive entry disappeared')
        # Runtime may append conflicting replay evidence, but cannot replace the original.
        old_base = {k: v for k, v in old.items() if k != 'replays'}
        new_base = {k: v for k, v in new.items() if k != 'replays'}
        old_replays, new_replays = old.get('replays', []), new.get('replays', [])
        if canonical(old_base) != canonical(new_base) or canonical(new_replays[:len(old_replays)]) != canonical(old_replays):
            raise ValueError('Earlier decision evidence changed')


def checkpoint(source, out):
    """Write byte-exact, immutable checkpoints; only the verified latest pointer advances."""
    source, out = Path(source).resolve(), Path(out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    lock = out / '.checkpoint.lock'
    try:
        owner = lock.open('x', encoding='utf-8')
    except FileExistsError:
        raise ValueError('Checkpoint publisher is already active or requires crash recovery') from None
    try:
        with owner:
            return _checkpoint_locked(source, out)
    finally:
        lock.unlink()


def _checkpoint_locked(source, out):
    raw = source.read_bytes()
    world = validate_world(decode(raw))
    reject_credentials(world)
    index_path = out / 'manifest.json'
    if index_path.exists():
        index = decode(index_path.read_bytes())
        if index.get('schema_version') != 1 or index.get('world_id') != world['world_id']:
            raise ValueError('Checkpoint manifest identity mismatch')
        latest = index['checkpoints'][-1]
        name = latest['file']
        if not isinstance(name, str) or Path(name).name != name or '/' in name or '\\' in name:
            raise ValueError('Invalid checkpoint filename')
        old_raw = (out / name).read_bytes()
        if digest(old_raw) != latest['sha256']:
            raise ValueError('Previous checkpoint checksum mismatch')
        assert_continuation(validate_world(decode(old_raw)), world)
        if digest(raw) == latest['sha256']:
            return index
    else:
        index = {'schema_version': 1, 'world_id': world['world_id'], 'checkpoints': []}
    sha = digest(raw)
    name = f"seq{world['life']['seq']:06d}-{sha[:16]}.world.json"
    out.mkdir(parents=True, exist_ok=True)
    target = out / name
    if target.exists():
        if target.read_bytes() != raw:
            raise ValueError('Checkpoint collision')
    else:
        with target.open('xb') as stream:
            stream.write(raw)
    index['checkpoints'].append({'seq': world['life']['seq'], 'file': name, 'sha256': sha,
                                 'created_utc': datetime.now(timezone.utc).isoformat(),
                                 'resident_count': len(world['residents']),
                                 'archive_count': len(world['godot'].get('resident_archive', {}).get('order', [])),
                                 'full_history_preserved': True})
    temp = index_path.with_name('manifest.pending.json')
    with temp.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    temp.replace(index_path)
    return index


def observe(world, baseline=None):
    """Return every decision, public delivery and actual operation outcome without invented thoughts."""
    validate_world(world)
    if baseline is not None:
        validate_world(baseline)
        assert_continuation(baseline, world)
    old_keys = set((baseline or {}).get('godot', {}).get('resident_archive', {}).get('order', []))
    start_seq = (baseline or {}).get('life', {}).get('seq', 0)
    archive = world['godot'].get('resident_archive', {})
    turns = world['godot'].get('resident_turns', {})
    events = world['life']['events']
    by_id = {r['stable_id']: {'resident_id': r['stable_id'], 'name': r['name'], 'decisions': [],
                            'controller_status': turns.get(r['stable_id'], {}).get('status', 'not_started'),
                            'pending_job': deepcopy(world['godot'].get('pending', {}).get(r['stable_id'], {})),
                            'module_jobs': {module: deepcopy(world['godot'].get(module, {}).get('jobs', {}).get(r['stable_id'], {}))
                                            for module in ('materials', 'baking')}}
             for r in world['residents']}
    for key in archive.get('order', []):
        if key in old_keys:
            continue
        entry = archive['entries'][key]
        resident_id = entry['resident_id']
        original = entry.get('original_reply', {})
        choice = original.get('decision', {})
        if not isinstance(choice, dict):
            choice = {}
        history = turns.get(resident_id, {}).get('history', [])
        history_row = next((h for h in history if h.get('command_id') == key), {})
        application = entry.get('application', {})
        delivery = application.get('speech_delivery', {})
        matching = [deepcopy(e) for e in events if e.get('operation_id') == key or e.get('command_id') == key]
        delivered_seq = delivery.get('event_seq')
        actual_speech = next((e for e in events if delivery.get('delivered') is True
                              and e.get('seq') == delivered_seq and e.get('actor_id') == resident_id
                              and e.get('operation_id') == key and e.get('text') == delivery.get('text')), None)
        command = world['godot'].get('commands', {}).get(key, {})
        trade_command = world['godot'].get('trade', {}).get('commands', {}).get(key, {})
        row = {'request_id': key, 'provider': entry.get('provider_id', ''),
               'model_returned': entry.get('model_returned', False),
               'decision': deepcopy(choice), 'resolved_action': history_row.get('action'),
               'stated_reason': entry.get('reason', ''),
               'proposed_speech': entry.get('speech', ''),
               'actually_spoken': actual_speech.get('text') if actual_speech else None,
               'speech_event_seq': actual_speech.get('seq') if actual_speech else None,
               'recipients': actual_speech.get('recipient_ids', []) if actual_speech else [],
               'application': deepcopy(application), 'later_events': matching,
               'current_command_status': command.get('status'),
               'current_trade_command_status': trade_command.get('status'),
               'module_command_status': {module: world['godot'].get(module, {}).get('commands', {}).get(key, {}).get('status')
                                         for module in ('materials', 'baking')},
               'replay_count': len(entry.get('replays', [])),
               'complete_archive': entry.get('complete', True),
               'interpretation': 'Stated reason is model output, not access to hidden thought; action acceptance is not proof of job completion.'}
        by_id[resident_id]['decisions'].append(row)
    return {'schema_version': 1, 'world_id': world['world_id'], 'start_seq': start_seq,
            'end_seq': world['life']['seq'], 'elapsed_seconds': world['godot'].get('elapsed_seconds'),
            'decision_count': sum(len(p['decisions']) for p in by_id.values()),
            'residents': list(by_id.values()), 'new_world_events': deepcopy(events[start_seq:]),
            'limitation': 'No decisions or speech are inferred from a personality profile. A pending provider request has no known decision.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--checkpoint-dir', type=Path)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--baseline', type=Path)
    args = parser.parse_args()
    if not args.checkpoint_dir and not args.report:
        parser.error('Choose a checkpoint directory, a report, or both.')
    result = {}
    if args.checkpoint_dir:
        result['checkpoint'] = checkpoint(args.source, args.checkpoint_dir)['checkpoints'][-1]
    if args.report:
        world = decode(args.source.read_bytes())
        baseline = decode(args.baseline.read_bytes()) if args.baseline else None
        report = observe(world, baseline)
        reject_credentials(report)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
        result['report'] = {'path': str(args.report), 'decisions': report['decision_count'], 'residents': len(report['residents'])}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
