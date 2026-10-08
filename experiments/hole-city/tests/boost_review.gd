extends SceneTree
## Non-author BOOST review: real viewport input and naturally scheduled movement.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var evidence:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for i in count:await process_frame
func ticks(count:int)->void:
	for i in count:
		await physics_frame
		await process_frame
func touch(id:int,at:Vector2,pressed:bool)->void:
	var e:=InputEventScreenTouch.new();e.index=id;e.position=at;e.pressed=pressed
	root.push_input(e,true);await frames()
func drag(id:int,at:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=id;e.position=at;e.relative=Vector2(48,0)
	root.push_input(e,true);await frames()
func control(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id:return b
	return null
func tap_control(id:String,finger:=1)->void:
	var b:=control(id)
	check(b!=null,"Actual control exists: "+id)
	if b==null:return
	var at:=b.get_global_rect().get_center()
	await touch(finger,at,true);await touch(finger,at,false)
func steering()->void:
	await touch(0,Vector2(115,615),true)
	await drag(0,Vector2(163,615))
func isolate_world()->void:
	game.set_physics_process(false)
	game.city.process_mode=Node.PROCESS_MODE_DISABLED
	for body in game.city.foods:
		if is_instance_valid(body) and body is RigidBody3D:body.freeze=true
	for h in game.holes:h.set_physics_process(false)
func motion(count:int)->float:
	var p=game.player
	var at:Vector3=p.position
	var distance:=0.0
	p.set_physics_process(true)
	# The following camera can curve a screen-space input path. Sum actual
	# per-tick travel rather than comparing the chord between its endpoints.
	for i in count:
		await physics_frame
		await process_frame
		distance+=p.position.distance_to(at)
		at=p.position
	p.set_physics_process(false)
	return distance
func prepared(radius:float)->void:
	var p=game.player
	p.position=Vector3(0,0,35);p.radius=radius;p._sync_shape()
	p.boost_time=0;p.speed_boost_time=0;p.pulse_cooldown=0;p.pulse_charge=100
	p.active=true;p.enabled=true;p.test_direction=Vector2.ZERO
func map_cases(map_id:String)->void:
	game.selected_map=map_id;game.start_level();await frames(3)
	game.player.set_physics_process(false);game.player.pulse_charge=100
	check(game.phase=="intro" and not game.player.trigger_pulse(),map_id+": intro cannot spend boost")
	game.begin_play();isolate_world()
	var p=game.player
	var rect:Rect2=control("pulse-action").get_global_rect()
	check(rect.size.x*375/540>=44 and rect.size.y*375/540>=44,map_id+": actual BOOST target meets phone touch size")
	await steering()
	check(p.touch_index==0 and is_equal_approx(p.joystick.length(),.6),map_id+": genuine partial steering is preserved")
	for radius:float in [.85,24.88]:
		prepared(radius)
		var normal:=await motion(18)
		var charges_before:int=game.resonance_count;var score_before:int=p.score
		await tap_control("pulse-action")
		check(p.touch_index==0 and is_equal_approx(p.joystick.length(),.6),map_id+": second finger does not steal analog steering")
		check(game.resonance_count==charges_before+1 and p.pulse_charge==0,map_id+": a complete real touch spends and activates once")
		check(p.boost_time==2.5 and p.pulse_cooldown==7,map_id+": independent duration/cooldown are armed")
		var charge_count:int=game.resonance_count
		p.pulse_charge=100
		await tap_control("pulse-action")
		check(game.resonance_count==charge_count and p.pulse_charge==100 and p.boost_time==2.5,map_id+": charged repeated tap does not extend active boost")
		p.position=Vector3(0,0,35)
		var faster:=await motion(18)
		check(normal>.2 and absf(faster/normal-1.55)<.005,map_id+": naturally scheduled movement scales exactly once at radius "+str(radius))
		check(p.score==score_before,map_id+": acceleration itself cannot award score")
		evidence.append({"map":map_id,"radius":radius,"joystick":.6,"ordinary_distance":normal,"boosted_distance":faster,"ratio":faster/normal})
	prepared(.85)
	# Release the original steering finger over the HUD; this must not leave a stuck joystick.
	await tap_control("pulse-action")
	await touch(0,rect.get_center(),false)
	check(p.touch_index==-1 and p.joystick==Vector2.ZERO,map_id+": release over BOOST ends the movement finger")
	check(await motion(6)<.0001,map_id+": BOOST does not propel an idle player")
	await steering()
	# Opposite order to the author fixture: Beacon is already running when BOOST starts.
	prepared(.85);p.skin_id="lantern";p.skin_cooldown=0
	check(p.trigger_skin_skill(),map_id+": Beacon activates before charged boost")
	await motion(10)
	var remaining_skin:float=p.speed_boost_time
	await tap_control("pulse-action")
	check(p.speed_boost_time==remaining_skin and p.boost_time==2.5,map_id+": boost does not reset Beacon's own remaining timer")
	await motion(1)
	var expected:=7.8/(1+.85*.05)*.6*1.55
	check(absf(p.velocity.length()-expected)<.003,map_id+": simultaneous skill and BOOST cannot multiply each other")
	await motion(150)
	check(p.boost_time==0 and p.speed_boost_time==0 and p.pulse_cooldown>0,map_id+": both boosts expire while their cooldowns remain meaningful")
	check(absf(p.velocity.length()-expected/1.55)<.003,map_id+": velocity returns to ordinary analog speed")
	p.pulse_charge=100
	await tap_control("pulse-action")
	check(p.boost_time==0 and p.pulse_charge==100 and game.ui.boost_button_state().phase=="cooldown",map_id+": food charge cannot bypass cooldown")
	await motion(280)
	check(p.pulse_cooldown==0 and game.ui.boost_button_state().phase=="ready",map_id+": natural cooldown eventually allows a new charged use")
	await tap_control("pulse-action")
	check(p.boost_time==2.5 and p.pulse_charge==0,map_id+": ready action works after expiry without resetting the round")
	# An independently active late Beacon continues after a nearly expired BOOST.
	p.boost_time=.08;p.skin_cooldown=0
	check(p.trigger_skin_skill(),map_id+": Beacon can begin late in a boost")
	await motion(10)
	check(p.boost_time==0 and p.speed_boost_time>0 and absf(p.velocity.length()-expected)<.003,map_id+": late Beacon survives BOOST expiry at the same capped speed")
	prepared(.85);await tap_control("pulse-action")
	p.set_physics_process(true)
	await tap_control("pause-action",2)
	check(paused and p.touch_index==-1 and p.joystick==Vector2.ZERO,map_id+": actual pause button releases movement")
	var remaining:float=p.boost_time;var cool:float=p.pulse_cooldown;var at:Vector3=p.position
	await ticks(20)
	check(p.boost_time==remaining and p.pulse_cooldown==cool and p.position==at,map_id+": pause freezes actual movement and both timers")
	p.pulse_charge=100
	check(not p.trigger_pulse() and p.pulse_charge==100,map_id+": paused calls cannot consume charge")
	var resume:Button
	for b in game.ui.buttons:
		if b.text=="KEEP PLAYING":resume=b
	check(resume!=null,map_id+": real pause resume control exists")
	await touch(2,resume.get_global_rect().get_center(),true)
	await touch(2,resume.get_global_rect().get_center(),false)
	p.set_physics_process(false)
	check(not paused and p.boost_time<=remaining and p.pulse_cooldown<=cool,map_id+": resume preserves rather than restarts the boost")
	for blocked in ["inactive","disabled","empty","cooldown","complete"]:
		prepared(.85)
		if blocked=="inactive":p.active=false
		if blocked=="disabled":p.enabled=false
		if blocked=="empty":p.pulse_charge=99.999
		if blocked=="cooldown":p.pulse_cooldown=.0001
		if blocked=="complete":game.phase="complete"
		var previous_charge:float=p.pulse_charge;var previous_count:int=game.resonance_count
		check(not p.trigger_pulse() and p.pulse_charge==previous_charge and game.resonance_count==previous_count,map_id+": invalid "+blocked+" activation has no payment or pulse")
		game.phase="playing"
	prepared(.85);await tap_control("pulse-action")
	game.start_level();await frames(3);isolate_world()
	check(game.player.boost_time==0 and game.player.pulse_cooldown==0 and game.player.pulse_charge==0,map_id+": fresh round starts without stale speed, charge or cooldown")
	game.back_home();await frames(3)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(4)
	game.set_physics_process(false)
	for map_id:String in ["city","food"]:await map_cases(map_id)
	game.audio.set_process(false) # Freeze pending route changes before decoder teardown.
	game.audio.music.stop();OS.delay_msec(150);await frames(4)
	game.free();await frames(3)
	print("BOOST_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"measurements":evidence,"scope":"Non-author actual input and natural CharacterBody physics; collection isolated to keep radius constant. No phone FPS, browser rendering or subjective feel claim."}))
	quit(0 if failures.is_empty() else 1)
