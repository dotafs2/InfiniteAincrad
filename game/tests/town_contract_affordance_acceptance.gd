extends "res://tests/town_trade_acceptance.gd"
## gm-02 / issue-30c86464ae28: a worker's repair-acceptance affordance must state exactly the
## prerequisites the authoritative submit path enforces. Offline synthetic proof only: no paid
## calls, no real world save, no other resident's private inventory or dialogue.
##
## Trigger mirrored from the real supervisor-specified event (shared:aincrad-trial-1, seq 131): an
## edge-repair offer at price 2 Col from an owner holding 8 Col to a smith holding 0 iron was listed
## as an executable acceptance; the authoritative submit refused it and conserved every resource.
## The real denial and the conservation are correct and are preserved here, never removed.

const OWNER := "fictional:ember"       # axe owner: 12 Col, 2 wood, 0 iron
const WOODWORKER := "fictional:birch"  # wood carpenter: 3 Col, 1 wood, 0 iron
const SMITH := "fictional:forge"       # metal smith: 3 Col, 0 wood, 1 iron, metal_repair
const AXE := "fictional:axe-edge"
const EDGE_CONTRACT := "fixture:proposed-edge"

func _path(tag: String) -> String:
	return "user://contract-affordance-%s-%d.json" % [tag, Time.get_ticks_usec()]

func _affordance_fixture(owner_coins: int, smith_iron: int, smith_skill: bool, with_contract: bool) -> Dictionary:
	## Synthetic fixture only. Every fact is fixed in the file before the world loads it.
	var world := trade_fixture()
	for person in world.residents:
		if person.stable_id == OWNER:
			person.coins_col = owner_coins
	for account in world.life.accounts:
		if account.resident_id == SMITH:
			account.iron = smith_iron
	if not smith_skill:
		world.life.skills = world.life.skills.filter(func(skill): return not (skill.resident_id == SMITH and skill.skill_id == "metal_repair"))
	if with_contract:
		# Exactly the record shape the world itself writes when an offer is accepted as proposed.
		world.life.contracts.append({"id": EDGE_CONTRACT, "part": "edge", "item_id": AXE, "owner_id": OWNER,
			"worker_id": SMITH, "status": "proposed", "price_col": 2, "reserved_col": 0})
	return world

func _accept_option(town: TownTrade, id: String, contract_id: String) -> Dictionary:
	for option in town.trade_options(id):
		if str(option.get("id", "")) == "contract:accept:" + contract_id:
			return option
	return {}

func _accept_notes(town: TownTrade, id: String, contract_id: String) -> Array:
	return town.resident_view(id).unavailable_actions.filter(func(entry): return entry.get("action") == "accept" and entry.get("contract_id") == contract_id)

func _forged_accept(town: TownTrade, worker: String, contract_id: String, label: String, command: String) -> Dictionary:
	## The exact option payload a pre-fix (or foreign) affordance handed out, driven straight into the
	## authoritative start path. It proves the submit-side guard was neither weakened nor removed.
	return town._apply_trade_start(worker, {"action": "accept", "counterparty": OWNER, "_contract_id": contract_id, "label": label}, command, "opengameagent_fixture")

func _cleanup(path: String, town: TownTrade) -> void:
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".replace-pending"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func run() -> void:
	# --- 1. The real trigger: the owner holds 8 Col, the offered smith holds 0 iron.
	var trigger_path := _path("trigger")
	_write_fixture(trigger_path, _affordance_fixture(8, 0, true, false))
	var trigger := _load_trade(trigger_path)
	var offer := _option(trigger, OWNER, "offer_repair", "edge", SMITH, 2)
	check(not offer.is_empty(), "the owner can still make a lawful edge-repair offer")
	execute(trigger, trigger_path, OWNER, offer, "trigger-offer")
	var contract := _contract(trigger, AXE, "proposed")
	var contract_id := str(contract.get("id", ""))
	check(contract_id.begins_with("trade_contract_") and contract.get("price_col") == 2 and contract.get("worker_id") == SMITH, "the world records the offer terms unchanged")
	# Pre-fix this exact choice was listed even though the smith held no iron.
	check(_accept_option(trigger, SMITH, contract_id).is_empty(), "an acceptance the smith cannot execute is not offered as executable")
	check(not _option(trigger, SMITH, "reject", "", "", -1).is_empty(), "the lawful refusal is still offered")
	var notes := _accept_notes(trigger, SMITH, contract_id)
	var note: Dictionary = notes[0] if notes.size() == 1 else {}
	check(note.get("code") == "material_unavailable" and note.get("required_material") == "iron" and int(note.get("required_quantity", 0)) == 1, "the smith is told the real missing prerequisite instead of a silent omission")
	check(not note.has("position") and not note.has("target_position") and not note.has("owner_coins_col"), "the prerequisite statement exposes no other resident's position or wallet")
	check(not JSON.stringify(trigger.resident_view(SMITH).unavailable_actions).contains(WOODWORKER), "no other resident's inventory or dialogue enters the smith's personal text")
	check(not trigger.resident_view(OWNER).unavailable_actions.any(func(entry): return entry.get("action") == "accept"), "the owner does not receive the worker's private shortfall")
	check(not JSON.stringify(trigger.resident_view(WOODWORKER)).contains(contract_id), "a third resident does not learn the private contract")
	# Read-only affordance construction: nothing about the world may drift while it is enumerated.
	var stable: Dictionary = trigger.snapshot()
	for repeat in 3:
		for who in [OWNER, WOODWORKER, SMITH]:
			trigger.trade_options(who)
	check(trigger.snapshot() == stable, "repeated option construction changes no item, coin, skill, contract, need or history")
	# The authoritative denial and its conservation are the correct behaviour and stay intact.
	var bytes_before := FileAccess.get_file_as_bytes(trigger_path)
	var trigger_before: Dictionary = trigger.snapshot()
	var refused := trigger.transaction(trigger_path, func(): return _forged_accept(trigger, SMITH, contract_id, "pre-fix acceptance", "trigger-accept"))
	check(not refused.ok and refused.code == "insufficient_funds", "authority still denies the impossible acceptance with its historical code")
	check(trigger.snapshot() == trigger_before and FileAccess.get_file_as_bytes(trigger_path) == bytes_before, "the denial rewrites no world fact and no save byte")
	check(trigger.resident(OWNER).coins_col == 8 and trigger._trade_account(OWNER).get("reserved_col", -1) == 0 and trigger._contract(contract_id).get("status") == "proposed", "the denial reserves nothing, pays nobody and leaves the contract outstanding")
	check(trigger._trade_account(SMITH).get("iron", -1) == 0, "the denial invents no material")
	check(trigger._item(AXE).get("edge", -1) == 20 and trigger._item(AXE).get("owner_id") == OWNER and trigger._item(AXE).get("custodian_id") == OWNER, "the real material shortage and the outstanding repair need stay real")
	_cleanup(trigger_path, trigger)

	# --- 2. Positive control: identical contract, sufficient legitimate skill, material and funds.
	var ok_path := _path("positive")
	_write_fixture(ok_path, _affordance_fixture(12, 1, true, true))
	var good := _load_trade(ok_path)
	check(not _accept_option(good, SMITH, EDGE_CONTRACT).is_empty(), "with the skill, 1 iron and 12 Col the acceptance is offered")
	check(_accept_notes(good, SMITH, EDGE_CONTRACT).is_empty(), "no prerequisite is reported while the acceptance is executable")
	var accepted := good.transaction(ok_path, func(): return good.submit_trade(SMITH, "contract:accept:" + EDGE_CONTRACT, "positive-accept", "opengameagent_fixture"))
	check(accepted.ok and accepted.code == "contract_accepted", "the offered acceptance succeeds under the existing rules")
	check(good.resident(OWNER).coins_col == 10 and good._trade_account(OWNER).get("reserved_col", -1) == 2 and good._contract(EDGE_CONTRACT).get("reserved_col", -1) == 2 and good._contract(EDGE_CONTRACT).get("status") == "accepted", "escrow moves exactly once at the unchanged price")
	check(good.resident(SMITH).coins_col == 3 and good._trade_account(SMITH).get("iron", -1) == 1, "acceptance alone pays nobody and consumes nothing")
	var duplicate := good.submit_trade(SMITH, "contract:accept:" + EDGE_CONTRACT, "positive-accept", "opengameagent_fixture")
	check(duplicate.get("duplicate", false) and duplicate.ok and good._trade_account(OWNER).get("reserved_col", -1) == 2, "the same command cannot reserve a second time")
	check(_accept_option(good, SMITH, EDGE_CONTRACT).is_empty(), "an already accepted contract is no longer offered as an acceptance")
	good.release_writer(ok_path)
	var cold_accept := _load_trade(ok_path)
	var cold_contract := cold_accept._contract(EDGE_CONTRACT)
	check(cold_contract.get("status") == "accepted" and cold_accept._trade_account(OWNER).get("reserved_col", -1) == 2 and cold_accept.resident(OWNER).coins_col == 10, "cold restore keeps the accepted contract and its escrow")
	check(_accept_option(cold_accept, SMITH, EDGE_CONTRACT).is_empty(), "cold restore never re-offers an accepted contract")
	_cleanup(ok_path, good)

	# --- 3. Negative matrix on a pre-existing proposed contract: each real prerequisite on its own.
	var cases := [
		{"tag": "skill", "coins": 12, "iron": 1, "skill": false, "code": "skill_unavailable"},
		{"tag": "funds", "coins": 1, "iron": 1, "skill": true, "code": "funds_unavailable"},
		{"tag": "material", "coins": 12, "iron": 0, "skill": true, "code": "material_unavailable"},
	]
	for case in cases:
		var tag := str(case.tag)
		var case_path := _path(tag)
		_write_fixture(case_path, _affordance_fixture(int(case.coins), int(case.iron), bool(case.skill), true))
		var part := _load_trade(case_path)
		check(_accept_option(part, SMITH, EDGE_CONTRACT).is_empty(), tag + ": the acceptance is not offered while that prerequisite fails")
		var entries := _accept_notes(part, SMITH, EDGE_CONTRACT)
		var entry: Dictionary = entries[0] if entries.size() == 1 else {}
		check(entry.get("code") == str(case.code), tag + ": the worker is told which real prerequisite fails")
		var coins_before: int = part.resident(OWNER).coins_col
		var case_refused := part.transaction(case_path, func(): return _forged_accept(part, SMITH, EDGE_CONTRACT, tag + " acceptance", tag + "-accept"))
		check(not case_refused.ok and case_refused.code == "insufficient_funds", tag + ": authority still refuses the same choice")
		check(part.resident(OWNER).coins_col == coins_before and part._trade_account(OWNER).get("reserved_col", -1) == 0 and part._contract(EDGE_CONTRACT).get("status") == "proposed" and part._trade_account(SMITH).get("iron", -1) == int(case.iron), tag + ": the refusal conserves money, material and contract")
		_cleanup(case_path, part)

	# --- 4. Stale-choice control: generated while valid, submitted after the world changed.
	var stale_path := _path("stale")
	_write_fixture(stale_path, _affordance_fixture(12, 1, true, true))
	var stale := _load_trade(stale_path)
	check(not _accept_option(stale, SMITH, EDGE_CONTRACT).is_empty(), "stale control starts from an offered acceptance")
	stale._trade_account(SMITH).iron = 0
	var stale_before: Dictionary = stale.snapshot()
	var stale_bytes := FileAccess.get_file_as_bytes(stale_path)
	var stale_result := stale.transaction(stale_path, func(): return stale.submit_trade(SMITH, "contract:accept:" + EDGE_CONTRACT, "stale-accept", "opengameagent_fixture"))
	check(not stale_result.ok and stale_result.code == "option_unavailable", "a stale acceptance submitted after the world changed is refused")
	check(stale.snapshot() == stale_before and FileAccess.get_file_as_bytes(stale_path) == stale_bytes, "the stale refusal changes no world fact and rewrites no save byte")
	check(stale.resident(OWNER).coins_col == 12 and stale._trade_account(OWNER).get("reserved_col", -1) == 0 and stale._contract(EDGE_CONTRACT).get("status") == "proposed" and stale._trade_account(SMITH).get("iron", -1) == 0, "the stale refusal moves no money or material, relaxes no reservation and cannot auto-succeed")
	check(_accept_option(stale, SMITH, EDGE_CONTRACT).is_empty(), "re-enumeration no longer offers the stale acceptance")
	_cleanup(stale_path, stale)

	var spent_path := _path("stale-funds")
	_write_fixture(spent_path, _affordance_fixture(12, 1, true, true))
	var spent := _load_trade(spent_path)
	check(not _accept_option(spent, SMITH, EDGE_CONTRACT).is_empty(), "funds stale control starts from an offered acceptance")
	spent.resident(OWNER).coins_col = 1
	var spent_before: Dictionary = spent.snapshot()
	var spent_result := spent.transaction(spent_path, func(): return spent.submit_trade(SMITH, "contract:accept:" + EDGE_CONTRACT, "stale-funds-accept", "opengameagent_fixture"))
	check(not spent_result.ok and spent.snapshot() == spent_before and spent._trade_account(OWNER).get("reserved_col", -1) == 0, "an offer the owner can no longer fund cannot be accepted or reserved")
	_cleanup(spent_path, spent)

	# --- 5. Same world, cold-restored: the shortage, the need and the honest statement are unchanged.
	var restore_path := _path("restore")
	_write_fixture(restore_path, _affordance_fixture(8, 0, true, true))
	var first := _load_trade(restore_path)
	var first_notes := _accept_notes(first, SMITH, EDGE_CONTRACT)
	check(first_notes.size() == 1, "the restored world states the missing prerequisite")
	first.release_writer(restore_path)
	var second := _load_trade(restore_path)
	check(second.resident_view(SMITH).unavailable_actions == first.resident_view(SMITH).unavailable_actions, "a cold restore repeats the same honest prerequisite statement")
	check(_accept_option(second, SMITH, EDGE_CONTRACT).is_empty() and second._item(AXE).get("edge", -1) == 20 and second._contract(EDGE_CONTRACT).get("status") == "proposed", "a cold restore keeps the shortage and the outstanding repair need real")
	_cleanup(spent_path, spent)

	print(JSON.stringify({"suite": "town_contract_affordance", "checks": checks, "failures": failures, "paid_calls": 0, "provenance": "scripted_test"}))
	quit(0 if failures == 0 else 1)
