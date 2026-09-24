extends Control
## Screen composition measured from the live Poki game at 836 x 470.
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
	hero.position=Vector2(360,136)
	hero.size=Vector2(560,425)
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
		button(Rect2(529,578,222,44),"PLAY",game.start_level)
		# The observed initial menu shows locked side tabs. They remain locked in
		# this first-level slice; the separately observed shop pages are phase two.
	elif game.phase=="eaten":
		var gem:=button(Rect2(525,486,111,46),"  100",show_no_gems,Color("16d222"))
		gem.tooltip_text="100 gems required"
		var gem_art:=Control.new()
		gem_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		gem.add_child(gem_art)
		gem_art.draw.connect(func():
			gem_art.draw_colored_polygon(PackedVector2Array([Vector2(16,18),Vector2(23,13),Vector2(30,18),Vector2(30,27),Vector2(23,32),Vector2(16,27)]),Color("db43ee"))
			gem_art.draw_line(Vector2(17,18),Vector2(23,22),Color("f6adff"),2)
			gem_art.draw_line(Vector2(23,22),Vector2(29,18),Color("f6adff"),2)
			gem_art.draw_line(Vector2(23,22),Vector2(23,30),Color("9d2dcb"),2))
		var video:=button(Rect2(653,486,111,46),"",show_no_video)
		video.tooltip_text="No video available offline"
		var film:=Control.new()
		film.mouse_filter=Control.MOUSE_FILTER_IGNORE
		video.add_child(film)
		film.draw.connect(func():
			film.draw_rect(Rect2(43,13,26,21),Color.WHITE,false,2)
			film.draw_colored_polygon(PackedVector2Array([Vector2(51,18),Vector2(51,29),Vector2(61,23)]),Color.WHITE)
			for y in [16,22,28]:film.draw_rect(Rect2(44,y,3,3),Color.WHITE))
		var giveup:=button(Rect2(565,559,150,38),"Give Up",game.back_home,Color(0,0,0,0))
		giveup.add_theme_font_size_override("font_size",18)
	elif game.phase in ["timeout","complete"]:
		button(Rect2(529,485,222,48),"PLAY AGAIN",game.start_level)
		button(Rect2(529,550,222,42),"HOME",game.back_home,Color("b2a8e2"))
	elif get_tree().paused:
		button(Rect2(529,350,222,50),"RESUME",game.toggle_pause)
		button(Rect2(529,414,222,45),"HOME",game.back_home,Color("b2a8e2"))
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
		var background:=Color("4825c9").lerp(Color("247ce2"),(sin(animation*0.21)+1)*0.23)
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),background)
		for y in 9:
			for x in 14:crossed_axes(Vector2(x*104-30+(y%2)*52,y*91-30+fmod(animation*4,91)))
		draw_circle(Vector2(640,79),42,Color("a1e5f8"))
		draw_circle(Vector2(640,79),34,Color("272487"))
		draw_arc(Vector2(640,79),41,-PI/2,-PI/2+TAU*0.04,16,Color("28bcef"),7,true)
		text_center(str(game.stage),Vector2(640,95),43)
		text_center("level",Vector2(640,122),13)
		draw_rect(Rect2(0,642,1280,78),Color("e5e2fa"))
		draw_rect(Rect2(427,642,426,78),Color("aaa4dd"))
		text_center("STORE",Vector2(213,659),11,Color("383d76"),false)
		text_center("HOLES",Vector2(1067,659),11,Color("383d76"),false)
		lock_icon(Vector2(213,685))
		lock_icon(Vector2(1067,685))
		home_icon(Vector2(640,666))
		return
	if game.phase in ["intro","playing"]:
		if game.phase=="playing":draw_game_hud()
		else:
			draw_rect(Rect2(0,0,1280,720),Color(0,0,0,0.54))
			var points:=PackedVector2Array()
			for i in 65:
				var t:float=float(i)/64*TAU
				points.append(Vector2(640+47*cos(t),423+23*sin(2*t)))
			draw_polyline(points,Color.WHITE,7,true)
			draw_circle(Vector2(650,454),13,Color("bce9f1"))
			text_center("DRAG TO MOVE",Vector2(640,479),17)
	elif game.phase=="eaten":
		draw_rect(Rect2(0,0,1280,720),Color(0.9,0.53,0.95,0.28))
		for i in range(18,0,-1):draw_circle(Vector2(640,341),float(i)*12,Color(0.9,0.1,0.8,0.014))
		text_center("EATEN!",Vector2(640,165),44)
		var stone:=PackedVector2Array([Vector2(572,389),Vector2(583,224),Vector2(615,197),Vector2(693,211),Vector2(705,239),Vector2(681,393)])
		draw_colored_polygon(stone,Color("484352"))
		var inside:=PackedVector2Array([Vector2(588,378),Vector2(597,232),Vector2(619,217),Vector2(678,225),Vector2(687,246),Vector2(667,378)])
		draw_colored_polygon(inside,Color("7b7a8c"))
		draw_circle(Vector2(641,282),31,Color("aaa3b5"))
		for x in [628,654]:
			draw_line(Vector2(x-6,274),Vector2(x+6,288),Color("2b313b"),6)
			draw_line(Vector2(x+6,274),Vector2(x-6,288),Color("2b313b"),6)
		box(Rect2(623,301,34,19),Color("aba3b8"),4,Color("716d82"),2)
		box(Rect2(556,379,161,45),Color("626073"),8,Color("394150"),3)
		text_center("HOLE",Vector2(639,410),26,Color("beb6c6"))
		text_center("REVIVE",Vector2(640,474),21)
	elif game.phase in ["complete","timeout"]:
		draw_rect(Rect2(0,0,1280,720),Color(0.12,0.17,0.3,0.7))
		text_center("TARGET REACHED!" if game.phase=="complete" else "TIME'S UP!",Vector2(640,235),42)
		star(Vector2(640,329),55,Color("ffbf2c"))
		text_center("%d / 500 PTS"%game.player.score,Vector2(640,421),28)
	if get_tree().paused:
		draw_rect(Rect2(0,0,1280,720),Color(0.09,0.08,0.19,0.76))
		text_center("PAUSED",Vector2(640,292),43)
	if toast_time>0:
		box(Rect2(470,619,340,45),Color(0.09,0.12,0.19,0.9),8,Color.TRANSPARENT,0)
		text_center(toast,Vector2(640,649),20)

func draw_game_hud() -> void:
	box(Rect2(590,12,100,32),Color(0.08,0.08,0.11,0.85),5,Color.TRANSPARENT,0)
	draw_circle(Vector2(604,28),13,Color("ec8a2b"))
	draw_circle(Vector2(604,28),10,Color("eaf3f2"))
	draw_line(Vector2(604,28),Vector2(604,20),Color("326fae"),2)
	draw_line(Vector2(604,28),Vector2(611,28),Color("326fae"),2)
	var seconds:=int(ceil(game.remaining))
	text_center("%02d:%02d"%[seconds/60,seconds%60],Vector2(651,37),21)
	box(Rect2(617,66,46,62),Color("eef0fe"),6,Color("4b4555"),2)
	star(Vector2(640,81),11,Color("ffb100"))
	text_center("500 PTS",Vector2(640,104),8,Color("141e2f"),false)
	box(Rect2(622,109,36,13),Color("232934"),5,Color("232934"),0)
	var ratio:float=clampf(float(game.player.score)/500,0,1)
	if ratio>0:box(Rect2(623,110,34*ratio,11),Color("24baed"),4,Color("24baed"),0)
	box(Rect2(1216,13,59,28),Color(0.06,0.06,0.10,0.82),5,Color.TRANSPARENT,0)
	draw_circle(Vector2(1234,24),6,Color("f1f1f5"))
	draw_rect(Rect2(1230,27,8,6),Color("f1f1f5"))
	for x in [1231,1237]:draw_circle(Vector2(x,24),1.6,Color("41434d"))
	text_center(str(game.kills),Vector2(1258,33),16)
	if game.elapsed<5:
		box(Rect2(573,151,134,72),Color("eeecff"),5,Color("6d6774"),1)
		text_center("Eat everything",Vector2(640,176),15,Color("ffe321"))
		text_center("to reach the",Vector2(640,194),14)
		text_center("score target!",Vector2(640,213),14)
	draw_arc(Vector2(640,540),69,0,TAU,64,Color(1,1,1,0.22),3,true)
	var knob:=Vector2.ZERO
	if game.player.dragged:knob=((get_viewport().get_mouse_position()-game.player.mouse_origin)/100.0).limit_length()*37
	draw_circle(Vector2(640,540)+knob,28,Color.WHITE)
	if game.notice_time>0:text_center(game.notice,Vector2(640,211),36,Color("ffd541"))
