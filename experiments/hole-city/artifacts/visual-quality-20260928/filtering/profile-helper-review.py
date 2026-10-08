"""Independent synthetic profile-helper review. No Godot or game-source edits."""
from pathlib import Path
from unittest.mock import patch
import contextlib,copy,hashlib,importlib.util,io,json,math,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('profile_under_review',ROOT/'tools/profile_maps.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
checks=[]
def check(label,ok):checks.append({'label':label,'pass':bool(ok)})
version=next(line.split('=',1)[1].strip('"') for line in (ROOT/'project.godot').read_text().splitlines() if line.startswith('config/version='))
def trace(map_id='city',scenario='opening'):
    return dict(map=map_id,scenario=scenario,version=version,headless=True,
                frame_times_ms=[1.0]*600,samples=600,measured_reveal_updates=600,
                reveal_strength=1.0,reveal_per_frame_scene_scans=0,
                p50_ms=1,p95_ms=1,p99_ms=1,worst_ms=1,over_16_67_ms=0,nodes=10)
good=trace();p.validate_trace(good,'city','opening',version);check('valid trace accepted',True)
bad=[('map','food'),('scenario','grown'),('version','stale'),('headless',False),
     ('samples',599),('frame_times_ms',[1.0]*599),('frame_times_ms',[math.nan]*600),
     ('frame_times_ms',[math.inf]*600),('frame_times_ms',[-1.0]*600),('frame_times_ms',[True]*600),
     ('measured_reveal_updates',599),('measured_reveal_updates',math.nan),
     ('measured_reveal_updates',math.inf),('reveal_strength',.98),('reveal_strength',math.nan),
     ('reveal_strength',math.inf),('reveal_strength',1.1),('reveal_per_frame_scene_scans',1),
     ('p95_ms',2),('over_16_67_ms',1)]
for key,value in bad:
    data=copy.deepcopy(good);data[key]=value;caught=False
    try:p.validate_trace(data,'city','opening',version)
    except (RuntimeError,TypeError,ValueError):caught=True
    check('reject '+key+'='+repr(value)[:45],caught)

with tempfile.TemporaryDirectory(prefix='hole-profile-helper-review-') as folder:
    temp=Path(folder);fake=temp/'fake-engine';fake.write_bytes(b'never executed')
    errors={
      'native':'ERROR: Missing resource',
      'shader':'SHADER ERROR: deliberately invalid',
      'script':'SCRIPT ERROR: deliberately invalid',
      'fatal':'FATAL ERROR: deliberately invalid',
      'ansi':'\x1b[31m  ERROR: deliberately invalid\x1b[0m',
      'ca':'ERROR: Condition "ret != noErr" is true. Returning: ""\n   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)',
    }
    cases=['clean','ca','native','shader','script','fatal','ansi','nonzero','no-marker','missing-report','malformed-report','stale-report','bad-metadata','input-change','engine-change','timeout']
    for case in cases:
        out=temp/case;out.mkdir();(out/'summary.json').write_text('OLD SUMMARY')
        (out/'city-opening-1.json').write_text(json.dumps(good))
        report_removed=[];calls=[]
        def fake_run(command,stdout=None,**kwargs):
            map_id=next(s.removeprefix('--map=') for s in command if s.startswith('--map='))
            scenario=next(s.removeprefix('--scenario=') for s in command if s.startswith('--scenario='))
            report=Path(next(s.removeprefix('--report=') for s in command if s.startswith('--report=')))
            report_removed.append(not report.exists());calls.append(command)
            if case=='timeout':raise subprocess.TimeoutExpired(command,120)
            data=trace(map_id,scenario)
            if case=='bad-metadata':data['version']='stale'
            if case not in ['missing-report','stale-report']:
                report.write_text('not JSON' if case=='malformed-report' else json.dumps(data))
            stdout.write(errors.get(case,'ordinary line')+'\n')
            if case!='no-marker':stdout.write('MOBILE_PROFILE '+json.dumps(data)+'\n')
            stdout.flush()
            return type('Result',(),{'returncode':2 if case=='nonzero' else 0})()
        before={'input':'one','engine_binary':'engine-one'};after=dict(before)
        if case=='input-change':after['input']='two'
        if case=='engine-change':after['engine_binary']='engine-two'
        accepted=False
        with patch.object(p,'profile_hashes',side_effect=[before,after]),patch.object(p.subprocess,'run',fake_run),patch.object(sys,'argv',['profile','--godot',str(fake),'--output',str(out),'--repeats','1']),contextlib.redirect_stdout(io.StringIO()):
            try:p.main();accepted=True
            except (RuntimeError,ValueError,subprocess.TimeoutExpired):pass
        should_pass=case in ['clean','ca']
        check('run '+case,accepted==should_pass)
        check('stale summary removed '+case,(out/'summary.json').is_file()==should_pass)
        check('prior reports removed before launch '+case,bool(report_removed) and all(report_removed))
        check('command remains headless isolated test '+case,all('--headless' in c and '--test' in c and c[c.index('--fixed-fps')+1]=='60' for c in calls))
    hashes=p.profile_hashes(fake)
    for key in ['tools/profile_maps.py','tests/mobile_profile.gd','fidelity/hole_reveal.gdshaderinc','assets/food_city/streets.png.import','engine_binary']:
        check('fingerprint contains '+key,key in hashes)
    check('engine fingerprint binds actual bytes',hashes['engine_binary']==hashlib.sha256(fake.read_bytes()).hexdigest())

result={'passed':all(c['pass'] for c in checks),'checks':len(checks),'failures':[c for c in checks if not c['pass']],'cases':checks,
        'sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['tools/release_web.py','tools/profile_maps.py','tests/mobile_profile.gd']},
        'scope':'Direct trace validation and mocked subprocesses in temporary owned output folders; no Godot, source mutation, timing measurement or preview access'}
(OUT/'profile-helper-review.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result));sys.exit(0 if result['passed'] else 1)
