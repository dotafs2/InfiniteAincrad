shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float palette_mix=0.0;
uniform vec4 palette_primary:source_color=vec4(0.1,0.4,0.6,1.0);
uniform vec4 palette_secondary:source_color=vec4(0.8,0.9,1.0,1.0);
#include "res://fidelity/shaders/tempest_common.gdshaderinc"
uniform float fx_time=0.0;
varying vec2 seed;
void vertex() {
 seed=INSTANCE_CUSTOM.xy*12.0;
 mat4 facing=mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),
  INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),
  INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 MODELVIEW_MATRIX=VIEW_MATRIX*facing;
}
void fragment() {
 vec2 p=UV*2.0-1.0;float r=length(p);
 vec2 drift=vec2(sin(fx_time*TAU/3.0),cos(fx_time*TAU/3.0))*.10;
 float density=storm_density(p*3.3+seed+drift);
 float light=clamp(.6-p.y*.3+(density-.5)*1.6,0.0,1.0);
 ALBEDO=mix(vec3(.07,.18,.20),vec3(.79,.88,.92),light);
 ALPHA=(1.0-smoothstep(.55,1.0,r+(0.5-density)*.3))*(1.0-smoothstep(.84,.99,r))*.55;
 // A variant changes color only; density, alpha and intake timing stay identical.
 float value=clamp(dot(ALBEDO,vec3(.2126,.7152,.0722)),0.0,1.0);
 ALBEDO=mix(ALBEDO,mix(palette_primary.rgb*.36,palette_secondary.rgb,value),palette_mix);
}
