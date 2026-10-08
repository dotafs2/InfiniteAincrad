#version 150
vec3 VERTEX; vec3 ALBEDO; vec3 EMISSION; float ALPHA=1.0; vec2 UV;
in vec2 out_uv; out vec4 out_color;
uniform vec4 base_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform vec4 accent_color = vec4(1.0);
uniform float fx_time = 0.0;
uniform int style = 0;
void shade() {
    vec3 color = base_color.rgb;
    if (style == 1) { // Brushed copper: narrow travelling reflection.
        float scan = pow(max(0.0, sin(UV.x * 6.283185 - fx_time * 1.4)), 18.0);
        color = mix(color * (0.78 + UV.y * 0.3), accent_color.rgb, scan * 0.85);
    } else if (style == 2) { // Leaves: a vein, not a travelling ring.
        float vein = 1.0 - smoothstep(0.02, 0.05, abs(UV.x - 0.5));
        color = mix(color, accent_color.rgb, vein * 0.6 + UV.y * 0.16);
    } else if (style == 3) { // Stone slabs and sparse molten cracks.
        float crack = pow(max(0.0, sin(UV.x * 26.0 + sin(UV.y * 17.0))), 35.0);
        color = mix(color * 0.7, accent_color.rgb, crack * (0.55 + 0.25 * sin(fx_time * 1.8)));
    } else if (style == 4) { // Warm breathing lantern glass.
        color = mix(color, accent_color.rgb, (0.5 + 0.5 * sin(fx_time * 2.4)) * 0.32);
    } else if (style == 5) { // Crystal facets and intermittent glints.
        vec2 cell = floor(UV * vec2(6.0, 4.0));
        float facet = fract(sin(dot(cell, vec2(12.7, 31.9))) * 431.2);
        float glint = pow(max(0.0, sin(fx_time * 1.5 + facet * 13.0)), 24.0);
        color = mix(color * (0.65 + facet * 0.45), accent_color.rgb, 0.16 + glint * 0.7);
    } else if (style == 6) { // Ember base, under the flame ribbons.
        color = mix(color, accent_color.rgb, 0.5 + 0.5 * sin(UV.x * 30.0 - fx_time * 5.0));
    } else if (style == 7) {
        color = 0.55 + 0.45 * cos(UV.x * 6.283185 + fx_time * 0.8 + vec3(0.0, 2.1, 4.2));
    }
    ALBEDO = color;
}

void main(){UV=out_uv; shade(); out_color=vec4(ALBEDO,ALPHA);}