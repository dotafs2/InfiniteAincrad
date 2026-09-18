extends SceneTree
## Read-only English UI capture on the real sixteen-house scene. No model/provider.
const TownScene := preload("res://scenes/town_street.tscn")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var source := ""
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="): source = arg.trim_prefix("--town-save=")
		if arg.begins_with("--english-capture="): out = arg.trim_prefix("--english-capture=")
	if source.is_empty() or out.is_empty() or "--town-restore" not in OS.get_cmdline_user_args():
		push_error("Requires --town-restore --town-save=... --english-capture=...")
		quit(2)
		return
	var original_bytes := FileAccess.get_file_as_bytes(source)
	var scene = TownScene.instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.restore_only and scene.paused and scene.model_turns == null, "paused read-only scene has no provider")
	check(scene.quarter != null and scene.town.active_ids().size() == 10, "actual quarter contains ten residents")
	var original: Dictionary = scene.town.snapshot()
	scene._camera.global_position = Vector3(0, 6, 24)
	scene._camera.look_at(Vector3(0, 1, 0))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var han := RegEx.new()
	han.compile("[\\x{3400}-\\x{9fff}]")
	DirAccess.make_dir_recursive_absolute(out)
	var frames: Array = []
	for viewport_size in [Vector2i(1280, 800), Vector2i(1600, 900)]:
		root.size = viewport_size
		scene._refresh()
		for unused in 30: await process_frame
		await RenderingServer.frame_post_draw
		# UI coordinates use the stretched logical viewport, not physical window pixels.
		var screen: Rect2 = scene.get_viewport().get_visible_rect()
		for panel in [scene.status.get_parent(), scene.life_panel, scene.dialogue_panel]:
			check(screen.encloses(panel.get_global_rect()), "English panel fits %s: %s" % [viewport_size, panel.get_global_rect()])
		for label in [scene.status, scene.life_roster, scene.life_feed, scene.dialogue]:
			check(han.search(label.text) == null, "fresh-world UI text is English at %s" % viewport_size)
		for id in scene.town.active_ids():
			check(han.search(scene.cards[id].text) == null, "resident nameplate is English: " + id)
		var filename := "town-english-%dx%d.png" % [viewport_size.x, viewport_size.y]
		check(root.get_texture().get_image().save_png(out.path_join(filename)) == OK, "screenshot saved")
		frames.append(filename)
	check(scene.town.snapshot() == original, "UI capture never changes canonical world state")
	check(FileAccess.get_file_as_bytes(source) == original_bytes, "UI capture preserves exact save bytes")
	var report := {"suite": "town_english_ui", "checks": checks, "failures": failures,
		"paid_calls": 0, "world_save_byte_equal": FileAccess.get_file_as_bytes(source) == original_bytes, "screenshots": frames,
		"names": scene.town.active_ids().map(func(id): return scene.town.resident_name(id))}
	var file := FileAccess.open(out.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	scene.free()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
