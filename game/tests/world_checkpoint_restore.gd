extends SceneTree
const World = preload("res://core/town_places.gd")

func _initialize() -> void:
	var source := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source = arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not source.is_empty() and not output.is_empty() and source != output)
	assert(not FileAccess.file_exists(output), "Use a fresh output copy; never overwrite a continuation")
	var world := World.new()
	assert(world.load_from(source).ok, "Checkpoint must pass production world validation")
	var expected := world.snapshot()
	assert(world.save_to(output).ok)
	var restored := World.new()
	assert(restored.load_from(output).ok)
	assert(_same_value(expected, restored.snapshot()), "Every nested field must survive cold restore")
	print("WORLD_CHECKPOINT_RESTORE_OK residents=%d seq=%d exact_fields=true" % [world.active_ids().size(), expected.life.seq])
	quit(0)

func _same_value(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same_value(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same_value(a[i], b[i]): return false
		return true
	return a == b
