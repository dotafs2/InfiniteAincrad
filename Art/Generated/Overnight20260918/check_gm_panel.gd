extends SceneTree
## Bounded review driver only: unchanged product scene, one normal G key event,
## native viewport PNGs. No world/API operations or product input changes.

func _initialize() -> void:
	call_deferred("_review")

func _review() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-capture="):
			out_dir = arg.trim_prefix("--town-capture=")
	if out_dir.is_empty() or not OS.get_cmdline_user_args().has("--town-restore"):
		quit(2)
		return
	var scene: Node = load("res://scenes/town_street.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("v2-street.png"))
	var press := InputEventKey.new()
	press.keycode = KEY_G
	press.pressed = true
	Input.parse_input_event(press)
	for i in 4:
		await process_frame
	var panel: PanelContainer = scene.get("gm_panel")
	var label: Label = scene.get("gm_status_label")
	var header: Label = scene.get("gm_status_header")
	var rows: Array = scene.get("gm_status_rows")
	var scroll := label.get_parent() as ScrollContainer
	var receipt := {"mode":"restore-only audit-copy review", "g_key_opens_panel":panel.visible,
		"loaded_rows":rows.size(), "header":header.text,
		"panel_rect":[panel.position.x,panel.position.y,panel.size.x,panel.size.y],
		"viewport_size":[root.size.x,root.size.y],
		"all_rows_fit_without_scrolling":label.size.y <= scroll.size.y,
		"content_height":label.size.y,"scroll_view_height":scroll.size.y,
		"statuses":[],"adoption_proven":false}
	for row in rows:
		receipt.statuses.append({"id":row.id,"status":row.status,"source_seq":row.last_source_seq})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("gm-panel-top.png"))
	# Inspect the existing scroll control, without changing layout or product code.
	scroll.scroll_vertical = int((scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page) / 2.0)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("gm-panel-middle.png"))
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("gm-panel-bottom.png"))
	scroll.scroll_vertical = 0
	var file := FileAccess.open(out_dir.path_join("gm-panel-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  ")+"\n")
	file.close()
	# Product's existing paused 3-second capture saves evidence and quits normally.
