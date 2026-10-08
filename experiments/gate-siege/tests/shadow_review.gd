extends SceneTree
## Independent player/flight shadow regression and optional fixed-scene GPU probe.
const Game = preload("res://scripts/game.gd")
var game: Node3D
var checks := 0
var failures: Array[String] = []
var profile_only := false
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--shadow-profile": profile_only = true
		if arg.begins_with("--shadow-output="): output = arg.trim_prefix("--shadow-output=")
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func step(seconds: float) -> void:
	for i in range(ceili(seconds * 60)):
		game._physics_process(1.0 / 60.0)

func shadow_meshes() -> Array[MeshInstance3D]:
	return [game.player_directional_shadow, game.player_contact_shadow]

func on_floor(mesh: MeshInstance3D) -> bool:
	return is_instance_valid(mesh) and mesh.global_position.y > 0 and mesh.global_position.y < 0.06 and mesh.global_basis.y.normalized().is_equal_approx(Vector3.UP)

func named_count(node: Node, wanted: String) -> int:
	var amount := 1 if node.name == wanted else 0
	for child in node.get_children(): amount += named_count(child, wanted)
	return amount

func player_realtime_casters(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: count += 1
	for child in node.get_children(): count += player_realtime_casters(child)
	return count

func _run() -> void:
	root.size = Vector2i(486,864)
	game = Game.new()
	root.add_child(game)
	game.qa_mode = true
	game.audio_enabled = false
	game.auto_demo = false
	game.set_process(false)
	game.set_physics_process(false)
	for i in range(12):
		await process_frame
		if game.render_warmup_done: break
	await process_frame
	if profile_only:
		await _profile()
	else:
		await _test_tiers_and_motion()
		await _test_upgrades_and_restart()
		print("SHADOW_REVIEW ",JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_tiers_and_motion() -> void:
	for tier in range(4):
		game.restart_game()
		game.tier = tier
		game._set_player_model()
		game._update_player_shadow()
		await process_frame
		var rig: Node3D = game.player_shadow_root
		check(rig.get_parent() == game and not game.player.is_ancestor_of(rig), "Tier%d shadow rig has an independent world anchor" % tier)
		check(rig.get_child_count() == 2 and named_count(game,"DirectionalShadow") == 1 and named_count(game,"ContactShadow") == 1, "Tier%d has exactly one directional and one contact mesh" % tier)
		var shadow_material: ShaderMaterial = game.player_directional_shadow.material_override
		var silhouette = shadow_material.get_shader_parameter("shadow_texture")
		check(shadow_material.get_shader_parameter("use_texture") == true and silhouette is Texture2D and silhouette.get_width() >= 32 and silhouette.get_height() >= 32, "Tier%d selects an imported silhouette texture" % tier)
		var heights: Array[float] = []
		for mesh in shadow_meshes(): heights.append(mesh.global_position.y)
		var floor_valid := true
		var tracking_valid := true
		var changed_bob := false
		var changed_lean := false
		for frame in range(120):
			game.target_x = -4.0 if frame < 60 else 4.0
			step(1.0/60.0)
			changed_bob = changed_bob or game.player.position.y > 0.01
			changed_lean = changed_lean or absf(game.player_model.rotation.z) > 0.01
			tracking_valid = tracking_valid and is_equal_approx(rig.global_position.x,game.player_x) and is_zero_approx(rig.global_position.y) and is_equal_approx(rig.global_position.z,game.PLAYER_Z)
			for index in range(2):
				var mesh := shadow_meshes()[index]
				floor_valid = floor_valid and on_floor(mesh) and is_equal_approx(mesh.global_position.y,heights[index])
		check(changed_bob and changed_lean and floor_valid, "Tier%d shadows stay flat at fixed floor height during real bob and lean" % tier)
		check(tracking_valid, "Tier%d world anchor follows horizontal player steering" % tier)
		for mode in ["low","battery","high"]:
			game.set_quality(mode)
			game._update_player_shadow()
			var directional: MeshInstance3D = game.player_directional_shadow
			var contact: MeshInstance3D = game.player_contact_shadow
			check(contact.is_visible_in_tree() and on_floor(contact) and contact.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Tier%d %s keeps a floor contact shadow without recursive casting" % [tier,mode])
			if mode == "high":
				check(game.sun.shadow_enabled and not directional.is_visible_in_tree() and player_realtime_casters(game.player_model)>0, "Tier%d high uses realtime direction without duplicate baked direction" % tier)
			else:
				check(not game.sun.shadow_enabled and directional.is_visible_in_tree() and on_floor(directional) and directional.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Tier%d %s retains the cheap directional silhouette with sun shadows off" % [tier,mode])
		var frozen: Array[Transform3D] = [rig.global_transform, game.player_directional_shadow.global_transform, game.player_contact_shadow.global_transform]
		game.toggle_pause()
		game.target_x = -4.0
		step(0.5)
		await create_timer(0.06).timeout
		check(game.phase == "paused" and frozen == [rig.global_transform,game.player_directional_shadow.global_transform,game.player_contact_shadow.global_transform], "Tier%d pause freezes all player-shadow transforms" % tier)

func _test_upgrades_and_restart() -> void:
	game.restart_game()
	game.set_quality("low")
	game.target_x = -4.0
	for expected_tier in range(1,4):
		game._damage_recruit(game.recruit_remaining)
		check(game.recruiting and game.tier == expected_tier and is_instance_valid(game.recruit_shadow), "Upgrade%d creates one flight shadow through the real recruit path" % expected_tier)
		var flight_shadow: MeshInstance3D = game.recruit_shadow
		check(flight_shadow.get_parent() == game and on_floor(flight_shadow), "Upgrade%d flight shadow is independent and floor anchored" % expected_tier)
		for mode in ["low","battery","high"]:
			game.set_quality(mode)
			game._update_recruit_shadow()
			check(flight_shadow.visible == (mode != "high") and on_floor(flight_shadow), "Upgrade%d %s selects one flight shadow strategy" % [expected_tier,mode])
		game.set_quality("low")
		var floor_y := flight_shadow.global_position.y
		var flight_valid := true
		for i in range(20):
			step(1.0/60.0)
			flight_valid = flight_valid and on_floor(flight_shadow) and is_equal_approx(flight_shadow.global_position.y,floor_y)
		var ray: Vector3 = -game.sun.global_basis.z
		var expected_ground: Vector3 = game.recruit_flight.global_position-ray*(game.recruit_flight.global_position.y/ray.y)
		var projected: Vector3 = flight_shadow.global_position
		check(is_equal_approx(projected.x,expected_ground.x) and is_equal_approx(projected.z,expected_ground.z), "Upgrade%d footprint projects along the scene light onto the ground" % expected_tier)
		check(game.recruit_flight.global_position.y > 1.0 and flight_valid, "Upgrade%d airborne hero keeps its projection on the ground" % expected_tier)
		var frozen_shadow := flight_shadow.global_transform
		game.toggle_pause()
		step(0.25)
		await create_timer(0.06).timeout
		check(flight_shadow.global_transform.is_equal_approx(frozen_shadow), "Upgrade%d pause freezes its airborne shadow" % expected_tier)
		game.toggle_pause()
		step(0.7)
		await process_frame
		check(not game.recruiting and not is_instance_valid(flight_shadow) and not is_instance_valid(game.recruit_shadow), "Upgrade%d landing frees the temporary shadow" % expected_tier)
		check(named_count(game,"DirectionalShadow") == 1 and named_count(game,"ContactShadow") == 1 and game.player_shadow_root.get_child_count() == 2, "Upgrade%d leaves exactly one player-shadow rig" % expected_tier)
	for attempt in range(4):
		game.restart_game()
		game._damage_recruit(game.recruit_remaining)
		step(0.25)
		var old_flight: MeshInstance3D = game.recruit_shadow
		var old_rig: Node3D = game.player_shadow_root
		game.restart_game()
		await process_frame
		check(not is_instance_valid(old_flight) and not is_instance_valid(game.recruit_shadow) and not game.recruiting, "Restart%d releases an interrupted flight shadow" % attempt)
		check((not is_instance_valid(old_rig) or old_rig == game.player_shadow_root) and game.player_shadow_root.get_parent()==game and named_count(game,"DirectionalShadow")==1 and named_count(game,"ContactShadow")==1, "Restart%d neither leaks nor duplicates the grounded shadow rig" % attempt)

func _render_sample() -> Dictionary:
	for i in range(4): await RenderingServer.frame_post_draw
	return {"draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}

func _profile() -> void:
	if DisplayServer.get_name() == "headless":
		check(false,"Shadow GPU probe requires a real rendering device")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rows: Array = []
	for mode in ["low","battery","high"]:
		game.set_quality(mode)
		Engine.max_fps = 0
		for tier in range(4):
			game.restart_game()
			game.tier = tier
			game._set_player_model()
			game._update_player_shadow()
			game._process(0)
			var present: Dictionary = await _render_sample()
			game.player_shadow_root.hide()
			var hidden: Dictionary = await _render_sample()
			game.player_shadow_root.show()
			rows.append({"quality":mode,"tier":tier,"visible":present,"hidden":hidden,"added_draws":present.draws-hidden.draws,"added_primitives":present.primitives-hidden.primitives})
	var report := {"device":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info(),"rows":rows,"note":"Same-scene visible versus hidden shadow rig; four rendered settling frames, no phone frame-rate claim."}
	print("SHADOW_GPU_PROFILE ",JSON.stringify(report))
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"  "))
