extends SceneTree
## Actual street, registered capsules, scenery contacts and gravity. OFFLINE ONLY.
## Default mode runs 45 real physics frames with scripted choices suppressed.
## --cold-read keeps the scene paused and verifies the save remains byte exact.
## The source world is always a disposable copy in one of the validation roots.

const TownScene := preload("res://scenes/town_street.tscn")
const ROOTS := ["../tmp/chain-20260912/ten-world-validation", "../tmp/gpt6-sprint/ten-world"]
const EXPECTED_RESIDENTS := 10
const SETTLE_FRAMES := 45
const CONTACT_TOLERANCE := 0.01

var _save_path := ""
var _out_path := ""
var _seed_path := ""
var _screenshot := ""
var _cold_read := false
var _inject_obstacle := false
var _scene: Node3D
var _checks := 0
var _failures: Array = []
var _before := PackedByteArray()
var _initial: Dictionary = {}

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

func _allowed(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path().to_lower()
	if not path.is_absolute_path():
		return false
	for relative in ROOTS:
		var allowed := ProjectSettings.globalize_path("res://").path_join(relative).simplify_path().replace("\\", "/").to_lower()
		if normalized.begins_with(allowed + "/"):
			return true
	return false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="):
			_save_path = arg.trim_prefix("--town-save=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--ten-save="):
			_seed_path = arg.trim_prefix("--ten-save=")
		elif arg.begins_with("--screenshot="):
			_screenshot = arg.trim_prefix("--screenshot=")
		elif arg == "--cold-read":
			_cold_read = true
		elif arg == "--inject-obstacle":
			_inject_obstacle = true
		elif arg.begins_with("--town-"):
			push_error("This offline probe rejects additional town flags: " + arg)
			quit(2)
			return
	if not _allowed(_save_path) or not _allowed(_out_path) or _save_path == _out_path \
			or (not _screenshot.is_empty() and (not _allowed(_screenshot) or _screenshot in [_save_path, _out_path])):
		push_error("Use distinct absolute save/output paths under a ten-world validation root")
		quit(2)
		return
	_before = FileAccess.get_file_as_bytes(_save_path)
	var parsed: Variant = JSON.parse_string(_before.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("origin", {}).get("kind") != "new_world_seed":
		push_error("The disposable save must declare an independent new world")
		quit(2)
		return
	_initial = parsed
	if not _seed_path.is_empty():
		var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_seed_path))
		if not seed is Dictionary or seed.get("world_id") != _initial.get("world_id"):
			push_error("Expected seed world identity does not match the disposable save")
			quit(2)
			return
	_run.call_deferred()

func _run() -> void:
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	# No gateway node is created. Suppress the legacy offline choice scheduler,
	# while exercising the scene's ordinary gravity and move_and_slide loop.
	_scene.set("scripted_trade", true)
	_scene.set("paused", _cold_read)
	for frame in SETTLE_FRAMES:
		await physics_frame
	_scene.set("paused", true)
	var town: RefCounted = _scene.get("town")
	var bodies: Dictionary = _scene.get("bodies")
	if _inject_obstacle and not bodies.is_empty():
		# Deliberate negative control: the ordinary overlap check must FAIL when
		# actual scenery is inserted inside a resident after motion is paused.
		var obstacle := StaticBody3D.new()
		obstacle.name = "TenWorldNegativeControlObstacle"
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		collision.shape = box
		obstacle.add_child(collision)
		_scene.add_child(obstacle)
		obstacle.global_position = bodies.values()[0].global_position + Vector3.UP * 0.75
		await physics_frame
		await physics_frame
	_check(_scene.get("model_turns") == null and not _scene.get("gateway_mode"), "offline scene creates no model controller")
	_check(town.snapshot().get("world_id") == _initial.get("world_id"), "street loads the declared independent world identity")
	_check(bodies.size() == EXPECTED_RESIDENTS, "street creates exactly ten resident bodies")
	var expected_ids: Array = []
	for person in _initial.residents:
		expected_ids.append(person.stable_id)
	expected_ids.sort()
	var ids: Array = bodies.keys()
	ids.sort()
	_check(ids == expected_ids, "ten bodies bind exactly to the saved stable identities")
	var space := _scene.get_world_3d().direct_space_state
	var rows: Array = []
	var resident_rids: Dictionary = {}
	var penetrations: Array = []
	for id in ids:
		var body: CharacterBody3D = bodies[id] as CharacterBody3D
		_check(body != null and body.is_inside_tree(), "%s is a live CharacterBody3D" % id)
		if body == null:
			continue
		_check(body.collision_layer != 0 and body.collision_mask != 0, "%s participates in physical collisions" % id)
		resident_rids[body.get_rid()] = id
		var collider: CollisionShape3D = null
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
				collider = child
		_check(collider != null, "%s has an enabled capsule" % id)
		if collider == null:
			continue
		var declared: Array = _initial.godot.positions[id]
		var start := Vector3(declared[0], declared[1], declared[2])
		_check(body.global_position.is_finite() and body.global_position.distance_to(start) < 0.75,
			"%s remains close to its declared start" % id)
		var ray := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 0.10,
			body.global_position - Vector3.UP * 0.35, body.collision_mask, [body.get_rid()])
		var ground := space.intersect_ray(ray)
		_check(not ground.is_empty() and ground.get("normal", Vector3.ZERO).y > 0.7,
			"%s has walkable scenery immediately below its feet" % id)
		if not _cold_read:
			_check(body.is_on_floor(), "%s actually reaches a floor through move_and_slide" % id)
		# Inset the ACTUAL capsule by 1 cm to ignore permitted resting contact.
		# Report every scenery/player/resident hit; no resident-only filtering.
		var shape: CapsuleShape3D = collider.shape.duplicate()
		shape.radius -= CONTACT_TOLERANCE
		shape.height -= CONTACT_TOLERANCE * 2.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = collider.global_transform
		query.collision_mask = body.collision_mask
		query.exclude = [body.get_rid()]
		query.margin = 0.0
		for hit in space.intersect_shape(query, 64):
			var other: Node = hit.collider
			penetrations.append({"resident": id, "collider": str(other.get_path())})
		rows.append({"id": id, "position": [body.position.x, body.position.y, body.position.z],
			"on_floor": body.is_on_floor(), "support": str(ground.collider.get_path()) if not ground.is_empty() else "",
			"capsule_radius": collider.shape.radius, "capsule_height": collider.shape.height})
	_check(resident_rids.size() == EXPECTED_RESIDENTS, "ten distinct resident physics RIDs are registered")
	_check(penetrations.is_empty(), "no resident capsule penetrates scenery, player or another resident beyond 1 cm")
	_check(town.snapshot().life.seq == _initial.life.seq, "the geometry probe invents no life event or resident decision")
	if _cold_read:
		_check(FileAccess.get_file_as_bytes(_save_path) == _before, "cold paused street load preserves exact save bytes")
	var payload := {"scenario": "ten-world-street-physics", "checks": _checks,
		"failure_count": _failures.size(), "failures": _failures,
		"evidence_kind": "real_engine_scene_capsule_and_scenery_physics", "cold_read": _cold_read,
		"negative_control_obstacle": _inject_obstacle,
		"process_id": OS.get_process_id(), "physics_frames": SETTLE_FRAMES,
		"gravity_executed": not _cold_read, "contact_tolerance_metres": CONTACT_TOLERANCE,
		"world_id": town.snapshot().world_id, "bodies": bodies.size(),
		"resident_rids": resident_rids.size(), "penetrations": penetrations, "residents": rows,
		"model_calls": 0, "provenance": "offline paused scene read" if _cold_read else "offline geometry diagnostic with actual gravity; no autonomous model choices"}
	DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
	var output := FileAccess.open(_out_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write physics evidence")
		quit(2)
		return
	output.store_string(JSON.stringify(payload, "  "))
	output.close()
	if not _screenshot.is_empty() and DisplayServer.get_name() != "headless":
		var camera: Camera3D = _scene.get("_camera")
		camera.global_position = Vector3(0, 6, 15)
		camera.look_at(Vector3(0, 1, 5))
		_scene.call("_refresh")
		# This test suppresses choices with scripted_trade, but runs no trade.
		# Label the diagnostic screenshot truthfully rather than inheriting that HUD.
		var status: Label = _scene.get("status")
		status.text = "独立新建十人世界 · 离线物理验收\n10个存档身份 · 10个真实身体 · 无模型调用\n实际重力落地 · 胶囊碰撞与脚下铺路已检查\n世界已暂停 · 生活事件 %d" % town.snapshot().life.seq
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(_screenshot.get_base_dir())
		var capture_error := root.get_texture().get_image().save_png(_screenshot)
		if capture_error != OK:
			push_error("Cannot write physics screenshot")
			quit(2)
			return
	print(JSON.stringify(payload))
	quit(0 if _failures.is_empty() else 1)
