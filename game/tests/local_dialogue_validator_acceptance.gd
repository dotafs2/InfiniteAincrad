extends SceneTree
const Validator = preload("res://tests/validate_local_dialogue_proposals.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var context := {"target_ids": ["shared:carpenter"], "claim_ids": [], "action_ids": ["offer:axe"]}
	var raw := JSON.stringify({"speech": "I can inspect the edge.", "intent": "offer", "stance": "guarded", "target_id": "shared:carpenter", "claim_ids": [], "stakes": "The edge remains unresolved.", "next_action": "offer:axe", "confidence": 0.8})
	var data := {"fixture_only": true, "cases": [{"case_id": "a", "raw_content": raw}]}
	var exported := {"fixture_only": true, "cases": [{"case_id": "a", "context": context}]}
	var valid := Validator.validate_documents(data, exported)
	_check(valid.ok and valid.results.size() == 1 and valid.results[0].accepted, "valid raw envelope accepted through Receipt.parse")
	var malformed: Dictionary = data.duplicate(true); malformed.cases[0].raw_content = "{not-json"
	var malformed_result := Validator.validate_documents(malformed, exported)
	_check(malformed_result.ok and not malformed_result.results[0].accepted and malformed_result.results[0].reason == "malformed_json", "malformed raw is rejected without repair")
	var unlisted: Dictionary = exported.duplicate(true); unlisted.cases[0].context.action_ids = ["wait"]
	var unlisted_result := Validator.validate_documents(data, unlisted)
	_check(unlisted_result.ok and not unlisted_result.results[0].accepted and unlisted_result.results[0].reason == "unsupported_next_action", "unlisted action is rejected by Receipt.parse")
	_check(not Validator.validate_documents({"fixture_only": true, "cases": []}, exported).ok, "empty probe batch rejected")
	var duplicate_fixture := {"fixture_only": true, "cases": [{"case_id": "a", "context": context}, {"case_id": "a", "context": context}]}
	_check(not Validator.validate_documents(data, duplicate_fixture).ok, "duplicate fixture IDs rejected")
	_check(not Validator.validate_documents({"fixture_only": true, "cases": [{"case_id": "other", "raw_content": raw}]}, exported).ok, "unknown case ID set rejected")
	_check(not Validator.validate_documents({"fixture_only": true, "cases": [{"case_id": "a", "raw_content": 7}]}, exported).ok, "non-string raw content rejected honestly")
	var bad_flag: Dictionary = exported.duplicate(true); bad_flag.fixture_only = false
	_check(not Validator.validate_documents(data, bad_flag).ok, "non-fixture contexts rejected")
	if failures.is_empty(): print(JSON.stringify({"ok": true, "checks": checks, "semantic_truth_verification": false})); quit(0); return
	print(JSON.stringify({"ok": false, "checks": checks, "failures": failures})); quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
