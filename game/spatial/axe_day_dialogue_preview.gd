extends Node3D

## Isolated visual replay of the authored axe-day fixture. It never loads the production
## town and never turns dialogue into a world mutation. The runner is loaded dynamically so
## this preview remains inspectable while the sibling runner worker is still landing.

const RESIDENT := preload("res://spatial/trial_resident.gd")
const CARPENTER := "shared:carpenter"
const SMITH := "shared:smith"

var _carpenter: Node3D
var _smith: Node3D
var _steps: Array = []
var _step_index := -1
var _mode := "success"
var _paused := false
var _capture_dir := ""
var _capture_step := -1
var _capture_done := false
var _running := false
var _capture_frames := 0
var _result: Dictionary = {}
var _status: Label
var _speech: Label
var _details: Label
var _controls: Label
var _mode_label: Label
var _yard_materials: Dictionary = {}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=") if arg.trim_prefix("--mode=") in ["success", "refusal"] else "success"
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--capture-step="):
			_capture_step = int(arg.trim_prefix("--capture-step="))
	_build_yard()
	_build_residents()
	_build_ui()
	call_deferred("_run_fixture")

func _process(_delta: float) -> void:
	if _capture_dir.is_empty() or _result.is_empty() or _capture_step >= 0:
		return
	_capture_frames += 1
	if _capture_frames < 12:
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var image = null
	if DisplayServer.get_name() != "headless":
		var viewport_texture := get_viewport().get_texture()
		image = viewport_texture.get_image() if viewport_texture != null else null
	var image_path := _capture_dir.path_join("axe_day_dialogue_preview.png")
	var saved: bool = image != null and image.save_png(image_path) == OK
	var evidence := _result.duplicate(true)
	evidence["screenshot_saved"] = saved
	evidence["mode"] = _mode
	var file := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "  "))
		file.close()
	print(JSON.stringify(evidence))
	get_tree().quit(0 if bool(_result.get("ok", false)) else 1)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_N:
			_next_step()
		KEY_R:
			_replay()
		KEY_S:
			_start_mode("success")
		KEY_F:
			_start_mode("refusal")

func _run_fixture() -> void:
	if _running:
		return
	_running = true
	var runner_script = load("res://demo/axe_day_demo_runner.gd")
	if runner_script == null:
		_fail_preview("runner_missing: res://demo/axe_day_demo_runner.gd")
		_running = false
		return
	var runner = runner_script.new()
	var runner_mode := "missing_iron_refusal" if _mode == "refusal" else "success"
	var response: Dictionary = await runner.run(self, runner_mode)
	_running = false
	_result = response.duplicate(true)
	if not bool(response.get("ok", false)):
		_fail_preview("runner_failed: " + "; ".join(Array(response.get("failures", []))), response)
		return
	_steps = response.get("steps", [])
	_step_index = _capture_step - 1 if _capture_step >= 0 else -1
	_refresh_ui()
	_next_step()

func _start_mode(mode: String) -> void:
	if _running:
		return
	_mode = mode
	_steps = []
	_step_index = -1
	_result = {}
	_refresh_ui()
	call_deferred("_run_fixture")

func _replay() -> void:
	_step_index = -1
	call_deferred("_apply_initial_loadouts")

func _apply_initial_loadouts() -> void:
	_apply_loadouts(false)
	_refresh_ui()
	_next_step()

func _next_step() -> void:
	if _paused or _steps.is_empty() or _step_index + 1 >= _steps.size():
		return
	_step_index += 1
	var step: Dictionary = _steps[_step_index]
	_apply_step(step)
	_refresh_ui()
	if _capture_step == _step_index:
		call_deferred("_capture_replay_frame", _step_index)

func _capture_replay_frame(index: int) -> void:
	if _capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var saved: bool = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var texture := get_viewport().get_texture()
		if texture != null:
			var phase := str(_steps[index].get("phase", "step")) if index >= 0 and index < _steps.size() else "step"
			var filename := "%s_step_%02d.png" % [phase, index]
			saved = texture.get_image().save_png(_capture_dir.path_join(filename)) == OK
	var evidence := _result.duplicate(true)
	evidence["screenshot_saved"] = saved
	evidence["capture_step"] = index
	var file := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "  "))
		file.close()
	_capture_done = true
	get_tree().quit(0 if bool(_result.get("ok", false)) else 1)

func _apply_step(step: Dictionary) -> void:
	var speaker := str(step.get("speaker_id", ""))
	var speaker_node: Node3D = _carpenter if speaker == CARPENTER else _smith if speaker == SMITH else null
	if speaker_node != null:
		speaker_node.set_meta("last_fixture_speech", str(step.get("speech", "")))
	var phase := str(step.get("phase", ""))
	var result_code := str(step.get("result_code", ""))
	var custodian := str(step.get("custodian_id", ""))
	var edge := int(step.get("edge", -1))
	# Custody is authoritative fixture output: every transition clears both right
	# hands, then gives the axe to the named custodian. Edge 100 is supplied data.
	if _carpenter != null:
		_carpenter.call_deferred("set_holds_axe", custodian == CARPENTER, custodian == CARPENTER and edge >= 100)
	if _smith != null:
		_smith.call_deferred("set_holds_axe", custodian == SMITH, custodian == SMITH and edge >= 100)
		_smith.call_deferred("equip_item", "hammer", "left")

func _apply_loadouts(repaired: bool) -> void:
	if _carpenter != null:
		_carpenter.set_holds_axe(true, repaired)
	if _smith != null:
		_smith.set_holds_axe(false)
		_smith.equip_item("hammer", "left")

func _fail_preview(message: String, supplied: Dictionary = {}) -> void:
	if supplied.is_empty():
		_result = {"ok": false, "mode": _mode, "scripted": true, "source_unchanged": null, "steps": [], "failures": [message], "paid_calls": null}
	else:
		_result = supplied.duplicate(true)
		_result["failures"] = Array(_result.get("failures", [])) + [message]
	_status.text = "ERROR · " + message
	_speech.text = "Runner failure is shown; no success fallback was applied."
	_details.text = "source_unchanged=%s · paid_calls=%s" % [_result.get("source_unchanged", null), _result.get("paid_calls", null)]

func _build_residents() -> void:
	_carpenter = RESIDENT.new()
	_carpenter.name = "Resident_Carpenter"
	_carpenter.shirt_color = Color("49647b")
	_carpenter.hair_color = Color("6f4b36")
	_carpenter.position = Vector3(-1.7, 0, 0.8)
	add_child(_carpenter)
	_smith = RESIDENT.new()
	_smith.name = "Resident_Smith"
	_smith.shirt_color = Color("7a4d3d")
	_smith.hair_color = Color("302a2b")
	_smith.position = Vector3(1.3, 0, -0.2)
	add_child(_smith)
	_carpenter.set_meta("resident_id", CARPENTER)
	_smith.set_meta("resident_id", SMITH)
	_build_label("Rowan", _carpenter.position + Vector3(0, 2.55, 0), Color("d5e8ef"))
	_build_label("Flint", _smith.position + Vector3(0, 2.55, 0), Color("f2d2b3"))
	_apply_loadouts(false)

func _build_yard() -> void:
	_box("Yard", Vector3(0, -0.18, 0), Vector3(9, 0.3, 7), Color("493c35"))
	_box("Forge", Vector3(2.8, 0.85, -1.4), Vector3(1.5, 1.7, 1.1), Color("252a31"))
	_box("ForgeGlow", Vector3(2.8, 0.85, -0.82), Vector3(0.75, 0.7, 0.05), Color("d47a3e"))
	_box("Anvil", Vector3(0.15, 0.48, -1.25), Vector3(1.0, 0.65, 0.55), Color("59626c"))
	_box("WorkTable", Vector3(-1.1, 0.55, -1.8), Vector3(2.3, 0.7, 0.9), Color("694a32"))
	_box("Fence", Vector3(-3.4, 0.65, -2.4), Vector3(0.18, 1.3, 5.0), Color("684932"))
	var light := OmniLight3D.new()
	light.name = "ForgeLight"
	light.position = Vector3(2.8, 2.4, -1.0)
	light.light_color = Color("ff9e55")
	light.light_energy = 3.2
	light.omni_range = 7.0
	add_child(light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(7.6, 5.6, 8.8)
	camera.look_at_from_position(camera.position, Vector3(0, 1.0, -0.5), Vector3.UP)
	camera.fov = 48.0
	camera.current = true
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(24, 22)
	panel.size = Vector2(820, 240)
	panel.color = Color(0.025, 0.04, 0.065, 0.9)
	layer.add_child(panel)
	_mode_label = Label.new(); _mode_label.position = Vector2(22, 14); _mode_label.add_theme_font_size_override("font_size", 24); panel.add_child(_mode_label)
	_status = Label.new(); _status.position = Vector2(22, 52); _status.add_theme_font_size_override("font_size", 17); panel.add_child(_status)
	_speech = Label.new(); _speech.position = Vector2(22, 82); _speech.size = Vector2(710, 45); _speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _speech.add_theme_font_size_override("font_size", 18); panel.add_child(_speech)
	_details = Label.new(); _details.position = Vector2(22, 136); _details.size = Vector2(770, 68); _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _details.modulate = Color("b9c7d1"); _details.add_theme_font_size_override("font_size", 17); panel.add_child(_details)
	_controls = Label.new(); _controls.position = Vector2(22, 210); _controls.text = "N  Next step     R  Replay     S  Success     F  Refusal"; _controls.modulate = Color("f3dfb7"); _controls.add_theme_font_size_override("font_size", 18); panel.add_child(_controls)
	_refresh_ui()

func _refresh_ui() -> void:
	if _mode_label == null:
		return
	_mode_label.text = "AXE DAY · %s" % _mode.to_upper()
	var count := "%d/%d" % [_step_index + 1, _steps.size()] if not _steps.is_empty() else "waiting"
	_status.text = "SCRIPTED REPLAY • no live AI • arrival simulated · %s" % count
	if _step_index >= 0 and _step_index < _steps.size():
		var step: Dictionary = _steps[_step_index]
		var speech := str(step.get("speech", ""))
		var phase := _phase_title(str(step.get("phase", "")))
		if speech.is_empty():
			var event_type := str(step.get("event_type", ""))
			_speech.text = "%s · %s" % [phase, _event_title(event_type) if not event_type.is_empty() else ("Checkpoint saved" if step.get("phase", "") == "work_interrupted" else "No spoken line")]
		else:
			_speech.text = "%s: %s" % [_speaker_label(str(step.get("speaker_id", ""))), speech]
		var proposal := str(step.get("proposed_action", ""))
		var result := str(step.get("result_code", ""))
		var result_text := _event_title(str(step.get("event_type", ""))) if not str(step.get("event_type", "")).is_empty() else (_event_title(result) if not result.is_empty() else ("Checkpoint saved" if step.get("phase", "") == "work_interrupted" else "No new result"))
		_details.text = "Phase: %s\nAction: %s   Result: %s\nCustody: %s   Edge: %s   Coins: %s / %s   Escrow: %s" % [phase, proposal if not proposal.is_empty() else "—", result_text, _custodian_label(str(step.get("custodian_id", ""))), step.get("edge", "—"), step.get("owner_col", "—"), step.get("smith_col", "—"), step.get("reserved_col", "—")]
	else:
		_speech.text = "Waiting for the bounded fixture runner…"
		_details.text = "source_unchanged=%s · paid_calls=%s" % [_result.get("source_unchanged", true), _result.get("paid_calls", 0)]

func _box(node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new(); mesh.name = node_name
	var shape := BoxMesh.new(); shape.size = size; mesh.mesh = shape; mesh.position = position; mesh.material_override = _material(node_name, color); add_child(mesh)

func _build_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new(); label.text = text; label.position = position; label.modulate = color; label.font_size = 28; label.pixel_size = 0.01; label.outline_size = 6; label.outline_modulate = Color("17202a"); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(label)

func _speaker_label(id: String) -> String:
	return "Rowan" if id == CARPENTER else "Flint" if id == SMITH else "System"

func _custodian_label(id: String) -> String:
	return "Rowan" if id == CARPENTER else "Flint" if id == SMITH else "Unassigned"

func _phase_title(phase: String) -> String:
	return phase.replace("_", " ").capitalize()

func _event_title(value: String) -> String:
	return value.replace("_", " ").capitalize() if not value.is_empty() else "No new result"

func _material(key: String, color: Color) -> StandardMaterial3D:
	if _yard_materials.has(key): return _yard_materials[key]
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.82; _yard_materials[key] = material; return material
