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
	game.start_level()
	game.begin_play()
	await frames(3)
	check(game.city.signal_nodes.size()==5,"city builds five original signal pylons")
	check(game.city.authored_actor_type_count()==100,"world recipe catalog contains one hundred distinct actor types")
	check(game.city.actor_layout_source=="houdini_hom","actor positions use the local Houdini HOM layout export")
	check(game.city.world_actor_count()>=100,"running city contains more than one hundred live actors")
	check(game.ui.buttons.any(func(b:Button):return b.name=="pulse-action"),"playing HUD exposes resonance action")
	var resident:RigidBody3D=game.city.citizens[0].body
	check(resident.get_meta("resident",false) and resident.collision_layer==0 and resident.lock_rotation,"residents stay upright and outside swallow physics")
	var candidate:Node3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):
			candidate=item
			break
	if is_instance_valid(candidate):candidate.global_position=game.player.global_position+Vector3(2.2,0,0)
	var score_before:int=game.player.score
	game.player.pulse_charge=100.0
	var activated:bool=game.player.trigger_pulse()
	check(activated,"full resonance charge activates")
	check(game.player.pulse_charge==0.0 and game.player.pulse_cooldown>0.0,"activation consumes charge and starts cooldown")
	check(game.player.pulse_time>0.0 and game.resonance_count==1,"activation starts a bounded pulse window")
	check(game.player.score==score_before,"resonance does not award score directly")
	check(game.resonance_pull_count>=1 and game.resonance_pull_count<=10,"resonance marks nearby objects without exceeding its cap")
	await frames(8)
	check(game.player.pulse_time<.72,"pulse window decays with simulation time")
	check(not game.player.trigger_pulse(),"cooldown prevents immediate second activation")
	var result:={"checks":checks,"failures":failures,"pylons":game.city.signal_nodes.size(),"pulls":game.resonance_pull_count}
	print("RESONANCE_ACTION_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			out.store_string(JSON.stringify(result,"\t")+"\n")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
