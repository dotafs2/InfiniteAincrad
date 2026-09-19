extends SceneTree
## Short, controlled replay from a disposable copy of the failed seq165 world.
## The caller owns the copy. This script issues one new approach and no model call.

const TownScene = preload("res://scenes/town_street.tscn")
const ACTOR := "shared:carpenter"
const TARGET := "shared:smith"
const PRIOR_COMMAND := "fixture:resource-chain:meet_smith"
const COMMAND := "fixture:resource-chain:meet_smith:local-steering-replay"

var scene: Node
var out := ""
var phase := "boot"
var seconds := 0.0
var frames := 0
var checks := 0
var failures: Array[String] = []
var start_positions: Dictionary = {}
var last := Vector3.ZERO
var target := Vector3.INF
var walked := 0.0
var max_step := 0.0
var max_speed := 0.0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty():
		push_error("failed-world replay requires --out; TownStreet also requires --town-save")
		quit(2)
		return
	Engine.time_scale = 4.0
	_open.call_deferred()

func _open() -> void:
	scene = TownScene.instantiate()
	scene.scripted_trade = true
	root.add_child(scene)
	scene.paused = false
	var snap: Dictionary = scene.town.snapshot()
	check(int(snap.life.get("seq", -1)) == 165, "replay begins from the disposable failed seq165 copy")
	var prior: Dictionary = snap.godot.get("trade", {}).get("commands", {}).get(PRIOR_COMMAND, {})
	check(prior.get("status") == "rejected" and prior.get("result", {}).get("code") == "approach_blocked",
		"source copy contains the exact earlier blocked approach")
	check(not snap.godot.get("trade", {}).get("commands", {}).has(COMMAND), "new replay command has not run before")
	for id in scene.town.active_ids():
		start_positions[id] = scene.town.position_of(id)
	last = scene.town.position_of(ACTOR)

func _physics_process(delta: float) -> bool:
	if phase == "done" or not is_instance_valid(scene):
		return false
	frames += 1
	seconds += delta
	if phase == "boot" and frames >= 8:
		_start_approach()
		if phase == "done":
			return false
	var here: Vector3 = scene.town.position_of(ACTOR)
	var step := here - last
	step.y = 0.0
	walked += step.length()
	max_step = maxf(max_step, step.length())
	last = here
	var body: CharacterBody3D = scene.bodies.get(ACTOR)
	if is_instance_valid(body):
		max_speed = maxf(max_speed, Vector2(body.velocity.x, body.velocity.z).length())
	if phase == "running":
		var command: Dictionary = scene.town.snapshot().godot.get("trade", {}).get("commands", {}).get(COMMAND, {})
		if command.get("status") != "pending":
			check(command.get("status") == "completed" and command.get("result", {}).get("code") == "approach",
				"new physical approach completes instead of blocking: " + JSON.stringify(command))
			check(_flat_distance(here, target) <= 0.45, "body reaches the original world arrival gate")
			check(walked > 0.5 and walked < 15.0, "short replay walks a bounded route without looping")
			check(max_step < 0.10 and max_speed <= 1.37, "movement keeps the established speed and physical step")
			for id in start_positions:
				if id != ACTOR:
					check(_flat_distance(scene.town.position_of(id), start_positions[id]) < 0.001,
						"approach does not move bystander " + str(id))
			_finish()
	if seconds > 45.0:
		check(false, "new short approach exceeded 45 world seconds")
		_finish()
	return false

func _start_approach() -> void:
	for option in scene.town.trade_options(ACTOR):
		if option.get("action") != "approach" or str(option.get("counterparty", "")) != TARGET:
			continue
		var raw: Array = option.get("target_position", [])
		check(raw.size() == 3, "new approach exposes its unchanged meeting target")
		if raw.size() != 3:
			_finish()
			return
		target = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		var admitted: Dictionary = scene.town.transaction(scene._save_path, func():
			return scene.town.submit_trade(ACTOR, str(option.id), COMMAND, "opengameagent_fixture"))
		check(admitted.ok and admitted.get("pending", false), "one explicit fixture approach is admitted")
		if not admitted.ok:
			_finish()
			return
		phase = "running"
		return
	check(false, "failed copy offers no new approach to Flint")
	_finish()

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	scene.paused = true
	var snap: Dictionary = scene.town.snapshot()
	var result := {"suite": "town_social_failed_world_replay", "checks": checks,
		"failures": failures, "paid_calls": 0, "controlled_copy": true,
		"source_seq": 165, "final_seq": int(snap.life.get("seq", -1)),
		"target": [target.x, target.y, target.z] if target.is_finite() else [],
		"final_position": _array(scene.town.position_of(ACTOR)), "walked_metres": walked,
		"max_sample_step_m": max_step, "max_speed_mps": max_speed, "world_seconds": seconds,
		"command": snap.godot.get("trade", {}).get("commands", {}).get(COMMAND, {})}
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("cannot write replay result")
		quit(2)
		return
	file.store_string(JSON.stringify(result, "  ", true, true))
	file.close()
	print(JSON.stringify(result))
	scene.queue_free()
	_exit.call_deferred()

func _exit() -> void:
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _flat_distance(first: Vector3, second: Vector3) -> float:
	var offset := first - second
	offset.y = 0.0
	return offset.length()

func _array(point: Vector3) -> Array:
	return [point.x, point.y, point.z]
