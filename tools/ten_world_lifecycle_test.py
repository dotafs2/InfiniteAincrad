"""Bounded OFFLINE ten-body life, process-exit and same-save continuation test.

The maintained seed is read once and copied byte-for-byte into a NEW test folder.
The real street runs at ordinary simulation speed; no model/gateway is configured.
run_godot.py owns every engine PID, timeout, stdout/stderr and exit record.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = (ROOT / 'tmp/gpt6-sprint/ten-world').resolve()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--seed', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    destination = args.out.resolve()
    if ALLOWED not in destination.parents or destination.exists():
        parser.error('Choose a NEW test subdirectory under tmp/gpt6-sprint/ten-world')
    source = args.seed.resolve()
    original_bytes = source.read_bytes()
    original = json.loads(original_bytes)
    if original.get('origin', {}).get('kind') != 'new_world_seed' or original['life']['seq'] != 0:
        parser.error('This test requires a declared independent genesis source')
    destination.mkdir(parents=True)
    save = destination / 'world.json'
    with save.open('xb') as handle:
        handle.write(original_bytes)
    result = {'provenance': 'ordinary offline local_rule_policy in actual street; no model or gateway',
              'world_id': original['world_id'], 'source_sha256': hashlib.sha256(original_bytes).hexdigest(),
              'model_calls': 0, 'checks': [], 'stages': []}

    def check(condition, label):
        result['checks'].append({'ok': bool(condition), 'label': label})
        if not condition:
            raise AssertionError(label)

    def run_stage(name, duration, restore=False, graphical=False):
        capture = destination / name
        command = [sys.executable, '-X', 'utf8', str(ROOT / 'tools/run_godot.py'), '--godot', str(args.godot.resolve()),
                   '--name', name, '--out', str(destination), '--timeout', str(duration + 30), '--']
        command += ['--rendering-method', 'gl_compatibility'] if graphical else ['--headless']
        command += ['--audio-driver', 'Dummy', 'res://scenes/town_street.tscn', '--',
                    '--town-save=' + str(save), '--town-capture=' + str(capture),
                    '--town-duration=' + str(duration)]
        if restore:
            command += ['--town-restore']
        print('Starting ' + name + ' on the same offline save', flush=True)
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8',
                                 timeout=duration + 45)
        (destination / (name + '.runner.log')).write_text(process.stdout + process.stderr, encoding='utf-8')
        check(process.returncode == 0, name + ': owned engine exits successfully')
        record = json.loads((destination / (name + '.process.json')).read_text(encoding='utf-8'))
        state = json.loads(save.read_bytes())
        evidence = json.loads((capture / 'evidence.json').read_text(encoding='utf-8'))
        result['stages'].append({'name': name, 'pid': record['pid'], 'exit_code': record['exit_code'],
                                'sequence': state['life']['seq'], 'pending_count': len(state['godot']['pending']),
                                'sha256': hashlib.sha256(save.read_bytes()).hexdigest()})
        check(evidence['world_origin'] == 'independent_new_world' and evidence['original_identities'] == 0,
              name + ': capture labels the independent world without claiming original-town recovery')
        check(evidence['active'] == 10 and evidence['identity_count'] == 10,
              name + ': capture reports ten saved and active residents')
        check(evidence['new_decisions'] == ('none_restore' if restore else 'local_rule_policy'),
              name + ': provenance remains explicit offline or cold restore')
        check(not Path(str(save) + '.writer-lock').exists(), name + ': normal exit releases the writer')
        print(name + ': sequence ' + str(state['life']['seq']) + ', pending ' + str(len(state['godot']['pending'])), flush=True)
        return state

    try:
        initial = run_stage('life-before-exit', 40)
        check(initial['life']['seq'] == 10, 'all ten residents finish one ordinary offline meal before exit')
        check(len(initial['godot']['pending']) == 10 and
              all(job['action'] == 'rest' for job in initial['godot']['pending'].values()),
              'all ten have real unfinished rest jobs at the first process exit')
        pending_commands = {job['command_id'] for job in initial['godot']['pending'].values()}
        initial_bytes = save.read_bytes()
        run_stage('life-cold-before-resume', 3, restore=True)
        check(save.read_bytes() == initial_bytes, 'cold street reopen preserves every byte and all ten unfinished jobs')
        resumed = run_stage('life-after-resume', 95)
        events = resumed['life']['events']
        check(events[:len(initial['life']['events'])] == initial['life']['events'], 'old life history remains an exact prefix')
        completions = [event for event in events if event.get('operation_id') in pending_commands]
        check(len(completions) == 10 and len({e['operation_id'] for e in completions}) == 10,
              'each of the ten original unfinished commands completes exactly once after restart')
        check(all(event['type'] == 'rest' for event in completions), 'the resumed commands retain their original rest meaning')
        check(resumed['life']['seq'] > 20 and resumed['foraging']['harvested_total'] > 0,
              'continued street time produces additional physical food-gathering consequences')
        moved = []
        for identity, position in original['godot']['positions'].items():
            after = resumed['godot']['positions'][identity]
            if sum((after[index] - position[index]) ** 2 for index in (0, 2)) > 0.25:
                moved.append(identity)
        check(len(moved) == 10, 'all ten actual resident bodies move from genesis toward the food source')
        result['moved_ids'] = moved
        for key in ('world_id', 'origin', 'seed'):
            check(resumed[key] == original[key], key + ' remains the same across all processes')
        check([(p['stable_id'], p['name'], p['role'], p['coins_col']) for p in resumed['residents']] ==
              [(p['stable_id'], p['name'], p['role'], p['coins_col']) for p in original['residents']],
              'all original identities, backgrounds and wallets are preserved')
        for key in ('items', 'skills', 'accounts', 'contracts'):
            check(resumed['life'][key] == original['life'][key], key + ' remains conserved')
        final_bytes = save.read_bytes()
        run_stage('life-final-cold', 3, restore=True, graphical=True)
        check(save.read_bytes() == final_bytes, 'final graphical cold restore is byte exact')
        check(len({stage['pid'] for stage in result['stages']}) == 4, 'all four stages use distinct owned engine processes')
    except Exception as error:
        result['error'] = str(error)
    finally:
        result['source_unchanged'] = source.read_bytes() == original_bytes
        result['failure_count'] = sum(not row['ok'] for row in result['checks']) + int('error' in result and all(row['ok'] for row in result['checks']))
        if not result['source_unchanged']:
            result['failure_count'] += 1
        (destination / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'checks': len(result['checks']), 'failure_count': result['failure_count'],
                      'source_unchanged': result['source_unchanged'], 'error': result.get('error')}, ensure_ascii=False))
    return 0 if result['failure_count'] == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
