extends SceneTree
## Actual touch, notifications and physics frames; no device feel claim.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=3)->void:
	for _i in n:await process_frame
func notify(what:int)->void:
	game.notification(what)
	game.audio.notification(what)
func control(label:String)->Button:
	for button in game.ui.buttons:
		if button.text==label:return button
	return null
func tap(label:String)->void:
	var button:=control(label)
	check(button!=null,"The actual "+label+" control exists")
	if button==null:return
	var point:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var touch:=InputEventScreenTouch.new()
		touch.index=2;touch.position=point;touch.pressed=pressed
		root.push_input(touch,true);await frames()
func steer()->void:
	var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(170,900);touch.pressed=true
	root.push_input(touch,true);await frames()
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(215,850)
	root.push_input(drag,true);await frames()
func frozen(label:String)->void:
	var time:float=game.remaining;var elapsed:float=game.elapsed
	var at:Vector3=game.player.position;var cooldown:float=game.player.pulse_cooldown
	var boost:float=game.player.boost_time
	var score:int=game.player.score;var wallet:Vector2i=Vector2i(game.coins,game.gems)
	for _i in 12:await physics_frame
	check(game.remaining==time and game.elapsed==elapsed,label+": physics cannot spend round time")
	check(game.player.position==at,label+": the player cannot travel unattended")
	check(game.player.boost_time==boost and game.player.pulse_cooldown==cooldown,label+": boost duration and cooldown remain frozen")
	check(game.player.score==score and Vector2i(game.coins,game.gems)==wallet,label+": interruption cannot grant score or currency")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,1174);Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames()
	check(game.phase=="title" and not paused,"The ordinary menu starts unpaused")
	for map_id in ["city","food"]:
		game.select_map(map_id);await frames()
		await tap("PLAY");game.begin_play();await frames()
		check(game.remaining<=game.round_duration() and game.remaining>game.round_duration()-1,map_id+": the run starts with its full map duration")
		await steer()
		check(game.player.touch_index==0 and game.player.joystick.length()>0,map_id+": genuine screen input starts steering")
		game.player.pulse_charge=100;check(game.player.trigger_pulse(),map_id+": a real boost is armed before interruption")
		notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await frames()
		check(paused,map_id+": focus loss opens the pause state")
		check(game.player.touch_index==-1 and game.player.joystick==Vector2.ZERO and not game.player.dragged,map_id+": mouse and touch movement are released")
		check(game.player.velocity==Vector3.ZERO,map_id+": stale physical velocity is cleared")
		check(control("KEEP PLAYING")!=null,map_id+": the existing resume UI is shown")
		check(not game.audio.focused and game.audio.music.stream_paused,map_id+": music is suspended independently")
		await frozen(map_id+" focus loss")
		notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		notify(Node.NOTIFICATION_APPLICATION_PAUSED);await frames()
		check(paused,map_id+": duplicate focus and background notifications do not toggle pause off")
		notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await frames()
		await tap("KEEP PLAYING")
		check(paused,map_id+": focus-in alone cannot resume an outstanding app suspension")
		await frozen(map_id+" outstanding suspension")
		notify(Node.NOTIFICATION_APPLICATION_RESUMED);await frames()
		check(paused,map_id+": foreground return still requires the player's resume gesture")
		var before:float=game.remaining
		await tap("KEEP PLAYING")
		check(not paused and game.remaining<before,map_id+": real resume touch continues the existing timer")
		check(game.player.touch_index==-1 and game.player.joystick==Vector2.ZERO,map_id+": resume does not revive the old held finger")
		check(game.player.boost_time>0 and game.player.boost_time<2.5,map_id+": boost resumes without restarting its duration")
		game.toggle_pause();notify(Node.NOTIFICATION_APPLICATION_PAUSED)
		notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		notify(Node.NOTIFICATION_APPLICATION_RESUMED);await frames()
		await tap("KEEP PLAYING")
		check(paused,map_id+": resume-before-focus ordering cannot override focus loss")
		notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await frames()
		check(paused,map_id+": an existing manual pause survives app recovery")
		await tap("KEEP PLAYING")
		check(not paused,map_id+": recovered foreground allows an explicit resume")
		game.back_home();await frames()
		notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		notify(Node.NOTIFICATION_APPLICATION_PAUSED);await frames()
		check(game.phase=="title" and not paused,map_id+": a freed player/menu does not leave the tree paused")
		notify(Node.NOTIFICATION_APPLICATION_RESUMED);notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		check(not paused,map_id+": menu recovery stays responsive")
	game.start_level();await frames()
	notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.phase=="intro" and not paused and game.remaining==game.round_duration(),"An untouched intro has no hidden running timer or unreachable pause screen")
	notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game.begin_play()
	game.remaining=.01;await physics_frame;await frames()
	check(game.phase=="complete","The configured map expiry still settles normally after lifecycle recovery")
	notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	notify(Node.NOTIFICATION_APPLICATION_PAUSED);await frames()
	check(game.phase=="complete" and not paused and control("HOME")!=null,"Result navigation is not hidden behind an interruption pause")
	notify(Node.NOTIFICATION_APPLICATION_RESUMED);notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tap("HOME")
	check(game.phase=="title" and not paused,"Actual result HOME touch remains usable after recovery")
	# Fixed-FPS/headless time can outrun the independent audio mixer.
	# Drain only this test-owned loop before immediately ending the engine.
	game.audio.music.stop();OS.delay_msec(100)
	game.free();await frames();root.size=Vector2i(540,960)
	print("APPLICATION_LIFECYCLE_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"maps":["city","food"],"actual_touch":true,"notification_orderings":true,"device_acceptance":false}))
	quit(0 if failures.is_empty() else 1)
