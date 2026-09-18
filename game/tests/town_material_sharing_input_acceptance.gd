extends "res://tests/town_capabilities_turns_acceptance.gd"
const Sharing = preload("res://core/actions/material_knowledge_capability.gd")
const SPEAKER := "shared:well-keeper"
const LISTENER := "shared:baker"
const MATERIAL := "street:iron-salvage-20260918"

func run() -> void:
	var source := "res://../worlds/restart-20260918-01/checkpoints/seq000148-cdfe013685698028.world.json"
	var path := "user://material-sharing-input-%d.json" % Time.get_ticks_usec()
	check(DirAccess.copy_absolute(source, path) == OK, "copy full rich-profile seq148 world")
	var world := Actions.new()
	check(world.load_from(path).ok, "complete source history loads")
	check(world.transaction(path, func(): return world.observe_material_notice(SPEAKER, true)).ok, "fixture gives speaker personal notice evidence")
	var stage := {"world": world, "path": path}
	var turns := _controller(stage, SPEAKER, Sharing.new().option_id(MATERIAL, LISTENER))
	var outcome: Dictionary = await turns.step(SPEAKER)
	check(outcome.ok, "actual controller dispatches the chosen share alias")
	if not outcome.ok:
		print(JSON.stringify({"controller_failure": outcome.code}))
		turns.free()
		_close_stage(stage)
		quit(1)
		return
	var archive: Dictionary = world._state.godot.resident_archive.entries[outcome.record.request_id]
	check(archive.application.speech_delivery.delivered and archive.delivered_text.begins_with("I can tell you this route:"), "archive records the canonical words actually spoken")
	check(archive.original_reply.decision.speech == "" and archive.delivered_text != archive.reason, "actual statement is neither invented model speech nor private reasoning")
	var sizes := {}
	for actor in [SPEAKER, LISTENER]:
		var view: Dictionary
		if actor == SPEAKER:
			view = turns.brains[SPEAKER].received
		else:
			turns.free()
			turns = _controller(stage, LISTENER, "wait")
			outcome = await turns.step(LISTENER)
			check(outcome.ok, "recipient may choose wait rather than collect")
			view = turns.brains[LISTENER].received
			check(view.material_sources[0].reported_by_id == SPEAKER and view.material_sources[0].last_observed_stock == null, "recipient model input includes exact attribution and unknown stock")
			check(outcome.record.offered_actions.values().has("material:recover:" + MATERIAL), "recipient receives a valid optional collection alias")
		var brain := Brain.new()
		var input := {"sessionId": "fixture-sharing", "actorId": actor, "inputId": "fixture", "type": "personal_observation", "timelineId": world.snapshot().world_id, "tick": world.snapshot().life.seq, "payload": {"resident_view": view}}
		var payload: String = brain._bounded_input(input, view)
		check(not payload.is_empty(), "sharing and rich personal history fit the unchanged model input cap")
		sizes[actor] = brain._input_units(payload)
		brain.free()
	check(world.pending_job(LISTENER).is_empty() and world.material_sources()[0].stock == 3, "listening and waiting grant no material or forced job")
	turns.free()
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_material_sharing_input", "checks": checks, "failures": failures, "input_units": sizes, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
