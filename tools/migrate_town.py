"""Preserve a complete UE town in a NEW private directory for Godot port validation.

Never replaces the source or silently resumes old pending routes/model requests.
All original JSON fields survive unchanged. Godot placement is an explicit new
layout mapping, not a claim to reproduce UE coordinates or complete migration.
"""
import argparse
import hashlib
import json
from pathlib import Path

PLACEMENTS = {
    'sao_inn_01': [-2.0, 0.22, 7.0],
    'sao_smithy_01': [4.0, 0.22, 7.0],
    'sao_carpentry_01': [-3.0, 0.22, 2.0],
}

def prepare(raw):
    world = json.loads(raw)
    required = {'world_id', 'schema_version', 'residents', 'life', 'survival', 'foraging', 'building_bindings'}
    if not required <= world.keys() or world['schema_version'] != 2 or 'godot' in world:
        raise ValueError('Expected a complete unconverted schema-2 source world')
    residents = world['residents']
    ids = [r['stable_id'] for r in residents]
    if not ids or len(set(ids)) != len(ids):
        raise ValueError('Missing/duplicate identities')
    events = world['life']['events']
    if [e['seq'] for e in events] != list(range(1, world['life']['seq'] + 1)):
        raise ValueError('Incomplete or nonconsecutive life event history')
    active = [a['resident_id'] for a in world['survival']['accounts']]
    if len(set(active)) != len(active) or not set(active) <= set(ids):
        raise ValueError('Invalid survival identities')
    bindings = {b['resident_id']: b['building_id'] for b in world['building_bindings']}
    homes = {r: PLACEMENTS[bindings[r]] for r in active}
    berry = world['foraging']
    if not (0 <= berry['stock'] <= berry['capacity'] and
            berry['stock'] == berry['initial_stock'] + berry['produced_total'] - berry['harvested_total']):
        raise ValueError('Foraging conservation failed')
    digest = hashlib.sha256(raw).hexdigest()
    world['godot'] = {
        'schema_version': 1, 'mode': 'migration_validation',
        'source_sha256': digest, 'source_life_seq': world['life']['seq'],
        'layout': 'market-life-port-1', 'positions': homes,
        'homes': homes.copy(), 'berry_position': [4.0, 0.22, 1.0],
        'pending': {}, 'commands': {}, 'new_events': [], 'elapsed_seconds': 0.0,
        'observations': {r: [] for r in active},
        'runtime_policy': 'UE runtime retained as historical data; no pending action or model request resumed',
    }
    return world, {
        'source_sha256': digest, 'world_id': world['world_id'],
        'source_life_seq': world['life']['seq'], 'identities_preserved': len(ids),
        'active_ids': active, 'all_original_fields_preserved': True,
        'status': 'separate migration-validation copy, not promoted maintained world',
        'unsupported_execution': ['UE coordinates/routes/camera geometry', 'pending UE operations',
                                  'pending UE repair/communication execution (history preserved; never auto-resumed)',
                                  'old private billing authorization and pending model requests'],
        'placement_change': 'Three work locations mapped to explicit Godot market anchors; old coordinates retained',
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='New PRIVATE directory outside game/')
    args = parser.parse_args()
    out = args.output.resolve()
    game = Path(__file__).resolve().parents[1] / 'game'
    if out == game or game in out.parents:
        parser.error('Private migration output must not be placed under the exportable game directory')
    raw = args.source.read_bytes()
    world, report = prepare(raw)
    encoded = json.dumps(world, ensure_ascii=False, indent=2).encode('utf-8')
    restored = json.loads(encoded)
    original = json.loads(raw)
    assert all(restored[k] == value for k, value in original.items())
    out.mkdir(parents=True, exist_ok=False)
    (out / 'source-world.json').write_bytes(raw)
    (out / 'world.json').write_bytes(encoded)
    (out / 'migration-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    assert args.source.read_bytes() == raw
    print(json.dumps(report, ensure_ascii=False))

if __name__ == '__main__':
    main()
