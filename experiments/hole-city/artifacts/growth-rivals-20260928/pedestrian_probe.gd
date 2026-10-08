extends SceneTree
## Actual scenes and physics, isolated attribution. Never writes player saves.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var cases:Array=[]
var receipts:Array=[]
var active_case:Dictionary={}
var source_hashes:Dictionary={}
const SOURCE_PATHS:=["fidelity/game.gd","fidelity/hole.gd","fidelity/catalog_city.gd","fidelity/food_city.gd","fidelity/food_body.gd","fidelity/rim_body.gd","fidelity/cut_ground.gd","fidelity/food_query.gd","scripts/swallowable.gd"]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
	for i in n:await physics_frame
func collected(item:Node3D,hole:Node3D)->void:
	if active_case.is_empty() or item.get_instance_id()!=active_case.target_id:return
	receipts.append({"case":active_case.name,"target_id":item.get_instance_id(),"hole_id":hole.get_instance_id(),"player_id":game.player.get_instance_id(),"points":item.points,"score_after":hole.score,"top_at_collect":item.global_position.y+item.vertical_extent(),"consumed":item.consumed,"claim_matches":item.claimed_by==hole,"frame":active_case.frame})
func one_case(map_name:String,grown:bool,role_index:int,chase:bool)->void:
	active_case={}
	game.selected_map=map_name;game.start_level();game.begin_play()
	for hole in game.holes:hole.active=false;hole.enabled=false
	game.player.position=Vector3(74,0,74)
	if grown:game.player.award(30)
	var roles:Array=[]
	for citizen in game.city.citizens:
		if not roles.has(citizen.kind):roles.append(citizen.kind)
	var kind:String=roles[mini(role_index,roles.size()-1)]
	var citizen:Dictionary=game.city.citizens.filter(func(c:Dictionary):return c.kind==kind)[0]
	var target:Node3D=citizen.body
	var prefix:="%s/%s/%s/%s"%[map_name,"grown" if grown else "starter",kind,"chase" if chase else "underfoot"]
	game.elapsed=float(citizen.get("rest_cycle",12.0))*2.0+2.0-float(citizen.phase)-float(citizen.get("rest_offset",0.0))
	var origin:Vector3=target.position
	await frames(40)
	var walked:float=Vector2(target.position.x-origin.x,target.position.z-origin.z).length()
	active_case={"name":prefix,"target_id":target.get_instance_id(),"kind":kind,"map":map_name,"radius":game.player.radius,"footprint":target.footprint,"height":target.height,"points":target.points,"motion_m":walked,"motion_clip":citizen.clip,"frame":0,"claim_frame":-1,"minimum_top":target.position.y+target.vertical_extent(),"entry_position":str(target.position),"rain_enabled":game.city.rain_enabled if map_name=="food" else false}
	check(walked>.02,prefix+": actual route controller moves the resident before approach")
	check(str(citizen.clip) in ["Walk","Run"],prefix+": imported locomotion is playing")
	check(target.can_fit(game.player),prefix+": real resident passes hole size and support gates")
	check(target.freeze and not is_instance_valid(target.claimed_by),prefix+": resident starts alive with route ownership")
	game.player.active=true
	var at:Vector3=target.interaction_position()
	game.player.position=Vector3(at.x+(3.0 if chase else 0.0),0,at.z)
	game.player.enabled=chase
	if not chase:check(game.city.scan_candidates(game.holes).has(target),prefix+": active-actor query includes the overlapping resident")
	var before_score:int=game.player.score
	var before_receipts:int=receipts.size()
	var released:=false
	var downward:=false
	var claim_seen:=false
	var chase_distance:=0.0
	for tick in 240:
		active_case.frame=tick
		var before:Vector3=game.player.position
		if chase and is_instance_valid(target):
			if is_instance_valid(target.claimed_by):game.player.test_direction=Vector2.ZERO;game.player.enabled=false
			else:
				var gap:Vector3=target.interaction_position()-game.player.position
				game.player.test_direction=Vector2(gap.x,gap.z).normalized()
		await physics_frame
		chase_distance+=game.player.position.distance_to(before)
		if not is_instance_valid(target):break
		if target.claimed_by==game.player:
			if not claim_seen:active_case.claim_frame=tick
			claim_seen=true
			released=released or not target.freeze
			downward=downward or target.linear_velocity.y<-.1
			active_case.minimum_top=minf(float(active_case.minimum_top),target.global_position.y+target.vertical_extent())
	active_case["chase_distance_m"]=chase_distance
	active_case["claim_seen"]=claim_seen
	active_case["physics_released"]=released
	active_case["downward_gravity_seen"]=downward
	active_case["target_freed"]=not is_instance_valid(target)
	active_case["score_delta_all_nearby_objects"]=game.player.score-before_score
	var own_receipts:Array=receipts.slice(before_receipts)
	active_case["receipts"]=own_receipts
	check(claim_seen and released,prefix+": normal scan or citizen opening check transfers claim and physics ownership")
	check(downward,prefix+": actual rigid body obtains downward velocity")
	check(own_receipts.size()==1,prefix+": exactly one actual collection receipt arrives within four seconds")
	if own_receipts.size()==1:
		check(own_receipts[0].hole_id==game.player.get_instance_id() and own_receipts[0].claim_matches,prefix+": receipt credits the player owning the fall")
		check(own_receipts[0].top_at_collect< -3.5 and own_receipts[0].consumed,prefix+": the full body actually crossed the collection depth")
	check(not is_instance_valid(target),prefix+": collected resident node is removed")
	check(game.player.score>=before_score+int(active_case.points),prefix+": score reflects the real collection")
	if chase:check(chase_distance>1.0,prefix+": actual player controller approaches the moving resident")
	cases.append(active_case.duplicate(true));active_case={}
	print("PEDESTRIAN_CASE "+JSON.stringify(cases.back()))
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for path in SOURCE_PATHS:source_hashes[path]=FileAccess.get_sha256("res://"+path)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.item_collected.connect(collected)
	for map_name in ["city","food"]:
		for grown in [false,true]:
			for role in 2:await one_case(map_name,grown,role,false)
		await one_case(map_name,false,0,true)
	var after:Dictionary={}
	for path in SOURCE_PATHS:after[path]=FileAccess.get_sha256("res://"+path)
	var result:={"checks":checks,"failures":failures,"cases":cases,"source_before":source_hashes,"source_after":after,"source_unchanged_during_run":source_hashes==after,"scope":"Actual current map, imported walking citizens, normal update/query/claim/ground/rigid-body/collect chain. Rival holes are inactive to isolate ownership. Underfoot cases place only the player at the resident; chase cases use the actual player controller. Grown score is a test setup award. Food rain remains enabled. No browser, visual or performance claim; no saves."}
	print("PEDESTRIAN_PROBE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
