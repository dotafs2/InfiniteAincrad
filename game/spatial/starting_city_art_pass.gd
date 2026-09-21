extends Node3D

## Art dressing pass for the first-floor Starting City study.
##
## This scene is intentionally separate from the production town controller. It composes
## imported modular assets with small procedural meshes, then places original primitive
## residents carrying hand props so scale, silhouettes and attachment points are reviewable.

const Layout := preload("res://spatial/starting_city_whitebox_layout.gd")
const WHITEBOX := preload("res://scenes/starting_city_whitebox.tscn")
const RESIDENT := preload("res://spatial/trial_resident.gd")

const HOUSE_VARIANTS := [
	"res://assets/floor1/modular_houses_20260916/01_hearth_cottage.glb",
	"res://assets/floor1/modular_houses_20260916/02_market_house.glb",
	"res://assets/floor1/modular_houses_20260916/03_corner_turret.glb",
]
const PROPS := {
	"fountain": "res://assets/floor1/plaza_fountain_20260916/F1_plaza_fountain.glb",
	"stall": "res://assets/floor1/demo_prefabs/market-stall.tscn",
	"barrel": "res://assets/floor1/demo_prefabs/market-barrel.tscn",
	"crate": "res://assets/floor1/demo_prefabs/produce-crate.tscn",
	"lantern": "res://assets/floor1/demo_prefabs/lantern.tscn",
	"anvil": "res://assets/floor1/demo_prefabs/anvil.tscn",
	"forge": "res://assets/floor1/demo_prefabs/forge.tscn",
	"weapon_rack": "res://assets/floor1/demo_prefabs/weapon_rack.tscn",
	"cart": "res://assets/floor1/demo_prefabs/wooden-handcart.tscn",
	"hearth": "res://assets/floor1/demo_prefabs/hearth.tscn",
	"shelf": "res://assets/floor1/demo_prefabs/shelf.tscn",
}

var evidence: Dictionary = {}
var _materials: Dictionary = {}
var _asset_count := 0
var _procedural_count := 0
var _collision_count := 0
var _resident_loadouts: Dictionary = {}
var _capture_dir := ""
var _capture_frames := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("_build_art_pass")

func _process(_delta: float) -> void:
	if _capture_dir.is_empty() or evidence.is_empty():
		return
	_capture_frames += 1
	if _capture_frames < 8:
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var screenshot_path := _capture_dir.path_join("starting_city_art.png")
	var viewport_texture := get_viewport().get_texture()
	var error := ERR_UNAVAILABLE
	if DisplayServer.get_name() != "headless" and viewport_texture != null:
		var image := viewport_texture.get_image()
		if image != null:
			error = image.save_png(screenshot_path)
	var report := evidence.duplicate(true)
	report["screenshot_saved"] = error == OK
	var output := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  ", false, true))
		output.close()
	print(JSON.stringify(report))
	get_tree().quit(0)

func _build_art_pass() -> void:
	var whitebox := WHITEBOX.instantiate()
	whitebox.name = "StartingCityWhitebox"
	add_child(whitebox)
	await get_tree().process_frame
	var cubes := whitebox.get_node_or_null("WhiteHouseCubes")
	if cubes != null:
		cubes.visible = false
	var labels := whitebox.get_node_or_null("ZoneAndRoadLabels")
	if labels != null:
		labels.visible = false

	var dressing := Node3D.new()
	dressing.name = "StartingCityArtDressing"
	add_child(dressing)
	_build_art_houses(dressing)
	_build_black_iron_palace(dressing)
	_build_plaza(dressing)
	_build_market_and_smithy(dressing)
	_build_lantern_posts(dressing)
	_build_gate_and_signs(dressing)
	_build_residents(dressing)
	_build_camera_and_ui()
	evidence = {
		"suite": "starting_city_art_pass",
		"revision": "starting-city-art-20260922-v1",
		"reference_scope": "Town of Beginnings-inspired first-floor dressing; not a canon map recreation",
		"source_motifs": ["southern town", "central plaza", "Black Iron Palace", "market streets", "smithy", "forest/lake/labyrinth approaches"],
		"imported_asset_instances": _asset_count,
		"procedural_asset_instances": _procedural_count,
		"generated_collision_bodies": _collision_count,
		"resident_count": _resident_loadouts.size(),
		"resident_loadouts": _resident_loadouts.duplicate(true),
		"model_calls": 0,
		"world_state_mutations": 0,
		"production_world_loaded": false,
	}
	print(JSON.stringify(evidence))

func get_evidence() -> Dictionary:
	return evidence.duplicate(true)

func _build_art_houses(parent: Node3D) -> void:
	var houses := Node3D.new()
	houses.name = "ArtHouses"
	parent.add_child(houses)
	for index in range(Layout.HOUSES.size()):
		var data: Dictionary = Layout.HOUSES[index]
		var at: Array = data["at"]
		var house := _spawn_asset(houses, HOUSE_VARIANTS[index % HOUSE_VARIANTS.size()], Vector3(float(at[0]), 0.0, float(at[1])), 0.95 + float(index % 3) * 0.06)
		if house == null:
			continue
		house.name = "HouseArt_%s" % String(data["id"]).replace(":", "_")
		house.set_meta("resident_id", data["id"])
		house.set_meta("art_role", data["label"])
		_label(parent, String(data["label"]), Vector3(float(at[0]), 8.2, float(at[1])), Color("f4e8cf"), 15)

func _build_black_iron_palace(parent: Node3D) -> void:
	var palace := Node3D.new()
	palace.name = "BlackIronPalace_Procedural"
	palace.position = Vector3(0.0, 0.0, -55.0)
	parent.add_child(palace)
	var stone := _material("palace_stone", Color("262c37"), 0.6)
	var iron := _material("palace_iron", Color("111722"), 0.42)
	_solid_box(palace, "PalaceNave", Vector3(0, 5.0, 0), Vector3(20, 10, 13), stone)
	_solid_box(palace, "PalaceSteps", Vector3(0, 0.55, 7.0), Vector3(27, 1.1, 8), stone)
	for side in [-1.0, 1.0]:
		for depth in [-4.5, 4.5]:
			var tower := MeshInstance3D.new()
			var tower_mesh := CylinderMesh.new()
			tower_mesh.top_radius = 2.2
			tower_mesh.bottom_radius = 2.8
			tower_mesh.height = 16.0
			tower.mesh = tower_mesh
			tower.position = Vector3(side * 8.0, 8.0, depth)
			tower.material_override = stone
			palace.add_child(tower)
			_procedural_count += 1
			var roof := MeshInstance3D.new()
			var roof_mesh := CylinderMesh.new()
			roof_mesh.top_radius = 0.0
			roof_mesh.bottom_radius = 3.5
			roof_mesh.height = 6.0
			roof.mesh = roof_mesh
			roof.position = Vector3(side * 8.0, 19.0, depth)
			roof.material_override = iron
			palace.add_child(roof)
			_procedural_count += 1
	for window_x in [-5.5, -2.0, 2.0, 5.5]:
		_box(palace, "Window_%s" % window_x, Vector3(window_x, 5.6, -6.62), Vector3(1.25, 3.2, 0.18), _material("window", Color("6da0b2"), 0.25))
	_label(parent, "BLACK IRON PALACE", Vector3(0, 23.0, -55), Color("d8d1b4"), 26)

func _build_plaza(parent: Node3D) -> void:
	var fountain := _spawn_asset(parent, PROPS["fountain"], Vector3(0, 0.2, -55), 0.85)
	if fountain != null:
		fountain.name = "CentralPlazaFountain"
	for position in [Vector3(-18, 0, -68), Vector3(18, 0, -68), Vector3(-18, 0, -42), Vector3(18, 0, -42)]:
		_spawn_asset(parent, PROPS["lantern"], position, 1.15)
	for angle in range(0, 360, 45):
		var radians := deg_to_rad(float(angle))
		var tree := _tree_cluster(parent, Vector3(cos(radians) * 24.0, 0.0, -55.0 + sin(radians) * 18.0), 1.0 + float(angle % 3) * 0.08)
		tree.name = "PlazaTree_%03d" % angle

func _build_market_and_smithy(parent: Node3D) -> void:
	var market := Node3D.new()
	market.name = "MarketAndSmithy"
	parent.add_child(market)
	for position in [Vector3(-34, 0, -48), Vector3(-24, 0, -48), Vector3(-34, 0, -38)]:
		_spawn_asset(market, PROPS["stall"], position, 1.0)
	for position in [Vector3(-40, 0, -51), Vector3(-28, 0, -51), Vector3(-40, 0, -41), Vector3(-28, 0, -41)]:
		_spawn_asset(market, PROPS["barrel"], position, 0.9)
		_spawn_asset(market, PROPS["crate"], position + Vector3(1.2, 0.0, 0.4), 0.7)
	var smithy := Node3D.new()
	smithy.name = "SmithyYard"
	smithy.position = Vector3(22, 0, -38)
	market.add_child(smithy)
	_spawn_asset(smithy, PROPS["forge"], Vector3(-2, 0, 0), 1.0)
	_spawn_asset(smithy, PROPS["anvil"], Vector3(2, 0, 0), 0.8)
	_spawn_asset(smithy, PROPS["weapon_rack"], Vector3(0, 0, 2.8), 1.0)
	_spawn_asset(smithy, PROPS["shelf"], Vector3(-3.0, 0, 2.6), 0.9)
	for position in [Vector3(-1.4, 0, -1.4), Vector3(1.4, 0, -1.4)]:
		_spawn_asset(smithy, PROPS["lantern"], position, 0.9)

func _build_lantern_posts(parent: Node3D) -> void:
	for position in [Vector3(-9, 0, -91), Vector3(9, 0, -91), Vector3(-45, 0, -73), Vector3(45, 0, -73), Vector3(-45, 0, -7), Vector3(45, 0, -7)]:
		var post := Node3D.new()
		post.position = position
		parent.add_child(post)
		_box(post, "Post", Vector3(0, 1.6, 0), Vector3(0.16, 3.2, 0.16), _material("lamp_post", Color("4b3526")))
		_spawn_asset(post, PROPS["lantern"], Vector3(0, 3.1, 0), 0.75)
		_procedural_count += 1

func _build_gate_and_signs(parent: Node3D) -> void:
	var gate := Node3D.new()
	gate.name = "SouthGateArt"
	parent.add_child(gate)
	var stone := _material("gate_stone", Color("a99f8e"), 0.85)
	_solid_box(gate, "GateLeft", Vector3(-15, 5.5, -101), Vector3(7, 11, 5), stone)
	_solid_box(gate, "GateRight", Vector3(15, 5.5, -101), Vector3(7, 11, 5), stone)
	_solid_box(gate, "GateLintel", Vector3(0, 10.5, -101), Vector3(23, 3, 5), stone)
	_label(parent, "TOWN OF BEGINNINGS", Vector3(0, 14.5, -101), Color("f0dfb9"), 21)
	_label(parent, "SOUTH GATE · SAFE ZONE", Vector3(0, 3.5, -112), Color("e8d6ae"), 15)

func _build_residents(parent: Node3D) -> void:
	var specs := [
		{"id": "art_guard", "at": Vector3(-7, 0, -72), "shirt": Color("4d657d"), "hair": Color("2c2530"), "right": "sword", "left": "shield"},
		{"id": "art_smith", "at": Vector3(24, 0, -33), "shirt": Color("7a4d3d"), "hair": Color("4b3629"), "right": "hammer", "left": "lantern"},
		{"id": "art_scout", "at": Vector3(-58, 0, -18), "shirt": Color("486c55"), "hair": Color("765b3c"), "right": "spear", "left": "bag"},
		{"id": "art_healer", "at": Vector3(-24, 0, 24), "shirt": Color("8b6c9d"), "hair": Color("d1b079"), "right": "potion", "left": "book"},
	]
	for spec in specs:
		var resident := RESIDENT.new()
		resident.name = "ArtResident_%s" % spec["id"]
		resident.shirt_color = spec["shirt"]
		resident.hair_color = spec["hair"]
		resident.position = spec["at"]
		parent.add_child(resident)
		resident.set_loadout(spec["right"], spec["left"])
		resident.set_meta("art_loadout", {"right": spec["right"], "left": spec["left"]})
		_resident_loadouts[spec["id"]] = {"right": spec["right"], "left": spec["left"]}
		_label(parent, "%s · %s / %s" % [spec["id"], spec["right"], spec["left"]], spec["at"] + Vector3(0, 2.8, 0), Color("f4ead2"), 12)

func _tree_cluster(parent: Node3D, position: Vector3, scale_value: float) -> Node3D:
	var tree := Node3D.new()
	tree.position = position
	tree.scale = Vector3.ONE * scale_value
	parent.add_child(tree)
	_box(tree, "Trunk", Vector3(0, 2.2, 0), Vector3(0.65, 4.4, 0.65), _material("plaza_trunk", Color("5a3b2b")))
	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 2.1
	canopy_mesh.height = 3.3
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0, 5.1, 0)
	canopy.material_override = _material("plaza_leaf", Color("406c55"))
	tree.add_child(canopy)
	_procedural_count += 2
	return tree

func _spawn_asset(parent: Node3D, path: String, position: Vector3, scale_value := 1.0) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var instance := packed.instantiate()
	instance.position = position
	instance.scale = Vector3.ONE * scale_value
	parent.add_child(instance)
	_asset_count += 1
	return instance

func _solid_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := _box(parent, node_name, position, size, material)
	var body := StaticBody3D.new()
	body.name = "Collision_%s" % node_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = position
	body.add_child(shape)
	parent.add_child(body)
	_collision_count += 1
	return mesh

func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	_procedural_count += 1
	return mesh_instance

func _label(parent: Node3D, text: String, position: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = "Label_" + text.replace(" ", "_").replace("/", "_")
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 6
	label.outline_modulate = Color("1b2028")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _material(key: String, color: Color, roughness := 0.82) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_materials[key] = material
	return material

func _build_camera_and_ui() -> void:
	var camera := Camera3D.new()
	camera.name = "ArtPassCamera"
	camera.position = Vector3(42, 22, 10)
	camera.look_at_from_position(camera.position, Vector3(0, 5, -48), Vector3.UP)
	camera.fov = 55.0
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(700, 98)
	panel.color = Color(0.025, 0.045, 0.075, 0.84)
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(22, 12)
	title.text = "TOWN OF BEGINNINGS · ART PASS V1"
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(23, 52)
	subtitle.text = "Procedural palace + modular houses + hand-prop loadout preview"
	subtitle.modulate = Color("c8e1ea")
	subtitle.add_theme_font_size_override("font_size", 16)
	panel.add_child(subtitle)
