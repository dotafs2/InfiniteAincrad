shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Static, restrained material grain. Silhouette and large details are geometry.
uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness = 0.5;
uniform float metallic = 0.0;
uniform int pattern = 0;
uniform float grain = 0.08;
varying vec3 model_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() { model_position = VERTEX; }

void fragment() {
	vec3 p = model_position;
	float detail = noise3(p * 37.0) - 0.5;
	float broad = noise3(p * 6.0) - 0.5;
	float variation = detail * 0.5 + broad;
	if (pattern == 2) { // Long wood grain.
		variation = sin(p.y * 4.0 + noise3(p * vec3(21.0, 1.4, 21.0)) * 15.0) * 0.5;
	} else if (pattern == 3) { // Mineral seams, deliberately sparse.
		float vein = abs(sin((p.x + p.z * 0.7) * 15.0 + noise3(p * 4.0) * 7.0));
		variation = smoothstep(0.92, 0.99, vein) * 1.5 + broad * 0.5;
	} else if (pattern == 4) { // Baked textile weave, no fiber meshes.
		float weave = sin((p.x + p.z) * 110.0) * sin((p.x - p.z + p.y) * 100.0);
		float fade = 1.0 - smoothstep(0.5, 2.0, fwidth((p.x + p.z) * 110.0));
		variation = weave * fade * 0.45 + broad * 0.5;
	} else if (pattern == 6) { // Watermelon rind.
		float angle = atan(p.x, p.z);
		variation = sin(angle * 15.0 + noise3(p * 12.0) * 1.7) * 1.8;
	} else if (pattern == 7) { // Fine brushed metal.
		variation = sin(p.y * 140.0) * 0.22 + detail * 0.35;
	}
	ALBEDO = base_color.rgb * (1.0 + variation * grain);
	ROUGHNESS = clamp(roughness + detail * grain * 0.4, 0.13, 1.0);
	METALLIC = metallic;
	SPECULAR = 0.45;
	CLEARCOAT = roughness < 0.35 ? 0.25 : 0.0;
	CLEARCOAT_ROUGHNESS = 0.3;
}
