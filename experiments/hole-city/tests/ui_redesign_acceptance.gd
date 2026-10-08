extends SceneTree
const Rarity=preload("res://fidelity/skin_rarity.gd")
## Real viewport pointer routing, phone-sized hit targets, preview lifecycle and
## food-order state. Test progress is session-local; no player save is written.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(count:=2)->void:
	for i in count:await process_frame
func target(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id or b.text==id:return b
	return null
func click(id:String)->void:
	var b:=target(id)
	check(b!=null,"Navigation target exists: "+id)
	if b==null:return
	var at:=b.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await frames()
func layout(label:String)->void:
	var buttons:Array=game.ui.buttons
	for i in buttons.size():
		var b:Button=buttons[i]
		if b.has_meta("skin_id"):continue
		check(Rect2(Vector2(16,16),game.ui.size-Vector2(32,32)).encloses(b.get_rect()),label+": safe portrait margins "+b.name)
		check(minf(b.size.x,b.size.y)*375.0/540.0>=44,label+": >=44 pt at 375 pt width "+b.name)
		check(b.mouse_filter==Control.MOUSE_FILTER_STOP,label+": controls consume pointer input "+b.name)
		for j in range(i+1,buttons.size()):
			if not buttons[j].has_meta("skin_id"):check(not b.get_rect().intersects(buttons[j].get_rect()),label+": no overlapping hit targets")
func thumbnail_framing()->void:
	for view in game.ui.skin_cards:
		var camera:Camera3D=view.get_camera_3d()
		var fits:=true
		var visible_meshes:=0
		var bounds:=Rect2()
		var first_vertex:=true
		var skin_id:=""
		for child in view.get_children():
			if child is Node3D and "skin_id" in child:skin_id=child.skin_id
		for mesh in view.find_children("*","MeshInstance3D",true,false):
			if not mesh.visible:continue
			visible_meshes+=1
			for surface in mesh.mesh.get_surface_count():
				var arrays:Array=mesh.mesh.surface_get_arrays(surface)
				for vertex in arrays[Mesh.ARRAY_VERTEX]:
					var pixel:Vector2=camera.unproject_position(mesh.global_transform*vertex)
					if first_vertex:bounds=Rect2(pixel,Vector2.ZERO);first_vertex=false
					else:bounds=bounds.expand(pixel)
					if not Rect2(4,4,view.size.x-8,view.size.y-8).has_point(pixel):fits=false
		if not fits:print("UI_THUMBNAIL_BOUNDS ",skin_id," ",bounds," camera ",camera.size," aspect ",camera.keep_aspect)
		check(visible_meshes>0 and fits,"Complete skin geometry fits the thumbnail with a four-pixel margin: "+skin_id)
func run()->void:
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	game.set_process(false)
	layout("home")
	for name in game.ui.ICON_NAMES:
		var texture:Texture2D=game.ui.icons[name]
		check(texture!=null and texture.get_width()==100 and texture.get_height()==100,"Packaged vector icon exists: "+name)
		var pixels:=texture.get_image()
		var painted:=0
		for y in range(5,100,10):
			for x in range(5,100,10):
				if pixels.get_pixel(x,y).a>.1:painted+=1
		check(not pixels.is_empty() and painted>=5,"Icon has actual raster content: "+name)
	await click("map-next")
	check(game.selected_map=="food" and game.ui.map_carousel.current_id()=="food" and game.ui.map_carousel.visible and not game.ui.hero.visible,"Actual next-arrow pointer selects Food in the screenshot row")
	await click("map-previous")
	check(game.selected_map=="city" and game.ui.map_carousel.current_id()=="city","Actual previous-arrow pointer restores the City card")
	await click("holes-nav")
	check(game.ui.menu_screen=="holes" and not game.ui.skin_texture.visible,"Pointer opens the skin library")
	layout("classic")
	check(game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden home miniature stops rendering")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing(),"Collection keeps the reusable case result dormant")
	check(game.ui.skin_cards.size()==game.ui.visible_skin_ids().size() and game.ui.card_textures.size()==game.ui.skin_cards.size(),"Exactly six visible model thumbnail owners")
	thumbnail_framing()
	for i in game.ui.skin_cards.size():
		var rect:Rect2=game.ui.slot_rect(i);rect.position-=game.ui.skin_list.position
		check(rect.encloses(game.ui.card_textures[i].get_rect()),"Thumbnail fits its card")
		check(game.ui.card_textures[i].position.y+game.ui.card_textures[i].size.y<rect.position.y+130,"Thumbnail clears card name and lock state")
	# Every actual model must fit while browsing the one continuous collection.
	for id in game.ui.skin_order:
		game.ui.scroll_to_skin(id);await frames()
		thumbnail_framing();layout("collection "+id)
	game.ui.scroll_to_skin("gravitas");await frames()
	await click("hole-slot-gravitas")
	check(game.ui.preview_skin_id=="gravitas" and game.selected_skin_id==Rarity.NEW_PLAYER_SKIN,"Locked card previews without equipping")
	check(game.ui.toast_time>0,"Locked card explains its real unlock requirement")
	game.owned_skin_ids.append("shard") # Skill fixture; acquisition has dedicated coin QA.
	game.ui.scroll_to_skin("shard");await frames()
	await click("hole-slot-shard")
	check(game.selected_skin_id=="shard","Unlocked card equips through pointer routing")
	await click("holes-home")
	check(game.ui.menu_screen=="home" and game.selected_skin_id=="shard","Collection HOME retains the chosen equipment before the single PLAY action")
	await click("PLAY")
	check(game.phase=="intro" and game.player.skin_id=="shard","Home PLAY uses the skin equipped in the collection")
	check(game.ui.toast_time==0,"Menu toast does not leak into gameplay")
	check(game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and game.ui.skin_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Both large preview viewports stop during play")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,"Gameplay hides and stops the additional reusable case result")
	check(game.ui.skin_cards.is_empty(),"Thumbnail viewports are released on round entry")
	game.begin_play();await frames()
	layout("playing")
	check(target("skin-action")!=null and target("pulse-action")!=null,"Functional skill and boost remain available")
	await click("pause-action")
	check(paused and not game.player.dragged,"Pointer pauses without leaving a stuck joystick")
	layout("pause")
	await click("KEEP PLAYING")
	check(not paused and game.phase=="playing","Pointer resumes the same round")
	# Verify the order UI uses the actual map counters, including all small foods.
	game.selected_map="food"
	game.food_collected={"bacon":2,"egg":3,"pizza":7,"donut":1,"cake":0}
	check(game.ui.food_order_counts()==[10,1,0],"Order icons cap the correct grouped receipt counts")
	game.food_collected={"egg":10,"donut":4,"cake":1}
	check(game.ui.food_order_counts()==[10,4,1] and game.food_order_complete() and not game.food_goal_complete(),"Optional completed food badges do not complete the timed run")
	game.finish("eaten");await frames()
	layout("eaten")
	check(target("REVIVE")==null and target("WATCH VIDEO")==null,"Web fallback presents working replay/home actions")
	await click("PLAY AGAIN")
	check(game.phase=="intro" and game.food_collected.is_empty(),"Replay keeps the food map and clears the order")
	game.begin_play();game.finish("complete");await frames();layout("complete")
	await click("HOME")
	check(game.phase=="title" and game.ui.map_carousel.visible and not game.ui.hero.visible,"Results HOME restores the screenshot row without live map rendering")
	# Repeated navigation must not retain queued thumbnail resources or controls.
	for i in 12:
		game.ui.open_holes();await frames()
		game.ui.scroll_to_skin("music_stage");await frames()
		game.ui.close_menu();await frames()
	check(game.ui.find_children("*","SubViewport",true,false).size()==3,"Repeated menu navigation retains only the two legacy previews and one reusable case result")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing(),"Returning Home leaves the reusable case result stopped")
	check(game.ui.find_children("*","Button",true,false).size()==7 and target("home-settings")!=null and target("map-next")!=null and target("map-previous")!=null and target("release-info")==null,"Repeated menu navigation retains seven real Home controls: settings, play, two arrows and three dock destinations")
	await click("home-settings")
	check(game.ui.menu_screen=="settings" and target("audio-music")!=null and target("audio-sfx")!=null and target("release-info")!=null,"Actual home settings input exposes independent audio and support controls")
	layout("settings")
	await click("settings-back")
	check(game.ui.menu_screen=="home" and game.ui.find_children("*","Button",true,false).size()==7,"Actual settings BACK restores the bounded seven Home control owners")
	var result:={"checks":checks,"failures":failures,"input":"Actual viewport mouse down/up","minimum_test_width_points":375}
	print("UI_REDESIGN_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	# Release the streamed music decoder on its audio thread before freeing the game.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
