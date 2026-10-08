extends SceneTree
var game:Node3D
func _initialize()->void:run.call_deferred()
func triangles(mesh:Mesh)->int:
	var total:=0
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		total+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	return total
func digest(bytes:PackedByteArray)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func visible_box(box:AABB,camera:Camera3D)->bool:
	var inner:Vector3=camera.global_position-camera.global_basis.z*5
	for plane in camera.get_frustum():
		var sign_side:=1.0 if plane.distance_to(inner)>=0 else -1.0
		var any_inside:=false
		for i in 8:
			if plane.distance_to(box.get_endpoint(i))*sign_side>=0:any_inside=true;break
		if not any_inside:return false
	return true
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.active=false;h.enabled=false;h.set_physics_process(false)
	var views:Array=[];var total:=0;var legacy_region:=0;var outer_region:=0;var meshes:={};var bodies:Array=[]
	for key in game.city.mesh_cache:
		var mesh:Mesh=game.city.mesh_cache[key];meshes[key]={"triangles":triangles(mesh),"arrays_sha256":digest(var_to_bytes(mesh.surface_get_arrays(0)))}
	for body in game.city.foods:
		if not body.has_meta("food_kind"):continue
		var count:=triangles(body.food_visual.mesh);total+=count
		if maxf(absf(body.position.x),absf(body.position.z))<=80:legacy_region+=count
		else:outer_region+=count
		bodies.append({"key":str(body.get_meta("food_mesh_key","")),"at":[body.position.x,body.position.y,body.position.z],"triangles":count})
	for view in game.city.find_children("*","MultiMeshInstance3D",false,false):
		var mm:MultiMesh=view.multimesh
		if view.material_override!=game.city.food_batch_material:continue
		views.append({"box":view.global_transform*mm.custom_aabb,"triangles":triangles(mm.mesh)*mm.visible_instance_count,"instances":mm.visible_instance_count})
	var samples:Array=[]
	for radius in [.85,7.2,14.0]:
		for at in [Vector2(1,23),Vector2(0,0),Vector2(-35,-40),Vector2(40,30),Vector2(-84,-60),Vector2(-88,0),Vector2(-84,60),Vector2(0,88),Vector2(84,60),Vector2(88,0),Vector2(84,-60),Vector2(0,-88)]:
			game.player.position=Vector3(at.x,0,at.y);game.player.radius=radius;game.update_camera(1,true)
			var cell_triangles:=0;var cell_count:=0;var cell_instances:=0
			for view in views:
				if visible_box(view.box,game.camera):cell_triangles+=view.triangles;cell_count+=1;cell_instances+=view.instances
			samples.append({"at":[at.x,at.y],"radius":radius,"visible_cells_upper_bound":cell_count,"submitted_static_triangles_upper_bound":cell_triangles,"instances":cell_instances,"camera":[game.camera.position.x,game.camera.position.y,game.camera.position.z],"viewport":[root.size.x,root.size.y]})
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"total_food_triangles":total,"old_square_region_triangles":legacy_region,"outside_old_square_triangles":outer_region,"cached_meshes":meshes,"body_inventory":bodies,"batch_count":views.size(),"camera_samples":samples,"scope":"Real scene meshes and actual static-batch world AABBs against camera frustum. Conservative CPU geometry submission bounds only; no renderer/GPU timing or appearance claim."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t")+"\n");f.close()
	game.free();await process_frame
	print("WORLD_GEOMETRY_PROBE "+JSON.stringify({"checks":1,"failures":[],"total":total,"old_region":legacy_region,"outer_region":outer_region,"batches":views.size()}));quit(0)
