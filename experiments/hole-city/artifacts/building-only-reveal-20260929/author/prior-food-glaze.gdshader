shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://fidelity/hole_reveal.gdshaderinc"

// Opaque ingredient finish in COLOR.a, not transparency. Two broad studio
// reflections make glossy icing readable without SSR, bloom or extra lights.
uniform float glaze_strength = 0.72;
uniform float reveal_occluder = 0.0;
uniform bool reveal_use_instance = false;
varying float food_reveal_weight;
varying vec3 food_world_normal;
varying vec3 food_world_position;

vec3 food_reflection(vec3 n, vec3 view_direction, float roughness) {
    vec3 r = reflect(-view_direction, n);
    float gloss = 1.0 - smoothstep(0.20, 0.62, roughness);
    float broad = pow(max(dot(r, normalize(vec3(-0.45, 0.86, 0.38))), 0.0), mix(9.0, 24.0, gloss));
    float strip = pow(max(dot(r, normalize(vec3(0.65, 0.65, -0.38))), 0.0), 32.0);
    float edge = pow(1.0 - max(dot(n, view_direction), 0.0), 4.0);
    return vec3(1.0, 0.97, 0.89) * broad * mix(0.045, 0.82, gloss)
        + vec3(0.80, 0.91, 1.0) * (strip * 0.20 + edge * 0.045) * gloss;
}

void vertex() {
    food_reveal_weight = reveal_use_instance ? INSTANCE_CUSTOM.r : reveal_occluder;
    food_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    food_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    if (food_reveal_weight > 0.0 && food_reveal_weight * hole_reveal_mask(food_world_position, INV_VIEW_MATRIX[3].xyz, INV_VIEW_MATRIX[2].xyz, IN_SHADOW_PASS) > hole_reveal_threshold(FRAGCOORD.xy)) { discard; }
    // Match StandardMaterial's sRGB vertex-albedo decoding.
    ALBEDO = mix(pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
    ROUGHNESS = clamp(COLOR.a, 0.18, 0.70);
    SPECULAR = 0.5;
    vec3 n = normalize(food_world_normal);
    vec3 v = normalize(CAMERA_POSITION_WORLD - food_world_position);
    EMISSION = food_reflection(n, v, ROUGHNESS) * glaze_strength;
}
