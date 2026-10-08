extends Control
## Rounded toy-like interface with generous touch targets and candy colors.
## Every graphic here is drawn locally; the miniature and skin preview use
## authored Godot geometry rather than reference assets.
const Art=preload("res://fidelity/art.gd")
const FoodPreview=preload("res://fidelity/food_preview.gd")
const ToyPreview=preload("res://fidelity/toy_preview.gd")
const FrostPreview=preload("res://fidelity/frost_preview.gd")
const SkinVisual=preload("res://fidelity/skin_visual.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const MapCatalog=preload("res://fidelity/map_catalog.gd")
const CaseOpening=preload("res://fidelity/case_opening.gd")
const MapCarousel=preload("res://fidelity/map_carousel.gd")
const ReleaseInfo=preload("res://fidelity/release_info.gd")
const ViewportLayout=preload("res://fidelity/viewport_layout.gd")
const FairytaleLighting=preload("res://fidelity/fairytale_lighting.gd")
const PURCHASE_IDS:=["sink_city.diamonds_100","sink_city.diamonds_360","sink_city.diamonds_1800"]
const PURCHASE_DIAMONDS:=[100,360,1800]
var game:Node3D
var font:Font
var buttons:Array[Button]=[]
var case_opening:Control
var rates_return:="holes"
var map_carousel:Control
var home_play_button:Button
var hero:TextureRect
var hero_models:Node3D
var hero_view:SubViewport
var skin_view:SubViewport
var skin_texture:TextureRect
var skin_preview:Node3D
var skin_preview_void:MeshInstance3D
var skin_preview_ring:MeshInstance3D
var skin_cards:Array[SubViewport]=[]
var card_environment:Environment
var card_textures:Array[TextureRect]=[]
var animation:=0.0
var toast:=""
var toast_time:=0.0
var menu_screen:="home"
var preview_skin_id:="core_shell"
var skin_scroll:=0.0
var skin_list:Control
var skin_order:Array[String]=[]
var skin_positions:Dictionary={}
var skin_tiers:Array[Dictionary]=[]
var skin_content_height:=0.0
var card_skin_ids:Array[String]=[]
var skin_pointer:=-2
var skin_pointer_origin:=Vector2.ZERO
var skin_pointer_last:=Vector2.ZERO
var skin_pointer_dragged:=false
var skin_scroll_velocity:=0.0
var unlock_feedback_time:=0.0
var icons:Dictionary={}
var panel_styles:Dictionary={}
var goal_pop:=[0.0,0.0,0.0]
var last_goal_counts:=[0,0,0]
var displayed_phase:=""
var release_info:Control
var rewarded_ui_available:=false
var monetization_poll_remaining:=0.0
var layout_poll_remaining:=0.0
const ICON_NAMES:=["coin","trophy","boost","check","lock","pause","back","play","clock","donut","cake","treats","skins","city","food-map"]
const MAP_CAROUSEL_RECT:=Rect2(0,214,540,458)
const SKIN_LIST_RECT:=Rect2(20,168,500,452)
const SKIN_CARD_SIZE:=Vector2i(144,106)
const SKIN_CARD_MAX_SCALE:=3.0
const STORE_VIDEO_RECT:=Rect2(40,199,460,100)
const RESULT_OFFER_TOP:=340.0
const RESULT_OFFER_GAP:=166.0
const RESULT_VIDEO_X:=78.0
const RESULT_DIAMONDS_X:=288.0
const NAV_DESTINATIONS:=["home","store","holes"]
const NAV_TARGET_IDS:=["holes-home","store-nav","holes-nav"]
const NAV_LABELS:=["HOME","STORE","HOLES"]
const INK:=Color("263467")
const PAPER:=Color("fffdf7")
const RUST:=Color("ffae12")
const OCHRE:=Color("fff080")
const MINT:=Color("cafffb")
const MOSS:=Color("56ccff")
const SLATE:=Color("3771ce")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(update_viewport_layout)
	update_viewport_layout()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	var bold:=FontVariation.new()
	bold.base_font=load("res://assets/fonts/Fredoka.ttf")
	bold.variation_opentype={"wght":650.0}
	bold.variation_embolden=0.65
	font=bold
	for id in ICON_NAMES:icons[id]=load("res://assets/ui/"+id+".svg")
	make_hero()
	make_map_carousel()
	make_skin_preview()
	make_skin_collection()
	case_opening=CaseOpening.new();case_opening.ui=self;case_opening.game=game
	add_child(case_opening);case_opening.hide()
	refresh()

func make_skin_collection()->void:
	skin_list=Control.new()
	var window:=skin_list_rect()
	skin_list.position=window.position;skin_list.size=window.size
	skin_list.clip_contents=true;skin_list.mouse_filter=Control.MOUSE_FILTER_IGNORE
	skin_list.draw.connect(draw_skin_collection)
	add_child(skin_list)
	skin_order=game.skin_ids("collection")
	skin_order.sort_custom(func(a:String,b:String)->bool:
		var first:Dictionary=game.skin_definition(a);var second:Dictionary=game.skin_definition(b)
		var rank_a:=Rarity.index_of(str(first.rarity));var rank_b:=Rarity.index_of(str(second.rarity))
		return rank_a<rank_b if rank_a!=rank_b else str(first.name).naturalnocasecmp_to(str(second.name))<0)
	var y:=0.0
	for rank in Rarity.ORDER.size():
		var tier_ids:=skin_order.filter(func(id):return game.skin_definition(id).rarity==Rarity.ORDER[rank])
		skin_tiers.append({"rarity":Rarity.ORDER[rank],"y":y,"count":tier_ids.size(),"rank":rank})
		y+=36.0
		for index in tier_ids.size():skin_positions[tier_ids[index]]=Rect2((index%3)*170,y+(index/3)*172,160,164)
		y+=ceilf(float(tier_ids.size())/3.0)*172.0+12.0
	skin_content_height=y-12.0

func update_viewport_layout()->void:
	var viewport:=get_viewport_rect().size
	var layout:=ViewportLayout.fit(viewport,viewport_safe_rect(viewport))
	var changed:bool=not position.is_equal_approx(layout.position) or not scale.is_equal_approx(layout.scale) or not size.is_equal_approx(layout.size)
	if changed:
		# A pointer began in the previous canvas transform. Its next release
		# must not select a new card or apply stale flick velocity after a resize.
		skin_pointer=-2;skin_pointer_dragged=false;skin_scroll_velocity=0
		if is_instance_valid(map_carousel):map_carousel.cancel_pointer(true)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position=layout.position;scale=layout.scale;size=layout.size
	if is_instance_valid(skin_list):
		var window:=skin_list_rect()
		skin_list.position=window.position;skin_list.size=window.size
	if is_instance_valid(hero):
		var miniature:=responsive_rect(Rect2(-8,188,556,296))
		hero.position=miniature.position;hero.size=miniature.size
	if is_instance_valid(map_carousel):
		var maps_rect:=responsive_rect(MAP_CAROUSEL_RECT)
		map_carousel.position=maps_rect.position;map_carousel.size=maps_rect.size
	if changed and font!=null and is_instance_valid(hero):refresh(true)
	queue_redraw()

func viewport_safe_rect(viewport:Vector2)->Rect2:
	return ViewportLayout.safe_rect(viewport)

func responsive_y(y:float)->float:
	# Keep the status controls near the safe top and the dock near the safe
	# bottom. Extra portrait space opens the middle; text remains undistorted.
	var extra:=maxf(0.0,size.y-ViewportLayout.DESIGN.y)
	return y+extra*clampf((y-100.0)/746.0,0.0,1.0)

func responsive_point(at:Vector2)->Vector2:
	return Vector2(at.x,responsive_y(at.y))

func responsive_rect(rect:Rect2)->Rect2:
	var top:=responsive_y(rect.position.y)
	return Rect2(rect.position.x,top,rect.size.x,responsive_y(rect.end.y)-top)

func skin_list_rect()->Rect2:
	return responsive_rect(SKIN_LIST_RECT)

func canvas_point(at:Vector2)->Vector2:
	return get_global_transform_with_canvas().affine_inverse()*at

func canvas_bounds()->Rect2:
	return Rect2(canvas_point(Vector2.ZERO),get_viewport_rect().size/scale)

func make_hero() -> void:
	hero_view=SubViewport.new()
	hero_view.size=Vector2i(640,560)
	hero_view.transparent_bg=true
	hero_view.own_world_3d=true
	hero_view.msaa_3d=Viewport.MSAA_2X
	add_child(hero_view)
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_CLEAR_COLOR
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color.WHITE
	env.ambient_light_energy=0.8
	envnode.environment=env
	hero_view.add_child(envnode)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-32,0)
	light.light_color=Color.WHITE
	light.light_energy=0.9
	light.shadow_enabled=true
	hero_view.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=21
	hero_view.add_child(camera)
	camera.position=Vector3(19,24,26)
	camera.look_at(Vector3(0,4.0,0))
	camera.current=true
	hero=TextureRect.new()
	hero.texture=hero_view.get_texture()
	hero.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Keep the 3D miniature below the status line so the model never paints
	# over the only instruction on the home screen.
	var miniature:=responsive_rect(Rect2(-8,188,556,296))
	hero.position=miniature.position
	hero.size=miniature.size
	hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hero)
	# Lighting and visibility must already exist when a saved food selection
	# builds its first miniature, just as when the map card is selected later.
	update_map_preview()

func make_map_carousel()->void:
	map_carousel=MapCarousel.new();map_carousel.game=game;map_carousel.font=font
	var rect:=responsive_rect(MAP_CAROUSEL_RECT)
	map_carousel.position=rect.position;map_carousel.size=rect.size
	add_child(map_carousel)
	map_carousel.focused.connect(map_focus_changed)

func map_focus_changed(id:String)->void:
	if game.map_unlocked(id):
		game.select_map(id)
	else:refresh()

func play_focused_map()->void:
	if not is_instance_valid(map_carousel) or map_carousel.pointer!=-2:return
	var id:String=map_carousel.current_id()
	if not game.map_unlocked(id):return
	if game.selected_map!=id:game.select_map(id)
	if game.selected_map==id:game.start_level()

func sync_map_controls()->void:
	if not is_instance_valid(map_carousel):return
	var showing:bool=game.phase=="title" and menu_screen=="home"
	map_carousel.visible=showing
	if not showing:map_carousel.cancel_pointer(true)
	map_carousel.set_process(showing)
	if showing:
		map_carousel.layout_photos()
		if is_instance_valid(home_play_button):
			var unlocked:bool=game.map_unlocked(map_carousel.current_id())
			home_play_button.text="PLAY" if unlocked else "LOCKED"
			home_play_button.icon=icons.play if unlocked else icons.lock
			home_play_button.disabled=not unlocked or map_carousel.pointer!=-2

func make_skin_preview() -> void:
	skin_view=SubViewport.new()
	skin_view.size=Vector2i(360,190)
	skin_view.transparent_bg=true
	skin_view.own_world_3d=true
	skin_view.msaa_3d=Viewport.MSAA_2X
	add_child(skin_view)
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_CLEAR_COLOR
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b8d8ff")
	env.ambient_light_energy=0.75
	envnode.environment=env
	skin_view.add_child(envnode)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-24,0)
	light.light_color=Color("ffd166")
	light.light_energy=1.1
	skin_view.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.65
	camera.position=Vector3(0,6.6,8.0)
	skin_view.add_child(camera)
	camera.look_at(Vector3(0,.16,0))
	camera.current=true
	skin_preview=SkinVisual.new()
	skin_view.add_child(skin_preview)
	skin_texture=TextureRect.new()
	skin_texture.texture=skin_view.get_texture()
	skin_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	skin_texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skin_texture.position=Vector2(90,170)
	skin_texture.size=Vector2(360,132)
	skin_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	skin_texture.visible=false
	add_child(skin_texture)

func apply_skin_preview(id:String) -> void:
	if not is_instance_valid(skin_preview):return
	if skin_preview.skin_id!=id or not is_instance_valid(skin_preview.main_ring):
		skin_preview.build(game.skin_definition(id),true)
	skin_preview.frame_preview(skin_view.get_camera_3d(),false)
	skin_preview_ring=skin_preview.main_ring
	skin_preview_void=skin_preview.mouth

func box(rect:Rect2,color:Color,radius:=24,border:=Color("ffffff"),stroke:=2,target:CanvasItem=null) -> void:
	if target==null:target=self
	if target!=skin_list:rect=responsive_rect(rect)
	var corner:=mini(int(rect.size.y*.5),radius)
	var key:="%s:%s:%d:%d:%s"%[color.to_html(),border.to_html(),corner,stroke,rect.size.y>30]
	if not panel_styles.has(key):
		var fresh:=StyleBoxFlat.new()
		fresh.bg_color=color
		fresh.set_corner_radius_all(corner)
		fresh.border_color=border
		fresh.set_border_width_all(stroke)
		if rect.size.y>30:
			fresh.shadow_color=Color("26316b",.25)
			fresh.shadow_size=2;fresh.shadow_offset=Vector2(0,6)
		panel_styles[key]=fresh
	var style:StyleBoxFlat=panel_styles[key]
	target.draw_style_box(style,rect)
	if rect.size.y>=44:
		target.draw_line(rect.position+Vector2(corner+5,7),rect.position+Vector2(rect.size.x-corner-5,7),Color(1,1,1,.20),3,true)

func icon(id:String,at:Vector2,size_:float=48.0,alpha:float=1.0,target:CanvasItem=null) -> void:
	if target==null:target=self
	if target!=skin_list:at=responsive_point(at)
	if icons.has(id):target.draw_texture_rect(icons[id],Rect2(at-Vector2.ONE*size_*.5,Vector2.ONE*size_),false,Color(1,1,1,alpha))

func text_center(message:String,at:Vector2,font_size:int,tint:=Color.WHITE,outline:=true,target:CanvasItem=null) -> void:
	if target==null:target=self
	if target!=skin_list:at=responsive_point(at)
	var width:=font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var pos:=at-Vector2(width/2,0)
	if outline:target.draw_string_outline(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("273766"))
	target.draw_string(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func button(rect:Rect2,title:String,callback:Callable,tint:=Color("ffa51b")) -> Button:
	rect=responsive_rect(rect)
	var b:=Button.new()
	b.position=rect.position
	b.size=rect.size
	b.text=title
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",32 if title=="PLAY" and rect.size.x<200 else 40 if title=="PLAY" else 23)
	b.add_theme_font_override("font",font)
	var ink_text:=tint.get_luminance()>.65 and title!="PLAY"
	b.add_theme_color_override("font_color",INK if ink_text else PAPER)
	b.add_theme_color_override("font_hover_color",INK if ink_text else PAPER)
	b.add_theme_color_override("font_pressed_color",INK if ink_text else PAPER)
	b.add_theme_color_override("font_outline_color",Color(0,0,0,0.35))
	b.add_theme_constant_override("outline_size",2)
	for state in ["normal","hover","pressed"]:
		var s:=StyleBoxFlat.new()
		s.bg_color=tint.lightened(0.12) if state=="hover" else tint.darkened(0.12) if state=="pressed" else tint
		s.border_color=tint.lightened(.65) if tint.a>0 else Color(1,1,1,.35)
		s.border_width_left=2
		s.border_width_top=2
		s.border_width_right=2
		s.border_width_bottom=5 if tint.a>0 else 0
		s.set_corner_radius_all(mini(36,int(rect.size.y*.5)))
		s.shadow_color=tint.darkened(.30) if tint.a>0 else Color("3946a2",.25)
		s.shadow_size=1
		s.shadow_offset=Vector2(0,7 if state!="pressed" else 2)
		b.add_theme_stylebox_override(state,s)
	var disabled_style:=StyleBoxFlat.new()
	disabled_style.bg_color=tint.lerp(Color("889eb4"),.70)
	disabled_style.border_color=Color("d4dfeb")
	disabled_style.set_border_width_all(2)
	disabled_style.set_corner_radius_all(mini(36,int(rect.size.y*.5)))
	b.add_theme_stylebox_override("disabled",disabled_style)
	b.add_theme_color_override("font_disabled_color",Color("f3f6fa"))
	var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT
	focus.border_color=Color("fff4ad");focus.set_border_width_all(3);focus.set_corner_radius_all(30)
	b.add_theme_stylebox_override("focus",focus)
	if title=="PLAY":
		b.icon=icons.play
		b.add_theme_constant_override("icon_max_width",32)
		b.add_theme_constant_override("h_separation",12)
	b.pressed.connect(callback)
	add_child(b)
	buttons.append(b)
	return b

func hotspot(id:String,rect:Rect2,callback:Callable,adapt:=true) -> Button:
	if adapt:rect=responsive_rect(rect)
	var b:=Button.new()
	b.name=id
	b.position=rect.position
	b.size=rect.size
	b.flat=true
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		var s:=StyleBoxFlat.new()
		s.bg_color=Color(1,1,1,.12) if state=="hover" else Color("213a7b",.18) if state=="pressed" else Color.TRANSPARENT
		if state=="focus":s.border_color=Color("fff4ad");s.set_border_width_all(3)
		s.set_corner_radius_all(26)
		b.add_theme_stylebox_override(state,s)
	b.pressed.connect(callback)
	add_child(b)
	buttons.append(b)
	return b

func slot_rect(index:int) -> Rect2:
	var rect:Rect2=skin_positions[visible_skin_ids()[index]]
	rect.position+=skin_list.position-Vector2(0,skin_scroll)
	return rect

func visible_skin_ids()->Array[String]:
	var ids:Array[String]=[]
	var window:=Rect2(0,skin_scroll,skin_list.size.x,skin_list.size.y)
	for id in skin_order:
		if window.intersects(skin_positions[id]):ids.append(id)
	return ids

func max_skin_scroll()->float:
	return maxf(0,skin_content_height-skin_list.size.y)

func set_skin_scroll(value:float)->void:
	skin_scroll=clampf(value,0,max_skin_scroll())
	if visible_skin_ids()!=card_skin_ids:refresh()
	else:
		for i in card_textures.size():
			card_textures[i].position=slot_rect(i).position-skin_list.position+Vector2(8,4)
		for b in buttons:
			if b.has_meta("skin_id"):
				var rect:Rect2=skin_positions[str(b.get_meta("skin_id"))]
				b.position=rect.position-Vector2(0,skin_scroll)
				b.disabled=not Rect2(Vector2.ZERO,skin_list.size).encloses(b.get_rect())
		skin_list.queue_redraw();queue_redraw()

func scroll_to_skin(id:String)->void:
	if not skin_positions.has(id):return
	skin_scroll_velocity=0
	set_skin_scroll(float(skin_positions[id].position.y)-36.0)

func focus_card_previews()->void:
	for i in skin_cards.size():
		var active:bool=card_skin_ids[i]==preview_skin_id and game.phase=="title" and menu_screen=="holes"
		skin_cards[i].render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_ONCE
		for child in skin_cards[i].get_children():
			if child is SkinVisual:child.set_process(active)

func skin_detail_text()->String:
	var definition:Dictionary=game.skin_definition(preview_skin_id)
	return str(definition.skill_desc)

func skin_trigger_text()->String:
	var definition:Dictionary=game.skin_definition(preview_skin_id)
	if definition.kind=="cosmetic":return "COSMETIC · No gameplay effect"
	return ("AUTO" if definition.kind=="bloom" else "TAP SKILL")+" · %.0fs cooldown"%float(definition.cooldown)

func slot_hotspot(rect:Rect2,skin_id:String) -> void:
	var b:=hotspot("hole-slot-"+skin_id,rect,Callable(self,"select_hole_slot").bind(skin_id),false)
	b.reparent(skin_list,false);b.position=rect.position-skin_list.position
	b.set_meta("skin_id",skin_id)
	b.tooltip_text=str(game.skin_definition(skin_id).name)
	b.disabled=not Rect2(Vector2.ZERO,skin_list.size).encloses(b.get_rect())

func select_hole_slot(skin_id:String) -> void:
	preview_skin_id=skin_id
	apply_skin_preview(skin_id)
	var definition:Dictionary=game.skin_definition(skin_id)
	if not game.skin_unlocked(skin_id):
		toast="Open a case to discover a new skin"
		toast_time=1.5
	else:
		var equipped:bool=game.select_skin(skin_id)
		toast="%s EQUIPPED"%definition.name if equipped else "Could not save. Try again."
		toast_time=1.5
	focus_card_previews()
	skin_list.queue_redraw()
	queue_redraw()

func open_holes() -> void:
	menu_screen="holes"
	preview_skin_id=game.selected_skin_id
	skin_scroll=0;skin_scroll_velocity=0;skin_pointer=-2
	toast_time=0
	refresh()

func close_menu() -> void:
	menu_screen="home"
	refresh()

func refresh(preserve_info:=false) -> void:
	game.sync_audio_context()
	if is_instance_valid(skin_list):skin_list.visible=game.phase=="title" and menu_screen=="holes"
	if game.phase!="title" or menu_screen!="holes":skin_pointer=-2;skin_scroll_velocity=0
	if not preserve_info and is_instance_valid(release_info):release_info.queue_free()
	if displayed_phase!=game.phase:
		displayed_phase=game.phase
		toast_time=0.0
		last_goal_counts=[0,0,0]
		goal_pop=[0.0,0.0,0.0]
	for b in buttons:
		b.hide()
		# Refresh can be called from a pressed signal. Keep the emitting button
		# deferred-free, but release its name so the next menu can reuse it.
		b.name="_old-ui-%s"%b.get_instance_id()
		b.queue_free()
	buttons.clear()
	for texture in card_textures:texture.hide();texture.queue_free()
	for view in skin_cards:
		view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		for child in view.get_children():
			if child is SkinVisual:child.set_process(false)
		view.queue_free()
	card_textures.clear();skin_cards.clear();card_skin_ids.clear()
	sync_hero_preview()
	sync_map_controls()
	if is_instance_valid(skin_texture):
		skin_texture.visible=false # The reference collection uses card previews, without a large detail panel.
		skin_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if skin_texture.visible else SubViewport.UPDATE_DISABLED
		apply_skin_preview(preview_skin_id)
		skin_preview.set_process(skin_texture.visible)
	if is_instance_valid(case_opening):
		case_opening.visible=game.phase=="title" and menu_screen=="case"
	if game.phase=="title" and menu_screen=="case":
		case_opening.controls()
	elif game.phase=="title" and menu_screen=="home":
		var settings:=button(Rect2(412,20,104,64),"SETTINGS",open_settings,Color("638be7"))
		settings.name="home-settings";settings.add_theme_font_size_override("font_size",14)
		home_play_button=button(Rect2(86,744,368,82),"PLAY",play_focused_map,Color("ffa51c"))
		home_play_button.name="home-play"
		var previous:=button(Rect2(20,678,64,64),"‹",func():map_carousel.step(-1),Color("638be7"))
		previous.name="map-previous";previous.disabled=map_carousel.focus_index==0
		var next:=button(Rect2(456,678,64,64),"›",func():map_carousel.step(1),Color("638be7"))
		next.name="map-next";next.disabled=map_carousel.focus_index==map_carousel.definitions.size()-1
		make_navigation("home")
		sync_map_controls()
	elif game.phase=="title" and menu_screen=="holes":
		button(Rect2(394,20,122,64),"RATES",open_rates,Color("748bea")).name="skin-rates"
		skin_scroll=clampf(skin_scroll,0,max_skin_scroll())
		var ids:=visible_skin_ids()
		for index in ids.size():
			make_card_preview(ids[index],slot_rect(index))
			slot_hotspot(slot_rect(index),ids[index])
		focus_card_previews()
		var unlock:=hotspot("unlock-random",Rect2(90,757,360,81),request_unlock)
		unlock.disabled=game.locked_skin_ids(active_skin_group()).is_empty() and game.pending_skin_case().is_empty()
		unlock.tooltip_text="Preview the skin case and its current odds"
		make_navigation("holes")
	elif game.phase=="title" and menu_screen=="store":
		hotspot("store-diamond-video",STORE_VIDEO_RECT,request_diamond_video)
		for i in game.COIN_PACKS.size():
			hotspot("store-pack-%d"%i,Rect2(40,324+i*122,460,96),Callable(self,"request_coin_pack").bind(i))
		button(Rect2(90,735,360,68),"DIAMOND SHOP",open_purchases,Color("bd64e1")).name="diamond-shop"
		make_navigation("store")
	elif game.phase=="title" and menu_screen=="rates":
		button(Rect2(20,20,122,64),"BACK",close_rates,Color("748bea")).name="rates-back"
		make_navigation("holes")
	elif game.phase=="title" and menu_screen=="purchases":
		button(Rect2(20,20,122,64),"BACK",open_store,Color("748bea")).name="purchase-back"
		for i in PURCHASE_IDS.size():
			var available:bool=is_instance_valid(game.commerce) and game.commerce.purchase_available(PURCHASE_IDS[i])
			hotspot("purchase-%d"%i,Rect2(40,236+i*156,460,126),Callable(self,"request_purchase").bind(PURCHASE_IDS[i])).disabled=not available or not game.purchase_request.is_empty()
		make_navigation("store")
	elif game.phase=="title" and menu_screen=="settings":
		button(Rect2(20,20,122,64),"BACK",close_menu,Color("748bea")).name="settings-back"
		for entry in [["audio-music","MUSIC",game.music_enabled,game.toggle_music],
			["audio-sfx","SOUND",game.sfx_enabled,game.toggle_sfx],
			["feedback-haptics","HAPTICS",game.haptics_enabled,game.toggle_haptics]]:
			var index:int=["audio-music","audio-sfx","feedback-haptics"].find(entry[0])
			button(Rect2(90,236+index*96,360,70),entry[1]+"  "+("ON" if entry[2] else "OFF"),entry[3],Color("638be7")).name=entry[0]
		button(Rect2(90,574,360,70),"PRIVACY & SUPPORT",open_release_info,Color("638be7")).name="release-info"
		make_navigation("home")
	elif game.phase in ["eaten","timeout","complete"]:
		var loading:bool=game.reward_video_pending()
		if game.can_boost_round_coins():
			make_result_offer("coin-boost",RESULT_OFFER_TOP,"%d DIAMONDS"%game.COIN_BOOST_GEM_COST,request_coin_boost_video,request_coin_boost_diamonds)
		if game.can_extend_round():
			make_result_offer("extend",result_extension_y(),"%d DIAMONDS"%game.EXTENSION_GEM_COST,request_extension_video,request_extension_diamonds)
		var again:=button(Rect2(90,735,360,68),"PLAY AGAIN",game.start_level,Color("ffa51c"))
		again.name="result-play-again";again.disabled=loading
		var home:=button(Rect2(142,820,256,64),"HOME",game.back_home,Color("5f88e8"))
		home.name="result-home";home.disabled=loading
	elif get_tree().paused:
		make_audio_controls(true)
		button(Rect2(90,491,360,70),"KEEP PLAYING",game.toggle_pause,Color("49d08a"))
		button(Rect2(142,589,256,64),"HOME",game.back_home,Color("638be7"))
	elif game.phase=="playing":
		hotspot("pause-action",Rect2(456,20,64,64),game.toggle_pause).tooltip_text="Pause"
		if game.skin_definition(game.player.skin_id).kind!="cosmetic":
			hotspot("skin-action",Rect2(414,680,104,94),Callable(self,"request_skin_skill"))
		hotspot("pulse-action",Rect2(414,797,104,112),Callable(self,"request_pulse")).tooltip_text="Eat to charge. Tap for 2.5s of faster movement."
	if is_instance_valid(skin_list):skin_list.queue_redraw()
	sync_monetization_controls()
	queue_redraw()

func open_store()->void:
	menu_screen="store";toast_time=0;refresh()

func open_settings()->void:
	menu_screen="settings";toast_time=0;refresh()

func open_release_info()->void:
	if is_instance_valid(release_info):return
	release_info=ReleaseInfo.new()
	release_info.ads_bridge=game.ads
	add_child(release_info)

func open_maps()->void:
	# The complete row now lives on Home; retain the entry point for old callers.
	menu_screen="home";toast_time=0;refresh()

func pick_map(id:String)->void:
	if not game.MAPS.has(id):return
	menu_screen="home";map_carousel.focus_map(id,true,true)

func open_rates()->void:
	rates_return=menu_screen
	menu_screen="rates";toast_time=0;refresh()

func close_rates()->void:
	menu_screen=rates_return;toast_time=0;refresh()

func open_purchases()->void:
	menu_screen="purchases";toast_time=0;refresh()

func request_purchase(product_id:String)->void:
	var result:Dictionary=game.request_diamond_purchase(product_id)
	toast=result.message;toast_time=3.0;refresh()

func make_audio_controls(in_pause:bool)->void:
	# 64 design pixels remain above 44 points at a 375-point phone width.
	var y:=681.0 if in_pause else 20.0
	var first:=Rect2(90,y,112,64) if in_pause else Rect2(166,y,112,64)
	var second:=Rect2(214,y,112,64) if in_pause else Rect2(286,y,98,64)
	var music_button:=button(first,"MUSIC ON" if game.music_enabled else "MUSIC OFF",game.toggle_music,Color("638be7"))
	music_button.name="audio-music"
	music_button.add_theme_font_size_override("font_size",15 if in_pause else 18)
	music_button.tooltip_text="Turn background music on or off"
	var sfx_button:=button(second,"SFX ON" if game.sfx_enabled else "SFX OFF",game.toggle_sfx,Color("638be7"))
	sfx_button.name="audio-sfx"
	sfx_button.add_theme_font_size_override("font_size",17 if in_pause else 18)
	sfx_button.tooltip_text="Turn collection and collision sounds on or off"
	if in_pause:
		var haptic_button:=button(Rect2(338,y,112,64),"HAPTIC ON" if game.haptics_enabled else "HAPTIC OFF",game.toggle_haptics,Color("638be7"))
		haptic_button.name="feedback-haptics"
		haptic_button.add_theme_font_size_override("font_size",14)
		haptic_button.tooltip_text="Turn light swallow vibration on or off"

func request_diamond_video()->void:
	var result:Dictionary=game.request_diamond_video()
	toast=result.message;toast_time=3.0;refresh()

func request_extension_video()->void:
	var result:Dictionary=game.request_round_extension_video()
	toast=result.message;toast_time=3.0;refresh()

func request_extension_diamonds()->void:
	var result:Dictionary=game.request_round_extension_gems()
	toast=result.message;toast_time=3.0;refresh()

func request_coin_boost_video()->void:
	var result:Dictionary=game.request_round_coin_boost_video()
	toast=result.message;toast_time=3.0;refresh()

func request_coin_boost_diamonds()->void:
	var result:Dictionary=game.request_round_coin_boost_gems()
	toast=result.message;toast_time=3.0;refresh()

func result_extension_y()->float:
	return RESULT_OFFER_TOP+RESULT_OFFER_GAP if game.can_boost_round_coins() else RESULT_OFFER_TOP

func make_result_offer(id:String,y:float,price:String,video_action:Callable,diamond_action:Callable)->void:
	var video:=button(Rect2(RESULT_VIDEO_X,y+55,174,64),"VIDEO",video_action,Color("59c592"))
	video.name=id+"-video"
	video.add_theme_font_size_override("font_size",19)
	video.tooltip_text="Finish the optional rewarded video and close the ad to receive this reward. An unfinished video gives no reward."
	var diamonds:=button(Rect2(RESULT_DIAMONDS_X,y+55,174,64),price,diamond_action,Color("bd64e1"))
	diamonds.name=id+"-diamonds";diamonds.add_theme_font_size_override("font_size",17)

func sync_monetization_controls()->void:
	# Availability callbacks update immediately; the bounded poll also releases
	# the earned-video cooldown without rebuilding previews or touch controls.
	rewarded_ui_available=is_instance_valid(game.ads) and game.ads.validated_reward_available()
	var rewarded_supported:bool=is_instance_valid(game.ads) and game.ads.native_available
	var pending:bool=game.reward_video_pending()
	for b in buttons:
		if b.name=="store-diamond-video":b.disabled=pending or not rewarded_supported or game.diamond_video_cooldown_remaining()>0
		elif str(b.name).begins_with("store-pack-"):
			var index:=int(str(b.name).trim_prefix("store-pack-"))
			b.disabled=pending or game.gems<int(game.COIN_PACKS[index].gems)
		elif b.name=="extend-video":
			b.disabled=pending or not rewarded_supported or not game.can_extend_round()
			b.text="WAIT..." if pending else "VIDEO" if rewarded_ui_available else "RETRY VIDEO" if rewarded_supported else "NOT READY"
		elif b.name=="extend-diamonds":b.disabled=pending or game.gems<game.EXTENSION_GEM_COST or not game.can_extend_round()
		elif b.name=="coin-boost-video":
			b.disabled=pending or not rewarded_supported or not game.can_boost_round_coins()
			b.text="WAIT..." if pending else "VIDEO" if rewarded_ui_available else "RETRY VIDEO" if rewarded_supported else "NOT READY"
		elif b.name=="coin-boost-diamonds":b.disabled=pending or game.gems<game.COIN_BOOST_GEM_COST or not game.can_boost_round_coins()
		elif b.name in ["result-play-again","result-home"]:b.disabled=pending
		elif game.phase=="title" and menu_screen in ["store","purchases"] and pending:b.disabled=true

func request_coin_pack(index:int)->void:
	var result:Dictionary=game.buy_coin_pack(index)
	toast=result.message;toast_time=2.0;refresh()

func make_navigation(active:String)->void:
	if active=="maps":active="home"
	var actions:Array[Callable]=[close_menu,open_store,open_holes]
	for index in NAV_DESTINATIONS.size():
		var destination:String=NAV_DESTINATIONS[index]
		var target:Button=hotspot(NAV_TARGET_IDS[index],navigation_rect(index),actions[index])
		# A secondary page highlights its parent but still permits returning to it.
		target.disabled=active==destination and menu_screen==destination
		target.tooltip_text=NAV_LABELS[index]+(" · CURRENT" if target.disabled else "")

func navigation_rect(index:int)->Rect2:
	return Rect2(20+index*172,854,156,74)

func draw_navigation(active:String)->void:
	if active=="maps":active="home"
	var bar:=responsive_rect(Rect2(0,846,540,114))
	var screen:=canvas_bounds()
	# Carry the dock background under the home indicator; only its controls
	# stay inside the safe area, avoiding an unrelated strip at the screen edge.
	draw_rect(Rect2(screen.position.x,bar.position.y,screen.size.x,screen.end.y-bar.position.y),Color("374889"))
	for index in NAV_DESTINATIONS.size():
		var selected:bool=active==NAV_DESTINATIONS[index]
		var rect:=navigation_rect(index)
		var fill:=PAPER if selected else Color("465b9b")
		box(rect,fill,22 if selected else 18,Color("ffcf60") if selected else Color("7389bc"),3 if selected else 1)
		var icon_at:Vector2=rect.position+Vector2(78,25)
		if NAV_DESTINATIONS[index]=="home":
			draw_home_symbol(responsive_point(icon_at),42 if selected else 40,INK if selected else Color("e6edff"),fill)
		else:icon("coin" if NAV_DESTINATIONS[index]=="store" else "skins",icon_at,42 if selected else 40,1.0 if selected else .82)
		text_center(NAV_LABELS[index],rect.position+Vector2(78,63),19 if selected else 16,INK if selected else Color("e6edff"),false)

func draw_home_symbol(at:Vector2,size_:float,tint:Color,background:Color)->void:
	# The caller maps the icon center once, keeping the house aligned with its tap target.
	var shape:=PackedVector2Array()
	for point:Vector2 in [Vector2(-.46,-.08),Vector2(0,-.43),Vector2(.46,-.08),Vector2(.31,-.08),Vector2(.31,.39),Vector2(-.31,.39),Vector2(-.31,-.08)]:
		shape.append(at+point*size_)
	draw_colored_polygon(shape,tint)
	draw_rect(Rect2(at+Vector2(-.105,.10)*size_,Vector2(.21,.29)*size_),background)

func gem_icon(at:Vector2,size_:float)->void:
	at=responsive_point(at)
	var points:=PackedVector2Array([at+Vector2(-.5,-.1)*size_,at+Vector2(-.3,-.4)*size_,at+Vector2(.3,-.4)*size_,at+Vector2(.5,-.1)*size_,at+Vector2(0,.5)*size_])
	draw_colored_polygon(points,Color("ee60fa"))
	draw_polyline(points+PackedVector2Array([points[0]]),Color("ffd4ff"),2,true)
	draw_line(at-Vector2(.22,.24)*size_,at+Vector2(.23,-.24)*size_,Color.WHITE,3,true)

func draw_store()->void:
	contour_wallpaper()
	text_center("STORE",Vector2(270,129),48,PAPER)
	box(Rect2(24,28,224,58),Color("415792"),20,Color("a5c8f1"),2)
	icon("coin",Vector2(56,56),45);text_center(str(game.coins),Vector2(155,69),26,PAPER)
	box(Rect2(292,28,224,58),Color("415792"),20,Color("a5c8f1"),2)
	gem_icon(Vector2(325,55),37);text_center(str(game.gems),Vector2(417,69),26,PAPER)
	text_center("COINS",Vector2(155,83),10,PAPER,false)
	text_center("DIAMONDS",Vector2(417,83),10,PAPER,false)
	var cooldown:=int(ceil(game.diamond_video_cooldown_remaining()))
	var pending:bool=game.reward_video_pending()
	var supported:bool=is_instance_valid(game.ads) and game.ads.native_available
	var available:bool=rewarded_ui_available and cooldown<=0 and not pending
	box(STORE_VIDEO_RECT,Color("69bf66") if available else Color("879bb6"),25,Color("e2ffe3"),3)
	gem_icon(Vector2(85,241),45)
	var video_label:="LOADING VIDEO..." if pending else "WATCH VIDEO" if available else "NEXT VIDEO IN %ds"%cooldown if cooldown>0 else "RETRY VIDEO" if supported else "VIDEO NOT READY"
	text_center(video_label,Vector2(299,233),24,PAPER)
	text_center("+3 DIAMONDS",Vector2(299,269),20,PAPER,false)
	text_center("EXCHANGE",Vector2(270,315),15,Color("fff4aa"),false)
	for i in game.COIN_PACKS.size():
		var offer:Dictionary=game.COIN_PACKS[i]
		var y:float=324.0+int(i)*122
		box(Rect2(40,y,460,96),PAPER,26,Color.WHITE,2)
		icon("coin",Vector2(89,y+47),64)
		text_center("%d COINS"%int(offer.coins),Vector2(252,y+38),28,INK,false)
		gem_icon(Vector2(210,y+66),25)
		text_center("%d DIAMONDS"%int(offer.gems),Vector2(303,y+76),19,Color("955abe"),false)
		icon("check" if game.gems>=int(offer.gems) else "lock",Vector2(459,y+48),32)
	if toast_time>0:
		text_center(toast,Vector2(270,824),17,PAPER,false)
	draw_navigation("store")

func active_skin_group()->String:
	return "collection"

func request_unlock()->void:
	if menu_screen=="case":return
	menu_screen="case";toast_time=0
	case_opening.enter();refresh()

func request_skin_skill() -> void:
	if is_instance_valid(game.player) and game.player.trigger_skin_skill():
		queue_redraw()
		return
	if not is_instance_valid(game.player):return
	var definition:Dictionary=game.skin_definition(game.player.skin_id)
	if definition.kind=="bloom":toast="AUTO SKILL"
	elif definition.kind=="cosmetic":toast="LOOKS ONLY"
	elif game.player.skin_cooldown>0.0:toast="COOLDOWN %.1f"%game.player.skin_cooldown
	else:toast="SKILL UNAVAILABLE"
	toast_time=1.3
	queue_redraw()

func request_pulse() -> void:
	if is_instance_valid(game.player) and game.player.trigger_pulse():
		queue_redraw()
	else:
		toast=boost_button_state().hint
		toast_time=1.3
		queue_redraw()

func boost_button_state()->Dictionary:
	var state:={"phase":"charging","text":"0%","caption":"BOOST","ratio":0.0,"hint":"Eat to charge your boost"}
	if not is_instance_valid(game.player):return state
	var hole=game.player
	state.ratio=clampf(hole.pulse_charge/hole.PULSE_MAX,0,1)
	state.text="%d%%"%int(state.ratio*100)
	if hole.boost_time>0.0:
		state.phase="active";state.caption="BOOSTING"
		state.text="%.1fs"%hole.boost_time
		state.ratio=clampf(hole.boost_time/hole.BOOST_DURATION,0,1)
		state.hint="Boost active: +55% speed"
	elif hole.pulse_cooldown>0.0:
		state.phase="cooldown";state.caption="RECHARGE"
		state.text="%.1fs"%hole.pulse_cooldown
		state.ratio=1.0-clampf(hole.pulse_cooldown/hole.BOOST_COOLDOWN,0,1)
		state.hint=("Boost ready in %.1fs" if hole.pulse_charge>=hole.PULSE_MAX else "Cooling down: %.1fs. Eat to charge.")%hole.pulse_cooldown
	elif state.ratio>=1.0:
		state.phase="ready";state.text="GO!"
		state.hint="Tap BOOST for +55% speed"
	return state

func show_no_gems() -> void:
	toast="Not enough diamonds"
	toast_time=2.0

func _process(delta:float) -> void:
	animation+=delta
	if game.phase=="title" and menu_screen=="home" and is_instance_valid(home_play_button):
		home_play_button.disabled=not game.map_unlocked(map_carousel.current_id()) or map_carousel.pointer!=-2
	layout_poll_remaining-=delta
	if layout_poll_remaining<=0:
		layout_poll_remaining=.5
		update_viewport_layout()
	monetization_poll_remaining-=delta
	if monetization_poll_remaining<=0:
		monetization_poll_remaining=.25
		if game.phase in ["eaten","timeout","complete"] or game.phase=="title" and menu_screen in ["store","purchases"]:
			sync_monetization_controls()
			queue_redraw()
	if game.phase=="title" and menu_screen=="holes":
		refresh_card_render_sizes()
		if skin_pointer==-2 and absf(skin_scroll_velocity)>1:
			var previous:=skin_scroll
			set_skin_scroll(skin_scroll+skin_scroll_velocity*delta)
			skin_scroll_velocity=move_toward(skin_scroll_velocity,0,1800*delta)
			if skin_scroll==previous:skin_scroll_velocity=0
	if unlock_feedback_time>0:
		unlock_feedback_time=maxf(0,unlock_feedback_time-delta)
		if game.phase=="title" and menu_screen=="holes":
			var ids:=visible_skin_ids()
			for i in card_textures.size():
				if ids[i]==preview_skin_id:
					card_textures[i].pivot_offset=card_textures[i].size*.5
					card_textures[i].scale=Vector2.ONE*(1.0+.08*sin(unlock_feedback_time*PI))
		if unlock_feedback_time==0:refresh()
	toast_time=maxf(0,toast_time-delta)
	if game.phase=="playing" and game.selected_map=="food" and not get_tree().paused:
		var counts:=food_order_counts()
		for i in 3:
			goal_pop[i]=maxf(0,goal_pop[i]-delta)
			if counts[i]>last_goal_counts[i]:goal_pop[i]=.32
			last_goal_counts[i]=counts[i]
	if is_instance_valid(skin_preview) and is_instance_valid(skin_texture) and skin_texture.visible:
		skin_preview.rotation.y+=delta*.20
	if game.phase=="title" or toast_time>0:queue_redraw()

func _input(event:InputEvent) -> void:
	if game.phase=="title" and menu_screen=="home" and is_instance_valid(map_carousel):
		var handled:=false
		if event is InputEventScreenTouch:
			handled=map_carousel.pointer_event(event.index,canvas_point(event.position)-map_carousel.position,event.pressed,event.canceled)
		elif event is InputEventScreenDrag and event.index==map_carousel.pointer:
			map_carousel.drag_pointer(canvas_point(event.position)-map_carousel.position);handled=true
		elif event is InputEventMouseButton:
			var at:=canvas_point(event.position)-map_carousel.position
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT] and event.pressed and Rect2(Vector2.ZERO,map_carousel.size).has_point(at):
				map_carousel.step(1 if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_RIGHT] else -1);handled=true
			elif event.button_index==MOUSE_BUTTON_LEFT:handled=map_carousel.pointer_event(-1,at,event.pressed)
		elif event is InputEventMouseMotion and map_carousel.pointer==-1:
			map_carousel.drag_pointer(canvas_point(event.position)-map_carousel.position);handled=true
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_LEFT,KEY_RIGHT]:
			map_carousel.step(1 if event.keycode==KEY_RIGHT else -1);handled=true
		if handled:
			# Consumed card releases still count as real audio gestures. Defer
			# playback until callbacks finish, matching the shared audio gate.
			if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
				game.audio.unlock_from_gesture.call_deferred()
			get_viewport().set_input_as_handled();return

	if game.phase=="title" and menu_screen=="holes":
		if event is InputEventScreenTouch:
			if skin_pointer_event(event.index,canvas_point(event.position),event.pressed,event.canceled):get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag and event.index==skin_pointer:
			drag_skin_collection(canvas_point(event.position),event.velocity/scale)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var at:=canvas_point(event.position)
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and skin_list_rect().has_point(at):
				skin_scroll_velocity=0
				set_skin_scroll(skin_scroll+(96 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -96))
				get_viewport().set_input_as_handled()
			elif event.button_index==MOUSE_BUTTON_LEFT and skin_pointer_event(-1,at,event.pressed):get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and skin_pointer==-1:
			drag_skin_collection(canvas_point(event.position),event.velocity/scale)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if game.phase=="title" and menu_screen=="case":case_opening.back()
		elif game.phase=="title" and menu_screen=="rates":close_rates()
		elif game.phase=="title" and menu_screen!="home":close_menu()
		else:game.toggle_pause()
		get_viewport().set_input_as_handled()

func skin_pointer_event(pointer:int,at:Vector2,pressed:bool,canceled:=false)->bool:
	if pressed:
		if skin_pointer!=-2 or not skin_list_rect().has_point(at):return skin_pointer!=-2
		skin_pointer=pointer;skin_pointer_origin=at;skin_pointer_last=at
		skin_pointer_dragged=false;skin_scroll_velocity=0
		return true
	if pointer!=skin_pointer:return skin_pointer!=-2
	var moved:=skin_pointer_dragged or at.distance_to(skin_pointer_origin)>10
	skin_pointer=-2
	if canceled:skin_scroll_velocity=0;return true
	if not moved and skin_list_rect().has_point(at):
		var content_at:=at-skin_list.position+Vector2(0,skin_scroll)
		for id in skin_order:
			if skin_positions[id].has_point(content_at):select_hole_slot(id);break
	return true

func drag_skin_collection(at:Vector2,velocity:Vector2)->void:
	if at.distance_to(skin_pointer_origin)>10:skin_pointer_dragged=true
	if skin_pointer_dragged:
		set_skin_scroll(skin_scroll+skin_pointer_last.y-at.y)
		skin_scroll_velocity=clampf(-velocity.y,-1800,1800)
	skin_pointer_last=at

func crossed_axes(at:Vector2) -> void:
	draw_set_transform(at,-0.45,Vector2.ONE)
	var white:=Color("f5f4fc")
	draw_line(Vector2(-21,-16),Vector2(21,16),white,8,true)
	draw_line(Vector2(-21,16),Vector2(21,-16),white,8,true)
	for x in [-1,1]:
		draw_colored_polygon(PackedVector2Array([Vector2(x*13,-21),Vector2(x*25,-18),Vector2(x*27,-5),Vector2(x*21,0),Vector2(x*11,-9)]),white)
		draw_rect(Rect2(x*15-4,14,8,12),white)
	draw_set_transform(Vector2.ZERO)

func lock_icon(at:Vector2) -> void:
	draw_arc(at+Vector2(0,-6),9,PI,TAU,18,Color("626a91"),3,true)
	box(Rect2(at-Vector2(12,3),Vector2(24,21)),Color("c7cbea"),7,Color("6b7293"),2)
	draw_circle(at+Vector2(0,5),2.5,Color("626585"))
	draw_line(at+Vector2(0,6),at+Vector2(0,11),Color("626585"),2)

func home_icon(at:Vector2) -> void:
	draw_circle(at+Vector2(0,10),35,Color("0b1519"))
	draw_arc(at+Vector2(0,10),32,0,TAU,32,RUST,3,true)
	draw_arc(at+Vector2(0,10),24,0,TAU,32,MINT,2,true)
	draw_line(at+Vector2(-17,10),at+Vector2(17,10),OCHRE,3,true)
	draw_line(at+Vector2(0,-7),at+Vector2(0,27),OCHRE,3,true)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-9,10),at+Vector2(0,-3),at+Vector2(9,10)]),PAPER)

func contour_wallpaper() -> void:
	var bounds:=canvas_bounds()
	for i in 24:
		var tint:=Color("7260de").lerp(Color("479de9"),float(i)/23.0)
		draw_rect(Rect2(bounds.position+Vector2(0,i*bounds.size.y/24.0),Vector2(bounds.size.x,bounds.size.y/24.0+1)),tint)
	for i in 10:
		var at:=Vector2(float((i*193+33)%680)-70,float((i*223+77)%1120)-60+sin(animation*.18+i)*8)
		var radius:=float(28+(i%4)*15)
		draw_circle(at,radius,Color(1,1,1,.055))
		draw_arc(at,radius,-2.7,-1.3,20,Color(1,1,1,.19),3,true)

func signal_mark(at:Vector2,scale:=1.0) -> void:
	# A glossy hole badge replaces the previous technical crosshair emblem.
	var r:=38.0*scale
	draw_circle(at+Vector2(0,6)*scale,r+6*scale,Color("3e52ae",.30))
	draw_circle(at,r+4*scale,PAPER)
	draw_circle(at,r,Color("ff4b98"))
	draw_circle(at,r*.72,Color("293b75"))
	draw_arc(at,r*.87,-2.7,-1.1,24,Color("ffb9d9"),5*scale,true)
	draw_circle(at+Vector2(-18,-24)*scale,5*scale,Color.WHITE)
	if game.phase=="complete":star(at,r*.56,OCHRE)
	else:
		for x in [-1,1]:
			draw_circle(at+Vector2(x*10,-5)*scale,6*scale,PAPER)
			draw_circle(at+Vector2(x*10,-3)*scale,2.5*scale,INK)
		draw_arc(at+Vector2(0,3)*scale,12*scale,.1,PI-.1,18,PAPER,3*scale,true)

func star(at:Vector2,radius:float,tint:Color) -> void:
	var vertices:=PackedVector2Array()
	for i in 10:
		var a:float=-PI/2+i*PI/5
		vertices.append(at+Vector2(cos(a),sin(a))*radius*(1.0 if i%2==0 else 0.43))
	draw_colored_polygon(vertices,tint)

func _draw() -> void:
	if font==null:return
	if game.phase=="title":contour_wallpaper()
	if game.phase=="title" and menu_screen=="case":return
	if game.phase=="title" and menu_screen=="rates":draw_rates();return
	if game.phase=="title" and menu_screen=="purchases":draw_purchases();return
	if game.phase=="title" and menu_screen=="settings":draw_settings();return
	if game.phase=="title" and menu_screen=="holes":
		draw_holes_menu()
		return
	if game.phase=="title" and menu_screen=="store":
		draw_store()
		return
	if game.phase=="title":
		draw_wallet()
		text_center("HOLE FEAST",Vector2(270,145),48,PAPER)
		text_center("CHOOSE YOUR WORLD",Vector2(270,183),18,Color("e3eaff"),false)
		if is_instance_valid(map_carousel):
			var count:int=map_carousel.definitions.size()
			for index in count:
				var at:=responsive_point(Vector2(270+(index-(count-1)*.5)*24,703))
				draw_circle(at,5 if index==map_carousel.focus_index else 4,PAPER if index==map_carousel.focus_index else Color("9babeb"))
			text_center("SWIPE TO EXPLORE",Vector2(270,732),13,Color("e3eaff"),false)
		draw_navigation("home")
		return
	if game.phase in ["intro","playing"]:
		draw_game_hud()
		if game.phase=="intro":
			var shade_top:=responsive_y(236.0)
			draw_rect(Rect2(0,shade_top,540,size.y-shade_top),Color("354c89",.30))
			var points:=PackedVector2Array()
			for i in 65:
				var t:float=float(i)/64*TAU
				points.append(responsive_point(Vector2(270+63*cos(t),695+30*sin(2*t))))
			draw_polyline(points,PAPER,8,true)
			draw_circle(responsive_point(Vector2(270+63*cos(animation*2),695+30*sin(animation*4))),15,OCHRE)
			text_center("SWIPE TO EAT",Vector2(270,782),32,PAPER)
		draw_round_skill_lesson()
	elif game.phase in ["eaten","complete","timeout"]:draw_result()
	if get_tree().paused:
		draw_rect(canvas_bounds(),Color("25356f",.68))
		box(Rect2(54,255,432,520),PAPER,40,Color.WHITE,3)
		box(Rect2(222,290,96,88),Color("8981e9"),36,Color("cbc7ff"),3)
		icon("pause",Vector2(270,334),66)
		text_center("TAKE A BREAK",Vector2(270,428),36,INK,false)
		text_center("Your city can wait.",Vector2(270,460),19,SLATE,false)
	if toast_time>0:
		box(Rect2(65,303,410,50),PAPER,25,Color("bbd8ff"),2)
		text_center(toast,Vector2(270,336),18,INK,false)

func draw_wallet() -> void:
	box(Rect2(24,26,160,50),PAPER,25,Color.WHITE,2)
	icon("coin",Vector2(49,49),43)
	text_center(str(game.coins),Vector2(119,59),23,INK,false)
	box(Rect2(200,26,188,50),PAPER,25,Color.WHITE,2)
	gem_icon(Vector2(228,49),35)
	text_center(str(game.gems),Vector2(313,59),23,INK,false)

func draw_settings()->void:
	contour_wallpaper()
	text_center("SETTINGS",Vector2(270,159),44,PAPER)
	draw_navigation("home")

func draw_rarity_badge(rarity_id:String,rect:Rect2,target:CanvasItem=null)->void:
	if target==null:target=self
	var rarity:Dictionary=Rarity.data(rarity_id)
	box(rect,rarity.color,12,Color.WHITE,0,target)
	if rarity_id=="prismatic":
		var stripe:=responsive_rect(rect) if target!=skin_list else rect
		for i in Rarity.RAINBOW_COLORS.size():
			target.draw_line(stripe.position+Vector2(12+i*(stripe.size.x-24)/6.0,stripe.size.y-3),stripe.position+Vector2(12+(i+1)*(stripe.size.x-24)/6.0,stripe.size.y-3),Rarity.RAINBOW_COLORS[i],3,true)
	text_center(str(rarity.name).to_upper(),rect.position+Vector2(rect.size.x*.5+8,17),12,PAPER,true,target)

func draw_map_symbol(id:String,at:Vector2,compact:=false)->void:
	if id=="animals":
		var center:=responsive_point(at)
		draw_circle(center+Vector2(0,10),20,Color("ffa94a"))
		for offset in [Vector2(-23,-13),Vector2(-8,-26),Vector2(10,-26),Vector2(25,-11)]:draw_circle(center+offset,9,Color("ffa94a"))
	elif id=="stars":
		var center:=responsive_point(at)
		star(center,34,Color("ffd25f"));star(center+Vector2(34,-26),9,PAPER)
	elif id=="toys":
		box(Rect2(at-Vector2(29,15),Vector2(58,40)),Color("ef93bf"),12,Color("fff1d3"),2)
		for x in [-23.0,0.0,23.0]:
			box(Rect2(at+Vector2(x-9,-30),Vector2(18,53)),Color("a5dce9") if x!=0 else Color("c7b4ef"),9,Color("fff1d3"),2)
			draw_circle(responsive_point(at+Vector2(x,-29)),10,Color("fff2b4"))
		box(Rect2(at+Vector2(-8,7),Vector2(16,18)),Color("795da9"),8)
	elif id=="frost":
		var center:=responsive_point(at)
		var points:=PackedVector2Array([center+Vector2(0,-34),center+Vector2(27,16),center+Vector2(-27,16)])
		draw_colored_polygon(points,Color("83d8f2"))
		draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[0]]),Color("f4fcff"),4,true)
		draw_circle(center+Vector2(0,10),10,Color("f8fcff"))
	else:icon("city" if id=="city" else "food-map",at,64 if compact else 94)

func draw_rates()->void:
	contour_wallpaper()
	text_center("SKIN CHANCES",Vector2(270,132),36,PAPER)
	text_center("ALL %d SKINS · ONE COLLECTION"%game.SKIN_DEFS.size(),Vector2(270,162),18,PAPER,false)
	var offer:Dictionary=game.skin_draw_offer(active_skin_group())
	for i in Rarity.ORDER.size():
		var entry:Dictionary=offer.entries[i]
		var data:Dictionary=Rarity.data(str(entry.rarity))
		var y:=182.0+i*76
		box(Rect2(24,y,492,66),PAPER,22,data.color,3)
		draw_rarity_badge(str(entry.rarity),Rect2(40,y+11,150,26))
		var left:int=entry.ids.size()
		text_center("%d left"%left,Vector2(112,y+55),13,SLATE,false)
		text_center("%.2f%%"%(float(entry.chance)*100.0),Vector2(402,y+30),25,INK,false)
		text_center("Each skin: %.2f%%"%(float(entry.chance)*100.0/maxi(1,left)),Vector2(365,y+54),14,SLATE,false)
	text_center("Current odds · equal chance within each tier",Vector2(270,660),16,PAPER,false)
	text_center("No repeats. Owned tiers leave the pool.",Vector2(270,686),16,PAPER,false)
	var counters:Dictionary=offer.counters
	text_center("GUARANTEED WITHIN",Vector2(270,722),18,Color("fff4aa"),false)
	text_center("Epic+ %d  ·  Legendary+ %d  ·  Prismatic %d"%[5-int(counters.epic),10-int(counters.legendary),20-int(counters.prismatic)],Vector2(270,747),17,PAPER,false)
	text_center("One shared guarantee, while eligible skins remain.",Vector2(270,772),15,PAPER,false)
	text_center("Base weights: 45 / 28 / 16 / 8 / 2.5 / 0.5",Vector2(270,804),15,PAPER,false)
	text_center("Odds adjust for ownership and guarantees.",Vector2(270,826),14,PAPER,false)
	draw_navigation("holes")

func draw_purchases()->void:
	contour_wallpaper()
	text_center("DIAMOND SHOP",Vector2(270,132),38,PAPER)
	gem_icon(Vector2(216,202),27)
	text_center("%d DIAMONDS"%game.gems,Vector2(317,213),17,PAPER,false)
	for i in PURCHASE_IDS.size():
		var id:String=PURCHASE_IDS[i]
		var product:Dictionary=game.commerce.product_info(id) if is_instance_valid(game.commerce) else {}
		var y:=236.0+i*156
		box(Rect2(40,y,460,126),PAPER,30,Color("ffe398"),3)
		gem_icon(Vector2(108,y+59),74)
		text_center("%d DIAMONDS"%int(product.get("diamonds",PURCHASE_DIAMONDS[i])),Vector2(322,y+47),26,INK,false)
		text_center(str(product.get("localized_price","UNAVAILABLE")),Vector2(330,y+89),23,Color("955abe"),false)
	text_center("UNAVAILABLE" if not is_instance_valid(game.commerce) or not game.commerce.purchase_available(PURCHASE_IDS[0]) else "Optional in-app purchases",Vector2(270,751),16,PAPER,false)
	if toast_time>0:text_wrapped(toast,Vector2(40,792),460,18,PAPER)
	draw_navigation("store")

func draw_result() -> void:
	draw_rect(canvas_bounds(),Color("2b3778",.70))
	box(Rect2(36,90,468,814),PAPER,36,Color.WHITE,3)
	text_center("TIME'S UP!" if game.phase in ["complete","timeout"] else "ROUND OVER",Vector2(270,158),38,INK,false)
	text_center("%d POINTS"%game.player.score,Vector2(270,222),34,INK,false)
	icon("coin",Vector2(173,263),40)
	text_center("+%d COINS"%game.round_coins,Vector2(298,275),29,Color("b77a13"),false)
	if game.can_boost_round_coins():draw_result_offer(RESULT_OFFER_TOP,"1.5× COINS")
	if game.can_extend_round():
		draw_result_offer(result_extension_y(),"+30 SECONDS")
	gem_icon(Vector2(248,688),28)
	text_center(str(game.gems),Vector2(288,698),20,Color("955abe"),false)
	if game.reward_video_pending():text_center("Finish & close the video",Vector2(270,318),16,SLATE,false)

func draw_result_offer(y:float,title:String)->void:
	box(Rect2(54,y,432,145),Color("eaf0fc"),22,Color("d3def0"),2)
	text_center(title,Vector2(270,y+37),26,INK,false)

func round_skill_lesson() -> Dictionary:
	# This is a drawn hint, so swiping through it still steers the player.
	# Keep it below map goals and notices, and above the movement tutorial.
	if not is_instance_valid(game.player) or get_tree().paused:return {}
	if game.phase!="intro" and (game.phase!="playing" or game.elapsed>=6.0):return {}
	var definition:Dictionary=game.skin_definition(game.player.skin_id)
	if definition.kind in ["cosmetic","none"]:return {}
	var trigger:="AUTO" if definition.kind=="bloom" else "TAP "+str(definition.skill_short)
	return {"rect":Rect2(36,372,468,146),"title":definition.skill_name,"effect":definition.skill_desc,
		"trigger":"%s · %.0fs cooldown"%[trigger,definition.cooldown]}

func draw_round_skill_lesson() -> void:
	var lesson:=round_skill_lesson()
	if lesson.is_empty():return
	box(lesson.rect,PAPER,26,Color("bbd8ff"),2)
	text_center(lesson.title,Vector2(270,405),25,INK,false)
	text_center(lesson.trigger,Vector2(270,431),17,SLATE,false)
	text_wrapped(lesson.effect,Vector2(52,455),436,17,INK)
	text_center("Keep swiping to move.",Vector2(270,501),14,SLATE,false)

func text_wrapped(message:String,at:Vector2,width:float,font_size:int,tint:Color) -> float:
	# All callers pass authored canvas coordinates and ignore the final baseline.
	# Map the paragraph origin once; line spacing, width and font stay unscaled.
	at=responsive_point(at)
	var line:=""
	var baseline:=at.y
	for word in message.split(" "):
		var candidate:=word if line.is_empty() else line+" "+word
		if not line.is_empty() and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
			draw_wrapped_line(line,Vector2(at.x,baseline),width,font_size,tint)
			baseline+=font_size+5
			line=word
		else:line=candidate
	draw_wrapped_line(line,Vector2(at.x,baseline),width,font_size,tint)
	return baseline

func draw_wrapped_line(message:String,at:Vector2,width:float,font_size:int,tint:Color)->void:
	draw_string(font,at,message,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,tint)

func draw_holes_menu() -> void:
	# One continuous low-to-high collection. Only on-screen cards own models.
	box(Rect2(26,27,144,50),Color("415792"),14,Color("a5c8f1"),2)
	icon("coin",Vector2(49,52),45)
	text_center(str(game.coins),Vector2(115,63),26,PAPER)
	text_center("HOLES",Vector2(270,110),42,PAPER)
	text_center("%d / %d COLLECTED · LOW TO HIGH"%[game.unlocked_skin_count("collection"),skin_order.size()],Vector2(270,144),18,PAPER,false)
	# A slim scrollbar signals that the collection continues below the fold.
	var track:=Rect2(523,168,4,452)
	box(track,Color("4454a5"),2,Color.TRANSPARENT,0)
	var thumb_height:=maxf(36,track.size.y*skin_list.size.y/skin_content_height)
	box(Rect2(track.position+Vector2(0,(track.size.y-thumb_height)*skin_scroll/maxf(1,max_skin_scroll())),Vector2(4,thumb_height)),Color("e5e9ff"),2,Color.TRANSPARENT,0)
	text_center("SCROLL TO DISCOVER",Vector2(270,635),12,PAPER,false)
	var detail:Dictionary=game.skin_definition(preview_skin_id)
	box(Rect2(20,648,500,96),PAPER,20,Color.WHITE,2)
	text_center(detail.name,Vector2(270,673),fitted_font_size(detail.name,468,22,16),INK,false)
	text_center(skin_trigger_text(),Vector2(270,694),15,Color("526b9d"),false)
	text_wrapped(skin_detail_text(),Vector2(36,718),468,16,INK)
	var group:=active_skin_group()
	var complete:bool=game.locked_skin_ids(group).is_empty()
	var price:int=game.skin_unlock_price(group)
	var affordable:bool=game.coins>=price
	var color:=Color("54c532") if affordable and not complete else Color("849cb2")
	box(Rect2(90,757,360,81),color,19,Color("bdf978") if affordable and not complete else Color("d1dfec"),3)
	text_center("VIEW RESULT" if not game.pending_skin_case().is_empty() else "COLLECTION COMPLETE" if complete else "OPEN CASE",Vector2(270,791),24 if complete else 28,PAPER)
	if not complete:
		icon("coin",Vector2(238,818),30)
		text_center(str(price),Vector2(288,828),24,PAPER)
	else:icon("check",Vector2(270,818),29)
	if toast_time>0:
		box(Rect2(99,97,342,66),Color("344889"),20,Color("fff6a8"),2)
		text_wrapped(toast,Vector2(111,125),318,16,PAPER)
	draw_navigation("holes")

func fitted_font_size(message:String,width:float,preferred:int,minimum:int)->int:
	var result:=preferred
	while result>minimum and font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,result).x>width:result-=1
	return result

func draw_skin_caption(definition:Dictionary,rect:Rect2)->void:
	if int(definition.get("variant_index",0))==0:
		text_center(definition.name,rect.position+Vector2(80,129),fitted_font_size(definition.name,140,18,13),INK,false,skin_list)
		return
	var family:Dictionary=game.skin_definition(str(definition.get("model_id",definition.id)))
	var base_name:String=str(family.name)
	var palette_name:String=str(definition.get("palette",{}).get("name",""))
	var base_size:=fitted_font_size(base_name,140,14,11)
	var palette_size:=fitted_font_size(palette_name,140,12,10)
	# The image keeps its full 144x106 render footprint. Two concise identities
	# occupy the whitespace below its visible silhouette and above the badge.
	var palette_baseline:float=136.0-font.get_descent(palette_size)
	var base_baseline:float=palette_baseline-font.get_ascent(palette_size)-1.0-font.get_descent(base_size)
	text_center(base_name,rect.position+Vector2(80,base_baseline),base_size,INK,false,skin_list)
	text_center(palette_name,rect.position+Vector2(80,palette_baseline),palette_size,Color("44536c"),false,skin_list)

func draw_skin_collection()->void:
	for tier in skin_tiers:
		var y:float=tier.y-skin_scroll
		if y< -36 or y>skin_list.size.y:continue
		var tint:Color=Rarity.data(str(tier.rarity)).color
		text_center("TIER %d · %s"%[int(tier.rank)+1,str(tier.rarity).to_upper()],Vector2(153,y+24),20,PAPER,true,skin_list)
		skin_list.draw_line(Vector2(310,y+17),Vector2(484,y+17),Color(tint,.65),2,true)
	var ids:=visible_skin_ids()
	for index in ids.size():
		var rect:=slot_rect(index);rect.position-=skin_list.position
		var definition:Dictionary=game.skin_definition(ids[index])
		var owned:bool=game.skin_unlocked(ids[index])
		var equipped:bool=game.selected_skin_id==definition.id
		var selected:bool=preview_skin_id==definition.id
		var rarity:Dictionary=Rarity.data(str(definition.rarity))
		box(rect,Color("c4f7b0") if equipped else Color("d7e1ee") if owned else Color("aebacf"),17,Color("f5ff8d") if equipped else Color("fff8bf") if selected else rarity.color,4 if equipped or selected else 3,skin_list)
		draw_skin_caption(definition,rect)
		draw_rarity_badge(str(definition.rarity),Rect2(rect.position+Vector2(8,137),Vector2(144,24)),skin_list)
		icon("check" if equipped else "lock" if not owned else "skins",rect.position+Vector2(23,149),19,1.0,skin_list)

func draw_game_hud() -> void:
	box(Rect2(186,24,168,56),PAPER,28,Color.WHITE,3)
	icon("clock",Vector2(207,51),48)
	var seconds:=int(ceil(game.remaining))
	text_center("%02d:%02d"%[seconds/60,seconds%60],Vector2(285,64),30,Color("e25a64") if seconds<=30 else INK,false)
	box(Rect2(151,94,238,52),Color("5889d8",.96),24,Color("c6eaff"),2)
	text_center("%d POINTS"%game.player.score,Vector2(270,117),23,PAPER)
	text_center("+%d COINS"%game.score_coin_reward(game.player.score),Vector2(270,137),14,Color("fff4aa"),false)
	box(Rect2(20,24,116,56),Color("5889d8",.96),28,Color("c6eaff"),2)
	icon("trophy",Vector2(45,51),45)
	text_center(str(game.kills),Vector2(90,64),29,PAPER)
	if game.phase=="playing":
		box(Rect2(456,20,64,64),Color("6996e7"),28,Color("d7eaff"),2)
		icon("pause",Vector2(488,52),42)
	# Food counts remain available in QA, but they are not win requirements.
	if game.phase!="playing":return
	draw_train_hint()
	var origin:=Vector2(270,801)
	var knob:=Vector2.ZERO
	if game.player.touch_index>=0:
		origin=canvas_point(game.player.touch_origin);knob=game.player.joystick.limit_length()*43
	elif game.player.dragged:
		origin=canvas_point(game.player.mouse_origin);knob=((get_viewport().get_mouse_position()-game.player.mouse_origin)/80).limit_length()*43
	if game.player.touch_index>=0 or game.player.dragged:
		draw_circle(origin,62,Color(1,1,1,.12))
		draw_arc(origin,62,0,TAU,64,Color(1,1,1,.42),3,true)
		draw_circle(origin+knob,25,Color(1,1,1,.7))
	var boost:Dictionary=boost_button_state()
	var pulse_at:=Vector2(466,845)
	var boost_color:=Color("ff7850") if boost.phase=="active" else Color("ffa51c") if boost.phase=="ready" else Color("739ce8")
	box(Rect2(pulse_at-Vector2(45,45),Vector2(90,90)),boost_color,45,Color("ffecaa") if boost.phase in ["active","ready"] else Color("d7eaff"),3)
	draw_arc(responsive_point(pulse_at),38,-PI/2,-PI/2+TAU*maxf(.001,float(boost.ratio)),48,Color("fff7b6"),4,true)
	icon("boost",pulse_at-Vector2(0,7),53)
	text_center(boost.text,pulse_at+Vector2(0,29),18,PAPER)
	text_center(boost.caption,pulse_at+Vector2(0,65),16,PAPER)
	var skin:Dictionary=game.skin_definition(game.player.skin_id)
	if skin.kind!="cosmetic":
		var skill_at:=Vector2(466,725)
		box(Rect2(skill_at-Vector2(43,43),Vector2(86,86)),Color("58c898") if game.player.skin_cooldown<=0 else Color("899ed8"),43,Color("d2ffea"),3)
		text_center(skin.skill_short,skill_at+Vector2(0,-2),16,PAPER)
		var state:="AUTO" if skin.kind=="bloom" else "GO!" if game.player.skin_cooldown<=0 else "%.1fs"%game.player.skin_cooldown
		text_center(state,skill_at+Vector2(0,23),19,PAPER)
		if float(skin.cooldown)>0.0:
			var ready:float=1.0-clampf(game.player.skin_cooldown/float(skin.cooldown),0,1)
			draw_arc(responsive_point(skill_at),35,-PI/2,-PI/2+TAU*maxf(.001,ready),48,Color("97ffd0"),3,true)
	if game.player.pulse_time>0.0:
		var pulse_screen:Vector2=canvas_point(game.camera.unproject_position(game.player.global_position+Vector3.UP*.2))
		var pulse_radius:float=minf(190.0,50.0+game.player.radius*14.0)
		draw_arc(pulse_screen,pulse_radius,0,TAU,48,Color("a9d8b5",.70),5,true)
		draw_arc(pulse_screen,pulse_radius+8,-PI/2,-PI/2+TAU*(game.player.pulse_time/.72),32,RUST,.95*8,true)
	var notice_y:=253.0
	if game.notice_time>0:
		box(Rect2(87,notice_y,366,46),Color("ffc04b"),23,Color.WHITE,3)
		text_center(game.notice,Vector2(270,notice_y+32),23,INK,false)
	elif game.swallow_hint!="":
		box(Rect2(140,notice_y,260,45),Color("fff9df"),22,Color.WHITE,3)
		text_center(game.swallow_hint,Vector2(270,notice_y+30),18,INK,false)

func draw_train_hint()->void:
	if game.train_controller==null or not is_instance_valid(game.player) or not game.player.active:return
	var nearest:Node3D
	var distance:=INF
	for car in game.train_controller.cars:
		if not is_instance_valid(car) or car.consumed or car.global_position.y< -1.0:continue
		var gap:float=car.global_position.distance_to(game.player.global_position)
		if gap<distance:nearest=car;distance=gap
	if nearest==null or distance<18.0:return
	var offset:Vector3=nearest.global_position-game.player.global_position
	var right:Vector3=game.camera.global_basis.x
	var back:Vector3=game.camera.global_basis.z
	var direction:=Vector2(offset.dot(right),offset.dot(back)).normalized()
	var center:=responsive_point(Vector2(157,179))
	var side:=Vector2(-direction.y,direction.x)
	box(Rect2(135,159,270,40),Color("fff4d7",.94),20,Color.WHITE,2)
	draw_line(center-direction*8,center+direction*8,INK,3,true)
	draw_polyline(PackedVector2Array([center+direction*2+side*6,center+direction*8,center+direction*2-side*6]),INK,3,true)
	var label:="SUSHI EXPRESS" if game.selected_map=="food" else "CITY TRAM"
	text_center("%s · %dm"%[label,int(round(distance))],Vector2(283,185),17,INK,false)

func draw_food_order() -> void:
	var amounts:=food_order_counts()
	box(Rect2(20,163,500,110),PAPER,30,Color.WHITE,3)
	for i in 3:
		var x:=26.0+i*166
		if i>0:draw_line(Vector2(x-2,178),Vector2(x-2,217),Color("d6e5f6"),2,true)
		var done:bool=amounts[i]>=[10,4,1][i]
		var bounce:float=1.0+sin(float(goal_pop[i])/.32*PI)*.13
		icon(["treats","donut","cake"][i],Vector2(x+33,194),57*bounce)
		text_center("%d/%d"%[amounts[i],[10,4,1][i]],Vector2(x+109,205),26,Color("268958") if done else INK,false)
		if done:icon("check",Vector2(x+145,178),22)

	var progress:Dictionary=game.food_city_progress()
	text_center("CITY %d/12 · LANDMARK %d/1 · HEAP %d/1"%[mini(12,progress.buildings),mini(1,progress.landmarks),mini(1,progress.heaps)],Vector2(270,244),17,INK,false)
	if is_instance_valid(game.food_guide):
		var destination:Vector2=canvas_point(game.camera.unproject_position(game.food_guide.global_position))
		var direction:Vector2=(destination-Vector2(270,480)).normalized()
		var center:=Vector2(50,260)
		draw_line(center-direction*7,center+direction*7,Color("268958"),3,true)
		draw_colored_polygon(PackedVector2Array([center+direction*11,center+direction.rotated(2.4)*7,center+direction.rotated(-2.4)*7]),Color("268958"))
		text_center("FOLLOW FOR CITY GOALS",Vector2(285,263),13,Color("268958"),false)

func food_order_counts() -> Array:
	return [mini(10,game.small_food_collected()),mini(4,int(game.food_collected.get("donut",0))),mini(1,int(game.food_collected.get("cake",0)))]

func sync_hero_preview()->void:
	if not is_instance_valid(hero) or not is_instance_valid(hero_view):return
	# Screenshot cards replace the continuously rendered miniature.
	hero.visible=false
	hero_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if hero.visible else SubViewport.UPDATE_DISABLED
	if is_instance_valid(hero_models):hero_models.set_process(hero.visible)

func update_map_preview()->void:
	if is_instance_valid(map_carousel):
		map_carousel.focus_map(game.selected_map,true)
		map_carousel.layout_photos()

	for child in hero_view.get_children():
		if child is WorldEnvironment:
			if game.selected_map in ["toys","frost"]:FairytaleLighting.environment(child.environment)
			else:
				FairytaleLighting.reset_environment(child.environment)
				child.environment.ambient_light_energy=.48 if game.selected_map=="food" else .8
		if child is DirectionalLight3D:
			if game.selected_map in ["toys","frost"]:FairytaleLighting.sun(child)
			else:
				child.light_color=Color.WHITE
				child.light_energy=.9
				child.shadow_opacity=1.0
		if child is Camera3D:
			child.size=14.0 if game.selected_map in ["toys","frost"] else 21.0
			child.look_at(Vector3(0,1.9 if game.selected_map=="frost" else (1.6 if game.selected_map=="toys" else 4.0),0))
	if is_instance_valid(hero_models):
		hero_models.set_process(false)
		hero_view.remove_child(hero_models)
		hero_models.queue_free()
	hero_models=FrostPreview.new() if game.selected_map=="frost" else (ToyPreview.new() if game.selected_map=="toys" else (FoodPreview.new() if game.selected_map=="food" else Art.new()))
	hero_models.name="MapMiniature"
	hero_view.add_child(hero_models)
	hero_models.build_preview()
	sync_hero_preview()

func cycle_map() -> void:
	if is_instance_valid(map_carousel):map_carousel.step(1)

func skin_card_render_size() -> Vector2i:
	# Stretch maps design coordinates to the viewport's backing pixels, including
	# high-DPI window/canvas sizing. Multiplying browser DPR again would double it.
	var pixels:=get_viewport().get_stretch_transform()*get_global_transform_with_canvas()
	var density:=clampf(maxf(pixels.x.length(),pixels.y.length()),1.0,SKIN_CARD_MAX_SCALE)
	return Vector2i(ceili(SKIN_CARD_SIZE.x*density),ceili(SKIN_CARD_SIZE.y*density))

func refresh_card_render_sizes() -> void:
	if skin_cards.is_empty():return
	var desired:=skin_card_render_size()
	var changed:=false
	for view in skin_cards:
		if view.size!=desired:
			view.size=desired
			changed=true
	# Cached cards need one fresh frame after a size change. An unchanged size
	# must not wake their render targets or restart any model's animation clock.
	if changed:focus_card_previews()

func make_card_preview(id:String,rect:Rect2) -> void:
	# Only a visible focused card animates; all other visible models stay cached.
	var view:=SubViewport.new()
	view.size=skin_card_render_size();view.transparent_bg=true;view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(view);skin_cards.append(view);card_skin_ids.append(id)
	# Each card owns an isolated world, so it cannot inherit the map's light.
	# Share the inexpensive ambient resource and light only these tiny cached
	# scenes; unshaded basic skins retain their authored solid colors.
	if card_environment==null:
		card_environment=Environment.new()
		card_environment.background_mode=Environment.BG_CLEAR_COLOR
		card_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		card_environment.ambient_light_color=Color("dce8ff")
		card_environment.ambient_light_energy=.65
	var environment:=WorldEnvironment.new()
	environment.environment=card_environment
	view.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-24,0)
	light.light_color=Color("fff2df");light.light_energy=1.1
	light.shadow_enabled=false
	view.add_child(light)
	var model:=SkinVisual.new();view.add_child(model)
	model.build(game.skin_definition(id),true);model._process(.65);model.set_process(false)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	# Taller cards have a narrower aspect ratio; preserve the wide water/plasma
	# silhouettes rather than cropping them with the previous 2.2 m framing.
	camera.size=3.1;view.add_child(camera);camera.position=Vector3(0,6.6,8)
	model.frame_preview(camera);camera.current=true
	var texture:=TextureRect.new()
	texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture.texture=view.get_texture()
	texture.position=rect.position-skin_list.position+Vector2(8,4);texture.size=Vector2(SKIN_CARD_SIZE)
	texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	skin_list.add_child(texture);card_textures.append(texture)
