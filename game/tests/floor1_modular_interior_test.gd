extends SceneTree
## Real ground-floor resident-size entry, room circulation and detachable
## furnished insert acceptance. Run headless after Godot imports the assets.

const VARIANTS := ["01_hearth_cottage", "02_market_house", "03_corner_turret"]
const WALKER_RADIUS := 0.32
const WALKER_HEIGHT := 1.80
const WALKER_CENTRE_Y := 0.93
const CLEAR_ROUTE_HALF_WIDTH := 0.45

var checks := 0
var failures := 0
var failed_labels: Array[String] = []
var rows: Array[Dictionary] = []
var _capture_dir := ""
var _camera: Camera3D = null


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		failed_labels.append(label)
		print("FAIL ", label)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--capture-dir="):
			_capture_dir = String(arg).trim_prefix("--capture-dir=")
	if not _capture_dir.is_empty():
		_prepare_actual_render()
	for i in range(VARIANTS.size()):
		await _check_house(VARIANTS[i], i)
	print(JSON.stringify({"checks": checks, "failures": failures,
		"failure_labels": failed_labels, "rooms": rows, "paid_calls": 0}))
	quit(1 if failures > 0 else 0)


func _check_house(variant: String, index: int) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(float(index) * 25.0, 0.0, -8.0)
	holder.rotation_degrees.y = [-90.0, 90.0, -90.0][index]
	root.add_child(holder)
	var house := ModularHouseComponent.new()
	house.variant_id = variant
	house.build_on_ready = false
	holder.add_child(house)
	await process_frame
	_check(house.build(), "%s authentic house GLB builds" % variant)
	var insert := Floor1ModularInterior.new()
	insert.build_on_ready = false
	house.add_child(insert)
	await process_frame
	_check(insert.build(), "%s independent ground-floor insert builds" % variant)
	if insert.room == null:
		holder.queue_free()
		await process_frame
		return
	var metrics := insert.art_metrics()
	var lantern := insert.room.find_child("CagedLanternVisual", false, false) as Node3D
	_check(lantern != null and lantern.find_child("TC_caged_travel_lantern", true, false) is MeshInstance3D,
		"%s independent imported iron/copper/glass lantern visual present" % variant)
	var actual_lights: Array[OmniLight3D] = []
	for child in insert.room.get_children():
		if child is OmniLight3D:
			actual_lights.append(child)
	var original_light_ok := actual_lights.size() == 1
	if original_light_ok:
		var original_lamp_at := Vector3(-1.35, 2.46, -0.78) if variant == "03_corner_turret" else Vector3(0.35, 2.46, -0.85)
		original_light_ok = (actual_lights[0].name == "WarmInteriorFill"
			and is_equal_approx(actual_lights[0].light_energy, 0.80)
			and is_equal_approx(actual_lights[0].omni_range, 4.6)
			and actual_lights[0].shadow_enabled
			and actual_lights[0].position.distance_to(original_lamp_at) < 0.001)
	_check(original_light_ok, "%s exactly one original shadow-casting local light preserved" % variant)
	if variant == "02_market_house":
		var sign_unit := insert.bakery_sign
		_check(sign_unit != null and sign_unit.get_parent() == insert.room,
			"one furnished bakery owns its separately removable exterior sign unit")
		if sign_unit != null:
			var sign_mesh := sign_unit.find_child("SF13_Bakery_Pretzel_Emblem", true, false) as MeshInstance3D
			_check(sign_mesh != null and sign_mesh.mesh != null
				and sign_mesh.mesh.get_surface_count() == 3,
				"existing iron/brass/oak double-knot and complete slim bracket actually import")
			if sign_mesh != null:
				var oak_material := sign_mesh.get_active_material(2) as StandardMaterial3D
				_check(oak_material != null and oak_material.roughness >= 0.70
					and not oak_material.emission_enabled
					and sign_mesh.get_surface_override_material(0) == null,
					"bakery wood remains matte and non-emissive while its iron uses the source material")
				var sign_bounds := _mesh_bounds_in_house(house, sign_mesh)
				var door_bounds: Dictionary = house.door_opening_godot()
				var door_left: float = door_bounds["centre"].x - door_bounds["size"].x * 0.5
				var door_top: float = door_bounds["centre"].y + door_bounds["size"].z * 0.5
				var lateral_gap: float = door_left - sign_bounds["max"].x
				var head_gap: float = sign_bounds["min"].y - door_top
				_check(lateral_gap > 0.30 and head_gap > 0.30
					and sign_bounds["max"].z > door_bounds["centre"].z + 0.70,
					"real imported sign stays outside door shoulder/head, faces street (lateral %.3f, head %.3f)" % [lateral_gap, head_gap])
	var route: Array[Vector3] = insert.route_waypoints_local()
	_check(route.size() >= 3, "%s route reaches useful room furniture" % variant)
	var opening := house.door_opening_godot()
	var doorway: Vector3 = opening["centre"]
	var outward: Vector3 = opening["outward"]
	_check(route[0].distance_to(Vector3(doorway.x, WALKER_CENTRE_Y, doorway.z)) < 0.01,
		"%s corridor starts at the true doorway" % variant)
	var route_clearance := _minimum_proxy_clearance(house, insert, route)
	_check(route_clearance >= CLEAR_ROUTE_HALF_WIDTH,
		"%s collision proxies leave 0.90 m measured route (half %.3f m)" % [variant, route_clearance])
	var body := _new_walker()
	var start_local := route[0] + outward * 2.20
	start_local.y = WALKER_CENTRE_Y
	body.global_position = house.global_transform * start_local
	house.set_door_open(false)
	await physics_frame
	await _walk_to(body, house.global_transform * route[1], 180)
	var closed_local: Vector3 = house.to_local(body.global_position)
	var closed_distance := (closed_local - doorway).dot(outward)
	_check(closed_distance > -0.05,
		"%s furnished closed door still stops 0.32x1.80 m walker (%.3f)" % [variant, closed_distance])
	body.global_position = house.global_transform * start_local
	house.set_door_open(true)
	await physics_frame
	for target_local in route.slice(1):
		await _walk_to(body, house.global_transform * target_local, 250)
	var reached_local: Vector3 = house.to_local(body.global_position)
	var goal_distance := Vector2(reached_local.x - route[-1].x,
		reached_local.z - route[-1].z).length()
	_check(goal_distance < 0.25,
		"%s open door/ground-floor route reaches useful furniture (miss %.3f m)" % [variant, goal_distance])
	_check(metrics["solid_proxies"] >= 4,
		"%s useful furniture has real solid footprint proxies" % variant)
	if variant == "02_market_house":
		_check("bakers_oven_peel_rack" in metrics["workshop_assets"]
			and "grain_hand_quern" in metrics["workshop_assets"],
			"bakery loads existing artisan oven/peel rack and quern")
	if variant == "03_corner_turret":
		_check("forge_with_bellows" in metrics["workshop_assets"]
			and "horn_anvil_stump" in metrics["workshop_assets"],
			"artisan room loads existing forge and anvil")
	if not _capture_dir.is_empty():
		await _save_player_height_views(house, insert, variant)
	rows.append({"variant": variant, "kind": metrics["kind"], "proxies": metrics["solid_proxies"],
		"props": metrics["prop_instances"], "workshop_assets": metrics["workshop_assets"],
		"route_half_clearance_m": snappedf(route_clearance, 0.001),
		"closed_signed_m": snappedf(closed_distance, 0.001),
		"useful_goal_miss_m": snappedf(goal_distance, 0.001)})
	body.queue_free()
	holder.queue_free()
	await physics_frame


func _prepare_actual_render() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color.html("315D86")
	sky_mat.sky_horizon_color = Color.html("719BB0")
	sky_mat.ground_horizon_color = Color.html("719BB0")
	sky_mat.ground_bottom_color = Color.html("6F9486")
	sky.sky_material = sky_mat
	world.environment.sky = sky
	world.environment.background_energy_multiplier = 0.78
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world.environment.ambient_light_energy = 0.42
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -28.0, 0.0)
	sun.light_color = Color.html("FFF0D5")
	sun.light_energy = 0.88
	sun.shadow_enabled = true
	root.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.near = 0.08
	_camera.far = 75.0
	root.add_child(_camera)
	_camera.current = true


func _save_player_height_views(house: ModularHouseComponent,
		insert: Floor1ModularInterior, variant: String) -> void:
	var shots := []
	match insert.interior_kind:
		"home": shots = [
			["from_door", Vector3(0.0, 1.62, 1.70), Vector3(0.25, 0.85, -1.50)],
			["at_table", Vector3(0.20, 1.62, -0.10), Vector3(2.35, 0.82, -1.25)],
			["at_hearth", Vector3(0.60, 1.62, -1.85), Vector3(3.12, 0.66, -2.73)]]
		"bakery": shots = [
			["from_door", Vector3(-0.9, 1.62, 2.45), Vector3(0.0, 0.90, -1.50)],
			["at_counter", Vector3(-0.45, 1.62, -0.20), Vector3(2.12, 0.82, 0.20)],
			["at_oven", Vector3(-0.65, 1.62, -1.40), Vector3(-2.22, 0.72, -4.02)],
			["bakery_front_wide", Vector3(0.0, 1.62, 9.4), Vector3(-0.70, 2.80, 4.60)],
			["at_exterior_sign", Vector3(-2.10, 1.62, 7.25), Vector3(-2.35, 3.05, 5.05)]]
		"artisan": shots = [
			["from_door", Vector3(2.2, 1.62, 1.55), Vector3(-1.85, 0.88, -0.92)],
			["at_workbench", Vector3(0.48, 1.62, 0.10), Vector3(-3.10, 0.86, 0.55)],
			["at_forge", Vector3(-0.65, 1.62, 0.25), Vector3(-3.12, 0.72, -2.10)]]
	# Eye-height lamp review uses an unchanged camera for the existing shade
	# and any later removable visual, while the real walker routes remain the
	# same nine furnished views above.
	var lamp_at := Vector3(-1.35, 2.46, -0.78) if insert.interior_kind == "artisan" else Vector3(0.35, 2.46, -0.85)
	var lamp_eye := Vector3(0.65, 1.62, 1.25) if insert.interior_kind == "artisan" else Vector3(-0.35, 1.62, 1.25)
	shots.append(["at_lantern", lamp_eye, lamp_at])
	for shot in shots:
		_camera.global_position = house.global_transform * shot[1]
		_camera.look_at(house.global_transform * shot[2], Vector3.UP)
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := _capture_dir.path_join("%s_%s.png" % [variant, shot[0]])
		_check(image.get_width() >= 1000 and image.save_png(path) == OK,
			"%s actual player-height Godot render saved (%s)" % [variant, shot[0]])


func _new_walker() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = WALKER_RADIUS
	capsule.height = WALKER_HEIGHT
	collider.shape = capsule
	body.add_child(collider)
	root.add_child(body)
	return body


func _walk_to(body: CharacterBody3D, target: Vector3, max_steps: int) -> void:
	for step in range(max_steps):
		var difference := target - body.global_position
		difference.y = 0.0
		if difference.length() < 0.17:
			break
		body.velocity = difference.normalized() * 2.25
		body.move_and_slide()
		await physics_frame
	body.velocity = Vector3.ZERO


func _minimum_proxy_clearance(house: ModularHouseComponent,
		insert: Floor1ModularInterior, route: Array[Vector3]) -> float:
	var minimum := INF
	var proxies: Array[StaticBody3D] = []
	for child in insert.room.get_children():
		if child is StaticBody3D:
			proxies.append(child)
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var length := Vector2(b.x - a.x, b.z - a.z).length()
		var samples := maxi(1, int(ceil(length / 0.10)))
		for sample in range(samples + 1):
			var fraction := float(sample) / float(samples)
			var point := a.lerp(b, fraction)
			for proxy in proxies:
				var shape_node := proxy.get_child(0) as CollisionShape3D
				var box := shape_node.shape as BoxShape3D
				var centre: Vector3 = house.to_local(proxy.global_position)
				var dx := maxf(absf(point.x - centre.x) - box.size.x * 0.5, 0.0)
				var dz := maxf(absf(point.z - centre.z) - box.size.z * 0.5, 0.0)
				minimum = minf(minimum, Vector2(dx, dz).length())
	return minimum


func _mesh_bounds_in_house(house: ModularHouseComponent, visual: MeshInstance3D) -> Dictionary:
	var raw: AABB = visual.get_aabb()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for corner_x in [0.0, 1.0]:
		for corner_y in [0.0, 1.0]:
			for corner_z in [0.0, 1.0]:
				var point := raw.position + raw.size * Vector3(corner_x, corner_y, corner_z)
				var local: Vector3 = house.to_local(visual.global_transform * point)
				low = low.min(local)
				high = high.max(local)
	return {"min": low, "max": high}
