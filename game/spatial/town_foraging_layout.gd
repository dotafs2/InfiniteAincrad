extends RefCounted
## Ten local work places around one unchanged public source. Placement probes real
## floor and resident capsules; it does not move bodies or alter jobs/resources.
## Clear endpoints are not a claim that the routes are reachable.

const RADII := [1.6, 1.85, 1.35]
const ROTATIONS := [0.0, PI / 10.0, PI / 20.0, PI * 3.0 / 20.0]
const CLEARANCE := 0.025
const MIN_SPACING := 0.55

func can_work(town: RefCounted, bodies: Dictionary, space: PhysicsDirectSpaceState3D,
		id: String, extra_exclude: Array[RID] = []) -> bool:
	if not Engine.is_in_physics_frame() or not bodies.has(id):
		return false
	var body: CharacterBody3D = bodies[id]
	var capsule: CollisionShape3D = null
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			capsule = child
	if capsule == null:
		return false
	var exclude: Array[RID] = extra_exclude.duplicate()
	for actor in bodies.values():
		exclude.append(actor.get_rid())
	var point: Vector3 = town.destination(id, "harvest_ration")
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2,
		point - Vector3.UP * 0.2, body.collision_mask, exclude)
	var floor_hit: Dictionary = space.intersect_ray(ray)
	if floor_hit.is_empty() or Vector3(floor_hit.normal).dot(Vector3.UP) < 0.7 or absf(float(floor_hit.position.y) - point.y) > 0.03:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	var transform := body.global_transform
	transform.origin = point
	query.transform = transform * capsule.transform
	query.transform.origin.y += CLEARANCE
	query.collision_mask = body.collision_mask
	query.exclude = exclude
	return space.intersect_shape(query, 1).is_empty()

func build(town: RefCounted, bodies: Dictionary, space: PhysicsDirectSpaceState3D,
		extra_exclude: Array[RID] = []) -> Dictionary:
	var ids: Array = town.active_ids()
	if ids.size() != 10 or not Engine.is_in_physics_frame():
		return {"ok": false, "code": "foraging_layout_requires_ten_physics_bodies"}
	var exclude: Array[RID] = extra_exclude.duplicate()
	var prototype: CharacterBody3D = null
	var capsule: CollisionShape3D = null
	for id in ids:
		if not bodies.has(id) or not is_instance_valid(bodies[id]):
			return {"ok": false, "code": "foraging_layout_missing_body"}
		var body: CharacterBody3D = bodies[id]
		exclude.append(body.get_rid())
		if prototype == null:
			prototype = body
			for child in body.get_children():
				if child is CollisionShape3D and child.shape is CapsuleShape3D:
					capsule = child
	if capsule == null:
		return {"ok": false, "code": "foraging_layout_missing_capsule"}
	var center: Vector3 = town.berry_center()
	var tested := 0
	for radius in RADII:
		for rotation in ROTATIONS:
			var points: Array[Vector3] = []
			for index in 10:
				var angle: float = TAU * float(index) / 10.0 + rotation
				var trial: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * float(radius)
				tested += 1
				var ray := PhysicsRayQueryParameters3D.create(trial + Vector3.UP * 0.4,
					trial - Vector3.UP * 0.4, prototype.collision_mask, exclude)
				var floor_hit: Dictionary = space.intersect_ray(ray)
				if floor_hit.is_empty() or Vector3(floor_hit.normal).dot(Vector3.UP) < 0.7:
					break
				var point: Vector3 = floor_hit.position
				if absf(point.y - center.y) > 0.10:
					break
				point.y += 0.005
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule.shape
				var transform := prototype.global_transform
				transform.origin = point
				query.transform = transform * capsule.transform
				query.transform.origin.y += CLEARANCE
				query.collision_mask = prototype.collision_mask
				query.exclude = exclude
				if not space.intersect_shape(query, 1).is_empty():
					break
				points.append(point)
			if points.size() == 10 and _spaced(points):
				return {"ok": true, "code": "foraging_layout_checked",
					"spots": _assign(ids, bodies, center, points), "tested_endpoints": tested,
					"radius": radius, "rotation": rotation, "routes_verified": false}
	return {"ok": false, "code": "foraging_layout_no_clear_ring", "tested_endpoints": tested}

func _spaced(points: Array[Vector3]) -> bool:
	for index in points.size():
		for other in range(index):
			var difference := points[index] - points[other]
			difference.y = 0.0
			if difference.length() < MIN_SPACING:
				return false
	return true

func _assign(ids: Array, bodies: Dictionary, center: Vector3, points: Array[Vector3]) -> Dictionary:
	# Preserve angular order and pick the shortest cyclic assignment. This avoids
	# allocating opposite sides through one another when a queue already exists.
	var ordered: Array = ids.duplicate()
	ordered.sort_custom(func(a, b):
		var av: Vector3 = bodies[a].position - center
		var bv: Vector3 = bodies[b].position - center
		var aa := fposmod(atan2(av.z, av.x), TAU)
		var ba := fposmod(atan2(bv.z, bv.x), TAU)
		return aa < ba if not is_equal_approx(aa, ba) else str(a) < str(b))
	var best_rotation := 0
	var best_cost := INF
	for rotation in points.size():
		var cost := 0.0
		for index in ordered.size():
			cost += bodies[ordered[index]].position.distance_squared_to(points[(index + rotation) % 10])
		if cost < best_cost:
			best_cost = cost
			best_rotation = rotation
	var result := {}
	for index in ordered.size():
		var point := points[(index + best_rotation) % 10]
		result[ordered[index]] = [point.x, point.y, point.z]
	return result
