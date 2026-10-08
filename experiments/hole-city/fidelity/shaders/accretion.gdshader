// Original, bounded-cost accretion ribbons; not a relativistic ray tracer.
// Visual references are recorded in docs/skin-ui-20260928.md.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fx_time = 0.0;
uniform float spectral = 0.0;
uniform float lensed = 0.0;
uniform float core_blue = 0.0;
void fragment() {
    float a = UV.x * 6.283185;
    float r = UV.y;
    float spin = a - fx_time * (1.5 + (1.0 - r) * 1.8);
    float turbulent = sin(spin * 7.0 + r * 23.0 + sin(spin * 3.0 - r * 11.0));
    float filament = pow(0.5 + 0.5 * sin(r * 74.0 + turbulent * 2.0), 3.0);
    float stream = 0.5 + 0.5 * sin(spin * 3.0 + r * 17.0 + turbulent);
    float hot_edge = exp(-r * 13.0);
    float beaming = 0.5 + 0.5 * pow(0.5 + 0.5 * cos(a - 0.8), 2.0);
    vec3 cool = mix(vec3(0.74, 0.075, 0.012), vec3(0.15, 0.02, 0.72), spectral);
    vec3 warm = mix(vec3(1.0, 0.60, 0.09), vec3(0.97, 0.12, 0.76), spectral);
    vec3 hot = mix(vec3(1.0, 0.96, 0.69), vec3(0.62, 0.95, 1.0), spectral);
    cool = mix(cool, vec3(0.01, 0.16, 0.64), core_blue);
    warm = mix(warm, vec3(0.08, 0.63, 1.0), core_blue);
    hot = mix(hot, vec3(0.75, 0.94, 1.0), core_blue);
    vec3 color = mix(cool, warm, stream * 0.65 + filament * 0.35);
    color = mix(color, hot, clamp(hot_edge + filament * 0.32, 0.0, 1.0));
    ALBEDO = color * beaming;
    float envelope = smoothstep(0.0, 0.035, r) * (1.0 - smoothstep(0.5, 1.0, r));
    ALPHA = envelope * (0.5 + 0.5 * stream) * (0.90 - lensed * 0.22);
}
