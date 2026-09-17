extends SceneTree
## Offline asset gallery. No residents, world state, API calls or production claims.

var stage: Node3D
var camera: Camera3D
var report: Dictionary = {"renderer": "Godot viewport", "live_world": false, "assets": []}
var output: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = ProjectSettings.globalize_path("res://captures")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 900)
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b8c4c6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6e2e0")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("fff2d7")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(200, 0.10, 200)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.055
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("78867d")
	floor_mat.roughness = 1.0
	floor_node.material_override = floor_mat
	stage.add_child(floor_node)
	var ids := ["baking_oven", "flour_sack", "bread_loaf"]
	var positions := [Vector3(-0.72,0,0), Vector3(0.5,0,0.08), Vector3(1.10,0,0.08)]
	var expected := [Vector3(1,1,.76), Vector3(.24,.30,.24), Vector3(.26,.15,.26)]
	for index in ids.size():
		var packed: PackedScene = load("res://assets/overnight20260918/%s.tscn" % ids[index])
		if packed == null:
			push_error("Cannot load prefab: " + ids[index])
			quit(1)
			return
		var visual: Node3D = packed.instantiate()
		stage.add_child(visual)
		var record := {"id":ids[index], "triangles":0, "mesh_instances":0, "scripts":0, "collision_objects":0, "materials":0}
		var boxes: Array[AABB] = []
		_measure(visual, visual, boxes, record)
		var total: AABB = boxes[0]
		for box in boxes.slice(1):
			total = total.merge(box)
		record["bounds_min"] = [total.position.x,total.position.y,total.position.z]
		record["bounds_size"] = [total.size.x,total.size.y,total.size.z]
		record["bounds_ok"] = total.size.distance_to(expected[index]) < .001 and absf(total.position.y) < .001
		record["pure_visual"] = record.scripts == 0 and record.collision_objects == 0
		report.assets.append(record)
		visual.position = positions[index]
		var label := Label3D.new()
		label.text = ["REUSED HEARTH\n1.00 x 1.00 x 0.76 m", "FLOUR UNIT\n0.24 x 0.30 x 0.24 m", "DARK BREAD\n0.26 x 0.15 x 0.26 m"][index]
		label.position = positions[index] + Vector3(0,-.005,.70)
		label.font_size = 30
		label.pixel_size = .0015
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		stage.add_child(label)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	stage.add_child(camera)
	camera.position = Vector3(2.2,2.1,4.8)
	camera.look_at(Vector3(0,.40,0))
	camera.current = true
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var title := Label.new()
	title.text = "AINCRAD / FLOOR 01     BAKING ASSETS\nGodot real-time asset review / 18 Sep 2026 / no live-world state"
	title.position = Vector2(36,28)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color",Color("233e35"))
	layer.add_child(title)
	await _capture("01-godot-front.png")
	camera.position = Vector3(-2.5,1.9,-4.5)
	camera.look_at(Vector3(0,.45,0))
	await _capture("02-godot-rear.png")
	camera.size = 1.7
	camera.position = Vector3(-.05,1.30,2.1)
	camera.look_at(Vector3(-.72,.50,0))
	await _capture("03-godot-oven-close.png")
	camera.size = .70
	camera.position = Vector3(1.48,.42,.9)
	camera.look_at(Vector3(1.10,.06,.08))
	await _capture("04-godot-bread-close.png")
	var ok := true
	for record in report.assets:
		ok = ok and record.bounds_ok and record.pure_visual
	report["ok"] = ok
	var file := FileAccess.open(output.path_join("godot-import-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print(JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0 if ok else 1)

func _capture(filename: String) -> void:
	for index in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(filename))
	if error != OK:
		push_error("Screenshot save failed: " + filename)

func _measure(node: Node, origin: Node3D, boxes: Array[AABB], record: Dictionary) -> void:
	if node.get_script() != null:
		record.scripts += 1
	if node is CollisionObject3D:
		record.collision_objects += 1
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(origin.global_transform.affine_inverse() * node.global_transform * node.get_aabb())
		record.mesh_instances += 1
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			record.triangles += indices.size() / 3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size() / 3
			record.materials += 1 if node.mesh.surface_get_material(surface) != null else 0
	for child in node.get_children():
		_measure(child,origin,boxes,record)
