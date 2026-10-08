extends SceneTree
## Independent quality/animation checks; valid with an external exact --main-pack.
const Game = preload("res://scripts/game.gd")
var checks := 0
var failures: Array[String] = []
var runs: Array[Dictionary] = []
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		print("FAIL: ",description)

func create_game(mode: String) -> void:
	game = Game.new()
	root.add_child(game)
	game.qa_mode = true
	game.audio_enabled = false
	game.auto_demo = false
	game.set_process(false)
	game.set_physics_process(false)
	game.set_quality(mode)
	Engine.max_fps = 0

func release_game() -> void:
	game.queue_free()
	await process_frame

func step(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		game._physics_process(1.0/60.0)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var result := find_skeleton(child)
		if result: return result
	return null

func poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var output: Array[Transform3D] = []
	for i in range(skeleton.get_bone_count()): output.append(skeleton.get_bone_pose(i))
	return output

func count_changed(a: Array[Transform3D], b: Array[Transform3D]) -> int:
	var amount := 0
	for i in range(mini(a.size(),b.size())):
		if not a[i].is_equal_approx(b[i]): amount += 1
	return amount

func _run() -> void:
	root.size = Vector2i(540,960)
	create_game("high")
	await _test_warmup()
	await _test_animation()
	await _test_attack_contact()
	await release_game()
	create_game("high")
	await process_frame
	_test_graphics_budget()
	_test_auto_quality()
	await release_game()
	var reference: Array = []
	for mode in ["high","low","battery","auto"]:
		create_game(mode)
		await process_frame
		var run := _test_full_run(mode)
		runs.append(run)
		if reference.is_empty(): reference = run.fingerprints
		else: check(run.fingerprints == reference, "Every one-second gameplay fingerprint is identical for " + mode + " versus high")
		await release_game()
	print("MOBILE_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"runs":runs.map(func(x): var copy=x.duplicate();copy.erase("fingerprints");return copy)}))
	quit(0 if failures.is_empty() else 1)

func _test_warmup() -> void:
	var before := fingerprint()
	for i in range(8):
		if game.render_warmup_done: break
		await process_frame
	await process_frame
	await process_frame
	check(game.render_warmup_done and game.get_node_or_null("GraphicsWarmup") == null, "Ready-screen graphics warmup completes and frees every proxy")
	check(fingerprint() == before and game.phase == "ready", "Graphics warmup advances no gameplay time, random state or shots")
	var first: Node3D = game.model("mech")
	first.free()
	var warmed_cache: Dictionary = game.model_cache.duplicate()
	var second: Node3D = game.model("mech")
	second.free()
	var stable_cache: bool = warmed_cache.keys() == game.model_cache.keys()
	for path in warmed_cache: stable_cache = stable_cache and warmed_cache[path] == game.model_cache[path] and game.model_cache[path] is PackedScene
	check(stable_cache and not game.model_cache.is_empty(), "Repeated model creation retains the same strongly cached PackedScene resources")
	var shell_shader: Shader = game.statue_shell.shader
	game._set_statue_model()
	check(game.statue_shell.shader == shell_shader, "Replacing a statue reuses the same shared shader resource")

func _test_animation() -> void:
	game.start_game()
	check(is_instance_valid(game.boss_anim), "Boss owns a real AnimationPlayer")
	if not is_instance_valid(game.boss_anim): return
	for clip in ["walk","attack","hit","death"]:
		check(game.boss_anim.has_animation(clip), "Boss provides the " + clip + " animation clip")
	var skeleton := find_skeleton(game.boss_model)
	check(skeleton != null and skeleton.get_bone_count() >= 10, "Boss mesh uses an articulated skeleton")
	if not skeleton: return
	var initial := poses(skeleton)
	step(0.25)
	var walking := poses(skeleton)
	check(count_changed(initial,walking) >= 4, "Walking changes multiple joint poses rather than only root bobbing")
	game.toggle_pause()
	var before_pause := poses(skeleton)
	var elapsed_before: float = game.elapsed
	step(0.25)
	await create_timer(0.18).timeout
	check(poses(skeleton) == before_pause and game.elapsed == elapsed_before, "Boss skeleton freezes during paused physics and real engine frames")
	game.toggle_pause()
	var resumed_changes := 0
	for i in range(12):
		step(1.0/60.0)
		resumed_changes = maxi(resumed_changes,count_changed(before_pause,poses(skeleton)))
	check(resumed_changes > 0, "Resuming continues joint animation")
	game._damage_boss(1)
	check(String(game.boss_anim.current_animation).ends_with("hit"), "A real bullet damage event selects the hit reaction")
	step(0.4)
	game.boss_z = game.PLAYER_Z - 2.25
	step(0.1)
	check(String(game.boss_anim.current_animation).ends_with("attack"), "An approaching boss visibly enters its attack animation")
	game._damage_boss(1000000)
	check(game.boss_dead and String(game.boss_anim.current_animation).ends_with("death"), "A lethal damage event selects the death animation")
	var dying := poses(skeleton)
	step(0.2)
	check(count_changed(dying,poses(skeleton)) >= 3 and game.boss.scale.is_equal_approx(Vector3.ONE), "Death articulates the body without uniformly shrinking its root")
	game.toggle_pause()
	var death_remaining: float = game.boss_death_time
	var paused_death := poses(skeleton)
	await create_timer(0.18).timeout
	step(0.2)
	check(game.boss_death_time == death_remaining and poses(skeleton) == paused_death, "Pause freezes death playback and its completion timer")
	game.toggle_pause()
	step(float(game.boss_death_time)+0.1)
	check(not game.boss.visible, "Completed death removes the defeated boss visually")
	game.restart_game()
	check(not game.boss_dead and game.boss.visible and game.boss_death_time == 0 and game.boss_hp == game.boss_max, "Restart restores a fresh visible boss and full health")
	step(0.1)
	check(String(game.boss_anim.current_animation).ends_with("walk"), "Restart begins walking instead of retaining the old death state")

func _test_graphics_budget() -> void:
	game.start_game()
	game.set_quality("high")
	check(Engine.max_fps == 60, "High mode applies the desktop 60 FPS cap")
	var high := {"bullets":game.visual_bullet_cap,"packet":game.per_packet_cap,"sparks":game.spark_cap,"deaths":game.death_cap,"scale":root.scaling_3d_scale}
	check(game.effective_quality == "high", "Explicit high quality is selected")
	check(game.sun.shadow_enabled, "High quality retains directional shadows")
	var before := fingerprint()
	game.set_quality("low")
	check(game.effective_quality == "low", "Explicit low quality is selected")
	check(Engine.max_fps == 30, "Low mode applies the mobile 30 FPS cap")
	check(game.visual_bullet_cap < high.bullets and game.per_packet_cap <= high.packet and game.spark_cap < high.sparks and game.death_cap <= high.deaths, "Low quality reduces visual instance budgets")
	check(not game.sun.shadow_enabled and root.scaling_3d_scale < high.scale, "Low quality reduces shadow and render-resolution costs")
	check(fingerprint() == before, "Switching quality leaves all gameplay state unchanged")
	var original_size := root.size
	root.size = Vector2i(1080,1920)
	game._update_resolution()
	var physical_size := root.get_visible_rect().size * root.get_stretch_transform().get_scale()
	check(maxf(physical_size.x,physical_size.y)*root.scaling_3d_scale <= 640.01, "A 1080 by1920 viewport keeps the physical3D long axis at or below640 pixels")
	root.size = original_size
	game._update_resolution()
	for mode in ["high","low","battery"]:
		game.set_quality(mode)
		game._update_crowd_visual()
		var represented := 0
		for batch in game.crowd_batches: represented += batch.multimesh.visible_instance_count
		check(represented == game._alive_crowd() and represented == 544, "LOD retains every living troop exactly once in " + mode)
		var format_valid := true
		var colors_valid := true
		var phases_valid := true
		var phase_examples: Array = []
		var phase_max_error := 0.0
		var half_bytes := PackedByteArray()
		half_bytes.resize(2)
		var gpu_half_precision := DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility"
		for batch in game.crowd_batches:
			var mm: MultiMesh = batch.multimesh
			format_valid = format_valid and mm.use_colors and mm.use_custom_data and mm.buffer.size() == mm.instance_count*20
			for i in range(mm.visible_instance_count):
				# The headless renderer's per-instance getters return dummy defaults.
				# Inspect the actual packed buffer; GPU pixels are separately reviewed.
				var buffer: PackedFloat32Array = mm.buffer
				var base := i*20
				colors_valid = colors_valid and Color(buffer[base+12],buffer[base+13],buffer[base+14],buffer[base+15]).is_equal_approx(Color.WHITE)
				var custom := Color(buffer[base+16],buffer[base+17],buffer[base+18],buffer[base+19])
				var matching_phase := false
				for c in game.crowd:
					var expected: float = c.phase
					if gpu_half_precision:
						# Compatibility custom channels use float16; compare the exact
						# documented representation, not a broadly relaxed epsilon.
						half_bytes.encode_half(0,expected)
						expected = half_bytes.decode_half(0)
					if is_equal_approx(expected,custom.r):
						matching_phase = true
						phase_max_error = maxf(phase_max_error,absf(c.phase-custom.r))
						if phase_examples.size()<3 and not is_equal_approx(c.phase,custom.r): phase_examples.append({"source":c.phase,"float16":expected,"readback":custom.r})
						break
				phases_valid = phases_valid and matching_phase and is_zero_approx(custom.g) and is_zero_approx(custom.b) and is_zero_approx(custom.a)
		if gpu_half_precision: print("CUSTOM_PHASE_PRECISION ",JSON.stringify({"mode":mode,"max_error":phase_max_error,"examples":phase_examples}))
		check(format_valid, "Crowd bulk data retains the20-float transform/color/custom layout in " + mode)
		check(colors_valid, "Every crowd instance explicitly preserves white modulation in " + mode)
		check(phases_valid, "Crowd custom data contains its source phase rather than leaking into vertex color in " + mode)
	game.set_quality("low")
	var gameplay_rng: int = game.rng.state
	game._emit(Vector3.ZERO,Color.WHITE,100000,0.1)
	check(game.sparks.size() <= game.spark_cap, "Particle emissions obey the selected cap")
	check(game.rng.state == gameplay_rng, "Cosmetic particle count cannot consume gameplay RNG")
	game.bullets.clear()
	for i in range(300): game.bullets.append({"pos":Vector3(-2.0,1.0,-6.0),"power":36.0,"count":9990,"width":4.5,"mask":7,"tier":3})
	var packets_before := JSON.stringify(game.bullets)
	game._process(1.0/60.0)
	check(game.bullet_mm.multimesh.visible_instance_count <= game.visual_bullet_cap, "Multiplied projectile graphics stay inside the selected visual budget")
	check(JSON.stringify(game.bullets) == packets_before, "Visual projectile capping never changes real packet counts or damage")
	game.set_quality("battery")
	check(game.visual_bullet_cap <= high.bullets and root.scaling_3d_scale <= high.scale, "Battery quality is a bounded graphics mode")
	game.set_quality("auto")
	check(game.quality_mode == "auto" and game.effective_quality == "low", "Auto starts with the low-cost audience baseline")
	game.restart_game()
	game._damage_recruit(game.recruit_remaining)
	check(game.recruiting, "Recruitment is active before a quality switch")
	game.toggle_pause()
	before = fingerprint()
	var flight_before: Node3D = game.recruit_flight
	game.set_quality("high")
	check(game.phase == "paused" and game.recruit_flight == flight_before and fingerprint() == before, "Quality switch during paused recruitment preserves the flight and simulation")

func _test_attack_contact() -> void:
	game.restart_game()
	game.boss_z = game.PLAYER_Z - 2.39
	step(0.15)
	check(game.phase == "playing" and game.health == 100 and game.boss_state == "attack", "Near-line attack has a visible windup before applying fatal damage")
	check(game.boss_z <= game.PLAYER_Z - 2.39, "Attacking boss stops at the contact line instead of sliding through the player")
	game.toggle_pause()
	var attack_clock: float = game.boss_state_clock
	await create_timer(0.15).timeout
	step(0.4)
	check(game.boss_state_clock == attack_clock and game.health == 100, "Pause freezes a wound-up attack before its contact event")
	game.toggle_pause()
	step(0.65)
	check(game.phase == "lost" and game.health == 0 and game.metrics.breaches == 1 and game.metrics.losses == 1, "Animation contact applies one breach and one loss")
	step(1)
	check(game.metrics.breaches == 1 and game.metrics.losses == 1, "Terminal contact cannot apply its damage again")

func _test_auto_quality() -> void:
	game.restart_game()
	game.set_quality("auto")
	game.qa_mode = false
	game.elapsed = 4.0
	var before := fingerprint()
	game._update_adaptive_quality(0.2)
	for i in range(10): game._update_adaptive_quality(0.5)
	check(game.effective_quality == "low", "One slow frame and loading-size stalls do not trigger battery fallback")
	for i in range(50): game._update_adaptive_quality(0.05)
	check(game.effective_quality == "battery", "Sustained slow frames lower auto graphics to the battery budget")
	check(fingerprint() == before, "Adaptive fallback changes no gameplay state or RNG")
	game.set_quality("high")
	for i in range(60): game._update_adaptive_quality(0.05)
	check(game.effective_quality == "high", "An explicit quality selection is not silently overridden")
	game.qa_mode = true
	Engine.max_fps = 0

func fingerprint() -> String:
	var units: Array = []
	for c in game.crowd: units.append([c.x,c.z,c.alive])
	var packets: Array = []
	for b in game.bullets: packets.append([b.pos.x,b.pos.z,b.power,b.count,b.mask,b.tier])
	return JSON.stringify({"phase":game.phase,"time":game.elapsed,"wave":game.wave,"tier":game.tier,"recruit":game.recruit_remaining,"boss_hp":game.boss_hp,"boss_z":game.boss_z,"boss_dead":game.boss_dead,"boss_state":game.boss_state,"boss_state_clock":game.boss_state_clock,"boss_next_attack":game.boss_next_attack,"health":game.health,"kills":game.kills,"gold":game.gold_hp,"player_x":game.player_x,"target_x":game.target_x,"crowd_front":game.crowd_front,"crowd":units,"packets":packets,"recruiting":game.recruiting,"flight_clock":game.flight_clock,"metrics":game.metrics,"rng_state":game.rng.state}).sha256_text()

func steer_world(x: float) -> void:
	var event: InputEvent
	if not game.dragging:
		event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	else: event=InputEventMouseMotion.new()
	event.position=game.camera.unproject_position(Vector3(x,0,game.PLAYER_Z))
	game._unhandled_input(event)

func _test_full_run(mode: String) -> Dictionary:
	game.start_game()
	var frames := 0
	var fingerprints: Array[String] = [fingerprint()]
	while game.phase == "playing" and frames < 21600:
		if game.tier < 2: steer_world(3.2)
		elif game.gold_hp > 0:
			steer_world(2.95*cos((game.elapsed+(game.PLAYER_Z-0.6-game.GATE_Z[1])/32.0)*TAU/5.3))
		elif game.boss_dead or game._alive_crowd() < 100:
			var nearest: Dictionary = {}
			for c in game.crowd:
				if c.alive and (nearest.is_empty() or c.z < nearest.z): nearest=c
			if not nearest.is_empty(): steer_world(clampf(nearest.x,-4.55,4.55))
		else: steer_world(2.95*cos((game.elapsed+(game.PLAYER_Z-0.6-game.GATE_Z[1])/32.0)*TAU/5.3))
		game._physics_process(1.0/60.0)
		game._process(1.0/60.0)
		frames += 1
		if frames%60 == 0: fingerprints.append(fingerprint())
	fingerprints.append(fingerprint())
	check(game.phase == "won" and game.health > 0, mode + " quality permits an unmodified full-game win")
	return {"mode":mode,"effective_quality":game.effective_quality,"phase":game.phase,"elapsed":game.elapsed,"kills":game.kills,"health":game.health,"tier":game.tier,"snapshots":fingerprints.size(),"fingerprints":fingerprints}
