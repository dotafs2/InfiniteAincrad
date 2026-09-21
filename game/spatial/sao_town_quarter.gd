extends Node3D
## A small, original procedural town study inspired by the broad composition of Aincrad's
## first-floor starting city: a fortified edge, a circular arrival plaza, radial streets,
## and readable service landmarks. It intentionally uses primitive geometry and no copied art.

const LAYOUT_PATH := "res://spatial/sao_town_quarter_layout.json"
const OUTER_RADIUS := 32.0
const PLAZA_RADIUS := 9.0
const ROAD_Y := 0.08

var built := false
var collision_body: StaticBody3D
var materials: Dictionary = {}
var landmark_nodes: Dictionary = {}


func _ready() -> void:
	build()


func build() -> void:
	if built:
		return
	built = true
	name = "SaoTownOfBeginningsQuarter"
	set_meta("reference_layout", LAYOUT_PATH)
	set_meta("asset_policy", "original procedural geometry; no copied map or game asset")
	collision_body = StaticBody3D.new()
	collision_body.name = "QuarterCollision"
	add_child(collision_body)
	_build_ground()
	_build_plaza()
	_build_roads()
	_build_wall_and_gate()
	_build_landmarks()
	_build_camera_and_light()


func _material(key: String, color: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.8
	materials[key] = material
	return material


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, solid := true, yaw := 0.0) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.rotation.y = yaw
	mesh_node.material_override = material
	parent.add_child(mesh_node)
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = position
		shape.rotation.y = yaw
		collision_body.add_child(shape)
	return mesh_node


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.material_override = material
	parent.add_child(mesh_node)
	if solid:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = height
		shape.shape = cylinder
		shape.position = position
		collision_body.add_child(shape)
	return mesh_node


func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "QuarterGround"
	add_child(ground)
	var earth := _material("earth", Color("#5a5746"))
	_box(ground, "Ground", Vector3(72.0, 0.3, 72.0), Vector3(0.0, -0.15, 0.0), earth, true)
	var grass := _material("grass", Color("#6d7b52"))
	_cylinder(ground, "TownLand", OUTER_RADIUS + 1.8, 0.12, Vector3(0.0, 0.07, 0.0), grass)


func _build_plaza() -> void:
	var plaza := Node3D.new()
	plaza.name = "CentralArrivalPlaza"
	add_child(plaza)
	var stone := _material("stone", Color("#aaa28c"))
	var trim := _material("stone_trim", Color("#d4c7a5"))
	_cylinder(plaza, "PlazaSurface", PLAZA_RADIUS, 0.18, Vector3(0.0, ROAD_Y, 0.0), stone, true)
	_cylinder(plaza, "PlazaInnerRing", 6.3, 0.20, Vector3(0.0, ROAD_Y + 0.07, 0.0), trim)
	_cylinder(plaza, "PlazaOuterRing", 8.3, 0.22, Vector3(0.0, ROAD_Y + 0.08, 0.0), trim)
	var teleporter := _material("teleporter", Color("#b9e9ff"), Color("#48cfff"))
	_cylinder(plaza, "TeleporterPad", 2.2, 0.10, Vector3(0.0, ROAD_Y + 0.18, 0.0), teleporter)
	_cylinder(plaza, "TeleporterPillar", 0.22, 5.4, Vector3(0.0, 2.85, 0.0), teleporter)
	var beacon := OmniLight3D.new()
	beacon.name = "TeleporterGlow"
	beacon.light_color = Color("#7ddcff")
	beacon.light_energy = 2.2
	beacon.omni_range = 11.0
	beacon.position = Vector3(0.0, 3.5, 0.0)
	plaza.add_child(beacon)


func _build_roads() -> void:
	var roads := Node3D.new()
	roads.name = "RadialRoads"
	add_child(roads)
	var paving := _material("paving", Color("#827b6b"))
	var route_mark := _material("route_mark", Color("#f3cf42"), Color("#ffe35b"))
	var data: Dictionary = _load_layout()
	for road: Dictionary in data.get("roads", []):
		var start := Vector2(float(road["from"][0]), float(road["from"][1]))
		var end := Vector2(float(road["to"][0]), float(road["to"][1]))
		var delta := end - start
		var length := delta.length()
		var midpoint := (start + end) * 0.5
		var yaw := atan2(delta.x, delta.y)
		var width := float(road["width"])
		_box(roads, "Road_%s" % road["id"], Vector3(width, 0.16, length), Vector3(midpoint.x, ROAD_Y, midpoint.y), paving, true, yaw)
		for segment in range(ceili(length / 3.0)):
			var t := (float(segment) + 0.5) / maxf(1.0, ceil(length / 3.0))
			var point := start.lerp(end, t)
			_box(roads, "Route_%s_%02d" % [road["id"], segment], Vector3(0.18, 0.04, 1.1), Vector3(point.x, ROAD_Y + 0.13, point.y), route_mark, false, yaw)


func _build_wall_and_gate() -> void:
	var wall := Node3D.new()
	wall.name = "FortifiedTownEdge"
	add_child(wall)
	var stone := _material("wall", Color("#6d6a63"))
	var tower := _material("tower", Color("#4d4b49"))
	var segment_count := 20
	var arc := TAU / float(segment_count)
	for index in segment_count:
		var angle := float(index) * arc
		var normalized := wrapf(angle - PI, -PI, PI)
		if absf(normalized) < 0.28:
			continue
		var radius := OUTER_RADIUS
		var position := Vector3(sin(angle) * radius, 1.6, cos(angle) * radius)
		_box(wall, "Wall_%02d" % index, Vector3(1.6, 3.2, 10.0), position, stone, true, -angle)
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 5.8
		_box(wall, "SouthGateTower_%s" % side, Vector3(3.2, 5.5, 4.5), Vector3(x, 2.75, -OUTER_RADIUS), tower, true)
	_box(wall, "SouthGateLintel", Vector3(11.6, 1.2, 4.5), Vector3(0.0, 5.0, -OUTER_RADIUS), tower, true)


func _build_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "TownLandmarks"
	add_child(landmarks)
	var data: Dictionary = _load_layout()
	for landmark: Dictionary in data.get("landmarks", []):
		var position := Vector3(float(landmark["position"][0]), ROAD_Y, float(landmark["position"][1]))
		var node := Node3D.new()
		node.name = String(landmark["id"])
		node.position = position
		landmarks.add_child(node)
		landmark_nodes[node.name] = node
		_match_landmark(String(landmark["kind"]), node)


func _match_landmark(kind: String, node: Node3D) -> void:
	var wall := _material("building", Color("#806b57"))
	var roof := _material("roof", Color("#433b3a"))
	var gold := _material("gold", Color("#d7b85a"))
	var dark := _material("dark_stone", Color("#33343a"))
	match kind:
		"teleport_plaza":
			pass
		"palace":
			_box(node, "PalaceBody", Vector3(11.0, 5.0, 8.0), Vector3(0.0, 2.5, 0.0), dark, true)
			_cylinder(node, "PalaceDome", 5.8, 3.0, Vector3(0.0, 6.3, 0.0), roof)
			_cylinder(node, "PalaceBeacon", 0.45, 7.5, Vector3(0.0, 10.0, 0.0), gold)
		"market":
			for index in 4:
				var x := -4.5 + float(index % 2) * 6.0
				var z := -2.0 + float(index / 2) * 4.0
				_box(node, "MarketStall_%d" % index, Vector3(4.2, 1.5, 2.5), Vector3(x, 0.85, z), wall, true)
				_cylinder(node, "MarketPost_%d" % index, 0.10, 3.2, Vector3(x, 2.2, z), gold, true)
		"guild":
			_box(node, "GuildHall", Vector3(9.0, 4.0, 7.0), Vector3(0.0, 2.0, 0.0), wall, true)
			_box(node, "GuildSign", Vector3(5.0, 1.0, 0.20), Vector3(0.0, 4.4, -3.6), gold, false)
		"church":
			_box(node, "ChurchBody", Vector3(8.0, 4.2, 10.0), Vector3(0.0, 2.1, 0.0), wall, true)
			_cylinder(node, "ChurchTower", 1.6, 10.0, Vector3(0.0, 7.0, 2.3), roof, true)
			_cylinder(node, "ChurchSpire", 1.0, 5.0, Vector3(0.0, 14.5, 2.3), gold)
		"smithy":
			_box(node, "SmithyBody", Vector3(9.0, 3.2, 7.0), Vector3(0.0, 1.6, 0.0), wall, true)
			_box(node, "SmithyAwning", Vector3(5.5, 0.25, 3.0), Vector3(0.0, 3.8, -4.0), roof, false)
			_cylinder(node, "SmithyChimney", 0.8, 5.0, Vector3(2.6, 4.1, 1.8), dark, true)
		"gate":
			var sign := _material("gate_sign", Color("#c8aa66"), Color("#8d6d28"))
			_box(node, "GateMarker", Vector3(3.8, 0.35, 0.25), Vector3(0.0, 2.5, 0.0), sign, false)


func _build_camera_and_light() -> void:
	var camera := Camera3D.new()
	camera.name = "QuarterCamera"
	camera.position = Vector3(0.0, 36.0, 42.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 1.0), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.name = "QuarterSun"
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return parsed if parsed is Dictionary else {}
