"""Independent stored-evidence fault tests. HTTP is mocked; no Godot or source edits."""
from pathlib import Path
from unittest.mock import patch
from urllib.parse import urlparse,unquote
import contextlib,copy,hashlib,importlib.util,io,json,sys,tempfile
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('verifier_under_review',ROOT/'tools/verify_visual_release.py')
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
from release_web import input_hashes,SUITES
inputs=input_hashes()
shaders=json.loads((ROOT/'artifacts/mobile-visibility-20260928/shader-probe-final/result.json').read_text())
shader_fixture=json.loads((ROOT/'artifacts/mobile-visibility-20260928/shader-probe-final/fixture.json').read_text())
version=next(line.split('=',1)[1].strip('"') for line in (ROOT/'project.godot').read_text().splitlines() if line.startswith('config/version='))
checks=[]
def check(label,ok):checks.append({'label':label,'pass':bool(ok)})
artifact_names=['index.html','index.js','index.wasm','index.pck','index.audio.worklet.js','index.audio.position.worklet.js','index.icon.png','index.png','index.apple-touch-icon.png','device-qa.js']
payloads={name:('fixture '+name).encode() for name in artifact_names}
def trace(map_id,scenario):
    return dict(map=map_id,scenario=scenario,version=version,headless=True,
                frame_times_ms=[1.0]*600,samples=600,measured_reveal_updates=600,
                reveal_strength=1.0,reveal_per_frame_scene_scans=0,
                p50_ms=1,p95_ms=1,p99_ms=1,worst_ms=1,over_16_67_ms=0,nodes=10,
                native_contact_diagnostics=0)
def records():
    release=dict(failures=[],source_sha256=inputs,source_checks=sum(n for s,e,n in SUITES),
                 packaged_checks=sum(n for s,e,n in SUITES),artifacts={n:hashlib.sha256(b).hexdigest() for n,b in payloads.items()})
    summary={m+'-'+s:dict(p50_ms=1,p95_ms=1,p99_ms=1,worst_ms=1,nodes=10,samples=600,
             over_16_67_ms=0,native_contact_diagnostics=0,measured_reveal_updates=600) for m in ['city','food'] for s in ['opening','grown']}
    result={'release/release.json':release,'shader-probe-final/result.json':copy.deepcopy(shaders),
            'shader-probe-final/fixture.json':copy.deepcopy(shader_fixture),
            'cpu/summary.json':dict(source_sha256={'fixture':'matched'},inputs_unchanged=True,repeats=1,summary=summary)}
    result.update({'release/'+phase+'-'+suite+'.json':{'checks':minimum,'failures':[]} for phase in ['source','package'] for suite,_,minimum in SUITES})
    result.update({'cpu/'+m+'-'+s+'-1.json':trace(m,s) for m in ['city','food'] for s in ['opening','grown']})
    return result

cases=['clean','release-failure','source-changed','low-source-checks','low-package-checks','missing-source-suite','missing-package-suite','failed-suite','short-suite',
       'empty-artifacts','missing-pck','bad-artifact-name','shader-failure','empty-shader-inputs',
       'missing-shader-input','wrong-shader-hash','empty-programs','missing-program',
       'short-reveal-cases','short-albedo-cases','duplicate-program','uncompiled-program','invalid-reveal-result','invalid-albedo-result','profile-stale','profile-changed',
       'zero-repeats','false-repeats','missing-trace','invalid-trace','inflated-summary-samples',
       'false-summary-p95','missing-summary-scenario','corrupt-http','missing-coop','missing-coep','http-error']
with tempfile.TemporaryDirectory(prefix='hole-visual-receipt-review-') as folder:
    temp=Path(folder)
    for case in cases:
        base=temp/case;base.mkdir();data=records();release=data['release/release.json'];shader=data['shader-probe-final/result.json'];profile=data['cpu/summary.json'];http_calls=[]
        if case=='release-failure':release['failures']=['failure']
        if case=='source-changed':release['source_sha256']={}
        if case=='low-source-checks':release['source_checks']=0
        if case=='low-package-checks':release['packaged_checks']=0
        if case=='missing-source-suite':data.pop('release/source-mobile_thumbnail.json')
        if case=='missing-package-suite':data.pop('release/package-procedural_filtering.json')
        if case=='failed-suite':data['release/package-procedural_filtering.json']['failures']=['failure']
        if case=='short-suite':data['release/package-procedural_filtering.json']['checks']=26
        if case=='empty-artifacts':release['artifacts']={}
        if case=='missing-pck':release['artifacts'].pop('index.pck')
        if case=='bad-artifact-name':release['artifacts']['../bad']='bad'
        if case=='shader-failure':shader['failures']=['failure']
        if case=='empty-shader-inputs':shader['input_sha256']={}
        if case=='missing-shader-input':shader['input_sha256'].pop('fidelity/facade.gdshader')
        if case=='wrong-shader-hash':shader['input_sha256']['fidelity/facade.gdshader']='bad'
        if case=='empty-programs':shader['programs']=[]
        if case=='missing-program':shader['programs']=shader['programs'][1:]
        if case=='short-reveal-cases':next(p for p in shader['programs'] if p['name']=='reveal-coverage')['cases'].pop()
        if case=='short-albedo-cases':next(p for p in shader['programs'] if p['name']=='adapter-albedo')['cases'].pop()
        if case=='duplicate-program':shader['programs'].append(copy.deepcopy(shader['programs'][0]))
        if case=='uncompiled-program':shader['programs'][0]['compiled']=False
        if case=='invalid-reveal-result':next(p for p in shader['programs'] if p['name']=='reveal-coverage')['cases'][0]['total_pixels']=0
        if case=='invalid-albedo-result':next(p for p in shader['programs'] if p['name']=='adapter-albedo')['cases'][0]['center_rgba8']=[0,0,0,0]
        if case=='profile-stale':profile['source_sha256']={}
        if case=='profile-changed':profile['inputs_unchanged']=False
        if case=='zero-repeats':profile['repeats']=0
        if case=='false-repeats':profile['repeats']=False
        if case=='missing-trace':data.pop('cpu/city-opening-1.json')
        if case=='invalid-trace':data['cpu/city-opening-1.json']['measured_reveal_updates']=599
        if case=='inflated-summary-samples':profile['summary']['city-opening']['samples']=999999
        if case=='false-summary-p95':profile['summary']['city-opening']['p95_ms']=0.01
        if case=='missing-summary-scenario':profile['summary'].pop('city-opening')
        for name,record in data.items():
            target=base/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(record))
        (base/'verification.json').write_text('OLD VERIFIED')
        class Response:
            def __init__(self,name):
                self.name=name;self.headers={'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp','Cache-Control':'no-store'}
                if case=='missing-coop':self.headers.pop('Cross-Origin-Opener-Policy')
                if case=='missing-coep':self.headers.pop('Cross-Origin-Embedder-Policy')
            def __enter__(self):return self
            def __exit__(self,*args):return False
            def read(self):return b'corrupt' if case=='corrupt-http' else payloads[self.name]
        def urlopen(url,**kwargs):
            http_calls.append(url)
            if case=='http-error':raise OSError('Synthetic unreachable endpoint')
            return Response(unquote(urlparse(url).path.rsplit('/',1)[-1]))
        accepted=False;error=None
        with patch.object(v,'profile_hashes',return_value={'fixture':'matched'}),patch.object(v,'urlopen',urlopen),patch.object(sys,'argv',['verify','--evidence',str(base),'--godot',str(temp/'never-executed')]),contextlib.redirect_stdout(io.StringIO()):
            try:v.main();accepted=True
            except (RuntimeError,ValueError,KeyError,TypeError,OSError) as exc:error=type(exc).__name__+': '+str(exc)
        should_pass=case=='clean'
        check(case,accepted==should_pass)
        check('stale verification removed '+case,(base/'verification.json').exists()==should_pass)
        if should_pass and accepted:
            verified=json.loads((base/'verification.json').read_text())
            check('raw sample total matches four traces',verified['cpu_samples']==2400)
            check('all artifact bytes visited',len(http_calls)==len(payloads))
result={'passed':all(c['pass'] for c in checks),'checks':len(checks),'failures':[c for c in checks if not c['pass']],
        'cases':checks,'verifier_sha256':hashlib.sha256((ROOT/'tools/verify_visual_release.py').read_bytes()).hexdigest(),
        'scope':'Temporary synthetic receipts and mocked HTTP only; no network, Godot, runtime edits or live preview'}
(OUT/'visual-verifier-review.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result));sys.exit(0 if result['passed'] else 1)
