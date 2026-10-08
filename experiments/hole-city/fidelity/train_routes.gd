extends RefCounted
## Use the existing perimeter streets, leaving the original traffic intact.
const Neighborhoods=preload("res://fidelity/food_neighborhoods.gd")
const SUSHI:=["gunkan","salmon","tuna","shrimp","eel","tamago","roe","mackerel"]

static func city_route()->Array[Vector2]:
	var points:Array[Vector2]=[]
	const EDGE:=84.4
	const RADIUS:=4.0
	var centers:=[Vector2(EDGE-RADIUS,-EDGE+RADIUS),Vector2(EDGE-RADIUS,EDGE-RADIUS),Vector2(-EDGE+RADIUS,EDGE-RADIUS),Vector2(-EDGE+RADIUS,-EDGE+RADIUS)]
	for corner in 4:
		var start:float=-PI*.5+float(corner)*PI*.5
		for i in 13:points.append(centers[corner]+Vector2.from_angle(start+float(i)/12.0*PI*.5)*RADIUS)
	return points

static func food_route()->Array[Vector2]:
	var points:Array[Vector2]=[]
	for node in range(12,20):
		for road in Neighborhoods.plan().roads:
			if int(road.from)!=node or int(road.to)!=(12 if node==19 else node+1):continue
			for point in road.path:
				if points.is_empty() or points.back().distance_to(point)>.001:points.append(point)
	if points.size()>1 and points.front().distance_to(points.back())<.001:points.pop_back()
	return points

static func specs(map_id:String)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if map_id=="food":
		for kind in SUSHI:result.append({"asset":"res://assets/trains/sushi_%s.glb"%kind,"category":"sushi","points":10})
	else:
		for i in 4:result.append({"asset":"res://assets/trains/%s.glb"%("rail_cab" if i==0 else "rail_car"),"category":"tram","points":15})
	return result
