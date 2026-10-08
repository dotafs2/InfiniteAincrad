extends SceneTree
## Read-only runtime audit; --test prevents touching the player's saved progress.
var game:Node3D
var output:={"scope":"Headless simulation; no visual or GPU acceptance", "rain_samples":[]}
func _initialize()->void:run.call_deferred()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_physics_process(false);game.city.set_process(false)
	for h in game.holes:h.enabled=false;h.active=h==game.player
	output.initial_edibles=game.city.foods.size()
	output.buildings=game.city.towers.size()
	output.heaps=game.city.piles.size()
	var building_recipes:={};var points:=0;var within10:=0
	for tower in game.city.towers:
		building_recipes[tower.kind]=int(building_recipes.get(tower.kind,0))+1
		if tower.at.distance_to(Vector2(1,23))<10:within10+=1
	for body in game.city.foods:points+=body.points
	output.building_recipes=building_recipes;output.initial_available_points=points
	output.building_centers_within_10m_of_spawn=within10
	for tick in 4500:
		await physics_frame
		if (tick+1)%300==0:
			var alive:=0;var awake:=0;var landed:=0
			for body in game.city.rain_bodies:
				if not is_instance_valid(body):continue
				alive+=1
				if not body.freeze and not body.sleeping:awake+=1
				if body.linear_velocity.length()<.5:landed+=1
			output.rain_samples.append({"seconds":float(tick+1)/60.0,"spawned":game.city.rain_serial,"alive":alive,"awake":awake,"nearly_stationary":landed,"waves":game.city.rain_waves})
	game.set_physics_process(true);game.demo_mode=true
	game.start_level();game.begin_play()
	for hole in game.holes:
		if hole!=game.player:hole.retire()
	var before:={};var ticks:=0
	while game.phase=="playing" and ticks<13000:
		before.clear()
		for body in game.city.foods:
			if is_instance_valid(body) and not body.freeze:before[body.get_instance_id()]={"body":weakref(body),"y":body.position.y,"speed":body.linear_velocity.length(),"kind":body.get_meta("food_kind","npc")}
		await physics_frame;ticks+=1
	var intact:=0;var partly_consumed:=0;var all_consumed:=0
	for tower in game.city.towers:
		var remaining:=0
		for body in tower.tiers:
			if is_instance_valid(body):remaining+=1
		if remaining==tower.tiers.size():intact+=1
		elif remaining==0:all_consumed+=1
		else:partly_consumed+=1
	var frozen_on_finish:=[]
	for state in before.values():
		var body=state.body.get_ref()
		if is_instance_valid(body) and body.freeze and state.speed>.5:frozen_on_finish.append({"kind":state.kind,"y":state.y,"speed_before_finish":state.speed})
	output.solo_round={"phase":game.phase,"seconds":game.elapsed,"score":game.player.score,"level":game.player.level,"radius":game.player.radius,"food_receipts":game.food_collected,"buildings_intact":intact,"buildings_partly_consumed":partly_consumed,"buildings_consumed":all_consumed,"moving_food_frozen_on_result":frozen_on_finish}
	FileAccess.open("res://artifacts/reference-audit-20260928/food/probe.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t")+"\n")
	print("FOOD_REFERENCE_AUDIT "+JSON.stringify(output))
	game.free();await process_frame;quit()
