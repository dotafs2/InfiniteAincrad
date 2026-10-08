extends SceneTree
## Fixed before/after cameras of actual royal city geometry, with no rearranged props.
const COMPOSITIONS:={
 "crown":{"focus":Vector3(-22,17,-64),"size":50.0,"offset":Vector3(44,24,58)},
 "crown-rear":{"focus":Vector3(-22,17,-64),"size":50.0,"offset":Vector3(-44,24,-58)},
 "neighborhood":{"focus":Vector3(24,6,34),"size":38.0,"offset":Vector3(-48,42,52)},
 "townhouses":{"focus":Vector3(-23,4,55),"size":30.0,"offset":Vector3(10,20,45)},
 "garden":{"focus":Vector3(-22,4,-54),"size":32.0,"offset":Vector3(25,22,55)},
 "overview":{"focus":Vector3(0,4,0),"size":210.0,"offset":Vector3(125,155,150)},
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
	assert(pixels.get_size()==Vector2i(1280,960))
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
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,960)
	for id in ["toys"]:
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
		for view in COMPOSITIONS:
			await capture(game,id,"-"+view,COMPOSITIONS[view])
		game.free();await process_frame
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Actual Mac GPU worlds, camera-only close compositions and hidden gameplay HUD; not painted concepts or rearranged scenery.","records":records},"\t"))
	print("MAP_THUMBNAIL_CAPTURE "+JSON.stringify({"captures":records.size(),"failures":[],"output":directory}))
	quit()
