extends SceneTree
## Actual desktop GPU pixels for Frostlight preview and world composition.
## This capture is art-direction evidence; it makes no iPhone or frame-rate claim.
var game: Node3D
var directory := ""
var records: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func capture(label: String, scope: String) -> void:
	for _index in 8:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(directory + "/" + label + ".png") == OK)
	records.append({"file": label + ".png", "scope": scope, "map": game.selected_map, "viewport": root.size})

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--test") and DisplayServer.get_name() != "headless")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	assert(not directory.is_empty())
	DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 960)
	game = load("res://fidelity/main.tscn").instantiate()
	game.selected_map = "frost"
	root.add_child(game)
	await process_frame
	await capture("frostlight-home", "Actual Frostlight home miniature with snow drifts and ice sentinels")
	game.ui.open_maps()
	await capture("frostlight-map-chooser", "Actual map chooser with Frostlight available beside the preserved worlds")
	game.ui.close_menu()
	game.start_level()
	game.set_process(false)
	game.set_physics_process(false)
	game.city.set_process(false)
	game.city.set_physics_process(false)
	for hole in game.holes:
		hole.enabled = false
	game.ui.visible = false
	game.camera.far = 800
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 225
	game.camera.position = Vector3(125, 155, 150)
	game.camera.look_at(Vector3(0, 2, 0))
	await capture("frostlight-world-overview", "Staged overview of the actual glacier field, polar ecosystems and research outposts")
	game.camera.size = 42
	game.camera.position = Vector3(116, 34, -28)
	game.camera.look_at(Vector3(72, 1, -70))
	await capture("frostlight-polar-life", "Closer GPU review of the penguin colony, polar wildlife and ice edge")
	FileAccess.open(directory + "/capture.json", FileAccess.WRITE).store_string(JSON.stringify({
		"scope": "Actual desktop GPU Frostlight Arctic art review; no native upload, iPhone FPS or ordinary pacing claim",
		"renderer": RenderingServer.get_current_rendering_method(), "muted": true, "records": records}, "\t"))
	game.free()
	await process_frame
	quit()
