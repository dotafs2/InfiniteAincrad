extends SceneTree
## Actual home controls and miniature framing variants for art review. Explicit
## camera overrides are staged design comparisons, not shipped gameplay claims.
var game:Node3D
var directory:=""
var records:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func capture(label:String,scope:String)->void:
	for _i in 8:await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	assert(picture!=null and not picture.is_empty())
	assert(picture.save_png(directory+"/"+label+".png")==OK)
	records.append({"file":label+".png","scope":scope,"map":game.selected_map,
		"viewport":root.size,"hero_position":game.ui.hero.position,"hero_size":game.ui.hero.size})
func run()->void:
	assert(OS.get_cmdline_user_args().has("--test") and DisplayServer.get_name()!="headless")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):directory=argument.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true)
	game=load("res://fidelity/main.tscn").instantiate()
	game.selected_map="toys";root.add_child(game);await process_frame
	await capture("toy-home-source","Actual current home UI and shipped toy camera; no played world")
	for child in game.ui.hero_view.get_children():
		if child is Camera3D:
			child.size=14.5;child.look_at(Vector3(0,1.6,0))
	await capture("toy-home-framing-14_5","Staged miniature camera design variant size14.5/looky1.6; unchanged game controls")
	game.ui.hero_models.set_process(false)
	for angle in [0,45,90,135,180,225,270,315]:
		game.ui.hero_models.preview.rotation.y=deg_to_rad(float(angle))
		await capture("toy-home-turn-%03d"%angle,"Staged rotation of the actual miniature at camera14.5/looky1.6; controls and original geometry preserved")
	for map_id in ["city","food"]:
		game.select_map(map_id)
		await capture(map_id+"-home-source","Actual unchanged prior-map home miniature framing and lighting")
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({
		"scope":"Actual desktop GPU UI; toy camera variant explicitly staged, no native safe-area or normal-play claim",
		"muted":true,"records":records},"\t"))
	game.free();await process_frame;quit()
