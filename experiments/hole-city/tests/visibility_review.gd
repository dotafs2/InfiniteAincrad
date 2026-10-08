extends SceneTree
## Independent material-path and camera-ray review. Headless configuration and
## geometry checks do not establish browser pixels, GPU cost or phone frame rate.
const Reveal=preload("res://fidelity/hole_reveal.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func pause_simulation()->void:
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false)
	for body in game.city.foods:
		if is_instance_valid(body):body.freeze=true;body.set_physics_process(false)
	for hole in game.holes:hole.set_process(false);hole.set_physics_process(false)
func material_supported(material:Material)->bool:
	return material is ShaderMaterial and material.shader!=null and 'hole_reveal.gdshaderinc' in material.shader.code
func visuals(node:Node)->Array:
	var result:Array=[]
	if node is MeshInstance3D or node is MultiMeshInstance3D:result.append(node)
	for child in node.get_children():result.append_array(visuals(child))
	return result
func audit_visuals(nodes:Array,label:String)->void:
	var missing:Array[String]=[];var count:=0;var skinned:=0;var batches:=0
	for node in nodes:
		if node is MultiMeshInstance3D:
			batches+=1;count+=1
			if not material_supported(node.material_override):missing.append(str(node.get_path()))
		else:
			if node.skin!=null:skinned+=1
			for surface in node.mesh.get_surface_count():
				count+=1
				if not material_supported(node.get_active_material(surface)):missing.append(str(node.get_path()))
	check(count>0 and missing.is_empty(),label+": every effective material has camera-ray reveal support")
	evidence[label]={"surfaces":count,"skinned_meshes":skinned,"batches":batches,"missing":missing}
func geometry_review()->void:
	var r=game.reveal
	var physics_before:Array=[]
	for body in game.city.foods:physics_before.append([body.transform,body.freeze,body.collision_layer,body.collision_mask,body.points,body.mass])
	var old_position:Vector3=game.player.position;var old_radius:float=game.player.radius
	var old_camera:Transform3D=game.camera.global_transform
	for yaw in [0.0,PI*.5,PI,PI*1.5]:
		var rotation:=Basis(Vector3.UP,yaw)
		var offset:Vector3=rotation*Vector3(10,18,14)
		game.player.position=Vector3(7,0,-11)
		game.camera.position=game.player.position+offset;game.camera.look_at(game.player.position)
		for hole_radius in [.85,3.0,8.0]:
			game.player.radius=hole_radius
			for velocity in [Vector3.ZERO,offset*Vector3(1,0,1)*-.4,rotation*Vector3(7,0,0)]:
				game.player.velocity=velocity;r.reset();r.tick(game.camera,game.player,4.0,true)
				var state:Dictionary=r.diagnostics()
				var cam:Vector3=game.camera.global_position;var back:Vector3=game.camera.global_basis.z
				var center:Vector3=game.player.global_position
				var segment:=Vector3(state.aperture.z,0,state.aperture.w)
				check(state.aperture.x>=hole_radius+1.0 and segment.length()<=5.0001,"Aperture adds a shoulder and bounds directional reach")
				# Known ground endpoints generate genuine camera rays; this does not
				# duplicate the implementation's ray-plane intersection formula.
				for endpoint in [center,center+segment,center+segment*.5]:
					for fraction in [.05,.35,.80]:
						var sample:Vector3=endpoint.lerp(cam,fraction)
						check(r.sample_mask(sample,cam,back)>.90,"Foreground ray remains clear across height, yaw, radius and away lookahead")
						check(r.sample_mask(sample,cam,back,true)==0.0,"Shadow pass retains complete foreground caster")
						check(r.sample_mask(sample,cam+Vector3(0,.1,0),back)==0.0,"Another camera cannot inherit gameplay cut")
						check(r.sample_mask(sample,cam,-back)==0.0,"Opposing camera orientation cannot inherit gameplay cut")
					check(r.sample_mask(endpoint,cam,back)==0.0 and r.sample_mask(endpoint+Vector3.DOWN,cam,back)==0.0,"Ground and below-aperture geometry stay opaque")
				var lateral:=Vector3(-offset.z,0,offset.x).normalized()
				var outside:Vector3=center+lateral*(float(state.aperture.x)+segment.length()+2)
				check(r.sample_mask(outside.lerp(cam,.35),cam,back)==0.0,"Unrelated side geometry stays opaque")
				check(r.sample_mask(cam+(cam-center)*.2,cam,back)==0.0,"Geometry behind camera stays opaque")
				check(r.sample_mask(center+Vector3.UP*.01,cam,back)==0.0,"Ground-contact guard does not cut the support plane")
	# Specific review failure: a roof directly over the player was rejected by
	# the removed vertical XZ foreground plane, despite covering the aperture.
	game.player.position=Vector3.ZERO;game.player.radius=.85;game.player.velocity=Vector3.ZERO
	game.camera.position=Vector3(10,18,14);game.camera.look_at(Vector3.ZERO)
	r.reset();r.tick(game.camera,game.player,4,true)
	check(r.sample_mask(Vector3(0,1,0),game.camera.position,game.camera.global_basis.z)>.9,"Roof directly above the mouth is actually revealed")
	for view in [game.ui.hero_view,game.ui.skin_view]:
		for child in view.get_children():
			if child is Camera3D:check(r.sample_mask(Vector3(0,1,0),child.global_position,child.global_basis.z)==0.0,"Actual menu SubViewport camera cannot inherit world reveal")
	var stable:Dictionary=r.diagnostics()
	for frame in 240:r.tick(game.camera,game.player,1.0/60.0,true)
	var after:Dictionary=r.diagnostics()
	check(after.bound_meshes==stable.bound_meshes and after.bound_batches==stable.bound_batches and after.adapted_materials==stable.adapted_materials,"Frame updates do not bind meshes or allocate adapted materials")
	var physics_after:Array=[]
	for body in game.city.foods:physics_after.append([body.transform,body.freeze,body.collision_layer,body.collision_mask,body.points,body.mass])
	check(physics_before==physics_after,"Reveal changes no edible transform, collision, freeze, score or mass state")
	game.player.position=old_position;game.player.radius=old_radius;game.player.velocity=Vector3.ZERO;game.camera.global_transform=old_camera
func adapter_review()->void:
	var fixture:=Node3D.new();game.add_child(fixture)
	for cull in [BaseMaterial3D.CULL_BACK,BaseMaterial3D.CULL_FRONT,BaseMaterial3D.CULL_DISABLED]:
		var source:=StandardMaterial3D.new();source.albedo_color=Color(.3,.6,.9,1)
		source.roughness=.27;source.metallic=.31;source.metallic_specular=.67;source.vertex_color_use_as_albedo=true;source.vertex_color_is_srgb=cull==BaseMaterial3D.CULL_FRONT
		source.emission_enabled=true;source.emission=Color(.2,.3,.4,1);source.emission_energy_multiplier=2.3;source.cull_mode=cull
		var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.material_override=source
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;fixture.add_child(mesh)
		var pose:=mesh.transform;game.prepare_occluder(mesh)
		var adapted:ShaderMaterial=mesh.material_override
		check(adapted.get_meta("hole_reveal_source")==source and adapted.get_shader_parameter("source_albedo")==source.albedo_color,"Adapter retains original source and exact albedo input")
		check(is_equal_approx(adapted.get_shader_parameter("source_roughness"),.27) and is_equal_approx(adapted.get_shader_parameter("source_metallic"),.31) and is_equal_approx(adapted.get_shader_parameter("source_specular"),.67),"Adapter retains roughness, metalness and specular inputs")
		check(adapted.get_shader_parameter("source_emission")==source.emission and is_equal_approx(adapted.get_shader_parameter("source_emission_energy"),2.3) and adapted.get_shader_parameter("source_vertex_color"),"Adapter retains separate emissive color/energy and vertex-palette inputs")
		check(adapted.get_shader_parameter("source_vertex_srgb")==source.vertex_color_is_srgb,"Adapter retains original vertex-color decoding flag")
		var expected:String=["cull_back","cull_front","cull_disabled"][cull]
		check(expected in adapted.shader.code and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED and mesh.transform==pose,"Culling, shadow-caster mode and transform survive adaptation")
		game.prepare_occluder(mesh);check(mesh.material_override==adapted,"Repeated prepare is idempotent")
	var unsupported:=StandardMaterial3D.new();unsupported.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(not game.reveal.unsupported_standard_reason(unsupported).is_empty(),"Unsupported alpha material fails adaptation preflight rather than silently changing appearance")
	unsupported.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED;unsupported.normal_enabled=true
	check(not game.reveal.unsupported_standard_reason(unsupported).is_empty(),"Unsupported normal-map path is reported rather than silently dropping finish")
	fixture.free()
func map_review(map_id:String)->void:
	game.selected_map=map_id;game.start_level();pause_simulation()
	check(is_equal_approx(game.reveal.aperture.x,1.85),map_id+": fresh round does not inherit previous large-hole aperture")
	check(game.reveal.diagnostics().unsupported.is_empty(),map_id+": actual map binds without unsupported materials")
	var by_category:Dictionary={}
	for body in game.city.foods:
		if not by_category.has(body.category):by_category[body.category]=[]
		by_category[body.category].append_array(visuals(body))
	for category in by_category:audit_visuals(by_category[category],map_id+"/"+category)
	var batches:Array=[]
	for child in game.city.get_children():
		if child is MultiMeshInstance3D:batches.append(child)
	audit_visuals(batches,map_id+"/static_batches")
	check(not material_supported(game.ground.surface),map_id+": terrain is outside reveal adaptation")
	for child in game.city.get_children():
		if child is MeshInstance3D:check(not material_supported(child.material_override),map_id+": nonedible pedestal and water remain unchanged")
	for node in visuals(game.player):
		if node is MeshInstance3D and node.mesh!=null:
			for surface in node.mesh.get_surface_count():check(not material_supported(node.get_active_material(surface)),map_id+": player's own skin does not cut itself")
	game.update_reveal(1)
	check(game.reveal.strength>.99,map_id+": intro enables opening visibility")
	game.begin_play();game.update_reveal(1)
	paused=true;var paused_state:Dictionary=game.reveal.diagnostics();game.update_reveal(1)
	check(game.reveal.diagnostics()==paused_state,map_id+": pause freezes reveal state without traversing paused actors")
	paused=false
	if map_id=="city":
		geometry_review();adapter_review()
		var released:=false
		for body in game.city.foods:
			if body.static_instances.is_empty():continue
			var handle:Dictionary=body.static_instances[0];var visual:MeshInstance3D=handle.visual
			var source:Material=visual.material_override;var source_mesh:Mesh=visual.mesh;var pool:RefCounted=handle.pool.get_ref()
			var count:int=pool.mesh.visible_instance_count;body.notify_moving()
			check(body.static_instances.is_empty() and visual.visible and visual.mesh==source_mesh and visual.material_override==source and pool.mesh.visible_instance_count<count,"Released city prop retains mesh/material and leaves its static batch")
			audit_visuals(visuals(body),"city/released_prop");released=true;break
		check(released,"City fixture exercises a real static-to-independent transition")
		for cached in [true,false]:
			var building:Node3D=game.city.building_visuals[0 if cached else 1].body
			var previous:Material=building.fracture_material
			if not cached:building.fracture_cache=null
			var parent_name:String=building.name;building.fracture_building(game.player)
			var pieces:Array=[]
			for body in game.city.foods:
				if is_instance_valid(body) and body.get_meta("fracture_parent","")==parent_name:
					body.freeze=true;body.set_physics_process(false);pieces.append_array(visuals(body))
			check(pieces.size()==16,"Actual fracture still creates sixteen independent pieces")
			audit_visuals(pieces,"city/"+("cached_fracture" if cached else "fallback_fracture"))
			if cached:check(pieces.all(func(v):return v.material_override==previous),"Cached fracture retains the original palette shader object")
	else:
		game.city.rain_enabled=false
		var original:Material=game.city.food_material
		for kind in game.city.Shapes.KINDS:
			var rain:Node3D=game.city.spawn_rain(kind,Vector2(70,70),15)
			rain.freeze=true;rain.set_physics_process(false)
			check(rain.food_visual.material_override==original and material_supported(original),"New airborne "+kind+" retains the shared food finish and reveal")
			rain.rain_landed=true;rain.sleeping=true;game.city.batch_settled_rain()
			check(rain.batch!=null and not rain.food_visual.visible,"Settled "+kind+" enters its render batch")
			var previous_batch:MultiMesh=rain.batch;var count:int=previous_batch.visible_instance_count
			rain.expose_visual()
			check(rain.batch==null and rain.food_visual.visible and rain.food_visual.material_override==original and previous_batch.visible_instance_count==count-1,"Released "+kind+" preserves reveal, finish and compact instance ownership")
		var settled:Array=[]
		for child in game.city.get_children():
			if child is MultiMeshInstance3D:settled.append(child)
		audit_visuals(settled,"food/static_and_dynamic_batches")
		game.city.ensure_impact_visuals()
		for child in game.city.get_children():
			if child is MultiMeshInstance3D and child.multimesh in [game.city.crumb_batch,game.city.glaze_batch]:
				check(not material_supported(child.material_override) and child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Contact flecks retain cosmetic material and shadow exclusion")
	game.player.radius=8;game.update_reveal(1)
	check(game.reveal.aperture.x>9,"Prior-round fixture really expands the aperture before reset")
	game.finish("timeout");check(game.reveal.strength==0.0,"Result screen immediately clears gameplay reveal")
	game.back_home();check(game.reveal.strength==0.0,"Home immediately clears gameplay reveal")
	await process_frame;await process_frame
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	check(game.test_mode and game.progress_file().is_empty(),"Review has no player progress path")
	await map_review("city");await map_review("food")
	game.selected_map="city";game.start_level();pause_simulation();game.update_reveal(1)
	check(game.reveal.diagnostics().unsupported.is_empty() and game.reveal.strength>.99,"Map restart discards stale adaptation state and re-enables current camera")
	game.player.active=false;game.update_reveal(.1);check(game.reveal.strength==0.0,"Inactive player clears the opening")
	var cpu_source:String=FileAccess.get_file_as_string("res://fidelity/hole_reveal.gd")
	var tick:String=cpu_source.get_slice("func tick(",1).get_slice("\nfunc ",0)
	check(not "for " in tick and not "while " in tick and not "get_children" in tick and not "find_children" in tick and not "set_shader_parameter" in tick,"Motion path contains no per-object loop, scene scan or material update")
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Headless camera-ray geometry, actual material paths and lifecycle; no GPU/phone claim"}
	print("VISIBILITY_REVIEW "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
