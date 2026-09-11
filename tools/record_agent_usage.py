"""Record usage increments from explicitly selected Codex rollout files, without emitting message text.

The local ledger stores cumulative high-water marks per rollout, so repeated snapshots
do not count twice. raw=input+output includes cached input; it is not a cost estimate.
Call between work batches. A due review is a checkpoint, not an automatic hard limiter.
"""
import argparse
import datetime as dt
import json
import sys
from pathlib import Path

FIELDS = ('input_tokens', 'cached_input_tokens', 'output_tokens', 'total_tokens')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--session', type=Path, action='append', required=True)
parser.add_argument('--ledger', type=Path, required=True)
parser.add_argument('--limit-raw', type=int, help='Fail the dispatch check if measured usage plus proposed reserve exceeds this batch limit.')
parser.add_argument('--reserve-raw', type=int, default=0, help='Planned next work including validation; a check, not a persisted reservation or transport interceptor.')
args = parser.parse_args()
if args.reserve_raw < 0 or (args.limit_raw is not None and args.limit_raw < 1):
    parser.error('Reserve must be nonnegative and limit positive.')
if args.reserve_raw and args.limit_raw is None:
    parser.error('--reserve-raw requires --limit-raw.')
ledger = json.loads(args.ledger.read_text(encoding='utf-8')) if args.ledger.exists() else {
    'schema_version': 1, 'review_interval_raw_tokens': 100_000_000,
    'reviewed_through_raw_tokens': 0, 'sessions': {}, 'totals': dict.fromkeys(FIELDS, 0), 'snapshots': []}
increment = dict.fromkeys(FIELDS, 0)
for session in args.session:
    latest = None
    with session.open(encoding='utf-8') as lines:
        for line in lines:
            record = json.loads(line)
            payload = record.get('payload', {})
            if record.get('type') == 'event_msg' and payload.get('type') == 'token_count':
                info = payload.get('info') or {}
                if info.get('total_token_usage'):
                    latest = info['total_token_usage']
    if latest is None or any(name not in latest for name in FIELDS):
        raise SystemExit(f'Usage unknown for {session.name}; ledger not written.')
    key = str(session.resolve())
    previous = ledger['sessions'].get(key, dict.fromkeys(FIELDS, 0))
    if any(latest[name] < previous[name] for name in FIELDS):
        raise SystemExit(f'Counter reset in {session.name}; reconcile before further dispatch.')
    for name in FIELDS:
        increment[name] += latest[name] - previous[name]
    ledger['sessions'][key] = {name: latest[name] for name in FIELDS}
for name in FIELDS:
    ledger['totals'][name] += increment[name]
snapshot = {'at_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'increment': increment,
            'review_due': ledger['totals']['total_tokens'] - ledger['reviewed_through_raw_tokens'] >= ledger['review_interval_raw_tokens']}
if any(increment.values()):
    ledger['snapshots'].append(snapshot)
args.ledger.parent.mkdir(parents=True, exist_ok=True)
temporary = args.ledger.with_suffix('.next.json')
temporary.write_text(json.dumps(ledger, indent=2) + '\n', encoding='utf-8')
temporary.replace(args.ledger)
allowed = args.limit_raw is None or ledger['totals']['total_tokens'] + args.reserve_raw <= args.limit_raw
print(json.dumps({'increment': increment, 'totals': ledger['totals'], 'review_due': snapshot['review_due'],
                  'dispatch_allowed': allowed, 'limit_raw': args.limit_raw, 'proposed_reserve_raw': args.reserve_raw,
                  'enforcement': 'pre_dispatch_check_only_not_model_transport_hard_limit'}))
sys.exit(0 if allowed else 3)
