"""Translate the shipped food surface functions for a windowless GLSL probe.

The ingredient/reflection functions are verbatim. Final scene lighting is an
approximation, not a reproduction of Godot's renderer.
"""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def function(source, signature):
    start = source.index(signature)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def ingredient_frames(output):
    frame = json.loads((output / 'opening.json').read_text())
    meshes = json.loads((output / 'render-meshes.json').read_text())
    def norm(v):
        length = math.sqrt(sum(x*x for x in v))
        return [x / length for x in v]
    def cross(a, b):
        return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
    def dot(a, b):
        return sum(x*y for x, y in zip(a, b))
    eye = [7, 12, 14]
    z = norm(eye); x = norm(cross([0, 1, 0], z)); y = cross(z, x)
    frame['width'], frame['height'] = 1080, 720
    frame['view'] = [x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-dot(x,eye),-dot(y,eye),-dot(z,eye),1]
    frame['projection'][0] = frame['projection'][5] / 1.5
    frame['instances'] = []
    for i, key in enumerate(['cake_0', 'donut_1', 'egg', 'burger', 'cookie_2', 'sushi']):
        bottom = min(meshes[key]['vertices'][1::3])
        frame['instances'].append({'key': key, 'matrix': [1.5,0,0,0,0,1.5,0,0,0,0,1.5,0,(i%3-1)*4.5,-bottom*1.5+.025,(i//3-.5)*4.7,1]})
    frame['ground'] = {'vertices': [-20,0,-20,20,0,-20,-20,0,20,20,0,-20,20,0,20,-20,0,20],
                       'normals': [0,1,0]*6, 'colors': [1,1,1,1]*6, 'indices': list(range(6))}
    frame['openings'] = []
    (output / 'ingredients.json').write_text(json.dumps(frame))
    frame['glaze_strength'] = 0
    (output / 'ingredients-no-glaze.json').write_text(json.dumps(frame))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source = (ROOT / 'fidelity/food_glaze.gdshader').read_text()
    vertex = '''#version 150
in vec3 position; in vec3 normal; in vec4 color;
uniform mat4 model, view, projection;
out vec3 food_world_normal; out vec3 food_world_position; out vec4 COLOR;
#define VERTEX position
#define NORMAL normal
#define MODEL_MATRIX model
#define MODEL_NORMAL_MATRIX transpose(inverse(mat3(model)))
'''
    vertex += function(source, 'void vertex()')
    vertex += '\nvoid main(){vertex(); COLOR=color; gl_Position=projection*view*model*vec4(position,1.);}'
    fragment = '''#version 150
in vec3 food_world_normal; in vec3 food_world_position; in vec4 COLOR;
uniform mat4 view; uniform float glaze_strength = 0.72;
vec3 ALBEDO, EMISSION; float ROUGHNESS, SPECULAR;
#define CAMERA_POSITION_WORLD inverse(view)[3].xyz
out vec4 output_color;
'''
    fragment += function(source, 'vec3 food_reflection(') + '\n'
    fragment += function(source, 'void fragment()') + '\n'
    fragment += '''void main(){fragment();
vec3 n=normalize(food_world_normal);
float light=0.48+0.95*max(0.,dot(n,normalize(vec3(-.379,.788,.485))));
vec3 linear=ALBEDO*light+EMISSION;
output_color=vec4(pow(max(linear,vec3(0.)),vec3(1./2.2)),1.);
}'''
    (args.output / 'food-finish.vert').write_text(vertex)
    (args.output / 'food-finish.frag').write_text(fragment)
    # This showcase preserves current scene frames without synthetic ingredient arrangements.
    print('Prepared exact shipped food surface/reflection functions with approximate scene lighting.')


if __name__ == '__main__':
    main()
