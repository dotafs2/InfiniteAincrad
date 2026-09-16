"""Bounded multi-account Meshy queue. Python stdlib; secrets never enter logs.

python tools/meshy_pool.py init
python tools/meshy_pool.py estimate --plan experiments/meshy-pool/jobs.example.json
python tools/meshy_pool.py onboard
python tools/meshy_pool.py doctor
python tools/meshy_pool.py run --plan experiments/meshy-pool/jobs.example.json
"""
from __future__ import annotations
import argparse
import base64
import contextlib
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SECRETS = ROOT / 'secrets/meshy-pool'
CONFIG = SECRETS / 'accounts.json'
PRIVATE = ROOT / 'private/meshy-pool'
OUTPUT = ROOT / 'exports/meshy-pool'
ID = re.compile(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$')
ACTIVE = {'submitted', 'pending', 'in_progress', 'running', 'processing'}
BLOCKED = {'submitting', 'uncertain', 'rejected', 'failed', 'canceled', 'expired'}

class Stop(Exception):
    pass

class ApiError(Stop):
    def __init__(self, status=0):
        self.status = status
        super().__init__('HTTP_' + str(status) if status else 'NETWORK_OR_TIMEOUT')

def emit(event, **fields):
    print(json.dumps({'event': event, **fields}, ensure_ascii=False), flush=True)

def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def digest(data):
    return hashlib.sha256(data).hexdigest()

def write(path, obj):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.new')
    with temp.open('w', encoding='utf-8') as file:
        json.dump(obj, file, ensure_ascii=False, indent=2)
        file.write('\n')
        file.flush()
        os.fsync(file.fileno())
    os.replace(temp, path)

def valid_id(value):
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise Stop('INVALID_ID')
    return value

@contextlib.contextmanager
def pool_lock():
    PRIVATE.mkdir(parents=True, exist_ok=True)
    file = (PRIVATE / 'pool.lock').open('a+b')
    try:
        file.seek(0)
        file.write(b'0')
        file.flush()
        file.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            raise Stop('ANOTHER_POOL_COMMAND_IS_RUNNING') from None
        yield
    finally:
        file.close()  # OS releases the lock even after a process crash.

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward an API credential to a redirected origin.

class Api:
    def __init__(self):
        self.opener = urllib.request.build_opener(NoRedirect())

    def call(self, account, method, route, payload=None):
        if not re.fullmatch(r'v[12]/[a-z0-9/-]+', route):
            raise Stop('INVALID_API_ROUTE')
        request = urllib.request.Request('https://api.meshy.ai/openapi/' + route,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={'Authorization': 'Bearer ' + account['_key'], 'Content-Type': 'application/json'}, method=method)
        try:
            with self.opener.open(request, timeout=45) as response:
                raw = response.read(8 * 1024 * 1024 + 1)
                if len(raw) > 8 * 1024 * 1024:
                    raise ApiError()
                return json.loads(raw)
        except urllib.error.HTTPError as error:
            raise ApiError(error.code) from None
        except (OSError, ValueError, urllib.error.URLError):
            raise ApiError() from None

    def balance(self, account):
        value = self.call(account, 'GET', 'v1/balance').get('balance')
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            raise Stop('INVALID_BALANCE_RESPONSE')
        return value

    def download(self, url, dest):
        if not isinstance(url, str) or not url.startswith('https://'):
            raise Stop('MODEL_URL_MISSING')
        dest.parent.mkdir(parents=True, exist_ok=True)
        temp = dest.with_suffix('.glb.part')
        # Downloads deliberately have no Authorization header and no API key.
        try:
            with urllib.request.urlopen(url, timeout=90) as response, temp.open('wb') as file:
                size = 0
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    if size > 256 * 1024 * 1024:
                        raise Stop('MODEL_EXCEEDS_256MB')
                    file.write(chunk)
        except (OSError, urllib.error.URLError):
            raise Stop('DOWNLOAD_FAILED_RESUME_SAME_TASK') from None
        with temp.open('rb') as file:
            header = file.read(12)
        if len(header) != 12 or struct.unpack('<4sII', header) != (b'glTF', 2, temp.stat().st_size):
            raise Stop('INVALID_GLB_RESUME_SAME_TASK')
        os.replace(temp, dest)
        return {'file': str(dest.relative_to(ROOT)).replace('\\', '/'), 'bytes': dest.stat().st_size,
                'sha256': digest(dest.read_bytes())}

def accounts():
    if not CONFIG.exists():
        raise Stop('RUN_INIT_AND_ONBOARD_FIRST')
    result, names, fingerprints = [], set(), set()
    for item in load(CONFIG).get('accounts', []):
        if not item.get('enabled', True):
            continue
        name = valid_id(item.get('id'))
        key_path = (SECRETS / item['key_file']).resolve()
        if not key_path.is_relative_to(SECRETS.resolve()):
            raise Stop('KEY_FILE_MUST_BE_INSIDE_SECRET_POOL')
        key = key_path.read_text(encoding='utf-8-sig').strip()
        if not key.startswith('msy_') or len(key) < 20 or any(c.isspace() for c in key):
            raise Stop('INVALID_KEY_FILE_' + name)
        fingerprint = digest(key.encode())
        if name in names or fingerprint in fingerprints:
            raise Stop('DUPLICATE_ACCOUNT_OR_KEY')
        names.add(name)
        fingerprints.add(fingerprint)
        price, credits = float(item.get('price_cny', 12)), int(item.get('purchased_credits', 1100))
        if not math.isfinite(price) or price <= 0 or credits <= 0:
            raise Stop('INVALID_ACCOUNT_COST')
        result.append({**item, '_key': key, '_fingerprint': fingerprint, '_cny_per_credit': price / credits})
    if not result:
        raise Stop('NO_CONFIGURED_KEYS')
    return result

def read_plan(path):
    path = Path(path).resolve()
    plan = load(path)
    valid_id(plan.get('id'))
    if plan.get('model', 'meshy-7') != 'meshy-7':
        raise Stop('ONLY_MESHY_7_PRICING_SUPPORTED')
    texture = plan.get('texture', '4k')
    if texture not in ('none', '2k', '4k', '8k'):
        raise Stop('INVALID_TEXTURE')
    if not isinstance(plan.get('ultra', False), bool) or not isinstance(plan.get('remesh', True), bool):
        raise Stop('INVALID_BOOLEAN_SETTING')
    preview = 20 + (5 if plan.get('ultra') else 0)
    refine = 0 if texture == 'none' else (15 if texture == '8k' else 10)
    names = set()
    if not isinstance(plan.get('jobs'), list) or not 1 <= len(plan['jobs']) <= 10000:
        raise Stop('PLAN_NEEDS_1_TO_10000_JOBS')
    for job in plan['jobs']:
        name = valid_id(job.get('id'))
        if name in names:
            raise Stop('DUPLICATE_JOB_ID')
        names.add(name)
        mode = job.get('mode', 'text')
        if mode not in ('text', 'image'):
            raise Stop('INVALID_JOB_MODE')
        prompt = job.get('prompt', '')
        if not isinstance(prompt, str) or len(prompt) > 800 or (mode == 'text' and not prompt.strip()):
            raise Stop('INVALID_PROMPT_' + name)
        faces = job.get('faces', 12000)
        if type(faces) is not int or not 100 <= faces <= 300000:
            raise Stop('INVALID_FACE_TARGET')
        if mode == 'image':
            image_path = (path.parent / job['image_file']).resolve()
            data = image_path.read_bytes()
            if not 0 < len(data) <= 20 * 1024 * 1024:
                raise Stop('IMAGE_SIZE_LIMIT')
            if data.startswith(b'\x89PNG\r\n\x1a\n'): mime = 'image/png'
            elif data.startswith(b'\xff\xd8\xff'): mime = 'image/jpeg'
            else: raise Stop('IMAGE_MUST_BE_PNG_OR_JPEG')
            job['_image_sha256'] = digest(data)
            job['_image_path'] = str(image_path)
            job['_image_mime'] = mime
    required = len(plan['jobs']) * (preview + refine)
    budget = plan.get('budget_credits')
    if type(budget) is not int or budget < required:
        raise Stop('BUDGET_TOO_SMALL_REQUIRED_' + str(required))
    canonical = json.dumps(plan, sort_keys=True, ensure_ascii=False).encode()
    return plan, digest(canonical), {'mesh': preview, 'texture': refine, 'model': preview + refine, 'total': required}

def economy(credits, price=12, purchased=1100):
    if not math.isfinite(price) or price <= 0 or purchased <= 0:
        raise Stop('INVALID_ACCOUNT_COST')
    count = purchased // credits
    return {'credits_per_model': credits, 'cny_per_credit': price / purchased,
            'cny_per_model_credit_prorated': round(price / purchased * credits, 6),
            'models_per_account': count, 'credits_left_per_account': purchased % credits,
            'cny_per_model_if_leftover_unused': round(price / count, 6) if count else None}


def verify_task_identity(response, job, kind, record, task_id):
    if str(response.get('id')) != task_id:
        raise Stop('TASK_ID_MISMATCH')
    expected_type = 'image-to-3d' if kind == 'image' else 'text-to-3d-' + kind
    actual_type = response.get('type')
    if actual_type != expected_type:
        raise Stop('TASK_TYPE_MISMATCH')
    if kind == 'preview' and 'prompt' in response and response['prompt'] != job['prompt']:
        raise Stop('TASK_PROMPT_MISMATCH')
    if kind == 'refine' and 'preview_task_id' in response and response['preview_task_id'] != record['stages']['preview']['task_id']:
        raise Stop('TASK_PREVIEW_MISMATCH')

class Pipeline:
    def __init__(self, plan_path, api=None, account_list=None):
        self.plan, self.fingerprint, self.cost = read_plan(plan_path)
        self.api = api or Api()
        self.accounts = account_list if account_list is not None else accounts()
        self.by_id = {a['id']: a for a in self.accounts}
        self.work = PRIVATE / self.plan['id']
        self.dest = OUTPUT / self.plan['id']
        self.file = self.work / 'state.json'
        if self.file.exists():
            self.state = load(self.file)
            if self.state['plan_sha256'] != self.fingerprint:
                raise Stop('PLAN_CHANGED_USE_NEW_RUN_ID')
            for job in self.state['jobs'].values():
                if job.get('account'):
                    a = self.by_id.get(job['account'])
                    if not a or a['_fingerprint'] != job['key_fingerprint']:
                        raise Stop('BOUND_ACCOUNT_KEY_MISSING_OR_CHANGED')
        else:
            self.state = {'schema':1, 'id':self.plan['id'], 'plan_sha256':self.fingerprint,
                'created_at':time.time(), 'jobs':{j['id']:{'stages':{}} for j in self.plan['jobs']}}
            self.save()

    def save(self):
        write(self.file, self.state)

    def route(self, job):
        return 'v1/image-to-3d' if job.get('mode', 'text') == 'image' else 'v2/text-to-3d'

    def submit(self, job, kind, account):
        record = self.state['jobs'][job['id']]
        if kind in record['stages']:
            raise Stop('SUBMISSION_ALREADY_RECORDED')
        image = job.get('mode', 'text') == 'image'
        texture = self.plan.get('texture', '4k')
        if kind == 'refine':
            payload = {'mode':'refine','preview_task_id':record['stages']['preview']['task_id'],
                'ai_model':'meshy-7','enable_pbr':True,'texture_resolution':texture,'texture_prompt':job['prompt'], 'target_formats':['glb']}
            expected = self.cost['texture']
        else:
            payload = {'ai_model':'meshy-7','model_type':'standard','ultra_mode':self.plan.get('ultra',False),
                'should_remesh':self.plan.get('remesh',True),'topology':'triangle','target_polycount':job.get('faces',12000), 'target_formats':['glb']}
            if image:
                raw = Path(job['_image_path']).read_bytes()
                if digest(raw) != job['_image_sha256']:
                    raise Stop('SOURCE_IMAGE_CHANGED')
                payload.update(image_url='data:'+job['_image_mime']+';base64,'+base64.b64encode(raw).decode(),
                    should_texture=texture!='none', enable_pbr=texture!='none')
                if texture != 'none': payload['texture_resolution'] = texture
                if texture != 'none' and job.get('prompt'): payload['texture_prompt'] = job['prompt']
                expected = self.cost['model']
            else:
                payload.update(mode='preview', prompt=job['prompt'])
                expected = self.cost['mesh']
        stage = {'status':'submitting','expected_credits':expected,'submitted_at':time.time()}
        record['stages'][kind] = stage
        self.save()  # Persist BEFORE POST: a crash/timeout must never cause a second charge.
        try:
            response = self.api.call(account,'POST',self.route(job),payload)
            task_id = response.get('result')
            if not isinstance(task_id,str) or not re.fullmatch(r'[a-zA-Z0-9_-]{6,100}',task_id):
                raise ApiError()
            stage.update(status='submitted',task_id=task_id)
        except ApiError as error:
            stage.update(status='rejected' if error.status in (400,401,402,403,404,422,429) else 'uncertain',error_code=error.status)
            self.save()
            raise Stop('SUBMISSION_STOP_'+job['id']+'_'+kind+'_'+str(error.status)+'_NO_AUTO_RETRY') from None
        self.save()
        emit('submitted',job=job['id'],account=account['id'],stage=kind,task_id=task_id,expected_credits=expected)

    def poll(self, job):
        record = self.state['jobs'][job['id']]
        if record.get('model'):
            return
        for kind, stage in record['stages'].items():
            if stage['status'] in BLOCKED:
                raise Stop('REVIEW_REQUIRED_'+job['id']+'_'+kind+'_'+stage['status'])
            final = kind in ('refine','image') or not self.cost['texture']
            if stage['status'] == 'succeeded' and not final:
                continue
            response = self.api.call(self.by_id[record['account']],'GET',self.route(job)+'/'+stage['task_id'])
            status = str(response.get('status','')).lower()
            if status not in ACTIVE | {'succeeded','failed','canceled','expired'}:
                raise Stop('UNKNOWN_PROVIDER_STATUS')
            write(self.work / 'receipts' / (job['id']+'-'+kind+'.json'), response)
            stage['status'] = status
            amount = response.get('consumed_credits',response.get('credits_consumed'))
            if type(amount) in (int,float) and math.isfinite(amount) and amount >= 0:
                stage['actual_credits'] = amount
            self.save()
            if status in BLOCKED:
                raise Stop('PROVIDER_TASK_STOP_'+job['id']+'_'+status)
            if status == 'succeeded' and final:
                model = self.api.download(response.get('model_urls',{}).get('glb'), self.dest / (job['id']+'.glb'))
                record['model'] = model
                record['finished_at'] = time.time()
                self.save()
                emit('downloaded',job=job['id'],account=record['account'],**model)

    def tick(self, concurrency=2):
        # Stop globally before new creations on errors, unknown POST results or throttling.
        for job in self.plan['jobs']:
            self.poll(job)
        # A pricing change must not silently spend the rest of a batch.
        for record in self.state['jobs'].values():
            if any(s.get('actual_credits', 0) > s['expected_credits'] for s in record['stages'].values()):
                raise Stop('PROVIDER_COST_EXCEEDED_ESTIMATE_REVIEW_BEFORE_NEW_TASKS')
        busy = {r['account'] for r in self.state['jobs'].values() if r.get('account') and not r.get('model')}
        started = 0
        for job in self.plan['jobs']:
            record = self.state['jobs'][job['id']]
            if record.get('model'):
                continue
            if record.get('account'):
                first_kind = 'image' if job.get('mode','text') == 'image' else 'preview'
                if not record['stages']:
                    if self.api.balance(self.by_id[record['account']]) < self.cost['model']:
                        raise Stop('BOUND_ACCOUNT_CANNOT_FUND_COMPLETE_MODEL')
                    self.submit(job,first_kind,self.by_id[record['account']])
                    started += 1
                elif self.cost['texture'] and first_kind == 'preview' and record['stages']['preview']['status']=='succeeded' and 'refine' not in record['stages']:
                    account = self.by_id[record['account']]
                    if self.api.balance(account) < self.cost['texture']:
                        raise Stop('BOUND_ACCOUNT_NEEDS_TEXTURE_CREDITS_'+account['id'])
                    self.submit(job,'refine',account)
                    started += 1
                continue
            if len(busy) >= concurrency:
                continue
            for account in self.accounts:
                if account['id'] in busy:
                    continue
                balance = self.api.balance(account)
                if balance < self.cost['model']:
                    continue
                # A whole model stays on the same account, including texture generation.
                record.update(account=account['id'],key_fingerprint=account['_fingerprint'],
                    cny_per_credit=account['_cny_per_credit'],balance_at_assignment=balance)
                self.save()
                busy.add(account['id'])
                self.submit(job,'image' if job.get('mode','text')=='image' else 'preview',account)
                started += 1
                break
        done = sum(bool(r.get('model')) for r in self.state['jobs'].values())
        if done < len(self.plan['jobs']) and not busy and not started:
            raise Stop('NO_ACCOUNT_CAN_FUND_ONE_COMPLETE_MODEL')
        self.report()
        return done == len(self.plan['jobs'])

    def report(self):
        report = {'id':self.plan['id'],'planned_credits':self.cost['total'],'budget_credits':self.plan['budget_credits'],
                  'done':0,'jobs':[], 'expected_submitted_credits':0,'provider_reported_credits':0,'unknown_charge_stages':0}
        for job in self.plan['jobs']:
            record = self.state['jobs'][job['id']]
            stages = record['stages']
            expected = sum(s['expected_credits'] for s in stages.values())
            actual = sum(s.get('actual_credits',0) for s in stages.values())
            unknown = sum('actual_credits' not in s for s in stages.values())
            report['done'] += bool(record.get('model'))
            report['expected_submitted_credits'] += expected
            report['provider_reported_credits'] += actual
            report['unknown_charge_stages'] += unknown
            report['jobs'].append({'id':job['id'],'account':record.get('account'),'model':record.get('model'),
                'stages':{k:{f:s[f] for f in ('status','task_id','expected_credits','actual_credits','error_code') if f in s} for k,s in stages.items()},
                'expected_credits':expected,'provider_reported_credits':actual,'unknown_charge_stages':unknown,
                'expected_cny_prorated':round(expected*record.get('cny_per_credit',0),6),
                'actual_cny_prorated':round(actual*record.get('cny_per_credit',0),6) if not unknown else None})
        write(self.dest / 'report.json',report)
        return report

def initialize():
    SECRETS.mkdir(parents=True, exist_ok=True)
    if not CONFIG.exists(): write(CONFIG,{'accounts':[]})
    inbox = SECRETS / 'accounts-to-import.json'
    if not inbox.exists():
        write(inbox,{'accounts':[{'id':'meshy-001','email':'','password':'','price_cny':12,'purchased_credits':1100}]})
    emit('initialized',accounts_file=str(inbox),config=str(CONFIG))

def main():
    parser=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command',choices=['init','estimate','doctor','run','status','attach','onboard','import-key'])
    parser.add_argument('--plan',default='experiments/meshy-pool/jobs.example.json')
    parser.add_argument('--concurrency',type=int,default=2)
    parser.add_argument('--minutes',type=float,default=30)
    parser.add_argument('--poll-seconds',type=float,default=10)
    parser.add_argument('--id')
    parser.add_argument('--key-file')
    parser.add_argument('--price-cny',type=float,default=12)
    parser.add_argument('--credits',type=int,default=1100)
    parser.add_argument('--stage',choices=['preview','refine','image'])
    parser.add_argument('--task-id')
    parser.add_argument('--limit',type=int,default=1)
    args=parser.parse_args()
    if args.command=='estimate':
        plan,_,cost=read_plan(args.plan)
        per_account = args.credits // cost['model']
        emit('estimate',jobs=len(plan['jobs']),total_credits=cost['total'],economy=economy(cost['model'],args.price_cny,args.credits),
             accounts_needed=math.ceil(len(plan['jobs'])/per_account) if per_account else None)
        return
    with pool_lock():
        if args.command=='init': initialize(); return
        if args.command=='onboard':
            from owned_windows_job import WindowsProcessTree
            if not 1<=args.limit<=100: raise Stop('LIMIT_MUST_BE_1_TO_100')
            log=PRIVATE/'onboard-process.json'
            command=['node',str(ROOT/'tools/meshy_pool_browser.mjs'),'--limit',str(args.limit)]
            # Explicit handles are needed for CREATE_NO_WINDOW child output.
            # Forward only our structured events; never raw browser diagnostics.
            events = PRIVATE/'onboard-events.jsonl'
            with events.open('wb') as output, events.open('r',encoding='utf-8',errors='replace') as incoming:
                pending = ''
                def forward(_state):
                    nonlocal pending
                    pending += incoming.read()
                    lines = pending.split('\n')
                    pending = lines.pop()
                    for line in lines:
                        try: event=json.loads(line)
                        except ValueError: continue
                        if isinstance(event,dict) and 'event' in event:
                            allowed=('event','account','balance','reason','timeout_seconds','code','message')
                            print(json.dumps({k:v for k,v in event.items() if k in allowed},ensure_ascii=False),flush=True)
                with WindowsProcessTree(command,cwd=ROOT,stdout=output,stderr=output) as tree:
                    write(log,tree.snapshot())
                    try: code=tree.wait(args.limit*660+30,on_poll=forward)
                    finally:
                        if not tree.snapshot()['all_members_exited']: tree.terminate(130)
                        forward(None)
                        write(log,tree.snapshot())
            if code: raise Stop('ONBOARDING_STOPPED_SEE_STATUS')
            return
        if args.command=='import-key':
            name=valid_id(args.id)
            economy(30,args.price_cny,args.credits)
            if not args.key_file: raise Stop('KEY_FILE_REQUIRED')
            key=Path(args.key_file).read_text(encoding='utf-8-sig').strip()
            if not key.startswith('msy_') or len(key)<20: raise Stop('INVALID_KEY')
            account={'id':name,'_key':key}
            balance=Api().balance(account)
            config=load(CONFIG)
            if any(a['id']==name for a in config['accounts']): raise Stop('ACCOUNT_ALREADY_CONFIGURED')
            existing_keys = accounts() if any(a.get('enabled',True) for a in config['accounts']) else []
            if any(a['_fingerprint']==digest(key.encode()) for a in existing_keys):
                raise Stop('KEY_ALREADY_CONFIGURED')
            target=SECRETS/'keys'/(name+'.txt')
            target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('x',encoding='utf-8') as file: file.write(key+'\n')
            config['accounts'].append({'id':name,'key_file':'keys/'+name+'.txt','price_cny':args.price_cny,'purchased_credits':args.credits,'enabled':True})
            write(CONFIG,config)
            emit('key_imported',account=name,balance=balance)
            return
        if args.command=='doctor':
            api=Api()
            for account in accounts(): emit('account',id=account['id'],balance=api.balance(account),economy=economy(30,account['price_cny'],account['purchased_credits']))
            return
        pipeline=Pipeline(args.plan)
        if args.command=='status': emit('status',**pipeline.report()); return
        if args.command=='attach':
            if not args.stage or not args.task_id or not re.fullmatch(r'[a-zA-Z0-9_-]{6,100}',args.task_id): raise Stop('STAGE_AND_TASK_ID_REQUIRED')
            job=next((j for j in pipeline.plan['jobs'] if j['id']==args.id),None)
            if not job: raise Stop('UNKNOWN_JOB')
            record=pipeline.state['jobs'][job['id']]
            stage=record['stages'].get(args.stage)
            if not stage or stage['status'] not in ('submitting','uncertain'): raise Stop('ONLY_UNCERTAIN_SUBMISSIONS_CAN_BE_ATTACHED')
            response=pipeline.api.call(pipeline.by_id[record['account']],'GET',pipeline.route(job)+'/'+args.task_id)
            verify_task_identity(response,job,args.stage,record,args.task_id)
            stage.update(task_id=args.task_id,status='submitted',recovered_at=time.time())
            pipeline.save(); emit('attached_existing_task',job=args.id,task_id=args.task_id); return
        if not 1<=args.concurrency<=10 or not math.isfinite(args.minutes) or not 0<args.minutes<=120 or not 5<=args.poll_seconds<=60:
            raise Stop('INVALID_RUN_BOUNDS')
        deadline=time.monotonic()+args.minutes*60
        try:
            while time.monotonic()<deadline:
                if pipeline.tick(args.concurrency): emit('complete',**pipeline.report()); return
                emit('waiting',done=pipeline.report()['done'],total=len(pipeline.plan['jobs']))
                time.sleep(min(args.poll_seconds,max(0,deadline-time.monotonic())))
            emit('paused_time_limit',message='Submitted remote tasks continue; rerun the same command to retrieve them.',**pipeline.report())
        finally: pipeline.report()

if __name__=='__main__':
    try: main()
    except KeyboardInterrupt: emit('paused_by_user',message='Rerun the same plan to resume; remote tasks are not canceled.'); sys.exit(130)
    except Stop as error: emit('stopped',code=str(error)); sys.exit(2)
    except Exception as error: emit('stopped',code='LOCAL_'+type(error).__name__); sys.exit(2)
