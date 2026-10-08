extends SceneTree
## Actual toy bodies, measured admission, support and physical completion.
## Planning reachability is separate from an ordinary timed gameplay soak.
const Game=preload("res://fidelity/game.gd")
const ToyCity=preload("res://fidelity/toy_city.gd")
const Growth=preload("res://fidelity/hole.gd")
const Shapes=preload("res://fidelity/toy_shapes.gd")
const KINDS:=["toy_ball","toy_duck","toy_car","toy_block","toy_train","toy_arch","bubble_turret","block_tower","toy_castle","grand_castle","royal_topiary","royal_flowerbed"]
class SizeProbe:
	extends Node3D
	var radius:=.85
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var collected:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func descendants(owner:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in owner.get_children():
		result.append(child);result.append_array(descendants(child))
	return result
func physical_frames(count:int)->void:
	for _index in count:await physics_frame
func visual_points(body:Node3D)->PackedVector3Array:
	var view:MeshInstance3D=body.get_node_or_null("ToyVisual")
	var result:=PackedVector3Array()
	if view==null or view.mesh==null:return result
	for surface in view.mesh.get_surface_count():
		var arrays:Array=view.mesh.surface_get_arrays(surface)
		for vertex in arrays[Mesh.ARRAY_VERTEX]:result.append(view.transform*vertex)
	return result
func collision_points(body:Node3D)->PackedVector3Array:
	var result:=PackedVector3Array()
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is ConvexPolygonShape3D:
			for vertex in child.shape.points:result.append(child.transform*vertex)
	return result
func point_bounds(points:PackedVector3Array)->AABB:
	if points.is_empty():return AABB()
	var result:=AABB(points[0],Vector3.ZERO)
	for point in points:result=result.expand(point)
	return result
func horizontal_bounds(body:Node3D,points:PackedVector3Array)->Rect2:
	var first:=true;var result:=Rect2()
	for point in points:
		var at:Vector3=body.global_transform*point
		var planar:=Vector2(at.x,at.z)
		if first:result=Rect2(planar,Vector2.ZERO);first=false
		else:result=result.expand(planar)
	return result
func quiet_world()->void:
	game.set_process(false);game.set_physics_process(false)
	game.city.set_process(false);game.city.set_physics_process(false)
	if is_instance_valid(game.city.get("court")):game.city.court.set_process(false)
	for hole in game.holes:
		hole.enabled=false;hole.set_process(false);hole.set_physics_process(false)
		if hole!=game.player:hole.active=false
func fixture_player(level:int,at:Vector2)->void:
	game.player.level=level;game.player.score=Growth.level_start_for(level)
	game.player.radius=Growth.radius_for_level(level)
	game.player.position=Vector3(at.x,0,at.y);game.player.velocity=Vector3.ZERO
	game.player._sync_shape();game.ground.sync()
func static_foods()->Array[Node3D]:
	var result:Array[Node3D]=[]
	for body in game.city.foods:
		if is_instance_valid(body) and not body.get_meta("court_actor",false):result.append(body)
	return result

func inspect_population()->void:
	var city:Node3D=game.city
	var summary:Dictionary=city.population_summary()
	check(city is ToyCity and summary.map_id=="toys","The selected toy branch builds the actual procedural city")
	check(summary.legacy_models_loaded==0 and city.catalog.is_empty(),"Toy construction never loads the old city asset catalog")
	check(city.foods.size()==summary.bodies and static_foods().size()>=200 and static_foods().size()==int(summary.get("static_bodies",city.toy_plan.size())) and summary.bodies<=900,"Every authored toy and court body is an independent edible within the scene budget")
	check(summary.kind_counts.size()==12 and KINDS.all(func(kind):return summary.kind_counts.has(kind)),"All ten original toy silhouettes and two edible garden assemblies are present")
	check(summary.tier_counts.size()==9 and range(1,10).all(func(tier):return int(summary.tier_counts.get(tier,0))>0),"Actual edibles span all nine authored size tiers")
	check(summary.neighborhood_counts.size()==8,"All eight named districts contain actual edible bodies")
	check(summary.largest_height>=25 and summary.largest_required_radius>12,"Large late targets remain visibly taller and require late growth")
	var actual_points:=0;var static_points:=0
	for body in city.foods:actual_points+=body.points
	for body in static_foods():static_points+=body.points
	check(summary.total_points==actual_points and static_points>=Growth.level_start_for(12),"Actual static points suffice for late growth and the full point inventory includes court rewards exactly once")
	check(summary.mesh_cache_entries==12 and summary.shape_cache_entries<=100,"Unit geometry and scaled colliders remain bounded shared resources")
	var meshes:=0;var collisions:=0;var fragments:=0
	for node in descendants(city):
		if node is MeshInstance3D or node is MultiMeshInstance3D:meshes+=1
		if node is CollisionShape3D:collisions+=1
		if node.get_meta("building_fragment",false):fragments+=1
	check(meshes<=1200 and collisions<=2000 and collisions==summary.collision_parts,"The actual scene stays inside its mesh and collision budgets")
	check(fragments==0 and city.citizens.is_empty() and city.moving_vehicles.is_empty(),"No shell fragments or inherited city pedestrians/traffic populate Toy Town")
	metrics.population=summary;metrics.scene={"mesh_instances":meshes,"collision_parts":collisions,"fragments":fragments}

func inspect_bodies()->void:
	var layout:Dictionary=game.city.layout_metadata()
	var lanes:Array=layout.road_clearance
	var probe:=SizeProbe.new();root.add_child(probe)
	var ids:Dictionary={};var opening:=0;var low_late:=0;var envelope_levels:Dictionary={}
	var support_rows:Array[Dictionary]=[]
	var planar_bounds:Dictionary={}
	var targets:Dictionary={}
	var all_collision_ids:Array[RID]=[game.ground.body.get_rid()]
	for body in game.city.foods:all_collision_ids.append(body.get_rid())
	for body in static_foods():
		var label:String=body.name
		var view:MeshInstance3D=body.get_node_or_null("ToyVisual")
		var points:=visual_points(body);var box:=point_bounds(points)
		var maximum_radius:=0.0
		for point in points:maximum_radius=maxf(maximum_radius,Vector2(point.x,point.z).length())
		var required:float=maximum_radius*1.08
		var minimum:int=Growth.level_for_radius(required)
		var kind:String=body.get_meta("toy_kind","")
		var tier:int=int(body.get_meta("toy_tier",0))
		var target_key:String=kind+"/"+str(tier)+"/"+str(box.size)
		if not targets.has(target_key):targets[target_key]={"kind":kind,"tier":tier,"size":box.size,"required_radius":required,"minimum_level":minimum,"count":0,"supported":0}
		targets[target_key].count+=1
		if is_instance_valid(body.support_parent):targets[target_key].supported+=1
		check(view!=null and view.mesh!=null and KINDS.has(kind) and not ids.has(label) and body.points>0 and body.points<=96,label+": one stable original body owns valid geometry and points")
		ids[label]=true
		check(not points.is_empty() and box.size.is_equal_approx(body.half_size*2) and is_equal_approx(box.size.y,body.height) and box.get_center().is_zero_approx(),label+": physics bounds are measured from the scaled real mesh")
		check(absf(maximum_radius-body.footprint)<.0001 and absf(required-float(body.get_meta("required_radius")))<.0001 and minimum==int(body.get_meta("minimum_level")) and minimum>0,label+": actual horizontal vertices determine admission and the minimum level")
		var rect:=horizontal_bounds(body,points)
		planar_bounds[body.get_instance_id()]=rect
		check(Rect2(-96,-96,192,192).encloses(rect) and lanes.all(func(lane):return not rect.intersects(lane,true)),label+": rotated real geometry clears every reserved lane and the world edge")
		var physics:=collision_points(body);var collision_box:=point_bounds(physics)
		var contained:=not physics.is_empty() and collision_box.size.x>0 and collision_box.size.y>0 and collision_box.size.z>0
		for vertex in physics:contained=contained and vertex.is_finite() and box.grow(.001).has_point(vertex)
		check(contained and int(body.get_meta("collision_parts",0))==body.get_children().filter(func(node):return node is CollisionShape3D).size(),label+": finite real convex shapes fit their original model")
		probe.radius=required-.0001
		var rejects_small:bool=not body.can_fit(probe)
		probe.radius=Growth.radius_for_level(minimum)
		var supported:bool=is_instance_valid(body.support_parent)
		check(rejects_small and body.can_fit(probe)==(not supported),label+": measured size rejects a smaller mouth and valid support blocks independent admission")
		if body.position.distance_to(Vector3(layout.spawn.x,0,layout.spawn.y))<16 and not supported and minimum<=2:opening+=1
		if body.get_meta("landmark",false) and minimum<=2:low_late+=1
		envelope_levels[minimum]=int(envelope_levels.get(minimum,0))+1
		if tier==9:check(minimum>=11,label+": the largest tier cannot be swallowed during early growth")
		if kind in ["toy_arch","toy_castle","grand_castle"]:check(body.get_meta("compound_collision",false),label+": arch and castle collision preserves separate structural parts")
		if supported:
			var parent:Node3D=body.support_parent
			var parent_points:=collision_points(parent)
			var parent_box:=point_bounds(parent_points)
			var parent_top:float=parent.global_position.y+parent_box.end.y
			var bottom:float=body.global_position.y+collision_box.position.y
			var gap:float=bottom-parent_top
			check(parent.supported_toys.has(body) and body.get_meta("tower_id")==parent.get_meta("tower_id") and int(body.get_meta("tower_level"))==int(parent.get_meta("tower_level"))+1,label+": support references name the immediate physical layer")
			# First ray upward against the child alone to find its real lower
			# collision face. Then ray downward against the actual parent. This
			# preserves compound cavities and ignores unrelated decorative maxima.
			var child_exclude:Array[RID]=all_collision_ids.duplicate()
			child_exclude.erase(body.get_rid())
			var hits:=0;var closest_gap:=INF
			for x in [-.4,-.2,0.0,.2,.4]:
				for z in [-.4,-.2,0.0,.2,.4]:
					var at:Vector3=body.global_transform*Vector3(x*collision_box.size.x,0,z*collision_box.size.z)
					var upward:=PhysicsRayQueryParameters3D.create(at+Vector3.DOWN*(body.height+1),at+Vector3.UP*(body.height+1),1,child_exclude)
					var child_hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(upward)
					if child_hit.get("collider")!=body:continue
					at=child_hit.position+Vector3.DOWN*.001
					var query:=PhysicsRayQueryParameters3D.create(at,at+Vector3.DOWN*.10,1,[body.get_rid()])
					var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
					if hit.get("collider")==parent:
						hits+=1;closest_gap=minf(closest_gap,float(child_hit.position.y-hit.position.y))
			check(is_finite(closest_gap) and closest_gap>=-.002 and closest_gap<=.03,label+": real collision surfaces leave only the intended support clearance")
			check(hits>0,label+": an actual parent collider supports the child footprint")
			support_rows.append({"body":label,"parent":parent.name,"global_aabb_gap_diagnostic":gap,"actual_contact_gap":closest_gap,"support_ray_hits":hits})
	check(opening>=12,"The actual spawn has a sustained collection of level-one and level-two nearby targets")
	check(low_late==0 and layout.late_targets.size()>=10,"At least ten distant landmarks remain unavailable to a starter")
	check(envelope_levels.size()>=9,"Real minimum admission levels vary well beyond two object sizes")
	check(not support_rows.is_empty(),"The playable map includes independent physically supported stacks")
	var route:Array=layout.opening_route
	check(route.size()>=3 and route.front()==layout.spawn and route.all(func(at):return at.is_finite() and Rect2(-96,-96,192,192).has_point(at)),"The authored opening route starts at the actual spawn and stays finite inside the world")
	var clear_opening:=true
	for segment in mini(2,route.size()-1):
		var distance:float=route[segment].distance_to(route[segment+1])
		for step in range(int(ceil(distance/.5))+1):
			var sample:Vector2=route[segment].lerp(route[segment+1],minf(1.0,float(step)*.5/maxf(.001,distance)))
			for body in static_foods():
				if int(body.get_meta("minimum_level"))<=1:continue
				var rect:Rect2=planar_bounds[body.get_instance_id()]
				if rect.grow(.30).has_point(sample):clear_opening=false
	check(clear_opening,"The first two route segments reach the tiny-food shoulder without passing through a larger intact body")
	metrics.admission_levels=envelope_levels;metrics.opening_targets=opening;metrics.supports=support_rows;metrics.admission_targets=targets.values()
	probe.free()

func inspect_reachability()->void:
	# A deterministic admission graph proves the map cannot exhaust all legal
	# targets before a growth threshold. It does not claim a travel-time result.
	var score:=0;var admitted:Dictionary={};var thresholds:Array[Dictionary]=[]
	var levels:Dictionary={}
	var original:Array[Node3D]=static_foods()
	var ordered:Array=original.duplicate()
	ordered.sort_custom(func(a,b):return a.footprint<b.footprint)
	for _step in original.size()+1:
		var level:int=Growth.level_for_score(score)
		var radius:float=Growth.radius_for_level(level)
		if not levels.has(level):
			levels[level]=true;thresholds.append({"score":score,"level":level,"radius":radius,"admitted":admitted.size()})
		var next:Node3D
		for body in ordered:
			if admitted.has(body.get_instance_id()) or body.footprint*1.08>radius:continue
			if is_instance_valid(body.support_parent) and not admitted.has(body.support_parent.get_instance_id()):continue
			next=body;break
		if next==null:break
		admitted[next.get_instance_id()]=true;score+=next.points
	var remaining_landmarks:=0
	for body in original:
		if body.get_meta("landmark",false) and not admitted.has(body.get_instance_id()):remaining_landmarks+=1
	check(levels.size()>=9,"One-body planning crosses sustained real growth thresholds between opening snacks and late buildings")
	check(admitted.size()==original.size() and remaining_landmarks==0,"Independent static-toy point/size/support planning has no terminal growth deadlock without court rewards")
	var static_points:=0
	for body in original:static_points+=body.points
	check(score==static_points,"Reachability adds each real static layer exactly once without rivals, court rewards, ads or injected score bonuses")
	metrics.planning={"scope":"One-body admission graph only; no travel-time or ordinary 90-second pacing claim","thresholds":thresholds,"reachable":admitted.size(),"score":score,"blocked_landmarks":remaining_landmarks}

func on_collected(body:Node3D,hole:Node3D)->void:
	if not body.has_meta("toy_kind"):return
	var id:int=body.get_instance_id()
	var actual_top:float=body.global_position.y+body.vertical_extent()
	if not collected.has(id):collected[id]=[]
	collected[id].append({"name":body.name,"points":body.points,"top":actual_top,"player":hole==game.player,"score":hole.score})

func inspect_physical_completion()->void:
	var base:Node3D
	var unclaimed:Node3D
	for body in static_foods():
		var tower:String=body.get_meta("tower_id","")
		if int(body.get_meta("tower_level"))!=0 or body.supported_toys.is_empty():continue
		if tower in ["toy_tower_20","toy_tower_21"] and int(body.get_meta("toy_tier"))==3 and int(body.get_meta("minimum_level"))<=3:base=body
		elif tower!="" and unclaimed==null:unclaimed=body
	check(base!=null and unclaimed!=null and base!=unclaimed,"An actual authored level-three small stack and a separate tower provide independent physical support fixtures")
	if base==null or unclaimed==null:return
	var starter_id:String=base.get_meta("tower_id")
	var remote_id:String=unclaimed.get_meta("tower_id")
	var members:Array[Node3D]=[]
	for body in static_foods():
		if body.get_meta("tower_id","")==starter_id:members.append(body)
	members.sort_custom(func(a,b):return int(a.get_meta("tower_level"))<int(b.get_meta("tower_level")))
	check(members.size()==3 and members[0]==base,"The selected actual starter tower retains all three separately authored physics layers")
	if members.size()!=3:return
	var expected_points:=0;var identity:Dictionary={}
	for body in members:
		expected_points+=body.points
		var view:MeshInstance3D=body.get_node("ToyVisual")
		identity[body.get_instance_id()]={"mesh":view.mesh,"transform":view.transform,"points":body.points}
	var at:=Vector2(base.position.x,base.position.z)
	fixture_player(int(base.get_meta("minimum_level")),at)
	var initial_score:int=game.player.score
	var child:Node3D=members[1]
	check(not child.can_fit(game.player),"A supported upper toy cannot be admitted before its base releases")
	check(base.begin_swallow(game.player),"Normal measured admission releases the real small-stack base")
	check(game.player.score==initial_score and not collected.has(base.get_instance_id()),"Admission releases physics without awarding points")
	await physical_frames(2)
	check(is_instance_valid(child.support_parent),"The physical support delay does not release children immediately")
	await physical_frames(5)
	check(not is_instance_valid(child.support_parent) and not child.freeze,"After the bounded support delay the original upper toy wakes under gravity")
	var originals:=true
	for body in members:
		if not is_instance_valid(body):continue
		var view:MeshInstance3D=body.get_node("ToyVisual");var row:Dictionary=identity[body.get_instance_id()]
		originals=originals and view.mesh==row.mesh and view.transform==row.transform and body.points==row.points and view.visible
	check(originals,"Moving layers expose their original batched geometry and preserve each layer's actual reward")
	for _frame in 360:
		if members.all(func(body):return not is_instance_valid(body)):break
		game.scan_food();await physics_frame
	var all_once:=true;var below:=true;var credited:=0
	for id in identity:
		var rows:Array=collected.get(id,[])
		all_once=all_once and rows.size()==1
		for row in rows:
			below=below and row.top<-3.5 and row.player and int(row.points)==int(identity[id].points)
			credited+=int(row.points)
	check(all_once and members.all(func(body):return not is_instance_valid(body)),"All three original stack layers finish actual falling and emit one collection callback each")
	check(below and credited==expected_points,"Only whole bodies below the collection plane grant their exact per-layer points")
	var all_credited:=0
	for rows in collected.values():
		for row in rows:
			if row.player:all_credited+=int(row.points)
	check(game.player.score==initial_score+all_credited,"The real player's score equals actual completed receipts, including any nearby targets admitted by the normal scan")
	# A remote pull is an explicit support fixture, not an ordinary travel claim.
	fixture_player(int(unclaimed.get_meta("minimum_level")),Vector2(80,80))
	var upper:Node3D=unclaimed.supported_toys[0]
	check(unclaimed.begin_pull(game.player) and not is_instance_valid(unclaimed.claimed_by),"An unclaimed remote pull uses real physics without inventing a score reservation")
	await physical_frames(7)
	check(not is_instance_valid(upper.support_parent) and not upper.freeze and not is_instance_valid(upper.fall_credit) and not is_instance_valid(upper.claimed_by),"Support loss wakes a remote upper layer without assigning unearned credit")
	check(not collected.has(unclaimed.get_instance_id()) and not collected.has(upper.get_instance_id()),"Releasing support outside the mouth grants no collection receipt for either remote layer")
	var large:Node3D
	for body in game.city.foods:
		if body.category=="building" and body.points==96:large=body;break
	check(large!=null,"An actual large whole castle is available for the category-reward boundary")
	if large!=null:
		var view:MeshInstance3D=large.get_node("ToyVisual");var mesh:Mesh=view.mesh;var pose:Transform3D=view.transform
		fixture_player(int(large.get_meta("minimum_level")),Vector2(80,80))
		large.vinyl_material.set_shader_parameter("reveal_occluder",1.0)
		check(large.begin_pull(game.player) and large.points==96 and view.mesh==mesh and view.transform==pose and is_zero_approx(float(large.vinyl_material.get_shader_parameter("reveal_occluder"))),"Whole-castle admission clears reveal and preserves original geometry plus 96 points instead of the old city 48-point override")
	metrics.physical={"scope":"Explicit small-stack and remote-pull fixtures; real gravity and callbacks, not a timed growth soak","starter_tower_id":starter_id,"remote_tower_id":remote_id,"expected_stack_points":expected_points,"completed_stack_points":credited,"receipts":collected}

func inspect_garden_completion()->void:
	var counts:Dictionary={}
	for body in static_foods():
		if not body.get_meta("royal_garden",false):continue
		var kind:String=body.get_meta("toy_kind")
		counts[kind]=int(counts.get(kind,0))+1
	check(counts.get("royal_topiary",0)==8 and counts.get("royal_flowerbed",0)==8,"Two original crown gardens contain eight topiary and eight planted beds")
	for kind in ["royal_topiary","royal_flowerbed"]:
		var candidates:Array=static_foods().filter(func(body):return body.get_meta("toy_kind","")==kind)
		if candidates.is_empty():continue
		var body:Node3D=candidates[0]
		var identity:int=body.get_instance_id()
		var view:MeshInstance3D=body.get_node("ToyVisual")
		var mesh:Mesh=view.mesh
		fixture_player(int(body.get_meta("minimum_level")),Vector2(body.position.x,body.position.z))
		check(body.begin_swallow(game.player),kind+": actual garden owner accepts a sufficiently large mouth")
		await physical_frames(2)
		check(is_instance_valid(body) and view.mesh==mesh and view.visible,kind+": original planted assembly detaches from batching and falls as one object")
		for _frame in 360:
			if not is_instance_valid(body):break
			await physics_frame
		var rows:Array=collected.get(identity,[])
		check(not is_instance_valid(body) and rows.size()==1 and int(rows[0].points)==4 and rows[0].top<-3.5,kind+": whole assembly disappears below the collection plane and awards four points once")
	metrics.gardens={"counts":counts,"added_available_points":64,"scope":"Actual explicit physical swallow fixtures, not organic travel"}

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	game=Game.new();game.selected_map="toys";root.add_child(game)
	game.start_level();game.begin_play();quiet_world()
	await physical_frames(3)
	inspect_population();inspect_bodies();inspect_reachability()
	game.item_collected.connect(on_collected)
	await inspect_physical_completion()
	await inspect_garden_completion()
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual toy geometry, collision, support and explicit physics fixtures; no real save, production SDK, phone FPS or 90-second pacing claim"}
	print("TOY_CITY_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
