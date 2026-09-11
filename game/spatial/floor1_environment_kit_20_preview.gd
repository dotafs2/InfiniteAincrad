extends Node3D

const ENVIRONMENT_KIT := preload("res://assets/floor1/environment_kit_20/Floor1_EnvironmentKit20_Showcase.glb")
const PLANT_WIND_SCRIPT: GDScript = preload("res://spatial/plant_wind.gd")
const WIND_PROFILES := {
	"F1_ancient_oak": "tree_gentle", "F1_birch_grove": "tree_gentle", "F1_cypress_column": "tree_gentle",
	"F1_stone_pine": "tree_gentle", "F1_orchard_apple": "tree_gentle", "F1_young_maple": "tree_gentle",
	"F1_flowering_shrub": "shrub_soft", "F1_berry_bush": "shrub_soft",
	"F1_fern_patch": "ground_breeze", "F1_meadow_grass": "ground_breeze", "F1_wildflower_patch": "ground_breeze",
	"F1_ivy_wall_panel": "climber_subtle", "F1_reed_cluster": "reed_sway",
}

var _capture_dir := ""
var _frames := 0
var _kit: Node3D
var _generated_collisions := 0
var _wind_instances := 0
var _wind_initial_rotations: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	_kit = ENVIRONMENT_KIT.instantiate()
	_kit.name = "Floor1EnvironmentKit20"
	add_child(_kit)
	_apply_basic_wind(_kit)
	_build_collision(_kit, false)
	_setup_ground()
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
	var screenshot_path := _capture_dir.path_join("environment_kit_20_godot.png")
	var error := image.save_png(screenshot_path)
	var counts := _count_imported(_kit)
	var moved_wind_samples := 0
	for wind_node in get_tree().get_nodes_in_group("floor1_plant_wind"):
		if _wind_initial_rotations.has(wind_node.get_instance_id()) and wind_node.rotation.distance_to(_wind_initial_rotations[wind_node.get_instance_id()]) > 0.00001:
			moved_wind_samples += 1
	var evidence := {
		"suite": "floor1_environment_kit_20_preview",
		"asset": "Floor1_EnvironmentKit20_Showcase.glb",
		"style_id": "floor1_environment_kit_20_v1",
		"declared_assets": 20,
		"visual_meshes": counts.visuals,
		"collision_meshes": counts.collisions,
		"unique_asset_ids": counts.asset_ids.size(),
		"asset_identity_source": "imported_visual_node_name",
		"generated_static_bodies": _generated_collisions,
		"plant_groups": 6,
		"wind_controllers": _wind_instances,
		"wind_moved_samples": moved_wind_samples,
		"wind_mode": "category_root_sway_visual_only",
		"screenshot_saved": error == OK,
		"model_decisions": 0,
		"world_state_mutations": 0,
		"fixture": "art_catalogue_preview_only"
	}
	var output := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(evidence, "  ", false, true))
		output.close()
	print(JSON.stringify(evidence))
	get_tree().quit(0 if error == OK and counts.visuals == 20 and counts.collisions == 15 and counts.asset_ids.size() == 20 and _generated_collisions == 15 and _wind_instances == 13 and moved_wind_samples == 13 else 1)


func _apply_basic_wind(root: Node) -> void:
	var visuals: Array[MeshInstance3D] = []
	_collect_wind_visuals(root, visuals)
	for visual in visuals:
		var asset_id := _wind_asset_id(str(visual.name))
		if asset_id.is_empty():
			continue
		var parent := visual.get_parent()
		var original_transform := visual.transform
		var wind_root: Node3D = PLANT_WIND_SCRIPT.new()
		wind_root.name = "Wind_" + asset_id
		wind_root.transform = original_transform
		wind_root.call("configure", str(WIND_PROFILES[asset_id]), float(_wind_instances + 1))
		parent.add_child(wind_root)
		visual.reparent(wind_root, false)
		visual.transform = Transform3D.IDENTITY
		_wind_initial_rotations[wind_root.get_instance_id()] = wind_root.rotation
		_wind_instances += 1


func _wind_asset_id(node_name: String) -> String:
	for asset_id in WIND_PROFILES:
		if node_name.begins_with(str(asset_id)):
			return str(asset_id)
	return ""


func _collect_wind_visuals(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and not node.name.begins_with("COL_"):
		result.append(node)
	for child in node.get_children():
		_collect_wind_visuals(child, result)


func _build_collision(node: Node, inherited_proxy: bool) -> void:
	var is_proxy := inherited_proxy or node.name.begins_with("COL_")
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


func _count_imported(root: Node) -> Dictionary:
	var result := {"visuals": 0, "collisions": 0, "asset_ids": {}}
	_count_node(root, result)
	return result


func _count_node(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		if node.name.begins_with("COL_"):
			result.collisions += 1
		else:
			result.visuals += 1
			var asset_id := str(node.name).split(".")[0]
			if asset_id.begins_with("F1_"):
				result.asset_ids[asset_id] = true
	for child in node.get_children():
		_count_node(child, result)


func _setup_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "PreviewGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 34)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8f826e")
	material.roughness = 0.92
	ground.material_override = material
	ground.position = Vector3(0, -0.03, 5)
	add_child(ground)


func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("233e58")
	sky_material.sky_horizon_color = Color("9bb5c5")
	sky_material.ground_bottom_color = Color("222a2b")
	sky_material.ground_horizon_color = Color("746b59")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "WarmCatalogueSun"
	sun.light_color = Color("ffc08a")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	sun.rotation_degrees = Vector3(-50, -32, 0)
	add_child(sun)


func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "CatalogueCamera"
	camera.fov = 62.0
	camera.current = true
	add_child(camera)
	camera.position = Vector3(24, 19, 37)
	camera.look_at(Vector3(0, 2.8, 5.0), Vector3.UP)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(28, 26)
	panel.size = Vector2(690, 92)
	panel.color = Color(0.025, 0.045, 0.075, 0.84)
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(24, 12)
	title.text = "第一层 · 环境组件基础包 01–20"
	title.add_theme_font_size_override("font_size", 27)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(25, 52)
	subtitle.text = "6 类植物生态位 · 13 个动态样本 · 按类别基础风摆"
	subtitle.modulate = Color("b9d9e7")
	subtitle.add_theme_font_size_override("font_size", 17)
	panel.add_child(subtitle)
