extends "res://tests/town_capabilities_turns_acceptance.gd"
## Real rich-profile controller input, with an explicit offline wait choice.
const READER := "shared:well-keeper"
const SOURCE_ID := "street:iron-salvage-20260918"

func run() -> void:
	var source := "res://../worlds/restart-20260918-01/checkpoints/seq000148-cdfe013685698028.world.json"
	var path := "user://material-notice-input-%d.json" % Time.get_ticks_usec()
	check(DirAccess.copy_absolute(source, path) == OK, "copy immutable stopped world")
	var world := Actions.new()
	check(world.load_from(path).ok, "load every existing resident and decision")
	# This is the input-boundary fixture; the separate scene suite proves real LOS.
	check(world.transaction(path, func(): return world.observe_material_notice(READER, true)).ok, "record personal notice in an in-range copied world")
	var stage := {"world": world, "path": path}
	var turns := _controller(stage, READER, "wait")
	var outcome: Dictionary = await turns.step(READER)
	check(outcome.ok, "ordinary controller accepts explicit offline wait")
	var view: Dictionary = turns.brains[READER].received
	check(view.material_sources.size() == 1 and view.material_sources[0].last_observed_stock == null, "model receives location without remote stock")
	check(view.material_sources[0].knowledge_source == "personally_read_public_material_notice_stock_unknown", "model receives the actual knowledge attribution")
	check(outcome.record.offered_actions.values().has("material:recover:" + SOURCE_ID), "current request exposes a valid collection alias")
	var brain := Brain.new()
	var input := {"sessionId": "fixture-notice", "actorId": READER, "inputId": "fixture", "type": "personal_observation", "timelineId": world.snapshot().world_id, "tick": world.snapshot().life.seq, "payload": {"resident_view": view}}
	var payload: String = brain._bounded_input(input, view)
	check(not payload.is_empty(), "full rich profile, history and new notice fit unchanged input cap")
	if not payload.is_empty():
		var received: Dictionary = JSON.parse_string(payload).payload.resident_view
		# JSON parses all numbers as floats; normalize both sides through the same
		# production wire codec, with no tolerance or omission of fields.
		check(received.material_sources == JSON.parse_string(JSON.stringify(view.material_sources)), "bounding preserves exact notice facts")
	check(world.pending_job(READER).is_empty() and world._trade_account(READER).iron == 0 and world.material_sources()[0].stock == 3, "wait leaves collection optional and creates no material")
	var units := brain._input_units(payload)
	brain.free()
	turns.free()
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_material_notice_input", "checks": checks, "failures": failures, "input_units": units, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
