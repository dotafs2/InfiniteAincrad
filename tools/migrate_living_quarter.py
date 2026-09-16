"""Explicit spatial migration; never rewrites a resident, ledger or historical coordinate."""
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / 'game/spatial/living_quarter_layout.json'


def terrain_vertex(layout, x, z):
    height = (max(abs(x)-53, 0)/15)**1.35 * (2+.55*math.sin(z*.065))
    height += (max(z-104, 0)/17)**1.4 * 1.5
    for house in layout['houses'] + layout['infill']:
        hx, hy, hz = house['at']
        if hy <= 0:
            continue
        t = min(1, max(0, (math.hypot(x-hx, z-hz)-6)/6))
        height = max(height, hy*(1-t*t*(3-2*t)))
    return height


def terrain_height(layout, x, z):
    # Exactly the piecewise linear two-metre triangles built by living_quarter.gd.
    x0, z0 = math.floor(x/2)*2, math.floor(z/2)*2
    u, v = (x-x0)/2, (z-z0)/2
    a, b, c, d = [terrain_vertex(layout, px, pz) for px, pz in
                  [(x0,z0), (x0+2,z0), (x0,z0+2), (x0+2,z0+2)]]
    return a+(b-a)*u+(c-a)*v if u+v <= 1 else d+(c-d)*(1-u)+(b-d)*(1-v)


def migrate(source, destination):
    raw = source.read_bytes()
    state = json.loads(raw)
    layout = json.loads(LAYOUT.read_text(encoding='utf-8'))
    g = state['godot']
    if g.get('spatial_layout'):
        raise ValueError('Already migrated: refusing a second relocation')
    if g.get('pending') or g.get('trade', {}).get('jobs') or g.get('places', {}).get('jobs'):
        raise ValueError('Active journeys need an explicit target migration; refusing to discard them')
    result = copy.deepcopy(state)
    target = result['godot']
    residents = {r['stable_id']: r for r in state['residents']}
    mapped = []
    for i, house in enumerate(layout['houses']):
        resident = house['resident']
        if resident not in residents:
            raise ValueError(f'Missing resident {resident}')
        # Unobstructed indoor point on the entrance-to-room circulation line.
        dx, dz = {'01_hearth_cottage': (0, 1.1), '02_market_house': (-.9, 1.2),
                  '03_corner_turret': (2.2, .7)}[house['variant']]
        x, y, z = house['at']
        a = math.radians(house['yaw'])
        home = [x + dx * math.cos(a) + dz * math.sin(a), y + .045,
                z - dx * math.sin(a) + dz * math.cos(a)]
        target['homes'][resident] = home
        spawn = list(layout['spawn_points'][i])
        spawn[1] = terrain_height(layout, spawn[0], spawn[2]) + .06
        target['positions'][resident] = spawn
        mapped.append({'id': resident, 'name': residents[resident]['name'],
                       'home_before': g['homes'][resident], 'home_after': home,
                       'position_before': g['positions'][resident],
                       'position_after': target['positions'][resident]})
    if set(h['resident'] for h in layout['houses']) != set(g['homes']):
        raise ValueError('Roster differs from the reviewed ten-resident layout')
    target['berry_position'] = layout['berry_position']
    old_center = g['berry_position']
    delta = [b-a for a, b in zip(old_center, target['berry_position'])]
    spots = target['foraging_work_spots']['positions']
    for resident, point in spots.items():
        moved = [round(a+b, 8) for a, b in zip(point, delta)]
        moved[1] = terrain_height(layout, moved[0], moved[2]) + .005
        spots[resident] = moved
    target['spatial_layout'] = {'id': layout['id'], 'source_sha256': hashlib.sha256(raw).hexdigest(),
                              'layout_sha256': hashlib.sha256(LAYOUT.read_bytes()).hexdigest(),
                              'foraging_before': {'positions': g['foraging_work_spots']['positions'], 'center': g['berry_position']},
                              'foraging_after': {'positions': copy.deepcopy(spots), 'center': target['berry_position']},
                              'permission': 'User approved relocating positions and homes; retain all history and property',
                              'doors': {}, 'windows': {}, 'migration': mapped}
    # Exact deep equality of EVERYTHING except the explicitly authorized spatial fields.
    control = copy.deepcopy(result)
    for key in ['homes', 'positions', 'berry_position', 'foraging_work_spots']:
        control['godot'][key] = g[key]
    del control['godot']['spatial_layout']
    assert control == state
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise FileExistsError(destination)
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    report = {'world_id': state['world_id'], 'life_seq': state['life']['seq'], 'residents': mapped,
              'all_nonspatial_fields_identical': True, 'source_sha256': hashlib.sha256(raw).hexdigest(),
              'destination_sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}
    destination.with_suffix('.migration.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'residents'}, ensure_ascii=False))


def activate(canonical, candidate):
    canonical, candidate = canonical.resolve(), candidate.resolve()
    if canonical == candidate:
        raise ValueError('Candidate must be a separately reviewed copy')
    raw = candidate.read_bytes()
    state = json.loads(raw)
    metadata = state['godot']['spatial_layout']
    if metadata['layout_sha256'] != hashlib.sha256(LAYOUT.read_bytes()).hexdigest():
        raise ValueError('Candidate was prepared for a different layout')
    lock = canonical.with_name(canonical.name+'.writer-lock')
    staged = canonical.with_name(canonical.name+'.quarter-staging')
    lock.mkdir()  # Same atomic directory lock as the Godot writer; never remove another writer's lock.
    try:
        prior_raw = canonical.read_bytes()
        if hashlib.sha256(prior_raw).hexdigest() != metadata['source_sha256']:
            raise ValueError('World changed after backup; refusing to overwrite newer progress')
        original = json.loads(prior_raw)
        control = copy.deepcopy(state)
        for key in ['homes','positions','berry_position','foraging_work_spots']:
            control['godot'][key] = original['godot'][key]
        del control['godot']['spatial_layout']
        if control != original:
            raise ValueError('Candidate changes history, property or other non-spatial state')
        backup = candidate.with_name(candidate.stem+'.pre-activation.json')
        with backup.open('xb') as f:
            f.write(prior_raw)
        with staged.open('xb') as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
        os.replace(staged,canonical)
        receipt = {'canonical':str(canonical),'backup':str(backup),'source_sha256':metadata['source_sha256'],
                   'activated_sha256':hashlib.sha256(canonical.read_bytes()).hexdigest(),
                   'life_seq':state['life']['seq'],'history_and_property_unchanged':True}
        candidate.with_suffix('.activation.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
        print(json.dumps(receipt,ensure_ascii=False))
    finally:
        lock.rmdir()


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--destination', type=Path)
    p.add_argument('--activate-candidate', type=Path)
    args = p.parse_args()
    if args.activate_candidate:
        if args.destination:
            p.error('--destination and --activate-candidate are mutually exclusive')
        activate(args.source,args.activate_candidate)
    else:
        if not args.destination:
            p.error('--destination is required when preparing a migration')
        migrate(args.source, args.destination)
