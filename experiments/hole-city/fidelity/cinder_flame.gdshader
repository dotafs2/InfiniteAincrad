shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float phase_shift = 0.0;
uniform float warmth = 0.0;

void vertex() {
	float angle = UV.x * 6.283185;
	float sway = sin(angle * 7.0 + TIME * 3.2 + phase_shift);
	VERTEX.x += cos(angle) * sway * UV.y * UV.y * 0.10;
	VERTEX.z += sin(angle) * sway * UV.y * UV.y * 0.10;
	VERTEX.y *= 0.88 + 0.12 * sin(TIME * 4.0 + angle * 9.0 + phase_shift);
}

void fragment() {
	float angle = UV.x * 6.283185;
	float flame_height = 0.52 + 0.22 * sin(angle * 9.0 + sin(TIME * 2.0 + angle * 3.0));
	flame_height += 0.12 * sin(angle * 17.0 - TIME * 4.6 + phase_shift);
	float edge = 1.0 - smoothstep(flame_height - 0.13, flame_height, UV.y);
	float turbulence = 0.78 + 0.22 * sin(angle * 22.0 - UV.y * 13.0 + TIME * 5.0);
	vec3 foot = vec3(1.0, 0.83 + warmth * 0.1, 0.26);
	vec3 tip = vec3(1.0, 0.17, 0.025);
	ALBEDO = mix(foot, tip, clamp(UV.y * 1.8, 0.0, 1.0));
	EMISSION = ALBEDO * 0.45;
	ALPHA = edge * turbulence * smoothstep(0.0, 0.06, UV.y) * 0.96;
}
