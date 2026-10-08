#version 150
vec3 VERTEX; vec3 ALBEDO; vec3 EMISSION; float ALPHA=1.0; vec2 UV;
in vec3 in_position; in vec2 in_uv; out vec2 out_uv;
// Original, bounded-cost accretion ribbons; not a relativistic ray tracer.
// Visual references are recorded in docs/skin-ui-20260928.md.
uniform float fx_time = 0.0;
uniform float spectral = 0.0;
uniform float lensed = 0.0;
void shade() {
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
    vec3 color = mix(cool, warm, stream * 0.65 + filament * 0.35);
    color = mix(color, hot, clamp(hot_edge + filament * 0.32, 0.0, 1.0));
    ALBEDO = color * beaming;
    float envelope = smoothstep(0.0, 0.035, r) * (1.0 - smoothstep(0.5, 1.0, r));
    ALPHA = envelope * (0.5 + 0.5 * stream) * (0.90 - lensed * 0.22);
}

void main(){VERTEX=in_position; UV=in_uv;out_uv=UV; gl_Position=vec4(VERTEX.x/1.9,(VERTEX.y*0.75-VERTEX.z*0.66-0.15)/1.9,-(VERTEX.y*0.66+VERTEX.z*0.75)/10.0,1.0);}