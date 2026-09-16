@tool
class_name ModularHouseComponent
extends Node3D
## Semantic modular floor-1 house (cottage / merchant / L-plan corner).
##
## Instantiates one exported GLB exactly once, maps the authored semantic pivots
## (DoorPivot, WindowSash_NN, ShutterPivot_*_NN) and builds static collision: a trimesh
## from the real BuildingShell (which has true wall openings) plus a box that follows the
## door leaf hinge. Mesh resources are never mutated; only node transforms change, so two
## instances of the same variant stay independent.
##
## Contract: tmp/floor1-art-20260916/modular/contract.json

const DEFAULT_MANIFEST := "res://assets/floor1/modular_houses_20260916/manifest.json"
const DEFAULT_DOOR_VISUAL := "res://assets/floor1/door_leaf_20260916/F1_oak_door_leaf.glb"
const DOOR_RAW_HEIGHT := 1.902957
const DOOR_VISUAL_HEIGHT := 2.15

signal door_toggled(open: bool)
signal window_toggled(open: bool)

@export var variant_id: String = "01_hearth_cottage"
@export var manifest_path: String = DEFAULT_MANIFEST
@export var build_on_ready: bool = true
@export var external_door_visual_path: String = DEFAULT_DOOR_VISUAL

var manifest: Dictionary = {}
var house: Dictionary = {}
var instance: Node3D = null
var door_unit: Node3D = null
var door_pivot: Node3D = null
var door_visual_override: Node3D = null
var fallback_door_leaf: Node3D = null
var door_collision: StaticBody3D = null
var shell_collision: StaticBody3D = null
var sashes: Array[Node3D] = []
var shutters: Array[Node3D] = []
var _sash_closed: Dictionary = {}
var _shutter_closed: Dictionary = {}
var _door_closed_rotation := Vector3.ZERO
var _door_unit_anchor := Transform3D.IDENTITY
var _door_open := false
var _window_open := false
var _built := false


func _ready() -> void:
	if build_on_ready and not _built:
		build()


func build() -> bool:
	if _built:
		return true
	manifest = _read_manifest()
	house = _find_house(variant_id)
	if house.is_empty():
		push_error("ModularHouseComponent: variant %s is not in the manifest" % variant_id)
		return false
	var packed := load(String(house["source_glb"])) as PackedScene
	if packed == null:
		push_error("ModularHouseComponent: cannot load %s" % house["source_glb"])
		return false
	instance = packed.instantiate() as Node3D
	add_child(instance)
	_map_parts()
	_build_collision()
	if not external_door_visual_path.is_empty():
		attach_external_door_visual(external_door_visual_path, _default_door_visual_transform())
	_built = true
	return true


func _read_manifest() -> Dictionary:
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_error("ModularHouseComponent: manifest missing at %s" % manifest_path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _find_house(id: String) -> Dictionary:
	for entry in manifest.get("houses", []):
		if String(entry.get("variant_id", "")) == id:
			return entry
	return {}


func _map_parts() -> void:
	door_unit = instance.find_child("DoorUnit", true, false) as Node3D
	if door_unit != null:
		_door_unit_anchor = door_unit.transform
	door_pivot = instance.find_child("DoorPivot", true, false) as Node3D
	fallback_door_leaf = instance.find_child("DoorLeaf", true, false) as Node3D
	if door_pivot != null:
		_door_closed_rotation = door_pivot.rotation
	sashes.clear()
	shutters.clear()
	for child in _all_children(instance):
		var node := child as Node3D
		if node == null:
			continue
		if node.name.begins_with("WindowSash_"):
			sashes.append(node)
			_sash_closed[node] = node.position
		elif node.name.begins_with("ShutterPivot_"):
			shutters.append(node)
			_shutter_closed[node] = node.rotation


func _all_children(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			found.append(child)
			stack.append(child)
	return found


func _build_collision() -> void:
	var shell := instance.find_child("BuildingShell", true, false) as MeshInstance3D
	if shell != null and shell.mesh != null:
		var shape := shell.mesh.create_trimesh_shape()
		if shape != null:
			shell_collision = StaticBody3D.new()
			shell_collision.name = "ShellCollision"
			var collider := CollisionShape3D.new()
			collider.name = "ShellShape"
			collider.shape = shape
			shell_collision.add_child(collider)
			shell.add_child(shell_collision)
	# The merchant awning posts are approachable exterior supports. Keep their
	# simple physical boxes with the removable ShopBay mesh, using the authored
	# centres and sizes instead of a visual-only column that the walker crosses.
	var shop := instance.find_child("ShopBay", true, false) as MeshInstance3D
	if shop != null:
		var shop_body := StaticBody3D.new()
		shop_body.name = "ShopBayPostCollision"
		for entry in house.get("collision", []):
			if String(entry.get("node", "")) != "ShopBay" or String(entry.get("kind", "")) != "box":
				continue
			var size: Array = entry["size"]
			var centre: Array = entry["centre_local"]
			var box := BoxShape3D.new()
			box.size = Vector3(abs(float(size[0])), abs(float(size[2])), abs(float(size[1])))
			var post_shape := CollisionShape3D.new()
			post_shape.name = String(entry["id"]) + "Shape"
			post_shape.shape = box
			post_shape.position = Vector3(float(centre[0]), float(centre[2]), -float(centre[1]))
			shop_body.add_child(post_shape)
		if shop_body.get_child_count() > 0:
			shop.add_child(shop_body)
		else:
			shop_body.free()
	if door_pivot != null and not house.get("collision", []).is_empty():
		for entry in house["collision"]:
			if String(entry.get("id", "")) != "door_leaf":
				continue
			var size: Array = entry["size"]
			var centre: Array = entry["centre_local"]
			var box := BoxShape3D.new()
			# manifest is authored in Blender Z-up; convert to Godot Y-up here.
			box.size = Vector3(abs(float(size[0])), abs(float(size[2])), abs(float(size[1])))
			var collider := CollisionShape3D.new()
			collider.name = "DoorLeafShape"
			collider.shape = box
			collider.position = Vector3(float(centre[0]), float(centre[2]), -float(centre[1]))
			door_collision = StaticBody3D.new()
			door_collision.name = "DoorCollision"
			door_collision.add_child(collider)
			door_pivot.add_child(door_collision)
	# The window opening is real wall geometry. A thin pane collider travels with
	# each sash, so a closed pane blocks a ray and the lower opening clears on lift.
	for sash in sashes:
		var pane := BoxShape3D.new()
		pane.size = Vector3(0.89, 1.14, 0.06)
		var pane_shape := CollisionShape3D.new()
		pane_shape.shape = pane
		pane_shape.position = Vector3(0.0, 0.65, 0.0)
		var pane_body := StaticBody3D.new()
		pane_body.name = "WindowCollision_" + String(sash.name).trim_prefix("WindowSash_")
		pane_body.add_child(pane_shape)
		sash.add_child(pane_body)


func set_door_open(open: bool) -> void:
	if door_pivot == null:
		return
	var angle := float(_door_angle())
	door_pivot.rotation = _door_closed_rotation + Vector3(0.0, deg_to_rad(-angle if open else 0.0), 0.0)
	_door_open = open
	door_toggled.emit(open)


func detach_door_unit() -> Node3D:
	## Remove the whole authored frame, hinge, visual leaves and moving physical
	## collider as one live node. The real shell aperture remains in place.
	if door_unit == null or door_unit.get_parent() == null:
		return null
	var removed := door_unit
	removed.get_parent().remove_child(removed)
	door_unit = null
	door_pivot = null
	fallback_door_leaf = null
	door_visual_override = null
	door_collision = null
	_door_open = false
	return removed


func install_door_unit(replacement: Node3D) -> bool:
	## Accept a complete detached unit only. Its root is aligned to this house's
	## original facade anchor, so the same door size can move between variants.
	if instance == null or door_unit != null or replacement == null or replacement.get_parent() != null:
		return false
	var frame := replacement.find_child("DoorFrame", true, false) as MeshInstance3D
	var hinge := replacement.find_child("DoorPivot", true, false) as Node3D
	var fallback := replacement.find_child("DoorLeaf", true, false) as Node3D
	var moving_collision: StaticBody3D = null
	if hinge != null:
		moving_collision = hinge.find_child("DoorCollision", true, false) as StaticBody3D
	if frame == null or hinge == null or fallback == null or moving_collision == null:
		return false
	instance.add_child(replacement)
	replacement.name = "DoorUnit"
	replacement.transform = _door_unit_anchor
	replacement.visible = true
	door_unit = replacement
	door_pivot = hinge
	fallback_door_leaf = fallback
	door_collision = moving_collision
	door_visual_override = replacement.find_child("ExternalDoorVisual", true, false) as Node3D
	fallback_door_leaf.visible = door_visual_override == null
	door_pivot.rotation = _door_closed_rotation
	_door_open = false
	return true


func door_unit_node() -> Node3D:
	return door_unit


func attach_external_door_visual(path: String, local_transform: Transform3D = Transform3D.IDENTITY) -> bool:
	## Visual-only replacement under the existing hinge. Collision and semantic pivots
	## remain authored by this house; a failed load leaves the fallback leaf visible.
	if door_pivot == null:
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var replacement := packed.instantiate() as Node3D
	if replacement == null:
		return false
	clear_external_door_visual()
	replacement.name = "ExternalDoorVisual"
	door_pivot.add_child(replacement)
	replacement.transform = local_transform
	door_visual_override = replacement
	if fallback_door_leaf != null:
		fallback_door_leaf.visible = false
	return true


func _default_door_visual_transform() -> Transform3D:
	## Raw Y-up door is centred around its panel. Preserve the authored hinge and
	## collision box: only the external mesh scales into the 2.15 m leaf aperture.
	var uniform_scale := DOOR_VISUAL_HEIGHT / DOOR_RAW_HEIGHT
	return Transform3D(Basis.from_scale(Vector3.ONE * uniform_scale),
		Vector3(0.60, 1.075, 0.0))


func clear_external_door_visual() -> void:
	if door_visual_override != null:
		door_visual_override.queue_free()
		door_visual_override = null
	if fallback_door_leaf != null:
		fallback_door_leaf.visible = true


func set_window_open(open: bool) -> void:
	var travel := _window_travel()
	for sash in sashes:
		var closed: Vector3 = _sash_closed.get(sash, sash.position)
		sash.position = closed + (Vector3(0.0, travel, 0.0) if open else Vector3.ZERO)
	for shutter in shutters:
		var closed: Vector3 = _shutter_closed.get(shutter, shutter.rotation)
		if not open:
			shutter.rotation = closed
		else:
			# An outer-jamb leaf must not sweep past its hinge into the next doorway.
			# 75 degrees reads open while retaining clear shoulder/head space.
			var swing := deg_to_rad(75.0 if "_L_" in String(shutter.name) else -75.0)
			shutter.rotation = Vector3(closed.x, closed.y + swing, closed.z)
	_window_open = open
	window_toggled.emit(open)


func interact_door() -> bool:
	set_door_open(not _door_open)
	return _door_open


func is_door_open() -> bool:
	return _door_open


func is_window_open() -> bool:
	return _window_open


func roof_node() -> Node3D:
	return instance.find_child("Roof", true, false) as Node3D if instance != null else null


func door_opening_godot() -> Dictionary:
	## Doorway centre and outward direction in Godot coordinates (from the manifest).
	for entry in house.get("openings", []):
		if String(entry.get("kind", "")) == "door":
			var centre: Array = entry["centre"]
			var outward: Array = entry["outward"]
			return {
				"centre": Vector3(float(centre[0]), float(centre[2]), -float(centre[1])),
				"outward": Vector3(float(outward[0]), float(outward[2]), -float(outward[1])).normalized(),
				"size": Vector3(float(entry["size"][0]), float(entry["size"][2]), float(entry["size"][1])),
			}
	return {}


func _door_angle() -> float:
	for entry in house.get("pivots", []):
		if String(entry.get("id", "")) == "DoorPivot":
			return float(entry.get("open_angle_deg", 88.0))
	return 88.0


func _window_travel() -> float:
	for entry in house.get("pivots", []):
		if String(entry.get("id", "")) == "WindowSash":
			return float(entry.get("travel_m", 0.7))
	return 0.7
