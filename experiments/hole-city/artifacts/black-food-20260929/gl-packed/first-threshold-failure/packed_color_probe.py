"""Execute the pinned Godot instance-color multiply with actual packed GPU attributes.

This is an isolated windowless CGL reproducer, not Godot/browser scene capture.
The local half decoder substitutes only GLSL 4.20's unavailable unpack intrinsic.
"""
from pathlib import Path
import sys,json,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import validate_mobile_visual_shaders as shipped
OUT=Path(__file__).parent/'gl-packed';OUT.mkdir(exist_ok=True)
source=ROOT/'fidelity/food_glaze.gdshader'
scene=json.loads((OUT.parent/'before/package-scene.json').read_text())
vertex='''#version 150
in uvec4 instance_color_custom_data;
uniform vec4 probe_vertex_color;
uniform bool standalone;
out vec4 actual_color;
float half_value(uint bits) {
    uint exponent=(bits>>10u)&31u;uint mantissa=bits&1023u;
    float magnitude=exponent==0u ? float(mantissa)*exp2(-24.0) : (1.0+float(mantissa)/1024.0)*exp2(float(exponent)-15.0);
    return (bits&32768u)!=0u ? -magnitude:magnitude;
}
vec2 unpackHalf2x16(uint bits){return vec2(half_value(bits&65535u),half_value(bits>>16u));}
void main(){
    vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(p*2.0-1.0,0.0,1.0);
    // Pinned Godot scene-ed1daf0bf.glsl lines 651-656, same four components.
    vec4 color_interp=probe_vertex_color;
    vec4 instance_color;
    instance_color.xy=unpackHalf2x16(instance_color_custom_data.x);
    instance_color.zw=unpackHalf2x16(instance_color_custom_data.y);
    if(!standalone)color_interp*=instance_color;
    actual_color=color_interp;
}
'''
(OUT/'packed.vert').write_text(vertex)
frag=shipped.fragment(source,'vec4(ALBEDO,ROUGHNESS)',run_vertex=True)
frag=frag.replace('uniform vec4 probe_vertex_color = vec4(0.8,0.4,0.2,1.0);','in vec4 actual_color;')
frag=frag.replace('COLOR=probe_vertex_color;','COLOR=actual_color;')
(OUT/'food-color.frag').write_text(frag)
cases=[]
for color_name,color in sorted(scene['palette'].items()):
 for mode,packet,standalone in [('old_custom_only',[0,0,0,0],False),('white_color_custom',[0x3c003c00,0x3c003c00,0,0],False),('standalone_mesh',[0,0,0,0],True)]:
  cases.append({'name':color_name+':'+mode,'packed':packet,'uniforms':{'probe_vertex_color':color,'standalone':standalone},'mode':mode,'source_color':color})
fixture={'programs':[{'name':'actual-packed-food-color','vertex':'packed.vert','fragment':'food-color.frag','cases':cases}]}
(OUT/'fixture.json').write_text(json.dumps(fixture,indent=2)+'\n')
harness=(ROOT/'tools/visual_shader_probe.m').read_text()
harness=harness.replace('glLinkProgram(program);','glBindAttribLocation(program,15,"instance_color_custom_data");glLinkProgram(program);')
harness=harness.replace('NSDictionary *values=test[@"uniforms"];','''NSArray *packed=test[@"packed"];
            glDisableVertexAttribArray(15);
            glVertexAttribI4ui(15,[packed[0] unsignedIntValue],[packed[1] unsignedIntValue],[packed[2] unsignedIntValue],[packed[3] unsignedIntValue]);
            NSDictionary *values=test[@"uniforms"];''')
(OUT/'packed_probe.m').write_text(harness)
binary=OUT/'packed_probe'
compiled=subprocess.run(['xcrun','clang',str(OUT/'packed_probe.m'),'-framework','Foundation','-framework','OpenGL','-Wno-deprecated-declarations','-Wno-incompatible-pointer-types','-o',str(binary)],capture_output=True,text=True,timeout=60)
(OUT/'compile.log').write_text(compiled.stdout+compiled.stderr);compiled.check_returncode()
probe=subprocess.run([str(binary),str(OUT),str(OUT/'fixture.json')],capture_output=True,text=True,timeout=60)
(OUT/'probe.log').write_text(probe.stdout+probe.stderr);probe.check_returncode()
result=json.loads(probe.stdout);measurements=result['programs'][0]['cases'];failures=[];comparisons=[]
for index in range(0,len(cases),3):
 old,new,solo=measurements[index:index+3];expected=cases[index]['source_color'];labels=[row['name'] for row in measurements[index:index+3]]
 if labels!=[row['name'] for row in cases[index:index+3]]:failures.append('Missing/reordered case')
 if old['center_rgba8'][:3]!=[0,0,0]:failures.append(old['name']+': old packed zero did not produce black')
 if new['center_rgba8']!=solo['center_rgba8']:failures.append(new['name']+': batch differs from source mesh albedo/roughness')
 if max(new['center_rgba8'][:3])<20:failures.append(new['name']+': corrected ingredient is black')
 if abs(new['center_rgba8'][3]-round(max(.18,min(.70,expected[3]))*255))>1:failures.append(new['name']+': roughness alpha changed')
 comparisons.append({'ingredient':old['name'].split(':')[0],'source_rgba':expected,'old_rgba8':old['center_rgba8'],'fixed_rgba8':new['center_rgba8'],'standalone_rgba8':solo['center_rgba8']})
result.update({'failures':failures,'checks':len(comparisons)*4,'comparisons':comparisons,'shader_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'scene_fixture_sha256':hashlib.sha256((OUT.parent/'before/package-scene.json').read_bytes()).hexdigest(),'scope':'Actual CGL integer vertex attribute 15 with RGBA16F packed color and current food vertex/fragment equations; reproduces pinned native lane multiplication. Not Godot renderer invocation, browser pixels or a screenshot.'})
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'checks':result['checks'],'cases':len(cases),'ingredients':len(comparisons),'failures':failures,'first':comparisons[0]}))
if failures:raise SystemExit(1)
