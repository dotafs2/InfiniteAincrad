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
var last_action: Dictionary = {}
var boot_ms := Time.get_ticks_msec()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--experiment-dir="):
			directory = arg.trim_prefix("--experiment-dir=").replace("\\", "/")
		if arg.begins_with("--town-save="):
			save_path = arg.trim_prefix("--town-save=").replace("\\", "/")
	if directory.is_empty() or not save_path.begins_with(directory + "/"):
		quit(2)
		return
	Engine.max_fps = 240
	Engine.time_scale = 4.0
	_boot.call_deferred()

func _boot() -> void:
	var packed = load("res://scenes/town_street.tscn")
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.scripted_trade = true
	scene.restore_only = true
	scene.paused = true
	for i in range(12):
		await physics_frame
	_write("ready.json", {"ready": scene.status != null, "world_id": scene.town._state.world_id,
		"resident_ids": scene.town.active_ids(), "physics": "original town scene"})

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
				scene.town._state.godot["interface_experiment"] = request.get("plan_state", {}).duplicate(true)
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
		"pending": town.pending_job(resident_id), "archive_count": town._state.godot.get("resident_archive", {}).get("order", []).size()}

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
