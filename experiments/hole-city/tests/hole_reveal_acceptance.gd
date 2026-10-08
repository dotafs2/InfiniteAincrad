extends SceneTree
## Real source-scene material/lifecycle acceptance, not a screenshot or GPU timing claim.
var game:Node3D
var failures:Array[String]=[]
var checks:=0
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func materials_under(node:Node)->Array[Material]:
	var result:Array[Material]=[]
	if node is GeometryInstance3D and node.material_override!=null:result.append(node.material_override)
	elif node is MeshInstance3D and node.mesh!=null:
		for i in node.mesh.get_surface_count():
			if node.get_active_material(i)!=null:result.append(node.get_active_material(i))
	for child in node.get_children():result.append_array(materials_under(child))
	return result
func included(material:Material)->bool:
	return material is ShaderMaterial and (material.has_meta("hole_reveal_source") or material.shader.resource_path in game.Reveal.INCLUDED_SHADERS)
func material_fixture(map_id:String)->void:
	game.selected_map=map_id;game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for hole in game.holes:hole.enabled=false
	var missed:=0;var all_materials:=0;var hidden:=0;var skinned:=0;var actual_batches:=0
	var categories:Dictionary={}
	for body in game.city.foods:
		categories[body.category]=int(categories.get(body.category,0))+1
		for material in materials_under(body):
			all_materials+=1
			if not included(material):missed+=1
		for mesh in body.find_children("*","MeshInstance3D",true,false):
			if not mesh.visible:hidden+=1
			if mesh.skin!=null:skinned+=1
	for child in game.city.get_children():
		if child is MultiMeshInstance3D:
			var material:Material=child.material_override
			if material is StandardMaterial3D and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:continue
			actual_batches+=1
			if not included(material):missed+=1
	check(all_materials>300 and missed==0,map_id+": every edible/actor and visible batch uses the shared reveal path")
	check(hidden>50 and actual_batches>0,map_id+": hidden independent originals and visible MultiMesh materials are both covered")
	check(skinned>0,map_id+": actual skinned citizens retain adapted materials")
	check(game.reveal.unsupported.is_empty(),map_id+": no actual scene material silently loses its original shading")
	var floor_count:=0
	for child in game.city.get_children():
		if child is MeshInstance3D:
			floor_count+=1
			check(not child.has_meta("hole_reveal_bound"),map_id+": nonedible ground/base mesh remains outside reveal binding")
	check(floor_count>=2,map_id+": explicit city base and water exclusion is exercised")
	check(not game.ground.has_meta("hole_reveal_bound"),map_id+": cut ground is never adapted")
	for material in materials_under(game.ui.hero_models):check(not material.has_meta("hole_reveal_source"),map_id+": home miniature material is independent")
	var source_checks:=0;var source_bad:=0;var emissive:=0
	for result in game.reveal.material_cache.values():
		var source:StandardMaterial3D=result.get_meta("hole_reveal_source")
		source_checks+=1
		if result.get_shader_parameter("source_albedo")!=source.albedo_color:source_bad+=1
		if not is_equal_approx(result.get_shader_parameter("source_roughness"),source.roughness):source_bad+=1
		if not is_equal_approx(result.get_shader_parameter("source_metallic"),source.metallic):source_bad+=1
		if not is_equal_approx(result.get_shader_parameter("source_specular"),source.metallic_specular):source_bad+=1
		if result.get_shader_parameter("source_vertex_color")!=source.vertex_color_use_as_albedo:source_bad+=1
		if result.get_shader_parameter("source_vertex_srgb")!=source.vertex_color_is_srgb:source_bad+=1
		if source.emission_enabled:
			emissive+=1
			if result.get_shader_parameter("source_emission")!=source.emission or result.get_shader_parameter("source_emission_energy")!=source.emission_energy_multiplier:source_bad+=1
	check(source_checks>0 and source_bad==0,map_id+": all adapted source color, finish, vertex flags and emission parameters remain exact")
	if map_id=="city":check(emissive>0,map_id+": emissive signal/recipe actor material is exercised")
	else:check(game.city.food_material.shader.resource_path=="res://fidelity/food_glaze.gdshader",map_id+": glossy food keeps its original shared finish shader")
	var before:Dictionary=game.reveal.diagnostics()
	game.reveal.bind_city(game.city)
	check(game.reveal.bound_meshes==before.bound_meshes and game.reveal.adapted_materials==before.adapted_materials,map_id+": rebind is idempotent and preserves shared material cache")
	metrics[map_id]={"materials":all_materials,"hidden_originals":hidden,"skinned_meshes":skinned,"batches":actual_batches,"source_materials":source_checks,"emissive_sources":emissive,"categories":categories,"diagnostics":before}
func math_fixture()->void:
	var reveal=game.reveal
	game.player.position=Vector3.ZERO;game.player.radius=3.0;game.player.velocity=Vector3.ZERO
	game.camera.position=Vector3(10,18,14);game.camera.look_at(Vector3.ZERO)
	reveal.reset();reveal.tick(game.camera,game.player,1.0,true)
	var cam:Vector3=game.camera.position;var back:Vector3=game.camera.basis.z
	check(reveal.aperture.x>game.player.radius+0.9,"Aperture always exceeds the complete hole footprint with a safety margin")
	check(reveal.sample_mask(cam*.25,cam,back)>.9,"Tall blocker fragments on camera-to-hole rays are revealed")
	check(reveal.sample_mask(Vector3(0,1,0),cam,back)>.9,"Geometry directly above a large hole is revealed despite center-plane ambiguity")
	check(reveal.sample_mask(Vector3(0,0,0),cam,back)==0.0,"Floor-plane fragment remains opaque")
	check(reveal.sample_mask(Vector3(0,-1,0),cam,back)==0.0,"Fragments behind the ground target plane remain opaque")
	check(reveal.sample_mask(Vector3(-25,2,-25),cam,back)==0.0,"Unrelated background remains opaque")
	check(reveal.sample_mask(cam*.25,cam,back,true)==0.0,"Shadow pass retains complete occluder silhouette")
	check(reveal.sample_mask(cam*.25,cam+Vector3.ONE,back)==0.0,"Other viewport camera position cannot inherit gameplay cutout")
	check(reveal.sample_mask(cam*.25,cam,-back)==0.0,"Other viewport camera basis cannot inherit gameplay cutout")
	var large_mesh_center:=Vector3(30,6,10)
	var large_mesh_edge:Vector3=cam*.3
	check(reveal.sample_mask(large_mesh_center,cam,back)==0 and reveal.sample_mask(large_mesh_edge,cam,back)>.9,"Wide mesh edge is revealed even with its object center far outside the opening")
	game.player.velocity=Vector3(-4,0,-5.6)
	reveal.tick(game.camera,game.player,1.0,true)
	var destination:=Vector3(reveal.lookahead.x,0,reveal.lookahead.y)
	var away_fragment:=destination.lerp(cam,.05)
	check(reveal.sample_mask(away_fragment,cam,back)>.9,"Lookahead remains clear while moving away from camera")
	var probes:Array[Vector4]=[]
	for hz in [30,60,120]:
		reveal.reset();game.player.velocity=Vector3(4,0,-3)
		for i in hz:reveal.tick(game.camera,game.player,1.0/hz,true)
		probes.append(reveal.aperture)
	check(probes[0].distance_to(probes[1])<.00001 and probes[1].distance_to(probes[2])<.00001,"Lookahead smoothing is time-based at 30/60/120 Hz")
	var moving:float=reveal.lookahead.length();game.player.velocity=Vector3.ZERO
	reveal.tick(game.camera,game.player,.016,true)
	check(reveal.lookahead.length()>0 and reveal.lookahead.length()<moving,"Stopping smoothly retracts movement lookahead")
	reveal.tick(game.camera,game.player,1.0,false)
	check(reveal.target.w==0.0 and reveal.sample_mask(cam*.25,cam,back)==0.0,"Disabled controller removes stale cutout immediately")
func lifecycle_fixture()->void:
	game.player.active=true;game.phase="playing";game.update_reveal(1.0)
	var before:Vector4=game.reveal.target
	game.toggle_pause();game.update_reveal(1.0)
	check(game.reveal.target==before,"Pause freezes the aperture with the gameplay backdrop")
	game.toggle_pause();game.player.active=false;game.update_reveal(.016)
	check(game.reveal.target.w==0,"Inactive/eaten player removes cutout")
	game.player.active=true;game.update_reveal(1);game.finish("timeout")
	check(game.reveal.target.w==0,"Round settlement removes stale cutout")
	game.back_home()
	check(game.reveal.target.w==0,"Returning home removes gameplay cutout")
func fracture_fixture()->void:
	var buildings:Array=[]
	for body in game.city.foods:
		if body.category=="building":buildings.append(body)
	for mode in ["cached","fallback"]:
		var body:Node3D=buildings.pop_back()
		if mode=="fallback":body.fracture_cache=null
		else:check(body.fracture_cache!=null,"Cached fracture fixture uses an actual precomputed facade")
		var start:int=game.city.foods.size()
		body.fracture_building(game.player)
		var valid:=0
		for index in range(start,game.city.foods.size()):
			var piece:Node3D=game.city.foods[index]
			for material in materials_under(piece):
				if included(material):valid+=1
		check(valid==16,mode+": all sixteen newly spawned independent fragments use reveal materials")
func rain_fixture()->void:
	var body:RigidBody3D=game.city.spawn_rain("egg",Vector2(30,25),18.0)
	check(included(body.food_visual.material_override),"New airborne food inherits the included shared glaze shader")
	body.rain_landed=true;body.sleeping=true
	game.city.batch_settled_rain()
	check(body.batch!=null and not body.food_visual.visible,"Settled rain fixture enters an actual MultiMesh batch")
	var found:=false
	for child in game.city.get_children():
		if child is MultiMeshInstance3D and child.multimesh==body.batch:found=included(child.material_override)
	check(found,"New settled-rain MultiMesh uses the same shared reveal shader")
	body.expose_visual()
	check(body.food_visual.visible and included(body.food_visual.material_override),"Released rain returns to independent reveal-ready material")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	material_fixture("city");math_fixture();fracture_fixture();lifecycle_fixture()
	material_fixture("food");rain_fixture()
	var count_before:int=game.reveal.bound_meshes
	for i in 600:game.update_reveal(1.0/60.0)
	check(game.reveal.bound_meshes==count_before and game.reveal.diagnostics().per_frame_scene_scans==0,"600 reveal updates never rescan or rebind scene meshes")
	for shader in [game.Reveal.StandardShader,load("res://fidelity/palette.gdshader"),load("res://fidelity/food_glaze.gdshader")]:
		check("IN_SHADOW_PASS" in shader.code and "hole_reveal_discard" in shader.code,"Actual material shader calls shared include with explicit shadow guard")
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Headless actual-scene material/lifecycle tests plus CPU geometry mirror; no GPU/browser/iPhone performance claim"}
	print("HOLE_REVEAL_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var path:=argument.trim_prefix("--report=")
			if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):push_error("Report path must be a native absolute path");failures.append("invalid report path");continue
			var output:=FileAccess.open(path,FileAccess.WRITE)
			if output==null:push_error("Cannot write explicit report: "+path);failures.append("report write failed")
			else:output.store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
