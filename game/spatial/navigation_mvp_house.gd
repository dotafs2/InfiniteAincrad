extends Node3D
## Small visual fixture for the loaded-world route-graph MVP.
## It uses existing Meshy art for context and deliberately keeps movement data
## abstract: the route graph, not collision, is the acceptance surface.

const RouteGraph = preload("res://spatial/town_route_graph.gd")
const RouteConnector = preload("res://spatial/town_route_connector.gd")
const MESHY_HOUSE := "res://assets/floor1/meshy_houses_lod/01_hearth_cottage_lod.glb"

@export var third_person_camera_enabled := true
@export var autoplay_route := true
@export var preview_speed := 1.8

var route_graph = RouteGraph.new()
var connectors: Dictionary = {}
var resident_a: Node3D
var resident_b: Node3D
var preview_camera: Camera3D
var route_preview_segments: Array[Dictionary] = []
var preview_segment_index := 0
var preview_segment_progress := 0.0
var preview_paused := false
var route_glow_material: StandardMaterial3D


func _ready() -> void:
	_build_visual_fixture()
	_build_route_fixture()
	_build_route_markers()
	_build_third_person_camera()
	_build_preview_hud()
	_reset_preview()


func _process(delta: float) -> void:
	if preview_camera != null and is_instance_valid(resident_a):
		_update_third_person_camera()
	if autoplay_route and not preview_paused and is_instance_valid(resident_a):
		_advance_preview(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			preview_paused = not preview_paused
		KEY_R:
			_reset_preview()
		KEY_C:
			if preview_camera != null:
				preview_camera.current = not preview_camera.current


func _build_visual_fixture() -> void:
	_box("GroundFloor", Vector3(8.0, 0.25, 6.0), Vector3(4.0, 0.0, 0.0), Color("7b6954"))
	_box("UpperFloor", Vector3(8.0, 0.25, 6.0), Vector3(4.0, 3.2, 0.0), Color("8b765d"))
	_box("UpperWallBack", Vector3(8.0, 2.8, 0.25), Vector3(4.0, 4.6, -3.0), Color("b9a78b"))
	_box("UpperWallLeft", Vector3(0.25, 2.8, 6.0), Vector3(0.0, 4.6, 0.0), Color("b9a78b"))
	_box("UpperWallRight", Vector3(0.25, 2.8, 6.0), Vector3(8.0, 4.6, 0.0), Color("b9a78b"))
	_build_ladder_visual()
	resident_a = _build_target_marker("ResidentA", Vector3(-1.5, 0.65, 0.0), Color("5fa8d3"))
	resident_b = _build_target_marker("ResidentB", Vector3(6.5, 3.85, 0.0), Color("e07a5f"))

	var packed := load(MESHY_HOUSE) as PackedScene
	if packed != null:
		var art := packed.instantiate() as Node3D
		if art != null:
			art.name = "MeshyCottageContext"
			art.position = Vector3(14.0, 0.0, 0.0)
			art.scale = Vector3.ONE * 0.28
			add_child(art)


func _build_route_fixture() -> void:
	route_graph.add_region("street", Vector3(-1.5, 0.65, 0.0))
	route_graph.add_region("room_1f", Vector3(3.0, 0.65, 0.0))
	route_graph.add_region("room_2f", Vector3(3.0, 3.85, 0.0))
	route_graph.add_region("target_room", Vector3(6.5, 3.85, 0.0))
	_register_connector("front_door", "street", "room_1f", Vector3(0.0, 0.65, 0.0), Vector3(1.2, 0.65, 0.0), "door", "open_door")
	_register_connector("ladder_01", "room_1f", "room_2f", Vector3(3.0, 0.65, 1.2), Vector3(3.0, 3.85, 1.2), "ladder", "climb")
	_register_connector("upper_door", "room_2f", "target_room", Vector3(4.8, 3.85, 0.0), Vector3(5.8, 3.85, 0.0), "door", "open_door")


func _register_connector(
	connector_id: String,
	from_region: String,
	to_region: String,
	start: Vector3,
	end: Vector3,
	kind: String,
	action: String
) -> void:
	var connector := RouteConnector.new()
	connector.name = connector_id
	connector.connector_id = connector_id
	connector.connector_kind = kind
	connector.action_name = action
	connector.start_position = start
	connector.end_position = end
	add_child(connector)
	connectors[connector_id] = connector
	route_graph.add_connector(connector_id, from_region, to_region,
		connector.route_start_position(), connector.route_end_position(), kind, action, 1.0, true, connector)


func _build_route_markers() -> void:
	var route: Dictionary = route_graph.find_route("street", "target_room")
	if not bool(route.get("ok", false)):
		return
	route_glow_material = StandardMaterial3D.new()
	route_glow_material.albedo_color = Color.html("FFF02A")
	route_glow_material.emission_enabled = true
	route_glow_material.emission = Color.html("FFF02A")
	route_glow_material.emission_energy_multiplier = 4.0
	route_glow_material.roughness = 0.22
	var cursor := resident_a.global_position
	for raw_edge in route.get("connectors", []):
		var edge: Dictionary = raw_edge
		var start: Vector3 = edge["start_position"]
		var end: Vector3 = edge["end_position"]
		_add_preview_segment(cursor, start, "")
		_add_preview_segment(start, end, String(edge["id"]), edge.get("object"))
		cursor = end
	_add_preview_segment(cursor, resident_b.global_position, "")


func _add_preview_segment(start: Vector3, end: Vector3, connector_id: String, connector: Object = null) -> void:
	var length := start.distance_to(end)
	if length <= 0.01:
		return
	route_preview_segments.append({
		"start": start,
		"end": end,
		"connector_id": connector_id,
		"connector": connector,
		"triggered": false,
	})
	var piece_count := maxi(1, int(ceil(length / 0.42)))
	for piece in range(piece_count):
		var a := start.lerp(end, float(piece) / float(piece_count))
		var b := start.lerp(end, float(piece + 1) / float(piece_count))
		var midpoint := (a + b) * 0.5
		var piece_length := a.distance_to(b) * 0.72
		var glow := MeshInstance3D.new()
		glow.name = "RouteGlow_%02d" % get_child_count()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.075, 0.075, piece_length)
		glow.mesh = mesh
		glow.material_override = route_glow_material
		glow.position = midpoint
		add_child(glow)
		var direction := (b - a).normalized()
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.92 else Vector3.UP
		glow.look_at(glow.global_position + direction, up)


func _build_third_person_camera() -> void:
	if not third_person_camera_enabled or resident_a == null:
		return
	preview_camera = Camera3D.new()
	preview_camera.name = "ResidentAThirdPersonCamera"
	preview_camera.position = Vector3(-4.2, 2.65, 5.2)
	preview_camera.fov = 68.0
	resident_a.add_child(preview_camera)
	preview_camera.current = true
	_update_third_person_camera()


func _build_preview_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RoutePreviewHud"
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(24.0, 22.0)
	panel.size = Vector2(520.0, 78.0)
	panel.color = Color(0.025, 0.04, 0.055, 0.82)
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(16.0, 10.0)
	title.text = "Navigation MVP · ResidentA third-person route"
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)
	var controls := Label.new()
	controls.position = Vector2(16.0, 42.0)
	controls.text = "SPACE pause/resume   R reset   C camera toggle   yellow = route graph"
	controls.modulate = Color("FFF02A")
	controls.add_theme_font_size_override("font_size", 14)
	panel.add_child(controls)


func _update_third_person_camera() -> void:
	if preview_camera == null or resident_a == null:
		return
	var look_target := resident_a.global_position + Vector3(1.8, 0.9, 0.0)
	if preview_segment_index < route_preview_segments.size():
		var segment: Dictionary = route_preview_segments[preview_segment_index]
		look_target = resident_a.global_position.lerp(segment["end"], 0.65)
		look_target.y += 0.9
	preview_camera.look_at(look_target, Vector3.UP)


func _reset_preview() -> void:
	preview_segment_index = 0
	preview_segment_progress = 0.0
	preview_paused = false
	if resident_a != null and not route_preview_segments.is_empty():
		resident_a.global_position = route_preview_segments[0]["start"]
	for segment in route_preview_segments:
		segment["triggered"] = false


func _advance_preview(delta: float) -> void:
	if route_preview_segments.is_empty():
		return
	if preview_segment_index >= route_preview_segments.size():
		_reset_preview()
		return
	var segment: Dictionary = route_preview_segments[preview_segment_index]
	var start: Vector3 = segment["start"]
	var end: Vector3 = segment["end"]
	var length := start.distance_to(end)
	if length <= 0.01:
		preview_segment_index += 1
		return
	if not String(segment["connector_id"]).is_empty() and not bool(segment["triggered"]):
		segment["triggered"] = true
		var connector: Object = segment.get("connector")
		if is_instance_valid(connector) and connector.has_method("trigger_action"):
			connector.call("trigger_action")
	preview_segment_progress = minf(1.0, preview_segment_progress + preview_speed * delta / length)
	resident_a.global_position = start.lerp(end, preview_segment_progress)
	if preview_segment_progress >= 1.0:
		preview_segment_index += 1
		preview_segment_progress = 0.0


func _build_ladder_visual() -> void:
	_box("LadderLeft", Vector3(0.12, 3.1, 0.12), Vector3(2.7, 1.7, 1.2), Color("5c4633"))
	_box("LadderRight", Vector3(0.12, 3.1, 0.12), Vector3(3.3, 1.7, 1.2), Color("5c4633"))
	for index in 7:
		_box("LadderRung_%02d" % index, Vector3(0.7, 0.10, 0.10), Vector3(3.0, 0.35 + index * 0.45, 1.2), Color("8c6a47"))


func _build_target_marker(marker_name: String, at: Vector3, color: Color) -> Node3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	marker.material_override = material
	marker.position = at
	add_child(marker)
	return marker


func _box(box_name: String, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
