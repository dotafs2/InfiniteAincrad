extends RefCounted
const Registry = preload("res://core/actions/capability_registry.gd")

func definitions() -> Array:
	return [Registry.spec("social.talk", "social", "immediate", ["speaker_turn", "current_hearing_range"], "required",
		["both_residents_active", "recipient_in_hearing_range", "speaker_available"], ["attributed_utterance_only", "no_contract_or_shared_belief"]),
		Registry.spec("perception.observe_surroundings", "social", "immediate", ["observer_attention"], "forbidden",
		["observer_available"], ["private_snapshot_of_existing_personal_sensors", "no_new_hidden_knowledge"])]

func options(world, id: String) -> Array:
	if world._busy(id): return []
	var result: Array = []
	# Rate controls are world-time based and survive restart. Neither consumes a paid retry.
	if world.capability_ready(id, "perception.observe_surroundings", 30.0):
		result.append({"id": "ability:observe", "action": "observe_surroundings", "capability_id": "perception.observe_surroundings",
			"label": "Observe my surroundings privately; no skill gain.", "speech_allowed": false})
	if world.capability_ready(id, "social.talk", 10.0):
		for other in world.active_ids():
			if other != id and world.position_of(id).distance_to(world.position_of(other)) <= world.HEARING_RANGE:
				result.append({"id": "ability:talk:" + other, "action": "talk", "capability_id": "social.talk", "counterparty": other,
					"presentation": {"template": "Talk to {0} (speech required; no contract).", "arguments": [world.resident_name(other)]},
					"label": "Talk to %s (speech required; no contract)." % world.resident_name(other), "speech_allowed": true})
	return result

func execute(world, id: String, option: Dictionary, command: String, provenance: String, speech: String) -> Dictionary:
	if option.capability_id == "social.talk":
		if speech.strip_edges().is_empty(): return {"ok": false, "code": "speech_required"}
		var other: String = option.counterparty
		var event: Dictionary = world.capability_event("resident_said", id, [id, other], command, provenance, speech)
		event["subject_id"] = other
		event["epistemic_status"] = "speaker_statement_not_verified_world_fact"
		world._append_life_event(event)
		return {"ok": true, "code": "resident_said", "event_id": event.event_id}
	var view: Dictionary = world.resident_view(id)
	var snapshot := {"position": world._state.godot.positions[id].duplicate(),
		"needs": view.get("needs", {}).duplicate(true), "nearby_residents": view.get("nearby_residents", []).duplicate(true),
		"known_places": world.known_place_ids(id).duplicate()}
	# Do not copy other residents' dossiers, inventory, knowledge, or hidden jobs.
	var event: Dictionary = world.capability_event("surroundings_observed", id, [id], command, provenance, "I paused to observe my current surroundings.")
	event["observed"] = snapshot
	event["private_observation"] = true
	world._append_life_event(event)
	return {"ok": true, "code": "surroundings_observed", "event_id": event.event_id,
		"speech_delivery": {"attempted": false, "delivered": false, "code": "private_observation"}}

func validate_command(world, value: Dictionary, _command: String, row: Dictionary, event: Dictionary) -> Dictionary:
	var payload: Dictionary = row.payload
	if row.status != "completed" or row.result.get("event_id") != event.event_id:
		return world._failure("invalid_social_receipt")
	if row.result.get("code") != event.get("type"): return world._failure("invalid_social_receipt")
	if row.capability_id == "social.talk":
		var other: String = str(event.get("subject_id", ""))
		if other == payload.actor_id or not value.godot.positions.has(other) or payload.option_id != "ability:talk:" + other:
			return world._failure("invalid_speech_recipient")
		if event.get("type") != "resident_said" or event.get("text") != payload.speech or payload.speech.strip_edges().is_empty() or event.get("recipient_ids") != [payload.actor_id, other] or event.get("epistemic_status") != "speaker_statement_not_verified_world_fact":
			return world._failure("capability_speech_mismatch")
	elif row.capability_id == "perception.observe_surroundings":
		if payload.option_id != "ability:observe" or payload.speech != "" or event.get("type") != "surroundings_observed" or event.get("recipient_ids") != [payload.actor_id] or event.get("private_observation") != true:
			return world._failure("capability_observation_mismatch")
		var observed: Variant = event.get("observed")
		if not observed is Dictionary or not world._exact_keys(observed, ["position", "needs", "nearby_residents", "known_places"]):
			return world._failure("invalid_observation_snapshot")
		if not observed.nearby_residents is Array or not observed.known_places is Array or not observed.needs is Dictionary or not observed.position is Array or observed.position.size() != 3:
			return world._failure("invalid_observation_snapshot")
		for person in observed.nearby_residents:
			if not person is Dictionary or not world._exact_keys(person, ["id", "name"]) or not person.id is String or not person.name is String:
				return world._failure("invalid_observation_snapshot")
	return {"ok": true}

func validate_state(world, value: Dictionary) -> Dictionary:
	for event in value.life.events:
		if event.get("type") not in ["resident_said", "surroundings_observed"]: continue
		var command: Dictionary = value.godot.capabilities.commands.get(event.get("operation_id"), {})
		if command.get("event_seq") != event.seq or command.get("capability_id") not in ["social.talk", "perception.observe_surroundings"]:
			return world._failure("orphan_social_event")
	return {"ok": true}
