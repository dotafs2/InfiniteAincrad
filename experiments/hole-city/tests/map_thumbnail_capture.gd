extends SceneTree
## Truthful close views of unchanged worlds; no player saves or staged scenery.
const COMPOSITIONS:={
	"city":{"focus":Vector3(0,4,17),"size":33.0,"offset":Vector3(48,46,58)},
	"food":{"focus":Vector3(-42,4.5,24),"size":23.0,"offset":Vector3(-30,44,-58)},
	"toys":{"focus":Vector3(23,11,69),"size":36.0,"offset":Vector3(44,38,64)},
	"frost":{"focus":Vector3(71,3,-69),"size":31.0,"offset":Vector3(60,40,-22)},
}
var directory:=""
var records:Array[Dictionary]=[]
var survey:=false
var only_map:=""
func _initialize()->void:run.call_deferred()
func capture(game:Node3D,id:String,suffix:String,composition:Dictionary)->void:
	var focus:Vector3=composition.focus
	game.camera.size=float(composition.size)
	game.camera.position=focus+Vector3(composition.offset);game.camera.look_at(focus)
	for _i in 8:await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image()
	assert(pixels.get_size()==Vector2i(880,620))
	var path:String=directory+"/"+id+suffix+".png"
	assert(pixels.save_png(path)==OK)
	records.append({"map":id,"resolved_map":game.selected_map,"world_map":game.world.get_meta("map_id"),
		"file":path,"focus":str(focus),"camera_size":composition.size,"camera_offset":str(composition.offset),
		"actual_world":true,"pose_policy":"Existing Idle poses evaluated once, then unchanged world frozen; no staged or rescaled actors."})
func run()->void:
	assert(OS.get_cmdline_user_args().has("--test"))
	assert(DisplayServer.get_name()!="headless")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):directory=argument.trim_prefix("--capture-dir=")
		elif argument=="--survey":survey=true
		elif argument.begins_with("--only-map="):only_map=argument.trim_prefix("--only-map=")
	assert(directory.is_absolute_path());DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(880,620)
	for id in ["city","food","toys","frost"]:
		if not only_map.is_empty() and id!=only_map:continue
		var game=load("res://fidelity/main.tscn").instantiate()
		game.unlocked_map_ids=game.available_map_ids();game.selected_map=id
		root.add_child(game)
		assert(game.test_mode and game.progress_file().is_empty())
		game.music_enabled=false;game.sfx_enabled=false
		game.audio.set_music_enabled(false);game.audio.set_sfx_enabled(false);game.audio.set_process(false)
		game.start_level();game.set_process(false);game.set_physics_process(false)
		assert(game.selected_map==id and game.world.get_meta("map_id")==id)
		for player in game.world.find_children("*","AnimationPlayer",true,false):player.advance(0.0)
		game.world.process_mode=Node.PROCESS_MODE_DISABLED;game.ui.visible=false
		for hole in game.holes:
			hole.active=false;hole.visible=false
			if is_instance_valid(hole.hole):hole.hole.visible=false
		game.ground.sync();game.reveal.reset()
		game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.far=800
		await capture(game,id,"",COMPOSITIONS[id])
		if survey:
			var alternative:Dictionary=COMPOSITIONS[id].duplicate()
			alternative["size"]=float(alternative.size)*.82
			await capture(game,id,"-tight",alternative)
			alternative=COMPOSITIONS[id].duplicate()
			alternative["offset"]=Vector3(48,46,58)
			await capture(game,id,"-reverse",alternative)
		game.free();await process_frame
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Actual Mac GPU worlds, camera-only close compositions and hidden gameplay HUD; not painted concepts or rearranged scenery.","records":records},"\t"))
	print("MAP_THUMBNAIL_CAPTURE "+JSON.stringify({"captures":records.size(),"failures":[],"output":directory}))
	quit()
