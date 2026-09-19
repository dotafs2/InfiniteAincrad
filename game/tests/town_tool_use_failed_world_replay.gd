extends SceneTree
## Short replay of the already-pending tool job in a disposable copy of the failed seq168 world.
## The caller owns the copy. This script submits no command and makes no model call.

const TownScene = preload("res://scenes/town_street.tscn")
const ACTOR := "shared:carpenter"
const COMMAND := "fixture:resource-chain:use_repaired_axe"
const ARRIVAL_RADIUS := 0.45

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
var arrival_seconds := -1.0
var initial_wood := -1
var initial_kindling := -1

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
		push_error("tool-use failed-world replay requires --out; TownStreet also requires --town-save")
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
	check(int(snap.life.get("seq", -1)) == 168, "replay begins from the disposable failed seq168 copy")
	var job: Dictionary = scene.town.pending_job(ACTOR)
	check(job.get("action") == "use_tool" and str(job.get("command_id", "")) == COMMAND,
		"source copy contains the exact pending repaired-axe use job")
	check(float(job.get("elapsed", -1.0)) == 0.0 and float(job.get("duration_seconds", -1.0)) == 60.0,
		"pending tool job has done no work and keeps the original duration")
	var command: Dictionary = snap.godot.get("trade", {}).get("commands", {}).get(COMMAND, {})
	check(command.get("status") == "pending", "original tool-use command is still pending")
	var raw: Array = job.get("target_position", [])
	check(raw.size() == 3, "pending tool job keeps its accepted target")
	if raw.size() != 3:
		_finish()
		return
	target = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	for id in scene.town.active_ids():
		start_positions[id] = scene.town.position_of(id)
	last = scene.town.position_of(ACTOR)
	var account := _account(snap, ACTOR)
	initial_wood = int(account.get("wood", -1))
	initial_kindling = int(account.get("kindling", -1))
	var axe := _item(snap, "seed:axe")
	check(initial_wood >= 1 and int(axe.get("edge", -1)) == 100 and int(axe.get("handle", -1)) == 100
		and str(axe.get("custodian_id", "")) == ACTOR,
		"source copy has the real wood and repaired axe required by the pending work")
	phase = "running"

func _physics_process(delta: float) -> bool:
	if phase != "running" or not is_instance_valid(scene):
		return false
	frames += 1
	seconds += delta
	var here: Vector3 = scene.town.position_of(ACTOR)
	var step := here - last
	step.y = 0.0
	walked += step.length()
	max_step = maxf(max_step, step.length())
	last = here
	var body: CharacterBody3D = scene.bodies.get(ACTOR)
	if is_instance_valid(body):
		max_speed = maxf(max_speed, Vector2(body.velocity.x, body.velocity.z).length())
	if arrival_seconds < 0.0 and _flat_distance(here, target) <= ARRIVAL_RADIUS:
		arrival_seconds = seconds
	var snap: Dictionary = scene.town.snapshot()
	var command: Dictionary = snap.godot.get("trade", {}).get("commands", {}).get(COMMAND, {})
	if command.get("status") != "pending":
		check(command.get("status") == "completed" and command.get("result", {}).get("code") == "use_tool",
			"existing physical tool job completes instead of remaining pending: " + JSON.stringify(command))
		check(scene.town.pending_job(ACTOR).is_empty(), "completed tool job releases the resident")
		check(arrival_seconds >= 0.0 and arrival_seconds < 15.0,
			"resident physically reaches the unchanged home target on the bounded final leg")
		check(_flat_distance(here, target) <= ARRIVAL_RADIUS,
			"resident remains inside the original world arrival gate while work completes")
		check(walked > 0.5 and walked < 15.0, "short replay walks a bounded route without looping")
		check(max_step < 0.10 and max_speed <= 1.37,
			"movement keeps the established physical step and 1.35 m/s speed")
		var final_account := _account(snap, ACTOR)
		check(int(final_account.get("wood", -1)) == initial_wood - 1
			and int(final_account.get("kindling", -1)) == initial_kindling + 1,
			"only completed work consumes one wood and creates one kindling")
		var events: Array = snap.life.get("events", []).filter(func(event: Dictionary) -> bool:
			return str(event.get("operation_id", "")) == COMMAND and event.get("type") == "use_tool")
		check(events.size() == 1, "tool completion records exactly one authoritative use event")
		for id in start_positions:
			if id != ACTOR:
				check(_flat_distance(scene.town.position_of(id), start_positions[id]) < 0.001,
					"tool replay does not move bystander " + str(id))
		_finish()
	elif seconds > 90.0:
		check(false, "existing tool job exceeded its 60-second work plus bounded travel allowance")
		_finish()
	return false

func _account(snap: Dictionary, id: String) -> Dictionary:
	for account in snap.life.get("accounts", []):
		if account is Dictionary and str(account.get("resident_id", "")) == id:
			return account
	return {}

func _item(snap: Dictionary, id: String) -> Dictionary:
	for item in snap.life.get("items", []):
		if item is Dictionary and str(item.get("id", "")) == id:
			return item
	return {}

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	if is_instance_valid(scene):
		scene.paused = true
	var snap: Dictionary = scene.town.snapshot() if is_instance_valid(scene) else {}
	var result := {"suite": "town_tool_use_failed_world_replay", "checks": checks,
		"failures": failures, "paid_calls": 0, "controlled_copy": true,
		"source_seq": 168, "final_seq": int(snap.get("life", {}).get("seq", -1)),
		"target": [target.x, target.y, target.z] if target.is_finite() else [],
		"final_position": _array(scene.town.position_of(ACTOR)) if is_instance_valid(scene) else [],
		"walked_metres": walked, "arrival_world_seconds": arrival_seconds,
		"max_sample_step_m": max_step, "max_speed_mps": max_speed, "world_seconds": seconds,
		"command": snap.get("godot", {}).get("trade", {}).get("commands", {}).get(COMMAND, {})}
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("cannot write tool-use replay result: " + out)
		quit(2)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print(JSON.stringify(result))
	quit(1 if not failures.is_empty() else 0)
