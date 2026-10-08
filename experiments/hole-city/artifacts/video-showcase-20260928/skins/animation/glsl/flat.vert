#version 150
in vec3 in_position; in vec2 in_uv; void main(){vec3 p=in_position; gl_Position=vec4(p.x/1.9,(p.y*.75-p.z*.66-.15)/1.9,-(p.y*.66+p.z*.75)/10.,1.);}