extends SceneTree
## Ordinary ninety-second Frostlight play with original actors, bodies, camera,
## timer and receipts. Scripted legal direction/charged boost inputs only.
## No score/radius grants, target relocation, collision disabling or extra food.
var game: Node3D
var directory := ""
var seed_value := 7107
var frame_interval := 0
var samples: Array[Dictionary] = []
var check_failures: Array[String] = []
var collection_events: Array[Dictionary] = []
var frame_times: Array[Dictionary] = []
var final_check_count := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	final_check_count += 1
	if not ok:
		check_failures.append(label)
		push_error(label)

func counters() -> Dictionary:
	return {"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"fps": Performance.get_monitor(Performance.TIME_FPS)}

func remaining_targets() -> Dictionary:
	var edible := 0
	var larger := 0
	var nearby := 0
	var tiers := {}
	var species := {}
	for body in game.city.foods:
		if not is_instance_valid(body) or body.consumed:
			continue
		var tier := str(body.get_meta("toy_tier", 0))
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		var kind := str(body.get_meta("frost_species", "legacy"))
		species[kind] = int(species.get(kind, 0)) + 1
		if float(body.footprint) * 1.08 > float(game.player.radius):
			larger += 1
		elif body.can_fit(game.player):
			edible += 1
			if body.global_position.distance_to(game.player.global_position) < 25.0:
				nearby += 1
	return {"edible": edible, "larger": larger, "edible_within_25m": nearby, "remaining_tiers": tiers, "remaining_species": species}

func collected(item: Node3D, hole: Node3D) -> void:
	if hole != game.player:
		return
	collection_events.append({"elapsed": game.elapsed, "species": str(item.get_meta("frost_species", "legacy")),
		"tier": int(item.get_meta("toy_tier", 0)), "points": int(item.points),
		"at": [item.global_position.x, item.global_position.y, item.global_position.z],
		"score_after": int(hole.score), "radius_after": float(hole.radius)})

func sample(label: String) -> void:
	await RenderingServer.frame_post_draw
	var file := directory + "/" + label + ".png"
	var captured: Image = root.get_texture().get_image()
	check(captured != null and not captured.is_empty() and captured.save_png(file) == OK, label + ": actual GPU frame saved")
	samples.append({"file": label + ".png", "elapsed": game.elapsed, "remaining": game.remaining,
		"score": game.player.score, "level": game.player.level, "radius": game.player.radius,
		"player_position": [game.player.position.x, game.player.position.y, game.player.position.z],
		"eaten": game.eaten, "world_items_eaten": game.eaten, "player_item_collections": collection_events.size(),
		"kills": game.kills, "deaths": game.round_deaths,
		"targets": remaining_targets(), "renderer": counters()})

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--capture-every="):
			frame_interval = maxi(0, int(argument.trim_prefix("--capture-every=")))
	if directory.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	if frame_interval > 0:
		DirAccess.make_dir_recursive_absolute(directory + "/frames")
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(540, 1174)
	root.content_scale_size = root.size
	# Explicitly seed global authored/render variation before scene construction.
	seed(seed_value)
	game = load("res://fidelity/main.tscn").instantiate()
	game.selected_map = "frost"
	game.test_progress_path = "/tmp/hole-feast-glacier-normal-%d-%d.cfg" % [OS.get_process_id(), seed_value]
	root.add_child(game)
	game.start_level()
	game.begin_play()
	game.item_collected.connect(collected)
	check(game.player.score == 0 and game.player.level == 1, "Normal player starts from zero with starter radius")
	check(game.holes.size() > 1, "Normal AI rivals remain in the world")
	var initial_bodies: int = game.city.foods.size()
	var started := Time.get_ticks_msec()
	var ticks := 0
	var frames_written := 0
	var next_sample := 15.0
	# Let the real ground cut and camera settle through normal physics ticks.
	for _settle_tick in 4:
		await physics_frame
	await sample("gameplay-000")
	while game.phase == "playing" and ticks < 16000:
		var player: Node3D = game.player
		if player.active:
			player.test_direction = game.auto_direction(player, 1.0 / 60.0)
			if player.pulse_charge >= player.PULSE_MAX and game.elapsed > 8.0:
				player.trigger_pulse()
		await physics_frame
		ticks += 1
		if frame_interval > 0 and ticks % frame_interval == 0:
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var relative_file: String = "frames/%05d.png" % frames_written
			var saved: int = image.save_png(directory + "/" + relative_file)
			check(saved == OK, "Gameplay movie frame %d saved" % frames_written)
			if saved == OK:
				frame_times.append({"file": relative_file, "elapsed": float(game.elapsed), "remaining": float(game.remaining)})
			frames_written += 1
		if game.elapsed + .001 >= next_sample:
			await sample("gameplay-%03d" % roundi(next_sample))
			print("GLACIER_GAMEPLAY_PROGRESS " + JSON.stringify(samples[-1]))
			next_sample += 15.0
		if Time.get_ticks_msec() - started > 1200000:
			check(false, "Twenty-minute wall-clock watchdog reached")
			break
	if is_instance_valid(game.player):
		game.player.test_direction = Vector2.ZERO
	await sample("gameplay-finish")
	check(game.phase == "complete", "Ordinary gameplay reaches the completed phase")
	check(absf(float(game.elapsed) - 90.0) < .1, "Initial round ends at ninety seconds")
	check(game.player.score > 0 and game.player.level > 1, "Ordinary movement earns points and growth")
	check(not collection_events.is_empty(), "Normal physics collections were observed")
	check(game.round_coins == game.score_coin_reward(game.player.score), "Round settles the accepted score-based coin reward")
	check(game.completed_runs == 1, "Exactly one run is credited")
	var tier_counts := {}
	var species_counts := {}
	for event in collection_events:
		var tier := str(event.tier)
		tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
		species_counts[event.species] = int(species_counts.get(event.species, 0)) + 1
	var result := {"checks": final_check_count, "failures": check_failures,
		"scope": "Actual muted Mac GPU portrait gameplay with standard camera/HUD and all normal rivals/collisions. Scripted legal movement and charged boost only; no score/radius/position grants, target staging, production ads/purchases or real saves. If launched with --fixed-fps, elapsed rendering time is not a real-time frame-rate benchmark.",
		"renderer": RenderingServer.get_current_rendering_method(), "viewport": str(root.size), "seed": seed_value, "render_seed": seed_value,
		"elapsed": game.elapsed, "score": game.player.score, "coins": game.round_coins, "level": game.player.level,
		"radius": game.player.radius, "eaten": game.eaten, "world_items_eaten": game.eaten, "player_item_collections": collection_events.size(),
		"kills": game.kills, "deaths": game.round_deaths,
		"initial_bodies": initial_bodies, "rivals": game.holes.size() - 1, "completed_runs": game.completed_runs,
		"wall_seconds": (Time.get_ticks_msec() - started) / 1000.0, "physics_iterations": ticks,
		"movie_frames": frames_written, "frame_interval": frame_interval, "frame_times": frame_times,
		"frame_timing_basis": "Per-frame actual game.elapsed; use consecutive timestamp differences when encoding video, not a presumed fixed capture rate.",
		"collected_tiers": tier_counts, "collected_species": species_counts,
		"remaining_targets": remaining_targets(), "samples": samples, "collections": collection_events}
	FileAccess.open(directory + "/report.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print("GLACIER_FROZEN_GAMEPLAY " + JSON.stringify({"checks": final_check_count, "failures": check_failures,
		"elapsed": game.elapsed, "score": game.player.score, "collected_tiers": tier_counts, "collected_species": species_counts}))
	game.free()
	await process_frame
	quit(0 if check_failures.is_empty() else 1)
