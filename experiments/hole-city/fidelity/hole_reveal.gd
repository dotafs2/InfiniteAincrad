extends RefCounted
## Only explicitly authored, intact buildings may reveal while blocking the
## mouth. Food towers and their independently edible layers always stay opaque.
const StandardShader=preload("res://fidelity/hole_reveal_standard.gdshader")
const INCLUDED_SHADERS:=["res://fidelity/palette.gdshader","res://fidelity/food_glaze.gdshader"]
var material_cache:Dictionary={}
var shader_cache:Dictionary={}
var unsupported:Array[String]=[]
var bound_meshes:=0
var bound_batches:=0
var preserved_shaders:=0
var adapted_materials:=0
var skipped_cosmetics:=0
var update_count:=0
var target:=Vector4.ZERO
var camera_data:=Vector4.ZERO
var aperture:=Vector4(1.85,.65,0,0)
var camera_back:=Vector4(0,0,1,0)
var lookahead:=Vector2.ZERO
var strength:=0.0
var radius:=1.85
var occluders:Array[Dictionary]=[]
var entries:Dictionary={}
var active_occluders:=0
var selection_bounds_tests:=0
var geometry_cache:Dictionary={}
var core_witness:=Vector2.ZERO
var mesh_ray_tests:=0
# World-unit thresholds for each building itself, never its group or stack.
# Size is an additional gate; a large tree, vehicle or snack cannot opt in.
var dither_min_height:=3.0
var dither_min_width:=2.4

func reset(clear_materials:=false)->void:
	for entry in occluders:write_weight(entry,0.0)
	active_occluders=0;selection_bounds_tests=0;mesh_ray_tests=0
	strength=0.0;lookahead=Vector2.ZERO;target.w=0.0;radius=1.85
	aperture.z=0.0;aperture.w=0.0
	if clear_materials:
		occluders.clear();entries.clear();geometry_cache.clear()
		material_cache.clear();unsupported.clear();bound_meshes=0;bound_batches=0
		preserved_shaders=0;adapted_materials=0;skipped_cosmetics=0;update_count=0
	publish()

func tick(camera:Camera3D,player:Node3D,delta:float,enabled:bool)->void:
	if not enabled or not is_instance_valid(camera) or not is_instance_valid(player):reset();return
	var blend:=1.0-exp(-maxf(delta,0.0)/.16)
	var velocity:Vector3=player.velocity
	var desired:=Vector2(velocity.x,velocity.z)*.55
	var player_radius:float=player.radius
	desired=desired.limit_length(clampf(player_radius*.7+1.4,2.0,5.0))
	lookahead=lookahead.lerp(desired,blend)
	strength=lerpf(strength,1.0,blend)
	# An extra metre remains available at the starting radius; large holes gain
	# a proportional shoulder. Radius cannot lag below the current hole edge.
	var requested_radius:=player_radius+maxf(1.0,player_radius*.22)
	radius=maxf(requested_radius,lerpf(radius,requested_radius,blend))
	var at:=player.global_position
	target=Vector4(at.x,0.0,at.z,strength)
	var cam:=camera.global_position
	camera_data=Vector4(cam.x,cam.y,cam.z,0.0)
	var back:=camera.global_basis.z.normalized()
	camera_back=Vector4(back.x,back.y,back.z,0.0)
	aperture=Vector4(radius,clampf(radius*.22,.55,1.4),lookahead.x,lookahead.y)
	update_count+=1
	update_occluders(camera,player,delta)
	publish()

func publish()->void:
	RenderingServer.global_shader_parameter_set("hole_reveal_target",target)
	RenderingServer.global_shader_parameter_set("hole_reveal_camera",camera_data)
	RenderingServer.global_shader_parameter_set("hole_reveal_aperture",aperture)
	RenderingServer.global_shader_parameter_set("hole_reveal_back",camera_back)

func is_structural_candidate(body:Node3D)->bool:
	if not is_instance_valid(body) or body.category!="building" or not body.get_meta("dither_building",false):return false
	if body.has_meta("food_kind") or body.get_meta("food_building",false) or body.get_meta("building_fragment",false):return false
	var size:Vector3=body.half_size*2.0*body.global_basis.get_scale().abs()
	return size.y>=dither_min_height and maxf(size.x,size.z)>=dither_min_width

func is_intact(body:Node3D)->bool:
	return is_instance_valid(body) and not body.is_queued_for_deletion() and not body.consumed and body.freeze and not is_instance_valid(body.claimed_by) and is_structural_candidate(body)

func bind_city(city:Node3D)->void:
	# Register only building meshes. Food batches never join this material path.
	for body in city.foods:
		if not is_instance_valid(body) or not is_structural_candidate(body):continue
		if entries.has(body.get_instance_id()):continue
		var entry:={"body":body,"materials":[],"meshes":[],"weight":-1.0}
		for visual in body.find_children("*","MeshInstance3D",true,false):
			if visual.mesh==null:continue
			var key:int=visual.mesh.get_instance_id()
			if not geometry_cache.has(key):geometry_cache[key]=visual.mesh.generate_triangle_mesh()
			if geometry_cache[key]!=null:entry.meshes.append({"visual":visual,"triangles":geometry_cache[key]})
		for mesh in body.find_children("*","MeshInstance3D",true,false):
			var material:Material=mesh.material_override
			if not material is ShaderMaterial or material.shader==null or not "reveal_occluder" in material.shader.code:
				unsupported.append("Building material lacks explicit reveal opt-in: "+str(body.name));continue
			if material not in entry.materials:entry.materials.append(material)
			bound_meshes+=1
		occluders.append(entry);entries[body.get_instance_id()]=entry
		write_weight(entry,0.0)

func body_reveal_weight(body:Node3D)->float:
	if not is_instance_valid(body):return 0.0
	return float(entries.get(body.get_instance_id(),{}).get("weight",0.0))

func write_weight(entry:Dictionary,value:float)->void:
	if is_equal_approx(float(entry.weight),value):return
	entry.weight=value
	if not is_instance_valid(entry.body):return
	for material in entry.materials:material.set_shader_parameter("reveal_occluder",value)

func update_occluders(camera:Camera3D,player:Node3D,delta:float)->void:
	active_occluders=0;selection_bounds_tests=0;mesh_ray_tests=0
	var blend:=1.0-exp(-maxf(delta,0.0)/.10)
	for entry in occluders:
		if not is_instance_valid(entry.body):entry.weight=0.0;continue
		var body:Node3D=entry.body
		# Physics release must immediately restore readability of falling pieces.
		if not is_intact(body):write_weight(entry,0.0);continue
		selection_bounds_tests+=1
		var blocked:=blocks_core(body,camera,player) and mesh_blocks_core(entry,camera,player)
		var value:=lerpf(float(entry.weight),1.0 if blocked else 0.0,blend)
		if value<.001:value=0.0
		elif value>.999:value=1.0
		write_weight(entry,value)
		if value>0.0:active_occluders+=1

func blocks_core(body:Node3D,camera:Camera3D,player:Node3D)->bool:
	if not is_intact(body):return false
	var half:Vector3=body.half_size
	var bounds:=AABB(-half,half*2.0)
	var pose:Transform3D=body.global_transform
	var world:AABB=pose*bounds
	var cam:Vector3=camera.global_position
	var center:=Vector2(player.global_position.x,player.global_position.z)
	core_witness=center
	var core:float=player.radius
	# Cheap broad phase around the camera-to-mouth volume. It never uses the
	# expanded shoulder/lookahead as the activation trigger.
	var low:=Vector2(minf(cam.x,center.x-core),minf(cam.z,center.y-core))
	var high:=Vector2(maxf(cam.x,center.x+core),maxf(cam.z,center.y+core))
	if not Rect2(low,high-low).intersects(Rect2(Vector2(world.position.x,world.position.z),Vector2(world.size.x,world.size.z))):return false
	if cam.y<=.04 or world.end.y<=.02 or world.position.y>=cam.y-.02:return false
	# Project the oriented box's silhouette, clipping edges to the ground and
	# camera-height planes. Tall roofs and side edges cannot evade a center ray.
	var corners:Array[Vector3]=[]
	for i in 8:corners.append(pose*(bounds.position+Vector3(bounds.size.x if i&1 else 0.0,bounds.size.y if i&2 else 0.0,bounds.size.z if i&4 else 0.0)))
	var projected:=PackedVector2Array()
	for i in 8:
		for bit in [1,2,4]:
			if i&bit:continue
			var a:Vector3=corners[i];var b:Vector3=corners[i|bit]
			var lower:=0.0;var upper:=1.0;var dy:=b.y-a.y
			if absf(dy)<.000001:
				if a.y<.02 or a.y>cam.y-.02:continue
			else:
				var t0:float=(.02-a.y)/dy;var t1:float=(cam.y-.02-a.y)/dy
				lower=maxf(0.0,minf(t0,t1));upper=minf(1.0,maxf(t0,t1))
				if lower>upper:continue
			for t in [lower,upper]:
				var point:Vector3=a.lerp(b,t)
				var scale:float=cam.y/(cam.y-point.y)
				projected.append(Vector2(cam.x,cam.z)+(Vector2(point.x,point.z)-Vector2(cam.x,cam.z))*scale)
	if projected.size()<3:return false
	var polygon:=Geometry2D.convex_hull(projected)
	if Geometry2D.is_point_in_polygon(center,polygon):return true
	for i in polygon.size()-1:
		var closest:=Geometry2D.get_closest_point_to_segment(center,polygon[i],polygon[i+1])
		if closest.distance_squared_to(center)<=core*core:
			core_witness=closest
			return true
	return false

func mesh_blocks_core(entry:Dictionary,camera:Camera3D,player:Node3D)->bool:
	# Bounds only admit candidates. A real triangle hit must confirm obstruction,
	# so arch openings and donut holes cannot trigger on their empty box volume.
	var center:=Vector3(player.global_position.x,0,player.global_position.z)
	var from:Vector3=camera.global_position
	if mesh_hit(entry,from,center):return true
	if mesh_hit(entry,from,Vector3(core_witness.x,0,core_witness.y)):return true
	for ring in [.33,.66,.999]:
		for i in 16:
			var angle:float=TAU*float(i)/16.0
			var endpoint:Vector3=center+Vector3(cos(angle),0,sin(angle))*player.radius*ring
			if mesh_hit(entry,from,endpoint):return true
	return false

func mesh_hit(entry:Dictionary,from:Vector3,to:Vector3)->bool:
	for part in entry.meshes:
		if not is_instance_valid(part.visual):continue
		var inverse:Transform3D=part.visual.global_transform.affine_inverse()
		mesh_ray_tests+=1
		if not part.triangles.intersect_segment(inverse*from,inverse*to).is_empty():return true
	return false

func bind_subtree(node:Node)->void:
	if node is MeshInstance3D or node is MultiMeshInstance3D:bind_visual(node)
	for child in node.get_children():bind_subtree(child)

func bind_visual(visual:GeometryInstance3D)->void:
	if visual.has_meta("hole_reveal_bound"):return
	if visual.material_override!=null:
		visual.material_override=adapt_material(visual.material_override)
	elif visual is MeshInstance3D and visual.mesh!=null:
		for surface in visual.mesh.get_surface_count():
			var material:Material=visual.get_active_material(surface)
			if material!=null:visual.set_surface_override_material(surface,adapt_material(material))
	elif visual is MultiMeshInstance3D and visual.multimesh!=null:
		unsupported.append("MultiMesh without an explicit source material: "+str(visual.name))
	visual.set_meta("hole_reveal_bound",true)
	if visual is MultiMeshInstance3D:bound_batches+=1
	else:bound_meshes+=1

func adapt_material(source:Material)->Material:
	if source is ShaderMaterial:
		if source.shader!=null and (source.shader.resource_path in INCLUDED_SHADERS or source.has_meta("hole_reveal_source")):
			preserved_shaders+=1
		else:unsupported.append("Shader material lacks reveal include: "+str(source.shader.resource_path if source.shader else "null"))
		return source
	if not source is StandardMaterial3D:
		unsupported.append("Unsupported material class: "+source.get_class());return source
	# Cosmetic contact flecks deliberately have no shadows and are not blockers.
	if source.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:
		skipped_cosmetics+=1;return source
	var id:=source.get_instance_id()
	if material_cache.has(id):return material_cache[id]
	var reason:=unsupported_standard_reason(source)
	if not reason.is_empty():
		unsupported.append(reason);push_error("Occlusion material adapter: "+reason);return source
	var cull:int=source.cull_mode
	if not shader_cache.has(cull):
		if cull==BaseMaterial3D.CULL_BACK:shader_cache[cull]=StandardShader
		else:
			var shader:=Shader.new()
			shader.code=StandardShader.code.replace("cull_back","cull_front" if cull==BaseMaterial3D.CULL_FRONT else "cull_disabled")
			shader_cache[cull]=shader
	var result:=ShaderMaterial.new();result.shader=shader_cache[cull]
	result.set_shader_parameter("source_albedo",source.albedo_color)
	result.set_shader_parameter("source_roughness",source.roughness)
	result.set_shader_parameter("source_metallic",source.metallic)
	result.set_shader_parameter("source_specular",source.metallic_specular)
	result.set_shader_parameter("source_vertex_color",source.vertex_color_use_as_albedo)
	result.set_shader_parameter("source_vertex_srgb",source.vertex_color_is_srgb)
	result.set_shader_parameter("source_emission",source.emission if source.emission_enabled else Color(0,0,0,1))
	result.set_shader_parameter("source_emission_energy",source.emission_energy_multiplier)
	result.render_priority=source.render_priority
	result.set_meta("hole_reveal_source",source)
	material_cache[id]=result;adapted_materials+=1
	return result

func unsupported_standard_reason(source:StandardMaterial3D)->String:
	if source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return "Nonopaque StandardMaterial requires an explicit reveal adapter"
	if source.shading_mode!=BaseMaterial3D.SHADING_MODE_PER_PIXEL:return "Nonstandard shading mode"
	if source.diffuse_mode!=BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode!=BaseMaterial3D.SPECULAR_SCHLICK_GGX:return "Nonstandard BRDF"
	if source.emission_operator!=BaseMaterial3D.EMISSION_OP_ADD:return "Multiplicative emission requires an explicit adapter"
	for property in source.get_property_list():
		if property.type==TYPE_OBJECT and (source.get(property.name) is Texture2D or source.get(property.name) is Texture3D or source.get(property.name) is TextureLayered):return "Textured StandardMaterial requires an explicit reveal adapter: "+str(property.name)
	for flag in ["normal_enabled","rim_enabled","clearcoat_enabled","anisotropy_enabled","ao_enabled","heightmap_enabled","subsurf_scatter_enabled","backlight_enabled","refraction_enabled","detail_enabled","disable_receive_shadows","disable_ambient_light","vertex_lighting"]:
		if source.get(flag)==true:return "Unsupported enabled material flag: "+flag
	return ""

func diagnostics()->Dictionary:
	return {"target":target,"camera":camera_data,"aperture":aperture,"camera_back":camera_back,
		"policy":"buildings_only","dither_min_height":dither_min_height,"dither_min_width":dither_min_width,
		"bound_meshes":bound_meshes,"bound_batches":bound_batches,"adapted_materials":adapted_materials,
		"preserved_shader_bindings":preserved_shaders,"skipped_cosmetics":skipped_cosmetics,
		"unsupported":unsupported.duplicate(),"updates":update_count,"per_frame_scene_scans":0,
		"registered_occluders":occluders.size(),"active_occluders":active_occluders,"selection_bounds_tests":selection_bounds_tests,
		"cached_triangle_meshes":geometry_cache.size(),"mesh_ray_tests":mesh_ray_tests}

## CPU mirror for bounded geometry regressions; production coverage is shader-side.
func sample_mask(world:Vector3,view_camera:Vector3,view_back:Vector3,shadow_pass:=false)->float:
	if shadow_pass or target.w<=.0001:return 0.0
	var camera:=Vector3(camera_data.x,camera_data.y,camera_data.z)
	var back:=Vector3(camera_back.x,camera_back.y,camera_back.z)
	if view_camera.distance_to(camera)>.025 or view_back.normalized().dot(back)<.9999:return 0.0
	var center:=Vector3(target.x,target.y,target.z)
	var height:=world.y-center.y;var denominator:=camera.y-world.y
	if height<=.02 or denominator<=.02:return 0.0
	var scale:float=(camera.y-center.y)/denominator
	if scale<=1.0:return 0.0
	var projected:=Vector2(camera.x,camera.z)+(Vector2(world.x,world.z)-Vector2(camera.x,camera.z))*scale
	var segment:=Vector2(aperture.z,aperture.w)
	var offset:=projected-Vector2(center.x,center.z)
	var along:=clampf(offset.dot(segment)/maxf(segment.length_squared(),.0001),0.0,1.0)
	var edge:=1.0-smoothstep(aperture.x-aperture.y,aperture.x,(offset-segment*along).length())
	return edge*smoothstep(.02,.20,height)*target.w*.94
