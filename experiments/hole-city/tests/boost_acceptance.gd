extends SceneTree
## Actual viewport touches and measured controller travel, with collection and
## rivals paused to keep the speed comparison at an identical radius.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var measurements:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=2)->void:
	for i in n:await process_frame
func touch(id:int,at:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=id;event.position=at;event.pressed=pressed
	root.push_input(event,true);await frames()
func tap_boost()->void:
	var button:Button
	for candidate in game.ui.buttons:
		if candidate.name=="pulse-action":button=candidate
	var at:Vector2=button.get_global_rect().get_center()
	await touch(1,at,true);await touch(1,at,false)
func drag_start()->void:
	await touch(0,Vector2(160,600),true)
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(240,600);drag.relative=Vector2(80,0)
	root.push_input(drag,true);await frames()
func travel(steps:int)->float:
	var start:Vector3=game.player.position
	for i in steps:
		await physics_frame
		game.player._physics_process(1.0/60.0)
	return game.player.position.distance_to(start)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	root.size=Vector2i(540,1174)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(4)
	game.set_process(false);game.set_physics_process(false)
	game.start_level();game.begin_play();await frames(3)
	game.city.process_mode=Node.PROCESS_MODE_DISABLED
	for h in game.holes:h.set_physics_process(false)
	var player=game.player
	var button:Button
	for b in game.ui.buttons:
		if b.name=="pulse-action":button=b
	check(button!=null and button.get_global_rect().has_point(game.ui.get_global_transform_with_canvas()*game.ui.responsive_point(Vector2(466,845))),"Actual tall-portrait BOOST touch target matches its drawn control")
	check(button.size.x*375.0/540.0>=44 and button.size.y*375.0/540.0>=44,"BOOST has at least a 44-point target at phone width")
	await drag_start()
	check(player.touch_index==0 and player.joystick.length()>=.99,"First real touch owns the movement joystick")
	player.pulse_charge=99.0
	await tap_boost()
	check(player.boost_time==0 and player.pulse_charge==99 and game.ui.toast=="Eat to charge your boost","Insufficient charge explains why a touch cannot activate")
	for radius:float in [.85,6.0,14.0]:
		player.radius=radius;player.position=Vector3.ZERO
		player.boost_time=0;player.speed_boost_time=0;player.pulse_cooldown=0;player.pulse_charge=100
		check(game.ui.boost_button_state().phase=="ready" and game.ui.boost_button_state().text=="GO!","Full charge shows an actionable ready state at radius "+str(radius))
		var normal:=await travel(30)
		var score_before:int=player.score
		var pulls_before:int=game.resonance_count
		await tap_boost()
		check(player.touch_index==0 and player.joystick.length()>=.99,"BOOST's second finger preserves steering at radius "+str(radius))
		check(player.pulse_charge==0 and game.resonance_count==pulls_before+1,"One physical tap spends charge exactly once and retains the bounded pull")
		check(player.boost_time==2.5 and player.pulse_cooldown==7.0,"BOOST grants the advertised duration and starts its cooldown")
		check(game.ui.boost_button_state().phase=="active" and game.ui.boost_button_state().caption=="BOOSTING","HUD distinguishes an active boost from an empty charge")
		check(player.score==score_before,"BOOST cannot grant score directly")
		player.position=Vector3.ZERO
		var boosted:=await travel(30)
		check(normal>1.0 and absf(boosted/normal-1.55)<.002,"Real movement travels 55 percent farther over equal physics steps at radius "+str(radius))
		check(absf(player.boost_time-2.0)<.002,"Active duration counts down in simulation time")
		var cooldown_before:float=player.pulse_cooldown
		player.pulse_charge=100
		await tap_boost()
		check(player.pulse_charge==100 and player.pulse_cooldown==cooldown_before and game.resonance_count==pulls_before+1,"Repeated touches cannot double-spend, extend or retrigger an active boost")
		check(game.ui.toast=="Boost active: +55% speed","Repeated touch explains the active state")
		await travel(125)
		check(game.ui.boost_button_state().phase=="cooldown" and game.ui.boost_button_state().caption=="RECHARGE","Expired boost exposes cooldown even if food has fully recharged it")
		await tap_boost()
		check(game.ui.toast.begins_with("Boost ready in ") and player.pulse_charge==100,"Cooldown rejection reports remaining time without spending charge")
		player.position=Vector3.ZERO
		var restored:=await travel(30)
		check(absf(restored/normal-1)<.002,"Base speed returns after boost expiry")
		measurements.append({"radius":radius,"normal_distance":normal,"boost_distance":boosted,"restored_distance":restored,"ratio":boosted/normal})
	player.radius=.85;player.position=Vector3.ZERO;player.pulse_charge=100;player.pulse_cooldown=0
	await tap_boost()
	player.skin_id="lantern";player.skin_cooldown=0
	check(player.trigger_skin_skill(),"Existing Beacon Step still activates during BOOST")
	await travel(1)
	check(player.boost_time>2.4 and is_equal_approx(player.velocity.length(),7.8*1.55/(1+.85*.05)),"Beacon Step neither shortens BOOST nor multiplies speed twice")
	await travel(60)
	check(player.speed_boost_time==0 and player.boost_time>1.4,"Charged boost continues after the independent skin timer expires")
	var remaining:float=player.boost_time
	var cooldown:float=player.pulse_cooldown
	player.set_physics_process(true)
	game.toggle_pause()
	for i in 12:await physics_frame
	check(player.boost_time==remaining and player.pulse_cooldown==cooldown,"Pause preserves actual node boost and cooldown timers")
	check(player.touch_index==-1 and not player.dragged,"Pause releases steering ownership")
	check(not player.trigger_pulse(),"Paused gameplay cannot start another boost")
	game.toggle_pause();player.set_physics_process(false)
	player.boost_time=0;player.pulse_cooldown=0;player.pulse_charge=100
	var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=true
	root.push_input(key,true);await frames()
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=false
	root.push_input(key,true);await frames()
	check(player.boost_time>0 and player.pulse_charge==0,"Keyboard Space reaches the same real boost action")
	player.boost_time=0;player.pulse_cooldown=0;player.pulse_charge=100
	for phase in ["intro","title","timeout","eaten"]:
		game.phase=phase
		check(not player.trigger_pulse() and player.pulse_charge==100,"No activation or payment outside gameplay: "+phase)
	game.phase="playing";player.active=false
	check(not player.trigger_pulse(),"Retired player cannot activate BOOST")
	# Fixed-fps headless frames can finish before the audio thread retires its
	# streamed decoder. Drain that owned playback before releasing the scene.
	game.audio.music.stop();OS.delay_msec(150);await frames(4);game.free();await frames()
	print("BOOST_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements,"scope":"Real portrait touch events, controller travel and pause lifecycle; headless CPU physics, not device FPS or browser visuals"}))
	quit(0 if failures.is_empty() else 1)
