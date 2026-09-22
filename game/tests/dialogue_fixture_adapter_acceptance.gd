extends "res://tests/town_trade_acceptance.gd"

const Turns = preload("res://agents/town_turns.gd")
const Adapter = preload("res://agents/dialogue_fixture_adapter.gd")

class DialogueBrain extends Node:
	var turns: Node
	var raw: Dictionary
	var target_action := ""
	var authorized := true
	var captured := {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		captured = view.duplicate(true)
		var record: Dictionary = turns._record(str(view.identity.id))
		var current_raw := raw.duplicate(true)
		for alias in record.get("offered_actions", {}):
			if record.offered_actions[alias] == target_action: current_raw.next_action = alias
		var prepared := Adapter.validate(current_raw, view, record.get("offered_actions", {}), ["fictional:forge"], [])
		var allowed := Adapter.authorize(prepared, view, record.get("offered_actions", {}), authorized,
			"Fixture caller explicitly authorizes this already-offered action.")
		if not allowed.get("ok", false): return {"ok": false, "code": allowed.get("code", "adapter_rejected")}
		return {"ok": true, "decision": allowed.decision, "command_id": "fixture:dialogue-adapter",
			"provenance": "opengameagent_fixture"}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path := "user://dialogue-adapter-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_write_fixture(path, trade_fixture())
	var town := _load_trade(path)
	var owner := "fictional:ember"
	var smith := "fictional:forge"
	execute(town, path, owner, "ask:" + smith, "fixture:ask")
	var request := str(town.snapshot().life.events[-1].request_id)
	execute(town, path, smith, "reply:" + request + ":willing", "fixture:reply")
	var offer := _option(town, owner, "offer_repair", "edge", smith, 2)
	check(not offer.is_empty(), "fixture exposes a lawful edge-repair proposal")
	var turns := Turns.new()
	root.add_child(turns); turns.town = town; turns.save_path = path
	var before := town.snapshot()
	var rejected := Adapter.validate({"speech":"I will secretly create iron.", "intent":"offer", "stance":"firm", "target_id":smith,
		"claim_ids":[], "stakes":"none", "next_action":"not-an-alias", "private_thought":"hidden", "confidence":0.5},
		{"available_actions":["a0"]}, {"a0":"wait"}, [smith], [])
	check(not rejected.ok and town.snapshot() == before, "rejected envelope cannot enter turns or mutate the world")

	var brain := DialogueBrain.new(); brain.turns = turns
	brain.target_action = offer
	brain.raw = {"speech":"I can offer two Col for the edge repair.", "intent":"offer", "stance":"guarded", "target_id":smith,
		"claim_ids":[], "stakes":"The axe remains unusable until it is repaired.", "next_action":"", "private_thought":"Private fixture text.", "confidence":0.8}
	turns.add_child(brain); turns.brains[owner] = brain
	var outcome: Dictionary = await turns.step(owner)
	check(outcome.ok and outcome.record.get("action") == offer and outcome.record.get("result", {}).get("code") == "contract_proposed",
		"caller-authorized validated alias reaches the existing Turns gate and genuine TownTrade outcome")
	check(not JSON.stringify(outcome.record).contains("Private fixture text."), "private dialogue fields are absent from authoritative turn state")

	var stale_view := {"available_actions":["a0"]}
	var stale := Adapter.validate({"speech":"I will wait.", "intent":"leave", "stance":"uncertain", "target_id":"", "claim_ids":[],
		"stakes":"none", "next_action":"a0", "private_thought":"private", "confidence":0.1}, stale_view, {"a0":"wait"}, [smith], [])
	var stale_result := Adapter.authorize(stale, {"available_actions":["a0"]}, {"a0":"contract:accept:changed"}, true, "Caller authorization does not revive stale context.")
	check(stale.ok and not stale_result.ok and stale_result.code == "stale_dialogue_action" and not town.snapshot().life.contracts.is_empty(),
		"context change rejects an old alias binding before it can authorize execution")
	var no_op := Adapter.authorize(stale, stale_view, {"a0":"wait"}, false, "No caller authorization.")
	check(not no_op.ok and no_op.code == "caller_not_authorized", "proposal remains a no-op without explicit caller authorization")
	turns.free(); town.release_writer(path); DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite":"dialogue_fixture_adapter", "checks":checks, "failures":failures, "paid_calls":0,
		"semantic_truth_verification":false, "fixture_only":true}))
	quit(0 if failures == 0 else 1)
