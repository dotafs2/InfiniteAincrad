extends "res://core/world_kernel.gd"
## Continuation module: reuse the existing single-writer/atomic JSON persistence.
## Source residents/history stay intact; only this module owns new life effects.

const DURATIONS := {"eat_ration": 30.0, "rest": 60.0, "harvest_ration": 20.0}
const SOCIAL_ACTIONS := ["ask_help", "reply_help", "cancel_help"]
const HEARING_RANGE := 3.0
const JsonCodec = preload("res://core/TownJsonCodec.cs")
var _visitor_position := Vector3.INF

func _parse_json_text(text: String) -> Variant:
	var codec = JsonCodec.new()
	return codec.Decode(text)

func _serialize_state() -> String:
	var codec = JsonCodec.new()
	return codec.Encode(_state)

func _init() -> void:
	_state = {}

func load_from(path: String) -> Dictionary:
	var result := super.load_from(path)
	if result.ok:
		result.world_id = _state.world_id
		result.state_version = "legacy-2/godot-1"
	return result

func active_ids() -> Array:
	# JSON serialization may sort dictionary keys; identity/order comes from the source roster.
	var result: Array = []
	for person in _state.residents:
		if _state.godot.positions.has(person.stable_id):
			result.append(person.stable_id)
	return result

func resident(id: String) -> Dictionary:
	for value in _state.residents:
		if value.stable_id == id:
			return value
	return {}

func account(id: String) -> Dictionary:
	for value in _state.survival.accounts:
		if value.resident_id == id:
			return value
	return {}

func resident_view(resident_id: String = "") -> Dictionary:
	if not active_ids().has(resident_id):
		return {}
	var person := resident(resident_id)
	var own_events: Array = []
	for event in _state.life.events:
		if event.get("recipient_ids", []).has(resident_id):
			own_events.append(event.duplicate(true))
	return {"identity": {"id": resident_id, "name": person.name, "role": person.role},
		"needs": person.needs.duplicate(true), "inventory": account(resident_id).duplicate(true),
		"experiences": own_events, "observations": _state.godot.observations[resident_id].duplicate(true),
		"available_actions": available(resident_id), "pending": _state.godot.pending.get(resident_id, {}).duplicate(true),
		"nearby_residents": nearby(resident_id)}

func nearby(id: String) -> Array:
	var result: Array = []
	for other in active_ids():
		if other != id and position_of(id).distance_to(position_of(other)) <= HEARING_RANGE:
			result.append({"id": other, "name": resident(other).name})
	return result

func host_visitor_position(value: Vector3) -> void:
	_visitor_position = value

func visitor_inquiry(target: String, text: String, command_id: String, source: String = "human_player") -> Dictionary:
	# A human visitor has no granted inventory/wallet and is not an extra resident.
	if target not in active_ids() or not _validate_decision_command_id(command_id).ok or text.strip_edges().is_empty() or text.length() > MAX_REASON_LENGTH or source not in ["human_player", "scripted_player_fixture"]:
		return _failure("invalid_visitor_inquiry")
	var payload := {"actor_id": "visitor:local", "action": "visitor_inquiry", "recipient_id": target, "text": text, "provenance": source}
	if _state.godot.commands.has(command_id):
		var same: bool = _state.godot.commands[command_id].payload == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if not _visitor_position.is_finite() or _visitor_position.distance_to(position_of(target)) > HEARING_RANGE:
		return _failure("recipient_out_of_range")
	var event := {"type": "visitor_inquiry", "actor_id": "visitor:local", "subject_id": target,
		"recipient_ids": ["visitor:local", target], "operation_id": command_id, "source": source,
		"text": text, "request_id": "visitor_inquiry:" + command_id, "contractual": false}
	_append_life_event(event)
	_state.godot.commands[command_id] = {"payload": payload, "status": "completed"}
	return {"ok": true, "code": "visitor_inquiry", "request_id": event.request_id}

func reply_to_visitor(id: String, request_id: String, choice: String, text: String, command_id: String, provenance: String = "local_rule_policy") -> Dictionary:
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE or choice not in ["willing", "unavailable", "unsure"] or text.strip_edges().is_empty() or text.length() > MAX_REASON_LENGTH:
		return _failure("invalid_visitor_reply")
	var payload := {"actor_id": id, "action": "visitor_reply", "request_id": request_id, "choice": choice, "text": text, "provenance": provenance}
	if _state.godot.commands.has(command_id):
		var same: bool = _state.godot.commands[command_id].payload == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if not _visitor_position.is_finite() or _visitor_position.distance_to(position_of(id)) > HEARING_RANGE:
		return _failure("recipient_out_of_range")
	var found := false
	for event in _state.life.events:
		if event.get("request_id") == request_id:
			if event.type == "visitor_reply":
				return _failure("request_already_closed")
			if event.type == "visitor_inquiry" and event.subject_id == id:
				found = true
	if not found:
		return _failure("unknown_request")
	var event := {"type": "visitor_reply", "actor_id": id, "subject_id": "visitor:local",
		"recipient_ids": [id, "visitor:local"], "operation_id": command_id, "source": provenance,
		"text": text, "reply_choice": choice, "request_id": request_id, "contractual": false}
	_append_life_event(event)
	_state.godot.commands[command_id] = {"payload": payload, "status": "completed"}
	return {"ok": true, "code": "visitor_reply", "text": text, "choice": choice}

func has_open_help_request(sender: String, recipient: String, need: Dictionary = {}) -> bool:
	var open_requests: Dictionary = {}
	for event in _state.life.events:
		if event.get("type") == "ask_help" and event.get("actor_id") == sender and event.get("subject_id") == recipient and event.get("need", {}) == need:
			open_requests[str(event.get("request_id", ""))] = true
		elif event.get("type") in ["reply_help", "cancel_help"]:
			open_requests.erase(str(event.get("request_id", "")))
	return not open_requests.is_empty()

func _validate_communicate_need(_sender_id: String, _need: Variant) -> Dictionary:
	return _failure("unsupported_need")

func communicate(id: String, decision: Dictionary, command_id: String, provenance: String = "local_rule_policy") -> Dictionary:
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	var action = decision.get("action")
	if action not in SOCIAL_ACTIONS:
		return _failure("invalid_social_action")
	var keys: Array = ["action", "recipient_id", "text"]
	if action != "ask_help":
		keys.append("request_id")
	elif decision.has("need"):
		keys.append("need")
	if action == "reply_help":
		keys.append("choice")
	if not _exact_keys(decision, keys) or not decision.get("recipient_id") is String or not decision.get("text") is String or decision.text.strip_edges().is_empty() or decision.text.length() > MAX_REASON_LENGTH:
		return _failure("invalid_message")
	var target: String = decision.recipient_id
	if target == id or target not in active_ids():
		return _failure("invalid_recipient")
	var payload := {"actor_id": id, "action": action, "provenance": provenance, "decision": decision.duplicate(true)}
	if _state.godot.commands.has(command_id):
		var matches: bool = _state.godot.commands[command_id].payload == payload
		return {"ok": matches, "duplicate": matches, "code": "duplicate" if matches else "command_conflict"}
	if decision.has("need"):
		var checked := _validate_communicate_need(id, decision.need)
		if not checked.ok:
			return checked
	if position_of(id).distance_to(position_of(target)) > HEARING_RANGE:
		return _failure("recipient_out_of_range")
	if action == "ask_help" and has_open_help_request(id, target, decision.get("need", {})):
		return _failure("help_request_pending")
	var request_id := "godot_help:" + command_id
	if action != "ask_help":
		if not decision.get("request_id") is String:
			return _failure("invalid_request_id")
		request_id = decision.request_id
		var request: Dictionary = {}
		for event in _state.life.events:
			if event.get("request_id") == request_id:
				if event.type in ["reply_help", "cancel_help"]:
					return _failure("request_already_closed")
				if event.type == "ask_help":
					request = event
		if request.is_empty():
			return _failure("unknown_request")
		if action == "reply_help":
			if request.subject_id != id or request.actor_id != target or decision.choice not in ["willing", "unavailable", "unsure"]:
				return _failure("invalid_reply")
		elif request.actor_id != id or request.subject_id != target:
			return _failure("invalid_cancellation")
	var event := {"type": action, "actor_id": id, "subject_id": target, "recipient_ids": [id, target],
		"operation_id": command_id, "source": provenance, "text": decision.text,
		"request_id": request_id, "topic": "help_availability", "contractual": false}
	if action == "ask_help" and decision.has("need"):
		event.need = decision.need.duplicate(true)
	if action == "reply_help":
		event.reply_choice = decision.choice
	_append_life_event(event)
	_state.godot.commands[command_id] = {"payload": payload, "status": "completed"}
	return {"ok": true, "code": action, "request_id": request_id, "event_id": event.event_id}

func _append_life_event(event: Dictionary) -> void:
	_state.life.seq += 1
	event.seq = _state.life.seq
	event.event_id = "life_event_%d" % _state.life.seq
	_state.life.events.append(event)
	_state.godot.new_events.append(event.event_id)

func position_of(id: String) -> Vector3:
	return _vector(_state.godot.positions[id])

func pending_job(id: String) -> Dictionary:
	return _state.godot.pending.get(id, {}).duplicate(true)

func command_count() -> int:
	return _state.godot.commands.size()

func destination(id: String, action: String) -> Vector3:
	return _vector(_state.godot.berry_position if action == "harvest_ration" else _state.godot.homes[id])

func host_move(id: String, position_value: Vector3) -> void:
	# Host scene passes the collision-resolved body position; never exposed to a model.
	if active_ids().has(id) and position_value.is_finite():
		_state.godot.positions[id] = [position_value.x, position_value.y, position_value.z]

func available(id: String) -> Array:
	var result: Array = ["wait"]
	if not active_ids().has(id) or _state.godot.pending.has(id):
		return result
	var a := account(id)
	if a.food >= 1 and resident(id).needs.hunger <= 80:
		result.append("eat_ration")
	if a.energy <= 70:
		result.append("rest")
	# The public source's rules are known; current stock is checked on arrival.
	if a.food < 2:
		result.append("harvest_ration")
	return result

func choose_local(id: String) -> String:
	var options := available(id)
	for action in ["eat_ration", "rest", "harvest_ration"]:
		if action in options:
			if action == "harvest_ration":
				var observations: Array = _state.godot.observations[id]
				if not observations.is_empty():
					var last: Dictionary = observations[-1]
					if last.get("stock", -1) == 0 and _state.godot.elapsed_seconds - last.get("elapsed", 0) < 1800:
						continue
			return action
	return "wait"

func start_action(id: String, action: String, command_id: String, provenance: String = "local_rule_policy") -> Dictionary:
	if not active_ids().has(id) or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	var payload := {"actor_id": id, "action": action, "provenance": provenance}
	if _state.godot.commands.has(command_id):
		var prior: Dictionary = _state.godot.commands[command_id]
		return {"ok": prior.payload == payload, "duplicate": prior.payload == payload, "code": "duplicate" if prior.payload == payload else "command_conflict"}
	if action not in available(id) or action == "wait":
		return _failure("action_unavailable")
	_state.godot.commands[command_id] = {"payload": payload, "status": "pending"}
	_state.godot.pending[id] = {"action": action, "command_id": command_id, "elapsed": 0.0, "provenance": provenance}
	return {"ok": true, "code": "action_started"}

func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or delta > 120.0:
		return _failure("invalid_delta")
	_state.godot.elapsed_seconds += delta
	_state.elapsed_seconds += delta
	var survival: Dictionary = _state.survival
	var total: float = survival.tick_remainder_seconds + delta
	var steps := floori(total / 120.0)
	survival.tick_remainder_seconds = fmod(total, 120.0)
	for id in active_ids():
		account(id).energy = maxf(0.0, account(id).energy - steps)
		resident(id).needs.hunger = maxf(0.0, resident(id).needs.hunger - steps)
	var berry: Dictionary = _state.foraging
	var growth: float = berry.growth_remainder_seconds + delta
	var count := mini(int(berry.capacity - berry.stock), floori(growth / 1800.0))
	berry.stock += count
	berry.produced_total += count
	berry.growth_remainder_seconds = 0.0 if berry.stock >= berry.capacity else fmod(growth, 1800.0)
	var completed: Array = []
	for id in _state.godot.pending.keys():
		var pending: Dictionary = _state.godot.pending[id]
		if position_of(id).distance_to(destination(id, pending.action)) > 0.45:
			continue
		pending.elapsed += delta
		if pending.elapsed >= DURATIONS[pending.action]:
			completed.append(_finish(id, pending))
	return {"ok": true, "completed": completed}

func _finish(id: String, pending: Dictionary) -> Dictionary:
	var a := account(id)
	var needs: Dictionary = resident(id).needs
	var action: String = pending.action
	var valid := true
	match action:
		"eat_ration":
			valid = a.food >= 1 and needs.hunger <= 80
			if valid:
				a.food -= 1
				needs.hunger = minf(100.0, needs.hunger + 40)
		"rest":
			valid = a.energy <= 70
			if valid:
				a.energy = minf(100.0, a.energy + 35)
		"harvest_ration":
			valid = a.food < 2 and _state.foraging.stock >= 1
			_state.godot.observations[id].append({"source": "host_arrival", "stock": _state.foraging.stock, "elapsed": _state.godot.elapsed_seconds})
			if valid:
				a.food += 1
				_state.foraging.stock -= 1
				_state.foraging.harvested_total += 1
	var receipt := {"ok": valid, "code": action if valid else "resources_unavailable", "actor_id": id, "command_id": pending.command_id}
	_state.godot.commands[pending.command_id].status = "completed" if valid else "rejected"
	_state.godot.commands[pending.command_id].result = receipt.duplicate(true)
	_state.godot.pending.erase(id)
	if valid:
		_state.life.seq += 1
		var event := {"event_id": "life_event_%d" % _state.life.seq, "seq": _state.life.seq,
			"type": action, "actor_id": id, "subject_id": id, "recipient_ids": [id],
			"operation_id": pending.command_id, "source": pending.provenance,
			"text": "%s: %s (Godot continuation, %s)" % [resident(id).name, action, pending.provenance]}
		_state.life.events.append(event)
		_state.godot.new_events.append(event.event_id)
	return receipt

func transaction(path: String, operation: Callable) -> Dictionary:
	# Acquire before touching state; roll back in-memory consequences on save failure.
	var locked := acquire_writer(path)
	if not locked.ok:
		return locked
	var before := _state.duplicate(true)
	var result: Dictionary = operation.call()
	if not result.get("ok", false):
		_state = before
		return result
	var valid := _validate_state(_state)
	if not valid.ok:
		_state = before
		return valid
	var saved := save_to(path)
	if not saved.ok:
		_state = before
		return saved
	return result

func _validate_state(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema_version") != 2:
		return _failure("unsupported_town_schema")
	for key in ["residents", "life", "survival", "foraging", "godot", "elapsed_seconds", "world_id"]:
		if not value.has(key):
			return _failure("missing_" + key)
	if not value.residents is Array or not value.life is Dictionary or not value.survival is Dictionary or not value.foraging is Dictionary or not value.godot is Dictionary:
		return _failure("invalid_town_objects")
	var g: Dictionary = value.godot
	if g.get("schema_version") != 1 or g.get("mode") != "migration_validation":
		return _failure("unsupported_continuation")
	for key in ["positions", "homes", "pending", "commands", "observations"]:
		if not g.get(key) is Dictionary:
			return _failure("invalid_" + key)
	if not g.get("new_events") is Array or not _valid_nonnegative(g.get("elapsed_seconds")):
		return _failure("invalid_continuation_history")
	if not value.life.get("events") is Array or not value.survival.get("accounts") is Array:
		return _failure("invalid_history_or_accounts")
	var ids: Array = []
	for r in value.residents:
		if not r is Dictionary or not r.get("stable_id") is String or r.stable_id in ids or not r.get("needs") is Dictionary or not _bounded(r.needs.get("hunger"), 100):
			return _failure("invalid_resident")
		if not r.get("name") is String or not r.get("role") is String or not _bounded(r.get("coins_col"), 1000000000):
			return _failure("invalid_identity_or_wallet")
		ids.append(r.stable_id)
	var active: Array = []
	for a in value.survival.accounts:
		if not a is Dictionary or a.get("resident_id") not in ids or a.resident_id in active or not _bounded(a.get("food"), 2) or not _bounded(a.get("energy"), 100):
			return _failure("invalid_survival_account")
		active.append(a.resident_id)
	if active.is_empty() or g.positions.size() != active.size():
		return _failure("invalid_active_set")
	for id in active:
		if not _valid_position(g.positions.get(id)) or not _valid_position(g.homes.get(id)) or not g.observations.get(id) is Array:
			return _failure("invalid_placement")
	if not _valid_position(g.get("berry_position")):
		return _failure("invalid_berry_position")
	for id in g.pending:
		var job = g.pending[id]
		if id not in active or not job is Dictionary or job.get("action") not in DURATIONS or not _valid_nonnegative(job.get("elapsed")) or not g.commands.has(job.get("command_id")) or job.get("provenance") not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_pending")
	for command_id in g.commands:
		var command = g.commands[command_id]
		if not command_id is String or not _validate_decision_command_id(command_id).ok or not command is Dictionary or command.get("status") not in ["pending", "completed", "rejected"] or not command.get("payload") is Dictionary:
			return _failure("invalid_command")
		var payload: Dictionary = command.payload
		if payload.get("action") in ["visitor_inquiry", "visitor_reply"]:
			if command.status != "completed" or not payload.get("text") is String:
				return _failure("invalid_visitor_command")
			if payload.action == "visitor_inquiry":
				if payload.get("actor_id") != "visitor:local" or payload.get("recipient_id") not in active or payload.get("provenance") not in ["human_player", "scripted_player_fixture"]:
					return _failure("invalid_visitor_identity")
			elif payload.get("actor_id") not in active or payload.get("provenance") not in ALLOWED_DECISION_PROVENANCE or payload.get("choice") not in ["willing", "unavailable", "unsure"]:
				return _failure("invalid_visitor_reply_command")
			continue
		if payload.get("actor_id") not in active or (payload.get("action") not in DURATIONS and payload.get("action") not in SOCIAL_ACTIONS) or payload.get("provenance") not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_command_payload")
		if payload.action in SOCIAL_ACTIONS and (command.status != "completed" or not payload.get("decision") is Dictionary):
			return _failure("invalid_social_command")
		if command.status == "pending":
			var pending: Dictionary = g.pending.get(payload.actor_id, {})
			if pending.get("command_id") != command_id or pending.get("action") != payload.action or pending.get("provenance") != payload.provenance:
				return _failure("orphan_pending_command")
	for id in g.pending:
		if g.commands[g.pending[id].command_id].status != "pending":
			return _failure("completed_command_still_pending")
	var berry: Dictionary = value.foraging
	for key in ["stock", "capacity", "initial_stock", "produced_total", "harvested_total"]:
		if not _bounded(berry.get(key), 1000000000):
			return _failure("invalid_berry_count")
	if berry.stock > berry.capacity or berry.stock != berry.initial_stock + berry.produced_total - berry.harvested_total:
		return _failure("berry_conservation_failed")
	if not _bounded(value.survival.get("tick_remainder_seconds"), 120, false) or not _bounded(berry.get("growth_remainder_seconds"), 1800, false):
		return _failure("invalid_clock")
	var seq := 0
	for event in value.life.events:
		seq += 1
		if not event is Dictionary or event.get("seq") != seq:
			return _failure("nonconsecutive_history")
	if value.life.get("seq") != seq:
		return _failure("missing_history")
	return {"ok": true, "code": "town_state_valid"}

func _bounded(value: Variant, maximum: float, integral: bool = true) -> bool:
	return _valid_nonnegative(value) and value <= maximum and (not integral or floor(value) == value)

func _valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number in value:
		if typeof(number) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(number) or absf(number) > 10000:
			return false
	return true

func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
