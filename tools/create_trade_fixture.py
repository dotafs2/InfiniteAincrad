"""Create an explicitly fictional trade test world; never reconstruct the original town.

The destination must be new and outside game/. No keys, models or engine calls.
"""
import argparse
import hashlib
import json
from pathlib import Path


def fixture():
    people = [
        ('fixture:innkeeper', '测试旅店主', 'innkeeper', [-2, .22, 7],
         '我经营一间测试旅店，想用自己已有的木料准备引火柴。我珍惜自己的柴斧，会权衡修理费用，也可以拒绝或等待。'),
        ('fixture:smith', '测试铁匠', 'smith', [0, .22, 7],
         '我是测试铁匠，靠金属修理谋生。我希望得到合理报酬，先了解委托再决定接不接，不替别人作决定。'),
        ('fixture:carpenter', '测试木匠', 'carpenter', [-2, .22, 5],
         '我是测试木匠，能修木柄。我重视踏实的工作和明确的交付，也有权拒绝不合适的委托。'),
    ]
    residents = [dict(stable_id=i, name=n, role=r, story=s, personality='谨慎、独立',
                      coins_col=20 if index == 0 else 5, needs={'hunger': 95},
                      runtime={'fixture_only': True}) for index, (i, n, r, p, s) in enumerate(people)]
    life = dict(seq=0, events=[], contracts=[], applied=[], relations=[], inboxes=[],
                items=[dict(id='fixture:axe', kind='axe', owner_id=people[0][0], custodian_id=people[0][0],
                            edge=20, handle=20, source='explicit_test_fixture')],
                skills=[dict(resident_id=people[1][0], skill_id='metal_repair'),
                        dict(resident_id=people[2][0], skill_id='wood_repair')],
                accounts=[dict(resident_id=i, wood=2 if index == 0 else 1 if index == 2 else 0,
                               iron=1 if index == 1 else 0, kindling=0, reserved_col=0)
                          for index, (i, *_rest) in enumerate(people)])
    positions = {i: p for i, n, r, p, s in people}
    return dict(schema_version=2, world_id='fixture:town-trade-validation', fixture=True, elapsed_seconds=0,
                residents=residents, life=life,
                survival=dict(accounts=[dict(resident_id=i, food=1, energy=95) for i, *_ in people], tick_remainder_seconds=0),
                foraging=dict(stock=3, capacity=3, initial_stock=3, produced_total=0, harvested_total=0, growth_remainder_seconds=0),
                godot=dict(schema_version=1, mode='migration_validation', source_life_seq=0,
                           source_sha256=hashlib.sha256(b'explicit-test-fixture-not-original-world').hexdigest(),
                           positions=positions, homes={i: p[:] for i, p in positions.items()},
                           berry_position=[4, .22, 1], pending={}, commands={}, new_events=[], elapsed_seconds=0,
                           observations={i: [] for i, *_ in people}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--online-join', action='store_true', help='Two explicit residents, one hungry enough to eat; third joins at runtime.')
    args = parser.parse_args()
    path = args.output.resolve()
    game = Path(__file__).resolve().parents[1] / 'game'
    if path == game or game in path.parents:
        parser.error('Place fixture saves outside game/.')
    path.parent.mkdir(parents=True, exist_ok=True)
    world = fixture()
    if args.online_join:
        absent = 'fixture:carpenter'
        world['residents'] = [r for r in world['residents'] if r['stable_id'] != absent]
        world['residents'][0]['needs']['hunger'] = 60
        for section, key in [('survival', 'accounts'), ('life', 'accounts'), ('life', 'skills')]:
            world[section][key] = [r for r in world[section][key] if r['resident_id'] != absent]
        for key in ['positions', 'homes', 'observations']:
            world['godot'][key].pop(absent)
    with path.open('x', encoding='utf-8') as target:
        json.dump(world, target, ensure_ascii=False, indent=2)
    print(json.dumps({'world_id': fixture()['world_id'], 'path': str(path), 'original_world': False}))
