extends SceneTree
## Disposable desktop demonstration. No real save, ad request or purchase.
var game:Node3D
var directory:=""
func _initialize()->void:run.call_deferred()
func frames(count:int)->void:
	for _i in count:await process_frame
func snap(id:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(id+".png"))
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):directory=arg.trim_prefix("--output=")
	if not directory.is_absolute_path():quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4);game.set_process(false)
	game.music_enabled=false;game.audio.set_music_enabled(false)
	game.sfx_enabled=true;game.audio.set_sfx_enabled(true)
	game.coins=1000;game.last_unlock_msec=-1000
	game.ui.request_unlock();await frames(45);await snap("ready")
	seed(80421);game.ui.case_opening.begin_open()
	await frames(30);await snap("rolling")
	await frames(255);await snap("result")
	game.ui.case_opening.equip();await frames(140)
	game.ui.case_opening.continue_case();await frames(25)
	game.ui.case_opening.back();game.ui.open_rates();await frames(65);await snap("odds")
	print("CASE_CAPTURE "+JSON.stringify({"scope":"Mac GPU isolated 1000-coin QA fixture, no actual purchase, no player save","skins":game.owned_skin_ids,"coins":game.coins,"output":directory}))
	quit()
