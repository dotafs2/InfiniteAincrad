extends SceneTree
## Real rendered case UI with explicitly isolated Common/Prismatic eligible pools.
## --test disables player save access. Host audio remains muted.
var game:Node3D
var directory:=""
var evidence:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func frames(count:int)->void:
	for _i in count:await process_frame
func snap(id:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(id+".png"))
func fixture(id:String)->void:
	game.owned_skin_ids.clear()
	for definition in game.SKIN_DEFS:
		if str(definition.id)!=id:game.owned_skin_ids.append(str(definition.id))
	game.selected_skin_id="cocoa_square";game.coins=350;game.draw_pity={}
	game.skin_case_receipt={};game.last_unlock_msec=-1000
	game.ui.case_opening.stage="ready"
	game.ui.request_unlock();game.ui.case_opening.enter();game.ui.refresh()
func record(id:String,prefix:String,skip:bool)->void:
	fixture(id);await frames(35);await snap(prefix+"-ready")
	seed(80421);game.ui.case_opening.begin_open()
	var receipt:Dictionary=game.pending_skin_case()
	if skip:
		await frames(55);game.ui.case_opening.reveal()
	else:
		while game.ui.case_opening.stage=="rolling":await process_frame
	var spent_coins:int=game.coins
	await frames(9);await snap(prefix+"-onset")
	await frames(10);await snap(prefix+"-peak")
	await frames(21);await snap(prefix+"-drift")
	await frames(33);await snap(prefix+"-tail")
	await frames(35);await snap(prefix+"-settled")
	evidence.append({"skin":id,"mode":"skip" if skip else "natural", "receipt_id":receipt.case_id,
		"coins_before":350,"coins_after":game.coins,"award_unchanged":game.pending_skin_case()==receipt,
		"coins_unchanged_during_effect":game.coins==spent_coins,
		"burst_finished":not game.ui.case_opening.celebration.active,
		"effect_processing_stopped":not game.ui.case_opening.celebration.is_processing()})
	game.ui.case_opening.continue_case()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):directory=arg.trim_prefix("--output=")
	if not directory.is_absolute_path():quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4);game.set_process(false)
	game.music_enabled=false;game.audio.set_music_enabled(false)
	game.sfx_enabled=false;game.audio.set_sfx_enabled(false)
	assert(game.test_mode and game.progress_file().is_empty())
	await record("plain_loop","common",false)
	await record("aurora_rift__solar_rift","prismatic",true)
	var data:={"scope":"Muted actual Mac GPU case UI. Common and Prismatic use explicit isolated one-skin eligible pools, not organic rare-roll claims. No player save, production ad or purchase.","viewport":"540x960","observations":evidence}
	var file:=FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  "));file.close()
	print("CELEBRATION_CAPTURE "+JSON.stringify(data))
	game.free();await frames(2);quit()
