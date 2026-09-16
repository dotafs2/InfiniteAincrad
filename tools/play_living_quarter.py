"""Open the migrated world for walking/doors/windows, with resident time paused."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import subprocess
from owned_windows_job import WindowsProcessTree
from check_living_quarter import ROOT, GODOT


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--save',type=Path,default=ROOT/'tmp/mvp-autonomy-20260914/prepared/real/canonical-world.json')
    args=p.parse_args()
    state=json.loads(args.save.read_text(encoding='utf-8'))
    if state.get('godot',{}).get('spatial_layout',{}).get('id')!='first-floor-market-quarter-v1':
        raise RuntimeError('This save has not been migrated to the living quarter')
    out=ROOT/'private/living-quarter-20260916'/('visit-'+datetime.now().strftime('%Y%m%d-%H%M%S'))
    out.mkdir(parents=True)
    cmd=[str(GODOT),'--path',str(ROOT/'game'),'res://scenes/town_street.tscn','--',
         '--town-save='+str(args.save.resolve()),'--town-restore']
    with (out/'engine.log').open('w',encoding='utf-8') as log:
        with WindowsProcessTree(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT) as job:
            (out/'process.json').write_text(json.dumps(job.snapshot(),indent=2))
            try:
                code=job.wait(86400)
            finally:
                if job.process.poll() is None:
                    job.terminate()
                (out/'process.json').write_text(json.dumps(job.snapshot(),indent=2))
    return code


if __name__=='__main__':
    raise SystemExit(main())
