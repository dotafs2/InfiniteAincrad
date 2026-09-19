extends RefCounted
## A resident may give one uncommitted repair material to a nearby resident.
## The existing life accounts remain the only material stock ledger.
const Registry = preload("res://core/actions/capability_registry.gd")
const English = preload("res://core/english_text.gd")
const ID := "inventory.give_material"
const EVENT := "material_handed_over"
const PREFIX := "ability:give_material:"
const MATERIALS := ["iron", "wood"]

func definitions() -> Array:
	return [Registry.spec(ID, "material_handoff", "immediate",
		["actor_owned_material", "uncommitted_repair_material", "current_handoff_range"],
		"forbidden", ["donor_available", "recipient_active_and_nearby", "exactly_one_iron_or_wood_available"],
		["transfer_one_existing_unit", "conserve_total_material", "gift_without_payment_contract_or_debt"])]

func option_id(material: String, recipient: String) -> String:
	return PREFIX + (material + "\n" + recipient).sha256_text().substr(0, 32)

func _resident_name(value: Dictionary, id: String) -> String:
	for resident in value.get("residents", []):
		if resident is Dictionary and resident.get("stable_id") == id:
			return English.text(str(resident.get("name", id)))
	return ""

func _available(world, id: String, recipient: String, material: String) -> bool:
	return material in MATERIALS and id in world.active_ids() and recipient in world.active_ids() \
		and id != recipient and not world._busy(id) \
		and not world._trade_account(id).is_empty() and not world._trade_account(recipient).is_empty() \
		and world.position_of(id).distance_to(world.position_of(recipient)) <= world.FOOD_HANDOFF_RANGE \
		and world._available_repair_material(id, material) >= 1

func options(world, id: String) -> Array:
	if id not in world.active_ids() or world._busy(id): return []
	var result: Array = []
	for material in MATERIALS:
		# Recipient inventory is deliberately not read. A donor sees the same choice
		# whether the other resident holds zero or many units.
		if world._available_repair_material(id, material) < 1: continue
		for recipient in world.active_ids():
			if not _available(world, id, recipient, material): continue
			var template := "Give 1 uncommitted {0} to {1} in person as a gift; no trade, payment or debt."
			var arguments := [material, world.resident_name(recipient)]
			result.append({"id": option_id(material, recipient), "action": "give_material", "capability_id": ID,
				"counterparty": recipient, "material": material, "quantity": 1, "speech_allowed": false,
				"label": template.format(arguments), "presentation": {"template": template, "arguments": arguments}})
	return result

func execute(world, id: String, option: Dictionary, command: String, provenance: String, _speech: String) -> Dictionary:
	var recipient: String = str(option.get("counterparty", ""))
	var material: String = str(option.get("material", ""))
	if not _available(world, id, recipient, material): return world._failure("option_unavailable")
	var donor_account: Dictionary = world._trade_account(id)
	var recipient_account: Dictionary = world._trade_account(recipient)
	donor_account[material] = int(donor_account[material]) - 1
	recipient_account[material] = int(recipient_account[material]) + 1
	var text := "%s gave 1 unit of %s to %s in person. This was a gift, not a trade; it created no payment or debt." % [world.resident_name(id), material, world.resident_name(recipient)]
	var event: Dictionary = world.capability_event(EVENT, id, [id, recipient], command, provenance, text)
	event.subject_id = recipient
	event.merge({"material": material, "quantity": 1, "donor_delta": -1, "recipient_delta": 1,
		"donor_position": world._state.godot.positions[id].duplicate(),
		"recipient_position": world._state.godot.positions[recipient].duplicate()})
	world._append_life_event(event)
	return {"ok": true, "code": EVENT, "event_id": event.event_id, "actor_id": id,
		"recipient_id": recipient, "material": material, "quantity": 1,
		"speech_delivery": {"attempted": false, "delivered": false, "code": "physical_handoff_not_speech"}}

func validate_command(world, value: Dictionary, command: String, row: Dictionary, event: Dictionary) -> Dictionary:
	var event_keys := ["type", "actor_id", "subject_id", "recipient_ids", "operation_id", "source", "provenance", "text", "contractual",
		"material", "quantity", "donor_delta", "recipient_delta", "donor_position", "recipient_position", "seq", "event_id"]
	if not world._exact_keys(event, event_keys): return world._failure("invalid_material_handoff_event")
	var result_keys := ["ok", "code", "event_id", "actor_id", "recipient_id", "material", "quantity", "speech_delivery"]
	if not world._exact_keys(row.result, result_keys): return world._failure("invalid_material_handoff_result")
	var payload: Dictionary = row.payload
	var id: String = str(payload.get("actor_id", ""))
	var recipient: String = str(event.get("subject_id", ""))
	var material: String = str(event.get("material", ""))
	if row.status != "completed" or row.result.get("ok") != true or row.result.get("code") != EVENT or row.result.get("event_id") != event.get("event_id"):
		return world._failure("invalid_material_handoff_receipt")
	if event.get("type") != EVENT or event.get("operation_id") != command or event.get("actor_id") != id or event.get("recipient_ids") != [id, recipient] or recipient == id or not value.godot.positions.has(recipient):
		return world._failure("invalid_material_handoff_identity")
	if material not in MATERIALS or payload.get("option_id") != option_id(material, recipient) or payload.get("speech") != "":
		return world._failure("invalid_material_handoff_payload")
	if event.get("quantity") != 1 or event.get("donor_delta") != -1 or event.get("recipient_delta") != 1 or int(event.donor_delta) + int(event.recipient_delta) != 0:
		return world._failure("material_handoff_conservation_failed")
	if event.get("source") != payload.get("provenance") or event.get("provenance") != payload.get("provenance") or event.get("contractual") != false:
		return world._failure("invalid_material_handoff_provenance")
	if not world._valid_position(event.get("donor_position")) or not world._valid_position(event.get("recipient_position")) or world._vector(event.donor_position).distance_to(world._vector(event.recipient_position)) > world.FOOD_HANDOFF_RANGE:
		return world._failure("invalid_material_handoff_range")
	var donor_name := _resident_name(value, id)
	var recipient_name := _resident_name(value, recipient)
	if donor_name.is_empty() or recipient_name.is_empty(): return world._failure("invalid_material_handoff_identity")
	var expected_text := "%s gave 1 unit of %s to %s in person. This was a gift, not a trade; it created no payment or debt." % [donor_name, material, recipient_name]
	if event.get("text") != expected_text: return world._failure("invalid_material_handoff_text")
	if row.result.get("actor_id") != id or row.result.get("recipient_id") != recipient or row.result.get("material") != material or row.result.get("quantity") != 1:
		return world._failure("invalid_material_handoff_result")
	if row.result.get("speech_delivery") != {"attempted": false, "delivered": false, "code": "physical_handoff_not_speech"}:
		return world._failure("invalid_material_handoff_speech")
	return {"ok": true}

func validate_state(world, value: Dictionary) -> Dictionary:
	for event in value.life.events:
		if event.get("type") != EVENT: continue
		var command: Dictionary = value.godot.capabilities.commands.get(event.get("operation_id"), {})
		if command.get("capability_id") != ID or command.get("event_seq") != event.get("seq"):
			return world._failure("orphan_material_handoff")
	return {"ok": true}
