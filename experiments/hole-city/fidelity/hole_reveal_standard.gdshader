shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://fidelity/hole_reveal.gdshaderinc"
uniform vec4 source_albedo : source_color = vec4(1.0);
uniform vec4 source_emission : source_color = vec4(0.0);
uniform float source_emission_energy = 1.0;
uniform float source_roughness = 1.0;
uniform float source_metallic = 0.0;
uniform float source_specular = 0.5;
uniform bool source_vertex_color = false;
uniform bool source_vertex_srgb = false;
uniform float reveal_occluder = 0.0;
void vertex() {
    // Match BaseMaterial3D: the sRGB vertex flag converts only in linear-output
    // renderers. Compatibility already has OUTPUT_IS_SRGB, so keep COLOR intact.
    if (source_vertex_srgb && !OUTPUT_IS_SRGB) {
        COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
    }
}
void fragment() {
    if (reveal_occluder > 0.0 && reveal_occluder * hole_reveal_body_mask(INV_VIEW_MATRIX[3].xyz, INV_VIEW_MATRIX[2].xyz, IN_SHADOW_PASS) > hole_reveal_threshold(FRAGCOORD.xy)) { discard; }
    ALBEDO = source_albedo.rgb * (source_vertex_color ? COLOR.rgb : vec3(1.0));
    ROUGHNESS = source_roughness;
    METALLIC = source_metallic;
    SPECULAR = source_specular;
    EMISSION = source_emission.rgb * source_emission_energy;
}
