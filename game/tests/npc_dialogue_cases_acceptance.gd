extends SceneTree

const Receipt = preload("res://core/dialogue_receipt.gd")
const CASES_PATH := "res://../docs/design/npc-dialogue-cases-20260923.json"
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var file := FileAccess.open(CASES_PATH, FileAccess.READ)
	_check(file != null, "case pack opens")
	if file == null:
		_finish()
		return
	var parser := JSON.new()
	_check(parser.parse(file.get_as_text()) == OK, "case pack parses as JSON")
	if parser.data is not Dictionary:
		_finish()
		return
	var pack: Dictionary = parser.data
	var cases: Array = pack.get("cases", [])
	_check(cases.size() == 30, "exactly 30 cases")
	var residents := {}
	for item in cases:
		if not item is Dictionary:
			_check(false, "case is an object")
			continue
		var context_view: Dictionary = item.get("context", {})
		var receipt_context: Dictionary = item.get("parse_context", {})
		var candidate: Dictionary = item.get("candidate", {})
		var result := Receipt.parse(candidate, receipt_context)
		var expected_ok: bool = item.get("expected_accept", false)
		_check(result.ok == expected_ok, "%s structural expectation" % item.get("case_id", "unknown"))
		if not expected_ok:
			_check(not result.ok and result.code == item.get("expected_code", ""), "%s expected rejection code" % item.get("case_id", "unknown"))
		if result.ok:
			_check(result.execution == "not_attempted", "%s remains proposal-only" % item.get("case_id", "unknown"))
			_check(not Receipt.public_projection(result.receipt).has("private_thought"), "%s private thought is not public" % item.get("case_id", "unknown"))
			var mutation := candidate.duplicate(true)
			mutation.next_action = "fixture:unlisted-action"
			var mutation_result := Receipt.parse(mutation, receipt_context)
			_check(not mutation_result.ok and mutation_result.code == "unsupported_next_action", "%s rejects unlisted action mutation" % item.get("case_id", "unknown"))
		residents[str(item.get("resident_id", ""))] = true
	_check(residents.size() == 10, "all ten formal resident IDs covered")
	_finish()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _finish() -> void:
	if failures.is_empty():
		print(JSON.stringify({"ok": true, "checks": checks, "cases": 30, "voice_evaluation": "separate", "semantic_truth_verification": false}))
		quit(0)
	else:
		print(JSON.stringify({"ok": false, "checks": checks, "failures": failures}))
		quit(1)
