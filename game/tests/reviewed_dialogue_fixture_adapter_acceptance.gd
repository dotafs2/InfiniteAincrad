extends SceneTree

const Adapter = preload("res://agents/reviewed_dialogue_fixture_adapter.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var view := {"available_actions": ["a_accept"]}
	var offered := {"a_accept": "contract:accept:fixture"}
	var raw := _raw("agree", "a_accept")
	var prepared := Adapter.prepare(raw, view, offered)
	_check(prepared.ok and prepared.alias == "a_accept" and prepared.action_id == offered["a_accept"], "consistent proposal prepares through review and base adapter")
	_check(not prepared.execution_authorized and not prepared.review.has("private_thought"), "prepared result cannot authorize or expose private thought")
	var decision := Adapter.authorize(prepared, view, offered, true, "Explicit fixture authorization.")
	_check(decision.ok and decision.decision.action == "a_accept" and decision.decision_authorized and not decision.execution_authorized and not decision.decision.has("speech"), "authorized bounded decision excludes speech and stays unexecuted")
	_check(not Adapter.prepare({"speech":"dictionary"}, view, offered).ok and Adapter.prepare({"speech":"dictionary"}, view, offered).code == "invalid_raw", "dictionary raw input is rejected predictably")
	var mismatch := Adapter.prepare(_raw("offer", "a_accept"), view, offered)
	_check(not mismatch.ok and mismatch.code == "dialogue_review_required", "intent mismatch cannot produce a decision")
	var changed := {"available_actions": ["a_accept"]}
	var remapped := {"a_accept": "contract:accept:new-fixture"}
	var stale := Adapter.authorize(prepared, changed, remapped, true, "Explicit fixture authorization.")
	_check(not stale.ok and stale.code == "stale_dialogue_review", "same-family canonical remap is rejected")
	var forged: Dictionary = prepared.duplicate(true); forged.ok = true; forged.review.review_required = false; forged.raw = _raw("offer", "a_accept")
	var forged_result := Adapter.authorize(forged, view, offered, true, "Explicit fixture authorization.")
	_check(not forged_result.ok and forged_result.code == "dialogue_review_required", "forged prepared flags cannot bypass fresh review")
	var denied := Adapter.authorize(prepared, view, offered, false, "Explicit fixture authorization.")
	_check(not denied.ok and denied.code == "caller_not_authorized", "caller authorization is explicit")
	var private_result := Adapter.authorize(prepared, view, offered, true, "Explicit fixture authorization.")
	_check(not private_result.review.has("private_thought") and not private_result.decision.has("private_thought"), "private thought absent from public authorization result")
	var contextual_view := {"available_actions": ["a_accept"]}
	var contextual_offered := {"a_accept": "contract:accept:fixture"}
	var contextual_raw := _raw_with_context("agree", "a_accept", "shared:smith", ["claim:known"])
	var contextual_prepared := Adapter.prepare(contextual_raw, contextual_view, contextual_offered, ["shared:smith"], ["claim:known"])
	var target_removed := Adapter.authorize(contextual_prepared, contextual_view, contextual_offered, true, "Explicit fixture authorization.", [], ["claim:known"])
	_check(not target_removed.ok and not target_removed.has("decision"), "fresh target removal rejects authorization")
	var claim_removed := Adapter.authorize(contextual_prepared, contextual_view, contextual_offered, true, "Explicit fixture authorization.", ["shared:smith"], [])
	_check(not claim_removed.ok and not claim_removed.has("decision"), "fresh claim removal rejects authorization")
	if failures.is_empty():
		print(JSON.stringify({"ok": true, "checks": checks, "semantic_truth_verification": false}))
		quit(0)
		return
	print(JSON.stringify({"ok": false, "checks": checks, "failures": failures}))
	quit(1)

func _raw(intent: String, alias: String) -> String:
	return _raw_with_context(intent, alias, "", [])

func _raw_with_context(intent: String, alias: String, target: String, claims: Array) -> String:
	return JSON.stringify({"speech": "I will state the bounded proposal.", "intent": intent, "stance": "guarded", "target_id": target, "claim_ids": claims, "stakes": "The terms remain visible.", "next_action": alias, "confidence": 0.8, "private_thought": "private fixture note"})

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
