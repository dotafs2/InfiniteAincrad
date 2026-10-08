extends SceneTree
## A labeled art camera and explicit late-growth fixture, never a pacing claim.
var game:Node3D
var output:=""
var ledger:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func frames(count:int)->void:
	for _i in count:await process_frame
func snap(id:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(id+".png"))
func collected(body:Node3D,hole:Node3D)->void:
	ledger.append({"body":str(body.name),"kind":body.get_meta("toy_kind",""),"points":body.points,"player":hole==game.player})
func run()->void:
	assert(OS.get_cmdline_user_args().has("--test") and DisplayServer.get_name()!="headless")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	assert(output.is_absolute_path());DirAccess.make_dir_recursive_absolute(output)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate()
	game.unlocked_map_ids=game.available_map_ids();game.selected_map="toys";root.add_child(game)
	assert(game.test_mode and game.progress_file().is_empty())
	game.music_enabled=false;game.sfx_enabled=false
	game.audio.set_music_enabled(false);game.audio.set_sfx_enabled(false);game.audio.set_process(false)
	game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
	game.city.set_process(false);game.city.set_physics_process(false);game.city.court.set_process(false)
	for actor in game.world.find_children("*","AnimationPlayer",true,false):actor.advance(0.0)
	game.ui.visible=false
	for hole in game.holes:
		hole.enabled=false;hole.set_process(false);hole.set_physics_process(false)
		hole.active=false;hole.visible=false
		if is_instance_valid(hole.hole):hole.hole.visible=false
	game.ground.sync();game.reveal.reset()
	var layer:=CanvasLayer.new();root.add_child(layer)
	var label:=Label.new();layer.add_child(label);label.position=Vector2(24,20)
	label.size=Vector2(492,84);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",20);label.add_theme_color_override("font_shadow_color",Color(.03,.07,.12,.9));label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
	label.text="BUBBLE TOY TOWN · ROYAL COURT"
	var target:Node3D
	for body in game.city.foods:
		if body.get_meta("toy_kind","")=="grand_castle" and absf(body.position.x+22)<.1 and absf(body.position.z+64)<.1:target=body;break
	assert(is_instance_valid(target))
	var focus:=Vector3(-22,15,-64)
	game.camera.far=800;game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=50
	for frame in 150:
		var t:float=float(frame)/149.0
		game.camera.position=focus+Vector3(44.0-18.0*t,24,58)
		game.camera.look_at(focus)
		await process_frame
	await snap("castle-hero")
	label.text="STAGED ROYAL COURT SWEEP · REAL PHYSICS"
	var player:Node3D=game.player
	player.level=12;player.score=player.level_start_for(12);player.radius=player.radius_for_level(12)
	player.position=Vector3(-22,0,-64);player.velocity=Vector3.ZERO
	player.active=true;player.visible=true;player._update_badge();player.hole.visible=true
	game.ground.sync();game.reveal.reset()
	game.item_collected.connect(collected)
	await frames(20)
	assert(target.can_fit(player));var identity:int=target.get_instance_id();var target_name:String=str(target.name)
	assert(target.begin_swallow(player))
	for frame in 240:
		if frame>=110 and frame<210:
			player.position.z+=.06
			game.ground.sync()
		game.scan_food()
		if frame in [15,35,65]:await snap("swallow-%02d"%frame)
		await process_frame
	assert(not is_instance_id_valid(identity))
	var target_receipts:Array=ledger.filter(func(row):return row.body==target_name)
	assert(target_receipts.size()==1 and target_receipts[0].points==96 and target_receipts[0].player)
	await snap("swallow-complete");await frames(25)
	var receipt:={"scope":"Original Blender castle in the actual Toy world. Staged camera orbit and level-12 movement path are explicit fixtures; gravity and whole-body reward are real. No ordinary-play claim, no save, no production services.","map":game.selected_map,"target_receipts":target_receipts,"ledger":ledger,"muted":true,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("ROYAL_CASTLE_CAPTURE "+JSON.stringify(receipt))
	game.free();layer.free();await frames(2);quit()
