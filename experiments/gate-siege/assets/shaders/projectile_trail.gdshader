shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
 float x=abs(UV.x-0.5)*2.0;
 float head=smoothstep(0.0,0.12,UV.y);
 float tail=pow(max(0.0,1.0-UV.y),0.45);
 float halo=exp(-x*x*5.5);
 float core=exp(-x*x*100.0);
 ALBEDO=mix(tint.rgb,vec3(1.0),core*0.5);
 ALPHA=halo*head*tail*0.82;
}
