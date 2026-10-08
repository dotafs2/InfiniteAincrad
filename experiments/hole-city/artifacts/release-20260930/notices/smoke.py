from pathlib import Path
import hashlib, importlib.util, json, shutil, sys, tempfile
from unittest import mock
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
import package_web_notices as notices
import release_web as release
OUT=ROOT/'artifacts/release-20260930/notices'
checks=[]
def check(condition, description):
    checks.append({'check':description,'passed':bool(condition)})
    if not condition:raise AssertionError(description)
def snapshot(folder):
    return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file()}
before_inputs=release.input_hashes()
served_before=snapshot(ROOT/'build/web')
candidate=OUT/'copied-export'
if candidate.exists():raise RuntimeError('Preserve existing smoke candidate; use fresh evidence directory')
candidate.mkdir()
for name in ('index.html','index.js'):
    shutil.copy2(ROOT/'build/web'/name,candidate/name)
real_run=notices.subprocess.run
engine_runs=[]
def capture(command,**kwargs):
    result=real_run(command,**kwargs)
    log=Path(command[command.index('--log-file')+1])
    index=len(engine_runs)
    (OUT/f'smoke-engine-{index}.log').write_text(result.stdout+('\n'+log.read_text() if log.exists() else ''))
    engine_runs.append({'command':command,'returncode':result.returncode})
    return result
with mock.patch.object(notices.subprocess,'run',side_effect=capture):
    artifacts=notices.install_notices(candidate,ROOT/'.build/godot-standard/Godot.app/Contents/MacOS/Godot')
    first=snapshot(candidate)
    repeated=notices.install_notices(candidate,ROOT/'.build/godot-standard/Godot.app/Contents/MacOS/Godot')
check(first==snapshot(candidate) and artifacts==repeated,'Actual engine install repeated byte-identically')
check(len(artifacts)==9 and all(first[k]==v for k,v in artifacts.items()),'Nine installed artifacts match returned SHA-256')
for source,dest,_ in notices.SOURCE_NOTICES:
    check((ROOT/source).read_bytes()==(candidate/'notices'/dest).read_bytes(),'Exact source bytes: '+source)
page=(candidate/'index.html').read_text()
check('statusOverlay.remove();' in page and "setStatusMode('hidden');" in page,'Existing engine removes status overlay including credits entry')
check(page.count(notices.HEAD_START)==1 and page.count(notices.LOAD_START)==1,'Exactly one entry of each type')
check((candidate/'index.js').read_bytes()==(ROOT/'build/web/index.js').read_bytes(),'Existing engine bootstrap script unchanged')
check(served_before==snapshot(ROOT/'build/web'),'Served Web build untouched')
check(before_inputs==release.input_hashes(),'All release inputs untouched')
# Non-author integration checks, exclusively synthetic candidate/preview paths.
with tempfile.TemporaryDirectory(prefix='notice-release-integration-') as temp:
    base=Path(temp);source=base/'candidate';target=base/'preview'
    shutil.copytree(candidate,source);target.mkdir();(target/'old.txt').write_text('old preview')
    hashes=snapshot(source)
    release.publish_candidate(source,target,hashes)
    check(snapshot(target)==hashes,'Recursive publisher carries and checks nested license artifacts')
    previous=snapshot(target)
    (source/'notices/MUSIC_CREDITS.txt').write_text('tampered nested input')
    try:release.publish_candidate(source,target,hashes)
    except RuntimeError:pass
    else:raise AssertionError('Nested tamper accepted')
    check(previous==snapshot(target),'Nested notice hash failure preserves old preview')
    hashes=snapshot(source)
    real_rename=Path.rename
    def fail_swap(path,dest):
        if path.name=='ready':raise OSError('injected stage swap failure')
        return real_rename(path,dest)
    with mock.patch.object(Path,'rename',fail_swap):
        try:release.publish_candidate(source,target,hashes)
        except OSError:pass
        else:raise AssertionError('Swap fault not exercised')
    check(previous==snapshot(target),'Failed final swap restores prior nested preview')
required=['tools/package_web_notices.py','tests/test_web_notices.py','tools/runtime_licenses.gd','LICENSE','THIRD_PARTY.md','third_party/mbmayer/LICENSE','assets/fonts/OFL.txt','assets/audio/MUSIC_CREDITS.txt']
check(all(x in before_inputs for x in required),'All source notices/helper/tests/generator participate in gate input hashes')
# Confirm verifier loading by importlib does not depend on a caller sys.path.
spec=importlib.util.spec_from_file_location('notice_review_gate',ROOT/'tools/release_web.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
check(callable(module.install_notices),'Release integration imports via verifier importlib entry point')
report={'checks':len(checks),'failures':[],'assertions':checks,'engine_runs':engine_runs,'artifacts':artifacts,
        'input_sha256':{p:before_inputs[p] for p in required+['tools/release_web.py']},
        'engine_notice_bytes':(candidate/'notices/GODOT_LICENSES.txt').stat().st_size,
        'limitations':['Copied export HTML and actual headless engine license generation; no browser/UI verification.','Credits entry exists only during the engine loading overlay; credits.html remains directly accessible.','No publication or served build mutation.']}
(OUT/'smoke-result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'checks':len(checks),'failures':[],'engine_notice_bytes':report['engine_notice_bytes'],'artifacts':len(artifacts)}))
