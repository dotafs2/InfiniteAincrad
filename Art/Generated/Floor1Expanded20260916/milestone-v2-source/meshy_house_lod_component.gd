@tool
extends Node3D
## Exterior appearance adapter for the three immutable Meshy 7 house trials.
## Three mesh levels share the imported source PBR material/embedded textures.
## Optional visual-shell collision is exterior-only; it does not make rooms enterable.

@export_enum("01_hearth_cottage", "02_market_house", "03_corner_turret") var house_id := "01_hearth_cottage"
@export_enum("4k", "2k") var texture_tier := "4k"
@export_range(-1, 2) var force_lod: int = -1
@export var exterior_only_collision_enabled := false
@export_range(1.0, 300.0, 1.0) var near_end_m := 30.0
@export_range(1.0, 500.0, 1.0) var mid_end_m := 75.0

const ASSET_ROOT := "res://assets/floor1/meshy_houses_lod/"
const VALID_IDS := ["01_hearth_cottage", "02_market_house", "03_corner_turret"]
static var _shared_materials: Dictionary = {}

var _levels: Array[MeshInstance3D] = []
var active_lod := -1


func _ready() -> void:
	if not VALID_IDS.has(house_id):
		push_error("Unknown Meshy house id: " + house_id)
		return
	if not texture_tier in ["4k", "2k"]:
		push_error("Unknown Meshy house texture tier: " + texture_tier)
		return
	if get_node_or_null("MeshyHouseGeometry") != null:
		return
	# One selected GLB/tier supplies all three mesh levels and its PBR set.
	# Do not load 4K and 2K concurrently for the same house to save memory.
	var asset_path := ASSET_ROOT + house_id + "_lod" + ("_2k" if texture_tier == "2k" else "") + ".glb"
	var scene := load(asset_path) as PackedScene
	if scene == null:
		push_error("Meshy house LOD asset missing: " + asset_path)
		return
	var imported := scene.instantiate() as Node3D
	imported.name = "MeshyHouseGeometry"
	add_child(imported)
	_levels.resize(3)
	for item: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
		var label := String(item.name)
		if not label in ["LOD0", "LOD1", "LOD2"]:
			continue
		var index := int(label.trim_prefix("LOD"))
		_levels[index] = item
		item.set_meta("lod", index)
		item.set_meta("exterior_only", true)
		for surface in range(item.mesh.get_surface_count()):
			var key := asset_path + ":" + str(surface)
			if not _shared_materials.has(key):
				_shared_materials[key] = item.mesh.surface_get_material(surface)
			if _shared_materials[key] != null:
				item.set_surface_override_material(surface, _shared_materials[key])
	for index in range(3):
		if _levels[index] == null:
			push_error("Missing LOD%d in %s" % [index, asset_path])
			return
	set_meta("asset_id", house_id)
	set_meta("texture_tier", texture_tier)
	set_meta("asset_path", asset_path)
	set_meta("exterior_only", true)
	update_lod_for_distance(0.0)
	if exterior_only_collision_enabled:
		_create_exterior_only_collision()
	set_process(force_lod < 0)


func _process(_delta: float) -> void:
	if _levels.size() != 3 or _levels[0] == null:
		return
	if force_lod >= 0:
		update_lod_for_distance(0.0)
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		update_lod_for_distance(camera.global_position.distance_to(global_position))


func update_lod_for_distance(distance_m: float) -> int:
	var selected := clampi(force_lod, 0, 2) if force_lod >= 0 else 0
	if force_lod < 0:
		if distance_m >= mid_end_m:
			selected = 2
		elif distance_m >= near_end_m:
			selected = 1
	if selected != active_lod:
		for index in range(_levels.size()):
			if _levels[index] != null:
				_levels[index].visible = index == selected
		active_lod = selected
		set_meta("active_lod", selected)
	return selected


func lod_mesh(index: int) -> MeshInstance3D:
	return _levels[index] if index >= 0 and index < _levels.size() else null


func _create_exterior_only_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "ExteriorOnlyVisualShellCollision"
	body.set_meta("exterior_only", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = _levels[1].mesh.create_trimesh_shape()
	body.add_child(shape)
	body.global_transform = _levels[1].global_transform
