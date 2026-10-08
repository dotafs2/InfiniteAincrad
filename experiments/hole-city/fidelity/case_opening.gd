extends Control
## The outcome is committed by Game before this cosmetic reel starts.
const Rarity=preload("res://fidelity/skin_rarity.gd")
const SkinVisual=preload("res://fidelity/skin_visual.gd")
const CaseAudio=preload("res://fidelity/case_audio.gd")
const Celebration=preload("res://fidelity/case_celebration.gd")
const DURATION:=4.25
const CELL:=158.0
const WINNER_INDEX:=30
const REEL_RECT:=Rect2(24,244,492,236)
const WHITE:=Color("f4f7ff")
const MUTED:=Color("9daec8")
var ui:Control
var game:Node3D
var stage:="ready"
var receipt:Dictionary={}
var elapsed:=0.0
var offset:=0.0
var last_crossing:=-1
var reel_ids:Array[String]=[]
var textures:Dictionary={}
var reel:Control
var sound:Node
var result_view:SubViewport
var result_model:Node3D
var result_camera:Camera3D
var result_texture:TextureRect
var result_id:=""
var message:=""
var focused:=true
var open_button:Button
var reopen_waiting:=false
var celebration:Control

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	reel=Control.new();reel.mouse_filter=Control.MOUSE_FILTER_IGNORE;reel.clip_contents=true
	add_child(reel);reel.draw.connect(draw_reel)
	sound=CaseAudio.new();add_child(sound)
	celebration=Celebration.new();celebration.ui=ui;add_child(celebration)
	make_result_view()
	visibility_changed.connect(sync_visibility)
	layout()

func thumbnail(id:String)->Texture2D:
	if not textures.has(id):
		var path:="res://assets/skin_thumbnails/"+id+".png"
		textures[id]=load(path) if ResourceLoader.exists(path) else null
	return textures[id]

func make_result_view()->void:
	result_view=SubViewport.new();result_view.size=Vector2i(480,384)
	result_view.transparent_bg=true;result_view.own_world_3d=true;result_view.msaa_3d=Viewport.MSAA_2X
	result_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(result_view)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_CLEAR_COLOR;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("dce8ff");env.ambient_light_energy=.7
	environment.environment=env;result_view.add_child(environment)
	for rotation in [Vector3(-48,-24,0),Vector3(-25,145,0)]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=rotation
		light.light_energy=1.1 if rotation.y<0 else .45;result_view.add_child(light)
	result_camera=Camera3D.new();result_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	result_view.add_child(result_camera);result_camera.position=Vector3(0,6.6,8);result_camera.current=true
	result_model=SkinVisual.new();result_view.add_child(result_model);result_model.set_process(false)
	result_texture=TextureRect.new();result_texture.texture=result_view.get_texture()
	result_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	result_texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(result_texture);result_texture.hide()

func layout()->void:
	size=ui.size
	var rect:Rect2=ui.responsive_rect(REEL_RECT)
	reel.position=rect.position;reel.size=rect.size
	var model_rect:Rect2=ui.responsive_rect(Rect2(54,226,432,338))
	result_texture.position=model_rect.position;result_texture.size=model_rect.size
	celebration.layout()
	reel.queue_redraw();queue_redraw()

func sync_visibility()->void:
	var active:=visible and stage=="result"
	result_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	result_model.set_process(active);result_texture.visible=active
	reel.visible=visible and stage!="result"
	if not active:celebration.clear()
	if not visible:
		sound.stop_all();textures.clear()

func enter()->void:
	celebration.clear()
	message="";textures.clear()
	var pending:Dictionary=game.pending_skin_case()
	if not pending.is_empty():
		receipt=pending;reveal(false)
	else:
		receipt={};stage="ready";elapsed=0;offset=CELL
		var shortfall:int=maxi(0,game.skin_unlock_price("collection")-game.coins)
		if shortfall>0:message="Need %d more coins"%shortfall
		reel_ids.clear()
		for tier in ["common","rare","epic","legendary","prismatic","uncommon"]:
			var candidates:Array[String]=[]
			for id in game.locked_skin_ids("collection"):
				if game.skin_definition(id).rarity==tier:candidates.append(id)
			if not candidates.is_empty():reel_ids.append(candidates[candidates.size()/2])
		if reel_ids.size()==1:offset=0
		sync_visibility()
	layout()

func build_reel()->void:
	# Decorative neighbors are sampled from the same eligible tier weights.
	# Never select or reorder rare neighbors to manufacture a near miss.
	var rng:=RandomNumberGenerator.new();rng.seed=int(receipt.presentation_seed)
	var pools:Dictionary={}
	for tier in Rarity.ORDER:pools[tier]=[]
	for definition in game.SKIN_DEFS:
		if not game.skin_unlocked(definition.id) or definition.id==receipt.id:
			pools[definition.rarity].append(str(definition.id))
	reel_ids.clear()
	for index in WINNER_INDEX+4:
		var ticket:=rng.randf()*float(receipt.odds.total_weight)
		var tier:="common"
		for entry in receipt.odds.entries:
			ticket-=float(entry.weight)
			if ticket<0:tier=entry.rarity;break
		var pool:Array=pools[tier]
		reel_ids.append(str(pool[rng.randi_range(0,pool.size()-1)]) if not pool.is_empty() else str(receipt.id))
	reel_ids[WINNER_INDEX]=str(receipt.id)

func begin_open()->void:
	if stage!="ready":return
	var result:Dictionary=game.open_skin_case()
	if not result.get("ok",false):message=str(result.get("message","Please try again"));queue_redraw();return
	receipt=game.pending_skin_case();message=""
	if result.get("resumed",false):reveal(false);return
	build_reel();stage="rolling";elapsed=0;offset=CELL;last_crossing=1
	sound.play_open();sync_visibility();ui.refresh()

func reveal(play_sound:=true)->void:
	if receipt.is_empty():return
	if stage=="result" and result_id==str(receipt.id):sync_visibility();return
	stage="result";elapsed=DURATION;offset=float(WINNER_INDEX)*CELL
	if result_id!=str(receipt.id):
		result_id=str(receipt.id);result_model.build(game.skin_definition(result_id),true)
		result_model.frame_preview(result_camera,true)
	if play_sound:
		sound.play_reveal(str(receipt.rarity))
		celebration.start(str(receipt.rarity),int(receipt.presentation_seed))
	else:sound.stop_all()
	sync_visibility();ui.refresh();queue_redraw()

func equip()->void:
	if stage!="result":return
	if game.select_skin(str(receipt.id)):message="EQUIPPED"
	else:message="Could not save. Try again."
	ui.refresh();queue_redraw()

func continue_case()->void:
	if stage!="result":return
	if not game.acknowledge_skin_case(str(receipt.case_id)):
		message="Could not save. Try again.";queue_redraw();return
	sound.stop_all();enter();ui.refresh()

func back()->void:
	sound.stop_all();ui.open_holes()

func controls()->void:
	if stage=="ready" and (message.is_empty() or message.begins_with("Need ")):
		var shortfall:int=maxi(0,game.skin_unlock_price("collection")-game.coins)
		message="Need %d more coins"%shortfall if shortfall>0 else ""
	layout();sync_visibility()
	case_button("case-back",Rect2(24,20,106,64),"BACK",back,false)
	var odds:=case_button("case-odds",Rect2(410,20,106,64),"ODDS",ui.open_rates,false)
	odds.disabled=stage=="rolling"
	if stage=="rolling":
		case_button("case-skip",Rect2(156,798,228,72),"SKIP",reveal,false)
	elif stage=="result":
		var equipped:bool=game.selected_skin_id==str(receipt.id)
		var equip_button:=case_button("case-equip",Rect2(48,728,444,68),"EQUIPPED" if equipped else "EQUIP SKIN",equip,true)
		equip_button.disabled=equipped
		case_button("case-continue",Rect2(48,814,444,68),"CONTINUE",continue_case,false)
	else:
		var complete:bool=game.locked_skin_ids("collection").is_empty()
		var price:int=game.skin_unlock_price("collection")
		open_button=case_button("case-open",Rect2(48,798,444,72),"COLLECTION COMPLETE" if complete else "OPEN CASE  ·  %d COINS"%price,begin_open,true)
		reopen_waiting=Time.get_ticks_msec()-game.last_unlock_msec<800
		open_button.disabled=complete or game.coins<price or reopen_waiting
		case_button("case-collection",Rect2(130,701,280,64),"VIEW COLLECTION",back,false)

func case_button(id:String,rect:Rect2,label:String,action:Callable,primary:bool)->Button:
	var button:Button=ui.button(rect,label,action,Color("58d5bf") if primary else Color("25344a"))
	button.name=id;button.add_theme_font_size_override("font_size",21 if primary else 17)
	for state in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.set_corner_radius_all(12)
		style.bg_color=Color("203145") if not primary else Color("64dfc1")
		if state=="hover":style.bg_color=style.bg_color.lightened(.1)
		if state=="pressed":style.bg_color=style.bg_color.darkened(.16)
		if state=="disabled":style.bg_color=Color("273549")
		style.set_border_width_all(1);style.border_color=Color("3b526d") if not primary else Color("9cf5db")
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",Color("102f35") if primary else WHITE)
	button.add_theme_color_override("font_hover_color",Color("102f35") if primary else WHITE)
	button.add_theme_color_override("font_pressed_color",Color("102f35") if primary else WHITE)
	button.add_theme_color_override("font_disabled_color",MUTED)
	return button

func _process(delta:float)->void:
	if not visible:return
	if stage=="ready" and reopen_waiting and Time.get_ticks_msec()-game.last_unlock_msec>=800:
		reopen_waiting=false
		if is_instance_valid(open_button):open_button.disabled=game.locked_skin_ids("collection").is_empty() or game.coins<game.skin_unlock_price("collection")
	if stage=="rolling" and focused:
		elapsed=minf(DURATION,elapsed+delta)
		var t:=elapsed/DURATION
		offset=lerpf(CELL,float(WINNER_INDEX)*CELL,1.0-pow(1.0-t,4.0))
		var crossing:=floori(offset/CELL+.5)
		if crossing!=last_crossing:sound.play_tick();last_crossing=crossing
		reel.queue_redraw()
		if elapsed>=DURATION:reveal()
	if stage=="result":result_model.rotation.y+=delta*.14
	queue_redraw()

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN or what==NOTIFICATION_APPLICATION_RESUMED:focused=true

func panel(rect:Rect2,color:Color,border:=Color.TRANSPARENT)->void:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(14)
	style.border_color=border;style.set_border_width_all(1)
	draw_style_box(style,ui.responsive_rect(rect))

func label(value:String,at:Vector2,font_size:int=20,color:=WHITE,max_width:=480.0)->void:
	var actual:int=ui.fitted_font_size(value,max_width,font_size,12)
	var point:Vector2=ui.responsive_point(at)
	var width:float=ui.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual).x
	draw_string(ui.font,point-Vector2(width*.5,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,color)

func _draw()->void:
	if ui==null or ui.font==null:return
	draw_rect(ui.canvas_bounds(),Color("101b2c"))
	for index in 12:
		var at:Vector2=ui.responsive_point(Vector2(60+(index%4)*148,180+(index/4)*257))
		draw_arc(at,112,PI*.9,PI*1.9,32,Color("1a2b43"),1,true)
	label(str(game.coins)+"  COINS",Vector2(270,60),20,Color("f6d580"),240)
	label("NEW SKIN" if stage=="result" else "SKIN CASE",Vector2(270,143),38)
	label("ADDED TO YOUR COLLECTION" if stage=="result" else "One case. One new skin.",Vector2(270,181),17,MUTED)
	if stage=="result":
		var tier:Dictionary=Rarity.data(str(receipt.rarity))
		panel(Rect2(24,221,492,359),Color(tier.color,.08),Color(tier.color,.3))
		for index in 4:
			var center:Vector2=ui.responsive_point(Vector2(270,405))
			draw_arc(center,90+index*33,0,TAU,80,Color(tier.color,.09-float(index)*.015),1,true)
		label(str(tier.name).to_upper(),Vector2(270,614),19,tier.color)
		label(str(game.skin_definition(receipt.id).name),Vector2(270,656),30,WHITE,474)
		label(message if not message.is_empty() else "Yours to keep. Ready to equip.",Vector2(270,695),16,MUTED)
	else:
		label("OPENING…" if stage=="rolling" else "%d SKINS  /  %d COLLECTED"%[game.SKIN_DEFS.size(),game.unlocked_skin_count("collection")],Vector2(270,222),16,MUTED)
		panel(Rect2(20,240,500,244),Color("0b1422"),Color("36475f"))
		# The marker belongs to the stationary frame, never to a moving cell.
		var tip:Vector2=ui.responsive_point(Vector2(270,249))
		draw_colored_polygon(PackedVector2Array([tip+Vector2(-10,-14),tip+Vector2(10,-14),tip+Vector2(0,3)]),Color("f4dda5"))
		var bottom:Vector2=ui.responsive_point(Vector2(270,484))
		draw_colored_polygon(PackedVector2Array([bottom+Vector2(-7,7),bottom+Vector2(7,7),bottom+Vector2(0,-5)]),Color("f4dda5"))
		label("Every opening adds an unowned skin",Vector2(270,521),16,MUTED)
		for index in Rarity.ORDER.size():
			var x:float=24+(index%2)*252;var y:float=550+(index/2)*46
			var tier:Dictionary=Rarity.data(Rarity.ORDER[index])
			panel(Rect2(x,y,240,38),Color("1b2a40"),Color(tier.color,.3))
			draw_circle(ui.responsive_point(Vector2(x+20,y+19)),4,tier.color)
			label(str(tier.name),Vector2(x+130,y+26),16,tier.color,196)
		if stage=="ready":
			var price:int=game.skin_unlock_price("collection")
			var shortfall:int=maxi(0,price-game.coins)
			label(message if not message.is_empty() else "Need %d more coins"%shortfall if shortfall>0 else "No duplicates · Current odds above",Vector2(270,912),16,Color("f6d580") if shortfall>0 else MUTED)
		else:label("Your skin is already saved",Vector2(270,740),16,MUTED)

func draw_reel()->void:
	if reel_ids.is_empty():return
	var height:float=reel.size.y
	for index in reel_ids.size():
		var x:float=reel.size.x*.5+(index*CELL-offset)-CELL*.5
		if x+CELL<0 or x>reel.size.x:continue
		var definition:Dictionary=game.skin_definition(reel_ids[index])
		var color:Color=Rarity.data(str(definition.rarity)).color
		var rect:=Rect2(x+4,8,CELL-8,height-16)
		var style:=StyleBoxFlat.new();style.set_corner_radius_all(9);style.bg_color=Color("22334b")
		style.border_color=Color(color,.45);style.set_border_width_all(1);reel.draw_style_box(style,rect)
		reel.draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-4),Vector2(rect.size.x,4)),color)
		var texture:=thumbnail(str(definition.id))
		if texture!=null:
			var image_size:=minf(rect.size.x,height-75)
			reel.draw_texture_rect(texture,Rect2(x+(CELL-image_size)*.5,14+(height-236)*.35,image_size,image_size),false)
		var title:String=str(definition.name)
		var base_name:String=str(game.skin_definition(str(definition.get("model_id",definition.id))).name)
		var variant_name:String=str(definition.get("palette",{}).get("name",""))
		if variant_name.is_empty():base_name=title
		for row in [[base_name,height-53,15,WHITE],[variant_name,height-33,12,MUTED]]:
			var text_value:=str(row[0]);var font_size:int=ui.fitted_font_size(text_value,136,int(row[2]),10)
			var width:float=ui.font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			reel.draw_string(ui.font,Vector2(x+CELL*.5-width*.5,float(row[1])),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,row[3])
