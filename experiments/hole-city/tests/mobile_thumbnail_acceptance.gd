extends SceneTree
## Backing-pixel sizing and preview lifecycle, in a headless --test window only.
## This does not measure GPU edge quality or certify device frame time.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var profiles:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for i in count:await process_frame
func active_count()->int:
	var count:=0
	for view in game.ui.skin_cards:
		for child in view.get_children():
			if "skin_id" in child and child.is_processing():count+=1
	return count
func models()->Array:
	var result:=[]
	for view in game.ui.skin_cards:
		for child in view.get_children():
			if "skin_id" in child:result.append(child)
	return result
func inspect_page(label:String)->void:
	var ui=game.ui
	var owner_limit:=3*(ceili(ui.skin_list.size.y/172.0)+1)
	check(ui.skin_cards.size()==ui.visible_skin_ids().size() and ui.skin_cards.size()<=owner_limit,label+": only visible adaptive rows own bounded targets")
	var focused:bool=ui.visible_skin_ids().has(ui.preview_skin_id)
	check(active_count()==(1 if focused else 0),label+": only a visible focused model animates")
	var always:=0
	for i in ui.skin_cards.size():
		var view:SubViewport=ui.skin_cards[i]
		var texture:TextureRect=ui.card_textures[i]
		check(view.msaa_3d==Viewport.MSAA_2X,label+": visible target has 2x MSAA")
		check(view.size.x>=144 and view.size.y>=106 and view.size.x<=432 and view.size.y<=318,label+": target stays inside bounded budget")
		check(absf(float(view.size.x)/view.size.y-144.0/106.0)<.015,label+": camera aspect stays stable within pixel rounding")
		var expected_position:Vector2=ui.slot_rect(i).position-ui.skin_list.position+Vector2(8,4)
		# Control derives size from floating offsets. The retained fractional
		# layout probe measures <=0.000030517578 logical px of subtraction error.
		# Keep a strict absolute tolerance so large coordinates cannot weaken it.
		var footprint_matches:bool=texture.size.distance_to(Vector2(144,106))<.001 and texture.position.distance_to(expected_position)<.001
		if not footprint_matches:
			var position_delta:Vector2=texture.position-expected_position
			var size_delta:Vector2=texture.size-Vector2(144,106)
			print("THUMBNAIL_FOOTPRINT "+JSON.stringify({"profile":label,"skin":ui.card_skin_ids[i],"actual_position":["%.12f"%texture.position.x,"%.12f"%texture.position.y],"expected_position":["%.12f"%expected_position.x,"%.12f"%expected_position.y],"position_delta":["%.12f"%position_delta.x,"%.12f"%position_delta.y],"actual_size":["%.12f"%texture.size.x,"%.12f"%texture.size.y],"size_delta":["%.12f"%size_delta.x,"%.12f"%size_delta.y],"list_position":str(ui.skin_list.position)}))
		check(footprint_matches,label+": logical footprint uses the current responsive card origin within 0.001 logical pixels")
		check(texture.expand_mode==TextureRect.EXPAND_IGNORE_SIZE and texture.get_combined_minimum_size()==Vector2.ZERO,label+": larger raster cannot enlarge the control")
		check(texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR and texture.mouse_filter==Control.MOUSE_FILTER_IGNORE,label+": filtered image never consumes touch")
		check(ui.card_skin_ids[i]==ui.visible_skin_ids()[i],label+": exact current skin identity")
		if view.render_target_update_mode==SubViewport.UPDATE_ALWAYS:always+=1
	check(always==(1 if focused else 0),label+": only a visible focused target renders continuously")
func resize_profile(label:String,size_:Vector2i,minimum:Vector2i,maximum:Vector2i)->void:
	var views:Array=game.ui.skin_cards.map(func(v):return v.get_instance_id())
	var ids:Array=game.ui.card_skin_ids.duplicate()
	var previous_size:Vector2=game.ui.size
	var previous_position:Vector2=game.ui.position
	var previous_scale:Vector2=game.ui.scale
	var previous_views:Array=game.ui.skin_cards.duplicate()
	root.size=size_
	await frames(4)
	var actual:Vector2i=game.ui.skin_cards[0].size
	check(actual.x>=minimum.x and actual.y>=minimum.y and actual.x<=maximum.x and actual.y<=maximum.y,label+": raster follows actual backing size once, without double DPR")
	if previous_size.is_equal_approx(game.ui.size) and previous_position.is_equal_approx(game.ui.position) and previous_scale.is_equal_approx(game.ui.scale) and ids==game.ui.card_skin_ids:
		check(views==game.ui.skin_cards.map(func(v):return v.get_instance_id()),label+": unchanged logical geometry reuses preview owners during density changes")
	else:
		check(previous_views.all(func(v):return not is_instance_valid(v) or game.ui.skin_cards.has(v)) and game.ui.card_skin_ids==game.ui.visible_skin_ids(),label+": adaptive page replacement retires stale owners and binds the exact visible forms")
	profiles.append({"name":label,"backing_size":str(size_),"stretch":str(root.get_stretch_transform()),"target":str(actual)})
	inspect_page(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.content_scale_size=Vector2i(540,960)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	game.set_process(false);game.set_physics_process(false)
	check(game.progress_file().is_empty(),"Default --test progress is isolated from player saves")
	var coins:int=game.coins;var owned:Array=game.owned_skin_ids.duplicate();var equipped:String=game.selected_skin_id
	var hero_size:Vector2i=game.ui.hero_view.size
	game.ui.open_holes();await frames()
	await resize_profile("design size",Vector2i(540,960),Vector2i(144,106),Vector2i(144,106))
	await resize_profile("narrow phone",Vector2i(270,480),Vector2i(144,106),Vector2i(144,106))
	await resize_profile("375-point phone at DPR1",Vector2i(375,812),Vector2i(144,106),Vector2i(144,106))
	await resize_profile("375-point phone at DPR2",Vector2i(750,1624),Vector2i(200,148),Vector2i(201,149))
	await resize_profile("390-point phone at DPR3",Vector2i(1170,2532),Vector2i(312,230),Vector2i(313,231))
	await resize_profile("large display capped",Vector2i(4320,7680),Vector2i(432,318),Vector2i(432,318))
	await resize_profile("expanded landscape",Vector2i(1200,600),Vector2i(144,106),Vector2i(144,106))
	root.size=Vector2i(540,960);root.content_scale_factor=1.5;await frames(4)
	var card:TextureRect=game.ui.card_textures[0]
	var backing:Transform2D=root.get_stretch_transform()*card.get_global_transform_with_canvas()
	var demand:=Vector2i(ceili((backing.x*card.size.x).length()),ceili((backing.y*card.size.y).length()))
	var raster:Vector2i=game.ui.skin_cards[0].size
	check(raster.x>=demand.x and raster.y>=demand.y and raster.x<=432 and raster.y<=318,"Preview raster covers the actual backing-pixel footprint after safe UI refitting")
	root.content_scale_factor=1.0
	game.ui.get_parent().scale=Vector2(2,2);await frames(4)
	check(game.ui.skin_cards[0].size==Vector2i(288,212),"CanvasLayer transform is included once")
	game.ui.get_parent().scale=Vector2.ONE;await frames(4)
	# Dummy headless rendering does not consume UPDATE_ONCE. Model an already
	# rendered inactive cache, then ensure stable frames never invalidate it.
	var model_list:=models();var clocks:=model_list.map(func(m):return m.clock_time)
	for i in game.ui.skin_cards.size():
		if game.ui.card_skin_ids[i]!=game.ui.preview_skin_id:game.ui.skin_cards[i].render_target_update_mode=SubViewport.UPDATE_DISABLED
	await frames(8)
	for i in game.ui.skin_cards.size():
		if game.ui.card_skin_ids[i]==game.ui.preview_skin_id:
			check(model_list[i].clock_time>clocks[i],"Focused animation keeps advancing")
		else:
			check(game.ui.skin_cards[i].render_target_update_mode==SubViewport.UPDATE_DISABLED and model_list[i].clock_time==clocks[i],"Stable density preserves cached inactive raster and clock")
	root.size=Vector2i(1080,1920);await frames(3)
	for i in game.ui.skin_cards.size():
		if game.ui.card_skin_ids[i]!=game.ui.preview_skin_id:
			check(game.ui.skin_cards[i].render_target_update_mode in [SubViewport.UPDATE_ONCE,SubViewport.UPDATE_DISABLED],"A changed density schedules at most one cached redraw")
	var seen:Array[String]=[]
	for id in game.ui.skin_order:
		game.ui.scroll_to_skin(id);await frames()
		inspect_page("collection "+id)
		for visible_id in game.ui.visible_skin_ids():
			if not seen.has(visible_id):seen.append(visible_id)
	check(seen.size()==200 and game.SKIN_DEFS.all(func(d):return seen.count(d.id)==1),"All 200 forms are reachable through bounded continuous scrolling")
	check(game.coins==coins and game.owned_skin_ids==owned and game.selected_skin_id==equipped,"Display resizing and pagination do not change economy or equipment")
	check(game.ui.hero_view.size==hero_size and game.ui.hero_view.msaa_3d==Viewport.MSAA_2X and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Existing home miniature remains bounded and dormant in collection")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing(),"Collection resizing never starts the reusable case result renderer or animation")
	# Repeated exit must stop the queued model before the next rendered frame.
	for i in 5:
		var retired:Array=game.ui.skin_cards.duplicate()
		var retired_models:=models()
		game.ui.close_menu()
		check(retired.all(func(v):return v.render_target_update_mode==SubViewport.UPDATE_DISABLED) and retired_models.all(func(m):return not m.is_processing()),"Leaving collection immediately stops retired rendering/animation")
		await frames()
		check(retired.all(func(v):return not is_instance_valid(v)),"Retired viewport owners are freed after exit")
		check(game.ui.find_children("*","SubViewport",true,false).size()==3,"Only two legacy previews and one reusable case result viewport remain")
		check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,"Home leaves the reusable case result hidden and stopped")
		game.ui.open_holes();await frames()
	game.start_level();await frames()
	check(game.ui.skin_cards.is_empty() and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Round entry releases cards and stops home rendering")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing(),"Gameplay also leaves the case result renderer and animation stopped")
	check(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")==Viewport.MSAA_4X,"Main4x scene AA is unchanged")
	game.free();await frames()
	var result:={"checks":checks,"failures":failures,"profiles":profiles,"scope":"Headless backing-size, AA configuration, layout and lifecycle; no GPU image or phone FPS claim"}
	print("MOBILE_THUMBNAIL_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:=arg.trim_prefix("--report=")
			var file:=FileAccess.open(path,FileAccess.WRITE) if path.is_absolute_path() and not path.begins_with("res://") and not path.begins_with("user://") else null
			if file==null:quit(2);return
			file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
