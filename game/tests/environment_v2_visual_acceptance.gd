extends SceneTree
## Actual rendered visibility at both sides of every LOD boundary for all 20 IDs.
const KIT := preload("res://spatial/environment_v2.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(480, 480)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("293842")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_energy = 0.85
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 150
	scene.add_child(camera)
	camera.current = true
	var results: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	for id in KIT.IDS:
		var item := KIT.create("F1_" + id)
		scene.add_child(item)
		KIT.set_review_time(0.0)
		var mesh_node: MeshInstance3D = item.find_children("*", "MeshInstance3D", true, false)[0]
		var bounds := mesh_node.custom_aabb
		var center := bounds.get_center()
		camera.size = maxf(bounds.size.x, bounds.size.y) * 1.35 + 0.2
		var ranges := [22.0,48.0] if KIT.IDS.find(id) < 6 else [12.0,28.0]
		for boundary in ranges:
			for offset in [-0.25,0.0,0.25]:
				camera.position = center + Vector3(0,0,boundary + offset)
				camera.look_at(center)
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				var frame_image := root.get_texture().get_image()
				var background := frame_image.get_pixel(0,0)
				var visible_samples := 0
				for y in range(0,frame_image.get_height(),6):
					for x in range(0,frame_image.get_width(),6):
						var pixel := frame_image.get_pixel(x,y)
						if absf(pixel.r-background.r)+absf(pixel.g-background.g)+absf(pixel.b-background.b) > 0.08: visible_samples += 1
				var result := {"id":id,"distance":boundary+offset,"visible_samples":visible_samples}
				results.append(result)
				if visible_samples < 20: failures.append(result)
		scene.remove_child(item)
		item.free()
	var evidence := {"suite":"environment_v2_lod_render_boundaries","cases":results.size(),"failed":failures.size(),"failures":failures,"results":results,"world_mutations":0}
	var folder := "res://../docs/validation/floor1_environment_v2_2026-09-11"
	var path := ProjectSettings.globalize_path(folder).simplify_path().path_join("lod_boundaries.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	print(JSON.stringify({"suite":evidence.suite,"cases":results.size(),"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() and results.size() == 120 else 1)
