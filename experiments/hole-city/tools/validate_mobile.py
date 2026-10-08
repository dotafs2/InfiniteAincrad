"""Run scene-level regressions and reject silent Godot script failures.
Usage: python3 tools/validate_mobile.py --godot /path/to/Godot
All sessions use --test so the player's progress file is never modified.
"""
import argparse, json, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CASES=[('portrait',[]),('destruction_traffic',[]),('skin_skill',[]),('skin_fx',[]),('title_navigation',[]),('no_tether',[]),('resonance_action',[]),('ads_bridge',[]),('mobile_maps',[]),('rim_fall',['--cut-ground']),('fidelity',[]),('food_round',[]),('actor_fall',[]),('rig_fracture',[]),('snack_city',[]),('food_city_density',[]),('scene_qa',[]),('street_prop_qa',['--all-props']),('claim_recovery',[]),('full_city_qa',[])]
def main():
    p=argparse.ArgumentParser();p.add_argument('--godot',required=True,type=Path)
    p.add_argument('--suite',action='append',choices=[name for name,_ in CASES])
    p.add_argument('--timeout',type=int,default=600)
    p.add_argument('--report',type=Path)
    args=p.parse_args()
    out=ROOT/'artifacts/mobile';out.mkdir(parents=True,exist_ok=True)
    report_path=args.report or out/('selected-regressions.json' if args.suite else 'regressions.json')
    report_path.parent.mkdir(parents=True,exist_ok=True)
    results=[]
    with tempfile.TemporaryDirectory(prefix='sink-mobile-') as scratch:
        for name,extra in CASES:
            if args.suite and name not in args.suite:continue
            log=Path(scratch)/(name+'.log')
            timed_out=False
            with log.open('w') as f:
                try:
                    result=subprocess.run([str(args.godot.resolve()),'--headless','--path',str(ROOT),'--log-file',str(Path(scratch)/(name+'-engine.log')),'--script','res://tests/'+name+'_acceptance.gd','--fixed-fps','60','--quit-after','35000','--','--test',*extra],stdout=f,stderr=subprocess.STDOUT,timeout=args.timeout)
                except subprocess.TimeoutExpired:timed_out=True
            output=log.read_text();marker=name.upper()+'_ACCEPTANCE '
            reports=[line.split(marker,1)[1] for line in output.splitlines() if marker in line]
            valid=not timed_out and result.returncode==0 and bool(reports) and 'SCRIPT ERROR' not in output
            report=json.loads(reports[-1]) if reports else {'error':'timeout' if timed_out else 'missing acceptance report','log_tail':output[-5000:]}
            valid=valid and not report.get('failures') and report.get('passed',True)
            results.append({'suite':name,'passed':bool(valid),'report':report})
            report_path.write_text(json.dumps(results,indent=2)+'\n')
            print(name, 'PASS' if valid else 'FAIL',flush=True)
            if not valid:print(output[-5000:],flush=True)
    raise SystemExit(0 if all(r['passed'] for r in results) else 1)
if __name__=='__main__':main()
