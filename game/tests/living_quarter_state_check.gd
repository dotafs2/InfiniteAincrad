extends SceneTree
const World = preload("res://core/town_places.gd")
var failures: Array = []
var checks := 0

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	var source := ""
	var baseline := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="): source=arg.trim_prefix("--town-save=")
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
		if arg.begins_with("--quarter-report="): output=arg.trim_prefix("--quarter-report=")
	if source.is_empty() or baseline.is_empty() or output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var original := World.new()
	verify(original.load_from(baseline).ok,"original save still loads")
	var world := World.new()
	verify(world.load_from(source).ok,"migrated save loads")
	if not failures.is_empty():
		print(JSON.stringify(failures))
		quit(1)
		return
	var before: Dictionary = original.snapshot()
	var migrated: Dictionary = world.snapshot()
	for key in before:
		if key != "godot": verify(before[key] == migrated[key],"unchanged "+key)
	for key in before.godot:
		if key not in ["homes","positions","berry_position","foraging_work_spots"]:
			verify(before.godot[key] == migrated.godot[key],"unchanged godot."+key)
	var doors: Dictionary = migrated.godot.spatial_layout.doors.duplicate()
	var windows: Dictionary = migrated.godot.spatial_layout.windows.duplicate()
	world._state.godot.spatial_layout.doors["shared:well-keeper"] = true
	world._state.godot.spatial_layout.windows["shared:well-keeper"] = true
	var cold_path := output.path_join("door-window-cold-save.json")
	verify(world.save_to(cold_path).ok,"persist door and window")
	var cold := World.new()
	verify(cold.load_from(cold_path).ok,"cold reload")
	var restored: Dictionary = cold.snapshot()
	verify(restored.godot.spatial_layout.doors["shared:well-keeper"],"door restored open")
	verify(restored.godot.spatial_layout.windows["shared:well-keeper"],"window restored open")
	restored.godot.spatial_layout.doors = doors
	restored.godot.spatial_layout.windows = windows
	# Canonical serialization normalizes integral floats during the disk round trip.
	var state_diff := first_difference(restored,migrated,"state")
	verify(state_diff.is_empty(),"fixture interaction preserves all other state: "+state_diff)
	var damaged: Dictionary = migrated.duplicate(true)
	damaged.godot.spatial_layout.foraging_after.positions["shared:well-keeper"][0] += 1.0
	verify(not world._validate_state(damaged).ok,"reject broken migration evidence")
	damaged = migrated.duplicate(true)
	damaged.godot.spatial_layout.foraging_before.positions["shared:well-keeper"][0] += .03
	verify(not world._validate_state(damaged).ok,"reject rewritten historical link")
	var report := {"checks":checks,"failures":failures,"ok":failures.is_empty(),"life_seq":migrated.life.seq,"no_life_decisions":true}
	var file := FileAccess.open(output.path_join("state-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LIVING_QUARTER_REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func first_difference(a: Variant, b: Variant, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return path+" dictionary size"
		for key in a:
			if not b.has(key): return path+" missing "+str(key)
			var diff := first_difference(a[key],b[key],path+"."+str(key))
			if not diff.is_empty(): return diff
		return ""
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+" array size"
		for i in a.size():
			var diff := first_difference(a[i],b[i],path+"["+str(i)+"]")
			if not diff.is_empty(): return diff
		return ""
	return "" if a==b else path+" "+str(a)+" != "+str(b)
