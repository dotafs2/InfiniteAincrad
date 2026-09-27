extends Node3D
const Art=preload("res://fidelity/catalog_city.gd")
const Hole=preload("res://fidelity/hole.gd")
const UI=preload("res://fidelity/ui.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
const Asphalt=preload("res://fidelity/asphalt.gdshader")
## Authored first-season tuning. These values deliberately differ from the
## reference game's four-minute / 500-point loop.
const ROUND_SECONDS:=210.0
const SCORE_TARGET:=420
const WORLD_LIMIT:=76.0
const SKIN_DEFS:Array[Dictionary]=[
	{"id":"core_shell","name":"Core Shell","group":"foundation","unlock":0,"tint":"c85d3b","accent":"e2a956","skill_name":"STEADY SHELL","skill_short":"STEADY","skill_desc":"A dark vortex held by four glowing anchors. Visual only.","play_desc":"Learn the field and time Resonance well.","cooldown":0.0,"kind":"cosmetic"},
	{"id":"copper_ring","name":"Copper Ring","group":"resonance","unlock":25,"tint":"b86f52","accent":"e2a956","skill_name":"COPPER DRAW","skill_short":"DRAW","skill_desc":"Pull up to five nearby objects in one copper pulse.","play_desc":"Use the copper band beside a tight cluster, then let gravity finish.","cooldown":8.0,"kind":"draw"},
	{"id":"moss_bloom","name":"Moss Bloom","group":"resonance","unlock":70,"tint":"6c8f7a","accent":"a9d8b5","skill_name":"BLOOM CATCH","skill_short":"BLOOM","skill_desc":"Living leaves catch up to three nearby objects every 12 seconds.","play_desc":"Keep moving near props; the green catch happens by itself.","cooldown":12.0,"kind":"bloom"},
	{"id":"gravitas","name":"Gravitas","group":"resonance","unlock":120,"tint":"746f68","accent":"e2a956","skill_name":"GROUND THRUM","skill_short":"THRUM","skill_desc":"Gravity thrum vibrates every nearby building and shifts it slightly.","play_desc":"Trigger the weighted ring beside a cluster before swallowing the heap.","cooldown":12.0,"kind":"thrum"},
	{"id":"lantern","name":"Lantern","group":"resonance","unlock":180,"tint":"d9ad62","accent":"efe4ce","skill_name":"BEACON STEP","skill_short":"STEP","skill_desc":"Beacon glow gives a short speed surge for repositioning.","play_desc":"Tap SKILL, then steer the warm signal across open ground.","cooldown":9.0,"kind":"speed"},
	{"id":"shard","name":"Shard","group":"resonance","unlock":240,"tint":"8da6a3","accent":"c85d3b","skill_name":"SHARD SWEEP","skill_short":"SWEEP","skill_desc":"Ice-blue crystals sweep up to eight objects from a wider area.","play_desc":"Use the shard ring at the edge of a pile and let objects fall.","cooldown":11.0,"kind":"sweep"},
	{"id":"cinder","name":"Cinder","group":"foundation","unlock":300,"tint":"b66a4a","accent":"e2a956","skill_name":"EMBER MOTES","skill_short":"EMBER","skill_desc":"Living flames and rising embers surround the rift. Visual only.","play_desc":"Bring the heat. Your flames never change what you can swallow.","cooldown":0.0,"kind":"cosmetic"},
	{"id":"tide","name":"Tide","group":"foundation","unlock":340,"tint":"4d9aa0","accent":"a9d8b5","skill_name":"WAVE TRACE","skill_short":"WAVE","skill_desc":"Rippling water rings with drifting sea spray. Visual only.","play_desc":"A calm visual form for careful route planning.","cooldown":0.0,"kind":"cosmetic"},
	{"id":"orbit","name":"Orbit","group":"foundation","unlock":380,"tint":"6b6fb6","accent":"d9ad62","skill_name":"SATELLITE GLOW","skill_short":"ORBIT","skill_desc":"Three satellites circle a violet rift. Visual only.","play_desc":"Pick it for a clean, high-contrast silhouette.","cooldown":0.0,"kind":"cosmetic"},
	{"id":"prism_vale","name":"Prism Vale","group":"foundation","unlock":420,"tint":"d77c9b","accent":"7be4d7","skill_name":"PRISM DRIFT","skill_short":"PRISM","skill_desc":"A shifting rainbow with sparkling crystals. Visual only.","play_desc":"The full-sync reward for finishing the field.","cooldown":0.0,"kind":"cosmetic"}
]
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
var ads:Node
var resonance_count:=0
var resonance_pull_count:=0
var selected_skin_id:="core_shell"
var skin_progress:=0
var progress_dirty:=false
var progress_save_time:=0.0

func _ready() -> void:
	if not test_mode:
		var cfg:=ConfigFile.new()
		if cfg.load("user://reference-first-level.cfg")==OK:
			coins=int(cfg.get_value("progress","coins",50))
			gems=int(cfg.get_value("progress","gems",50))
			stage=int(cfg.get_value("progress","stage",1))
			skin_progress=clampi(int(cfg.get_value("progress","skin_progress",0)),0,SCORE_TARGET)
			var saved_skin:=str(cfg.get_value("progress","selected_skin_id","core_shell"))
			if skin_exists(saved_skin) and skin_progress>=int(skin_definition(saved_skin).unlock):selected_skin_id=saved_skin
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("102327")
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
	camera.fov=58
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
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
	ads=Ads.new()
	add_child(ads)
	ads.rewarded_completed.connect(revive_after_ad)
	ads.initialize()
	if demo_mode:start_level();begin_play()

func start_level() -> void:
	get_tree().paused=false
	if is_instance_valid(ui):ui.menu_screen="home"
	if is_instance_valid(world):world.free()
	holes.clear()
	phase="intro"
	remaining=ROUND_SECONDS
	elapsed=0
	eaten=0
	kills=0
	scan=0
	resonance_count=0
	resonance_pull_count=0
	world=Node3D.new()
	add_child(world)
	ground=CSGCombiner3D.new()
	ground.use_collision=true
	ground.collision_layer=1
	ground.collision_mask=1
	world.add_child(ground)
	var floor_shape:=CSGBox3D.new()
	floor_shape.size=Vector3(160,3,160)
	floor_shape.position.y=-1.5
	var mat:=ShaderMaterial.new()
	mat.shader=Asphalt
	floor_shape.material=mat
	ground.add_child(floor_shape)
	city=Art.new()
	world.add_child(city)
	city.build(self)
	total=city.foods.size()
	player=spawn_hole("Mica",Vector3(1,0,23),Color("c85d3b"),true)
	var names:=["Rowan","Lumen","Brine","Aster","Ember","Kite","Moss"]
	var colors:=[Color("a9d8b5"),Color("d9ad62"),Color("6c8f7a"),Color("c98068"),Color("e8c27d"),Color("8da6a3"),Color("b66a4a")]
	var starts:=[Vector3(-4,0,23),Vector3(-2,0,27),Vector3(9,0,24),Vector3(-8,0,32),Vector3(19,0,37),Vector3(-12,0,14),Vector3(22,0,14)]
	for i in 7:spawn_hole(names[i],starts[i],colors[i],false)
	update_camera(1.0,true)
	ui.refresh()

func spawn_hole(title:String, at:Vector3, tint:Color, human:bool) -> CharacterBody3D:
	var h:=Hole.new()
	h.game=self
	h.display_name=title
	h.skin_id=selected_skin_id if human else ""
	h.color=Color(skin_definition(selected_skin_id).tint) if human else tint
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
	if is_instance_valid(player) and player.skin_id=="moss_bloom":player.skin_cooldown=4.0
	ui.refresh()

func screen_direction(d:Vector2) -> Vector2:
	var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var back:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	return right*d.x+back*d.y

func _physics_process(delta:float) -> void:
	if progress_dirty and not test_mode:
		progress_save_time-=delta
		if progress_save_time<=0.0:save_player_progress()
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
	if is_instance_valid(player) and player.skin_id=="moss_bloom" and player.skin_cooldown<=0.0:activate_skin_skill(player,true)
	if player.score>=SCORE_TARGET:finish("complete")
	elif remaining<=0:finish("timeout")
	if demo_mode and phase=="playing":
		if not is_instance_valid(demo_target) or is_instance_valid(demo_target.claimed_by):demo_target=nearest_food(player)
		if is_instance_valid(demo_target):
			var gap:=Vector2(demo_target.position.x-player.position.x,demo_target.position.z-player.position.z)
			player.test_direction=gap.normalized()*clampf(gap.length()/0.4,0,1)

func _process(delta:float) -> void:
	if is_instance_valid(player) and phase in ["intro","playing"]:update_camera(delta)
	if is_instance_valid(player) and phase in ["intro","playing"]:update_hole_labels()
	if is_instance_valid(ui):ui.queue_redraw()

func update_hole_labels() -> void:
	if not is_instance_valid(camera):return
	# Keep the player's three-line badge readable, then admit nearby rival
	# badges only when their screen-space blocks do not collide. This affects
	# presentation only; all holes remain active and simulated.
	var ordered:Array[Node3D]=[]
	if is_instance_valid(player) and player.active:ordered.append(player)
	var rivals:Array[Node3D]=[]
	for h in holes:
		if not is_instance_valid(h) or not h.active or h==player:continue
		rivals.append(h)
	rivals.sort_custom(func(a:Node3D,b:Node3D)->bool:
		return a.global_position.distance_squared_to(player.global_position)<b.global_position.distance_squared_to(player.global_position))
	ordered.append_array(rivals)
	var accepted:Array[Dictionary]=[]
	for h in holes:
		if not is_instance_valid(h):continue
		h.label.visible=false
		h.name_tag.visible=false
		h.meter.visible=false
	for h in ordered:
		var screen:=camera.unproject_position(h.global_position+Vector3.UP*1.7)
		# Label3D has a wide outline and three lines. Reserve space for the
		# actual name length instead of forcing off-screen player tags visible.
		# The sector line is wider than the short display name, so reserve a
		# conservative block for all three billboard lines and their outline.
		var span:=clampf(72.0+float(h.display_name.length())*6.0,132.0,180.0)
		var on_screen:=screen.x>span+10.0 and screen.x<540.0-span-10.0 and screen.y>92.0 and screen.y<660.0
		var clear:=on_screen
		if clear:
			for other in accepted:
				if absf(screen.x-float(other.at.x))<span+float(other.span) and absf(screen.y-float(other.at.y))<58.0:
					clear=false
					break
		if clear:
			accepted.append({"at":screen,"span":span})
			h.label.visible=true
			h.name_tag.visible=true
			h.meter.visible=true

func update_camera(delta:float, instant:=false) -> void:
	var distance:float=1.0+(player.radius-0.85)*0.12
	var target:Vector3=player.position
	var offset:=Vector3(10,18,14)*distance
	camera.position=target+offset if instant else camera.position.lerp(target+offset,1-exp(-delta*6))
	camera.look_at(target)

func nearest_food(h:Node3D) -> Node3D:
	var found:Node3D
	var best:=INF
	for item in city.foods:
		if not is_instance_valid(item) or item.get_meta("resident",false) or not item.can_fit(h):continue
		var dist:float=item.global_position.distance_squared_to(h.global_position)
		if dist<best:best=dist;found=item
	return found

func scan_food() -> void:
	for item in city.foods:
		if not is_instance_valid(item) or item.get_meta("resident",false) or item.consumed or is_instance_valid(item.claimed_by):continue
		for h in holes:
			if not h.active or not item.can_fit(h):continue
			var d:=Vector2(item.position.x-h.position.x,item.position.z-h.position.z).length()
			# Wake while part of the base is still supported by the rim, so
			# asymmetric contact and gravity can tip the rigid body into the cut.
			if d<h.radius*0.90:item.begin_swallow(h);break

func activate_resonance(hole:Node3D) -> bool:
	if phase!="playing" or hole!=player:return false
	var influenced:=0
	var reach:=maxf(4.0,hole.radius*2.8)
	for item in city.foods:
		if influenced>=10:break
		if not is_instance_valid(item) or item.get_meta("resident",false) or item.consumed or is_instance_valid(item.claimed_by):continue
		if not item.can_fit(hole):continue
		if item.global_position.distance_to(hole.global_position)>reach:continue
		if item.begin_pull(hole):influenced+=1
	resonance_count+=1
	resonance_pull_count+=influenced
	notice="RESONANCE %02d"%influenced
	notice_time=1.2
	return true

func skin_definition(id:String)->Dictionary:
	for definition in SKIN_DEFS:
		if definition.id==id:return definition
	return SKIN_DEFS[0]

func skin_exists(id:String)->bool:
	for definition in SKIN_DEFS:
		if definition.id==id:return true
	return false

func skin_ids(group:String)->Array[String]:
	var ids:Array[String]=[]
	for definition in SKIN_DEFS:
		if definition.group==group:ids.append(definition.id)
	return ids

func skin_unlocked(id:String)->bool:
	return skin_exists(id) and skin_progress>=int(skin_definition(id).unlock)

func unlocked_skin_count(group:String)->int:
	var count:=0
	for id in skin_ids(group):
		if skin_unlocked(id):count+=1
	return count

func note_skin_progress(value:int) -> void:
	var previous:=skin_progress
	skin_progress=mini(SCORE_TARGET,maxi(skin_progress,value))
	if skin_progress!=previous:
		progress_dirty=true
		progress_save_time=maxf(progress_save_time,1.0)
	if skin_progress!=previous and is_instance_valid(ui):ui.queue_redraw()

func select_skin(id:String)->bool:
	if not skin_exists(id) or not skin_unlocked(id):return false
	selected_skin_id=id
	save_player_progress()
	if is_instance_valid(ui):ui.refresh()
	return true

func save_player_progress() -> void:
	if test_mode:return
	var cfg:=ConfigFile.new()
	cfg.load("user://reference-first-level.cfg")
	cfg.set_value("progress","skin_progress",skin_progress)
	cfg.set_value("progress","selected_skin_id",selected_skin_id)
	cfg.save("user://reference-first-level.cfg")
	progress_dirty=false
	progress_save_time=0.0

func pull_skin_objects(hole:Node3D, reach:float, limit:int)->int:
	var influenced:=0
	for item in city.foods:
		if influenced>=limit:break
		if not is_instance_valid(item) or item.get_meta("resident",false) or item.consumed or is_instance_valid(item.claimed_by):continue
		if not item.can_fit(hole) or item.global_position.distance_to(hole.global_position)>reach:continue
		if item.begin_pull(hole):influenced+=1
	return influenced

func activate_skin_skill(hole:Node3D, passive:=false)->bool:
	if phase!="playing" or hole!=player or not is_instance_valid(hole):return false
	var definition:=skin_definition(hole.skin_id)
	var kind:String=definition.kind
	if kind in ["cosmetic","none"]:return false
	if not passive and kind=="bloom":return false
	if hole.skin_cooldown>0.0:return false
	var used:=true
	var affected:=0
	match kind:
		"draw":affected=pull_skin_objects(hole,5.0,5)
		"bloom":affected=pull_skin_objects(hole,4.2,3)
		"sweep":affected=pull_skin_objects(hole,6.5,8)
		"thrum":
			for entry in city.building_visuals:
				var body:RigidBody3D=entry.body
				if not is_instance_valid(body) or is_instance_valid(body.claimed_by):continue
				var offset:Vector3=body.global_position-hole.global_position
				if Vector2(offset.x,offset.z).length()>20.0:continue
				var away:=Vector3(offset.x,0,offset.z).normalized()
				# Buildings begin frozen for the ordinary swallow model. A thrum is
				# deliberately a tiny authored presentation nudge, not a free-flight
				# impulse that could destabilize the city before a collapse.
				body.global_position+=away*.14
				body.rotation.y+=.018 if affected%2==0 else -.018
				affected+=1
		"speed":hole.speed_boost_time=.85
		_:used=false
	if not used:return false
	hole.skin_cooldown=float(definition.cooldown)
	if is_instance_valid(hole.skin_visual):hole.skin_visual.flash()
	notice=definition.skill_name+(" %02d"%affected if affected>0 else "")
	notice_time=1.2
	return true

func collect(item:Node3D, h:Node3D) -> void:
	if phase!="playing":return
	h.award(item.points)
	if h==player:note_skin_progress(h.score)
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
	save_player_progress()
	for h in holes:h.enabled=false
	for item in city.foods:
		if is_instance_valid(item):item.freeze=true
	ui.refresh()

func back_home() -> void:
	get_tree().paused=false
	phase="title"
	if is_instance_valid(ui):ui.menu_screen="home"
	if is_instance_valid(world):world.queue_free()
	holes.clear()
	ui.refresh()

func revive_after_ad() -> void:
	if phase!="eaten":return
	start_level()
	begin_play()
	notice="REVIVED"
	notice_time=1.5

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
		elif event.keycode==KEY_SPACE and phase=="playing" and is_instance_valid(player) and player.trigger_pulse():get_viewport().set_input_as_handled()
		elif event.keycode==KEY_Q and phase=="playing" and is_instance_valid(player) and player.trigger_skin_skill():get_viewport().set_input_as_handled()
