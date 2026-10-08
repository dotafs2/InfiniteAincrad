extends SceneTree
func _initialize()->void:run.call_deferred()
func collision_radius(body:Node3D)->float:
	var radius:=0.0
	for child in body.get_children():
		if not child is CollisionShape3D:continue
		if child.shape is BoxShape3D:
			radius=maxf(radius,Vector2(child.shape.size.x,child.shape.size.z).length()*.5)
		elif child.shape is ConvexPolygonShape3D:
			for vertex in child.shape.points:radius=maxf(radius,Vector2(vertex.x,vertex.z).length())
	return radius
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.active=false;hole.enabled=false;hole.set_physics_process(false)
	var meshes:={};var ground:Array=[]
	for key in game.city.mesh_cache:
		var box:AABB=game.city.mesh_cache[key].get_aabb();meshes[key]={"size":[box.size.x,box.size.y,box.size.z],"triangles":game.city.mesh_cache[key].surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3}
	for body in game.city.foods:
		if not body.has_meta("food_kind") or is_instance_valid(body.support_parent):continue
		ground.append({"key":str(body.get_meta("food_mesh_key")),"at":[body.position.x,body.position.z],"half":[body.half_size.x,body.half_size.z],"yaw":body.rotation.y,"collision_radius":collision_radius(body),"tower":int(body.get_meta("tower_id",-1)),"pile":int(body.get_meta("pile_id",-1))})
	var report:={"meshes":meshes,"ground_food":ground,"plan_sha256":FileAccess.get_sha256("res://assets/food_city/neighborhoods.json")}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.free();await process_frame;print("DENSITY_BASELINE "+JSON.stringify({"checks":1,"failures":[],"ground_bodies":ground.size()}));quit(0)
