extends SceneTree
## Disposable, fixture-labelled integration of the existing axe-repair rules with
## formal saved resident IDs. It proves authoritative mechanics and persistence,
## not a resident-model decision or unattended autonomy.

const Town = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const SOURCE := "res://../worlds/restart-20260918-01/checkpoints/seq000000-22fe742384341a2b.world.json"
const OWNER := "shared:carpenter"
const SMITH := "shared:smith"
const AXE := "seed:axe"

var checks := 0
var failures: Array[String] = []

class FixtureBrain extends Node:
	var turns: Node
	var choice := ""
	var received := {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		received = view.duplicate(true)
		var alias := "missing"
		for key in turns._record(str(view.identity.id)).get("offered_actions", {}):
			if turns._record(str(view.identity.id)).offered_actions[key] == choice:
				alias = key
		await get_tree().process_frame
		return {"ok": true, "decision": {"action": alias,
			"reason": "Explicit offline formal-resident fixture choice."},
			"command_id": "fixture:axe-day:" + str(view.identity.id),
			"provenance": "opengameagent_fixture"}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _option(town: RefCounted, id: String, action: String, part := "", worker := "", price := -1) -> String:
	for option in town.trade_options(id):
		if option.get("action") == action and (part.is_empty() or option.get("_part") == part) \
				and (worker.is_empty() or option.get("_worker_id") == worker) and (price < 0 or option.get("_price") == price):
			return str(option.get("id", ""))
	return ""

func _contract(town: RefCounted, status: String) -> Dictionary:
	for contract in town.snapshot().life.get("contracts", []):
		if contract.get("item_id") == AXE and contract.get("status") == status:
			return contract
	return {}

func _repair_ask(town: RefCounted) -> String:
	for option in town.trade_options(OWNER):
		var need: Dictionary = option.get("_decision", {}).get("need", {})
		if option.get("action") == "ask_help" and option.get("counterparty") == SMITH \
				and need.get("kind") == "repair" and need.get("item_id") == AXE and need.get("part") == "edge":
			return str(option.get("id", ""))
	return ""

func _move_and_advance(town: RefCounted, path: String, id: String, seconds: float) -> void:
	var job: Dictionary = town.pending_job(id)
	town.host_move(id, town.destination(id, str(job.get("action", ""))))
	check(town.transaction(path, func(): return town.advance(seconds)).ok, "fixture advances durable authoritative job")

func _controller(town: RefCounted, path: String, id: String, choice: String) -> Dictionary:
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	var brain := FixtureBrain.new()
	brain.turns = turns
	brain.choice = choice
	turns.add_child(brain)
	turns.brains[id] = brain
	var result: Dictionary = await turns.step(id)
	var output := {"result": result, "view": brain.received.duplicate(true), "record": turns._record(id).duplicate(true)}
	turns.free()
	return output

func _write_fixture(path: String) -> String:
	var source_bytes := FileAccess.get_file_as_bytes(SOURCE)
	var source_hash := FileAccess.get_sha256(SOURCE)
	if FileAccess.file_exists(path):
		check(false, "fixture refuses to overwrite an existing destination")
		return source_hash
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	check(state is Dictionary, "formal genesis JSON parses")
	if not state is Dictionary: return source_hash
	state.fixture = true
	state.fixture_note = "Injected only into disposable axe-day formal-resident acceptance fixture."
	state.life.contracts = []
	state.godot.positions[OWNER] = [0, 0, 0]
	state.godot.positions[SMITH] = [0, 0, 0]
	state.godot.homes[OWNER] = [0, 0, 0]
	state.godot.homes[SMITH] = [0, 0, 0]
	for resident in state.residents:
		if resident.get("stable_id") in [OWNER, SMITH]: resident.coins_col = 10
	for item in state.life.items:
		if item.get("id") == AXE:
			item.owner_id = OWNER; item.custodian_id = OWNER; item.edge = 20; item.handle = 100
	for account in state.life.accounts:
		if account.get("resident_id") == OWNER:
			account.iron = 0; account.reserved_col = 0
		if account.get("resident_id") == SMITH:
			account.iron = 1; account.reserved_col = 0
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "", true, true))
	file.close()
	check(FileAccess.get_file_as_bytes(SOURCE) == source_bytes and FileAccess.get_sha256(SOURCE) == source_hash,
		"immutable formal genesis remains byte-identical")
	return source_hash

func run() -> void:
	var path := "user://formal-axe-day-%d-%d.world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var source_hash := _write_fixture(path)
	var town := Town.new()
	check(town.load_from(path).ok, "disposable formal-resident fixture loads")
	check(town.active_ids().has(OWNER) and town.active_ids().has(SMITH), "fixture retains actual Carpenter and Smith IDs")
	check(town._item(AXE).get("edge") == 20 and town._has_skill(SMITH, "metal_repair"), "injected need and lawful smith skill are present")
	var notice := await _controller(town, path, SMITH, "share-skill:" + OWNER + ":metal_repair")
	check(notice.result.get("ok"), "smith publicly discloses its existing repair skill through an offered alias")

	# Need and negotiation are both selected through the current authoritative option aliases.
	var ask := _repair_ask(town)
	check(not ask.is_empty(), "damaged formal axe offers a specific edge-help request")
	var asked := await _controller(town, path, OWNER, ask)
	check(asked.result.get("ok") and asked.record.get("action") == ask, "owner selects specific need through offered alias")
	var request_id := str(asked.record.get("result", {}).get("request_id", ""))
	if request_id.is_empty():
		for event in town.snapshot().life.events:
			if event.get("type") == "ask_help" and event.get("actor_id") == OWNER: request_id = str(event.get("request_id", ""))
	var willing := "reply:" + request_id + ":willing"
	var replied := await _controller(town, path, SMITH, willing)
	check(replied.result.get("ok") and replied.record.get("action") == willing, "fixture scripts smith's willing reply through an offered alias")

	var offer := _option(town, OWNER, "offer_repair", "edge", SMITH, 2)
	check(not offer.is_empty(), "owner receives a lawful 2 Col edge-repair offer")
	var offered := await _controller(town, path, OWNER, offer)
	check(offered.result.get("ok") and offered.record.get("result", {}).get("code") == "contract_proposed", "offer is an authoritative accepted decision")
	var contract := _contract(town, "proposed")
	var contract_id := str(contract.get("id", ""))
	check(not contract_id.is_empty(), "authoritative proposal has a stable contract ID")
	var accepted := await _controller(town, path, SMITH, "contract:accept:" + contract_id)
	check(accepted.result.get("ok") and accepted.record.get("result", {}).get("code") == "contract_accepted", "smith accepts only the offered authoritative contract")
	check(town.resident(OWNER).coins_col == 8 and town._trade_account(OWNER).reserved_col == 2, "acceptance produces the real escrow receipt")
	check(town.snapshot().life.events.any(func(event): return event.get("type") == "axe_contract_accepted" and event.get("actor_id") == SMITH), "accepted action emits a durable public event")
	var accept_request := str(accepted.record.get("request_id", ""))
	var archive: Dictionary = town._state.godot.get("resident_archive", {}).get("entries", {}).get(accept_request, {})
	check(archive.get("application", {}).get("code") == "contract_accepted", "resident archive retains the actual acceptance effect")

	# Use the same existing lifecycle after acceptance; no parallel repair executor exists here.
	check(town.transaction(path, func(): return town.submit_trade(OWNER, "contract:deliver:" + contract_id, "fixture:deliver", "opengameagent_fixture")).ok, "owner starts delivery")
	_move_and_advance(town, path, OWNER, 1.0)
	check(town._item(AXE).get("custodian_id") == SMITH, "delivery changes custody only after job completion")
	check(town.transaction(path, func(): return town.submit_trade(SMITH, "contract:work:" + contract_id + ":edge", "fixture:work", "opengameagent_fixture")).ok, "smith starts authoritative edge work")
	_move_and_advance(town, path, SMITH, 60.0)
	check(town._item(AXE).get("edge") == 100 and town._trade_account(SMITH).iron == 0, "one iron repairs the edge exactly once")
	check(town.transaction(path, func(): return town.submit_trade(OWNER, "contract:collect:" + contract_id, "fixture:collect", "opengameagent_fixture")).ok, "owner starts collection")
	_move_and_advance(town, path, OWNER, 1.0)
	check(town._item(AXE).get("custodian_id") == OWNER and town.resident(SMITH).coins_col == 12, "collection returns axe and settles one payment")
	var final_state := town.snapshot()
	check(town.submit_trade(OWNER, "contract:collect:" + contract_id, "fixture:collect", "opengameagent_fixture").get("duplicate", false) and town.snapshot() == final_state,
		"duplicate collection is fenced without a second payment")

	# Cold restart preserves both the real accepted receipt and the smith's own memory projection.
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var cold := Town.new()
	check(cold.load_from(path).ok and FileAccess.get_file_as_bytes(path) == saved_bytes, "independent cold load preserves disposable save bytes")
	var memory_probe := await _controller(cold, path, SMITH, "wait")
	var memories: Array = memory_probe.view.get("memory", {}).get("previous_decisions", [])
	check(memories.any(func(entry): return str(entry.get("action", "")).begins_with("contract:accept:") and entry.get("result", {}).get("code") == "axe_contract_accepted"),
		"same formal smith sees its accepted receipt in next durable personal memory")
	check(memory_probe.view.get("experiences", []).any(func(event): return event.get("type") == "axe_contract_accepted"), "same formal smith retains its own acceptance event after restart")

	# Lawful failure is valid: without iron, the exact acceptance option disappears and nothing changes.
	var refusal_path := "user://formal-axe-day-refusal-%d-%d.world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_write_fixture(refusal_path)
	var refusal := Town.new()
	check(refusal.load_from(refusal_path).ok, "separate lawful-failure fixture loads")
	refusal._trade_account(SMITH).iron = 0
	var failure_offer := _option(refusal, OWNER, "offer_repair", "edge", SMITH, 2)
	check(refusal.transaction(refusal_path, func(): return refusal.submit_trade(OWNER, failure_offer, "fixture:failure-offer", "opengameagent_fixture")).ok, "owner may still propose without forcing acceptance")
	var failure_contract := _contract(refusal, "proposed")
	var failure_before := refusal.snapshot()
	check(not failure_contract.is_empty() and _option(refusal, SMITH, "accept") == "" and not refusal.submit_trade(SMITH, "contract:accept:" + str(failure_contract.get("id", "")), "fixture:failure-accept", "opengameagent_fixture").ok
		and refusal.snapshot() == failure_before, "missing iron lawfully blocks acceptance without changing coins, material or contract")
	refusal.release_writer(refusal_path)
	cold.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(refusal_path))
	check(FileAccess.get_sha256(SOURCE) == source_hash, "canonical formal checkpoint hash remains unchanged at teardown")
	print(JSON.stringify({"suite": "town_axe_day_formal_fixture", "checks": checks, "failures": failures,
		"paid_calls": 0, "formal_ids": [OWNER, SMITH], "source_sha256": source_hash,
		"fixture_only": true}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
