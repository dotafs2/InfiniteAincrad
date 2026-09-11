extends SceneTree
## GPT-6 review camera/evidence only; no runtime implementation or world state.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="): output = arg.trim_prefix("--review-output=")
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1400,900)
	var scene := Node3D.new()
	scene.set_script(load("res://spatial/deepseek_residences_review.gd"))
	root.add_child(scene)
	var shots := [
		{"id":"front","pos":Vector3(15,9.5,13.5),"look":Vector3(0,3.4,0),"fov":42.0},
		{"id":"rear","pos":Vector3(-15,10,-16),"look":Vector3(0,4,0),"fov":42.0},
		{"id":"near_door","pos":Vector3(-4.5,2.4,9),"look":Vector3(-1.6,1.8,0),"fov":42.0},
		{"id":"right_facade","pos":Vector3(13,5.5,0),"look":Vector3(0,3.3,0),"fov":48.0},
		{"id":"porch_structure","pos":Vector3(2.3,5.4,8.8),"look":Vector3(-1.75,3.0,4.0),"fov":48.0},
		{"id":"porch_eye","pos":Vector3(-1.75,1.65,6.2),"look":Vector3(-1.75,1.8,3.2),"fov":65.0}
	]
	var results: Array[Dictionary] = []
	var failure := false
	for shot in shots:
		var camera := scene.get_node("ReviewCamera") as Camera3D
		camera.fov = shot.fov
		scene.call("_place_camera",shot.pos,shot.look)
		for frame in range(24): await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := output.path_join(shot.id+".png")
		var error := img.save_png(path)
		failure = failure or error != OK
		results.append({"id":shot.id,"file":path,"save_error":error,"camera":str(shot.pos),"look":str(shot.look),"fov":shot.fov,"width":img.get_width(),"height":img.get_height()})
	var report := {"suite":"house06_review_views","shots":results,"meshes":scene.call("_mesh_report"),"lod_state":scene.call("_lod_forced_state"),"world_save_writes":0,"resident_model_calls":0}
	var file := FileAccess.open(output.path_join("evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify({"captures":results.size(),"failed":failure,"output":output}))
	quit(1 if failure else 0)
