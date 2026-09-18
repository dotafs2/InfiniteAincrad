extends "res://tests/town_life_acceptance.gd"

const Turns = preload("res://agents/town_turns.gd")

class WaitTown extends "res://core/town_life.gd":
	func trade_options(_id: String) -> Array:
		return [{"id": "wait", "label": "等待", "action": "wait"}]
	func submit_trade(_id: String, option: String, _command: String, _provenance: String) -> Dictionary:
		return {"ok": option == "wait", "code": "wait" if option == "wait" else "invalid_option"}

class TestBrain extends Node:
	var calls := 0
	var received: Dictionary = {}
	var answer := {"ok": true, "decision": {"action": "a0", "reason": "我选择稍后再谈。"},
		"command_id": "fixture-turn-1", "provenance": "opengameagent_fixture"}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		received = view.duplicate(true)
		await get_tree().process_frame
		return answer.duplicate(true)

func run() -> void:
	var path := "user://town-turns-%d.json" % Time.get_ticks_usec()
	var previous_config := OS.get_environment("AINCRAD_GATEWAY_RUN_CONFIG")
	var scope_path := path + ".scope.json"
	OS.set_environment("AINCRAD_GATEWAY_RUN_CONFIG", ProjectSettings.globalize_path(scope_path))
	var scoped := Turns.new()
	check(scoped.max_parallel == 3 and scoped._configured_gateway_concurrency() == 1, "gateway missing scope defaults to one, offline concurrency unchanged")
	for example in [[1, 1], [3, 3], [0, 1], [4, 1], [1.5, 1], ["2", 1], [[], 1], [null, 1]]:
		var value: Variant = example[0]
		var scope_file := FileAccess.open(scope_path, FileAccess.WRITE)
		scope_file.store_string(JSON.stringify({"concurrency": value}))
		scope_file.close()
		check(scoped._configured_gateway_concurrency() == example[1], "gateway concurrency validated: " + str(value))
	OS.set_environment("AINCRAD_GATEWAY_RUN_CONFIG", previous_config)
	scoped.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scope_path))
	var initial := fixture()
	initial.residents[0].story = "A persistent personal story."
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(initial))
	f.close()
	var town := WaitTown.new()
	check(town.load_from(path).ok, "turn fixture loads")
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	for id in town.active_ids():
		var brain := TestBrain.new()
		turns.add_child(brain)
		turns.brains[id] = brain
	var result: Dictionary = await turns.step()
	check(result.ok, "optional wait is accepted")
	check(result.record.model_choice == "a0" and result.record.action == "wait", "short choice uses exact frozen host mapping")
	check(turns.brains["fixture:a"].received.identity.story == initial.residents[0].story, "own persistent story is supplied")
	check(turns.brains["fixture:a"].received.identity.name == "Eileen", "actual model request translates the known legacy name")
	check(turns.brains["fixture:a"].received.action_details[0].label == "Wait", "actual model request translates a known legacy option")
	check(turns.brains["fixture:a"].received.known_rules.decision_format.language.begins_with("English"), "actual model request declares English output")
	check(turns.brains["fixture:a"].received.world_id == initial.world_id, "actual world timeline supplied")
	check(turns.brains["fixture:a"].received.needs.satiety == 60 and not turns.brains["fixture:a"].received.needs.has("hunger"), "legacy fullness is not mislabeled as hunger")
	check(town.resident("fixture:a").needs.hunger == 60, "sensor normalization preserves old save schema")
	check(town.snapshot().life == initial.life, "wait does not manufacture a life event")
	check(turns.ready_resident() == "fixture:b", "wait does not immediately charge same resident again")
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := WaitTown.new()
	check(restored.load_from(path).ok, "saved model choice loads")
	check(FileAccess.get_file_as_bytes(path) == bytes, "loading does not advance or rewrite")
	turns.town = restored
	turns.brains["fixture:b"].answer = {"ok": false, "code": "brain_timeout", "command_id": "fixture-timeout", "provenance": "opengameagent_fixture"}
	result = await turns.step()
	check(not result.ok and result.code == "provider_error", "timeout is a system error")
	check(restored.snapshot().godot.resident_turns["fixture:b"].status == "provider_error", "error is durable")
	result = await turns.step("fixture:b")
	check(not result.ok and turns.brains["fixture:b"].calls == 1, "error cannot mint a retry")
	restored.release_writer(path)
	var after_crash := WaitTown.new()
	check(after_crash.load_from(path).ok, "provider error survives cold load")
	turns.town = after_crash
	result = await turns.step("fixture:b")
	check(not result.ok and turns.brains["fixture:b"].calls == 1, "cold load cannot convert error to wait or retry")
	# The exact no-operation per-process limit is different: its saved receipt is
	# deliberately eligible for one fresh turn after a cold start. It has neither a
	# next_due nor a new own event, so admission itself must make that one turn due.
	var limit_request := "turn:fixture:c:0:limit"
	var limit_record: Dictionary = after_crash._state.godot.resident_turns["fixture:b"].duplicate(true)
	limit_record.status = "provider_error"
	limit_record.error = "brain_session_request_limit"
	limit_record.accepted_reply = {"ok": false, "code": "brain_session_request_limit"}
	limit_record.request_id = limit_request
	limit_record.command_id = limit_request
	limit_record.provider_command_id = ""
	limit_record.provenance = ""
	limit_record.seen_seq = turns._own_seq("fixture:c")
	limit_record.session_limit_recovery_spent = ""
	limit_record.session_limit_recovery_attempt = false
	limit_record.erase("next_due")
	after_crash._state.godot.resident_turns["fixture:a"].status = "disconnected"
	after_crash._state.godot.resident_turns["fixture:c"] = limit_record
	turns._local_limit_failures["fixture:c"] = limit_request
	check(turns.ready_resident().is_empty(), "same-process session limit remains held")
	turns._local_limit_failures.erase("fixture:c")
	after_crash._state.godot.resident_turns["fixture:c"].session_limit_recovery_spent = limit_request
	check(turns.ready_resident().is_empty(), "spent cold recovery remains held")
	after_crash._state.godot.resident_turns["fixture:c"].session_limit_recovery_spent = ""
	check(turns.ready_resident() == "fixture:c", "fresh cold session-limit recovery becomes due without invented evidence")
	var calls_before: int = int(turns.brains["fixture:c"].calls)
	result = await turns.step()
	check(result.ok and result.code == "settled" and turns.brains["fixture:c"].calls == calls_before + 1,
		"cold session-limit recovery consumes exactly one fresh turn")
	after_crash._state.godot.resident_turns["fixture:c"].status = "ready"
	after_crash._state.godot.resident_turns["fixture:c"].next_due = 0.0
	# Simulate a crash after durable preparation, before any response is known.
	after_crash._state.godot.resident_turns["fixture:b"].status = "pending"
	check(after_crash.save_to(path).ok, "pending request snapshot saved")
	result = await turns.step("fixture:b")
	check(not result.ok and result.code == "saved_model_turn_requires_review", "unknown pending model result isolates its actor")
	check(turns.ready_resident() == "fixture:c", "pending actor does not block another resident")
	check(after_crash.snapshot().survival == initial.survival, "model control adds no food or energy")
	after_crash.release_writer(path)
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_turns", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
