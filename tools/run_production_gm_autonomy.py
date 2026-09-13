#!/usr/bin/env python3
"""Finite production bridge for the maintained ten-resident world and retained ten GM sessions.

The bridge alternates fully closed canonical life phases and gm_autonomy cycles under one reviewed
scope. It never selects an issue, edits a candidate, approves a release, or calls a provider
itself. The resident launcher and GM runner remain the only model routes. A deployment is verified
on a COPY; real resident adoption is observed only in a later sole-writer canonical life phase.
"""
from __future__ import annotations
import argparse, datetime as dt, hashlib, json, math, os, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gm_runner
import gm_autonomy
from owned_windows_job import WindowsProcessTree

SCHEMA = 1
ELAPSED_TOLERANCE = 1e-6
OPERATIONAL_EVIDENCE_NAME = 'gm-operational-evidence.json'
OPERATIONAL_EVIDENCE_KIND = 'host_operational_controller_failure'

# Only explicitly published, sanitized controller error identifiers may cross the host bridge.
# The list is the published vocabulary of game/agents/resident_brain.gd (including the GM-03 exact
# input-size class and the legacy local request-cap constant). Anything else - raw provider text,
# secrets, unknown categories - yields None so the bridge never forwards unverified text.
KNOWN_CONTROLLER_ERROR_IDENTIFIERS = (
    'brain_input_too_large',
    'brain_context_window_exceeded',
    'brain_session_request_limit',
    'brain_gateway_validation_failed',
    'brain_gateway_rejected_or_uncertain',
    'brain_provider_failed',
    'brain_response_invalid',
    'brain_run_failed',
    'brain_run_canceled',
    'brain_timeout',
)

def known_error_identifier(turn):
    """Return the published sanitized identifier a controller record carries, else None."""
    value = turn.get('error') if isinstance(turn, dict) else None
    return value if isinstance(value, str) and value in KNOWN_CONTROLLER_ERROR_IDENTIFIERS else None

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def load(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def save(path, value):
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_name(path.name+'.new'); tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    os.replace(tmp,path)
def resolve(value):
    p=Path(value); return p.resolve() if p.is_absolute() else (ROOT/p).resolve()
def tracked():
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    names=subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines()
    return {'head':head,'files':{n:sha(ROOT/n) for n in names if (ROOT/n).is_file()}}
def expand(command, values):
    out=[]
    for token in command:
        for k,v in values.items(): token=token.replace('{'+k+'}',str(v))
        if '{' in token or '}' in token: raise ValueError('unresolved command placeholder')
        out.append(token)
    return out
def run_owned(command,cwd,timeout,log,env=None):
    log.parent.mkdir(parents=True,exist_ok=True)
    with log.open('w',encoding='utf-8') as stream:
        with WindowsProcessTree(command,cwd=cwd,stdout=stream,stderr=subprocess.STDOUT,
                                env=env) as tree:
            timed=False
            try: code=tree.wait(timeout)
            except subprocess.TimeoutExpired:
                tree.terminate(); code=130; timed=True
            owned=tree.snapshot()
    return {'exit_code':code,'timed_out':timed,'owned':owned}

def validate(scope):
    errors=[]
    required=('world_id','canonical_world','gm_state_dir','deployment_checkout','autonomy_policy_template',
              'life_command','out_root','max_cycles','max_seconds','life_timeout','autonomy_timeout','head',
              'stop_file','status_path','life_max_requests','max_kimi_requests','max_gm_model_calls',
              'canonical_world_sha256','settlement_reserve_seconds')
    for k in required:
        if k not in scope: errors.append('missing '+k)
    if scope.get('schema_version') != SCHEMA: errors.append('schema_version must be 1')
    if not isinstance(scope.get('life_command'),list) or not scope.get('life_command'): errors.append('life_command argv required')
    if not any('{max_requests}' in token for token in scope.get('life_command', [])):
        errors.append('life_command must bind {max_requests} for the lifetime limit')
    if not isinstance(scope.get('max_cycles'),int) or not 1<=scope.get('max_cycles',0)<=100000: errors.append('max_cycles 1..100000')
    for k in ('max_seconds','life_timeout','autonomy_timeout'):
        if not isinstance(scope.get(k),int) or scope.get(k,0)<=0: errors.append(k+' positive integer required')
    for k in ('life_max_requests','max_kimi_requests','max_gm_model_calls'):
        if not isinstance(scope.get(k),int) or scope.get(k,0)<=0: errors.append(k+' positive integer required')
    if (not isinstance(scope.get('settlement_reserve_seconds'),int)
            or scope.get('settlement_reserve_seconds',-1)<0):
        errors.append('settlement_reserve_seconds non-negative integer required')
    for k in ('stop_file','status_path'):
        if not isinstance(scope.get(k),str) or not scope.get(k): errors.append(k+' required for ongoing operation')
    if scope.get('head') and scope['head'] != subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(): errors.append('HEAD pin mismatch')
    for k in ('canonical_world','gm_state_dir','deployment_checkout','autonomy_policy_template'):
        if scope.get(k) and not resolve(scope[k]).exists(): errors.append(k+' missing')
    out=resolve(scope.get('out_root','.'))
    if out.exists(): errors.append('out_root must be absent')
    for k,kind in (('cutoff_utc',str),('admission_buffer_seconds',int),('require_fresh_final_evidence',bool)):
        if k in scope and scope[k] is not None and type(scope[k]) is not kind: errors.append(k+' has the wrong type')
    if 'cutoff_utc' in scope and scope['cutoff_utc']:
        try:
            parsed_cutoff=dt.datetime.fromisoformat(str(scope['cutoff_utc']).replace('Z','+00:00'))
            if parsed_cutoff.tzinfo is None:
                errors.append('cutoff_utc must include a timezone offset (naive timestamps are refused)')
        except ValueError: errors.append('cutoff_utc must be an ISO-8601 timestamp')
    if errors: return errors
    world=load(resolve(scope['canonical_world']))
    ids=[x.get('stable_id') for x in world.get('residents',[]) if isinstance(x,dict)]
    if world.get('world_id')!=scope['world_id'] or len(ids)!=10 or len(set(ids))!=10: errors.append('canonical world identity/ten residents mismatch')
    if sha(resolve(scope['canonical_world'])) != scope.get('canonical_world_sha256'):
        errors.append('canonical world hash pin mismatch')
    state=gm_runner.load_state(resolve(scope['gm_state_dir']))
    if state.get('world_id')!=scope['world_id'] or len(state.get('sessions',{}))!=10: errors.append('retained GM state/world/ten identities mismatch')
    unknown=gm_runner.global_unknown_gms(state)
    if unknown: errors.append('unresolved unknown-cost GM attempts: '+','.join(unknown))
    return errors

def controller_error_matches(world, actor, expected):
    turn=(world.get('godot',{}).get('resident_turns',{}).get(actor) or {})
    result=turn.get('result') if isinstance(turn.get('result'),dict) else {}
    return (turn.get('status')==expected.get('status')
            and turn.get('request_id')==expected.get('request_id')
            and result.get('code')==expected.get('result_code')
            and turn.get('replan_policy')==expected.get('replan_policy'))

def build_operational_evidence(source_path, local_failures, destination):
    """Host operational projection for the GM intake.

    The game's own public export is copied verbatim (its world_id, source_revision, evidence
    list and proposals are preserved exactly) and one entry per degraded controller is
    appended. Only the whitelisted receipt fields are added - never raw error text, a
    resident's reason or speech, an accepted reply, cognition or a log line - and the source
    export bytes are never modified. The host-added entries are labelled as host observations,
    not NPC requests and not engine-created facts.
    """
    source=load(source_path)
    source_sha=sha(source_path)
    document=dict(source) if isinstance(source,dict) else {}
    document['kind']=gm_runner.EVIDENCE_KIND
    document['schema_version']=gm_runner.EVIDENCE_SCHEMA
    boundaries=document.get('boundaries') if isinstance(document.get('boundaries'),dict) else {}
    for flag in gm_runner.REQUIRED_BOUNDARY_FLAGS: boundaries.setdefault(flag, False)
    document['boundaries']=boundaries
    evidence=list(document.get('evidence') or []); proposals=list(document.get('proposals') or [])
    appended=0
    for receipt in local_failures or []:
        evidence.append({'evidence_kind':OPERATIONAL_EVIDENCE_KIND,
                         'issue_id':'host:controller_failure:'+str(receipt.get('actor')),
                         'status':'open',
                         'source':'host_bridge_operational_projection',
                         'origin':'host_operational_projection_not_npc_not_engine',
                         'operational':{'actor':receipt.get('actor'),
                                        'controller_status':receipt.get('controller_status'),
                                        'request_id':receipt.get('request_id'),
                                        'code':receipt.get('code'),
                                        'result_code':receipt.get('result_code'),
                                        'replan_policy':receipt.get('replan_policy'),
                                        'classification':receipt.get('classification'),
                                        'error_identifier':receipt.get('error_identifier')}})
        appended+=1
    document['evidence']=evidence; document['proposals']=proposals
    document['counts']={'issues':len(evidence),'proposals':len(proposals)}
    document['operational_projection']={'label':'host operational projection; appended entries are host-observed controller receipts, not NPC requests or engine-created facts',
        'source_export':str(source_path),'source_export_sha256':source_sha,'appended_operational_entries':appended}
    save(destination,document)
    return {'path':str(destination),'sha256':sha(destination),'source_export_sha256':source_sha,
            'appended_operational_entries':appended,
            'source_export_bytes_unchanged':sha(source_path)==source_sha,
            'counts':document['counts'],'parser_errors':gm_runner.validate_evidence(document)}


def verify_journey_stall(argv):
    ap=argparse.ArgumentParser()
    for name in ('save','out','release','issue','identity','target','target-sha','evidence','phase','godot','checkout','source-world-sha'):
        ap.add_argument('--'+name,required=True)
    ap.add_argument('--seconds',type=int,default=60)
    args=ap.parse_args(argv)
    save_path,out_path,evidence_path=Path(args.save).resolve(),Path(args.out).resolve(),Path(args.evidence).resolve()
    checkout=Path(args.checkout).resolve(); target=(checkout/args.target).resolve()
    before=load(save_path); source=load(evidence_path)
    save_before_sha=sha(save_path)
    normalized_target=args.target.replace('\\','/').lstrip('./')
    if (not 5<=args.seconds<=180 or not args.identity.startswith('journey_stall:')
            or normalized_target != 'game/spatial/town_street.gd'):
        return 2
    source_issue=next((x for x in source.get('evidence',[]) if isinstance(x,dict)
                       and x.get('issue_id')==args.identity and x.get('status')=='open'),None)
    run_out=out_path.parent/(out_path.stem+'-town')
    gm_export=run_out/'gm'/'evidence.json'
    command=[sys.executable,str(checkout/'tools/run_godot.py'),'--godot',args.godot,
             '--name','gm-autonomy-town-contract','--timeout',str(args.seconds+45),'--out',str(run_out),'--',
             '--headless','--audio-driver','Dummy','res://scenes/town_street.tscn','--',
             '--town-save='+str(save_path),'--town-restore','--town-capture='+str(run_out/'capture'),
             '--town-duration='+str(args.seconds),'--town-gm-export='+str(gm_export)]
    clean=dict(os.environ); clean.pop('AINCRAD_GATEWAY_RUN_CONFIG',None)
    outcome=run_owned(command,checkout,args.seconds+60,run_out.with_suffix('.log'),env=clean)
    after=load(save_path) if save_path.is_file() else {}
    projection=load(gm_export) if gm_export.is_file() else {}
    # The closure arm is only causally valid when this run really produced a readable
    # public projection for this world. A missing, empty or unreadable export must never
    # be read as "the journey stall was resolved".
    projection_read=(gm_export.is_file() and isinstance(projection,dict)
                     and isinstance(projection.get('evidence'),list)
                     and projection.get('world_id')==before.get('world_id'))
    after_issue=next((x for x in (projection.get('evidence') if projection_read else []) if isinstance(x,dict)
                      and x.get('issue_id')==args.identity and x.get('status')=='open'),None)
    old_remaining=((source_issue or {}).get('physical_facts') or {}).get('remaining_distance')
    new_remaining=((after_issue or {}).get('physical_facts') or {}).get('remaining_distance')
    progressed=((after_issue is None and projection_read) or (isinstance(old_remaining,(int,float))
                and isinstance(new_remaining,(int,float)) and new_remaining<old_remaining))
    old_events=before.get('life',{}).get('events',[]); new_events=after.get('life',{}).get('events',[])
    old_ids=[item.get('stable_id') for item in before.get('residents',[]) if isinstance(item,dict)]
    new_ids=[item.get('stable_id') for item in after.get('residents',[]) if isinstance(item,dict)]
    causal={'actual_town_scene_exited':outcome['exit_code']==0 and not outcome['timed_out'],
            'owned_processes_exited':(outcome.get('owned') or {}).get('all_members_exited') is True,
            'loaded_exact_release_target':target.is_file() and sha(target)==args.target_sha,
            'source_issue_was_open':source_issue is not None,
            'public_projection_present_and_readable':projection_read,
            'bound_journey_progressed_or_closed':progressed,
            'world_and_history_continued':after.get('world_id')==before.get('world_id')
                and new_events[:len(old_events)]==old_events,
            'same_ten_resident_identities':len(old_ids)==10 and len(set(old_ids))==10
                and new_ids==old_ids,
            'no_model_gateway_used':'AINCRAD_GATEWAY_RUN_CONFIG' not in clean}
    payload={'ok':all(causal.values()),'continuation_ok':causal['world_and_history_continued'],
             'world_id':before.get('world_id'),'issue_id':args.issue,'issue_identity':args.identity,
             'release_digest':args.release,'source_world_sha256':args.source_world_sha,
             'loaded_target_sha256':sha(target) if target.is_file() else None,
             'causal_checks':causal,'observed_facts':{
                 'save_copy_sha256_before_run':save_before_sha,
                 'declared_source_world_sha256':args.source_world_sha,
                 'declared_source_matches_loaded_copy':save_before_sha==args.source_world_sha,
                 'projection_world_id':(projection.get('world_id') if isinstance(projection,dict) else None),
                 'after_issue_present':after_issue is not None},
             'resident_adoption':False,'phase':args.phase,
             'owned_processes_exited':(outcome.get('owned') or {}).get('all_members_exited')}
    save(out_path,payload); print(json.dumps(payload)); return 0 if payload['ok'] else 1

def main(argv=None):
    if argv is None: argv=sys.argv[1:]
    if argv and argv[0]=='verify-journey-stall':
        return verify_journey_stall(argv[1:])
    ap=argparse.ArgumentParser(); ap.add_argument('--scope',type=Path,required=True); ap.add_argument('--preflight',action='store_true')
    args=ap.parse_args(argv); scope=load(args.scope); errors=validate(scope)
    if errors: print(json.dumps({'status':'refused','errors':errors})); return 2
    cutoff=None
    if scope.get('cutoff_utc'):
        # validate() already checked this; the guard exists so no naive or malformed value can
        # raise inside the loop (a crash would leave the run without a checkpoint).
        try:
            cutoff=dt.datetime.fromisoformat(str(scope['cutoff_utc']).replace('Z','+00:00'))
        except ValueError:
            print(json.dumps({'status':'refused','errors':['cutoff_utc unparseable at runtime']})); return 2
        if cutoff.tzinfo is None:
            print(json.dumps({'status':'refused','errors':['cutoff_utc must include a timezone offset']})); return 2
    if args.preflight: print(json.dumps({'status':'ready','model_calls':0})); return 0
    out=resolve(scope['out_root']); out.mkdir(parents=True)
    baseline=tracked(); deadline=time.monotonic()+scope['max_seconds']
    admission_buffer=int(scope.get('admission_buffer_seconds') or scope.get('settlement_reserve_seconds') or 120)
    run={'schema_version':1,'status':'running','scope_sha256':sha(args.scope),'head':baseline['head'],'cycles':[],'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'pid':os.getpid(),'kimi_requests':0,'gm_model_calls':0,'counted_gm_cycle_ids':[]}
    def checkpoint():
        save(out/'run.json',run)
        save(resolve(scope['status_path']), {'status':run['status'],'reason':run.get('reason'),
             'pid':os.getpid(),'started_utc':run['started_utc'],'run':str(out/'run.json'),
             'cycles':len(run['cycles']),'kimi_requests':run['kimi_requests'],
             'gm_model_calls':run['gm_model_calls'],
             'updated_utc':dt.datetime.now(dt.timezone.utc).isoformat()})
    checkpoint()
    world=resolve(scope['canonical_world']); deployment=resolve(scope['deployment_checkout'])
    for index in range(1,scope['max_cycles']+1):
        stop_file=resolve(scope['stop_file']) if scope.get('stop_file') else None
        if stop_file and stop_file.exists(): run.update(status='stopped',reason='operator_stop_file'); break
        if run['kimi_requests']>=int(scope.get('max_kimi_requests',2147483647)) or run['gm_model_calls']>=int(scope.get('max_gm_model_calls',2147483647)):
            run.update(status='stopped',reason='lifetime_model_call_limit'); break
        if time.monotonic()>=deadline: run.update(status='stopped',reason='time_limit'); break
        full_cycle_budget=(scope['life_timeout']+scope['autonomy_timeout']
                           +scope['settlement_reserve_seconds'])
        if deadline-time.monotonic() < full_cycle_budget:
            run.update(status='stopped',reason='time_limit'); break
        if cutoff is not None:
            left=(cutoff-dt.datetime.now(dt.timezone.utc)).total_seconds()
            if left <= 0:
                run.update(status='stopped',reason='absolute_cutoff'); break
            if left < full_cycle_budget+admission_buffer:
                run.update(status='stopped',reason='absolute_cutoff_admission_buffer'); break
        remaining_kimi=int(scope['max_kimi_requests'])-run['kimi_requests']
        remaining_gm=int(scope['max_gm_model_calls'])-run['gm_model_calls']
        if remaining_kimi <= 0 or remaining_gm <= 0:
            run.update(status='stopped',reason='lifetime_model_call_limit'); break
        phase=out/f'cycle-{index:02d}'; phase.mkdir(); live=phase/'life'
        evidence=live/'gm'/'live-evidence.json'
        values={'world':world,'out':live,'evidence':evidence,'deployment':deployment,'root':ROOT,
                'max_requests':min(int(scope['life_max_requests']),remaining_kimi)}
        command=expand(scope['life_command'],values)
        before_world=phase/'world-before.json'; shutil.copyfile(world,before_world)
        record={'index':index,'status':'life_in_flight','world_before_sha256':sha(world),'life_command':command}
        run['cycles'].append(record); checkpoint()
        life=run_owned(command,deployment,scope['life_timeout'],phase/'life.log'); record['life']=life
        result=load(live/'result.json') if (live/'result.json').is_file() else None
        record['life_result']=result
        if (life['exit_code'] not in (0,1) or life['timed_out']
                or (life.get('owned') or {}).get('all_members_exited') is not True
                or not evidence.is_file()
                or not result or result.get('engine_exit') != 0
                or result.get('budget_stop_reason') not in ('', None)
                or result.get('carried_uncertainty_reviewed') is not True):
            run.update(status='stopped',reason='life_failed_or_missing_evidence'); break
        if tracked()!=baseline:
            run.update(status='stopped',reason='development_checkout_changed'); break
        run['kimi_requests']+=int(result.get('upstream_requests') or 0)
        before_ledger=result.get('ledger_before') or {}; after_ledger=result.get('ledger_after') or {}
        ledger_stable=(before_ledger.get('ledger_id')==after_ledger.get('ledger_id')
            and before_ledger.get('model')==after_ledger.get('model')
            and (before_ledger.get('counts') or {}).get('uncertain')
                == (after_ledger.get('counts') or {}).get('uncertain')
            and not after_ledger.get('halted'))
        if not ledger_stable:
            run.update(status='stopped',reason='ledger_identity_or_uncertainty_changed'); break
        model_errors=result.get('model_errors') or {}
        allowed=scope.get('allowed_existing_model_errors') or {}
        after_world=load(world); before_world_state=load(before_world)
        local_failures=[]; fatal_errors=[]
        for actor,code in sorted(model_errors.items()):
            turn=(after_world.get('godot',{}).get('resident_turns',{}).get(actor) or {})
            result_code=((turn.get('result') or {}).get('code'))
            receipt={'actor':actor,'code':code,'controller_status':turn.get('status'),
                     'request_id':turn.get('request_id'),'result_code':result_code,
                     'replan_policy':turn.get('replan_policy'),
                     'error_identifier':known_error_identifier(turn)}
            if (actor in allowed and code==allowed[actor].get('status')
                    and controller_error_matches(after_world,actor,allowed[actor])
                    and controller_error_matches(before_world_state,actor,allowed[actor])):
                receipt['classification']='known_stale_option_cooldown'
                local_failures.append(receipt); continue
            # A settled resident-local failure keeps its exact receipt and stays quarantined
            # to that resident: a provider_error, or a rule_rejection with a recorded
            # authoritative result code and request id. The ledger-uncertainty equality
            # above already proves this attempt created no new unknown cost, so this is a
            # degraded resident, not a global fault. Nothing is reset or forced here.
            if (code in ('provider_error','rule_rejection') and turn.get('request_id')
                    and turn.get('status')==code):
                receipt['classification']='resident_local_settled_quarantine'
                local_failures.append(receipt); continue
            receipt['classification']='fatal_global_or_ambiguous'
            fatal_errors.append(receipt)
        if local_failures:
            record['local_failures']=local_failures
            run['local_failures_total']=int(run.get('local_failures_total',0))+len(local_failures)
            run['degraded_residents']=sorted({r['actor'] for r in local_failures})
            run['local_failure_classes']=sorted({r['classification'] for r in local_failures})
            checkpoint()
        if fatal_errors:
            record['fatal_errors']=fatal_errors
            run.update(status='stopped',reason='new_life_model_error'); break
        freshness=None
        try:
            projection=load(evidence)
            revision=(projection.get('source_revision') or {}) if isinstance(projection,dict) else {}
            world_now=load(world)
            world_id_ok=isinstance(projection,dict) and projection.get('world_id')==world_now.get('world_id')==scope.get('world_id')
            export_seq=revision.get('life_seq'); world_seq=(world_now.get('life') or {}).get('seq')
            seq_ok=isinstance(export_seq,int) and isinstance(world_seq,int) and export_seq==world_seq
            if isinstance(world_now.get('elapsed_seconds'),(int,float)):
                world_elapsed=world_now.get('elapsed_seconds'); elapsed_source='world.elapsed_seconds'
            else:
                world_elapsed=(world_now.get('godot') or {}).get('elapsed_seconds'); elapsed_source='godot.elapsed_seconds'
            export_elapsed=revision.get('world_elapsed_seconds')
            time_ok=(isinstance(export_elapsed,(int,float)) and isinstance(world_elapsed,(int,float))
                     and math.isfinite(float(export_elapsed)) and math.isfinite(float(world_elapsed))
                     and abs(float(export_elapsed)-float(world_elapsed))<=ELAPSED_TOLERANCE)
            fresh=bool(world_id_ok and seq_ok and time_ok)
            freshness={'world_id_matches':world_id_ok,'export_life_seq':export_seq,'world_life_seq':world_seq,
                       'life_seq_exact_match':seq_ok,'export_world_elapsed_seconds':export_elapsed,
                       'world_elapsed_seconds':world_elapsed,'world_elapsed_source':elapsed_source,
                       'elapsed_tolerance':ELAPSED_TOLERANCE,'elapsed_matches':time_ok,'fresh':fresh}
        except Exception:
            freshness={'fresh':None,'error':'projection_unreadable'}
        record['final_evidence_freshness']=freshness
        if scope.get('require_fresh_final_evidence') and freshness.get('fresh') is not True:
            run.update(status='stopped',reason='final_evidence_stale_or_unverifiable'); break
        post_life_sha=sha(world)
        policy=load(resolve(scope['autonomy_policy_template']))
        verify_copy=phase/'verify-world.json'; shutil.copyfile(world,verify_copy)
        verify_copy_before=sha(verify_copy)
        policy['mode']='production'; policy['world_id']=scope['world_id']; policy['base_revision']=baseline['head']
        operational=build_operational_evidence(evidence,local_failures,phase/OPERATIONAL_EVIDENCE_NAME)
        record['operational_evidence']=operational
        if operational['parser_errors']:
            run.update(status='stopped',reason='operational_evidence_invalid'); break
        policy['paths']['evidence']=operational['path']; policy['paths']['state_dir']=str(resolve(scope['gm_state_dir']))
        policy['deployment']['checkout']=str(deployment); policy['runtime']['save_path']=str(verify_copy)
        policy.setdefault('limits', {})['max_model_calls'] = min(
            int(policy.get('limits', {}).get('max_model_calls', 64)), remaining_gm)
        policy['limits']['deadline_seconds'] = max(1, min(
            int(policy['limits'].get('deadline_seconds', scope['autonomy_timeout'])),
            int(deadline-time.monotonic())))
        policy_path=phase/'autonomy-policy.json'; save(policy_path,policy)
        auto=[sys.executable,str(ROOT/'tools/gm_autonomy.py'),'cycle','--policy',str(policy_path)]
        auto += [str(x) for x in scope.get('gm_runner_args',[])]
        record['status']='autonomy_in_flight'; record['evidence_sha256']=sha(evidence); checkpoint()
        autonomous=run_owned(auto,ROOT,scope['autonomy_timeout'],phase/'autonomy.log'); record['autonomy']=autonomous
        report=None
        # gm_autonomy emits one JSON object to its log; durable report remains under retained state.
        try:
            text=(phase/'autonomy.log').read_text(encoding='utf-8'); report=gm_autonomy.last_json_line(text)
        except Exception: pass
        record['autonomy_summary']=report
        if (autonomous['exit_code']!=0 or autonomous['timed_out']
                or (autonomous.get('owned') or {}).get('all_members_exited') is not True or not report):
            run.update(status='stopped',reason='autonomy_failed'); break
        if report.get('status') not in ('completed','no_action','limit_reached'):
            run.update(status='stopped',reason='autonomy_not_terminal_success'); break
        runtime_checks=(report.get('independently_tested') or {}).get('runtime_checks') or {}
        if report.get('status')=='completed' and (not runtime_checks or not all(runtime_checks.values())):
            run.update(status='stopped',reason='release_not_host_verified'); break
        gm_cycle_id=report.get('cycle_id')
        if not isinstance(gm_cycle_id,str) or not gm_cycle_id:
            run.update(status='stopped',reason='autonomy_report_missing_cycle_id'); break
        if gm_cycle_id not in run['counted_gm_cycle_ids']:
            run['gm_model_calls']+=int(((report.get('usage') or {}).get('model_calls')) or 0)
            run['counted_gm_cycle_ids'].append(gm_cycle_id)
            record['gm_usage_counted']=True
        else:
            record['gm_usage_counted']=False
        if run['gm_model_calls'] > int(scope['max_gm_model_calls']):
            run.update(status='stopped',reason='lifetime_gm_limit_exceeded'); break
        if sha(world) != post_life_sha:
            run.update(status='stopped',reason='canonical_world_changed_during_gm_cycle'); break
        if sha(verify_copy)!=verify_copy_before and report.get('status')!='completed':
            run.update(status='stopped',reason='verification_copy_changed_without_release'); break
        record['status']='closed'; record['resident_adoption']='pending_next_canonical_life' if report.get('status')=='completed' else 'no_release'
        record['world_after_sha256']=sha(world); checkpoint()
    else: run.update(status='completed_finite',reason='max_cycles')
    run['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat(); run['tracked_frozen']=tracked()==baseline
    checkpoint(); print(json.dumps(run,ensure_ascii=False))
    clean_stops={'operator_stop_file','time_limit','lifetime_model_call_limit','absolute_cutoff','absolute_cutoff_admission_buffer'}
    return 0 if run['status']=='completed_finite' or (run['status']=='stopped' and run.get('reason') in clean_stops) else 1
if __name__=='__main__': raise SystemExit(main())
