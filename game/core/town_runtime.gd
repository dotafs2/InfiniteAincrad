extends "res://core/town_materials.gd"
## Trusted host admission, not a public authentication endpoint.
## Joining creates no money, materials or food. Reconnecting never calls admission.

func admit_resident(person: Dictionary, maintainer: String, point: Vector3, command: String) -> Dictionary:
	if not _exact_keys(person, ["stable_id", "name", "role", "story"]) or not _validate_decision_command_id(command).ok:
		return _failure("invalid_admission")
	for key in person:
		if not person[key] is String or person[key].strip_edges().is_empty() or person[key].length() > (2048 if key == "story" else 64):
			return _failure("invalid_identity")
	if maintainer.is_empty() or maintainer.length() > 128 or not point.is_finite() or absf(point.x) > 64 or absf(point.z) > 64 or point.y < 0 or point.y > 2:
		return _failure("invalid_admission_location_or_maintainer")
	var payload := {"person": person.duplicate(true), "maintainer": maintainer, "position": [point.x, point.y, point.z]}
	var admissions: Dictionary = _state.godot.get("admissions", {})
	if admissions.has(command):
		var prior: Dictionary = admissions[command]
		# JSON can restore integral coordinates as int instead of float. Compare
		# the authoritative Vector3 value, not the Array's variant element types.
		var same: bool = prior.person == person and prior.maintainer == maintainer and _vector(prior.position) == point
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict", "actor_id": person.stable_id}
	if not resident(person.stable_id).is_empty():
		return _failure("identity_already_exists")
	if active_ids().size() >= 10:
		return _failure("resident_capacity")
	var id: String = person.stable_id
	var newcomer := person.duplicate(true)
	newcomer.needs = {"hunger": 60}
	newcomer.coins_col = 0
	_state.residents.append(newcomer)
	_state.survival.accounts.append({"resident_id": id, "food": 0, "energy": 50})
	if not _state.life.has("accounts"):
		_state.life.accounts = []
	_state.life.accounts.append({"resident_id": id, "wood": 0, "iron": 0, "kindling": 0, "reserved_col": 0})
	_state.godot.positions[id] = payload.position.duplicate()
	_state.godot.homes[id] = payload.position.duplicate()
	_state.godot.observations[id] = []
	if not _state.godot.has("maintainers"):
		_state.godot.maintainers = {}
	_state.godot.maintainers[id] = maintainer
	_state.godot.admissions = admissions
	admissions[command] = payload
	# Existing residents learn about the newcomer only through normal nearby views.
	_append_life_event({"type": "resident_joined", "actor_id": id, "recipient_ids": [id], "operation_id": command, "source": "host_admission"})
	return {"ok": true, "code": "resident_joined", "actor_id": id}

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok:
		return base
	for key in ["admissions", "maintainers", "resident_turns"]:
		if value.godot.has(key) and not value.godot[key] is Dictionary:
			return _failure("invalid_" + key)
	for id in value.godot.get("resident_turns", {}):
		var record = value.godot.resident_turns[id]
		if not value.godot.positions.has(id) or not record is Dictionary or not record.get("history", []) is Array or not record.get("reviews", []) is Array:
			return _failure("invalid_resident_turn")
		if record.get("status", "ready") not in ["ready", "pending", "settled", "provider_error", "rule_rejection", "disconnected", "reviewed"]:
			return _failure("invalid_controller_status")
		for key in ["controller_epoch", "request_number"]:
			if not _bounded(record.get(key, 0), 1000000000):
				return _failure("invalid_controller_counter")
	return base
