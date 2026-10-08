extends SceneTree
## Dynamic imported-geometry and cosmetic-lifecycle checks. The three isolated
## swallow probes deliberately grant growth and reposition the hole; ordinary
## progression is tested separately by glacier_frozen_gameplay_capture.gd.
const Game = preload("res://fidelity/game.gd")
var game: Node3D
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var mesh_cache: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func mesh_nodes(owner: Node) -> Array[Node]:
	return owner.find_children("*", "MeshInstance3D", true, false)

func bounds_in(owner: Node3D, subject: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for node in mesh_nodes(subject):
		if node.mesh == null:
			continue
		var pose: Transform3D = owner.global_transform.affine_inverse() * node.global_transform
		var measured: AABB = pose * node.mesh.get_aabb()
		result = result.merge(measured) if found else measured
		found = true
	return result

func point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 100000.0), roundi(point.y * 100000.0), roundi(point.z * 100000.0)]

func topology(mesh: Mesh) -> Dictionary:
	var id := mesh.get_instance_id()
	if mesh_cache.has(id):
		return mesh_cache[id]
	var edges := {}
	var triangles := 0
	var degenerate := 0
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var length := indices.size() if not indices.is_empty() else vertices.size()
		for start in range(0, length - 2, 3):
			var points: Array[Vector3] = []
			for corner in 3:
				points.append(vertices[indices[start + corner] if not indices.is_empty() else start + corner])
			triangles += 1
			if (points[1] - points[0]).cross(points[2] - points[0]).length_squared() < 1.0e-16:
				degenerate += 1
				continue
			for corner in 3:
				var a := point_key(points[corner])
				var b := point_key(points[(corner + 1) % 3])
				var key := a + "/" + b if a < b else b + "/" + a
				edges[key] = int(edges.get(key, 0)) + 1
	var boundary := 0
	var overused := 0
	for count in edges.values():
		if int(count) == 1:
			boundary += 1
		elif int(count) > 2:
			overused += 1
	var result := {"triangles": triangles, "boundary_edges": boundary, "overused_edges": overused, "degenerate_triangles": degenerate}
	mesh_cache[id] = result
	return result

func imported_asset(body: Node3D) -> Node3D:
	for node in body.find_children("BlenderAuthored_*", "Node3D", true, false):
		return node
	return null

func render_counters() -> Dictionary:
	return {"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"gpu_available": DisplayServer.get_name() != "headless"}

func probe_swallow(target: Node3D) -> Dictionary:
	var body_name := str(target.name)
	var points := int(target.points)
	var visuals: Array[WeakRef] = []
	for node in mesh_nodes(target):
		visuals.append(weakref(node))
	var handles: int = target.static_instances.size()
	var batch_pools: Dictionary = {}
	for handle in target.static_instances:
		var pool: RefCounted = handle.pool.get_ref()
		if pool == null:
			continue
		var pool_id: int = pool.get_instance_id()
		if not batch_pools.has(pool_id):
			batch_pools[pool_id] = {"ref": weakref(pool), "before": pool.handles.size(), "removed": 0}
		batch_pools[pool_id].removed += 1
	var needed_level: int = game.player.level_for_radius(float(target.footprint) * 1.08)
	var needed_score: int = game.player.level_start_for(needed_level + 1)
	game.player.award(maxi(0, needed_score - int(game.player.score)))
	game.player.global_position = Vector3(target.global_position.x, 0.0, target.global_position.z)
	var before_score: int = game.player.score
	var before_eaten: int = game.eaten
	target.collision_layer = 1
	target.collision_mask = 1
	var admitted: bool = target.begin_swallow(game.player)
	check(admitted, body_name + ": the real shared admission path accepts the suitably grown hole")
	check(target.static_instances.is_empty(), body_name + ": admission retires every stationary batch handle")
	for row in batch_pools.values():
		var pool: RefCounted = row.ref.get_ref()
		check(pool != null and pool.handles.size() == int(row.before) - int(row.removed),
			body_name + ": the actual shared batch loses only this food's instances")
	for _frame in 360:
		game.ground.sync()
		await physics_frame
		if not is_instance_valid(target):
			break
	var consumed := not is_instance_valid(target)
	if is_instance_valid(target):
		consumed = bool(target.consumed)
	check(consumed, body_name + ": whole edible body settles by real gravity")
	check(int(game.player.score) - before_score == points, body_name + ": points are awarded once")
	check(int(game.eaten) - before_eaten == 1, body_name + ": shared eaten counter increments once")
	await process_frame
	var alive_visuals := 0
	for reference in visuals:
		if reference.get_ref() != null:
			alive_visuals += 1
	check(alive_visuals == 0, body_name + ": every owned mesh disappears with collection, including snow and ice accents")
	return {"body": body_name, "points": points, "admitted": admitted, "consumed": consumed,
		"owned_visuals": visuals.size(), "remaining_owned_visuals": alive_visuals, "retired_batch_handles": handles,
		"score_delta": int(game.player.score) - before_score, "eaten_delta": int(game.eaten) - before_eaten}

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(540, 1174)
	root.content_scale_size = root.size
	game = Game.new()
	game.selected_map = "frost"
	game.test_progress_path = "/tmp/hole-feast-glacier-review-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	game.start_level()
	game.begin_play()
	for _frame in 4:
		await physics_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	metrics.initial_render = render_counters()
	metrics.population = game.city.population_summary()
	check(game.round_duration() == 90.0, "Frostlight keeps its ninety-second initial round")
	check(game.score_coin_reward(1000) == 100 and game.score_coin_reward(9) == 0, "Accepted score/10 coin economy remains")
	check(game.SKIN_DEFS.size() == 200, "The entire two-hundred-skin catalog remains available")
	var species: Dictionary = metrics.population.get("frost_species", {})
	check(species.size() >= 10, "At least ten polar/expedition species remain present")
	for id in ["polar_bear", "penguin", "scientist", "icebreaker", "ice_rock"]:
		check(species.has(id), "The preserved ecosystem includes " + id)
	var topology_rows: Array[Dictionary] = []
	var examined_meshes := {}
	var count := 0
	var worst_floor := 0.0
	var worst_width_ratio := 0.0
	var variants := {}
	var targets: Dictionary = {}
	var batched_candidates: Dictionary = {}
	for body in game.city.foods:
		if not is_instance_valid(body):
			continue
		var kind := str(body.get_meta("frost_species", ""))
		if kind not in ["glacier_iceberg", "ice_rock", "ice_chip"]:
			continue
		var asset := imported_asset(body)
		check(asset != null, str(body.name) + ": glacier and ice rock use imported authored geometry")
		if asset == null:
			continue
		count += 1
		variants[str(body.get_meta("frost_variant", kind))] = true
		var measured := bounds_in(body, asset)
		var floor_error := absf(measured.position.y + float(body.half_size.y))
		var width_ratio := maxf(measured.size.x / maxf(.01, float(body.half_size.x) * 2.0), measured.size.z / maxf(.01, float(body.half_size.z) * 2.0))
		worst_floor = maxf(worst_floor, floor_error)
		worst_width_ratio = maxf(worst_width_ratio, width_ratio)
		check(floor_error < .065, str(body.name) + ": measured imported bottom rests on collider floor")
		check(width_ratio <= 1.10 and width_ratio >= .65, str(body.name) + ": measured imported width visibly matches its edible owner")
		check(measured.end.y <= float(body.half_size.y) + .10, str(body.name) + ": no rendered summit projects beyond the edible height envelope")
		for node in mesh_nodes(asset):
			if node.mesh == null or examined_meshes.has(node.mesh.get_instance_id()):
				continue
			examined_meshes[node.mesh.get_instance_id()] = true
			var row := topology(node.mesh)
			row["node"] = str(node.name)
			topology_rows.append(row)
			check(int(row.boundary_edges) == 0, str(node.name) + ": position-welded imported triangle edges are closed")
			check(int(row.overused_edges) == 0, str(node.name) + ": imported edges do not have non-manifold overlaps")
		if not is_instance_valid(body.support_parent) and body.supported_toys.is_empty():
			var candidate_handles: int = body.static_instances.size()
			if candidate_handles > 0:
				batched_candidates[kind] = int(batched_candidates.get(kind, 0)) + 1
			if not targets.has(kind) or candidate_handles > int(targets[kind].static_instances.size()):
				targets[kind] = body
	check(count > 0, "The actual game contains imported edible ice")
	check(variants.size() >= 3, "At least three distinct authored ice variants support silhouette variety")
	# Grounded ridge snow is allowed. Tall free-floating caps from the old
	# per-food dressing pass are not: edible accents must follow food owners.
	var floating_caps := 0
	if is_instance_valid(game.city.decor_root):
		for node in game.city.decor_root.find_children("SnowCap_*", "MeshInstance3D", true, false):
			if node.global_position.y > 2.0:
				floating_caps += 1
	check(floating_caps == 0, "No tall per-food snow caps remain detached under world decoration")
	metrics.imported = {"instances": count, "variants": variants.keys(), "unique_meshes": topology_rows,
		"worst_floor_error": worst_floor, "worst_visible_width_ratio": worst_width_ratio, "floating_caps": floating_caps, "batched_candidates": batched_candidates}
	# Isolate three admission/lifecycle probes without presenting this fixture
	# as natural progression. All unchanged normal play is captured separately.
	game.set_physics_process(false)
	game.city.set_process(false)
	if is_instance_valid(game.city.court):
		game.city.court.set_process(false)
		game.city.court.set_physics_process(false)
	for hole in game.holes:
		hole.set_physics_process(false)
	for body in game.city.foods:
		if is_instance_valid(body) and body not in targets.values():
			body.collision_layer = 0
			body.collision_mask = 0
			body.set_physics_process(false)
			body.freeze = true
	metrics.lifecycle = []
	for kind in ["ice_rock", "glacier_iceberg", "ice_chip"]:
		check(targets.has(kind), "An unsupported " + kind + " is available for a lifecycle probe")
		if targets.has(kind):
			if int(batched_candidates.get(kind, 0)) > 0:
				check(targets[kind].static_instances.size() > 0, kind + ": lifecycle probe exercises an actual batched owner")
			metrics.lifecycle.append(await probe_swallow(targets[kind]))
	var result := {"checks": checks, "failures": failures, "metrics": metrics,
		"scope": "Dynamic source-mesh bounds/topology and explicitly isolated real physics lifecycle. Probe growth/position are staged. Ordinary 90-second progression is separate. No phone, production save or SDK claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print("GLACIER_FROZEN_REVIEW " + JSON.stringify(result))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
