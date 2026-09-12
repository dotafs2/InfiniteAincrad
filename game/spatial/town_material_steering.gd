extends RefCounted
## Bounded local two-leg steering for MATERIAL recovery jobs only.
##
## This is a small runtime helper (never persisted world state). It performs a
## fixed, bounded left/right perpendicular waypoint search for goals within
## 4 horizontal meters, using the real capsule sweep (body.test_move) without
## moving the body. It does NOT introduce a navmesh, broad world pathfinding,
## NPC decisions or new action schemas.
##
## Explicit limitation: a two-segment detour cannot solve mazes or fully
## enclosed goals. Unreachable jobs stay unfinished and keep their elapsed
## work/resources/history. A fully enclosing barrier remains a visible
## unsolved path case.

const MAX_GOAL_DISTANCE := 4.0
const ARRIVAL_RADIUS := 0.30
const WAYPOINT_REACHED := 0.15
const TARGET_TOLERANCE := 0.05
const CANDIDATE_DISTANCES := [0.8, 1.2, 1.8, 2.4]

var _routes: Dictionary = {}

func retain_active(ids: Array) -> void:
	var keep := {}
	for id in ids:
		keep[str(id)] = true
	for key in _routes.keys():
		if not keep.has(key):
			_routes.erase(key)

func clear_route(id: String) -> void:
	_routes.erase(id)

func direction_for(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	if not Engine.is_in_physics_frame():
		return Vector3.ZERO
	if id.is_empty() or command_id.is_empty():
		_routes.erase(id)
		return Vector3.ZERO
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		_routes.erase(id)
		return Vector3.ZERO
	if not body.global_position.is_finite() or not target.is_finite():
		_routes.erase(id)
		return Vector3.ZERO
	var goal := target
	goal.y = body.global_position.y
	var to_goal := goal - body.global_position
	to_goal.y = 0.0
	if to_goal.length() <= ARRIVAL_RADIUS:
		_routes.erase(id)
		return Vector3.ZERO
	if to_goal.length() > MAX_GOAL_DISTANCE:
		_routes.erase(id)
		return to_goal.normalized()
	if _corridor_clear(body, body.global_position, to_goal):
		_routes.erase(id)
		return to_goal.normalized()
	var cached: Dictionary = _routes.get(id, {})
	if not cached.is_empty() and _route_still_valid(cached, command_id, goal, body):
		var waypoint: Vector3 = cached.waypoint
		var to_waypoint := waypoint - body.global_position
		to_waypoint.y = 0.0
		if to_waypoint.length() <= WAYPOINT_REACHED:
			_routes.erase(id)
		else:
			return to_waypoint.normalized()
	var chosen: Variant = _choose_waypoint(body, goal)
	if chosen == null:
		_routes.erase(id)
		return Vector3.ZERO
	_routes[id] = {
		"command_id": command_id,
		"target": goal,
		"body_id": body.get_instance_id(),
		"waypoint": chosen,
	}
	var first_leg: Vector3 = chosen - body.global_position
	first_leg.y = 0.0
	if first_leg.length() <= WAYPOINT_REACHED:
		return to_goal.normalized()
	return first_leg.normalized()

func _route_still_valid(cached: Dictionary, command_id: String, goal: Vector3, body: CharacterBody3D) -> bool:
	if str(cached.get("command_id", "")) != command_id:
		return false
	if int(cached.get("body_id", 0)) != body.get_instance_id():
		return false
	var cached_target: Vector3 = cached.get("target", Vector3.INF)
	if not cached_target.is_finite():
		return false
	var flat_target := cached_target
	flat_target.y = goal.y
	if flat_target.distance_to(goal) > TARGET_TOLERANCE:
		return false
	var waypoint: Vector3 = cached.get("waypoint", Vector3.INF)
	if not waypoint.is_finite():
		return false
	waypoint.y = body.global_position.y
	if not _corridor_clear(body, body.global_position, waypoint - body.global_position):
		return false
	if not _corridor_clear(body, waypoint, goal - waypoint):
		return false
	return true

func _choose_waypoint(body: CharacterBody3D, goal: Vector3) -> Variant:
	var to_goal := goal - body.global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.001:
		return null
	var forward := to_goal.normalized()
	var left := Vector3(-forward.z, 0.0, forward.x)
	var right := Vector3(forward.z, 0.0, -forward.x)
	var best: Variant = null
	var best_distance := INF
	for distance in CANDIDATE_DISTANCES:
		for side in [left, right]:
			var waypoint: Vector3 = body.global_position + side * distance
			waypoint.y = body.global_position.y
			var first_leg: Vector3 = waypoint - body.global_position
			first_leg.y = 0.0
			var second_leg: Vector3 = goal - waypoint
			second_leg.y = 0.0
			if not _corridor_clear(body, body.global_position, first_leg):
				continue
			if not _corridor_clear(body, waypoint, second_leg):
				continue
			var total: float = first_leg.length() + second_leg.length()
			if total < best_distance:
				best_distance = total
				best = waypoint
	return best

func _corridor_clear(body: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	var flat := motion
	flat.y = 0.0
	if flat.length() < 0.001:
		return true
	var probe := body.global_transform
	probe.origin = from
	return not body.test_move(probe, flat)
