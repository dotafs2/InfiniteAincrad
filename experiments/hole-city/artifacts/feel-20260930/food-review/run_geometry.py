from pathlib import Path
import hashlib,importlib.util,json
r=Path(__file__).resolve().parents[3];o=Path(__file__).resolve().parent
sp=importlib.util.spec_from_file_location('gate',r/'tools/release_web.py');g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g);g.REVIEW_SCRIPTS['food_geometry_review']=('unused','FOOD_GEOMETRY_REVIEW')
engine=r/'.build/godot-standard/Godot.app/Contents/MacOS/Godot';pack=r/'build/web/index.pck';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();package=sha(pack)
for label,opts,cwd in [('old',['--main-pack',str(pack)],'/private/tmp'),('new',['--path',str(r)],str(r))]:
 c=[str(engine),'--headless',*opts,'--script',str(o/'geometry_probe.gd'),'--log-file',str(o/(label+'-geometry.engine.log')),'--fixed-fps','60','--quit-after','1000','--','--test','--report='+str(o/(label+'-geometry-data.json'))]
 g.acceptance(c,o/(label+'-geometry.log'),o/(label+'-geometry-result.json'),'food_geometry_review',1,cwd=cwd)
 print(label,'pass',flush=True)
assert package==sha(pack)
a=json.loads((o/'old-geometry-data.json').read_text());b=json.loads((o/'new-geometry-data.json').read_text());assert a['shared_meshes']==b['shared_meshes'];assert a['food_count']==b['food_count']
rows=[]
for x,y in zip(a['opening'],b['opening']):
 old={v['key']:v for v in x['batches']};new={v['key']:v for v in y['batches']};changes=[]
 for key in sorted(set(old)|set(new)):
  was=old.get(key,{});now=new.get(key,{})
  dt=now.get('members',0)*now.get('per_body_triangles',0)-was.get('members',0)*was.get('per_body_triangles',0)
  dv=now.get('visible_bodies',0)*now.get('per_body_triangles',0)-was.get('visible_bodies',0)*was.get('per_body_triangles',0)
  if dt or dv:changes.append({'batch':key,'submitted_delta':dt,'individually_visible_delta':dv})
 rows.append({'radius':x['radius'],'before':{k:v for k,v in x.items() if k!='batches'},'after':{k:v for k,v in y.items() if k!='batches'},'deltas':changes})
(o/'geometry-comparison.json').write_text(json.dumps({'result':'pass','old_package_sha256':package,'old_version':a['version'],'shared_mesh_count':len(a['shared_meshes']),'all_mesh_arrays_identical':True,'body_count_before_after':[a['food_count'],b['food_count']],'total_triangles_before_after':[a['food_triangles'],b['food_triangles']],'batch_cell_before_after':[a['batch_cell'],b['batch_cell']],'opening':rows},indent=2)+'\n')
