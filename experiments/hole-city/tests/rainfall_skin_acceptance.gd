extends "res://tests/rival_combat_acceptance.gd"
## Exercise actual settlement/combat, generated water data and bounded effects.
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	game=load("res://fidelity/main.tscn").instantiate();game.selected_skin_id="rainfall"
	root.add_child(game);game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.free()
	game.city=Arena.new();game.world.add_child(game.city)
	reset_arena();configure(game.player,60,Vector3.ZERO)
	var visual:Node3D=game.player.skin_visual
	var rain:Node3D=visual.rainfall
	check(visual.fx_family=="rainfall" and game.skin_definition("rainfall").rarity=="prismatic","Actual selected player builds Prismatic Rainfall")
	var initial_nodes:=rain.get_child_count()
	var bake=load("res://fidelity/rainfall_bake.gd")
	check(rain.drops.multimesh.instance_count==48 and bake.DROP_DATA.size()==48,"Forty-eight scheduled raindrops use one fixed batch")
	check(rain.clouds.multimesh.instance_count==7 and rain.splash.multimesh.instance_count==24,"Cloud and burst allocations are bounded")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/skins/rainfall/bake-manifest.json"))
	check(manifest.period_seam_max_height_error<0.0000001 and manifest.courant_2d<.9,"Recorded PDE bake is stable and converged to a periodic loop")
	check(manifest.last_to_first_frame_delta<=manifest.max_ordinary_frame_delta,"Animation wrap has no exceptional temporal jump")
	check(manifest.frames==48 and manifest.period_seconds==3.0,"Runtime loop dimensions agree with the bake")
	var texture:Texture2D=rain.water.get_shader_parameter("wave_atlas")
	var imported:=texture.get_image();var source:=Image.load_from_file("res://assets/skins/rainfall/shallow_water_atlas.png")
	check(texture.get_width()==1584 and texture.get_height()==528,"The actual atlas has the expected padded tile layout")
	check(imported.get_data()==source.get_data() and not imported.has_mipmaps(),"Data atlas survives import exactly, with no alpha-border or mipmap corruption")
	var phases:={}
	for i in bake.DROP_DATA.size():
		var d:Vector4=bake.DROP_DATA[i];var pose:Transform3D=rain.drops.multimesh.get_instance_transform(i)
		var custom:Color=rain.drops.multimesh.get_instance_custom_data(i)
		check(Vector2(d.x,d.y).length()<.88 and Vector2(pose.origin.x,pose.origin.z).is_equal_approx(Vector2(d.x,d.y)),"Rain lands inside the pool at its baked position: %d"%i)
		# Compatibility packs instance data at reduced precision. Require sub-step
		# agreement rather than an impossible double-precision equality.
		check(absf(custom.r*3.0-d.z)<.002 and d.z>=0 and d.z<3.0,"GPU drop phase agrees with PDE forcing within two milliseconds: %d"%i)
		phases[d.z]=true
	check(phases.size()==48,"Rainfall phases are distributed, not a synchronized burst")
	for i in 3:food(Vector3((i-1)*.45,1.0+i*.55,0),2)
	game.scan_food()
	check(rain.object_events==0 and game.player.score==60,"Admission does not invent a collection or reward")
	# Physics speed is ordinary gravity; afterimages must never delay this receipt.
	for frame in 180:
		await physics_frame;game.scan_food()
		if rain.object_events==3:break
	check(rain.object_events==3 and game.player.score==66 and game.eaten==3,"Three real falling props settle and produce exactly three water responses")
	check(rain.rival_events==0 and not rain.shock.visible,"Ordinary items never create the larger rival burst")
	configure(game.holes[1],0,Vector3(.3,0,0));game.reset_rival_state();game.scan_rivals()
	check(rain.rival_events==1 and game.kills==1 and not game.holes[1].active,"Real rival containment triggers one splash burst")
	visual._process(.08)
	check(rain.shock.visible and rain.splash.multimesh.visible_instance_count==24,"Rival burst uses the existing fixed splash batch")
	var score:int=game.player.score;var radius:float=game.player.radius
	game.scan_rivals();game.scan_rivals()
	check(rain.rival_events==1 and game.player.score==score,"Retired rival cannot award twice")
	for i in 1000:rain.absorb(i%7==0)
	check(rain.get_child_count()==initial_nodes and rain.splash.multimesh.instance_count==24,"One thousand cosmetic triggers do not allocate extra nodes or particles")
	visual._process(2.0)
	check(not rain.shock.visible and rain.splash.multimesh.visible_instance_count==0,"Burst effects retire while ambient rain remains")
	check(game.player.score==score and game.player.radius==radius,"Cosmetic effects cannot change scores or eating reach")
	check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Shallow-water surface has no collision")
	visual.build(game.skin_definition("tempest"));visual._process(.2)
	check(visual.rainfall==null and visual.tempest!=null,"Switching to Tempest frees rain without changing the existing tornado")
	visual.build(game.skin_definition("rainfall"),true);visual._process(.2)
	check(visual.rainfall.object_events==0 and not visual.mouth.visible,"Rebuilding creates fresh effects and hides the old black preview disk")
	var result:={"checks":checks,"failures":failures,"physical_objects":3,"physical_rivals":1,"rain_instances":48,"splash_capacity":24,"scope":"Actual physics callbacks, data import and bounded lifecycle. Appearance is verified separately on Mac GPU."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("RAINFALL_SKIN_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
