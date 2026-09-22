extends Control
## Offline review of saved local dialogue proposals. No world state or network access.

const CONTEXTS_PATH := "res://../docs/validation/local-npc-dialogue-20260923/contexts.json"
const RAW_PATH := "res://../docs/validation/local-npc-dialogue-20260923/raw.json"
const REVIEW_PATH := "res://agents/dialogue_proposal_review.gd"
const BatchValidator = preload("res://tests/validate_local_dialogue_proposals.gd")

var cases: Array = []
var reviews: Array = []
var case_index := 0
var status := "Loading saved local output..."
var _body: VBoxContainer
var _case_label: Label
var _status_label: Label
var _capture_dir := ""
var _capture_case := -1
var _capture_pending := false

func _ready() -> void:
	_parse_command_line()
	_build_ui()
	_load_saved_evidence()
	if not _capture_dir.is_empty():
		if _capture_case >= 0 and _capture_case < cases.size():
			_select_case(_capture_case)
		else:
			status = "Capture unavailable: --case must be 0, 1, or 2."
		_capture_pending = true
		_call_deferred_capture()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_N or event.keycode == KEY_RIGHT:
		_select_case(case_index + 1)
	elif event.keycode == KEY_P or event.keycode == KEY_LEFT:
		_select_case(case_index - 1)

func _parse_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--case="):
			_capture_case = int(arg.trim_prefix("--case="))

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 38)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "DIALOGUE PROPOSAL REVIEW"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var banner := Label.new()
	banner.text = "SAVED LOCAL OUTPUT  •  NOT EXECUTED  •  INTENT CHECK ONLY"
	banner.add_theme_color_override("font_color", Color("f4c95d"))
	banner.add_theme_font_size_override("font_size", 21)
	column.add_child(banner)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_status_label)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	column.add_child(nav)
	var previous := Button.new()
	previous.text = "Previous (P)"
	previous.pressed.connect(func(): _select_case(case_index - 1))
	nav.add_child(previous)
	var next := Button.new()
	next.text = "Next (N)"
	next.pressed.connect(func(): _select_case(case_index + 1))
	nav.add_child(next)
	_case_label = Label.new()
	_case_label.add_theme_font_size_override("font_size", 20)
	nav.add_child(_case_label)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 9)
	column.add_child(_body)

func _load_saved_evidence() -> void:
	cases.clear()
	reviews.clear()
	var contexts: Variant = _read_json(CONTEXTS_PATH)
	var raw: Variant = _read_json(RAW_PATH)
	if not contexts is Dictionary or not raw is Dictionary:
		status = "Review unavailable: saved evidence could not be read."
		_refresh()
		return
	var checked: Dictionary = BatchValidator.validate_documents(raw, contexts)
	if not checked.get("ok", false):
		status = "Review unavailable: saved evidence rejected (%s)." % str(checked.get("code", "invalid_metadata"))
		_refresh()
		return
	var context_cases: Array = contexts.get("cases")
	var raw_cases: Array = raw.get("cases")
	if context_cases.size() != 3 or raw_cases.size() != 3:
		status = "Review unavailable: expected exactly three saved cases."
		_refresh()
		return
	var reviewer = load(REVIEW_PATH)
	if reviewer == null:
		status = "Review unavailable: structural review contract is missing."
		_refresh()
		return
	var raw_by_id := {}
	for raw_case in raw_cases:
		if raw_case is Dictionary:
			raw_by_id[raw_case.get("case_id", "")] = raw_case
	for fixture in context_cases:
		if not fixture is Dictionary or not raw_by_id.has(fixture.get("case_id", "")):
			status = "Review unavailable: context/raw case IDs do not match."
			cases.clear()
			reviews.clear()
			_refresh()
			return
		var saved: Dictionary = raw_by_id[fixture.case_id]
		var raw_content: String = saved.get("raw_content", "")
		cases.append({"fixture": fixture, "raw_content": raw_content, "case_id": fixture.case_id})
		reviews.append(reviewer.review(raw_content, fixture))
	status = "Loaded 3 saved local proposals; NOT EXECUTED."
	_refresh()

func _read_json(path: String) -> Variant:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(absolute))

func _select_case(index: int) -> void:
	if cases.is_empty():
		return
	case_index = posmod(index, cases.size())
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_status_label):
		return
	_status_label.text = status
	if cases.is_empty() or reviews.size() != cases.size():
		_case_label.text = "No review case available"
		_clear_body()
		return
	_case_label.text = "Case %d / %d" % [case_index + 1, cases.size()]
	_clear_body()
	var fixture: Dictionary = cases[case_index].fixture
	var result: Dictionary = reviews[case_index]
	_add_row("Case", str(cases[case_index].case_id))
	_add_row("Spoken line", _safe_text(result.get("speech", ""), "No spoken line"))
	_add_row("Declared intent", _safe_text(result.get("declared_intent", ""), "No declared intent"))
	var expected: Array = result.get("expected_intents", []) if result.get("expected_intents", []) is Array else []
	_add_row("Expected intent", ", ".join(expected) if not expected.is_empty() else "No expected intent")
	_add_row("Canonical selected action", _safe_text(result.get("action_id", ""), "No canonical action"))
	var structural := bool(result.get("structural_accepted", false))
	var needs_review := bool(result.get("review_required", true))
	_add_row("Structural check", "PASS" if structural else "REJECTED")
	_add_row("Intent review", "REVIEW REQUIRED" if needs_review else "DECLARED INTENT COMPATIBLE")
	_add_row("Reason", _safe_text(result.get("reason", ""), "No review result"))
	_add_row("Execution", "not_attempted" if result.get("execution", "") == "not_attempted" else "UNAVAILABLE")
	var authorization: Variant = result.get("execution_authorized", null)
	_add_row("Execution authorized", str(authorization) if authorization is bool else "UNKNOWN")
	_add_row("Source", "Saved local output; raw evidence unchanged")

func _safe_text(value: Variant, fallback: String) -> String:
	var text := str(value)
	return fallback if text.is_empty() else text

func _clear_body() -> void:
	for child in _body.get_children():
		child.queue_free()

func _add_row(label_text: String, value: String) -> void:
	var label := Label.new()
	label.text = "%s: %s" % [label_text, value]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20 if label_text == "Spoken line" else 18)
	_body.add_child(label)

func _call_deferred_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_replay_frame()

func _capture_replay_frame() -> void:
	if not _capture_pending or _capture_dir.is_empty():
		return
	_capture_pending = false
	var valid_case := _capture_case >= 0 and _capture_case < cases.size() and cases.size() == reviews.size()
	var evidence := {"screenshot_saved": false, "case_index": case_index if valid_case else -1, "case_id": cases[case_index].case_id if valid_case else "", "status": status, "capture_valid_case": valid_case}
	if DisplayServer.get_name() != "headless" and valid_case:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		var filename := "%s_review.png" % str(cases[case_index].case_id)
		evidence.screenshot_saved = image.save_png(_capture_dir.path_join(filename)) == OK
	if valid_case:
		var review: Dictionary = reviews[case_index]
		evidence.review = {"ok": review.get("ok", false), "structural_accepted": review.get("structural_accepted", false), "review_required": review.get("review_required", true), "reason": review.get("reason", ""), "alias": review.get("alias", ""), "action_id": review.get("action_id", ""), "declared_intent": review.get("declared_intent", ""), "expected_intents": review.get("expected_intents", []), "speech": review.get("speech", ""), "execution": review.get("execution", "not_attempted"), "semantic_truth_verification": review.get("semantic_truth_verification", false)}
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var evidence_file := _capture_dir.path_join("review_capture.json")
	if valid_case:
		evidence.review["execution_authorized"] = reviews[case_index].get("execution_authorized", null)
	var handle := FileAccess.open(evidence_file, FileAccess.WRITE)
	if handle:
		handle.store_string(JSON.stringify(evidence, "  "))
		handle.close()
	get_tree().quit(0 if handle != null and valid_case and (DisplayServer.get_name() == "headless" or evidence.screenshot_saved) else 2)
