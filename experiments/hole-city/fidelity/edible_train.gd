extends RefCounted
signal route_changed(plans:Array)
## One head records its actual path; coupled cars follow that path by distance.
## Detached cars retain their world pose and are never routed or reattached.
const Car=preload("res://fidelity/train_car.gd")
const Assets=preload("res://fidelity/train_assets.gd")
const CLEARANCE:=.10
const SAMPLE_STEP:=.12
var game:Node3D
var city:Node3D
var cars:Array[Node3D]=[]
var offsets:Array[float]=[]
var route:Array[Vector2]=[]
var cumulative:Array[float]=[]
var route_length:=0.0
var speed:=2.0
var bypass_offset:=1.35
var ramp_length:=7.0
var head_distance:=0.0
var traveled:=0.0
var attached_count:=0
var detach_events:Array[Dictionary]=[]
var history:Array[Dictionary]=[]
var detours:Array[Dictionary]=[]
var planning_needed:=false
var blocked:=false
var blocked_steps:=0
var planning_count:=0
var max_half:=Vector3.ZERO
var query_shape:=BoxShape3D.new()
var couplers:Array[MeshInstance3D]=[]
var obstruction:Node3D
var external_obstacles:Array[Node3D]=[]
var probe_clock:=0.0
var plan_retry_time:=0.0

func build(owner_game:Node3D,owner_city:Node3D,points:Array[Vector2],specs:Array[Dictionary],travel_speed:float)->bool:
	if not cars.is_empty() or points.size()<3 or specs.is_empty():return false
	game=owner_game;city=owner_city;speed=maxf(0.0,travel_speed)
	for point in points:
		if route.is_empty() or route.back().distance_to(point)>.001:route.append(point)
	if route.size()>2 and route.front().distance_to(route.back())<.001:route.pop_back()
	if route.size()<3:return false
	cumulative.append(0.0)
	for i in route.size():
		route_length+=route[i].distance_to(route[(i+1)%route.size()]);cumulative.append(route_length)
	if route_length<1.0:return false
	var resources:Array[Dictionary]=[]
	for spec in specs:
		var resource:=Assets.visual(spec)
		if resource.is_empty():
			for loaded in resources:loaded.root.free()
			return false
		resources.append(resource)
	var tail_distance:=0.0
	for i in specs.size():
		var spec:Dictionary=specs[i];var resource:Dictionary=resources[i]
		var box:AABB=resource.bounds
		var body:=Car.new();body.game=game;body.train=weakref(self);body.train_index=i
		body.name="TrainCar_%s_%02d"%[str(spec.get("category","train")),i]
		body.category=str(spec.get("category","train"));body.points=maxi(1,int(spec.get("points",5)))
		body.height=box.size.y;body.half_size=box.size*.5
		body.footprint=Vector2(body.half_size.x,body.half_size.z).length()
		body.mass=maxf(.5,box.size.x*box.size.y*box.size.z*.4)
		body.set_meta("train_car",true);body.set_meta("train_index",i)
		body.set_meta("scripted_actor",true);body.set_meta("traffic",true)
		if spec.has("asset"):body.set_meta("train_asset",spec.asset)
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=box.size
		collision.shape=shape;body.add_child(collision)
		var view:Node3D=resource.root;view.position-=box.get_center();body.add_child(view)
		city.add_child(body)
		body.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC;body.collision_layer=2;body.collision_mask=1
		# A width-aware coupler gap preserves corner clearance on tight turns;
		# length-only spacing lets the inside rectangle corners interpenetrate.
		if i>0:tail_distance+=cars.back().half_size.z+body.half_size.z+maxf(.35,(cars.back().half_size.x+body.half_size.x)*.55)
		offsets.append(tail_distance);cars.append(body)
		max_half=max_half.max(body.half_size)
		city.foods.append(body)
		if city.has_method("register_food"):city.register_food(body)
		elif city.has_method("index_new_foods"):city.index_new_foods()
	attached_count=cars.size()
	var link_mesh:=BoxMesh.new();link_mesh.size=Vector3(.075,.07,1.0)
	var link_material:=StandardMaterial3D.new();link_material.albedo_color=Color("506074");link_material.roughness=.55
	for i in range(1,cars.size()):
		var link:=MeshInstance3D.new();link.mesh=link_mesh;link.material_override=link_material
		link.name="TrainCoupler_%02d"%i;city.add_child(link);couplers.append(link)
	bypass_offset=maxf(1.35,max_half.x*2.0+.30)
	query_shape.size=max_half*2.0+Vector3(CLEARANCE,0,CLEARANCE)
	# Populate the complete initial tail; no first-frame stacking or teleport.
	var sample:float=-tail_distance-1.0
	while sample<0.0:
		var pose:=base_pose(sample)
		history.append({"distance":sample,"base":sample,"at":pose.at,"forward":pose.forward})
		sample=minf(0.0,sample+SAMPLE_STEP)
	var first:=base_pose(0.0)
	history.append({"distance":0.0,"base":0.0,"at":first.at,"forward":first.forward})
	apply_coupled_poses()
	for body in cars:body.spawn_position=body.global_position
	return true

func base_point(distance:float)->Vector2:
	var s:=fposmod(distance,route_length)
	var low:=0;var high:=route.size()-1
	while low<high:
		var middle:int=(low+high+1)/2
		if cumulative[middle]<=s:low=middle
		else:high=middle-1
	var length:float=cumulative[low+1]-cumulative[low]
	return route[low].lerp(route[(low+1)%route.size()],(s-cumulative[low])/maxf(.0001,length))

func base_pose(distance:float)->Dictionary:
	return {"at":base_point(distance),"forward":(base_point(distance+.08)-base_point(distance-.08)).normalized()}

func smooth01(value:float)->float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func lateral_at(distance:float)->float:
	var lateral:=0.0
	for detour in detours:
		if distance<detour.start or distance>detour.end:continue
		var weight:float=minf(smooth01((distance-detour.start)/float(detour.get("ramp_in",ramp_length))),smooth01((detour.end-distance)/ramp_length))
		# A newly planned obstacle may overlap an existing bypass. Blend from
		# that existing curve instead of zeroing its offset at the new start.
		lateral=lerpf(lateral,float(detour.lateral),weight)
	return lateral

func path_point(distance:float)->Vector2:
	var pose:=base_pose(distance);var forward:Vector2=pose.forward
	return Vector2(pose.at)+Vector2(forward.y,-forward.x)*lateral_at(distance)

func path_pose(distance:float)->Dictionary:
	return {"at":path_point(distance),"forward":(path_point(distance+.04)-path_point(distance-.04)).normalized()}

func history_pose(distance:float)->Dictionary:
	for i in range(history.size()-2,-1,-1):
		var a:Dictionary=history[i];var b:Dictionary=history[i+1]
		if distance<float(a.distance):continue
		var ratio:float=clampf((distance-float(a.distance))/maxf(.00001,float(b.distance)-float(a.distance)),0,1)
		return {"at":Vector2(a.at).lerp(b.at,ratio),"forward":Vector2(a.forward).lerp(b.forward,ratio).normalized(),"base":lerpf(a.base,b.base,ratio)}
	return history.front()

func owns_live_city()->bool:
	return is_instance_valid(game) and is_instance_valid(city) and game.get("city")==city

func apply_coupled_poses()->void:
	if not owns_live_city():return
	for i in attached_count:
		var body=cars[i]
		if not is_instance_valid(body):continue
		var pose:=history_pose(traveled-offsets[i]);var forward:Vector2=pose.forward
		body.global_transform=Transform3D(Basis(Vector3.UP,atan2(forward.x,forward.y)),Vector3(pose.at.x,body.half_size.y+.035,pose.at.y))
		body.route_distance=pose.base
	for i in couplers.size():
		var link=couplers[i]
		if not is_instance_valid(link):continue
		link.visible=i+1<attached_count and is_instance_valid(cars[i]) and is_instance_valid(cars[i+1])
		if not link.visible:continue
		var a:Node3D=cars[i];var b:Node3D=cars[i+1]
		var rear:Vector3=a.global_position-a.global_basis.z*a.half_size.z
		var front:Vector3=b.global_position+b.global_basis.z*b.half_size.z
		rear.y=.20;front.y=.20
		var difference:=rear-front
		link.global_transform=Transform3D(Basis(Vector3.UP,atan2(difference.x,difference.z)).scaled(Vector3(1,1,maxf(.01,difference.length()))),(rear+front)*.5)

func detach_from(index:int)->void:
	if index<0 or index>=attached_count:return
	var poses:Array[Transform3D]=[]
	for i in range(index,attached_count):
		var body=cars[i]
		if not is_instance_valid(body):continue
		poses.append(body.global_transform);body.attached=false
		# Preserve exact current pose. The admitted car immediately enters the
		# unchanged RimBody fall/pull; the other cars remain ordinary edibles.
		body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
		body.freeze=true;body.sleeping=true
	detach_events.append({"index":index,"head_distance":head_distance,"poses":poses})
	attached_count=index;planning_needed=true
	for link_index in couplers.size():
		var link=couplers[link_index]
		if is_instance_valid(link):link.visible=link_index+1<attached_count

func parked_cars()->Array[Node3D]:
	var result:Array[Node3D]=[]
	for i in range(attached_count,cars.size()):
		var body=cars[i]
		if is_instance_valid(body) and not body.consumed and body.freeze:result.append(body)
	return result

func excluded_rids()->Array[RID]:
	var result:Array[RID]=[]
	if is_instance_valid(game.ground):result.append(game.ground.body.get_rid())
	for i in attached_count:
		if is_instance_valid(cars[i]):result.append(cars[i].get_rid())
	return result

func clear_pose(at:Vector2,forward:Vector2,half:Vector3,excluded:Array[RID])->bool:
	obstruction=null
	query_shape.size=half*2.0+Vector3(CLEARANCE,0,CLEARANCE)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=query_shape;query.collision_mask=3
	query.exclude=excluded;query.margin=.015
	query.transform=Transform3D(Basis(Vector3.UP,atan2(forward.x,forward.y)),Vector3(at.x,half.y+.035,at.y))
	var hits:=city.get_world_3d().direct_space_state.intersect_shape(query,1)
	if not hits.is_empty():obstruction=hits[0].collider;return false
	# Some frozen pedestrians deliberately have no collision layer. They still
	# occupy visible space, so the train cannot pass through their bodies.
	if city.has_method("query_foods"):
		for other in city.query_foods(Vector3(at.x,0,at.y),half.length()+2.0):
			if not is_instance_valid(other) or other.consumed or other.collision_layer!=0:continue
			if other.global_position.y-other.vertical_extent()>half.y*2.0+.1 or other.global_position.y+other.vertical_extent()<.02:continue
			var gap:=Vector2(other.global_position.x,other.global_position.z)-at
			var side:=Vector2(forward.y,-forward.x)
			if absf(gap.dot(side))<half.x+other.footprint+.08 and absf(gap.dot(forward))<half.z+other.footprint+.08:obstruction=other;return false
	return true

func nearest_route_distance(at:Vector2)->float:
	var best:=INF;var result:=0.0
	for i in route.size():
		var from:=route[i];var segment:=route[(i+1)%route.size()]-from
		var fraction:=clampf((at-from).dot(segment)/maxf(.0001,segment.length_squared()),0.0,1.0)
		var distance:=at.distance_squared_to(from+segment*fraction)
		if distance<best:best=distance;result=cumulative[i]+segment.length()*fraction
	return result

func probe_ahead(delta:float,excluded:Array[RID])->void:
	probe_clock-=delta
	if probe_clock>0.0:return
	probe_clock=.25
	for ahead in [3.0,6.0,9.0,12.0,15.0]:
		var pose:=path_pose(head_distance+ahead)
		if clear_pose(pose.at,pose.forward,max_half,excluded):continue
		if not is_instance_valid(obstruction):continue
		if not external_obstacles.has(obstruction) and not parked_cars().has(obstruction):
			external_obstacles.append(obstruction);planning_needed=true
		break

func detour_clear(plan:Dictionary,excluded:Array[RID])->bool:
	var old:=detours.duplicate();detours.append(plan)
	var distance:float=plan.start;var okay:=true
	while distance<=float(plan.end):
		var pose:=path_pose(distance)
		if not clear_pose(pose.at,pose.forward,max_half,excluded):okay=false;break
		distance+=.45
	detours=old
	return okay

func plan_parked()->void:
	planning_needed=false;planning_count+=1
	# Future changes never alter a path section under the current head. Followers
	# use recorded world-space history even when a future bypass is replanned.
	var kept:Array[Dictionary]=[]
	for plan in detours:
		if plan.start<=head_distance and plan.end>=head_distance:kept.append(plan)
	detours=kept
	var intervals:Array[Dictionary]=[]
	for body in parked_cars():
		var center:float=body.route_distance
		while center-ramp_length-max_half.z-body.half_size.z-.4<=head_distance+.2:center+=route_length
		var padding:float=max_half.z+body.half_size.z+.35
		intervals.append({"start":center-padding-ramp_length,"end":center+padding+ramp_length})
	var still_live:Array[Node3D]=[]
	for body in external_obstacles:
		if not is_instance_valid(body) or body.get("consumed")==true or body.global_position.y< -2:continue
		still_live.append(body)
		var center:=nearest_route_distance(Vector2(body.global_position.x,body.global_position.z))
		while center<head_distance:center+=route_length
		var other_half:Vector3=body.get("half_size") if body.get("half_size") is Vector3 else Vector3(1,1,1)
		var padding:=max_half.z+Vector2(other_half.x,other_half.z).length()+.35
		var start:=maxf(head_distance+.02,center-padding-ramp_length)
		intervals.append({"start":start,"end":center+padding+ramp_length,"ramp_in":maxf(.5,minf(ramp_length,center-padding-start))})
	external_obstacles=still_live
	intervals.sort_custom(func(a:Dictionary,b:Dictionary):return a.start<b.start)
	var merged:Array[Dictionary]=[]
	for interval in intervals:
		if not merged.is_empty() and interval.start<=merged.back().end:
			merged.back().end=maxf(merged.back().end,interval.end)
		else:merged.append(interval.duplicate())
	var excluded:=excluded_rids()
	var unresolved:=0
	for interval in merged:
		var found:=false
		for lateral in [bypass_offset,-bypass_offset]:
			var plan:Dictionary=interval.duplicate();plan["lateral"]=lateral
			if detour_clear(plan,excluded):detours.append(plan);found=true;break
		if not found:unresolved+=1
	# The admitted middle section is still a real temporary obstacle while it
	# falls. Retry a failed future plan well before the next lap; one transient
	# contact must not leave the head permanently using a blocked centerline.
	plan_retry_time=.5 if unresolved>0 else 0.0
	route_changed.emit(planned_branches())

func planned_branches()->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	for plan in detours:
		var points:=PackedVector2Array();var distance:float=plan.start
		while distance<plan.end:
			points.append(path_point(distance));distance+=.25
		points.append(path_point(plan.end));result.append(points)
	return result

func step(delta:float)->void:
	# A retained controller must not operate on a destroyed or replaced map.
	# Validity alone is insufficient when the former city remains alive during
	# a transition; ownership must still point to this exact scene instance.
	if delta<=0.0 or not owns_live_city() or game.phase!="playing" or game.get_tree().paused or attached_count==0:return
	for i in attached_count:
		var body=cars[i]
		if not is_instance_valid(body) or not body.freeze or is_instance_valid(body.claimed_by) or body.pull_time>0.0:
			detach_from(i);break
	if attached_count==0:return
	if plan_retry_time>0.0:
		plan_retry_time=maxf(0.0,plan_retry_time-delta)
		if plan_retry_time<=0.0:planning_needed=true
	if not detours.is_empty() and head_distance>float(detours.back().end):planning_needed=true
	if planning_needed:plan_parked()
	var excluded:=excluded_rids();blocked=false
	probe_ahead(delta,excluded)
	if planning_needed:plan_parked()
	var remaining:=minf(speed*delta,48.0)
	while remaining>.00001:
		var advance:=minf(SAMPLE_STEP,remaining)
		var from:Vector2=history.back().at
		# The lateral curve is longer than its centerline; normalize the advance
		# by its local derivative so physical head speed stays distance-based.
		var derivative:float=(path_point(head_distance+.025)-path_point(head_distance-.025)).length()/.05
		var next_distance:=head_distance+advance/maxf(.2,derivative)
		var pose:=path_pose(next_distance);var distance:float=from.distance_to(pose.at)
		if distance>advance*1.001:
			next_distance=head_distance+(next_distance-head_distance)*advance/distance
			pose=path_pose(next_distance);distance=from.distance_to(pose.at)
		var proposed:={"distance":traveled+distance,"base":next_distance,"at":pose.at,"forward":pose.forward}
		history.append(proposed)
		var clear:=true
		for i in attached_count:
			var car_pose:=history_pose(traveled+distance-offsets[i])
			if not clear_pose(car_pose.at,car_pose.forward,cars[i].half_size,excluded):clear=false;break
		if not clear:
			history.pop_back();blocked=true;blocked_steps+=1;break
		head_distance=next_distance;traveled+=distance;remaining-=advance
		apply_coupled_poses()
	# A bounded history contains only the head-to-tail path and a short margin.
	var keep_after:float=traveled-offsets[maxi(0,attached_count-1)]-1.0
	while history.size()>2 and history[1].distance<keep_after:history.pop_front()

func diagnostics()->Dictionary:
	return {"cars":cars.size(),"attached":attached_count,"parked":parked_cars().size(),"route_length":route_length,"head_distance":head_distance,"traveled":traveled,"blocked":blocked,"blocked_steps":blocked_steps,"detachments":detach_events.size(),"history_samples":history.size(),"detours":detours.duplicate(true),"planning_count":planning_count}
