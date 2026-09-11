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
