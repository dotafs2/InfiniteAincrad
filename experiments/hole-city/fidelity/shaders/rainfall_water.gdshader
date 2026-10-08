shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float palette_mix=0.0;
uniform vec4 palette_primary:source_color=vec4(0.1,0.4,0.6,1.0);
uniform vec4 palette_secondary:source_color=vec4(0.8,0.9,1.0,1.0);
uniform sampler2D wave_atlas : filter_linear, repeat_disable;
uniform float fx_time = 0.0;
uniform float intake = 0.0;
uniform float rival = 0.0;
uniform float impact_age = 4.0;
uniform vec2 contact_origin = vec2(0.0);
uniform float contact_age = 3.0;
varying vec3 world_at;
vec4 wave_frame(vec2 uv, float frame) {
 vec2 tile = vec2(mod(frame, 12.0), floor(frame / 12.0));
 // Two-pixel replicated gutters avoid sampling an adjacent animation frame.
 vec2 coord = (tile * 132.0 + vec2(2.5) + clamp(uv,vec2(0.0),vec2(1.0)) * 127.0) / vec2(1584.0,528.0);
 return texture(wave_atlas, coord);
}
vec4 wave(vec2 uv) {
 float frame = mod(fx_time, 3.0) * 16.0;
 return mix(wave_frame(uv, floor(frame)), wave_frame(uv, mod(floor(frame)+1.0,48.0)), fract(frame));
}
void vertex() {
 VERTEX.y += (wave(UV).b * 2.0 - 1.0) * 0.038;
 world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 vec4 baked = wave(UV);
 vec2 p = (UV - 0.5) * 2.6;
 float r = length(p);
 vec2 slope = (baked.rg * 2.0 - 1.0) * 0.12 * 13.0;
 // Confirmed swallowing adds one bounded transient; ambient rain is PDE-baked.
 float pulse = exp(-pow((r-impact_age*1.2)*5.0,2.0)) * sin(r*24.0-impact_age*27.0) * rival;
 slope += p / max(r,0.08) * pulse * 0.32;
 // One reused contact ripple, independent of the larger confirmed rival burst.
 vec2 contact_p = p-contact_origin;
 float contact_r = length(contact_p);
 float contact = exp(-pow((contact_r-contact_age*0.9)*7.0,2.0)) * sin(contact_r*30.0-contact_age*22.0) * (1.0-smoothstep(0.35,1.25,contact_age));
 slope += contact_p/max(contact_r,0.08)*contact*0.30;
 vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
 vec3 eye = normalize(INV_VIEW_MATRIX[3].xyz - world_at);
 vec3 reflected = reflect(-eye, normal);
 float fresnel = pow(1.0-clamp(dot(normal,eye),0.0,1.0),3.0);
 float highlight = pow(max(dot(reflected, normalize(vec3(-0.35,0.8,0.48))),0.0),42.0);
 float sky = smoothstep(0.28,0.72,reflected.y);
 float sky_band = smoothstep(0.35,0.56,reflected.y)*(1.0-smoothstep(0.64,0.88,reflected.y));
 vec3 deep = vec3(0.015,0.20,0.19);
 vec3 water = mix(deep,vec3(0.10,0.56,0.55),sky*0.7+fresnel*0.3);
 float silver = baked.a * (0.55+intake*0.18) + highlight * 0.65 + sky_band * 0.38;
 water = mix(water,vec3(0.84,0.97,0.94),clamp(silver,0.0,0.78));
 float edge_rim = exp(-pow((r-1.04)*24.0,2.0));
 // A restrained opal edge reuses the existing rim and one slow color wave.
 vec3 opal = mix(vec3(0.52,0.93,0.85),vec3(0.90,0.79,0.96),0.5+0.5*sin(p.x*2.1+p.y*1.3+fx_time*TAU/3.0));
 ALBEDO = water + opal*edge_rim*0.25 + vec3(0.18,0.29,0.30)*abs(pulse) + vec3(0.22,0.29,0.28)*abs(contact);
 ALPHA = (1.0-smoothstep(1.05,1.22,r)) * (0.89+edge_rim*0.09);
 // A variant changes color only; density, alpha and intake timing stay identical.
 float value=clamp(dot(ALBEDO,vec3(.2126,.7152,.0722)),0.0,1.0);
 ALBEDO=mix(ALBEDO,mix(palette_primary.rgb*.36,palette_secondary.rgb,value),palette_mix);
}
