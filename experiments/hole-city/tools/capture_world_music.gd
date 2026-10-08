extends SceneTree
## Actual Mac GPU/audio mixer capture with disposable progression and Dummy output.
var game:Node3D
var directory:=""
var timeline:Array[Dictionary]=[]
var caption:Label
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for _i in n:await process_frame
func mark(label:String)->void:
	caption.text="AUDIO REVIEW  ·  "+label
	timeline.append({"label":label,"frame":Engine.get_process_frames(),"seconds":Engine.get_process_frames()/60.0,"route":game.audio.current_track,"target":game.audio.target_track,"music_db":game.audio.music.volume_db})
func snap(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):directory=arg.trim_prefix("--output=")
	if not directory.is_absolute_path():quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	game.unlocked_map_ids=game.available_map_ids()
	game.music_enabled=true;game.audio.set_music_enabled(true)
	game.sfx_enabled=true;game.audio.set_sfx_enabled(true)
	game.audio.unlock_from_gesture()
	var layer:=CanvasLayer.new();layer.layer=50;root.add_child(layer)
	caption=Label.new();caption.position=Vector2(12,927);caption.size=Vector2(510,24)
	caption.add_theme_font_size_override("font_size",15)
	caption.add_theme_color_override("font_color",Color.WHITE)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",1);caption.add_theme_constant_override("shadow_offset_y",1)
	layer.add_child(caption)
	mark("Menu · Buy Something!");await frames(240);await snap("menu")
	var titles:={"city":"Hometown","food":"Sunshine Coast","toys":"Children's March","frost":"Through the Snow"}
	for id in ["city","food","toys","frost"]:
		game.select_map(id);game.start_level();mark(id.capitalize()+" · "+titles[id])
		await frames(360);await snap(id)
		game.back_home();await frames(36)
	game.coins=500;game.last_unlock_msec=-1000
	game.ui.request_unlock();mark("Case · A Little Wonder");await frames(180);await snap("case-ready")
	seed(80421);game.ui.case_opening.begin_open();mark("Full opening · timed phrase + ticks")
	await frames(290);await snap("case-result");await frames(90)
	game.ui.case_opening.continue_case();await frames(60)
	# Test clock guard is respected in wall time even under offline MovieWriter.
	OS.delay_msec(820);await frames(2)
	game.ui.case_opening.begin_open();mark("Early skip · same committed award")
	await frames(90);game.ui.case_opening.reveal();mark("SKIP · opening voice replaced by reveal")
	await frames(180);await snap("case-skip")
	var report:={"scope":"Actual Mac engine render and audio mixer; isolated500-coin fixture, two100-coin draws; no player save, real ad or purchase","timeline":timeline,"frames":Engine.get_process_frames(),"coins":game.coins,"music_contexts":game.audio.TRACKS.keys(),"limitation":"Host output uses Dummy; no physical-device or subjective-listening claim"}
	FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_MUSIC_CAPTURE "+JSON.stringify(report))
	quit()
