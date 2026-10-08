extends SceneTree
## Isolated script-kernel costs and scene geometry; no claim of GPU timing.
var game:Node3D
var report:={}
var map_id:="city"
var output:=""
func _initialize()->void:run.call_deferred()
func measure(action:Callable,count:=120)->Dictionary:
	var values:Array[float]=[]
	for i in count:
		var started:=Time.get_ticks_usec();action.call(i)
		values.append(float(Time.get_ticks_usec()-started)/1000)
	values.sort()
	return {"samples":count,"p50_ms":values[count/2],"p95_ms":values[int(count*.95)]}
func triangles(mesh:Mesh)->int:
	var count:=0
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var indices:int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else 0
		count+=(indices if indices>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	return count
func on_camera(bounds:AABB)->bool:
	for plane in game.camera.get_frustum():
		var outside:=true
		for i in 8:
			if plane.distance_to(bounds.get_endpoint(i))<=0:outside=false;break
		if outside:return false
	return true
func inventory()->Dictionary:
	var draws:=0;var tris:=0;var view_draws:=0;var view_tris:=0;var multimeshes:=0
	var materials:={};var unique_meshes:={};var food_bounds:={}
	# The dummy renderer does not retain GPU instance matrices. Reconstruct
	# batches from authored owner poses instead of reading identity transforms.
	for body in game.city.foods:
		if not is_instance_valid(body) or not ("batch" in body) or body.batch==null:continue
		var key:int=body.batch.get_instance_id()
		var aabb:AABB=body.food_visual.global_transform*body.food_visual.mesh.get_aabb()
		food_bounds[key]=food_bounds[key].merge(aabb) if food_bounds.has(key) else aabb
	for node in game.world.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree():continue
		var mesh:Mesh;var copies:=1;var bounds:=AABB()
		if node is MultiMeshInstance3D:
			multimeshes+=1;mesh=node.multimesh.mesh
			copies=node.multimesh.visible_instance_count if node.multimesh.visible_instance_count>=0 else node.multimesh.instance_count
			if food_bounds.has(node.multimesh.get_instance_id()):bounds=food_bounds[node.multimesh.get_instance_id()]
			elif node.multimesh.custom_aabb.size!=Vector3.ZERO:bounds=node.global_transform*node.multimesh.custom_aabb
			else:
				push_error("Geometry inventory requires CPU bounds for each batch");quit(1);return {}
		elif node is MeshInstance3D:
			mesh=node.mesh
			if mesh!=null:bounds=node.global_transform*mesh.get_aabb()
		if mesh==null or copies==0:continue
		var count:=triangles(mesh)*copies;var surfaces:=mesh.get_surface_count()
		tris+=count;draws+=surfaces;unique_meshes[mesh.get_instance_id()]=true
		if node.material_override:materials[node.material_override.get_instance_id()]=true
		if on_camera(bounds):view_draws+=surfaces;view_tris+=count
	return {"scene_surface_submissions":draws,"scene_triangles":tris,"camera_surface_submissions":view_draws,"camera_batch_triangles":view_tris,"multimeshes":multimeshes,"unique_meshes":unique_meshes.size(),"override_materials":materials.size(),"scope":"Conservative geometry inventory; excludes UI, shadow passes and GPU timings"}
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):map_id=arg.trim_prefix("--map=")
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map=map_id;game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false);game.ground.set_physics_process(false)
	for hole in game.holes:hole.enabled=false
	report["map"]=map_id;report["version"]=ProjectSettings.get_setting("application/config/version")
	report["loaded_catalog_models"]=game.city.models.size();report["static_memory_bytes"]=OS.get_static_memory_usage()
	report["opening_geometry"]=inventory()
	for scenario in ["opening","grown"]:
		if scenario=="grown":
			for i in game.holes.size():
				var h:Node3D=game.holes[i];h.level=8;h.score=350;h.radius=7.2;h.position=Vector3(-30+(i%4)*20,0,-15+(i/4)*30);h._sync_shape()
			game.update_camera(1.0,true)
			report["grown_geometry"]=inventory()
		report[scenario+"_ground"]=measure(func(i):
			for h in game.holes:h.position.x+=.003
			game.ground.sync())
		report[scenario+"_city_update"]=measure(func(i):game.elapsed=i/60.0;game.city._process(1.0/60))
		report[scenario+"_nearest_eight"]=measure(func(i):
			for h in game.holes:game.nearest_food(h),40)
		report[scenario+"_scan"]=measure(func(i):game.scan_food(),40)
	print("COMPONENT_PROFILE "+JSON.stringify(report))
	if output!="":FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	game.free();await process_frame;quit()
