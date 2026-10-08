shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float palette_mix=0.0;
uniform vec4 palette_primary:source_color=vec4(0.1,0.4,0.6,1.0);
uniform vec4 palette_secondary:source_color=vec4(0.8,0.9,1.0,1.0);
#include "res://fidelity/shaders/tempest_common.gdshaderinc"
uniform float fx_time = 0.0;
uniform float surge = 0.0;
uniform int surface_kind = 0;
varying vec3 storm_normal;
void vertex() {
 storm_normal = NORMAL;
 if (surface_kind == 1) {
  float roll = sin(UV.x * TAU * 3.0 - UV.y * 12.0 + fx_time * 1.6);
  VERTEX.xz *= 1.0 + roll * 0.045 * UV.y;
 }
}
void fragment() {
 if (surface_kind == 0) {
  vec2 p = (UV - 0.5) * 2.0;
  float r = length(p);
  float turn = fx_time * 0.24 + (1.0 - r) * 1.1;
  mat2 spin = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn)));
  vec2 q = spin * p * 4.2;
  float warp = storm_noise(q * 0.7 + fx_time * 0.05);
  float field = storm_density(q + vec2(warp - 0.5, 0.5 - warp) * 1.4);
  float light = clamp(0.52 - dot(p, vec2(0.16, 0.22)), 0.0, 1.0);
  ALBEDO = storm_color(field, light, surge);
  float edge = r + (0.5 - field) * 0.16;
  // A denser cloud shoulder bridges the real ground cut without hiding its
  // centre or changing collision. The outer cloud still feathers into the street.
  float shoulder = smoothstep(0.45, 0.64, r) * (1.0 - smoothstep(0.76, 0.88, r));
  ALPHA = (1.0 - smoothstep(0.75, 0.95, edge)) * (1.0 - smoothstep(0.76, 0.91, r))
   * max(mix(0.20, 0.40, field), shoulder * 0.96);
 } else {
  // Broken, translucent storm strands reveal props inside the funnel.
  float turn = UV.x * TAU - UV.y * 5.4 + fx_time * 1.45;
  vec2 q = vec2(cos(turn), sin(turn)) * 3.1 + vec2(UV.y * 3.4, -fx_time * 0.15);
  float field = storm_density(q);
  float roll = pow(0.5 + 0.5 * sin(turn * 3.0 + field * 2.6), 2.0);
  float wisps = pow(0.5 + 0.5 * sin(turn * 6.0 - UV.y * 3.0 + field * 4.0), 5.0);
  float light = max(0.0, dot(normalize(storm_normal), normalize(vec3(-0.45, 0.6, 0.65))));
  ALBEDO = storm_color(field, 0.40 + light * 0.30 + roll * 0.35 + wisps * 0.12, surge);
  // Tint existing fine strands; no extra noise, mesh or lightning branch.
  float filament = wisps * wisps * smoothstep(0.40, 0.75, field);
  ALBEDO = mix(ALBEDO, vec3(1.0, 0.69, 0.27), filament * (0.16 + surge * 0.34));
  float fade = smoothstep(0.0, 0.075, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
  ALPHA = (0.08 + field * 0.17 + roll * 0.16 + wisps * 0.055) * fade;
 }
 // A variant changes color only; density, alpha and intake timing stay identical.
 float value=clamp(dot(ALBEDO,vec3(.2126,.7152,.0722)),0.0,1.0);
 ALBEDO=mix(ALBEDO,mix(palette_primary.rgb*.36,palette_secondary.rgb,value),palette_mix);
}
