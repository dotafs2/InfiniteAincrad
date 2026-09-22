extends SceneTree

const Receipt = preload("res://core/dialogue_receipt.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var context := {"target_ids": ["player", "resident:b"], "claim_ids": ["claim:rain", "claim:key"], "action_ids": ["offer:lantern", "wait"]}
	var valid := {"speech": "The north road is flooded.", "intent": "warn", "stance": "guarded", "target_id": "player",
		"claim_ids": ["claim:rain"], "stakes": "We lose the crossing until dawn.", "next_action": "offer:lantern", "private_thought": "I hope they listen.", "confidence": 0.75}
	var accepted := Receipt.parse(valid, context)
	_check(accepted.ok, "valid envelope accepted")
	_check(accepted.proposed and accepted.execution == "not_attempted", "proposal remains separate from execution")
	_check(not Receipt.public_projection(accepted.receipt).has("private_thought"), "private thought is omitted from public projection")
	_check(accepted.receipt.private_thought == "I hope they listen.", "private thought remains available to private owner")
	var parsed_json := Receipt.parse(JSON.stringify(valid), context)
	_check(parsed_json.ok and parsed_json.receipt == accepted.receipt, "JSON string parses to equivalent receipt")
	for field in ["speech", "intent", "stance", "target_id", "claim_ids", "stakes", "next_action", "confidence"]:
		var missing := valid.duplicate(true)
		missing.erase(field)
		_check(not Receipt.parse(missing, context).ok, "missing field rejected: " + field)
	_check(not Receipt.parse("{bad", context).ok, "malformed JSON rejected")
	var unknown := valid.duplicate(true); unknown.extra = true
	_check(not Receipt.parse(unknown, context).ok, "unknown field rejected")
	var private_metadata_receipt: Dictionary = accepted.receipt.duplicate(true); private_metadata_receipt.private_metadata = "do not leak"
	var public_result := Receipt.public_projection(private_metadata_receipt)
	_check(not public_result.has("private_metadata") and public_result.keys().size() == 8, "public projection uses explicit allow-list")
	var unsupported_target := valid.duplicate(true); unsupported_target.target_id = "admin"
	_check(not Receipt.parse(unsupported_target, context).ok, "unsupported target rejected")
	var unsupported_claim := valid.duplicate(true); unsupported_claim.claim_ids = ["claim:made-up"]
	_check(not Receipt.parse(unsupported_claim, context).ok, "unsupported claim rejected")
	var unsupported_action := valid.duplicate(true); unsupported_action.next_action = "spawn:item"
	_check(not Receipt.parse(unsupported_action, context).ok, "unsupported proposed action rejected")
	var long_speech := valid.duplicate(true); long_speech.speech = "x".repeat(513)
	_check(not Receipt.parse(long_speech, context).ok, "oversized speech rejected")
	var wrong_type := valid.duplicate(true); wrong_type.claim_ids = "claim:rain"
	_check(not Receipt.parse(wrong_type, context).ok, "wrong claim type rejected")
	var bad_confidence := valid.duplicate(true); bad_confidence.confidence = 1.1
	_check(not Receipt.parse(bad_confidence, context).ok, "out of range confidence rejected")
	var bool_confidence := valid.duplicate(true); bool_confidence.confidence = true
	_check(not Receipt.parse(bool_confidence, context).ok, "boolean confidence rejected")
	var nan_confidence := valid.duplicate(true); nan_confidence.confidence = NAN
	_check(not Receipt.parse(nan_confidence, context).ok, "NaN confidence rejected")
	var malformed_context := context.duplicate(true); malformed_context.erase("action_ids")
	_check(not Receipt.parse(valid, malformed_context).ok, "incomplete context rejected")
	var wrong_context := context.duplicate(true); wrong_context.action_ids = "offer:lantern"
	_check(not Receipt.parse(valid, wrong_context).ok, "wrong context list type rejected")
	var no_target := valid.duplicate(true); no_target.target_id = ""; no_target.next_action = ""
	_check(Receipt.parse(no_target, context).ok, "non-applicable target and action may be empty")
	var duplicate_claim := valid.duplicate(true); duplicate_claim.claim_ids = ["claim:rain", "claim:rain"]
	_check(not Receipt.parse(duplicate_claim, context).ok, "duplicate claims rejected")
	var oversized_raw := "x".repeat(8193)
	_check(not Receipt.parse(oversized_raw, context).ok, "oversized raw input rejected")
	if not failures.is_empty():
		print(JSON.stringify({"ok": false, "failures": failures}))
		quit(1)
	print(JSON.stringify({"ok": true, "checks": checks, "semantic_truth_verification": false}))
	quit(0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
