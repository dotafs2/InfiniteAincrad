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

# The only inner-autonomy block this bridge may settle as a local GM failure: an ordinary,
# never-published candidate that failed the host gate, whose owning GM already received that
# exact receipt and answered with a deferring terminal decision. Every other blocked reason
# stays the global stop it already was: guard/scope/conflict refusals, unknown or interrupted
# calls, coding transport failures, published-but-unverified releases and every ambiguous case.
SETTLED_LOCAL_CANDIDATE_BLOCKED_REASONS = ('host_gate_refused_candidate',)
# gm_runner.FEEDBACK_DECISIONS is the authoritative vocabulary. 'accept' and 'no_action' end the
# author's own work on the reported failure; 'repair' reopens the candidate and 'escalate' asks
# the host to act, so neither of those may settle anything locally.
SETTLED_LOCAL_AUTHOR_DECISIONS = ('accept', 'no_action')

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

def deployment_content_digest(checkout, manifest_path):
    """Bounded content digest of the concrete deployment files the pinned base manifest declares.

    Git text status is not evidence about bytes: a dirty tracked file can change content while
    its porcelain entry stays ' M samefile', an untracked file can change with the same '?? path',
    and a checkout that is not itself a repository lets git discover a PARENT repository and
    measure the wrong tree. The manifest's files object is keyed by the concrete deployment
    TARGET path - the same key gm_autonomy publishes with, deployment_target(source, path_map).
    path_map itself is a directory PREFIX map ('game/': '' or 'game/': 'game/', mapped by
    gm_autonomy.deployment_target), so its values are prefixes: they are never hashed as files
    and no directory is ever enumerated. Only the manifest is read, and None means unverifiable.
    """
    if not manifest_path or not Path(manifest_path).is_file(): return None
    try: manifest=load(manifest_path)
    except Exception: return None
    declared=manifest.get('files') if isinstance(manifest,dict) else None
    if not isinstance(declared,dict) or not declared: return None
    declared_safe={}
    for rel,digest in declared.items():
        safe=gm_autonomy.safe_relpath(rel)
        if not safe or not isinstance(digest,str): return None
        declared_safe[safe]=digest
    root=Path(checkout).resolve()
    hashes={}
    for rel in sorted(declared_safe):
        path=(root/rel).resolve()
        if not gm_autonomy.is_within(path,root) or not path.is_file(): return None
        hashes[rel]=sha(path)
    return {'checkout':str(root),'declared_file_count':len(declared_safe),'files':hashes,
            'matches_pinned_base':all(hashes[rel]==digest for rel,digest in declared_safe.items())}

def durable_cycle(report, state_dir):
    """The retained cycle document and its directory, or (None,None) when not trustworthy.

    Only a report.json that resolves to <state_dir>/autonomy/auto-*/report.json is accepted, so
    a forged or stale report path can never point the bridge at an unrelated document.
    """
    value=report.get('report_path') if isinstance(report,dict) else None
    if not isinstance(value,str) or not value: return (None,None)
    try:
        resolved=(Path(value) if Path(value).is_absolute() else (ROOT/value)).resolve()
        autonomy=(Path(state_dir)/'autonomy').resolve()
    except OSError:
        return (None,None)
    if resolved.name!='report.json' or resolved.parent.parent!=autonomy: return (None,None)
    if not resolved.parent.name.startswith('auto-') or not resolved.is_file(): return (None,None)
    document=resolved.with_name('cycle.json')
    if not document.is_file(): return (None,None)
    try: return (load(document),resolved.parent)
    except Exception: return (None,None)

def accounted_model_calls(stages):
    """Measured calls the retained per-stage records account for, or None when not comparable.

    Every dispatched batch must carry its own measured record: the observe stage reports how
    many calls its batch dispatched, and every candidate and feedback attempt must be measured
    on its own durable attempt record. A cycle summary must never be able to hide an unmeasured
    individual attempt.
    """
    observed=(stages.get('observe') or {}).get('model_calls_observed')
    if type(observed) is not int or observed<0: return None
    total=observed
    for name in ('candidate','feedback'):
        for attempt in (stages.get(name) or {}).get('attempts') or []:
            if not isinstance(attempt,dict) or attempt.get('usage_measured') is not True: return None
            total+=1
    return total

def owned_host_test_failure(stages):
    """True only when the retained host-gate detail proves an ordinary, fully owned test failure.

    A plain failing assertion is local work. A timeout, a missing or non-integer exit code, a
    live member or an unstated process tree is not: the host may not certify what it did not
    observe, so the gate refuses to settle. This reads the durable validate stage checks - whose
    detail is the per-command run list - and never infers host execution from a cycle summary,
    which cannot express a timed-out or unsettled host test.
    """
    checks=(stages.get('validate') or {}).get('checks')
    if not isinstance(checks,list) or not checks: return False
    failed=[check.get('check') for check in checks if isinstance(check,dict) and not check.get('ok')]
    if failed!=['host_test_commands_pass']: return False
    detail=None
    for check in checks:
        if isinstance(check,dict) and check.get('check')=='host_test_commands_pass':
            detail=check.get('detail')
    if not isinstance(detail,list) or not detail: return False
    commands=(stages.get('candidate') or {}).get('host_test_commands')
    if not isinstance(commands,list) or len(commands)!=len(detail): return False
    exits=[]
    for run in detail:
        if not isinstance(run,dict): return False
        if type(run.get('exit_code')) is not int: return False
        if run.get('timed_out') is not False: return False
        owned=run.get('owned')
        if not isinstance(owned,dict) or owned.get('all_members_exited') is not True: return False
        members=owned.get('observed_members')
        if not isinstance(members,list) or not members: return False
        if any(not isinstance(member,dict) or member.get('running') is True for member in members):
            return False
        active=owned.get('active_processes')
        if active is not None and active!=0: return False
        if owned.get('containment')=='windows_kill_on_close_job' and active!=0: return False
        exits.append(run['exit_code'])
    # gm_autonomy marks this check failed only when one of its commands exited non-zero, so the
    # ordinary assertion failure this path may settle always carries an explicit non-zero exit.
    # A check marked failed whose commands all reported zero observed no test defect.
    if not any(code!=0 for code in exits): return False
    return True

def settled_local_candidate_failure(report, state_dir, deployment_before, deployment_after):
    """A truthful local-failure receipt, or None when any required fact is absent or ambiguous.

    The fact set is closed and every fact is read from durable evidence: an ordinary
    never-published host-gate candidate failure whose retained host-test detail proves every
    required command exited explicitly inside a fully exited owned tree, per-attempt accounted
    quota calls that match the cycle summary exactly with no unknown, the owning GM's own
    persisted receipt for this exact cycle/issue/world and its deferring terminal decision, a
    deployment content digest unchanged over the manifest-declared files, and an unchanged
    canonical world. Another GM's deferred claims are pending work, not an integrity failure,
    and are neither refused nor touched. A published-but-unverified cycle cannot reach the
    allowlist, so it stays global even when the canonical save bytes are unchanged.
    """
    if not isinstance(report,dict) or report.get('status')!='blocked': return None
    if report.get('blocked_reason') not in SETTLED_LOCAL_CANDIDATE_BLOCKED_REASONS: return None
    if report.get('next_stage') not in ('candidate','validate'): return None
    if report.get('mode')!='production': return None
    world_id=(report.get('policy') or {}).get('world_id')
    if not world_id: return None
    stage_status=report.get('stage_status') or {}
    if stage_status.get('publish')!='pending' or stage_status.get('verify')!='pending': return None
    if list(report.get('what_changed') or []): return None
    if report.get('release_digest') is not None: return None
    if report.get('installed') or report.get('used'): return None
    tested=report.get('independently_tested') or {}
    failed_validate=set(tested.get('failed_checks') or [])
    if not failed_validate or not failed_validate<=set(gm_autonomy.REPAIRABLE_VALIDATE_CHECKS): return None
    if any(not ok for ok in (tested.get('runtime_checks') or {}).values()): return None
    owned=report.get('owned_processes') or {}
    if owned.get('all_observed_members_exited') is not True or not owned.get('members'): return None
    usage=report.get('usage') or {}
    if usage.get('unknown'): return None
    model_calls=usage.get('model_calls')
    if type(model_calls) is not int or model_calls<1: return None
    gm=report.get('gm') or {}
    if not gm.get('gm_id') or not gm.get('issue_id'): return None
    if deployment_before is None or deployment_after is None: return None
    if deployment_before.get('checkout')!=deployment_after.get('checkout'): return None
    if deployment_before.get('files')!=deployment_after.get('files'): return None
    document,cycle_dir=durable_cycle(report,state_dir)
    if not isinstance(document,dict) or cycle_dir is None: return None
    if document.get('cycle_id')!=report.get('cycle_id'): return None
    if document.get('mode')!=report.get('mode') or document.get('world_id')!=world_id: return None
    if document.get('status')!='blocked' or document.get('blocked_reason')!=report.get('blocked_reason'):
        return None
    if document.get('gm_id')!=gm.get('gm_id') or document.get('issue_id')!=gm.get('issue_id'):
        return None
    if document.get('unknown') or document.get('repair_blocked'): return None
    if document.get('release') or document.get('repair_history') or document.get('repair_rounds'):
        return None
    if document.get('model_calls')!=model_calls: return None
    stages=document.get('stages') or {}
    publish=stages.get('publish') or {}; verify=stages.get('verify') or {}
    if publish.get('status')=='done' or verify.get('status')=='done': return None
    if publish.get('release_digest'): return None
    # The host gate must have failed only because its own test commands reported a defect, and
    # every one of those runs must be a fully observed, fully exited process. The cycle summary
    # cannot express a timeout or an unsettled tree, so the durable detail decides.
    if not owned_host_test_failure(stages): return None
    # The accounted attempts must match the cycle summary exactly, attempt for attempt: a
    # summary must not hide an unmeasured individual attempt, and a cycle whose attempts live
    # outside the current stages (a reopened repair round) fails closed instead of guessing.
    accounted=accounted_model_calls(stages)
    if accounted is None or accounted!=model_calls: return None
    candidate_attempts=(stages.get('candidate') or {}).get('attempts') or []
    counted_attempts=usage.get('attempts')
    if not isinstance(counted_attempts,dict): return None
    if sum(value for value in counted_attempts.values()
           if type(value) is int) != len(candidate_attempts): return None
    # The acknowledgement must be the owning GM's own answer to this exact persisted receipt.
    feedback=stages.get('feedback') or {}
    feedback_attempts=feedback.get('attempts') or []
    if feedback.get('status')!='done' or not feedback_attempts: return None
    if usage.get('feedback_attempts')!=feedback_attempts: return None
    last_attempt=feedback_attempts[-1]
    receipt_file=cycle_dir/('feedback-%d.json' % len(feedback_attempts))
    if not receipt_file.is_file(): return None
    receipt_sha=sha(receipt_file)
    if receipt_sha!=feedback.get('receipt_sha256') or receipt_sha!=last_attempt.get('receipt_sha256'):
        return None
    try: receipt=load(receipt_file)
    except Exception: return None
    if not isinstance(receipt,dict): return None
    if receipt.get('kind')!='autonomy_release_receipt': return None
    if receipt.get('gm_id')!=gm.get('gm_id') or receipt.get('issue_id')!=gm.get('issue_id'):
        return None
    if receipt.get('cycle_id')!=report.get('cycle_id') or receipt.get('world_id')!=world_id:
        return None
    if receipt.get('published') is not False or receipt.get('release_digest') is not None: return None
    if (receipt.get('failure') or {}).get('stage') not in ('candidate','validate'): return None
    runtime=receipt.get('runtime_verification') or {}
    if runtime.get('installed') or runtime.get('used'): return None
    acknowledgement=feedback.get('acknowledgement') or {}
    decision=acknowledgement.get('decision')
    if acknowledgement.get('acknowledged') is not True: return None
    if acknowledgement.get('gm_id') not in (None,gm.get('gm_id')): return None
    if decision not in gm_runner.FEEDBACK_DECISIONS: return None
    if decision not in SETTLED_LOCAL_AUTHOR_DECISIONS: return None
    if last_attempt.get('decision')!=decision or last_attempt.get('acknowledged') is not True:
        return None
    return {'classification':'settled_local_candidate_failure_unpublished',
            'cycle_id':report.get('cycle_id'),'gm_id':gm.get('gm_id'),'issue_id':gm.get('issue_id'),
            'blocked_reason':report.get('blocked_reason'),'next_stage':report.get('next_stage'),
            'stage_status':stage_status,'failed_validate_checks':sorted(failed_validate),
            'author_acknowledged':True,'author_decision':decision,
            'author_next_work':acknowledgement.get('next_work'),
            'feedback_receipt_sha256':receipt_sha,'accounted_model_calls':accounted,
            'model_calls_basis':'gm_autonomy_quota_count_including_retained_reservations',
            'other_gm_deferred_claims':len(document.get('deferred_claims') or []),
            'deployment_files':sorted(deployment_after.get('files') or {}),
            'deployment_matches_pinned_base':bool(deployment_after.get('matches_pinned_base')),
            'published':False,'release_digest':None,'runtime_installed':False,'runtime_used':False,
            'model_calls':model_calls,'usage_unknown':None,'owned_processes_exited':True,
            'deployment_unchanged':True,'report_path':report.get('report_path')}

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
    run={'schema_version':1,'status':'running','scope_sha256':sha(args.scope),'head':baseline['head'],'cycles':[],'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'pid':os.getpid(),'kimi_requests':0,'gm_model_calls':0,'counted_gm_cycle_ids':[],'counted_gm_cycle_calls':{}}
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
        # The deployment is verified by bounded content, not by version-control text status:
        # only the concrete target files the pinned base manifest declares are read.
        deployment_policy=policy.get('deployment') if isinstance(policy.get('deployment'),dict) else {}
        manifest_value=deployment_policy.get('base_manifest')
        manifest_path=(resolve(manifest_value)
                       if isinstance(manifest_value,str) and manifest_value.strip() else None)
        deployment_before=deployment_content_digest(deployment,manifest_path)
        autonomous=run_owned(auto,ROOT,scope['autonomy_timeout'],phase/'autonomy.log'); record['autonomy']=autonomous
        report=None
        # gm_autonomy emits one JSON object to its log; durable report remains under retained state.
        try:
            text=(phase/'autonomy.log').read_text(encoding='utf-8'); report=gm_autonomy.last_json_line(text)
        except Exception: pass
        record['autonomy_summary']=report
        if (autonomous['timed_out']
                or (autonomous.get('owned') or {}).get('all_members_exited') is not True or not report):
            run.update(status='stopped',reason='autonomy_failed'); break
        gm_status=report.get('status')
        gm_cycle_id=report.get('cycle_id')
        if not isinstance(gm_cycle_id,str) or not gm_cycle_id:
            run.update(status='stopped',reason='autonomy_report_missing_cycle_id'); break
        gm_usage=report.get('usage') if isinstance(report.get('usage'),dict) else {}
        measured_calls=gm_usage.get('model_calls')
        unknown_usage=gm_usage.get('unknown')
        # Attempt accounting is settled before any classification. usage.model_calls is
        # gm_autonomy's call/quota count: it keeps the admission reservations of interrupted or
        # unknown calls (gm_autonomy reserve/settle), so it is not proof that every call
        # completed and it is not a currency figure. A total that is absent or not an integer is
        # unmeasured, which is never the same as zero.
        if type(measured_calls) is not int or measured_calls<0:
            run.update(status='stopped',reason='autonomy_usage_unmeasured'); break
        # A cycle id reports a cumulative per-cycle total, and the checkpointed ledger keeps what
        # this run already charged for that id, so a resumed or repeated cycle is charged only the
        # delta against the same conservative quota cap. Broader restart/resume semantics are
        # deliberately out of scope here.
        cumulative=dict(run.get('counted_gm_cycle_calls') or {})
        already=int(cumulative.get(gm_cycle_id,0))
        if measured_calls<already:
            run.update(status='stopped',reason='autonomy_usage_regressed'); break
        charged=measured_calls-already
        if charged:
            run['gm_model_calls']+=charged
            if gm_cycle_id not in run['counted_gm_cycle_ids']:
                run['counted_gm_cycle_ids'].append(gm_cycle_id)
        cumulative[gm_cycle_id]=measured_calls
        run['counted_gm_cycle_calls']=cumulative
        record['gm_usage_counted']=bool(charged); record['gm_quota_calls_charged']=charged
        if run['gm_model_calls'] > int(scope['max_gm_model_calls']):
            run.update(status='stopped',reason='lifetime_gm_limit_exceeded'); break
        if unknown_usage:
            # The known part of the quota count stays charged and the unknown tail is carried as
            # an explicit marker that includes the retained reservations. It is never dropped,
            # never recorded as zero and never claimed as settled completion or currency.
            record['gm_usage_unknown']=unknown_usage
            run['gm_unknown_usage']={'cycle_id':gm_cycle_id,'usage_unknown':unknown_usage,
                                     'quota_calls_charged':charged,
                                     'counts_including_unresolved_reservations':measured_calls}
            run.update(status='stopped',reason='autonomy_usage_unknown'); break
        if sha(world) != post_life_sha:
            run.update(status='stopped',reason='canonical_world_changed_during_gm_cycle'); break
        if sha(verify_copy)!=verify_copy_before and gm_status!='completed':
            run.update(status='stopped',reason='verification_copy_changed_without_release'); break
        if autonomous['exit_code']==0 and gm_status in ('completed','no_action','limit_reached'):
            runtime_checks=(report.get('independently_tested') or {}).get('runtime_checks') or {}
            if gm_status=='completed' and (not runtime_checks or not all(runtime_checks.values())):
                run.update(status='stopped',reason='release_not_host_verified'); break
            record['resident_adoption']=('pending_next_canonical_life' if gm_status=='completed'
                                         else 'no_release')
        elif autonomous['exit_code']!=0 and gm_status=='blocked':
            # A nonzero blocked exit stays the global stop it already was unless every listed
            # fact is proven now, after accounting and integrity, by the durable evidence.
            gm_local=settled_local_candidate_failure(report,resolve(scope['gm_state_dir']),
                                                     deployment_before,
                                                     deployment_content_digest(deployment,
                                                                               manifest_path))
            if gm_local is None:
                run.update(status='stopped',reason='autonomy_blocked_unresolved'); break
            record.setdefault('gm_local_failures',[]).append(gm_local)
            run['gm_local_failures_total']=int(run.get('gm_local_failures_total',0))+1
            run['gm_local_failure_classes']=sorted(set(run.get('gm_local_failure_classes') or [])
                                                   | {gm_local['classification']})
            record['resident_adoption']='no_release'
        elif autonomous['exit_code']==0:
            run.update(status='stopped',reason='autonomy_not_terminal_success'); break
        else:
            run.update(status='stopped',reason='autonomy_failed'); break
        record['status']='closed'
        record['world_after_sha256']=sha(world); checkpoint()
    else: run.update(status='completed_finite',reason='max_cycles')
    run['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat(); run['tracked_frozen']=tracked()==baseline
    checkpoint(); print(json.dumps(run,ensure_ascii=False))
    clean_stops={'operator_stop_file','time_limit','lifetime_model_call_limit','absolute_cutoff','absolute_cutoff_admission_buffer'}
    return 0 if run['status']=='completed_finite' or (run['status']=='stopped' and run.get('reason') in clean_stops) else 1
if __name__=='__main__': raise SystemExit(main())
