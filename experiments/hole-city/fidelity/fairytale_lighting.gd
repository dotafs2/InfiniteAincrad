extends RefCounted
## Shared daylight reflections for the original glazed storybook buildings.
static var reflection_sky:Sky

static func sky()->Sky:
	if reflection_sky==null:
		var paint:=ProceduralSkyMaterial.new()
		paint.sky_top_color=Color("389ace")
		paint.sky_horizon_color=Color("e9f4ff")
		paint.ground_bottom_color=Color("335345")
		paint.ground_horizon_color=Color("e5eac9")
		paint.sky_curve=.24
		paint.ground_curve=.3
		reflection_sky=Sky.new()
		reflection_sky.sky_material=paint
	return reflection_sky

static func environment(env:Environment)->void:
	env.sky=sky()
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("dcecff")
	env.ambient_light_energy=.34

static func sun(light:DirectionalLight3D)->void:
	light.light_color=Color("fff1da")
	light.light_energy=.92
	light.shadow_opacity=.72

static func reset_environment(env:Environment)->void:
	env.sky=null
	env.reflected_light_source=Environment.REFLECTION_SOURCE_BG
	env.ambient_light_color=Color.WHITE
