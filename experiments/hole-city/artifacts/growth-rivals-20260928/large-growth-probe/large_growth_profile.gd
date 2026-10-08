extends SceneTree
## Bounded CPU stress probe. All timings exclude GPU rendering.
## The only gameplay override suppresses the ordinary 500-point win condition.
class ProfileGame:
	extends "res://fidelity/game.gd"
	var probe_frame:=-1
	var physics_steps:=0
	var rival_scans:=0
	var food_scans:=0
	var camera_updates:=0
	var dynamic_snapshots:Array[Dictionary]=[]
	var peak_dynamic:=0
	var peak_falling:=0
	var measured_peak_dynamic:=0
	var measured_peak_falling:=0
	var last_dynamic:=0
	var last_falling:=0
	var observed_falling:Dictionary={}
	func food_goal_complete()->bool:return false
	func _physics_process(delta:float)->void:
		physics_steps+=1
		super._physics_process(delta)
	func scan_rivals(delta:=0.0)->void:
		rival_scans+=1
		super.scan_rivals(delta)
	func update_camera(delta:float,instant:=false)->void:
		camera_updates+=1
		super.update_camera(delta,instant)
	func scan_food()->void:
		food_scans+=1
		super.scan_food()
		# Read the already-maintained active index only at admission cadence.
		# This is sampled dynamic load, not an unmeasured per-frame scene scan.
		var dynamic:=0;var falling:=0;var claimed:=0
		for value in city.food_queries.active.values():
			if not is_instance_valid(value):continue
			var body:RigidBody3D=value
			if body.consumed or body.freeze:continue
			dynamic+=1
			if is_instance_valid(body.claimed_by):claimed+=1
			if body.linear_velocity.y<-.15:
				falling+=1;observed_falling[body.get_instance_id()]=true
		last_dynamic=dynamic;last_falling=falling
		peak_dynamic=maxi(peak_dynamic,dynamic);peak_falling=maxi(peak_falling,falling)
		if probe_frame>=60:
			measured_peak_dynamic=maxi(measured_peak_dynamic,dynamic)
			measured_peak_falling=maxi(measured_peak_falling,falling)
		dynamic_snapshots.append({"frame":probe_frame,"elapsed":elapsed,"dynamic":dynamic,"falling":falling,"claimed":claimed})

var game:ProfileGame
var map_id:="city"
var report_path:=""
var source_manifest_path:=""
var intervals:Array[float]=[]
var timeline:Array[Dictionary]=[]
var receipts:Array[Dictionary]=[]
var measured_receipts:=0
var player_receipts:=0
var measured_player_receipts:=0
var failures:Array[String]=[]

func _initialize()->void:run.call_deferred()
func percentile(ordered:Array[float],q:float)->float:
	return ordered[mini(ordered.size()-1,int(ordered.size()*q))] if not ordered.is_empty() else 0.0
func counters()->Dictionary:
	return {"physics":game.physics_steps,"rivals":game.rival_scans,"food":game.food_scans,"camera":game.camera_updates,"reveal":game.reveal.update_count,"ground":game.ground.rebuilds,"receipts":receipts.size(),"eaten":game.eaten,"elapsed":game.elapsed}
func alive_rivals()->int:
	var count:=0
	for hole in game.holes:
		if hole!=game.player and hole.active:count+=1
	return count
func collected(item:Node3D,hole:Node3D)->void:
	var human:bool=hole==game.player
	if human:player_receipts+=1
	if game.probe_frame>=60:
		measured_receipts+=1
		if human:measured_player_receipts+=1
	var top:float=item.global_position.y+(item.vertical_extent() if item.has_method("vertical_extent") else item.height*.5)
	receipts.append({"frame":game.probe_frame,"elapsed":game.elapsed,"category":item.category,"points":item.points,"owner":hole.display_name,"player":human,"owner_score":hole.score,"consumed":item.consumed,"freeze":item.freeze,"top_y":top,"position":[item.position.x,item.position.y,item.position.z]})

@warning_ignore("integer_division")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):map_id=arg.trim_prefix("--map=")
		elif arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
		elif arg.begins_with("--source-manifest="):source_manifest_path=arg.trim_prefix("--source-manifest=")
	if map_id not in ["city","food"] or not report_path.is_absolute_path() or not source_manifest_path.is_absolute_path():
		push_error("The large-growth probe requires a valid map and absolute report/source-manifest paths");quit(2);return
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(source_manifest_path))
	if not manifest is Dictionary or not manifest.has("source_sha256"):
		push_error("The large-growth probe requires a source hash manifest");quit(2);return
	Engine.max_fps=0;Engine.physics_ticks_per_second=60
	game=ProfileGame.new();root.add_child(game)
	game.selected_map=map_id;game.start_level()
	for index in game.holes.size():
		var hole:Node3D=game.holes[index]
		if hole!=game.player:hole.score=350;hole.level=8;hole.radius=7.2
		hole.position=Vector3(-30+(index%4)*20,0,-15+(index/4)*30)
		hole._sync_shape()
	game.player.award(5000)
	var initial:={"player_score":game.player.score,"player_level":game.player.level,"player_radius":game.player.radius,"alive_rivals":alive_rivals(),"rival_score":350,"rival_level":8,"rival_radius":7.2}
	if initial.player_score!=5000 or initial.player_level!=19 or absf(initial.player_radius-23.9166666666667)>.00001:failures.append("Player did not reach the intended size through a real award")
	game.reset_rival_state();game.update_camera(1.0,true)
	game.item_collected.connect(collected)
	game.begin_play()
	var start:=Time.get_ticks_usec();var previous:int=start
	var baseline:Dictionary={}
	for frame in 660:
		game.probe_frame=frame
		game.player.test_direction=Vector2(cos(frame*.018),sin(frame*.018))
		await process_frame
		var now:=Time.get_ticks_usec()
		if frame==59:baseline=counters()
		if frame>=60:
			intervals.append(float(now-previous)/1000.0)
			timeline.append({"frame":frame,"elapsed":game.elapsed,"score":game.player.score,"level":game.player.level,"radius":game.player.radius,"alive_rivals":alive_rivals(),"dynamic_last_sample":game.last_dynamic,"falling_last_sample":game.last_falling,"collections":receipts.size(),"combat_events":game.rival_combat_events.size()})
		previous=now
	var wall_seconds:=float(Time.get_ticks_usec()-start)/1e6
	var end:=counters();var measured:Dictionary={}
	for key in ["physics","rivals","food","camera","reveal","ground","receipts","eaten","elapsed"]:measured[key]=end[key]-baseline[key]
	var ordered:Array[float]=intervals.duplicate();ordered.sort()
	if intervals.size()!=600:failures.append("Expected 600 measured frame intervals")
	for key in ["physics","rivals","camera","reveal"]:
		if measured[key]!=600:failures.append("Expected 600 active measured updates: "+key)
	if measured.food<90:failures.append("Food admission did not run at normal cadence")
	if measured_receipts<=0 or measured_player_receipts<=0:failures.append("No real measured collection receipts for the enlarged player")
	if game.measured_peak_dynamic<=0 or game.measured_peak_falling<=0:failures.append("No active falling physics observed in the measured scene")
	if game.phase!="playing" or not game.player.active:failures.append("The stress scene stopped before completing the sample")
	var result:={"marker":"LARGE_GROWTH_PROFILE","scope":"Mac headless CPU wall intervals, including lightweight instrumentation; excludes GPU work and is not phone FPS","map":map_id,"scenario":"large-growth-real-round","version":ProjectSettings.get_setting("application/config/version"),"headless":DisplayServer.get_name()=="headless","os":OS.get_name(),"engine":Engine.get_version_info().string,"physics_hz":Engine.physics_ticks_per_second,"warmup_frames":60,"samples":intervals.size(),"frame_times_ms":intervals,"timeline":timeline,"wall_seconds":wall_seconds,"simulation_seconds":game.elapsed,"initial":initial,"final":{"score":game.player.score,"level":game.player.level,"radius":game.player.radius,"phase":game.phase,"alive_rivals":alive_rivals()},"measured_updates":measured,"p50_ms":percentile(ordered,.5),"p95_ms":percentile(ordered,.95),"p99_ms":percentile(ordered,.99),"worst_ms":percentile(ordered,1),"over_16_67_ms":intervals.filter(func(value):return value>16.667).size(),"collections_total":receipts.size(),"collections_measured":measured_receipts,"player_collections_total":player_receipts,"player_collections_measured":measured_player_receipts,"collection_receipts":receipts,"combat_events":game.rival_combat_events.duplicate(true),"sampled_peak_dynamic":game.peak_dynamic,"sampled_peak_falling":game.peak_falling,"measured_sampled_peak_dynamic":game.measured_peak_dynamic,"measured_sampled_peak_falling":game.measured_peak_falling,"unique_observed_falling":game.observed_falling.size(),"dynamic_sample_cadence":"After each ordinary scan_food call, approximately every0.09s; peaks are observed samples","dynamic_snapshots":game.dynamic_snapshots,"reveal":game.reveal.diagnostics(),"reveal_strength":game.reveal.target.w,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"source_sha256":manifest.source_sha256,"failures":failures}
	game.free();await process_frame
	var report:=FileAccess.open(report_path,FileAccess.WRITE)
	if report==null:push_error("Cannot write large-growth profile report");quit(2);return
	report.store_string(JSON.stringify(result,"\t"));report.close()
	print("LARGE_GROWTH_PROFILE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
