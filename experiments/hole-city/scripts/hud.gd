extends CanvasLayer
const Map = preload("res://scripts/minimap.gd")
const INK := Color("102c3b")
const CREAM := Color("f6f1e4")
const MINT := Color("57e4d0")
var game: Node
var root: Control
var title_layer: Control
var playing_layer: Control
var modal_layer: Control
var modal_card: VBoxContainer
var timer: Label
var score: Label
var size_label: Label
var progress_label: Label
var note: Label
var board: Label
var progress: ProgressBar
var pop: Label
var muted_button: Button
var map: Control
var mode_label: Label
var best_label: Label
var pop_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_title()
	_game_hud()
	_modal()

func style(color: Color, radius := 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box

func label(parent: Node, text: String, font_size: int, tint := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",tint)
	parent.add_child(l)
	return l

func button(parent: Node, text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0,54)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_color_override("font_color",INK if primary else CREAM)
	b.add_theme_color_override("font_hover_color",INK if primary else CREAM)
	b.add_theme_color_override("font_pressed_color",INK if primary else CREAM)
	b.add_theme_stylebox_override("normal",style(MINT if primary else Color("2d4956"),12))
	b.add_theme_stylebox_override("hover",style(Color("87f3df") if primary else Color("3d5d68"),12))
	b.add_theme_stylebox_override("pressed",style(Color("41bfae") if primary else Color("1d3b48"),12))
	var focus := style(Color(0,0,0,0),12)
	focus.border_color = CREAM
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",focus)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c

func panel(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = at
	p.size = dimensions
	p.add_theme_stylebox_override("panel",style(color))
	parent.add_child(p)
	return p

func column(parent: Node, separation := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",separation)
	parent.add_child(v)
	return v

func _title() -> void:
	title_layer = layer()
	var shade := ColorRect.new()
	shade.color = Color(0.035,0.12,0.17,0.25)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(shade)
	var p := panel(title_layer,Vector2(64,94),Vector2(455,660),Color(0.045,0.14,0.19,0.96))
	var v := column(p,12)
	label(v,"SMALL HOLE. BIG APPETITE.",15,MINT)
	var title := label(v,"SINK\nCITY.",84)
	title.add_theme_constant_override("line_spacing",-22)
	label(v,"An entire city. One very hungry hole.",18,Color("c2d0cb"))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	v.add_child(spacer)
	button(v,"PLAY  /  2 MINUTE ROUND",game.start_game.bind("round"),true)
	label(v,"Compete against 3 CPU-controlled holes.",15,Color("aebfc0"))
	button(v,"FREE ROAM  /  EAT THE WHOLE CITY",game.start_game.bind("free"))
	label(v,"No timer. No rivals. Every last building.",15,Color("aebfc0"))
	label(v,"WASD or arrows  •  Hold mouse / drag to move\nStart small. Grow. Swallow the skyline.",16,Color("d5ddd3"))
	best_label = label(v,"BEST  %s" % game.best,17,MINT)
	button(v,"CREDITS",show_credits)
	var caption := label(title_layer,"WELCOME TO MARINA DISTRICT",16,INK)
	caption.position = Vector2(64,34)
	var badge := panel(title_layer,Vector2(990,725),Vector2(370,90),Color(0.96,0.94,0.87,0.94))
	var bv := column(badge,2)
	label(bv,"FROM CURBS TO SKYSCRAPERS",16,INK)
	label(bv,"Your next bite is always around the corner.",14,Color("4e6c70"))

func _game_hud() -> void:
	playing_layer = layer()
	var brand := panel(playing_layer,Vector2(24,22),Vector2(285,90),Color(0.96,0.95,0.90,0.96))
	var b := column(brand,1)
	label(b,"SINK CITY",27,INK)
	mode_label = label(b,"MARINA / SOLO",13,Color("526c72"))
	var clock_panel := panel(playing_layer,Vector2(590,22),Vector2(240,90),Color(0.06,0.16,0.21,0.94))
	clock_panel.anchor_left = 0.5
	clock_panel.anchor_right = 0.5
	clock_panel.offset_left = -120
	clock_panel.offset_right = 120
	var clock_box := column(clock_panel,0)
	timer = label(clock_box,"02:00",34)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var clock_caption := label(clock_box,"TIME LEFT",11,Color("91b4b8"))
	clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var score_panel := panel(playing_layer,Vector2(1126,22),Vector2(290,198),Color(0.06,0.16,0.21,0.94))
	score_panel.anchor_left = 1.0
	score_panel.anchor_right = 1.0
	score_panel.offset_left = -314
	score_panel.offset_right = -24
	var sb := column(score_panel,1)
	label(sb,"YOUR SCORE",12,MINT)
	score = label(sb,"0",44)
	size_label = label(sb,"2.3 m  /  JUST A LITTLE HUNGRY",13,Color("b1c4c5"))
	board = label(sb,"",15,CREAM)
	var progress_panel := panel(playing_layer,Vector2(24,777),Vector2(440,99),Color(0.06,0.16,0.21,0.94))
	progress_panel.anchor_top = 1.0
	progress_panel.anchor_bottom = 1.0
	progress_panel.offset_top = -123
	progress_panel.offset_bottom = -24
	var pv := column(progress_panel,6)
	progress_label = label(pv,"CITY EATEN   0 / 0",15)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(380,9)
	progress.show_percentage = false
	var track := style(Color("31505b"),5)
	var fill := style(MINT,5)
	for s in [track,fill]:
		s.content_margin_left = 0
		s.content_margin_right = 0
		s.content_margin_top = 0
		s.content_margin_bottom = 0
	progress.add_theme_stylebox_override("background",track)
	progress.add_theme_stylebox_override("fill",fill)
	pv.add_child(progress)
	label(pv,"WASD / ARROWS / DRAG    •    ESC pause    •    R restart",12,Color("abc1c2"))
	var map_panel := panel(playing_layer,Vector2(1218,660),Vector2(198,216),Color(0.06,0.16,0.21,0.94))
	map_panel.anchor_left = 1.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_top = 1.0
	map_panel.anchor_bottom = 1.0
	map_panel.offset_left = -222
	map_panel.offset_right = -24
	map_panel.offset_top = -240
	map_panel.offset_bottom = -24
	var mv := column(map_panel,7)
	map = Map.new()
	map.game = game
	map.custom_minimum_size = Vector2(154,154)
	mv.add_child(map)
	label(mv,"BRIGHT DOTS = EDIBLE",10,MINT)
	note = label(playing_layer,"",18,INK)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	note.offset_left = -400
	note.offset_right = 400
	note.offset_top = -100
	note.offset_bottom = -60
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_shadow_color",Color(1,1,1,0.65))
	note.add_theme_constant_override("shadow_offset_x",1)
	note.add_theme_constant_override("shadow_offset_y",1)
	pop = label(playing_layer,"",30,MINT)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pop.offset_top = -70
	pop.offset_bottom = -30
	pop.offset_left = -200
	pop.offset_right = 200
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.add_theme_color_override("font_shadow_color",INK)
	pop.add_theme_constant_override("shadow_offset_y",2)
	var controls := HBoxContainer.new()
	playing_layer.add_child(controls)
	controls.position = Vector2(24,125)
	controls.add_theme_constant_override("separation",8)
	button(controls,"PAUSE",game.toggle_pause)
	muted_button = button(controls,"SOUND ON",_mute)

func _modal() -> void:
	modal_layer = layer()
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.055,0.09,0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(570,0)
	p.add_theme_stylebox_override("panel",style(Color("102c3b"),22))
	center.add_child(p)
	modal_card = column(p,14)
	modal_layer.hide()

func clear_modal() -> void:
	for c in modal_card.get_children(): c.free()
	modal_layer.show()

func show_title() -> void:
	title_layer.show()
	playing_layer.hide()
	modal_layer.hide()
	best_label.text = "BEST  %d" % game.best

func show_game() -> void:
	title_layer.hide()
	playing_layer.show()
	modal_layer.hide()
	mode_label.text = "MARINA / 3 CPU RIVALS" if game.mode == "round" else "MARINA / FREE ROAM"

func show_pause(paused: bool) -> void:
	if not paused:
		modal_layer.hide()
		return
	clear_modal()
	label(modal_card,"TAKE A BREATHER",34)
	label(modal_card,"The city will still be here when you get back.",17,Color("b3c7c8"))
	button(modal_card,"KEEP EATING",game.toggle_pause,true)
	button(modal_card,"RESTART",game.start_game.bind(game.mode))
	button(modal_card,"MAIN MENU",game.back_to_title)

func show_results(reason: String) -> void:
	clear_modal()
	label(modal_card,"ROUND COMPLETE" if game.mode == "round" else "FREE ROAM",13,MINT)
	label(modal_card,reason,42)
	label(modal_card,"%d POINTS" % game.player.score,34,MINT)
	var rank: int = game.ranking().find(game.player)+1
	var summary := "%d objects eaten by you  •  %.0f%% of the city cleared" % [game.player.collected,100.0*game.eaten/maxi(game.total,1)]
	label(modal_card,summary,16,Color("c3d1cf"))
	if game.mode == "round": label(modal_card,"FINISH  #%d / 4     •     BEST  %d" % [rank,game.best],18)
	button(modal_card,"ONE MORE BITE",game.start_game.bind(game.mode),true)
	button(modal_card,"FREE ROAM",game.start_game.bind("free"))
	button(modal_card,"MAIN MENU",game.back_to_title)

func show_credits() -> void:
	clear_modal()
	label(modal_card,"MADE TO BE PLAYED",32)
	label(modal_card,"Based on Godot-Hole.io by mbMayer (MIT).\nCSG hole scene and controller adapted with attribution.\nOriginal city, interface, rules and generated audio.\nNo Hole.io branding, maps or proprietary assets.\nBuilt with Godot Engine (MIT).",17,Color("c3d1cf"))
	button(modal_card,"BACK",modal_layer.hide,true)

func update_hud() -> void:
	if not is_instance_valid(game.player) or not playing_layer.visible:return
	var seconds := int(ceil(game.remaining))
	timer.text = "%02d:%02d" % [seconds/60,seconds%60] if game.mode == "round" else "NO LIMIT"
	timer.add_theme_color_override("font_color",Color("ffab85") if seconds<20 and game.mode=="round" else CREAM)
	score.text = str(game.player.score)
	size_label.text = "%.1f m DIAMETER  /  %d BITES" % [game.player.radius*2.0,game.player.collected]
	progress_label.text = "CITY EATEN   %d / %d" % [game.eaten,game.total]
	progress.value = 100.0*game.eaten/maxi(game.total,1)
	note.text = game.status_note if game.status_time>0.0 else ""
	var rows := PackedStringArray()
	var i := 0
	for h in game.ranking():
		i += 1
		rows.append("%d.  %s   %d%s" % [i,h.display_name,h.score,"  OUT" if not h.active else ""])
	board.text = "\n".join(rows) if game.mode == "round" else "SOLO  /  THE WHOLE CITY IS YOURS"

func pop_score(value: int, kind: String) -> void:
	if is_instance_valid(pop_tween): pop_tween.kill()
	pop.text = "+%d  %s" % [value,kind.to_upper()]
	pop.modulate.a = 1.0
	pop_tween = create_tween()
	pop_tween.tween_interval(0.2)
	pop_tween.tween_property(pop,"modulate:a",0.0,0.8)

func _mute() -> void:
	game.muted = not game.muted
	muted_button.text = "SOUND OFF" if game.muted else "SOUND ON"
	if game.muted:game.sound.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			game.toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and game.phase != "title":
			game.start_game(game.mode)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and game.phase == "title":game.start_game("round")
		elif event.keycode == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
