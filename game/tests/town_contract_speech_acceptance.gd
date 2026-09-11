extends "res://tests/town_trade_acceptance.gd"
const Turns = preload("res://agents/town_turns.gd")
const Recovery = preload("res://tools/recover_town_controller.gd")

class Speaker extends Node:
	var turns
	var target_action := ""
	var speech := ""
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var alias := ""
		for key in turns._record(view.identity.id).offered_actions:
			if turns._record(view.identity.id).offered_actions[key] == target_action:
				alias = key
		return {"ok": true, "command_id": "fixture-provider", "provenance": "opengameagent_fixture", "decision": {"action": alias, "reason": "PRIVATE_RATIONALE", "speech": speech}}

func run() -> void:
	var path := "user://contract-speech-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town := _load_trade(path)
	var owner := "fictional:ember"
	var smith := "fictional:forge"
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town; turns.save_path = path
	var brain := Speaker.new(); brain.turns = turns
	brain.target_action = _option(town, owner, "offer_repair", "edge", smith, 2)
	brain.speech = "我想修好它。口头说免费不能改变这份2Col报价。"
	check(turns.connect_controller(owner, brain, "fixture:contract-speaker").ok, "speaking controller connects")
	check((await turns.step(owner)).ok, "model can attach public words to a selected offer")
	var contract := _contract(town, "fictional:axe-edge", "proposed")
	check(contract.price_col == 2 and town.resident(owner).coins_col == 12, "spoken words neither override terms nor transfer money")
	check(town.resident_view(smith).experiences[-1].text == brain.speech and not JSON.stringify(town.resident_view(smith)).contains("PRIVATE_RATIONALE"), "counterparty hears only public offer explanation")
	check(not JSON.stringify(town.resident_view("fictional:birch")).contains(brain.speech), "other resident is not granted the discussion")
	check(town.transaction(path, func(): return town.submit_trade(smith, "contract:accept:" + str(contract.id), "spoken-accept", "opengameagent_fixture", "我接受这份合同。")).ok, "acceptance can carry speech")
	check(town._trade_account(owner).reserved_col == 2 and town.resident_view(owner).experiences[-1].text == "我接受这份合同。", "acceptance reserves canonical amount and delivers statement")
	check(town.transaction(path, func(): return town.submit_trade(owner, "contract:cancel:" + str(contract.id), "spoken-cancel", "opengameagent_fixture", "尚未交付，我想撤销。")).ok, "cancellation can carry speech")
	check(town.resident(owner).coins_col == 12 and town._trade_account(owner).reserved_col == 0, "spoken cancellation refunds only existing reserve")
	# A protocol error needs a matching explicit host review; never reset a wait/refusal.
	brain.target_action = "wait"; brain.speech = "unsupported wait speech"
	check((await turns.step(owner)).ok, "unsupported optional speech does not veto a legal wait")
	check(turns._record(owner).history[-1].speech_delivery.delivered == false, "unsent speech is explicitly recorded for the speaker")
	check(not JSON.stringify(town.resident_view(smith)).contains(brain.speech), "unsupported speech is never broadcast")
	brain.target_action = "not-an-offered-action"; brain.speech = ""
	check((await turns.step(owner)).code == "rule_rejection", "invalid action still receives a real rule rejection")
	var failed: Dictionary = turns._record(owner).duplicate(true)
	var world_before: Dictionary = town.snapshot()
	town.release_writer(path)
	turns.free()
	check(not (await Recovery.recover(root, path, owner, failed.request_id)).ok, "default provider recovery does not silently retry rule rejection")
	check(not (await Recovery.recover(root, path, owner, failed.request_id, "wrong-error")).ok, "wrong reviewed error cannot reset decision")
	check((await Recovery.recover(root, path, owner, failed.request_id, "choice_not_offered")).ok, "matching reviewed protocol error can recover without replay")
	var cold := _load_trade(path)
	check(cold.snapshot().life == world_before.life and cold.snapshot().residents == world_before.residents, "review preserves exact facts and experiences")
	check(cold.snapshot().godot.resident_turns[owner].history == failed.history, "failed response remains in history after recovery")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	print(JSON.stringify({"suite": "town_contract_speech", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
