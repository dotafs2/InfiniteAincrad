extends SceneTree
## Real imported-GLB audit plus deterministic mutual-exclusion checks.
## No live world, resident, GM, network or save access.

var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func record_case(label: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"case": label, "passed": passed, "detail": detail})


func triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var indices := mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array
		total += indices.size() / 3
	return total


func _run() -> void:
	var report_text := FileAccess.get_file_as_string("res://assets/floor1/meshy_houses_lod/manifest.json")
	var manifest: Dictionary = JSON.parse_string(report_text)
	record_case("manifest_present", not manifest.is_empty())
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var bounds_by_house := {}
	for house: Dictionary in manifest.get("houses", []):
		var house_id := String(house["id"])
		var component := Node3D.new()
		component.name = house_id
		component.set_script(load("res://spatial/meshy_house_lod_component.gd"))
		component.set("house_id", house_id)
		scene.add_child(component)
		var expected: Array = house["lod_metrics_blender"]
		var material: Material = null
		var surfaces := []
		for index in range(3):
			var item := component.call("lod_mesh", index) as MeshInstance3D
			record_case(house_id + "_lod%d_imported" % index, item != null)
			if item == null: continue
			var measured := triangle_count(item.mesh)
			record_case(house_id + "_lod%d_actual_triangles" % index,
				measured == int(expected[index]["triangles"]), measured)
			var count := item.mesh.get_surface_count()
			surfaces.append(count)
			record_case(house_id + "_lod%d_surface" % index, count == 1, count)
			var item_material := item.get_active_material(0)
			record_case(house_id + "_lod%d_material_present" % index, item_material != null)
			if material == null: material = item_material
			record_case(house_id + "_lod%d_material_shared" % index, item_material == material)
			var pbr := item_material as StandardMaterial3D
			record_case(house_id + "_lod%d_source_color_texture" % index,
				pbr != null and pbr.albedo_texture != null)
			var arrays := item.mesh.surface_get_arrays(0)
			var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			record_case(house_id + "_lod%d_uv_present" % index, not uv.is_empty(), uv.size())
			var aabb := item.mesh.get_aabb()
			record_case(house_id + "_lod%d_metric_height" % index,
				absf(aabb.size.y - float(house["intended_display_height_m"])) <= 0.5, aabb.size.y)
			if index == 0: bounds_by_house[house_id] = [aabb.position, aabb.size]
		for distance in [0.0, 29.99, 30.0, 50.0, 74.99, 75.0, 200.0]:
			var actual := int(component.call("update_lod_for_distance", distance))
			var wanted := 0 if distance < 30.0 else (1 if distance < 75.0 else 2)
			var visible := 0
			for index in range(3):
				var item := component.call("lod_mesh", index) as MeshInstance3D
				if item != null and item.visible: visible += 1
			record_case(house_id + "_distance_" + str(distance), actual == wanted and visible == 1,
				{"actual": actual, "expected": wanted, "visible": visible})
		for forced in range(3):
			component.set("force_lod", forced)
			var actual := int(component.call("update_lod_for_distance", 200.0))
			var visible := 0
			for index in range(3):
				var item := component.call("lod_mesh", index) as MeshInstance3D
				if item != null and item.visible: visible += 1
			record_case(house_id + "_forced_" + str(forced), actual == forced and visible == 1)
		component.set("force_lod", -1)
		component.call("update_lod_for_distance", 0.0)
		var body := component.get_node_or_null("ExteriorOnlyVisualShellCollision")
		record_case(house_id + "_collision_opt_in", body == null)
		# A separate selected 2K GLB keeps the same actual mesh/UV metrics but
		# imports its own 2048² PBR images. Loading one tier per house is the
		# runtime contract; the test loads both only to compare resources.
		var tier2 := Node3D.new()
		tier2.name = house_id + "_2k"
		tier2.set_script(load("res://spatial/meshy_house_lod_component.gd"))
		tier2.set("house_id", house_id)
		tier2.set("texture_tier", "2k")
		scene.add_child(tier2)
		record_case(house_id + "_2k_asset_selected",
			String(tier2.get_meta("asset_path", "")).ends_with("_lod_2k.glb") and
			String(tier2.get_meta("texture_tier", "")) == "2k")
		var tier2_material: Material = null
		for index in range(3):
			var low2 := tier2.call("lod_mesh", index) as MeshInstance3D
			record_case(house_id + "_2k_lod%d_imported" % index, low2 != null)
			if low2 == null: continue
			var actual2 := triangle_count(low2.mesh)
			record_case(house_id + "_2k_lod%d_triangles_byte_preserved" % index,
				actual2 == int(expected[index]["triangles"]), actual2)
			record_case(house_id + "_2k_lod%d_surface" % index,
				low2.mesh.get_surface_count() == 1, low2.mesh.get_surface_count())
			var material2 := low2.get_active_material(0)
			if tier2_material == null: tier2_material = material2
			record_case(house_id + "_2k_lod%d_material_shared" % index,
				material2 != null and material2 == tier2_material)
			var pbr2 := material2 as StandardMaterial3D
			record_case(house_id + "_2k_lod%d_actual_albedo_2048" % index,
				pbr2 != null and pbr2.albedo_texture != null and
				pbr2.albedo_texture.get_width() == 2048 and
				pbr2.albedo_texture.get_height() == 2048)
			record_case(house_id + "_2k_lod%d_actual_normal_2048" % index,
				pbr2 != null and pbr2.normal_texture != null and
				pbr2.normal_texture.get_width() == 2048 and
				pbr2.normal_texture.get_height() == 2048)
			var uv2 := low2.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			record_case(house_id + "_2k_lod%d_uv_present" % index,
				uv2.size() > 0, uv2.size())
			var bounds2 := low2.mesh.get_aabb()
			record_case(house_id + "_2k_lod%d_height" % index,
				absf(bounds2.size.y - float(house["intended_display_height_m"])) <= 0.5,
				bounds2.size.y)
		record_case(house_id + "_2k_material_distinct_from_4k",
			material != null and tier2_material != null and material != tier2_material)
		for distance in [0.0, 29.99, 30.0, 74.99, 75.0, 200.0]:
			var chosen := int(tier2.call("update_lod_for_distance", distance))
			var expected_lod := 0 if distance < 30.0 else (1 if distance < 75.0 else 2)
			var active := 0
			for index in range(3):
				var low2 := tier2.call("lod_mesh", index) as MeshInstance3D
				if low2 != null and low2.visible: active += 1
			record_case(house_id + "_2k_distance_" + str(distance),
				chosen == expected_lod and active == 1,
				{"chosen": chosen, "expected": expected_lod, "visible": active})
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row["passed"])
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("LOD audit output path required")
		quit(2)
		return
	var result := {"suite": "meshy_house_lod_import", "check_count": checks.size(),
		"failure_count": failures.size(), "failures": failures, "checks": checks,
		"bounds_by_house": bounds_by_house, "world_save_writes": 0,
		"resident_model_calls": 0}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print(JSON.stringify({"suite": result.suite, "checks": checks.size(),
		"failures": failures.size(), "output": output}))
	quit(0 if failures.is_empty() else 1)
