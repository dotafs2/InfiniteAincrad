extends SceneTree
## Captures the real renderer and normal automated play; no injected score.
var game:Node3D
var directory:=""
func _initialize()->void:run.call_deferred()
func frame(label:String)->void:
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image!=null and not image.is_empty())
	assert(image.save_png(directory+"/"+label+".png")==OK)
func run()->void:
	assert(OS.get_cmdline_user_args().has("--test"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):directory=arg.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await process_frame;await frame("home")
	game.selected_map="food";game.demo_mode=true
	game.start_level();game.begin_play()
	var records:=[]
	for moment in [0.0,12.0,25.0,40.0,58.0]:
		while game.elapsed<moment and game.phase=="playing":await physics_frame
		await frame("food-%02d"%int(moment))
		records.append({"time":game.elapsed,"score":game.player.score,"level":game.player.level,
			"position":game.player.position,"phase":game.phase})
	var file:=FileAccess.open(directory+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual desktop renderer, automated normal physics play, no score or radius injection; not physical iPhone evidence.","viewport":root.get_visible_rect(),"records":records},"\t"))
	game.free();await process_frame;quit()
