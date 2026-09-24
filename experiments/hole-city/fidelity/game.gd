extends Node3D
const Art=preload("res://fidelity/art.gd")
const Hole=preload("res://fidelity/hole.gd")
const UI=preload("res://fidelity/ui.gd")
const Asphalt=preload("res://fidelity/asphalt.gdshader")
const ROUND_SECONDS:=240.0
const SCORE_TARGET:=500
var phase:="title"
var remaining:=ROUND_SECONDS
var elapsed:=0.0
var player:CharacterBody3D
var holes:Array[Node3D]=[]
var city:Node3D
var ground:CSGCombiner3D
var world:Node3D
var camera:Camera3D
var ui:Control
var eaten:=0
var total:=0
var scan:=0.0
var kills:=0
var notice:=""
var notice_time:=0.0
var coins:=50
var gems:=50
var stage:=1
var test_mode:=OS.get_cmdline_user_args().has("--test")
var demo_mode:=OS.get_cmdline_user_args().has("--demo")
var demo_target:Node3D
var sound:AudioStreamPlayer

func _ready() -> void:
	if not test_mode:
		var cfg:=ConfigFile.new()
		if cfg.load("user://reference-first-level.cfg")==OK:
			coins=int(cfg.get_value("progress","coins",50))
			gems=int(cfg.get_value("progress","gems",50))
			stage=int(cfg.get_value("progress","stage",1))
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("258cdd")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d8deee")
	env.ambient_light_energy=0.43
	envnode.environment=env
	add_child(envnode)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-52,-38,0)
	sun.light_energy=0.8
	sun.shadow_enabled=true
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=48
	camera.far=220
	add_child(camera)
	camera.current=true
	sound=AudioStreamPlayer.new()
	sound.volume_db=-19
	add_child(sound)
	var layer:=CanvasLayer.new()
	add_child(layer)
	ui=UI.new()
	ui.game=self
	layer.add_child(ui)
	if demo_mode:start_level();begin_play()

func start_level() -> void:
	get_tree().paused=false
	if is_instance_valid(world):world.free()
	holes.clear()
	phase="intro"
	remaining=ROUND_SECONDS
	elapsed=0
	eaten=0
	kills=0
	scan=0
	world=Node3D.new()
	add_child(world)
	ground=CSGCombiner3D.new()
	ground.use_collision=true
	ground.collision_layer=1
	ground.collision_mask=1
	world.add_child(ground)
	var floor_shape:=CSGBox3D.new()
	floor_shape.size=Vector3(100,3,100)
	floor_shape.position.y=-1.5
	var mat:=ShaderMaterial.new()
	mat.shader=Asphalt
	floor_shape.material=mat
	ground.add_child(floor_shape)
	city=Art.new()
	world.add_child(city)
	city.build(self)
	total=city.foods.size()
	player=spawn_hole("Player",Vector3(1,0,23),Color("32c6f2"),true)
	var names:=["Marina","Shay","Comet","Yucca","Archie","Sawyer","Zephyr"]
	var colors:=[Color("9546d5"),Color("a972f2"),Color("cc696c"),Color("2caa74"),Color("dc9a29"),Color("ed7cc0"),Color("839e77")]
	var starts:=[Vector3(-4,0,23),Vector3(-2,0,27),Vector3(9,0,24),Vector3(-8,0,32),Vector3(19,0,37),Vector3(-12,0,14),Vector3(22,0,14)]
	for i in 7:spawn_hole(names[i],starts[i],colors[i],false)
	update_camera(1.0,true)
	ui.refresh()

func spawn_hole(title:String, at:Vector3, tint:Color, human:bool) -> CharacterBody3D:
	var h:=Hole.new()
	h.game=self
	h.display_name=title
	h.color=tint
	h.is_player=human
	ground.add_child(h)
	ground.add_child(h.hole)
	h.position=at
	holes.append(h)
	return h

func begin_play() -> void:
	if phase!="intro":return
	phase="playing"
	for h in holes:h.enabled=true
	ui.refresh()

func screen_direction(d:Vector2) -> Vector2:
	var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var back:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	return right*d.x+back*d.y

func _physics_process(delta:float) -> void:
	if phase!="playing":return
	elapsed+=delta
	remaining=maxf(0,remaining-delta)
	notice_time=maxf(0,notice_time-delta)
	scan-=delta
	if scan<=0:
		scan=0.09
		scan_food()
		if elapsed>10:scan_rivals()
	if phase!="playing":return
	if player.score>=SCORE_TARGET:finish("complete")
	elif remaining<=0:finish("timeout")
	if demo_mode and phase=="playing":
		if not is_instance_valid(demo_target) or is_instance_valid(demo_target.claimed_by):demo_target=nearest_food(player)
		if is_instance_valid(demo_target):
			var gap:=Vector2(demo_target.position.x-player.position.x,demo_target.position.z-player.position.z)
			player.test_direction=gap.normalized()*clampf(gap.length()/0.4,0,1)

func _process(delta:float) -> void:
	if is_instance_valid(player) and phase in ["intro","playing"]:update_camera(delta)
	if is_instance_valid(ui):ui.queue_redraw()

func update_camera(delta:float, instant:=false) -> void:
	var distance:float=1.0+(player.radius-0.85)*0.12
	var target:Vector3=player.position
	var offset:=Vector3(11,15.5,17)*distance
	camera.position=target+offset if instant else camera.position.lerp(target+offset,1-exp(-delta*6))
	camera.look_at(target)

func nearest_food(h:Node3D) -> Node3D:
	var found:Node3D
	var best:=INF
	for item in city.foods:
		if not is_instance_valid(item) or not item.can_fit(h):continue
		var dist:float=item.global_position.distance_squared_to(h.global_position)
		if dist<best:best=dist;found=item
	return found

func scan_food() -> void:
	for item in city.foods:
		if not is_instance_valid(item) or item.consumed or is_instance_valid(item.claimed_by):continue
		for h in holes:
			if not h.active or not item.can_fit(h):continue
			var d:=Vector2(item.position.x-h.position.x,item.position.z-h.position.z).length()
			# Wake while part of the base is still supported by the rim, so
			# asymmetric contact and gravity can tip the rigid body into the cut.
			if d<h.radius*0.90:item.begin_swallow(h);break

func collect(item:Node3D, h:Node3D) -> void:
	if phase!="playing":return
	h.award(item.points)
	eaten+=1
	if h==player:ping()

func scan_rivals() -> void:
	for large in holes:
		if not large.active:continue
		for small in holes:
			if small==large or not small.active or large.radius<small.radius*1.4:continue
			if large.position.distance_to(small.position)+small.radius*0.5<large.radius:
				large.award(maxi(5,int(small.score*0.3)))
				for item in city.foods:
					if is_instance_valid(item) and item.claimed_by==small:item.claimed_by=large
				small.retire()
				if small==player:finish("eaten");return
				if large==player:kills+=1

func level_up() -> void:
	notice="LEVEL UP!"
	notice_time=1.2

func finish(reason:String) -> void:
	if phase!="playing":return
	phase=reason
	for h in holes:h.enabled=false
	for item in city.foods:
		if is_instance_valid(item):item.freeze=true
	ui.refresh()

func back_home() -> void:
	get_tree().paused=false
	phase="title"
	if is_instance_valid(world):world.queue_free()
	holes.clear()
	ui.refresh()

func toggle_pause() -> void:
	if phase!="playing":return
	get_tree().paused=not get_tree().paused
	player.dragged=false
	player.touch_index=-1
	player.joystick=Vector2.ZERO
	ui.refresh()

func ping() -> void:
	if DisplayServer.get_name()=="headless":return
	var wav:=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=22050
	var bytes:=PackedByteArray()
	bytes.resize(1764*2)
	for i in 1764:bytes.encode_s16(i*2,int(sin(float(i)/22050*TAU*620)*pow(1-float(i)/1764,2)*6000))
	wav.data=bytes
	sound.stream=wav
	sound.play()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ENTER and phase=="title":start_level()
