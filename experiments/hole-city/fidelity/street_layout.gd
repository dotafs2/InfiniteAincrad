extends RefCounted
## Shared road geometry for rendering, traffic and pedestrian validation.
const WorldBounds=preload("res://fidelity/world_bounds.gd")
const OUTER_ROAD:=WorldBounds.CITY_RING
const OUTER_HALF_WIDTH:=WorldBounds.CITY_RING_HALF_WIDTH
const ROAD_X:=Vector2(-27.0,29.0)
const ROAD_Z:=Vector2(-2.0,-30.0)
const HALF_WIDTH:=4.1
const SIDEWALKS:Array[Rect2]=[
	Rect2(-20.5,3.3,42.0,4.0),
	Rect2(-20.5,-10.2,42.0,3.0),
	Rect2(-20.5,37.8,42.0,3.5),
	Rect2(-20.5,-25.0,42.0,3.2)
]
const WALK_HALF_WIDTH:=1.05
const WALK_LOOPS:Array[Rect2]=[
	Rect2(-21.4,5.0,43.5,35.5),
	Rect2(-21.4,-23.4,43.5,15.0),
	Rect2(-21.4,-71.0,43.5,29.0),
	Rect2(-21.4,42.4,43.5,29.0)
]
static func walk_length(route:int)->float:
	return 2.0*(WALK_LOOPS[route].size.x+WALK_LOOPS[route].size.y)
static func walk_sample(progress:float,route:int)->Vector2:
	var rect:=WALK_LOOPS[route]
	var distance:=fposmod(progress,walk_length(route))
	if distance<rect.size.x:return rect.position+Vector2(distance,0)
	distance-=rect.size.x
	if distance<rect.size.y:return Vector2(rect.end.x,rect.position.y+distance)
	distance-=rect.size.y
	if distance<rect.size.x:return rect.end-Vector2(distance,0)
	return Vector2(rect.position.x,rect.end.y-(distance-rect.size.x))
static func walk_closest(at:Vector2,route:int)->Dictionary:
	var rect:=WALK_LOOPS[route]
	var corners:=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	var best:=INF;var result:={};var progress:=0.0
	for i in 4:
		var a:Vector2=corners[i];var b:Vector2=corners[(i+1)%4]
		var point:=Geometry2D.get_closest_point_to_segment(at,a,b)
		var distance:=at.distance_squared_to(point)
		if distance<best:best=distance;result={"at":point,"progress":progress+a.distance_to(point)}
		progress+=a.distance_to(b)
	return result
static func walk_constrain(at:Vector2,route:int)->Vector2:
	var closest:Vector2=walk_closest(at,route).at
	return closest+(at-closest).limit_length(WALK_HALF_WIDTH-.30)
static func walk_clearance_rects()->Array[Rect2]:
	var result:Array[Rect2]=[]
	for area in WALK_LOOPS:
		var h:=WALK_HALF_WIDTH
		result.append(Rect2(area.position-Vector2(h,h),Vector2(area.size.x+2*h,2*h)))
		result.append(Rect2(Vector2(area.position.x-h,area.end.y-h),Vector2(area.size.x+2*h,2*h)))
		result.append(Rect2(area.position-Vector2(h,h),Vector2(2*h,area.size.y+2*h)))
		result.append(Rect2(Vector2(area.end.x-h,area.position.y-h),Vector2(2*h,area.size.y+2*h)))
	return result
static func intersects_walk(rect:Rect2)->bool:
	for path in walk_clearance_rects():
		if rect.intersects(path):return true
	return false
static func on_road(at:Vector2,margin:=0.0)->bool:
	return absf(at.x-ROAD_X.x)<HALF_WIDTH+margin or absf(at.x-ROAD_X.y)<HALF_WIDTH+margin or absf(at.y-ROAD_Z.x)<HALF_WIDTH+margin or absf(at.y-ROAD_Z.y)<HALF_WIDTH+margin or absf(maxf(absf(at.x),absf(at.y))-OUTER_ROAD)<OUTER_HALF_WIDTH+margin
static func sidewalk_point(at:Vector2,region:int)->Vector2:
	var area:=SIDEWALKS[region].grow(-.3)
	return at.clamp(area.position,area.end)
static func traffic_spec(index:int)->Dictionary:
	var lane:int=index%2
	var progress:float=traffic_length(lane)*float(index/2)/4.0
	var pose:=traffic_sample(progress,lane)
	return {"route":lane,"progress":progress,"speed":2.4+float(index%3)*.2,"at":pose.at,"angle":atan2(pose.forward.x,pose.forward.y)}

static func traffic_rect(route:int)->Rect2:
	var inset:float=-1.8 if route==0 else 1.8
	return Rect2(Vector2(ROAD_X.x+inset,ROAD_Z.y+inset),Vector2(ROAD_X.y-ROAD_X.x-2.0*inset,ROAD_Z.x-ROAD_Z.y-2.0*inset))

static func traffic_length(route:int)->float:
	var rect:=traffic_rect(route)
	return 2.0*(rect.size.x+rect.size.y-16.0)+TAU*4.0

static func traffic_sample(progress:float,route:int)->Dictionary:
	# Two opposite, rounded block loops follow the four rendered avenues.
	# The modulo wraps arc length, never world coordinates: the seam has the
	# same position and tangent, including when an entire loop is visible.
	var rect:=traffic_rect(route)
	var radius:=4.0
	var horizontal:=rect.size.x-radius*2.0
	var vertical:=rect.size.y-radius*2.0
	var arc:=PI*.5*radius
	var distance:=fposmod(progress if route==0 else -progress,traffic_length(route))
	var at:=Vector2.ZERO;var forward:=Vector2.ZERO
	var lengths:=[horizontal,arc,vertical,arc,horizontal,arc,vertical,arc]
	for segment in 8:
		if distance>float(lengths[segment]):distance-=float(lengths[segment]);continue
		if segment%2==0:
			var starts:=[Vector2(rect.position.x+radius,rect.position.y),Vector2(rect.end.x,rect.position.y+radius),Vector2(rect.end.x-radius,rect.end.y),Vector2(rect.position.x,rect.end.y-radius)]
			var directions:=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
			forward=directions[segment/2];at=starts[segment/2]+forward*distance
		else:
			var centers:=[Vector2(rect.end.x-radius,rect.position.y+radius),Vector2(rect.end.x-radius,rect.end.y-radius),Vector2(rect.position.x+radius,rect.end.y-radius),Vector2(rect.position.x+radius,rect.position.y+radius)]
			var angle:float=-PI*.5+float(segment/2)*PI*.5+distance/radius
			at=centers[segment/2]+Vector2.from_angle(angle)*radius
			forward=Vector2(-sin(angle),cos(angle))
		break
	if route==1:forward=-forward
	return {"at":at,"forward":forward}
