extends "res://tests/town_trade_acceptance.gd"
const Turns = preload("res://agents/town_turns.gd")
class Speaker extends Node:
	var turns
	var target_action := "ask:fictional:birch"
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var action := ""
		for key in turns._record(view.identity.id).offered_actions:
			if turns._record(view.identity.id).offered_actions[key] == target_action:
				action = key
		return {"ok": true, "command_id": "fixture-provider", "provenance": "opengameagent_fixture", "decision": {"action": action, "reason": "PRIVATE_REASON_SENTINEL", "speech": "我想问清楚报酬何时结算。"}}

func run() -> void:
	var path := "user://public-speech-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town := _load_trade(path)
	var owner := "fictional:ember"
	var wood := "fictional:birch"
	var smith := "fictional:forge"
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town; turns.save_path = path
	var brain := Speaker.new(); brain.turns = turns
	check(turns.connect_controller(owner, brain, "fixture:speech").ok, "speech controller attaches")
	check((await turns.step(owner)).ok, "chosen public speech is delivered through turn adapter")
	var event: Dictionary = town.snapshot().life.events[-1]
	check(event.text == "我想问清楚报酬何时结算。", "recipient gets chosen speech instead of stock template")
	check(not JSON.stringify(town.resident_view(wood)).contains("PRIVATE_REASON_SENTINEL"), "private rationale is not broadcast")
	check(not JSON.stringify(town.resident_view(smith)).contains(event.text), "third person does not hear private exchange")
	var command: String = turns._record(owner).command_id
	check(town.submit_trade(owner, brain.target_action, command, "opengameagent_fixture", event.text).duplicate, "same speech command remains idempotent")
	check(town.submit_trade(owner, brain.target_action, command, "opengameagent_fixture", "changed").code == "command_conflict", "same command cannot rewrite spoken words")
	var before: Dictionary = town.snapshot()
	check(not town.submit_trade(owner, "wait", "wait-speech", "opengameagent_fixture", "not an allowed speech action").ok, "wait cannot publish arbitrary speech")
	check(not town.submit_trade(owner, "ask:" + smith, "oversized-speech", "opengameagent_fixture", "x".repeat(513)).ok, "oversized speech is rejected")
	check(town.snapshot() == before, "invalid speech changes no state")
	execute(town, path, owner, _option(town, owner, "offer_repair", "edge", smith, 2), "public-offer")
	var contract := _contract(town, "fictional:axe-edge", "proposed")
	var refusal := town.transaction(path, func(): return town.submit_trade(smith, "contract:reject:" + str(contract.id), "public-refusal", "opengameagent_fixture", "我现在不愿接单，请稍后再谈。"))
	check(refusal.ok, "contract rejection can carry public explanation")
	check(town.resident_view(owner).experiences[-1].text == "我现在不愿接单，请稍后再谈。", "counterparty receives rejection explanation")
	check(town.resident(owner).coins_col == 12 and town._trade_account(owner).reserved_col == 0, "spoken words cannot transfer money")
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var cold := _load_trade(path)
	check(FileAccess.get_file_as_bytes(path) == bytes and cold.resident_view(owner).experiences[-1].text == town.resident_view(owner).experiences[-1].text, "public statement survives restart exactly")
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_public_speech", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
