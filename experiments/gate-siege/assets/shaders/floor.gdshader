shader_type spatial;
varying vec3 world_position;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 ALBEDO=vec3(0.50,0.52,0.60);
 float edge=1.0-smoothstep(0.02,0.055,abs(abs(world_position.x)-3.95));
 float dash=step(0.48,fract(world_position.z*0.13));
 ALBEDO=mix(ALBEDO,vec3(0.67,0.78,0.84),edge*dash*0.46);
 ROUGHNESS=0.92;
}
