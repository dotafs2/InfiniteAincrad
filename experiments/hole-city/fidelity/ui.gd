extends Control
## Original portrait signal dashboard with a readable one-finger control loop.
## Every graphic here is drawn locally; the miniature and skin preview use
## authored Godot geometry rather than reference assets.
const Art=preload("res://fidelity/art.gd")
const SkinVisual=preload("res://fidelity/skin_visual.gd")
var game:Node3D
var font:Font
var buttons:Array[Button]=[]
var hero:TextureRect
var hero_view:SubViewport
var skin_view:SubViewport
var skin_texture:TextureRect
var skin_preview:Node3D
var skin_preview_void:MeshInstance3D
var skin_preview_ring:MeshInstance3D
var animation:=0.0
var toast:=""
var toast_time:=0.0
var menu_screen:="home"
var holes_tab:="classic"
var preview_skin_id:="core_shell"
const CLASSIC_SLOT_COUNT:=5
const SPECIAL_SLOT_COUNT:=5
const INK:=Color("151633")
const PAPER:=Color("f7f8ff")
const RUST:=Color("ff8a2a")
const OCHRE:=Color("ffd166")
const MINT:=Color("b8d8ff")
const MOSS:=Color("7b72e7")
const SLATE:=Color("2e2d68")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	var bold:=FontVariation.new()
	bold.base_font=ThemeDB.fallback_font
	bold.variation_embolden=0.65
	font=bold
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
	var models:=Art.new()
	hero_view.add_child(models)
	models.build_preview()
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_CLEAR_COLOR
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("a9d8b5")
	env.ambient_light_energy=0.55
	envnode.environment=env
	hero_view.add_child(envnode)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-32,0)
	light.light_color=Color("e2a956")
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
	hero.position=Vector2(18,272)
	hero.size=Vector2(504,385)
	hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hero)

func make_skin_preview() -> void:
	skin_view=SubViewport.new()
	skin_view.size=Vector2i(492,186)
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
	skin_texture.position=Vector2(24,228)
	skin_texture.size=Vector2(492,186)
	skin_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	skin_texture.visible=false
	add_child(skin_texture)

func apply_skin_preview(id:String) -> void:
	if not is_instance_valid(skin_preview):return
	if skin_preview.skin_id!=id or not is_instance_valid(skin_preview.main_ring):
		skin_preview.build(game.skin_definition(id),true)
	skin_preview_ring=skin_preview.main_ring
	skin_preview_void=skin_preview.mouth

func box(rect:Rect2,color:Color,radius:=7,border:=Color("222a3b"),stroke:=2) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.border_color=border
	style.set_border_width_all(stroke)
	draw_style_box(style,rect)

func text_center(message:String,at:Vector2,font_size:int,tint:=Color.WHITE,outline:=true) -> void:
	var width:=font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var pos:=at-Vector2(width/2,0)
	if outline:draw_string_outline(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("303340"))
	draw_string(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func button(rect:Rect2,title:String,callback:Callable,tint:=Color("ffa51b")) -> Button:
	var b:=Button.new()
	b.position=rect.position
	b.size=rect.size
	b.text=title
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_font_override("font",font)
	var ink_text:=tint.a>0.1 and tint.r+tint.g+tint.b>1.65
	b.add_theme_color_override("font_color",INK if ink_text else PAPER)
	b.add_theme_color_override("font_hover_color",INK if ink_text else PAPER)
	b.add_theme_color_override("font_pressed_color",INK if ink_text else PAPER)
	b.add_theme_color_override("font_outline_color",Color(0,0,0,0.35))
	b.add_theme_constant_override("outline_size",2)
	for state in ["normal","hover","pressed"]:
		var s:=StyleBoxFlat.new()
		s.bg_color=tint.lightened(0.12) if state=="hover" else tint.darkened(0.12) if state=="pressed" else tint
		s.border_color=MINT if state=="hover" else OCHRE
		s.border_width_left=2
		s.border_width_top=2
		s.border_width_right=2
		s.border_width_bottom=5 if tint.a>0 else 0
		s.set_corner_radius_all(2)
		s.shadow_color=Color(0,0,0,0.32)
		s.shadow_size=4
		s.shadow_offset=Vector2(0,3)
		b.add_theme_stylebox_override(state,s)
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
		s.bg_color=Color(1,1,1,0.035) if state=="hover" else Color(0,0,0,0)
		s.set_corner_radius_all(8)
		b.add_theme_stylebox_override(state,s)
	b.pressed.connect(callback)
	add_child(b)
	buttons.append(b)
	return b

func tab_skin_ids() -> Array[String]:
	return game.skin_ids("foundation" if holes_tab=="classic" else "resonance")

func slot_rect(index:int) -> Rect2:
	# Three compact columns preserve the familiar library scan while leaving
	# room for a live 3D form preview below the cards.
	return Rect2(18+(index%3)*170,444+(index/3)*84,160,74)

func slot_hotspot(index:int,rect:Rect2,skin_id:String) -> void:
	var id:="hole-slot-%s-%02d"%[holes_tab,index]
	hotspot(id,rect,Callable(self,"select_hole_slot").bind(skin_id))

func select_hole_slot(skin_id:String) -> void:
	preview_skin_id=skin_id
	apply_skin_preview(skin_id)
	var definition:Dictionary=game.skin_definition(skin_id)
	if not game.skin_unlocked(skin_id):
		toast="UNLOCK AT %d SYNC"%int(definition.unlock)
		toast_time=1.5
	else:
		game.select_skin(skin_id)
		toast="%s EQUIPPED"%definition.name
		toast_time=1.5
	queue_redraw()

func open_holes() -> void:
	menu_screen="holes"
	holes_tab="classic"
	var ids:=tab_skin_ids()
	preview_skin_id=game.selected_skin_id if ids.has(game.selected_skin_id) else ids[0]
	refresh()

func choose_holes_tab(tab:String) -> void:
	if tab!="classic" and tab!="special":return
	holes_tab=tab
	var ids:=tab_skin_ids()
	preview_skin_id=game.selected_skin_id if ids.has(game.selected_skin_id) else ids[0]
	refresh()

func close_menu() -> void:
	menu_screen="home"
	refresh()

func refresh() -> void:
	for b in buttons:
		b.hide()
		# Refresh can be called from a pressed signal. Keep the emitting button
		# deferred-free, but release its name so the next menu can reuse it.
		b.name="_old-ui-%s"%b.get_instance_id()
		b.queue_free()
	buttons.clear()
	hero.visible=game.phase=="title" and menu_screen=="home"
	hero_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if hero.visible else SubViewport.UPDATE_DISABLED
	if is_instance_valid(skin_texture):
		skin_texture.visible=game.phase=="title" and menu_screen=="holes"
		skin_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if skin_texture.visible else SubViewport.UPDATE_DISABLED
		apply_skin_preview(preview_skin_id)
	if game.phase=="title" and menu_screen=="home":
		button(Rect2(72,735,396,74),"ENTER THE RIFT",game.start_level,RUST)
		hotspot("holes-nav",Rect2(24,850,492,88),open_holes)
	elif game.phase=="title" and menu_screen=="holes":
		hotspot("holes-home",Rect2(15,875,150,64),close_menu)
		hotspot("holes-classic-tab",Rect2(24,104,238,66),Callable(self,"choose_holes_tab").bind("classic"))
		hotspot("holes-special-tab",Rect2(278,104,238,66),Callable(self,"choose_holes_tab").bind("special"))
		var ids:=tab_skin_ids()
		for index in ids.size():slot_hotspot(index,slot_rect(index),ids[index])
	elif game.phase=="eaten":
		button(Rect2(68,630,188,60),"OPEN A BEACON",show_no_gems,OCHRE)
		button(Rect2(284,630,188,60),"WATCH SIGNAL",show_no_video,RUST)
		button(Rect2(128,730,284,54),"RETURN TO DOCK",game.back_home,Color(0,0,0,0))
	elif game.phase in ["timeout","complete"]:
		button(Rect2(70,620,400,68),"REDEPLOY",game.start_level,MINT)
		button(Rect2(116,710,308,58),"RETURN TO DOCK",game.back_home,Color("647b63"))
	elif get_tree().paused:
		button(Rect2(70,430,400,70),"RESUME SIGNAL",game.toggle_pause,MINT)
		button(Rect2(116,530,308,60),"RETURN TO DOCK",game.back_home,Color("647b63"))
	elif game.phase=="playing":
		button(Rect2(462,22,58,50),"||",game.toggle_pause,Color("283234"))
		hotspot("skin-action",Rect2(382,646,140,76),Callable(self,"request_skin_skill"))
		hotspot("pulse-action",Rect2(382,742,140,76),Callable(self,"request_pulse"))
	queue_redraw()

func request_skin_skill() -> void:
	if is_instance_valid(game.player) and game.player.trigger_skin_skill():
		queue_redraw()
		return
	if not is_instance_valid(game.player):return
	var definition:Dictionary=game.skin_definition(game.player.skin_id)
	if definition.kind=="bloom":toast="AUTO SKILL"
	elif definition.kind=="cosmetic":toast="CHROMA ONLY"
	elif game.player.skin_cooldown>0.0:toast="COOLDOWN %.1f"%game.player.skin_cooldown
	else:toast="SKILL UNAVAILABLE"
	toast_time=1.3
	queue_redraw()

func request_pulse() -> void:
	if is_instance_valid(game.player) and game.player.trigger_pulse():
		queue_redraw()
	else:
		toast="Charge the resonance ring"
		toast_time=1.3

func show_no_gems() -> void:
	toast="Not enough gems"
	toast_time=2.0

func show_no_video() -> void:
	if is_instance_valid(game.ads) and game.ads.show_rewarded():
		toast="Loading reward..."
	else:
		toast="No video available"
	toast_time=2.0

func _process(delta:float) -> void:
	animation+=delta
	toast_time=maxf(0,toast_time-delta)
	if is_instance_valid(skin_preview) and is_instance_valid(skin_texture) and skin_texture.visible:
		skin_preview.rotation.y+=delta*.20
	if game.phase=="title" or toast_time>0:queue_redraw()

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if game.phase=="title" and menu_screen=="holes":close_menu()
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
	# Broken contour lines and a quiet coordinate grid keep the field authored
	# without copying a recognizable third-party pattern.
	for i in 8:
		var y:=float(i*124)+fmod(animation*5.0,124.0)-20.0
		var pts:=PackedVector2Array()
		for x in range(-40,600,24):
			pts.append(Vector2(x,y+sin(float(x)*0.024+float(i))*10.0))
		draw_polyline(pts,Color("a4a5ff",0.20),1.5,true)
	for x in range(24,540,48):
		draw_line(Vector2(x,0),Vector2(x,960),Color("b8d8ff",0.07),1.0,true)
	for y in range(22,960,48):
		draw_line(Vector2(0,y),Vector2(540,y),Color("b8d8ff",0.07),1.0,true)

func signal_mark(at:Vector2,scale:=1.0) -> void:
	var r:=38.0*scale
	draw_arc(at,r,0,TAU,40,RUST,3,true)
	draw_arc(at,r-10*scale,0.3,TAU-0.3,36,MINT,2,true)
	draw_line(at-Vector2(r*0.7,0),at+Vector2(r*0.7,0),OCHRE,2,true)
	draw_line(at-Vector2(0,r*0.7),at+Vector2(0,r*0.7),OCHRE,2,true)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-2)*scale,at+Vector2(0,-15)*scale,at+Vector2(9,-2)*scale,at+Vector2(0,11)*scale]),PAPER)

func star(at:Vector2,radius:float,tint:Color) -> void:
	var vertices:=PackedVector2Array()
	for i in 10:
		var a:float=-PI/2+i*PI/5
		vertices.append(at+Vector2(cos(a),sin(a))*radius*(1.0 if i%2==0 else 0.43))
	draw_colored_polygon(vertices,tint)

func _draw() -> void:
	if font==null:return
	if game.phase=="title" and menu_screen=="holes":
		draw_holes_menu()
		return
	if game.phase=="title":
		draw_rect(Rect2(0,0,540,960),INK)
		draw_rect(Rect2(0,0,540,960),Color("24255b"))
		contour_wallpaper()
		# The signal mark and split title keep this composition distinct from the
		# reference while using a brighter battle-screen contrast.
		signal_mark(Vector2(270,104),1.18)
		text_center("SINK//FIELD",Vector2(270,190),35,PAPER)
		text_center("A CITY BUILT TO FALL",Vector2(270,219),13,MINT,false)
		box(Rect2(16,248,508,456),Color("1c1d46",0.96),4,MOSS,2)
		box(Rect2(28,260,484,432),Color("353674",0.34),2,Color("ff8a2a",0.42),1)
		text_center("DROP INTO THE FIELD",Vector2(270,252),15,OCHRE,false)
		var active_skin:Dictionary=game.skin_definition(game.selected_skin_id)
		text_center("SECTOR %02d"%game.stage,Vector2(270,648),14,PAPER,false)
		text_center("ACTIVE FORM  %s  ·  SYNC %d / %d"%[active_skin.name.to_upper(),game.skin_progress,game.SCORE_TARGET],Vector2(270,681),10,MINT,false)
		# A direct loadout entry replaces non-functional imitation navigation.
		box(Rect2(24,850,492,88),SLATE,14,MOSS,2)
		text_center("CUSTOMIZE YOUR FORM  >",Vector2(270,886),20,PAPER,false)
		text_center("10 shapes / 5 field skills",Vector2(270,914),14,MINT,false)
		return
	if game.phase in ["intro","playing"]:
		if game.phase=="playing":draw_game_hud()
		else:
			draw_rect(Rect2(0,0,540,960),Color("17183e",.72))
			var points:=PackedVector2Array()
			for i in 65:
				var t:float=float(i)/64*TAU
				points.append(Vector2(270+63*cos(t),695+30*sin(2*t)))
			draw_polyline(points,MINT,7,true)
			draw_circle(Vector2(283,738),17,OCHRE)
			text_center("DRAG TO STEER",Vector2(270,792),27,PAPER)
			text_center("Collapse the field. Follow the signal.",Vector2(270,829),16,MINT,false)
	elif game.phase=="eaten":
		draw_rect(Rect2(0,0,540,960),Color("30213f",0.92))
		contour_wallpaper()
		text_center("RIFT COLLAPSED",Vector2(270,235),37,PAPER)
		signal_mark(Vector2(270,418),1.7)
		text_center("YOUR SIGNAL WENT DARK",Vector2(270,534),17,OCHRE,false)
		text_center("RECOVER OR RETURN TO DOCK",Vector2(270,571),14,MINT,false)
	elif game.phase in ["complete","timeout"]:
		draw_rect(Rect2(0,0,540,960),Color("17183e",0.94))
		contour_wallpaper()
		text_center("COLLAPSE COMPLETE" if game.phase=="complete" else "WINDOW CLOSED",Vector2(270,246),30,PAPER)
		signal_mark(Vector2(270,390),1.35)
		text_center("%d / %d SYNC"%[game.player.score,game.SCORE_TARGET],Vector2(270,533),28,OCHRE)
	if get_tree().paused:
		draw_rect(Rect2(0,0,540,960),Color("17183e",.86))
		text_center("SIGNAL HOLD",Vector2(270,341),39,PAPER)
	if toast_time>0:
		box(Rect2(48,835,444,54),Color("1c1d46",.98),2,RUST,2)
		text_center(toast,Vector2(270,871),18,OCHRE,false)

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
	draw_rect(Rect2(0,0,540,960),Color("24255b"))
	contour_wallpaper()
	text_center("RIFT FORMS",Vector2(270,55),31,PAPER)
	text_center("Pick your shape. Find your rhythm.",Vector2(270,82),16,MINT,false)
	box(Rect2(24,104,238,66),RUST if holes_tab=="classic" else SLATE,10,OCHRE,2)
	box(Rect2(278,104,238,66),RUST if holes_tab=="special" else SLATE,10,OCHRE,2)
	text_center("FOUNDATION  %d / 5"%game.unlocked_skin_count("foundation"),Vector2(143,145),16,INK if holes_tab=="classic" else PAPER,false)
	text_center("RESONANCE  %d / 5"%game.unlocked_skin_count("resonance"),Vector2(397,145),16,INK if holes_tab=="special" else PAPER,false)
	var detail:Dictionary=game.skin_definition(preview_skin_id)
	var detail_unlocked:bool=game.skin_unlocked(preview_skin_id)
	box(Rect2(18,184,504,250),Color("171a3d"),16,MOSS,2)
	text_center(detail.name,Vector2(270,215),25,PAPER,false)
	text_center("EQUIPPED" if game.selected_skin_id==detail.id else "PREVIEW / LOCKED" if not detail_unlocked else "AVAILABLE",Vector2(270,425),13,OCHRE,false)
	var ids:=tab_skin_ids()
	for index in ids.size():
		var rect:=slot_rect(index)
		var definition:Dictionary=game.skin_definition(ids[index])
		var unlocked:bool=game.skin_unlocked(ids[index])
		var equipped:bool=game.selected_skin_id==definition.id
		box(rect,Color("414590") if equipped else Color("22234f"),10,OCHRE if equipped else MOSS,3 if equipped else 1)
		text_center(definition.name,rect.position+Vector2(80,25),16,PAPER,false)
		var state:="EQUIPPED" if equipped else "READY" if unlocked else "%d SYNC"%int(definition.unlock)
		text_center(state,rect.position+Vector2(80,53),13,MINT if unlocked else OCHRE,false)
	box(Rect2(18,616,504,242),Color("1b1c42"),14,MOSS,2)
	draw_string(font,Vector2(34,644),detail.skill_name,HORIZONTAL_ALIGNMENT_LEFT,320,17,OCHRE)
	var cooldown_text:="VISUAL" if detail.kind=="cosmetic" else "AUTO / 12s" if detail.kind=="bloom" else "%ds COOLDOWN"%int(detail.cooldown)
	text_center(cooldown_text,Vector2(445,644),12,MINT,false)
	text_wrapped(detail.skill_desc,Vector2(34,676),472,18,PAPER)
	draw_string(font,Vector2(34,733),"HOW TO PLAY",HORIZONTAL_ALIGNMENT_LEFT,472,13,OCHRE)
	text_wrapped(detail.play_desc,Vector2(34,761),472,17,MINT)
	text_center("BEST ROUND %d   /   UNLOCK %d SYNC"%[game.skin_progress,int(detail.unlock)],Vector2(270,838),13,PAPER,false)
	box(Rect2(15,875,150,64),SLATE,10,OCHRE,2)
	text_center("DOCK",Vector2(90,915),18,PAPER,false)
	if toast_time>0:
		text_center(toast,Vector2(345,910),15,OCHRE,false)

func draw_game_hud() -> void:
	box(Rect2(178,22,184,50),Color("1c1d46",.96),2,MOSS,2)
	draw_circle(Vector2(204,47),16,RUST)
	draw_arc(Vector2(204,47),11,-PI/2,-PI/2+TAU*(game.remaining/game.ROUND_SECONDS),24,PAPER,3,true)
	draw_line(Vector2(204,47),Vector2(204,37),PAPER,2)
	draw_line(Vector2(204,47),Vector2(213,47),PAPER,2)
	var seconds:=int(ceil(game.remaining))
	text_center("%02d:%02d"%[seconds/60,seconds%60],Vector2(289,57),25,PAPER)
	box(Rect2(182,90,176,74),Color("f0efff"),2,OCHRE,2)
	text_center("FIELD LOAD",Vector2(270,113),11,SLATE,false)
	text_center("%d / %d"%[game.player.score,game.SCORE_TARGET],Vector2(270,137),20,INK,false)
	box(Rect2(197,148,146,9),SLATE,2,SLATE,0)
	var ratio:float=clampf(float(game.player.score)/float(game.SCORE_TARGET),0,1)
	if ratio>0:box(Rect2(198,149,144*ratio,7),RUST,2,RUST,0)
	box(Rect2(20,22,112,50),Color("1c1d46",.96),2,MOSS,2)
	text_center("%02d OUT"%game.kills,Vector2(76,55),16,MINT,false)
	var origin:=Vector2(270,801)
	var knob:=Vector2.ZERO
	if game.player.touch_index>=0:
		origin=game.player.touch_origin
		knob=game.player.joystick.limit_length()*43
	elif game.player.dragged:
		origin=game.player.mouse_origin
		knob=((get_viewport().get_mouse_position()-origin)/80).limit_length()*43
	draw_arc(origin,64,0,TAU,64,Color("a9d8b5",.34),3,true)
	draw_circle(origin+knob,25,Color("efe4ce",.82))
	box(Rect2(382,742,140,76),Color("1c1d46",.98),2,RUST,2)
	var pulse_ratio:float=clampf(game.player.pulse_charge/100.0,0,1)
	text_center("PULSE %02d%%"%int(round(pulse_ratio*100.0)),Vector2(452,767),13,OCHRE,false)
	box(Rect2(398,780,108,12),SLATE,2,SLATE,0)
	if pulse_ratio>0:box(Rect2(399,781,106*pulse_ratio,10),MINT,2,MINT,0)
	if pulse_ratio>=1.0:text_center("ARMED",Vector2(452,808),11,MINT,false)
	var skin:Dictionary=game.skin_definition(game.player.skin_id)
	box(Rect2(382,646,140,76),Color("1c1d46",.98),2,MOSS,2)
	text_center(skin.name.to_upper(),Vector2(452,657),9,MINT,false)
	text_center("SKILL  "+skin.skill_short,Vector2(452,680),12,OCHRE,false)
	var skill_state:="AUTO" if skin.kind=="bloom" else "CHROMA" if skin.kind=="cosmetic" else "READY" if game.player.skin_cooldown<=0.0 else "%.1fs"%game.player.skin_cooldown
	text_center(skill_state,Vector2(452,706),11,MINT if skill_state in ["AUTO","CHROMA","READY"] else OCHRE,false)
	if float(skin.cooldown)>0.0 and game.player.skin_cooldown>0.0:
		var cooldown_ratio:float=clampf(game.player.skin_cooldown/float(skin.cooldown),0.0,1.0)
		box(Rect2(511,650,5,64),SLATE,2,SLATE,0)
		box(Rect2(511,650+64.0*(1.0-cooldown_ratio),5,64.0*cooldown_ratio),OCHRE,2,OCHRE,0)
	if game.player.pulse_time>0.0:
		var pulse_screen:Vector2=game.camera.unproject_position(game.player.global_position+Vector3.UP*.2)
		var pulse_radius:float=minf(190.0,50.0+game.player.radius*14.0)
		draw_arc(pulse_screen,pulse_radius,0,TAU,48,Color("a9d8b5",.70),5,true)
		draw_arc(pulse_screen,pulse_radius+8,-PI/2,-PI/2+TAU*(game.player.pulse_time/.72),32,RUST,.95*8,true)
	if game.notice_time>0:text_center(game.notice,Vector2(270,218),32,OCHRE)
