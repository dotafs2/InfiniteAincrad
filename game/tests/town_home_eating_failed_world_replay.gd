extends SceneTree
## Physical continuation of the two already-accepted meals in a disposable seq151 copy.
## The caller owns the copy. This script submits no command and makes no model call.

const TownScene = preload("res://scenes/town_street.tscn")
const ACTORS := {
	"shared:herder": "turn:shared:herder:0:8",
	"shared:fisher": "turn:shared:fisher:0:10",
}
const SOURCE_POSITIONS := {
	"shared:herder": Vector3(34.560272216796875, 0.0009345522848889232, 80.51966857910156),
	"shared:fisher": Vector3(31.647245407104492, 0.0009349967585876584, 52.41352462768555),
}
const ARRIVAL_RADIUS := 0.45
const EAT_SECONDS := 30.0

var scene: Node
var out := ""
var phase := "boot"
var seconds := 0.0
var checks := 0
var failures: Array[String] = []
var start_positions: Dictionary = {}
var traces: Dictionary = {}

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
		push_error("home-eating replay requires --out; TownStreet also requires --town-save")
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
	check(int(snap.life.get("seq", -1)) == 151, "replay begins from the disposable failed seq151 copy")
	check(snap.godot.get("pending", {}).size() == 2, "source copy contains exactly the two accepted meals")
	for id in scene.town.active_ids():
		start_positions[id] = scene.town.position_of(id)
	for id in ACTORS:
		var job: Dictionary = scene.town.pending_job(id)
		var command_id: String = ACTORS[id]
		check(job.get("action") == "eat_ration" and str(job.get("command_id", "")) == command_id,
			"source copy contains the exact accepted meal for " + str(id))
		check(float(job.get("elapsed", -1.0)) == 0.0, "accepted meal has accrued no work for " + str(id))
		var command: Dictionary = snap.godot.get("commands", {}).get(command_id, {})
		check(command.get("status") == "pending", "original meal command remains pending for " + str(id))
		var here: Vector3 = scene.town.position_of(id)
		var target: Vector3 = scene.town.destination(id, "eat_ration")
		check(_flat_distance(here, SOURCE_POSITIONS[id]) < 0.001, "replay starts at the measured stalled position for " + str(id))
		check(_flat_distance(target, scene.town.home_point(id)) < 0.001,
			"meal keeps the resident's existing home destination for " + str(id))
		var remaining := _flat_distance(here, target)
		check(remaining > ARRIVAL_RADIUS and remaining <= 4.0,
			"stalled meal starts outside arrival but inside the bounded final route for " + str(id))
		traces[id] = {"last": here, "target": target, "walked": 0.0, "max_step": 0.0,
			"max_speed": 0.0, "arrival_seconds": -1.0, "first_work_seconds": -1.0,
			"completion_seconds": -1.0, "initial_food": int(scene.town.account(id).food),
			"initial_satiety": float(scene.town.resident(id).needs.hunger), "completed": false}
	phase = "running"

func _physics_process(delta: float) -> bool:
	if phase != "running" or not is_instance_valid(scene):
		return false
	seconds += delta
	for id in ACTORS:
		var trace: Dictionary = traces[id]
		var here: Vector3 = scene.town.position_of(id)
		var step := _flat_distance(here, trace.last)
		trace.walked += step
		trace.max_step = maxf(float(trace.max_step), step)
		trace.last = here
		var body: CharacterBody3D = scene.bodies.get(id)
		if is_instance_valid(body):
			trace.max_speed = maxf(float(trace.max_speed), Vector2(body.velocity.x, body.velocity.z).length())
		if float(trace.arrival_seconds) < 0.0 and _flat_distance(here, trace.target) <= ARRIVAL_RADIUS:
			trace.arrival_seconds = seconds
		var job: Dictionary = scene.town.pending_job(id)
		if not job.is_empty() and float(job.get("elapsed", 0.0)) > 0.0 and float(trace.first_work_seconds) < 0.0:
			trace.first_work_seconds = seconds
		if job.is_empty() and not bool(trace.completed):
			trace.completed = true
			trace.completion_seconds = seconds
			_check_completion(id, trace)
		traces[id] = trace
	if _all_completed():
		for id in start_positions:
			if id not in ACTORS:
				check(_flat_distance(scene.town.position_of(id), start_positions[id]) < 0.001,
					"meal replay does not move bystander " + str(id))
		_finish()
	elif seconds > 60.0:
		check(false, "existing meals exceeded their 30-second work plus bounded travel allowance")
		_finish()
	return false

func _check_completion(id: String, trace: Dictionary) -> void:
	var command_id: String = ACTORS[id]
	var snap: Dictionary = scene.town.snapshot()
	var command: Dictionary = snap.godot.get("commands", {}).get(command_id, {})
	check(command.get("status") == "completed" and command.get("result", {}).get("code") == "eat_ration",
		"existing meal completes through its original command for " + id + ": " + JSON.stringify(command))
	check(float(trace.arrival_seconds) >= 0.0 and float(trace.arrival_seconds) < 15.0,
		"resident physically reaches the unchanged home gate before eating for " + id)
	check(float(trace.first_work_seconds) >= float(trace.arrival_seconds),
		"meal work begins only after physical arrival for " + id)
	check(float(trace.completion_seconds) - float(trace.first_work_seconds) >= EAT_SECONDS - 1.0,
		"meal keeps the existing 30-second work duration for " + id)
	check(float(trace.walked) > 0.5 and float(trace.walked) < 12.0,
		"short home replay walks a bounded physical route for " + id)
	check(float(trace.max_step) < 0.10 and float(trace.max_speed) <= 1.37,
		"movement keeps the established physical step and 1.35 m/s speed for " + id)
	check(int(scene.town.account(id).food) == int(trace.initial_food) - 1,
		"completed meal consumes exactly one held ration for " + id)
	check(float(scene.town.resident(id).needs.hunger) > float(trace.initial_satiety),
		"completed meal increases the resident's satiety for " + id)
	var events: Array = snap.life.get("events", []).filter(func(event: Dictionary) -> bool:
		return str(event.get("operation_id", "")) == command_id and event.get("type") == "eat_ration")
	check(events.size() == 1, "meal records exactly one authoritative event for " + id)

func _all_completed() -> bool:
	for id in ACTORS:
		if not bool(traces[id].completed):
			return false
	return true

func _flat_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()

func _array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	if is_instance_valid(scene):
		scene.paused = true
	var snap: Dictionary = scene.town.snapshot() if is_instance_valid(scene) else {}
	var evidence := {}
	for id in traces:
		var trace: Dictionary = traces[id]
		evidence[id] = {"target": _array(trace.target), "final_position": _array(scene.town.position_of(id)),
			"walked_metres": trace.walked, "arrival_world_seconds": trace.arrival_seconds,
			"first_work_world_seconds": trace.first_work_seconds, "completion_world_seconds": trace.completion_seconds,
			"max_sample_step_m": trace.max_step, "max_speed_mps": trace.max_speed,
			"command": snap.get("godot", {}).get("commands", {}).get(ACTORS[id], {})}
	var result := {"suite": "town_home_eating_failed_world_replay", "checks": checks,
		"failures": failures, "paid_calls": 0, "controlled_copy": true, "source_seq": 151,
		"final_seq": int(snap.get("life", {}).get("seq", -1)), "world_seconds": seconds,
		"actors": evidence}
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("cannot write home-eating replay result: " + out)
		quit(2)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print(JSON.stringify(result))
	quit(1 if not failures.is_empty() else 0)
