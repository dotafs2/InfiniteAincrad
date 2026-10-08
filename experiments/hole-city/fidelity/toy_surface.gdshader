shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://fidelity/hole_reveal.gdshaderinc"

// Opaque original vinyl toys. The shared small-toy/preview material keeps zero
// weight; only a unique whole-castle material is registered by the city reveal.
uniform float reveal_occluder = 0.0;
uniform float toy_roughness : hint_range(0.08, 0.8) = 0.18;
uniform float toy_gloss : hint_range(0.0, 1.0) = 0.85;
varying vec3 toy_world_normal;
varying vec3 toy_world_position;

void vertex() {
    toy_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    toy_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // One pixel threshold covers every face of one opted-in castle. No local
    // roof/wall perforation; the shared include preserves shadows and UI views.
    if (reveal_occluder > 0.0 && reveal_occluder * hole_reveal_body_mask(
            INV_VIEW_MATRIX[3].xyz, INV_VIEW_MATRIX[2].xyz, IN_SHADOW_PASS)
            > hole_reveal_threshold(FRAGCOORD.xy)) { discard; }
    ALBEDO = OUTPUT_IS_SRGB ? COLOR.rgb : mix(
        pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)),
        COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
    // Both cream blocks and colored roofs read as polished molded toy plastic.
    float chroma = max(COLOR.r, max(COLOR.g, COLOR.b)) - min(COLOR.r, min(COLOR.g, COLOR.b));
    float glaze = smoothstep(0.16, 0.44, chroma);
    ROUGHNESS = mix(0.24, toy_roughness, glaze);
    SPECULAR = mix(0.60, 0.72, glaze);
    CLEARCOAT = mix(0.45, 0.85, glaze);
    CLEARCOAT_ROUGHNESS = 0.10;
    vec3 n = normalize(toy_world_normal);
    vec3 view_direction = normalize(CAMERA_POSITION_WORLD - toy_world_position);
    vec3 reflected = reflect(-view_direction, n);
    float softbox = pow(max(dot(reflected, normalize(vec3(-0.42, 0.84, 0.36))), 0.0), 14.0);
    float ribbon = pow(max(dot(reflected, normalize(vec3(0.62, 0.72, -0.31))), 0.0), 28.0);
    // Subtle painted studio reflections keep vinyl legible without bloom/SSR.
    EMISSION = vec3(1.0, 0.98, 0.94) * (softbox * 0.30 + ribbon * 0.18) * toy_gloss * mix(0.35, 1.0, glaze);
}
