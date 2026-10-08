extends SceneTree
## Record the current UI's real 2D draw calls without a window or player saves.
## Output is a layout reconstruction input, not a Godot viewport screenshot.
var output := "res://artifacts/ui-comparison"
const ADAPTER := '''
var recorded:Array=[]
var image_output:String=""
func packed(value):
	if value is Vector2:return [value.x,value.y]
	if value is Rect2:return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Color:return [value.r,value.g,value.b,value.a]
	if value is Array or value is PackedVector2Array:
		var result:Array=[]
		for item in value:result.append(packed(item))
		return result
	return value
func record(op:String,args:Array):recorded.append({"op":op,"args":packed(args)})
func capture_draw_set_transform(at:Vector2,angle:float=0,scale_:Vector2=Vector2.ONE):record("transform",[at,angle,scale_])
func capture_draw_rect(rect:Rect2,color:Color,filled:bool=true,width:float=-1):record("rect",[rect,color,filled,width])
func capture_draw_circle(at:Vector2,radius:float,color:Color):record("circle",[at,radius,color])
func capture_draw_arc(at:Vector2,radius:float,start:float,end:float,count:int,color:Color,width:float=1,antialiased:bool=false):record("arc",[at,radius,start,end,count,color,width])
func capture_draw_line(a:Vector2,b:Vector2,color:Color,width:float=-1,antialiased:bool=false):record("line",[a,b,color,width])
func capture_draw_polyline(points:PackedVector2Array,color:Color,width:float=-1,antialiased:bool=false):record("polyline",[points,color,width])
func capture_draw_colored_polygon(points:PackedVector2Array,color:Color):record("polygon",[points,color])
func capture_draw_string(f:Font,at:Vector2,message:String,align:int=0,width:float=-1,size_:int=16,color:Color=Color.WHITE):record("text",[at,message,size_,color,0])
func capture_draw_string_outline(f:Font,at:Vector2,message:String,align:int=0,width:float=-1,size_:int=16,outline:int=1,color:Color=Color.WHITE):record("text",[at,message,size_,color,outline])
func capture_draw_style_box(style:StyleBoxFlat,rect:Rect2):record("style",[rect,style.bg_color,style.border_color,style.corner_radius_top_left,style.border_width_left,style.border_width_bottom,style.shadow_color,style.shadow_size,style.shadow_offset])
func capture_draw_texture_rect(texture:Texture2D,rect:Rect2,tile:bool,modulate_:Color=Color.WHITE,transpose:bool=false):
	var filename:=texture.resource_path.get_file().get_basename()+".png"
	if not FileAccess.file_exists(image_output+"/"+filename):texture.get_image().save_png(image_output+"/"+filename)
	record("image",[rect,filename,modulate_])
'''
func _initialize()->void:run.call_deferred()
func snapshot(ui:Control,label:String)->void:
	ui.recorded.clear()
	ui._draw()
	for button in ui.buttons:
		if not button.visible or button.text.is_empty():continue
		ui.capture_draw_style_box(button.get_theme_stylebox("normal"),Rect2(button.position,button.size))
		var size_:int=button.get_theme_font_size("font_size")
		var width:float=ui.font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_).x
		var icon_width:float=button.get_theme_constant("icon_max_width") if button.icon!=null else 0.0
		var separation:float=button.get_theme_constant("h_separation") if button.icon!=null else 0.0
		var baseline:float=button.position.y+(button.size.y-ui.font.get_height(size_))*.5+ui.font.get_ascent(size_)
		var at:=Vector2(button.position.x+(button.size.x-width+icon_width+separation)*.5,baseline)
		if button.icon!=null:ui.capture_draw_texture_rect(button.icon,Rect2(at.x-icon_width-separation,button.position.y+(button.size.y-icon_width)*.5,icon_width,icon_width),false)
		ui.record("text",[at,button.text,size_,button.get_theme_color("font_outline_color"),2])
		ui.record("text",[at,button.text,size_,button.get_theme_color("font_color"),0])
	var out:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"scope":"2D draw-command reconstruction; 3D scene and previews omitted; test defaults, not user save", "version":ProjectSettings.get_setting("application/config/version"),"source_sha256":FileAccess.get_sha256("res://fidelity/ui.gd"),"preview_rects":ui.card_textures.map(func(t):return [t.position.x,t.position.y,t.size.x,t.size.y]),"commands":ui.recorded},"\t"))
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):
		push_error("Requires --test to avoid player saves");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(output+"/icons")
	var source:=FileAccess.get_file_as_string("res://fidelity/ui.gd")
	for method in ["draw_set_transform","draw_rect","draw_circle","draw_arc","draw_line","draw_polyline","draw_colored_polygon","draw_string_outline","draw_string","draw_style_box","draw_texture_rect"]:
		source=source.replace(method+"(","capture_"+method+"(")
	var script:=GDScript.new();script.source_code=source+ADAPTER
	if script.reload()!=OK:quit(1);return
	var game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_process(false)
	var parent=game.ui.get_parent();game.ui.free()
	var ui=script.new();ui.game=game;ui.image_output=output+"/icons";game.ui=ui;parent.add_child(ui);ui.set_process(false)
	snapshot(ui,"home")
	ui.open_store();snapshot(ui,"store");ui.close_menu()
	game.select_map("food");snapshot(ui,"food-home")
	ui.open_holes();snapshot(ui,"skins")
	for category in ["classic","special"]:
		ui.choose_holes_tab(category)
		for page in ui.page_count():
			ui.change_skin_page(page-ui.skin_page);snapshot(ui,category+"-page-"+str(page+1))
	ui.choose_holes_tab("classic")
	ui.request_unlock();snapshot(ui,"unlocked-skin")
	ui.unlock_feedback_time=0;ui.request_unlock();snapshot(ui,"insufficient-coins")
	ui.choose_holes_tab("special");ui.select_hole_slot("gravitas");snapshot(ui,"locked-skin")
	game.owned_skin_ids=game.skin_ids("resonance")+game.skin_ids("foundation");ui.toast_time=0;ui.refresh();snapshot(ui,"complete-collection")
	game.selected_map="city"
	game.start_level();game.phase="playing";game.notice_time=0;game.swallow_hint="";ui.refresh()
	snapshot(ui,"city-hud")
	game.selected_map="food";snapshot(ui,"food-hud")
	game.food_collected={"egg":10,"donut":4,"cake":1};snapshot(ui,"order-complete")
	game.toggle_pause();snapshot(ui,"pause");game.toggle_pause()
	for phase_ in ["eaten","timeout","complete"]:
		game.player.score=game.SCORE_TARGET if phase_=="complete" else 27 if phase_=="eaten" else 198
		game.phase="playing";game.finish(phase_);snapshot(ui,phase_)
	game.free()
	await process_frame
	print("UI_LAYOUT_EXPORTED code-derived 2D layouts; no viewport capture")
	quit()
