"""Non-author packed-attribute GPU checks from independently captured scene data.
No window, browser, Godot-renderer capture, or performance measurement.
"""
from pathlib import Path
import hashlib, importlib.util, json, math, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent;OUT=HERE/'gpu';OUT.mkdir(exist_ok=True)
old=json.loads((HERE/'old-package-scene.json').read_text());new=json.loads((HERE/'source-scene.json').read_text())
assert old['mesh_hashes']==new['mesh_hashes'] and old['palette']==new['palette'] and old['shader_code']==new['shader_code']
assert old['source_tool_visible'] is False
assert all(b['uses_custom_data'] and not b['uses_colors'] for b in old['batches'])
assert all(b['uses_custom_data'] and b['uses_colors'] for b in new['batches'])
helper=ROOT/'tools/validate_mobile_visual_shaders.py';spec=importlib.util.spec_from_file_location('glsl',helper);glsl=importlib.util.module_from_spec(spec);spec.loader.exec_module(glsl)
author=ROOT/'artifacts/black-food-20260929/gl-packed'
# Independently reviewed constant integer attribute 15 plus finite-half decode.
shutil.copyfile(author/'packed.vert',OUT/'packed.vert');shutil.copyfile(author/'packed_probe.m',OUT/'packed_probe.m')
source=ROOT/'fidelity/food_glaze.gdshader';assert source.read_text()==new['shader_code']
programs=[]
for program,output in [('albedo_roughness','vec4(ALBEDO,ROUGHNESS)'),('glaze_specular','vec4(EMISSION,SPECULAR)')]:
 frag=glsl.fragment(source,output,run_vertex=True).replace('uniform vec4 probe_vertex_color = vec4(0.8,0.4,0.2,1.0);','in vec4 actual_color;').replace('COLOR=probe_vertex_color;','COLOR=actual_color;')
 (OUT/(program+'.frag')).write_text(frag)
 cases=[]
 for name,color in sorted(new['palette'].items()):
  for mode,packet,solo in [('old',[0,0,0,0],False),('fixed',[0x3c003c00,0x3c003c00,0,0],False),('fixed_custom',[0x3c003c00,0x3c003c00,0x3c003c00,0x42004000],False),('solo',[0,0,0,0],True)]:
   cases.append({'name':name+':'+mode,'packed':packet,'uniforms':{'probe_vertex_color':color,'standalone':solo},'ingredient':color,'mode':mode})
 programs.append({'name':program,'vertex':'packed.vert','fragment':program+'.frag','cases':cases})
fixture={'programs':programs};(OUT/'fixture.json').write_text(json.dumps(fixture,indent=2)+'\n')
with tempfile.TemporaryDirectory(prefix='sink-food-color-review-') as scratch:
 binary=str(Path(scratch)/'probe')
 compiled=subprocess.run(['xcrun','clang',str(OUT/'packed_probe.m'),'-framework','Foundation','-framework','OpenGL','-Wno-deprecated-declarations','-Wno-incompatible-pointer-types','-o',binary],capture_output=True,text=True,timeout=60)
 (OUT/'compile.log').write_text(compiled.stdout+compiled.stderr);compiled.check_returncode()
 result=subprocess.run([binary,str(OUT),str(OUT/'fixture.json')],capture_output=True,text=True,timeout=60)
 (OUT/'probe.log').write_text(result.stdout+result.stderr);result.check_returncode();assert not result.stderr
observed=json.loads(result.stdout);checks=0;comparisons=[]
def check(value,label):
 global checks
 checks+=1
 if not value:raise AssertionError(label)
def linear(x):return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
for jobs,measured in zip(programs,observed['programs']):
 check(len(measured['cases'])==len(jobs['cases']),jobs['name']+': no missing cases')
 for offset in range(0,len(jobs['cases']),4):
  cases=jobs['cases'][offset:offset+4];rows=measured['cases'][offset:offset+4];rgba=[row['center_rgba8'] for row in rows]
  check([x['name'] for x in rows]==[x['name'] for x in cases],jobs['name']+': exact case binding')
  check(rgba[1]==rgba[3],jobs['name']+': corrected instance equals original standalone ingredient')
  check(rgba[2]==rgba[1],jobs['name']+': nonzero custom lanes cannot recolor the food')
  if jobs['name']=='albedo_roughness':
   color=cases[0]['ingredient'];expected=[round(linear(c)*255) for c in color[:3]]+[round(min(.7,max(.18,color[3]))*255)]
   check(rgba[0][:3]==[0,0,0],cases[0]['name']+': original zero color lane independently reproduces black albedo')
   check(max(abs(a-b) for a,b in zip(rgba[1],expected))<=1,cases[1]['name']+': full independent sRGB plus roughness oracle')
  comparisons.append({'program':jobs['name'],'name':cases[0]['name'].split(':')[0],'old':rgba[0],'fixed':rgba[1],'fixed_custom':rgba[2],'standalone':rgba[3]})
report={'pass':True,'checks':checks,'gpu_cases':sum(len(p['cases']) for p in programs),'ingredients':len(new['palette']),'renderer':observed['renderer'],'comparisons':comparisons,'shader_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'old_capture_sha256':hashlib.sha256((HERE/'old-package-scene.json').read_bytes()).hexdigest(),'new_capture_sha256':hashlib.sha256((HERE/'source-scene.json').read_bytes()).hexdigest(),'scope':'Actual windowless CGL integer attribute input, pinned instance color multiplication and shipped material functions. Headless captures establish real scene resources/flags; this does not invoke the full Godot renderer or capture browser pixels. Alpha stores roughness in one diagnostic program, not visibility.'}
(OUT/'independent-result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='comparisons'}))
