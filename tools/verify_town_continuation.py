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
    ported_life = {'seq', 'events', 'items', 'accounts', 'contracts'}
    checks['unported_life_fields_exact'] = all(
        current['life'][k] == value for k, value in source['life'].items()
        if k not in ported_life)
    checks['unported_world_fields_exact'] = all(current[k] == v for k, v in source.items() if k not in ('life', 'residents', 'survival', 'foraging', 'elapsed_seconds'))
    checks['same_roster_order'] = [r['stable_id'] for r in source['residents']] == [r['stable_id'] for r in current['residents']]
    checks['identity_runtime_fields_exact'] = all(
        all(new[k] == value for k, value in old.items() if k not in ('needs', 'coins_col')) and
        all(new['needs'][k] == value for k, value in old['needs'].items() if k != 'hunger')
        for old, new in zip(source['residents'], current['residents']))
    source_accounts = {a['resident_id']: a for a in source['life'].get('accounts', [])}
    current_accounts = {a['resident_id']: a for a in current['life'].get('accounts', [])}
    checks['same_work_accounts'] = source_accounts.keys() == current_accounts.keys()
    checks['unported_work_account_fields_exact'] = checks['same_work_accounts'] and all(
        all(current_accounts[resident_id][key] == value for key, value in account.items()
            if key not in ('wood', 'iron', 'reserved_col'))
        for resident_id, account in source_accounts.items())
    edge_work = sum(event.get('type') == 'work' and event.get('part') == 'edge'
                    for event in new_events)
    handle_work = sum(event.get('type') == 'work' and event.get('part') == 'handle'
                      for event in new_events)
    checks['repair_materials_accounted'] = checks['same_work_accounts'] and (
        sum(a['iron'] for a in current_accounts.values()) ==
        sum(a['iron'] for a in source_accounts.values()) - edge_work and
        sum(a['wood'] for a in current_accounts.values()) ==
        sum(a['wood'] for a in source_accounts.values()) - handle_work)
    source_items = {item['id']: item for item in source['life'].get('items', [])}
    current_items = {item['id']: item for item in current['life'].get('items', [])}
    checks['same_repair_items'] = source_items.keys() == current_items.keys()
    checks['repair_item_identity_exact'] = checks['same_repair_items'] and all(
        all(current_items[item_id][key] == value for key, value in item.items()
            if key not in ('edge', 'handle', 'custodian_id'))
        for item_id, item in source_items.items())
    repair_effects_ok = checks['same_repair_items']
    for item_id, item in source_items.items():
        for part in ('edge', 'handle'):
            repaired = any(event.get('type') == 'work' and event.get('item_id') == item_id
                           and event.get('part') == part for event in new_events)
            expected = 100 if repaired else item[part]
            repair_effects_ok = repair_effects_ok and current_items[item_id][part] == expected
    checks['repair_item_effects_accounted'] = repair_effects_ok
    source_contracts = source['life'].get('contracts', [])
    current_contracts = current['life'].get('contracts', [])
    new_contracts = current_contracts[len(source_contracts):]
    checks['source_contracts_exact'] = current_contracts[:len(source_contracts)] == source_contracts
    checks['new_contracts_valid'] = all(
        str(contract.get('id', '')).startswith('godot_repair:') and
        contract.get('status') in ('proposed', 'accepted', 'delivered', 'completed',
                                   'collected', 'rejected') and
        contract.get('price_col') in (2, 5, 8) and
        contract.get('reserved_col') == (contract['price_col'] if contract['status'] in
                                         ('accepted', 'delivered', 'completed') else 0)
        for contract in new_contracts)
    custody_ok = checks['same_repair_items']
    for item_id, item in source_items.items():
        related = [contract for contract in new_contracts if contract.get('item_id') == item_id]
        expected = item['custodian_id']
        if related:
            latest = related[-1]
            expected = (latest['worker_id'] if latest['status'] in ('delivered', 'completed')
                        else latest['owner_id'])
        custody_ok = custody_ok and current_items[item_id]['custodian_id'] == expected
    checks['repair_custody_accounted'] = custody_ok
    source_money = (sum(r['coins_col'] for r in source['residents']) +
                    sum(a.get('reserved_col', 0) for a in source_accounts.values()))
    current_money = (sum(r['coins_col'] for r in current['residents']) +
                     sum(a.get('reserved_col', 0) for a in current_accounts.values()))
    checks['money_accounted'] = source_money == current_money
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
