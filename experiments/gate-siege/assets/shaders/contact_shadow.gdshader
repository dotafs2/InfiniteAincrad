shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform sampler2D shadow_texture : filter_linear, repeat_disable;
uniform bool use_texture = false;
uniform bool clip_to_road = false;
uniform float opacity : hint_range(0.0, 1.0) = 0.24;
varying vec2 ground_position;

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Transparent quads must not extend beyond the actual receiving runway.
	if (clip_to_road && (abs(ground_position.x) > 5.10 || ground_position.y < -15.15 || ground_position.y > 15.95)) {
		discard;
	}
	float mask;
	if (use_texture) {
		mask = texture(shadow_texture, UV).a;
	} else {
		float d = length((UV - vec2(0.5)) * 2.0);
		mask = 1.0 - smoothstep(0.45, 1.0, d);
	}
	ALBEDO = vec3(0.06, 0.065, 0.085);
	ALPHA = mask * opacity;
}
