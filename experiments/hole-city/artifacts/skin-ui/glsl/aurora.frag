#version 150
vec3 VERTEX; vec3 ALBEDO; vec3 EMISSION; float ALPHA=1.0; vec2 UV;
in vec2 out_uv; out vec4 out_color;
uniform float fx_time = 0.0;
void deform() {
    VERTEX.y += sin(UV.x * 25.13274 + fx_time * 1.3) * UV.y * 0.14;
}
void shade() {
    vec3 rainbow = 0.55 + 0.45 * cos(UV.x * 6.283185 - fx_time * 0.6 + vec3(0.0, 2.1, 4.2));
    float pleat = 0.6 + 0.4 * sin(UV.x * 100.0 + sin(UV.x * 13.0 + fx_time));
    ALBEDO = rainbow;
    ALPHA = sin(UV.y * 3.141593) * pleat * 0.65;
}

void main(){UV=out_uv; shade(); out_color=vec4(ALBEDO,ALPHA);}