extends RefCounted
## Disposable scripted demonstration for UI replay. This is not model autonomy or
## physical walking: host_move is an explicit fixture surrogate for arrival.

const Town = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const Adapter = preload("res://agents/dialogue_fixture_adapter.gd")
const SOURCE := "res://../worlds/restart-20260918-01/checkpoints/seq000000-22fe742384341a2b.world.json"
const OWNER := "shared:carpenter"
const SMITH := "shared:smith"
const AXE := "seed:axe"

class ScriptedBrain extends Node:
	var turns: Node
	var target_action := ""
	var raw := {}
	var via_dialogue := false
	var captured := {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		captured = view.duplicate(true)
		var record: Dictionary = turns._record(str(view.identity.id))
		var alias := ""
		for key in record.get("offered_actions", {}):
			if record.offered_actions[key] == target_action: alias = str(key)
		if via_dialogue:
			var envelope := raw.duplicate(true); envelope.next_action = alias
			var prepared := Adapter.validate(envelope, view, record.get("offered_actions", {}), [OWNER, SMITH], [])
			var allowed := Adapter.authorize(prepared, view, record.get("offered_actions", {}), true,
				"Explicit scripted demo authorization for an already-offered action.")
			if not allowed.get("ok", false): return {"ok": false, "code": allowed.get("code", "dialogue_adapter_rejected")}
			return {"ok": true, "decision": allowed.decision, "command_id": "fixture:axe-day-demo", "provenance": "opengameagent_fixture"}
		return {"ok": true, "decision": {"action": alias, "reason":"Explicit scripted demo choice."},
			"command_id":"fixture:axe-day-demo", "provenance":"opengameagent_fixture"}

func run(host: Node, mode: String = "success") -> Dictionary:
	var report := {"ok": false, "mode": mode, "scripted": true, "source_unchanged": false,
		"steps": [], "failures": [], "paid_calls": 0}
	if mode not in ["success", "missing_iron_refusal"]:
		report.failures.append("invalid_mode")
		return report
	var source_hash := FileAccess.get_sha256(SOURCE)
	if source_hash.is_empty():
		report.failures.append("source_unavailable")
		return report
	var path := "user://axe-day-demo-%d-%d.world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	if FileAccess.file_exists(path) or not _write_fixture(path):
		report.failures.append("fixture_destination_unavailable")
		return report
	var town := Town.new()
	if not town.load_from(path).ok:
		report.failures.append("fixture_load_failed")
		_cleanup(town, path)
		return report
	# The existing public-skill path enables the existing repair menu; no prompt or world rule changes.
	var notice := await _turn(host, town, path, SMITH, "share-skill:" + OWNER + ":metal_repair", false, {})
	_step(report, "skill_notice", SMITH, "I can repair metal edges.", notice, town, false)
	if not notice.result.get("ok", false): return _abort(report, town, path, source_hash, "skill_notice_failed")
	var ask := _repair_ask(town)
	if ask.is_empty(): return _abort(report, town, path, source_hash, "need_option_missing")
	var asked := await _turn(host, town, path, OWNER, ask, false, {})
	_step(report, "need", OWNER, "Can you repair the edge of my axe?", asked, town, false)
	if not asked.result.get("ok", false): return _abort(report, town, path, source_hash, "need_failed")
	var request_id := _request_id(town, OWNER)
	if request_id.is_empty(): return _abort(report, town, path, source_hash, "request_missing")
	var reply := await _turn(host, town, path, SMITH, "reply:" + request_id + ":willing", false, {})
	_step(report, "negotiation", SMITH, "I am willing to discuss the repair.", reply, town, false)
	if not reply.result.get("ok", false): return _abort(report, town, path, source_hash, "negotiation_failed")
	var offer := _option(town, OWNER, "offer_repair", "edge", SMITH, 2)
	if offer.is_empty(): return _abort(report, town, path, source_hash, "offer_option_missing")
	var offer_dialogue := {"speech":"I can offer two Col for an edge repair.", "intent":"offer", "stance":"guarded", "target_id":SMITH,
		"claim_ids":[], "stakes":"The axe cannot be used until its edge is repaired.", "next_action":"", "private_thought":"Scripted fixture proposal.", "confidence":0.8}
	var offered := await _turn(host, town, path, OWNER, offer, true, offer_dialogue)
	_step(report, "offer", OWNER, str(offer_dialogue.speech), offered, town, false)
	if not offered.result.get("ok", false) or offered.result.get("record", {}).get("result", {}).get("code") != "contract_proposed": return _abort(report, town, path, source_hash, "offer_failed")
	var contract := _contract(town, "proposed")
	var contract_id := str(contract.get("id", ""))
	if contract_id.is_empty(): return _abort(report, town, path, source_hash, "proposal_missing_contract")
	if mode == "missing_iron_refusal":
		town._trade_account(SMITH).iron = 0
		var refusal_before := town.snapshot()
		var blocked := town.submit_trade(SMITH, "contract:accept:" + contract_id, "fixture:missing-iron", "opengameagent_fixture")
		_step(report, "refusal", SMITH, "I cannot accept without iron.", {"result":blocked}, town, false)
		# The current menu removes acceptance when material is unavailable; submitting its
		# former ID therefore reaches the authoritative `option_unavailable` refusal.
		if blocked.get("ok", false) or blocked.get("code", "") != "option_unavailable" or town.snapshot() != refusal_before: report.failures.append("missing_iron_mutated")
		return _finish(report, town, path, source_hash)
	var accept_dialogue := {"speech":"I accept the two Col edge-repair contract.", "intent":"agree", "stance":"firm", "target_id":OWNER,
		"claim_ids":[], "stakes":"I must use my one iron and complete the work.", "next_action":"", "private_thought":"Scripted fixture acceptance.", "confidence":0.9}
	var accepted := await _turn(host, town, path, SMITH, "contract:accept:" + contract_id, true, accept_dialogue)
	_step(report, "accept", SMITH, str(accept_dialogue.speech), accepted, town, false)
	if not accepted.get("result", {}).get("ok", false) or accepted.result.get("record", {}).get("result", {}).get("code") != "contract_accepted": return _abort(report, town, path, source_hash, "acceptance_failed")
	var deliver := town.transaction(path, func(): return town.submit_trade(OWNER, "contract:deliver:" + contract_id, "fixture:deliver", "opengameagent_fixture"))
	if not deliver.ok: return _abort(report, town, path, source_hash, "delivery_submit_failed")
	var delivery_advance := _arrive(town, path, OWNER, 1.0); _step(report, "delivery", "", "", {"result":delivery_advance}, town, false)
	report.steps[-1].event_type = _event_type(town, "fixture:deliver")
	report.steps[-1].result_code = report.steps[-1].event_type
	if not delivery_advance.ok or town._item(AXE).get("custodian_id") != SMITH or report.steps[-1].event_type != "axe_delivered": return _abort(report, town, path, source_hash, "delivery_failed")
	var work := town.transaction(path, func(): return town.submit_trade(SMITH, "contract:work:" + contract_id + ":edge", "fixture:work", "opengameagent_fixture"))
	if not work.ok: return _abort(report, town, path, source_hash, "work_submit_failed")
	var interrupted := _arrive(town, path, SMITH, 30.0); _step(report, "work_interrupted", "", "", {"result":interrupted}, town, false)
	if not work.ok or not interrupted.ok or town._item(AXE).get("edge") != 20 or town._trade_account(SMITH).iron != 1: return _abort(report, town, path, source_hash, "work_interruption_failed")
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var resumed := Town.new()
	if not resumed.load_from(path).ok or FileAccess.get_file_as_bytes(path) != bytes:
		report.failures.append("cold_reload_failed")
		_cleanup(resumed, path)
		return _finish(report, null, "", source_hash)
	town = resumed
	var completed := _arrive(town, path, SMITH, 30.0); _step(report, "work_completed", "", "", {"result":completed}, town, true)
	report.steps[-1].event_type = _event_type(town, "fixture:work")
	report.steps[-1].result_code = report.steps[-1].event_type
	var completion_events: Array = town.snapshot().life.events.filter(func(event): return event.get("type") == "axe_repaired" and event.get("actor_id") == SMITH)
	if not completed.ok or completion_events.size() != 1 or report.steps[-1].event_type != "axe_repaired" or town._item(AXE).get("edge") != 100 or town._trade_account(SMITH).iron != 0: return _abort(report, town, path, source_hash, "work_completion_failed")
	var memory := await _turn(host, town, path, SMITH, "wait", false, {})
	var memories: Array = memory.get("view", {}).get("memory", {}).get("previous_decisions", [])
	if not memory.result.get("ok", false) or not memories.any(func(entry): return str(entry.get("action", "")).begins_with("contract:accept:") and entry.get("result", {}).get("code") == "axe_contract_accepted"):
		return _abort(report, town, path, source_hash, "identity_memory_missing")
	_step(report, "memory", SMITH, "", memory, town, true)
	var collect := town.transaction(path, func(): return town.submit_trade(OWNER, "contract:collect:" + contract_id, "fixture:collect", "opengameagent_fixture"))
	if not collect.ok: return _abort(report, town, path, source_hash, "collection_submit_failed")
	var collection_advance := _arrive(town, path, OWNER, 1.0); _step(report, "collection", "", "", {"result":collection_advance}, town, true)
	report.steps[-1].event_type = _event_type(town, "fixture:collect")
	report.steps[-1].result_code = report.steps[-1].event_type
	if not collection_advance.ok or report.steps[-1].event_type != "axe_repair_paid" or town._item(AXE).get("custodian_id") != OWNER or town.resident(SMITH).coins_col != 12 or town.resident(OWNER).coins_col != 8 or town._trade_account(OWNER).reserved_col != 0:
		report.diagnostics = {"stage":"collection", "submit":collect.duplicate(true), "advance":collection_advance.duplicate(true),
			"event_type":report.steps[-1].event_type, "custodian_id":town._item(AXE).get("custodian_id", ""),
			"owner_col":town.resident(OWNER).coins_col, "smith_col":town.resident(SMITH).coins_col,
			"reserved_col":town._trade_account(OWNER).reserved_col, "pending_job":town.pending_job(OWNER)}
		return _abort(report, town, path, source_hash, "collection_or_conservation_failed")
	return _finish(report, town, path, source_hash)

func _turn(host: Node, town: RefCounted, path: String, id: String, action: String, dialogue: bool, raw: Dictionary) -> Dictionary:
	var turns := Turns.new(); host.add_child(turns); turns.town = town; turns.save_path = path
	var brain := ScriptedBrain.new(); brain.turns = turns; brain.target_action = action; brain.via_dialogue = dialogue; brain.raw = raw
	turns.add_child(brain); turns.brains[id] = brain
	var result: Dictionary = await turns.step(id)
	var output := {"result":result, "view":brain.captured.duplicate(true)}
	turns.free()
	return output

func _step(report: Dictionary, phase: String, speaker: String, speech: String, outcome: Dictionary, town: RefCounted, resumed: bool) -> void:
	var item: Dictionary = town._item(AXE)
	var result: Dictionary = outcome.get("result", {})
	report.steps.append({"phase":phase, "speaker_id":speaker, "speech":speech,
		"proposed_action":str(result.get("record", {}).get("action", "")),
		"result_code":str(result.get("record", {}).get("result", {}).get("code", result.get("code", ""))),
		"custodian_id":str(item.get("custodian_id", "")), "edge":int(item.get("edge", -1)),
		"owner_col":int(town.resident(OWNER).coins_col), "smith_col":int(town.resident(SMITH).coins_col),
		"iron":int(town._trade_account(SMITH).iron), "reserved_col":int(town._trade_account(OWNER).reserved_col), "resumed":resumed})

func _arrive(town: RefCounted, path: String, id: String, seconds: float) -> Dictionary:
	var job: Dictionary = town.pending_job(id)
	if not job.is_empty(): town.host_move(id, town.destination(id, str(job.action)))
	return town.transaction(path, func(): return town.advance(seconds))

func _event_type(town: RefCounted, command_id: String) -> String:
	for event in town.snapshot().life.events:
		if event.get("operation_id", "") == command_id: return str(event.get("type", ""))
	return ""

func _abort(report: Dictionary, town: Variant, path: String, source_hash: String, code: String) -> Dictionary:
	report.failures.append(code)
	return _finish(report, town, path, source_hash)

func _finish(report: Dictionary, town: Variant, path: String, source_hash: String) -> Dictionary:
	if town != null and not path.is_empty(): _cleanup(town, path)
	report.source_unchanged = FileAccess.get_sha256(SOURCE) == source_hash
	report.ok = report.failures.is_empty() and report.source_unchanged
	return report

func _cleanup(town: Variant, path: String) -> void:
	if town != null: town.release_writer(path)
	if not path.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_fixture(path: String) -> bool:
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not state is Dictionary: return false
	state.fixture = true; state.fixture_note = "Scripted axe-day demo copy; no model call or walking evidence."
	state.life.contracts = []; state.godot.positions[OWNER] = [0,0,0]; state.godot.positions[SMITH] = [0,0,0]
	state.godot.homes[OWNER] = [0,0,0]; state.godot.homes[SMITH] = [0,0,0]
	for person in state.residents:
		if person.get("stable_id") in [OWNER,SMITH]: person.coins_col = 10
	for item in state.life.items:
		if item.get("id") == AXE: item.edge=20; item.handle=100; item.owner_id=OWNER; item.custodian_id=OWNER
	for account in state.life.accounts:
		if account.get("resident_id") == OWNER: account.reserved_col=0; account.iron=0
		if account.get("resident_id") == SMITH: account.reserved_col=0; account.iron=1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(state)); file.close()
	return true

func _option(town: RefCounted, id: String, action: String, part := "", worker := "", price := -1) -> String:
	for option in town.trade_options(id):
		if option.get("action")==action and (part.is_empty() or option.get("_part")==part) and (worker.is_empty() or option.get("_worker_id")==worker) and (price<0 or option.get("_price")==price): return str(option.id)
	return ""
func _repair_ask(town: RefCounted) -> String:
	for option in town.trade_options(OWNER):
		var need: Dictionary = option.get("_decision",{}).get("need",{})
		if option.get("counterparty")==SMITH and need.get("kind")=="repair" and need.get("part")=="edge": return str(option.id)
	return ""
func _request_id(town: RefCounted, id: String) -> String:
	for event in town.snapshot().life.events:
		if event.get("type")=="ask_help" and event.get("actor_id")==id: return str(event.get("request_id",""))
	return ""
func _contract(town: RefCounted, status: String) -> Dictionary:
	for contract in town.snapshot().life.contracts:
		if contract.get("item_id")==AXE and contract.get("status")==status: return contract
	return {}
