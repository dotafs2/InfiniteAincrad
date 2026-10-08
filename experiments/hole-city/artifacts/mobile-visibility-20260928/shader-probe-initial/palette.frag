#version 150
uniform bool probe_bool_shadow = false;
#define IN_SHADOW_PASS probe_bool_shadow
#define FRAGCOORD gl_FragCoord
const bool OUTPUT_IS_SRGB = true;
uniform float TIME = 0.0;
uniform vec3 VERTEX = vec3(0.0);
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


uniform float visibility = 1.0;
uniform vec4 building_tint= vec4(1.0);
uniform float tint_amount = 0.0;
void shipped_fragment(){
	ALBEDO=mix(COLOR.rgb, COLOR.rgb*building_tint.rgb, tint_amount);
	ROUGHNESS=0.82;
	ALPHA=visibility;
}

void main(){shipped_fragment();probe_color=vec4(1.0);}
