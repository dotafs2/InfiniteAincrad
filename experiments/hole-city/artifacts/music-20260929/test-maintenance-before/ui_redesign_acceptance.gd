extends SceneTree
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
		check(Rect2(16,16,508,928).encloses(b.get_rect()),label+": safe portrait margins "+b.name)
		check(minf(b.size.x,b.size.y)*375.0/540.0>=44,label+": >=44 pt at 375 pt width "+b.name)
		check(b.mouse_filter==Control.MOUSE_FILTER_STOP,label+": controls consume pointer input "+b.name)
		for j in range(i+1,buttons.size()):check(not b.get_rect().intersects(buttons[j].get_rect()),label+": no overlapping hit targets")
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
	await click("home-food-nav")
	check(game.selected_map=="food" and game.ui.hero.visible,"Pointer selects the food map and actual miniature")
	await click("home-map-nav")
	check(game.selected_map=="city","Pointer selects the city card")
	await click("holes-nav")
	check(game.ui.menu_screen=="holes" and not game.ui.skin_texture.visible,"Pointer opens the skin library")
	layout("classic")
	check(game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden home miniature stops rendering")
	check(game.ui.skin_cards.size()==6 and game.ui.card_textures.size()==6,"Exactly six visible model thumbnail owners")
	thumbnail_framing()
	for i in 6:
		var rect:Rect2=game.ui.slot_rect(i)
		check(rect.encloses(game.ui.card_textures[i].get_rect()),"Thumbnail fits its card")
		check(game.ui.card_textures[i].position.y+game.ui.card_textures[i].size.y<rect.position.y+130,"Thumbnail clears card name and lock state")
	await click("holes-special-tab")
	layout("special")
	thumbnail_framing()
	# Every actual model must fit, including later pages.
	for category in ["classic","special"]:
		game.ui.choose_holes_tab(category)
		for page in game.ui.page_count():
			game.ui.skin_page=page;game.ui.refresh();await frames()
			thumbnail_framing();layout(category+" page "+str(page+1))
	game.ui.choose_holes_tab("special");await frames()
	await click("hole-slot-special-02")
	check(game.ui.preview_skin_id=="gravitas" and game.selected_skin_id=="core_shell","Locked card previews without equipping")
	check(game.ui.toast_time>0,"Locked card explains its real unlock requirement")
	game.owned_skin_ids.append("shard") # Skill fixture; acquisition has dedicated coin QA.
	await click("hole-slot-special-04")
	check(game.selected_skin_id=="shard","Unlocked card equips through pointer routing")
	await click("PLAY")
	check(game.phase=="intro" and game.player.skin_id=="shard","Library PLAY uses the equipped skin")
	check(game.ui.toast_time==0,"Menu toast does not leak into gameplay")
	check(game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and game.ui.skin_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Both large preview viewports stop during play")
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
	check(game.ui.food_order_counts()==[10,4,1] and game.food_order_complete() and not game.food_goal_complete(),"Completed food badges do not bypass remaining city objectives")
	game.finish("eaten");await frames()
	layout("eaten")
	check(target("REVIVE")==null and target("WATCH VIDEO")==null,"Web fallback presents working replay/home actions")
	await click("PLAY AGAIN")
	check(game.phase=="intro" and game.food_collected.is_empty(),"Replay keeps the food map and clears the order")
	game.begin_play();game.finish("complete");await frames();layout("complete")
	await click("HOME")
	check(game.phase=="title" and game.ui.hero.visible,"Results HOME restores the miniature")
	# Repeated navigation must not retain queued thumbnail resources or controls.
	for i in 12:
		game.ui.open_holes();await frames()
		game.ui.choose_holes_tab("special");await frames()
		game.ui.close_menu();await frames()
	check(game.ui.find_children("*","SubViewport",true,false).size()==2,"Repeated menu navigation retains only two reusable preview viewports")
	check(game.ui.find_children("*","Button",true,false).size()==7,"Repeated menu navigation retains only seven home controls")
	var result:={"checks":checks,"failures":failures,"input":"Actual viewport mouse down/up","minimum_test_width_points":375}
	print("UI_REDESIGN_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
