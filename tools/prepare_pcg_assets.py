"""Copy first-pass Meshy results unchanged, retaining provider and geometry provenance."""
import hashlib
import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PLAN=ROOT/'experiments/pcg-trial/assets.json'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--available',action='store_true')
    args=parser.parse_args()
    plan=json.loads(PLAN.read_text())
    source=ROOT/'exports/meshy-pool'/plan['id']
    state=json.loads((ROOT/'private/meshy-pool'/plan['id']/'state.json').read_text())
    destination=ROOT/'game/assets/floor1/pcg_20260916'
    missing=[job['id'] for job in plan['jobs'] if not (source/(job['id']+'.glb')).exists()]
    if missing and not args.available: raise SystemExit('Meshy generation is still pending: '+', '.join(missing))
    destination.mkdir(parents=True,exist_ok=True)
    assets=[]
    for job in plan['jobs']:
        if job['id'] in missing: continue
        path=source/(job['id']+'.glb'); raw=path.read_bytes()
        target=destination/path.name
        if target.exists() and target.read_bytes()!=raw: raise RuntimeError('Refusing to overwrite a different asset')
        target.write_bytes(raw)
        stages=state['jobs'][job['id']]['stages']
        assets.append({'id':job['id'],'source':str(path.relative_to(ROOT)).replace('\\','/'),
                      'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'prompt':job['prompt'],
                      'geometry_and_textures_unchanged':True,
                      'stages':{k:{a:v[a] for a in ['task_id','actual_credits','status'] if a in v} for k,v in stages.items()}})
    (destination/'manifest.json').write_text(json.dumps({'plan':plan['id'],'assets':assets},indent=2))
    print(json.dumps({'models':len(assets),'bytes':sum(a['bytes'] for a in assets),'pending':missing}))

if __name__=='__main__': main()
