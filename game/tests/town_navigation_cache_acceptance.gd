extends SceneTree
## Real stock A* path following and RVO velocities around a physical wall, no model.
const Navigation = preload("res://spatial/town_navigation.gd")
var failures: Array = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	Engine.time_scale = 4.0
	call_deferred("run")

func collider(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = at

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	collider(world, Vector3(20, .4, 20), Vector3(0, -.2, 0))
	collider(world, Vector3(2, 2, 6), Vector3(0, 1, 0))
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.5
	collision.shape = capsule
	collision.position.y = .75
	body.add_child(collision)
	world.add_child(body)
	body.position = Vector3(-5, .01, 0)
	var navigation = Navigation.new()
	world.add_child(navigation)
	navigation.build()
	navigation.register_body("walker", body)
	for _frame in 30:
		await process_frame
		if navigation.enabled: break
	await physics_frame
	check(navigation.enabled, "real collider map ready")
	var target := Vector3(5, .01, 0)
	var frames := 0
	var walked := 0.0
	var furthest_z := 0.0
	var maximum_speed := 0.0
	var previous := body.position
	for frame in 1500:
		await physics_frame
		var direction: Vector3 = navigation.direction_for("walker", "walk", body, target)
		body.velocity = direction * navigation.WALK_SPEED
		body.velocity.y = -1.0
		body.move_and_slide()
		maximum_speed = maxf(maximum_speed, Vector2(body.velocity.x, body.velocity.z).length())
		walked += body.position.distance_to(previous)
		previous = body.position
		furthest_z = maxf(furthest_z, absf(body.position.z))
		frames = frame + 1
		if body.position.distance_to(target) < .32: break
	check(body.position.distance_to(target) < .4, "body reaches true target around wall")
	check(furthest_z > 3.2 and walked > 11.0, "body physically detours beyond wall clearance")
	check(maximum_speed <= 1.351, "RVO velocity keeps the fixed walking speed cap")
	check(navigation.path_updates < frames / 8, "stock path cache avoids a complete A* query each frame")
	var first_updates: int = navigation.path_updates
	# A test-only reposition exercises the cold restore invalidation seam, not journey success.
	body.position = Vector3(-5, .01, -5)
	navigation.direction_for("walker", "walk", body, target)
	check(navigation.path_updates > first_updates, "same-command restored body invalidates cached corridor")
	var old_iteration := NavigationServer3D.map_get_iteration_id(navigation.region.get_navigation_map())
	navigation.region.enabled = false
	NavigationServer3D.map_force_update(navigation.region.get_navigation_map())
	for _frame in 30:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(navigation.region.get_navigation_map()) != old_iteration: break
	check(NavigationServer3D.map_get_iteration_id(navigation.region.get_navigation_map()) != old_iteration, "disabled region synchronizes with the navigation server")
	var missing_map: Vector3 = navigation.direction_for("walker", "walk", body, target)
	check(missing_map == Vector3.ZERO and navigation.is_unreachable("walker"), "removed navmesh invalidates a cached route")
	old_iteration = NavigationServer3D.map_get_iteration_id(navigation.region.get_navigation_map())
	navigation.region.enabled = true
	NavigationServer3D.map_force_update(navigation.region.get_navigation_map())
	for _frame in 30:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(navigation.region.get_navigation_map()) != old_iteration: break
	navigation.direction_for("walker", "walk", body, target)
	check(not navigation.is_unreachable("walker"), "same command recovers when map becomes reachable")
	var outside: Vector3 = navigation.direction_for("walker", "outside", body, Vector3(200, 0, 200))
	check(outside == Vector3.ZERO and navigation.is_unreachable("walker"), "out-of-map goal remains explicitly unreachable")
	var wall: Vector3 = navigation.direction_for("walker", "wall", body, Vector3(0, .01, 0))
	check(wall == Vector3.ZERO and navigation.is_unreachable("walker"), "partial path inside wall cannot fabricate arrival")
	navigation.clear_route("walker")
	check(navigation.route_status("walker") == "inactive", "cancel clears route and velocity")
	print(JSON.stringify({"checks": checks, "failures": failures, "frames": frames,
		"walked": walked, "maximum_speed": maximum_speed, "path_updates": first_updates,
		"furthest_z": furthest_z, "model_calls": 0, "time_scale": 4}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
