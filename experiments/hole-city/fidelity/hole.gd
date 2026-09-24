extends "res://scripts/hole.gd"
## The MIT template's cut/controller with observed level badges and drag controls.
const LEVEL_STARTS: Array[int] = [0,10,30,60,100,160,240,350,500,700,950,1250]
const RADII: Array[float] = [0.85,1.2,1.65,2.2,3.5,5.1,6.0,7.2,8.7,10.2,12.0,14.0]
var level:=1
var meter:Label3D
var name_tag:Label3D
var mouse_origin:=Vector2.ZERO

func _ready() -> void:
	radius=RADII[0]
	super._ready()
	rim.mesh.inner_radius=0.86
	rim.mesh.outer_radius=1.08
	label.font_size=38
	label.pixel_size=0.019
	label.outline_size=10
	var bold:=FontVariation.new()
	bold.base_font=ThemeDB.fallback_font
	bold.variation_embolden=0.65
	label.font=bold
	name_tag=Label3D.new()
	name_tag.font=bold
	name_tag.font_size=28
	name_tag.pixel_size=0.019
	name_tag.outline_size=8
	name_tag.modulate=color
	name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test=true
	add_child(name_tag)
	meter=Label3D.new()
	meter.font_size=20
	meter.pixel_size=0.019
	meter.outline_size=15
	meter.modulate=Color.WHITE
	meter.outline_modulate=Color("101b21")
	meter.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	meter.no_depth_test=true
	add_child(meter)
	_update_badge()

func _sync_shape() -> void:
	super._sync_shape()
	if is_instance_valid(label):label.position=Vector3(0,3.0+radius*0.1,0)
	if is_instance_valid(name_tag):name_tag.position=Vector3(0,2.05+radius*0.1,0)
	if is_instance_valid(meter):meter.position=Vector3(0,1.2+radius*0.1,0)

func _update_badge() -> void:
	label.text="LVL %d"%level
	name_tag.text=display_name
	label.line_spacing=-6
	if is_instance_valid(meter):
		var next:int=LEVEL_STARTS[mini(level,LEVEL_STARTS.size()-1)]
		meter.text="●  %d/%d"%[score-LEVEL_STARTS[level-1],maxi(1,next-LEVEL_STARTS[level-1])]
	_sync_shape()

func award(value:int) -> void:
	score+=value
	collected+=1
	var previous:=level
	while level<LEVEL_STARTS.size() and score>=LEVEL_STARTS[level]:level+=1
	radius=RADII[level-1]
	_update_badge()
	if is_player and level>previous:game.level_up()

func _physics_process(delta:float) -> void:
	if not active:return
	if not enabled:
		_sync_shape()
		return
	var d:=Vector2.ZERO
	if is_player:
		d=_player_direction()
	else:
		ai_clock-=delta
		if ai_clock<=0 or not is_instance_valid(target) or is_instance_valid(target.claimed_by):
			ai_clock=0.6
			target=game.nearest_food(self)
		if is_instance_valid(target):
			var gap:=target.global_position-global_position
			d=Vector2(gap.x,gap.z).normalized()*clampf(gap.length()/0.5,0,1)
	velocity=Vector3(d.x,0,d.y)*(7.8 if is_player else 4.6)/(1+radius*0.05)
	move_and_slide()
	position.x=clampf(position.x,-47.0,47.0)
	position.z=clampf(position.z,-47.0,47.0)
	position.y=0
	_sync_shape()

func _player_direction() -> Vector2:
	if test_direction.length_squared()>0:return test_direction.limit_length()
	var d:=Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):d.y-=1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):d.y+=1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):d.x-=1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):d.x+=1
	if d.length_squared()>0:return game.screen_direction(d.normalized())
	if touch_index>=0:return game.screen_direction(joystick.limit_length())
	if dragged:
		d=(get_viewport().get_mouse_position()-mouse_origin)/80.0
		return game.screen_direction(d.limit_length())
	return Vector2.ZERO

func _unhandled_input(event:InputEvent) -> void:
	if not is_player or not active:return
	var move_key:bool=event is InputEventKey and event.pressed and event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]
	var pointer:bool=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if game.phase=="intro" and (move_key or pointer):game.begin_play()
	if not enabled:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragged=event.pressed
		if dragged:mouse_origin=event.position
	if event is InputEventScreenTouch:
		if event.pressed and touch_index<0:
			touch_index=event.index
			touch_origin=event.position
		elif not event.pressed and event.index==touch_index:
			touch_index=-1
			joystick=Vector2.ZERO
	if event is InputEventScreenDrag and event.index==touch_index:joystick=(event.position-touch_origin)/80.0
