"""Report H86 observations and costs; this report does not approve game releases."""
from collections import defaultdict
import math

import model_interface_experiment as base
from r5_capability_experiment import OUT, CONTRACT


def summarize():
    manifest = base.read(OUT/'manifest.json')
    contract = base.read(base.ROOT/CONTRACT)
    canonical = base.read(base.SOURCE)
    rows, usage = [], defaultdict(lambda: defaultdict(int))
    for phase in ('before', 'after'):
        for provider, repetition in manifest['order']:
            name = f'{phase}-{provider}-{repetition}'
            directory = OUT/'trials'/name
            r = base.read(directory/'result.json')
            initial = base.read(directory/'initial-observation.json')
            world = base.read(r['final_world'])
            events = [e for e in world['life']['events']
                      if e['seq'] > initial['seq'] and e.get('actor_id') == base.RESIDENT]
            prepared = [e for e in events if e['type'] == contract['prepare_event']]
            eaten = [e for e in events if e['type'] == contract['consume_event']]
            warm = world['godot'].get('warm_food', {})
            commands = warm.get('commands', {})
            completions = [c['result'] for c in commands.values() if c.get('status') == 'completed']
            row = {k:r.get(k) for k in ('trial','provider','status','closed','cold_state_equal',
                    'identities_preserved','all_replies_archived','midplan_restart')}
            row.update(calls=len(r['calls']), actions=[a['option_id'] for a in r['actions']],
                prepared_count=len(prepared), eaten_count=len(eaten),
                same_item_used=bool(prepared and eaten and prepared[0]['meal_id']==eaten[0]['meal_id']),
                initial_rations=initial['view'].get('warm_food',{}).get('rations_held'),
                ration_consumed=sum(c.get('ration_consumed',0) for c in completions),
                held_items=len(warm.get('held',{})),
                satiety_gained=sum(e.get('satiety_gained',0) for e in eaten),
                canonical_events_preserved=world['life']['events'][:len(canonical['life']['events'])]==canonical['life']['events'],
                source_archive_preserved=all(world['godot']['resident_archive']['entries'].get(k)==v
                    for k,v in canonical['godot']['resident_archive']['entries'].items()))
            if phase == 'after':
                before = base.read(OUT/'trials'/f'before-{provider}-{repetition}'/'result.json')
                prior = base.read(before['final_world'])['godot']['resident_archive']['entries']
                row['paired_before_archive_preserved'] = all(
                    world['godot']['resident_archive']['entries'].get(k)==v for k,v in prior.items())
            if r['actions']:
                last=r['actions'][-1]
                row.update(final_rations=last['personal_view'].get('warm_food',{}).get('rations_held'),
                           final_distance_home=math.dist(last['position'],initial['home']),
                           start_to_final_distance=math.dist(last['position'],initial['position']))
            rows.append(row)
            for call in r['calls']:
                usage[provider]['calls'] += 1
                if isinstance(call.get('usage'),dict):
                    for k,v in call['usage'].items():
                        if isinstance(v,int):usage[provider][k] += v
                else:usage[provider]['unmetered_calls'] += 1
    gm=[]
    for phase in ('coding','repair','feedback'):
        path=OUT/'gm-turns'/phase/'receipt.json'
        if path.exists():
            r=base.read(path)
            gm.append({k:r.get(k) for k in ('phase','status','exit_code','elapsed_seconds','session_returned','usage')})
    latest=next((g for g in reversed(gm) if isinstance(g.get('usage'),dict)),None)
    summary={'experiment':'H86','rows':rows,'resident_usage':dict(usage),
        'gm_turns':gm,'gm_latest_session_cumulative':latest['usage'] if latest else None,
        'gm_usage_note':'Resumed native turns report session cumulative counters. Use the latest counters once; they are not a dollar bill. The initial timeout and incomplete initial receipt remain recorded.',
        'canonical_sha256':base.sha(base.SOURCE),'canonical_unchanged':base.sha(base.SOURCE)==base.SOURCE_SHA,
        'harness_unchanged':all(base.sha(base.ROOT/p)==h for p,h in manifest['source_files_sha256'].items()),
        'limitations':['One prompted wish, one original resident, two repeats per model and phase.',
            'After starts from its paired before save, including that models own request and memory.',
            'The GM chose one shared implementation; this is not a comparison of GM model quality.',
            'Home and work point coincide under the explicit new rule. Separate workplace-to-house transport, stove/fuel simulation and spontaneous needs remain untested.',
            'Only isolated probes load the new runtime; production world and original GM sessions remain paused.',
            'Main AI inspection, packaging and model usage are not included in experiment provider counters.']}
    base.write(OUT/'summary.json',summary)
    base.emit({'rows':[{'trial':r['trial'],'status':r['status'],'same_item_used':r['same_item_used'],
        'ration_consumed':r['ration_consumed'],'cold_equal':r['cold_state_equal']} for r in rows],
        'resident_usage':dict(usage),'gm_latest_session_cumulative':summary['gm_latest_session_cumulative'],
        'canonical_unchanged':summary['canonical_unchanged'],'harness_unchanged':summary['harness_unchanged']})
    return summary


if __name__ == '__main__':
    summarize()
