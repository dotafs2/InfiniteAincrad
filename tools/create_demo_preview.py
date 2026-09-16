"""Create a fresh living-quarter world from the public seed, never private history."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from create_trade_fixture import shared_world_seed
from migrate_living_quarter import LAYOUT, terrain_height


DEFAULT_WORLD_ID = 'shared:demo-preview-20260916'
DEFAULT_LABEL = 'Fresh offline art preview; no original world history or model calls'


def create_preview(destination, world_id=DEFAULT_WORLD_ID, label=DEFAULT_LABEL):
    if destination.exists():
        raise FileExistsError(destination)
    if not world_id or world_id.startswith('fixture:'):
        raise ValueError('A fresh preview requires a non-fixture world_id')
    layout = json.loads(LAYOUT.read_text(encoding='utf-8'))
    state = shared_world_seed(world_id, label)
    world = state['godot']
    for index, house in enumerate(layout['houses']):
        dx, dz = {'01_hearth_cottage': (0, 1.1), '02_market_house': (-.9, 1.2),
                  '03_corner_turret': (2.2, .7)}[house['variant']]
        x, y, z = house['at']
        angle = math.radians(house['yaw'])
        world['homes'][house['resident']] = [x+dx*math.cos(angle)+dz*math.sin(angle), y+.045,
                                            z-dx*math.sin(angle)+dz*math.cos(angle)]
        point = list(layout['spawn_points'][index])
        point[1] = terrain_height(layout, point[0], point[2])+.06
        world['positions'][house['resident']] = point
    world['berry_position'] = layout['berry_position']
    world['spatial_layout'] = {'id': layout['id'], 'doors': {}, 'windows': {},
                               'preview_genesis': True,
                               'layout_sha256': hashlib.sha256(LAYOUT.read_bytes()).hexdigest()}
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(state, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--world-id', default=DEFAULT_WORLD_ID,
                        help='Independent identity for this new world (never an existing world id).')
    parser.add_argument('--label', default=DEFAULT_LABEL)
    args = parser.parse_args()
    print(create_preview(args.output, args.world_id.strip(), args.label.strip()))
