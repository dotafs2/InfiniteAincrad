extends SceneTree
const Town = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const Reviewed = preload("res://agents/reviewed_dialogue_fixture_adapter.gd")
const Runner = preload("res://demo/axe_day_demo_runner.gd")
const BatchValidator = preload("res://tests/validate_local_dialogue_proposals.gd")
const OWNER := "shared:carpenter"
const SMITH := "shared:smith"
const AXE := "seed:axe"
const CONTEXTS := "res://../docs/validation/local-npc-dialogue-20260923/contexts.json"
const RAW := "res://../docs/validation/local-npc-dialogue-20260923/raw.json"
var checks := 0
var failures: Array[String] = []
var source_unchanged := false
var offer_code := ""
var accept_code := ""
var cold_memory_acceptance := false
var raw_rejections: Array = []
var escrow_col := -1

class ReviewedBrain extends Node:
	var turns: Node
	var action_id := ""
	var raw := ""
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var record: Dictionary = turns._record(str(view.identity.id))
		var alias := ""
		for key in record.get("offered_actions", {}):
			if str(record.offered_actions[key]) == action_id: alias = str(key)
		var envelope: Dictionary = JSON.parse_string(raw)
		envelope.next_action = alias
		var prepared := Reviewed.prepare(JSON.stringify(envelope), view, record.get("offered_actions", {}), [OWNER, SMITH], [])
		var approved := Reviewed.authorize(prepared, view, record.get("offered_actions", {}), true, "Explicit formal fixture authorization.", [OWNER, SMITH], [])
		if not approved.get("ok", false): return {"ok": false, "code": approved.get("code", "review_rejected")}
		return {"ok": true, "decision": approved.decision, "command_id": "fixture:reviewed-dialogue", "provenance": "opengameagent_fixture"}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var source_hash := FileAccess.get_sha256(Runner.SOURCE)
	_check(not source_hash.is_empty(), "formal source hash available")
	var path := "user://reviewed-formal-%d-%d.world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var worker := Runner.new()
	if not worker._write_fixture(path): _fail("fixture write failed"); _finish(null, path, source_hash); return
	var town := Town.new()
	if not town.load_from(path).ok: _fail("fixture load failed"); _finish(town, path, source_hash); return
	_check(town.active_ids().has(OWNER) and town.active_ids().has(SMITH), "formal IDs load")
	_check(town._item(AXE).owner_id == OWNER and town._item(AXE).custodian_id == OWNER, "formal axe custody starts with carpenter")
	_validate_saved_rejections(town, path)
	if not failures.is_empty(): _finish(town, path, source_hash); return
	var source_before := FileAccess.get_sha256(Runner.SOURCE)
	var notice := town.transaction(path, func(): return town.submit_trade(SMITH, "share-skill:" + OWNER + ":metal_repair", "fixture:notice", "opengameagent_fixture"))
	_check(notice.ok, "formal skill notice commits")
	if not notice.ok: _fail("skill_notice_failed"); _finish(town, path, source_hash); return
	var offer := _option(town, OWNER, "offer_repair", "edge", SMITH, 2)
	_check(not offer.is_empty(), "two-Col offer is available")
	if offer.is_empty(): _finish(town, path, source_hash); return
	var offered := await _turn(town, path, OWNER, offer, _raw("offer", "I can offer two Col for an edge repair.", SMITH))
	offer_code = str(offered.result.get("record", {}).get("result", {}).get("code", ""))
	_check(offered.result.get("ok", false) and offer_code == "contract_proposed", "reviewed offer creates contract")
	if not offered.result.get("ok", false) or offer_code != "contract_proposed": _fail("offer_failed"); _finish(town, path, source_hash); return
	var contract := _contract(town, "proposed")
	var contract_id := str(contract.get("id", ""))
	_check(not contract_id.is_empty(), "contract ID recorded")
	if contract_id.is_empty(): _finish(town, path, source_hash); return
	var accepted := await _turn(town, path, SMITH, "contract:accept:" + contract_id, _raw("agree", "I accept the repair contract.", OWNER))
	accept_code = str(accepted.result.get("record", {}).get("result", {}).get("code", ""))
	_check(accepted.result.get("ok", false) and accept_code == "contract_accepted", "reviewed acceptance creates receipt")
	if not accepted.result.get("ok", false) or accept_code != "contract_accepted": _fail("acceptance_failed"); _finish(town, path, source_hash); return
	escrow_col = int(town._trade_account(OWNER).reserved_col)
	_check(town.resident(OWNER).coins_col == 8 and escrow_col == 2 and town.resident(SMITH).coins_col == 10 and town._trade_account(SMITH).iron == 1, "escrow and resources conserved")
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var cold := Town.new()
	var loaded: Dictionary = cold.load_from(path)
	if not loaded.get("ok", false): _fail("cold_load_failed"); _finish(cold, path, source_hash); return
	_check(FileAccess.get_file_as_bytes(path) == saved_bytes and cold._trade_account(OWNER).reserved_col == 2 and cold.resident(OWNER).coins_col == 8, "cold reload preserves contract and escrow")
	_check(cold.snapshot().life.contracts.any(func(item): return item.get("id") == contract_id and item.get("status") == "accepted"), "accepted contract persists")
	var replay := Turns.new(); root.add_child(replay); replay.town = cold; replay.save_path = path
	var feedback: Array = replay._feedback_history(SMITH, replay._record(SMITH))
	cold_memory_acceptance = feedback.any(func(entry): return entry.get("action", "") == "contract:accept:" + contract_id and entry.get("result", {}).get("code") == "axe_contract_accepted")
	_check(cold_memory_acceptance, "cold Smith feedback contains accepted receipt")
	replay.free(); cold.release_writer(path); DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(FileAccess.get_sha256(Runner.SOURCE) == source_before, "formal source unchanged")
	source_unchanged = FileAccess.get_sha256(Runner.SOURCE) == source_hash
	_finish(null, "", source_hash)

func _validate_saved_rejections(town: RefCounted, path: String) -> void:
	var contexts: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTEXTS))
	var raw_batch: Variant = JSON.parse_string(FileAccess.get_file_as_string(RAW))
	var context_hash := FileAccess.get_sha256(CONTEXTS); var raw_hash := FileAccess.get_sha256(RAW)
	_check(contexts is Dictionary and raw_batch is Dictionary and contexts.fixture_only == true and raw_batch.fixture_only == true, "saved evidence is fixture-only")
	var batch_check := BatchValidator.validate_documents(raw_batch, contexts)
	_check(batch_check.get("ok", false) and contexts.cases.size() == 3 and raw_batch.cases.size() == 3, "saved evidence has exactly three joined cases")
	if not batch_check.get("ok", false): return
	var by_id := {}; for item in contexts.cases: by_id[item.case_id] = item
	var before: Dictionary = town.snapshot(); var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path); var commands: int = town.command_count()
	for candidate in raw_batch.cases:
		var fixture: Dictionary = by_id[candidate.case_id]; var view := {"available_actions": fixture.context.action_ids}; var offered := {}
		for option in fixture.options: offered[option.alias] = option.action_id
		var prepared := Reviewed.prepare(candidate.raw_content, view, offered, fixture.context.target_ids, fixture.context.claim_ids)
		var denied := Reviewed.authorize(prepared, view, offered, true, "No execution.", fixture.context.target_ids, fixture.context.claim_ids)
		var rejected: bool = not prepared.ok and not denied.get("ok", false) and not denied.has("decision")
		raw_rejections.append({"case_id": candidate.case_id, "rejected": rejected})
		_check(rejected, "saved raw rejected without decision: " + str(candidate.case_id))
		_check(town.snapshot() == before and town.command_count() == commands and FileAccess.get_file_as_bytes(path) == bytes, "saved rejection leaves world/disk unchanged: " + str(candidate.case_id))
	_check(FileAccess.get_sha256(CONTEXTS) == context_hash and FileAccess.get_sha256(RAW) == raw_hash, "saved evidence hashes unchanged")

func _turn(town: RefCounted, path: String, id: String, action_id: String, raw: String) -> Dictionary:
	var turns := Turns.new(); root.add_child(turns); turns.town = town; turns.save_path = path
	var brain := ReviewedBrain.new(); brain.turns = turns; brain.action_id = action_id; brain.raw = raw; turns.add_child(brain); turns.brains[id] = brain
	var result: Dictionary = await turns.step(id); turns.free(); return {"result": result}

func _raw(intent: String, speech: String, target: String) -> String:
	return JSON.stringify({"speech": speech, "intent": intent, "stance": "guarded", "target_id": target, "claim_ids": [], "stakes": "Terms remain authoritative.", "next_action": "", "confidence": 0.8, "private_thought": "fixture private note"})

func _option(town: RefCounted, id: String, action: String, part := "", worker := "", price := -1) -> String:
	for option in town.trade_options(id):
		if option.get("action") == action and (part.is_empty() or option.get("_part") == part) and (worker.is_empty() or option.get("_worker_id") == worker) and (price < 0 or option.get("_price") == price): return str(option.get("id", ""))
	return ""
func _contract(town: RefCounted, status: String) -> Dictionary:
	for item in town.snapshot().life.contracts:
		if item.get("item_id") == AXE and item.get("status") == status: return item
	return {}
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: _fail(label)
func _fail(label: String) -> void: failures.append(label)
func _finish(town: Variant, path: String, source_hash: String) -> void:
	if town != null: town.release_writer(path)
	if not path.is_empty() and FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	source_unchanged = FileAccess.get_sha256(Runner.SOURCE) == source_hash
	if not source_unchanged: _fail("formal source hash changed")
	print(JSON.stringify({"suite":"reviewed_dialogue_world","checks":checks,"failures":failures,"paid_calls":0,"fixture_only":true,"source_unchanged":source_unchanged,"formal_ids":[OWNER,SMITH],"offer_code":offer_code,"accept_code":accept_code,"escrow_col":escrow_col,"cold_memory_acceptance":cold_memory_acceptance,"raw_rejections":raw_rejections}))
	quit(0 if failures.is_empty() else 1)
