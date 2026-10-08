extends RefCounted
## The atlas, frontage, pedestrian constraints and QA share one authored plan.
const PLAN_PATH:="res://assets/food_city/neighborhoods.json"
const ATLAS_PATH:="res://assets/food_city/streets.png"
const WorldBounds=preload("res://fidelity/world_bounds.gd")
static var cached:Dictionary={}
static func plan()->Dictionary:
	if cached.is_empty():
		cached=JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
		for route in cached.routes+cached.roads+[cached.traffic]+cached.get("traffic_routes",[]):
			var path:=PackedVector2Array()
			for p in route.points:path.append(point(p))
			route["path"]=path
			var lengths:=PackedFloat32Array([0.0])
			for i in path.size()-1:lengths.append(lengths[-1]+path[i].distance_to(path[i+1]))
			route["lengths"]=lengths
			route["length"]=lengths[-1]
		# Every delivery lane inherits exactly the painted connected road path.
		if not cached.has("traffic_routes"):cached["traffic_routes"]=[cached.traffic]
		for route in cached.traffic_routes:
			var lane:=PackedVector2Array();var road:PackedVector2Array=route.path
			for i in road.size()-1:
				var tangent:Vector2=(road[(i+1)%(road.size()-1)]-road[posmod(i-1,road.size()-1)]).normalized()
				lane.append(road[i]+Vector2(-tangent.y,tangent.x)*float(route.get("lane_offset",1.35)))
			lane.append(lane[0]);route["lane"]=lane
			var lengths:=PackedFloat32Array([0.0])
			for i in lane.size()-1:lengths.append(lengths[-1]+lane[i].distance_to(lane[i+1]))
			route["lane_lengths"]=lengths;route["lane_length"]=lengths[-1]
		cached.traffic=cached.traffic_routes[0]
	return cached
static func point(values:Array)->Vector2:return Vector2(values[0],values[1])
static func atlas_uv(at:Vector2)->Vector2:return (at+Vector2.ONE*WorldBounds.HALF)/(WorldBounds.HALF*2.0)
static func closest(at:Vector2,route:Dictionary)->Vector2:
	var nearest:=Vector2.ZERO;var best:=INF
	var path:PackedVector2Array=route.path
	for i in path.size()-1:
		var a:=path[i];var b:=path[i+1]
		var t:=clampf((at-a).dot(b-a)/(b-a).length_squared(),0,1)
		var q:=a.lerp(b,t);var d:=q.distance_squared_to(at)
		if d<best:best=d;nearest=q
	return nearest
static func constrain(at:Vector2,route:Dictionary)->Vector2:
	var center:=closest(at,route)
	return center+(at-center).limit_length(maxf(.1,float(route.half_width)-.4))

static func lane_length(route_id:=0)->float:return float(plan().traffic_routes[route_id].lane_length)

static func lane_sample(progress:float,route_id:=0)->Dictionary:
	var route:Dictionary=plan().traffic_routes[route_id]
	var path:PackedVector2Array=route.lane
	var lengths:PackedFloat32Array=route.lane_lengths
	var along:=fposmod(progress,float(route.lane_length))
	var low:=0;var high:=lengths.size()-1
	while high-low>1:
		var middle:int=(low+high)/2
		if lengths[middle]<=along:low=middle
		else:high=middle
	var direction:Vector2=(path[high]-path[low]).normalized()
	return {"at":path[low].lerp(path[high],(along-lengths[low])/(lengths[high]-lengths[low])),"forward":direction}

static func on_road(at:Vector2,margin:=0.0)->bool:
	for road in plan().roads:
		if closest(at,road).distance_squared_to(at)<pow(float(road.half_width)+margin,2):return true
	return false
