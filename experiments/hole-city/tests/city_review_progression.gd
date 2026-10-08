extends SceneTree
## Independent review of settlement: physical late receipt and disk retry edges.
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func review_source_hash(path:String)->Variant:
	# Exported packages can contain compiled scripts without original source text.
	if not FileAccess.file_exists(path):return null
	var digest:=FileAccess.get_sha256(path)
	return null if digest.is_empty() else digest
func write_optional_report(result:Dictionary)->bool:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():return true
	if not output.is_absolute_path() or "://" in output:
		push_error("Review report requires an absolute filesystem path: "+output)
		return false
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		push_error("Could not write review report: %s (error %d)"%[output,FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(result,"\t")+"\n");file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:
		push_error("Could not finish review report: %s (error %d)"%[output,error])
		return false
	return true
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false)
	for h in game.holes:h.enabled=false;h.active=false
	game.player.active=true;game.player.radius=2.0;game.player._sync_shape()
	var food:RigidBody3D=game.city.foods.filter(func(b):return b.category=="cone")[0]
	game.player.position=Vector3(food.position.x,0,food.position.z)
	for tick in 4:await physics_frame
	check(food.begin_swallow(game.player),"A real cone begins swallowing before settlement")
	game.player.score=49;game.stage=7
	game.finish("unknown")
	check(game.phase=="playing" and game.stage==7,"Unknown settlement reason is rejected")
	game.finish("timeout")
	var coins:int=game.coins;var eaten:int=game.eaten
	check(game.round_coins==4 and game.round_score_coins==4 and game.round_win_coins==0 and game.stage==8,"49 points pay four whole coins and advance stage once")
	check(not food.freeze,"Actual claimed cone remains physically released")
	for tick in 180:
		await physics_frame
		if not is_instance_valid(food):break
	check(not is_instance_valid(food),"Claimed cone finishes physical fall after settlement")
	check(game.player.score==49 and game.coins==coins and game.eaten==eaten,"Late physical receipt cannot modify score, coins or counts")
	# This save-retry fixture is a distinct new run. Merely forcing the old
	# result back to playing represents continuation and must not grant stage9.
	game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false)
	for h in game.holes:h.enabled=false
	game.player.score=500
	game.test_progress_path="/tmp/nonexistent-city-review-%d/progress.cfg"%OS.get_process_id()
	game.finish("complete")
	check(game.progress_dirty and game.stage==9,"Failed disk write keeps awarded progress dirty for retry")
	var retry_coins:int=game.coins;game.finish("complete")
	check(game.stage==9 and game.coins==retry_coins,"Failed save does not permit duplicate settlement")
	var path:="/tmp/city-review-progress-%d.cfg"%OS.get_process_id()
	game.test_progress_path=path
	check(game.save_player_progress() and not game.progress_dirty,"Later writable save completes settlement retry")
	var cfg:=ConfigFile.new();cfg.load(path)
	check(cfg.get_value("progress","stage")==9 and cfg.get_value("progress","coins")==retry_coins,"Retry persists the single awarded stage and balance")
	var result:={"checks":checks,"failures":failures,"game_sha256":review_source_hash("res://fidelity/game.gd")}
	game.free();await process_frame
	for suffix in ["",".tmp",".pre-coins.cfg"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	result["source_hash_note"]="Null means source text is unavailable in this runtime; package identity is recorded by the release gate."
	var report_ok:=write_optional_report(result)
	print("CITY_REVIEW_PROGRESSION "+JSON.stringify(result))
	quit(0 if failures.is_empty() and report_ok else 1)
