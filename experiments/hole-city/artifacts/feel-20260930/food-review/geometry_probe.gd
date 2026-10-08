extends SceneTree
func _initialize()->void:run.call_deferred()
func visible(box:AABB,camera:Camera3D)->bool:
	var inside:Vector3=camera.global_position-camera.global_basis.z*5
	for plane in camera.get_frustum():
		var signum:=1.0 if plane.distance_to(inside)>=0 else -1.0
		var contained:=false
		for i in 8:
			if signum*plane.distance_to(box.get_endpoint(i))>=0:contained=true;break
		if not contained:return false
	return true
func digest(value:Variant)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false)
	var city:Node3D=game.city;city.process_mode=Node.PROCESS_MODE_DISABLED;city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.set_physics_process(false)
	var groups:Dictionary={};var meshes:Dictionary={};var total:=0
	for key in city.mesh_cache:meshes[key]=digest(city.mesh_cache[key].surface_get_arrays(0))
	for body in city.foods:
		if not body.has_meta("food_kind"):continue
		var tris:int=body.food_visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3;total+=tris
		if body.batch==null:continue
		var id:int=body.batch.get_instance_id()
		if not groups.has(id):
			var cell:=Vector2i(floori(body.position.x/city.BATCH_CELL),floori(body.position.z/city.BATCH_CELL))
			groups[id]={"key":str(body.get_meta("food_mesh_key"))+"@%d,%d"%[cell.x,cell.y],"triangles_each":tris,"members":[],"mesh":body.batch}
		groups[id].members.append(body)
	var vp:=SubViewport.new();vp.size=Vector2i(390,844);vp.world_3d=game.get_world_3d();root.add_child(vp);game.camera.reparent(vp)
	await process_frame
	var views:=[]
	for radius in [.85,7.2]:
		game.player.radius=radius;game.player.position=Vector3(1,0,23);game.update_camera(1.0,true)
		var batches:=[];var submitted:=0;var visible_body_triangles:=0;var visible_bodies:=0
		for group in groups.values():
			var mm:MultiMesh=group.mesh
			if not visible(city.global_transform*mm.custom_aabb,game.camera):continue
			var body_count:=0
			for body in group.members:
				var aabb:AABB=body.food_visual.global_transform*body.food_visual.mesh.get_aabb()
				if visible(aabb,game.camera):body_count+=1
			submitted+=group.triangles_each*mm.visible_instance_count
			visible_body_triangles+=group.triangles_each*body_count;visible_bodies+=body_count
			batches.append({"key":group.key,"members":mm.visible_instance_count,"per_body_triangles":group.triangles_each,"visible_bodies":body_count,"bounds":[mm.custom_aabb.position.x,mm.custom_aabb.position.y,mm.custom_aabb.position.z,mm.custom_aabb.size.x,mm.custom_aabb.size.y,mm.custom_aabb.size.z]})
		views.append({"radius":radius,"triangles":submitted,"cells":batches.size(),"individually_visible_triangles":visible_body_triangles,"individually_visible_bodies":visible_bodies,"batches":batches})
	var result:={"checks":1,"failures":[],"version":ProjectSettings.get_setting("application/config/version"),"food_count":city.foods.size(),"food_triangles":total,"shared_meshes":meshes,"batch_cell":city.BATCH_CELL,"opening":views,"scope":"Read-only actual meshes and mathematical frustum bounds; no render, GPU timing or screenshot."}
	game.camera.reparent(game);vp.free();game.free();await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			if file==null:quit(3);return
			file.store_string(JSON.stringify(result,"  "))
	print("FOOD_GEOMETRY_REVIEW "+JSON.stringify({"checks":1,"failures":[],"version":result.version,"food_count":result.food_count,"triangles":total}))
	quit()
