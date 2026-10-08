extends SceneTree
## Non-author mechanics review. Controlled fixtures do not claim normal play.
const Hole=preload("res://fidelity/hole.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
	for i in n:await physics_frame
func clean()->void:
	game.phase="playing";game.elapsed=20.0;game.kills=0;game.player_respawn_time=0;game.player_protected_until=10.0
	for h in game.holes:
		h.active=false;h.enabled=false;h.test_direction=Vector2.ZERO;h.target=null;h.settle_time=0.0
		h.score=0;h.level=1;h.ai_reward_tenths=0;h.radius=.85;h.position=Vector3(68,0,68)
	game.reset_rival_state()
func actor(index:int,radius:float,at:Vector3,points:=0)->Node3D:
	var h:Node3D=game.holes[index]
	h.active=true;h.radius=radius;h.position=at;h.score=points;h.level=Hole.level_for_score(points)
	return h
func growth_math()->void:
	var starts:Array[int]=[0,10,30,60,100,160,240,350,500,700,950,1250]
	for i in starts.size():
		check(Hole.level_for_score(starts[i])==i+1,"original level %d begins at its preserved score"%(i+1))
		if i>0:check(Hole.level_for_score(starts[i]-1)==i,"original score just below level %d stays below"%(i+1))
	# Independent recurrence: the first extension costs 350, then +50 per level.
	var expected:=1250;var increment:=350
	for level in range(13,93):
		expected+=increment;increment+=50
		check(Hole.level_start_for(level)==expected and Hole.level_for_score(expected)==level and Hole.level_for_score(expected-1)==level-1,"extended level %d matches accumulated independent costs"%level)
		check(Hole.radius_for_level(level)>Hole.radius_for_level(level-1) and Hole.radius_for_level(level)<48.0,"extended level %d grows below the physical world limit"%level)
	for score in [1000000,1000000000,1000000000000000,9223372036854775806,9223372036854775807]:
		var level:int=Hole.level_for_score(score)
		check(Hole.level_start_for(level)<=score and (Hole.level_start_for(level+1)>score or level==Hole.level_for_score(Hole.MAX_SCORE)),"large integer score has an exact enclosing level: %d"%score)
		var radius:float=Hole.radius_for_level(level)
		check(is_finite(radius) and radius>14 and radius<48,"large integer score yields bounded finite physical size")
		check(Hole.level_for_radius(radius)==level,"radius admission lookup returns the actual large-score level")
	check(Hole.level_for_radius(48.0)==0 and Hole.level_for_radius(INF)==0,"impossible or infinite required sizes have no fake level")
func reward_and_camera()->void:
	clean()
	var ai:Node3D=actor(1,.85,Vector3.ZERO)
	var total:=0
	for value in [1,1,1,1,1,1,1,1,1,1,7,11,35,101,240]:
		total+=value;ai.award(value)
		check(ai.score==int(total*7/10) and ai.ai_reward_tenths==(total*7)%10,"AI receipt fractions equal exact cumulative seventy percent at %d"%total)
	var before:int=ai.score;ai.award(-10)
	check(ai.score==before,"negative awards cannot lower AI score")
	var player:Node3D=actor(0,.85,Vector3.ZERO)
	player.award(Hole.MAX_SCORE);player.award(100)
	check(player.score==Hole.MAX_SCORE and player.level>12 and player.radius<48,"real player awards saturate numeric score safely without authored level cap")
	check(player.growth_progress().earned>=0 and player.growth_progress().cost>0,"extreme score keeps badge arithmetic nonnegative")
	player.score=0;player.level=1;player.radius=.85;player._sync_shape();game.update_camera(1,true)
	player.award(1000000000)
	game.update_camera(1.0/60.0,false)
	var fits:=true
	for i in 40:
		var theta:=TAU*float(i)/40
		if not game.camera.is_position_in_frustum(player.position+Vector3(cos(theta),0,sin(theta))*player.radius):fits=false
	check(fits,"non-instant camera preserves whole mouth immediately after a multi-level jump")
	check(game.camera.position.distance_to(player.position)+player.radius<game.camera.far,"non-instant extreme growth retains far-plane coverage")
func combat_boundaries()->void:
	clean();var p:=actor(0,1.15,Vector3.ZERO);var a:=actor(1,1.0,Vector3.ZERO)
	game.elapsed=0
	check(game.rival_size_allows(p,a),"player can eat a 15-percent-smaller rival during the opening")
	p.radius=1.14999
	check(not game.rival_size_allows(p,a),"player size threshold rejects just below 1.15")
	p.radius=1.0;a.radius=1.4
	check(not game.rival_size_allows(a,p),"opening protects the player even at otherwise sufficient enemy size")
	game.elapsed=10
	check(game.rival_size_allows(a,p),"player protection expires exactly at ten seconds")
	a.radius=1.39999
	check(not game.rival_size_allows(a,p),"AI needs the full forty-percent advantage against the player")
	var b:=actor(2,1.0,Vector3.ZERO);a.radius=1.2
	check(game.rival_size_allows(a,b),"AI-versus-AI uses the twenty-percent relation")
	a.radius=1.19999
	check(not game.rival_size_allows(a,b),"AI-versus-AI rejects just below its threshold")
	a.active=false
	check(not game.rival_size_allows(a,b) and not game.rival_size_allows(p,a),"inactive bodies can neither eat nor be eaten again")
	clean();p=actor(0,1.2,Vector3.ZERO,10);a=actor(1,.85,Vector3(.351,0,0))
	game.reset_rival_state();game.scan_rivals()
	check(a.active,"overlapping rims alone do not count as full mouth containment")
	a.position.x=.349;game.scan_rivals()
	check(not a.active and game.kills==1,"full small mouth containment succeeds at the actual reachable boundary")
	var score:int=p.score;game.scan_rivals();game.scan_rivals()
	check(game.kills==1 and p.score==score,"retired victim is never rewarded a second time")
	# A real sub-frame crossing has both endpoints outside the containment disk.
	clean();p=actor(0,1.2,Vector3.ZERO,10);a=actor(1,.85,Vector3(-.4,0,0))
	game.reset_rival_state();a.position.x=.4;game.scan_rivals(.1)
	check(not a.active and game.kills==1,"continuous collision catches a legal-speed crossing missed by endpoints")
	clean();p=actor(0,1.2,Vector3.ZERO,10);a=actor(1,.85,Vector3(-20,0,0))
	game.reset_rival_state();a.position.x=20;game.scan_rivals(1.0/60.0)
	check(a.active,"fixture teleports do not sweep through unrelated rival positions")
	# Crossing entirely while protected is not replayed at expiry.
	clean();p=actor(0,.85,Vector3(-.7,0,0));a=actor(1,1.5,Vector3.ZERO)
	game.elapsed=9.9;game.reset_rival_state();p.position.x=.7;game.elapsed=10.0;game.scan_rivals(.1)
	check(p.active and game.phase=="playing","expiry cannot replay a protected previous-to-current crossing")
	game.elapsed=10.1;p.position=Vector3.ZERO;game.scan_rivals(.1)
	check(not p.active and game.phase=="playing" and game.player_respawn_time==2.0,"A new actual contained contact after expiry eats player without ending timed run")
	var coins:int=game.coins;game.scan_rivals(.1)
	check(game.coins==coins,"completed combat cannot settle round rewards twice")
func ownership_chain()->void:
	clean()
	var middle:=actor(1,2.0,Vector3.ZERO,60)
	var victim:=actor(2,.85,Vector3.ZERO,10)
	var item:Node3D=game.city.foods.filter(func(f):return is_instance_valid(f) and not f.consumed and f.category!="building" and not f.get_meta("structural_shell",false))[0]
	item.claimed_by=victim;item.pull_owner=victim;item.fall_credit=victim
	var has_release:bool=item.get("release_hole")!=null or item.get_script()==preload("res://fidelity/food_body.gd")
	if has_release:item.release_hole=victim
	game.reset_rival_state();game.scan_rivals()
	check(not victim.active and middle.active,"intermediate AI retires the original owner")
	check(item.claimed_by==middle and item.pull_owner==middle and item.fall_credit==middle,"claim, pull and fallback credit all follow the surviving AI")
	if has_release:check(item.release_hole==middle,"delayed supported-tier release follows the surviving AI")
	var player:=actor(0,3.0,Vector3.ZERO,100)
	game.scan_rivals()
	check(not middle.active and player.active,"player can consume the intermediate owner")
	check(game.active_rival_owner(victim)==player and item.claimed_by==player and item.fall_credit==player,"two-hop owner chain routes deferred receipts to the living player")
	if has_release:check(item.release_hole==player,"delayed release owner follows a second retirement")
	# Exercise ordinary-item idempotent completion independently of building
	# admission, whose pending total is reserved by its own size-gated path. Geometry/fall depth is
	# independently covered by the pedestrian scene review, not fabricated here.
	var before:int=player.score;var points:int=item.points
	item.finish_swallow();item.finish_swallow()
	check(player.score==before+points and item.consumed,"two completion calls cannot duplicate one object's reward")
	var late:Node3D=game.city.foods.filter(func(f):return is_instance_valid(f) and not f.consumed)[0]
	before=player.score;game.collect(late,victim)
	check(player.score==before+late.points and not victim.active,"late callback to retired original owner is redirected exactly once by this callback")
	game.phase="complete";before=player.score;game.collect(late,victim)
	check(player.score==before,"result phase rejects any further delayed score mutation")
func actual_approach(map_id:String)->void:
	clean();var player:=actor(0,.85,Vector3.ZERO);player.award(10)
	var victim:=actor(1,.85,Vector3(3,0,0))
	game.elapsed=0;game.reset_rival_state();player.enabled=true;player.test_direction=Vector2.RIGHT
	var start:Vector3=player.position
	var tick:=0
	for step in 60:
		tick=step
		await physics_frame
		game.elapsed+=1.0/60.0;game.scan_rivals(1.0/60.0)
		if not victim.active:break
	player.enabled=false;player.test_direction=Vector2.ZERO
	check(not victim.active and game.kills==1,map_id+": actual player movement reaches and eats an AI mouth during spawn protection")
	check(player.position.distance_to(start)>2.0,map_id+": success uses actual controller travel, not fixture overlap")
	metrics[map_id+"_moving_capture"]={"frame":tick,"distance_m":player.position.distance_to(start),"radius":player.radius}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	growth_math()
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level();game.begin_play()
		game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for h in game.holes:h.enabled=false
		reward_and_camera();combat_boundaries();ownership_chain()
		await actual_approach(map_id)
	game.free();await process_frame
	var report:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent growth arithmetic and controlled real-scene combat review, with actual player movement on both maps. Scene updates are isolated for deterministic mechanic boundaries. Separate pedestrian review proves actual rigid-body collection. No save, browser or device-performance claim."}
	print("GROWTH_RIVALS_REVIEW "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
