"""Offline acceptance for the reviewed innkeeper-to-smith approach stagnation.

The source observation is a real Kimi run in the shared trial world: the accepted
approach turn:shared:innkeeper:0:2 held the innkeeper at x=2.000277 for 93.5167 s
with zero accrued work, 1.1503 m from the meeting point, while the carpenter stood
0.500277 m away. Everything this driver runs is an explicitly labelled offline
fixture: no model call, no gateway, no network, no private world and no screenshot.
The 93.5 s real observation is reproduced as geometry, not as a recorded choice.

Stages, each a real owned Godot process through tools/run_godot.py:
  acceptance        isolated acceptance with real physics bodies
  feasible          the real street scene on the reviewed geometry: the same
                    accepted approach must reach its original target and finish
                    exactly once, without moving any bystander
  occupied          the real street scene with a body standing on the meeting
                    point: the target stays unreachable and truthfully pending
  feasible-restore  the engine's own cold reopen after the completed approach
  occupied-restore  the engine's own cold reopen with the social job still pending

Every exit code, runner log and process record is retained under --out. Nothing is
written into game/ and no maintained save is read or written.
"""
import argparse
import datetime as dt
import hashlib
import json
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

WORLD_ID = 'fixture:town-social-approach'
OCCUPIED_WORLD_ID = 'fixture:town-social-approach-occupied'
MOVER = 'fixture:innkeeper'
COUNTERPARTY = 'fixture:smith'
BLOCKER = 'fixture:carpenter'
# In the separately labelled negative world one of the reviewed bystanders is
# declared standing on the meeting point. No body is ever relocated during play,
# and the feasible world keeps the reviewed ten-resident geometry exact.
DECLARED_OCCUPANT = 'fixture:baker'
ARRIVAL_GATE = 0.45
BODY_CONTACT = 0.5
MAX_PHYSICAL_STEP = 0.10
FEASIBLE_COMMAND = 'fixture-social-approach:1'
OCCUPIED_COMMAND = 'fixture-social-approach:occupied'

# Roster order and genesis grid of the shared trial world seed, so homes stay the
# declared genesis and only the current positions are the reviewed observations.
ROSTER = [
    ('fixture:well-keeper', 'Well keeper (offline fixture)', 'interest_water'),
    ('fixture:baker', 'Baker (offline fixture)', 'interest_baking'),
    (COUNTERPARTY, 'Smith (offline fixture)', 'repair_metal'),
    (BLOCKER, 'Carpenter (offline fixture)', 'repair_wood'),
    (MOVER, 'Innkeeper (offline fixture)', 'interest_hospitality'),
    ('fixture:herder', 'Herder (offline fixture)', 'interest_herding'),
    ('fixture:gardener', 'Gardener (offline fixture)', 'interest_gardening'),
    ('fixture:weaver', 'Weaver (offline fixture)', 'interest_weaving'),
    ('fixture:fisher', 'Fisher (offline fixture)', 'interest_fishing'),
    ('fixture:healer', 'Healer (offline fixture)', 'interest_herbs'),
]
GENESIS_COLUMNS = [-3.0, -1.5, 0.0, 1.5, 3.0]
GENESIS_ROWS = [7.5, 5.5]

# Whitelisted positions from the reviewed supervisor facts. The mover, the blocking
# carpenter, the counterparty and the goal are the geometry the repair must serve;
# the remaining residents are the bystanders that must not be moved for it.
REVIEWED_POSITIONS = {
    'fixture:well-keeper': [-2.1765027046203613, 0.22083944082260132, 6.402005672454834],
    'fixture:baker': [-1.5, 0.2199999988079071, 7.5],
    COUNTERPARTY: [0.0, 0.2199999988079071, 7.5],
    BLOCKER: [1.5, 0.2199999988079071, 7.5],
    MOVER: [2.000276803970337, 0.22065602242946625, 7.5],
    'fixture:herder': [-3.0, 0.2199999988079071, 5.5],
    'fixture:gardener': [-1.5, 0.2199999988079071, 5.5],
    'fixture:weaver': [0.0, 0.2199999988079071, 5.5],
    'fixture:fisher': [1.5, 0.22083817422389984, 6.354984283447266],
    'fixture:healer': [3.0, 0.2199999988079071, 5.5],
}
GOAL = [0.8500000238418579, 0.2199999988079071, 7.5]


def genesis(index):
    return [GENESIS_COLUMNS[index % len(GENESIS_COLUMNS)], 0.2199999988079071,
            GENESIS_ROWS[index // len(GENESIS_COLUMNS)]]


def build_world(world_id, occupied):
    roster = list(ROSTER)
    positions = {identity: list(point) for identity, point in REVIEWED_POSITIONS.items()}
    if occupied:
        positions[DECLARED_OCCUPANT] = list(GOAL)
    residents = []
    survival = []
    accounts = []
    for index, (stable_id, name, role) in enumerate(roster):
        residents.append({'stable_id': stable_id, 'name': name, 'role': role,
                          'story': 'explicit offline fixture identity',
                          'personality': 'explicit offline fixture',
                          'coins_col': 5 + index, 'needs': {'hunger': 60.0},
                          'runtime': {'fixture_only': True,
                                      'genesis': 'labelled offline fixture, not a migrated or maintained world'}})
        survival.append({'resident_id': stable_id, 'food': 1, 'energy': 60.0})
        accounts.append({'resident_id': stable_id, 'wood': 1, 'iron': 0, 'kindling': 0, 'reserved_col': 0})
    homes = {}
    for index, (stable_id, _name, _role) in enumerate(ROSTER):
        homes[stable_id] = genesis(index)
    identity = json.dumps({'world_id': world_id, 'residents': [r[0] for r in roster],
                           'positions': positions, 'kind': 'offline_fixture'},
                          ensure_ascii=False, sort_keys=True)
    return {
        'schema_version': 2, 'world_id': world_id, 'fixture': True, 'elapsed_seconds': 0,
        'residents': residents,
        'survival': {'accounts': survival, 'tick_remainder_seconds': 0},
        'foraging': {'stock': 6, 'capacity': 6, 'initial_stock': 6, 'produced_total': 0,
                     'harvested_total': 0, 'growth_remainder_seconds': 0},
        'life': {'seq': 0, 'events': [], 'contracts': [], 'applied': [], 'relations': [],
                 'inboxes': [],
                 'items': [{'id': 'fixture:axe', 'kind': 'axe', 'owner_id': BLOCKER,
                            'custodian_id': BLOCKER, 'edge': 20, 'handle': 20,
                            'source': 'explicit_offline_fixture'}],
                 'skills': [{'resident_id': COUNTERPARTY, 'skill_id': 'metal_repair'},
                            {'resident_id': BLOCKER, 'skill_id': 'wood_repair'}],
                 'accounts': accounts},
        'godot': {'schema_version': 1, 'mode': 'migration_validation', 'source_life_seq': 0,
                  'source_sha256': hashlib.sha256(identity.encode('utf-8')).hexdigest(),
                  'positions': positions, 'homes': homes, 'pending': {}, 'commands': {},
                  'new_events': [], 'elapsed_seconds': 0,
                  'observations': {stable_id: [] for stable_id, _n, _r in roster},
                  'berry_position': [4.0, 0.2199999988079071, 1.0]},
    }


class Failure(Exception):
    pass


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def flat_gap(left, right):
    return ((left[0] - right[0]) ** 2 + (left[2] - right[2]) ** 2) ** 0.5


def close(left, right, tolerance=1e-4):
    """Compare a Godot real_t (float32) position against the reviewed decimal facts."""
    return len(left) == len(right) and all(abs(a - b) <= tolerance for a, b in zip(left, right))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--out', type=Path, default=ROOT / 'tmp/gm09-tests/social-approach')
    parser.add_argument('--seconds', type=float, default=15.0,
                        help='Real-time seconds per street stage (no time scaling).')
    args = parser.parse_args(argv)
    root_out = args.out.resolve()
    if root_out != ROOT and ROOT not in root_out.parents:
        parser.error('--out must stay inside this candidate checkout')
    # Every run gets its own new child directory. No caller directory is ever moved,
    # renamed or deleted, so an earlier failing run stays reviewable as it was.
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    out = root_out / f'run-{stamp}-{uuid.uuid4().hex[:8]}'
    (out / 'fixtures').mkdir(parents=True)
    (out / 'captures').mkdir()
    (out / 'traces').mkdir()

    results = {'provenance': 'offline labelled fixtures, real owned engines, no model or gateway call',
               'world_id': WORLD_ID, 'occupied_world_id': OCCUPIED_WORLD_ID,
               'started_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
               'checks': [], 'stages': [], 'commands': []}
    failure = []

    def check(label, ok, detail=''):
        results['checks'].append({'label': label, 'ok': bool(ok), 'detail': str(detail)})
        if not ok:
            failure.append(label)
        return bool(ok)

    def engine(name, timeout, engine_args, user_args, expected=0):
        command = [sys.executable, '-X', 'utf8', str(ROOT / 'tools/run_godot.py'),
                   '--godot', str(args.godot), '--name', name, '--out', str(out),
                   '--timeout', str(timeout), '--'] + engine_args
        if user_args:
            command += ['--'] + user_args
        results['commands'].append({'name': name, 'argv': command})
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 encoding='utf-8', errors='replace', timeout=timeout + 60)
        (out / (name + '.runner.log')).write_text(process.stdout + process.stderr, encoding='utf-8')
        record_path = out / (name + '.process.json')
        record = read(record_path) if record_path.is_file() else {}
        results['stages'].append({'name': name, 'exit_code': process.returncode,
                                  'engine_exit': record.get('exit_code'),
                                  'engine_status': record.get('status'),
                                  'elapsed_seconds': record.get('elapsed_seconds'),
                                  'log': name + '.runner.log'})
        if process.returncode != expected:
            raise Failure(f'{name}: owned engine exit {process.returncode}, expected {expected}; '
                          f'see {name}.runner.log')
        return record

    def engine_json(name, suite):
        document = {}
        for line in (out / (name + '.runner.log')).read_text(encoding='utf-8', errors='replace').splitlines():
            if not line.startswith('{'):
                continue
            try:
                parsed = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict) and parsed.get('suite') == suite:
                document = parsed
        if not document:
            raise Failure(f'{name}: no {suite} result document in the retained engine log')
        return document

    feasible_save = out / 'fixtures' / 'feasible.json'
    occupied_save = out / 'fixtures' / 'occupied.json'
    feasible_save.write_text(json.dumps(build_world(WORLD_ID, False), ensure_ascii=False, indent=2),
                             encoding='utf-8')
    occupied_save.write_text(json.dumps(build_world(OCCUPIED_WORLD_ID, True), ensure_ascii=False, indent=2),
                             encoding='utf-8')
    results['fixture_sha256'] = {'feasible': sha(feasible_save), 'occupied': sha(occupied_save)}

    def probe(name, stage, save, command, seconds):
        trace = out / 'traces' / f'{name}.json'
        capture = out / 'captures' / name
        engine(name, 60, ['--headless', '--audio-driver', 'Dummy', '--script',
                          'res://tests/town_social_approach_scene.gd'],
               ['--town-save=' + str(save), '--town-capture=' + str(capture),
                '--social-stage=' + stage, '--social-trace=' + str(trace),
                '--social-seconds=' + str(seconds), '--social-command=' + command])
        return read(trace), read(capture / 'evidence.json')

    def restore(name, save):
        trace = out / 'traces' / f'{name}.json'
        capture = out / 'captures' / name
        engine(name, 45, ['--headless', '--audio-driver', 'Dummy', '--script',
                          'res://tests/town_social_approach_scene.gd'],
               ['--town-save=' + str(save), '--town-capture=' + str(capture),
                '--town-restore', '--social-stage=restore', '--social-trace=' + str(trace)])
        return read(trace), read(capture / 'evidence.json')

    try:
        # 1. Isolated acceptance: real bodies, the reviewed geometry, the control.
        engine('social-acceptance', 90, ['--headless', '--script',
                                         'res://tests/town_social_approach_acceptance.gd'],
               ['--social-work-dir=' + str(out / 'acceptance-work')])
        acceptance = engine_json('social-acceptance', 'town_social_approach')
        results['acceptance'] = acceptance
        check('the isolated real-body acceptance reports no failure',
              acceptance.get('failures') == 0, json.dumps(acceptance.get('cases', {})))
        cases = acceptance.get('cases', {})
        control = cases.get('direct_control', {})
        detour = cases.get('steered_detour', {})
        occupied_case = cases.get('occupied_target', {})
        check('the reviewed lane is physically blocked for a straight approach',
              bool(control.get('blocked_at_start')), json.dumps(control))
        check('a direct offset reproduces the observed stall outside the arrival gate',
              float(control.get('min_distance', 0.0)) > ARRIVAL_GATE, str(control.get('min_distance')))
        check('the same lane reaches the original target through the real steering',
              float(detour.get('min_distance', 9.9)) <= ARRIVAL_GATE, str(detour.get('min_distance')))
        check('an occupied target stays unreachable and is never entered',
              float(occupied_case.get('min_distance', 0.0)) > ARRIVAL_GATE
              and float(occupied_case.get('min_clearance', -1.0)) > -0.02, json.dumps(occupied_case))

        # 2. Feasible street stage on the reviewed geometry.
        trace, evidence = probe('social-feasible', 'feasible', feasible_save, FEASIBLE_COMMAND, args.seconds)
        results['feasible_trace'] = trace
        check('the street stage runs at the real time scale', trace.get('engine_time_scale') == 1.0,
              str(trace.get('engine_time_scale')))
        check('the street scene really uses the social steering module', trace.get('social_steering_wired') is True)
        check('the accepted approach is submitted through the trade API', trace.get('command_submitted') is True)
        check('the accepted target is the reviewed meeting point',
              close(trace.get('target', []), GOAL), str(trace.get('target')))
        check('the mover starts at the reviewed position',
              close(trace.get('mover_world_start', []), REVIEWED_POSITIONS[MOVER]),
              str(trace.get('mover_world_start')))
        check('the blocking resident stands at the reviewed position',
              close(trace['bystander_start'][BLOCKER], REVIEWED_POSITIONS[BLOCKER]), str(trace['bystander_start'][BLOCKER]))
        check('the mover only ever moved through physics steps',
              float(trace.get('mover_max_physics_step', 9.9)) <= MAX_PHYSICAL_STEP
              and int(trace.get('physics_frames_observed', 0)) > 600,
              json.dumps({key: trace.get(key) for key in
                          ('mover_max_physics_step', 'mover_path_length',
                           'physics_frames_observed', 'physics_seconds_observed')}))
        check('the mover really travelled a detour path around the neighbour',
              float(trace.get('mover_path_length', 0.0)) >= 2.0, str(trace.get('mover_path_length')))
        check('the mover starts the traced path at the reviewed position',
              close(trace.get('mover_first_body_position', []), REVIEWED_POSITIONS[MOVER], 0.03),
              str(trace.get('mover_first_body_position')))
        check('every resident starts at its reviewed position in the world record',
              all(close(trace['world_start'][identity], point)
                  for identity, point in REVIEWED_POSITIONS.items()),
              json.dumps(trace.get('world_start')))
        check('the probe observed every resident body, not a subset',
              int(trace.get('residents_seen', 0)) == len(REVIEWED_POSITIONS),
              str(trace.get('residents_seen')))
        check('the physical mover reaches the original target',
              float(trace.get('min_distance_to_target', 9.9)) <= ARRIVAL_GATE,
              str(trace.get('min_distance_to_target')))
        check('the physical bodies never penetrate each other',
              float(trace.get('min_body_clearance', -9.9)) >= -0.02, str(trace.get('min_body_clearance')))
        check('no bystander moves from where its own decisions left it',
              all(float(value) <= 0.001 for identity, value in trace.get('bystander_max_drift', {}).items()
                  if identity != MOVER), json.dumps(trace.get('bystander_max_drift', {})))
        check('the approach finishes exactly once', trace.get('events_for_command') == 1,
              str(trace.get('events_for_command')))
        save = read(feasible_save)
        trade = save['godot']['trade']
        check('the completed approach is no longer pending', MOVER not in trade['jobs'])
        check('the completed command keeps its completed status',
              trade['commands'][FEASIBLE_COMMAND]['status'] == 'completed')
        completions = [event for event in save['life']['events']
                       if event.get('operation_id') == FEASIBLE_COMMAND]
        check('the save holds exactly one completion receipt for the command',
              len(completions) == 1 and completions[0].get('type') == 'resident_moved',
              json.dumps(completions))
        check('the saved mover position is legally inside the arrival gate',
              flat_gap(save['godot']['positions'][MOVER], GOAL) <= ARRIVAL_GATE,
              str(save['godot']['positions'][MOVER]))
        check('every bystander keeps its reviewed horizontal position in the save',
              all(flat_gap(save['godot']['positions'][identity], point) <= 1e-4
                  for identity, point in REVIEWED_POSITIONS.items() if identity != MOVER),
              json.dumps({identity: save['godot']['positions'][identity]
                          for identity in REVIEWED_POSITIONS if identity != MOVER}))
        pending_fields = {key: evidence.get(key) for key in
                          ('pending_count', 'pending_life_count', 'pending_trade_count')}
        check('the capture reports the fixed pending breakdown',
              pending_fields == {'pending_count': 0, 'pending_life_count': 0, 'pending_trade_count': 0},
              json.dumps(pending_fields))
        check('the capture labels the labelled fixture mode',
              evidence.get('new_decisions') == 'scripted_trade_fixture' and evidence.get('is_fixture') is True)

        # 3. Occupied street stage: the same accepted approach cannot arrive.
        trace, evidence = probe('social-occupied', 'occupied', occupied_save, OCCUPIED_COMMAND, args.seconds)
        results['occupied_trace'] = trace
        check('the occupied target is never entered',
              float(trace.get('min_distance_to_target', 0.0)) > ARRIVAL_GATE,
              str(trace.get('min_distance_to_target')))
        check('the occupied target is never penetrated',
              float(trace.get('min_body_clearance', -9.9)) >= -0.02, str(trace.get('min_body_clearance')))
        check('the unreachable approach stays truthfully pending',
              trace.get('job_pending') is True and trace.get('command_status') == 'pending'
              and trace.get('events_for_command') == 0, json.dumps(
                  {key: trace.get(key) for key in ('job_pending', 'command_status', 'events_for_command')}))
        check('no bystander moves while the target is occupied',
              all(float(value) <= 0.001 for identity, value in trace.get('bystander_max_drift', {}).items()
                  if identity != MOVER), json.dumps(trace.get('bystander_max_drift', {})))
        check('the blocked mover stays where it is instead of pressing through a body',
              float(trace.get('mover_path_length', 9.9)) <= 0.05
              and float(trace.get('mover_max_physics_step', 9.9)) <= MAX_PHYSICAL_STEP,
              json.dumps({key: trace.get(key) for key in
                          ('mover_path_length', 'mover_max_physics_step', 'min_body_clearance')}))
        save = read(occupied_save)
        trade = save['godot']['trade']
        job = trade['jobs'].get(MOVER, {})
        check('the pending social job keeps its accepted target and zero work',
              job.get('action') == 'approach' and job.get('elapsed') == 0.0
              and job.get('target_position') == GOAL and job.get('command_id') == OCCUPIED_COMMAND,
              json.dumps(job))
        check('the pending command is retained without a receipt',
              trade['commands'][OCCUPIED_COMMAND]['status'] == 'pending'
              and not [event for event in save['life']['events']
                       if event.get('operation_id') == OCCUPIED_COMMAND])
        check('the capture counts the pending social job instead of dropping it',
              evidence.get('pending_trade_count') == 1 and evidence.get('pending_life_count') == 0
              and evidence.get('pending_count') == 1, json.dumps(
                  {key: evidence.get(key) for key in ('pending_count', 'pending_life_count', 'pending_trade_count')}))

        # 4. Cold reopen of the completed approach: no replay, no rewrite.
        feasible_bytes = sha(feasible_save)
        trace, evidence = restore('social-feasible-restore', feasible_save)
        check('the cold reopen is labelled as such',
              trace.get('restore_mode') is True and evidence.get('new_decisions') == 'none_restore')
        check('the cold reopen of the completed approach rewrites nothing',
              sha(feasible_save) == feasible_bytes)
        save = read(feasible_save)
        check('the completed command id and history survive the cold reopen',
              save['godot']['trade']['commands'][FEASIBLE_COMMAND]['status'] == 'completed'
              and len([event for event in save['life']['events']
                       if event.get('operation_id') == FEASIBLE_COMMAND]) == 1)
        check('the cold reopen leaves no writer lock behind',
              not Path(str(feasible_save) + '.writer-lock').exists())

        # 5. Cold reopen of the still-pending approach.
        occupied_bytes = sha(occupied_save)
        trace, evidence = restore('social-occupied-restore', occupied_save)
        check('the cold reopen of the pending approach rewrites nothing',
              sha(occupied_save) == occupied_bytes)
        save = read(occupied_save)
        job = save['godot']['trade']['jobs'].get(MOVER, {})
        check('the pending social job survives the cold reopen without replay',
              job.get('command_id') == OCCUPIED_COMMAND and job.get('elapsed') == 0.0
              and save['godot']['trade']['commands'][OCCUPIED_COMMAND]['status'] == 'pending'
              and not [event for event in save['life']['events']
                       if event.get('operation_id') == OCCUPIED_COMMAND])
        check('the cold reopen still counts the pending social job',
              evidence.get('pending_count') == 1 and evidence.get('pending_trade_count') == 1,
              json.dumps({key: evidence.get(key) for key in ('pending_count', 'pending_trade_count')}))
    except Failure as error:
        failure.append(str(error))
    except (subprocess.TimeoutExpired, json.JSONDecodeError, KeyError, OSError) as error:
        failure.append(f'{type(error).__name__}: {error}')

    results['failure_count'] = len(failure)
    results['failures'] = failure
    results['passed'] = not failure
    results['finished_at_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
    (out / 'tests.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'suite': 'town_social_approach_driver', 'out': str(out),
                      'checks': len(results['checks']), 'failed_checks': len(failure),
                      'stages': [(stage['name'], stage['exit_code']) for stage in results['stages']],
                      'result': 'passed' if results['passed'] else 'failed',
                      'failures': failure, 'paid_calls': 0}, ensure_ascii=False))
    return 0 if results['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
