from pathlib import Path
import importlib.util,hashlib,json,tempfile
r=Path(__file__).resolve().parents[3];out=Path(__file__).resolve().parent
pack=r/'build/qa-candidate-f_00f11j/index.pck'
spec=importlib.util.spec_from_file_location('gate',r/'tools/release_web.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
gate.REVIEW_SCRIPTS['shop_package_content']=('package_content_probe.gd','SHOP_PACKAGE_CONTENT')
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=digest(pack)
with tempfile.TemporaryDirectory(prefix='shop-package-review-',dir='/private/tmp') as cwd:
 cmd=[str(r/'.build/godot-standard/Godot.app/Contents/MacOS/Godot'),'--headless','--audio-driver','Dummy','--main-pack',str(pack),'--script',str(out/'package_content_probe.gd'),'--quit-after','30','--','--test']
 report=gate.acceptance(cmd,out/'package-content.log',out/'package-content.json','shop_package_content',12,cwd=cwd)
after=digest(pack);assert before==after
(out/'package-content-provenance.json').write_text(json.dumps({'status':'pass','checks':report['checks'],'candidate':str(pack),'pck_sha256_before':before,'pck_sha256_after':after,'probe_sha256':digest(out/'package_content_probe.gd'),'engine_sha256':digest(r/'.build/godot-standard/Godot.app/Contents/MacOS/Godot'),'cwd':'Fresh isolated /private/tmp/shop-package-review-* directory, removed after exit','command':cmd,'runtime_music_gate_status':'The full root-owned package gate is running separately; this receipt proves actual package contents only.'},indent=2)+'\n')
print(json.dumps({'checks':report['checks'],'pck_sha256':after}))
