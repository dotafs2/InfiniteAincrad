extends "res://tests/town_trade_acceptance.gd"
## Offline synthetic cap/cold/resume acceptance. No gateway, provider or maintained save.
const Street = preload("res://spatial/town_street.gd")

class FakeTurns extends Node:
	var busy := false
	var ready_id := ""
	func ready_resident() -> String:
		return ready_id

class CaptureStreet extends Street:
	var captures := 0
	var captured_snapshot := {}
	func _capture_town() -> void:
		paused = true
		captures += 1
		captured_snapshot = town.snapshot()

var _mode := ""
var _save := ""
var _evidence := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--save="):
			_save = arg.trim_prefix("--save=")
		elif arg.begins_with("--evidence="):
			_evidence = arg.trim_prefix("--evidence=")
	if _mode not in ["prepare", "cold", "resume"] or _save.is_empty() or _evidence.is_empty():
		push_error("H42 fixture requires prepare/cold/resume plus disposable save/evidence paths")
		quit(2)
		return
	run.call_deferred()

func _write_evidence(value: Dictionary) -> void:
	var parent := _evidence.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(_evidence, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  "))
	file.close()

func _record_fixture_history(town, actor: String, command: String) -> Dictionary:
	return town.transaction(_save, func():
		if not town._state.godot.has("resident_turns"):
			town._state.godot.resident_turns = {}
		town._state.godot.resident_turns[actor] = {
			"status": "settled", "request_number": 1, "request_id": command,
			"command_id": command, "controller_epoch": 0, "controller_id": "fixture:h42",
			"seen_seq": 0, "next_due": town._state.godot.elapsed_seconds + 1800.0,
			"history": [{"command_id": command, "action": "approach:fictional:forge",
				"status": "settled", "result": {"ok": true, "code": "approach_started"},
				"provenance": "opengameagent_fixture", "reason": "Offline fixture"}],
			"reviews": [], "choice_protocol": 2, "offered_actions": {}, "speech_actions": []}
		return {"ok": true})

func run() -> void:
	if _mode == "prepare":
		_run_prepare()
	elif _mode == "cold":
		_run_cold()
	else:
		_run_resume()

func _run_prepare() -> void:
	_write_fixture(_save, trade_fixture())
	var town := _load_trade(_save)
	var actor := "fictional:ember"
	var target := "fictional:forge"
	var command := "fixture:h42:long-approach"
	var started := execute(town, _save, actor, "approach:" + target, command)
	check(started.ok and not town.pending_job(actor).is_empty(), "offline long journey starts as a durable physical job")
	check(_record_fixture_history(town, actor, command).ok, "fixture controller history is saved with the accepted job")
	var pending := town.pending_job(actor).duplicate(true)
	var history: Array = town.snapshot().godot.resident_turns[actor].history.duplicate(true)
	var street := CaptureStreet.new()
	var turns := FakeTurns.new()
	check(street.town.load_from(_save).ok, "street capture view loads the same saved fixture")
	street.status = Label.new()
	street.add_child(street.status)
	street.model_turns = turns
	street.gateway_mode = true
	street.paused = false
	street.capture_dir = "fixture:h42:no-file"
	street.stop_on_decision_limit = true
	street.validation_decision_limit = 1
	street.validation_decisions_started = 0
	street._process(0.1)
	await process_frame
	check(street.captures == 0, "zero-ready cooldown remains running before the decision cap")
	street.validation_decisions_started = 1
	turns.busy = true
	street._process(0.1)
	await process_frame
	check(street.captures == 0, "capture does not freeze an in-flight model result")
	turns.busy = false
	street._process(0.1)
	await process_frame
	check(street.captures == 1 and street.paused, "settled model boundary pauses and captures exactly once")
	check(street.captured_snapshot.godot.trade.jobs.has(actor), "cap capture does not wait for the physical journey")
	var captured_pending: Dictionary = street.captured_snapshot.godot.trade.jobs.get(actor, {})
	check(captured_pending.get("command_id") == pending.command_id
		and captured_pending.get("target_id") == pending.target_id
		and captured_pending.get("target_position") is Array
		and Vector3(captured_pending.target_position[0], captured_pending.target_position[1], captured_pending.target_position[2]).is_equal_approx(
			Vector3(pending.target_position[0], pending.target_position[1], pending.target_position[2]))
		and is_equal_approx(float(captured_pending.get("elapsed", -1)), float(pending.elapsed)),
		"cap capture preserves pending command target and progress")
	check(street.captured_snapshot.godot.resident_turns[actor].history == history,
		"cap capture preserves controller history")
	var result := {"suite": "h42_cap_exit", "mode": _mode, "checks": checks, "failures": failures,
		"paid_calls": 0, "pending": pending, "history": history, "captures": street.captures,
		"captured_pending": captured_pending,
		"captured_history": street.captured_snapshot.godot.resident_turns[actor].history}
	_write_evidence(result)
	print(JSON.stringify(result))
	street.free()
	turns.free()
	town.release_writer(_save)
	quit(0 if failures == 0 else 1)

func _run_cold() -> void:
	var before := FileAccess.get_file_as_bytes(_save)
	var town := _load_trade(_save)
	var actor := "fictional:ember"
	var pending := town.pending_job(actor).duplicate(true)
	var history: Array = town.snapshot().godot.resident_turns[actor].history.duplicate(true)
	check(not pending.is_empty() and pending.command_id == "fixture:h42:long-approach", "cold process retains pending command identity")
	check(pending.get("target_id") == "fictional:forge" and pending.get("target_position") is Array
		and pending.target_position.size() == 3 and float(pending.elapsed) == 0.0,
		"cold process retains target and unfinished progress")
	check(history.size() == 1 and history[0].command_id == pending.command_id, "cold process retains controller history")
	check(FileAccess.get_file_as_bytes(_save) == before, "cold inspection is byte-identical")
	var result := {"suite": "h42_cap_exit", "mode": _mode, "checks": checks, "failures": failures,
		"paid_calls": 0, "byte_equal": FileAccess.get_file_as_bytes(_save) == before, "pending": pending}
	_write_evidence(result)
	print(JSON.stringify(result))
	town.release_writer(_save)
	quit(0 if failures == 0 else 1)

func _run_resume() -> void:
	var town := _load_trade(_save)
	var actor := "fictional:ember"
	var before_events: Array = town.snapshot().life.events.duplicate(true)
	var pending := town.pending_job(actor).duplicate(true)
	check(not pending.is_empty(), "next segment receives the same pending physical job")
	arrive(town, actor)
	elapse(town, _save, 1.0)
	check(town.pending_job(actor).is_empty(), "next segment can continue and finish the saved journey")
	check(town.snapshot().life.events.slice(0, before_events.size()) == before_events, "resume preserves the old event prefix")
	check(town.snapshot().godot.trade.commands[pending.command_id].status == "completed", "saved command completes once under its original ID")
	var result := {"suite": "h42_cap_exit", "mode": _mode, "checks": checks, "failures": failures,
		"paid_calls": 0, "original_command": pending.command_id, "pending_after": town.pending_job(actor)}
	_write_evidence(result)
	print(JSON.stringify(result))
	town.release_writer(_save)
	quit(0 if failures == 0 else 1)
