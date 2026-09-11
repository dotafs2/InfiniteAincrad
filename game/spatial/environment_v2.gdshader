shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform int surface_kind = 0;
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;
uniform float review_time = -1.0;
varying vec3 local_position;

float hash_noise(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash_noise(i), hash_noise(i + vec3(1,0,0)), f.x), mix(hash_noise(i + vec3(0,1,0)), hash_noise(i + vec3(1,1,0)), f.x), f.y), mix(mix(hash_noise(i + vec3(0,0,1)), hash_noise(i + vec3(1,0,1)), f.x), mix(hash_noise(i + vec3(0,1,1)), hash_noise(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	local_position = VERTEX;
	float time = review_time >= 0.0 ? review_time : TIME;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float anchor = smoothstep(0.015, 0.22, VERTEX.y);
	float weight = UV2.x * anchor * wind_strength;
	float gust = sin(time * 0.73 + world.x * 0.18 + world.z * 0.13);
	float sway = sin(time * 1.55 + world.x * 0.45 + world.z * 0.31) + 0.28 * gust;
	float flutter = sin(time * 4.2 + UV2.y * 6.283 + world.x * 1.3) * UV.y * 0.014;
	VERTEX.x += weight * (sway * 0.072 + flutter);
	VERTEX.z += weight * (sway * 0.038 - flutter * 0.7);
	VERTEX.y -= weight * abs(sway) * 0.008;
}

void fragment() {
	vec3 color = COLOR.rgb;
	ROUGHNESS = 0.83;
	SPECULAR = 0.22;
	if (surface_kind == 1) {
		float rib = 1.0 - smoothstep(0.015, 0.037, abs(UV.x - 0.5));
		float veins = pow(0.5 + 0.5 * cos((UV.y - abs(UV.x - 0.5) * 0.65) * 64.0), 20.0);
		color *= 0.95 + 0.085 * rib + 0.024 * veins;
		ROUGHNESS = 0.72;
		BACKLIGHT = color * 0.24;
		if (!FRONT_FACING) NORMAL = -NORMAL;
	} else if (surface_kind == 2) {
		float warping = noise(vec3(UV * vec2(5.0, 0.65), 2.0));
		float grain = sin(UV.x * 155.0 + warping * 7.0);
		float broad = noise(vec3(UV * vec2(32.0, 1.7), 5.0));
		float groove = smoothstep(0.86, 0.98, grain);
		color *= 0.82 + broad * 0.24 - groove * 0.10;
	} else if (surface_kind == 3) {
		float weave = sin(UV.x * 330.0) * sin(UV.y * 330.0);
		color *= 0.97 + weave * 0.02;
		if (!FRONT_FACING) NORMAL = -NORMAL;
	} else if (surface_kind == 4) {
		ROUGHNESS = 0.22;
		SPECULAR = 0.55;
		float time = review_time >= 0.0 ? review_time : TIME;
		color *= 0.94 + 0.045 * sin(local_position.x * 19.0 + local_position.z * 13.0 + time);
	} else {
		float weather = noise(local_position * 5.0) * 0.65 + noise(local_position * 21.0) * 0.35;
		color *= 0.88 + weather * 0.18;
	}
	ALBEDO = color;
}
