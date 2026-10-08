extends "res://tests/rival_combat_acceptance.gd"
## Actual gravity settlement and combat receipts exercise the cosmetic hooks.
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	game=load("res://fidelity/main.tscn").instantiate();game.selected_skin_id="tempest"
	root.add_child(game);game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.free()
	game.city=Arena.new();game.world.add_child(game.city)
	reset_arena();configure(game.player,60,Vector3.ZERO)
	var visual:Node3D=game.player.skin_visual
	var storm:Node3D=visual.tempest
	check(visual.fx_family=="tornado" and game.skin_definition("tempest").rarity=="prismatic","Real selected player builds the Prismatic tornado")
	check(storm.clouds.multimesh.instance_count==9,"Layered cloud bank batches all nine lobes in one MultiMesh")
	var initial_nodes:=storm.get_child_count()
	for i in 3:food(Vector3((i-1)*.45,1.0+i*.55,0),2)
	game.scan_food()
	check(storm.object_events==0 and game.player.score==60,"Admission does not manufacture a collection reward or completion burst")
	for frame in 180:
		await physics_frame
		game.scan_food()
		if storm.object_events==3:break
	check(storm.object_events==3 and game.player.score==66 and game.eaten==3,"Three physical props fall completely and trigger exactly three object effects")
	check(storm.rival_events==0 and not storm.shock.visible and not storm.lightning.visible,"Object receipts never cause the stronger rival shock or lightning")
	configure(game.holes[1],0,Vector3(.3,0,0));game.reset_rival_state();game.scan_rivals()
	check(storm.rival_events==1 and game.kills==1 and not game.holes[1].active,"Real rival containment invokes the storm burst exactly once")
	visual._process(.08)
	check(storm.shock.visible and storm.lightning.visible and storm.rival_energy>.8,"Rival burst has distinct lightning, an expanding ring and a longer pulse")
	var score:int=game.player.score
	game.scan_rivals();game.scan_rivals()
	check(storm.rival_events==1 and game.player.score==score,"Retired rivals cannot retrigger FX or score")
	configure(game.holes[2],1250,Vector3.ZERO);game.player_protected_until=100
	game.scan_rivals()
	check(storm.rival_events==1 and game.holes[2].active,"A larger rival is not falsely swallowed by the cosmetic funnel")
	var radius:float=game.player.radius
	for i in 1000:storm.absorb(i%7==0)
	check(storm.get_child_count()==initial_nodes and storm.pool.multimesh.instance_count==32 and storm.particles.size()==32,"A thousand receipts retain the fixed 32-slot pool and fixed node count")
	visual._process(2.0)
	check(not storm.shock.visible and not storm.lightning.visible and storm.particles.all(func(p):return p.age>=p.life),"All transient effects retire after their bounded lifetime")
	check(game.player.score==score and game.player.radius==radius,"Stress effects cannot change rewards or swallowing reach")
	check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Wind geometry never adds physics bodies")
	visual.build(game.skin_definition("cocoa_square"));visual._process(.2)
	check(visual.tempest==null and is_instance_valid(visual.common) and visual.fx_family=="cocoa_square","Switching to the authored Slate Ring frees the tornado and its pool")
	visual.build(game.skin_definition("tempest"));visual._process(.2)
	check(visual.tempest.object_events==0 and visual.tempest.rival_events==0 and visual.tempest.get_child_count()==initial_nodes,"Rebuild starts with no stale effects or node accumulation")
	var preview:Node3D=load("res://fidelity/skin_visual.gd").new();root.add_child(preview)
	preview.build(game.skin_definition("tempest"),true)
	check(is_instance_valid(preview.mouth) and not preview.mouth.visible,"Collection preview disables the opaque disk that clips cloud billboards")
	preview.free()
	var result:={"checks":checks,"failures":failures,"physical_objects":3,"physical_rivals":1,"pool_capacity":32,"scope":"Real headless falling-body and rival-contact events; cosmetic lifecycle and fixed pool. Rendering is verified separately on the Mac GPU."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("TEMPEST_SKIN_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
