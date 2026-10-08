from pathlib import Path
import importlib.util,json,hashlib
r=Path(__file__).resolve().parents[3];o=Path(__file__).resolve().parent;s=importlib.util.spec_from_file_location('gate',r/'tools/release_web.py');g=importlib.util.module_from_spec(s);s.loader.exec_module(g)
g.REVIEW_SCRIPTS['food_growth_review']=('food_growth_review.gd','FOOD_GROWTH_REVIEW')
paths=['fidelity/food_city.gd','fidelity/food_body.gd','assets/food_city/neighborhoods.json','tools/build_food_neighborhoods.py','tests/food_growth_review.gd','tests/food_finish_acceptance.gd'];hashes=lambda:{p:hashlib.sha256((r/p).read_bytes()).hexdigest() for p in paths};before=hashes();results={}
for suite,minimum in [('food_growth_review',1476)]:
 results[suite]=g.acceptance([str(r/'.build/godot-standard/Godot.app/Contents/MacOS/Godot'),'--headless','--path',str(r),'--script',str(r/'tests'/g.suite_script(suite)),'--fixed-fps','60','--quit-after','15000','--','--test'],o/(suite+'-final.log'),o/(suite+'-final.json'),suite,minimum)
 print(suite,results[suite]['checks'],flush=True)
after=hashes();assert before==after
(o/'acceptance-final-provenance.json').write_text(json.dumps({'result':'pass','checks':{k:v['checks'] for k,v in results.items()},'inputs_before':before,'inputs_after':after},indent=2)+'\n')
