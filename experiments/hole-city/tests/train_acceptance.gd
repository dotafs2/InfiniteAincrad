extends SceneTree
## Actual RimBody admission/falls with an isolated real-game terrain fixture.
const Train=preload("res://fidelity/edible_train.gd")
class Arena:
	extends Node3D
	var foods:Array[Node3D]=[]
	var food_queries=preload("res://fidelity/food_query.gd").new()
	func register_food(body:Node3D)->void:food_queries.register(body)
	func activate_food(body:Node3D)->void:food_queries.activate(body)
	func query_foods(at:Vector3,reach:float)->Array[Node3D]:return food_queries.query(at,reach)
	func scan_candidates(holes:Array)->Array[Node3D]:return food_queries.scan(holes)
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var receipts:Dictionary={}
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for i in count:await physics_frame
func collected(body:Node3D,hole:Node3D)->void:
	var id:=body.get_instance_id()
	receipts[id]={"count":int(receipts.get(id,{}).get("count",0))+1,"owner":hole,"top":body.global_position.y+body.vertical_extent()}
func reset_arena()->void:
	game.city.free();game.city=Arena.new();game.world.add_child(game.city)
	for hole in game.holes:
		hole.enabled=false;hole.active=false;hole.set_physics_process(false);hole.position=Vector3(70,0,70)
	game.player.active=true;game.phase="playing";game.remaining=220;game.elapsed=10
	game.ground.sync();receipts.clear()
func circle(radius:=14.0)->Array[Vector2]:
	var points:Array[Vector2]=[]
	for i in 256:points.append(Vector2(cos(i*TAU/256),sin(i*TAU/256))*radius)
	return points
func specs(count:=8,size:=Vector3(1.05,1.1,1.55))->Array[Dictionary]:
	var mesh:=BoxMesh.new();mesh.size=size
	var result:Array[Dictionary]=[]
	for i in count:result.append({"mesh":mesh,"category":"sushi","points":7})
	return result
func spawn(count:=8,size:=Vector3(1.05,1.1,1.55),radius:=14.0):
	var train:=Train.new()
	check(train.build(game,game.city,circle(radius),specs(count,size),6.4),"Train builds separate real bodies on an arc-length loop")
	return train
func mouth(body:Node3D,hole:Node3D)->void:
	hole.active=true;hole.radius=body.footprint*1.08+.25;hole._sync_shape();hole.position=Vector3(body.position.x,0,body.position.z)
	game.ground.sync()
func wait_eaten(body:Node3D)->bool:
	for i in 420:
		await physics_frame
		if not is_instance_valid(body):return true
	return false
func wait_eaten_while_running(body:Node3D,train)->bool:
	for i in 420:
		train.step(1.0/60.0)
		await physics_frame
		if not is_instance_valid(body):return true
	return false
func overlap(a:Node3D,b:Node3D)->bool:
	var delta:=Vector2(a.position.x-b.position.x,a.position.z-b.position.z)
	var af:=Vector2(a.basis.z.x,a.basis.z.z);var ar:=Vector2(a.basis.x.x,a.basis.x.z)
	var bf:=Vector2(b.basis.z.x,b.basis.z.z);var br:=Vector2(b.basis.x.x,b.basis.x.z)
	for axis in [af,ar,bf,br]:
		var arad:float=absf(axis.dot(af))*a.half_size.z+absf(axis.dot(ar))*a.half_size.x
		var brad:float=absf(axis.dot(bf))*b.half_size.z+absf(axis.dot(br))*b.half_size.x
		if absf(delta.dot(axis))>=arad+brad:return false
	return true
func chain_and_motion()->void:
	reset_arena();var train=spawn();await frames(2)
	check(game.city.foods.size()==8 and train.couplers.size()==7,"Eight independent registry entries have seven visual-only couplers")
	for body in train.cars:
		check(body.get_parent()==game.city and body.get_meta("scripted_actor") and body.get_meta("train_car"),"Each section owns one independent queryable body")
		check(game.city.query_foods(body.position,.2).has(body),"Dynamic registry resolves the current moving car position")
		check(body.half_size.is_equal_approx(Vector3(.525,.55,.775)),"Single-car dimensions never use whole-train bounds")
	var before:Transform3D=train.cars[0].transform
	for phase in ["intro","title","complete","timeout"]:
		game.phase=phase;train.step(1.0)
		check(train.cars[0].transform==before,"Route is frozen outside play: "+phase)
	game.phase="playing";paused=true;train.step(1.0);paused=false
	check(train.cars[0].transform==before,"Tree pause freezes routing even when step is invoked")
	for hz in [30,60,120]:
		var distance:float=train.traveled
		for i in hz:train.step(1.0/hz)
		check(absf(train.traveled-distance-6.4)<.02,"Head actual arc speed is frame-rate stable at %d Hz"%hz)
	var maximum_jump:=0.0;var previous:Vector3=train.cars[0].position
	for i in 1700:
		train.step(1.0/60);maximum_jump=maxf(maximum_jump,previous.distance_to(train.cars[0].position));previous=train.cars[0].position
	check(train.head_distance>train.route_length*2 and maximum_jump<.108,"Two complete loops cross the seam without teleporting")
	check(train.history.size()<300 and not train.blocked,"Head history is bounded by live train length")
	metrics["loop"]=train.diagnostics()
func cut_and_fall(index:int,enemy:=false)->void:
	reset_arena();var train=spawn();await frames(2)
	for i in 90:train.step(1.0/60)
	await frames(2)
	var target:Node3D=train.cars[index];var id:=target.get_instance_id()
	var owner:Node3D=game.holes[1] if enemy else game.player
	var score:int=owner.score;var poses:Array[Transform3D]=[]
	for body in train.cars:poses.append(body.global_transform)
	owner.radius=target.footprint*1.08-.001
	check(not target.begin_swallow(owner) and train.attached_count==8,"Rejected size admission cannot sever the chain")
	mouth(target,owner);await frames(3);game.scan_food()
	check(target.claimed_by==owner and train.attached_count==index,"Normal scan independently claims car %d and cuts all downstream"%index)
	check(owner.score==score,"Severing a train does not award points before descent")
	for i in range(index+1,8):
		check(train.cars[i].global_transform==poses[i] and train.cars[i].freeze and not train.cars[i].attached,"Downstream car keeps its exact stopped pose")
	for i in train.couplers.size():check(train.couplers[i].visible==(i+1<index),"Disconnected visual coupling disappears immediately")
	check(await wait_eaten(target),"Admitted car completes a real RimBody gravity fall")
	check(receipts.has(id) and receipts[id].count==1 and receipts[id].owner==owner and receipts[id].top< -3.5,"Exactly one legitimate owner receipt follows complete physical descent")
	if index==0:
		train.step(3.0);check(train.attached_count==0 and train.traveled>0,"Eating the head leaves the whole trailing chain parked")
	else:
		owner.position=Vector3(70,0,70);game.ground.sync();await frames(2)
		var start:float=train.head_distance
		for tick in ceili(train.route_length*2.3/6.4*30):train.step(1.0/30)
		check(train.head_distance-start>train.route_length*2,"Remaining head completes two laps past the parked tail")
		check(not train.blocked,"A single cut has a collision-checked bypass, not a permanent head stop")
		for i in range(index+1,8):check(train.cars[i].global_transform==poses[i],"Parked tail never moves, respawns or rejoins on later laps")
		check(receipts[id].count==1,"Later laps cannot duplicate the consumed car receipt")
	metrics["cut_%d_%s"%[index,enemy]]=train.diagnostics()
func pull_and_reclaim()->void:
	reset_arena();var train=spawn(4,Vector3(1.25,1.35,2.15));await frames(2)
	var body:Node3D=train.cars[2];var id:=body.get_instance_id();var tail:Transform3D=train.cars[3].global_transform
	game.player.radius=2;game.player.position=body.position+Vector3(3,0,0)
	check(body.begin_pull(game.player) and train.attached_count==2,"Pulling a middle section severs before any route movement")
	var events:int=train.detach_events.size();body.begin_pull(game.player)
	check(train.detach_events.size()==events and train.cars[3].global_transform==tail,"Repeated pulling is idempotent and preserves tail pose")
	await frames(60)
	check(not body.attached and body.freeze==false,"Pull expiration does not reattach or tether the body")
	game.player.position=Vector3(70,0,70)
	mouth(body,game.holes[1]);await frames(3);game.scan_food()
	check(body.claimed_by==game.holes[1],"Reclaim fixture offers the loose car to one active nearby owner")
	check(await wait_eaten(body),"Another active owner can reclaim and physically swallow the loose section")
	check(receipts.has(id) and receipts[id].owner==game.holes[1] and receipts[id].count==1,"Reclaim credits only the final legal owner")
func narrow_curve()->void:
	reset_arena();var train=spawn(4,Vector3(1.25,1.35,2.15),2.4);await frames(2)
	var penetrated:=false
	for frame in 240:
		train.step(1.0/60)
		for i in 4:
			for j in range(i+1,4):penetrated=penetrated or overlap(train.cars[i],train.cars[j])
	check(not penetrated,"Actual rail rectangles remain separate on the tight 2.4m inner-turn radius")
func world_obstruction(width:float)->Node3D:
	var body:Node3D=load("res://fidelity/rim_body.gd").new();body.game=game
	var shape:=BoxShape3D.new();shape.size=Vector3(width,.8,1.0)
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	game.city.add_child(body);body.collision_layer=2;body.position=Vector3.ZERO
	game.city.foods.append(body);game.city.register_food(body)
	return body
func world_avoidance()->void:
	for wide in [false,true]:
		reset_arena();var train=spawn(4)
		var obstacle:=world_obstruction(10.0 if wide else .6)
		var pose:Dictionary=train.base_pose(19.0);var forward:Vector2=pose.forward
		obstacle.position=Vector3(pose.at.x,.4,pose.at.y);obstacle.rotation.y=atan2(forward.x,forward.y)
		await frames(2)
		for i in 700:train.step(1.0/30)
		if wide:
			check(train.blocked and train.head_distance<18,"A full-corridor obstruction stops the head before contact")
			var distance:float=train.traveled;obstacle.free();await frames(2)
			for i in 90:train.step(1.0/30)
			check(not train.blocked and train.traveled>distance+15,"Removing a real obstruction allows the waiting head to resume")
		else:
			check(train.head_distance>train.route_length and not train.blocked,"A narrow world obstruction receives a real local bypass")
			check(train.planning_count>0 and not train.external_obstacles.is_empty(),"Bypass planning includes scenery, not only its own parked tail")
		metrics["world_wide_%s"%wide]=train.diagnostics()
func repeat_cut()->void:
	reset_arena();var train=spawn();await frames(2)
	game.player.radius=3;game.player.position=Vector3(70,0,70)
	var first:Node3D=train.cars[5]
	check(first.begin_pull(game.player) and train.attached_count==5,"First middle pull cuts one suffix")
	var tail:Transform3D=train.cars[7].global_transform
	for i in 60:train.step(1.0/60)
	var second:Node3D=train.cars[2]
	check(second.begin_pull(game.player) and train.attached_count==2,"A later upstream pull cuts only the remaining connected suffix")
	await frames(10)
	var pose:Transform3D=second.global_transform;var velocity:Vector3=second.linear_velocity
	train.step(.3)
	check(second.global_transform==pose and second.linear_velocity==velocity,"Controller cannot snap or rewrite velocity of a falling loose section")
	check(train.detach_events.size()==2 and train.cars[7].global_transform==tail,"Repeated cuts never move a previously parked suffix")
	check(train.couplers[0].visible and train.couplers.slice(1).all(func(link):return not link.visible),"Only the surviving head-to-car coupling remains visible")
func imported_assets()->void:
	reset_arena()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/trains/manifest.json"))
	check(manifest.assets.size()==10,"All eight sushi and two rail models ship as separate imported resources")
	var entries:Array[Dictionary]=[]
	for entry in manifest.assets:entries.append({"asset":entry.file,"category":"tram" if str(entry.key).begins_with("rail") else "sushi","points":9})
	var train:=Train.new()
	check(train.build(game,game.city,circle(18.0),entries,6.4),"Controller instantiates every real authored GLB without substitute geometry")
	await frames(2)
	for i in train.cars.size():
		var body:Node3D=train.cars[i];var entry:Dictionary=manifest.assets[i]
		var dimensions:=Vector3(entry.bounds.size[0],entry.bounds.size[1],entry.bounds.size[2])
		check((body.half_size*2.0).is_equal_approx(dimensions),"Imported %s collider follows actual Godot mesh bounds"%entry.key)
		check(is_equal_approx(body.footprint,Vector2(dimensions.x,dimensions.z).length()*.5),"Imported car admission uses its own complete rectangle")
		check(not body.has_meta("food_kind") and not body.has_meta("dither_building"),"Train avoids recipe inventory spoofing and building-only reveal")
		var meshes:=body.find_children("*","MeshInstance3D",true,false)
		check(meshes.size()==1 and meshes[0].mesh.get_surface_count()==1,"Imported %s remains one visible mesh/material surface"%entry.key)
		var arrays:Array=meshes[0].mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_VERTEX].size()>0 and arrays[Mesh.ARRAY_COLOR].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Authored vertex palette remains on the actual train mesh")
		var mat:BaseMaterial3D=meshes[0].get_active_material(0)
		check(mat!=null and mat.vertex_color_use_as_albedo,"Imported train material uses the actual vertex palette")
		var original:BaseMaterial3D=meshes[0].mesh.surface_get_material(0)
		check(mat.albedo_color==original.albedo_color and mat.roughness==original.roughness and mat.vertex_color_is_srgb==original.vertex_color_is_srgb,"Palette opt-in preserves authored PBR finish and color-space setting")
	metrics["imported_assets"]=train.diagnostics()

func real_map_integration()->void:
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
		game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
		game.player.active=true
		await frames(3)
		var train=game.train_controller
		check(train!=null and train.cars.size()==(8 if map_id=="food" else 4),"Real %s map owns its bounded additional train"%map_id)
		if train==null:continue
		check(game.city.moving_vehicles.size()==8,"Real %s train preserves the original eight traffic actors"%map_id)
		check(game.train_tracks!=null and game.train_tracks.updates==1,"Real map paints its track on existing ground exactly once at construction")
		var initial:Vector3=train.cars[0].global_position
		for frame in 90:train.step(1.0/60)
		check(train.cars[0].global_position.distance_to(initial)>8 and not train.blocked,"Real %s imported train moves along its clear street"%map_id)
		# The independent reviewer found a corner cut after the first full lap.
		# Keep the head moving while the admitted section is still falling, so
		# an initially obstructed bypass must retry before the next encounter.
		while train.head_distance<train.route_length+8.75:train.step(1.0/60)
		await frames(2)
		var target:Node3D=train.cars[2];var id:=target.get_instance_id()
		mouth(target,game.player);await frames(3);game.scan_food()
		check(target.claimed_by==game.player and train.attached_count==2,"Real %s normal player scan independently cuts the imported middle car"%map_id)
		check(await wait_eaten_while_running(target,train),"Real %s imported section falls fully through cut ground while the head continues"%map_id)
		check(receipts.has(id) and receipts[id].count==1,"Real map imported car produces one actual collection receipt")
		game.player.position=Vector3(1,0,23);game.ground.sync();await frames(2)
		var parked:Array[Dictionary]=[]
		for body in train.parked_cars():parked.append({"body":body,"pose":body.global_transform})
		var before:float=train.head_distance
		for frame in ceili(train.route_length*2.15/train.speed*15):train.step(1.0/15)
		check(train.head_distance-before>train.route_length*2 and not train.blocked,"Real %s head completes two full laps around its parked tail"%map_id)
		check(parked.all(func(item:Dictionary):return item.body.global_transform==item.pose),"Real map tail keeps its exact original stopped poses")
		check(game.train_tracks.updates>=2 and not game.train_tracks.last_branches.is_empty(),"Actual planned bypass becomes a visible ground-track branch")
		metrics["actual_"+map_id]=train.diagnostics()
	check(Train.Assets.palette_materials.size()<=10,"Repeated model/map teardown cannot accumulate imported palette materials")
func destroyed_owner_lifecycle()->void:
	reset_arena();game.selected_map="city"
	var train=spawn(4);game.train_controller=train
	await frames(2)
	var original_city:Node3D=game.city
	var pose:Transform3D=train.cars[0].global_transform;var distance:float=train.traveled
	# A still-live former city must not be moved by the new world's controller.
	game.city=Arena.new();game.world.add_child(game.city)
	train.step(.5);train.apply_coupled_poses()
	check(not train.owns_live_city() and train.traveled==distance and train.cars[0].global_transform==pose,"Replacing a live owning city immediately makes its retained train inert")
	# Match the legacy rival fixture exactly: free the original city and retain
	# the train while the real game physics callback continues on a new Arena.
	original_city.free()
	train.step(.5);train.apply_coupled_poses()
	check(train.traveled==distance and train.detach_events.is_empty(),"A freed owning city makes step a no-op without stale node accesses")
	game.set_physics_process(true);await frames(8);game.set_physics_process(false)
	check(train.traveled==distance,"Natural game physics remains safe with an old controller and replacement city")
	train.detach_from(1)
	check(train.attached_count==1,"Explicit cleanup tolerates already-freed body and visual-link entries")
	reset_arena();train=spawn(4);game.train_controller=train;await frames(2)
	train.couplers[1].free();train.apply_coupled_poses();distance=train.traveled
	train.step(.05)
	check(train.traveled>distance,"Independent visual-link destruction does not stop valid body motion")
	train.cars[1].free();train.apply_coupled_poses()
	check(not train.couplers[0].visible,"Direct pose refresh hides the link adjacent to an independently freed car")
	train.step(.05)
	check(train.attached_count==1 and train.cars[0].attached,"Independent car destruction safely detaches only its remaining suffix")
	check(not train.cars[2].attached and not train.cars[3].attached and not train.couplers[2].visible,"Surviving downstream cars and links retain ordinary disconnected state")
	train.detach_from(0)
	check(train.attached_count==0 and not train.couplers[0].visible,"Explicit head cleanup ignores a previously freed middle visual link")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
	game.item_collected.connect(collected)
	await chain_and_motion()
	await cut_and_fall(4)
	await cut_and_fall(7,true)
	await cut_and_fall(0)
	await pull_and_reclaim()
	await narrow_curve()
	await world_avoidance()
	await repeat_cut()
	await imported_assets()
	await real_map_integration()
	await destroyed_owner_lifecycle()
	print("TRAIN_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Real headless physics and controller geometry; not rendered or phone performance evidence"}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
