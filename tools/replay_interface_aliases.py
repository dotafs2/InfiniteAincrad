"""Offline sensitivity check: bind retained alias references to their original IDs.

No inference, new plan, manual waypoint, or canonical-world mutation is allowed.
These replays are kept outside the formal model-comparison trial directory.
"""
import argparse
from pathlib import Path

from model_interface_experiment import Probe, RESIDENT, SOURCE, SOURCE_SHA, read, resolve_step, sha, write


def replay(call_directory, output):
    call_directory, output = Path(call_directory).resolve(), Path(output).resolve()
    assert not output.exists(), 'keep previous replay evidence'
    request, receipt = read(call_directory/'input.json'), read(call_directory/'receipt.json')
    import json
    decision = json.loads(receipt['assistant_text'])
    aliases = {o['alias']: o['id'] for o in request['payload']['options']}
    steps = [dict(step) for step in decision['steps']]
    changes = []
    for index, step in enumerate(steps):
        if step.get('option_id') in aliases:
            original = step['option_id']
            step['option_id'] = aliases[original]
            changes.append({'step': index, 'from': original, 'to': step['option_id']})
    assert changes, 'no alias-confusion hypothesis to check'
    result = {'scope': 'Offline replay of retained model plan. Only original alias references normalized; zero new model calls.',
              'original_call_id': receipt['call_id'], 'input_sha256': sha(call_directory/'input.json'),
              'changes': changes, 'steps': steps, 'actions': [], 'source_sha256': SOURCE_SHA}
    host = Probe(output, SOURCE)
    try:
        observation = host.request('observe')
        initial_seq = observation['seq']
        for index, step in enumerate(steps):
            option, error = resolve_step(step, observation)
            if error:
                result['stopped_on'] = {'step': index, 'error': error}
                break
            observation = host.request('apply', option_id=option['id'], command_id=f'interface:offline:alias:{index}',
                                       seconds=180, provenance='local_rule_policy')
            result['actions'].append({'option_id': option['id'], 'observation': observation})
            if observation['pending'] or not observation.get('action_result', {}).get('ok'):
                break
        result['final_observation'] = observation
        result['new_events'] = [e for e in read(host.world)['life']['events'] if e.get('seq',0)>initial_seq and e.get('actor_id')==RESIDENT]
    finally:
        host.close()
    assert sha(SOURCE) == SOURCE_SHA
    write(output/'result.json', result)
    return {'call_id': receipt['call_id'], 'actions': len(result['actions']),
            'actual_events': [e['type'] for e in result['new_events']], 'pending': bool(observation['pending'])}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('call_directory', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print(replay(args.call_directory, args.output))
