extends "res://tests/ten_world_forage_probe.gd"
## Read-only actual capsule sweeps at the persisted herder position.
## Synthetic query origins are measurements only; no body is moved or save written.

func _probe_motion(body: CharacterBody3D, from: Vector3, motion: Vector3) -> Dictionary:
	var transform := body.global_transform
	transform.origin = from
	var collision := KinematicCollision3D.new()
	var blocked := body.test_move(transform, motion, collision)
	var result := {"from": [from.x, from.y, from.z], "motion": [motion.x, motion.y, motion.z], "blocked": blocked}
	if blocked:
		var collider: Object = collision.get_collider()
		var normal := collision.get_normal()
		var point := collision.get_position()
		result["collider"] = str(collider.get_path()) if collider is Node else str(collider)
		result["normal"] = [normal.x, normal.y, normal.z]
		result["point"] = [point.x, point.y, point.z]
	return result

func _run() -> void:
	var before := FileAccess.get_file_as_bytes(_save)
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	for frame in 3:
		await physics_frame
	var town: RefCounted = _scene.get("town")
	var body: CharacterBody3D = _scene.get("bodies")["shared:herder"]
	var target: Vector3 = town.destination("shared:herder", "harvest_ration")
	target.y = body.position.y
	var offset := target - body.position
	var forward := offset.normalized()
	var left := Vector3(-forward.z, 0, forward.x)
	var candidates: Array = []
	for distance in [0.8, 1.2, 1.8, 2.4]:
		for side in [left, -left]:
			var waypoint: Vector3 = body.position + side * float(distance)
			candidates.append({"distance": distance, "waypoint": [waypoint.x, waypoint.y, waypoint.z],
				"first": _probe_motion(body, body.position, waypoint - body.position),
				"second": _probe_motion(body, waypoint, target - waypoint)})
	var payload := {"scenario": "h33-herder-readonly-route-capsule-sweeps", "process_id": OS.get_process_id(),
		"position": [body.position.x, body.position.y, body.position.z], "target": [target.x, target.y, target.z],
		"direct": _probe_motion(body, body.position, offset), "candidates": candidates,
		"save_unchanged": FileAccess.get_file_as_bytes(_save) == before,
		"model_calls": 0, "provenance": "paused existing scene; actual capsule query results, no body relocation"}
	var output := FileAccess.open(_out, FileAccess.WRITE)
	output.store_string(JSON.stringify(payload, "  "))
	output.close()
	print(JSON.stringify(payload))
	quit(0 if payload.save_unchanged else 1)
