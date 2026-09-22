extends SceneTree
## Offline-only validation of Python probe output against exported Turns contexts.
## Raw assistant content is passed to Receipt.parse without repair or rewriting.

const Receipt = preload("res://core/dialogue_receipt.gd")
const MAX_CASES := 3
var input := ""
var contexts := ""
var out := ""

static func validate_documents(data: Variant, exported: Variant) -> Dictionary:
	var batch := _validate_batch(data, "probe")
	if not batch.get("ok", false): return batch
	var source := _validate_batch(exported, "contexts")
	if not source.get("ok", false): return source
	var candidates: Array = batch.cases
	var fixtures: Array = source.cases
	var candidate_ids := _ids(candidates)
	var fixture_ids := _ids(fixtures)
	if candidate_ids.size() != fixture_ids.size(): return {"ok": false, "code": "case_count_mismatch"}
	for case_id in candidate_ids:
		if not fixture_ids.has(case_id): return {"ok": false, "code": "case_id_set_mismatch", "detail": case_id}
	for case_id in fixture_ids:
		if not candidate_ids.has(case_id): return {"ok": false, "code": "case_id_set_mismatch", "detail": case_id}
	var by_id := {}
	for fixture in fixtures: by_id[fixture.case_id] = fixture
	var results: Array = []
	for candidate in candidates:
		var case_id: String = candidate.case_id
		if not candidate.has("raw_content") or not candidate.raw_content is String:
			return {"ok": false, "code": "raw_content_invalid", "detail": case_id}
		var fixture: Dictionary = by_id[case_id]
		if not fixture.has("context") or not fixture.context is Dictionary:
			return {"ok": false, "code": "context_invalid", "detail": case_id}
		var parsed: Dictionary = Receipt.parse(candidate.raw_content, fixture.context)
		results.append({"case_id": case_id, "accepted": parsed.get("ok", false), "reason": parsed.get("code", "")})
	return {"ok": true, "results": results}

static func _validate_batch(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary or value.get("fixture_only") != true: return {"ok": false, "code": label + "_fixture_required"}
	var cases: Variant = value.get("cases")
	if not cases is Array or cases.is_empty() or cases.size() > MAX_CASES: return {"ok": false, "code": label + "_cases_invalid"}
	var seen := {}
	for item in cases:
		if not item is Dictionary or not item.has("case_id") or not item.case_id is String or item.case_id.is_empty(): return {"ok": false, "code": label + "_case_invalid"}
		if seen.has(item.case_id): return {"ok": false, "code": "duplicate_case_id", "detail": item.case_id}
		seen[item.case_id] = true
	return {"ok": true, "cases": cases}

static func _ids(cases: Array) -> Array:
	var result: Array = []
	for item in cases: result.append(item.case_id)
	return result

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input = arg.trim_prefix("--input=")
		elif arg.begins_with("--contexts="): contexts = arg.trim_prefix("--contexts=")
		elif arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if input.is_empty() or contexts.is_empty() or out.is_empty() or not FileAccess.file_exists(input) or not FileAccess.file_exists(contexts) or FileAccess.file_exists(out): quit(2); return
	var checked := validate_documents(JSON.parse_string(FileAccess.get_file_as_string(input)), JSON.parse_string(FileAccess.get_file_as_string(contexts)))
	if not checked.get("ok", false): print(JSON.stringify(checked)); quit(2); return
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify({"fixture_only": true, "semantic_truth_verification": false, "results": checked.results}, "  ", true, true)); file.close()
	print(JSON.stringify({"suite": "validate_local_dialogue_proposals", "results": checked.results.size(), "paid_calls": 0})); quit(0)
