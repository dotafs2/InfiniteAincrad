extends SceneTree

func _initialize() -> void:
	var source := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if source.is_empty() or output.is_empty() or source == output or FileAccess.file_exists(output):
		quit(2)
		return
	var town = load("res://core/town_life.gd").new()
	var loaded: Dictionary = town.load_from(source)
	if not loaded.ok:
		print(JSON.stringify(loaded))
		quit(1)
		return
	var result: Dictionary = town.save_to(output)
	print(JSON.stringify({"suite": "private_town_roundtrip", "ok": result.ok, "paid_calls": 0}))
	quit(0 if result.ok else 1)
