extends "res://tests/town_life_acceptance.gd"
## Fault injection in real world rules; no model calls or fabricated original history.
const Runtime = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
var answers: Dictionary = {}

class DelayedBrain extends Node:
	var calls := 0
	var delay := 0.04
	var fail := false
	var choice := "wait"
	var captured: Dictionary = {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		captured = view.duplicate(true)
		var selected := "a0"
		for option in view.action_details:
			if option.label == "等待":
				selected = option.id
		await get_tree().create_timer(delay).timeout
		return {"ok": false, "code": "brain_timeout"} if fail else {"ok": true, "decision": {"action": selected, "reason": "显式测试替身选择等待"}, "command_id": "same-provider-id", "provenance": "opengameagent_fixture"}

func drive(turns: Node, id: String, tag: String) -> void:
	answers[tag] = await turns.step(id)

func act(town: RefCounted, path: String, id: String, action: String, cmd: String) -> Dictionary:
	for option in town.trade_options(id):
		if option.action != action or (action == "offer_repair" and (option.get("_part") != "edge" or option.get("_price") != 2)):
			continue
		var result: Dictionary = town.transaction(path, func(): return town.submit_trade(id, option.id, cmd, "opengameagent_fixture"))
		if not result.ok:
			print(JSON.stringify({"failed_test_action": action, "result": result}))
		return result
	print(JSON.stringify({"missing_test_action": action, "options": town.trade_options(id), "job": town.pending_job(id)}))
	return {"ok": false, "code": "test_option_missing", "action": action}

func run() -> void:
	var path := "user://town-online-%d.json" % Time.get_ticks_usec()
	var initial := fixture()
	initial.residents.pop_back()
	initial.residents[1].role = "smith"
	initial.survival.accounts.pop_back()
	for key in ["positions", "homes", "observations"]:
		initial.godot[key].erase("fixture:c")
	initial.life.accounts = [{"resident_id": "fixture:a", "wood": 1, "iron": 0, "kindling": 0, "reserved_col": 0}, {"resident_id": "fixture:b", "wood": 0, "iron": 1, "kindling": 0, "reserved_col": 0}]
	initial.life.items = [{"id": "fixture:axe", "kind": "axe", "owner_id": "fixture:a", "custodian_id": "fixture:a", "edge": 20, "handle": 100}]
	initial.life.skills = [{"resident_id": "fixture:b", "skill_id": "metal_repair"}]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(initial)); f.close()
	var town := Runtime.new()
	check(town.load_from(path).ok, "two-person world loads")
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town; turns.save_path = path
	var newcomer := {"stable_id": "fixture:new", "name": "新来者", "role": "resident", "story": "永久保存的入城故事"}
	check(town.transaction(path, func(): return town.start_action("fixture:a", "eat_ration", "existing-meal")).ok, "first resident already eating")
	check(town.transaction(path, func(): return town.start_action("fixture:b", "rest", "existing-rest")).ok, "second resident already resting")
	var joined: Dictionary = town.transaction(path, func(): return town.admit_resident(newcomer, "maintainer:test", Vector3(1, 0, 0), "join-once"))
	check(joined.ok and town.active_ids().size() == 3, "third identity admitted after actions start")
	check(town.resident("fixture:new").coins_col == 0 and town.account("fixture:new").food == 0 and town._trade_account("fixture:new").wood == 0, "admission mints no scarce resources")
	var joined_state := town.snapshot()
	check(town.transaction(path, func(): return town.admit_resident(newcomer, "maintainer:test", Vector3(1, 0, 0), "join-once")).get("duplicate", false), "repeated admission acknowledged")
	check(town.snapshot() == joined_state, "repeated admission changes nothing")
	check(not town.transaction(path, func(): return town.admit_resident(newcomer, "maintainer:test", Vector3.ZERO, "join-another")).ok, "same identity cannot be created again")
	check(not town.transaction(path, func(): return town.admit_resident(newcomer, "maintainer:other", Vector3.ZERO, "join-once")).ok, "admission payload conflict rejected")
	var failing := DelayedBrain.new(); failing.fail = true
	check(turns.connect_controller("fixture:new", failing, "external:test").ok, "new controller attaches")
	drive(turns, "fixture:new", "timeout")
	check(turns.busy, "request truly outstanding")
	check(town.transaction(path, func(): return town.advance(60)).ok, "world advances during request")
	check(town.account("fixture:a").food == 0 and town.pending_job("fixture:b").is_empty(), "others finish eating and resting during request")
	var fast := DelayedBrain.new()
	check(turns.connect_controller("fixture:a", fast, "local:test").ok, "another resident controller attaches")
	drive(turns, "fixture:a", "parallel")
	check(turns.inflight.size() == 2, "two distinct residents have concurrent provider requests")
	await create_timer(0.08).timeout
	check(answers.get("parallel", {}).get("ok", false), "another resident settles despite concurrent timeout")
	check(answers.get("timeout", {}).get("code") == "provider_error", "timeout recorded as system failure")
	for i in range(20):
		check(turns.ready_resident() == "", "failed controller is not auto-retried")
	check(failing.calls == 1, "timeout makes exactly one provider attempt")
	var epoch := int(turns._record("fixture:new").controller_epoch)
	check(turns.disconnect_controller("fixture:new", "external:test", epoch).ok, "disconnect only controller")
	var old := DelayedBrain.new(); old.delay = 0.2
	check(turns.connect_controller("fixture:new", old, "external:old").ok, "explicit reconnect allowed")
	drive(turns, "fixture:new", "late")
	var before_replace := town.snapshot()
	var current := DelayedBrain.new()
	check(turns.connect_controller("fixture:new", current, "external:new").ok, "new controller fences outstanding request")
	check(not turns.disconnect_controller("fixture:new", "external:old", int(before_replace.godot.resident_turns["fixture:new"].controller_epoch)).ok, "old disconnect cannot remove replacement")
	check((await turns.step("fixture:new")).ok, "replacement decides without old reply")
	var settled := town.snapshot()
	await create_timer(0.25).timeout
	check(answers.get("late", {}).get("code") == "stale_controller_reply", "late old reply rejected")
	check(town.snapshot() == settled, "late reply changes no history or world fact")
	var record := turns._record("fixture:new")
	check(turns.apply_reply("fixture:new", record.controller_epoch, record.request_id, record.accepted_reply).get("duplicate", false), "duplicate response acknowledged")
	check(town.snapshot() == settled, "duplicate response applies no second action")
	check(town.resident("fixture:new").story == newcomer.story, "identity and personal story survive reconnect")
	check(not JSON.stringify(current.captured).contains("historical_coordinate"), "controller view excludes another resident's private history")
	check(act(town, path, "fixture:a", "offer_repair", "offer").ok, "existing resident offers repair")
	check(act(town, path, "fixture:b", "accept", "accept").ok, "worker accepts escrow")
	check(act(town, path, "fixture:a", "deliver", "deliver").ok, "delivery starts")
	town.host_move("fixture:a", town.destination("fixture:a", "deliver"))
	town.transaction(path, func(): return town.advance(2))
	check(act(town, path, "fixture:b", "work", "work").ok, "repair starts")
	var b := DelayedBrain.new()
	var connected := turns.connect_controller("fixture:b", b, "worker:test")
	check(turns.disconnect_controller("fixture:b", "worker:test", connected.epoch).ok, "working resident disconnects")
	check(town.transaction(path, func(): return town.advance(60)).ok and town._item("fixture:axe").edge == 100, "accepted work finishes without AI connection")
	var collection := act(town, path, "fixture:a", "collect", "payment-once")
	check(collection.ok, "owner collects")
	town.host_move("fixture:a", town.destination("fixture:a", "collect"))
	town.transaction(path, func(): return town.advance(2))
	check(town.resident("fixture:a").coins_col == 8 and town.resident("fixture:b").coins_col == 12, "two Col paid once")
	var paid := town.snapshot()
	if not paid.godot.trade.commands.has("payment-once"):
		turns.free()
		town.release_writer(path)
		print(JSON.stringify({"suite": "town_online", "checks": checks, "failures": failures}))
		quit(1)
		return
	var option_id: String = paid.godot.trade.commands["payment-once"].payload.option_id
	check(town.transaction(path, func(): return town.submit_trade("fixture:a", option_id, "payment-once", "opengameagent_fixture")).get("duplicate", false), "duplicate payment acknowledged")
	check(town.snapshot() == paid, "duplicate payment conserves money and custody")
	# Reconnect failure rolls back persisted controller and leaves original in-memory brain.
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	var rejected := DelayedBrain.new()
	check(not turns.connect_controller("fixture:new", rejected, "save-failure").ok and turns.brains["fixture:new"] == current, "failed save cannot replace controller")
	rejected.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var cold := Runtime.new()
	check(cold.load_from(path).ok and cold._serialize_state() == town._serialize_state(), "cold restart preserves full state and identity")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold load does not rewrite source")
	check(cold.transaction(path, func(): return cold.admit_resident(newcomer, "maintainer:test", Vector3(1, 0, 0), "join-once")).get("duplicate", false), "admission de-dup survives cold restart")
	cold.release_writer(path)
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_online", "checks": checks, "failures": failures, "paid_calls": 0, "provenance": "fault_injection_fixture"}))
	quit(0 if failures == 0 else 1)
