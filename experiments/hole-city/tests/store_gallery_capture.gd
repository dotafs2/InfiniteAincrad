extends SceneTree
## Desktop layout evidence only. Ordinary movement/scoring and real menus;
## no position, wallet, ownership, radius or score grants for screenshots.
var game:Node3D
var directory:=""
var records:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func capture(label:String)->void:
	for _i in 8:await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	assert(picture.save_png(directory+"/"+label+".png")==OK)
	records.append({"file":label+".png","map":game.selected_map,"phase":game.phase,
		"elapsed":game.elapsed,"score":game.player.score if is_instance_valid(game.player) else 0,
		"level":game.player.level if is_instance_valid(game.player) else 0,"menu":game.ui.menu_screen,
		"coins":game.coins,"owned_skin_ids":game.owned_skin_ids.duplicate()})
func run()->void:
	assert(OS.get_cmdline_user_args().has("--test"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):directory=argument.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="city";game.demo_mode=true;game.start_level();game.begin_play()
	for moment in [0.0,18.0,40.0,58.0]:
		while game.elapsed<moment and game.phase=="playing":await physics_frame
		await capture("city-%02d"%int(moment))
	while game.phase=="playing":await physics_frame
	game.back_home();await capture("home-after-city")
	game.ui.open_holes()
	for page in game.ui.skin_tiers.size():
		game.ui.set_skin_scroll(game.ui.skin_tiers[page].y)
		await capture("skins-tier-%d"%page)
	game.selected_map="food";game.demo_mode=true;game.start_level();game.begin_play()
	while game.elapsed<25 and game.phase=="playing":await physics_frame
	game.demo_mode=false
	var next_capture:=0;var train_frames:=0
	while game.phase=="playing":
		var closest:Node3D;var distance:=INF
		for car in game.train_controller.cars:
			if not is_instance_valid(car) or car.consumed:continue
			var gap:float=car.global_position.distance_to(game.player.global_position)
			if gap<distance:closest=car;distance=gap
		if is_instance_valid(closest):
			var offset:Vector3=closest.global_position-game.player.global_position
			game.player.test_direction=Vector2(offset.x,offset.z).normalized() if distance>.4 else Vector2.ZERO
		if distance<18 and train_frames<3 and Time.get_ticks_msec()>=next_capture:
			await capture("sushi-express-%d"%train_frames);train_frames+=1;next_capture=Time.get_ticks_msec()+2000
		await physics_frame
	await capture("food-result")
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({
		"scope":"Desktop gameplay/menu capture. No injected score, radius, position, wallet or ownership; camera remains the shipped following camera. Food route follows actual train positions after 25 seconds of ordinary automatic collecting.",
		"version":ProjectSettings.get_setting("application/config/version"),"records":records,
		"train_frames":train_frames,"native_capture":false,"ready_for_upload":false},"\t"))
	game.audio.music.stop();OS.delay_msec(120);game.free();await process_frame;quit()
