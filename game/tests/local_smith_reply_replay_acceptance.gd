extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	var scene = load("res://scenes/local_smith_reply_replay.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	_check(node.fields.get("evidence_ok") == true, "saved_evidence_accepted")
	_check(node.fields.get("fixture_only") == true, "fixture_label")
	_check(node.fields.get("raw_next_action") == "contract:accept:trade_contract_fixture:offer", "raw_canonical_action")
	_check(node.fields.get("required_alias") == "a16", "independent_alias_join")
	_check(node.fields.get("expected_intents") == ["agree"], "expected_intent")
	_check(node.fields.get("structural_result") == "rejected" and node.fields.get("reason") == "unsupported_next_action", "receipt_matches_saved_review")
	_check(node.fields.get("result_code") == "provider_error" and node.fields.get("last_event") == "offer_repair" and node.fields.get("outcome") == "review_rejected" and node.fields.get("provider_id") == "local:ollama" and node.fields.get("model") == "qwen3:8b" and node.fields.get("speech_delivery") == "proposal_not_delivered", "actual_report_fields")
	_check(node.fields.get("model_returned") == true, "recorded_model_returned")
	var rows = node.get_node("EvidenceMargin/EvidenceScroll/EvidenceRows")
	_check(rows.get_node("raw_speech").text == "raw_speech: I can repair the edge for 2 Col. Do you want me to accept the contract?" and rows.get_node("raw_intent").text == "raw_intent: ask" and rows.get_node("raw_next_action").text == "raw_next_action: contract:accept:trade_contract_fixture:offer" and rows.get_node("reason").text == "reason: unsupported_next_action", "visible_public_labels")
	_check(rows.get_node("public_proposal_only").text.contains("proposal only") and not rows.get_children().any(func(child): return child.text.contains("private_thought") or child.text.contains("carpenter has offered")), "private_thought_absent")
	var contexts = node._read_json(node.C)
	var response = node._read_json(node.R)
	var report = node._read_json(node.P)
	response.cases[0].raw_content = "{\"speech\":\"tampered\"}"
	_check(node._fields_from_evidence(contexts, response, report).get("evidence_ok") == false, "tampered_raw_fails_closed")
	print(JSON.stringify({"suite":"local_smith_reply_replay_acceptance","ok":failures.is_empty(),"checks":11,"failures":failures,"fixture_only":true,"world_calls":0,"model_calls":0}))
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
