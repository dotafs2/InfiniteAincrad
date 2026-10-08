from pathlib import Path
import importlib.util,json,hashlib
root=Path(__file__).resolve().parents[3];out=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('gate',root/'tools/release_web.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
inputs=[root/'fidelity/audio.gd',root/'fidelity/audio_bus_layout.tres',root/'tools/build_music.py',*sorted((root/'assets/audio').glob('*.ogg')),root/'tests/music_acceptance.gd',root/'tests/music_review.gd']
hashfiles=lambda:{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
before=hashfiles();engine=root/'.build/godot-standard/Godot.app/Contents/MacOS/Godot';reports={}
for suite,minimum in [('music',125),('music_review',118)]:
 command=[str(engine),'--headless','--path',str(root),'--script',str(root/'tests'/gate.suite_script(suite)),'--fixed-fps','60','--quit-after','140000','--','--test']
 reports[suite]=gate.acceptance(command,out/(suite+'.log'),out/(suite+'.json'),suite,minimum)
 print(suite,reports[suite]['checks'],flush=True)
after=hashfiles();assert before==after
(out/'runtime-provenance.json').write_text(json.dumps({'result':'pass','inputs_before':before,'inputs_after':after,'checks':{k:v['checks'] for k,v in reports.items()},'scope':'Headless real engine functional checks; no audible playback, Web autoplay certification or browser workaround.'},indent=2)+'\n')
