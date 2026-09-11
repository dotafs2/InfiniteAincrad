extends "res://core/world_kernel.gd"
## Continuation module: reuse the existing single-writer/atomic JSON persistence.
## Source residents/history stay intact; only this module owns new life effects.

const DURATIONS := {"eat_ration": 30.0, "rest": 60.0, "harvest_ration": 20.0,
	"repair_edge": 60.0, "repair_handle": 60.0}
const SOCIAL_ACTIONS := ["ask_help", "reply_help", "cancel_help"]
const REPAIR_COMMAND_ACTIONS := ["repair_propose", "repair_accept", "repair_reject",
	"repair_deliver", "repair_collect"]
const REPAIR_ACTIVE_STATUSES := ["proposed", "accepted", "delivered", "completed"]
const REPAIR_PRICES := [2, 5, 8]
const HEARING_RANGE := 3.0
const WORK_STATION_RANGE := 2.5
const HANDOFF_RANGE := 2.2
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
		"nearby_residents": nearby(resident_id), "work": work_view(resident_id)}

func work_view(id: String) -> Dictionary:
	if not active_ids().has(id) or not _has_repair_state():
		return {}
	var own_items: Array = []
	for value in _state.life.items:
		if value.get("owner_id") == id or value.get("custodian_id") == id:
			own_items.append(value.duplicate(true))
	var own_skills: Array = []
	for value in _state.life.skills:
		if value.get("resident_id") == id:
			own_skills.append(value.duplicate(true))
	var own_contracts: Array = []
	for value in _state.life.contracts:
		if value.get("owner_id") == id or value.get("worker_id") == id:
			own_contracts.append(value.duplicate(true))
	return {"materials": work_account(id).duplicate(true), "items": own_items,
		"skills": own_skills, "contracts": own_contracts}

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

func communicate(id: String, decision: Dictionary, command_id: String, provenance: String = "local_rule_policy") -> Dictionary:
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	var action = decision.get("action")
	if action not in SOCIAL_ACTIONS:
		return _failure("invalid_social_action")
	var keys: Array = ["action", "recipient_id", "text"]
	if action != "ask_help":
		keys.append("request_id")
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
	if position_of(id).distance_to(position_of(target)) > HEARING_RANGE:
		return _failure("recipient_out_of_range")
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
	if action == "reply_help":
		event.reply_choice = decision.choice
	_append_life_event(event)
	_state.godot.commands[command_id] = {"payload": payload, "status": "completed"}
	return {"ok": true, "code": action, "request_id": request_id, "event_id": event.event_id}

func work_account(id: String) -> Dictionary:
	if not _has_repair_state():
		return {}
	for value in _state.life.accounts:
		if value.get("resident_id") == id:
			return value
	return {}

func repair_contracts() -> Array:
	return _state.life.get("contracts", []).duplicate(true) if _has_repair_state() else []

func active_repair_for(id: String) -> Dictionary:
	if not _has_repair_state():
		return {}
	for value in _state.life.contracts:
		if str(value.get("id", "")).begins_with("godot_repair:") and value.get("status") in REPAIR_ACTIVE_STATUSES and (value.get("owner_id") == id or value.get("worker_id") == id):
			return value.duplicate(true)
	return {}

func repair_candidate(part: String = "edge") -> Dictionary:
	if not _has_repair_state() or not _repair_part(part).has("skill"):
		return {}
	var rule := _repair_part(part)
	for value in _state.life.items:
		var owner: String = value.get("owner_id", "")
		if value.get("kind") != "axe" or value.get(part, 100) >= 100 or value.get("custodian_id") != owner or owner not in active_ids() or not _active_contract_for_item(value.id).is_empty():
			continue
		for worker in active_ids():
			if worker != owner and _has_skill(worker, rule.skill) and work_account(worker).get(rule.material, 0) >= 1 and resident(owner).get("coins_col", 0) >= (2 if part == "edge" else 5):
				return {"owner_id": owner, "worker_id": worker, "item_id": value.id,
					"part": part, "price_col": 2 if part == "edge" else 5}
	return {}

func propose_repair(owner_id: String, item_id: String, worker_id: String, part: String,
		price_col: int, command_id: String, provenance: String = "local_rule_policy") -> Dictionary:
	var rule := _repair_part(part)
	if owner_id not in active_ids() or worker_id not in active_ids() or owner_id == worker_id or rule.is_empty() or price_col not in REPAIR_PRICES or not _valid_repair_caller(command_id, provenance) or ("godot_repair:" + command_id).length() > 128:
		return _failure("invalid_repair_proposal")
	var payload := {"actor_id": owner_id, "action": "repair_propose", "item_id": item_id,
		"worker_id": worker_id, "part": part, "price_col": price_col, "provenance": provenance}
	var prior := _prior_repair_command(command_id, payload)
	if not prior.is_empty():
		prior["contract_id"] = "godot_repair:" + command_id
		return prior
	var item := _find_repair_item(item_id)
	if item.is_empty() or item.get("owner_id") != owner_id or item.get("custodian_id") != owner_id or item.get(part, 100) >= 100 or not _has_skill(worker_id, rule.skill) or not _active_contract_for_item(item_id).is_empty():
		return _failure("repair_proposal_unavailable")
	var contract_id := "godot_repair:" + command_id
	if not _find_repair_contract(contract_id).is_empty():
		return _failure("repair_contract_conflict")
	var contract := {"id": contract_id, "part": part, "item_id": item_id,
		"owner_id": owner_id, "worker_id": worker_id, "price_col": price_col,
		"reserved_col": 0, "status": "proposed"}
	_state.life.contracts.append(contract)
	var event := {"type": "repair_" + part, "actor_id": owner_id, "subject_id": worker_id,
		"recipient_ids": [owner_id, worker_id], "operation_id": command_id, "source": provenance,
		"text": "%s向%s提出修%s委托，报价%d Col。" % [resident(owner_id).name, resident(worker_id).name, "刃" if part == "edge" else "柄", price_col],
		"contract_id": contract_id, "item_id": item_id, "part": part, "price_col": price_col}
	_append_life_event(event)
	_complete_repair_command(command_id, payload)
	return {"ok": true, "code": "repair_proposed", "contract_id": contract_id, "event_id": event.event_id}

func respond_repair(worker_id: String, contract_id: String, choice: String, command_id: String,
		provenance: String = "local_rule_policy") -> Dictionary:
	if worker_id not in active_ids() or choice not in ["accept", "reject"] or not _valid_repair_caller(command_id, provenance):
		return _failure("invalid_repair_response")
	var payload := {"actor_id": worker_id, "action": "repair_" + choice,
		"contract_id": contract_id, "provenance": provenance}
	var prior := _prior_repair_command(command_id, payload)
	if not prior.is_empty():
		return prior
	var contract := _find_repair_contract(contract_id)
	if contract.is_empty() or contract.get("worker_id") != worker_id or contract.get("status") != "proposed":
		return _failure("repair_response_unavailable")
	var owner_id: String = contract.owner_id
	var rule := _repair_part(contract.part)
	if choice == "accept":
		var materials := work_account(worker_id)
		var owner_materials := work_account(owner_id)
		var owner := resident(owner_id)
		if materials.is_empty() or owner_materials.is_empty() or not _has_skill(worker_id, rule.skill) or materials.get(rule.material, 0) < 1:
			return _failure("worker_missing_skill_or_material")
		if not _at_worker_station(worker_id, worker_id):
			return _failure("worker_not_at_station")
		if owner.get("coins_col", 0) < contract.price_col:
			return _failure("owner_balance_insufficient")
		owner.coins_col -= contract.price_col
		owner_materials.reserved_col += contract.price_col
		contract.reserved_col = contract.price_col
		contract.status = "accepted"
	else:
		contract.status = "rejected"
	var event := {"type": choice, "actor_id": worker_id, "subject_id": owner_id,
		"recipient_ids": [worker_id, owner_id], "operation_id": command_id, "source": provenance,
		"text": "%s%s了%s的修%s委托%s" % [resident(worker_id).name, "接受" if choice == "accept" else "拒绝", resident(owner_id).name,
			"刃" if contract.part == "edge" else "柄", "，已预留%d Col。" % contract.price_col if choice == "accept" else "。"],
		"contract_id": contract_id, "item_id": contract.item_id}
	_append_life_event(event)
	_complete_repair_command(command_id, payload)
	return {"ok": true, "code": "repair_" + choice, "contract_id": contract_id, "event_id": event.event_id}

func deliver_repair(owner_id: String, contract_id: String, command_id: String,
		provenance: String = "local_rule_policy") -> Dictionary:
	if owner_id not in active_ids() or not _valid_repair_caller(command_id, provenance):
		return _failure("invalid_repair_delivery")
	var payload := {"actor_id": owner_id, "action": "repair_deliver",
		"contract_id": contract_id, "provenance": provenance}
	var prior := _prior_repair_command(command_id, payload)
	if not prior.is_empty():
		return prior
	var contract := _find_repair_contract(contract_id)
	var item := _find_repair_item(contract.get("item_id", ""))
	if contract.is_empty() or item.is_empty() or contract.get("owner_id") != owner_id or contract.get("status") != "accepted" or item.get("custodian_id") != owner_id:
		return _failure("repair_delivery_unavailable")
	var worker_id: String = contract.worker_id
	if not _both_at_worker_station(owner_id, worker_id):
		return _failure("repair_delivery_out_of_range")
	item.custodian_id = worker_id
	contract.status = "delivered"
	var event := {"type": "deliver", "actor_id": owner_id, "subject_id": worker_id,
		"recipient_ids": [owner_id, worker_id], "operation_id": command_id, "source": provenance,
		"text": "%s已把柴斧交到%s的岗位，等待实际修理。" % [resident(owner_id).name, resident(worker_id).name],
		"contract_id": contract_id, "item_id": item.id}
	_append_life_event(event)
	_complete_repair_command(command_id, payload)
	return {"ok": true, "code": "repair_delivered", "contract_id": contract_id, "event_id": event.event_id}

func start_repair_work(worker_id: String, contract_id: String, command_id: String,
		provenance: String = "local_rule_policy") -> Dictionary:
	if worker_id not in active_ids() or not _valid_repair_caller(command_id, provenance):
		return _failure("invalid_repair_work")
	var contract := _find_repair_contract(contract_id)
	var rule := _repair_part(contract.get("part", ""))
	var action: String = "repair_" + str(contract.get("part", ""))
	var payload := {"actor_id": worker_id, "action": action,
		"contract_id": contract_id, "provenance": provenance}
	var prior := _prior_repair_command(command_id, payload)
	if not prior.is_empty():
		return prior
	var item := _find_repair_item(contract.get("item_id", ""))
	var materials := work_account(worker_id)
	if contract.is_empty() or item.is_empty() or rule.is_empty() or contract.get("worker_id") != worker_id or contract.get("status") != "delivered" or item.get("custodian_id") != worker_id or not _has_skill(worker_id, rule.skill) or materials.get(rule.material, 0) < 1 or _state.godot.pending.has(worker_id):
		return _failure("repair_work_unavailable")
	if not _at_worker_station(worker_id, worker_id):
		return _failure("worker_not_at_station")
	_state.godot.commands[command_id] = {"payload": payload, "status": "pending"}
	_state.godot.pending[worker_id] = {"action": action, "command_id": command_id,
		"contract_id": contract_id, "elapsed": 0.0, "provenance": provenance}
	return {"ok": true, "code": "repair_work_started", "contract_id": contract_id}

func collect_repair(owner_id: String, contract_id: String, command_id: String,
		provenance: String = "local_rule_policy") -> Dictionary:
	if owner_id not in active_ids() or not _valid_repair_caller(command_id, provenance):
		return _failure("invalid_repair_collection")
	var payload := {"actor_id": owner_id, "action": "repair_collect",
		"contract_id": contract_id, "provenance": provenance}
	var prior := _prior_repair_command(command_id, payload)
	if not prior.is_empty():
		return prior
	var contract := _find_repair_contract(contract_id)
	var item := _find_repair_item(contract.get("item_id", ""))
	if contract.is_empty() or item.is_empty() or contract.get("owner_id") != owner_id or contract.get("status") != "completed":
		return _failure("repair_collection_unavailable")
	var worker_id: String = contract.worker_id
	var owner_materials := work_account(owner_id)
	if item.get("custodian_id") != worker_id or owner_materials.get("reserved_col", -1) < contract.price_col or contract.get("reserved_col") != contract.price_col or not _both_at_worker_station(owner_id, worker_id):
		return _failure("repair_collection_out_of_range_or_unsettled")
	owner_materials.reserved_col -= contract.price_col
	resident(worker_id).coins_col += contract.price_col
	item.custodian_id = owner_id
	contract.reserved_col = 0
	contract.status = "collected"
	var event := {"type": "collect", "actor_id": owner_id, "subject_id": worker_id,
		"recipient_ids": [owner_id, worker_id], "operation_id": command_id, "source": provenance,
		"text": "%s取回柴斧，向%s结算%d Col。" % [resident(owner_id).name, resident(worker_id).name, contract.price_col],
		"contract_id": contract_id, "item_id": item.id}
	_append_life_event(event)
	_complete_repair_command(command_id, payload)
	return {"ok": true, "code": "repair_collected", "contract_id": contract_id, "event_id": event.event_id}

func _has_repair_state() -> bool:
	return _state.get("life") is Dictionary and _state.life.get("items") is Array and _state.life.get("skills") is Array and _state.life.get("accounts") is Array and _state.life.get("contracts") is Array

func _repair_part(part: String) -> Dictionary:
	if part == "edge":
		return {"skill": "metal_repair", "material": "iron"}
	if part == "handle":
		return {"skill": "wood_repair", "material": "wood"}
	return {}

func _has_skill(id: String, skill: String) -> bool:
	if not _has_repair_state():
		return false
	for value in _state.life.skills:
		if value.get("resident_id") == id and value.get("skill_id") == skill:
			return true
	return false

func _find_repair_item(item_id: String) -> Dictionary:
	if not _has_repair_state():
		return {}
	for value in _state.life.items:
		if value.get("id") == item_id:
			return value
	return {}

func _find_repair_contract(contract_id: String) -> Dictionary:
	if not _has_repair_state():
		return {}
	for value in _state.life.contracts:
		if value.get("id") == contract_id:
			return value
	return {}

func _active_contract_for_item(item_id: String) -> Dictionary:
	if not _has_repair_state():
		return {}
	for value in _state.life.contracts:
		if value.get("item_id") == item_id and value.get("status") in REPAIR_ACTIVE_STATUSES:
			return value
	return {}

func _valid_repair_caller(command_id: String, provenance: String) -> bool:
	return _has_repair_state() and _validate_decision_command_id(command_id).ok and provenance in ALLOWED_DECISION_PROVENANCE

func _prior_repair_command(command_id: String, payload: Dictionary) -> Dictionary:
	if not _state.godot.commands.has(command_id):
		return {}
	var matches: bool = _state.godot.commands[command_id].payload == payload
	return {"ok": matches, "duplicate": matches, "code": "duplicate" if matches else "command_conflict"}

func _complete_repair_command(command_id: String, payload: Dictionary) -> void:
	_state.godot.commands[command_id] = {"payload": payload, "status": "completed"}

func _at_worker_station(id: String, worker_id: String) -> bool:
	return position_of(id).distance_to(destination(worker_id, "rest")) <= WORK_STATION_RANGE

func _both_at_worker_station(owner_id: String, worker_id: String) -> bool:
	return _at_worker_station(owner_id, worker_id) and _at_worker_station(worker_id, worker_id) and position_of(owner_id).distance_to(position_of(worker_id)) <= HANDOFF_RANGE

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
	if pending.action in ["repair_edge", "repair_handle"]:
		return _finish_repair(id, pending)
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

func _finish_repair(worker_id: String, pending: Dictionary) -> Dictionary:
	var contract := _find_repair_contract(pending.get("contract_id", ""))
	var item := _find_repair_item(contract.get("item_id", ""))
	var part: String = contract.get("part", "")
	var rule := _repair_part(part)
	var materials := work_account(worker_id)
	var valid: bool = not contract.is_empty() and not item.is_empty() and not rule.is_empty() and contract.get("worker_id") == worker_id and contract.get("status") == "delivered" and item.get("custodian_id") == worker_id and _has_skill(worker_id, rule.skill) and materials.get(rule.material, 0) >= 1 and _at_worker_station(worker_id, worker_id)
	_state.godot.commands[pending.command_id].status = "completed" if valid else "rejected"
	_state.godot.pending.erase(worker_id)
	if not valid:
		return {"ok": false, "code": "repair_resources_unavailable", "actor_id": worker_id,
			"command_id": pending.command_id, "contract_id": pending.get("contract_id", "")}
	materials[rule.material] -= 1
	item[part] = 100
	contract.status = "completed"
	var event := {"type": "work", "actor_id": worker_id, "subject_id": contract.owner_id,
		"recipient_ids": [contract.owner_id, worker_id], "operation_id": pending.command_id,
		"source": pending.provenance, "text": "%s完成了柴斧的修%s。" % [resident(worker_id).name, "刃" if part == "edge" else "柄"],
		"contract_id": contract.id, "item_id": item.id, "part": part}
	_append_life_event(event)
	return {"ok": true, "code": "repair_completed", "actor_id": worker_id,
		"command_id": pending.command_id, "contract_id": contract.id, "event_id": event.event_id}

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
		if job.action in ["repair_edge", "repair_handle"]:
			var contract: Dictionary = {}
			for candidate in value.life.get("contracts", []):
				if candidate is Dictionary and candidate.get("id") == job.get("contract_id"):
					contract = candidate
					break
			if contract.is_empty() or contract.get("worker_id") != id or contract.get("status") != "delivered" or "repair_" + str(contract.get("part", "")) != job.action:
				return _failure("invalid_pending_repair")
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
		if payload.get("actor_id") not in active or (payload.get("action") not in DURATIONS and payload.get("action") not in SOCIAL_ACTIONS and payload.get("action") not in REPAIR_COMMAND_ACTIONS) or payload.get("provenance") not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_command_payload")
		if payload.action in SOCIAL_ACTIONS and (command.status != "completed" or not payload.get("decision") is Dictionary):
			return _failure("invalid_social_command")
		if payload.action in REPAIR_COMMAND_ACTIONS and (command.status != "completed" or not payload.get("contract_id", payload.get("item_id", "")) is String):
			return _failure("invalid_repair_command")
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
