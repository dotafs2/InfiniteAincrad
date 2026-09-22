extends Control
## Read-only replay of one saved local Smith reply. It never opens TownRuntime.
const C := "res://../docs/validation/local-smith-reply-20260923/contexts.json"
const R := "res://../docs/validation/local-smith-reply-20260923/response.json"
const P := "res://../docs/validation/local-smith-reply-20260923/report.json"
const Receipt = preload("res://core/dialogue_receipt.gd")
const Review = preload("res://agents/dialogue_proposal_review.gd")
const SMITH := "shared:smith"
var fields := {}
var _capture_dir := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	fields = _fields_from_evidence(_read_json(C), _read_json(R), _read_json(P))
	_build()
	if not _capture_dir.is_empty(): _capture.call_deferred()

func _read_json(path: String) -> Variant:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute): return null
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(absolute)) == OK else null

func _fields_from_evidence(contexts: Variant, response: Variant, report: Variant) -> Dictionary:
	var result := {"evidence_ok":false,"fixture_only":false,"public_proposal_only":"proposal only; no speech delivered or action executed by replay","raw_speech":"","raw_intent":"","raw_next_action":"","required_alias":"","expected_intents":[],"structural_result":"invalid_evidence","reason":"invalid_evidence","result_code":"","last_event":"","outcome":"","provider_id":"","model":"","speech_delivery":"","model_returned":false,"private_thought_exposed":false}
	if not contexts is Dictionary or not response is Dictionary or not report is Dictionary: return result
	if contexts.get("fixture_only") != true or response.get("fixture_only") != true or report.get("fixture_only") != true: return result
	if not contexts.get("cases") is Array or contexts.cases.size() != 1 or not response.get("cases") is Array or response.cases.size() != 1: return result
	var fixture = contexts.cases[0]
	var reply = response.cases[0]
	if not fixture is Dictionary or not reply is Dictionary or fixture.get("case_id") != "smith_reply" or reply.get("case_id") != "smith_reply" or fixture.get("resident_id") != SMITH or not fixture.get("context") is Dictionary or not fixture.get("options") is Array or not reply.get("raw_content") is String: return result
	var raw: String = reply.raw_content
	if report.get("raw_sha256", "") != raw.sha256_text(): return result
	var aliases := {}
	var canonical := {}
	for option in fixture.options:
		if not option is Dictionary or not option.get("alias") is String or not option.get("action_id") is String or option.alias.is_empty() or option.action_id.is_empty() or aliases.has(option.alias) or canonical.has(option.action_id): return result
		aliases[option.alias] = option.action_id
		canonical[option.action_id] = option.alias
	var action_ids = fixture.context.get("action_ids", null)
	if not action_ids is Array or action_ids.size() != aliases.size(): return result
	var seen := {}
	for alias in action_ids:
		if not alias is String or not aliases.has(alias) or seen.has(alias): return result
		seen[alias] = true
	var decoded := JSON.new()
	if decoded.parse(raw) != OK or not decoded.data is Dictionary: return result
	var candidate: Dictionary = decoded.data
	# Only three raw public strings are replayed. private_thought is never copied.
	if candidate.get("speech") is String and candidate.speech.length() <= Receipt.MAX_SPEECH: result.raw_speech = candidate.speech
	if candidate.get("intent") is String and candidate.intent.length() <= 32: result.raw_intent = candidate.intent
	if candidate.get("next_action") is String and candidate.next_action.length() <= Receipt.MAX_NEXT_ACTION: result.raw_next_action = candidate.next_action
	if result.raw_speech.is_empty() or result.raw_intent.is_empty() or result.raw_next_action.is_empty(): return result
	if not canonical.has(result.raw_next_action): return result
	result.required_alias = canonical[result.raw_next_action]
	result.expected_intents = Review._expected_intents(result.raw_next_action)
	var parsed: Dictionary = Receipt.parse(raw, fixture.context)
	var saved_review = report.get("proposal_review", {})
	if not saved_review is Dictionary or saved_review.get("reason", null) != ("accepted" if parsed.get("ok", false) else parsed.get("code", "")) or bool(saved_review.get("structural_accepted", false)) != bool(parsed.get("ok", false)): return result
	for key in ["result_code", "actual_event", "outcome", "provider_id", "speech_delivery"]:
		if not report.get(key) is String: return result
	if not report.get("model_returned") is bool: return result
	var metrics = report.get("response_metrics", {})
	if not metrics is Dictionary or not metrics.get("model") is String: return result
	result.fixture_only = true
	result.evidence_ok = true
	result.structural_result = "accepted" if parsed.get("ok", false) else "rejected"
	result.reason = str(saved_review.reason)
	result.result_code = report.result_code
	result.last_event = report.actual_event
	result.outcome = report.outcome
	result.provider_id = report.provider_id
	result.model = metrics.model
	result.speech_delivery = report.speech_delivery
	result.model_returned = report.model_returned
	return result

func _build() -> void:
	var margin := MarginContainer.new()
	margin.name = "EvidenceMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "EvidenceScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "EvidenceRows"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for key in ["evidence_ok", "fixture_only", "public_proposal_only", "provider_id", "model", "speech_delivery", "raw_speech", "raw_intent", "raw_next_action", "required_alias", "expected_intents", "structural_result", "reason", "result_code", "last_event", "outcome", "model_returned"]:
		var label := Label.new()
		label.name = key
		label.text = "%s: %s" % [key, fields.get(key, "")]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 16)
		box.add_child(label)

func _capture() -> void:
	if not _capture_dir.is_absolute_path() or not fields.get("evidence_ok", false):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var png_path := _capture_dir.path_join("local_smith_reply_replay.png")
	var saved := image != null and image.get_width() > 0 and image.save_png(png_path) == OK
	var public_record := {"fixture_only":fields.fixture_only,"evidence_ok":fields.evidence_ok,"public_proposal_only":fields.public_proposal_only,"raw_speech":fields.raw_speech,"raw_intent":fields.raw_intent,"raw_next_action":fields.raw_next_action,"required_alias":fields.required_alias,"expected_intents":fields.expected_intents,"structural_result":fields.structural_result,"reason":fields.reason,"provider_id":fields.provider_id,"model":fields.model,"speech_delivery":fields.speech_delivery,"result_code":fields.result_code,"last_event":fields.last_event,"outcome":fields.outcome,"model_returned":fields.model_returned,"screenshot_saved":saved}
	var handle := FileAccess.open(_capture_dir.path_join("local_smith_reply_replay_capture.json"), FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(public_record, "  ", true, true))
		handle.close()
	get_tree().quit(0 if saved and handle != null else 2)
