extends SceneTree
## Final paused presentation: existing V/G/N inputs and native viewport captures.
func _initialize() -> void:
	call_deferred("_capture")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _capture() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-capture="):
			output = arg.trim_prefix("--town-capture=")
	if output.is_empty() or not OS.get_cmdline_user_args().has("--town-restore"):
		quit(2)
		return
	var scene: Node = load("res://scenes/town_street.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.6).timeout
	await _key(KEY_V)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("overview.png"))
	await _key(KEY_G)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("gm-panel-top.png"))
	var panel: PanelContainer = scene.get("gm_panel")
	var label: Label = scene.get("gm_status_label")
	var header: Label = scene.get("gm_status_header")
	var column: VBoxContainer = panel.get_child(0)
	var title: Label = column.get_child(0)
	var rows: Array = scene.get("gm_status_rows")
	var receipt := {"mode":"paused restore-only presentation", "g_key_opens_panel":panel.visible,
		"title":title.text,"header":header.text,"rendered_text":label.text,
		"loaded_rows":rows.size(),"paused":scene.get("paused"),"restore_only":scene.get("restore_only"),
		"panel_rect":[panel.position.x,panel.position.y,panel.size.x,panel.size.y],
		"resident_switches":[],"statuses":[]}
	for row in rows:
		receipt.statuses.append({"id":row.id,"status":row.status,"source_seq":row.last_source_seq})
	await _key(KEY_G)
	for index in 10:
		await _key(KEY_N)
		var id: String = scene.get("resident_focus_id")
		var camera: Camera3D = scene.get("resident_observer_camera")
		var bodies: Dictionary = scene.get("bodies")
		receipt.resident_switches.append({"id":id,"body_present":bodies.has(id),"camera_current":camera.current})
	var file := FileAccess.open(output.path_join("presentation-check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  ")+"\n")
	file.close()
	# Existing product capture writes evidence and exits after its paused interval.
