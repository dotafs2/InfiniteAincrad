"""Compare a private continuation to its full source; emit only public-safe evidence."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path


def verify(source_raw, current_raw):
    source, current = json.loads(source_raw), json.loads(current_raw)
    seq = source['life']['seq']
    new_events = current['life']['events'][seq:]
    types = Counter(event['type'] for event in new_events)
    checks = {}
    checks['same_world'] = source['world_id'] == current['world_id']
    checks['source_hash'] = hashlib.sha256(source_raw).hexdigest() == current['godot']['source_sha256']
    checks['history_prefix_exact'] = current['life']['events'][:seq] == source['life']['events']
    checks['unported_life_fields_exact'] = all(current['life'][k] == v for k, v in source['life'].items() if k not in ('seq', 'events'))
    checks['unported_world_fields_exact'] = all(current[k] == v for k, v in source.items() if k not in ('life', 'residents', 'survival', 'foraging', 'elapsed_seconds'))
    checks['same_roster_order'] = [r['stable_id'] for r in source['residents']] == [r['stable_id'] for r in current['residents']]
    checks['identity_runtime_wallets_exact'] = all(
        all(new[k] == v for k, v in old.items() if k != 'needs') and
        all(new['needs'][k] == v for k, v in old['needs'].items() if k != 'hunger')
        for old, new in zip(source['residents'], current['residents']))
    old_food = sum(a['food'] for a in source['survival']['accounts'])
    new_food = sum(a['food'] for a in current['survival']['accounts'])
    checks['food_accounted'] = new_food == old_food + types['harvest_ration'] - types['eat_ration']
    berry = current['foraging']
    checks['berry_accounted'] = berry['stock'] == berry['initial_stock'] + berry['produced_total'] - berry['harvested_total']
    checks['new_actions_honestly_attributed'] = all(e['source'] == 'local_rule_policy' for e in new_events)
    return {'checks': checks, 'passed': all(checks.values()), 'original_identities': len(source['residents']),
            'active': len(current['survival']['accounts']), 'source_seq': seq, 'result_seq': current['life']['seq'],
            'new_event_types': dict(types), 'new_paid_calls': 0,
            'current_sha256': hashlib.sha256(current_raw).hexdigest(),
            'status': 'partial life port on a separate validation copy; not full migration or v1'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--current', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = verify(args.source.read_bytes(), args.current.read_bytes())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
