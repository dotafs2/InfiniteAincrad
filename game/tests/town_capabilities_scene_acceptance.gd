extends "res://tests/town_places_route_acceptance.gd"
## Actual playable street, real bodies/steering, a mid-walk cold scene restart.
## Reuses only the route fixture and scene setup. No movement is teleported.
const CapabilityWorld = preload("res://core/town_actions.gd")
const PLAN := "fixture:joint-invite"
const ACCEPT := "fixture:joint-consent"
var metrics := {}
var resumed_once := false
var saved_positions := {}

func _initialize() -> void:
	super()
	Engine.time_scale = 4.0

func _wait_for_notice() -> void:
	if _game < 2.0: return
	for id in [READER, NEIGHBOUR]:
		check(PLACE in town().known_place_ids(id), "both participants personally read the real sign")
		metrics[id] = {"last": town().position_of(id), "distance": 0.0, "speed": 0.0, "step": 0.0}
	var invited: Dictionary = _scene.town.perform_action(_save, READER, "ability:invite:" + NEIGHBOUR + ":" + PLACE, PLAN, "opengameagent_fixture", "Would you join me at the caravan rest?")
	check(invited.ok, "physical host accepts an invitation without starting movement")
	check(town().pending_job(READER).is_empty() and town().pending_job(NEIGHBOUR).is_empty(), "neither body moves on invitation alone")
	var accepted: Dictionary = _scene.town.perform_action(_save, NEIGHBOUR, "ability:accept_visit:" + PLAN, ACCEPT, "opengameagent_fixture", "Yes, I will join you.")
	check(accepted.ok, "separate consent starts two existing travel primitives")
	if not accepted.ok:
		_finish()
		return
	_phase = "walk"
	_start_game = _game

func _walk_step(_resumed: bool) -> void:
	for id in metrics:
		var position: Vector3 = town().position_of(id)
		var row: Dictionary = metrics[id]
		var moved := Vector2(position.x - row.last.x, position.z - row.last.z).length()
		row.distance += moved
		row.step = maxf(row.step, moved)
		row.last = position
		var body: CharacterBody3D = _scene.bodies[id]
		row.speed = maxf(row.speed, Vector2(body.velocity.x, body.velocity.z).length())
	var plan: Dictionary = _scene.town.capability_store().plans[PLAN]
	if plan.status != "running":
		check(plan.status == "completed", "both real arrivals complete the shared plan")
		for index in plan.children.size():
			var child: Dictionary = plan.children[index]
			var row: Dictionary = metrics[child.actor_id]
			check(receipts(child.command_id, "place_visited") == 1, "exactly one physical arrival per participant across restart")
			check(receipts(child.command_id, "travel_blocked") == 0, "no participant's journey was closed as blocked")
			check(row.distance > 20.0 and absf(row.speed - WALK_SPEED) < .02 and row.step < .6, "resident walked real metres at the original speed without jumping")
			check(town().pending_job(child.actor_id).is_empty(), "body job closes only after arrival")
		check(resumed_once and receipts(ACCEPT, "joint_visit_completed") == 1, "one shared completion after cold continuation")
		var final := CapabilityWorld.new()
		check(final.load_from(_save).ok and final.capability_store().plans[PLAN].status == "completed", "completed plan passes production cold validation")
		_finish()
		return
	if not resumed_once and metrics[READER].distance > 5 and metrics[NEIGHBOUR].distance > 5:
		check(_scene.town.save_to(_save).ok, "mid-walk state saved with both jobs")
		_copied = _work.path_join("joint-mid-walk.json")
		check(DirAccess.copy_absolute(_save, _copied) == OK, "retain exact mid-walk evidence")
		for id in metrics: saved_positions[id] = town().position_of(id)
		_scene.paused = true
		_scene.queue_free()
		_phase = "swap"
	if _game - _start_game > 240.0:
		check(false, "bounded physical journey failed to complete")
		_finish()

func _swap() -> void:
	if FileAccess.file_exists(_world_save + ".writer-lock"): return
	check(DirAccess.copy_absolute(_copied, _world_save) == OK, "resume the exact saved world")
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = false
	_scene.scripted_trade = true
	var plan: Dictionary = _scene.town.capability_store().plans[PLAN]
	check(plan.status == "running" and plan.accepted_command == ACCEPT, "new scene retains the original consent and shared plan")
	for child in plan.children:
		check(town().pending_job(child.actor_id).get("command_id") == child.command_id, "new scene retains original child command")
		check(town().position_of(child.actor_id).distance_to(saved_positions[child.actor_id]) < .001, "new body starts at saved position")
		metrics[child.actor_id].last = town().position_of(child.actor_id)
	resumed_once = true
	_phase = "resume"

func _finish() -> void:
	_phase = "done"
	var output := {"suite": "town_capabilities_scene", "checks": _checks, "failures": _failures, "paid_calls": 0,
		"time_scale": Engine.time_scale, "world_seconds": _game, "resumed": resumed_once, "metrics": {}}
	for id in metrics:
		output.metrics[id] = {"walked_metres": metrics[id].distance, "max_speed_mps": metrics[id].speed, "max_sample_step_m": metrics[id].step}
	var path: String = str(_args().get("out", ""))
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(output, "  ", true, true))
		file.close()
	print(JSON.stringify(output))
	if is_instance_valid(_scene):
		_scene.paused = true
		_scene.queue_free()
	call_deferred("_exit_after_cleanup")

func _exit_after_cleanup() -> void:
	await process_frame
	await process_frame
	quit(0 if _failures.is_empty() else 1)
