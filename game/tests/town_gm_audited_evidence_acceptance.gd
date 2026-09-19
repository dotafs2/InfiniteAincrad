extends "res://tests/town_self_repair_acceptance.gd"

const Handoff = preload("res://core/actions/material_handoff_capability.gd")
const SECRET := "PRIVATE_AUDITED_EVIDENCE_SENTINEL"

func _entries(snapshot: Dictionary, kind: String) -> Array:
	return snapshot.get("evidence", []).filter(func(value): return value is Dictionary and value.get("evidence_kind", "") == kind)

func _handoff_option(world, donor: String, recipient: String, material: String) -> String:
	for option in world.action_options(donor):
		if option.get("action") == "give_material" and option.get("counterparty") == recipient and option.get("material") == material:
			return str(option.id)
	return Handoff.new().option_id(material, recipient)

func run() -> void:
	var stage := _repair_stage("gm-audited-evidence")
	var world = stage.world
	_do(stage, A, SELF, "gm:self-complete")
	world.host_move(A, world.destination(A, "self_repair"))
	world.advance(60.0)
	check(world.action_receipt("gm:self-complete").result.code == "self_repair_completed", "fixture creates an authoritative self-repair completion")
	var gift := _handoff_option(world, C, B, "iron")
	_do(stage, C, gift, "gm:material-gift")
	check(world.snapshot().life.events[-1].type == "material_handed_over", "fixture creates an authoritative physical material handoff")
	# A basic-life command is accepted first and then reaches a depleted source. The turn journal
	# is the only accepted-action acknowledgement; the terminal command receipt is authoritative.
	world._trade_account(A).food = 0
	world._state.foraging.stock = 0
	var basic: Dictionary = world.start_action(A, "harvest_ration", "gm:basic-failure", "opengameagent_fixture")
	check(basic.ok and basic.code == "action_started", "fixture accepts a basic-life action before terminal depletion")
	world.host_move(A, world.destination(A, "harvest_ration"))
	world.advance(60.0)
	check(world.snapshot().godot.commands["gm:basic-failure"].result.code == "resources_unavailable", "fixture records terminal basic-life resource failure")
	world._state.godot.resident_turns = {A: {"status": "settled", "history": [{"status": "settled", "command_id": "gm:basic-failure",
		"action": "life:harvest_ration", "result": {"ok": true, "code": "action_started"}}]}}

	var snapshot: Dictionary = world.background_gm_snapshot()
	var completed := _entries(snapshot, "self_repair_completed")
	var gifts := _entries(snapshot, "material_handoff_completed")
	var depleted := _entries(snapshot, "basic_life_resources_unavailable")
	check(completed.size() == 1 and gifts.size() == 1 and depleted.size() == 1,
		"only cross-checked terminal self-repair, handoff and basic failure enter the bounded projection")
	if completed.size() == 1:
		var repair: Dictionary = completed[0]
		check(repair.get("status") == "completed" and repair.get("result_code") == "self_repair_completed"
			and repair.get("physical_facts", {}).get("consumed") == 1 and repair.get("physical_facts", {}).get("position", []).size() == 3,
			"self-repair completion exposes status, actual consumption and physical position")
	if gifts.size() == 1:
		var handoff: Dictionary = gifts[0]
		check(handoff.get("status") == "completed" and handoff.get("donor_id") == C and handoff.get("recipient_id") == B
			and handoff.get("physical_facts", {}).get("quantity", 1) == 1
			and handoff.get("physical_facts", {}).get("donor_delta") == -1,
			"material handoff exposes the donor, recipient and conserved physical delta")
	if depleted.size() == 1:
		var failed: Dictionary = depleted[0]
		check(failed.get("status") == "failed" and failed.get("result_code") == "resources_unavailable"
			and failed.get("physical_facts", {}).get("consumed") == 0 and failed.get("action") == "harvest_ration",
			"basic-life failure exposes the terminal resource result with zero consumption")
	check(snapshot.get("counts", {}).get("issues", 65) <= 64, "audited evidence shares the existing hard limit")
	check(not JSON.stringify(snapshot).contains(SECRET), "audited evidence never copies private text")
	for entry in completed + gifts + depleted:
		check(not entry.has("delivered_text") and not entry.has("speech_delivery") and entry.get("discriminators", {}).get("public_utterance", true) == false,
			"terminal evidence is independent physical evidence, never speech")

	# More than one bounded feed's worth of historical handoffs must retain the current basic
	# failure and choose the newest historical window. The selected historical window itself stays
	# chronological, so a consumer never sees an older receipt after a newer one.
	var saved_state: Dictionary = world._state.duplicate(true)
	for index in 70:
		var command_id := "gm:old-gift-%02d" % index
		var sequence := int(world._state.life.events.size()) + 1
		var event_id := "life_event_old_gift_%02d" % index
		var donor_position: Vector3 = world.position_of(C)
		var recipient_position: Vector3 = world.position_of(B)
		world._state.life.events.append({"seq": sequence, "event_id": event_id, "type": "material_handed_over",
			"actor_id": C, "subject_id": B, "recipient_ids": [C, B], "operation_id": command_id,
			"material": "iron", "quantity": 1, "donor_delta": -1, "recipient_delta": 1, "contractual": false,
			"donor_position": [donor_position.x, donor_position.y, donor_position.z],
			"recipient_position": [recipient_position.x, recipient_position.y, recipient_position.z]})
		world._state.godot.capabilities.commands[command_id] = {"capability_id": "inventory.give_material", "version": 1,
			"payload": {"actor_id": C, "option_id": "ability:give_material:old-%02d" % index, "provenance": "fixture", "speech": ""},
			"created_elapsed": 0.0, "status": "completed", "event_seq": sequence,
			"result": {"ok": true, "code": "material_handed_over", "event_id": event_id,
				"actor_id": C, "recipient_id": B, "material": "iron", "quantity": 1}}
	var overflow: Dictionary = world.background_gm_snapshot()
	var overflow_gifts := _entries(overflow, "material_handoff_completed")
	check(overflow.get("counts", {}).get("issues", 65) <= 64 and _entries(overflow, "basic_life_resources_unavailable").size() == 1,
		"current resource failure survives a historical evidence overflow")
	check(overflow_gifts.any(func(entry): return entry.get("command_id", "") == "gm:old-gift-69")
		and not overflow_gifts.any(func(entry): return entry.get("command_id", "") == "gm:old-gift-00"),
		"newest historical handoffs are retained while the oldest falls outside the bound")
	var overflow_sequences: Array = overflow_gifts.map(func(entry): return int(entry.get("event_seq", 0)))
	var sorted_overflow := overflow_sequences.duplicate()
	sorted_overflow.sort()
	check(overflow_sequences == sorted_overflow, "retained historical terminal facts remain chronological")
	world._state = saved_state

	# Altering the terminal event or receipt breaks the command/event cross-check and removes the
	# forged item from the projection. Restore the in-memory fixture after each probe.
	saved_state = world._state.duplicate(true)
	var terminal_event: Dictionary = world._state.life.events[-2]
	terminal_event.text = SECRET
	terminal_event.consumed = 0
	check(_entries(world.background_gm_snapshot(), "self_repair_completed").is_empty(), "tampered self-repair event is not projected")
	world._state = saved_state.duplicate(true)
	var handoff_event: Dictionary = world._state.life.events[-1]
	handoff_event.subject_id = A
	check(_entries(world.background_gm_snapshot(), "material_handoff_completed").is_empty(), "tampered handoff identity is not projected")
	world._state = saved_state.duplicate(true)
	world._state.godot.commands["gm:basic-failure"].result.code = "made_up_success"
	check(_entries(world.background_gm_snapshot(), "basic_life_resources_unavailable").is_empty(), "tampered basic terminal receipt is not projected")
	world._state = saved_state
	world._state.godot.resident_turns[A].history[-1].action = "life:rest"
	check(_entries(world.background_gm_snapshot(), "basic_life_resources_unavailable").is_empty(), "mismatched accepted basic action is not projected")
	world._state = saved_state
	_close_stage(stage)

	stage = _repair_stage("gm-audited-failure")
	world = stage.world
	_do(stage, A, SELF, "gm:self-failure")
	world._trade_account(A).wood = 0
	world.host_move(A, world.destination(A, "self_repair"))
	world.advance(60.0)
	check(world.action_receipt("gm:self-failure").result.code == "self_repair_unavailable", "fixture creates an authoritative self-repair failure")
	var failed_snapshot: Dictionary = world.background_gm_snapshot()
	var failed_repairs := _entries(failed_snapshot, "self_repair_failed")
	check(failed_repairs.size() == 1 and failed_repairs[0].get("result_code") == "self_repair_unavailable"
		and failed_repairs[0].get("physical_facts", {}).get("consumed") == 0,
		"self-repair failure exposes only the recorded terminal code and zero consumption")
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_gm_audited_evidence", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
