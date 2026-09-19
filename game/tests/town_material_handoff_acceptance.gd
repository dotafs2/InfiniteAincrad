extends "res://tests/town_capabilities_acceptance.gd"
const Handoff = preload("res://core/actions/material_handoff_capability.gd")

func _handoff(world, donor: String, recipient: String, material: String) -> String:
	for option in world.action_options(donor):
		if option.get("action") == "give_material" and option.get("counterparty") == recipient and option.get("material") == material:
			return str(option.id)
	return Handoff.new().option_id(material, recipient)

func _material_options(world, donor: String) -> Array:
	return world.action_options(donor).filter(func(option): return option.get("capability_id") == Handoff.ID)

func run() -> void:
	var stage := _new_stage("material-handoff")
	var world = stage.world
	var option := _handoff(world, C, B, "iron")
	var initial: Dictionary = world.snapshot()
	check(_material_options(world, C).any(func(row): return row.id == option and row.quantity == 1 and row.speech_allowed == false),
		"one owned iron produces one explicit nearby gift option")
	check(not _material_options(world, C).any(func(row): return row.counterparty == C or row.material not in ["iron", "wood"]),
		"the donor cannot target self or an unsupported stock field")
	var private_options: Array = _material_options(world, C).duplicate(true)
	world._trade_account(B).iron = 999
	check(_material_options(world, C) == private_options, "recipient material inventory cannot change or leak through donor discovery")
	world._trade_account(B).iron = 0
	check(world.snapshot() == initial and _material_options(world, C) == private_options, "option discovery remains pure")

	var before_total := int(world._trade_account(C).iron) + int(world._trade_account(B).iron)
	var before: Dictionary = world.snapshot()
	check(not world.perform_action(stage.path, C, option, "handoff:speech", "opengameagent_fixture", "You owe me.").ok and world.snapshot() == before,
		"a plain material gift cannot smuggle barter terms through speech")
	var given := _do(stage, C, option, "handoff:iron")
	var after: Dictionary = world.snapshot()
	var after_total := int(world._trade_account(C).iron) + int(world._trade_account(B).iron)
	check(given.code == Handoff.EVENT and given.quantity == 1 and world._trade_account(C).iron == 0 and world._trade_account(B).iron == 1 and after_total == before_total,
		"exactly one existing iron unit moves and resident stock is conserved")
	check(after.residents == before.residents and after.survival == before.survival and after.life.items == before.life.items
		and after.life.contracts == before.life.contracts and after.life.skills == before.life.skills and after.godot.positions == before.godot.positions,
		"the gift creates no food, money, item, contract, skill, debt or movement effect")
	var event: Dictionary = after.life.events[-1]
	check(event.type == Handoff.EVENT and event.actor_id == C and event.subject_id == B and event.recipient_ids == [C, B]
		and event.material == "iron" and event.quantity == 1 and event.donor_delta + event.recipient_delta == 0 and event.contractual == false,
		"the persisted physical handoff has exact participants and a zero-sum unit delta")
	check(not given.speech_delivery.delivered and not JSON.stringify(given).contains("999"), "receipt exposes no recipient balance and records no dialogue")
	var settled: Dictionary = world.snapshot()
	check(world.perform_action(stage.path, C, option, "handoff:iron", "opengameagent_fixture").duplicate and world.snapshot() == settled,
		"an exact replay cannot transfer the same unit twice")
	check(not world.perform_action(stage.path, C, option, "handoff:changed", "opengameagent_fixture").ok and world.snapshot() == settled,
		"a spent donor cannot use a fresh command to duplicate material")

	for defect in ["quantity", "delta", "material", "recipient", "range", "result", "speech", "orphan", "missing_store"]:
		var corrupt: Dictionary = settled.duplicate(true)
		var last: Dictionary = corrupt.life.events[-1]
		match defect:
			"quantity": last.quantity = 2
			"delta": last.recipient_delta = 2
			"material": last.material = "wood"
			"recipient": last.subject_id = A
			"range": last.recipient_position = [100, 0, 100]
			"result": corrupt.godot.capabilities.commands["handoff:iron"].result.recipient_id = A
			"speech": corrupt.godot.capabilities.commands["handoff:iron"].result.speech_delivery.delivered = true
			"orphan": corrupt.godot.capabilities.commands.erase("handoff:iron")
			"missing_store": corrupt.godot.erase("capabilities")
		check(not world._validate_state(corrupt).ok, "reject forged material handoff: " + defect)
	world.release_writer(stage.path)
	var restored := Actions.new()
	check(restored.load_from(stage.path).ok and _same_value(restored.snapshot(), settled), "conserved handoff and receipt cold-restore exactly")
	stage.world = restored
	_close_stage(stage)

	stage = _new_stage("material-handoff-range-busy")
	world = stage.world
	option = _handoff(world, C, B, "iron")
	world.host_move(B, world.position_of(C) + Vector3(world.FOOD_HANDOFF_RANGE + 0.01, 0, 0))
	before = world.snapshot()
	check(not _material_options(world, C).any(func(row): return row.counterparty == B and row.material == "iron")
		and not world.execute_action(C, option, "handoff:far", "opengameagent_fixture").ok and world.snapshot() == before,
		"a recipient beyond the existing physical handoff range makes a stale choice atomic")
	world.host_move(B, world.position_of(C) + Vector3(1, 0, 0))
	_do(stage, C, "life:rest", "handoff:busy-job")
	before = world.snapshot()
	check(_material_options(world, C).is_empty() and not world.execute_action(C, option, "handoff:busy", "opengameagent_fixture").ok and world.snapshot() == before,
		"a donor with a body job cannot perform a concurrent handoff")
	_close_stage(stage)

	stage = _new_stage("material-handoff-commitment")
	world = stage.world
	option = _handoff(world, B, C, "wood")
	check(_material_options(world, B).any(func(row): return row.id == option), "worker initially owns one uncommitted wood")
	var offer := ""
	for row in world.action_options(A):
		if row.action == "offer_repair" and row.get("_worker_id") == B and row.get("_part") == "handle" and row.get("_price") == 2:
			offer = row.id
	check(not offer.is_empty(), "fixture offers the existing wood repair contract")
	_do(stage, A, offer, "handoff:offer")
	var contract_id := str(world.snapshot().life.contracts[-1].id)
	_do(stage, B, "contract:accept:" + contract_id, "handoff:accept")
	before = world.snapshot()
	check(world._available_repair_material(B, "wood") == 0 and not _material_options(world, B).any(func(row): return row.material == "wood")
		and not world.execute_action(B, option, "handoff:committed", "opengameagent_fixture").ok and world.snapshot() == before,
		"an accepted repair's committed wood cannot be gifted away")
	_close_stage(stage)

	stage = _new_stage("material-handoff-rollback")
	world = stage.world
	option = _handoff(world, C, B, "iron")
	before = world.snapshot()
	var batch: Dictionary = world.execute_atomic_actions([_step(C, option, "handoff:batch"), _step(A, "ability:missing", "handoff:bad")])
	check(not batch.ok and world.snapshot() == before, "later batch failure rolls back both material accounts and handoff evidence")
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_material_handoff", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
