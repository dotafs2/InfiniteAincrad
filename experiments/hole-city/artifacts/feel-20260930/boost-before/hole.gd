extends "res://scripts/hole.gd"
## The MIT template's cut/controller with observed level badges and drag controls.
const LEVEL_STARTS: Array[int] = [0,10,30,60,100,160,240,350,500,700,950,1250]
const RADII: Array[float] = [0.85,1.2,1.65,2.2,3.5,5.1,6.0,7.2,8.7,10.2,12.0,14.0]
const MAX_SCORE: int = 9223372036854775807
# Levels continue past the observed table. Physical size approaches this world
# safety limit so even extraordinary scores cannot erase the entire ground.
const RADIUS_LIMIT := 48.0
const PLAYER_BASE_SPEED := 7.8
const AI_BASE_SPEED := 3.5
var level:=1
var ai_reward_tenths:=0
var meter:Label3D
var name_tag:Label3D
var mouse_origin:=Vector2.ZERO
var pulse_charge:=0.0
var pulse_cooldown:=0.0
var pulse_time:=0.0
const PULSE_MAX:=100.0
const SkinVisual=preload("res://fidelity/skin_visual.gd")
var skin_id:=""
var skin_cooldown:=0.0
var speed_boost_time:=0.0
var skin_ring:MeshInstance3D
var skin_visual:Node3D
var settle_time:=0.0
var settle_at:=Vector3.ZERO

func _ready() -> void:
	radius=RADII[0]
	super._ready()
	rim.mesh.inner_radius=0.86
	rim.mesh.outer_radius=1.08
	label.font_size=31
	label.pixel_size=0.016
	label.outline_size=7
	var bold:=FontVariation.new()
	bold.base_font=load("res://assets/fonts/Fredoka.ttf")
	bold.variation_embolden=0.65
	label.font=bold
	name_tag=Label3D.new()
	name_tag.font=bold
	name_tag.font_size=25
	name_tag.pixel_size=0.019
	name_tag.outline_size=8
	name_tag.modulate=color
	name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test=true
	add_child(name_tag)
	meter=Label3D.new()
	meter.font=bold
	meter.font_size=17
	meter.pixel_size=0.019
	meter.outline_size=6
	meter.modulate=Color.WHITE
	meter.outline_modulate=Color("101b21")
	meter.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	meter.no_depth_test=true
	add_child(meter)
	if is_player and is_instance_valid(game) and skin_id!="":
		var skin:Dictionary=game.skin_definition(skin_id)
		skin_visual=SkinVisual.new()
		add_child(skin_visual)
		skin_visual.build(skin)
		skin_ring=skin_visual.main_ring
		rim.visible=false
	_update_badge()

func _sync_shape() -> void:
	super._sync_shape()
	if is_instance_valid(label):label.position=Vector3(0,3.0+radius*0.1,0)
	if is_instance_valid(name_tag):name_tag.position=Vector3(0,2.05+radius*0.1,0)
	if is_instance_valid(meter):meter.position=Vector3(0,1.2+radius*0.1,0)
	if is_instance_valid(skin_visual):skin_visual.scale=Vector3(radius,minf(radius,2.2),radius)

func _update_badge() -> void:
	label.text="LVL %d"%level
	name_tag.text=display_name
	label.line_spacing=-6
	if is_instance_valid(meter):
		var progress:=growth_progress()
		meter.text="%d / %d"%[progress.earned,progress.cost]
	_sync_shape()

@warning_ignore("integer_division")
static func level_start_for(target_level:int) -> int:
	if target_level<=1:return 0
	if target_level<=LEVEL_STARTS.size():return LEVEL_STARTS[target_level-1]
	var extra:=target_level-LEVEL_STARTS.size()
	# Check before multiplying. MAX_SCORE is the numeric storage boundary, not
	# an authored final level; ordinary progression never encounters this guard.
	if extra>MAX_SCORE-13 or extra>((MAX_SCORE-1250)/25)/(extra+13):return MAX_SCORE
	return 1250+25*extra*(extra+13)

@warning_ignore("integer_division")
static func _extension_fits(extra:int,points:int) -> bool:
	return extra<=0 or extra<=((points-1250)/25)/(extra+13)

@warning_ignore("integer_division")
static func level_for_score(points:int) -> int:
	points=maxi(0,points)
	if points<1250:
		for index in range(1,LEVEL_STARTS.size()):
			if points<LEVEL_STARTS[index]:return index
		return LEVEL_STARTS.size()
	var extra:=maxi(0,int(sqrt(float((points-1250)/25)+42.25)-6.5))
	# Floating-point sqrt only estimates the level. These exact integer checks
	# retain threshold accuracy even close to the signed 64-bit score ceiling.
	while not _extension_fits(extra,points):extra-=1
	while _extension_fits(extra+1,points):extra+=1
	return LEVEL_STARTS.size()+extra

static func radius_for_level(target_level:int) -> float:
	if target_level<=RADII.size():return RADII[maxi(0,target_level-1)]
	var extra:=float(target_level-RADII.size())
	return 14.0+(RADIUS_LIMIT-14.0)*extra/(extra+17.0)

static func level_for_radius(required:float) -> int:
	if not is_finite(required):return 0
	for index in RADII.size():
		if RADII[index]>=required:return index+1
	var last_level:=level_for_score(MAX_SCORE)
	if required>radius_for_level(last_level):return 0
	var extra:=maxi(1,int(ceil(17.0*(required-14.0)/(RADIUS_LIMIT-required))))
	var result:=RADII.size()+extra
	while result>RADII.size()+1 and radius_for_level(result-1)>=required:result-=1
	while radius_for_level(result)<required:result+=1
	return result

func growth_progress() -> Dictionary:
	var cost:int=LEVEL_STARTS[level]-LEVEL_STARTS[level-1] if level<LEVEL_STARTS.size() else 350+50*(level-LEVEL_STARTS.size())
	return {"earned":maxi(0,score-level_start_for(level)),"cost":cost}

@warning_ignore("integer_division")
func award(value:int) -> void:
	if value<0:return
	var credited:=value
	if not is_player:
		# Exact 70% rewards retain tenths between receipts, without float drift
		# or overflowing value*7 for a very large award.
		var tenths:=(value%10)*7+ai_reward_tenths
		credited=(value/10)*7+tenths/10
		ai_reward_tenths=tenths%10
	score+=mini(credited,MAX_SCORE-maxi(0,score))
	if collected<MAX_SCORE:collected+=1
	if is_player and is_instance_valid(game):game.note_skin_progress(score)
	if is_player:pulse_charge=minf(PULSE_MAX,pulse_charge+clampf(float(value)*2.5+8.0,0.0,24.0))
	var previous:=level
	level=level_for_score(score)
	radius=radius_for_level(level)
	_update_badge()
	if is_player and level>previous and is_instance_valid(game):game.level_up()

func trigger_pulse() -> bool:
	if not is_player or not active or not enabled or pulse_charge<PULSE_MAX or pulse_cooldown>0.0:return false
	if not is_instance_valid(game) or game.phase!="playing" or game.get_tree().paused:return false
	if not game.activate_resonance(self):return false
	pulse_charge=0.0
	pulse_cooldown=7.0
	pulse_time=0.72
	return true

func trigger_skin_skill() -> bool:
	if not is_player or not is_instance_valid(game):return false
	return game.activate_skin_skill(self)

func _physics_process(delta:float) -> void:
	pulse_cooldown=maxf(0.0,pulse_cooldown-delta)
	pulse_time=maxf(0.0,pulse_time-delta)
	skin_cooldown=maxf(0.0,skin_cooldown-delta)
	speed_boost_time=maxf(0.0,speed_boost_time-delta)
	if not active:return
	if not enabled:
		_sync_shape()
		return
	var d:=Vector2.ZERO
	if is_player:
		d=_player_direction()
	else:
		d=game.auto_direction(self,delta)
	var speed_boost:=1.55 if speed_boost_time>0.0 else 1.0
	velocity=Vector3(d.x,0,d.y)*(PLAYER_BASE_SPEED if is_player else AI_BASE_SPEED)*speed_boost/(1+radius*0.05)
	move_and_slide()
	position.x=clampf(position.x,-game.WORLD_LIMIT,game.WORLD_LIMIT)
	position.z=clampf(position.z,-game.WORLD_LIMIT,game.WORLD_LIMIT)
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
