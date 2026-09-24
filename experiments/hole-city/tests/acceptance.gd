extends SceneTree
## Runs actual game physics; never uses models, network or the town save.
var checks := 0
var failures: Array[String] = []
var game: Node3D
var ticks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for _i in count:await physics_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	check(game.phase == "title","main scene starts at title")
	check(game.total == 316,"complete seeded city has 316 edible objects")
	check(game.holes.size() == 1,"title has no running CPU contest")
	game.start_game("free")
	await frames(8)
	check(game.player.hole.get_parent() == game.ground,"copied CSG hole is owned by the live floor combiner")
	check(game.player.hole.operation == CSGShape3D.OPERATION_SUBTRACTION,"hole subtracts actual floor geometry")
	check(is_equal_approx(game.player.hole.radius,game.player.radius),"visual cut and game radius agree")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0,2,25),Vector3(0,-2.8,25),1)
	var solid_ray := PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-2.8,0),1)
	var space := game.get_world_3d().direct_space_state
	check(space.intersect_ray(ray).is_empty(),"center of hole has no ground collider")
	check(not space.intersect_ray(solid_ray).is_empty(),"ground still supports bodies outside the hole")
	var start: Vector3 = game.player.position
	var press := InputEventKey.new()
	press.physical_keycode = KEY_W
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	await frames(12)
	press.pressed = false
	Input.parse_input_event(press)
	check(game.player.position.z < start.z-0.5,"actual W input moves the player north")
	var big: Node3D
	var small: Node3D
	for item in game.city.foods:
		if item.category == "tower":big = item
		if item.category == "cone":small = item
	check(not big.can_fit(game.player),"initial hole cannot swallow a tower")
	game.player.position = Vector3(big.position.x,0,big.position.z)
	game._scan_food()
	check(not is_instance_valid(big.claimed_by),"oversize object remains solid when the hole passes underneath")
	game.player.position = Vector3(small.position.x,0,small.position.z)
	var before: int = game.player.score
	game._scan_food()
	check(small.claimed_by == game.player and not small.freeze,"fitting object is released to real rigid-body physics")
	check(game.player.score == before,"score is not awarded at initial contact")
	await frames(80)
	check(not is_instance_valid(small),"swallowed body is removed after falling below the ground")
	check(game.player.score > before,"completed fall awards score")
	check(game.player.radius > 1.15,"earned score grows the hole")
	var another: Node3D
	for item in game.city.foods:
		if is_instance_valid(item) and item.category=="cone" and not is_instance_valid(item.claimed_by):another=item;break
	another.begin_swallow(game.player)
	another.position.y = -10
	before = game.player.score
	another.finish_swallow()
	another.finish_swallow()
	check(game.player.score == before+another.points,"duplicate terminal callbacks award exactly once")
	await frames(2)
	game.player.position = Vector3(1000,0,-1000)
	await frames(2)
	check(absf(game.player.position.x)<39.0 and absf(game.player.position.z)<39.0,"movement is clamped to the playable city")
	game.toggle_pause()
	var time_before: float = game.elapsed
	await frames(8)
	check(game.elapsed == time_before,"pause freezes simulation time")
	game.toggle_pause()
	await frames(3)
	check(game.elapsed > time_before,"resume advances simulation time")
	game.start_game("round")
	await frames(3)
	check(game.holes.size()==4 and game.player.score==0 and game.eaten==0,"restart rebuilds city and CPU round without old scores")
	var cpu_start: Vector3 = game.holes[1].position
	await frames(60)
	check(game.holes[1].position.distance_to(cpu_start)>0.5,"CPU rival pursues food without player input")
	game.remaining = 0.04
	await frames(6)
	check(game.phase=="finished" and game.hud.modal_layer.visible,"round timeout presents results")
	game.start_game("round")
	await frames(3)
	game.player.award(400)
	game.holes[1].position = game.player.position
	game._scan_rivals()
	check(not game.holes[1].active,"large hole can swallow a smaller CPU rival")
	game.start_game("round")
	await frames(3)
	game.holes[1].award(400)
	game.holes[1].position = game.player.position
	game._scan_rivals()
	check(game.phase=="finished" and not game.player.active,"being swallowed ends the player's round")
	# Whole-city run uses normal movement, size gates, gravity and collection.
	# It does not grant points, teleport objects or remove the size checks.
	game.demo_mode = true
	game.start_game("free")
	Engine.time_scale = 3.0
	while game.phase=="playing" and ticks<8000:
		await physics_frame
		ticks += 1
		if ticks%600==0:
			print("FULL_RUN "+JSON.stringify({"ticks":ticks,"eaten":game.eaten,"score":game.player.score,"radius":game.player.radius,"elapsed":game.elapsed}))
	Engine.time_scale = 1.0
	check(game.eaten==316,"normal automated play can consume all 316 objects, including gardens and towers")
	check(game.phase=="finished","free roam ends with city-cleared results")
	var result := {"checks":checks,"failures":failures,"full_run_objects":game.eaten,"full_run_score":game.player.score,"full_run_seconds":game.elapsed,"full_run_ticks":ticks}
	print("SINK_CITY_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"\t")+"\n")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
