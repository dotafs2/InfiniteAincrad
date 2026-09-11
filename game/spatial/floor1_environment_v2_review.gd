extends Node3D
## Art-only courtyard. No world save, actor, model request or authoritative resource.

const KIT := preload("res://spatial/environment_v2.gd")
var _camera: Camera3D
var _capture_dir := ""
var _instances: Array[Node3D] = []
var _label: Label
var _frame_ms: Array[float] = []
var _yaw := 0.0
var _pitch := -0.16
var _forced_lod := -1
var _benchmark_ms: Array[float] = []
var _wind_demo := false


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--force-lod="): _forced_lod = int(arg.trim_prefix("--force-lod="))
		if arg == "--wind-demo": _wind_demo = true
	_setup_light()
	_build_courtyard()
	_camera = Camera3D.new()
	_camera.fov = 56.0
	_camera.near = 0.08
	add_child(_camera)
	_camera.current = true
	_pose(Vector3(10.5, 5.5, 14.5), Vector3(0, 1.45, -1.8))
	if _wind_demo: _pose(Vector3(-1.45, 1.05, 6.15), Vector3(-3.05, 0.45, 3.75))
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(32, 24)
	_label.add_theme_font_size_override("font_size", 23)
	_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.09, 0.08, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.text = "起始之镇 · 庭园组件 V2\n20 件重制 / 6 类植物 / 枝叶风动"
	if _wind_demo: _label.text = "起始之镇 · 草叶与蕨类风动"
	layer.add_child(_label)
	if not _capture_dir.is_empty():
		call_deferred("_capture_review")


func _process(delta: float) -> void:
	if _frame_ms.size() < 600: _frame_ms.append(delta * 1000.0)
	if _capture_dir.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var direction := Vector3(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		_camera.position += _camera.basis * direction.normalized() * delta * 5.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.45, 1.45)
		_camera.rotation = Vector3(_pitch, _yaw, 0)


func _pose(at: Vector3, target: Vector3) -> void:
	_camera.position = at
	_camera.look_at(target)
	_yaw = _camera.rotation.y
	_pitch = _camera.rotation.x


func _asset(id: String, at: Vector3, yaw: float = 0.0, scale_value: float = 1.0) -> void:
	var item := KIT.create("F1_" + id, true, _forced_lod)
	item.position = at
	item.rotation_degrees.y = yaw
	item.scale = Vector3.ONE * scale_value
	add_child(item)
	_instances.append(item)


func _solid(name_text: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name_text
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mesh.material_override = mat
	mesh.position = at
	add_child(mesh)


func _build_courtyard() -> void:
	_solid("Ground", Vector3(0, -0.18, 0), Vector3(120, 0.30, 120), Color("7a8661"))
	_solid("GardenSoil", Vector3(0, -0.02, 0), Vector3(22, 0.12, 23), Color("626449"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	for row in range(21):
		for col in range(4):
			var x := (col - 1.5) * 0.87 + (0.08 if row % 2 else 0.0)
			var z := (row - 10) * 1.03
			var shade := rng.randf_range(0.94, 1.04)
			_solid("LimestonePaving", Vector3(x, 0.018, z), Vector3(0.85, 0.13, 1.00), Color("b9b69f") * shade)
	for side in [-1, 1]:
		for row in range(24):
			_solid("GardenCoping", Vector3(side * 1.96, 0.115, (row - 11.5) * 0.91), Vector3(0.24, 0.28, 0.88), Color("969d8a"))
	for row in range(3):
		for i in range(24):
			_solid("GardenBoundary", Vector3((i - 11.5) * 0.90 + (0.22 if row % 2 else 0), 0.22 + row * 0.37, -10.9), Vector3(0.885, 0.35, 0.50), Color("a6aa97") * rng.randf_range(.95,1.05))
	_asset("ancient_oak", Vector3(-4.3, 0, -5.8), -18)
	_asset("birch_grove", Vector3(4.3, 0, -7.4), 25)
	_asset("cypress_column", Vector3(7.8, 0, -6.2), 7)
	_asset("stone_pine", Vector3(-8.4, 0, -7.7), 19)
	_asset("orchard_apple", Vector3(9.1, 0, 2.2), 31)
	_asset("young_maple", Vector3(-7.2, 0, 2.2), -35)
	_asset("flowering_shrub", Vector3(-2.9, 0.05, 2.2), 17)
	_asset("berry_bush", Vector3(-3.1, 0.05, -0.1), -12)
	_asset("fern_patch", Vector3(-2.8, 0.05, 4.5), 27, 1.20)
	_asset("meadow_grass", Vector3(-3.8, 0.05, 5.6), -19)
	_asset("wildflower_patch", Vector3(2.9, 0.05, 4.9), 9, 1.18)
	_asset("ivy_wall_panel", Vector3(-.5, 0, -10.55), 0, .72)
	_asset("reed_cluster", Vector3(5.3, 0.05, -3.9), 11)
	_asset("mossy_fallen_log", Vector3(-5.4, 0.05, -1.4), 24)
	_asset("herb_planter", Vector3(3.65, 0.08, 2.35), 0)
	_asset("mossy_boulder_cluster", Vector3(-4.2, 0.05, 3.3), 22)
	_asset("roadside_milestone", Vector3(-2.6, 0.05, 7.5), -12)
	_asset("timber_fence_vine", Vector3(5.5, 0, 5.7), 0)
	_asset("stone_water_trough", Vector3(4.1, 0.05, -2.35), 0)
	_asset("canvas_rest_shelter", Vector3(5.2, 0.05, -0.3), 0)
	# Reuse approved small forms around roots with deterministic variation.
	for i in range(35):
		var side := -1.0 if i % 2 else 1.0
		var x := side * rng.randf_range(2.45, 8.5)
		var z := rng.randf_range(-9.0, 7.0)
		_asset("meadow_grass" if i % 4 else "wildflower_patch", Vector3(x, .05, z), rng.randf_range(-180,180), rng.randf_range(.65,1.10))


func _setup_light() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("6796b4")
	material.sky_horizon_color = Color("c5d7d6")
	material.ground_horizon_color = Color("a3b0a1")
	material.ground_bottom_color = Color("687667")
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c1d5db")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.75
	env.ssao_intensity = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("b3c9c4")
	env.fog_density = 0.002
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	sun.shadow_blur = 1.5
	add_child(sun)


func _capture_review() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	KIT.set_review_time(0.0)
	for i in range(40): await get_tree().process_frame
	var last_us := Time.get_ticks_usec()
	for i in range(120):
		await RenderingServer.frame_post_draw
		var now_us := Time.get_ticks_usec()
		_benchmark_ms.append(float(now_us - last_us) / 1000.0)
		last_us = now_us
	_benchmark_ms.sort()
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var shots := [
		["courtyard", Vector3(10.5,5.5,14.5), Vector3(0,1.45,-1.8)],
		["player_path", Vector3(0.5,1.72,9.6), Vector3(0.3,1.55,-3.8)],
		["botanical_close", Vector3(-1.45,1.05,6.15), Vector3(-3.05,.45,3.75)],
		["planter_close", Vector3(3.2,1.65,4.1), Vector3(3.65,.65,2.35)],
		["canopy", Vector3(-.5,4.0,.0), Vector3(-4.2,5.1,-5.8)],
		["components", Vector3(1.1,2.6,3.9), Vector3(5.1,1.55,-.5)]
	]
	var saved: Array[String] = []
	for shot in shots:
		_pose(shot[1],shot[2])
		_label.text = "起始之镇 · 庭园组件 V2"
		for i in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(shot[0]+".png"))
		if err == OK: saved.append(shot[0])
	_pose(Vector3(3.2,1.65,4.1), Vector3(3.65,.65,2.35))
	_label.visible = false
	var wind_frames: Array[Image] = []
	for t in [0.0, 1.7]:
		KIT.set_review_time(t)
		for i in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var wind_frame := get_viewport().get_texture().get_image()
		wind_frames.append(wind_frame)
		wind_frame.save_png(_capture_dir.path_join("wind_%.1f.png" % t))
	var plant_pixels := _changed_pixels(wind_frames[0], wind_frames[1], Rect2i(180, 200, 1040, 300))
	var board_pixels := _changed_pixels(wind_frames[0], wind_frames[1], Rect2i(500, 650, 400, 40))
	var ids: Dictionary = {}
	var mesh_count := 0
	var shape_count := 0
	for item in _instances:
		ids[item.get_meta("asset_id")] = true
		mesh_count += item.find_children("*", "MeshInstance3D", true, false).size()
		shape_count += item.find_children("*", "CollisionShape3D", true, false).size()
	_frame_ms.sort()
	var evidence := {"suite":"floor1_environment_v2_review", "fixture":"art_courtyard_only", "unique_assets":ids.size(), "instances":_instances.size(), "mesh_lods":mesh_count, "collision_shapes":shape_count, "screenshots":saved, "wind_mode":"UV2_weighted_vertex_shader", "wind_changed_plant_pixels":plant_pixels, "wind_changed_board_pixels":board_pixels, "wind_pixel_threshold":4.0/255.0, "forced_lod":_forced_lod, "rendered_frame_ms_median":_benchmark_ms[60], "rendered_frame_ms_p95":_benchmark_ms[114], "warm_benchmark_frames":120, "draw_calls_with_shadows":draw_calls, "primitives_with_shadows":primitives, "world_mutations":0, "model_calls":0}
	var file := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	print(JSON.stringify(evidence))
	get_tree().quit(0 if ids.size() == 20 and saved.size() == shots.size() and shape_count > 10 and plant_pixels > 100 and board_pixels < 160 else 1)


func _changed_pixels(a: Image, b: Image, area: Rect2i) -> int:
	var changed := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r-cb.r), maxf(absf(ca.g-cb.g), absf(ca.b-cb.b))) > 4.0/255.0:
				changed += 1
	return changed
