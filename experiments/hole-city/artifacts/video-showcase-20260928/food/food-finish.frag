#version 150
in vec3 food_world_normal; in vec3 food_world_position; in vec4 COLOR;
uniform mat4 view; uniform float glaze_strength = 0.72;
vec3 ALBEDO, EMISSION; float ROUGHNESS, SPECULAR;
#define CAMERA_POSITION_WORLD inverse(view)[3].xyz
out vec4 output_color;
vec3 food_reflection(vec3 n, vec3 view_direction, float roughness) {
    vec3 r = reflect(-view_direction, n);
    float gloss = 1.0 - smoothstep(0.20, 0.62, roughness);
    float broad = pow(max(dot(r, normalize(vec3(-0.45, 0.86, 0.38))), 0.0), mix(9.0, 24.0, gloss));
    float strip = pow(max(dot(r, normalize(vec3(0.65, 0.65, -0.38))), 0.0), 32.0);
    float edge = pow(1.0 - max(dot(n, view_direction), 0.0), 4.0);
    return vec3(1.0, 0.97, 0.89) * broad * mix(0.045, 0.82, gloss)
        + vec3(0.80, 0.91, 1.0) * (strip * 0.20 + edge * 0.045) * gloss;
}
void fragment() {
    // Match StandardMaterial's sRGB vertex-albedo decoding.
    ALBEDO = mix(pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
    ROUGHNESS = clamp(COLOR.a, 0.18, 0.70);
    SPECULAR = 0.5;
    vec3 n = normalize(food_world_normal);
    vec3 v = normalize(CAMERA_POSITION_WORLD - food_world_position);
    EMISSION = food_reflection(n, v, ROUGHNESS) * glaze_strength;
}
void main(){fragment();
vec3 n=normalize(food_world_normal);
float light=0.48+0.95*max(0.,dot(n,normalize(vec3(-.379,.788,.485))));
vec3 linear=ALBEDO*light+EMISSION;
output_color=vec4(pow(max(linear,vec3(0.)),vec3(1./2.2)),1.);
}