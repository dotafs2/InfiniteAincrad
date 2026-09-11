extends "res://tests/town_trade_acceptance.gd"

const OWNER := "fictional:ember"
const WOODWORKER := "fictional:birch"
const SMITH := "fictional:forge"

func _source_fixture() -> Dictionary:
	var world := trade_fixture()
	var events: Array = world.life.events
	while events.size() < 33:
		var seq := events.size() + 1
		events.append({"event_id": "life_event_%d" % seq, "seq": seq, "type": "fixture_observation", "actor_id": OWNER, "subject_id": OWNER, "recipient_ids": [OWNER], "text": "fixture history"})
	events[32] = {"event_id": "life_event_33", "seq": 33, "type": "visitor_reply", "actor_id": SMITH, "subject_id": "visitor:local", "recipient_ids": [SMITH, "visitor:local"], "source": "opengameagent_fixture", "text": "I am concerned that payment only arrives when the owner collects the repaired tool.", "reply_choice": "unavailable", "request_id": "visitor_inquiry:smith-concern", "contractual": false}
	world.life.seq = events.size()
	return world

func _write_temp(path: String, world: Dictionary) -> void:
	_write_fixture(path, world)

func _load_source(path: String) -> TownTrade:
	var town := TownTrade.new()
	check(town.load_from(path).ok, "completion fixture loads")
	return town

func _install(town: TownTrade, path: String, command_id: String = "development_gm:completion-v1") -> Dictionary:
	return town.transaction(path, func(): return town.install_completion_escrow(33, command_id))

func _completion_option(town: TownTrade, owner: String, part: String, worker: String, price: int) -> String:
	for option in town.trade_options(owner):
		if option.get("action") == "offer_repair" and option.get("_settlement") == "completion" and option.get("_part") == part and option.get("_worker_id") == worker and option.get("_price") == price:
			return str(option.get("id"))
	return ""

func _completion_contract(town: TownTrade, status: String) -> Dictionary:
	for contract in town.snapshot().life.contracts:
		if contract.get("settlement") == "completion" and contract.get("status") == status:
			return contract
	return {}

func _set_completion_field(world: Dictionary, field: String, value: Variant) -> void:
	for contract in world.life.contracts:
		if contract.get("settlement") == "completion":
			contract[field] = value
			return

func _cleanup(path: String, town: TownTrade) -> void:
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".replace-pending"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func run() -> void:
	var legacy_path := "user://completion-legacy-%d.json" % Time.get_ticks_usec()
	var legacy_world := trade_fixture()
	_write_temp(legacy_path, legacy_world)
	var legacy := _load_source(legacy_path)
	check(not legacy.snapshot().godot.has("trade"), "old save has no completion runtime state")
	check(_completion_option(legacy, OWNER, "edge", SMITH, 2).is_empty(), "completion offer is absent before installation")
	var no_source := legacy.install_completion_escrow(34, "development_gm:missing-source")
	check(not no_source.ok and no_source.code == "source_need_missing", "missing source sequence is rejected")
	var non_gm := legacy.install_completion_escrow(33, "npc:smith-install")
	check(not non_gm.ok and non_gm.code == "development_gm_required", "NPC command cannot install capability")

	var old_offer := _option(legacy, OWNER, "offer_repair", "edge", SMITH, 2)
	execute(legacy, legacy_path, OWNER, old_offer, "legacy-offer")
	var old_contract := _contract(legacy, "fictional:axe-edge", "proposed")
	execute(legacy, legacy_path, SMITH, "contract:accept:" + str(old_contract.id), "legacy-accept")
	execute(legacy, legacy_path, OWNER, "contract:deliver:" + str(old_contract.id), "legacy-deliver")
	arrive(legacy, OWNER)
	elapse(legacy, legacy_path, 1)
	execute(legacy, legacy_path, SMITH, "contract:work:" + str(old_contract.id) + ":edge", "legacy-work")
	arrive(legacy, SMITH)
	elapse(legacy, legacy_path, 60)
	old_contract = _contract(legacy, "fictional:axe-edge", "completed")
	check(old_contract.get("settlement", "collection") == "collection" and old_contract.reserved_col == 2 and legacy.resident(SMITH).coins_col == 3, "legacy completed contract remains unpaid until collection")
	check(legacy._validate_state(legacy.snapshot()).ok, "legacy completed unpaid state remains valid")
	_cleanup(legacy_path, legacy)

	var path := "user://completion-escrow-%d.json" % Time.get_ticks_usec()
	var world := _source_fixture()
	_write_temp(path, world)
	var town := _load_source(path)
	check(not town._validate_completion_manifest({"id": "wrong"}).ok, "malformed module shape is rejected")
	check(not town.trade_options(SMITH).any(func(option): return option.get("action") == "install_completion_escrow"), "NPC trade options do not expose installation")
	var installed := _install(town, path)
	check(installed.ok and installed.code == "completion_escrow_installed" and installed.reviewer == "development_gm" and installed.source_seq == 33, "development GM installs from the authoritative public source")
	var capability: Dictionary = town.snapshot().godot.trade.capabilities.repair_completion_escrow
	check(capability.source.actor_id == SMITH and capability.source.text == world.life.events[32].text, "immutable source evidence stores sequence actor and text")
	var duplicate := _install(town, path)
	check(duplicate.ok and duplicate.duplicate and duplicate.code == installed.code, "install receipt is deterministic and idempotent")
	var conflict := town.install_completion_escrow(32, "development_gm:completion-v1")
	check(not conflict.ok and conflict.code == "command_conflict", "same command with another source conflicts")
	var capability_conflict := town.install_completion_escrow(33, "development_gm:another-install")
	check(not capability_conflict.ok and capability_conflict.code == "capability_conflict", "second capability installation conflicts")

	var offers := town.trade_options(OWNER).filter(func(option): return option.get("action") == "offer_repair" and option.get("_part") == "edge" and option.get("_worker_id") == SMITH)
	check(offers.size() == 6 and offers.any(func(option): return option.get("_settlement") == "collection" and option.get("_price") == 2) and offers.any(func(option): return option.get("_settlement") == "completion" and option.get("_price") == 8), "installation adds 2 5 and 8 Col completion variants beside legacy offers")

	var completion_offer := _completion_option(town, OWNER, "edge", SMITH, 2)
	execute(town, path, OWNER, completion_offer, "completion-offer")
	var contract := _completion_contract(town, "proposed")
	check(contract.get("settlement") == "completion" and contract.get("settled") == false, "new completion contract records explicit settlement")
	execute(town, path, SMITH, "contract:accept:" + str(contract.id), "completion-accept")
	check(town.resident(OWNER).coins_col == 10 and town._trade_account(OWNER).reserved_col == 2, "acceptance escrows the existing funds")
	execute(town, path, OWNER, "contract:deliver:" + str(contract.id), "completion-deliver")
	arrive(town, OWNER)
	elapse(town, path, 1)
	execute(town, path, SMITH, "contract:work:" + str(contract.id) + ":edge", "completion-work-start")
	arrive(town, SMITH)
	elapse(town, path, 30)
	town.release_writer(path)
	var unfinished := _load_source(path)
	check(unfinished.pending_job(SMITH).get("action") == "work" and _completion_contract(unfinished, "delivered").reserved_col == 2 and unfinished.resident(SMITH).coins_col == 3, "cold restore preserves unfinished work and escrow")
	arrive(unfinished, SMITH)
	elapse(unfinished, path, 30)
	var paid_contract := _completion_contract(unfinished, "completed")
	check(paid_contract.get("settled") == true and paid_contract.reserved_col == 0 and unfinished.resident(SMITH).coins_col == 5 and unfinished._trade_account(OWNER).reserved_col == 0, "successful work pays the exact escrow once")
	unfinished.release_writer(path)
	var paid_restore := _load_source(path)
	check(_completion_contract(paid_restore, "completed").get("settled") == true and paid_restore._item("fictional:axe-edge").custodian_id == SMITH, "cold restore preserves paid but uncollected completion")
	execute(paid_restore, path, OWNER, "contract:collect:" + str(paid_contract.id), "completion-collect")
	arrive(paid_restore, OWNER)
	elapse(paid_restore, path, 1)
	var worker_coins: int = paid_restore.resident(SMITH).coins_col
	var collect_duplicate := paid_restore.transaction(path, func(): return paid_restore.submit_trade(OWNER, "contract:collect:" + str(paid_contract.id), "completion-collect", "opengameagent_fixture"))
	check(collect_duplicate.ok and collect_duplicate.duplicate and paid_restore.resident(SMITH).coins_col == worker_coins and paid_restore._item("fictional:axe-edge").custodian_id == OWNER, "collection returns property without a second payment")
	check(paid_restore.resident(OWNER).coins_col + paid_restore.resident(WOODWORKER).coins_col + paid_restore.resident(SMITH).coins_col == 18, "completion settlement conserves total coins")

	var bad_reserved := paid_restore.snapshot()
	_set_completion_field(bad_reserved, "reserved_col", 1)
	check(not paid_restore._validate_state(bad_reserved).ok, "corrupt reserved amount is rejected")
	var bad_settlement := paid_restore.snapshot()
	_set_completion_field(bad_settlement, "settlement", "unknown")
	check(not paid_restore._validate_state(bad_settlement).ok, "unknown settlement is rejected")

	var failure_path := "user://completion-failure-%d.json" % Time.get_ticks_usec()
	var failure_world := _source_fixture()
	_write_temp(failure_path, failure_world)
	var failure := _load_source(failure_path)
	check(_install(failure, failure_path).ok, "failure fixture installs capability")
	execute(failure, failure_path, OWNER, _completion_option(failure, OWNER, "edge", SMITH, 2), "failure-offer")
	var failed_contract := _completion_contract(failure, "proposed")
	execute(failure, failure_path, SMITH, "contract:accept:" + str(failed_contract.id), "failure-accept")
	execute(failure, failure_path, OWNER, "contract:deliver:" + str(failed_contract.id), "failure-deliver")
	arrive(failure, OWNER)
	elapse(failure, failure_path, 1)
	execute(failure, failure_path, SMITH, "contract:work:" + str(failed_contract.id) + ":edge", "failure-work-start")
	arrive(failure, SMITH)
	failure._trade_account(SMITH).iron = 0
	elapse(failure, failure_path, 60)
	failed_contract = _completion_contract(failure, "delivered")
	check(failed_contract.reserved_col == 2 and failed_contract.get("settled") == false and failure.resident(SMITH).coins_col == 3, "failed work does not pay")
	_cleanup(failure_path, failure)

	var cancel_path := "user://completion-cancel-%d.json" % Time.get_ticks_usec()
	var cancel_world := _source_fixture()
	_write_temp(cancel_path, cancel_world)
	var cancelled := _load_source(cancel_path)
	check(_install(cancelled, cancel_path).ok, "cancel fixture installs capability")
	execute(cancelled, cancel_path, OWNER, _completion_option(cancelled, OWNER, "edge", SMITH, 2), "cancel-offer")
	var cancel_contract := _completion_contract(cancelled, "proposed")
	execute(cancelled, cancel_path, SMITH, "contract:accept:" + str(cancel_contract.id), "cancel-accept")
	execute(cancelled, cancel_path, OWNER, "contract:cancel:" + str(cancel_contract.id), "cancel-contract")
	check(cancelled.resident(OWNER).coins_col == 12 and cancelled._trade_account(OWNER).reserved_col == 0, "cancelled accepted contract refunds escrow")
	_cleanup(cancel_path, cancelled)
	_cleanup(path, paid_restore)
	_cleanup(legacy_path, legacy)
	print(JSON.stringify({"suite": "town_completion_escrow", "checks": checks, "failures": failures, "paid_calls": 0, "provenance": "scripted_test"}))
	quit(0 if failures == 0 else 1)
