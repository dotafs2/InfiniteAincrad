extends SceneTree
var game:Node3D
func _initialize()->void:run.call_deferred()
func frames(n:=2)->void:
	for i in n:await process_frame
func touch(id:int,at:Vector2,pressed:bool)->void:
	var e:=InputEventScreenTouch.new();e.index=id;e.position=at;e.pressed=pressed
	root.push_input(e,true);await frames()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(4)
	game.set_process(false);game.set_physics_process(false)
	game.start_level();game.begin_play();await frames()
	game.city.set_process(false);game.city.set_physics_process(false)
	for h in game.holes:h.set_physics_process(false)
	await touch(0,Vector2(160,600),true)
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(240,600);drag.relative=Vector2(80,0)
	root.push_input(drag,true);await frames()
	await physics_frame
	game.player._physics_process(1.0/60.0)
	var speed_before:float=game.player.velocity.length()
	game.player.pulse_charge=100
	await touch(1,Vector2(466,845),true);await touch(1,Vector2(466,845),false)
	game.player._physics_process(1.0/60.0)
	var result:={"speed_before":speed_before,"speed_after":game.player.velocity.length(),"charge_after":game.player.pulse_charge,"resonance_count":game.resonance_count,"speed_boost_time":game.player.speed_boost_time,"joystick_finger":game.player.touch_index}
	await touch(0,Vector2(466,845),false)
	result.joystick_after_release_over_boost=game.player.touch_index
	print("BOOST_BEFORE "+JSON.stringify(result))
	var out:=FileAccess.open("res://artifacts/feel-20260930/boost-before/result.json",FileAccess.WRITE);out.store_string(JSON.stringify(result,"\t")+"\n");out.close()
	game.audio.music.stop();await frames(3);game.free();await frames();quit()
