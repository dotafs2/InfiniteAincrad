"""Run isolated, reproducible CPU profiles for both maps. Headless is not GPU FPS."""
from pathlib import Path
import argparse,json,subprocess,hashlib,statistics,math
from release_web import input_hashes, unexpected_engine_errors
ROOT=Path(__file__).resolve().parents[1]
def profile_hashes(godot):
    values=input_hashes()
    for path in [ROOT/'tools/profile_maps.py',ROOT/'tests/mobile_profile.gd']:
        values[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    values['engine_binary']=hashlib.sha256(godot.read_bytes()).hexdigest()
    return values

def validate_trace(data,map_id,scenario,version):
    if (data.get('map'),data.get('scenario'),data.get('version'),data.get('headless'))!=(map_id,scenario,version,True):
        raise RuntimeError('Profile metadata does not match this run')
    times=data.get('frame_times_ms',[])
    if len(times)!=600 or data.get('samples')!=600 or any(type(v) not in (int,float) or not math.isfinite(v) or v<0 for v in times):
        raise RuntimeError('Profile requires 600 finite measured intervals')
    updates=data.get('measured_reveal_updates');strength=data.get('reveal_strength')
    if type(updates) is not int or updates!=600 or type(strength) not in (int,float) or not math.isfinite(strength) or not .99<=strength<=1.0 or data.get('reveal_per_frame_scene_scans')!=0:
        raise RuntimeError('Reveal was not active throughout the measured trace')
    ordered=sorted(times)
    for key,q in [('p50_ms',.5),('p95_ms',.95),('p99_ms',.99),('worst_ms',1)]:
        expected=ordered[min(599,int(600*q))]
        if not math.isclose(data.get(key,-1),expected,abs_tol=.000001):
            raise RuntimeError('Reported percentile does not match intervals: '+key)
    if data.get('over_16_67_ms')!=sum(v>16.667 for v in times):
        raise RuntimeError('Reported frame-budget count does not match intervals')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--repeats',type=int,default=3)
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    if args.repeats<1:parser.error('--repeats must be positive')
    (out/'summary.json').unlink(missing_ok=True)
    godot=args.godot.resolve();before=profile_hashes(godot)
    version=next(line.split('=',1)[1].strip('"') for line in (ROOT/'project.godot').read_text().splitlines() if line.startswith('config/version='))
    base=[str(godot),'--headless','--path',str(ROOT),'--fixed-fps','60']
    records=[]
    for repeat in range(args.repeats):
        for map_id in ['city','food']:
            for scenario in ['opening','grown']:
                name=f'{map_id}-{scenario}-{repeat+1}';report=out/(name+'.json');log=out/(name+'.log')
                print('Profiling '+name,flush=True)
                report.unlink(missing_ok=True)
                command=base+['--script',str(ROOT/'tests/mobile_profile.gd'),'--log-file',str(out/(name+'.engine.log')),'--','--test','--map='+map_id,'--scenario='+scenario,'--report='+str(report)]
                with log.open('w') as stream:result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
                text=log.read_text()
                if result.returncode or unexpected_engine_errors(text) or 'MOBILE_PROFILE ' not in text or not report.is_file():raise RuntimeError('Profile failed: '+str(log))
                data=json.loads(report.read_text());validate_trace(data,map_id,scenario,version)
                data['native_contact_diagnostics']=text.count('num_points >= max_clip');records.append(data)
    if before!=profile_hashes(godot):raise RuntimeError('Source or engine changed while profiling; no summary published')
    summary={}
    for map_id in ['city','food']:
        for scenario in ['opening','grown']:
            rows=[r for r in records if r['map']==map_id and r['scenario']==scenario]
            summary[map_id+'-'+scenario]={key:statistics.median(r[key] for r in rows) for key in ['p50_ms','p95_ms','p99_ms','worst_ms','nodes']}
            summary[map_id+'-'+scenario].update(samples=sum(r['samples'] for r in rows),over_16_67_ms=sum(r['over_16_67_ms'] for r in rows),native_contact_diagnostics=sum(r['native_contact_diagnostics'] for r in rows))
            summary[map_id+'-'+scenario]['measured_reveal_updates']=sum(r['measured_reveal_updates'] for r in rows)
    result={'scope':'Mac headless CPU wall times, median of independent runs; not browser or phone FPS','repeats':args.repeats,'summary':summary,'source_sha256':before,'inputs_unchanged':True}
    (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
if __name__=='__main__':main()
