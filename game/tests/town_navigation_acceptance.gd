extends SceneTree

const TownScene = preload("res://scenes/town_street.tscn")

var failures := 0
var checks := 0
var scene: Node3D

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _arg(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	call_deferred("run")

func _walk_to(id: String, target: Vector3, command_id: String, max_frames: int) -> Dictionary:
	var body: CharacterBody3D = scene.bodies[id]
	var navigation = scene.town_navigation
	var status := ""
	var first_direction := Vector3.ZERO
	var saw_direction := false
	var start := body.global_position
	for frame in max_frames:
		var direction: Vector3 = navigation.direction_for(id, command_id, body, target)
		status = navigation.route_status(id)
		if frame == 0:
			first_direction = direction
		if direction.length() > 0.1:
			saw_direction = true
		body.velocity.x = direction.x * 1.35
		body.velocity.z = direction.z * 1.35
		body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 18.0 * (1.0 / 60.0)
		body.move_and_slide()
		if body.global_position.distance_to(target) <= 0.45:
			return {"arrived": true, "status": status, "frames": frame + 1,
				"start": start, "end": body.global_position, "first_direction": first_direction,
				"saw_direction": saw_direction}
		# NavigationAgent3D emits velocity_computed on the physics tick after set_velocity;
		# yield here so the next iteration consumes the actual avoidance result.
		await physics_frame
	await physics_frame
	return {"arrived": body.global_position.distance_to(target) <= 0.45, "status": status,
		"frames": max_frames, "start": start, "end": body.global_position,
		"first_direction": first_direction, "saw_direction": saw_direction}

func run() -> void:
	var save_path := _arg("--save=")
	if save_path.is_empty():
		print(JSON.stringify({"ok": false, "code": "save_required"}))
		quit(2)
		return
	scene = TownScene.instantiate()
	root.add_child(scene)
	for _frame in 180:
		await process_frame
		if scene.town_navigation != null and not scene.town_navigation.baking:
			break
	var navigation = scene.town_navigation
	check(navigation != null, "town street installs the shared navigation helper")
	check(navigation != null and navigation.enabled, "navigation mesh baked from static colliders")
	if navigation == null or not navigation.enabled:
		print(JSON.stringify({"ok": false, "checks": checks, "failures": failures,
			"navigation_status": navigation.bake_status if navigation != null else "missing"}))
		quit(1)
		return
	var id := "shared:well-keeper"
	var body: CharacterBody3D = scene.bodies[id]
	body.position = Vector3(0.0, 0.22, 30.0)
	await physics_frame
	var ramp := await _walk_to(id, Vector3(0.0, 0.10, 53.0), "nav-ramp", 1200)
	check(ramp.status == "following", "market-to-field route follows baked mesh")
	check(ramp.saw_direction, "market-to-field produces a physical steering direction")
	check(ramp.arrived, "body crosses the real junction ramp to the field")
	body.position = Vector3(0.0, 0.10, 53.0)
	await physics_frame
	var reverse := await _walk_to(id, Vector3(0.0, 0.22, 30.0), "nav-ramp-reverse", 1200)
	check(reverse.status == "following", "field-to-market route follows baked mesh")
	check(reverse.arrived, "body walks back up the real junction ramp to market")
	var off_center_id := "shared:baker"
	var off_center_body: CharacterBody3D = scene.bodies[off_center_id]
	off_center_body.position = Vector3(-22.0, 0.10, 39.0)
	await physics_frame
	var off_center := await _walk_to(off_center_id, Vector3(0.0, 0.22, 30.0), "nav-off-center-home", 1800)
	check(off_center.status == "following", "off-center field-to-market route follows baked mesh")
	check(off_center.saw_direction, "off-center route produces a physical steering direction")
	check(off_center.arrived, "body crosses the real ramp from the offset field position")
	body.position = Vector3(0.0, 0.10, 53.0)
	await physics_frame
	var trough := await _walk_to(id, Vector3(10.5, 0.10, 47.8), "nav-trough", 1400)
	check(trough.status == "following", "field-to-trough route follows baked mesh")
	check(trough.saw_direction, "field-to-trough produces a physical steering direction")
	check(trough.arrived, "body walks from the field to the water trough")
	var unreachable: Vector3 = navigation.direction_for(id, "nav-outside", body, Vector3(200.0, 0.1, 200.0))
	check(unreachable == Vector3.ZERO and navigation.is_unreachable(id), "outside AABB is explicitly unreachable")
	print(JSON.stringify({"ok": failures == 0, "checks": checks, "failures": failures,
		"bake_status": navigation.bake_status, "ramp": ramp, "reverse": reverse,
		"off_center": off_center, "trough": trough,
		"unreachable_status": navigation.route_status(id), "save_path": save_path}))
	quit(0 if failures == 0 else 1)
