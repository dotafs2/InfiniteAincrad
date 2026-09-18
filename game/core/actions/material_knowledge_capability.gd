extends RefCounted
## Sharing is an explicit attributed utterance; it never shares stock or possessions.
const Registry = preload("res://core/actions/capability_registry.gd")
const ID := "knowledge.share_material_location"
const EVENT := "material_location_shared"
const PREFIX := "ability:share_material:"

func definitions() -> Array:
	return [Registry.spec(ID, "material_knowledge", "immediate", ["speaker_turn", "personal_source_evidence", "current_hearing_range"],
		"forbidden", ["speaker_available", "recipient_active_and_in_hearing_range", "source_known_to_speaker"],
		["attributed_route_statement", "recipient_location_knowledge_stock_unknown", "no_material_or_contract_transfer"])]

func option_id(source: String, recipient: String) -> String:
	return PREFIX + (source + "\n" + recipient).sha256_text().substr(0, 32)

func _already_told(world, id: String, source: String, recipient: String) -> bool:
	# Only the speaker's own prior disclosures prune the menu. Another person's
	# private knowledge must not silently reveal itself through offered choices.
	for row in world.capability_store().get("commands", {}).values():
		if row.capability_id == ID and row.payload.actor_id == id and row.payload.option_id == option_id(source, recipient): return true
	return false

func options(world, id: String) -> Array:
	if world._busy(id) or not world.capability_ready(id, ID, 10.0): return []
	var result: Array = []
	for source_id in world._known_materials(id):
		var source: Dictionary = world._materials().sources[source_id]
		for other in world.active_ids():
			if other == id or world.position_of(id).distance_to(world.position_of(other)) > world.HEARING_RANGE or _already_told(world, id, source_id, other): continue
			var template := "Tell {0} the route to {1}; current stock unverified, no goods transferred."
			var arguments := [world.resident_name(other), source.label]
			result.append({"id": option_id(source_id, other), "action": "share_material_location", "capability_id": ID,
				"counterparty": other, "source_id": source_id, "speech_allowed": false,
				"label": template.format(arguments), "presentation": {"template": template, "arguments": arguments}})
	return result

func execute(world, id: String, option: Dictionary, command: String, provenance: String, _speech: String) -> Dictionary:
	var source: Dictionary = world._materials().sources[option.source_id]
	var target: String = option.counterparty
	var known: Dictionary = world._known_materials(id)[option.source_id]
	var evidence: Dictionary = world._material_knowledge_event(world._state, id, option.source_id, known.event_seq)
	if evidence.is_empty(): return world._failure("material_knowledge_evidence_missing")
	var text: String = "I can tell you this route: " + world._material_notice_text(source, world.position_of(id))
	var prior: Dictionary = world._known_materials(target).get(source.id, {})
	var event: Dictionary = world.capability_event(EVENT, id, [id, target], command, provenance, text)
	event.subject_id = target
	event.merge({"source_id": source.id, "source_event_seq": known.event_seq, "stock": null,
		"speaker_position": world._state.godot.positions[id].duplicate(), "recipient_position": world._state.godot.positions[target].duplicate()})
	world._append_life_event(event)
	var materials: Dictionary = world._ensure_materials()
	if prior.is_empty():
		if not materials.known.has(target): materials.known[target] = {}
		materials.known[target][source.id] = {"stock": null, "observed_elapsed": world._state.godot.elapsed_seconds, "event_seq": event.seq}
	return {"ok": true, "code": EVENT, "event_id": event.event_id,
		"speech_delivery": {"attempted": true, "delivered": true, "code": "speech_delivered", "text": text,
			"event_id": event.event_id, "event_seq": event.seq, "recipient_ids": [id, target]}}

func validate_command(world, value: Dictionary, _command: String, row: Dictionary, event: Dictionary) -> Dictionary:
	if not world._exact_keys(event, ["type", "actor_id", "subject_id", "recipient_ids", "operation_id", "source", "provenance", "text", "contractual", "source_id", "source_event_seq", "stock", "speaker_position", "recipient_position", "seq", "event_id"]):
		return world._failure("invalid_material_disclosure_event")
	var payload: Dictionary = row.payload
	if row.status != "completed" or row.result.get("code") != EVENT or row.result.get("event_id") != event.event_id or event.type != EVENT or event.source != payload.provenance or event.contractual != false or event.stock != null:
		return world._failure("invalid_material_disclosure_receipt")
	if not event.source_id is String or not value.godot.materials.sources.has(event.source_id) or not event.subject_id is String or not value.godot.positions.has(event.subject_id) or event.subject_id == payload.actor_id or event.recipient_ids != [payload.actor_id, event.subject_id] or payload.speech != "" or payload.option_id != option_id(event.source_id, event.subject_id):
		return world._failure("invalid_material_disclosure_recipient")
	var proof: Dictionary = world._material_knowledge_event(value, payload.actor_id, event.source_id, event.source_event_seq)
	if proof.is_empty() or proof.seq >= event.seq:
		return world._failure("invalid_material_disclosure_origin")
	if not world._exact_keys(row.result, ["ok", "code", "event_id", "speech_delivery"]): return world._failure("invalid_material_disclosure_result")
	if not world._valid_position(event.speaker_position) or not world._valid_position(event.recipient_position) or world._vector(event.speaker_position).distance_to(world._vector(event.recipient_position)) > world.HEARING_RANGE:
		return world._failure("invalid_material_disclosure_range")
	var source: Dictionary = value.godot.materials.sources[event.source_id]
	if event.text != "I can tell you this route: " + world._material_notice_text(source, world._vector(event.speaker_position)):
		return world._failure("invalid_material_disclosure_text")
	var expected := {"attempted": true, "delivered": true, "code": "speech_delivered", "text": event.text,
		"event_id": event.event_id, "event_seq": event.seq, "recipient_ids": event.recipient_ids}
	if row.result.get("speech_delivery") != expected:
		return world._failure("invalid_material_disclosure_speech")
	var known: Dictionary = value.godot.materials.known.get(event.subject_id, {}).get(event.source_id, {})
	var earliest: int = world._first_material_knowledge_seq(value, event.subject_id, event.source_id)
	if known.is_empty() or known.get("event_seq", -1) < earliest:
		return world._failure("material_disclosure_knowledge_missing")
	return {"ok": true}

func validate_state(world, value: Dictionary) -> Dictionary:
	for event in value.life.events:
		if event.get("type") != EVENT: continue
		var command: Dictionary = value.godot.capabilities.commands.get(event.get("operation_id"), {})
		if command.get("capability_id") != ID or command.get("event_seq") != event.seq:
			return world._failure("orphan_material_disclosure")
	return {"ok": true}
