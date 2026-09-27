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
	check(game.SKIN_DEFS.size()==10,"the first release defines ten skins")
	check(game.skin_ids("foundation").size()==5 and game.skin_ids("resonance").size()==5,"five cosmetic and five functional forms are grouped in the library")
	check(game.skin_unlocked("core_shell") and not game.skin_unlocked("copper_ring"),"score zero only unlocks the base form")
	game.start_level();game.begin_play();await frames(3)
	game.player.award(25)
	check(game.skin_progress>=25 and game.skin_unlocked("copper_ring") and not game.skin_unlocked("moss_bloom"),"sync progress unlocks forms at their per-run thresholds")
	check(game.select_skin("copper_ring") and game.selected_skin_id=="copper_ring","unlocked form can be equipped")
	game.start_level();game.begin_play();await frames(3)
	var candidate:Node3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):candidate=item;break
	if is_instance_valid(candidate):candidate.global_position=game.player.global_position+Vector3(2.0,0,0)
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.skin_cooldown>0.0,"Copper Draw activates and starts its cooldown")
	check(is_instance_valid(candidate) and candidate.pull_owner==game.player and candidate.pull_time>0.0,"Copper Draw marks a nearby object for the ordinary fall path")
	check(not game.player.trigger_skin_skill(),"a skin skill cannot be activated during cooldown")
	game.player.skin_cooldown=.15
	await frames(20)
	check(game.player.skin_cooldown<=0.0 and game.player.trigger_skin_skill(),"a functional skin can be reused after its cooldown expires")
	game.player.award(70)
	check(game.skin_unlocked("moss_bloom") and game.select_skin("moss_bloom"),"Moss Bloom unlocks at its threshold")
	game.start_level();game.begin_play();await frames(3)
	var bloom_target:RigidBody3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):bloom_target=item;break
	if is_instance_valid(bloom_target):bloom_target.global_position=game.player.global_position+Vector3(2.0,0,0)
	game.player.skin_cooldown=.12
	await frames(15)
	check(game.player.skin_cooldown>0.0 and is_instance_valid(bloom_target) and bloom_target.pull_owner==game.player,"Moss Bloom performs an automatic nearby catch on the live timer")
	game.player.award(120)
	check(game.skin_unlocked("gravitas") and game.select_skin("gravitas"),"Gravitas unlocks at its threshold")
	game.start_level();game.begin_play();await frames(3)
	var building:RigidBody3D=game.city.building_visuals[0].body
	building.global_position=game.player.global_position+Vector3(4.0,0,0)
	var building_before:Vector3=building.global_position
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.skin_cooldown>0.0,"Ground Thrum activates with a cooldown")
	check(building.global_position.distance_to(building_before)>.1,"Ground Thrum gives a nearby building a bounded physical nudge")
	game.player.award(240)
	check(game.skin_unlocked("shard") and game.select_skin("shard"),"Shard unlocks at its threshold")
	game.start_level();game.begin_play();await frames(3)
	var sweep_target:RigidBody3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):sweep_target=item;break
	if is_instance_valid(sweep_target):sweep_target.global_position=game.player.global_position+Vector3(2.0,0,0)
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.skin_cooldown>0.0,"Shard Sweep activates with its own cooldown")
	check(is_instance_valid(sweep_target) and sweep_target.pull_owner==game.player,"Shard Sweep marks a nearby object for the wider fall path")
	game.player.award(180)
	check(game.skin_unlocked("lantern") and game.select_skin("lantern"),"Lantern unlocks at its threshold")
	game.start_level();game.begin_play();await frames(3)
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.speed_boost_time>0.0,"Beacon Step activates a short movement boost")
	var lantern_start:Vector3=game.player.position
	game.player.test_direction=Vector2(1,0)
	await frames(12)
	game.player.test_direction=Vector2.ZERO
	check(game.player.position.distance_to(lantern_start)>.35,"Beacon Step produces visible movement in the live round")
	game.player.award(420)
	check(game.skin_unlocked("prism_vale") and game.select_skin("prism_vale"),"full sync unlocks the final cosmetic form")
	game.start_level();game.begin_play();await frames(3)
	check(game.player.skin_id=="prism_vale" and not game.player.trigger_skin_skill(),"a fresh round equips the cosmetic form without a gameplay skill")
	var result:={"checks":checks,"failures":failures,"skins":game.SKIN_DEFS.size(),"progress":game.skin_progress}
	print("SKIN_SKILL_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			out.store_string(JSON.stringify(result,"\t")+"\n")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
