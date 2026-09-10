extends Control
## Presentation only. Resident choices and every mutation pass through the kernel.
const Kernel = preload("res://core/world_kernel.gd")
const Courtyard = preload("res://ui/well_courtyard.gd")
const INK := Color("243946")
const MUTED := Color("526975")
const PAPER := Color("edf1ed")
const SURFACE := Color("f7f8f3")
const ACCENT := Color("31697b")

var world = Kernel.new()
var manifest: Dictionary = {}
var save_path := "user://capability-trial/world.json"
var courtyard: Control
var resident_text: RichTextLabel
var history_text: RichTextLabel
var operator_text: RichTextLabel
var feedback: Label
var phase_label: Label
var next_button: Button
var auto_button: Button
var install_button: Button
var validate_button: Button
var disable_button: Button
var save_button: Button
var tabs: TabContainer
var timer: Timer
var running := false
var steps_left := 0
var writable := true
var verified := false
var approval_id := ""
var command_sequence := 0
var smoke_directory := ""
var reduced_motion := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path="):
			save_path = argument.trim_prefix("--save-path=")
		elif argument.begins_with("--ui-smoke="):
			smoke_directory = argument.trim_prefix("--ui-smoke=")
		elif argument == "--reduced-motion":
			reduced_motion = true
	_build_ui()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	var lock_result: Dictionary = world.acquire_writer(save_path)
	if not lock_result.get("ok", false):
		writable = false
		_feedback("该测试存档已有写入者，无法打开：" + _result_text(lock_result), true)
		_refresh()
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://capabilities/well_bucket.v1.json"))
	if parsed is Dictionary:
		manifest = parsed
	var result: Dictionary
	if FileAccess.file_exists(save_path):
		result = world.load_from(save_path)
	else:
		result = world.create_fixture()
		if result.get("ok", false):
			result = world.save_to(save_path)
	writable = result.get("ok", false)
	if writable:
		var request_path := ProjectSettings.globalize_path("user://capability-trial/resident-decision-request.json")
		DirAccess.make_dir_recursive_absolute(request_path.get_base_dir())
		world.export_resident_decision_request(request_path)
	if writable:
		_feedback("独立测试世界已就绪。让居民先观察井边。")
	else:
		_feedback("无法打开测试存档：%s。未重置已有世界。" % _result_text(result), true)
	_refresh()
	get_tree().auto_accept_quit = false
	if not smoke_directory.is_empty():
		call_deferred("_smoke_test")

func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	var display_font := SystemFont.new()
	display_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Serif CJK SC", "Georgia"])
	var theme_resource := Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 16
	theme_resource.set_color("font_color", "Label", INK)
	theme_resource.set_color("default_color", "RichTextLabel", INK)
	theme_resource.set_color("font_color", "Button", INK)
	theme_resource.set_color("font_hover_color", "Button", INK)
	theme_resource.set_color("font_pressed_color", "Button", INK)
	theme_resource.set_stylebox("normal", "Button", _box(Color("e0e8e6"), 8))
	theme_resource.set_stylebox("hover", "Button", _box(Color("d1e1e3"), 8))
	theme_resource.set_stylebox("pressed", "Button", _box(Color("b9d3da"), 8))
	theme_resource.set_stylebox("disabled", "Button", _box(Color("e8ece8"), 8))
	var focus := _box(Color(0, 0, 0, 0), 8)
	focus.set_border_width_all(3)
	focus.border_color = ACCENT
	theme_resource.set_stylebox("focus", "Button", focus)
	theme = theme_resource
	var background := ColorRect.new()
	background.color = PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_group)
	var eyebrow := _label("INFINITE AINCRAD  /  CAPABILITY TRIAL", 13, MUTED)
	title_group.add_child(eyebrow)
	var title := _label("井边的一天", 34)
	title.add_theme_font_override("font", display_font)
	title_group.add_child(title)
	var badge := _label("独立人工场景\n离线规则决策 · 零付费模型调用", 15, MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(badge)
	var separator := HSeparator.new()
	root.add_child(separator)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	phase_label = _label("观察需要 → 验证能力 → 自行使用 → 保存延续", 17)
	left.add_child(phase_label)
	courtyard = Courtyard.new()
	courtyard.motion = not reduced_motion
	courtyard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	courtyard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(courtyard)
	var caption := _label("一个居民，一口井。已经发生的事，不随能力停用消失。", 16, MUTED)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(caption)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	left.add_child(controls)
	next_button = _button("居民行动一次", _step)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.add_theme_stylebox_override("normal", _box(ACCENT, 8))
	next_button.add_theme_color_override("font_color", Color.WHITE)
	controls.add_child(next_button)
	auto_button = _button("连续观察", _toggle_auto)
	controls.add_child(auto_button)
	var motion_toggle := CheckButton.new()
	motion_toggle.text = "减少动态"
	motion_toggle.button_pressed = reduced_motion
	motion_toggle.toggled.connect(func(value: bool):
		courtyard.motion = not value
		if value:
			courtyard.pulse = 0
			courtyard.set_process(false)
			courtyard.queue_redraw())
	left.add_child(motion_toggle)
	tabs = TabContainer.new()
	tabs.custom_minimum_size.x = 420
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", _box(SURFACE, 10))
	body.add_child(tabs)
	var resident_panel := _tab("居民所见")
	resident_text = _rich()
	resident_panel.add_child(resident_text)
	var operator_panel := _tab("开发者 GM")
	operator_text = _rich()
	operator_panel.add_child(operator_text)
	validate_button = _button("检查需求与能力包", _validate)
	operator_panel.add_child(validate_button)
	install_button = _button("安装吊桶取水 v1", _install)
	operator_panel.add_child(install_button)
	disable_button = _button("停用取水能力", _disable)
	operator_panel.add_child(disable_button)
	var deny := _button("验收：拒绝居民安装请求", _reject_install)
	operator_panel.add_child(deny)
	save_button = _button("保存并重读测试存档", _save_reload)
	operator_panel.add_child(save_button)
	var history_panel := _tab("事实记录")
	history_text = _rich()
	history_panel.add_child(history_text)
	feedback = _label("", 16)
	feedback.custom_minimum_size.y = 48
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(feedback)
	root.add_child(_label("测试身份未迁移原档。这里没有 Kimi 决策、旧回复回放或无人监督开发。", 13, MUTED))
	timer = Timer.new()
	timer.wait_time = 1.6
	timer.timeout.connect(_step)
	add_child(timer)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(value: String, font_size: int, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func _button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 44
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	return result

func _tab(title: String) -> VBoxContainer:
	var panel := MarginContainer.new()
	panel.name = title
	for edge in ["left", "right", "top", "bottom"]:
		panel.add_theme_constant_override("margin_" + edge, 14)
	tabs.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column

func _rich() -> RichTextLabel:
	var result := RichTextLabel.new()
	result.bbcode_enabled = true
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.selection_enabled = true
	result.add_theme_constant_override("normal_font_size", 16)
	return result

func _command_id(prefix: String) -> String:
	command_sequence += 1
	return "%s:%d:%d" % [prefix, Time.get_ticks_usec(), command_sequence]

func _result_text(result: Dictionary) -> String:
	return str(result.get("code", result.get("message", result)))

func _feedback(message: String, failed: bool = false) -> void:
	feedback.text = message
	feedback.add_theme_color_override("font_color", Color("9b3f32") if failed else ACCENT)

func _persist() -> bool:
	var result: Dictionary = world.save_to(save_path)
	if not result.get("ok", false):
		writable = false
		_stop_auto()
		_feedback("保存失败，已停止继续操作：" + _result_text(result), true)
	return result.get("ok", false)

func _step() -> void:
	if not writable:
		return
	var result: Dictionary = world.resident_step()
	if _persist():
		_feedback("居民按自己的观察作出规则选择：" + _result_text(result))
	steps_left -= 1
	if steps_left <= 0 or not result.get("ok", false):
		_stop_auto()
	_refresh()

func _toggle_auto() -> void:
	if running:
		_stop_auto()
	else:
		running = true
		steps_left = 4
		auto_button.text = "暂停观察"
		timer.start()
		_step()

func _stop_auto() -> void:
	running = false
	timer.stop()
	auto_button.text = "连续观察"

func _validate() -> void:
	var result: Dictionary = world.validate_manifest(manifest)
	verified = result.get("ok", false)
	if verified:
		var need = world.snapshot().get("residents", {}).get("fixture:luna", {}).get("needs", {}).get("capability_request", null)
		if need != null and need.get("status", "") == "open":
			approval_id = _command_id("gm-review")
			var review: Dictionary = world.gm_review_need(approval_id, "approve", manifest.get("capability_id", ""), "The resident has a persistent access need; this package is the smallest reviewed fix.")
			verified = review.get("ok", false)
			result = review if not verified else {"ok": true, "code": "manifest_valid_and_need_approved", "approval_id": approval_id, "provenance": "gm_review"}
		else:
			verified = false
			result = {"ok": false, "code": "gm_need_missing"}
	_feedback("能力包与需求检查：" + _result_text(result), not verified)
	_refresh()

func _install() -> void:
	_stop_auto()
	var result: Dictionary = world.gm_install(manifest, _command_id("install"), approval_id)
	if result.get("ok", false):
		_persist()
	_feedback("安装结果：" + _result_text(result), not result.get("ok", false))
	_refresh()

func _disable() -> void:
	_stop_auto()
	var result: Dictionary = world.gm_disable(_command_id("disable"))
	if result.get("ok", false):
		_persist()
	_feedback("停用结果：" + _result_text(result), not result.get("ok", false))
	_refresh()

func _reject_install() -> void:
	var before: Dictionary = world.snapshot()
	var result: Dictionary = world.resident_command({"action": "install_plugin", "command_id": _command_id("resident-denial"), "actor": "gm"})
	_feedback("居民安装请求：%s。世界未变化：%s" % [_result_text(result), str(before == world.snapshot())])
	_refresh()

func _save_reload() -> void:
	_stop_auto()
	if not _persist():
		_refresh()
		return
	var result: Dictionary = world.load_from(save_path)
	writable = result.get("ok", false)
	_feedback("保存并重读：%s。真正冷恢复请关闭后重新启动。" % _result_text(result), not writable)
	_refresh()

func _refresh() -> void:
	# Field formatting is kept here; the NPC policy receives resident_view only.
	var state: Dictionary = world.snapshot()
	var view: Dictionary = world.resident_view()
	resident_text.text = "[b]Luna · 测试居民[/b]\n\n" + _display_view(view)
	history_text.text = "[b]稳定核心记录的事实[/b]\n\n" + JSON.stringify(state.get("events", []), "  ")
	operator_text.text = "[b]开发者承担 GM[/b]\n\n人工设置的井边障碍，仅验证技术闭环。先让居民表达需要，再检查并安装有限的能力包。\n\n包：well_bucket / v1\n只启用已审核的取水规则；不加载任意代码。\n\n居民请求 JSON：\n%s\n\n测试存档：\n%s\n\n[b]核心状态[/b]\n%s" % [ProjectSettings.globalize_path("user://capability-trial/resident-decision-request.json"), ProjectSettings.globalize_path(save_path), JSON.stringify(state.get("capability", state.get("plugins", {})), "  ")]
	_update_courtyard(state, view)
	next_button.disabled = not writable
	auto_button.disabled = not writable
	validate_button.disabled = not writable
	install_button.disabled = not writable or not verified
	disable_button.disabled = not writable
	save_button.disabled = not writable

func _display_view(view: Dictionary) -> String:
	var text := ""
	for key in view:
		var names := {"identity": "我是谁", "needs": "我的需要", "observations": "我看见", "memories": "我的经历", "actions": "我可以做", "available_actions": "我可以做", "inventory": "我随身带着"}
		text += "[b]%s[/b]\n%s\n\n" % [names.get(key, key), JSON.stringify(view[key], "  ")]
	return text

func _update_courtyard(state: Dictionary, _view: Dictionary) -> void:
	var well: Dictionary = state.get("world", {})
	var resident: Dictionary = state.get("residents", {}).get("fixture:luna", {})
	var inventory: Dictionary = resident.get("inventory", {})
	var capability: Dictionary = state.get("plugins", {}).get("well_bucket", {})
	courtyard.update_world(int(well.get("well_water", 0)), int(inventory.get("water", 0)), int(resident.get("consumed", {}).get("water", 0)), capability.get("status", "") == "enabled", "每次变化都来自已验证的行动回执。")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_stop_auto()
		if writable:
			_persist()
		if world.has_method("release_writer"):
			world.release_writer(save_path)
		get_tree().quit()

func _smoke_test() -> void:
	if not writable:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(smoke_directory)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(smoke_directory.path_join("ui-before.png"))
	next_button.pressed.emit()
	tabs.current_tab = 1
	validate_button.pressed.emit()
	install_button.pressed.emit()
	next_button.pressed.emit()
	next_button.pressed.emit()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(smoke_directory.path_join("ui-used.png"))
	disable_button.pressed.emit()
	save_button.pressed.emit()
	tabs.current_tab = 0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(smoke_directory.path_join("ui-disabled-restored.png"))
	var evidence := FileAccess.open(smoke_directory.path_join("ui-state.json"), FileAccess.WRITE)
	evidence.store_string(JSON.stringify(world.snapshot(), "  "))
	evidence.close()
	print("UI_SMOKE_COMPLETE")
	_notification(NOTIFICATION_WM_CLOSE_REQUEST)
