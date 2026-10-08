extends Control
## Rounded toy-like interface with generous touch targets and candy colors.
## Every graphic here is drawn locally; the miniature and skin preview use
## authored Godot geometry rather than reference assets.
const Art=preload("res://fidelity/art.gd")
const FoodPreview=preload("res://fidelity/food_preview.gd")
const SkinVisual=preload("res://fidelity/skin_visual.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const MapCatalog=preload("res://fidelity/map_catalog.gd")
const PURCHASE_IDS:=["sink_city.coins_320","sink_city.coins_2000","sink_city.coins_9600"]
var game:Node3D
var font:Font
var buttons:Array[Button]=[]
var hero:TextureRect
var hero_models:Node3D
var hero_view:SubViewport
var skin_view:SubViewport
var skin_texture:TextureRect
var skin_preview:Node3D
var skin_preview_void:MeshInstance3D
var skin_preview_ring:MeshInstance3D
var skin_cards:Array[SubViewport]=[]
var card_textures:Array[TextureRect]=[]
var animation:=0.0
var toast:=""
var toast_time:=0.0
var menu_screen:="home"
var holes_tab:="classic"
var preview_skin_id:="core_shell"
var skin_page:=0
var card_skin_ids:Array[String]=[]
var page_swipe_origin:=Vector2.ZERO
var page_swipe_finger:=-1
var unlock_feedback_time:=0.0
var icons:Dictionary={}
var panel_styles:Dictionary={}
var goal_pop:=[0.0,0.0,0.0]
var last_goal_counts:=[0,0,0]
var displayed_phase:=""
const ICON_NAMES:=["coin","trophy","boost","check","lock","pause","back","play","clock","donut","cake","treats","skins","city","food-map"]
const MAP_CARD_RECTS:=[Rect2(24,556,238,130),Rect2(278,556,238,130)]
const CLASSIC_SLOT_COUNT:=27
const SPECIAL_SLOT_COUNT:=17
const PAGE_SIZE:=6
const SKIN_CARD_SIZE:=Vector2i(144,106)
const SKIN_CARD_MAX_SCALE:=3.0
const COIN_EARNING_RULE:="10 points = 1 coin · Finish with points: +20"
const INK:=Color("263467")
const PAPER:=Color("fffdf7")
const RUST:=Color("ffae12")
const OCHRE:=Color("fff080")
const MINT:=Color("cafffb")
const MOSS:=Color("56ccff")
const SLATE:=Color("3771ce")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	var bold:=FontVariation.new()
	bold.base_font=load("res://assets/fonts/Fredoka.ttf")
	bold.variation_opentype={"wght":650.0}
	bold.variation_embolden=0.65
	font=bold
	for id in ICON_NAMES:icons[id]=load("res://assets/ui/"+id+".svg")
	make_hero()
	make_skin_preview()
	refresh()

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
	hero.position=Vector2(-8,188)
	hero.size=Vector2(556,296)
	hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hero)
	# Lighting and visibility must already exist when a saved food selection
	# builds its first miniature, just as when the map card is selected later.
	update_map_preview()

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
	skin_preview_ring=skin_preview.main_ring
	skin_preview_void=skin_preview.mouth

func box(rect:Rect2,color:Color,radius:=24,border:=Color("ffffff"),stroke:=2) -> void:
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
	draw_style_box(style,rect)
	if rect.size.y>=44:
		draw_line(rect.position+Vector2(corner+5,7),rect.position+Vector2(rect.size.x-corner-5,7),Color(1,1,1,.20),3,true)

func icon(id:String,at:Vector2,size_:float=48.0,alpha:float=1.0) -> void:
	if icons.has(id):draw_texture_rect(icons[id],Rect2(at-Vector2.ONE*size_*.5,Vector2.ONE*size_),false,Color(1,1,1,alpha))

func text_center(message:String,at:Vector2,font_size:int,tint:=Color.WHITE,outline:=true) -> void:
	var width:=font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var pos:=at-Vector2(width/2,0)
	if outline:draw_string_outline(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("273766"))
	draw_string(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func button(rect:Rect2,title:String,callback:Callable,tint:=Color("ffa51b")) -> Button:
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

func hotspot(id:String,rect:Rect2,callback:Callable) -> Button:
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

func tab_skin_ids() -> Array[String]:
	return game.skin_ids("foundation" if holes_tab=="classic" else "resonance")

func slot_rect(index:int) -> Rect2:
	var local_index:=index%PAGE_SIZE
	return Rect2(20+(local_index%3)*170,202+(local_index/3)*172,160,164)

func visible_skin_ids()->Array[String]:
	var ids:=tab_skin_ids()
	return ids.slice(skin_page*PAGE_SIZE,mini(ids.size(),(skin_page+1)*PAGE_SIZE))

func page_count()->int:
	return maxi(1,int(ceil(float(tab_skin_ids().size())/PAGE_SIZE)))

func change_skin_page(step:int)->void:
	skin_page=clampi(skin_page+step,0,page_count()-1)
	var visible_ids:=visible_skin_ids()
	if not visible_ids.has(preview_skin_id):preview_skin_id=visible_ids[0]
	toast_time=0
	refresh()

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

func slot_hotspot(index:int,rect:Rect2,skin_id:String) -> void:
	var id:="hole-slot-%s-%02d"%[holes_tab,index]
	hotspot(id,rect,Callable(self,"select_hole_slot").bind(skin_id))

func select_hole_slot(skin_id:String) -> void:
	preview_skin_id=skin_id
	apply_skin_preview(skin_id)
	var definition:Dictionary=game.skin_definition(skin_id)
	if not game.skin_unlocked(skin_id):
		toast="Use UNLOCK RANDOM to get new skins"
		toast_time=1.5
	else:
		var equipped:bool=game.select_skin(skin_id)
		toast="%s EQUIPPED"%definition.name if equipped else "Could not save. Try again."
		toast_time=1.5
	focus_card_previews()
	queue_redraw()

func open_holes() -> void:
	menu_screen="holes"
	holes_tab="special" if game.skin_definition(game.selected_skin_id).group=="resonance" else "classic"
	var ids:=tab_skin_ids()
	preview_skin_id=game.selected_skin_id
	skin_page=maxi(0,ids.find(preview_skin_id))/PAGE_SIZE
	toast_time=0
	refresh()

func choose_holes_tab(tab:String) -> void:
	if tab!="classic" and tab!="special":return
	holes_tab=tab
	var ids:=tab_skin_ids()
	preview_skin_id=game.selected_skin_id if ids.has(game.selected_skin_id) else ids[0]
	skin_page=maxi(0,ids.find(preview_skin_id))/PAGE_SIZE
	toast_time=0
	refresh()

func close_menu() -> void:
	menu_screen="home"
	refresh()

func refresh() -> void:
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
	for texture in card_textures:texture.queue_free()
	for view in skin_cards:
		view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		for child in view.get_children():
			if child is SkinVisual:child.set_process(false)
		view.queue_free()
	card_textures.clear();skin_cards.clear();card_skin_ids.clear()
	sync_hero_preview()
	if is_instance_valid(skin_texture):
		skin_texture.visible=false # The reference collection uses card previews, without a large detail panel.
		skin_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if skin_texture.visible else SubViewport.UPDATE_DISABLED
		apply_skin_preview(preview_skin_id)
		skin_preview.set_process(skin_texture.visible)
	if game.phase=="title" and menu_screen=="home":
		make_audio_controls(false)
		hotspot("all-maps",Rect2(24,486,492,64),open_maps)
		button(Rect2(86,724,368,82),"PLAY",game.start_level,Color("ffa51c"))
		make_navigation("home")
		hotspot("home-map-nav",MAP_CARD_RECTS[0],Callable(game,"select_map").bind("city")).tooltip_text="Sunny City"
		hotspot("home-food-nav",MAP_CARD_RECTS[1],Callable(game,"select_map").bind("food")).tooltip_text="Snack Garden"
	elif game.phase=="title" and menu_screen=="holes":
		button(Rect2(394,20,122,64),"RATES",open_rates,Color("748bea")).name="skin-rates"
		hotspot("holes-classic-tab",Rect2(24,126,238,64),Callable(self,"choose_holes_tab").bind("classic"))
		hotspot("holes-special-tab",Rect2(278,126,238,64),Callable(self,"choose_holes_tab").bind("special"))
		skin_page=clampi(skin_page,0,page_count()-1)
		var ids:=visible_skin_ids()
		for index in ids.size():
			make_card_preview(ids[index],slot_rect(index))
			slot_hotspot(skin_page*PAGE_SIZE+index,slot_rect(index),ids[index])
		focus_card_previews()
		hotspot("skins-previous",Rect2(20,552,72,64),Callable(self,"change_skin_page").bind(-1)).disabled=skin_page==0
		hotspot("skins-next",Rect2(448,552,72,64),Callable(self,"change_skin_page").bind(1)).disabled=skin_page>=page_count()-1
		var unlock:=hotspot("unlock-random",Rect2(90,757,360,81),request_unlock)
		unlock.disabled=game.locked_skin_ids(active_skin_group()).is_empty() or unlock_feedback_time>0
		unlock.tooltip_text="Spend coins to unlock one new skin from this tab"
		make_navigation("holes")
	elif game.phase=="title" and menu_screen=="store":
		hotspot("store-gift",Rect2(40,199,460,86),request_shop_gift)
		for i in game.COIN_PACKS.size():
			hotspot("store-pack-%d"%i,Rect2(40,324+i*122,460,96),Callable(self,"request_coin_pack").bind(i))
		button(Rect2(90,715,360,68),"COIN SHOP",open_purchases,Color("ffad2f")).name="coin-shop"
		make_navigation("store")
	elif game.phase=="title" and menu_screen=="maps":
		for i in MapCatalog.DEFS.size():
			var definition:Dictionary=MapCatalog.DEFS[i]
			hotspot("map-"+str(definition.id),map_row(i),Callable(self,"pick_map").bind(str(definition.id))).disabled=not definition.available
		make_navigation("maps")
	elif game.phase=="title" and menu_screen=="rates":
		button(Rect2(20,20,122,64),"BACK",close_rates,Color("748bea")).name="rates-back"
		make_navigation("holes")
	elif game.phase=="title" and menu_screen=="purchases":
		button(Rect2(20,20,122,64),"BACK",open_store,Color("748bea")).name="purchase-back"
		for i in PURCHASE_IDS.size():
			var available:bool=is_instance_valid(game.commerce) and game.commerce.purchase_available(PURCHASE_IDS[i])
			hotspot("purchase-%d"%i,Rect2(40,236+i*156,460,126),Callable(self,"request_purchase").bind(PURCHASE_IDS[i])).disabled=not available or not game.purchase_request.is_empty()
		make_navigation("store")
	elif game.phase in ["eaten","timeout","complete"]:
		var doubled:bool=game.round_receipt.get("doubled",false)
		var loading:bool=game.reward_video_pending()
		var available:bool=is_instance_valid(game.ads) and game.ads.validated_reward_available()
		var reward:=button(Rect2(90,616,360,68),"COINS DOUBLED!" if doubled else "LOADING VIDEO..." if loading else "WATCH VIDEO · 2X COINS",show_no_video,Color("59c592") if available else Color("889eb4"))
		reward.name="double-round-coins";reward.disabled=doubled or loading or not available or game.round_coins<=0
		button(Rect2(90,715,360,68),"PLAY AGAIN",game.start_level,Color("ffa51c"))
		button(Rect2(142,804,256,64),"HOME",game.back_home,Color("5f88e8"))
	elif get_tree().paused:
		make_audio_controls(true)
		button(Rect2(90,491,360,70),"KEEP PLAYING",game.toggle_pause,Color("49d08a"))
		button(Rect2(142,589,256,64),"HOME",game.back_home,Color("638be7"))
	elif game.phase=="playing":
		hotspot("pause-action",Rect2(456,20,64,64),game.toggle_pause).tooltip_text="Pause"
		if game.skin_definition(game.player.skin_id).kind!="cosmetic":
			hotspot("skin-action",Rect2(414,680,104,94),Callable(self,"request_skin_skill"))
		hotspot("pulse-action",Rect2(414,797,104,112),Callable(self,"request_pulse")).tooltip_text="Eat to charge your boost"
	queue_redraw()

func open_store()->void:
	menu_screen="store";toast_time=0;refresh()

func open_maps()->void:
	menu_screen="maps";toast_time=0;refresh()

func map_row(index:int)->Rect2:
	return Rect2(24,164+index*126,492,112)

func pick_map(id:String)->void:
	if not game.MAPS.has(id):return
	menu_screen="home"
	game.select_map(id)

func open_rates()->void:
	menu_screen="rates";toast_time=0;refresh()

func close_rates()->void:
	menu_screen="holes";toast_time=0;refresh()

func open_purchases()->void:
	menu_screen="purchases";toast_time=0;refresh()

func request_purchase(product_id:String)->void:
	var result:Dictionary=game.request_coin_purchase(product_id)
	toast=result.message;toast_time=3.0;refresh()

func make_audio_controls(in_pause:bool)->void:
	# 64 design pixels remain above 44 points at a 375-point phone width.
	var y:=681.0 if in_pause else 20.0
	var first:=Rect2(90,y,174,64) if in_pause else Rect2(166,y,112,64)
	var second:=Rect2(276,y,174,64) if in_pause else Rect2(286,y,98,64)
	var music_button:=button(first,"MUSIC ON" if game.music_enabled else "MUSIC OFF",game.toggle_music,Color("638be7"))
	music_button.name="audio-music"
	music_button.add_theme_font_size_override("font_size",21 if in_pause else 18)
	music_button.tooltip_text="Turn background music on or off"
	var sfx_button:=button(second,"SFX ON" if game.sfx_enabled else "SFX OFF",game.toggle_sfx,Color("638be7"))
	sfx_button.name="audio-sfx"
	sfx_button.add_theme_font_size_override("font_size",21 if in_pause else 18)
	sfx_button.tooltip_text="Turn collection and collision sounds on or off"

func request_shop_gift()->void:
	var result:Dictionary=game.claim_shop_gift()
	toast=result.message;toast_time=2.0;refresh()

func request_coin_pack(index:int)->void:
	var result:Dictionary=game.buy_coin_pack(index)
	toast=result.message;toast_time=2.0;refresh()

func make_navigation(active:String)->void:
	hotspot("store-nav",Rect2(20,854,116,74),open_store).disabled=active=="store"
	hotspot("holes-home",Rect2(148,854,116,74),close_menu).disabled=active=="home"
	hotspot("holes-nav",Rect2(276,854,116,74),open_holes).disabled=active=="holes"
	if active!="home":
		var play:=button(Rect2(404,854,116,74),"PLAY",game.start_level,Color("ffae1a"))
		play.add_theme_font_size_override("font_size",22);play.icon=null
	else:
		hotspot("home-play-dock",Rect2(404,854,116,74),game.start_level)

func draw_navigation(active:String)->void:
	draw_rect(Rect2(0,846,540,114),Color("374889"))
	for i in 3:
		var selected:bool=active==["store","home","holes"][i]
		var rect:=Rect2(20+i*128,854,116,74)
		box(rect,Color("a0e3ff") if selected else Color("6071b7"),16,Color.WHITE if selected else Color("a8baff"),2)
		icon(["coin","city","skins"][i],rect.position+Vector2(58,25),41)
		text_center(["STORE","HOME","HOLES"][i],rect.position+Vector2(58,62),17,INK if selected else PAPER,false)
	if active=="home":
		box(Rect2(404,854,116,74),Color("ffae1a"),16,Color("fff2bc"),2)
		icon("play",Vector2(462,879),31)
		text_center("PLAY",Vector2(462,916),17,PAPER,false)
	text_center(COIN_EARNING_RULE,Vector2(270,949),14,PAPER,false)

func gem_icon(at:Vector2,size_:float)->void:
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
	text_center("Earn gems. Choose more holes.",Vector2(270,165),19,PAPER,false)
	var available:bool=game.shop_gift_claimed_stage<game.stage
	box(Rect2(40,199,460,86),Color("69bf66") if available else Color("879bb6"),25,Color("e2ffe3"),3)
	gem_icon(Vector2(85,241),45)
	text_center("FREE 5 GEMS" if available else "GIFT CLAIMED",Vector2(299,235),28,PAPER)
	text_center("One gift per completed run" if available else "Finish a timed run for the next gift",Vector2(299,263),16,PAPER,false)
	for i in game.COIN_PACKS.size():
		var offer:Dictionary=game.COIN_PACKS[i]
		var y:float=324.0+int(i)*122
		box(Rect2(40,y,460,96),PAPER,26,Color.WHITE,2)
		icon("coin",Vector2(89,y+47),64)
		text_center("%d COINS"%int(offer.coins),Vector2(252,y+38),28,INK,false)
		gem_icon(Vector2(210,y+66),25)
		text_center("%d GEMS"%int(offer.gems),Vector2(291,y+76),22,Color("955abe"),false)
		icon("check" if game.gems>=int(offer.gems) else "lock",Vector2(459,y+48),32)
	text_center("Earn gems from runs. Trade gems for coins.",Vector2(270,701),17,PAPER,false)
	if toast_time>0:
		text_center(toast,Vector2(270,824),17,PAPER,false)
	draw_navigation("store")

func active_skin_group()->String:
	return "foundation" if holes_tab=="classic" else "resonance"

func request_unlock()->void:
	if unlock_feedback_time>0:return
	var result:Dictionary=game.unlock_random_skin(active_skin_group())
	if result.ok:
		preview_skin_id=result.id
		skin_page=maxi(0,tab_skin_ids().find(preview_skin_id))/PAGE_SIZE
		unlock_feedback_time=1.0
		toast="%s UNLOCKED!"%game.skin_definition(result.id).name
		apply_skin_preview(result.id)
	else:toast=result.message
	toast_time=2.5
	refresh()

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
		toast="Eat to charge your boost"
		toast_time=1.3

func show_no_gems() -> void:
	toast="Not enough gems"
	toast_time=2.0

func show_no_video() -> void:
	var result:Dictionary=game.request_round_double()
	toast=result.message;toast_time=2.0;refresh()

func _process(delta:float) -> void:
	animation+=delta
	if game.phase=="title" and menu_screen=="holes":refresh_card_render_sizes()
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
	if game.phase=="title" and menu_screen=="holes":
		if event is InputEventScreenTouch:
			if event.pressed and Rect2(20,202,500,336).has_point(event.position):
				page_swipe_finger=event.index;page_swipe_origin=event.position
			elif not event.pressed and event.index==page_swipe_finger:
				var difference:Vector2=event.position-page_swipe_origin
				page_swipe_finger=-1
				if absf(difference.y)>60 or absf(difference.x)>60:
					change_skin_page(1 if (difference.y if absf(difference.y)>absf(difference.x) else difference.x)<0 else -1)
					get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and Rect2(20,202,500,336).has_point(event.position):
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				change_skin_page(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
				get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if game.phase=="title" and menu_screen!="home":close_menu()
		else:game.toggle_pause()
		get_viewport().set_input_as_handled()

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
	for i in 24:
		var tint:=Color("7260de").lerp(Color("479de9"),float(i)/23.0)
		draw_rect(Rect2(0,i*40,540,41),tint)
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
	if game.phase=="title" and menu_screen=="maps":draw_maps();return
	if game.phase=="title" and menu_screen=="rates":draw_rates();return
	if game.phase=="title" and menu_screen=="purchases":draw_purchases();return
	if game.phase=="title" and menu_screen=="holes":
		draw_holes_menu()
		return
	if game.phase=="title" and menu_screen=="store":
		draw_store()
		return
	if game.phase=="title":
		contour_wallpaper()
		box(Rect2(24,26,130,50),PAPER,25,Color.WHITE,2)
		icon("trophy",Vector2(48,50),40)
		text_center("LVL %d"%game.stage,Vector2(108,59),21,INK,false)
		draw_wallet()
		text_center("SINK CITY",Vector2(270,155),66,Color("444295"))
		text_center("SINK CITY",Vector2(270,148),66,PAPER)
		text_center("A BIG LITTLE APPETITE",Vector2(270,183),16,Color("eeeaff"),false)
		draw_set_transform(Vector2(270,435),0,Vector2(1,.34))
		draw_circle(Vector2.ZERO,228,Color(1,1,1,.07))
		draw_arc(Vector2.ZERO,219,0,TAU,72,Color(1,1,1,.22),4,true)
		draw_set_transform(Vector2.ZERO)
		box(Rect2(24,486,492,64),Color("748bea"),28,Color("cbd8ff"),2)
		text_center("ALL MAPS · 2 / 5 OPEN",Vector2(270,527),24,PAPER)
		for i in 2:
			var rect:Rect2=MAP_CARD_RECTS[i]
			var active:bool=game.selected_map==["city","food"][i]
			box(rect,Color("f5fff5") if active else Color("d9e9ff"),26,Color("adffc8") if active else Color("f5f7ff"),3)
			icon(["city","food-map"][i],rect.position+Vector2(53,60),96)
			text_center(["SUNNY","SNACK"][i],rect.position+Vector2(160,45),23,INK,false)
			text_center(["CITY","GARDEN"][i],rect.position+Vector2(160,73),23,INK,false)
			if active:
				icon("check",rect.position+Vector2(124,103),24)
				text_center("SELECTED",rect.position+Vector2(176,109),12,Color("269a65"),false)
			else:text_center("TAP TO PICK",rect.position+Vector2(162,109),12,SLATE,false)
		draw_navigation("home")
		return
	if game.phase in ["intro","playing"]:
		draw_game_hud()
		if game.phase=="intro":
			var shade_top:=236.0
			draw_rect(Rect2(0,shade_top,540,960-shade_top),Color("354c89",.30))
			var points:=PackedVector2Array()
			for i in 65:
				var t:float=float(i)/64*TAU
				points.append(Vector2(270+63*cos(t),695+30*sin(2*t)))
			draw_polyline(points,PAPER,8,true)
			draw_circle(Vector2(270+63*cos(animation*2),695+30*sin(animation*4)),15,OCHRE)
			text_center("SWIPE TO EAT",Vector2(270,782),32,PAPER)
			text_center("4 minutes. Eat everything. Earn more coins!",Vector2(270,817),19,PAPER,false)
		draw_round_skill_lesson()
	elif game.phase in ["eaten","complete","timeout"]:draw_result()
	if get_tree().paused:
		draw_rect(Rect2(0,0,540,960),Color("25356f",.68))
		box(Rect2(54,255,432,520),PAPER,40,Color.WHITE,3)
		box(Rect2(222,290,96,88),Color("8981e9"),36,Color("cbc7ff"),3)
		icon("pause",Vector2(270,334),66)
		text_center("TAKE A BREAK",Vector2(270,428),36,INK,false)
		text_center("Your city can wait.",Vector2(270,460),19,SLATE,false)
	if toast_time>0:
		box(Rect2(65,303,410,50),PAPER,25,Color("bbd8ff"),2)
		text_center(toast,Vector2(270,336),18,INK,false)

func draw_wallet() -> void:
	box(Rect2(394,26,122,50),PAPER,25,Color.WHITE,2)
	icon("coin",Vector2(414,49),43)
	text_center(str(game.coins),Vector2(474,59),23,INK,false)

func draw_rarity_badge(rarity_id:String,rect:Rect2)->void:
	var rarity:Dictionary=Rarity.data(rarity_id)
	box(rect,rarity.color,12,Color.WHITE,.0)
	if rarity_id=="prismatic":
		for i in Rarity.RAINBOW_COLORS.size():
			draw_line(rect.position+Vector2(12+i*(rect.size.x-24)/6.0,rect.size.y-3),rect.position+Vector2(12+(i+1)*(rect.size.x-24)/6.0,rect.size.y-3),Rarity.RAINBOW_COLORS[i],3,true)
	text_center(str(rarity.name).to_upper(),rect.position+Vector2(rect.size.x*.5+8,17),12,PAPER,true)

func draw_map_symbol(id:String,at:Vector2)->void:
	if id=="animals":
		draw_circle(at+Vector2(0,10),20,Color("ffa94a"))
		for offset in [Vector2(-23,-13),Vector2(-8,-26),Vector2(10,-26),Vector2(25,-11)]:draw_circle(at+offset,9,Color("ffa94a"))
	elif id=="stars":
		star(at,34,Color("ffd25f"));star(at+Vector2(34,-26),9,PAPER)
	elif id=="toys":
		box(Rect2(at-Vector2(28,26),Vector2(56,56)),Color("ef83bf"),12,Color("fff1d3"),3)
		text_center("A",at+Vector2(0,17),40,PAPER,false)
	else:icon("city" if id=="city" else "food-map",at,94)

func draw_maps()->void:
	contour_wallpaper()
	text_center("CHOOSE YOUR WORLD",Vector2(270,106),34,PAPER)
	text_center("4 minutes · no score limit",Vector2(270,138),18,PAPER,false)
	for i in MapCatalog.DEFS.size():
		var definition:Dictionary=MapCatalog.DEFS[i]
		var rect:=map_row(i)
		var active:bool=game.selected_map==definition.id
		box(rect,PAPER if definition.available else Color("dce5fc"),26,Color("adffc8") if active else Color.WHITE,3)
		draw_map_symbol(str(definition.id),rect.position+Vector2(64,55))
		text_center(str(definition.name).to_upper(),rect.position+Vector2(300,35),24,INK,false)
		text_center(str(definition.description),rect.position+Vector2(300,59),15,SLATE,false)
		var status:="COMING SOON"
		if definition.available:status="BEST %d · %s"%[int(game.best_scores.get(definition.id,0)),"SELECTED" if active else "PLAY"]
		text_center(status,rect.position+Vector2(300,90),18,Color("209965") if definition.available else Color("8564bc"),false)
	draw_navigation("maps")

func draw_rates()->void:
	contour_wallpaper()
	text_center("SKIN CHANCES",Vector2(270,132),36,PAPER)
	text_center("CLASSIC" if holes_tab=="classic" else "SPECIAL",Vector2(270,162),18,PAPER,false)
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
	text_center("Draws per tab, while eligible skins remain.",Vector2(270,772),15,PAPER,false)
	text_center("Base weights: 45 / 28 / 16 / 8 / 2.5 / 0.5",Vector2(270,804),15,PAPER,false)
	text_center("Odds adjust for ownership and guarantees.",Vector2(270,826),14,PAPER,false)
	draw_navigation("holes")

func draw_purchases()->void:
	contour_wallpaper()
	text_center("COIN SHOP",Vector2(270,132),40,PAPER)
	text_center("More coins. More looks to collect.",Vector2(270,170),18,PAPER,false)
	for i in PURCHASE_IDS.size():
		var id:String=PURCHASE_IDS[i]
		var product:Dictionary=game.commerce.product_info(id) if is_instance_valid(game.commerce) else {}
		var y:=236.0+i*156
		box(Rect2(40,y,460,126),PAPER,30,Color("ffe398"),3)
		icon("coin",Vector2(108,y+59),84)
		text_center("%d COINS"%int(game.COIN_PACKS[i].coins),Vector2(330,y+47),31,INK,false)
		text_center(str(product.get("localized_price","COMING SOON")),Vector2(330,y+89),23,Color("b58022"),false)
	text_center("Purchases are not available on this platform yet." if not is_instance_valid(game.commerce) or not game.commerce.purchase_available(PURCHASE_IDS[0]) else "Purchases are confirmed securely by your app store.",Vector2(270,751),16,PAPER,false)
	if toast_time>0:text_wrapped(toast,Vector2(40,792),460,18,PAPER)
	draw_navigation("store")

func draw_result() -> void:
	draw_rect(Rect2(0,0,540,960),Color("2b3778",.70))
	box(Rect2(54,219,432,680),PAPER,40,Color.WHITE,3)
	text_center("TIME'S UP!",Vector2(270,285),39,INK,false)
	for i in 3:star(Vector2(204+i*66,332-12*(i%2)),23,Color("ffbe35"))
	icon("trophy",Vector2(270,413),109)
	text_center("%d POINTS"%game.player.score,Vector2(270,508),31,INK,false)
	text_center("SCORE +%d   FINISH +%d"%[game.round_score_coins,game.round_win_coins],Vector2(270,538),18,SLATE,false)
	icon("coin",Vector2(221,566),34)
	var doubled:bool=game.round_receipt.get("doubled",false)
	text_center("+%d COINS"%(game.round_coins*(2 if doubled else 1)),Vector2(300,576),23,Color("b77a13"),false)
	text_center(COIN_EARNING_RULE,Vector2(270,603),15,SLATE,false)
	var videos_available:bool=is_instance_valid(game.ads) and game.ads.validated_reward_available()
	text_center("Includes +%d video bonus"%game.round_coins if doubled else "Optional video · double this run's coins" if videos_available else "Videos are not available right now",Vector2(270,705),15,SLATE,false)

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
	var line:=""
	var baseline:=at.y
	for word in message.split(" "):
		var candidate:=word if line.is_empty() else line+" "+word
		if not line.is_empty() and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
			draw_string(font,Vector2(at.x,baseline),line,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,tint)
			baseline+=font_size+5
			line=word
		else:line=candidate
	draw_string(font,Vector2(at.x,baseline),line,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,tint)
	return baseline

func draw_holes_menu() -> void:
	# Match the reference collection hierarchy: balance, tabs, three-column
	# cards, one green coin unlock action, then the persistent bottom dock.
	for i in 24:
		draw_rect(Rect2(0,i*40,540,41),Color("666fd1").lerp(Color("559cdb"),float(i)/23.0))
	for i in 15:
		crossed_axes(Vector2(35+(i%3)*220,85+(i/3)*206))
	draw_rect(Rect2(0,0,540,960),Color("6976d4",.80))
	box(Rect2(26,27,144,50),Color("415792"),14,Color("a5c8f1"),2)
	icon("coin",Vector2(49,52),45)
	text_center(str(game.coins),Vector2(115,63),26,PAPER)
	text_center("HOLES",Vector2(270,110),42,PAPER)
	for i in 2:
		var active:bool=holes_tab==["classic","special"][i]
		var rect:=Rect2(24+i*254,126,238,64)
		box(rect,Color("e8edff") if active else Color("435184"),14,Color.WHITE if active else Color("8b9cd0"),3)
		var group:String=["foundation","resonance"][i]
		text_center("%s  %d/%d"%[["CLASSIC","SPECIAL"][i],game.unlocked_skin_count(group),game.skin_ids(group).size()],rect.position+Vector2(119,40),23,INK if active else PAPER,false)
	var ids:=visible_skin_ids()
	for index in ids.size():
		var rect:=slot_rect(index)
		var definition:Dictionary=game.skin_definition(ids[index])
		var owned:bool=game.skin_unlocked(ids[index])
		var equipped:bool=game.selected_skin_id==definition.id
		var selected:bool=preview_skin_id==definition.id
		var rarity:Dictionary=Rarity.data(str(definition.rarity))
		box(rect,Color("c4f7b0") if equipped else Color("d7e1ee") if owned else Color("aebacf"),17,Color("f5ff8d") if equipped else Color("fff8bf") if selected else rarity.color,4 if equipped or selected else 3)
		text_center(definition.name,rect.position+Vector2(80,129),18,INK,false)
		draw_rarity_badge(str(definition.rarity),Rect2(rect.position+Vector2(8,137),Vector2(144,24)))
		icon("check" if equipped else "lock" if not owned else "skins",rect.position+Vector2(23,149),19)
	for x in [20,448]:box(Rect2(x,552,72,64),Color("586daf"),20,Color("a8baff"),2)
	icon("back",Vector2(56,584),39)
	draw_set_transform(Vector2(484,584),PI)
	icon("back",Vector2.ZERO,39)
	draw_set_transform(Vector2.ZERO)
	text_center("%d / %d"%[skin_page+1,page_count()],Vector2(270,583),22,PAPER)
	text_center("SWIPE TO BROWSE",Vector2(270,605),12,PAPER,false)
	var detail:Dictionary=game.skin_definition(preview_skin_id)
	box(Rect2(20,626,500,118),PAPER,20,Color.WHITE,2)
	text_center(detail.name,Vector2(270,652),22,INK,false)
	text_center(skin_trigger_text(),Vector2(270,674),15,Color("526b9d"),false)
	text_wrapped(skin_detail_text(),Vector2(36,698),468,17,INK)
	var group:=active_skin_group()
	var complete:bool=game.locked_skin_ids(group).is_empty()
	var price:int=game.skin_unlock_price(group)
	var affordable:bool=game.coins>=price
	var color:=Color("54c532") if affordable and not complete else Color("849cb2")
	box(Rect2(90,757,360,81),color,19,Color("bdf978") if affordable and not complete else Color("d1dfec"),3)
	text_center("COLLECTION COMPLETE" if complete else "UNLOCK RANDOM",Vector2(270,791),24 if complete else 28,PAPER)
	if not complete:
		icon("coin",Vector2(238,818),30)
		text_center(str(price),Vector2(288,828),24,PAPER)
	else:icon("check",Vector2(270,818),29)
	if toast_time>0:
		box(Rect2(99,550,342,66),Color("344889"),20,Color("fff6a8"),2)
		text_wrapped(toast,Vector2(111,578),318,16,PAPER)
	draw_navigation("holes")

func draw_game_hud() -> void:
	box(Rect2(186,24,168,56),PAPER,28,Color.WHITE,3)
	icon("clock",Vector2(207,51),48)
	var seconds:=int(ceil(game.remaining))
	text_center("%02d:%02d"%[seconds/60,seconds%60],Vector2(285,64),30,Color("e25a64") if seconds<=30 else INK,false)
	box(Rect2(151,94,238,52),Color("5889d8",.96),24,Color("c6eaff"),2)
	text_center("%d POINTS"%game.player.score,Vector2(270,117),23,PAPER)
	text_center("%d COINS"%(maxi(0,game.player.score)/10),Vector2(270,137),14,Color("fff4aa"),false)
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
		origin=game.player.touch_origin;knob=game.player.joystick.limit_length()*43
	elif game.player.dragged:
		origin=game.player.mouse_origin;knob=((get_viewport().get_mouse_position()-origin)/80).limit_length()*43
	if game.player.touch_index>=0 or game.player.dragged:
		draw_circle(origin,62,Color(1,1,1,.12))
		draw_arc(origin,62,0,TAU,64,Color(1,1,1,.42),3,true)
		draw_circle(origin+knob,25,Color(1,1,1,.7))
	var pulse_ratio:float=clampf(game.player.pulse_charge/100.0,0,1)
	var pulse_at:=Vector2(466,845)
	box(Rect2(pulse_at-Vector2(45,45),Vector2(90,90)),Color("ffa51c") if pulse_ratio>=1 else Color("739ce8"),45,Color("ffecaa") if pulse_ratio>=1 else Color("d7eaff"),3)
	draw_arc(pulse_at,38,-PI/2,-PI/2+TAU*maxf(.001,pulse_ratio),48,Color("fff7b6"),4,true)
	icon("boost",pulse_at-Vector2(0,7),53)
	text_center("GO!" if pulse_ratio>=1 else "%d%%"%int(pulse_ratio*100),pulse_at+Vector2(0,29),18,PAPER)
	text_center("BOOST",pulse_at+Vector2(0,65),16,PAPER)
	var skin:Dictionary=game.skin_definition(game.player.skin_id)
	if skin.kind!="cosmetic":
		var skill_at:=Vector2(466,725)
		box(Rect2(skill_at-Vector2(43,43),Vector2(86,86)),Color("58c898") if game.player.skin_cooldown<=0 else Color("899ed8"),43,Color("d2ffea"),3)
		text_center(skin.skill_short,skill_at+Vector2(0,-2),16,PAPER)
		var state:="AUTO" if skin.kind=="bloom" else "GO!" if game.player.skin_cooldown<=0 else "%.1fs"%game.player.skin_cooldown
		text_center(state,skill_at+Vector2(0,23),19,PAPER)
		if float(skin.cooldown)>0.0:
			var ready:float=1.0-clampf(game.player.skin_cooldown/float(skin.cooldown),0,1)
			draw_arc(skill_at,35,-PI/2,-PI/2+TAU*maxf(.001,ready),48,Color("97ffd0"),3,true)
	if game.player.pulse_time>0.0:
		var pulse_screen:Vector2=game.camera.unproject_position(game.player.global_position+Vector3.UP*.2)
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
	var center:=Vector2(157,179)
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
		var destination:Vector2=game.camera.unproject_position(game.food_guide.global_position)
		var direction:Vector2=(destination-Vector2(270,480)).normalized()
		var center:=Vector2(50,260)
		draw_line(center-direction*7,center+direction*7,Color("268958"),3,true)
		draw_colored_polygon(PackedVector2Array([center+direction*11,center+direction.rotated(2.4)*7,center+direction.rotated(-2.4)*7]),Color("268958"))
		text_center("FOLLOW FOR CITY GOALS",Vector2(285,263),13,Color("268958"),false)

func food_order_counts() -> Array:
	return [mini(10,game.small_food_collected()),mini(4,int(game.food_collected.get("donut",0))),mini(1,int(game.food_collected.get("cake",0)))]

func sync_hero_preview()->void:
	if not is_instance_valid(hero) or not is_instance_valid(hero_view):return
	hero.visible=game.phase=="title" and menu_screen=="home"
	hero_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if hero.visible else SubViewport.UPDATE_DISABLED
	if is_instance_valid(hero_models):hero_models.set_process(hero.visible)

func update_map_preview()->void:
	for child in hero_view.get_children():
		if child is WorldEnvironment:child.environment.ambient_light_energy=.48 if game.selected_map=="food" else .8
	if is_instance_valid(hero_models):
		hero_models.set_process(false)
		hero_view.remove_child(hero_models)
		hero_models.queue_free()
	hero_models=FoodPreview.new() if game.selected_map=="food" else Art.new()
	hero_models.name="MapMiniature"
	hero_view.add_child(hero_models)
	hero_models.build_preview()
	sync_hero_preview()

func cycle_map() -> void:
	game.select_map("food" if game.selected_map=="city" else "city")

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
	# Only the focused card animates; the other five render once and stay cached.
	var view:=SubViewport.new()
	view.size=skin_card_render_size();view.transparent_bg=true;view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(view);skin_cards.append(view);card_skin_ids.append(id)
	var model:=SkinVisual.new();view.add_child(model)
	model.build(game.skin_definition(id),true);model._process(.65);model.set_process(false)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	# Taller cards have a narrower aspect ratio; preserve the wide water/plasma
	# silhouettes rather than cropping them with the previous 2.2 m framing.
	camera.size=3.1;view.add_child(camera);camera.position=Vector3(0,6.6,8)
	camera.look_at(Vector3(0,.14,0));camera.current=true
	var texture:=TextureRect.new()
	texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture.texture=view.get_texture()
	texture.position=rect.position+Vector2(8,4);texture.size=Vector2(SKIN_CARD_SIZE)
	texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(texture);card_textures.append(texture)
