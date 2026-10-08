shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float clock = 0.0;
void fragment(){
 float radius=length((UV-vec2(0.5))*2.0);
 float edge=1.0-smoothstep(0.965,1.0,radius);
 float ring=smoothstep(0.86,0.92,radius)*edge;
 ALBEDO=mix(vec3(0.95,0.08,0.025),vec3(1.0,0.54,0.15),ring);
 ALPHA=edge*(0.15+0.09*(0.5+0.5*sin(clock*15.0)))+ring*0.56;
}
