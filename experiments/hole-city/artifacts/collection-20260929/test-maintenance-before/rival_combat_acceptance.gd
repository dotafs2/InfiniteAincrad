extends SceneTree
## Real hole controllers, physical ground and falling food run during pursuit.
## Boundary cases use explicit combat-history resets, never synthetic awards.
class Arena:
	extends Node3D
	var foods:Array[Node3D]=[]
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var original_hz:=60
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func reset_arena(time:=20.0)->void:
	game.set_physics_process(false);game.get_tree().paused=false;game.phase="playing";game.elapsed=time
	game.remaining=200;game.scan=0;game.kills=0
	for item in game.city.foods:
		if is_instance_valid(item):item.free()
	game.city.foods.clear()
	for h in game.holes:
		h.set_physics_process(false);h.active=false;h.enabled=false;h.target=null
		h.settle_time=0;h.settle_at=Vector3.ZERO;h.velocity=Vector3.ZERO;h.test_direction=Vector2.ZERO
		h.position=Vector3(65,0,65);h.score=0;h.collected=0;h.ai_reward_tenths=0
		h.level=1;h.radius=.85;h.show();h._update_badge()
	game.reset_rival_state()
func configure(h:Node3D,score:int,at:Vector3)->void:
	h.score=score;h.level=h.level_for_score(score);h.radius=h.radius_for_level(h.level)
	h.active=true;h.enabled=true;h.position=at;h._update_badge()
func food(at:Vector3,points:=1)->RigidBody3D:
	var item:RigidBody3D=load("res://fidelity/food_body.gd").new();item.game=game;item.category="prop";item.points=points;item.height=.25;item.footprint=.18
	var shape:=BoxShape3D.new();shape.size=Vector3(.25,.25,.25)
	var collision:=CollisionShape3D.new();collision.shape=shape;item.add_child(collision)
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=shape.size;mesh.mesh=box;item.add_child(mesh);item.food_visual=mesh
	game.city.add_child(item);item.position=at;game.city.foods.append(item)
	return item
func size_and_contact_fixture()->void:
	reset_arena(0)
	configure(game.player,1250,Vector3.ZERO);configure(game.holes[1],950,Vector3.ZERO)
	check(game.player.radius==14 and game.holes[1].radius==12,"Actual legacy LVL12/LVL11 radii reproduce the old impossible match")
	check(game.rival_size_allows(game.player,game.holes[1]),"Player LVL12 can eat clearly smaller LVL11")
	game.scan_rivals()
	check(not game.holes[1].active and game.kills==1,"Player can swallow a smaller rival during opening protection")
	var score:int=game.player.score;var count:int=game.player.collected
	game.scan_rivals();game.scan_rivals()
	check(game.player.score==score and game.player.collected==count and game.kills==1,"Repeated scans cannot award the same retired rival again")
	reset_arena(0)
	configure(game.holes[1],60,Vector3.ZERO);configure(game.holes[2],0,Vector3.ZERO)
	game.scan_rivals()
	check(not game.holes[2].active and game.holes[1].active,"AI can eat smaller AI during the player's opening protection")
	for relation in ["player_ai","ai_ai","ai_player"]:
		for offset in [-.0001,0.0,.0001]:
			reset_arena()
			var hunter:Node3D=game.player if relation=="player_ai" else game.holes[1]
			var victim:Node3D=game.player if relation=="ai_player" else game.holes[2]
			configure(hunter,0,Vector3.ZERO);configure(victim,0,Vector3.ZERO)
			var ratio:float=1.15 if relation=="player_ai" else 1.4 if relation=="ai_player" else 1.2
			hunter.radius=ratio+offset;victim.radius=1
			check(game.rival_size_allows(hunter,victim)==(offset>=0),relation+": exact ratio boundary %+f"%offset)
	reset_arena();configure(game.player,30,Vector3.ZERO);configure(game.holes[1],30,Vector3.ZERO)
	game.scan_rivals()
	check(game.player.active and game.holes[1].active,"Coincident equal-level holes cannot swallow each other")
	reset_arena();configure(game.player,60,Vector3.ZERO);configure(game.holes[1],0,Vector3(1.36,0,0))
	game.scan_rivals()
	check(game.holes[1].active,"Partial overlap is insufficient: the smaller complete circle must fit")
	game.holes[1].position.x=1.34;game.scan_rivals()
	check(not game.holes[1].active,"Full smaller-circle containment permits swallowing")
func protection_and_phase_fixture()->void:
	reset_arena(9.98);configure(game.holes[1],100,Vector3.ZERO);configure(game.player,0,Vector3.ZERO)
	game.holes[1].radius=1.4;game.player.radius=1.0
	game.reset_rival_state();game.scan_rivals(.016)
	check(game.player.active and game.phase=="playing","Larger AI cannot defeat the player during first ten seconds")
	game.player.position.x=.45;game.elapsed=10.01;game.scan_rivals(.03)
	check(game.player.active,"Protection expiry cannot replay earlier protected contact through swept history")
	game.player.position.x=.2;game.scan_rivals()
	check(not game.player.active and game.phase=="eaten","A sufficiently larger AI can defeat player after protection ends")
	var coins:int=game.coins;game.scan_rivals()
	check(game.coins==coins,"Repeated scan after player defeat cannot settle the result again")
	for stopped_phase in ["title","intro","complete","timeout","eaten"]:
		reset_arena();configure(game.player,100,Vector3.ZERO);configure(game.holes[1],0,Vector3.ZERO)
		game.phase=stopped_phase;game.scan_rivals()
		check(game.holes[1].active,"Combat is disabled outside play: "+stopped_phase)
	reset_arena();configure(game.player,100,Vector3.ZERO);configure(game.holes[1],0,Vector3.ZERO)
	game.get_tree().paused=true;game.scan_rivals()
	check(game.holes[1].active and game.auto_direction(game.holes[1],.1)==Vector2.ZERO,"Paused game neither eats nor steers rivals")
	game.get_tree().paused=false
func sweep_fixture()->void:
	for hz in [30,60,120]:
		reset_arena();configure(game.player,0,Vector3.ZERO);configure(game.holes[1],0,Vector3(-5.6/hz,0,0))
		game.player.radius=1.15;game.holes[1].radius=1.0;game.reset_rival_state()
		game.holes[1].position.x=5.6/hz;game.scan_rivals(1.0/hz)
		check(not game.holes[1].active,"%d Hz: crossing mouth is not missed between physics samples"%hz)
	reset_arena();configure(game.player,0,Vector3.ZERO);configure(game.holes[1],0,Vector3(-20,0,0))
	game.player.radius=1.15;game.holes[1].radius=1.0;game.reset_rival_state()
	game.holes[1].position.x=20;game.scan_rivals(1.0/60)
	check(game.holes[1].active,"Teleport across the map does not manufacture a swept swallow")
func snapshot_and_claim_fixture()->void:
	reset_arena();configure(game.player,29,Vector3.ZERO);configure(game.holes[1],0,Vector3.ZERO);configure(game.holes[2],10,Vector3.ZERO)
	game.scan_rivals()
	check(not game.holes[1].active and game.holes[2].active and game.player.radius==1.65,"One victory cannot unlock an additional size gate in the same scan")
	game.scan_rivals()
	check(not game.holes[2].active,"Growth from a real victory applies to the next physics scan")
	for reverse_order in [false,true]:
		reset_arena();configure(game.player,1250,Vector3.ZERO);configure(game.holes[1],950,Vector3.ZERO);configure(game.holes[2],0,Vector3.ZERO)
		var small:Node3D=game.holes[2]
		if reverse_order:game.holes.reverse()
		game.scan_rivals()
		check(game.player.score==1540 and game.kills==2 and game.rival_combat_events.size()==2,"Largest-first simultaneous combat awards each original victim once, array reversed=%s"%reverse_order)
		check(game.active_rival_owner(small)==game.player,"A dead intermediate rival cannot act or steal a victim")
		if reverse_order:game.holes.reverse()
	reset_arena();configure(game.player,100,Vector3.ZERO);configure(game.holes[1],0,Vector3.ZERO)
	var victim:Node3D=game.holes[1]
	var held:RigidBody3D=food(Vector3(40,4,40),3)
	held.claimed_by=victim;held.pull_owner=victim;held.fall_credit=victim;held.release_hole=victim
	game.scan_rivals()
	for field in ["claimed_by","pull_owner","fall_credit","release_hole"]:
		check(held.get(field)==game.player,"Captured opponent transfers pending "+field)
	var prior:int=game.player.score;var retired_score:int=victim.score
	game.collect(held,victim)
	check(game.player.score==prior+3 and victim.score==retired_score,"Late physical receipt resolves to the surviving owner")
func ai_choice_fixture()->void:
	reset_arena();configure(game.holes[1],30,Vector3.ZERO);configure(game.holes[2],0,Vector3(0,0,3))
	var hunter:Node3D=game.holes[1];var victim:Node3D=game.holes[2]
	var meal:RigidBody3D=food(Vector3(0,.125,6))
	var direction:Vector2=game.auto_direction(hunter,.016)
	check(direction.y>.9 and hunter.get_meta("rival_pursuit")==victim.get_instance_id(),"Active AI deliberately selects a nearby smaller rival over farther food")
	check(hunter.target==meal,"Food and rival targets remain separate object types")
	hunter.settle_time=.5;hunter.settle_at=Vector3(2,0,0)
	check(game.auto_direction(hunter,.1).x>.9 and hunter.get_meta("rival_pursuit")==0,"AI completes released-food settlement before switching to a rival")
	victim.active=false;hunter.settle_time=0
	check(game.choose_rival_prey(hunter)==null,"Inactive rivals are never hunting targets")
func moving_ai_fixture(hz:int)->void:
	reset_arena(0);Engine.physics_ticks_per_second=hz
	var hunter:Node3D=game.holes[1];var victim:Node3D=game.holes[2]
	configure(hunter,30,Vector3(0,0,0));configure(victim,0,Vector3(0,0,4))
	food(Vector3(0,.125,6))
	game.reset_rival_state();game.ground.sync()
	var hunter_start:Vector3=hunter.position;var victim_start:Vector3=victim.position
	var pursuit_frames:=0;var frames:=0;var hunter_distance:=0.0;var victim_distance:=0.0
	hunter.set_physics_process(true);victim.set_physics_process(true);game.set_physics_process(true)
	while victim.active and frames<hz*6:
		var prior_hunter:Vector3=hunter.position;var prior_victim:Vector3=victim.position
		await physics_frame
		frames+=1
		hunter_distance+=hunter.position.distance_to(prior_hunter);victim_distance+=victim.position.distance_to(prior_victim)
		if hunter.get_meta("rival_pursuit",0)==victim.get_instance_id():pursuit_frames+=1
	game.set_physics_process(false);hunter.set_physics_process(false);victim.set_physics_process(false)
	check(pursuit_frames>hz/2,"%d Hz: enabled hunter spends real physics frames actively pursuing prey"%hz)
	check(hunter_distance>3.0 and victim_distance>.8,"%d Hz: both AI controllers actually move; prey follows normal food behavior"%hz)
	check(not victim.active and hunter.active and game.rival_combat_events.size()==1,"%d Hz: real AI pursuit ends in one opponent swallow without direct scan setup"%hz)
	check(hunter.score>=33 and hunter.score<=35,"%d Hz: hunter receives only the legitimate reduced AI kill/food rewards"%hz)
	metrics.get_or_add("pursuit",[]).append({"hz":hz,"physics_frames":frames,"seconds":float(frames)/hz,"pursuit_frames":pursuit_frames,"hunter_distance":hunter_distance,"prey_distance":victim_distance,"prey_start":str(victim_start),"hunter_start":str(hunter_start),"hunter_score":hunter.score,"events":game.rival_combat_events.duplicate(true)})
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	original_hz=Engine.physics_ticks_per_second
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.free()
	game.city=Arena.new();game.world.add_child(game.city)
	size_and_contact_fixture();protection_and_phase_fixture();sweep_fixture();snapshot_and_claim_fixture();ai_choice_fixture()
	for hz in [30,60,120]:await moving_ai_fixture(hz)
	Engine.physics_ticks_per_second=original_hz
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Headless real controllers/physical pursuit plus geometric and lifecycle regressions; no browser or phone FPS claim."}
	print("RIVAL_COMBAT_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
