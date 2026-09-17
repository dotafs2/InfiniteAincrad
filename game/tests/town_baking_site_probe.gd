extends SceneTree
## Read-only, actual-town placement probe for one already-installed candidate oven.
## The caller supplies a disposable save and --town-restore. No model/controller is attached.

const TownStreetScene := preload("res://scenes/town_street.tscn")
const Catalog := preload("res://spatial/town_places.gd")
const ARRIVAL_RANGE := 3.0
const WORK_OFFSET := Vector3(0.0, 0.0, 0.85)
const WALK_SPEED := 1.35

class PhysicsRunner extends Node3D:
	var pending: Callable = Callable()
	var result: Variant = null
	var done := false
	func schedule(callable: Callable) -> void:
		pending = callable
		result = null
		done = false
	func _physics_process(_delta: float) -> void:
		if pending.is_valid():
			var callable := pending
			pending = Callable()
			result = callable.call()
			done = true

var scene: Node = null
var runner: PhysicsRunner = null
var failures: Array[String] = []
var checks := 0
var save_path := ""
var output_path := ""
var point_id := ""
var save_before := PackedByteArray()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="):
			save_path = arg.trim_prefix("--town-save=")
		elif arg.begins_with("--site-output="):
			output_path = arg.trim_prefix("--site-output=")
		elif arg.begins_with("--site-point="):
			point_id = arg.trim_prefix("--site-point=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _physics(callable: Callable) -> Variant:
	runner.schedule(callable)
	var guard := 0
	while not runner.done and guard < 120:
		await physics_frame
		await process_frame
		guard += 1
	if not runner.done:
		check(false, "physics callback completes")
		return null
	return runner.result

func _los(id: String) -> bool:
	var value: Variant = await _physics(func(): return scene.baking_visibility.can_observe(id, point_id))
	return value is bool and value

func _point(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _sample(id: String, at: Vector3, oven: Vector3) -> Dictionary:
	var body: CharacterBody3D = scene.bodies[id]
	body.global_position = at
	body.velocity = Vector3.ZERO
	await physics_frame
	await process_frame
	var visible := await _los(id)
	return {"id": id, "position": [at.x, at.y, at.z], "distance_m": at.distance_to(oven),
		"inside_range": at.distance_to(oven) <= ARRIVAL_RANGE, "line_of_sight": visible}

func _walk_static_route(id: String, start: Vector3, target: Vector3) -> Dictionary:
	var body: CharacterBody3D = scene.bodies[id]
	body.global_position = start
	body.velocity = Vector3.ZERO
	scene.place_steering.clear_route(id)
	var closest := body.global_position.distance_to(target)
	var frames := 0
	while frames < 900 and closest > 0.45:
		var direction_value: Variant = await _physics(func():
			var direction: Vector3 = scene.place_steering.direction_to_point(id, "site-probe-route", body, target)
			body.velocity = direction * WALK_SPEED
			body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 18.0 / 60.0
			body.move_and_slide()
			return {"position": body.global_position, "collisions": body.get_slide_collision_count()})
		if not direction_value is Dictionary:
			break
		closest = minf(closest, body.global_position.distance_to(target))
		frames += 1
	scene.place_steering.clear_route(id)
	body.velocity = Vector3.ZERO
	return {"start": [start.x, start.y, start.z], "target": [target.x, target.y, target.z],
		"end": [body.global_position.x, body.global_position.y, body.global_position.z],
		"closest_m": closest, "frames": frames, "arrived": closest <= 0.45}

func _nav_report(start: Vector3, target: Vector3) -> Dictionary:
	var navigation = scene.town_navigation
	var guard := 0
	while navigation.baking and guard < 600:
		await process_frame
		guard += 1
	if not navigation.enabled:
		return {"enabled": false, "bake_status": navigation.bake_status}
	var map: RID = navigation.region.get_navigation_map()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, target, true)
	return {"enabled": true, "bake_status": navigation.bake_status, "points": path.size(),
		"end_distance_m": INF if path.is_empty() else path[path.size() - 1].distance_to(target),
		"reaches": not path.is_empty() and path[path.size() - 1].distance_to(target) <= 0.45}

func run() -> void:
	if save_path.is_empty() or output_path.is_empty() or point_id.is_empty() or not OS.get_cmdline_user_args().has("--town-restore"):
		print(JSON.stringify({"ok": false, "code": "requires --town-save --town-restore --site-point --site-output"}))
		quit(2)
		return
	save_before = FileAccess.get_file_as_bytes(save_path)
	scene = TownStreetScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	runner = PhysicsRunner.new()
	root.add_child(runner)
	var points: Array = scene.town.baking_points().filter(func(entry): return entry.get("id", "") == point_id)
	check(points.size() == 1, "candidate oven exists exactly once")
	if points.size() != 1:
		_finish({})
		return
	var oven := _point(points[0].position)
	var work_target := oven + WORK_OFFSET
	var known_ids := ["shared:well-keeper", "shared:baker", "shared:smith", "shared:carpenter"]
	var slot_reports: Array = []
	for id in known_ids:
		var slot: int = scene.town.active_ids().find(id)
		var at := Catalog.slot_point("west_forecourt", slot)
		slot_reports.append(await _sample(id, at, oven))
	var road_reports: Array = []
	for x in [-19.5, -18.5, -17.5]:
		road_reports.append(await _sample("shared:smith", Vector3(x, 0.10, 40.0), oven))
	for report in road_reports:
		check(report.inside_range and report.line_of_sight, "verified west road sample is within 3m and has LOS")
	check(slot_reports.filter(func(report): return report.inside_range and report.line_of_sight).size() >= 2,
		"at least two known west-forecourt arrival slots directly discover the oven")
	var nav := await _nav_report(Vector3(-13.5, 0.10, 40.0), work_target)
	check(nav.get("reaches", false), "actual navigation map reaches the work apron")
	var route := await _walk_static_route("shared:smith", Vector3(-13.5, 0.10, 40.0), work_target)
	check(route.arrived, "real resident capsule reaches the work apron over fallback road steering")
	var apron_report := await _sample("shared:smith", work_target, oven)
	check(apron_report.line_of_sight, "work apron has real LOS to oven mouth")
	var oven_display: Node3D = scene.baking_visibility.source_visuals.points[point_id].display
	var oven_collision := oven_display.find_child("OvenCollision", true, false)
	check(oven_collision != null, "candidate carries the production oven collider")
	var payload := {"suite": "town_baking_site_probe", "checks": checks, "failures": failures,
		"point_id": point_id, "oven": [oven.x, oven.y, oven.z], "work_target": [work_target.x, work_target.y, work_target.z],
		"road_samples": road_reports, "known_slot_samples": slot_reports, "navigation": nav,
		"fallback_capsule_route": route, "work_apron": apron_report, "real_model_calls": 0,
		"runtime_mode": "actual_town_street_physics_restore_only"}
	_finish(payload)

func _finish(payload: Dictionary) -> void:
	if scene != null and is_instance_valid(scene):
		if scene.get("_owns_writer"):
			scene.town.release_writer(save_path)
			scene.set("_owns_writer", false)
		scene.queue_free()
	await process_frame
	payload["save_byte_equal"] = FileAccess.get_file_as_bytes(save_path) == save_before
	check(payload.save_byte_equal, "restore-only probe leaves save bytes unchanged")
	payload["checks"] = checks
	payload["failures"] = failures
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ", true, true))
		file.close()
	print(JSON.stringify(payload))
	quit(0 if failures.is_empty() else 1)
