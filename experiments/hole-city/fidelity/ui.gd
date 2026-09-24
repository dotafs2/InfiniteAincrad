extends Control
## Portrait adaptation of the observed Poki menu and one-finger controls.
## Every graphic here is drawn locally; the miniature is original Godot geometry.
const Art=preload("res://fidelity/art.gd")
var game:Node3D
var font:Font
var buttons:Array[Button]=[]
var hero:TextureRect
var hero_view:SubViewport
var animation:=0.0
var toast:=""
var toast_time:=0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	var bold:=FontVariation.new()
	bold.base_font=ThemeDB.fallback_font
	bold.variation_embolden=0.65
	font=bold
	make_hero()
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
	env.ambient_light_color=Color("c9e4f0")
	env.ambient_light_energy=0.7
	envnode.environment=env
	hero_view.add_child(envnode)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-32,0)
	light.light_energy=1.0
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
	hero.position=Vector2(10,193)
	hero.size=Vector2(520,515)
	hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(hero)

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
	b.add_theme_font_size_override("font_size",22)
	b.add_theme_font_override("font",font)
	b.add_theme_color_override("font_color",Color.WHITE)
	b.add_theme_color_override("font_outline_color",Color("776341"))
	b.add_theme_constant_override("outline_size",3)
	for state in ["normal","hover","pressed"]:
		var s:=StyleBoxFlat.new()
		s.bg_color=tint.lightened(0.1) if state=="hover" else tint.darkened(0.1) if state=="pressed" else tint
		s.border_color=Color("99642d")
		s.border_width_bottom=4 if tint.a>0 else 0
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state,s)
	b.pressed.connect(callback)
	add_child(b)
	buttons.append(b)
	return b

func refresh() -> void:
	for b in buttons:b.hide();b.queue_free()
	buttons.clear()
	hero.visible=game.phase=="title"
	hero_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if hero.visible else SubViewport.UPDATE_DISABLED
	if game.phase=="title":
		button(Rect2(90,740,360,70),"PLAY",game.start_level)
	elif game.phase=="eaten":
		button(Rect2(90,630,172,60),"100 GEMS",show_no_gems,Color("16c72d"))
		button(Rect2(278,630,172,60),"VIDEO",show_no_video)
		button(Rect2(160,730,220,54),"Give Up",game.back_home,Color(0,0,0,0))
	elif game.phase in ["timeout","complete"]:
		button(Rect2(90,620,360,68),"PLAY AGAIN",game.start_level)
		button(Rect2(140,710,260,58),"HOME",game.back_home,Color("b2a8e2"))
	elif get_tree().paused:
		button(Rect2(90,430,360,70),"RESUME",game.toggle_pause)
		button(Rect2(140,530,260,60),"HOME",game.back_home,Color("b2a8e2"))
	elif game.phase=="playing":
		button(Rect2(466,22,54,50),"II",game.toggle_pause,Color(.10,.14,.22,.76))
	queue_redraw()

func show_no_gems() -> void:
	toast="Not enough gems"
	toast_time=2.0

func show_no_video() -> void:
	toast="No video available"
	toast_time=2.0

func _process(delta:float) -> void:
	animation+=delta
	toast_time=maxf(0,toast_time-delta)
	if game.phase=="title" or toast_time>0:queue_redraw()

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		game.toggle_pause()
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
	draw_circle(at+Vector2(0,10),37,Color("1b2936"))
	draw_circle(at+Vector2(0,10),32,Color("23d5f2"))
	draw_circle(at+Vector2(0,10),27,Color("2960a4"))
	box(Rect2(at+Vector2(-21,-4),Vector2(42,36)),Color("9fe2ff"),3,Color("183b70"),2)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-36,-2),at+Vector2(0,-31),at+Vector2(36,-2),at+Vector2(29,5),at+Vector2(0,-17),at+Vector2(-29,5)]),Color("be70ed"))
	box(Rect2(at+Vector2(-13,4),Vector2(17,27)),Color("fb9158"),3,Color("fb9158"),0)
	box(Rect2(at+Vector2(8,3),Vector2(10,14)),Color("509beb"),2,Color("509beb"),0)

func star(at:Vector2,radius:float,tint:Color) -> void:
	var vertices:=PackedVector2Array()
	for i in 10:
		var a:float=-PI/2+i*PI/5
		vertices.append(at+Vector2(cos(a),sin(a))*radius*(1.0 if i%2==0 else 0.43))
	draw_colored_polygon(vertices,tint)

func _draw() -> void:
	if font==null:return
	if game.phase=="title":
		var background:=Color("4825c9").lerp(Color("247ce2"),(sin(animation*.21)+1)*.23)
		draw_rect(Rect2(0,0,540,960),background)
		for y in 12:
			for x in 7:crossed_axes(Vector2(x*104-30+(y%2)*52,y*91-30+fmod(animation*4,91)))
		draw_circle(Vector2(270,100),49,Color("a1e5f8"))
		draw_circle(Vector2(270,100),40,Color("272487"))
		draw_arc(Vector2(270,100),48,-PI/2,-PI/2+TAU*.04,16,Color("28bcef"),7,true)
		text_center(str(game.stage),Vector2(270,117),47)
		text_center("level",Vector2(270,151),18)
		draw_rect(Rect2(0,850,540,110),Color("e5e2fa"))
		draw_rect(Rect2(180,850,180,110),Color("aaa4dd"))
		text_center("STORE",Vector2(90,878),16,Color("383d76"),false)
		text_center("HOLES",Vector2(450,878),16,Color("383d76"),false)
		lock_icon(Vector2(90,920));lock_icon(Vector2(450,920));home_icon(Vector2(270,900))
		return
	if game.phase in ["intro","playing"]:
		if game.phase=="playing":draw_game_hud()
		else:
			draw_rect(Rect2(0,0,540,960),Color(0,0,0,.48))
			var points:=PackedVector2Array()
			for i in 65:
				var t:float=float(i)/64*TAU
				points.append(Vector2(270+63*cos(t),695+30*sin(2*t)))
			draw_polyline(points,Color.WHITE,7,true)
			draw_circle(Vector2(283,738),17,Color("bce9f1"))
			text_center("DRAG TO MOVE",Vector2(270,792),27)
			text_center("Eat small objects. Grow bigger.",Vector2(270,829),19)
	elif game.phase=="eaten":
		draw_rect(Rect2(0,0,540,960),Color(.21,.10,.28,.58))
		text_center("EATEN!",Vector2(270,235),50)
		box(Rect2(193,320,154,206),Color("74717f"),36,Color("444152"),8)
		draw_circle(Vector2(270,397),39,Color("beb5c7"))
		for x in [253,287]:
			draw_line(Vector2(x-8,387),Vector2(x+8,405),Color("30303b"),6)
			draw_line(Vector2(x+8,387),Vector2(x-8,405),Color("30303b"),6)
		box(Rect2(246,421,48,24),Color("beb5c7"),4,Color("74717f"),2)
		box(Rect2(172,510,196,45),Color("626073"),8,Color("394150"),3)
		text_center("HOLE",Vector2(270,544),30,Color("beb6c6"))
		text_center("REVIVE",Vector2(270,603),25)
	elif game.phase in ["complete","timeout"]:
		draw_rect(Rect2(0,0,540,960),Color(.12,.17,.3,.76))
		text_center("TARGET REACHED!" if game.phase=="complete" else "TIME'S UP!",Vector2(270,275),34)
		star(Vector2(270,394),68,Color("ffbf2c"))
		text_center("%d / 500 PTS"%game.player.score,Vector2(270,533),30)
	if get_tree().paused:
		draw_rect(Rect2(0,0,540,960),Color(.09,.08,.19,.80))
		text_center("PAUSED",Vector2(270,341),45)
	if toast_time>0:
		box(Rect2(55,835,430,54),Color(.09,.12,.19,.94),8,Color.TRANSPARENT,0)
		text_center(toast,Vector2(270,871),23)

func draw_game_hud() -> void:
	box(Rect2(200,22,140,50),Color(.08,.08,.11,.85),9,Color.TRANSPARENT,0)
	draw_circle(Vector2(224,47),16,Color("ec8a2b"))
	draw_circle(Vector2(224,47),12,Color("eaf3f2"))
	draw_line(Vector2(224,47),Vector2(224,37),Color("326fae"),2)
	draw_line(Vector2(224,47),Vector2(232,47),Color("326fae"),2)
	var seconds:=int(ceil(game.remaining))
	text_center("%02d:%02d"%[seconds/60,seconds%60],Vector2(287,57),27)
	box(Rect2(182,90,176,74),Color("eef0fe"),9,Color("4b4555"),2)
	star(Vector2(203,117),13,Color("ffb100"))
	text_center("%d / 500"%game.player.score,Vector2(280,125),21,Color("141e2f"),false)
	box(Rect2(197,138,146,13),Color("232934"),5,Color("232934"),0)
	var ratio:float=clampf(float(game.player.score)/500,0,1)
	if ratio>0:box(Rect2(198,139,144*ratio,11),Color("24baed"),4,Color("24baed"),0)
	box(Rect2(20,22,75,50),Color(.06,.06,.10,.82),8,Color.TRANSPARENT,0)
	text_center("%d K.O."%game.kills,Vector2(58,55),18)
	var origin:=Vector2(270,801)
	var knob:=Vector2.ZERO
	if game.player.touch_index>=0:
		origin=game.player.touch_origin
		knob=game.player.joystick.limit_length()*43
	elif game.player.dragged:
		origin=game.player.mouse_origin
		knob=((get_viewport().get_mouse_position()-origin)/80).limit_length()*43
	draw_arc(origin,64,0,TAU,64,Color(1,1,1,.30),3,true)
	draw_circle(origin+knob,25,Color(1,1,1,.76))
	if game.notice_time>0:text_center(game.notice,Vector2(270,218),32,Color("ffd541"))
