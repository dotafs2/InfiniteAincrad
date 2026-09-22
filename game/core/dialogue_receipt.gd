extends RefCounted
## Bounded, fail-closed dialogue envelope validation.
## This module validates shape and authorization against a caller-supplied view only;
## it does not decide whether language claims are true and never executes actions.

const MAX_SPEECH := 512
const MAX_STAKES := 256
const MAX_NEXT_ACTION := 128
const MAX_PRIVATE_THOUGHT := 512
const MAX_ID := 96
const MAX_CLAIMS := 12
const MAX_CONTEXT_IDS := 256

const INTENTS := ["ask", "offer", "refuse", "warn", "agree", "disclose", "greet", "leave"]
const STANCES := ["warm", "guarded", "curious", "firm", "uncertain"]
const REQUIRED_FIELDS := ["speech", "intent", "stance", "target_id", "claim_ids", "stakes", "next_action", "confidence"]
const OPTIONAL_FIELDS := ["private_thought"]

static func parse(raw: Variant, context: Dictionary) -> Dictionary:
	var source: Variant = raw
	if raw is String:
		if raw.to_utf8_buffer().size() > 8192:
			return _reject("input_too_large")
		var parser := JSON.new()
		if parser.parse(raw) != OK:
			return _reject("malformed_json")
		source = parser.data
	if not source is Dictionary:
		return _reject("envelope_must_be_object")
	var allowed_context := _validate_context(context)
	if not allowed_context.get("ok", false):
		return allowed_context
	var envelope: Dictionary = source
	for key in REQUIRED_FIELDS:
		if not envelope.has(key):
			return _reject("missing_field", key)
	for key in envelope.keys():
		if key not in REQUIRED_FIELDS and key not in OPTIONAL_FIELDS:
			return _reject("unsupported_field", str(key))
	if not envelope.speech is String or envelope.speech.strip_edges().is_empty() or envelope.speech.length() > MAX_SPEECH:
		return _reject("invalid_speech")
	if not envelope.intent is String or envelope.intent not in INTENTS:
		return _reject("unsupported_intent")
	if not envelope.stance is String or envelope.stance not in STANCES:
		return _reject("unsupported_stance")
	if not envelope.target_id is String or envelope.target_id.length() > MAX_ID:
		return _reject("invalid_target_id")
	if envelope.target_id != "" and not context["target_ids"].has(envelope.target_id):
		return _reject("unsupported_target_id", envelope.target_id)
	if not envelope.claim_ids is Array or envelope.claim_ids.size() > MAX_CLAIMS:
		return _reject("invalid_claim_ids")
	var seen_claims := {}
	for claim_id in envelope.claim_ids:
		if not claim_id is String or claim_id.is_empty() or claim_id.length() > MAX_ID or seen_claims.has(claim_id):
			return _reject("invalid_claim_ids")
		if not context["claim_ids"].has(claim_id):
			return _reject("unsupported_claim_id", claim_id)
		seen_claims[claim_id] = true
	if not envelope.stakes is String or envelope.stakes.length() > MAX_STAKES:
		return _reject("invalid_stakes")
	if not envelope.next_action is String or envelope.next_action.length() > MAX_NEXT_ACTION:
		return _reject("invalid_next_action")
	if envelope.next_action != "" and not context["action_ids"].has(envelope.next_action):
		return _reject("unsupported_next_action", envelope.next_action)
	if not (envelope.confidence is float or envelope.confidence is int) or envelope.confidence is bool:
		return _reject("invalid_confidence")
	var confidence := float(envelope.confidence)
	if is_nan(confidence) or is_inf(confidence) or confidence < 0.0 or confidence > 1.0:
		return _reject("invalid_confidence")
	if envelope.has("private_thought") and (not envelope.private_thought is String or envelope.private_thought.length() > MAX_PRIVATE_THOUGHT):
		return _reject("invalid_private_thought")
	var receipt := {"speech": envelope.speech, "intent": envelope.intent, "stance": envelope.stance,
		"target_id": envelope.target_id, "claim_ids": envelope.claim_ids.duplicate(), "stakes": envelope.stakes,
		"next_action": envelope.next_action, "confidence": confidence}
	if envelope.has("private_thought"):
		receipt["private_thought"] = envelope.private_thought
	return {"ok": true, "receipt": receipt, "proposed": envelope.next_action != "", "execution": "not_attempted"}

static func public_projection(receipt: Dictionary) -> Dictionary:
	var result := {}
	for key in ["speech", "intent", "stance", "target_id", "claim_ids", "stakes", "next_action", "confidence"]:
		if receipt.has(key):
			result[key] = receipt[key].duplicate(true) if receipt[key] is Array else receipt[key]
	return result

static func _validate_context(context: Dictionary) -> Dictionary:
	for key in ["target_ids", "claim_ids", "action_ids"]:
		if not context.has(key) or not context[key] is Array or context[key].size() > MAX_CONTEXT_IDS:
			return _reject("invalid_allowed_context", key)
		var seen := {}
		for value in context[key]:
			if not value is String or value.is_empty() or value.length() > MAX_ID or seen.has(value):
				return _reject("invalid_allowed_context", key)
			seen[value] = true
	return {"ok": true}

static func _reject(code: String, detail: String = "") -> Dictionary:
	var result := {"ok": false, "code": code}
	if detail != "":
		result["detail"] = detail
	return result
