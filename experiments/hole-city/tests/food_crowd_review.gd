extends SceneTree
## Independent food-map review of the inherited standing NPC controller.
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false;hole.active=false
	var metrics:Array[Dictionary]=[]
	for hz in [30,60,120]:
		for c in game.city.citizens:c.body.position=c.origin;c.body.rotation.y=2.17
		var bad_heading:=0;var moving:=0;var overlaps:=0;var escaped:=0;var minimum:=INF
		for tick in hz*20:
			if tick%(hz*4)==0:game.player.position=game.city.citizens[(tick/(hz*4))*7].body.position+Vector3(1.7,0,0)
			var prior:Array[Vector3]=[]
			for c in game.city.citizens:prior.append(c.body.position)
			game.elapsed=float(tick)/hz;game.city._process(1.0/hz)
			for i in game.city.citizens.size():
				var c:Dictionary=game.city.citizens[i]
				var velocity:Vector3=(c.body.position-prior[i])*hz
				if velocity.length()>.02:
					moving+=1
					if absf(angle_difference(c.body.rotation.y,atan2(velocity.x,velocity.z)))>deg_to_rad(15.05):bad_heading+=1
				var at:=Vector2(c.body.position.x,c.body.position.z)
				if not game.city.pedestrian_contains(c,at):escaped+=1
				for j in range(i+1,game.city.citizens.size()):
					var b:Node3D=game.city.citizens[j].body
					var distance:=at.distance_to(Vector2(b.position.x,b.position.z));minimum=minf(minimum,distance)
					if distance<.46:overlaps+=1
		check(moving>hz*100 and bad_heading==0,"Food-map moving NPCs face actual displacement at %dHz"%hz)
		check(overlaps==0 and escaped==0,"Food-map curved paths retain spacing and sidewalk safety at %dHz"%hz)
		metrics.append({"hz":hz,"samples":moving,"wrong_heading":bad_heading,"overlaps":overlaps,"escaped":escaped,"minimum_spacing":minimum})
	var route:int=game.city.citizens[0].walk_route
	var base:Vector3=game.city.citizens[0].body.position
	for i in 8:
		var c:Dictionary=game.city.citizens[i];c.walk_route=route;c.body.position=base
	game.city.separate_citizens()
	var dense_min:=INF
	for i in 8:
		var c:Dictionary=game.city.citizens[i]
		check(game.city.pedestrian_contains(c,Vector2(c.body.position.x,c.body.position.z)),"Dense-food-route correction stays on own path")
		for j in range(i+1,8):dense_min=minf(dense_min,c.body.position.distance_to(game.city.citizens[j].body.position))
	check(dense_min>=.46,"Eight coincident people separate on a constrained curved food route")
	var body:Node3D=game.city.citizens[0].body
	game.player.position=Vector3(body.position.x,0,body.position.z);game.player.active=true;game.player.radius=2;game.player._sync_shape()
	var prior:Vector3=body.position;game.city._process(1.0/60.0)
	check(not body.freeze and body.claimed_by==game.player,"A food-map crowd member transfers to gravity over the hole")
	check(Vector2(body.position.x-prior.x,body.position.z-prior.z).length()<.001,"Standing solver does not move a falling food-map NPC")
	print("FOOD_CROWD_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"dense_min":dense_min}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
