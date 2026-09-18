extends "res://tests/town_capabilities_acceptance.gd"
const Brain = preload("res://agents/resident_brain.gd")

class FixtureBrain extends Node:
	var controller: Node
	var actor := ""
	var choice := ""
	var speech := ""
	var collide_second_child := false
	var received := {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		received = view.duplicate(true)
		var record: Dictionary = controller.town._state.godot.resident_turns[actor]
		var alias := "missing"
		for key in record.offered_actions:
			if record.offered_actions[key] == choice: alias = key
		if collide_second_child:
			# A deterministic collision after discovery exercises second-child failure
			# inside a controller transaction which must retain the rejected reply.
			var collision: String = "joint:" + str(record.request_id).sha256_text().substr(0, 32) + ":1"
			controller.town.perform_action(controller.save_path, "fictional:forge", "wait", collision, "opengameagent_fixture")
		await get_tree().process_frame
		return {"ok": true, "decision": {"action": alias, "reason": "This is my explicit offline fixture choice.", "speech": speech},
			"command_id": "fixture-provider:" + actor, "provenance": "opengameagent_fixture"}

func _controller(stage: Dictionary, actor: String, choice: String, speech: String = "") -> Turns:
	var controller := Turns.new()
	root.add_child(controller)
	controller.town = stage.world
	controller.save_path = stage.path
	var brain := FixtureBrain.new()
	brain.controller = controller
	brain.actor = actor
	brain.choice = choice
	brain.speech = speech
	controller.add_child(brain)
	controller.brains[actor] = brain
	return controller

func run() -> void:
	var stage := _new_stage("turn-talk")
	var turns := _controller(stage, A, "ability:talk:" + B, "I enjoy quiet mornings by the garden.")
	var outcome: Dictionary = await turns.step(A)
	check(outcome.ok and outcome.record.action == "ability:talk:" + B, "real controller dispatches the frozen free-talk choice")
	var request: String = outcome.record.request_id
	var archive: Dictionary = stage.world._state.godot.resident_archive.entries[request]
	check(archive.application.speech_delivery.delivered and archive.application.speech_delivery.text == turns.brains[A].speech, "full reply archive records actual delivered speech")
	check(turns._feedback_history(A, outcome.record)[-1].result.get("code") == "resident_said", "next personal turn sees native execution feedback")
	var real_brain := Brain.new()
	var view: Dictionary = turns.brains[A].received
	var input := {"payload": {"resident_view": view}}
	check(not real_brain._bounded_input(input, view).is_empty(), "new offered actions fit the existing model input budget")
	real_brain.free()
	turns.free()
	_close_stage(stage)

	stage = _new_stage("turn-observe")
	turns = _controller(stage, A, "ability:observe")
	outcome = await turns.step(A)
	check(outcome.ok, "real controller applies private observation")
	archive = stage.world._state.godot.resident_archive.entries[outcome.record.request_id]
	check(not archive.application.speech_delivery.delivered, "private sensing stays out of public speech archive")
	turns.free()
	_close_stage(stage)

	stage = _new_stage("turn-rollback")
	_do(stage, A, "ability:invite:" + B + ":west_forecourt", "turn:invite")
	turns = _controller(stage, B, "ability:accept_visit:turn:invite", "Yes, let us go.")
	turns.brains[B].collide_second_child = true
	outcome = await turns.step(B)
	check(not outcome.ok and outcome.code == "rule_rejection", "second-child collision rejects shared departure")
	check(stage.world.pending_job(A).is_empty() and stage.world.pending_job(B).is_empty(), "failed batch leaves both bodies available")
	check(stage.world.capability_store().plans["turn:invite"].status == "invited", "failed batch leaves consent pending")
	request = outcome.record.request_id
	archive = stage.world._state.godot.resident_archive.entries[request]
	check(archive.application.status == "rule_rejection" and outcome.record.history[-1].command_id == request, "outer turn retains the complete rejected reply after inner rollback")
	stage.world.release_writer(stage.path)
	var restored := Actions.new()
	check(restored.load_from(stage.path).ok and restored._state.godot.resident_turns[B].status == "rule_rejection", "rejected controller turn and unstarted bodies survive cold restore")
	stage.world = restored
	turns.free()
	_close_stage(stage)

	# Stress actual rich profiles and all nearby residents, without a provider.
	var source := "res://../worlds/restart-20260918-01/checkpoints/seq000000-22fe742384341a2b.world.json"
	var path := "user://capability-rich-input-%d.json" % Time.get_ticks_usec()
	check(DirAccess.copy_absolute(source, path) == OK, "copy immutable rich genesis into a disposable test world")
	var rich := Actions.new()
	check(rich.load_from(path).ok, "all ten original rich characters load unchanged")
	for index in rich.active_ids().size():
		var actor: String = rich.active_ids()[index]
		rich.host_move(actor, Vector3(-3 + (index % 4) * .5, .22, 12 + (index / 4) * .5))
		check(rich.observe_public_places(actor, true, []).ok, "fixture crowd has personal notice evidence")
	check(rich.save_to(path).ok, "crowd fixture saved")
	stage = {"world": rich, "path": path}
	var sizes := {}
	for actor in rich.active_ids():
		turns = _controller(stage, actor, "wait")
		outcome = await turns.step(actor)
		check(outcome.ok, "rich resident uses the complete common action menu")
		view = turns.brains[actor].received
		real_brain = Brain.new()
		input = {"sessionId": "fixture-rich", "actorId": actor, "inputId": "fixture", "type": "personal_observation", "timelineId": rich.snapshot().world_id, "tick": rich.snapshot().life.seq, "payload": {"resident_view": view}}
		var bounded: String = real_brain._bounded_input(input, view)
		sizes[actor] = {"options": view.available_actions.size(), "input_units": real_brain._input_units(bounded)}
		var represented := {}
		for detail in view.action_details: represented[detail.id] = detail.label
		for group in view.get("action_groups", {}).values():
			for alias in group.choices:
				check(not represented.has(alias), "factored menu has no duplicate aliases")
				represented[alias] = group.template.format(group.choices[alias])
		var offered: Dictionary = outcome.record.offered_actions
		check(represented.size() == offered.size(), "factored menu preserves every offered option")
		for alias in offered:
			var option: Dictionary = {}
			for current in rich.action_options(actor):
				if current.id == offered[alias]: option = current
			check(not option.is_empty() and represented[alias] == rich.English.project(option.label), "factoring preserves the exact action description")
		if bounded.is_empty():
			var sections := {}
			for key in input.payload.resident_view: sections[key] = JSON.stringify(input.payload.resident_view[key]).length()
			print(JSON.stringify({"input_overflow": actor, "sections": sections}))
		check(not bounded.is_empty(), "full rich crowd menu fits the real input cap for " + actor)
		real_brain.free()
		turns.free()
	_close_stage(stage)
	print(JSON.stringify({"rich_crowd_input": sizes}))
	print(JSON.stringify({"suite": "town_capabilities_turns", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
