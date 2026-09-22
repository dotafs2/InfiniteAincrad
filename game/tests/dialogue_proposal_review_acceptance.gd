extends SceneTree

const Review = preload("res://agents/dialogue_proposal_review.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run_synthetic()
	_run_saved_fixture()
	if failures.is_empty():
		print(JSON.stringify({"ok": true, "checks": checks, "semantic_truth_verification": false}))
		quit(0)
		return
	print(JSON.stringify({"ok": false, "checks": checks, "failures": failures}))
	quit(1)

func _run_synthetic() -> void:
	var accept_id := "contract:accept:fixture"
	var reject_id := "contract:reject:fixture"
	var fixture := {"context": {"target_ids": ["shared:smith"], "claim_ids": [], "action_ids": ["a_accept", "a_reject"]},
		"options": [{"alias": "a_accept", "action_id": accept_id}, {"alias": "a_reject", "action_id": reject_id}]}
	var raw_accept := _raw("agree", "a_accept")
	var accepted := Review.review(raw_accept, fixture)
	_check(accepted.ok and accepted.structural_accepted and not accepted.review_required and accepted.alias == "a_accept" and accepted.action_id == accept_id and accepted.expected_intents == ["agree"] and accepted.reason == "intent_compatible", "consistent accept maps to canonical action")
	_check(accepted.execution == "not_attempted" and not accepted.semantic_truth_verification and not accepted.has("private_thought"), "review gate does not execute or expose private thought")
	var consistent_reject := Review.review(_raw("refuse", "a_reject"), fixture)
	_check(consistent_reject.ok and not consistent_reject.review_required and consistent_reject.action_id == reject_id, "consistent refusal maps to canonical action")
	var offer_fixture := {"context": {"target_ids": ["shared:smith"], "claim_ids": [], "action_ids": ["a_offer", "a_disclose"]}, "options": [{"alias": "a_offer", "action_id": "contract:offer:fixture"}, {"alias": "a_disclose", "action_id": "share-skill:shared:smith:metal_repair"}]}
	var consistent_offer := Review.review(_raw("offer", "a_offer"), offer_fixture)
	var consistent_disclose := Review.review(_raw("disclose", "a_disclose"), offer_fixture)
	_check(not consistent_offer.review_required and consistent_offer.expected_intents == ["offer"], "synthetic offer counterpart maps consistently")
	_check(not consistent_disclose.review_required and consistent_disclose.expected_intents == ["disclose"], "synthetic disclose counterpart maps consistently")
	var mismatch := Review.review(_raw("offer", "a_accept"), fixture)
	_check(mismatch.ok and mismatch.structural_accepted and mismatch.review_required and mismatch.reason == "intent_mismatch", "valid mismatched intent requires review")
	var contradictory_speech := Review.review(_raw_with_speech("agree", "a_accept", "I refuse this job and will not accept it."), fixture)
	_check(contradictory_speech.ok and not contradictory_speech.review_required and contradictory_speech.execution_authorized == false and not contradictory_speech.semantic_truth_verification, "intent compatibility does not claim speech semantics or authorize execution")
	var no_action := Review.review(_raw("agree", ""), fixture)
	_check(no_action.ok and no_action.structural_accepted and no_action.review_required and no_action.reason == "no_action", "missing action requires review")
	var unknown := Review.review(_raw("greet", "a_unknown"), fixture)
	_check(not unknown.structural_accepted and unknown.reason == "unsupported_next_action", "unlisted alias is rejected by receipt authorization")
	var unmapped_fixture := {"context": {"target_ids": ["shared:smith"], "claim_ids": [], "action_ids": ["a_wait"]}, "options": [{"alias": "a_wait", "action_id": "wait"}]}
	var unmapped := Review.review(_raw("agree", "a_wait"), unmapped_fixture)
	_check(unmapped.ok and unmapped.structural_accepted and unmapped.review_required and unmapped.reason == "unmapped_action", "unknown action family requires review")
	var remapped: Dictionary = fixture.duplicate(true); remapped.options[0].action_id = "contract:reject:tampered"
	var tampered := Review.review(raw_accept, remapped)
	_check(tampered.ok and tampered.review_required and tampered.reason == "intent_mismatch", "alias remap uses supplied canonical action and detects mismatch")
	var duplicate: Dictionary = fixture.duplicate(true); duplicate.options.append({"alias": "a_accept", "action_id": "share-skill:fixture:metal_repair"})
	_check(not Review.review(raw_accept, duplicate).ok, "duplicate alias fixture rejected")
	var malformed := Review.review("{not-json", fixture)
	_check(not malformed.ok and malformed.reason == "malformed_json", "malformed raw rejected without repair")

func _run_saved_fixture() -> void:
	var contexts_path := "res://../docs/validation/local-npc-dialogue-20260923/contexts.json"
	var raw_path := "res://../docs/validation/local-npc-dialogue-20260923/raw.json"
	var context_hash := FileAccess.get_sha256(contexts_path)
	var raw_hash := FileAccess.get_sha256(raw_path)
	var contexts: Variant = JSON.parse_string(FileAccess.get_file_as_string(contexts_path))
	var raw_batch: Variant = JSON.parse_string(FileAccess.get_file_as_string(raw_path))
	_check(contexts is Dictionary and raw_batch is Dictionary and contexts.fixture_only == true and raw_batch.fixture_only == true, "saved fixture inputs are fixture-only")
	var fixtures := {}
	for fixture in contexts.cases:
		fixtures[fixture.case_id] = fixture
	var seen := {}
	for candidate in raw_batch.cases:
		var case_id: String = candidate.case_id
		seen[case_id] = true
		var review := Review.review(candidate.raw_content, fixtures[case_id])
		_check(review.structural_accepted and review.execution_authorized == false and review.semantic_truth_verification == false, "saved case structurally parses without authorization: " + case_id)
		if case_id == "owner_repair_offer":
			_check(review.reason == "intent_mismatch" and review.expected_intents == ["disclose"], "saved skill disclosure mismatch expects disclose")
		elif case_id == "smith_accept_or_wait":
			_check(review.reason == "intent_mismatch" and review.expected_intents == ["agree"], "saved accept mismatch expects agree")
		elif case_id == "smith_missing_iron":
			_check(review.reason == "intent_mismatch" and review.expected_intents == ["refuse"], "saved reject mismatch expects refuse")
	_check(seen.size() == contexts.cases.size(), "saved fixture case IDs join one-to-one")
	_check(FileAccess.get_sha256(contexts_path) == context_hash and FileAccess.get_sha256(raw_path) == raw_hash, "saved fixture hashes remain unchanged")

func _raw(intent: String, alias: String) -> String:
	return _raw_with_speech(intent, alias, "I will state the bounded proposal.")

func _raw_with_speech(intent: String, alias: String, speech: String) -> String:
	return JSON.stringify({"speech": speech, "intent": intent, "stance": "guarded", "target_id": "shared:smith", "claim_ids": [], "stakes": "The terms remain visible.", "next_action": alias, "confidence": 0.8, "private_thought": "private fixture note"})

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
