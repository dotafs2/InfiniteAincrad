"""Create an explicitly fictional trade test world, or a NEW ten-resident world seed.

Never reconstructs the original town, never copies or renames a private save. The
destination must be new and outside game/. No keys, models or engine calls.

Presets:
  trade-fixture      the deterministic three-person trade fixture used by the
                     existing offline validation suites (default, unchanged shape)
  shared-world-seed  a new independent simple world: ten distinct residents with
                     explicit GENESIS starting positions, needs, holdings and roles.
                     This is a new shared-world initialization, not a migration and
                     not a replay of the original town.
"""
import argparse
import datetime as dt
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


def _grid_positions(count: int) -> list:
    """Non-overlapping feasible plaza grid: 5 columns x 2 rows, 1.5 m / 2.0 m apart."""
    columns = [-3.0, -1.5, 0.0, 1.5, 3.0]
    rows = [7.5, 5.5]
    return [[columns[index % len(columns)], .22, rows[index // len(columns)]]
            for index in range(count)]


def shared_world_seed(world_id: str, label: str = '') -> dict:
    """A NEW ten-resident simple world. Starting resources are declared GENESIS facts.

    Role labels are interests and background only. Only the world's own rules decide
    what is actually possible, so no resident is described as running a bakery,
    herd, loom, boat or clinic; nothing here claims an unimplemented capability or
    an already achieved life history.
    """
    people = [
        ('shared:well-keeper', '阿岚', 'interest_water',
         '我总在街口水槽边停留，喜欢看水怎么被人分走；我还没学会怎么把水变成生计。'),
        ('shared:baker', '白枝', 'interest_baking',
         '我常闻面包铺的味道，想有一天学会烤面包；现在只是自己找吃的。'),
        ('shared:smith', '石青', 'repair_metal',
         '我会修铁器，希望靠这份手艺换口粮；接不接委托由我自己决定。'),
        ('shared:carpenter', '木生', 'repair_wood',
         '我会修木柄，看重明确的交付和报酬；我可以拒绝不合适的活。'),
        ('shared:innkeeper', '灯姐', 'interest_hospitality',
         '我喜欢看街上人来人往，想以后守着住处招呼客人；现在住处只是我自己住。'),
        ('shared:herder', '草见', 'interest_herding',
         '我对牲畜有兴趣，喜欢看它们被人照顾；我还没有自己的牲畜。'),
        ('shared:gardener', '叶禾', 'interest_gardening',
         '我留意街边的植物，想学着照料一小片地；现在只是观察。'),
        ('shared:weaver', '细娘', 'interest_weaving',
         '我喜欢摸布料，想以后学会织东西；现在只是有耐心。'),
        ('shared:fisher', '渡白', 'interest_fishing',
         '我喜欢待在近水的地方，想着以后能靠水吃饭；我还没有网或船。'),
        ('shared:healer', '枚青', 'interest_herbs',
         '我留意药草的样子，想以后能帮人处理小伤；我还没有行医的能力。'),
    ]
    positions = _grid_positions(len(people))
    residents = []
    survival_accounts = []
    life_accounts = []
    for index, (stable_id, name, role, story) in enumerate(people):
        residents.append(dict(stable_id=stable_id, name=name, role=role, story=story,
                              interests=[role], personality='谨慎、独立', coins_col=5 + index,
                              needs={'hunger': 60.0},
                              runtime={'fixture_only': False,
                                       'genesis': 'declared starting resident of a new world seed',
                                       'capability_note': ('role 只是兴趣或背景；实际能做什么由世界规则'
                                                           '决定，本种子不授予职业能力')}))
        survival_accounts.append(dict(resident_id=stable_id, food=1, energy=60.0))
        # Explicit allocations preserve the first ten-world seed's actual genesis.
        # Background labels never grant inventory or an achieved occupation.
        life_accounts.append(dict(resident_id=stable_id, wood=1, iron=0,
                                  kindling=0, reserved_col=0))
    life = dict(seq=0, events=[], contracts=[], applied=[], relations=[], inboxes=[],
                items=[dict(id='seed:axe', kind='axe', owner_id='shared:carpenter',
                            custodian_id='shared:carpenter', edge=20, handle=20,
                            source='explicit_genesis_fact_not_earned_not_migrated')],
                skills=[dict(resident_id='shared:smith', skill_id='metal_repair'),
                        dict(resident_id='shared:carpenter', skill_id='wood_repair')],
                accounts=life_accounts)
    position_map = {stable_id: position
                    for (stable_id, *_rest), position in zip(people, positions)}
    genesis_identity = json.dumps({'world_id': world_id, 'residents': [p[0] for p in people],
                                   'positions': position_map, 'kind': 'new_world_seed'},
                                  ensure_ascii=False, sort_keys=True)
    return dict(schema_version=2, world_id=world_id, fixture=False, elapsed_seconds=0,
                residents=residents, life=life,
                survival=dict(accounts=survival_accounts, tick_remainder_seconds=0),
                foraging=dict(stock=6, capacity=6, initial_stock=6, produced_total=0,
                              harvested_total=0, growth_remainder_seconds=0),
                origin=dict(kind='new_world_seed', genesis=True, migrated_from=None,
                            deterministic_test_choices=False, live_model_demand=False,
                            label=label or 'ten-resident simple world seed',
                            created_utc=dt.datetime.now(dt.timezone.utc).isoformat(),
                            starting_resources=('explicit GENESIS facts; not earned by play and '
                                                'not migrated from any other world'),
                            note=('new independent world; never a copy, rename or replay of a '
                                  'private original town')),
                seed=dict(label=label or 'ten-resident-simple-world', version=1,
                          residents=len(people),
                          role_note=('roles are interests or the two repair skills the world rules '
                                     'already implement; no other occupation exists yet')),
                godot=dict(schema_version=1, mode='migration_validation', source_life_seq=0,
                           source_sha256=hashlib.sha256(genesis_identity.encode()).hexdigest(),
                           new_world_seed=True,
                           positions=position_map,
                           homes={stable_id: position[:]
                                  for stable_id, position in position_map.items()},
                           berry_position=[4, .22, 1], pending={}, commands={}, new_events=[],
                           elapsed_seconds=0,
                           observations={stable_id: [] for stable_id, *_rest in people}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preset', choices=('trade-fixture', 'shared-world-seed'),
                        default='trade-fixture')
    parser.add_argument('--world-id', help='Required for --preset shared-world-seed: the new world '
                                           'identity. Never an existing or private world id.')
    parser.add_argument('--label', default='', help='Optional human label for a new world seed.')
    parser.add_argument('--online-join', action='store_true', help='Two explicit residents, one hungry enough to eat; third joins at runtime.')
    args = parser.parse_args()
    if args.world_id is not None:
        args.world_id = args.world_id.strip()
    path = args.output.resolve()
    game = Path(__file__).resolve().parents[1] / 'game'
    if path == game or game in path.parents:
        parser.error('Place fixture saves outside game/.')
    if args.preset == 'shared-world-seed':
        if not args.world_id:
            parser.error('--world-id is required for --preset shared-world-seed')
        if args.world_id.startswith('fixture:'):
            parser.error('a new shared world seed must not reuse a fixture world id')
        if args.online_join:
            parser.error('--online-join belongs to the trade fixture preset only')
    elif args.world_id:
        parser.error('--world-id is only valid with --preset shared-world-seed')
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        parser.error(f'{path} already exists; a new world seed never overwrites an existing save')
    world = fixture() if args.preset == 'trade-fixture' \
        else shared_world_seed(args.world_id.strip(), args.label.strip())
    if args.online_join:
        absent = 'fixture:carpenter'
        world['residents'] = [r for r in world['residents'] if r['stable_id'] != absent]
        world['residents'][0]['needs']['hunger'] = 60
        for section, key in [('survival', 'accounts'), ('life', 'accounts'), ('life', 'skills')]:
            world[section][key] = [r for r in world[section][key] if r['resident_id'] != absent]
        for key in ['positions', 'homes', 'observations']:
            world['godot'][key].pop(absent)
    try:
        with path.open('x', encoding='utf-8') as target:
            json.dump(world, target, ensure_ascii=False, indent=2)
    except FileExistsError:
        parser.error(f'{path} already exists; refusing a concurrent creation or overwrite')
    print(json.dumps({'preset': args.preset, 'world_id': world['world_id'], 'path': str(path),
                      'residents': len(world['residents']), 'original_world': False,
                      'migrated_from': None, 'genesis': bool(world.get('origin'))}))
