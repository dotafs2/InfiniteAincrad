from pathlib import Path
import importlib.util,hashlib,json
r=Path(__file__).resolve().parents[3];out=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('gate',r/'tools/release_web.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
gate.REVIEW_SCRIPTS['shop_theme_review']=('shop_theme_review.gd','SHOP_THEME_REVIEW')
paths=['fidelity/audio.gd','fidelity/audio_bus_layout.tres','assets/audio/shop_theme_loop.ogg','assets/audio/music_manifest.json','tools/prepare_shop_theme.py','tests/music_acceptance.gd','tests/music_review.gd','tests/shop_theme_review.gd'];hashes=lambda:{p:hashlib.sha256((r/p).read_bytes()).hexdigest() for p in paths};before=hashes();reports={}
for suite,minimum in [('shop_theme_review',55),('music_review',118),('music',125)]:
 cmd=[str(r/'.build/godot-standard/Godot.app/Contents/MacOS/Godot'),'--headless','--audio-driver','Dummy','--path',str(r),'--script',str(r/'tests'/gate.suite_script(suite)),'--fixed-fps','60','--quit-after','2000','--','--test']
 reports[suite]=gate.acceptance(cmd,out/(suite+'-source.log'),out/(suite+'-source.json'),suite,minimum);print(suite,reports[suite]['checks'],flush=True)
after=hashes();assert before==after
(out/'source-provenance.json').write_text(json.dumps({'status':'pass','checks':{k:v['checks'] for k,v in reports.items()},'inputs_before':before,'inputs_after':after,'audio_driver':'Dummy','scope':'Native audio decoder/controller and real UI lifecycle, no audible/browser certification.'},indent=2)+'\n')
