extends RefCounted
## Test-only wrapper combining Receipt validation, optional intent review, and the existing alias gate.
## It authorizes only a bounded fixture decision; it never executes a world action.

const Base = preload("res://agents/dialogue_fixture_adapter.gd")
const Review = preload("res://agents/dialogue_proposal_review.gd")

static func prepare(raw: Variant, view: Dictionary, offered_actions: Dictionary,
		target_ids: Array = [], claim_ids: Array = []) -> Dictionary:
	if not raw is String:
		return {"ok": false, "code": "invalid_raw", "execution_authorized": false}
	var fixture := _fixture(view, offered_actions, target_ids, claim_ids)
	var reviewed: Dictionary = Review.review(raw, fixture)
	if not reviewed.get("ok", false) or not reviewed.get("structural_accepted", false) or reviewed.get("review_required", true):
		return {"ok": false, "code": "dialogue_review_required", "review": _public_review(reviewed), "execution_authorized": false}
	var validated: Dictionary = Base.validate(raw, view, offered_actions, target_ids, claim_ids)
	if not validated.get("ok", false):
		return {"ok": false, "code": validated.get("code", "invalid_dialogue_receipt"), "review": _public_review(reviewed), "execution_authorized": false}
	return {"ok": true, "raw": raw, "alias": reviewed.alias, "action_id": reviewed.action_id,
		"review": _public_review(reviewed), "execution_authorized": false}

static func authorize(prepared: Dictionary, current_view: Dictionary, current_offered_actions: Dictionary,
		caller_authorized: bool, reason: String, current_target_ids: Array = [], current_claim_ids: Array = []) -> Dictionary:
	if not caller_authorized:
		return {"ok": false, "code": "caller_not_authorized", "execution_authorized": false}
	if reason.is_empty() or not prepared is Dictionary or not prepared.has("raw") or not prepared.raw is String:
		return {"ok": false, "code": "invalid_prepared_dialogue", "execution_authorized": false}
	var reviewed: Dictionary = Review.review(prepared.raw, _fixture(current_view, current_offered_actions, current_target_ids, current_claim_ids))
	if not reviewed.get("ok", false) or not reviewed.get("structural_accepted", false) or reviewed.get("review_required", true):
		return {"ok": false, "code": "dialogue_review_required", "review": _public_review(reviewed), "execution_authorized": false}
	if str(reviewed.alias) != str(prepared.get("alias", "")) or str(reviewed.action_id) != str(prepared.get("action_id", "")):
		return {"ok": false, "code": "stale_dialogue_review", "review": _public_review(reviewed), "execution_authorized": false}
	# Rebuild a minimal prepared record so editable caller fields cannot influence Base.authorize.
	var bounded := {"ok": true, "alias": reviewed.alias, "action_id": reviewed.action_id}
	var decision: Dictionary = Base.authorize(bounded, current_view, current_offered_actions, true, reason)
	decision["execution_authorized"] = false
	decision["decision_authorized"] = decision.get("ok", false)
	decision["review"] = _public_review(reviewed)
	return decision

static func _fixture(view: Dictionary, offered_actions: Dictionary, target_ids: Array, claim_ids: Array) -> Dictionary:
	var options: Array = []
	for alias in offered_actions:
		options.append({"alias": alias, "action_id": offered_actions[alias]})
	return {"context": {"target_ids": target_ids, "claim_ids": claim_ids, "action_ids": view.get("available_actions", [])}, "options": options}

static func _public_review(reviewed: Dictionary) -> Dictionary:
	var result := reviewed.duplicate(true)
	result.erase("private_thought")
	return result
