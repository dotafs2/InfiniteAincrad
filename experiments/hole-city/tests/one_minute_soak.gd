extends SceneTree
## Normal automatic movement and real physics receipts, with no score/radius,
## position, wallet or ownership grants. This is not human retention evidence.
var checks:=0
var failures:Array[String]=[]
var rounds:Array[Dictionary]=[]
var game:Node3D
var output_path:=""
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=4)->void:
	for _i in count:await process_frame
func remaining_targets()->Dictionary:
	var larger:=0;var edible:=0;var nearby:=0
	for item in game.city.foods:
		if not is_instance_valid(item) or item.consumed:continue
		if item.footprint*1.08>game.player.radius:larger+=1
		elif item.can_fit(game.player):
			edible+=1
			if item.global_position.distance_to(game.player.global_position)<25:nearby+=1
	return {"larger":larger,"edible":edible,"edible_within_25m":nearby}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output_path=arg.trim_prefix("--report=")
	if output_path.is_empty():quit(2);return
	var run_count:=12
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak-rounds="):run_count=clampi(int(arg.trim_prefix("--soak-rounds=")),2,12)
	for run_index in run_count:
		var run_seed:=1501+run_index
		seed(run_seed)
		game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames()
		var expected_map:="food" if run_index%2==0 else "city"
		game.select_map(expected_map)
		check(game.selected_map==expected_map,"The actual map chooser selects "+expected_map)
		game.demo_mode=true
		var events:Array[Dictionary]=[]
		game.feedback.feedback_triggered.connect(func(event:Dictionary):events.append(event))
		game.start_level();game.begin_play()
		var moments:Array[Dictionary]=[]
		var next_moment:=10.0
		var ticks:=0
		while game.phase=="playing" and ticks<6000:
			await physics_frame;ticks+=1
			if game.elapsed>=next_moment:
				moments.append({"elapsed":game.elapsed,"score":game.player.score,"level":game.player.level,"radius":game.player.radius,"targets":remaining_targets()})
				next_moment+=10.0
		var label:="%s seed %d"%[game.selected_map,run_seed]
		check(game.phase=="complete" and absf(game.elapsed-game.round_duration())<.05,label+": ordinary play settles at its configured map duration")
		check(game.player.score>0 and game.player.level>1,label+": real movement collects and grows")
		check(not events.is_empty(),label+": actual human-player receipts produce feedback events")
		check(game.round_receipt.base_coins==game.round_coins and game.completed_runs==1,label+": the run settles one durable reward basis")
		var targets:=remaining_targets()
		check(int(targets.edible)>0 and int(targets.larger)>0,label+": smaller reachable classes and later growth classes remain at the finish")
		if not moments.is_empty():
			check(int(moments[0].targets.larger)>0,label+": the first growth interval retains larger food")
		rounds.append({"map":game.selected_map,"seed":run_seed,"elapsed":game.elapsed,"score":game.player.score,"level":game.player.level,"radius":game.player.radius,"deaths":game.round_deaths,"feedback_events":events.size(),"targets_at_finish":targets,"moments":moments})
		print("SOAK_ROUND "+JSON.stringify(rounds[-1]))
		game.audio.music.stop();game.free();await frames(8)
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"ok":failures.is_empty(),"rounds":rounds,"scope":"Normally simulated 60/90-second rounds with automatic movement, real physics and disposable profiles. No human retention, native SDK callback, speaker/haptic sensation or device GPU claim."}
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null:push_error("Cannot write soak report");quit(2);return
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ONE_MINUTE_SOAK "+JSON.stringify({"checks":checks,"failures":failures,"rounds":rounds.size(),"ok":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
