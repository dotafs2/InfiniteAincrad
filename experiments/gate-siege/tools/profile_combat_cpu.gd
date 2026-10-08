extends SceneTree
## Deterministic accelerated CPU comparison. Never interpret this as device FPS.
const Game = preload("res://scripts/game.gd")
var game: Node3D
var output := ""
var seconds := 20.0
var repeats := 3
var label := "unspecified"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--repeats="): repeats = int(arg.trim_prefix("--repeats="))
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	call_deferred("_run")

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"samples": 0}
	var sorted := values.duplicate(); sorted.sort()
	var sum := 0.0
	for value in sorted: sum += value
	return {"samples": values.size(), "mean": sum/values.size(), "p50": sorted[int(sorted.size()*0.5)], "p95": sorted[mini(sorted.size()-1,int(sorted.size()*0.95))], "max": sorted[-1], "min": sorted[0]}

func _run() -> void:
	root.size = Vector2i(720,1280)
	game = Game.new(); root.add_child(game)
	if not is_instance_valid(game.squad) or game.encounters == null:
		push_error("Game did not initialize"); game.queue_free(); quit(2); return
	game.qa_mode = true; game.auto_demo = false; game.audio_enabled = false
	game.set_process(false); game.set_physics_process(false); Engine.max_fps = 0
	var coverage := false
	for property in game.get_property_list():
		if property.name == "combat": coverage = true
	var rows: Array = []
	for mode in game.Campaign.WEAPONS:
		for repetition in range(repeats):
			_configure(mode)
			await process_frame
			var values: Array[float] = []
			var combat_ticks: Array[float] = []
			var between_ticks: Array[float] = []
			var peak_fields := 0
			var peak_cosmetics := 0
			for frame in range(ceili(seconds*60)):
				var previous_ticks: int = game.combat.resolved_ticks if coverage else 0
				var start := Time.get_ticks_usec()
				game._physics_process(1.0/60.0)
				var duration: float = Time.get_ticks_usec()-start
				values.append(duration)
				if coverage:
					if game.combat.resolved_ticks>previous_ticks: combat_ticks.append(duration)
					else: between_ticks.append(duration)
				peak_cosmetics = maxi(peak_cosmetics,game.bullets.size())
				if coverage: peak_fields = maxi(peak_fields,game.combat.fields.size())
				# Bound deferred node cleanup, outside the timed physics call.
				if frame%60 == 59: await process_frame
			var row := {"mode": mode, "repeat": repetition, "physics_us": stats(values), "combat_tick_us": stats(combat_ticks), "between_tick_us": stats(between_ticks), "simulation_seconds": game.elapsed, "phase": game.phase, "damage": game.metrics.damage, "members": game.squad.members.size(), "living_crowd": game._alive_crowd(), "peak_cosmetics_or_legacy_packets": peak_cosmetics, "peak_coverage_fields": peak_fields}
			rows.append(row)
			print("COMBAT_CPU_ROW ",JSON.stringify(row))
	var report := {"label": label, "engine": Engine.get_version_info(), "processor": OS.get_processor_name(), "display": DisplayServer.get_name(), "coverage_solver": coverage, "dt": 1.0/60.0, "repeats": repeats, "requested_simulation_seconds": seconds, "results": rows, "notes": "Accelerated fixed-step CPU timing only. All modes use 36 members, 544 high-HP troops, mixed high-HP elites and a high-HP dragon boss in wave 8. Actual normal physics is timed; no rendering or phone FPS claim. Damage values may differ between reviewed combat contracts. Setup and deferred deletion are outside timed calls."}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"  "))
	print("COMBAT_CPU_COMPLETE ",label)
	game.queue_free(); await process_frame; quit()

func _configure(mode: String) -> void:
	game.restart_game(); game.wave = 7; game.tier = 3; game._set_player_model()
	while game.squad.members.size()<36: game.squad.add_member()
	game.squad.rebuild(); game._start_wave()
	game.player_x = -1.7; game.target_x = -1.7; game.squad.update_visuals()
	game.health = 1e9; game.boss_hp = 1e12; game.boss_max = 1e12
	for c in game.crowd: c.hp = 1e12
	for e in game.encounters.enemies: e.health = 1e12; e.max_health = 1e12
	game.gold_hp = 0; game.bullets.clear(); game.sparks.clear()
	game.set_quality("low"); Engine.max_fps = 0; game.select_weapon(mode)
	game._step_recruit_lane(0); game._update_gates()
