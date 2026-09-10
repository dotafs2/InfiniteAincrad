extends SceneTree

const KERNEL := preload("res://core/world_kernel.gd")
const BRAIN := preload("res://agents/resident_brain.gd")
var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures.append(label)
		push_error(label)

func make_brain(mode: String = "normal", timeout_ms: int = 10000) -> Node:
	var brain: Node = BRAIN.new()
	root.add_child(brain)
	brain.configure(mode, timeout_ms)
	return brain

func _run() -> void:
	var world: RefCounted = KERNEL.new()
	world.create_fixture()
	var brain: Node = make_brain()
	var original: Dictionary = world.snapshot()
	var need: Dictionary = await brain.propose(world.resident_view(), 0)
	check(need.get("ok", false), "actual upstream runtime returns a proposal")
	check(world.snapshot() == original, "decision plugin cannot mutate world")
	if not need.get("ok", false):
		print(JSON.stringify(need))
		_finish()
		return
	check(need.provenance == "opengameagent_fixture", "fixture is not mislabeled live AI")
	check(world.submit_resident_decision(need.decision, need.command_id, need.provenance).ok, "world accepts valid need")
	check(world.gm_review_need("oga-review", "approve", "well_bucket", "fixture approval").ok, "GM review separate")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://capabilities/well_bucket.v1.json"))
	check(world.gm_install(manifest, "oga-install", "oga-review").ok, "GM installation separate")
	var deferred_brain: Node = make_brain("defer-use")
	var before_defer: Dictionary = world.snapshot()
	var deferred: Dictionary = await deferred_brain.propose(world.resident_view(), before_defer.turn)
	check(deferred.get("ok", false) and deferred.get("decision", {}).get("action") == "wait", "resident may wait despite installed capability")
	if deferred.get("ok", false):
		check(world.submit_resident_decision(deferred.decision, deferred.command_id, deferred.provenance).code == "resident_waited", "wait is a valid consequential choice")
	check(world.snapshot().world == before_defer.world and world.resident_view().inventory == before_defer.residents["fixture:luna"].inventory,
		"waiting consumes no material or water")
	check(world.resident_view().memory.last_action == "wait", "waiting enters the next personal observation")
	deferred_brain.free()
	var draw: Dictionary = await brain.propose(world.resident_view(), world.snapshot().turn)
	check(draw.get("ok", false) and draw.get("decision", {}).get("action") == "draw_water", "new observation changes next proposal")
	if draw.get("ok", false):
		check(world.submit_resident_decision(draw.decision, draw.command_id, draw.provenance).code == "water_drawn", "authoritative draw")
	brain.free()
	# Replace the entire runtime instance while keeping the same world.
	brain = make_brain()
	var drink: Dictionary = await brain.propose(world.resident_view(), world.snapshot().turn)
	check(drink.get("ok", false) and drink.get("decision", {}).get("action") == "drink_water", "new runtime continues personal experience")
	if drink.get("ok", false):
		check(world.submit_resident_decision(drink.decision, drink.command_id, drink.provenance).code == "water_consumed", "authoritative consumption")
	brain.free()
	var finished: Dictionary = world.snapshot()
	var resident: Dictionary = finished.residents["fixture:luna"]
	check(finished.world.well_water == 0 and resident.inventory.water == 0 and resident.consumed.water == 1, "water conservation")
	for mode in ["disabled", "failure", "timeout", "malformed"]:
		brain = make_brain(mode, 100 if mode == "timeout" else 10000)
		var rejected: Dictionary = await brain.propose(world.resident_view(), finished.turn)
		check(not rejected.get("ok", true), "provider %s fails explicitly" % mode)
		check(world.snapshot() == finished, "provider %s preserves world" % mode)
		brain.free()
		await process_frame
	_finish()

func _finish() -> void:
	print(JSON.stringify({"suite": "opengameagent_integration", "passed": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "real_paid_calls": 0, "provider": "offline_fixture", "runtime": "OpenGameAgent"}))
	quit(0 if _failures.is_empty() else 1)
