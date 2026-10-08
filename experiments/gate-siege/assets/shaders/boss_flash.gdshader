shader_type spatial; uniform float flash=0.0; void fragment(){ ALBEDO=mix(COLOR.rgb,vec3(1.0),flash); ROUGHNESS=0.72; EMISSION=vec3(flash*0.2); }
