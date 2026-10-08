// Three bounded noise scales restore billow detail without extra cloud draws.
float storm_hash(vec2 p) {
 vec3 h = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
 h += dot(h, h.yzx + 33.33);
 return fract((h.x + h.y) * h.z);
}
float storm_noise(vec2 p) {
 vec2 cell = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(storm_hash(cell), storm_hash(cell + vec2(1.0, 0.0)), f.x),
  mix(storm_hash(cell + vec2(0.0, 1.0)), storm_hash(cell + vec2(1.0)), f.x), f.y);
}
float storm_density(vec2 p) {
 return storm_noise(p) * 0.55 + storm_noise(p * 2.03 + vec2(13.7, 4.3)) * 0.30
  + storm_noise(p * 4.13 + vec2(7.9, 21.1)) * 0.15;
}
vec3 storm_color(float density, float light, float energy) {
 float shade = clamp(0.12 + light * 0.68 + (density - 0.5) * 1.35, 0.0, 1.0);
 vec3 color = mix(vec3(0.095, 0.035, 0.19), vec3(0.65, 0.40, 0.87), shade);
 return color + vec3(0.18, 0.10, 0.055) * energy * (0.3 + light * 0.7);
}
