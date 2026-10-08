#version 150
in vec3 position; in vec3 normal; in vec4 color;
uniform mat4 model, view, projection;
out vec3 food_world_normal; out vec3 food_world_position; out vec4 COLOR;
#define VERTEX position
#define NORMAL normal
#define MODEL_MATRIX model
#define MODEL_NORMAL_MATRIX transpose(inverse(mat3(model)))
void vertex() {
    food_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    food_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void main(){vertex(); COLOR=color; gl_Position=projection*view*model*vec4(position,1.);}