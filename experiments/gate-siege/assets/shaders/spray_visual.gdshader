shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float clock = 0.0;
varying vec4 tint;
varying float life;

void vertex() {
	tint = COLOR;
	float age = clock - (INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.y);
	float speed = INSTANCE_CUSTOM.z;
	float maximum_length = length(MODEL_MATRIX[2].xyz);
	float distance_limit = INSTANCE_CUSTOM.w;
	float travelled = max(0.0, age) * speed;
	life = 0.0;
	if (age < 0.0 || distance_limit <= 0.0 || travelled > distance_limit + maximum_length) {
		// Collapse expired/unborn quads behind the eye; no fragments or CPU expiry.
		VERTEX = vec3(0.0, 0.0, 1.0);
	} else {
		vec3 origin = MODEL_MATRIX[3].xyz;
		vec3 direction = normalize(MODEL_MATRIX[1].xyz);
		float width = length(MODEL_MATRIX[0].xyz);
		vec3 to_camera = normalize(INV_VIEW_MATRIX[3].xyz - origin);
		vec3 sideways = cross(direction, to_camera);
		if (dot(sideways, sideways) < 0.00001) {
			sideways = MODEL_MATRIX[0].xyz;
		}
		sideways = normalize(sideways);
		// A new shot grows forward from the muzzle, never behind the boots.
		float visible_length = min(maximum_length, travelled);
		float head_distance = min(travelled, distance_limit);
		visible_length = min(visible_length, head_distance);
		vec3 center = origin + direction * (head_distance - visible_length * 0.5);
		vec3 world = center + sideways * VERTEX.x * width - direction * VERTEX.y * visible_length;
		VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
		// Dissolve at the endpoint, rather than sailing through a hit target.
		life = 1.0 - smoothstep(distance_limit, distance_limit + max(0.1, maximum_length), travelled);
	}
}

void fragment() {
	if (life <= 0.001) {
		discard;
	}
	// Exact accepted colored alpha-blended profile: narrow white core and soft halo.
	float x = abs(UV.x - 0.5) * 2.0;
	float head = smoothstep(0.0, 0.12, UV.y);
	float tail = pow(max(0.0, 1.0 - UV.y), 0.45);
	float halo = exp(-x * x * 5.5);
	float core = exp(-x * x * 100.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.5);
	ALPHA = halo * head * tail * 0.82 * tint.a * life;
}
