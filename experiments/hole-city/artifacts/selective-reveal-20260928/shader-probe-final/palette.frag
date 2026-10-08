#version 150
uniform bool probe_bool_shadow = false;
#define IN_SHADOW_PASS probe_bool_shadow
#define FRAGCOORD gl_FragCoord
const bool OUTPUT_IS_SRGB = true;
uniform float TIME = 0.0;
uniform vec3 VERTEX = vec3(0.0);
uniform vec4 INSTANCE_CUSTOM = vec4(0.0);
uniform vec4 COLOR = vec4(0.8, 0.4, 0.2, 1.0);
uniform vec3 NORMAL = vec3(0.0, 1.0, 0.0);
uniform vec3 VIEW = vec3(0.0, 1.0, 0.0);
uniform vec2 UV = vec2(0.3);
uniform vec2 UV2 = vec2(0.3);
uniform vec2 SCREEN_UV = vec2(0.5);
uniform vec2 VIEWPORT_SIZE = vec2(64.0);
uniform vec3 CAMERA_POSITION_WORLD = vec3(0.0, 18.0, 14.0);
uniform vec3 CAMERA_DIRECTION_WORLD = vec3(0.0, -1.0, 0.0);
uniform mat4 MODEL_MATRIX = mat4(1.0);
uniform mat3 MODEL_NORMAL_MATRIX = mat3(1.0);
uniform mat4 VIEW_MATRIX = mat4(1.0);
uniform mat4 INV_VIEW_MATRIX = mat4(1.0);
uniform mat4 MAIN_CAM_INV_VIEW_MATRIX = mat4(1.0);
uniform mat4 PROJECTION_MATRIX = mat4(1.0);
uniform mat4 INV_PROJECTION_MATRIX = mat4(1.0);
vec3 ALBEDO = vec3(1.0);
vec3 EMISSION = vec3(0.0);
float ROUGHNESS = 1.0;
float METALLIC = 0.0;
float SPECULAR = 0.5;
float ALPHA = 1.0;
out vec4 probe_color;


// Shared by actual opaque city, actor, food and fracture materials.
// A per-fragment camera ray is projected onto the hole plane: wide/tall meshes
// and MultiMesh instances cannot evade the aperture through a distant center.
uniform vec4 hole_reveal_target;
uniform vec4 hole_reveal_camera;
uniform vec4 hole_reveal_aperture;
uniform vec4 hole_reveal_back;

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
    // Stable 4 x 4 Bayer threshold: no time-uniform noise or transparent sorting.
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

uniform vec3 reveal_world_position;
uniform float visibility = 1.0;
uniform float reveal_occluder = 0.0;
uniform vec4 building_tint= vec4(1.0);
uniform float tint_amount = 0.0;

void shipped_fragment(){
	if(reveal_occluder > 0.0 && reveal_occluder * hole_reveal_mask(reveal_world_position,INV_VIEW_MATRIX[3].xyz,INV_VIEW_MATRIX[2].xyz,IN_SHADOW_PASS)>hole_reveal_threshold(FRAGCOORD.xy)){discard;}
	ALBEDO=mix(COLOR.rgb, COLOR.rgb*building_tint.rgb, tint_amount);
	ROUGHNESS=0.82;
}

void main(){shipped_fragment();probe_color=vec4(1.0);}
