extends "res://core/town_actions.gd"
## Disposable-only resident bridge for the reviewed adventure sidecar.
## It exposes one host-gated travel choice after a measured physical route. It is
## not wired into the maintained production TownActions instance.

const ADVENTURE_OPTION := "ability:adventure.enter_wilderness"
const ADVENTURE_CAPABILITY := "adventure.enter_wilderness"
const ADVENTURE_OWNER := "adventure_contract.v1"
const GATE_TARGET := Vector3(0.0, 0.10, 53.0)
const GATE_ARRIVAL_RADIUS := 0.45
const GATE_TARGET_TOLERANCE := 0.001
const AdventureCapabilityManifest = preload("res://core/actions/adventure_capabilities.gd")
const AdventureBridge = preload("res://core/adventure_live_bridge.gd")

class AdventureResidentCapability:
	extends RefCounted
	const OPTION := "ability:adventure.enter_wilderness"
	const CAPABILITY := "adventure.enter_wilderness"

	func options(_world, _id: String) -> Array:
		return []

	func execute(world, _id: String, _option: Dictionary, _command: String,
			_provenance: String, _speech: String) -> Dictionary:
		return world._failure("adventure_adapter_dispatch_required")

	func validate_command(world, _value: Dictionary, command: String, row: Dictionary,
			event: Dictionary) -> Dictionary:
		var payload: Dictionary = row.payload
		var result: Dictionary = row.result
		if row.capability_id != CAPABILITY or row.status != "completed":
			return world._failure("invalid_adventure_resident_receipt")
		if payload.option_id != OPTION or payload.speech != "":
			return world._failure("invalid_adventure_resident_payload")
		if event.get("type") != "adventure_enter_wilderness" or event.get("actor_id") != payload.actor_id \
				or event.get("subject_id") != payload.actor_id or event.get("recipient_ids") != [payload.actor_id] \
				or event.get("operation_id") != command or event.get("provenance") != payload.provenance:
			return world._failure("adventure_resident_event_mismatch")
		if result.get("ok") != true or result.get("code") != "entered_wilderness" \
				or result.get("resident_id") != payload.actor_id or result.get("command_id") != command \
				or result.get("kind") != "enter_wilderness" or result.get("capability_id") != CAPABILITY \
				or result.get("event_id") != event.get("event_id"):
			return world._failure("adventure_resident_result_mismatch")
		var effect: Variant = event.get("adventure_receipt")
		if not effect is Dictionary or effect.get("ok") != true or effect.get("code") != "entered_wilderness" \
				or effect.get("resident_id") != payload.actor_id or effect.get("command_id") != command \
				or effect.get("kind") != "enter_wilderness":
			return world._failure("adventure_sidecar_receipt_mismatch")
		var expected: Dictionary = effect.duplicate(true)
		expected["event_id"] = event.get("event_id")
		expected["capability_id"] = CAPABILITY
		if result != expected:
			return world._failure("adventure_resident_result_mismatch")
		return {"ok": true}

	func validate_state(world, value: Dictionary) -> Dictionary:
		var sidecar: Variant = value.godot.get("adventure_state")
		var adventure_commands: Dictionary = {}
		for command_id in value.godot.get("capabilities", {}).get("commands", {}):
			var row: Dictionary = value.godot.capabilities.commands[command_id]
			if row.get("capability_id") == CAPABILITY:
				adventure_commands[command_id] = row
		if not adventure_commands.is_empty():
			if not sidecar is Dictionary or sidecar.get("schema_version") != 1 \
					or sidecar.get("contract_id") != "adventure_contract.v1" \
					or not sidecar.get("residents") is Dictionary or not sidecar.get("commands") is Dictionary \
					or not sidecar.get("receipts") is Array:
				return world._failure("adventure_town_snapshot_missing_or_invalid")
			for person in value.residents:
				var resident_id := str(person.get("stable_id", ""))
				if not value.godot.positions.has(resident_id):
					continue
				var sidecar_resident: Dictionary = sidecar.residents.get(resident_id, {})
				if sidecar_resident.get("id") != resident_id:
					return world._failure("adventure_town_snapshot_resident_mismatch")
		for event in value.life.events:
			if event.get("type") != "adventure_enter_wilderness":
				continue
			if not sidecar is Dictionary:
				return world._failure("adventure_town_snapshot_missing_or_invalid")
			var command_id: String = str(event.get("operation_id", ""))
			var command: Dictionary = adventure_commands.get(command_id, {})
			var sidecar_commands: Variant = sidecar.get("commands", {})
			if not sidecar_commands is Dictionary:
				return world._failure("adventure_town_snapshot_missing_or_invalid")
			var sidecar_command_value: Variant = sidecar_commands.get(command_id, {})
			if not sidecar_command_value is Dictionary:
				return world._failure("adventure_town_snapshot_missing_or_invalid")
			var sidecar_command: Dictionary = sidecar_command_value
			var expected_request := {"kind": "enter_wilderness", "parameters": {
				"resident_id": event.get("actor_id"), "physical_arrival": true}}
			if command.get("capability_id") != CAPABILITY or command.get("event_seq") != event.get("seq") \
					or sidecar_command.get("request") != expected_request \
					or sidecar_command.get("result") != event.get("adventure_receipt"):
				return world._failure("orphan_adventure_resident_event")
		if not adventure_commands.is_empty() and AdventureBridge.validate_adventure_snapshot(sidecar, value) != {"ok": true}:
			return world._failure("adventure_town_snapshot_invalid")
		return {"ok": true}

var adventure_bridge
var _adventure_transaction_depth := 0

func transaction(path: String, operation: Callable) -> Dictionary:
	var before_adventure: Dictionary = {}
	var had_bridge_snapshot := adventure_bridge != null and adventure_bridge.adventure != null
	if had_bridge_snapshot:
		before_adventure = adventure_bridge.adventure.snapshot()
	var previous_depth := _adventure_transaction_depth
	_adventure_transaction_depth += 1
	var result: Dictionary = super.transaction(path, func():
		var outcome: Dictionary = operation.call()
		if outcome.get("ok", false) and adventure_bridge != null and adventure_bridge.adventure != null:
			var current_adventure: Dictionary = adventure_bridge.adventure.snapshot()
			if had_bridge_snapshot and current_adventure != before_adventure:
				_state.godot.adventure_state = current_adventure
		return outcome)
	_adventure_transaction_depth = previous_depth
	if not result.get("ok", false) and had_bridge_snapshot:
		adventure_bridge.restore_adventure_snapshot(before_adventure)
	return result

func _ensure_adventure_capability() -> bool:
	if not _capability_modules.has(ADVENTURE_OWNER):
		_capability_modules[ADVENTURE_OWNER] = AdventureResidentCapability.new()
	if not _capability_registry.definition(ADVENTURE_CAPABILITY).is_empty():
		return true
	for definition in AdventureCapabilityManifest.new().definitions():
		if definition.get("id") == ADVENTURE_CAPABILITY:
			var registered: Dictionary = _capability_registry.register(definition)
			return bool(registered.get("ok", false))
	return false

func attach_adventure(bridge) -> Dictionary:
	if bridge == null or not bridge.has_method("enter_wilderness") or not _ensure_adventure_capability():
		return _failure("adventure_bridge_invalid")
	var hydrated: Dictionary = bridge.hydrate_from_town_state(_state)
	if not hydrated.get("ok", false):
		return hydrated
	adventure_bridge = bridge
	return {"ok": true, "code": "adventure_bridge_attached"}

func adventure_resident_adopted() -> bool:
	for row in capability_store().get("commands", {}).values():
		if row.get("capability_id") == ADVENTURE_CAPABILITY and row.get("status") == "completed":
			return true
	return false

func load_from(path: String) -> Dictionary:
	if not _ensure_adventure_capability():
		return _failure("adventure_capability_registration_failed")
	return super.load_from(path)

func mark_physical_arrival(path: String, resident_id: String, route_receipt: Dictionary) -> Dictionary:
	if adventure_bridge == null:
		return _failure("adventure_bridge_missing")
	if resident_id not in active_ids():
		return _failure("resident_missing")
	if route_receipt.get("ok", false) != true \
			or str(route_receipt.get("route_kind", "")) != "collision_aware_town_route":
		return _failure("physical_route_receipt_required")
	if str(route_receipt.get("resident_id", "")) != resident_id:
		return _failure("physical_route_actor_mismatch")
	if str(route_receipt.get("target", "")) != "wilderness_gate":
		return _failure("physical_route_target_mismatch")
	var target_value: Variant = route_receipt.get("target_position")
	if not _valid_position(target_value):
		return _failure("physical_route_target_position_invalid")
	var target_position := _vector(target_value)
	if target_position.distance_to(GATE_TARGET) > GATE_TARGET_TOLERANCE:
		return _failure("physical_route_target_untrusted")
	var route_id := str(route_receipt.get("route_id", ""))
	var frames: Variant = route_receipt.get("frames", null)
	var metres: Variant = route_receipt.get("metres", null)
	if route_id.is_empty() or typeof(frames) != TYPE_INT or frames < 1 \
			or typeof(metres) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(metres)) or float(metres) <= 0.0:
		return _failure("physical_route_measurements_invalid")
	var arrival_position: Vector3 = position_of(resident_id)
	if arrival_position.distance_to(target_position) > GATE_ARRIVAL_RADIUS:
		return _failure("physical_route_actor_not_at_target")
	return transaction(path, func():
		if not _state.godot.has("adventure_physical_arrivals"):
			_state.godot.adventure_physical_arrivals = {}
		_state.godot.adventure_physical_arrivals[resident_id] = {
			"resident_id": resident_id,
			"route_kind": route_receipt.route_kind,
			"route_id": route_id,
			"target": "wilderness_gate",
			"target_position": [target_position.x, target_position.y, target_position.z],
			"arrival_position": [arrival_position.x, arrival_position.y, arrival_position.z],
			"arrived": true,
			"frames": frames,
			"metres": float(metres)
		}
		return {"ok": true, "code": "physical_arrival_recorded", "resident_id": resident_id})

func _has_physical_arrival(id: String) -> bool:
	var arrivals: Variant = _state.godot.get("adventure_physical_arrivals", {})
	if not arrivals is Dictionary:
		return false
	var arrival: Variant = arrivals.get(id, {})
	if not arrival is Dictionary or arrival.get("arrived", false) != true \
			or arrival.get("resident_id", "") != id or arrival.get("target", "") != "wilderness_gate":
		return false
	var target: Variant = arrival.get("target_position")
	var stored_position: Variant = arrival.get("arrival_position")
	if not _valid_position(target) or not _valid_position(stored_position):
		return false
	if _vector(target).distance_to(GATE_TARGET) > GATE_TARGET_TOLERANCE:
		return false
	return _vector(stored_position).distance_to(_vector(target)) <= GATE_ARRIVAL_RADIUS \
			and position_of(id).distance_to(GATE_TARGET) <= GATE_ARRIVAL_RADIUS

func action_options(id: String) -> Array:
	var options: Array = super.action_options(id)
	if adventure_bridge == null or id not in active_ids() or not _has_physical_arrival(id):
		return options
	var adventure_state: Dictionary = adventure_bridge.adventure.snapshot()
	var resident: Dictionary = adventure_state.get("residents", {}).get(id, {})
	if resident.is_empty() or resident.get("zone") != "town" or resident.get("status") == "defeated":
		return options
	if not pending_job(id).is_empty() or bool(resident.get("committed_job", false)):
		return options
	options.append({
		"id": ADVENTURE_OPTION,
		"label": "Enter the wilderness from the gate",
		"capability_id": ADVENTURE_CAPABILITY,
		"speech_allowed": false,
		"adventure_host_gated": true
	})
	return options

func execute_action(id: String, option_id: String, command_id: String,
		provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if option_id != ADVENTURE_OPTION:
		return super.execute_action(id, option_id, command_id, provenance, speech)
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok \
			or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if speech.length() > MAX_REASON_LENGTH or (not speech.is_empty() and speech.strip_edges().is_empty()):
		return _failure("invalid_public_speech")
	if not speech.is_empty():
		return _failure("speech_not_supported_for_action")
	var payload := {"actor_id": id, "option_id": option_id, "provenance": provenance, "speech": speech}
	var prior: Dictionary = capability_store().get("commands", {}).get(command_id, {})
	if not prior.is_empty():
		var same: bool = prior.get("payload", {}) == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if LegacyCapabilities.has_command(_state, command_id):
		return _failure("command_conflict")
	if adventure_bridge == null:
		return _failure("adventure_bridge_missing")
	if not _has_physical_arrival(id):
		return _failure("physical_arrival_required")
	if not pending_job(id).is_empty():
		return _failure("resident_has_pending_job")
	var adventure_state: Dictionary = adventure_bridge.adventure.snapshot()
	var resident: Dictionary = adventure_state.get("residents", {}).get(id, {})
	if resident.is_empty() or resident.get("zone") != "town" or resident.get("status") == "defeated":
		return _failure("adventure_entry_unavailable")
	if bool(resident.get("committed_job", false)):
		return _failure("committed_job_must_finish_or_reject")
	if position_of(id).distance_to(GATE_TARGET) > GATE_ARRIVAL_RADIUS:
		return _failure("physical_arrival_required")
	if _adventure_transaction_depth <= 0:
		return _failure("adventure_transaction_required")
	var effect: Dictionary = adventure_bridge.enter_wilderness(id, command_id)
	if not effect.get("ok", false):
		return effect
	var result := effect.duplicate(true)
	result["capability_id"] = ADVENTURE_CAPABILITY
	_append_life_event({
		"type": "adventure_enter_wilderness",
		"actor_id": id,
		"subject_id": id,
		"recipient_ids": [id],
		"operation_id": command_id,
		"source": provenance,
		"provenance": provenance,
		"text": "%s entered the wilderness from the gate." % resident_name(id),
		"adventure_receipt": effect.duplicate(true)
	})
	result["event_id"] = _state.life.events[-1].event_id
	ensure_capability_store().commands[command_id] = {
		"capability_id": ADVENTURE_CAPABILITY,
		"version": _capability_registry.definition(ADVENTURE_CAPABILITY).version,
		"payload": payload,
		"created_elapsed": _state.godot.elapsed_seconds,
		"status": "completed",
		"event_seq": int(_state.life.seq),
		"result": result.duplicate(true)
	}
	return result
