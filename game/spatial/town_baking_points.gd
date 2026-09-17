extends Node3D
## Visual projection of the public baking points: displays the world's own baking state without
## ever changing it.
##
## The oven and its public flour sacks are the honest visual target of the town street's own
## line-of-sight probe (`observation_target`), so the fact a resident learns comes from the same
## object a human player sees. Nothing here grants knowledge, food or flour: a depleted stock
## simply stops drawing sacks while the label keeps stating the real number.

var town
var points: Dictionary = {}
var prior_flour: Dictionary = {}
var oven_mesh: BoxMesh
var sack_mesh: BoxMesh
var oven_material: StandardMaterial3D
var sack_material: StandardMaterial3D
const SACK_LIMIT := 5
## The drawn oven body, in the display's own local space. The visual mesh and its solid collider
## share exactly one box, so the physical oven can never drift away from the visible oven.
const OVEN_BODY_SIZE := Vector3(1.0, 1.0, 0.76)
const OVEN_BODY_CENTER := Vector3(0.0, 0.5, 0.0)

func configure(world) -> void:
	town = world
	var point_list: Array = town.baking_points()
	if point_list.is_empty():
		return
	oven_mesh = BoxMesh.new()
	oven_mesh.size = OVEN_BODY_SIZE
	sack_mesh = BoxMesh.new()
	sack_mesh.size = Vector3(0.24, 0.30, 0.24)
	oven_material = StandardMaterial3D.new()
	oven_material.albedo_color = Color("6d5a4b")
	oven_material.roughness = 0.9
	sack_material = StandardMaterial3D.new()
	sack_material.albedo_color = Color("d8cba8")
	sack_material.roughness = 0.85
	for point in point_list:
		var point_id: String = str(point.get("id", ""))
		if point_id.is_empty():
			continue
		var display := Node3D.new()
		display.position = _point_position(point)
		add_child(display)
		var oven := MeshInstance3D.new()
		oven.mesh = oven_mesh
		oven.material_override = oven_material
		oven.position = OVEN_BODY_CENTER
		display.add_child(oven)
		_add_oven_collision(oven)
		var mouth := MeshInstance3D.new()
		var mouth_mesh := BoxMesh.new()
		mouth_mesh.size = Vector3(0.5, 0.34, 0.06)
		mouth.mesh = mouth_mesh
		var mouth_material := StandardMaterial3D.new()
		mouth_material.albedo_color = Color("2f2620")
		mouth_material.roughness = 0.7
		mouth.material_override = mouth_material
		mouth.position = Vector3(0.0, 0.42, 0.40)
		display.add_child(mouth)
		for index in SACK_LIMIT:
			var sack := MeshInstance3D.new()
			sack.mesh = sack_mesh
			sack.material_override = sack_material
			sack.position = Vector3(-0.62 + (index % 3) * 0.30, 0.15 + (index / 3) * 0.32, 0.52)
			sack.visible = false
			display.add_child(sack)
		var label := Label3D.new()
		label.font_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 6
		label.position = Vector3(0, 1.30, 0)
		display.add_child(label)
		points[point_id] = {"display": display, "label": label}
		var flour := _flour(point)
		prior_flour[point_id] = flour
		_update_point(point_id, str(point.get("label", point_id)), flour)

func _add_oven_collision(oven: MeshInstance3D) -> void:
	# One solid box that is exactly the drawn oven body: a resident capsule can no longer walk
	# through the oven. It is deliberately restricted to the body, so it cannot reach into the
	# authoritative working apron in front of the mouth (`town_baking.gd` BAKING_WORK_OFFSET with
	# arrival radius 0.45), which stays walkable, and it cannot reach the line-of-sight target
	# above the body top, which stays observable from that apron. The 6 cm decorative mouth plate
	# is left exactly as drawn; it never carried collision.
	var body := StaticBody3D.new()
	body.name = "OvenCollision"
	# Layer 1: the layer resident capsules scan and the layer the town navigation bake parses.
	body.collision_layer = 1
	var collider := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = OVEN_BODY_SIZE
	collider.shape = volume
	body.add_child(collider)
	oven.add_child(body)

func _process(_delta: float) -> void:
	if town == null or points.is_empty():
		return
	var current: Dictionary = {}
	for point in town.baking_points():
		var point_id: String = str(point.get("id", ""))
		if not points.has(point_id):
			continue
		var flour := _flour(point)
		current[point_id] = flour
		if int(prior_flour.get(point_id, -1)) != flour:
			_update_point(point_id, str(point.get("label", point_id)), flour)
	prior_flour = current

func _update_point(point_id: String, label_text: String, flour: int) -> void:
	var entry: Dictionary = points[point_id]
	var display: Node3D = entry["display"]
	var label: Label3D = entry["label"]
	label.text = "%s\n公共面粉：%d" % [label_text, flour]
	var sack_count := mini(SACK_LIMIT, flour)
	for index in SACK_LIMIT:
		display.get_child(index + 2).visible = index < sack_count

func observation_target(point_id: String) -> Vector3:
	# Read-only actual target: the front of the oven mouth. Returns Vector3.INF when the point is
	# unknown, freed, hidden or not in the tree, so the probe can never observe a ghost.
	if not points.has(point_id):
		return Vector3.INF
	var entry: Dictionary = points[point_id]
	var display: Variant = entry.get("display")
	if not is_instance_valid(display):
		return Vector3.INF
	if not display is Node3D or not display.is_inside_tree() or not display.is_visible_in_tree():
		return Vector3.INF
	return (display as Node3D).to_global(Vector3(0, 1.05, 0))

func _flour(point: Dictionary) -> int:
	return clampi(int(point.get("flour_remaining", 0)), 0, 100)

func _point_position(point: Dictionary) -> Vector3:
	var coordinates: Array = point.get("position", [])
	if coordinates.size() < 3:
		return Vector3.ZERO
	return Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
