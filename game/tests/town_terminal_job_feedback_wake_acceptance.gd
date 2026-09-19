extends "res://tests/town_capabilities_turns_acceptance.gd"

class ProviderFailureBrain extends Node:
	var received := {}
	var calls := 0
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		received = view.duplicate(true)
		calls += 1
		await get_tree().process_frame
		return {"ok": false, "code": "brain_gateway_rejected_or_uncertain",
			"command_id": "fixture-terminal-feedback-provider-failure",
			"provenance": "opengameagent_fixture"}

func _terminal_stage(label: String) -> Dictionary:
	var stage := _new_stage("terminal-feedback-" + label)
	var world = stage.world
	var berry: Vector3 = world.berry_center()
	world.host_move(B, berry)
	_do(stage, B, "life:harvest_ration", "fixture:terminal-feedback:deplete:" + label)
	check(world.transaction(stage.path, func(): return world.advance(20.0)).ok
		and world.snapshot().foraging.stock == 0,
		label + ": another resident physically consumes the last available ration")
	world.host_move(A, berry)
	var turns := _controller(stage, A, "life:harvest_ration")
	var started: Dictionary = await turns.step(A)
	check(started.ok and started.record.history[-1].result.get("code") == "action_started",
		label + ": ordinary controller records only admission while physical work is pending")
	check(not world.pending_job(A).is_empty() and turns.ready_resident().is_empty(),
		label + ": a pending body job keeps the resident ineligible")
	check(world.transaction(stage.path, func(): return world.advance(20.0)).ok,
		label + ": resident arrives and the real harvest duration completes")
	var command_id := str(started.record.request_id)
	var terminal: Dictionary = world._state.godot.commands.get(command_id, {})
	check(world.pending_job(A).is_empty() and terminal.get("status") == "rejected"
		and terminal.get("result", {}).get("code") == "resources_unavailable",
		label + ": authoritative basic-life command holds the exact terminal resource rejection")
	stage["turns"] = turns
	stage["command_id"] = command_id
	stage["terminal_record"] = turns._record(A).duplicate(true)
	return stage

func _close_terminal_stage(stage: Dictionary) -> void:
	stage.turns.free()
	_close_stage(stage)

func _restore_terminal_record(stage: Dictionary) -> void:
	stage.world._state.godot.resident_turns[A] = stage.terminal_record.duplicate(true)

func run() -> void:
	var stage: Dictionary = await _terminal_stage("once")
	var world = stage.world
	var turns = stage.turns
	var before_ready: Variant = world.snapshot()
	var original_next_due: float = float(turns._record(A).next_due)
	check(turns.ready_resident() == A,
		"latest settled action_started with an authoritative terminal resource rejection wakes once")
	check(world.snapshot() == before_ready and float(turns._record(A).next_due) == original_next_due,
		"terminal feedback discovery is read-only and does not alter next_due")
	turns.brains[A].choice = "wait"
	var acknowledged: Dictionary = await turns.step()
	check(acknowledged.ok and acknowledged.record.action == "wait"
		and int(acknowledged.record.request_number) == 2,
		"resident freely acknowledges the terminal feedback with one ordinary wait decision")
	check("life:harvest_ration" in acknowledged.record.offered_actions.values(),
		"terminal feedback neither hides harvest from the menu nor forces a different choice")
	var observed: Dictionary = turns.brains[A].received.memory.previous_decisions[-1].result
	check(observed.get("ok") == false and observed.get("code") == "resources_unavailable"
		and observed.get("actor_id") == A and observed.get("command_id") == stage.command_id,
		"next real observation carries the exact authoritative rejection receipt")
	check(acknowledged.record.history[-2].command_id == stage.command_id
		and acknowledged.record.history[-1].action == "wait",
		"ordinary decision appends after rather than rewriting the failed job history")
	check(turns.ready_resident().is_empty() and turns.ready_resident().is_empty(),
		"the same now-nonlatest terminal failure cannot trigger another early wake")
	_close_terminal_stage(stage)

	stage = await _terminal_stage("gates")
	world = stage.world
	turns = stage.turns
	_restore_terminal_record(stage)
	world._state.godot.resident_turns[A].status = "rule_rejection"
	world._state.godot.resident_turns[A].result = {"ok": false, "code": "invalid_decision"}
	check(turns.ready_resident().is_empty(), "an existing review-required record keeps priority over terminal feedback")
	_restore_terminal_record(stage)
	check(world.perform_action(stage.path, A, "life:rest", "fixture:terminal-feedback:busy", "opengameagent_fixture").ok,
		"fixture starts a separate real body job after the terminal harvest")
	check(not world.pending_job(A).is_empty() and turns.ready_resident().is_empty(),
		"a current pending body job keeps priority over terminal feedback")
	_close_terminal_stage(stage)

	stage = await _terminal_stage("admission")
	turns = stage.turns
	check(turns.ready_resident() == A, "terminal feedback is otherwise due before admission closes")
	turns.close_admission("fixture_boundary")
	check(turns.ready_resident().is_empty(), "closed admission remains authoritative over terminal feedback")
	_close_terminal_stage(stage)

	stage = await _terminal_stage("provider-failure")
	world = stage.world
	turns = stage.turns
	var old_brain: Node = turns.brains[A]
	turns.brains.erase(A)
	old_brain.free()
	var failed_brain := ProviderFailureBrain.new()
	turns.add_child(failed_brain)
	turns.brains[A] = failed_brain
	var failed: Dictionary = await turns.step()
	check(not failed.ok and failed.code == "provider_error" and failed_brain.calls == 1,
		"one terminal-feedback observation may itself receive an uncertain provider failure")
	check(failed_brain.received.memory.previous_decisions[-1].result.get("code") == "resources_unavailable",
		"failed provider attempt still received the exact terminal job feedback")
	check(turns._record(A).status == "provider_error" and turns.ready_resident().is_empty(),
		"provider_error review gate prevents the same terminal receipt from buying another call")
	_close_terminal_stage(stage)

	print(JSON.stringify({"suite": "town_terminal_job_feedback_wake", "checks": checks,
		"failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
