extends "res://tests/rival_combat_acceptance.gd"
## Real physics and callback regression for stable weather-family palette aliases.
## No user save is read or written; only --test enables this runner.
const RAIN_ALIAS:="rainfall__rose_rain"
const STORM_ALIAS:="tempest__cobalt_storm"
var weather_rows:Array[Dictionary]=[]
var timing_rows:Dictionary={}

func weather_setup(hz:int,id:String)->void:
	reset_arena();Engine.physics_ticks_per_second=hz
	game.selected_skin_id=id;game.player.skin_id=id
	game.player.skin_visual.build(game.skin_definition(id))
	game.player.skin_ring=game.player.skin_visual.main_ring
	configure(game.player,60,Vector3.ZERO);game.ground.sync()
	for i in 4:await physics_frame

func settlement(hz:int,id:String,move:=false)->Dictionary:
	await weather_setup(hz,id)
	var visual:Node3D=game.player.skin_visual
	var is_rain:bool=visual.model_id=="rainfall"
	var rain:Node3D=visual.rainfall if is_rain else null
	var intake:Node3D=rain.intake if is_rain else null
	var body:=food(Vector3(0,.65,0),7)
	var score:int=game.player.score
	var child_count:=body.get_child_count()
	check(body.begin_swallow(game.player),"%d Hz %s: actual prop admission succeeds"%[hz,id])
	check(game.player.score==score and not body.consumed,"Admission alone cannot award or consume: "+id)
	var admission:={"gravity":body.gravity_scale,"mass":body.mass,"layer":body.collision_layer,"mask":body.collision_mask,"rotation_locked":body.lock_rotation,"freeze":body.freeze}
	check(body.claimed_by==game.player and body.fall_credit==game.player and body.get("rainfall_float")==null,"Canonical owner/credit and ordinary gravity admission are retained: "+id)
	if is_rain:
		check(body.get_meta("rainfall_entry_watched",false) and intake.watched.size()==1 and intake.watched[0].get_ref()==body,"Actual rim-body admission watches the base or alias exactly once: "+id)
		intake.watch(body)
		check(intake.watched.size()==1 and intake.started_events==0,"Repeated presentation watch does not create a second entry: "+id)
	var ticks:=0;var moved:=false;var saw_handoff:=false
	while is_instance_valid(body) and ticks<hz*2:
		await physics_frame;ticks+=1
		if is_instance_valid(body) and not body.consumed:
			check(body.get_child_count()==child_count,"The actual falling body acquires no cosmetic child nodes: "+id)
			if body.get_meta("rainfall_entry_started",false):
				saw_handoff=true
				check(not body.visible,"Original model stays hidden after the only water entry: "+id)
		if move and intake!=null and intake.active_count()>0 and not moved:
			var active:Array=intake.slots.filter(func(slot):return slot.age<intake.DURATION)
			var slot:Dictionary=active[0]
			var before:Vector3=slot.node.global_position
			var offset:=Vector3(8,0,-3)
			game.player.position+=offset;game.ground.sync();moved=true
			check(slot.node.global_position.is_equal_approx(before+offset),"Alias entry stays attached to the moving hole: "+id)
	check(not is_instance_valid(body) and game.player.score==score+7,"Physical settlement retires and credits the object once: "+id)
	check(ticks<=hz,"Palette cannot delay the small prop beyond one second: "+id)
	if is_rain:
		var started:int=intake.started_events
		check(started<=1,"Physical base/alias collection cannot start more than one water handoff: "+id)
		if saw_handoff:check(started==1,"An observed handoff has exactly one start receipt: "+id)
		check(rain.object_events==1 and rain.contact_events==1,"Confirmed collection gives exactly one cosmetic water response: "+id)
		for i in hz/2:await physics_frame
		check(intake.started_events==started and intake.active_count()==0,"Collection does not replay a second falling object: "+id)
		check(intake.views.all(func(view):return view.mesh==null and not view.visible),"All borrowed entry render views are released: "+id)
		check(game.player.score==score+7,"Completed presentation cannot award a second score: "+id)
		if move:check(moved,"The moving-hole fixture exercised an active entry")
	return {"ticks":ticks,"admission":admission,"handoffs":intake.started_events if is_rain else 0}

func exact_handoff(id:String)->void:
	await weather_setup(60,id)
	var visual:Node3D=game.player.skin_visual
	var rain:Node3D=visual.rainfall
	var intake:Node3D=rain.intake
	var body:=food(Vector3(.2,.15,.1),7)
	body.rotation=Vector3(.03,.35,-.07)
	var original:MeshInstance3D=body.food_visual
	var original_transform:Transform3D=original.global_transform
	var position:Vector3=body.global_position;var velocity:Vector3=body.linear_velocity
	var score:int=game.player.score
	check(intake.start(body),"Live original starts one manual boundary handoff: "+id)
	var slot:Dictionary=intake.slots.filter(func(value):return value.source!=null)[0]
	check(slot.views[0].global_transform.is_equal_approx(original_transform),"First alias handoff frame exactly matches original geometry pose: "+id)
	check(slot.views[0].mesh==original.mesh and slot.views[0].material_override==original.material_override,"Alias uses the original prop material rather than tinting the meal: "+id)
	check(not body.visible and slot.views[0].is_visible_in_tree(),"Boundary handoff renders only one copy: "+id)
	check(body.freeze and not body.consumed and body.claimed_by==null and body.global_position==position and body.linear_velocity==velocity and game.player.score==score,"Cosmetic handoff does not move, claim, consume, unfreeze or award: "+id)
	check(not intake.start(body),"Already handed-off body cannot start twice: "+id)
	var previous_y:float=slot.node.position.y
	for i in 28:
		intake.advance(1.0/60.0)
		check(slot.node.position.y<=previous_y+.00001,"Alias cosmetic descent never rises or resets: "+id)
		previous_y=slot.node.position.y
	check(intake.active_count()==0 and not body.visible,"Completed cosmetic descent never reveals the still-live original: "+id)
	var starts:int=intake.started_events
	rain.confirmed_object(body);rain.confirmed_object(body)
	check(intake.started_events==starts and intake.active_count()==0 and game.player.score==score,"Late collection callbacks cannot replay geometry or award score: "+id)
	visual.build(game.skin_definition("core_shell"))
	check(body.visible and not is_instance_valid(intake),"Replacing alias skin restores a live unconsumed source and frees its pool: "+id)

func weather_family(id:String,family:String)->Dictionary:
	await weather_setup(60,id)
	var visual:Node3D=game.player.skin_visual
	var controller:Node3D=visual.rainfall if family=="rainfall" else visual.tempest
	check(visual.skin_id==id and visual.model_id==family and is_instance_valid(controller),"Owned alias keeps actual ID and routes its canonical weather controller: "+id)
	check(visual.common==null and visual.collection==null,"Weather is not also dispatched through a second feedback controller: "+id)
	var score:int=game.player.score;var radius:float=game.player.radius
	visual.begin_intake()
	check((controller.intake_energy>=.35 if family=="rainfall" else controller.object_energy>=.65) and controller.object_events==0 and controller.rival_events==0,"Base and alias retain native admission-energy callbacks without false awards: "+id)
	check(game.player.score==score and game.player.radius==radius,"Admission energy cannot change player strength: "+id)
	configure(game.holes[1],0,Vector3(.3,0,0));game.reset_rival_state();game.scan_rivals()
	check(controller.rival_events==1 and game.kills==1 and not game.holes[1].active,"One actual rival retirement invokes one canonical weather response: "+id)
	var rewarded:int=game.player.score
	game.scan_rivals();game.scan_rivals()
	check(controller.rival_events==1 and game.player.score==rewarded,"Repeated contact does not duplicate weather reward or FX: "+id)
	check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Weather family owns no physics bodies: "+id)
	var labels:Array=[]
	for size in [.85,2.2,14.0]:
		game.player.radius=size;game.player._sync_shape()
		labels.append([game.player.label.position,game.player.name_tag.position,game.player.meter.position,visual.scale])
	var camera:=Camera3D.new();root.add_child(camera)
	var frames:Array=[]
	for card in [true,false]:
		camera.position=Vector3(0,6.6,8);visual.frame_preview(camera,card)
		frames.append({"size":camera.size,"transform":camera.transform})
	camera.free()
	weather_rows.append({"id":id,"model_id":family,"rival_events":controller.rival_events,"score_delta":rewarded-score,"labels":str(labels),"camera_sizes":[frames[0].size,frames[1].size]})
	return {"labels":labels,"frames":frames}

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	original_hz=Engine.physics_ticks_per_second
	game=load("res://fidelity/main.tscn").instantiate();game.selected_skin_id="rainfall"
	root.add_child(game);game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
	check(game.progress_file().is_empty(),"--test has no live save target")
	game.city.free();game.city=Arena.new();game.world.add_child(game.city)
	for hz in [30,60,120]:
		var ordinary:Dictionary=await settlement(hz,"core_shell")
		var base:Dictionary=await settlement(hz,"rainfall")
		var alias:Dictionary=await settlement(hz,RAIN_ALIAS)
		check(base.admission==ordinary.admission and alias.admission==ordinary.admission,"%d Hz: base and alias keep identical actual collision/gravity admission"%hz)
		check(absi(int(base.ticks)-int(ordinary.ticks))<=1 and absi(int(alias.ticks)-int(ordinary.ticks))<=1,"%d Hz: base/alias settlement matches ordinary skin within one physics tick"%hz)
		timing_rows[str(hz)]={"ordinary":ordinary.ticks,"rainfall":base.ticks,"alias":alias.ticks}
	await settlement(60,RAIN_ALIAS,true)
	await exact_handoff("rainfall");await exact_handoff(RAIN_ALIAS)
	for pair in [["rainfall",RAIN_ALIAS],["tempest",STORM_ALIAS]]:
		var base:Dictionary=await weather_family(pair[0],pair[0])
		var alias:Dictionary=await weather_family(pair[1],pair[0])
		check(base.labels==alias.labels,"Palette alias preserves canonical label clearance and world scaling: "+pair[0])
		for index in 2:
			check(is_equal_approx(base.frames[index].size,alias.frames[index].size) and base.frames[index].transform.is_equal_approx(alias.frames[index].transform),"Palette alias keeps canonical card/detail camera: %s %d"%[pair[0],index])
	Engine.physics_ticks_per_second=original_hz
	var result:={"checks":checks,"failures":failures,"timing":timing_rows,"weather":weather_rows,"scope":"Muted isolated --test real falling-body/retirement callbacks, alias handoff and label/camera math. No GPU appearance or phone-performance claim; no real save or account access."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("WEATHER_VARIANTS_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
