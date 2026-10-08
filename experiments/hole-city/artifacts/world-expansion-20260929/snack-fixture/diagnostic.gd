extends SceneTree
var checks:=0
var failures:Array[String]=[]
var game:Node3D
var starting_count:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
	for i in n:await physics_frame
func mouth(at:Vector3,radius:float)->void:
	game.player.position=Vector3(at.x,0,at.z)
	if radius>=3.4:game.player.level=5;game.player.score=maxi(100,game.player.score)
	game.player.radius=radius;game.player._sync_shape()
func await_eaten(item:Node3D)->bool:
	for i in 360:
		await physics_frame
		if not is_instance_valid(item):return true
	return false
func run()->void:
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(2)
	var play:Button
	for control in game.ui.buttons:
		if control.text=="PLAY":play=control;break
	check(play!=null and play.text=="PLAY" and (play.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left>=24,"primary action uses the rounded bubble theme")
	check(game.ui.font.base_font.resource_path.ends_with("Fredoka.ttf"),"rounded typeface ships with the actual game UI")
	game.select_map("food");game.start_level();game.begin_play()
	game.set_physics_process(false);game.city.rain_enabled=false
	for h in game.holes:
		h.enabled=false
		if h!=game.player:h.active=false
	starting_count=game.city.foods.size()
	check(starting_count>650,"dense map has more than 650 physical edibles")
	check(game.city.towers.size()>=90,"at least 90 food buildings form connected urban blocks")
	check(game.city.mesh_cache.size()<=40 and game.city.batch_count<700 and game.city.batch_count>30,"shared food geometry uses spatial batches rather than one uncullable map-wide batch")
	var icing_colors:PackedColorArray=game.city.mesh_cache["donut_0"].surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(Array(icing_colors).any(func(c:Color):return c.r>.95 and c.g<.3 and c.b>.5),"saturated icing colors survive the shared food mesh path")
	check(game.city.food_kind_counts.size()==10 and game.city.citizens.size()==48,"ten food types and 48 animated citizens are present")
	# Normal-size mouths, normal scan and the live fleeing controller; no direct
	# begin_swallow shortcut or enlarged mouth can hide a pedestrian defect.
	for i in 2:
		var npc:Node3D=game.city.citizens[i].body
		mouth(npc.position,.85)
		var score:int=game.player.score
		game.city._process(0);game.scan_food()
		check(not npc.freeze and npc.claimed_by==game.player and game.player.score==score,"citizen %d loses support at the starting mouth size without early scoring"%i)
		check(await await_eaten(npc),"citizen %d falls and disappears through the normal food-map path"%i)
	var tower:Dictionary=game.city.towers[0]
	var base:Node3D=tower.base
	var upper:Node3D=base.supported_food[0]
	check(not upper.can_fit(game.player),"upper food floors cannot be plucked through intact lower floors")
	mouth(base.position,3.4);await frames(3)
	game.scan_food();await frames(12)
	check(not base.freeze and not upper.freeze and base.food_visual.visible and upper.food_visual.visible,"eating a foundation releases stacked food and restores moving visuals")
	check(await await_eaten(upper),"upper food floors physically fall into the hole")
	# Drop all ten recipes onto real solid ground first, then eat them.
	mouth(Vector3(-65,0,65),.85)
	var drops:Array[Node3D]=[]
	for i in 10:drops.append(game.city.spawn_rain(game.city.Shapes.KINDS[i],Vector2(71+(i%2)*5.0,43+(i/2)*6.0),12.0))
	var before:int=game.player.score
	await frames(240)
	for item in drops:
		if not is_instance_valid(item):continue
		var query:=PhysicsRayQueryParameters3D.create(item.position,item.position+Vector3.DOWN*20,3,[item.get_rid()])
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
		var support_body=hit.get("collider")
		print("RAIN_SUPPORT ",JSON.stringify({"kind":item.get_meta("food_kind"),"position":str(item.position),"support":str(support_body.name) if is_instance_valid(support_body) else "none","support_kind":support_body.get_meta("food_kind","terrain") if is_instance_valid(support_body) else "none","support_position":str(support_body.global_position) if is_instance_valid(support_body) else "none","footprint":support_body.get("footprint") if is_instance_valid(support_body) else null}))
	check(drops.all(func(b):return is_instance_valid(b) and not b.consumed and not is_instance_valid(b.claimed_by)),"food landing on the ground remains uncollected and awards no rain receipt")
	for i in drops.size():
		var item:Node3D=drops[i]
		check(is_instance_valid(item) and item.position.y>-.25 and item.position.y<2 and item.linear_velocity.length()<.5,"rain recipe %d lands and settles on solid ground"%i)
		if not is_instance_valid(item):continue
		mouth(item.position,1.5);await frames(3);game.scan_food()
		check(await await_eaten(item),"rain recipe %d is edible after landing"%i)
	game.city.rain_enabled=true
	for i in 30:game.city.update_rain(3.0)
	check(game.city.rain_bodies.size()<=game.city.RAIN_LIMIT,"rain registry is bounded")
	var airborne:int=game.city.rain_bodies.filter(func(b):return is_instance_valid(b) and not b.sleeping and not b.freeze).size()
	check(airborne<=game.city.AIRBORNE_LIMIT,"rain limits concurrent airborne physics bodies")
	var serial:int=game.city.rain_serial
	game.phase="intro";game.city.update_rain(10)
	check(game.city.rain_serial==serial,"rain stops outside active play")
	game.start_level()
	check(game.city.rain_serial==0 and game.city.rain_bodies.is_empty(),"restart clears the previous rain population")
	var result:={"checks":checks,"failures":failures,"initial_edibles":starting_count,"buildings":game.city.towers.size(),"types":10,"npc_count":48}
	print("SNACK_CITY_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
