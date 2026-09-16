"""Sanitized provenance and reproducible delivery metadata for the first-pass kit."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Art/Generated/InteriorFirstPass20260916'
OUT = ROOT / 'exports/interior-first-pass-20260916'
WORK = ROOT / 'tmp/interior-first-pass-20260916'
read = lambda p: json.loads(p.read_text(encoding='utf-8'))
state = read(WORK / 'state.json')
raw = read(PUBLIC / 'raw-metrics.json')
plan = read(PUBLIC / 'request.json')
models = []
for provider in ['tripo','meshy']:
    for asset in plan['assets']:
        key = provider+'/'+asset['id']
        kind = 'model' if provider=='tripo' else 'refine'
        stage = state['stages'][key+'/'+kind]
        original = ROOT / stage['model']['path']
        staged = OUT / 'project/assets' / provider / original.name
        digest = hashlib.sha256(original.read_bytes()).hexdigest()
        assert digest == stage['model']['sha256']
        assert hashlib.sha256(staged.read_bytes()).hexdigest() == digest
        models.append({'id':key,'name_zh':asset['name_zh'],'task_id':stage['task_id'],
                       'source_glb':'assets/'+key+'.glb','sha256':digest,
                       'bytes':original.stat().st_size,'raw':raw[key],
                       'first_attempt_only':True,'source_and_staged_bytes_unchanged':True})
stages = [{k:s.get(k) for k in ['provider','asset','kind','task_id','status','credits','submitted_at','completed_observed_at']} for s in state['stages'].values()]
result = {'schema':'first-result-modular-houses-v1','models':models,'stages':stages,
          'request_sha256':state['request_sha256'],'created_at':state['created_at'],'finished_at':state['finished_at'],
          'initial_balances':state['initial_balances'],'final_balances':state['final_balances'],
          'credits':{p:sum(s['credits'] for s in stages if s['provider']==p) for p in ['tripo','meshy']},
          'total_original_triangles':{p:sum(m['raw']['triangles'] for m in models if m['id'].startswith(p+'/')) for p in ['tripo','meshy']},
          'original_glb_bytes':{p:sum(m['bytes'] for m in models if m['id'].startswith(p+'/')) for p in ['tripo','meshy']},
          'scope':'36 first-result GLBs; shared authored single-floor shell, two independent house instances. Not automatic full-house generation.',
          'no_quality_retries':True,'all_36_glb_hashes_unchanged':True,
          'assembly_changes':['uniform furniture scale','rigid orientation and position','door and shutter dimension fitting to existing apertures','colliders','lighting'],
          'raw_geometry_or_texture_changes':False,
          'license':{'demo_code':'MIT','generated_assets':'provider terms; blanket MIT not confirmed','account_type_reported_by_user':'API credits only'},
          'commercial_visual_status':'Not certified as finished commercial assets; first-result blockers retained in visual-review.json',
          'game_project':'exports/interior-first-pass-20260916/project/project.godot'}
verification = PUBLIC / 'screenshots/verification.json'
if verification.exists():
    result['game_verification'] = read(verification)
result['owned_process_records'] = [p.relative_to(ROOT).as_posix() for p in sorted((WORK/'processes').glob('*.process.json'))]
processes = [read(p) for p in (WORK/'processes').glob('*.process.json')]
result['all_owned_processes_exited'] = all(p.get('all_members_exited',False) for p in processes)
(PUBLIC/'manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(PUBLIC/'manifest.json',OUT/'project/asset-provenance.json')
shutil.copy2(PUBLIC/'visual-review.json',OUT/'project/visual-review.json')
print(json.dumps({k:result[k] for k in ['credits','total_original_triangles','original_glb_bytes','all_owned_processes_exited']},ensure_ascii=False))
