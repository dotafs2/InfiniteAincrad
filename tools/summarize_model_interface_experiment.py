"""Summarise retained experiment facts; never calls a model or modifies worlds."""
from collections import defaultdict
import argparse
import json
from pathlib import Path


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def ordered_meal_rest(result):
    types = [e.get('type') for e in result.get('new_events', []) if e.get('actor_id')=='shared:well-keeper']
    return ('eat_ration' in types and 'rest' in types
            and types.index('eat_ration') < types.index('rest')
            and result.get('final_observation', {}).get('distance_home', float('inf')) <= .55)


def summarize(out):
    manifest = load(out / 'manifest.json')
    groups = defaultdict(list)
    trials = []
    for path in sorted((out / 'trials').glob('*/result.json')):
        result = load(path)
        result['_directory'] = path.parent.name
        trials.append(result)
        groups[(result['provider'], result['arm'])].append(result)
    rows = []
    for (provider, arm), values in sorted(groups.items()):
        completed = [v for v in values if 'cold_state_equal' in v]
        calls = [c for v in values for c in v.get('calls', [])]
        currency = next((c.get('cost', {}).get('currency') for c in calls if c.get('cost')), None)
        token_totals = defaultdict(int)
        for call in calls:
            usage = call.get('usage', {})
            token_totals['input'] += usage.get('input_tokens', usage.get('prompt_tokens', 0))
            token_totals['output'] += usage.get('output_tokens', usage.get('completion_tokens', 0))
            token_totals['cached_input'] += usage.get('cached_input_tokens', usage.get('prompt_cache_hit_tokens', usage.get('cached_tokens', usage.get('prompt_tokens_details', {}).get('cached_tokens', 0))))
        by_case = {}
        for scenario in manifest['scenarios']:
            subset = [v for v in completed if v['scenario'] == scenario]
            by_case[scenario] = {'trials': len(subset), 'goal_completed': sum(v['status']=='goal_completed' for v in subset),
                                 'statuses': [v['status'] for v in subset],
                                 'calls': sum(len(v['calls']) for v in subset),
                                 'actions': sum(len(v['actions']) for v in subset)}
            if scenario == 'meal_rest':
                by_case[scenario]['eat_before_rest_verified'] = sum(ordered_meal_rest(v) for v in subset)
        rows.append({'provider': provider, 'model': manifest['models'][provider], 'arm': arm,
                     'completed_trials': len(completed), 'incomplete_trials': len(values)-len(completed),
                     'goal_completed': sum(v['status']=='goal_completed' for v in completed),
                     'calls': len(calls), 'actions': sum(len(v.get('actions', [])) for v in completed),
                     'cold_equal': sum(v.get('cold_state_equal', False) for v in completed),
                     'all_replies_archived': all(v.get('all_replies_archived', False) for v in completed),
                     'pending_action_trials': sum(bool(v.get('final_observation', {}).get('pending')) for v in completed),
                     'execution_error_trials': sum(v['status']=='execution_error' for v in values),
                     'completed_life_actions': sum(e.get('actor_id')=='shared:well-keeper' and e.get('type') in ('eat_ration','rest','harvest_ration') for v in completed for e in v.get('new_events', [])),
                     'latency_seconds': round(sum(c.get('latency_seconds',0) for c in calls),3),
                     'tokens': dict(token_totals), 'currency': currency,
                     'estimated_cost': None if currency=='subscription' else round(sum((c.get('cost') or {}).get('amount') or 0 for c in calls),9),
                     'by_scenario': by_case})
    initial_hashes = defaultdict(set)
    for value in trials:
        if value.get('initial_observation_sha256'):
            initial_hashes[value['scenario']].add(value['initial_observation_sha256'])
    all_receipts = []
    for path in sorted((out / 'calls').glob('*/receipt.json')):
        all_receipts.append(load(path))
    provider_totals = {}
    for provider in manifest['models']:
        receipts = [c for c in all_receipts if c['provider']==provider]
        settled = [c for c in receipts if c['status']=='settled']
        provider_totals[provider] = {
            'settled_calls_including_preflight': len(settled),
            'failed_or_uncertain_calls': len(receipts)-len(settled),
            'currency': next((c['cost']['currency'] for c in settled), None),
            'known_estimated_cost': None if provider in ('luna','astra') else round(sum(c['cost']['amount'] for c in settled),9),
            'input_tokens': sum(c['usage'].get('input_tokens',c['usage'].get('prompt_tokens',0)) for c in settled),
            'output_tokens': sum(c['usage'].get('output_tokens',c['usage'].get('completion_tokens',0)) for c in settled),
            'native_reasoning_output_tokens': sum(c['usage'].get('reasoning_output_tokens',0) for c in settled),
        }
    result = {'rows': rows, 'planned_trials': len(manifest['order']), 'started_trials': len(trials),
              'complete_trials': sum('cold_state_equal' in v for v in trials),
              'initial_observation_hashes_by_scenario': {k: sorted(v) for k,v in initial_hashes.items()},
              'identical_initial_information': all(len(v)==1 for v in initial_hashes.values()),
              'total_recorded_calls_including_preflight':len(all_receipts),
              'unsettled_calls':[c['call_id'] for c in all_receipts if c.get('status')!='settled'],
              'provider_totals_including_preflight': provider_totals,
              'interpretation': 'Exploratory paired trials. Shared personal observations and world state; provider harnesses differ. Codex usage is subscription consumption, not API expenditure. Delegation is a bounded action queue over existing capabilities, not free-form code or autonomous rule creation.'}
    (out / 'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('out',type=Path)
    args=parser.parse_args()
    print(json.dumps(summarize(args.out),ensure_ascii=False,indent=2))
