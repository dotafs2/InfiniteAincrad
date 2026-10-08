extends SceneTree
## Verifies that Blender presentation geometry is anchored to the inherited
## edible body floor and centre. It does not replace the physics collider.

const Game = preload("res://fidelity/game.gd")
var checks := 0
var failures: Array[String] = []
var glacier_count := 0
var rock_count := 0
var worst_floor_error := 0.0
var worst_center_error := 0.0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func find_asset(body: Node3D) -> Node3D:
	var assembly := body.get_node_or_null("FrostSpeciesVisual")
	if assembly == null:
		return null
	for child in assembly.get_children():
		if child.name.begins_with("BlenderAuthored_"):
			return child
	return null

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var game := Game.new()
	game.selected_map = "frost"
	game.test_progress_path = "/tmp/hole-feast-frostlight-alignment-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	game.start_level()
	game.begin_play()
	for _index in 4:
		await physics_frame
	for body in game.city.foods:
		if not is_instance_valid(body):
			continue
		var species := str(body.get_meta("frost_species", ""))
		if species not in ["glacier_iceberg", "ice_rock"]:
			continue
		var asset: Node3D = find_asset(body)
		check(asset != null, "%s has an imported Blender presentation child" % species)
		if asset == null:
			continue
		if species == "glacier_iceberg":glacier_count += 1
		else:rock_count += 1
		var bounds:=AABB()
		var first:=true
		for visual in asset.find_children("*", "MeshInstance3D", true, false):
			var pose:Transform3D=body.global_transform.affine_inverse()*visual.global_transform
			var measured:AABB=pose*visual.mesh.get_aabb()
			bounds=measured if first else bounds.merge(measured)
			first=false
		var world_min_y:float=body.global_position.y+bounds.position.y
		var world_max_y:float=body.global_position.y+bounds.end.y
		var collider_floor: float = body.global_position.y - body.half_size.y
		var collider_ceiling: float = body.global_position.y + body.half_size.y
		var floor_error := absf(world_min_y - collider_floor)
		var ceiling_overrun := maxf(0.0, world_max_y - collider_ceiling)
		var center:=bounds.get_center()
		var center_error:=Vector2(center.x,center.z).length()
		worst_floor_error = maxf(worst_floor_error, floor_error)
		worst_center_error = maxf(worst_center_error, center_error)
		check(floor_error <= .05, "%s visual floor follows its edible collider floor" % body.name)
		check(ceiling_overrun <= .05, "%s visual stays within its edible collider height" % body.name)
		check(center_error <= .05, "%s visual centre follows its edible body centre" % body.name)
	check(glacier_count >= 180 and rock_count >= 12, "All imported glacier and ice-rock owners are checked, including calved outcrops")
	var result := {"checks": checks, "failures": failures, "metrics": {
		"glacier_count": glacier_count,
		"ice_rock_count": rock_count,
		"worst_floor_error": worst_floor_error,
		"worst_center_error": worst_center_error,
		"scope": "Blender visual anchor and collider envelope only; no save or release claim",
	}}
	print("FROSTLIGHT_ASSET_ALIGNMENT " + JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(result, "\t") + "\n")
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
