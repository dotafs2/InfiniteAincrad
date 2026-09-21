extends Node3D
## Standalone, clearly labelled first-floor terrain and whitebox preview.
##
## White cubes are deliberate placeholders for houses. This scene is a design/scale aid and
## is not loaded by the authoritative resident save or production town scene.

const Layout := preload("res://spatial/starting_city_whitebox_layout.gd")

var evidence: Dictionary = {}
var _materials: Dictionary = {}

func _ready() -> void:
	build()

func build() -> Dictionary:
	name = "StartingCityWhitebox"
	set_meta("whitebox_revision", Layout.REVISION)
	set_meta("reference_scope", Layout.REFERENCE_SCOPE)
	_build_lighting()
	_build_terrain()
	_build_roads()
	_build_city_shell()
	_build_houses()
	_build_labels()
	_build_camera()
	evidence = {
		"revision": Layout.REVISION,
		"reference_scope": Layout.REFERENCE_SCOPE,
		"terrain_bounds": [Layout.TERRAIN_BOUNDS.position.x, Layout.TERRAIN_BOUNDS.position.y, Layout.TERRAIN_BOUNDS.size.x, Layout.TERRAIN_BOUNDS.size.y],
		"zone_count": Layout.ZONES.size(),
		"zone_ids": _zone_ids(),
		"authored_road_count": Layout.AUTHORED_ROADS.size(),
		"macro_road_count": Layout.MACRO_ROADS.size(),
		"road_count": Layout.all_roads().size(),
		"house_count": Layout.HOUSES.size(),
		"resident_house_count": 10,
		"infill_house_count": Layout.HOUSES.size() - 10,
		"whitebox_house_material": "white",
		"navigation_source": "living_quarter_layout.json authored road polylines + explicit macro connectors",
		"production_world_loaded": false,
		"model_calls": 0,
	}
	return evidence

func snapshot() -> Dictionary:
	return evidence.duplicate(true)

func _material(key: String, color: Color, roughness := 0.82) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	_materials[key] = result
	return result

func _box(parent: Node, node_name: String, position: Vector3, size: Vector3, material: Material, bevel := 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WhiteboxEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#b9c8d2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e9f1f5")
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "WhiteboxSun"
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_terrain() -> void:
	var terrain := Node3D.new()
	terrain.name = "TerrainZones"
	add_child(terrain)
	_box(terrain, "TerrainBase", Vector3(0, -2.3, 25), Vector3(280, 4.0, 310), _material("terrain_base", Color("#667264")))
	for raw_zone in Layout.ZONES:
		var zone: Dictionary = raw_zone
		var center: Vector2 = zone["center"]
		var size: Vector2 = zone["size"]
		var height := float(zone["height"])
		var slab := _box(terrain, "Zone_%s" % zone["id"], Vector3(center.x, height - 0.55, center.y), Vector3(size.x, 1.1, size.y), _material("zone_" + zone["id"], zone["color"]))
		slab.set_meta("zone_id", zone["id"])
		if zone["id"] == "wetland":
			var water := _box(terrain, "WaterSurface", Vector3(center.x, height + 0.04, center.y), Vector3(size.x - 8.0, 0.08, size.y - 8.0), _material("water", Color("#73b6c5", 0.82)))
			water.transparency = 0.12
		if zone["id"] == "labyrinth":
			for i in range(6):
				_box(terrain, "LabyrinthRidge_%02d" % i, Vector3(center.x - 52.0 + i * 20.0, height + 2.2, center.y), Vector3(8.0, 5.0, size.y - 8.0), _material("labyrinth_ridge", Color("#545863")))

func _build_roads() -> void:
	var roads := Node3D.new()
	roads.name = "Roads_AuthoredAndMacro"
	add_child(roads)
	for raw_road in Layout.all_roads():
		var road: Dictionary = raw_road
		var points: Array[Vector2] = Layout.vec2_points(road["points"])
		var width := float(road["width"])
		var road_group := Node3D.new()
		road_group.name = "Road_%s" % road["id"]
		road_group.set_meta("road_id", road["id"])
		road_group.set_meta("source", "authored_living_quarter" if Layout.AUTHORED_ROADS.has(road) else "macro_whitebox")
		roads.add_child(road_group)
		for index in range(points.size() - 1):
			var a := points[index]
			var b := points[index + 1]
			var midpoint := (a + b) * 0.5
			var length := a.distance_to(b)
			var strip := _box(road_group, "Segment_%02d" % index, Vector3(midpoint.x, 0.35, midpoint.y), Vector3(width, 0.18, length), _material("road", Color("#d5d7d2")))
			strip.rotation.y = -atan2(b.x - a.x, b.y - a.y)
			var centerline := _box(road_group, "CenterMark_%02d" % index, Vector3(midpoint.x, 0.47, midpoint.y), Vector3(0.22, 0.035, maxf(1.0, length - 1.0)), _material("road_mark", Color("#e9c45b")))
			centerline.rotation.y = strip.rotation.y

func _build_city_shell() -> void:
	var shell := Node3D.new()
	shell.name = "TownOfBeginningsShell"
	add_child(shell)
	var wall_material := _material("wall", Color("#e8e5dc"))
	var radius_x := 72.0
	var radius_z := 54.0
	var centre := Vector2(0, -35)
	for index in range(17):
		var angle_a := PI * (float(index) / 16.0)
		var angle_b := PI * (float(index + 1) / 16.0)
		var a := centre + Vector2(cos(angle_a) * radius_x, sin(angle_a) * radius_z)
		var b := centre + Vector2(cos(angle_b) * radius_x, sin(angle_b) * radius_z)
		var midpoint := (a + b) * 0.5
		var length := a.distance_to(b)
		var wall := _box(shell, "Wall_%02d" % index, Vector3(midpoint.x, 1.4, midpoint.y), Vector3(2.8, 2.8, length), wall_material)
		wall.rotation.y = -atan2(b.x - a.x, b.y - a.y)
	# A low wall around the straight southern edge, with a deliberately obvious gate gap.
	for x in [-64.0, -52.0, -40.0, -28.0, 28.0, 40.0, 52.0, 64.0]:
		_box(shell, "SouthWall_%s" % str(x), Vector3(x, 1.4, -89.0), Vector3(10.0, 2.8, 2.8), wall_material)

func _build_houses() -> void:
	var houses := Node3D.new()
	houses.name = "WhiteHouseCubes"
	add_child(houses)
	var white := _material("house_white", Color("#f7f7f2"), 0.65)
	var pad_colors := {"city_core": Color("#6f8aa0"), "outer_meadow": Color("#8eaa72")}
	for raw_house in Layout.HOUSES:
		var house: Dictionary = raw_house
		var at: Array = house["at"]
		var position := Vector3(float(at[0]), 3.0, float(at[1]))
		var id := String(house["id"])
		var cube := _box(houses, "House_%s" % id.replace(":", "_"), position, Vector3(8.0, 6.0, 8.0), white)
		cube.set_meta("resident_id", id)
		cube.set_meta("whitebox", true)
		var zone_id := String(house["zone"])
		_box(houses, "HousePad_%s" % id.replace(":", "_"), Vector3(float(at[0]), 0.59, float(at[1])), Vector3(10.0, 0.12, 10.0), _material("pad_" + zone_id, pad_colors.get(zone_id, Color("#8b9a8d"))))

func _label(parent: Node, text: String, position: Vector3, color := Color("#24313b"), font_size := 32) -> Label3D:
	var label := Label3D.new()
	label.name = "Label_" + text.replace(" ", "_").replace("/", "_")
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 8
	label.outline_modulate = Color("#f4f0df")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _build_labels() -> void:
	var labels := Node3D.new()
	labels.name = "ZoneAndRoadLabels"
	add_child(labels)
	for raw_zone in Layout.ZONES:
		var zone: Dictionary = raw_zone
		var center: Vector2 = zone["center"]
		_label(labels, String(zone["label"]), Vector3(center.x, float(zone["height"]) + 2.8, center.y), Color("#1d2932"), 34)
	_label(labels, "WHITEBOX · NORTH ↑", Vector3(-132, 8.0, -119), Color("#17232a"), 28)
	_label(labels, "ROADS FOLLOW AUTHORED PCG CENTRELINES", Vector3(-132, 7.0, 167), Color("#17232a"), 26)
	for raw_house in Layout.HOUSES:
		var house: Dictionary = raw_house
		var at: Array = house["at"]
		_label(labels, String(house["label"]), Vector3(float(at[0]), 7.0, float(at[1])), Color("#4b3a2f"), 18)

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "WhiteboxOverviewCamera"
	camera.position = Vector3(210, 255, 260)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 20), Vector3.UP)
	camera.fov = 48.0
	add_child(camera)

func _zone_ids() -> Array:
	var result: Array = []
	for zone in Layout.ZONES:
		result.append(zone["id"])
	return result
