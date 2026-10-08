extends Control
var game: Node
var font = preload("res://assets/fonts/Barlow-ExtraBold.ttf")
var last_phase := ""
var panel: Control
var pause_button: Button
var mute_button: Button
var weapon_buttons: Array[Button] = []
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	pause_button=_button("II",Rect2(470,18,48,46),func(): game.toggle_pause(),false)
	mute_button=_button("SFX",Rect2(414,18,48,46),func(): game.audio_enabled=not game.audio_enabled; mute_button.text="SFX" if game.audio_enabled else "OFF",false)
	for i in range(5):
		var mode:String=game.Campaign.WEAPONS[i]
		var button:=_button(["RAPID","SCATTER","RAIL","ROCKET","ARC"][i],Rect2(25+i*99,897,94,42),func():game.select_weapon(mode),false)
		button.add_theme_font_size_override("font_size",16)
		weapon_buttons.append(button)
	get_viewport().size_changed.connect(queue_redraw)
func _button(text: String, rect: Rect2, action: Callable, primary: bool) -> Button:
	var b:=Button.new()
	b.text=text
	b.position=rect.position
	b.size=rect.size
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",25 if primary else 20)
	b.add_theme_color_override("font_color",Color("182039") if primary else Color.WHITE)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("f4d455") if primary else Color(0.04,0.07,0.12,0.75)
	style.set_corner_radius_all(12)
	style.content_margin_top=9; style.content_margin_bottom=9
	style.border_width_bottom=4 if primary else 1
	style.border_color=Color("b89524") if primary else Color("5d6a7e")
	b.add_theme_stylebox_override("normal",style)
	var hover:=style.duplicate()
	hover.bg_color=style.bg_color.lightened(0.14)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",style)
	b.pressed.connect(action)
	add_child(b)
	return b
func text_at(text: String, center: Vector2, size: int, color: Color=Color.WHITE) -> void:
	var w:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var pos:=center-Vector2(w/2,0)
	draw_string_outline(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,5,Color(0.035,0.045,0.065,0.95))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func _draw() -> void:
	if not is_instance_valid(game): return
	if game.phase!=last_phase:
		last_phase=game.phase
		_rebuild_panel.call_deferred()
	pause_button.visible=game.phase in ["playing","paused"]
	mute_button.visible=game.phase in ["playing","paused"]
	for i in range(weapon_buttons.size()):
		var button:Button=weapon_buttons[i]
		button.visible=game.phase=="playing"
		button.disabled=game.wave<int(game.Campaign.WEAPON_UNLOCK_WAVE[game.Campaign.WEAPONS[i]])
		button.modulate=Color("ffdf83") if game.weapon_mode==game.Campaign.WEAPONS[i] else Color.WHITE
	if game.phase in ["playing","paused"]:
		text_at("WAVE %02d / %02d"%[game.wave+1,game.Campaign.WAVES.size()],Vector2(105,44),20)
		text_at("SQUAD %d / %d"%[game.squad.members.size(),game.Campaign.MAX_SQUAD],Vector2(100,883),17,Color("b4ecff"))
		draw_style_box(_bar_style(Color(0.05,0.07,0.12,0.7)),Rect2(26,58,120,9))
		draw_style_box(_bar_style(Color("68d5a3")),Rect2(28,60,116*game.health/100,5))
		if game.message_time>0:
			text_at(game.message,Vector2(270,856),22 if game.message.length()>22 else 28,Color("fff1be"))
		pass # Gameplay stays visually sparse after the initial hint.
		if game.upgrade_flash>0: draw_rect(Rect2(0,0,540,960),Color(0.3,0.95,1,game.upgrade_flash*0.1))
	if game.phase in ["ready","paused","won","lost"]:
		draw_rect(Rect2(0,0,540,960),Color(0.015,0.025,0.045,0.58 if game.phase=="ready" else 0.76))
		if game.phase=="ready":
			text_at("GATE",Vector2(270,210),81,Color("ffe072"))
			text_at("SIEGE",Vector2(270,290),81)
			text_at("RECRUIT. MULTIPLY. SURVIVE.",Vector2(270,329),20,Color("a2dcef"))
			text_at("Drag to steer. Blue ring marks your shield.",Vector2(270,632),19)
			text_at("Collect +1 cards. Upgrade your whole squad.",Vector2(270,665),21,Color("c7d2e6"))
			text_at("Dodge red zones • Weapons: 1–5",Vector2(270,898),17,Color("b7c5d8"))
		elif game.phase=="paused":
			text_at("PAUSED",Vector2(270,362),55)
			text_at("Your line is holding.",Vector2(270,411),24,Color("c7d2e6"))
		else:
			text_at("LINE HELD" if game.phase=="won" else "OVERRUN",Vector2(270,340),58,Color("ffe072") if game.phase=="won" else Color("ff8c84"))
			text_at("%d ENEMIES CLEARED"%game.kills,Vector2(270,403),25)
			text_at("%d SOLDIERS • %d CLASS UPGRADES"%[game.squad.members.size(),game.tier],Vector2(270,444),21,Color("a6dbef"))
func _bar_style(c: Color) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=c;s.set_corner_radius_all(4);return s
func _rebuild_panel() -> void:
	if is_instance_valid(panel): panel.queue_free()
	panel=Control.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	var buttons:Array[Button]=[]
	if game.phase=="ready": buttons.append(_button("DEPLOY",Rect2(105,729,330,66),func():game.start_game(),true))
	if game.phase=="paused":
		buttons.append(_button("RESUME",Rect2(105,506,330,66),func():game.toggle_pause(),true))
		buttons.append(_button("RESTART",Rect2(145,594,250,54),func():game.restart_game(),false))
	if game.phase in ["won","lost"]: buttons.append(_button("PLAY AGAIN",Rect2(105,530,330,66),func():game.restart_game(),true))
	if game.phase in ["ready","paused"]:
		var quality_button:=_button("QUALITY: "+game.quality_mode.to_upper(),Rect2(145,812 if game.phase=="ready" else 678,250,48),func():game.cycle_quality();_rebuild_panel(),false)
		buttons.append(quality_button)
	for b in buttons:
		remove_child(b);panel.add_child(b)
