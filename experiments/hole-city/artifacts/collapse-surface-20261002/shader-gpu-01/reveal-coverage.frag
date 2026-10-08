#version 150
uniform vec3 probe_world;
uniform vec3 probe_camera;
uniform vec3 probe_back;
uniform bool probe_bool_shadow;
out vec4 probe_color;
// Opted-in building materials use the uniform body mask below. CPU ray tests
// choose the whole building, so every surface shares the same pixel coverage.
// The legacy projected mask remains available for compatibility diagnostics.
uniform vec4 hole_reveal_target;
uniform vec4 hole_reveal_camera;
uniform vec4 hole_reveal_aperture;
uniform vec4 hole_reveal_back;

float hole_reveal_body_mask(vec3 view_camera, vec3 view_back, bool shadow_pass) {
    if (shadow_pass || hole_reveal_target.w <= 0.0001) { return 0.0; }
    // Shader globals also reach UI SubViewports. Only the gameplay camera may
    // fade buildings; shadows retain full casters and physics is unchanged.
    if (distance(view_camera, hole_reveal_camera.xyz) > 0.025 ||
            dot(normalize(view_back), hole_reveal_back.xyz) < 0.9999) { return 0.0; }
    // Independent of surface position and depth: discarding the facade pixel
    // also discards that building's roof/back pixel, never exposing cutaways.
    return hole_reveal_target.w * 0.94;
}

float hole_reveal_mask(vec3 world_position, vec3 view_camera, vec3 view_back, bool shadow_pass) {
    if (shadow_pass || hole_reveal_target.w <= 0.0001) { return 0.0; }
    // Shader globals also reach UI SubViewports. Only the gameplay camera may
    // cut geometry; shadow passes keep complete casters and physics is untouched.
    if (distance(view_camera, hole_reveal_camera.xyz) > 0.025 ||
            dot(normalize(view_back), hole_reveal_back.xyz) < 0.9999) { return 0.0; }
    vec3 target = hole_reveal_target.xyz;
    vec3 camera = hole_reveal_camera.xyz;
    float height = world_position.y - target.y;
    float denominator = camera.y - world_position.y;
    if (height <= 0.02 || denominator <= 0.02) { return 0.0; }
    float ray_scale = (camera.y - target.y) / denominator;
    if (ray_scale <= 1.0) { return 0.0; }
    vec2 projected = camera.xz + (world_position.xz - camera.xz) * ray_scale;
    vec2 segment = hole_reveal_aperture.zw;
    float along = clamp(dot(projected - target.xz, segment) / max(dot(segment, segment), 0.0001), 0.0, 1.0);
    float aperture_distance = length(projected - target.xz - segment * along);
    float edge = 1.0 - smoothstep(hole_reveal_aperture.x - hole_reveal_aperture.y,
            hole_reveal_aperture.x, aperture_distance);
    // Foreground is measured along each projected camera ray, not against a
    // vertical plane through the player. That plane incorrectly rejects roofs
    // directly above the hole and the destination when moving away from camera.
    return edge * smoothstep(0.02, 0.20, height) * hole_reveal_target.w * 0.94;
}

float hole_reveal_threshold(vec2 pixel) {
    // Stable 4 x 4 Bayer threshold: no time-varying noise or transparent sorting.
    ivec2 p = ivec2(mod(floor(pixel), vec2(4.0)));
    int rank = 0;
    if (p.y == 0) { rank = p.x == 0 ? 0 : (p.x == 1 ? 8 : (p.x == 2 ? 2 : 10)); }
    else if (p.y == 1) { rank = p.x == 0 ? 12 : (p.x == 1 ? 4 : (p.x == 2 ? 14 : 6)); }
    else if (p.y == 2) { rank = p.x == 0 ? 3 : (p.x == 1 ? 11 : (p.x == 2 ? 1 : 9)); }
    else { rank = p.x == 0 ? 15 : (p.x == 1 ? 7 : (p.x == 2 ? 13 : 5)); }
    return (float(rank) + 0.5) / 16.0;
}

bool hole_reveal_discard(vec3 world_position, vec2 pixel, vec3 view_camera, vec3 view_back, bool shadow_pass) {
    return hole_reveal_mask(world_position, view_camera, view_back, shadow_pass) > hole_reveal_threshold(pixel);
}

void main(){
    if(hole_reveal_discard(probe_world,gl_FragCoord.xy,probe_camera,probe_back,probe_bool_shadow))discard;
    probe_color=vec4(1.0);
}
