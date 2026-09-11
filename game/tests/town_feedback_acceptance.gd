extends "res://tests/town_trade_acceptance.gd"

const TownTurns = preload("res://agents/town_turns.gd")

func _history(command: String) -> Dictionary:
	return {"history": [{"command_id": command, "result": {"ok": true, "pending": true, "code": "trade_started"}}]}

func run() -> void:
	var path := "user://fictional-town-feedback-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town := _load_trade(path)
	var owner := "fictional:ember"
	var wood := "fictional:birch"
	var turns := TownTurns.new()
	turns.town = town
	town.host_move(owner, Vector3(-4, 0, 0))
	var command := "feedback-approach"
	var history := _history(command)
	var original := history.duplicate(true)
	execute(town, path, owner, "approach:" + wood, command)
	check(turns._feedback_history(owner, history)[0].result.code == "pending", "running job stays pending")
	elapse(town, path, 5)
	check(turns._feedback_history(owner, history)[0].result.code == "pending", "time without arrival is not completion")
	arrive(town, owner)
	elapse(town, path, 1)
	check(turns._feedback_history(owner, history)[0].result.code == "approach", "actual arrival supplies terminal receipt")
	check(history == original, "projection preserves archived pending receipt")
	check(not town.trade_options(owner).any(func(o): return o.id == "approach:" + wood), "arrival removes redundant approach option")
	var before: Dictionary = town.snapshot()
	var suppressed := town.transaction(path, func(): return town.submit_trade(owner, "approach:" + wood, "repeat-approach", "opengameagent_fixture"))
	check(not suppressed.ok and suppressed.code == "option_unavailable", "stale approach is rejected")
	check(town.snapshot() == before, "stale approach creates no job, movement or fee")
	var legacy_receipt: Dictionary = town._state.godot.trade.commands[command].result
	town._state.godot.trade.commands[command].erase("result")
	check(turns._feedback_history(owner, history)[0].result.code == "resident_moved", "legacy terminal command resolves its own movement event")
	check(turns._feedback_history(wood, history)[0].result.code == "unknown", "another resident cannot project owner's command")
	town._state.godot.trade.commands[command].result = legacy_receipt
	check(turns._feedback_history(owner, _history("missing-old-command"))[0].result.code == "unknown", "missing evidence never becomes success")
	town.host_move(owner, Vector3(-4, 0, 0))
	check(town.trade_options(owner).any(func(o): return o.id == "approach:" + wood), "real departure makes approach useful again")
	town.host_move(owner, Vector3.ZERO)
	execute(town, path, owner, "ask:" + wood, "feedback-ask")
	var request: String = town.snapshot().life.events[-1].request_id
	execute(town, path, wood, "reply:" + request + ":unavailable", "feedback-refusal")
	var refusal: Dictionary = turns._feedback_history(wood, _history("feedback-refusal"))[0].result
	check(refusal.code == "reply_help" and refusal.reply_choice == "unavailable", "refusal remains refusal, not an accepted job")
	check(turns._feedback_history(owner, _history("feedback-ask"))[0].result.code == "ask_help", "request receipt is not confused with another person's reply")
	# Exercise life-only commands and a real resource failure at completion.
	check(town.transaction(path, func(): return town.start_action(owner, "eat_ration", "feedback-eat", "opengameagent_fixture")).ok, "life-only action begins")
	town.account(owner).food = 0
	arrive(town, owner)
	elapse(town, path, 30)
	var failed: Dictionary = turns._feedback_history(owner, _history("feedback-eat"))[0].result
	check(not failed.ok and failed.code == "resources_unavailable", "failed execution reports actual resource failure")
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := _load_trade(path)
	turns.town = restored
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold load never rewrites save")
	check(turns._feedback_history(owner, history)[0].result.code == "approach", "movement receipt survives restart")
	check(turns._feedback_history(owner, _history("feedback-eat"))[0].result == failed, "failure receipt survives restart")
	check(restored.snapshot().life.contracts[0].opaque == "preserve", "unrelated old commitments preserved")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Optional read-only projection of the carried real-model fixture.
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--feedback-source="):
			continue
		var source: String = argument.trim_prefix("--feedback-source=")
		var source_bytes := FileAccess.get_file_as_bytes(source)
		var carried := _load_trade(source)
		turns.town = carried
		var saved: Dictionary = carried.snapshot()
		var record: Dictionary = saved.godot.resident_turns["fixture:innkeeper"]
		var projected: Array = turns._feedback_history("fixture:innkeeper", record)
		var completed_approaches := 0
		for entry in projected:
			if str(entry.get("action", "")).begins_with("approach:") and entry.result.code == "resident_moved":
				completed_approaches += 1
		check(completed_approaches == 3, "three real old approaches are now reported as completed")
		check(carried.snapshot() == saved and FileAccess.get_file_as_bytes(source) == source_bytes, "carried world remains byte-identical")
		print(JSON.stringify({"carried_completed_approaches": completed_approaches, "source_write": false}))
	turns.free()
	print(JSON.stringify({"suite": "town_feedback", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
