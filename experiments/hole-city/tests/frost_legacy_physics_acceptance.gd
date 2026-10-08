extends SceneTree
## Exact frozen inputs and actual Frost owners, including court installations.
## Source runs additionally recompute the historical visual hull; packaged runs
## use the independently hash-pinned extraction, without shipping old art.
const Game = preload("res://fidelity/game.gd")
const Legacy = preload("res://fidelity/frost_legacy_castle_physics.gd")
const Fairytale = preload("res://fidelity/fairytale_meshes.gd")
const Growth = preload("res://fidelity/hole.gd")
const SOURCE_SHA := {
	"toy_castle": "c24654a622051fede307d3181d8d7c4aa80d7782f7e5bccc4a48645e60e9a743",
	"grand_castle": "29038ac9435d677c34f241d3c252e9d9d551d19785d5e1007ee073f2cf0aca9d",
	"bubble_turret": "410f467c36edbcfe439a16cb6ec5e51fb13f52d03baae3dc0d86d2206c7d7c6f",
	"toy_arch": "1b9916dd6596a76b99ca344a5d239a9a3af612a9f2d142246f2d76f4afeb1c46",
	"block_tower": "7b05733cd4683a41568f7d757aacf505552ae117ddf1e2a0ca72bafdb7c46d06",
}
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var data: Dictionary = {}
var game: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func vector_points(rows: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for row: Array in rows: result.append(Vector3(row[0], row[1], row[2]))
	return result

func points_sha256(points: PackedVector3Array) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(points.to_byte_array())
	return context.finish().hex_encode()

func inspect_frozen_data() -> void:
	check(FileAccess.get_sha256(Legacy.DATA_PATH) == "e8896a669b60ce8258fe7387ec305a6ec8840b665abd67505d0b626d0cbc7c84", "The shipped frozen physics bytes match the independent extraction receipt")
	data = JSON.parse_string(FileAccess.get_file_as_string(Legacy.DATA_PATH))
	check(int(data.schema) == 1 and data.assets.size() == 5, "The physics-only schema contains exactly five historical architecture kinds")
	check(FileAccess.get_file_as_bytes(Legacy.DATA_PATH).size() < 600000, "Frost isolation does not ship a duplicate visual castle catalog")
	var recomputed := 0
	for kind: String in SOURCE_SHA:
		var row: Dictionary = data.assets[kind]
		check(row.source_payload_sha256 == SOURCE_SHA[kind], kind + ": extraction names the exact preserved source")
		var geometry: Dictionary = Legacy.geometry_for(kind)
		check(points_sha256(geometry.hull) == row.rim_hull_f32_sha256, kind + ": compact rim hull round-trips in exact engine float bytes and point order")
		var pairs := {}
		for point: Vector3 in geometry.vertices: pairs[Vector2(point.x, point.z)] = true
		var raw_pairs := {}
		for point: Array in row.horizontal_vertices: raw_pairs[Vector2(point[0], point[1])] = true
		check(pairs == raw_pairs and pairs.size() == geometry.vertices.size(), kind + ": every distinct historical horizontal admission input survives")
		var collisions: Array[PackedVector3Array] = Legacy.collision_parts_for(kind)
		var same: bool = collisions.size() == row.collision_parts.size()
		for index in mini(collisions.size(), row.collision_parts.size()):
			same = same and collisions[index] == vector_points(row.collision_parts[index].points)
		check(same, kind + ": provider exposes the exact compound point sequences")
		var original: Vector3 = collisions[0][0]
		collisions[0][0] += Vector3.ONE
		check(Legacy.collision_parts_for(kind)[0][0] == original, kind + ": caller edits cannot poison frozen collision caches")
		var old_hull: PackedVector3Array = geometry.hull.duplicate()
		geometry.hull[0] += Vector3.ONE
		check(Legacy.geometry_for(kind).hull == old_hull, kind + ": caller edits cannot poison frozen admission/rim caches")
		var baseline_path := "res://build/royal-castle-20261008/baseline/assets/fairytale_castles/" + kind + ".json"
		if not FileAccess.file_exists(baseline_path): continue
		recomputed += 1
		check(FileAccess.get_sha256(baseline_path) == SOURCE_SHA[kind], kind + ": source checkout retains the immutable historical payload")
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vector_points(raw.vertices)
		var indices := PackedInt32Array()
		for index in raw.indices: indices.append(int(index))
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var compact := mesh.create_convex_shape(true, true)
		var source_pairs := {}
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: source_pairs[Vector2(point.x, point.z)] = true
		check(compact.points == old_hull and mesh.get_aabb() == Legacy.geometry_for(kind).aabb and source_pairs == raw_pairs and raw.collision_parts == row.collision_parts, kind + ": independently rebuilt old mesh reproduces frozen AABB, admission, rim and compounds")
	metrics["historical_payloads_recomputed"] = recomputed
	check(recomputed == 0 or recomputed == 5, "Historical source verification is complete when the baseline is present")

func inspect_world() -> void:
	check(Fairytale.payloads.is_empty() and Fairytale.mesh_cache.is_empty(), "Cold fixture starts without a loaded current castle catalog")
	game = Game.new()
	game.unlocked_map_ids = game.available_map_ids()
	game.selected_map = "frost"
	game.music_enabled = false
	game.sfx_enabled = false
	root.add_child(game)
	check(Fairytale.payloads.is_empty() and Fairytale.mesh_cache.is_empty(), "Selected Frost home preview uses ice assets without loading the castle catalog")
	game.start_level()
	game.set_process(false)
	game.set_physics_process(false)
	game.world.process_mode = Node.PROCESS_MODE_DISABLED
	game.audio.set_process(false)
	game.audio.music.stop()
	check(game.test_mode and game.progress_file().is_empty() and game.selected_map == "frost" and game.world.get_meta("map_id") == "frost", "An explicitly unlocked, save-free fixture constructs the actual Frost world")
	check(Fairytale.payloads.is_empty() and Fairytale.mesh_cache.is_empty(), "Cold Frost build never loads the redesigned castle render payloads")
	var expected := {}
	for index in game.city.toy_plan.size():
		var spec: Dictionary = game.city.toy_plan[index]
		if spec.kind in Legacy.KINDS: expected["Toy_%03d_%s" % [index + 1, spec.kind]] = {"kind": spec.kind, "size": spec.size, "points": spec.points}
	for row: Dictionary in game.city.court.installations:
		for index in row.parts.size():
			var body: Node3D = row.parts[index]
			var kind: String = body.get_meta("original_toy_kind", "")
			if kind in Legacy.KINDS: expected[str(body.name)] = {"kind": kind, "size": Vector3(.9, .68, .85) if index == 0 else Vector3(.60, .65, .58), "points": 2 if index == 0 else 1}
	for row: Dictionary in game.city.court.beacons:
		expected[str(row.body.name)] = {"kind": "bubble_turret", "size": Vector3(.62, 1.5, .58), "points": 2}
	var found := 0
	var supported := 0
	var issues := {"extent": [], "admission": [], "rim": [], "colliders": [], "support": [], "visual": []}
	var kinds := {}
	for body in game.city.foods:
		if not is_instance_valid(body) or not body.has_meta("original_toy_kind"): continue
		var kind: String = body.get_meta("original_toy_kind")
		if kind not in Legacy.KINDS: continue
		found += 1
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		var name := str(body.name)
		if not expected.has(name):
			issues.extent.append(name + ": unaccounted owner")
			continue
		var spec: Dictionary = expected[name]
		var size: Vector3 = spec.size
		var row: Dictionary = data.assets[kind]
		var a: Array = row.aabb.position
		var b: Array = row.aabb.size
		var bounds := AABB(Vector3(a[0], a[1], a[2]), Vector3(b[0], b[1], b[2]))
		var measured := bounds.size * size
		var center := bounds.get_center() * size
		if body.half_size != measured * .5 or body.height != measured.y or body.points != int(spec.points): issues.extent.append(name)
		var radius := 0.0
		for at: Array in row.horizontal_vertices:
			var local := Vector3(at[0], 0.0, at[1]) * size - center
			radius = maxf(radius, Vector2(local.x, local.z).length())
		if body.footprint != radius or body.get_meta("required_radius") != radius * 1.08 or int(body.get_meta("minimum_level")) != Growth.level_for_radius(radius * 1.08): issues.admission.append(name)
		var rim := PackedVector3Array()
		for at in vector_points(row.rim_hull):
			var local: Vector3 = at * size - center
			if local.y <= -measured.y * .5 + .045: rim.append(local)
		if body.rim_samples != rim: issues.rim.append(name)
		var collisions: Array = body.get_children().filter(func(node): return node is CollisionShape3D)
		var matching: bool = collisions.size() == row.collision_parts.size()
		for index in mini(collisions.size(), row.collision_parts.size()):
			var scaled := PackedVector3Array()
			for point in vector_points(row.collision_parts[index].points): scaled.append(Vector3(point.x * size.x, (point.y - .5) * size.y, point.z * size.z))
			matching = matching and collisions[index].shape is ConvexPolygonShape3D and collisions[index].shape.points == scaled
		if not matching: issues.colliders.append(name)
		if is_instance_valid(body.support_parent):
			supported += 1
			var contact: float = body.support_parent.position.y + game.city._central_support_top(body.support_parent)
			var gap: float = body.position.y + game.city._collider_bottom(body) - contact
			if not body.support_parent.supported_toys.has(body) or absf(gap - .025) > .00001: issues.support.append(name)
		if body.get_node_or_null("ToyVisual") != null or body.get_node_or_null("FrostSpeciesVisual") == null: issues.visual.append(name)
	check(found == expected.size() and found >= 180 and kinds.size() == 5, "All static and court architecture owners use the frozen provider, including every historical kind")
	for issue: String in issues: check(issues[issue].is_empty(), "Actual Frost " + issue + " matches its independently read frozen contract: " + str(issues[issue]))
	check(supported > 10, "The real Frost scene exercises the frozen architecture in supported stacks")
	var proxies_visible := false
	for node in game.city.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null and node.mesh.get_meta("frost_temporary_visual", false) and node.is_visible_in_tree(): proxies_visible = true
	for node in game.city.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh != null and node.multimesh.mesh.get_meta("frost_temporary_visual", false) and node.is_visible_in_tree(): proxies_visible = true
	check(not proxies_visible, "Synchronous ice conversion leaves no visible temporary proxy or inherited proxy batch")
	metrics["owners"] = found
	metrics["supported_owners"] = supported
	metrics["kinds"] = kinds
	metrics["world_issues"] = issues
	game.free()
	game = null

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	inspect_frozen_data()
	inspect_world()
	await process_frame
	var result := {"checks": checks, "failures": failures, "metrics": metrics, "scope": "Exact legacy physics inputs and frozen real Frost owners; no ordinary-play, phone-performance, save or native-release claim"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(result, "\t") + "\n")
	print("FROST_LEGACY_PHYSICS_ACCEPTANCE " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
