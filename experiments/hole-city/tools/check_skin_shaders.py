"""Prepare portable GLSL from the shipped procedural shaders for offscreen QA.

This checks equations and exported geometry; it is not a Godot/browser capture.
Run export_skin_render_fixture.gd first, then compile skin_shader_offscreen.m.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/skin-ui/glsl'
OUT.mkdir(parents=True,exist_ok=True)
for path in [*sorted((ROOT/'fidelity/shaders').glob('*.gdshader')), ROOT/'fidelity/cinder_flame.gdshader']:
    code=path.read_text()
    code=re.sub(r'^(shader_type|render_mode).*;\n','',code,flags=re.M)
    code=code.replace(' : source_color','')
    has_vertex='void vertex()' in code
    code=code.replace('void vertex()', 'void deform()').replace('void fragment()', 'void shade()')
    common='#version 150\nvec3 VERTEX; vec3 ALBEDO; vec3 EMISSION; float ALPHA=1.0; vec2 UV;\n'
    vertex=common+'in vec3 in_position; in vec2 in_uv; out vec2 out_uv;\n'+code+'\nvoid main(){VERTEX=in_position; UV=in_uv;'+('deform();' if has_vertex else '')+'out_uv=UV; gl_Position=vec4(VERTEX.x/1.9,(VERTEX.y*0.75-VERTEX.z*0.66-0.15)/1.9,-(VERTEX.y*0.66+VERTEX.z*0.75)/10.0,1.0);}'
    fragment=common+'in vec2 out_uv; out vec4 out_color;\n'+code+'\nvoid main(){UV=out_uv; shade(); out_color=vec4(ALBEDO,ALPHA);}'
    (OUT/(path.stem+'.vert')).write_text(vertex)
    (OUT/(path.stem+'.frag')).write_text(fragment)
(OUT/'flat.vert').write_text('#version 150\nin vec3 in_position; in vec2 in_uv; void main(){vec3 p=in_position; gl_Position=vec4(p.x/1.9,(p.y*.75-p.z*.66-.15)/1.9,-(p.y*.66+p.z*.75)/10.,1.);}')
(OUT/'flat.frag').write_text('#version 150\nuniform vec4 color; out vec4 out_color; void main(){out_color=color;}')
print('Prepared all five shipped shaders and the flat mouth material.')
