extends RefCounted
## Continuous palace-road loops. Their seams never teleport a walking actor.
const WORLD_LIMIT:=94.0
const HALF_WIDTH:=2.8

const PATHS:Array[Array]=[
		[Vector2(-44,18),Vector2(0,18),Vector2(0,60),Vector2(-44,60)],
		[Vector2(0,18),Vector2(44,18),Vector2(44,60),Vector2(0,60)],
		[Vector2(-44,-36),Vector2(0,-36),Vector2(0,18),Vector2(-44,18)],
		[Vector2(0,-36),Vector2(44,-36),Vector2(44,18),Vector2(0,18)],
		[Vector2(-84,-84),Vector2(84,-84),Vector2(84,84),Vector2(-84,84)],
		[Vector2(-44,-36),Vector2(44,-36),Vector2(44,60),Vector2(-44,60)]
	]
const LENGTHS:Array[float]=[172.0,172.0,196.0,196.0,672.0,368.0]

static func paths()->Array[Array]:return PATHS

static func length(route:int)->float:
	return LENGTHS[posmod(route,PATHS.size())]

static func sample(progress:float,route:int)->Dictionary:
	var points:Array=paths()[posmod(route,paths().size())]
	var remaining:=fposmod(progress,length(route))
	for index in points.size():
		var a:Vector2=points[index];var b:Vector2=points[(index+1)%points.size()]
		var distance:=a.distance_to(b)
		if remaining<=distance:return {"at":a+(b-a).normalized()*remaining,"forward":(b-a).normalized()}
		remaining-=distance
	return {"at":points[0],"forward":(Vector2(points[1])-Vector2(points[0])).normalized()}

static func closest(at:Vector2,route:int)->Dictionary:
	var points:Array=paths()[posmod(route,paths().size())]
	var result:={"at":Vector2.ZERO,"progress":0.0,"distance":INF,"forward":Vector2.DOWN}
	var travelled:=0.0
	for index in points.size():
		var a:Vector2=points[index];var b:Vector2=points[(index+1)%points.size()]
		var point:=Geometry2D.get_closest_point_to_segment(at,a,b)
		var distance:=point.distance_squared_to(at)
		if distance<float(result.distance):result={"at":point,"progress":travelled+a.distance_to(point),"distance":distance,"forward":(b-a).normalized()}
		travelled+=a.distance_to(b)
	return result

static func constrain(at:Vector2,route:int,half_width:=HALF_WIDTH)->Vector2:
	var center:Vector2=closest(at,route).at
	return (center+(at-center).limit_length(half_width)).clamp(Vector2(-WORLD_LIMIT,-WORLD_LIMIT),Vector2(WORLD_LIMIT,WORLD_LIMIT))

static func guard_station(group:int)->Vector2:
	return [Vector2(-23,18),Vector2(23,18),Vector2(-23,-36),Vector2(23,-36)][posmod(group,4)]

static func metadata()->Dictionary:
	return {"paths":paths(),"half_width":HALF_WIDTH,"world_limit":WORLD_LIMIT,"guards_change_every":18.0,"formation_columns":2,"formation_spacing":1.05}
