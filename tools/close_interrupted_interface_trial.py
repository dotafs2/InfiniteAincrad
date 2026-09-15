"""Close an inspected interrupted trial without replaying a model request or action."""
import argparse
from pathlib import Path

from model_interface_experiment import Probe, SOURCE, SOURCE_SHA, read, sha, write


def close_trial(directory):
    directory = Path(directory).resolve()
    result = read(directory / 'result.json')
    assert result['status'] == 'execution_error'
    assert 'cold_state_equal' not in result, 'already closed'
    before = read(directory / 'live/world.json')
    initial = read(directory / 'initial-observation.json')
    assert not (directory / 'cold').exists(), 'inspect existing cold evidence first'
    cold = Probe(directory / 'cold', directory / 'live/world.json')
    try:
        restored = cold.request('observe')
    finally:
        cold.close()
    result['final_observation'] = restored
    result['cold_observation'] = {k: restored[k] for k in ('seq', 'position', 'archive_count', 'pending')}
    result['cold_state_equal'] = before == read(directory / 'cold/world.json')
    result['identities_preserved'] = [r['stable_id'] for r in before['residents']] == [r['stable_id'] for r in read(SOURCE)['residents']]
    result['new_events'] = [e for e in before['life']['events'] if e.get('seq', 0) > initial['seq']]
    result['all_replies_archived'] = all('interface:' + r['call_id'] in before['godot']['resident_archive']['entries'] for r in result['calls'])
    result['interruption_closure'] = 'Original error retained. Inspected save cold-loaded; no repeated model request and no resumed action. Trial remains an execution error.'
    assert sha(SOURCE) == SOURCE_SHA
    write(directory / 'result.json', result)
    return {k: result[k] for k in ('trial', 'status', 'cold_state_equal', 'all_replies_archived')}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trial_directory', type=Path)
    print(close_trial(parser.parse_args().trial_directory))
