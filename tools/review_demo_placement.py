"""Check saved PCG origins against road corridors and house footprints."""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def clearance(point, first, last, width):
    x, _, z = point
    dx, dz = last[0]-first[0], last[1]-first[1]
    t = max(0, min(1, ((x-first[0])*dx+(z-first[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(x-first[0]-t*dx, z-first[1]-t*dz)-width/2

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    pcg = json.loads((args.output/'pcg.json').read_text())
    living = json.loads((args.output/'report.json').read_text())
    layout = json.loads((ROOT/'game/spatial/living_quarter_layout.json').read_text())
    segments = [(a,b,road['width']) for road in layout['roads']
                for a,b in zip(road['points'],road['points'][1:])]
    checks = []
    for group in pcg['scatter']:
        margin = .85 if group['asset']=='simple-grass' else 5 if group['asset'] in ['boulder','fallen-log'] else 4
        clearances = [min(clearance(point,a,b,width) for a,b,width in segments) for point in group['positions']]
        house_hits = sum(any(abs(point[0]-house['at'][0])<7.5+margin-.002 and
                             abs(point[2]-house['at'][2])<7.5+margin-.002
                             for house in layout['houses']+layout['infill']) for point in group['positions'])
        checks.append({'asset':group['asset'],'seed':group['seed'],'placed':group['placed'],
                       'min_road_clearance':round(min(clearances),3) if clearances else None,
                       'road_margin_violations':sum(value<margin-.002 for value in clearances),
                       'house_exclusion_violations':house_hits})
    checks_passed = all(not c['road_margin_violations'] and not c['house_exclusion_violations'] and c['placed']>0 for c in checks)
    result = {'checks':checks, 'placement_checks_passed':checks_passed,
              'routes_passed':sum(r['reaches'] for r in living['routes']), 'routes_total':len(living['routes']),
              'physical_walks_passed':sum(r['reached'] for r in living.get('physical_walks',[])),
              'physical_walks_total':len(living.get('physical_walks',[])),
              'fixture_checks_passed':sum(f[key] for f in living['fixtures'] for key in
                                         ['closed_door_blocks','open_door_clears','closed_window_blocks','open_window_clears']),
              'dressing_instances':len(pcg.get('dressing',[])),
              'dressing_asset_types':len({p['asset'] for p in pcg.get('dressing',[])}),
              'canonical_world_sha256':hashlib.sha256((ROOT/'tmp/mvp-autonomy-20260914/prepared/real/canonical-world.json').read_bytes()).hexdigest(),
              'limits':'Origin clearance and bounded resident checks do not prove every possible route is valid.'}
    (args.output/'placement-checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return 0 if checks_passed and result['routes_passed']==result['routes_total'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
