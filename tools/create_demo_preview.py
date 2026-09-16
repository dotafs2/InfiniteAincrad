"""Create a fresh offline preview from the public ten-resident seed, never private history."""
import argparse
import json
import math
from pathlib import Path

from create_trade_fixture import shared_world_seed
from migrate_living_quarter import LAYOUT, terrain_height


def create_preview(destination):
    if destination.exists():
        raise FileExistsError(destination)
    layout = json.loads(LAYOUT.read_text(encoding='utf-8'))
    state = shared_world_seed('shared:demo-preview-20260916',
                              'Fresh offline art preview; no original world history or model calls')
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
                               'preview_genesis': True}
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(state, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(create_preview(args.output))
