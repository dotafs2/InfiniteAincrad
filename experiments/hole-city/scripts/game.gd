extends Node3D
const Hole = preload("res://scripts/hole.gd")
const City = preload("res://scripts/city.gd")
const HUD = preload("res://scripts/hud.gd")
const Street = preload("res://shaders/street.gdshader")
const ROUND_SECONDS := 120.0

var world: Node3D
var city: Node3D
var ground: CSGCombiner3D
var player: CharacterBody3D
var holes: Array[Node3D] = []
var camera: Camera3D
var hud: CanvasLayer
var phase := "title"
var mode := "round"
var remaining := ROUND_SECONDS
var elapsed := 0.0
var eaten := 0
var total := 0
var best := 0
var scan_clock := 0.0
var sound: AudioStreamPlayer
var muted := false
var status_note := ""
var status_time := 0.0
var demo_mode := false
var demo_clock := 0.0
var demo_target: Node3D
var screenshot_path := ""
var testing_mode := OS.get_cmdline_user_args().has("--test")

func _ready() -> void:
	_load_best()
	_environment()
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	sound = AudioStreamPlayer.new()
	sound.volume_db = -16.0
	add_child(sound)
	_build_world(false)
	hud.show_title()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): screenshot_path = arg.trim_prefix("--capture=")
		if arg == "--demo": demo_mode = true
	if demo_mode:
		start_game("free")
	if not screenshot_path.is_empty(): _capture_later()

func _environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a2cbd1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e1e9df")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58,-32,0)
	sun.light_color = Color("fff0d5")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 54.0
	camera.far = 300.0
	add_child(camera)
	camera.current = true

func _build_world(with_bots: bool) -> void:
	if is_instance_valid(world): world.free()
	holes.clear()
	world = Node3D.new()
	world.name = "PlayableCity"
	add_child(world)
	ground = CSGCombiner3D.new()
	ground.use_collision = true
	ground.collision_layer = 1
	ground.collision_mask = 1
	world.add_child(ground)
	var floor_mesh := CSGBox3D.new()
	floor_mesh.size = Vector3(78,3,78)
	floor_mesh.position.y = -1.5
	var mat := ShaderMaterial.new()
	mat.shader = Street
	floor_mesh.material = mat
	ground.add_child(floor_mesh)
	city = City.new()
	world.add_child(city)
	city.build(self)
	total = city.foods.size()
	player = _spawn_hole("You",Vector3(0,0,25),Color("54e4ce"),true)
	if with_bots:
		_spawn_hole("CPU Coral",Vector3(-28,0,-26),Color("ff8c7e"),false)
		_spawn_hole("CPU Violet",Vector3(27,0,-20),Color("b2a0ed"),false)
		_spawn_hole("CPU Gold",Vector3(23,0,22),Color("f4cd76"),false)
	camera.position = player.position + Vector3(0,42,32)
	camera.look_at(player.position)

func _spawn_hole(title: String, at: Vector3, tint: Color, human: bool) -> CharacterBody3D:
	var h := Hole.new()
	h.game = self
	h.display_name = title
	h.color = tint
	h.is_player = human
	ground.add_child(h)
	ground.add_child(h.hole)
	h.position = at
	holes.append(h)
	return h

func start_game(selected: String) -> void:
	get_tree().paused = false
	mode = selected
	phase = "playing"
	remaining = ROUND_SECONDS
	elapsed = 0.0
	eaten = 0
	scan_clock = 0.0
	status_note = "Start with cones and bins. Every bite makes you bigger."
	status_time = 7.0
	_build_world(mode == "round")
	for h in holes: h.enabled = true
	camera.size = 32.0
	hud.show_game()

func _physics_process(delta: float) -> void:
	if phase != "playing": return
	elapsed += delta
	remaining = maxf(0.0,remaining-delta)
	status_time = maxf(0.0,status_time-delta)
	scan_clock -= delta
	if scan_clock <= 0.0:
		scan_clock = 0.08
		_scan_food()
		if mode == "round" and elapsed > 10.0: _scan_rivals()
	if mode == "round" and remaining <= 0.0: finish("TIME'S UP")
	elif eaten >= total: finish("CITY CLEARED")
	if demo_mode:
		if not is_instance_valid(demo_target) or is_instance_valid(demo_target.claimed_by):
			demo_target = nearest_food(player)
		if is_instance_valid(demo_target):
			var gap := Vector2(demo_target.global_position.x-player.global_position.x,demo_target.global_position.z-player.global_position.z)
			player.test_direction = gap.normalized()*clampf(gap.length()/0.5,0.0,1.0)
		else:player.test_direction = Vector2.ZERO

func _process(delta: float) -> void:
	if is_instance_valid(player) and phase == "playing":
		var target := player.global_position
		camera.position = camera.position.lerp(target + Vector3(0,42,32),1.0-exp(-delta*5.0))
		camera.size = lerpf(camera.size,clampf(27.0+player.radius*4.0,32.0,70.0),1.0-exp(-delta*2.0))
		camera.look_at(Vector3(camera.position.x,0.0,camera.position.z-32.0))
	if is_instance_valid(hud): hud.update_hud()

func _scan_food() -> void:
	for item in city.foods:
		if not is_instance_valid(item) or item.consumed or is_instance_valid(item.claimed_by): continue
		for h in holes:
			if not h.active or not item.can_fit(h): continue
			var d := Vector2(item.global_position.x-h.global_position.x,item.global_position.z-h.global_position.z).length()
			if d + item.footprint <= h.radius * 0.99:
				item.begin_swallow(h)
				break

func nearest_food(h: Node3D) -> Node3D:
	var found: Node3D
	var best_distance := INF
	for item in city.foods:
		if not is_instance_valid(item) or not item.can_fit(h): continue
		var d: float = h.global_position.distance_squared_to(item.global_position)
		if d < best_distance:
			best_distance = d
			found = item
	return found

func collect(item: Node3D, h: Node3D) -> void:
	if phase != "playing": return
	h.award(item.points)
	eaten += 1
	if h.is_player:
		hud.pop_score(item.points,item.category)
		_ping(item.points)
		if h.collected == 1: announce("Good bite. Follow the street furniture to grow.")
		if h.score-item.points < 14 and h.score >= 14: announce("CARS UNLOCKED  /  Move right underneath them")
		if h.score-item.points < 78 and h.score >= 78: announce("BUILDING-SIZE  /  Time for a bigger lunch")
		if h.score-item.points < 500 and h.score >= 500: announce("CITY-SIZE  /  Nothing is too big now")

func _scan_rivals() -> void:
	for large in holes:
		if not large.active: continue
		for small in holes:
			if small == large or not small.active or large.radius < small.radius*1.35: continue
			var d := large.global_position.distance_to(small.global_position)
			if d+small.radius*0.7 < large.radius:
				large.award(maxi(12,int(small.score*0.4)))
				for item in city.foods:
					if is_instance_valid(item) and item.claimed_by == small: item.claimed_by = large
				small.retire()
				if small.is_player:
					finish("SWALLOWED!")
					return
				if large.is_player: announce("RIVAL SWALLOWED  /  " + small.display_name)

func announce(message: String) -> void:
	status_note = message
	status_time = 4.0

func toggle_pause() -> void:
	if phase != "playing": return
	get_tree().paused = not get_tree().paused
	player.dragged = false
	player.touch_index = -1
	player.joystick = Vector2.ZERO
	hud.show_pause(get_tree().paused)

func finish(reason: String) -> void:
	if phase != "playing": return
	phase = "finished"
	get_tree().paused = false
	for h in holes: h.enabled = false
	for item in city.foods:
		if is_instance_valid(item): item.freeze = true
	best = maxi(best,player.score)
	if not testing_mode:
		var config := ConfigFile.new()
		config.set_value("scores","best",best)
		config.save("user://sink-city.cfg")
	hud.show_results(reason)

func back_to_title() -> void:
	get_tree().paused = false
	phase = "title"
	_build_world(false)
	camera.size = 54.0
	hud.show_title()

func _load_best() -> void:
	if testing_mode:return
	var config := ConfigFile.new()
	if config.load("user://sink-city.cfg") == OK: best = int(config.get_value("scores","best",0))

func ranking() -> Array:
	var entries: Array = holes.duplicate()
	entries.sort_custom(func(a,b): return a.score > b.score)
	return entries

func _ping(value: int) -> void:
	if muted or DisplayServer.get_name() == "headless": return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(2205*2)
	var freq := 380.0+minf(value,40)*12.0
	for i in 2205:
		var t := float(i)/22050.0
		var envelope := pow(1.0-float(i)/2205.0,2.0)
		bytes.encode_s16(i*2,int(sin(t*TAU*freq)*envelope*7000.0))
	stream.data = bytes
	sound.stream = stream
	sound.play()

func _capture_later() -> void:
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(screenshot_path)
	print("SINK_CITY_CAPTURE " + screenshot_path)
	# Stop callbacks before destroying their world during the final draw frames.
	phase = "closing"
	set_process(false)
	set_physics_process(false)
	hud.queue_free()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
