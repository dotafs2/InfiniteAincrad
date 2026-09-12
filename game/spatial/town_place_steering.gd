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

const Catalog := preload("res://spatial/town_places.gd")
const TARGET_MATCH_TOLERANCE := 0.6
const LEG_WAYPOINT_REACH := 1.2
## The reused bounded search only detours within its own 4 m goal bound, so each long leg is
## handed over as a short sub-goal ON the same straight line toward the road node. The body
## therefore keeps walking the road graph while the existing two-leg search can still work
## around a stationary neighbour or a prop in the middle of a leg.
const LEG_SUB_GOAL := 3.4

var _place_routes: Dictionary = {}

func retain_active(ids: Array) -> void:
	super.retain_active(ids)
	for id in _place_routes.keys():
		if id not in ids:
			_place_routes.erase(id)

func clear_route(id: String) -> void:
	super.clear_route(id)
	_place_routes.erase(id)

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
