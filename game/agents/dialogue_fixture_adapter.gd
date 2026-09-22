## Test-only bridge from a validated dialogue proposal to the existing resident-turn
## alias gate. Production turns and trade never preload this file.
class_name DialogueFixtureAdapter

const Receipt = preload("res://core/dialogue_receipt.gd")

static func validate(raw: Variant, view: Dictionary, offered_actions: Dictionary,
		target_ids: Array = [], claim_ids: Array = []) -> Dictionary:
	if not _valid_offers(view, offered_actions):
		return {"ok": false, "code": "invalid_fixture_context"}
	var parsed: Dictionary = Receipt.parse(raw, {"target_ids": target_ids, "claim_ids": claim_ids,
		"action_ids": view.available_actions})
	if not parsed.get("ok", false):
		return {"ok": false, "code": "invalid_dialogue_receipt", "receipt": parsed.get("receipt", {})}
	var alias := str(parsed.get("receipt", {}).get("next_action", ""))
	if alias.is_empty() or not offered_actions.has(alias):
		return {"ok": false, "code": "dialogue_action_not_offered", "receipt": parsed.receipt}
	return {"ok": true, "receipt": parsed.receipt.duplicate(true), "alias": alias,
		"action_id": str(offered_actions[alias])}

static func authorize(prepared: Dictionary, current_view: Dictionary, current_offered_actions: Dictionary,
		caller_authorized: bool, reason: String) -> Dictionary:
	if not caller_authorized:
		return {"ok": false, "code": "caller_not_authorized"}
	if not prepared.get("ok", false) or reason.is_empty():
		return {"ok": false, "code": "invalid_prepared_dialogue"}
	if not _valid_offers(current_view, current_offered_actions):
		return {"ok": false, "code": "invalid_current_context"}
	var alias := str(prepared.get("alias", ""))
	if alias not in current_view.available_actions or not current_offered_actions.has(alias):
		return {"ok": false, "code": "stale_dialogue_action"}
	if str(current_offered_actions[alias]) != str(prepared.get("action_id", "")):
		return {"ok": false, "code": "stale_dialogue_action"}
	# Speech, intent, stakes and private_thought deliberately do not enter this decision.
	return {"ok": true, "decision": {"action": alias, "reason": reason}}

static func _valid_offers(view: Dictionary, offered_actions: Dictionary) -> bool:
	if not view.get("available_actions", null) is Array or offered_actions.is_empty():
		return false
	for alias in view.available_actions:
		if not alias is String or not offered_actions.has(alias) or not offered_actions[alias] is String:
			return false
	return true
