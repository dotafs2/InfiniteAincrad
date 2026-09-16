extends Node3D
## Actual EZ-Tree plugin generation. This harness only sets parameters and cameras.
const TreeGenerator = preload("res://addons/ez-tree-godot-port/ez_tree.gd")
var camera: Camera3D
var specimens: Array[Node3D] = []
var descriptions: Array[Dictionary] = []
var heading: Label
var detail: Label
var output := ""
var capture := false
var selected := -1
var orbit := 0.0
var elevation := 0.12

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output = argument.trim_prefix("--out=")
		if argument == "--capture": capture = true
	_setup_stage()
	_build_specimens()
	_show_overview()
	if capture: _capture_all.call_deferred()

func _setup_stage() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("7babc8")
	sky_material.sky_horizon_color = Color("d6e1d3")
	sky_material.ground_horizon_color = Color("d6e1d3")
	sky_material.ground_bottom_color = Color("889075")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e6de")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff3d7")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 180)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("929f72")
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])
	heading = Label.new()
	heading.position = Vector2(40, 28)
	heading.add_theme_font_override("font", font)
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("273a34"))
	ui.add_child(heading)
	detail = Label.new()
	detail.position = Vector2(40, 76)
	detail.add_theme_font_override("font", font)
	detail.add_theme_font_size_override("font_size", 19)
	detail.add_theme_color_override("font_color", Color("364b3b"))
	ui.add_child(detail)

func _build_specimens() -> void:
	var configs: Array[Dictionary] = [
		{"id":"default-oak", "label":"原始默认树", "seed":35729, "changes":{}},
		{"id":"broad-canopy", "label":"宽冠树 · 参数调整", "seed":91627, "changes":{
			"branch_length":PackedFloat32Array([6.8, 3.8, 3.1, 1.5]),
			"branch_angle":PackedFloat32Array([0, 68, 53, 35]),
			"branch_children":PackedInt32Array([8, 5, 3, 0]),
			"branch_start":PackedFloat32Array([0, 0.50, 0.08, 0.12]),
			"leaf_count":22, "leaf_size":0.70, "leaf_size_variance":0.45,
			"leaf_tint":Color8(230, 236, 191)}},
		{"id":"compact-canopy", "label":"紧凑树 · 参数调整", "seed":91633, "changes":{
			"branch_length":PackedFloat32Array([5.5, 2.3, 1.8, 1.0]),
			"branch_angle":PackedFloat32Array([0, 56, 49, 32]),
			"branch_children":PackedInt32Array([7, 5, 3, 0]),
			"branch_radius":PackedFloat32Array([0.29, 0.80, 0.65, 0.95]),
			"leaf_count":20, "leaf_size":0.56, "leaf_size_variance":0.4,
			"leaf_tint":Color8(213, 226, 185)}}
	]
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output.path_join("trees"))
	for config: Dictionary in configs:
		var tree: Node3D = TreeGenerator.new()
		tree.name = config.id.replace("-", "_")
		tree.set("rng_seed", config.seed)
		for property: String in config.changes: tree.set(property, config.changes[property])
		var started := Time.get_ticks_usec()
		add_child(tree)
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		var mesh: ArrayMesh = tree.get_tree_mesh()
		var triangles := 0
		var surface_counts: Array[int] = []
		for surface in mesh.get_surface_count():
			var count := mesh.surface_get_array_index_len(surface) / 3
			triangles += count
			surface_counts.append(count)
		var info := {"id":config.id, "label":config.label, "seed":config.seed,
			"triangles":triangles, "surface_triangles":surface_counts,
			"generation_ms":elapsed, "bounds_size":str(mesh.get_aabb().size),
			"plugin_materials_unchanged":true, "native_wind":true}
		descriptions.append(info)
		if not output.is_empty():
			var saved := PackedScene.new()
			var pack_error := saved.pack(tree)
			assert(pack_error == OK)
			var save_error := ResourceSaver.save(saved, output.path_join("trees/" + config.id + ".tscn"))
			assert(save_error == OK)
		tree.position.x = (specimens.size() - 1) * 14.0
		specimens.append(tree)
		print("EZTREE_GENERATED ", JSON.stringify(info))

func _show_overview() -> void:
	selected = -1
	heading.visible = true
	detail.visible = true
	for tree in specimens: tree.visible = true
	camera.size = 29.0
	camera.position = Vector3(0, 15.0, 58.0)
	camera.look_at(Vector3(0, 6.7, 0))
	heading.text = "EZ-Tree For Godot 0.2.0 | Godot 4.7.2 实渲"
	detail.text = "左：原始默认树    中：宽冠参数    右：紧凑参数    ·    原插件贴图 / 原插件风动材质"

func _show_tree(index: int, closeup := false) -> void:
	selected = index
	heading.visible = not closeup
	detail.visible = not closeup
	for i in specimens.size(): specimens[i].visible = i == index
	var tree := specimens[index]
	var mesh: ArrayMesh = tree.get_tree_mesh()
	var bounds := mesh.get_aabb()
	var target := tree.position + bounds.get_center()
	if closeup:
		target.y = bounds.position.y + bounds.size.y * 0.73
		camera.size = 5.0
	else:
		camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z) / 1.6) * 1.24
	camera.position = target + Vector3(sin(orbit) * cos(elevation), sin(elevation), cos(orbit) * cos(elevation)) * 42.0
	camera.look_at(target)
	heading.text = str(descriptions[index].label)
	detail.text = "EZ-Tree 原插件生成 · %s 三角面 · 双面叶片 / 原生风动" % descriptions[index].triangles

func _save_frame(filename: String) -> void:
	for frame in 16: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output.path_join(filename))
	assert(error == OK)
	print("EZTREE_CAPTURE ", filename)

func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await _save_frame("01-three-tree-overview.png")
	for index in specimens.size():
		orbit = 0.0
		_show_tree(index)
		await _save_frame("0%d-%s.png" % [index + 2, descriptions[index].id])
	_show_tree(1, true)
	await _save_frame("05-leaf-closeup.png")
	var report := {"godot":Engine.get_version_info(), "specimens":descriptions,
		"plugin":"EZ-Tree For Godot 0.2.0", "scope":"isolated visual trial; no town placement, no NPC save changes",
		"shader_edits":0,"paid_generation_calls":0}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if capture: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: _show_overview()
		elif event.keycode >= KEY_2 and event.keycode <= KEY_4:
			orbit = 0.0
			_show_tree(event.keycode - KEY_2)
		elif event.keycode == KEY_ESCAPE: get_tree().quit()
	if selected >= 0 and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit -= event.relative.x * 0.008
		elevation = clampf(elevation + event.relative.y * 0.003, -0.1, 0.8)
		_show_tree(selected)
