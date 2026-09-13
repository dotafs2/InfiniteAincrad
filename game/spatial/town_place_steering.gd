extends "res://spatial/town_foraging_steering.gd"
## Explicit road-graph steering for VOLUNTARY PLACE TRAVEL and place-bound rest.
##
## The route is the catalog's small connected road graph (nodes measured on the accepted
## run9 route). This helper walks the body leg by leg along those nodes and hands each leg to
## the already-reviewed bounded two-leg detour search, so local avoidance is exactly the
## behaviour the material and foraging journeys use: real capsule sweeps, no navmesh, no wall
## cutting, no teleport, no step-up assist, no changed final destination.
##
## It adds no world state. The route cache is runtime-only, is re-validated every frame
## against the command id, the body and the target, and never enters a save or a model view.
##
## The SAME verified graph also carries the basic-life walk back to a resident's own fixed
## point (eat_ration, and rest with no public place target), through direction_to_point(). A
## resident that walked down into the lower field cannot come home on the straight local push:
## outside the junction ramp the market floor's south lip is a vertical step the 0.25 m resident
## capsule cannot climb, so the body stops there while its accepted job stays unfinished and
## accrues no time. The graph route crosses that junction on the ramp, exactly like a place trip.
## Same leg handing, same bounded search, same world-owned 0.45 m arrival gate, no new state,
## no teleport, no rewritten destination.

const Catalog := preload("res://spatial/town_places.gd")
const TARGET_MATCH_TOLERANCE := 0.6
const LEG_WAYPOINT_REACH := 1.2
## The reused bounded search only detours within its own 4 m goal bound, so each long leg is
## handed over as a short sub-goal ON the same straight line toward the road node. The body
## therefore keeps walking the road graph while the existing two-leg search can still work
## around a stationary neighbour or a prop in the middle of a leg.
const LEG_SUB_GOAL := 3.4

var _place_routes: Dictionary = {}
var _point_routes: Dictionary = {}

func retain_active(ids: Array) -> void:
	super.retain_active(ids)
	for id in _place_routes.keys():
		if id not in ids:
			_place_routes.erase(id)
	for id in _point_routes.keys():
		if id not in ids:
			_point_routes.erase(id)

func clear_route(id: String) -> void:
	super.clear_route(id)
	_place_routes.erase(id)
	_point_routes.erase(id)

func direction_for(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	if not Engine.is_in_physics_frame() or body == null or not is_instance_valid(body) or not body.is_inside_tree() or not target.is_finite():
		return Vector3.ZERO
	var goal := target
	goal.y = body.global_position.y
	var offset := goal - body.global_position
	if offset.length() <= ARRIVAL_RADIUS:
		clear_route(id)
		return Vector3.ZERO
	var cached: Dictionary = _place_routes.get(id, {})
	if not cached.is_empty() and _cache_valid(cached, command_id, body, goal):
		var points: Array = cached.points
		while not points.is_empty() and Vector3(points[0]).distance_to(body.global_position) <= LEG_WAYPOINT_REACH:
			points.pop_front()
		if points.is_empty():
			## The road part of the journey is finished: the body is close to its own final point.
			## The completed route is RETAINED (marked final) until the world's own arrival gate
			## closes the trip, so no later frame rebuilds the road from a node behind the resident
			## and walks it backwards. Only a real arrival, a new command or clear_route drops it.
			cached.final_approach = true
			return _approach(id, command_id, goal, body)
		## While the road legs remain, a stale "final approach" flag must not survive a re-extension.
		cached.final_approach = false
		var leg_goal := _sub_goal(body.global_position, points[0])
		var direction := super.direction_for(id, command_id, body, leg_goal)
		# The bounded search may stop (bodies in contact). Keep the honest straight push at
		# the LEG, never at a rewritten destination.
		if direction.length() <= 0.0:
			var to_leg := leg_goal - body.global_position
			to_leg.y = 0.0
			if to_leg.length() > 0.001:
				direction = to_leg.normalized()
		return direction
	_place_routes.erase(id)
	_point_routes.erase(id)
	var place_id := Catalog.place_for_point(target)
	if place_id.is_empty():
		return super.direction_for(id, command_id, body, goal)
	var points := Catalog.path_points(place_id, body.global_position, _slot_for(place_id, target))
	if points.is_empty():
		return super.direction_for(id, command_id, body, goal)
	_place_routes[id] = {"command_id": command_id, "body_id": body.get_instance_id(),
		"place_id": place_id, "target": goal, "points": points, "final_approach": false}
	while not points.is_empty() and Vector3(points[0]).distance_to(body.global_position) <= LEG_WAYPOINT_REACH:
		points.pop_front()
	if points.is_empty():
		_place_routes[id].final_approach = true
		return _approach(id, command_id, goal, body)
	return super.direction_for(id, command_id, body, _sub_goal(body.global_position, points[0]))

func direction_to_point(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	## The same road-graph journey, ended at the resident's OWN fixed point instead of a catalog
	## arrival slot. It only decides which direction the body walks this frame; the trip still ends
	## through the world's own arrival gate, never here.
	if not Engine.is_in_physics_frame() or body == null or not is_instance_valid(body) or not body.is_inside_tree() or not target.is_finite():
		return Vector3.ZERO
	var goal := target
	goal.y = body.global_position.y
	var offset := goal - body.global_position
	if offset.length() <= ARRIVAL_RADIUS:
		clear_route(id)
		return Vector3.ZERO
	var cached: Dictionary = _point_routes.get(id, {})
	if not cached.is_empty() and _cache_valid(cached, command_id, body, goal):
		var points: Array = cached.points
		while not points.is_empty() and Vector3(points[0]).distance_to(body.global_position) <= LEG_WAYPOINT_REACH:
			points.pop_front()
		if points.is_empty():
			## Road part finished: retain the completed route and do the honest final approach,
			## so no later frame rebuilds the road from a node behind the resident.
			cached.final_approach = true
			return _approach(id, command_id, goal, body)
		cached.final_approach = false
		var leg_goal := _sub_goal(body.global_position, points[0])
		var direction := super.direction_for(id, command_id, body, leg_goal)
		if direction.length() <= 0.0:
			var to_leg := leg_goal - body.global_position
			to_leg.y = 0.0
			if to_leg.length() > 0.001:
				direction = to_leg.normalized()
		return direction
	_point_routes.erase(id)
	_place_routes.erase(id)
	var route := _point_path(target, body.global_position)
	if route.is_empty():
		## Either end is off the verified graph: keep the pre-existing local push rather than
		## inventing a road, and let the world's own gate decide the outcome.
		return super.direction_for(id, command_id, body, goal)
	_point_routes[id] = {"command_id": command_id, "body_id": body.get_instance_id(),
		"target": goal, "points": route, "final_approach": false}
	while not route.is_empty() and Vector3(route[0]).distance_to(body.global_position) <= LEG_WAYPOINT_REACH:
		route.pop_front()
	if route.is_empty():
		_point_routes[id].final_approach = true
		return _approach(id, command_id, goal, body)
	return super.direction_for(id, command_id, body, _sub_goal(body.global_position, route[0]))

func _point_path(target: Vector3, from: Vector3) -> Array:
	## Catalog graph nodes from the node nearest the body to the node nearest its own point, then
	## the point itself. Geometry only; [] when either end cannot be placed on the verified graph.
	if not target.is_finite() or not from.is_finite():
		return []
	var names := _node_route(Catalog.nearest_node(from), Catalog.nearest_node(target))
	if names.is_empty():
		return []
	var points: Array = []
	for name in names:
		var node: Array = Catalog.ROAD_NODES[name]
		points.append(Vector3(node[0], node[1], node[2]))
	points.append(target)
	return points

func _node_route(start: String, goal: String) -> Array:
	## Breadth-first walk of the catalog's verified road graph, so a home journey uses exactly the
	## paved legs the place journeys were accepted on and never a diagonal across the house rows.
	if start.is_empty() or goal.is_empty():
		return []
	var graph: Dictionary = {}
	for name in Catalog.ROAD_NODES:
		graph[name] = []
	for edge in Catalog.ROAD_EDGES:
		var pair: Array = edge
		var first: String = str(pair[0])
		var second: String = str(pair[1])
		if not graph.has(first) or not graph.has(second):
			continue
		graph[first].append(second)
		graph[second].append(first)
	if not graph.has(start) or not graph.has(goal):
		return []
	if start == goal:
		return [start]
	var queue: Array = [start]
	var came_from: Dictionary = {start: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == goal:
			break
		for neighbour in graph[current]:
			if came_from.has(neighbour):
				continue
			came_from[neighbour] = current
			queue.append(neighbour)
	if not came_from.has(goal):
		return []
	var reversed: Array = []
	var step := goal
	while step != "":
		reversed.append(step)
		step = str(came_from[step])
	reversed.reverse()
	return reversed

func _approach(id: String, command_id: String, goal: Vector3, body: CharacterBody3D) -> Vector3:
	## Final approach with NO road rebuild: the reviewed bounded detour may still work around a
	## bystander, and when it stops the body keeps the honest straight push at its own target.
	## The trip ends only through the world's own arrival gate, never by this helper.
	var direction := super.direction_for(id, command_id, body, goal)
	if direction.length() > 0.0:
		return direction
	var to_goal := goal - body.global_position
	to_goal.y = 0.0
	if to_goal.length() <= 0.001:
		return Vector3.ZERO
	return to_goal.normalized()

func _sub_goal(from: Vector3, waypoint: Vector3) -> Vector3:
	## A point on the same line to the waypoint, no farther than the reused search's bound.
	var offset := waypoint - from
	offset.y = 0.0
	if offset.length() <= LEG_SUB_GOAL:
		return waypoint
	var limited := from + offset.normalized() * LEG_SUB_GOAL
	limited.y = waypoint.y
	return limited

func _cache_valid(cached: Dictionary, command_id: String, body: CharacterBody3D, goal: Vector3) -> bool:
	if str(cached.get("command_id", "")) != command_id:
		return false
	if int(cached.get("body_id", 0)) != body.get_instance_id():
		return false
	var cached_target: Vector3 = cached.get("target", Vector3.INF)
	if not cached_target.is_finite():
		return false
	var flat := cached_target
	flat.y = goal.y
	return flat.distance_to(goal) <= TARGET_MATCH_TOLERANCE

func _slot_for(place_id: String, target: Vector3) -> int:
	for slot in Catalog.offset_count(place_id):
		if Catalog.slot_point(place_id, slot).distance_to(target) <= 0.05:
			return slot
	return 0
