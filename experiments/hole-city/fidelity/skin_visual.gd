extends Node3D
## Shared, original form geometry for the library and the actual player.
## Decorations never add collision, attraction or score.
var skin_id:=""
var main_ring:MeshInstance3D
var mouth:MeshInstance3D
var ornaments:Node3D
var wave:MeshInstance3D
var clock_time:=0.0
var effect_time:=0.0
var orbit_speed:=0.0
var accent:=Color.WHITE
var particle_fx:CPUParticles3D
var motes:Array[MeshInstance3D]=[]
var skin_shader:Shader
const CinderFlame = preload("res://fidelity/cinder_flame.gdshader")

const CRYSTAL_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float facet = floor(UV.x * 8.0 + UV.y * 4.0) / 12.0;
    float glint = pow(max(0.0, sin(UV.x * 12.0 + UV.y * 5.0 - TIME * 1.2)), 12.0);
    ALBEDO = mix(vec3(0.15, 0.5, 0.64), vec3(0.78, 0.96, 1.0), facet + glint * 0.7);
    EMISSION = ALBEDO * 0.25;
}
"""

const ORBIT_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float orbit_glint = pow(0.5 + 0.5 * sin(UV.x * 6.283185 - TIME * 1.4), 6.0);
    ALBEDO = mix(base_color.rgb, vec3(0.68, 0.51, 1.0), 0.3 + orbit_glint * 0.4);
    EMISSION = ALBEDO * 0.32;
}
"""

const SKIN_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float style = 0.0;
uniform float seed = 0.0;

void fragment() {
    float wave = sin(TIME * effect_speed + UV.x * 13.0 + UV.y * 9.0 + seed) * 0.08;
    vec3 color = mix(base_color.rgb, accent_color.rgb, 0.24 + wave);
    if (style > 0.5 && style < 1.5) {
        float flame = sin(TIME * 4.0 + UV.y * 18.0 + UV.x * 5.0 + seed) * 0.18;
        color = mix(base_color.rgb, accent_color.rgb, clamp(0.52 + flame, 0.0, 1.0));
    } else if (style > 1.5 && style < 2.5) {
        float void_rings = sin(length(UV - vec2(0.5)) * 34.0 - TIME * 3.0 + seed);
        color = mix(vec3(0.015, 0.02, 0.055), accent_color.rgb, 0.22 + void_rings * 0.16);
    } else if (style > 2.5 && style < 3.5) {
        color = mix(base_color.rgb, accent_color.rgb, 0.35 + sin(TIME * 2.0 + UV.x * 20.0) * 0.24);
    } else if (style > 3.5) {
        float prism = 0.5 + 0.5 * sin(TIME * 1.6 + UV.x * 8.0 + UV.y * 4.0 + seed);
        color = mix(base_color.rgb, accent_color.rgb, prism);
    }
    ALBEDO = color;
    EMISSION = color * 0.35;
    ROUGHNESS = 0.72;
}
"""

const VOID_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float radius = length(UV - vec2(0.5));
    float rings = sin(radius * 52.0 - TIME * effect_speed * 4.0 + seed);
    vec3 color = mix(vec3(0.018, 0.035, 0.10), vec3(0.46, 0.66, 1.0), 0.48 + rings * 0.25);
    ALBEDO = color;
    EMISSION = color * 0.92;
}
"""

const FLAME_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float tongues = sin(UV.y * 24.0 - TIME * effect_speed * 5.0 + sin(UV.x * 14.0 + seed) * 2.0);
    float heat = clamp(0.55 + tongues * 0.32 + UV.y * 0.18, 0.0, 1.0);
    vec3 color = mix(base_color.rgb, accent_color.rgb, heat);
    ALBEDO = color;
    EMISSION = color * (0.65 + heat * 0.55);
}
"""

const WAVE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float ripple = sin((UV.x + UV.y) * 22.0 - TIME * effect_speed * 3.2 + seed);
    float crest = smoothstep(0.18, 0.86, 0.50 + ripple * 0.5);
    vec3 color = mix(base_color.rgb, accent_color.rgb, crest);
    ALBEDO = color;
    EMISSION = color * 0.58;
}
"""

const PRISM_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float phase = TIME * effect_speed * 1.4 + UV.x * 8.0 + UV.y * 5.0 + seed;
    vec3 rainbow = vec3(0.5 + 0.5 * sin(phase), 0.5 + 0.5 * sin(phase + 2.094), 0.5 + 0.5 * sin(phase + 4.188));
    vec3 color = mix(base_color.rgb, rainbow, 0.72);
    ALBEDO = color;
    EMISSION = color * 0.60;
}
"""

const METAL_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float scan = 0.5 + 0.5 * sin(UV.x * 26.0 - TIME * effect_speed * 2.2 + seed);
    vec3 color = mix(base_color.rgb, accent_color.rgb, smoothstep(0.18, 0.86, scan));
    ALBEDO = color;
    EMISSION = color * 0.42;
}
"""

const GRAVITY_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float radius = 1.0 - length(UV - vec2(0.5)) * 1.7;
    float thrum = sin(TIME * effect_speed * 2.8 + UV.y * 18.0 + seed) * 0.12;
    vec3 color = mix(base_color.rgb, accent_color.rgb, clamp(0.24 + radius * 0.46 + thrum, 0.0, 1.0));
    ALBEDO = color;
    EMISSION = color * 0.52;
}
"""

const LANTERN_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform float effect_speed = 1.0;
uniform float seed = 0.0;
void fragment() {
    float glow = 0.5 + 0.5 * sin(TIME * effect_speed * 3.0 + seed);
    vec3 color = mix(base_color.rgb, accent_color.rgb, 0.38 + glow * 0.48);
    ALBEDO = color;
    EMISSION = color * (0.65 + glow * 0.65);
}
"""

func _shader_code_for_skin() -> String:
	match skin_id:
		"core_shell": return VOID_SHADER_CODE
		"copper_ring": return METAL_SHADER_CODE
		"cinder": return FLAME_SHADER_CODE
		"moss_bloom", "tide": return WAVE_SHADER_CODE
		"gravitas": return GRAVITY_SHADER_CODE
		"lantern": return LANTERN_SHADER_CODE
		"shard": return CRYSTAL_SHADER_CODE
		"orbit": return ORBIT_SHADER_CODE
		"prism_vale": return PRISM_SHADER_CODE
		_: return SKIN_SHADER_CODE

func _style_for_skin() -> float:
	match skin_id:
		"cinder": return 1.0
		"core_shell": return 2.0
		"moss_bloom", "tide": return 3.0
		"prism_vale", "shard", "orbit": return 4.0
		_: return 0.0

func material(tint:Color) -> Material:
	if not is_instance_valid(skin_shader):
		skin_shader=Shader.new()
		skin_shader.code=_shader_code_for_skin()
	var result:=ShaderMaterial.new()
	result.shader=skin_shader
	result.set_shader_parameter("base_color",tint)
	result.set_shader_parameter("accent_color",accent)
	result.set_shader_parameter("effect_speed",1.0+_style_for_skin()*.65)
	result.set_shader_parameter("style",_style_for_skin())
	result.set_shader_parameter("seed",float(abs(skin_id.hash()%97)))
	return result

func flat_material(tint:Color) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=tint
	result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func mesh_part(parent:Node3D,mesh:Mesh,at:Vector3,tint:Color) -> MeshInstance3D:
	var result:=MeshInstance3D.new()
	result.mesh=mesh
	result.material_override=material(tint)
	result.position=at
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result

func band(parent:Node3D,inner:float,outer:float,tint:Color) -> MeshInstance3D:
	var mesh:=TorusMesh.new()
	mesh.inner_radius=inner
	mesh.outer_radius=outer
	mesh.rings=48
	mesh.ring_segments=8
	var result:=mesh_part(parent,mesh,Vector3(0,.085,0),tint)
	result.scale.y=.30
	return result

func block(at:Vector3,size:Vector3,tint:Color,angle:float) -> MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=size
	var result:=mesh_part(ornaments,mesh,at,tint)
	result.rotation.y=angle
	return result

func jewel(at:Vector3,size:float,tint:Color,angle:float) -> MeshInstance3D:
	var mesh:=PrismMesh.new()
	mesh.size=Vector3(size,.32,size*.6)
	var result:=mesh_part(ornaments,mesh,at,tint)
	result.rotation.y=angle
	return result

func add_particles() -> void:
	particle_fx=CPUParticles3D.new()
	particle_fx.amount=18 if skin_id in ["cinder","lantern","prism_vale"] else 12
	particle_fx.lifetime=1.15
	particle_fx.emitting=true
	particle_fx.local_coords=true
	particle_fx.direction=Vector3(0,1,0)
	particle_fx.spread=42.0
	particle_fx.initial_velocity_min=.32 if skin_id=="cinder" else .08
	particle_fx.initial_velocity_max=.70 if skin_id=="cinder" else .22
	particle_fx.gravity=Vector3(0,.05,0)
	particle_fx.scale_amount_min=.035
	particle_fx.scale_amount_max=.08
	particle_fx.emission_shape=CPUParticles3D.EMISSION_SHAPE_RING
	particle_fx.emission_ring_axis=Vector3.UP
	particle_fx.emission_ring_radius=1.12
	particle_fx.emission_ring_inner_radius=1.02
	particle_fx.emission_ring_height=.03
	particle_fx.position.y=.15
	particle_fx.preprocess=.8
	particle_fx.fixed_fps=30
	var particle_mesh:=SphereMesh.new()
	particle_mesh.radius=.5
	particle_mesh.height=1.0
	particle_mesh.radial_segments=6
	particle_mesh.rings=3
	particle_fx.mesh=particle_mesh
	particle_fx.color=accent if skin_id!="cinder" else Color("ff8b32")
	var particle_material:=flat_material(Color.WHITE)
	particle_material.vertex_color_use_as_albedo=true
	particle_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_fx.material_override=particle_material
	var fade:=Gradient.new()
	fade.set_color(0,Color(1,1,1,1))
	fade.set_color(1,Color(1,1,1,0))
	particle_fx.color_ramp=fade
	add_child(particle_fx)
	var mote_count:=8 if skin_id in ["cinder","core_shell","tide","prism_vale","shard"] else 6
	for index in mote_count:
		var mote_mesh:=SphereMesh.new()
		mote_mesh.radius=.14 if skin_id=="cinder" else .10
		mote_mesh.height=mote_mesh.radius*2.0
		mote_mesh.radial_segments=6
		mote_mesh.rings=3
		var angle:=float(index)*TAU/float(mote_count)
		var color:=accent
		if skin_id=="cinder":color=Color("ff6b35") if index%2==0 else Color("ffd166")
		elif skin_id=="prism_vale":color=Color.from_hsv(float(index)/float(mote_count),.72,1.0)
		var mote:=mesh_part(self,mote_mesh,Vector3(sin(angle)*1.38,.22,cos(angle)*1.38),color)
		# The rim's UV animation should not erase the particles' authored colors.
		mote.material_override=flat_material(Color("b8f4ff") if skin_id=="shard" else color)
		motes.append(mote)

func add_flame_crown() -> void:
	# Two thin annular ribbons preserve the open mouth and change its silhouette.
	# Shared by preview and player; no collision or physical attraction.
	for layer_index in 2:
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var flame_radius:=1.03+float(layer_index)*.13
		var flame_height:=.95 if layer_index==0 else .67
		for segment in 80:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u:float=(float(segment)+corner.x)/80.0
				var angle:=u*TAU
				var width:float=flame_radius+corner.y*.10
				surface.set_uv(Vector2(u,corner.y))
				surface.add_vertex(Vector3(sin(angle)*width,.1+corner.y*flame_height,cos(angle)*width))
		var crown:=MeshInstance3D.new()
		crown.mesh=surface.commit()
		var flame_material:=ShaderMaterial.new()
		flame_material.shader=CinderFlame
		flame_material.set_shader_parameter("phase_shift",float(layer_index)*2.1)
		flame_material.set_shader_parameter("warmth",float(layer_index))
		crown.material_override=flame_material
		crown.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(crown)

func build(definition:Dictionary,with_mouth:=false) -> void:
	for child in get_children():child.free()
	motes.clear()
	skin_shader=null
	skin_id=definition.id
	clock_time=0.0
	effect_time=0.0
	orbit_speed=0.0
	accent=Color(definition.accent)
	var tint:=Color(definition.tint)
	main_ring=band(self,.89,1.13,tint)
	mouth=null
	if with_mouth:
		var disk:=CylinderMesh.new()
		disk.top_radius=.94
		disk.bottom_radius=.94
		disk.height=.035
		disk.radial_segments=48
		mouth=mesh_part(self,disk,Vector3(0,.045,0),tint.darkened(.94))
		# Keep the menu's inspectable core surface as a flat material; the animated
		# shader profile lives on the rim and ornaments around it.
		mouth.material_override=flat_material(tint.darkened(.94))
	ornaments=Node3D.new()
	add_child(ornaments)
	match skin_id:
		"core_shell":
			for index in 4:
				var a:=float(index)*TAU/4.0
				block(Vector3(sin(a)*1.08,.12,cos(a)*1.08),Vector3(.22,.12,.35),accent,a)
		"copper_ring":
			band(self,1.18,1.24,accent)
			for index in 3:
				var a:=float(index)*TAU/3.0
				block(Vector3(sin(a)*1.16,.16,cos(a)*1.16),Vector3(.52,.14,.23),accent,a)
		"moss_bloom":
			for index in 7:
				var a:=float(index)*TAU/7.0
				var leaf:=SphereMesh.new()
				leaf.radius=.24
				leaf.height=.48
				leaf.radial_segments=8
				leaf.rings=4
				var part:=mesh_part(ornaments,leaf,Vector3(sin(a)*1.13,.13,cos(a)*1.13),accent if index%2==0 else tint.lightened(.18))
				part.scale=Vector3(.65,.40,1.5)
				part.rotation.y=a
		"gravitas":
			for index in 6:
				var a:=float(index)*TAU/6.0
				block(Vector3(sin(a)*1.12,.20,cos(a)*1.12),Vector3(.46,.30,.38),tint.lightened(.25),a)
				block(Vector3(sin(a)*1.12,.36,cos(a)*1.12),Vector3(.30,.025,.09),accent,a)
		"lantern":
			for index in 4:
				var a:=float(index)*TAU/4.0
				var at:=Vector3(sin(a)*1.16,.25,cos(a)*1.16)
				block(at,Vector3(.16,.40,.16),accent,a)
				jewel(at+Vector3.UP*.23,.28,Color("ffc34a"),a)
		"shard":
			for index in 9:
				var a:=float(index)*TAU/9.0
				var part:=jewel(Vector3(sin(a)*1.14,.18,cos(a)*1.14),.40,accent if index%3==0 else tint.lightened(.20),a)
				part.rotation.z=.28 if index%2==0 else -.28
		"cinder":
			add_flame_crown()
		"tide":
			band(ornaments,1.17,1.22,accent)
			band(ornaments,1.32,1.35,Color("65cfff"))
			orbit_speed=.3
			for index in 3:
				var a:=float(index)*TAU/3.0
				block(Vector3(sin(a)*1.28,.13,cos(a)*1.28),Vector3(.33,.09,.10),Color("e3ffff"),a)
		"orbit":
			orbit_speed=.55
			var satellite_band:=band(ornaments,1.25,1.29,accent)
			satellite_band.rotation.x=.20
			satellite_band.position.y=.28
			for index in 3:
				var a:=float(index)*TAU/3.0
				var sphere:=SphereMesh.new()
				sphere.radius=.17
				sphere.height=.34
				sphere.radial_segments=10
				sphere.rings=5
				mesh_part(ornaments,sphere,Vector3(sin(a)*1.27,.27,cos(a)*1.27),accent)
		"prism_vale":
			orbit_speed=.22
			for index in 12:
				var a:=float(index)*TAU/12.0
				jewel(Vector3(sin(a)*1.10,.13,cos(a)*1.10),.32,Color.from_hsv(float(index)/12.0,.62,1.0),a)
	add_particles()
	wave=band(self,1.10,1.16,accent)
	wave.material_override=flat_material(accent)
	wave.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.visible=false
	set_meta("visual_id",skin_id)

func flash() -> void:
	effect_time=.70

func _process(delta:float) -> void:
	if not is_instance_valid(ornaments):return
	clock_time+=delta
	ornaments.rotation.y+=delta*orbit_speed
	if skin_id=="moss_bloom":ornaments.scale=Vector3.ONE*(1.0+sin(clock_time*2.0)*.025)
	for index in motes.size():
		var mote:=motes[index]
		if not is_instance_valid(mote):continue
		var angle:=float(index)*TAU/float(motes.size())+clock_time*(.75+orbit_speed*2.0)
		var orbit_radius:=1.38
		var height:=.22+sin(clock_time*2.4+index)*.13
		if skin_id=="cinder":
			orbit_radius+=sin(clock_time*3.2+index)*.14
			height=.20+fmod(clock_time*.62+float(index)*.17,1.0)*.56
		elif skin_id=="core_shell":
			orbit_radius=1.30+sin(clock_time*2.0+index)*.18
			height=.16+sin(clock_time*2.8+index)*.10
		elif skin_id=="tide":
			orbit_radius=1.28+sin(clock_time*2.2+index)*.22
			angle+=sin(clock_time*2.0+index)*.12
		mote.position=Vector3(sin(angle)*orbit_radius,height,cos(angle)*orbit_radius)
		mote.scale=Vector3.ONE*(.75+.25*sin(clock_time*3.0+index))
		if skin_id=="cinder":mote.scale*=.40
	if effect_time>0.0:
		effect_time=maxf(0.0,effect_time-delta)
		var progress:=1.0-effect_time/.70
		wave.visible=true
		wave.scale=Vector3(1.0+progress*2.1,.30,1.0+progress*2.1)
		wave.material_override.albedo_color=Color(accent,1.0-progress)
	else:wave.visible=false
