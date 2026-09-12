extends "res://spatial/town_material_steering.gd"
## For the observed two-neighbor obstruction at the shared patch, try one extra
## parallel leg after the existing two-leg search fails. Eight fixed rectangles,
## the same four-meter goal bound, and real capsule sweeps on every segment.
## Other residents remain physical and retain their own decisions/positions.

var _rectangles: Dictionary = {}
var _retry_after_frame: Dictionary = {}

func retain_active(ids: Array) -> void:
	super.retain_active(ids)
	for id in _rectangles.keys():
		if id not in ids:
			_rectangles.erase(id)
	for id in _retry_after_frame.keys():
		if id not in ids:
			_retry_after_frame.erase(id)

func clear_route(id: String) -> void:
	super.clear_route(id)
	_rectangles.erase(id)
	_retry_after_frame.erase(id)

func direction_for(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	if not Engine.is_in_physics_frame() or body == null or not is_instance_valid(body) or not body.is_inside_tree() or not target.is_finite():
		return Vector3.ZERO
	var goal := target
	goal.y = body.global_position.y
	var offset := goal - body.global_position
	if offset.length() <= ARRIVAL_RADIUS:
		clear_route(id)
		return Vector3.ZERO
	var route: Dictionary = _rectangles.get(id, {})
	if not route.is_empty():
		var same: bool = route.command_id == command_id and route.body_id == body.get_instance_id() and Vector3(route.target).distance_to(goal) <= TARGET_TOLERANCE
		if same:
			var points: Array = route.points
			while not points.is_empty() and body.global_position.distance_to(Vector3(points[0])) <= WAYPOINT_REACHED:
				points.pop_front()
			if not points.is_empty() and _clear_segments(body, points, goal):
				return (Vector3(points[0]) - body.global_position).normalized()
		_rectangles.erase(id)
	var ordinary := super.direction_for(id, command_id, body, target)
	if ordinary.length() > 0.0 or offset.length() > MAX_GOAL_DISTANCE or id.is_empty() or command_id.is_empty():
		return ordinary
	if Engine.get_physics_frames() < int(_retry_after_frame.get(id, 0)):
		return Vector3.ZERO
	var forward := offset.normalized()
	var left := Vector3(-forward.z, 0.0, forward.x)
	for distance in CANDIDATE_DISTANCES:
		for side in [left, -left]:
			var shift: Vector3 = side * float(distance)
			var points: Array = [body.global_position + shift, goal + shift]
			if _clear_segments(body, points, goal):
				_rectangles[id] = {"command_id": command_id, "body_id": body.get_instance_id(),
					"target": goal, "points": points}
				_retry_after_frame.erase(id)
				return shift.normalized()
	_retry_after_frame[id] = Engine.get_physics_frames() + 30
	return Vector3.ZERO

func _clear_segments(body: CharacterBody3D, points: Array, goal: Vector3) -> bool:
	var from := body.global_position
	for value in points:
		var point: Vector3 = value
		point.y = body.global_position.y
		if not _corridor_clear(body, from, point - from):
			return false
		from = point
	return _corridor_clear(body, from, goal - from)
