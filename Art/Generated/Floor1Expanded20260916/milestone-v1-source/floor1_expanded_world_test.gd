extends SceneTree
## Focused geometry and physics checks for the independent art world.
## Tests actual imported scene/components; never starts town or writes saves.

var checks: Array[Dictionary] = []
var scene: Node3D
var world: Node3D
var space: PhysicsDirectSpaceState3D
var layout_snapshot: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"case": label, "passed": passed, "detail": detail})


func ray_clear(label: String, start: Vector3, end: Vector3) -> void:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
	check(label, hit.is_empty(), hit.get("collider", null).name if not hit.is_empty() else "clear")


func ground_hit(label: String, x: float, z: float) -> void:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(x, 3.0, z), Vector3(x, -1.0, z)))
	check(label, not hit.is_empty(), hit.get("position", Vector3.ZERO))


func _run() -> void:
	var packed := load("res://scenes/floor1_expanded_world.tscn") as PackedScene
	check("scene_imported", packed != null)
	if packed == null:
		_finish()
		return
	scene = Node3D.new()
	root.add_child(scene)
	world = packed.instantiate() as Node3D
	world.set("review_mode", true)
	scene.add_child(world)
	check("world_script_loaded", world.has_method("layout_metrics"))
	if not world.has_method("layout_metrics"):
		_finish()
		return
	await physics_frame
	await physics_frame
	space = scene.get_world_3d().direct_space_state
	var m: Dictionary = world.call("layout_metrics")
	layout_snapshot = m
	check("continuous_extent", m["world_extent_m"] == [420, 460])
	check("town_extent", m["town_extent_m"] == [180, 170])
	check("twelve_modular_house_instances", int(m["interactive_houses"]) == 12,
		m["interactive_houses"])
	check("thirty_two_exterior_lod_houses", int(m["exterior_lod_houses"]) == 32,
		m["exterior_lod_houses"])
	check("gate_at_north85", int(m["northern_gate_z_m"]) == -85)
	check("path_to_north230", int(m["countryside_path_end_z_m"]) == -230)
	check("four_distinct_farm_plots", int(m["farm_plots"]) == 4)
	for z in [75.0, 52.0, 12.0, 0.0, -20.0, -55.0, -80.0, -86.0, -120.0, -180.0, -225.0, -230.0]:
		ground_hit("ground_z" + str(z), 0.0, z)
	for z in [52.0, 0.0, -20.0, -55.0, -83.0, -87.0, -120.0, -180.0]:
		ray_clear("main_walk_clear_z" + str(z), Vector3(0, 1.45, z + 2.0),
			Vector3(0, 1.45, z - 2.0))
	var basin := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-7.5, 0.45, -2.5), Vector3(-7.5, 0.45, 2.5)))
	check("fountain_basin_real_collision", not basin.is_empty(),
		basin.get("collider", null).name if not basin.is_empty() else "clear")
	for bench_x in [-11.25, 11.25]:
		var bench := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(bench_x, 0.65, -1.7), Vector3(bench_x, 0.65, 1.7)))
		check("plaza_bench_physical_%s" % str(bench_x), not bench.is_empty(),
			bench.get("collider", null).name if not bench.is_empty() else "clear")
	ray_clear("north_gate_capsule_centreline", Vector3(0, 1.45, -80),
		Vector3(0, 1.45, -90))
	for x in [-2.1, -1.7, -0.9, 0.0, 0.9, 1.7, 2.1]:
		ray_clear("gate_width_x" + str(x), Vector3(x, 1.45, -81),
			Vector3(x, 1.45, -89))
	for side in [-1, 1]:
		for z in [42.0, 0.0, -35.0]:
			ground_hit("lane_floor_%d_%d" % [side, z], side * 35.0, z)
			ray_clear("lane_walk_%d_%d" % [side, z],
				Vector3(side * 35.0, 1.45, z + 3.0),
				Vector3(side * 35.0, 1.45, z - 3.0))
	var rows: Array = m["building_layout"]
	var overlap_count := 0
	var overlap_pairs := []
	for i in range(rows.size()):
		var a: Dictionary = rows[i]
		for j in range(i + 1, rows.size()):
			var b: Dictionary = rows[j]
			var separation := Vector2(float(a["x"]), float(a["z"])) .distance_to(
				Vector2(float(b["x"]), float(b["z"])))
			if separation < float(a["footprint_radius_m"]) + float(b["footprint_radius_m"]):
				overlap_count += 1
				overlap_pairs.append({"a":a["id"],"b":b["id"],"separation":separation,
					"required":float(a["footprint_radius_m"])+float(b["footprint_radius_m"])})
	check("building_footprints_do_not_overlap", overlap_count == 0, overlap_pairs)
	var modular: Array = world.get("interactive_houses")
	var walker_probe := CharacterBody3D.new()
	walker_probe.set_script(load("res://spatial/floor1_art_walker.gd"))
	walker_probe.set("houses", modular)
	for index in range(modular.size()):
		var house: Node3D = modular[index]
		var opening: Dictionary = house.call("door_opening_godot")
		var label := String(house.name)
		check(label + "_real_doorway", not opening.is_empty())
		if opening.is_empty(): continue
		var centre: Vector3 = house.global_transform * opening["centre"]
		var outward: Vector3 = (house.global_basis * opening["outward"]).normalized()
		# Resident-centred capsule at 0.92 m absolute world height. The opening
		# centre itself is at ~1.1 m, so adding 0.92 would hit the header falsely.
		var body_centre := Vector3(centre.x, 0.92, centre.z)
		ray_clear(label + "_lane_to_door_approach_clear",
			body_centre + outward * 6.5 + Vector3(0, 0.48, 0),
			body_centre + outward * 0.92 + Vector3(0, 0.48, 0))
		house.call("set_door_open", false)
		await physics_frame
		var closed := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			body_centre + outward * 1.1 + Vector3(0, 0.4, 0),
			body_centre - outward * 1.1 + Vector3(0, 0.4, 0)))
		check(label + "_closed_door_blocks", not closed.is_empty(),
			closed.get("collider", null).name if not closed.is_empty() else "clear")
		var walker_capsule := CapsuleShape3D.new()
		walker_capsule.radius = 0.32
		walker_capsule.height = 1.8
		var closed_shape := PhysicsShapeQueryParameters3D.new()
		closed_shape.shape = walker_capsule
		closed_shape.transform = Transform3D(Basis.IDENTITY, body_centre)
		var closed_contacts := space.intersect_shape(closed_shape, 4)
		check(label + "_closed_actual_walker_capsule_blocks", not closed_contacts.is_empty(),
			closed_contacts.map(func(hit: Dictionary) -> String:
				return String(hit.get("collider", null).name)))
		house.call("set_door_open", true)
		await physics_frame
		var opened := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			body_centre + outward * 1.1 + Vector3(0, 0.4, 0),
			body_centre - outward * 1.1 + Vector3(0, 0.4, 0)))
		check(label + "_open_door_ray_clear", opened.is_empty(),
			opened.get("collider", null).name if not opened.is_empty() else "clear")
		var route_clear := true
		var contacts := []
		for t in [6.5, 4.0, 2.0, 0.8, 0.3, -0.3, -0.8]:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = walker_capsule
			q.transform = Transform3D(Basis.IDENTITY, body_centre + outward * t)
			var hits := space.intersect_shape(q, 4)
			if not hits.is_empty():
				route_clear = false
				var names := []
				for hit: Dictionary in hits:
					var collider: Object = hit.get("collider", null)
					names.append(String(collider.name) if collider != null else "unknown")
				contacts.append({"offset_m": t, "colliders": names})
		check(label + "_open_actual_walker_capsule_route_clear", route_clear, contacts)
		var record: Dictionary = house.get("house")
		var rear_point := Vector3.ZERO
		var rear_outward := Vector3.ZERO
		for entry: Dictionary in record.get("openings", []):
			if String(entry.get("kind", "")) != "window": continue
			var authored: Array = entry["centre"]
			var raw_outward: Array = entry["outward"]
			var candidate_outward := (house.global_basis * Vector3(float(raw_outward[0]),
				float(raw_outward[2]), -float(raw_outward[1]))).normalized()
			if candidate_outward.dot(outward) > -0.8: continue
			rear_point = house.global_transform * Vector3(float(authored[0]),
				float(authored[2]), -float(authored[1]))
			rear_outward = candidate_outward
			break
		var near_rear := Vector3(rear_point.x, 0.92, rear_point.z) + rear_outward * 0.9
		var selected: Node3D = walker_probe.call("nearest_house_for_interaction", false, near_rear)
		check(label + "_F_selects_actual_rear_window_house",
			rear_outward != Vector3.ZERO and selected == house,
			{"selected": selected.name if selected != null else "none", "sample": near_rear})
		if String(house.get("variant_id")) == "03_corner_turret":
			var side_point := Vector3.ZERO
			var side_outward := Vector3.ZERO
			for entry: Dictionary in record.get("openings", []):
				if String(entry.get("kind", "")) != "window": continue
				var authored: Array = entry["centre"]
				var raw_outward: Array = entry["outward"]
				var candidate_outward := (house.global_basis * Vector3(float(raw_outward[0]),
					float(raw_outward[2]), -float(raw_outward[1]))).normalized()
				if absf(candidate_outward.dot(outward)) > 0.2: continue
				side_point = house.global_transform * Vector3(float(authored[0]),
					float(authored[2]), -float(authored[1]))
				side_outward = candidate_outward
				break
			var near_side := Vector3(side_point.x, 0.92, side_point.z) + side_outward * 0.9
			var side_selected: Node3D = walker_probe.call("nearest_house_for_interaction", false, near_side)
			check(label + "_F_selects_actual_side_window_house",
				side_outward != Vector3.ZERO and side_selected == house,
				{"selected": side_selected.name if side_selected != null else "none", "sample": near_side})
		if index == 0:
			house.call("set_window_open", true)
			check("first_window_opens", house.call("is_window_open"))
			house.call("set_window_open", false)
			check("first_window_closes", not house.call("is_window_open"))
	if modular.size() >= 7:
		var first: Node3D = modular[0]
		var second: Node3D = modular[6]
		first.call("set_door_open", true)
		second.call("set_door_open", false)
		check("same_variant_instances_independent", first.call("is_door_open") and
			not second.call("is_door_open"))
	_finish()


func _finish() -> void:
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row["passed"])
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("Expanded world test output required")
		quit(2)
		return
	var report := {"suite": "floor1_expanded_world_geometry_physics",
		"checks": checks, "check_count": checks.size(), "failure_count": failures.size(),
		"failures": failures, "layout": layout_snapshot,
		"world_state_mutations": 0, "model_calls": 0}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite": report.suite, "checks": checks.size(),
		"failures": failures.size(), "output": output}))
	if scene != null:
		scene.free()
	quit(0 if failures.is_empty() else 1)
