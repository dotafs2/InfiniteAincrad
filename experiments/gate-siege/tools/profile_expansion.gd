extends SceneTree
## Independent expansion stress: staged population, real60-Hz physics, no movie mode.
class ObservedGame extends "res://scripts/game.gd":
	var collecting:=false
	var physics_us:Array[float]=[]
	var visual_us:Array[float]=[]
	var last_physics_us:=0
	var last_visual_us:=0
	func _physics_process(delta:float)->void:
		var began:=Time.get_ticks_usec();super._physics_process(delta)
		last_physics_us=Time.get_ticks_usec()-began
		if collecting: physics_us.append(float(last_physics_us))
	func _process(delta:float)->void:
		var began:=Time.get_ticks_usec();super._process(delta)
		last_visual_us=Time.get_ticks_usec()-began
		if collecting: visual_us.append(float(last_visual_us))
var game:ObservedGame
var output:=""
var quality:="low"
var frame_cap:=0
var seconds:=2.5
var warmup_seconds:=0.75
var has_coverage:=false
var results:Array=[]
var selected_scenarios:=PackedStringArray(["full_crowd","rifle","scatter","rail","rocket","arc","paused"])
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--quality="):quality=arg.trim_prefix("--quality=")
		if arg.begins_with("--cap="):frame_cap=int(arg.trim_prefix("--cap="))
		if arg.begins_with("--seconds="):seconds=float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--warmup="):warmup_seconds=float(arg.trim_prefix("--warmup="))
		if arg.begins_with("--scenarios="):selected_scenarios=arg.trim_prefix("--scenarios=").split(",")
	call_deferred("_run")
func stats(values:Array[float])->Dictionary:
	if values.is_empty():return {"samples":0}
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for v in sorted:total+=v
	return {"samples":values.size(),"mean":total/values.size(),"p50":sorted[int(sorted.size()*.5)],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted[-1],"min":sorted[0]}
func _run()->void:
	if DisplayServer.get_name()=="headless":push_error("This profiler requires an actual GPU display");quit(2);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(720,1280))
	root.size=Vector2i(720,1280)
	game=ObservedGame.new();root.add_child(game)
	for property in game.get_property_list():
		if property.name=="combat":has_coverage=true
	game.qa_mode=true;game.audio_enabled=false;game.auto_demo=false
	game.set_quality(quality);Engine.max_fps=frame_cap
	for i in range(6):await RenderingServer.frame_post_draw
	for scenario in selected_scenarios:
		_configure(scenario)
		var row:Dictionary=await _measure(scenario)
		results.append(row)
		var line:Dictionary=row.duplicate();line.erase("outliers")
		print("EXPANSION_PROFILE_SCENE ",JSON.stringify(line))
	var report:Dictionary={"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"processor":OS.get_processor_name(),"quality":quality,"cap":frame_cap,"window":str(DisplayServer.window_get_size()),"viewport":str(root.size),"scale":root.scaling_3d_scale,"movie_mode":false,"coverage_combat":has_coverage,"scenario_warmup_seconds":warmup_seconds,"vsync":"disabled","notes":"High-HP staged stress retains36 soldiers,544 troops,mixed elites and a dragon boss. Weapon scenes use normal real60-Hz physics and actual production combat. Full-crowd/paused intentionally freeze gameplay. Submitted trail slots may include shader-expired/unborn slots; they are not a CPU live-particle count. Desktop timings are not phone performance or ordinary-gameplay averages.","source_hashes":{},"results":results}
	for path in ["res://scripts/game.gd","res://scripts/squad.gd","res://scripts/campaign.gd","res://scripts/encounters.gd","res://scripts/creature_motion.gd","res://scripts/coverage_combat.gd","res://scripts/spray_visual.gd","res://assets/shaders/spray_visual.gdshader"]:report.source_hashes[path]=FileAccess.get_sha256(path)
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file:file.store_string(JSON.stringify(report,"  "))
	print("EXPANSION_PROFILE_COMPLETE ",quality," cap",frame_cap)
	game.queue_free();await process_frame;quit()
func _configure(scenario:String)->void:
	game.collecting=false;game.set_physics_process(false)
	game.restart_game();game.wave=7;game.tier=3;game._set_player_model()
	while game.squad.members.size()<36:game.squad.add_member()
	game.squad.rebuild();game._start_wave()
	game.player_x=-1.7;game.target_x=-1.7;game.squad.update_visuals()
	game.boss_hp=1e12;game.boss_max=1e12
	for c in game.crowd:c.hp=1e12
	for e in game.encounters.enemies:e.health=1e12;e.max_health=1e12
	game.gold_hp=0;game.bullets.clear();game.sparks.clear()
	game.set_quality(quality);Engine.max_fps=frame_cap
	if scenario in game.Campaign.WEAPONS:game.select_weapon(scenario)
	if scenario=="paused":game.toggle_pause()
	game._step_recruit_lane(0);game._update_gates();game.visual_dirty=true;game._process(0)
	game.set_physics_process(scenario in game.Campaign.WEAPONS)
func _measure(scenario:String)->Dictionary:
	var began:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-began<warmup_seconds*1e6:await RenderingServer.frame_post_draw
	game.physics_us.clear();game.visual_us.clear();game.collecting=true
	var frames:Array[float]=[];var draws:Array[float]=[];var triangles:Array[float]=[];var packets:Array[float]=[];var crowd:Array[float]=[];var fields:Array[float]=[];var outliers:Array=[]
	began=Time.get_ticks_usec();var previous:=began
	while Time.get_ticks_usec()-began<seconds*1e6:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();var ms:=float(now-previous)/1000.0;previous=now
		frames.append(ms);draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME));triangles.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME));packets.append(game.bullets.size());crowd.append(game._alive_crowd())
		if has_coverage:fields.append(game.get("combat").fields.size())
		if ms>50:outliers.append({"ms":ms,"wall":float(now-began)/1e6,"elapsed":game.elapsed,"weapon":game.weapon_mode,"packets":game.bullets.size(),"fields":game.get("combat").fields.size() if has_coverage else 0,"physics_us":game.last_physics_us,"visual_us":game.last_visual_us,"nodes":get_node_count(),"boss_hp":game.boss_hp,"recruit_hp":game.recruit_remaining,"damage":game.metrics.damage})
	game.collecting=false;game.set_physics_process(false)
	return {"scenario":scenario,"frame_ms":stats(frames),"draw_calls":stats(draws),"primitives":stats(triangles),"physics_cpu_us":stats(game.physics_us),"visual_cpu_us":stats(game.visual_us),"packets":stats(packets),"coverage_fields":stats(fields),"crowd":stats(crowd),"members":game.squad.members.size(),"elites":game.encounters.alive_count(),"submitted_trail_slots":game.bullet_mm.multimesh.visible_instance_count,"visual_cap":game.visual_bullet_cap,"phase":game.phase,"outliers":outliers,"over50ms":outliers.size()}
