extends SceneTree
## Real desktop GPU pixels and ordinary timed play. Test mode never reads or
## writes the player's save or initializes production purchases / ad requests.
var game:Node3D
var directory:=""
var records:Array[Dictionary]=[]
var frame_intervals_ms:Array[float]=[]
var sampling_paused:=false
var last_frame_usec:=0
var build_ms:=0.0
var with_extension:=false
var extension_receipt:Dictionary={}
var slow_frames:Array[Dictionary]=[]
var cold_intervals_ms:Array[float]=[]
var steady_intervals_ms:Array[float]=[]
var pacing_diagnostics:Array[Dictionary]=[]
var next_pacing_moment:=0
const PACING_MOMENTS=[60.0,75.0,89.0]

func pacing_tick()->void:
	if not is_instance_valid(game) or game.phase!="playing" or next_pacing_moment>=PACING_MOMENTS.size():return
	if game.elapsed<float(PACING_MOMENTS[next_pacing_moment]):return
	next_pacing_moment+=1
	var palaces:Array[Dictionary]=[]
	for body in game.city.static_foods():
		if not is_instance_valid(body) or body.get_meta("toy_kind","")!="toy_castle":continue
		if int(body.get_meta("minimum_level",0))!=5:continue
		var owner:Node3D=body.claimed_by
		palaces.append({"name":body.name,"position":body.position,"consumed":body.consumed,
			"freeze":body.freeze,"claimed_by":owner.name if is_instance_valid(owner) else "",
			"required_radius":body.footprint*1.08,"fits":body.can_fit(game.player),
			"planar_distance":Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length()})
	var target:Node3D=game.player.target
	pacing_diagnostics.append({"elapsed":game.elapsed,"player_position":game.player.position,
		"score":game.player.score,"radius":game.player.radius,
		"target_name":target.name if is_instance_valid(target) else "",
		"target_kind":target.get_meta("toy_kind","") if is_instance_valid(target) else "",
		"settle_time":game.player.settle_time,"settle_at":game.player.settle_at,"palaces":palaces})

func _initialize()->void:run.call_deferred()

func capture(label:String,scope:String)->void:
	sampling_paused=true
	for _i in 6:await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	assert(picture!=null and not picture.is_empty())
	assert(picture.save_png(directory+"/"+label+".png")==OK)
	var record:={"file":label+".png","scope":scope,"map":game.selected_map,
		"phase":game.phase,"elapsed":game.elapsed,
		"score":game.player.score if is_instance_valid(game.player) else 0,
		"level":game.player.level if is_instance_valid(game.player) else 0,
		"radius":game.player.radius if is_instance_valid(game.player) else 0,
		"viewport":root.size,"menu":game.ui.menu_screen}
	if is_instance_valid(game.city):
		record["world_population"]=game.city.population_summary()
		var court:Node3D=game.city.get("court")
		if is_instance_valid(court):
			var states:Dictionary={}
			for actor in court.snapshot_states():
				if actor.released:continue
				states[actor.state]=int(states.get(actor.state,0))+1
			record["court"]={"population":court.population_summary(),"current_states":states,
				"recent_events":court.activity_receipts.duplicate(true)}
		if game.phase=="complete":
			var collected:Array=game.city.collection_receipts.filter(func(item):return bool(item.player))
			var kinds:Dictionary={};var tiers:Dictionary={}
			for item in collected:
				kinds[item.toy_kind]=int(kinds.get(item.toy_kind,0))+1
				tiers[str(item.tier)]=int(tiers.get(str(item.tier),0))+1
			record["player_collection_summary"]={"objects":collected.size(),"kinds":kinds,"tiers":tiers}
			record["player_collections"]=collected.duplicate(true)
	records.append(record)
	last_frame_usec=Time.get_ticks_usec()
	sampling_paused=false

func sample_frame()->void:
	var now:=Time.get_ticks_usec()
	if last_frame_usec>0 and not sampling_paused and is_instance_valid(game) and game.phase=="playing":
		var duration:=float(now-last_frame_usec)/1000.0
		frame_intervals_ms.append(duration)
		if game.elapsed<3.0:cold_intervals_ms.append(duration)
		else:steady_intervals_ms.append(duration)
		if duration>=33.333:
			slow_frames.append({"duration_ms":duration,"elapsed":game.elapsed,"radius":game.player.radius,
				"ground_rebuilds":game.ground.rebuilds})
			slow_frames.sort_custom(func(a,b):return float(a.duration_ms)>float(b.duration_ms))
			if slow_frames.size()>24:slow_frames.resize(24)
	last_frame_usec=now

func interval_summary(values:Array[float])->Dictionary:
	var ordered:=values.duplicate()
	ordered.sort()
	if ordered.is_empty():return {"sample_count":0}
	var total:=0.0
	for duration in ordered:total+=duration
	return {"sample_count":ordered.size(),"mean_ms":total/ordered.size(),
		"median_ms":ordered[int(ordered.size()*.5)],
		"p95_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],
		"max_ms":ordered[-1],"scope":"Actual desktop GPU frame intervals during normal play; excludes capture waits and PNG writes; not iPhone performance"}

func run()->void:
	assert(OS.get_cmdline_user_args().has("--test"))
	assert(DisplayServer.get_name()!="headless")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):directory=argument.trim_prefix("--capture-dir=")
		if argument=="--with-extension":with_extension=true
	assert(not directory.is_empty())
	DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true)
	process_frame.connect(sample_frame)
	physics_frame.connect(pacing_tick)
	game=load("res://fidelity/main.tscn").instantiate()
	var save_directory:=ProjectSettings.globalize_path("res://build/toy-city-20261003/normal-play-saves")
	DirAccess.make_dir_recursive_absolute(save_directory)
	game.test_progress_path=save_directory+"/normal-%d.cfg"%OS.get_process_id()
	assert(not FileAccess.file_exists(game.test_progress_path))
	game.unlocked_map_ids=game.available_map_ids()
	game.selected_map="toys";root.add_child(game)
	assert(game.selected_map=="toys" and game.test_mode)
	await process_frame
	await capture("toy-home","Actual home preview; no playable world or granted progress")
	game.ui.open_maps()
	await capture("toy-map-chooser","Actual map chooser and responsive controls")
	game.ui.close_menu()
	game.demo_mode=true
	var build_started:=Time.get_ticks_usec()
	game.start_level();game.begin_play()
	assert(game.selected_map=="toys" and game.world.get_meta("map_id")=="toys")
	assert(game.remaining==90.0)
	build_ms=float(Time.get_ticks_usec()-build_started)/1000.0
	for moment in [0.0,12.0,30.0,60.0,89.0]:
		while game.elapsed<moment and game.phase=="playing":await physics_frame
		await capture("toy-play-%02d"%int(moment),"Ordinary automatic collecting, real physics and shipped following camera; no injected position, score, radius, wallet or ownership")
	while game.phase=="playing":await physics_frame
	assert(game.phase=="complete" and game.remaining==0.0)
	assert(game.elapsed>=90.0 and game.elapsed<90.1)
	assert(not game.city.collection_receipts.is_empty() and game.player.score>0)
	await capture("toy-results","Actual timeout results from the normal round")
	if with_extension:
		var original_world:Node3D=game.world
		var original_score:int=game.player.score
		var before_gems:int=game.gems
		var button:Button
		for candidate in game.ui.buttons:
			if candidate.name=="extend-diamonds":button=candidate
		assert(is_instance_valid(button) and not button.disabled)
		button.pressed.emit()
		assert(game.phase=="playing" and game.world==original_world and game.player.score==original_score)
		assert(game.gems==before_gems-game.EXTENSION_GEM_COST and game.remaining==30)
		extension_receipt={"source":"Actual result button, five diamonds debited from the isolated fresh QA wallet; no ad or purchase request",
			"gems_before":before_gems,"gems_after":game.gems,"preserved_world":true,"score_at_resume":original_score}
		for moment in [105.0,119.0]:
			while game.elapsed<moment and game.phase=="playing":await physics_frame
			await capture("toy-play-%03d"%int(moment),"Ordinary collecting in the same world after the actual paid thirty-second continuation; no score/radius/position grants")
		while game.phase=="playing":await physics_frame
		await capture("toy-extended-results","Actual timeout after the paid continuation, with whole-body collection ledger")
	# Separate art-direction view, explicitly distinguished from gameplay.
	game.demo_mode=false;game.start_level()
	game.set_process(false);game.set_physics_process(false)
	game.city.set_process(false);game.city.set_physics_process(false)
	for hole in game.holes:hole.enabled=false
	game.ui.visible=false
	root.size=Vector2i(1280,960)
	# This staged camera is farther away than the ordinary follow camera's
	# 220 m clip plane; expand only this art-review view to retain the whole city.
	game.camera.far=800
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=225
	game.camera.position=Vector3(125,155,150)
	game.camera.look_at(Vector3(0,2,0))
	await capture("toy-city-overview","Staged art-direction camera of the actual newly built map; not a gameplay growth claim")
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({
		"version":ProjectSettings.get_setting("application/config/version"),
		"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),
		"muted":true,"native_capture":false,"records":records,
		"build_ms":build_ms,"normal_play_frame_intervals":interval_summary(frame_intervals_ms),"slow_frames":slow_frames,
		"cold_first3s_frame_intervals":interval_summary(cold_intervals_ms),
		"steady_after3s_frame_intervals":interval_summary(steady_intervals_ms),
		"pacing_diagnostics":pacing_diagnostics,
		"paid_extension":extension_receipt,"qa_progress_path":game.test_progress_path},"\t"))
	game.audio.set_music_enabled(false);game.audio.set_sfx_enabled(false)
	game.audio.set_process(false);await create_timer(.15).timeout
	game.free();await process_frame;quit()
