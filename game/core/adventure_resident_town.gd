extends "res://core/town_actions.gd"
## Disposable-only resident bridge for the reviewed adventure sidecar.
## It exposes one host-gated travel choice after a real route receipt. It is not
## wired into the maintained production TownActions instance.

const ADVENTURE_OPTION := "ability:adventure.enter_wilderness"
const ADVENTURE_CAPABILITY := "adventure.enter_wilderness"

var adventure_bridge
var _adventure_resident_adopted := false

func attach_adventure(bridge) -> Dictionary:
	if bridge == null or not bridge.has_method("enter_wilderness"):
		return _failure("adventure_bridge_invalid")
	adventure_bridge = bridge
	return {"ok": true, "code": "adventure_bridge_attached"}

func adventure_resident_adopted() -> bool:
	return _adventure_resident_adopted

func load_from(path: String) -> Dictionary:
	var result: Dictionary = super.load_from(path)
	return result

func mark_physical_arrival(path: String, resident_id: String, route_receipt: Dictionary) -> Dictionary:
	if adventure_bridge == null:
		return _failure("adventure_bridge_missing")
	if resident_id not in active_ids():
		return _failure("resident_missing")
	if not route_receipt.get("ok", false) or str(route_receipt.get("route_kind", "")) != "collision_aware_town_route":
		return _failure("physical_route_receipt_required")
	return transaction(path, func():
		if not _state.godot.has("adventure_physical_arrivals"):
			_state.godot.adventure_physical_arrivals = {}
		_state.godot.adventure_physical_arrivals[resident_id] = {
			"resident_id": resident_id,
			"route_kind": route_receipt.route_kind,
			"route_id": str(route_receipt.get("route_id", "")),
			"target": str(route_receipt.get("target", "wilderness_gate")),
			"arrived": true,
			"frames": int(route_receipt.get("frames", 0)),
			"metres": float(route_receipt.get("metres", 0.0))
		}
		return {"ok": true, "code": "physical_arrival_recorded", "resident_id": resident_id})

func _has_physical_arrival(id: String) -> bool:
	var arrivals: Variant = _state.godot.get("adventure_physical_arrivals", {})
	return arrivals is Dictionary and arrivals.get(id, {}).get("arrived", false) == true

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
	if adventure_bridge == null:
		return _failure("adventure_bridge_missing")
	if speech != "":
		return _failure("speech_not_supported_for_action")
	if not _has_physical_arrival(id):
		return _failure("physical_arrival_required")
	var effect: Dictionary = adventure_bridge.enter_wilderness(id, command_id)
	if not effect.get("ok", false):
		return effect
	_adventure_resident_adopted = true
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
	effect["event_id"] = _state.life.events[-1].event_id
	effect["capability_id"] = ADVENTURE_CAPABILITY
	return effect
