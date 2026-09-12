extends "res://tests/ten_world_forage_probe.gd"
## Independent H33 acceptance on the SAME disposable save. No runtime edits,
## relocation, resource grants, time scaling, model or gateway calls.

var _mode := ""
var _seconds := 60.0
var _bytes := PackedByteArray()
var _motion: MotionSampler
var _blocked_id := ""

class MotionSampler extends Node:
	var bodies: Dictionary = {}
	var previous: Dictionary = {}
	var max_steps: Dictionary = {}
	var bad_steps: Array = []
	var overlap_frames := 0
	var mask_failures := 0
	var frames := 0
	func _physics_process(delta: float) -> void:
		frames += 1
		for id in bodies:
			var body: CharacterBody3D = bodies[id]
			if body.collision_layer == 0 or body.collision_mask == 0:
				mask_failures += 1
			if previous.has(id):
				var difference: Vector3 = body.position - previous[id]
				difference.y = 0
				max_steps[id] = maxf(max_steps.get(id, 0.0), difference.length())
				if difference.length() > 1.35 * delta + 0.05:
					bad_steps.append({"id": id, "metres": difference.length(), "delta": delta})
			previous[id] = body.position
			for child in body.get_children():
				if not child is CollisionShape3D or not child.shape is CapsuleShape3D:
					continue
				if child.disabled:
					mask_failures += 1
				var shape: CapsuleShape3D = child.shape.duplicate()
				shape.radius -= 0.01
				shape.height -= 0.02
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.transform = child.global_transform
				query.collision_mask = body.collision_mask
				query.exclude = [body.get_rid()]
				query.margin = 0.0
				if not body.get_world_3d().direct_space_state.intersect_shape(query, 32).is_empty():
					overlap_frames += 1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="):
			_save = arg.trim_prefix("--town-save=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		elif arg != "--town-restore":
			push_error("Unexpected acceptance argument: " + arg)
			quit(2)
			return
	if _mode not in ["install", "run", "cold", "occupied", "idle-policy"] or not _allowed(_save) or not _allowed(_out) \
			or _save == _out or FileAccess.file_exists(_out) or FileAccess.file_exists(_out + ".baseline.json") \
			or _seconds < 20 or _seconds > 90:
		push_error("Use install/run/cold/occupied, a disposable save and NEW output in the ten-world directory")
		quit(2)
		return
	if _mode == "cold" and not OS.get_cmdline_user_args().has("--town-restore"):
		push_error("Cold acceptance requires --town-restore")
		quit(2)
		return
	_bytes = FileAccess.get_file_as_bytes(_save)
	var parsed: Variant = JSON.parse_string(_bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("origin", {}).get("kind") != "new_world_seed":
		push_error("Expected independent world provenance")
		quit(2)
		return
	_baseline = parsed
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var backup := FileAccess.open(_out + ".baseline.json", FileAccess.WRITE)
	if backup == null:
		quit(2)
		return
	backup.store_buffer(_bytes)
	backup.close()
	_accept.call_deferred()

func _normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))

func _layout(town: RefCounted) -> Dictionary:
	return town.snapshot().godot.get("foraging_work_spots", {})

func _original_done(town: RefCounted) -> bool:
	for id in _baseline.godot.pending:
		var command: String = _baseline.godot.pending[id].command_id
		if town.snapshot().godot.commands.get(command, {}).get("status", "pending") == "pending":
			return false
	return true

func _inspect_layout(town: RefCounted) -> void:
	var positions: Dictionary = _layout(town).get("positions", {})
	_check(positions.size() == 10, "persisted layout supplies ten distinct resident work positions")
	var exclusions: Array[RID] = []
	for body in _scene.get("bodies").values():
		exclusions.append(body.get_rid())
	var player: CharacterBody3D = _scene.get("_player")
	exclusions.append(player.get_rid())
	var space := _scene.get_world_3d().direct_space_state
	for id in positions:
		var p: Array = positions[id]
		var point := Vector3(p[0], p[1], p[2])
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point - Vector3.UP * 0.3, 0xFFFFFFFF, exclusions)
		var support := space.intersect_ray(ray)
		_check(not support.is_empty() and support.get("normal", Vector3.ZERO).y >= 0.7, "%s work spot has actual walkable support" % id)
		var shape := CapsuleShape3D.new()
		shape.radius = 0.24
		shape.height = 1.48
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), point + Vector3.UP * 0.75)
		query.collision_mask = 0xFFFFFFFF
		query.exclude = exclusions
		query.margin = 0.0
		_check(space.intersect_shape(query, 32).is_empty(), "%s work spot capsule clears actual scenery" % id)

func _accept() -> void:
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	var town: RefCounted = _scene.get("town")
	_check(town.active_ids().size() == 10 and _scene.get("bodies").size() == 10, "same save binds ten actual bodies")
	_check(not _scene.get("gateway_mode") and _scene.get("model_turns") == null, "no model controllers or gateway exist")
	_motion = MotionSampler.new()
	_motion.bodies = _scene.get("bodies")
	for id in _motion.bodies:
		_motion.previous[id] = _motion.bodies[id].position
	root.add_child(_motion)
	if _mode == "install":
		_check(_layout(town).is_empty(), "installation begins without a preexisting layout")
		_scene.set("paused", false)
		for frame in 2:
			await physics_frame
		_scene.set("paused", true)
		_check(_normalized(town.snapshot().godot.pending) == _baseline.godot.pending, "layout installation preserves every original job and elapsed work")
		_check(town.snapshot().foraging.stock == _baseline.foraging.stock, "layout installation grants no stock")
		_check(town.snapshot().life.seq == _baseline.life.seq + 1, "installation appends exactly one attributed host event")
		var event: Dictionary = town.snapshot().life.events.back()
		_check(event.get("type") == "foraging_work_spots_installed" and event.get("recipient_ids", []) == [], "installation diagnostics are not broadcast into NPC memories")
	else:
		_check(not _layout(town).is_empty(), "acceptance continues the already installed persistent layout")
		for frame in 2:
			await physics_frame
	_inspect_layout(town)
	var original_layout: Dictionary = _layout(town).duplicate(true)
	var outcomes: Array = []
	var observed_seconds := 0.0
	if _mode == "idle-policy" and _failures.is_empty():
		var idle_positions: Dictionary = {}
		for id in town.active_ids():
			if town.pending_job(id).is_empty():
				idle_positions[id] = town.position_of(id)
		_check(not idle_positions.is_empty(), "idle-policy control has job-empty residents")
		_scene.set("scripted_trade", true)
		_scene.set("paused", false)
		await create_timer(2.0).timeout
		_scene.set("paused", true)
		for id in idle_positions:
			var difference: Vector3 = town.position_of(id) - idle_positions[id]
			difference.y = 0
			_check(difference.length() < 0.01, "%s is not forced to leave while ordinary idle routing is suppressed" % id)
		_check(town.transaction(_save, func(): return {"ok": true}).get("ok", false), "idle-policy control saves normally")
	if _mode in ["run", "occupied"] and _failures.is_empty():
		if _mode == "occupied":
			var furthest := 0.0
			for id in _baseline.godot.pending:
				var distance: float = town.position_of(id).distance_to(town.destination(id, "harvest_ration"))
				var clear_of_bodies := true
				for other_id in town.active_ids():
					if town.position_of(other_id).distance_to(town.destination(id, "harvest_ration")) < 0.85:
						clear_of_bodies = false
				if clear_of_bodies and distance > furthest:
					furthest = distance
					_blocked_id = id
			_check(not _blocked_id.is_empty() and furthest > 0.9, "negative control starts away from its assigned spot")
			if not _blocked_id.is_empty():
				var obstacle := StaticBody3D.new()
				obstacle.name = "H33OccupiedSpotNegativeControl"
				var collision := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.8, 1.6, 0.8)
				collision.shape = box
				obstacle.add_child(collision)
				_scene.add_child(obstacle)
				obstacle.position = town.destination(_blocked_id, "harvest_ration") + Vector3.UP * 0.8
				await physics_frame
				await physics_frame
		var started := Time.get_ticks_msec()
		_sample(town, 0)
		_scene.set("paused", false)
		while _failures.is_empty() and Time.get_ticks_msec() - started < int(_seconds * 1000):
			await create_timer(0.5).timeout
			observed_seconds = float(Time.get_ticks_msec() - started) / 1000
			_sample(town, observed_seconds)
			if _mode == "run" and _original_done(town):
				break
		_scene.set("paused", true)
		_check(town.transaction(_save, func(): return {"ok": true}).get("ok", false), "continuation saves through the ordinary writer transaction")
		for id in _baseline.godot.pending:
			var command: String = _baseline.godot.pending[id].command_id
			var record: Dictionary = town.snapshot().godot.commands.get(command, {})
			outcomes.append({"id": id, "original_command": command, "status": record.get("status"), "result": record.get("result", {}),
				"pending": town.pending_job(id), "distance_to_work_target": town.position_of(id).distance_to(town.destination(id, "harvest_ration"))})
			if _mode == "run":
				_check(record.get("status") in ["completed", "rejected"], "%s original command reaches a terminal world outcome" % id)
				_check(record.get("result", {}).get("code") in ["harvest_ration", "resources_unavailable"], "%s outcome is earned food or truthful depletion" % id)
		if _mode == "occupied" and not _blocked_id.is_empty():
			_check(town.pending_job(_blocked_id).get("command_id") == _baseline.godot.pending[_blocked_id].command_id,
				"occupied work spot retains its original unfinished command")
			_check(town.pending_job(_blocked_id).get("elapsed") == _baseline.godot.pending[_blocked_id].elapsed,
				"a blocked work spot accumulates no fictional labor")
			_check(town.position_of(_blocked_id).distance_to(town.destination(_blocked_id, "harvest_ration")) > 0.45,
				"actual capsule collision stops the resident outside work range")
	var final: Dictionary = town.snapshot()
	_check(_normalized(final.godot.berry_position) == _baseline.godot.berry_position, "original berry center remains unchanged")
	_check(_normalized(final.origin) == _baseline.origin and _normalized(final.seed) == _baseline.seed, "genesis facts remain unchanged")
	_check(_normalized(final.life.events.slice(0, _baseline.life.events.size())) == _baseline.life.events, "old history remains an exact prefix")
	_check(_normalized(_layout(town)) == _normalized(original_layout), "the installed work positions never silently regenerate")
	for key in ["items", "skills", "accounts", "contracts"]:
		_check(_normalized(final.life[key]) == _baseline.life[key], "%s remains conserved" % key)
	var food_before := 0
	var food_after := 0
	for account in _baseline.survival.accounts:
		food_before += int(account.food)
	for account in final.survival.accounts:
		food_after += int(account.food)
	_check(food_after - food_before == int(_baseline.foraging.stock) - int(final.foraging.stock), "food gained equals finite source depletion exactly")
	_check(final.foraging.stock >= 0 and final.foraging.stock <= _baseline.foraging.stock, "no negative or granted stock")
	_check(_motion.bad_steps.is_empty(), "every observed physics displacement stays within movement speed plus contact tolerance")
	_check(_motion.mask_failures == 0, "all resident masks and capsules remain enabled")
	_check(_motion.overlap_frames == 0, "no capsule penetrates scenery or residents beyond 1 cm during the observed frames")
	if _mode == "cold":
		_check(FileAccess.get_file_as_bytes(_save) == _bytes, "paused cold load preserves exact save bytes")
	var payload := {"scenario": "h33-independent-acceptance", "mode": _mode, "checks": _checks,
		"failure_count": _failures.size(), "failures": _failures, "process_id": OS.get_process_id(),
		"world_id": final.world_id, "before_seq": _baseline.life.seq, "after_seq": final.life.seq,
		"stock_before": _baseline.foraging.stock, "stock_after": final.foraging.stock,
		"layout": _layout(town), "original_job_outcomes": outcomes, "negative_control_id": _blocked_id,
		"wall_seconds": observed_seconds, "physics_frames": _motion.frames, "max_steps": _motion.max_steps,
		"bad_steps": _motion.bad_steps, "overlap_frames": _motion.overlap_frames,
		"mask_failures": _motion.mask_failures, "samples": _samples, "model_calls": 0,
		"provenance": "independent actual scene acceptance; ordinary offline time; no relocation or resource grants"}
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	print(JSON.stringify({"mode": _mode, "checks": _checks, "failures": _failures, "stock_after": final.foraging.stock,
		"after_seq": final.life.seq, "process_id": OS.get_process_id()}))
	quit(0 if _failures.is_empty() else 1)
