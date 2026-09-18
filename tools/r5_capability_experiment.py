"""R5 extension: compare two model grades before and after one GM-built capability.

The existing world is copied, every returned reply is archived, and developer work
and admission are explicit separate stages. No automatic GM review or paid retry.
"""
import argparse
import json
from pathlib import Path

import model_interface_experiment as base

OUT = base.ROOT / 'tmp/r5-capability-20260915'
RUNTIME = 'game/experiments/r5_gm_runtime.gd'
CONTRACT = 'game/experiments/r5_gm_capability.json'
GOAL = 'Your initial wish is to turn an existing ration into a warm meal and keep it until you return home to eat. Choose your method, change your goal, ask a GM with development capabilities for help, or give up. A ration is the existing abstract food; it is not already fish or hot soup.'
INSTRUCTIONS = '''You are a resident of a persistent town. Act only on the personal observations and actual world actions provided.
You are not a coding assistant. Do not read files, access the network or use external tools. Return JSON without Markdown.
Use English for all natural-language fields, including goal, reason, speech and change_request, even when historical evidence is in another language. Keep action identifiers unchanged.
World consequences require executed actions. Renaming or narration cannot create food, change supplies or install capabilities.
Use the complete id from options for each action; there are no aliases such as a1. You may execute one action, observe its actual result, and then choose the next step.
If your method needs a missing capability, tell the independent GM what change you want and how you would use it. The GM may implement it, offer advice or refuse.
You do not have to design the GM's code or build anything. Retain your goals and completed actions; plans are not results.
Higher satiety means fuller, and higher energy means more stamina. Existing eat_ration really travels home and consumes one ration; rest also travels home.
Output concise goal, reason and speech fields (speech may be empty); kind is act/request_change/stop. For act, include option_id. For request_change, include a change_request string.
'''


def configured_providers():
    base.COMMON = INSTRUCTIONS
    base.ARM['r5'] = 'Continue your life from the current observation. Keep development advice, actual execution and successful results distinct.'
    return base.Providers(OUT)


def host(directory, source, installed):
    return base.Probe(directory, source, script='res://experiments/r5_capability_probe.gd',
                      extra_args=['--r5-gm-runtime'] if installed else [])


def archived_entry(observation, call_id, raw, receipt):
    return {'world_id': observation['world_id'], 'request_id': 'r5:'+call_id,
            'resident_id': base.RESIDENT, 'provider_id': receipt['model'], 'original_reply': raw,
            'assistant_text': receipt['assistant_text'], 'assistant_text_parts': [receipt['assistant_text']],
            'application': {'status':'r5_experiment_reply_received'}, 'model_returned':True}


def observe_payload(observation, trace, persisted):
    view = json.loads(json.dumps(observation['view']))
    view['needs']['satiety'] = view['needs'].pop('hunger', None)
    view['experiences'] = view.get('experiences', [])[-10:]
    view['observations'] = view.get('observations', [])[-8:]
    return {'initial_wish':GOAL, 'persistent_goal_and_last_decision':persisted,
            'personal_observation':view, 'options':observation['options'],
            'own_position':observation['position'], 'own_home':observation['home'],
            'recent_actual_results':trace[-4:]}


def save_result(directory, result):
    base.write(directory/'result.json', result)


def run_trial(provider, repetition, phase):
    installed = phase == 'after'
    name = f'{phase}-{provider}-{repetition}'
    directory = OUT/'trials'/name
    if directory.exists():
        result = base.read(directory/'result.json')
        if result.get('closed'):
            return result
        raise RuntimeError('inspect_interrupted_trial_before_resuming_'+name)
    contract = None
    if installed:
        review = base.read(OUT/'review.json')
        assert review['decision']=='advisory' and review['runtime_sha256']==base.sha(base.ROOT/RUNTIME)
        assert review['contract_sha256']==base.sha(base.ROOT/CONTRACT)
        contract = base.read(base.ROOT/CONTRACT)
        before_result = base.read(OUT/'trials'/f'before-{provider}-{repetition}'/'result.json')
        assert before_result.get('closed')
        source = Path(before_result['final_world'])
    else:
        source = base.SOURCE
    directory.mkdir(parents=True)
    result = {'trial':name,'phase':phase,'provider':provider,'model':base.MODELS[provider],
              'source_world_sha256':base.sha(source),'calls':[],'actions':[],'status':'running',
              'developer_present':installed,'initial_wish':GOAL}
    save_result(directory,result)
    providers = configured_providers()
    engine = None
    trace = []
    observation = None
    try:
        engine = host(directory/'live',source,installed)
        observation = engine.request('observe')
        initial = observation
        base.write(directory/'initial-observation.json',initial)
        result['initial_observation_sha256']=base.sha(directory/'initial-observation.json')
        for turn in range(4):
            persisted = observation.get('plan_state', {})
            call_id = f'{name}-c{turn+1}'
            decision,receipt,raw = providers.call(provider,'r5',observe_payload(observation,trace,persisted),call_id)
            result['calls'].append(receipt)
            entry = archived_entry(observation,call_id,raw,receipt)
            remembered = engine.request('remember',entry=entry,plan_state={
                'experiment':'H86','trial':name,'goal':decision.get('goal') if isinstance(decision,dict) else None,
                'decision':decision,'last_actual_results':trace[-4:]})
            assert remembered.get('ok'),'archive_failed'
            if not isinstance(decision,dict):
                result['status']='invalid_response';break
            kind=decision.get('kind')
            if kind=='request_change':
                result['status']='development_requested'
                result['change_request']=decision.get('change_request','')
                break
            if kind=='stop':
                result['status']='voluntary_stop';break
            if kind!='act':
                result['status']='invalid_response';break
            option_id=decision.get('option_id')
            options={o['id']:o for o in observation['options']}
            if option_id not in options:
                trace.append({'option_id':option_id,'ok':False,'code':'unknown_option_id','executed':False})
                save_result(directory,result)
                continue
            observation=engine.request('apply',option_id=option_id,command_id=f'r5:{name}:{turn}',seconds=180,
                speech=decision.get('speech','') if options[option_id].get('speech_allowed') else '')
            world=base.read(engine.world)
            events=[e for e in world['life']['events'] if e.get('seq',0)>initial['seq'] and e.get('actor_id')==base.RESIDENT]
            action={'option_id':option_id,'submission':observation.get('action_result'),
                    'pending':observation['pending'],'actual_events':events,
                    'inventory':observation['view'].get('inventory'), 'personal_view':observation['view'],
                    'position':observation['position'],'advanced_seconds':observation.get('advanced_seconds')}
            result['actions'].append(action);trace.append(action)
            engine.request('remember',entry=entry,plan_state={'experiment':'H86','trial':name,
                'goal':decision.get('goal'),'decision':decision,'last_actual_results':trace[-4:]})
            if observation['pending']:
                result['status']='action_still_pending';break
            if installed and option_id==contract['prepare_action_id'] and not result.get('midplan_restart'):
                # Restart after preparation, before the resident decides whether to eat.
                snapshot=base.read(engine.world);old_world=engine.world
                engine.close();engine=None
                engine=host(directory/'resumed',old_world,True)
                observation=engine.request('observe')
                result['midplan_restart']={'full_state_equal':snapshot==base.read(engine.world),
                    'saved_goal':observation.get('plan_state',{}).get('goal')}
                assert result['midplan_restart']['full_state_equal'],'midplan_restore_changed_state'
            if installed:
                types=[e['type'] for e in events]
                if contract['prepare_event'] in types and contract['consume_event'] in types:
                    result['status']='prepared_and_consumed';break
            save_result(directory,result)
        if result['status']=='running':result['status']='decision_limit'
        result['final_observation']=observation
        result['final_world']=str(engine.world)
    except BaseException as error:
        result['status']='execution_error';result['error_type']=type(error).__name__
        result['error']=str(error)[:180]
        raise
    finally:
        if engine is not None:
            result['final_world']=str(engine.world)
            engine.close()
        save_result(directory,result)
        assert base.sha(base.SOURCE)==base.SOURCE_SHA
    world=base.read(result['final_world'])
    cold=host(directory/'cold',result['final_world'],installed)
    try:restored=cold.request('observe')
    finally:cold.close()
    result['cold_state_equal']=world==base.read(cold.world)
    result['all_replies_archived']=all('r5:'+r['call_id'] in world['godot']['resident_archive']['entries'] for r in result['calls'])
    result['identities_preserved']=[r['stable_id'] for r in world['residents']]==[r['stable_id'] for r in base.read(base.SOURCE)['residents']]
    result['final_world']=str(cold.world)
    result['closed']=True
    save_result(directory,result)
    base.emit({'trial':name,'status':result['status'],'calls':len(result['calls']),
               'actions':len(result['actions']),'cold_equal':result['cold_state_equal'],
               'midplan_restart':result.get('midplan_restart',{}).get('full_state_equal')})
    return result


def main():
    global OUT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['before','after'])
    base.add_runtime_arguments(parser, OUT)
    args=parser.parse_args()
    base.configure_runtime(args)
    OUT=args.out.resolve()
    assert base.sha(base.SOURCE)==base.SOURCE_SHA
    order=[('luna',1),('astra',1),('astra',2),('luna',2)]
    manifest={'order':order,'instructions':INSTRUCTIONS,'goal':GOAL,'max_calls':4,
              'source_world_sha256':base.SOURCE_SHA,'source_files_sha256':{p:base.sha(base.ROOT/p) for p in
              ['tools/r5_capability_experiment.py','game/experiments/r5_capability_probe.gd',
               'tools/model_interface_experiment.py','game/experiments/model_interface_probe.gd']}}
    base.freeze_manifest(OUT/'manifest.json',manifest)
    for provider,repetition in order:run_trial(provider,repetition,args.phase)


if __name__=='__main__':main()
