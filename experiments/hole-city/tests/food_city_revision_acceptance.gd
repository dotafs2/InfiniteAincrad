extends SceneTree
## Distinct edible silhouettes, close opening streets and branch-road deliveries.
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.active=h==game.player
	var city:Node3D=game.city;var urban=city.Neighborhoods;var plan:Dictionary=city.urban_plan
	var opening:=0;var families:Dictionary={};var nearest:=INF
	for i in city.towers.size():
		var tower:Dictionary=city.towers[i];families[tower.family]=true
		nearest=minf(nearest,tower.at.distance_to(Vector2(1,23)))
		if plan.plots[i].get("opening",false):
			opening+=1
			check(tower.at.distance_to(Vector2(1,23))<6,"Opening frontage is within six metres of the mouth")
			check(not urban.on_road(tower.at,float(plan.plots[i].radius)),"Opening shops leave roads clear")
			for route in plan.routes:check(urban.closest(tower.at,route).distance_to(tower.at)>=float(plan.plots[i].radius)+float(route.half_width),"Opening storefront keeps pedestrian passage")
	check(opening==2 and families.size()>=6,"Two composed opening shops and six distinct building families are present")
	var height_profiles:Dictionary={}
	for family in ["wedding_cake","wafer_gate","berry_water_tower"]:
		var tower:Dictionary=city.towers.filter(func(t):return t.family==family)[0]
		var roots:int=tower.tiers.filter(func(b):return not is_instance_valid(b.support_parent)).size()
		check(roots>1 if family!="wedding_cake" else roots==1,"Landmark silhouette has its intended independent structural roots: "+family)
		height_profiles[family]={"roots":roots,"height":tower.height,"pieces":tower.tiers.size()}
		game.player.level=8;game.player.score=500;game.player.radius=game.player.RADII[7];game.player.position=Vector3(tower.at.x,0,tower.at.y);game.player._sync_shape()
		for tick in 600:
			await physics_frame
			if tick%6==0:game.scan_food()
			if tower.tiers.all(func(b):return not is_instance_valid(b)):break
		check(tower.tiers.all(func(b):return not is_instance_valid(b)),"Every separate landmark piece physically falls and is collected: "+family)
	# Resolve an oversized upper piece: record actual motion rather than infer
	# support from a lower score or count.
	game.player.level=1;game.player.score=0;game.player.radius=.85;game.player.position=Vector3(-73,0,64);game.player._sync_shape()
	var base:Node3D=city.food("cookie",Vector2(-73,64),.38,1)
	var wide:Node3D=city.food("cake",Vector2(-73,64),1.15,5)
	wide.position.y=base.position.y+base.half_size.y+wide.half_size.y+.015;city.support(wide,base,1)
	var initial:Vector3=wide.position
	for tick in 90:
		await physics_frame
		if tick%6==0:game.scan_food()
		if tick in [24,59,89]:print("WIDE_REVIEW ",tick," ",wide.position if is_instance_valid(wide) else Vector3.ZERO," start ",initial," freeze ",wide.freeze if is_instance_valid(wide) else false," support ",is_instance_valid(wide.support_parent) if is_instance_valid(wide) else false)
	check(is_instance_valid(wide) and not wide.freeze and not is_instance_valid(wide.support_parent),"Oversized landmark part loses scripted support and remains physical")
	game.player.position=Vector3(75,0,75)
	var half:Vector3=city.moving_vehicles[1].body.half_size
	var off_road:=0
	for route_id in plan.traffic_routes.size():
		for step in int(urban.lane_length(route_id)*2):
			var pose:Dictionary=urban.lane_sample(step*.5,route_id);var f:Vector2=pose.forward;var side:=Vector2(f.y,-f.x)
			for sx in [-1,1]:
				for sz in [-1,1]:
					if not urban.on_road(pose.at+side*half.x*sx+f*half.z*sz):off_road+=1
	check(off_road==0,"Every full sushi footprint stays inside the actual road union on both loops")
	var branch_visits:Dictionary={};var overlaps:=0;var jumps:=0;var traveled:=0.0;var wraps:=0
	for tick in 3600:
		var previous:Array=[]
		for t in city.moving_vehicles:previous.append({"at":t.body.position,"progress":t.progress})
		city.update_traffic(.1)
		for i in city.moving_vehicles.size():
			var t:Dictionary=city.moving_vehicles[i];var at:=Vector2(t.body.position.x,t.body.position.z)
			var step:float=t.body.position.distance_to(previous[i].at);traveled+=step
			if step>float(t.speed)*.1+.005:jumps+=1
			if t.progress<previous[i].progress:wraps+=1
			for road in plan.roads:
				if road["class"]=="high_street" and urban.closest(at,road).distance_to(at)<1.7:branch_visits[road.name]=true
			for j in range(i+1,city.moving_vehicles.size()):
				if city.vehicles_overlap(t.body,city.moving_vehicles[j].body):overlaps+=1
	check(branch_visits.size()==5,"Real cars enter every one of the five authored branch streets")
	check(overlaps==0 and jumps==0 and traveled>6500 and wraps>=8,"Delivery convoys sustain continuous non-overlapping laps through junctions")
	metrics={"opening_frontages":opening,"nearest_building":nearest,"families":families.keys(),"landmarks":height_profiles,"off_road_footprints":off_road,"branches":branch_visits.keys(),"overlaps":overlaps,"jumps":jumps,"distance":traveled,"wraps":wraps,"traffic":city.moving_vehicles.map(func(t):return {"at":t.body.position,"progress":t.progress,"route":t.route_id})}
	print("FOOD_CITY_REVISION_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
