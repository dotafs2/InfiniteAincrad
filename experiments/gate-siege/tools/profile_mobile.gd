extends SceneTree
## External profiler: usable with an immutable --main-pack from an empty directory.
## Fixed GPU scenes and active gameplay are deliberately reported separately.
class ObservedGame extends "res://scripts/game.gd":
	var collecting := false
	var physics_us: Array[float] = []
	var visual_us: Array[float] = []
	var last_physics_us := 0
	var last_visual_us := 0
	func _physics_process(delta: float) -> void:
		var began := Time.get_ticks_usec()
		super._physics_process(delta)
		last_physics_us=Time.get_ticks_usec()-began
		if collecting: physics_us.append(float(last_physics_us))
	func _process(delta: float) -> void:
		var began := Time.get_ticks_usec()
		super._process(delta)
		last_visual_us=Time.get_ticks_usec()-began
		if collecting: visual_us.append(float(last_visual_us))

var game: ObservedGame
var output := ""
var label := "unlabeled"
var cpu_only := false
var quality := ""
var live_only := false
var frame_cap := 0
var demo_trace := false
var seconds := 2.5
var results: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-output="): output = arg.trim_prefix("--profile-output=")
		if arg.begins_with("--profile-label="): label = arg.trim_prefix("--profile-label=")
		if arg.begins_with("--profile-seconds="): seconds = float(arg.trim_prefix("--profile-seconds="))
		if arg == "--profile-cpu": cpu_only = true
		if arg == "--profile-live": live_only = true
		if arg == "--profile-demo": demo_trace = true
		if arg.begins_with("--profile-cap="): frame_cap = int(arg.trim_prefix("--profile-cap="))
		if arg.begins_with("--profile-quality="): quality = arg.trim_prefix("--profile-quality=")
	call_deferred("_run")

func summary(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"samples":0}
	var ordered := values.duplicate()
	ordered.sort()
	var sum := 0.0
	for v in ordered: sum += v
	return {"samples":ordered.size(),"mean":sum/ordered.size(),"p50":ordered[int(ordered.size()*0.5)],"p95":ordered[mini(ordered.size()-1,int(ordered.size()*0.95))],"max":ordered[-1]}

func _run() -> void:
	Engine.max_fps = frame_cap
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(486,864))
	game = ObservedGame.new()
	root.add_child(game)
	game.audio_enabled = false
	game.qa_mode = true
	game.auto_demo = false
	if not quality.is_empty():
		if not game.has_method("set_quality"):
			push_error("Requested quality cannot be selected: set_quality API missing")
			quit(2)
			return
		game.call("set_quality", quality)
	Engine.max_fps = frame_cap
	await process_frame
	var scenarios: Array = ["active_gameplay"] if live_only else ["full_crowd", "gunner_fans", "times999", "late_wave", "paused", "active_gameplay"]
	for scenario in scenarios:
		_configure(scenario)
		await process_frame
		var row: Dictionary
		if cpu_only:
			row = _cpu_profile(scenario)
		else:
			row = await _gpu_profile(scenario)
		results.append(row)
		var line := row.duplicate()
		if line.has("frames_over_30ms"):
			line["frames_over_30ms_count"] = line.frames_over_30ms.size()
			line.frames_over_30ms = line.frames_over_30ms.slice(0,6)
		print("PROFILE_SCENARIO ", JSON.stringify(line))
	var report := {"label":label,"mode":"headless_cpu" if cpu_only else "actual_gpu","engine":Engine.get_version_info(),"os":OS.get_name(),"processor":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"display":DisplayServer.get_name(),"quality_requested":quality,"viewport_3d_scale":root.scaling_3d_scale,"root_viewport":str(root.size),"window":str(DisplayServer.window_get_size()),"vsync":"disabled","frame_cap":frame_cap,"demo_trace":demo_trace,"movie_mode":false,"notes":"Fixed GPU scenarios keep production visual processing but freeze physics to retain the stated geometry. Active gameplay enables the real 60Hz physics loop. CPU-only scenarios manually run120 actual physics steps; their speed is not device FPS.","results":results}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"  "))
	print("PROFILE_COMPLETE ", label)
	game.queue_free()
	await process_frame
	quit()

func _configure(scenario: String) -> void:
	game.collecting = false
	game.restart_game()
	game.audio_enabled = false
	game.qa_mode = true
	Engine.max_fps = frame_cap
	game.set_physics_process(false)
	game.set_process(not cpu_only)
	game.bullets.clear()
	game.sparks.clear()
	game.player_x = -2.2
	game.target_x = -2.2
	if scenario in ["gunner_fans","times999","late_wave","paused"]:
		game.tier = 1 if scenario in ["gunner_fans","paused"] else 3
		game._set_player_model()
	if scenario == "late_wave":
		game.wave = 2
		game._start_wave()
	if scenario in ["times999","late_wave"]: game.gold_hp = 0
	if scenario in ["gunner_fans","times999","late_wave","paused"]:
		var count := 36 if scenario in ["gunner_fans","paused"] else 32
		for i in range(count):
			game.bullets.append({"pos":Vector3(-2.2,1.1,5.3-float(i)/count*20.0),"power":8.0 if game.tier==1 else 36.0,"count":10 if scenario in ["gunner_fans","paused"] else 9990,"width":3.3 if game.tier==1 else 4.5,"mask":7,"tier":game.tier})
		game._emit(Vector3(-2.2,1.0,-10),Color("77ffff"),200,0.08)
	if scenario == "paused": game.toggle_pause()
	game._update_gates()
	game._process(0)
	game.physics_us.clear()
	game.visual_us.clear()
	if scenario == "active_gameplay":
		game.auto_demo = demo_trace
		game.set_physics_process(true)

func _gpu_profile(scenario: String) -> Dictionary:
	var began := Time.get_ticks_usec()
	while Time.get_ticks_usec()-began < 1000000:
		await RenderingServer.frame_post_draw
	game.physics_us.clear()
	game.visual_us.clear()
	game.collecting = true
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var objects: Array[float] = []
	var frames_ms: Array[float] = []
	var crowd_counts: Array[float] = []
	var packet_counts: Array[float] = []
	var spikes: Array[Dictionary] = []
	began = Time.get_ticks_usec()
	var previous := began
	while Time.get_ticks_usec()-began < seconds*1000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var frame_ms := float(now-previous)/1000.0
		frames_ms.append(frame_ms)
		if frame_ms > 30:
			var state := {"wall_ms":float(now-began)/1000.0,"frame_ms":frame_ms,"elapsed":game.elapsed,"wave":game.wave,"tier":game.tier,"phase":game.phase,"crowd_alive":game._alive_crowd(),"packets":game.bullets.size(),"sparks":game.sparks.size(),"defeat_effects":game.kill_flashes.size(),"last_physics_us":game.last_physics_us,"last_visual_us":game.last_visual_us,"node_count":get_node_count(),"render_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
			for property in game.get_property_list():
				if property.name in ["boss_state","crowd_dirty","visual_dirty"]: state[property.name] = game.get(property.name)
			spikes.append(state)
		previous = now
		draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
		objects.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)))
		crowd_counts.append(game._alive_crowd())
		packet_counts.append(game.bullets.size())
	game.collecting = false
	game.set_physics_process(false)
	return {"scenario":scenario,"physics":"real60Hz" if scenario=="active_gameplay" else "frozen_staged_snapshot","wall_frame_ms":summary(frames_ms),"frames_over_30ms":spikes,"draw_calls":summary(draws),"primitives":summary(primitives),"rendered_objects":summary(objects),"visual_cpu_us":summary(game.visual_us),"physics_cpu_us":summary(game.physics_us),"alive_crowd":summary(crowd_counts),"packet_count":summary(packet_counts),"visible_bullet_instances":game.bullet_mm.multimesh.visible_instance_count,"mesh_batches":game.crowd_batches.size(),"phase":game.phase,"elapsed":game.elapsed}

func _cpu_profile(scenario: String) -> Dictionary:
	game.set_process(false)
	game.set_physics_process(false)
	for i in range(30):
		game._physics_process(1.0/60.0)
		game._process(1.0/60.0)
	game.physics_us.clear()
	game.visual_us.clear()
	game.collecting = true
	for i in range(120):
		game._physics_process(1.0/60.0)
		game._process(1.0/60.0)
	game.collecting = false
	return {"scenario":scenario,"physics_cpu_us":summary(game.physics_us),"visual_cpu_us":summary(game.visual_us),"phase":game.phase,"elapsed":game.elapsed,"alive_crowd":game._alive_crowd(),"packet_count":game.bullets.size(),"mesh_batches":game.crowd_batches.size()}
