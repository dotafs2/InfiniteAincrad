extends SceneTree

var checks:=0
var failures:Array[String]=[]
var game:Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count:int) -> void:
	for i in count:await physics_frame

func run() -> void:
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_level()
	game.begin_play()
	await frames(3)
	check(game.city.building_visuals.size()>=40,"city has a substantial building population")
	var styles:={}
	for entry in game.city.building_visuals:styles[entry.style]=true
	check(styles.size()>=4,"building silhouettes use multiple authored facade styles")
	check(game.city.moving_vehicles.size()==8,"street traffic loop has eight moving cars")
	var traffic:RigidBody3D=game.city.moving_vehicles[0].body
	var before:=traffic.position
	await frames(30)
	check(traffic.position.distance_to(before)>.05,"traffic car advances along its road lane")
	var target:RigidBody3D
	for item in game.city.foods:
		if is_instance_valid(item) and item.category=="building":
			target=item
			break
	check(is_instance_valid(target),"a building is available for the collapse interaction")
	game.player.radius=14.0
	game.player.position=Vector3(target.position.x,0,target.position.z)
	var started:bool=target.begin_swallow(game.player)
	check(started,"large hole can claim a building")
	check(is_instance_valid(target) and not target.consumed,"building keeps its facade before support loss")
	await frames(22)
	var fragments:Array=game.city.foods.filter(func(item):return is_instance_valid(item) and item.get_meta("building_fragment",false))
	check(fragments.size()>=16,"claimed building fractures into sixteen or more edible blocks")
	check(not is_instance_valid(target) or target.consumed,"original building is removed after fracture")
	check(fragments.all(func(item):return item.collision_mask==5 and item.collision_layer==4),"rubble keeps ground and fragment collision")
	var result:={"checks":checks,"failures":failures,"styles":styles.size(),"traffic":game.city.moving_vehicles.size(),"fragments":fragments.size()}
	print("DESTRUCTION_TRAFFIC_ACCEPTANCE "+JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
