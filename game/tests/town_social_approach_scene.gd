extends SceneTree
## Physical observation probe for the reviewed innkeeper-to-smith approach.
##
## Real street scene, real CharacterBody3D residents, real capsule collision and
## real physics steps at Engine.time_scale 1.0. This is an explicitly labelled
## offline fixture: no model call, no manual teleport, no relocated blocker and no
## reduced collision mask. The probe observes only and writes a trace;
## tools/test_town_social_approach.py performs every assertion on the trace, the
## persisted save and the engine's own capture evidence.
##
## Everything is measured on the actual physics bodies once per physics step, not on
## render frames: the largest single-step displacement of the mover, its whole path
## length, its closest approach to the accepted target and the closest approach
## between any two resident capsules. The driver derives from those numbers that the
## mover only ever moved through physics and really went around its neighbour.
##
## The source observation is a real Kimi run, but nothing chosen here is a model
## choice. Stages:
##   feasible  the mover starts at the reviewed x=2.000277, the reviewed carpenter
##             stands at x=1.5 and the accepted meeting point is x=0.85 (all z=7.5).
##             The real approach option is submitted through the world's own trade
##             API and the real bodies must find their own way around.
##   occupied  the same accepted approach, with a resident body standing exactly on
##             the meeting point; that target is then unreachable by the world's own
##             rules and the command must stay truthfully pending.
##   --town-restore  no new job and no new decision: the scene's own cold reopen,
##             used to prove the save keeps its pending/completed command.

const TownScene = preload("res://scenes/town_street.tscn")
const BODY_CONTACT := 0.5

var scene: Node
var watcher: Node
var trace_path := ""
var stage := ""
var run_seconds := 15.0
var elapsed := 0.0
var finished := false
var restore_mode := false
var submitted := false
var mover_id := "fixture:innkeeper"
var counterparty_id := "fixture:smith"
var command_id := "fixture-social-approach:1"
var target := Vector3.INF
var last_write := -1.0
var world_start: Dictionary = {}

func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--social-stage="):
			stage = arg.trim_prefix("--social-stage=")
		if arg.begins_with("--social-seconds="):
			run_seconds = clampf(float(arg.trim_prefix("--social-seconds=")), 3.0, 600.0)
		if arg.begins_with("--social-trace="):
			trace_path = arg.trim_prefix("--social-trace=")
		if arg.begins_with("--social-command="):
			command_id = arg.trim_prefix("--social-command=")
	restore_mode = OS.get_cmdline_user_args().has("--town-restore")
	if trace_path.strip_edges().is_empty() or (stage.is_empty() and not restore_mode):
		push_error("social approach probe needs --social-trace and --social-stage")
		quit(2)
		return
	scene = TownScene.instantiate()
	root.add_child(scene)
	if not str(scene.town.snapshot().world_id).begins_with("fixture:town-social-approach"):
		push_error("the probe runs only on the explicitly labelled social approach fixture")
		quit(2)
		return
	# The labelled offline fixture mode: no local life choices and no home routing, so
	# a bystander can only move because of its own pending job. The probe never calls
	# host_move, so every position in the trace comes from real physics.
	scene.scripted_trade = true
	# The world's own position record before any physics step runs, so the declared
	# starting geometry is evidence rather than an assumption.
	world_start = _world_positions()
	if not restore_mode:
		# Drive the stage myself so the run is bounded and observed end to end. A cold
		# restore keeps the scene paused and lets the scene's own 3 s capture end it.
		scene.paused = false
		scene.capture_seconds = 900.0
	watcher = PathWatcher.new()
	watcher.configure(scene, mover_id, BODY_CONTACT)
	root.add_child(watcher)
	if not restore_mode:
		_submit_approach()
		watcher.target = target
	_write_trace(true)

func _process(delta: float) -> bool:
	if scene == null:
		return false
	elapsed += delta
	if not restore_mode and not finished and elapsed >= run_seconds:
		finished = true
		_write_trace(true)
		scene._capture_town()
		return false
	if elapsed - last_write >= 0.25:
		_write_trace(false)
	return false

func _submit_approach() -> void:
	var town = scene.town
	for option in town.trade_options(mover_id):
		if option.get("action") != "approach" or str(option.get("counterparty", "")) != counterparty_id:
			continue
		var point: Array = option.get("target_position", [])
		if point.size() != 3:
			push_error("approach option has no target position")
			quit(2)
			return
		var applied: Dictionary = town.transaction(scene._save_path, func():
			return town.submit_trade(mover_id, str(option.get("id")), command_id, "opengameagent_fixture"))
		if not applied.ok:
			push_error("approach submission failed: " + JSON.stringify(applied))
			quit(2)
			return
		target = Vector3(point[0], point[1], point[2])
		submitted = true
		return
	push_error("the fixture offers no approach from the mover to the counterparty")
	quit(2)

func _write_trace(final: bool) -> void:
	if trace_path.strip_edges().is_empty() or watcher == null:
		return
	last_write = elapsed
	var town = scene.town
	var snap: Dictionary = town.snapshot()
	var events := 0
	for event in snap.life.get("events", []):
		if str(event.get("operation_id", "")) == command_id:
			events += 1
	var trade: Dictionary = snap.godot.get("trade", {})
	var job: Dictionary = trade.get("jobs", {}).get(mover_id, {})
	var commands: Dictionary = trade.get("commands", {})
	var command: Dictionary = commands.get(command_id, {})
	var payload := {
		"probe": "town_social_approach_scene",
		"provenance": "offline_fixture_physical_observation",
		"stage": stage if not stage.is_empty() else "restore",
		"world_id": snap.world_id,
		"fixture": true,
		"restore_mode": restore_mode,
		"engine_time_scale": Engine.time_scale,
		"engine_physics_frames": Engine.get_physics_frames(),
		"scripted_trade": true,
		"social_steering_wired": scene.social_steering != null,
		"mover_id": mover_id,
		"counterparty_id": counterparty_id,
		"command_id": command_id,
		"command_submitted": submitted,
		"target": [target.x, target.y, target.z] if target.is_finite() else [],
		"job_action": str(job.get("action", "")),
		"job_elapsed": float(job.get("elapsed", 0.0)),
		"job_pending": not job.is_empty(),
		"command_status": str(command.get("status", "")),
		"events_for_command": events,
		"physics_frames_observed": watcher.physics_frames,
		"physics_seconds_observed": watcher.physics_seconds,
		"min_distance_to_target": watcher.min_distance if is_finite(watcher.min_distance) else -1.0,
		"min_body_clearance": watcher.min_clearance if is_finite(watcher.min_clearance) else -1.0,
		"mover_first_body_position": _array(watcher.first_mover),
		"mover_last_body_position": _array(watcher.last_mover),
		"mover_world_start": _array(world_start.get(mover_id, Vector3.INF)),
		"world_start": _arrays(world_start),
		"mover_max_physics_step": watcher.max_step,
		"mover_path_length": watcher.path_length,
		"residents_seen": watcher.start_positions.size(),
		"bystander_start": _arrays(watcher.start_positions),
		"bystander_end": _arrays(watcher.last_positions),
		"bystander_max_drift": watcher.max_drift,
		"mover_samples": watcher.samples,
		"final_write": final}
	var next_path := trace_path + ".next"
	var file := FileAccess.open(next_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write social approach trace: " + next_path)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(next_path), ProjectSettings.globalize_path(trace_path))

func _array(point: Vector3) -> Array:
	return [point.x, point.y, point.z] if point.is_finite() else []

func _world_positions() -> Dictionary:
	var result: Dictionary = {}
	for id in scene.town.active_ids():
		result[id] = scene.town.position_of(id)
	return result

func _arrays(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in source.keys():
		result[id] = _array(source[id])
	return result


class PathWatcher extends Node:
	## Measures the real resident bodies once per physics step. Nothing here reads a
	## saved position or a world claim, and nothing here moves a body.
	var scene: Node
	var mover_id := ""
	var target := Vector3.INF
	var contact := 0.5
	var physics_frames := 0
	var physics_seconds := 0.0
	var max_step := 0.0
	var path_length := 0.0
	var min_distance := INF
	var min_clearance := INF
	var first_mover := Vector3.INF
	var last_mover := Vector3.INF
	var previous_mover := Vector3.INF
	var start_positions: Dictionary = {}
	var last_positions: Dictionary = {}
	var max_drift: Dictionary = {}
	var samples: Array = []

	func configure(owner_scene: Node, id: String, body_contact: float) -> void:
		scene = owner_scene
		mover_id = id
		contact = body_contact

	func _physics_process(delta: float) -> void:
		if scene == null or not scene.bodies.has(mover_id):
			return
		physics_frames += 1
		physics_seconds += delta
		var positions: Dictionary = {}
		for id in scene.bodies.keys():
			var body: Node3D = scene.bodies[id]
			if body == null or not is_instance_valid(body):
				continue
			positions[id] = body.position
		if not positions.has(mover_id):
			return
		if start_positions.is_empty():
			start_positions = positions.duplicate()
			for id in positions.keys():
				max_drift[id] = 0.0
		var mover: Vector3 = positions[mover_id]
		for id in positions.keys():
			var here: Vector3 = positions[id]
			var started: Vector3 = start_positions.get(id, here)
			var drift: Vector3 = here - started
			drift.y = 0.0
			max_drift[id] = maxf(max_drift.get(id, 0.0), drift.length())
			if id == mover_id:
				continue
			var separation := here - mover
			separation.y = 0.0
			min_clearance = minf(min_clearance, separation.length() - contact)
		if previous_mover.is_finite():
			var step := mover - previous_mover
			step.y = 0.0
			max_step = maxf(max_step, step.length())
			path_length += step.length()
		else:
			first_mover = mover
		previous_mover = mover
		last_mover = mover
		last_positions = positions.duplicate()
		if target.is_finite():
			var offset := mover - target
			offset.y = 0.0
			var distance := offset.length()
			min_distance = minf(min_distance, distance)
			if physics_frames % 3 == 1:
				samples.append([snappedf(physics_seconds, 0.02), snappedf(mover.x, 0.0001),
					snappedf(mover.z, 0.0001), snappedf(distance, 0.0001)])
