extends SceneTree
## Actual rendered LOD boundaries plus physical exterior/porch ray tests.
const HOUSE := preload("res://spatial/residence_component.gd")
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(480,480)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("293842")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_energy = .85
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 150
	scene.add_child(camera)
	camera.current = true
	var results: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	var physics_results: Array[Dictionary] = []
	for variant in range(1,6):
		var item := Node3D.new()
		item.set_script(HOUSE)
		item.variant = variant
		scene.add_child(item)
		var bounds: AABB = item.get_meta("bounds")
		var center := bounds.get_center()
		camera.size = maxf(bounds.size.x,bounds.size.y)*1.35+.2
		for boundary in [32.0,70.0]:
			for offset in [-.25,0.0,.25]:
				camera.position = center+Vector3(0,0,boundary+offset)
				camera.look_at(center)
				for frame in range(4): await process_frame
				await RenderingServer.frame_post_draw
				var frame_image := root.get_texture().get_image()
				var background := frame_image.get_pixel(0,0)
				var visible_samples := 0
				for y in range(0,frame_image.get_height(),6):
					for x in range(0,frame_image.get_width(),6):
						var pixel := frame_image.get_pixel(x,y)
						if absf(pixel.r-background.r)+absf(pixel.g-background.g)+absf(pixel.b-background.b)>.08: visible_samples+=1
				var result := {"variant":variant,"distance":boundary+offset,"visible_samples":visible_samples}
				results.append(result)
				if visible_samples<100: failures.append(result)
		await physics_frame
		await physics_frame
		var space := scene.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.3,8),Vector3(0,1.3,0)))
		physics_results.append({"variant":variant,"closed_exterior_blocks_ray":not hit.is_empty()})
		if hit.is_empty(): failures.append({"variant":variant,"physics":"exterior_missing"})
		if variant==3 or variant==4:
			var x := 3.9 if variant==3 else 1.4
			var a := Vector3(x,1.3,3.45 if variant==3 else 4.8)
			var b := Vector3(x,1.3,2.0 if variant==3 else 3.3)
			var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b)).is_empty()
			physics_results.append({"variant":variant,"porch_gap_clear":clear})
			if not clear: failures.append({"variant":variant,"physics":"porch_blocked"})
		scene.remove_child(item)
		item.free()
	var evidence := {"suite":"residences_lod_and_collision","render_cases":results.size(),"physics_cases":physics_results.size(),"failed":failures.size(),"failures":failures,"results":results,"physics":physics_results,"save_writes":0}
	var path := ProjectSettings.globalize_path("res://../docs/validation/floor1_residences_2026-09-11/lod_and_collision.json").simplify_path()
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	print(JSON.stringify({"suite":evidence.suite,"render_cases":results.size(),"physics_cases":physics_results.size(),"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() and results.size()==30 else 1)
