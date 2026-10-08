"""Independent lightweight release-gate fault injection. No Godot or live preview."""
import importlib.util,json,sys,tempfile
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('release_review',ROOT/'tools/release_web.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checks=[]
def check(label,ok):checks.append({'label':label,'passed':bool(ok)})
source_hash=m.digest(ROOT/'tools/release_web.py')
with tempfile.TemporaryDirectory(prefix='hole-release-review-') as d:
    root=Path(d)
    fixtures=[
        ('native','ERROR: Failed loading resource: res://assets/example.res.','scene_qa',False),
        ('ca','ERROR: Condition "ret != noErr" is true. Returning: ""\n   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)','scene_qa',True),
        ('wrong-ca','ERROR: Condition "ret != noErr" is true. Returning: ""\n   at: unrelated_function (native.cpp:32)','scene_qa',False),
        ('fixture','ERROR: ConfigFile parse error at /tmp/hole-city-coin-qa-1234-broken.cfg:0: Unexpected EOF while parsing simple tag.','coin_skins',True),
        ('outside-suite','ERROR: ConfigFile parse error at /tmp/hole-city-coin-qa-1234-broken.cfg:0: Unexpected EOF while parsing simple tag.','scene_qa',False),
        ('other-cfg','ERROR: ConfigFile parse error at /tmp/player.cfg:0: Unexpected EOF while parsing simple tag.','coin_skins',False),
        ('late-native','SCENE_QA_ACCEPTANCE {"checks": 400, "failures": []}\nERROR: Resource disappeared.','scene_qa',False),
        ('ansi','\x1b[31mERROR: Failed loading resource.\x1b[0m','scene_qa',False),
        ('indent','  ERROR: Failed loading resource.','scene_qa',False),
        ('shader','SHADER ERROR: Invalid function.','scene_qa',False),
        ('fatal','FATAL ERROR: Unrecoverable.','scene_qa',False),
        ('clean','ordinary diagnostic','scene_qa',True),
    ]
    for case,text,suite,expect in fixtures:
        marker=m.REVIEW_SCRIPTS.get(suite,(None,suite.upper()+'_ACCEPTANCE'))[1]
        lines=text+'\n'+marker+' '+json.dumps({'checks':400,'failures':[]})
        accepted=True
        try:m.acceptance([sys.executable,'-c','print('+repr(lines)+')'],root/(case+'.log'),root/(case+'.json'),suite,400)
        except RuntimeError:accepted=False
        check(case,accepted==expect)
    for case,text,code in [('missing-marker','ordinary text',0),('nonzero','SCENE_QA_ACCEPTANCE {"checks": 400, "failures": []}',2),('low-checks','SCENE_QA_ACCEPTANCE {"checks": 399, "failures": []}',0),('failed-assertion','SCENE_QA_ACCEPTANCE {"checks": 400, "failures": ["actual failure"]}',0)]:
        accepted=True
        try:m.acceptance([sys.executable,'-c','print('+repr(text)+'); raise SystemExit('+str(code)+')'],root/(case+'.log'),root/(case+'.json'),'scene_qa',400)
        except RuntimeError:accepted=False
        check(case,not accepted)
    for case in ['success','copy-failure','stage-corruption','backup-failure','swap-failure','verify-failure','rollback-failure']:
        work=root/case;work.mkdir();candidate=work/'candidate';candidate.mkdir();preview=work/'web';preview.mkdir()
        (candidate/'index.html').write_text('new');(candidate/'index.pck').write_text('newpack')
        (preview/'index.html').write_text('old');(preview/'index.pck').write_text('oldpack')
        artifacts={p.name:m.digest(p) for p in candidate.iterdir()};realcopy=m.shutil.copytree;realrename=Path.rename;realdigest=m.digest
        def badcopy(src,dst,*args,**kwargs):
            realcopy(src,dst,*args,**kwargs)
            if case=='copy-failure':raise OSError('Injected postcopy exception')
            if case=='stage-corruption':(Path(dst)/'index.pck').write_text('corrupt')
        def badrename(path,target):
            if path==preview and case=='backup-failure':raise OSError('Injected backup exception')
            if path.name=='ready' and case in ['swap-failure','rollback-failure']:raise OSError('Injected swap exception')
            if path.name.startswith('web.previous-') and case=='rollback-failure':raise OSError('Injected restore exception')
            return realrename(path,target)
        def baddigest(path):
            if case=='verify-failure' and path.parent==preview and path.read_text().startswith('new'):return 'corrupt'
            return realdigest(path)
        error=None
        try:
            with patch.object(m.shutil,'copytree',badcopy),patch.object(Path,'rename',badrename),patch.object(m,'digest',baddigest):m.publish_candidate(candidate,preview,artifacts)
        except Exception as exc:error=str(exc)
        old=[p for p in work.rglob('index.html') if p.read_text()=='old' and (p.parent/'index.pck').read_text()=='oldpack']
        current=(preview/'index.html').read_text() if (preview/'index.html').exists() else None
        check(case,(current=='new' and error is None) if case=='success' else bool(old) and error is not None)
        if case=='rollback-failure':check('rollback-failure-discloses-retained-backup',old and str(old[0].parent) in error)
    inputs=m.input_hashes()
    for path in ['scripts/swallowable.gd','fidelity/main.tscn','export_presets.cfg','assets/city_kit/manifest.json','assets/fonts/Fredoka.ttf']:check('guard-'+path,path in inputs)
    for case,current in [('modified',{'one':'new'}),('removed',{}),('added',{'one':'old','two':'new'})]:
        with patch.object(m,'input_hashes',lambda:current):
            caught=False
            try:m.verify_inputs({'one':'old'})
            except RuntimeError:caught=True
            check('guard-rejects-'+case,caught)
    check('all-suite-paths-and-markers-match',all((ROOT/'tests'/m.suite_script(s)).exists() and m.REVIEW_SCRIPTS.get(s,(None,s.upper()+'_ACCEPTANCE'))[1] in (ROOT/'tests'/m.suite_script(s)).read_text() for s,e,n in m.SUITES))
    check('independent-food-revision-included',('food_revision_review',[],11) in m.SUITES)
    check('independent-skin-catalog-included',('skin_catalog_review',[],212) in m.SUITES)
check('release-source-unchanged-during-review',m.digest(ROOT/'tools/release_web.py')==source_hash)
result={'checks':checks,'passed':all(c['passed'] for c in checks),'count':len(checks),'inputs':len(inputs),'suites':len(m.SUITES),'sha256':source_hash,'scope':'Synthetic subprocesses and temporary fixture directories; no live preview, saves or Godot processes'}
Path(__file__).with_name('release-gate-review.json').write_text(json.dumps(result,indent=2)+'\n')
print('RELEASE_GATE_REVIEW '+json.dumps(result));sys.exit(0 if result['passed'] else 1)
