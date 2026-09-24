shader_type spatial;
render_mode cull_back, depth_prepass_alpha;
uniform float visibility = 1.0;
void fragment(){
	ALBEDO=COLOR.rgb;
	ROUGHNESS=0.82;
	ALPHA=visibility;
}
