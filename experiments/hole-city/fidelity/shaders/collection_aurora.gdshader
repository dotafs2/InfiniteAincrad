shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform vec4 primary:source_color=vec4(.12,.75,.64,1.0);
uniform vec4 secondary:source_color=vec4(.68,.43,.96,1.0);
uniform float fx_time=0.0;
uniform float surge=0.0;
void vertex(){
 VERTEX.y+=sin(UV.x*TAU*3.0+fx_time*.85)*.06*UV.y;
}
void fragment(){
 float strands=.5+.5*sin(UV.x*TAU*11.0-UV.y*4.0+fx_time*.7);
 float band=.5+.5*sin(UV.x*TAU*2.0+UV.y*2.4-fx_time*.32);
 ALBEDO=mix(primary.rgb,secondary.rgb,band)+vec3(.09)*strands+secondary.rgb*surge*.15;
 ALPHA=sin(UV.y*PI)*(.20+strands*.21+surge*.08);
}
