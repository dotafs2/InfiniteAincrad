from pathlib import Path
import hashlib,importlib.util,json
r=Path(__file__).resolve().parents[3];o=Path(__file__).resolve().parent
sp=importlib.util.spec_from_file_location('gate',r/'tools/release_web.py');g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g);g.REVIEW_SCRIPTS['rain_admission_review']=('rain_admission_review.gd','RAIN_ADMISSION_REVIEW')
paths=['fidelity/food_city.gd','fidelity/food_body.gd','tests/food_rain_continuity_acceptance.gd','tests/rain_admission_review.gd','tests/snack_city_acceptance.gd','tests/rain_admission_acceptance.gd','tests/rain_support_acceptance.gd'];hashes=lambda:{p:hashlib.sha256((r/p).read_bytes()).hexdigest() for p in paths};before=hashes();results={}
for suite,minimum in [('rain_admission_review',101),('food_rain_continuity',38),('snack_city',80),('rain_admission',71),('rain_support',102)]:
 c=[str(r/'.build/godot-standard/Godot.app/Contents/MacOS/Godot'),'--headless','--path',str(r),'--script',str(r/'tests'/g.suite_script(suite)),'--fixed-fps','60','--quit-after','30000','--','--test']
 results[suite]=g.acceptance(c,o/(suite+'-final.log'),o/(suite+'-final.json'),suite,minimum);print(suite,results[suite]['checks'],flush=True)
after=hashes();assert before==after
(o/'final-provenance.json').write_text(json.dumps({'result':'pass','checks':{k:v['checks'] for k,v in results.items()},'inputs_before':before,'inputs_after':after},indent=2)+'\n')
