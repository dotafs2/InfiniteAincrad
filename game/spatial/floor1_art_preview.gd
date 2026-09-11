extends Node3D

const HERO_KIT := preload("res://assets/floor1/StartingTown_Floor1_HeroKit.glb")

var _capture_dir := ""
var _frames := 0
var _kit: Node3D
var _generated_collisions := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_kit = HERO_KIT.instantiate()
	_kit.name = "StartingTownFloor1HeroKit"
	add_child(_kit)
	_build_collision(_kit, false)
	_setup_environment()
	_setup_camera()
	_setup_ui()


func _process(_delta: float) -> void:
	if _capture_dir.is_empty():
		return
	_frames += 1
	if _frames < 8:
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var image := get_viewport().get_texture().get_image()
	var screenshot_path := _capture_dir.path_join("floor1_godot.png")
	var error := image.save_png(screenshot_path)
	var counts := _count_imported(_kit)
	var physical := _physical_checks()
	var evidence := {
		"suite": "floor1_art_preview",
		"asset": "StartingTown_Floor1_HeroKit.glb",
		"style_id": "floor1_starting_town_hero_kit_v1",
		"screenshot_saved": error == OK,
		"mesh_instances": counts.meshes,
		"collision_meshes": counts.collisions,
		"generated_static_bodies": _generated_collisions,
		"walkable_ground_samples": physical.ground_samples,
		"gate_clear_at_resident_height": physical.gate_clear,
		"walkable_gate_declared_m": [4.8, 6.6],
		"model_decisions": 0,
		"world_state_mutations": 0,
		"fixture": "art_preview_only"
	}
	var output := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(evidence, "  ", false, true))
		output.close()
	print(JSON.stringify(evidence))
	get_tree().quit(0 if error == OK and counts.meshes >= 25 and counts.collisions >= 5 and _generated_collisions >= 5 and physical.ground_samples == 5 and physical.gate_clear else 1)


func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("355d82")
	sky_material.sky_horizon_color = Color("abc5d8")
	sky_material.ground_bottom_color = Color("253235")
	sky_material.ground_horizon_color = Color("8f8068")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.light_color = Color("ffc08a")
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.rotation_degrees = Vector3(-48, -28, 0)
	add_child(sun)


func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "HeroCamera"
	camera.fov = 60.0
	camera.current = true
	add_child(camera)
	camera.position = Vector3(0.8, 5.4, 12.5)
	camera.look_at(Vector3(0.0, 4.9, -17.2), Vector3.UP)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(28, 26)
	panel.size = Vector2(640, 88)
	panel.color = Color(0.025, 0.045, 0.075, 0.82)
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(24, 13)
	title.text = "第一层 · 起始城镇英雄街角"
	title.add_theme_font_size_override("font_size", 27)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(25, 50)
	subtitle.text = "原创模块化美术样板 · Blender 5.2 LTS → Godot 4.7.2"
	subtitle.modulate = Color("b9d9e7")
	subtitle.add_theme_font_size_override("font_size", 17)
	panel.add_child(subtitle)


func _count_imported(root: Node) -> Dictionary:
	var result := {"meshes": 0, "collisions": 0}
	for child in root.get_children():
		_count_node(child, result)
	return result


func _count_node(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		result.meshes += 1
		if node.name.begins_with("COL_"):
			result.collisions += 1
	for child in node.get_children():
		_count_node(child, result)


func _build_collision(node: Node, inherited_proxy: bool) -> void:
	var is_proxy := inherited_proxy or node.name.to_lower().contains("col_")
	if is_proxy and node is GeometryInstance3D:
		node.visible = false
	if is_proxy and node is MeshInstance3D and node.mesh != null:
		var body := StaticBody3D.new()
		body.name = "GeneratedCollision_" + node.name
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
		body.global_transform = node.global_transform
		_generated_collisions += 1
	for child in node.get_children():
		_build_collision(child, is_proxy)


func _physical_checks() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var hits := 0
	for z in [2.0, -5.0, -12.0, -20.0, -26.0]:
		var down := PhysicsRayQueryParameters3D.create(Vector3(0, 3, z), Vector3(0, -1, z))
		if not space.intersect_ray(down).is_empty():
			hits += 1
	var through_gate := PhysicsRayQueryParameters3D.create(Vector3(0, 1.4, -24.5), Vector3(0, 1.4, -33.5))
	return {"ground_samples": hits, "gate_clear": space.intersect_ray(through_gate).is_empty()}
