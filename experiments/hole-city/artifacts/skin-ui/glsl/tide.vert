#version 150
vec3 VERTEX; vec3 ALBEDO; vec3 EMISSION; float ALPHA=1.0; vec2 UV;
in vec3 in_position; in vec2 in_uv; out vec2 out_uv;
// Original raster approximation. Visual study: Chris Wallis, Moana ShaderToy.
// Angular/radial UVs; no scene-color copy or ray marching on mobile.
uniform float fx_time = 0.0;
uniform float splash = 0.0;
void deform() {
    float a = UV.x * 6.283185;
    float swell = sin(a * 5.0 + UV.y * 11.0 - fx_time * 3.4);
    VERTEX.y += (0.055 + splash * 0.035) * swell * sin(UV.y * 3.141593);
}
void shade() {
    float a = UV.x * 6.283185;
    float r = UV.y;
    float flow = a * 5.0 + r * 14.0 + fx_time * 3.2;
    float ripple = sin(flow + sin(a * 3.0 - fx_time) * 1.5);
    float cross_wave = sin(a * 13.0 - r * 8.0 - fx_time * 2.3);
    float caustic = pow(max(0.0, 1.0 - abs(ripple * 0.64 + cross_wave * 0.36)), 12.0);
    float crest = smoothstep(0.70, 0.94, ripple + cross_wave * 0.13);
    float lip = (1.0 - smoothstep(0.01, 0.13, r)) * (0.5 + 0.5 * sin(a * 19.0 + fx_time * 2.0));
    vec3 water = mix(vec3(0.005, 0.16, 0.65), vec3(0.0, 0.82, 0.96), r);
    water += caustic * vec3(0.06, 0.22, 0.22);
    float shine = pow(max(0.0, sin(flow + 0.3) * cos(a - 1.1)), 16.0);
    ALBEDO = mix(water, vec3(0.84, 1.0, 1.0), clamp(crest * 0.86 + lip + shine, 0.0, 1.0));
    ALPHA = smoothstep(0.0, 0.035, r) * (1.0 - smoothstep(0.88, 1.0, r)) * (0.94 - splash * 0.16);
}

void main(){VERTEX=in_position; UV=in_uv;deform();out_uv=UV; gl_Position=vec4(VERTEX.x/1.9,(VERTEX.y*0.75-VERTEX.z*0.66-0.15)/1.9,-(VERTEX.y*0.66+VERTEX.z*0.75)/10.0,1.0);}