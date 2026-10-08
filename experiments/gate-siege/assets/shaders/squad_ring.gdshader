shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 ring_color : source_color = vec4(0.2,0.8,1.0,1.0);
void fragment(){
 float d=length((UV-vec2(0.5))*2.0);
 float ring=(1.0-smoothstep(0.80,1.0,d))*smoothstep(0.55,0.76,d);
 ALBEDO=ring_color.rgb;ALPHA=ring*ring_color.a;
}
