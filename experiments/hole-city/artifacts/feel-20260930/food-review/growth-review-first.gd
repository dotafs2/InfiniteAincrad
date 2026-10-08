extends SceneTree
## Independent actual-world growth review; source and exported-PCK portable.
const Hole=preload("res://fidelity/hole.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var changed_ids:Dictionary={}
var receipts:Array[Dictionary]=[]
var current_target:Node3D
var platter_target:Node3D
var platter_at:=Vector2.ZERO
var platter_ids:Dictionary={}
var platter_initial_poses:Dictionary={}
var finger_at:=Vector2(180,585)
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=2)->void:
	for i in n:await process_frame
func shape_for(body:Node3D)->Shape3D:
	for child in body.get_children():
		if child is CollisionShape3D:return child.shape
	return null
func distance_to_path(at:Vector2,points:Array)->float:
	var result:=INF
	for i in points.size()-1:
		var a:=Vector2(points[i][0],points[i][1]);var b:=Vector2(points[i+1][0],points[i+1][1])
		var u:=clampf((at-a).dot(b-a)/(b-a).length_squared(),0,1)
		result=minf(result,at.distance_to(a+(b-a)*u))
	return result
func inspect()->void:
	var city=game.city;var plan:Dictionary=city.urban_plan
	var loose:Array=city.foods.filter(func(b):return b.has_meta("food_kind") and not b.has_meta("tower_id") and not b.has_meta("pile_id") and not b.get_meta("traffic",false))
	check(city.foods.size()==2930 and loose.size()==1080,"Existing body count and loose-food count are preserved")
	check(city.towers.size()==160 and city.piles.size()==17 and city.mesh_cache.size()==34,"Existing skyline, independent heaps and shared recipe inventory remain")
	check(city.moving_vehicles.size()==8 and game.train_controller.cars.size()==8,"Both original sushi traffic and the eight-car sushi train remain")
	var counts:Dictionary={};var near:Dictionary={};var changed:=0
	var probe:=Hole.new()
	for index in loose.size():
		var b:Node3D=loose[index];var record:Dictionary=plan.snacks[index]
		if not record.has("growth_level"):continue
		changed+=1;changed_ids[b.get_instance_id()]=true
		var grade:int=Hole.level_for_radius(b.footprint*1.08)
		var district:int=record.growth_district
		if not counts.has(district):counts[district]={2:0,3:0,4:0}
		counts[district][grade]=int(counts[district].get(grade,0))+1
		if Vector2(b.position.x-1,b.position.z-23).length()<20:near[grade]=int(near.get(grade,0))+1
		check(grade in [2,3,4] and b.points in [1,2],"Resized food has a real intermediate size and modest original points: "+str(index))
		check(not is_instance_valid(b.support_parent) and b.freeze and b.batch!=null,"Intermediate target is an independent initially grounded body: "+str(index))
		probe.radius=Hole.radius_for_level(grade-1)
		check(not b.can_fit(probe),"Earlier physical mouth rejects target "+str(index))
		probe.radius=Hole.radius_for_level(grade)
		check(b.can_fit(probe),"Next physical mouth accepts target "+str(index))
		var mesh_box:AABB=b.food_visual.mesh.get_aabb()
		var half:Vector3=mesh_box.size*b.food_visual.scale*.5
		var s:Shape3D=shape_for(b);var dimensions_match:=false
		if s is BoxShape3D:dimensions_match=s.size.is_equal_approx(half*2)
		elif s is ConvexPolygonShape3D:
			var max_y:=0.0;var max_radius:=0.0
			for p:Vector3 in s.points:max_y=maxf(max_y,absf(p.y));max_radius=maxf(max_radius,Vector2(p.x,p.z).length())
			dimensions_match=absf(max_y-half.y)<.0001 and absf(max_radius-maxf(half.x,half.z))<.0001
		check(dimensions_match and b.half_size.is_equal_approx(half),"Actual collider matches the scaled rendered dimensions: "+str(index))
		var envelope:=0.0
		for vertex:Vector3 in b.food_visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var local:Vector3=b.food_visual.transform*vertex
			envelope=maxf(envelope,Vector2(local.x,local.z).length())
		var clear:=true;var at:=Vector2(b.position.x,b.position.z)
		for route in plan.roads+plan.routes:
			if distance_to_path(at,route.points)<envelope+float(route.half_width)+.25:clear=false
		check(clear and absf(b.position.y-half.y)<.05,"Whole real food leaves both traffic and pedestrian routes clear while resting on terrain: "+str(index))
	probe.free()
	check(changed==182,"Exactly 182 existing snacks are redistributed")
	for district in 7:check(counts.get(district,{})=={2:14,3:8,4:4},"Actual size bins fill all three intermediate steps in district "+str(district))
	check(int(near.get(2,0))>=14 and int(near.get(3,0))>=8 and int(near.get(4,0))>=4,"Actual intermediate bodies are available within 20m of the original spawn")
	var platter_total:=0
	for index in city.piles.size():
		var pile:Dictionary=city.piles[index];var base=pile.get("growth_platter")
		if not is_instance_valid(base):continue
		platter_total+=1
		check(index in [2,4,6] and pile.pieces.size()==59 and pile.roots==[base],"One existing heap piece is replaced, preserving 59 independent pieces")
		check(base.points==10 and absf(base.footprint-3.4)<.0001 and base.get_meta("food_kind")=="cookie","Real broad cookie has the intended level-six size and ten-point receipt")
		check(Hole.level_for_radius(base.footprint*1.08)==6,"Physical cookie size, not category metadata, selects its level-six gate")
		changed_ids[base.get_instance_id()]=true
		var unique:Dictionary={}
		for piece in pile.pieces:
			unique[piece.get_instance_id()]=true
			if piece==base:continue
			var parent=piece.support_parent;var visited:Dictionary={};var reaches:=false
			while is_instance_valid(parent) and not visited.has(parent.get_instance_id()):
				visited[parent.get_instance_id()]=true
				if parent==base:reaches=true;break
				parent=parent.support_parent
			check(reaches and piece is RigidBody3D and shape_for(piece)!=null,"Upper food has independent collision and an acyclic support chain to the cookie")
			var p=piece.support_parent
			check(p.supported_food.has(piece) and piece.position.y-piece.half_size.y>=p.position.y+p.half_size.y-.002,"Support dependency agrees with actual contact height")
		check(unique.size()==59,"The platter is not a merged 59-food collision/score owner")
	check(platter_total==3,"Exactly three planned inner-city platter opportunities exist")
	metrics["inventory"]={"body_count":city.foods.size(),"changed":changed,"district_bins":counts,"opening_20m":near}
func record(body:Node3D,owner:Node3D)->void:
	if owner!=game.player:return
	var id:=body.get_instance_id()
	var before:int=owner.score-body.points
	receipts.append({"id":id,"points":body.points,"grade":Hole.level_for_radius(body.footprint*1.08),"score":owner.score,"top":body.position.y+body.vertical_extent(),"changed":changed_ids.has(id),"jump":Hole.level_for_score(owner.score)-Hole.level_for_score(before)})
func steer_to(at:Vector2)->void:
	var p=game.player;var gap:=at-Vector2(p.position.x,p.position.z)
	var wanted:=gap.normalized()*clampf(gap.length()/.22,0,1)
	var right:Vector2=game.screen_direction(Vector2.RIGHT);var down:Vector2=game.screen_direction(Vector2.DOWN)
	var transform:=Transform2D(right,down,Vector2.ZERO)
	var stick:Vector2=(transform.affine_inverse()*wanted).limit_length()
	var e:=InputEventScreenDrag.new();e.index=0;e.position=finger_at+stick*80;e.relative=Vector2.ZERO
	root.push_input(e,true)
func target_food()->Node3D:
	var matching:Node3D;var fallback:Node3D;var match_distance:=22.0;var best:=INF
	var grade:=mini(game.player.level,4)
	for b in game.city.foods:
		if not is_instance_valid(b) or not b.has_meta("food_kind") or not b.can_fit(game.player):continue
		var d:float=Vector2(b.position.x-game.player.position.x,b.position.z-game.player.position.z).length()
		if Hole.level_for_radius(b.footprint*1.08)==grade and d<match_distance:matching=b;match_distance=d
		var value:=d/maxf(1,sqrt(float(b.points)))
		if value<best:best=value;fallback=b
	return matching if is_instance_valid(matching) else fallback
func live_route()->void:
	game.begin_play();game.city.rain_enabled=false
	for hole in game.holes:
		if hole!=game.player:hole.retire()
	game.item_collected.connect(record)
	var e:=InputEventScreenTouch.new();e.index=0;e.position=finger_at;e.pressed=true;root.push_input(e,true)
	check(game.player.score==0 and game.player.level==1 and game.player.touch_index==0,"Live route starts at original spawn/zero score using actual touch steering")
	var last:Vector3=game.player.position;var travelled:=0.0;var levels:=[];var current_level:=0;var released_count:=0;var settled_frames:=0
	for tick in 7200:
		if game.player.level!=current_level:
			current_level=game.player.level;levels.append({"level":current_level,"score":game.player.score,"time":game.elapsed,"at":[game.player.position.x,game.player.position.z]})
		if game.player.level>=6 and platter_ids.is_empty():
			var closest:=INF
			for pile in game.city.piles:
				var base=pile.get("growth_platter")
				if not is_instance_valid(base) or base.consumed:continue
				var d:float=game.player.position.distance_to(base.position)
				if d<closest:closest=d;platter_target=base;platter_at=pile.at
			if is_instance_valid(platter_target):
				for pile in game.city.piles:
					if pile.get("growth_platter")==platter_target:
						for piece in pile.pieces:
							platter_ids[piece.get_instance_id()]=weakref(piece);platter_initial_poses[piece.get_instance_id()]=piece.position
				current_target=platter_target
		if not platter_ids.is_empty():
			var alive:=0
			for ref in platter_ids.values():
				var piece=ref.get_ref()
				if is_instance_valid(piece):
					alive+=1
					if not piece.freeze:released_count+=1
			if alive==0:break
			steer_to(platter_at)
			if not is_instance_valid(platter_target):settled_frames+=1
			if settled_frames>900:break
		else:
			if not is_instance_valid(current_target) or current_target.consumed or (current_target.claimed_by!=game.player and not current_target.can_fit(game.player)):current_target=target_food()
			if is_instance_valid(current_target):
				var at:Vector3=current_target.interaction_position();steer_to(Vector2(at.x,at.z))
		await physics_frame
		travelled+=game.player.position.distance_to(last);last=game.player.position
	var release:=InputEventScreenTouch.new();release.index=0;release.position=finger_at;release.pressed=false;root.push_input(release,true)
	var totals:=0;var ids:Dictionary={};var bins:Dictionary={};var platter_receipts:=0;var cookie_receipts:=0;var score_safe:=true;var complete:=true
	for row in receipts:
		totals+=row.points;ids[row.id]=int(ids.get(row.id,0))+1;bins[row.grade]=int(bins.get(row.grade,0))+1
		if row.top>=-3.5:complete=false
		if row.changed and row.jump>1:score_safe=false
		if platter_ids.has(row.id):
			platter_receipts+=1
			if row.points==10:cookie_receipts+=1
	check(game.player.level>=6 and game.player.score>=160 and game.elapsed<120,"Normal actual input reaches the later meal without direct score, radius or position writes")
	check(totals==game.player.score and ids.size()==receipts.size() and complete,"All score comes from unique real below-floor receipts")
	check(score_safe,"Each resized snack and cookie alone advances at most one level")
	check(int(bins.get(2,0))>=2 and int(bins.get(3,0))>=2 and int(bins.get(4,0))>=2,"Route really eats several intermediate meals of each size")
	check(platter_ids.size()==59 and platter_receipts==59 and cookie_receipts==1,"After natural growth the player walks to a cookie and individually eats all 59 bodies")
	check(released_count>=58 and game.city.collection_progress.heaps>=1,"Physical support release triggers a genuine individual-food cascade and heap progress")
	check(travelled>35 and game.train_controller.traveled>0,"Route has actual distance and preserves moving train gameplay")
	metrics["route"]={"seconds":game.elapsed,"score":game.player.score,"level":game.player.level,"distance":travelled,"levels":levels,"grade_receipts":bins,"platter_at":[platter_at.x,platter_at.y],"platter_receipts":platter_receipts,"receipts":receipts}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(2)
	game.selected_map="food";game.start_level();game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.set_physics_process(false)
	inspect()
	for h in game.holes:h.set_physics_process(true)
	game.set_physics_process(true);game.city.set_process(true)
	await live_route()
	game.audio.music.stop();OS.delay_msec(150);await frames(4);game.free();await frames(3)
	print("FOOD_GROWTH_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent actual meshes/colliders and real viewport-directed physical play; rivals retired and rain disabled for deterministic target review. No phone FPS or human play claim."}))
	quit(0 if failures.is_empty() else 1)
