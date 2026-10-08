shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float palette_mix=0.0;
uniform vec4 palette_primary:source_color=vec4(0.1,0.4,0.6,1.0);
uniform vec4 palette_secondary:source_color=vec4(0.8,0.9,1.0,1.0);
#include "res://fidelity/shaders/tempest_common.gdshaderinc"
uniform float fx_time = 0.0;
uniform float surge = 0.0;
varying vec2 cloud_seed;
void vertex() {
 cloud_seed = INSTANCE_CUSTOM.xy * 12.0;
 mat4 facing = mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
  INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
  INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
 MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 vec2 q = p * 3.4 + cloud_seed + fx_time * vec2(0.12, -0.07);
 float curl = storm_noise(q * 0.7 + fx_time * 0.045);
 q += vec2(curl - 0.5, 0.5 - curl) * 1.15;
 float field = storm_density(q);
 float edge = r + (0.5 - field) * 0.40;
 vec3 normal = normalize(vec3(p.x, -p.y, sqrt(max(0.02, 1.0-r*r))));
 float light = max(0.0, dot(normal, normalize(vec3(-0.5, 0.7, 0.9))));
 ALBEDO = storm_color(field, light, surge);
 // Keep density perturbation strictly inside the billboard silhouette.
 ALPHA = (1.0 - smoothstep(0.64, 1.0, edge)) * (1.0 - smoothstep(0.82, 0.99, r))
  * mix(0.26, 0.65, smoothstep(0.22, 0.78, field));
 // A variant changes color only; density, alpha and intake timing stay identical.
 float value=clamp(dot(ALBEDO,vec3(.2126,.7152,.0722)),0.0,1.0);
 ALBEDO=mix(ALBEDO,mix(palette_primary.rgb*.36,palette_secondary.rgb,value),palette_mix);
}
