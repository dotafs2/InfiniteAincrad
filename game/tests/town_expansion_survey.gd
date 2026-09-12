extends SceneTree
## Offline geometry survey for the town expansion: measures where the playable street
## actually is, so new blocks can be placed against real bounds instead of guesses.
## No model call, no gateway, no maintained world: a disposable copy only.
const TownScene := preload("res://scenes/town_street.tscn")

var _scene: Node = null
var _frames := 0
var _out := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("usage: -- --out=<json>")
		quit(2)
		return
	_scene = TownScene.instantiate()
	root.add_child(_scene)

func _world_aabb(node: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var item: MeshInstance3D = mesh
		if not item.is_visible_in_tree() and item.visibility_range_begin > 0.0:
			continue
		var box: AABB = item.global_transform * item.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var report := {"children": [], "market_loaded": _scene.get("_market_loaded")}
	for child in _scene.get_children():
		var entry := {"name": str(child.name), "class": child.get_class()}
		var bounds := _world_aabb(child)
		if bounds.size != Vector3.ZERO:
			entry["aabb_position"] = [bounds.position.x, bounds.position.y, bounds.position.z]
			entry["aabb_size"] = [bounds.size.x, bounds.size.y, bounds.size.z]
		report["children"].append(entry)
	var town: RefCounted = _scene.get("town")
	if town != null:
		report["active"] = town.active_ids().size()
		report["sample_positions"] = {}
		for id in town.active_ids():
			var p: Vector3 = town.position_of(id)
			report["sample_positions"][id] = [p.x, p.y, p.z]
		report["berry"] = str(_scene.get("berry_patch_position")) if _scene.has_method("get") else ""
	var player: Node3D = _scene.get("_player")
	if player != null:
		report["player"] = [player.position.x, player.position.y, player.position.z]
	if not _out.is_empty():
		var handle := FileAccess.open(_out, FileAccess.WRITE)
		handle.store_string(JSON.stringify(report))
		handle.close()
	print(JSON.stringify(report).substr(0, 4000))
	quit(0)
	return true
