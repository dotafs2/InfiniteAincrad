extends Node3D
## Authored silhouettes shared by the collection and player. Effects never own physics.
const Palette=preload("res://fidelity/skin_palette.gd")
const Collection=preload("res://fidelity/collection_skin.gd")
const CollectionGeometry=preload("res://fidelity/collection_geometry.gd")
const SIMPLE_MODELS=["sunny_side","sugar_glaze","berry_crown","pretzel_twist","waffle_stack","frog_pond","turtle_shell","clockwork_key"]
const Common=preload("res://fidelity/common_skin.gd")
const Rainfall=preload("res://fidelity/rainfall_skin.gd")
const Tempest=preload("res://fidelity/tempest_skin.gd")
const Motifs=preload("res://fidelity/skin_motifs.gd")
const Sculpt=preload("res://fidelity/skin_sculpt.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Water=preload("res://fidelity/shaders/tide.gdshader")
const Accretion=preload("res://fidelity/shaders/accretion.gdshader")
const Solid=preload("res://fidelity/shaders/solid_skin.gdshader")
const Aurora=preload("res://fidelity/shaders/aurora.gdshader")
const CinderFlame=preload("res://fidelity/cinder_flame.gdshader")
var tempest:Node3D
var rainfall:Node3D
var common:Node3D
var collection:Node3D
var skin_id:=""
var model_id:=""
var variant_index:=0
var definition_data:Dictionary={}
var main_ring:MeshInstance3D
var mouth:MeshInstance3D
var ornaments:Node3D
var wave:MeshInstance3D
var clock_time:=0.0
var effect_time:=0.0
var accent:=Color.WHITE
var skin_shader:Shader
var materials:Array[ShaderMaterial]=[]
var motes:Array[MeshInstance3D]=[]
var parts:Array[MeshInstance3D]=[]
var tint:=Color.WHITE
var fx_family:=""
var rarity_id:=""
var visual_profile:=""

func shader_material(shader:Shader) -> ShaderMaterial:
	var result:=ShaderMaterial.new()
	result.shader=shader
	materials.append(result)
	return result

func flat_material(color:Color) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func mesh_part(parent:Node3D,mesh:Mesh,at:Vector3,mat:Material) -> MeshInstance3D:
	var result:=MeshInstance3D.new()
	result.mesh=mesh;result.material_override=mat;result.position=at
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Vertex-deformed wave crests remain inside this small fixed render bound.
	result.extra_cull_margin=.2
	parent.add_child(result)
	return result

func band(parent:Node3D,inner:float,outer:float,mat:Material,segments:=64) -> MeshInstance3D:
	var mesh:=TorusMesh.new()
	mesh.inner_radius=inner;mesh.outer_radius=outer
	mesh.rings=segments;mesh.ring_segments=6
	var result:=mesh_part(parent,mesh,Vector3(0,.07,0),mat)
	result.scale.y=.3
	return result

func block(at:Vector3,size:Vector3,mat:Material,angle:float) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size
	var result:=mesh_part(ornaments,mesh,at,mat)
	result.rotation.y=angle
	parts.append(result)
	return result

func jewel(at:Vector3,size:Vector3,mat:Material,angle:float) -> MeshInstance3D:
	var mesh:=PrismMesh.new();mesh.size=size
	var result:=mesh_part(ornaments,mesh,at,mat)
	result.rotation.y=angle
	parts.append(result)
	return result

func ribbon(inner:float,outer:float,height:float,mat:Material,vertical:=false,start:=0.0,length:=TAU,warp:=0.0) -> MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:=72 if length==TAU else 24
	var rows:=5 if not vertical else 1
	for segment in segments:
		for row in rows:
			for corner in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
				var u:float=(float(segment)+corner.x)/float(segments)
				var v:float=(float(row)+corner.y)/float(rows)
				var angle:=start+u*length
				var radius:=lerpf(inner,outer,v)
				var y:=.075+v*height if vertical else height
				y+=maxf(0.0,sin(angle))*warp
				surface.set_uv(Vector2(u,v));surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(sin(angle)*radius,y,cos(angle)*radius))
	var result:=mesh_part(self,surface.commit(),Vector3.ZERO,mat)
	result.set_meta("opening_radius",inner)
	return result

func leaf_mesh() -> ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices:=[Vector3(0,0,-.34),Vector3(-.16,.07,0),Vector3(0,.14,.05),Vector3(.16,.07,0),Vector3(0,0,.42)]
	for index in [0,1,2,0,2,3,1,4,2,2,4,3]:
		var vertex:Vector3=vertices[index]
		surface.set_uv(Vector2(vertex.x/.32+.5,(vertex.z+.34)/.76));surface.set_normal(Vector3.UP);surface.add_vertex(vertex)
	return surface.commit()

func add_sparks(count:int,color:Color) -> void:
	# Two skins use rising flat sparks. No common orbit emitter or sphere mesh.
	var mat:=flat_material(color)
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in count:
		var mesh:=QuadMesh.new();mesh.size=Vector2(.035,.12) if model_id=="cinder" else Vector2(.065,.065)
		var mote:=mesh_part(self,mesh,Vector3.ZERO,mat)
		motes.append(mote)

func build(definition:Dictionary,with_mouth:=false) -> void:
	for child in get_children():child.free()
	materials.clear();motes.clear();parts.clear();tempest=null;rainfall=null;common=null;collection=null
	if has_meta("polish_revision"):remove_meta("polish_revision")
	definition_data=definition.duplicate(true)
	skin_id=definition.id;model_id=str(definition.get("model_id",skin_id));variant_index=int(definition.get("variant_index",0))
	tint=Color(definition.tint);accent=Color(definition.accent)
	rarity_id=Rarity.for_skin(skin_id)
	visual_profile=str(Rarity.data(rarity_id).get("profile","unknown"))
	clock_time=0.0;effect_time=0.0;mouth=null;wave=null
	ornaments=Node3D.new();add_child(ornaments)
	var solid:=shader_material(Solid)
	var style:int={"copper_ring":1,"moss_bloom":2,"gravitas":3,"lantern":4,"shard":5,"cinder":6,"prism_vale":7,"rainbow_bridge":7}.get(model_id,1 if model_id in SIMPLE_MODELS else 5 if rarity_id=="epic" else 0)
	solid.set_shader_parameter("base_color",tint);solid.set_shader_parameter("accent_color",accent);solid.set_shader_parameter("style",style)
	main_ring=band(self,.96,1.09,solid,32 if model_id in Common.IDS or model_id in SIMPLE_MODELS else 64)
	if with_mouth:
		var disk:=CylinderMesh.new();disk.top_radius=.98;disk.bottom_radius=.98;disk.height=.02;disk.radial_segments=64
		if model_id in Common.IDS:disk.top_radius=1.005;disk.bottom_radius=1.005;disk.radial_segments=32;disk.rings=1
		elif model_id in CollectionGeometry.IDS:disk.top_radius=1.014;disk.bottom_radius=1.014;disk.radial_segments=32;disk.rings=1
		mouth=mesh_part(self,disk,Vector3(0,.025,0),flat_material(tint.darkened(.97)))
	if model_id in Common.IDS:
		# Existing authored objects keep their geometry/controller after regrading.
		fx_family=model_id
		common=Common.new();add_child(common);common.build(self)
	elif model_id in SIMPLE_MODELS:
		fx_family="simple_trim"
		band(self,1.11,1.15,flat_material(accent),32)
	elif model_id in CollectionGeometry.IDS:
		fx_family=model_id
		collection=Collection.new();add_child(collection);collection.build(self,true)
	elif model_id in Sculpt.IDS:
		fx_family=model_id
		Sculpt.build(self)
	else:
		match model_id:
			"rainfall":
				fx_family="rainfall"
				rainfall=Rainfall.new();add_child(rainfall);rainfall.build(self)
			"tempest":
				fx_family="tornado"
				tempest=Tempest.new();add_child(tempest);tempest.build(self)
			"core_shell","orbit":
				fx_family="accretion" if model_id=="core_shell" else "lensed_vortex"
				var disk_mat:=shader_material(Accretion)
				disk_mat.set_shader_parameter("spectral",0.0 if model_id=="core_shell" else 1.0)
				disk_mat.set_shader_parameter("core_blue",1.0 if model_id=="core_shell" else 0.0)
				main_ring.free()
				main_ring=ribbon(1.0,1.62,.085,disk_mat)
				var lens_mat:=shader_material(Accretion)
				lens_mat.set_shader_parameter("spectral",0.0 if model_id=="core_shell" else 1.0)
				lens_mat.set_shader_parameter("core_blue",1.0 if model_id=="core_shell" else 0.0)
				lens_mat.set_shader_parameter("lensed",1.0)
				ribbon(1.015,1.22,.11,lens_mat,false,0.0,TAU,.20 if model_id=="core_shell" else .75)
				band(self,.99,1.015,flat_material(Color("bfeaff") if model_id=="core_shell" else Color("9aedff")))
			"tide":
				fx_family="water"
				var water_mat:=shader_material(Water)
				main_ring.free();main_ring=ribbon(.99,1.50,.10,water_mat)
				var splash_mat:=shader_material(Water);splash_mat.set_shader_parameter("splash",1.0)
				for i in 3:ribbon(1.10,1.22,.28,splash_mat,true,float(i)*TAU/3.0,.62)
			"cinder":
				fx_family="flame"
				for i in 2:
					var flame:=shader_material(CinderFlame);flame.set_shader_parameter("phase_shift",float(i)*2.1);flame.set_shader_parameter("warmth",float(i))
					ribbon(1.03+i*.10,1.10+i*.10,.88-i*.22,flame,true)
				add_sparks(10,Color("ffd35a"))
			"moss_bloom":
				fx_family="leaves"
				var leaf:=leaf_mesh()
				for i in 8:
					var a:=float(i)*TAU/8.0
					var part:=mesh_part(ornaments,leaf,Vector3(sin(a)*1.17,.12,cos(a)*1.17),solid)
					part.rotation.y=a;parts.append(part)
				for i in 4:
					var a:=float(i)*TAU/4.0+.3
					jewel(Vector3(sin(a)*1.10,.20,cos(a)*1.10),Vector3(.17,.20,.17),flat_material(Color("ff79be")),a)
			"copper_ring":
				fx_family="mechanical"
				band(self,1.20,1.24,solid)
				for i in 6:
					var a:=float(i)*TAU/6.0
					block(Vector3(sin(a)*1.12,.12,cos(a)*1.12),Vector3(.36,.16,.18),solid,a)
			"gravitas":
				fx_family="stone"
				for i in 6:
					var a:=float(i)*TAU/6.0
					var part:=block(Vector3(sin(a)*1.16,.19,cos(a)*1.16),Vector3(.39,.32,.28),solid,a)
					part.rotation.z=.12 if i%2==0 else -.12
			"lantern":
				fx_family="lanterns"
				for i in 4:
					var a:=float(i)*TAU/4.0
					var at:=Vector3(sin(a)*1.15,.3,cos(a)*1.15)
					block(at,Vector3(.20,.38,.20),solid,a)
					jewel(at+Vector3.UP*.24,Vector3(.28,.14,.28),flat_material(Color("ff742c")),a)
				add_sparks(5,Color("ffe891"))
			"shard":
				fx_family="crystals"
				for i in 9:
					var a:=float(i)*TAU/9.0
					var part:=jewel(Vector3(sin(a)*1.15,.19,cos(a)*1.15),Vector3(.24,.40+float(i%3)*.13,.22),solid,a)
					part.rotation.z=.25 if i%2==0 else -.25
			"prism_vale":
				fx_family="aurora"
				var aurora:=shader_material(Aurora)
				for i in 2:ribbon(1.07+i*.14,1.09+i*.14,.55-i*.16,aurora,true)
				for i in 6:
					var a:=float(i)*TAU/6.0
					jewel(Vector3(sin(a)*1.10,.14,cos(a)*1.10),Vector3(.2,.26,.18),flat_material(Color.from_hsv(float(i)/6.0,.8,1.0)),a)
			_:
				fx_family=model_id
				Motifs.build(self)
	light_authored_ornaments()
	Palette.apply(self,definition)
	if common==null and tempest==null and rainfall==null and collection==null:
		collection=Collection.new();add_child(collection);collection.build(self,false)
	# Authored models can carry lit materials on their batched mesh surfaces.
	var main_material:Material=main_ring.material_override
	if main_material==null and main_ring.mesh.get_surface_count()>0:main_material=main_ring.mesh.surface_get_material(0)
	skin_shader=main_material.shader if main_material is ShaderMaterial else null
	wave=band(self,1.05,1.11,flat_material(accent),16 if model_id in Common.IDS or model_id in CollectionGeometry.IDS else 64)
	wave.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.visible=false
	set_meta("visual_id",skin_id)
	set_meta("model_id",model_id)
	set_meta("variant_index",variant_index)
	set_meta("rarity",rarity_id)
	set_meta("visual_profile",visual_profile)
	_process(0.0)

func light_authored_ornaments()->void:
	if model_id not in ["royal_gate","carnival_tent","satellite_dish"]:return
	# Only these original ornaments need directional/specular form cues. Share
	# one copied material per source within this instance; never mutate a base.
	var lit_copies:Dictionary={}
	for part in ornaments.find_children("*","MeshInstance3D",true,false):
		var source:Material=part.material_override
		if not source is StandardMaterial3D:continue
		var key:int=source.get_instance_id()
		if not lit_copies.has(key):
			var material:StandardMaterial3D=source.duplicate()
			material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.roughness=.35;material.metallic_specular=.55
			material.clearcoat_enabled=true;material.clearcoat=.14;material.clearcoat_roughness=.30
			lit_copies[key]=material
		part.material_override=lit_copies[key]

func frame_preview(camera:Camera3D,card:=true) -> void:
	if model_id in Common.IDS:
		camera.size=3.8 if card else 4.0
		camera.look_at(Vector3(0,.20,0))
		return
	if model_id in CollectionGeometry.IDS:
		camera.size=3.9 if card else 4.1
		camera.look_at(Vector3(0,.26,0))
		return
	camera.size=(3.7 if card else 4.0) if model_id=="rainfall" else (3.35 if card else 3.9) if model_id=="tempest" else (3.1 if card else 2.65)
	camera.look_at(Vector3(0,.80 if model_id=="rainfall" else .46 if model_id=="tempest" else .14 if card else .16,0))

func begin_intake() -> void:
	if is_instance_valid(rainfall):rainfall.begin_intake()
	if is_instance_valid(tempest):tempest.object_energy=maxf(tempest.object_energy,.65)

func absorb_object(body:Node3D=null) -> void:
	if is_instance_valid(collection):collection.absorb(false)
	if is_instance_valid(common):common.absorb(false)
	if is_instance_valid(rainfall):
		rainfall.absorb(false)
		if is_instance_valid(body):rainfall.confirmed_object(body)
	if is_instance_valid(tempest):tempest.absorb(false)

func absorb_rival(source_color:Color) -> bool:
	if is_instance_valid(collection):
		collection.absorb(true,source_color);return true
	if is_instance_valid(common):
		common.absorb(true,source_color);return true
	if is_instance_valid(rainfall):
		rainfall.absorb(true,source_color);return true
	if not is_instance_valid(tempest):return false
	tempest.absorb(true,source_color)
	return true

func flash() -> void:effect_time=.70

func _process(delta:float) -> void:
	if not is_instance_valid(ornaments):return
	clock_time+=delta
	if is_instance_valid(common):common.advance(delta)
	if is_instance_valid(collection):collection.advance(delta)
	if is_instance_valid(tempest):tempest.advance(delta)
	if is_instance_valid(rainfall):rainfall.advance(delta)
	for mat in materials:mat.set_shader_parameter("fx_time",clock_time)
	if model_id=="moss_bloom":
		for i in mini(8,parts.size()):parts[i].rotation.x=sin(clock_time*1.7+i*.7)*.10
	elif model_id=="gravitas":
		for i in parts.size():parts[i].position.y=.19+sin(clock_time*1.2+i)*.025
	elif model_id=="jelly_veil":
		for i in parts.size():parts[i].rotation.z=sin(clock_time*2.0+i)*.12
	for i in motes.size():
		var progress:=fmod(clock_time*(.62 if model_id=="cinder" else .24)+float(i)*.173,1.0)
		var angle:=float(i)*2.39996
		var radius:=1.09+progress*.14
		motes[i].position=Vector3(sin(angle)*radius+sin(progress*5.0+i)*.045,.15+progress*.83,cos(angle)*radius)
		motes[i].scale=Vector3.ONE*sin(progress*PI)
	if effect_time>0.0:
		effect_time=maxf(0.0,effect_time-delta)
		var progress:=1.0-effect_time/.70
		wave.visible=effect_time>0.0;wave.scale=Vector3(1.0+progress*2.1,.30,1.0+progress*2.1)
		wave.material_override.albedo_color=Color(accent,1.0-progress)
	else:wave.visible=false
