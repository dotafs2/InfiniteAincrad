extends SceneTree
## Isolated experiment host. Uses the real town scene, rules, bodies and save lock.
## No provider, fixture policy, teleport or automatic resident controller runs here.

var scene
var directory := ""
var save_path := ""
var pending: Dictionary = {}
var started_at := 0.0
var last_poll := 0
var resident_id := "shared:well-keeper"
const LEGACY_SINGLE_RESIDENT_ID := "shared:well-keeper"
var last_action: Dictionary = {}
var boot_ms := Time.get_ticks_msec()
var diagnose_live_layout := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--experiment-dir="):
			directory = arg.trim_prefix("--experiment-dir=").replace("\\", "/")
		if arg.begins_with("--town-save="):
			save_path = arg.trim_prefix("--town-save=").replace("\\", "/")
		if arg == "--diagnose-live-layout":
			diagnose_live_layout = true
	if directory.is_empty() or not save_path.begins_with(directory + "/"):
		quit(2)
		return
	Engine.max_fps = 240
	Engine.time_scale = 4.0
	_boot.call_deferred()

func _boot() -> void:
	var packed = load("res://scenes/town_street.tscn")
	scene = packed.instantiate()
	var runtime = _runtime_override()
	if runtime != null:
		scene.town = runtime
	root.add_child(scene)
	current_scene = scene
	scene.scripted_trade = true
	scene.restore_only = not diagnose_live_layout
	scene.paused = not diagnose_live_layout
	for i in range(12):
		await physics_frame
	var ready := {"ready": scene.status != null, "world_id": scene.town._state.world_id,
		"resident_ids": scene.town.active_ids(), "physics": "original town scene"}
	if diagnose_live_layout:
		ready["layout_diagnostic"] = _layout_diagnostic()
	_write("ready.json", ready)

func _runtime_override():
	return null

func _layout_diagnostic() -> Dictionary:
	var center: Vector3 = scene.town.berry_center()
	var result := {"paused": scene.paused, "latest": scene.latest,
		"foraging_layout_status": scene.foraging_layout_status.duplicate(true),
		"berry_position": [center.x, center.y, center.z],
		"layout_attempted": scene._foraging_layout_attempted,
		"spaced_foraging": scene._spaced_foraging, "candidates": []}
	if scene.bodies.is_empty():
		result["candidate_error"] = "no_resident_bodies"
		return result
	var prototype: CharacterBody3D = scene.bodies.values()[0]
	var capsule: CollisionShape3D = null
	for child in prototype.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			capsule = child
	if capsule == null:
		result["candidate_error"] = "no_capsule"
		return result
	var exclude: Array[RID] = [scene._player.get_rid()]
	for body in scene.bodies.values():
		exclude.append(body.get_rid())
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for radius in [1.6, 1.85, 1.35]:
		for rotation in [0.0, PI / 10.0, PI / 20.0, PI * 3.0 / 20.0]:
			for index in 10:
				var angle: float = TAU * float(index) / 10.0 + float(rotation)
				var trial := center + Vector3(cos(angle), 0.0, sin(angle)) * float(radius)
				var ray := PhysicsRayQueryParameters3D.create(trial + Vector3.UP * 0.4,
					trial - Vector3.UP * 0.4, prototype.collision_mask, exclude)
				var hit: Dictionary = space.intersect_ray(ray)
				var row := {"radius": radius, "rotation": rotation, "index": index,
					"trial": [trial.x, trial.y, trial.z]}
				if hit.is_empty():
					row["reason"] = "no_floor"
					result.candidates.append(row)
					continue
				var point: Vector3 = hit.position
				row["floor"] = [point.x, point.y, point.z]
				row["floor_normal_up"] = Vector3(hit.normal).dot(Vector3.UP)
				row["center_height_delta"] = absf(point.y - center.y)
				if float(row.floor_normal_up) < 0.7:
					row["reason"] = "steep_floor"
				elif float(row.center_height_delta) > 0.10:
					row["reason"] = "center_height_delta"
				else:
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = capsule.shape
					var transform := prototype.global_transform
					transform.origin = point
					query.transform = transform * capsule.transform
					query.transform.origin.y += 0.025
					query.collision_mask = prototype.collision_mask
					query.exclude = exclude
					var overlaps: Array[Dictionary] = space.intersect_shape(query, 8)
					row["reason"] = "clear" if overlaps.is_empty() else "shape_blocked"
					row["overlaps"] = []
					for overlap in overlaps:
						var collider: Variant = overlap.get("collider")
						row.overlaps.append({"name": str(collider.name) if collider is Node else "",
							"class": str(collider.get_class()) if collider is Object else ""})
				result.candidates.append(row)
	return result

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - boot_ms > 900000:
		_finish_process(3)
		return false
	if scene == null or scene.status == null:
		return false
	if not pending.is_empty():
		var elapsed: float = scene.town._state.godot.elapsed_seconds - started_at
		var finished: bool = scene.town.pending_job(resident_id).is_empty()
		if elapsed >= float(pending.get("seconds", 180.0)) or (finished and elapsed >= 0.5):
			scene.paused = true
			var saved: Dictionary = scene.town.save_to(save_path)
			var result := _observe()
			result["save"] = saved
			result["action_result"] = last_action
			result["advanced_seconds"] = elapsed
			_respond(pending, result)
			pending = {}
		return false
	if Time.get_ticks_msec() - last_poll < 20:
		return false
	last_poll = Time.get_ticks_msec()
	var request_path := directory + "/request.json"
	if not FileAccess.file_exists(request_path):
		return false
	var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
	DirAccess.remove_absolute(request_path)
	if not request is Dictionary:
		return false
	resident_id = str(request.get("resident_id", resident_id))
	if resident_id not in scene.town.active_ids():
		_respond(request, {"ok": false, "code": "unknown_resident"})
		return false
	match str(request.get("op", "")):
		"observe":
			_respond(request, _observe())
		"remember":
			var result: Dictionary = scene.town.transaction(save_path, func():
				var archive: Dictionary = scene.town.record_resident_reply(request.entry)
				if not archive.ok:
					return archive
				_store_plan_state(resident_id, request.get("plan_state", {}))
				return archive)
			_respond(request, result)
		"apply":
			last_action = scene.town.transaction(save_path, func():
				return scene.town.submit_trade(resident_id, str(request.option_id), str(request.command_id), str(request.get("provenance", "opengameagent_live")), str(request.get("speech", ""))))
			if not last_action.get("ok", false):
				var result := _observe()
				result["action_result"] = last_action
				_respond(request, result)
			else:
				pending = request
				started_at = scene.town._state.godot.elapsed_seconds
				scene.paused = false
		"stop":
			_respond(request, {"ok": true, "saved": scene.town.save_to(save_path)})
			_finish_process(0)
	return false

func _observe() -> Dictionary:
	var town = scene.town
	var position: Vector3 = town.position_of(resident_id)
	var home: Vector3 = town.home_point(resident_id)
	var result: Array = []
	for option in town.trade_options(resident_id):
		var entry := {"id": option.id, "action": option.get("action", ""), "label": option.get("label", ""),
			"speech_allowed": option.get("speech_allowed", false)}
		for key in ["counterparty", "target_position", "duration_seconds"]:
			if option.has(key):
				entry[key] = option[key]
		if option.has("_place_id"):
			entry["place_id"] = option._place_id
		result.append(entry)
	return {"ok": true, "world_id": town._state.world_id, "seq": town._state.life.seq,
		"elapsed_seconds": town._state.godot.elapsed_seconds, "view": town.resident_view(resident_id),
		"options": result, "position": [position.x, position.y, position.z],
		"home": [home.x, home.y, home.z], "distance_home": position.distance_to(home),
		"pending": town.pending_job(resident_id), "plan_state": _plan_state(resident_id),
		"archive_count": town._state.godot.get("resident_archive", {}).get("order", []).size()}

func _plan_state(id: String) -> Dictionary:
	var stored: Variant = scene.town._state.godot.get("interface_experiment", {})
	if not stored is Dictionary:
		return {}
	if int(stored.get("schema_version", 0)) == 2:
		var by_resident: Variant = stored.get("by_resident", {})
		if by_resident is Dictionary and by_resident.get(id, {}) is Dictionary:
			return by_resident.get(id, {}).duplicate(true)
		return {}
	# Old H85/H86 records had exactly one fixed resident. Preserve that binding,
	# while never exposing the unbound legacy goal to a different resident.
	var legacy_id := str(stored.get("resident_id", LEGACY_SINGLE_RESIDENT_ID))
	if legacy_id == id:
		return stored.duplicate(true)
	return {}

func _store_plan_state(id: String, value: Variant) -> void:
	var prior: Variant = scene.town._state.godot.get("interface_experiment", {})
	var by_resident := {}
	if prior is Dictionary and int(prior.get("schema_version", 0)) == 2 and prior.get("by_resident", {}) is Dictionary:
		by_resident = prior.by_resident.duplicate(true)
	elif prior is Dictionary:
		var legacy_id := str(prior.get("resident_id", LEGACY_SINGLE_RESIDENT_ID))
		if not legacy_id.is_empty() and legacy_id in scene.town.active_ids():
			by_resident[legacy_id] = prior.duplicate(true)
	by_resident[id] = value.duplicate(true) if value is Dictionary else {}
	scene.town._state.godot["interface_experiment"] = {"schema_version": 2,
		"by_resident": by_resident}

func _respond(request: Dictionary, value: Dictionary) -> void:
	value["request_number"] = request.get("request_number", 0)
	_write("response.json", value)

func _write(name: String, value: Dictionary) -> void:
	var temporary := directory + "/" + name + ".new"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	var target := directory + "/" + name
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	DirAccess.rename_absolute(temporary, target)

func _finish_process(code: int) -> void:
	if scene != null:
		scene.paused = true
		scene.town.release_writer(save_path)
		scene._owns_writer = false
	quit(code)
