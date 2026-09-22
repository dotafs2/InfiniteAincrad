extends RefCounted
## Optional offline review gate for an already parsed dialogue proposal.
## It joins an independently exported alias table to canonical action IDs, but never executes actions.

const Receipt = preload("res://core/dialogue_receipt.gd")

static func review(raw: Variant, fixture: Dictionary) -> Dictionary:
	var result := {"ok": false, "structural_accepted": false, "review_required": true,
		"reason": "invalid_input", "alias": "", "action_id": "", "declared_intent": "",
		"expected_intents": [], "speech": "", "execution": "not_attempted", "execution_authorized": false,
		"semantic_truth_verification": false}
	if not fixture is Dictionary or not fixture.has("context") or not fixture.context is Dictionary or not fixture.has("options") or not fixture.options is Array:
		return result
	var context: Dictionary = fixture.context
	var options: Array = fixture.options
	var aliases := {}
	var canonical_ids := {}
	for option in options:
		if not option is Dictionary or not option.has("alias") or not option.alias is String or option.alias.is_empty() or not option.has("action_id") or not option.action_id is String or option.action_id.is_empty():
			result.reason = "invalid_options"
			return result
		if aliases.has(option.alias) or canonical_ids.has(option.action_id):
			result.reason = "duplicate_options"
			return result
		aliases[option.alias] = option.action_id
		canonical_ids[option.action_id] = true
	if not context.has("action_ids") or not context.action_ids is Array or context.action_ids.size() != aliases.size():
		result.reason = "action_context_mismatch"
		return result
	var context_ids := {}
	for action_id in context.action_ids:
		if not action_id is String or action_id.is_empty() or context_ids.has(action_id):
			result.reason = "invalid_action_context"
			return result
		context_ids[action_id] = true
	for alias in aliases:
		if not context_ids.has(alias):
			result.reason = "action_context_mismatch"
			return result
	var parsed: Dictionary = Receipt.parse(raw, context)
	if not parsed.get("ok", false):
		result.reason = parsed.get("code", "receipt_rejected")
		return result
	var receipt: Dictionary = parsed.receipt
	result.ok = true
	result.structural_accepted = true
	result.speech = receipt.speech
	result.declared_intent = receipt.intent
	var alias: String = receipt.next_action
	result.alias = alias
	if alias.is_empty():
		result.reason = "no_action"
		return result
	if not aliases.has(alias):
		result.reason = "alias_not_exported"
		return result
	result.action_id = aliases[alias]
	result.expected_intents = _expected_intents(result.action_id)
	if result.expected_intents.is_empty():
		result.reason = "unmapped_action"
		return result
	if not result.expected_intents.has(receipt.intent):
		result.reason = "intent_mismatch"
		return result
	result.review_required = false
	result.reason = "intent_compatible"
	return result

static func _expected_intents(action_id: String) -> Array:
	if action_id.begins_with("contract:accept:"): return ["agree"]
	if action_id.begins_with("contract:reject:"): return ["refuse"]
	if action_id.begins_with("contract:offer:"): return ["offer"]
	if action_id.begins_with("share-skill:"): return ["disclose"]
	return []
