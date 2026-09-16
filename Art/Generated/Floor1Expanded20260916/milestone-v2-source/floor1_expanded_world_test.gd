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
	var requested_tier := "2k"
	var requested_meadow_mix := 0.22
	var requested_native_oak_trial := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lod-texture-tier="):
			requested_tier = arg.trim_prefix("--lod-texture-tier=")
		elif arg.begins_with("--meadow-texture-mix="):
			requested_meadow_mix = clampf(float(arg.trim_prefix("--meadow-texture-mix=")), 0.0, 0.40)
		elif arg == "--native-oak-trial":
			requested_native_oak_trial = true
		elif arg.begins_with("--native-oak-trial="):
			requested_native_oak_trial = arg.trim_prefix("--native-oak-trial=") in ["on", "true", "1"]
	check("selected_exterior_texture_tier", String(m["exterior_texture_tier"]) == requested_tier,
		m["exterior_texture_tier"])
	check("selectable_meadow_mix_actual_world_state",
		is_equal_approx(float(m["meadow_texture_mix"]), requested_meadow_mix),
		m["meadow_texture_mix"])
	var world_palette: Dictionary = world.get("_palette")
	var country_grass := world_palette["grass"] as ShaderMaterial
	var town_grass := world_palette["town_grass"] as ShaderMaterial
	var country_mix := float(country_grass.get_shader_parameter("meadow_mix"))
	check("painted_texture_affects_only_country_grass_not_town_patch",
		is_equal_approx(country_mix, requested_meadow_mix) and
		is_zero_approx(float(town_grass.get_shader_parameter("meadow_mix"))),
		{"country_mix": country_mix,
		"town_mix": town_grass.get_shader_parameter("meadow_mix")})
	if requested_meadow_mix > 0.0:
		var meadow_path := "res://assets/floor1/ground_textures_20260916/meadow_grass_albedo_v1.png"
		var meadow := load(meadow_path) as Texture2D
		check("painted_meadow_1254px_actual_import", meadow != null and
			meadow.get_width() == 1254 and meadow.get_height() == 1254,
			[meadow.get_width(), meadow.get_height()] if meadow != null else [])
		if meadow != null:
			var imported_image := meadow.get_image()
			check("painted_meadow_actual_import_has_mipmaps",
				imported_image != null and imported_image.has_mipmaps(),
				imported_image.has_mipmaps() if imported_image != null else false)
			check("country_shader_uses_one_imported_meadow_resource",
				country_grass.get_shader_parameter("meadow_albedo") == meadow and
				String(m["meadow_texture_path"]) == meadow_path)
	var exteriors: Array = world.get("exterior_houses")
	var imported_tier_count := 0
	var expected_suffix := "_lod_2k.glb" if requested_tier == "2k" else "_lod.glb"
	for exterior: Node3D in exteriors:
		var is_selected: bool = exterior.get_meta("texture_tier", "") == requested_tier
		var is_correct_asset := String(exterior.get_meta("asset_path", "")).ends_with(expected_suffix)
		if is_selected and is_correct_asset:
			imported_tier_count += 1
	check("all_32_exteriors_use_one_selected_texture_tier",
		imported_tier_count == 32, imported_tier_count)
	check("gate_at_north85", int(m["northern_gate_z_m"]) == -85)
	check("path_to_north230", int(m["countryside_path_end_z_m"]) == -230)
	check("four_distinct_farm_plots", int(m["farm_plots"]) == 4)
	check("grouped_residential_and_roadside_trees", int(m["tree_instances"]) >= 130,
		m["tree_instances"])
	check("grouped_yard_and_field_edge_vegetation", int(m["vegetation_instances"]) >= 330,
		m["vegetation_instances"])
	check("two_real_grounded_outer_ridge_collisions",
		int(m["perimeter_grounded_ridge_collision_bodies"]) == 2,
		m["perimeter_grounded_ridge_collision_bodies"])
	var ridge_triangles := int(m["perimeter_grounded_ridge_triangles"])
	check("restrained_low_polygon_side_ridges", ridge_triangles >= 500 and ridge_triangles <= 3000,
		ridge_triangles)
	var ridge_height := float(m["perimeter_ridge_max_height_m"])
	check("side_ridges_gently_grounded_under_9m", ridge_height > 4.0 and ridge_height < 9.0,
		ridge_height)
	check("detached_sphere_hill_props_removed", world.find_children("EdgeHill").is_empty())
	for side in [-1, 1]:
		var ridge := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(side * 178.0, 25.0, -155.0), Vector3(side * 178.0, -1.0, -155.0)))
		check("grounded_ridge_crest_real_walk_surface_%d" % side,
			not ridge.is_empty() and String(ridge.get("collider", null).name).begins_with(
				"PerimeterRidgeCollision") and float(ridge["position"].y) > 3.0,
			{"collider": ridge.get("collider", null).name if not ridge.is_empty() else "none",
			 "hit": ridge.get("position", Vector3.ZERO)})
		for z in [-120.0, -200.0]:
			var woodland := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(side * 136.0, 25.0, z), Vector3(side * 136.0, -1.0, z)))
			check("original_woodland_roots_stay_ground_level_%d_%d" % [side, int(z)],
				not woodland.is_empty() and float(woodland["position"].y) < 0.15,
				woodland.get("position", Vector3.ZERO))
	check("one_real_near_west_forest_edge_bank_collision",
		int(m["west_forest_bank_collision_bodies"]) == 1,
		m["west_forest_bank_collision_bodies"])
	check("low_west_bank_actual_triangles",
		int(m["west_forest_bank_triangles"]) == 168,
		m["west_forest_bank_triangles"])
	check("west_bank_rises_only_about_one_metre",
		float(m["west_forest_bank_max_height_m"]) > 0.75 and
		float(m["west_forest_bank_max_height_m"]) < 1.45,
		m["west_forest_bank_max_height_m"])
	var bank_visual := world.find_child("WestForestEdgeWalkableBank", true, false) as MeshInstance3D
	check("west_forest_bank_stays_before_ground_edge_minus235",
		bank_visual != null and bank_visual.mesh != null and
		bank_visual.mesh.get_aabb().position.z >= -229.2 and
		bank_visual.mesh.get_aabb().end.z <= -203.7,
		bank_visual.mesh.get_aabb() if bank_visual != null else "missing")
	var bank_crest := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-56.0, 8.0, -216.0), Vector3(-56.0, -1.0, -216.0)))
	check("near_bank_crest_is_actual_walkable_surface",
		not bank_crest.is_empty() and String(bank_crest.get("collider", null).name) ==
		"WestForestEdgeBankCollision" and float(bank_crest["position"].y) > 0.65 and
		float(bank_crest["normal"].y) > 0.75,
		{"collider": bank_crest.get("collider", null).name if not bank_crest.is_empty() else "none",
		 "position": bank_crest.get("position", Vector3.ZERO),
		 "normal": bank_crest.get("normal", Vector3.ZERO)})
	for place in [Vector3(-40, 0, -216), Vector3(-69, 0, -216),
			Vector3(-56, 0, -204), Vector3(-56, 0, -229)]:
		var fade := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(place.x, 5.0, place.z), Vector3(place.x, -1.0, place.z)))
		check("bank_fades_to_real_ground_%d_%d" % [int(place.x), int(place.z)],
			not fade.is_empty() and absf(float(fade["position"].y)) < 0.15,
			fade.get("position", Vector3.ZERO))
	var west_old_grove_root := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-57.0, 5.0, -192.5), Vector3(-57.0, -1.0, -192.5)))
	check("west_existing_grove_root_north_of_bank_unchanged",
		not west_old_grove_root.is_empty() and float(west_old_grove_root["position"].y) < 0.15,
		west_old_grove_root.get("position", Vector3.ZERO))
	var bank_capsule := CapsuleShape3D.new()
	bank_capsule.radius = 0.32
	bank_capsule.height = 1.8
	var bank_walk_clear := true
	var bank_walk_rows := []
	for point in [Vector2(-34, -211), Vector2(-40, -214), Vector2(-45, -216),
			Vector2(-50, -218), Vector2(-55, -220), Vector2(-60, -222), Vector2(-65, -224)]:
		var floor_ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(point.x, 5.0, point.y), Vector3(point.x, -1.0, point.y)))
		var surface_y := float(floor_ray["position"].y) if not floor_ray.is_empty() else -99.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = bank_capsule
		# Place the actual walker-sized body just above the sampled slope; the
		# 0.09m floor margin avoids counting the traversed surface as an obstacle.
		query.transform = Transform3D(Basis.IDENTITY,
			Vector3(point.x, surface_y + 0.99, point.y))
		var contacts := space.intersect_shape(query, 8) if not floor_ray.is_empty() else []
		if floor_ray.is_empty() or not contacts.is_empty():
			bank_walk_clear = false
		bank_walk_rows.append({"xz": point, "surface_y": surface_y,
			"collider": floor_ray.get("collider", null).name if not floor_ray.is_empty() else "none",
			"contacts": contacts.map(func(c: Dictionary) -> String:
				return String(c.get("collider", null).name))})
	check("actual_walker_size_shelter_approach_over_west_bank_clear", bank_walk_clear,
		bank_walk_rows)
	check("north_sector_is_specific_added_ground_not_bounding_box_claim",
		m["north_sector_bounds_m"] == {"x": [-210, 85], "z": [-335, -235]} and
		int(m["north_sector_added_area_m2"]) == 29500 and
		int(m["ground_union_area_m2"]) == 222700 and
		m["ground_union_is_rectangular"] == false and m["world_extent_m"] == [420, 460],
		{"base": m["world_extent_m"], "addition": m["north_sector_bounds_m"]})
	var north_visual := world.find_child("NorthwestContinuousGroundSector", true, false) as MeshInstance3D
	var north_actual_tris := -1
	if north_visual != null and north_visual.mesh != null:
		var arrays: Array = north_visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		north_actual_tris = int(vertices.size() / 3)
	check("north_sector_real_low_polygon_imported_mesh_and_true_collision",
		north_visual != null and north_actual_tris == 340 and
		int(m["north_sector_actual_triangles"]) == north_actual_tris and
		int(m["north_sector_collision_bodies"]) == 1,
		{"mesh_triangles": north_actual_tris, "reported": m["north_sector_actual_triangles"]})
	if north_visual != null:
		var aabb := north_visual.mesh.get_aabb()
		check("north_sector_mesh_true_bounds_and_8_to_15m_rising_mass",
			absf(aabb.position.x + 210.0) < 0.01 and absf(aabb.end.x - 85.0) < 0.01 and
			absf(aabb.position.z + 335.0) < 0.01 and absf(aabb.end.z + 235.0) < 0.01 and
			float(m["north_sector_max_height_m"]) >= 8.0 and
			float(m["north_sector_max_height_m"]) <= 15.0,
			{"aabb": aabb, "max_h": m["north_sector_max_height_m"]})
	for seam_x in [-200.0, -120.0, -50.0, -10.0, 0.0, 10.0, 70.0]:
		var join := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(seam_x, 25.0, -235.0), Vector3(seam_x, -1.0, -235.0)))
		check("north_sector_old_ground_zero_height_seam_at_x_%d" % int(seam_x),
			not join.is_empty() and absf(float(join["position"].y)) <= 0.08,
			{"position": join.get("position", Vector3.ZERO),
			 "collider": join.get("collider", null).name if not join.is_empty() else "none"})
	for crest_x in [-180.0, -130.0, -90.0]:
		var crest := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(crest_x, 25.0, -310.0), Vector3(crest_x, -2.0, -310.0)))
		check("north_sector_true_crest_walk_surface_%d" % int(crest_x),
			not crest.is_empty() and String(crest.get("collider", null).name) ==
			"NorthwestSectorTerrainCollision" and float(crest["position"].y) > 7.0 and
			float(crest["normal"].y) > 0.68,
			{"position": crest.get("position", Vector3.ZERO),
			 "normal": crest.get("normal", Vector3.ZERO),
			 "collider": crest.get("collider", null).name if not crest.is_empty() else "none"})
	var north_path := world.find_child("NorthPathPastOriginalGroundEdge", true, false) as MeshInstance3D
	check("visible_five_metre_path_crosses_original_minus235_edge",
		north_path != null and north_path.mesh != null and
		absf(north_path.mesh.get_aabb().size.x - 5.0) < 0.01 and
		(north_path.position.z + north_path.mesh.get_aabb().end.z) >= -230.05 and
		(north_path.position.z + north_path.mesh.get_aabb().position.z) <= -268.95,
		north_path.mesh.get_aabb() if north_path != null else "none")
	var north_axis_clear := true
	var north_axis_rows := []
	var uphill_clear := true
	var uphill_rows := []
	for route in [[Vector2(0, -225), Vector2(0, -232), Vector2(0, -235),
			Vector2(0, -245), Vector2(0, -260), Vector2(0, -267)],
			[Vector2(-105, -236), Vector2(-105, -251), Vector2(-105, -268),
			Vector2(-105, -282), Vector2(-105, -295)]]:
		var first_point: Vector2 = route[0]
		var is_axis := first_point.x == 0.0
		for point: Vector2 in route:
			var floor_ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(point.x, 25.0, point.y), Vector3(point.x, -2.0, point.y)))
			var floor_y := float(floor_ray["position"].y) if not floor_ray.is_empty() else -99.0
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = bank_capsule
			query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, floor_y + 0.99, point.y))
			var contacts := space.intersect_shape(query, 8) if not floor_ray.is_empty() else []
			if (floor_ray.is_empty() or not contacts.is_empty() or
				(is_axis and absf(floor_y) > 0.08)):
				if is_axis: north_axis_clear = false
				else: uphill_clear = false
			var record := {"xz": point, "floor_y": floor_y,
				"collider": floor_ray.get("collider", null).name if not floor_ray.is_empty() else "none",
				"contacts": contacts.map(func(c: Dictionary) -> String:
					return String(c.get("collider", null).name))}
			if is_axis: north_axis_rows.append(record)
			else: uphill_rows.append(record)
	check("real_0_32_by_1_80_walker_main_axis_old_to_new_sector_clear",
		north_axis_clear, north_axis_rows)
	check("real_0_32_by_1_80_walker_can_climb_sampled_north_ridge",
		uphill_clear, uphill_rows)
	var north_trees: Array = world.get("_north_sector_trees")
	check("exactly_24_grouped_original_kit_forestline_trees_only_on_new_slope",
		north_trees.size() == 24 and int(m["north_sector_kit_tree_instances"]) == 24 and
		north_trees.all(func(tree: Node3D) -> bool:
			return (tree.position.x < -60.0 and tree.position.z < -275.0 and
				String(tree.name).begins_with("NorthSectorForestLineTree"))),
		{"count": north_trees.size(), "reported": m["north_sector_kit_tree_instances"]})
	var grounded_tree_rows := []
	var all_tree_roots_grounded := true
	for tree: Node3D in north_trees:
		var root_ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(tree.position.x, 25.0, tree.position.z),
			Vector3(tree.position.x, -2.0, tree.position.z)))
		var actual_y := float(root_ray["position"].y) if not root_ray.is_empty() else -99.0
		var offset_y := absf(actual_y - tree.position.y)
		if (root_ray.is_empty() or offset_y > 0.03 or
			String(root_ray.get("collider", null).name) != "NorthwestSectorTerrainCollision"):
			all_tree_roots_grounded = false
		grounded_tree_rows.append({"name": tree.name, "parent_y": tree.position.y,
			"actual_mesh_surface_y": actual_y, "delta_y": offset_y})
	check("all_24_new_tree_pivots_sample_real_collision_triangle_heights",
		all_tree_roots_grounded, grounded_tree_rows)
	var native_trials := world.find_children("NativeT2ForestOakTrialOne", "Node3D", true, false)
	check("native_t2_oak_trial_is_exactly_one_only_when_requested",
		native_trials.size() == (1 if requested_native_oak_trial else 0) and
		int(m["native_forest_oak_trial_instances"]) == native_trials.size() and
		bool(m["native_forest_oak_one_tree_default_adopted"]) == requested_native_oak_trial,
		{"requested": requested_native_oak_trial, "instances": native_trials.size()})
	if requested_native_oak_trial and native_trials.size() == 1:
		var trial := native_trials[0] as Node3D
		var trunk := trial.find_child("NativeT2OakTrunkOnlyCollision", true, false) as StaticBody3D
		var sampled := PhysicsRayQueryParameters3D.create(
			Vector3(trial.position.x, 26.0, trial.position.z),
			Vector3(trial.position.x, -2.0, trial.position.z))
		if trunk != null: sampled.exclude = [trunk.get_rid()]
		var true_ground := space.intersect_ray(sampled)
		check("native_t2_oak_trial_root_samples_real_nw_ground_surface",
			trial.position.distance_to(Vector3(-55.0, trial.position.y, -275.0)) < 0.001 and
			not true_ground.is_empty() and
			String(true_ground.get("collider", null).name) == "NorthwestSectorTerrainCollision" and
			absf(float(true_ground["position"].y) - trial.position.y) < 0.035,
			{"parent": trial.position, "actual_ground": true_ground.get("position", Vector3.ZERO)})
		check("native_t2_oak_trial_is_separate_asset_not_approved_courtyard_100k",
			String(trial.get_meta("asset_path", "")).ends_with("F1_oak_smart15k_forest_trial.glb") and
			int(trial.get_meta("source_triangles", 0)) == 14783 and
			int(m["approved_courtyard_oak_instances"]) == 1)
		var bounds_low := Vector3(INF, INF, INF)
		var bounds_high := Vector3(-INF, -INF, -INF)
		var native_actual_tris := 0
		var native_surfaces := 0
		for mesh: MeshInstance3D in trial.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			var box := mesh.mesh.get_aabb()
			for xx in [box.position.x, box.end.x]:
				for yy in [box.position.y, box.end.y]:
					for zz in [box.position.z, box.end.z]:
						var point := mesh.global_transform * Vector3(xx, yy, zz)
						bounds_low = bounds_low.min(point)
						bounds_high = bounds_high.max(point)
			for surface in range(mesh.mesh.get_surface_count()):
				native_surfaces += 1
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				native_actual_tris += int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
		check("native_t2_oak_trial_real_imported_14783_triangles",
			native_actual_tris == 14783 and native_surfaces > 0,
			{"tris": native_actual_tris, "surfaces": native_surfaces})
		check("native_t2_oak_trial_true_visual_7_2m_root_and_crown_bounds",
			absf(bounds_low.y - trial.position.y) < 0.11 and
			absf((bounds_high.y - bounds_low.y) - 7.2) < 0.12,
			{"low": bounds_low, "high": bounds_high})
		var trunk_probe := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			trial.position + Vector3(-1.2, 1.2, 0),
			trial.position + Vector3(1.2, 1.2, 0)))
		check("native_t2_oak_trial_only_trunk_proxy_blocks",
			trunk != null and not trunk_probe.is_empty() and
			String(trunk_probe.get("collider", null).name) == "NativeT2OakTrunkOnlyCollision",
			trunk_probe.get("collider", null).name if not trunk_probe.is_empty() else "clear")
		check("native_t2_oak_trial_main_road_path_clear",
			trial.position.x < -48.0 and trial.position.z < -270.0)
	var focal_oaks := world.find_children("FocalCourtyardOakWest", "Node3D", true, false)
	check("exactly_one_approved_100k_courtyard_oak",
		focal_oaks.size() == 1 and int(m["approved_courtyard_oak_instances"]) == 1,
		{"nodes": focal_oaks.size(), "metrics": m["approved_courtyard_oak_instances"]})
	if focal_oaks.size() == 1:
		var focal := focal_oaks[0] as Node3D
		check("oak_authored_in_west_residential_garden",
			focal.position.distance_to(Vector3(-24.8, 0, 16.8)) < 0.01,
			focal.position)
		check("oak_imported_approved_asset_only",
			String(focal.get_meta("asset_path", "")).ends_with("F1_courtyard_oak_100k.glb") and
			int(focal.get_meta("source_approved_triangles", 0)) == 100000)
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		var mesh_count := 0
		var actual_triangles := 0
		for mesh: MeshInstance3D in focal.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			mesh_count += 1
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				actual_triangles += int(indices.size() / 3) if indices.size() > 0 else int(
					vertices.size() / 3)
			var box := mesh.mesh.get_aabb()
			for xx in [box.position.x, box.end.x]:
				for yy in [box.position.y, box.end.y]:
					for zz in [box.position.z, box.end.z]:
						var point := mesh.global_transform * Vector3(xx, yy, zz)
						low = low.min(point)
						high = high.max(point)
		check("oak_actual_imported_meshes_present", mesh_count > 0, mesh_count)
		check("oak_reported_100k_triangles_are_real_imported_geometry",
			actual_triangles == 100000, actual_triangles)
		check("oak_actual_visual_height_8_5m",
			mesh_count > 0 and absf((high.y - low.y) - 8.5) < 0.12,
			{"min": low, "max": high, "height": high.y - low.y})
		check("oak_visual_roots_touch_residential_ground",
			mesh_count > 0 and absf(low.y) < 0.12, low.y)
		check("oak_crown_clear_of_two_neighboring_house_footprints",
			Vector2(focal.position.x, focal.position.z).distance_to(Vector2(-24.5, 0)) > 11.1 and
			Vector2(focal.position.x, focal.position.z).distance_to(Vector2(-24.5, 35)) > 11.1)
		var trunk_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(-25.9, 1.2, 16.8), Vector3(-23.7, 1.2, 16.8)))
		check("courtyard_oak_trunk_only_proxy_blocks",
			not trunk_hit.is_empty() and String(trunk_hit.get("collider", null).name) ==
			"CourtyardOakTrunkOnlyCollision",
			trunk_hit.get("collider", null).name if not trunk_hit.is_empty() else "clear")
		var walker_capsule := CapsuleShape3D.new()
		walker_capsule.radius = 0.32
		walker_capsule.height = 1.8
		var garden_access_clear := true
		var access_contacts := []
		for x in [-35.0, -33.2, -31.4]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = walker_capsule
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.92, 16.8))
			var contacts := space.intersect_shape(query, 8)
			if not contacts.is_empty():
				garden_access_clear = false
				access_contacts.append({"x": x, "colliders": contacts.map(func(c: Dictionary) -> String:
					return String(c.get("collider", null).name))})
		check("real_walker_capsule_lane_to_oak_garden_access_clear",
			garden_access_clear, access_contacts)
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
	for side in [-1, 1]:
		var seat := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(side * 29.5, 0.25, 22.1),
			Vector3(side * 29.5, 0.25, 19.5)))
		check("residential_yard_seat_physical_%d" % side,
			not seat.is_empty() and String(seat.get("collider", null).name).begins_with("ResidenceGardenSeat"),
			seat.get("collider", null).name if not seat.is_empty() else "clear")
		var hedge_rail := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(side * 5.5, 0.33, -122.0),
			Vector3(side * 8.5, 0.33, -122.0)))
		check("country_verge_rail_physical_%d" % side,
			not hedge_rail.is_empty() and String(hedge_rail.get("collider", null).name).begins_with("CountryHedgeRail"),
			hedge_rail.get("collider", null).name if not hedge_rail.is_empty() else "clear")
	for z in [-122.0, -163.0, -196.0]:
		ray_clear("grove_path_centreline_still_clear_%d" % int(z),
			Vector3(0, 1.45, z + 3.0), Vector3(0, 1.45, z - 3.0))
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
	# _interact reads global_position, so the real scripted probe must be in
	# the scene tree. Keep its physics disabled and mask zero for geometry rays.
	walker_probe.collision_layer = 0
	walker_probe.collision_mask = 0
	walker_probe.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(walker_probe)
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
		if index in [0, 2] and rear_outward != Vector3.ZERO:
			# Drive the actual walker's F interaction at a real rear opening,
			# then verify this house's shared window state opens and closes.
			walker_probe.global_position = near_rear
			house.call("set_window_open", false)
			walker_probe.call("_interact", false)
			check(label + "_actual_F_interaction_opens_selected_house_windows",
				house.call("is_window_open"), {"sample": near_rear, "selected": selected.name})
			walker_probe.call("_interact", false)
			check(label + "_actual_F_interaction_closes_selected_house_windows",
				not house.call("is_window_open"), near_rear)
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
	var inserts: Array = world.get("furnished_interiors")
	check("three_dedicated_ground_floor_inserts", inserts.size() == 3,
		m["furnished_interior_metrics"])
	var expected_kinds := {"01_hearth_cottage": "home", "02_market_house": "bakery",
		"03_corner_turret": "artisan"}
	var furnished_variants: Array[String] = []
	for insert: Node3D in inserts:
		var host := insert.get_parent() as Node3D
		var metrics: Dictionary = insert.call("art_metrics")
		var variant := String(metrics.get("variant", ""))
		furnished_variants.append(variant)
		var label := "furnished_" + variant
		check(label + "_direct_child_and_ground_floor_only",
			host != null and host in modular and metrics.get("ground_floor_only", false),
			metrics)
		check(label + "_variant_layout_and_real_props",
			String(metrics.get("kind", "")) == String(expected_kinds.get(variant, "")) and
			int(metrics.get("prop_instances", 0)) >= 40 and
			int(metrics.get("solid_proxies", 0)) >= 4, metrics)
		var local_lights := insert.find_children("WarmInteriorFill", "OmniLight3D", true, false)
		var lamp := local_lights[0] as OmniLight3D if local_lights.size() == 1 else null
		check(label + "_one_original_local_light_actual_energy_range_shadows",
			lamp != null and is_equal_approx(lamp.light_energy, 0.80) and
			is_equal_approx(lamp.omni_range, 4.6) and lamp.shadow_enabled,
			{"lights": local_lights.size(), "energy": lamp.light_energy if lamp != null else -1.0,
			"range": lamp.omni_range if lamp != null else -1.0})
		var visual := insert.find_child("CagedLanternVisual", true, false) as Node3D
		var imported_lantern := visual.find_child("TC_caged_travel_lantern", true, false) if visual != null else null
		check(label + "_real_independent_caged_lantern_and_period_mount_in_world",
			visual != null and imported_lantern is MeshInstance3D and
			insert.find_child("LampCeilingMount", true, false) is MeshInstance3D and
			insert.find_child("LampHanger", true, false) is MeshInstance3D,
			{"lantern": imported_lantern.name if imported_lantern != null else "none"})
		var sign := insert.find_child("BakeryExteriorSign", true, false) as Node3D
		if String(metrics.get("kind", "")) == "bakery":
			var emblem := sign.find_child("SF13_Bakery_Pretzel_Emblem", true, false) as MeshInstance3D if sign != null else null
			check(label + "_unique_actual_bakery_exterior_identity_mesh_by_real_door",
				sign != null and emblem != null and emblem.mesh != null and
				emblem.mesh.get_surface_count() == 3 and
				sign.position.distance_to(Vector3(-2.35, 2.68, 4.62)) < 0.01 and
				metrics.get("bakery_exterior_sign", false),
				{"sign": sign.name if sign != null else "none",
				 "local": sign.position if sign != null else Vector3.ZERO})
		else:
			check(label + "_no_bakery_exterior_sign_on_other_home",
				sign == null and not metrics.get("bakery_exterior_sign", false))
		if host == null: continue
		host.call("set_door_open", true)
		await physics_frame
		var opening: Dictionary = host.call("door_opening_godot")
		var centre: Vector3 = host.global_transform * opening["centre"]
		var outward: Vector3 = (host.global_basis * opening["outward"]).normalized()
		var route_points: Array[Vector3] = [Vector3(centre.x, 0.93, centre.z) + outward * 0.8]
		for point: Vector3 in insert.call("route_waypoints_local"):
			route_points.append(host.global_transform * point)
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.80
		var contacts: Array[Dictionary] = []
		for segment in range(route_points.size() - 1):
			for step in range(11):
				var sample := route_points[segment].lerp(route_points[segment + 1], float(step) / 10.0)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, sample)
				var hits := space.intersect_shape(query, 4)
				if not hits.is_empty():
					contacts.append({"segment": segment, "step": step, "sample": sample,
						"colliders": hits.map(func(hit: Dictionary) -> String:
							return String(hit.get("collider", null).name))})
		check(label + "_actual_walker_capsule_door_to_room_route",
			route_points.size() >= 3 and contacts.is_empty(), contacts)
	check("one_of_each_furnished_variant", furnished_variants.size() == 3 and
		furnished_variants.has("01_hearth_cottage") and
		furnished_variants.has("02_market_house") and
		furnished_variants.has("03_corner_turret"), furnished_variants)
	if modular.size() >= 7:
		var first: Node3D = modular[0]
		var second: Node3D = modular[6]
		first.call("set_door_open", true)
		second.call("set_door_open", false)
		check("same_variant_instances_independent", first.call("is_door_open") and
			not second.call("is_door_open"))
	world.call("_init_tour_v2")
	var tour_keys: Array = world.get("_tour_keyframes")
	var tour_house := world.get("_tour_demo_house") as Node3D
	var tour_duration := 0.0
	for key: Dictionary in tour_keys:
		tour_duration += float(key["duration_to_next_s"])
	check("v2_camera_tour_60s_route_is_one_real_scene_without_cut",
		tour_keys.size() == 19 and is_equal_approx(tour_duration, 60.0) and
		tour_house != null, {"keys": tour_keys.size(), "duration_s": tour_duration})
	if tour_house != null and tour_keys.size() == 19:
		var doorway: Dictionary = tour_house.call("door_opening_godot")
		var true_centre: Vector3 = tour_house.global_transform * doorway["centre"]
		check("v2_camera_centreline_uses_actual_furnished_bakery_door_manifest",
			absf(true_centre.x + 29.0) < 0.08 and absf(true_centre.z + 0.9) < 0.08 and
			String(tour_house.get("variant_id")) == "02_market_house",
			true_centre)
		# ShopBay is a visible imported GLB mesh with no game collision proxy.
		# Give only that real mesh a temporary QA trimesh on an unused layer;
		# this catches a canopy timber visually piercing the true entrance even
		# when all physical capsule tests (correctly) find no existing collider.
		var shop_bay := tour_house.find_child("ShopBay", true, false) as MeshInstance3D
		check("v2_bakery_imported_shopbay_real_mesh_present",
			shop_bay != null and shop_bay.mesh != null)
		if shop_bay != null and shop_bay.mesh != null:
			var visual_probe := StaticBody3D.new()
			visual_probe.name = "ImportedShopBayVisibleMeshQAOnly"
			visual_probe.collision_layer = 1 << 24
			visual_probe.collision_mask = 0
			var visual_shape := CollisionShape3D.new()
			visual_shape.shape = shop_bay.mesh.create_trimesh_shape()
			visual_probe.add_child(visual_shape)
			scene.add_child(visual_probe)
			visual_probe.global_transform = shop_bay.global_transform
			await physics_frame
			var sightline := PhysicsRayQueryParameters3D.create(
				Vector3(-32.0, 1.62, -0.9), Vector3(-26.0, 1.62, -0.9))
			sightline.collision_mask = 1 << 24
			var shop_bay_hit := space.intersect_ray(sightline)
			check("v2_real_imported_shopbay_visual_mesh_does_not_cross_door_centreline",
				shop_bay_hit.is_empty(),
				{"hit_world_m": shop_bay_hit["position"], "source_node": shop_bay.name}
					if not shop_bay_hit.is_empty() else "clear")
			visual_probe.free()
		var camera_sphere := SphereShape3D.new()
		camera_sphere.radius = 0.16
		var camera_contacts := []
		var tested_samples := 0
		for index in range(241):
			var sample_time := float(index) * 0.25
			var should_open := sample_time >= 17.0 and sample_time < 30.0
			if bool(tour_house.call("is_door_open")) != should_open:
				tour_house.call("set_door_open", should_open)
				await physics_frame
			var pose: Dictionary = world.call("_tour_pose_at", sample_time)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = camera_sphere
			query.transform = Transform3D(Basis.IDENTITY, pose["position"])
			var overlaps := space.intersect_shape(query, 5)
			if not overlaps.is_empty():
				camera_contacts.append({"time_s": sample_time, "eye": pose["position"],
					"colliders": overlaps.map(func(c: Dictionary) -> String:
						return String(c.get("collider", null).name))})
			tested_samples += 1
		check("v2_camera_60s_all_241_quarter_second_samples_clear_of_solid_collision",
			tested_samples == 241 and camera_contacts.is_empty(), camera_contacts)
		check("v2_staged_real_door_recloses_after_camera_exits",
			not bool(tour_house.call("is_door_open")))
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
