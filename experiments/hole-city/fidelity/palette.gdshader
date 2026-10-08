shader_type spatial;
render_mode cull_back;
#include "res://fidelity/hole_reveal.gdshaderinc"
uniform float visibility = 1.0;
uniform float reveal_occluder = 0.0;
uniform vec4 building_tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
void vertex(){}
void fragment(){
	if(reveal_occluder > 0.0 && reveal_occluder * hole_reveal_body_mask(INV_VIEW_MATRIX[3].xyz,INV_VIEW_MATRIX[2].xyz,IN_SHADOW_PASS)>hole_reveal_threshold(FRAGCOORD.xy)){discard;}
	ALBEDO=mix(COLOR.rgb, COLOR.rgb*building_tint.rgb, tint_amount);
	ROUGHNESS=0.82;
}
