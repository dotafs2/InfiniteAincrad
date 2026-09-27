shader_type spatial;
render_mode cull_back, depth_prepass_alpha;
uniform float visibility = 1.0;
uniform vec4 building_tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
void fragment(){
	ALBEDO=mix(COLOR.rgb, COLOR.rgb*building_tint.rgb, tint_amount);
	ROUGHNESS=0.82;
	ALPHA=visibility;
}
