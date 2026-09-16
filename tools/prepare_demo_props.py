"""Package existing first-pass Meshy props and completed demo jobs, without regeneration."""
import argparse
import json
from pathlib import Path
from prepare_living_props import ROOT, prepare

EXISTING = ['anvil', 'lantern', 'meal', 'potion', 'cooking_pot', 'weapon_rack', 'shield']
NEW = ['market-stall', 'market-barrel', 'produce-crate', 'wooden-handcart']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--existing-only', action='store_true')
    args = parser.parse_args()
    destination = ROOT / 'game/assets/floor1/demo_props_20260916'
    records = []
    for asset in EXISTING + ([] if args.existing_only else NEW):
        source = ROOT / ('exports/interior-first-pass-20260916/meshy' if asset in EXISTING
                         else 'exports/meshy-pool/floor1-demo-props-20260916-v1') / (asset + '.glb')
        output = destination / (asset + '.glb')
        if not source.exists():
            raise RuntimeError('Required model is not downloaded: ' + str(source))
        if not output.exists():
            records.append(prepare(asset, source, output, 1024 if asset in EXISTING else 2048))
    destination.mkdir(parents=True, exist_ok=True)
    manifest = destination / 'manifest.json'
    previous = json.loads(manifest.read_text()) if manifest.exists() else []
    current = {row['id']: row for row in previous + records}
    manifest.write_text(json.dumps(list(current.values()), indent=2) + '\n')
    print(json.dumps({'packaged_this_run':len(records), 'available':list(current), 'paid_calls':0}))

if __name__ == '__main__':
    main()
