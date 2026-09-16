extends SceneTree
const World = preload("res://core/town_places.gd")

func _initialize() -> void:
	var source := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source = arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not source.is_empty() and not output.is_empty())
	var world := World.new()
	assert(world.load_from(source).ok, "Preview must pass actual world validation")
	assert(world.active_ids().size() == 10)
	assert(world.snapshot().life.seq == 0, "Fresh preview must not invent historical events")
	assert(world.snapshot().godot.spatial_layout.preview_genesis)
	for id in world.active_ids():
		assert(world.home_point(id).is_finite())
		assert(world.position_of(id).is_finite())
	world._state.godot.spatial_layout.doors[world.active_ids()[0]] = true
	assert(world.save_to(output).ok)
	var restored := World.new()
	assert(restored.load_from(output).ok)
	assert(_same_value(restored.snapshot(), world.snapshot()), "Cold save must retain the full preview state")
	print("DEMO_PREVIEW_STATE_OK residents=10 seq=0 cold_restore=true")
	quit(0)

func _same_value(a: Variant, b: Variant) -> bool:
	# Compare leaves explicitly: decoded numeric Variants can differ in storage type.
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
