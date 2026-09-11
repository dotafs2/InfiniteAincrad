extends "res://tests/town_trade_acceptance.gd"
const Turns = preload("res://agents/town_turns.gd")

class ChoiceBrain extends Node:
	var turns
	var option := "wait"
	var before_reply: Callable
	var view: Dictionary
	var calls := 0
	func propose(observation: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		view = observation.duplicate(true)
		var alias := "not-offered"
		var offered: Dictionary = turns._record(observation.identity.id).offered_actions
		for key in offered:
			if offered[key] == option:
				alias = key
		if before_reply.is_valid():
			var hook := before_reply
			before_reply = Callable()
			hook.call()
		return {"ok": true, "decision": {"action": alias, "reason": "Explicit offline race/replanning fixture"}, "command_id": "fixture-provider", "provenance": "opengameagent_fixture"}

func run() -> void:
	var path := "user://town-replan-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town := _load_trade(path)
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town; turns.save_path = path
	var owner := "fictional:ember"
	var smith := "fictional:forge"
	var brain := ChoiceBrain.new()
	brain.turns = turns
	check(turns.connect_controller(smith, brain, "fixture:smith").ok, "smith attaches")
	execute(town, path, owner, _option(town, owner, "offer_repair", "edge", smith, 2), "fixture:offer")
	var contract_id: String = _contract(town, "fictional:axe-edge", "proposed").id
	brain.option = "contract:accept:" + contract_id
	brain.before_reply = func():
		execute(town, path, owner, "contract:cancel:" + contract_id, "fixture:cancel-during-inference")
	var result: Dictionary = await turns.step(smith)
	check(result.code == "rule_rejection" and result.record.result.code == "option_unavailable", "real cancellation invalidates previously offered acceptance")
	check(town._contract(contract_id).status == "cancelled" and town._trade_account(owner).reserved_col == 0, "stale acceptance reserves nothing")
	var failed_record: Dictionary = turns._record(smith).duplicate(true)
	var failed_command: String = failed_record.request_id
	var failed_reply: Dictionary = failed_record.accepted_reply.duplicate(true)
	var historical_events: Array = town.snapshot().life.events
	check(turns.ready_resident().is_empty(), "rejection does not trigger immediate paid loop")
	var before_duplicate: Dictionary = town.snapshot()
	check(turns.apply_reply(smith, int(failed_record.controller_epoch), failed_command, failed_reply).duplicate, "duplicate rejected reply is terminal and acknowledged")
	check(town.snapshot() == before_duplicate, "duplicate changes no money, history or cooldown")
	var calls_before := brain.calls
	await turns.step(smith)
	check(brain.calls == calls_before, "explicit step cannot bypass rejection cooldown")
	# A later message must not bypass the rejection cooldown either.
	check(town.transaction(path, func(): return town.communicate(owner, {"action": "ask_help", "recipient_id": smith, "text": "I withdrew that old offer."}, "fixture:later-message", "opengameagent_fixture")).ok, "new personal information arrives")
	check(turns.ready_resident().is_empty(), "incoming message does not cause tight rejection retries")
	var bytes := FileAccess.get_file_as_bytes(path)
	var persisted_record: Dictionary = town._parse_json_text(FileAccess.get_file_as_string(path)).godot.resident_turns[smith]
	town.release_writer(path)
	var restored := _load_trade(path)
	turns.town = restored
	check(FileAccess.get_file_as_bytes(path) == bytes and turns._record(smith) == persisted_record, "cold load preserves exact saved rejection and cooldown")
	check(float(turns._record(smith).get("replan_not_before", -1)) == float(failed_record.get("replan_not_before", -2)), "integer JSON time retains cooldown semantics")
	check(turns.ready_resident().is_empty(), "restart cannot skip cooldown")
	for _tick in 15:
		elapse(restored, path, 120.0)
	check(turns.ready_resident() == smith, "ordinary stale choice becomes eligible after cooldown without host reset")
	brain.option = "wait"
	result = await turns.step(smith)
	check(result.ok and brain.calls == calls_before + 1, "resident can choose wait from a fresh personal observation")
	if result.ok:
		check(brain.view.memory.previous_decisions[-1].result.code == "option_unavailable", "new choice sees previous authoritative rejection")
		check(brain.view.experiences.any(func(e): return e.get("operation_id") == "fixture:cancel-during-inference"), "resident sees counterparty cancellation")
		check(not turns._record(smith).offered_actions.values().has("contract:accept:" + contract_id), "fresh options exclude cancelled offer")
		check(int(turns._record(smith).controller_epoch) == int(failed_record.controller_epoch), "replanning preserves controller identity")
		check(turns._record(smith).history[0] == failed_record.history[0], "old failed decision is not rewritten")
		check(turns._record(smith).request_id != failed_command, "fresh choice uses new host request ID")
		check(turns.apply_reply(smith, int(failed_record.controller_epoch), failed_command, failed_reply).code == "stale_controller_reply", "late old acceptance cannot be replayed")
		check(turns.ready_resident().is_empty(), "voluntary wait is respected")
		check(restored.snapshot().life.events.slice(0, historical_events.size()) == historical_events, "original event prefix stays intact")
		check(restored.resident(owner).coins_col == 12 and restored.resident(smith).coins_col == 3 and restored._trade_account(smith).iron == 1, "replanning invents no payment or material")
	# Protocol mistakes remain quarantined; gameplay recovery is not a provider retry.
	brain.option = "does-not-exist"
	result = await turns.step(smith)
	check(result.code == "rule_rejection" and result.record.result.code == "choice_not_offered", "invalid alias remains an explicit failure")
	for _tick in 15:
		elapse(restored, path, 120.0)
	check(turns.ready_resident().is_empty(), "invalid alias does not automatically buy another request")
	calls_before = brain.calls
	await turns.step(smith)
	check(brain.calls == calls_before, "explicit caller cannot retry protocol failure")
	check(turns._requires_review({"status": "rule_rejection", "result": {"code": "option_unavailable"}}), "legacy unclassified failure still requires explicit review")
	check(turns._requires_review({"status": "rule_rejection", "result": {"code": "option_unavailable"}, "replan_policy": "stale_option_v1", "replan_not_before": "bad"}), "malformed cooldown fails closed")
	for state in ["pending", "provider_error", "disconnected"]:
		check(turns._requires_review({"status": state, "replan_policy": "stale_option_v1", "replan_not_before": 0}), "stale replan marker does not override " + state)
	restored.release_writer(path)
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_replan", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
