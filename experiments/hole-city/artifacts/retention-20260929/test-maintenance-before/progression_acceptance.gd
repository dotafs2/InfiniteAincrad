extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var path:="/tmp/hole-stage-qa-%d.cfg"%OS.get_process_id()
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.test_progress_path=path
	game.stage=4;game.start_level();game.begin_play()
	check(game.remaining==240 and game.SCORE_TARGET==500,"Opening matches observed 240-second / 500-point reference")
	game.player.score=500
	var moving:RigidBody3D=game.city.foods.filter(func(b):return not is_instance_valid(b.support_parent) and b.category!="building")[0]
	moving.freeze=false;moving.position=Vector3(65,9,65);moving.linear_velocity=Vector3.DOWN
	var start_y:float=moving.position.y
	game.finish("complete")
	check(game.stage==5 and game.round_start_stage==4,"Completion advances the visible persistent stage once")
	check(game.round_coins==70 and game.round_score_coins==50 and game.round_win_coins==20,"Reward has transparent score and victory components")
	check(not moving.freeze,"Result does not freeze a body in the air")
	for i in 30:await physics_frame
	check(is_instance_valid(moving) and moving.position.y<start_y-1,"Released object continues descending after settlement")
	var coins:int=game.coins
	game.finish("complete")
	check(game.stage==5 and game.coins==coins,"Repeated completion cannot duplicate rank or reward")
	var cfg:=ConfigFile.new();check(cfg.load(path)==OK,"Progress writes an isolated save")
	check(cfg.get_value("progress","stage")==5 and cfg.get_value("progress","coins")==coins,"Rank and reward persist atomically")
	var fresh:Node3D=load("res://fidelity/game.gd").new();fresh.test_progress_path=path
	check(fresh.load_player_progress() and fresh.stage==5 and fresh.coins==coins,"Cold restore retains new stage and balance")
	fresh.free()
	for result in ["timeout","eaten"]:
		game.start_level();game.begin_play();game.player.score=40;game.finish(result)
		check(game.stage==5,"Unsuccessful result does not advance stage: "+result)
		check(game.round_score_coins==4 and game.round_win_coins==0,"Unsuccessful result shows score-only reward")
	game.start_level();game.begin_play();game.back_home()
	check(game.stage==5,"Abandoning a round does not advance rank")
	game.start_level();game.begin_play();game.player.score=0;game.finish("complete")
	check(game.stage==5 and game.round_coins==0,"Empty synthetic completion grants neither rank nor coins")
	game.free();await process_frame
	for suffix in ["",".tmp",".pre-coins.cfg"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	var result:={"checks":checks,"failures":failures}
	print("PROGRESSION_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
