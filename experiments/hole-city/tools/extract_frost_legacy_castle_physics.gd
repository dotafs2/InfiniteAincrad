extends SceneTree
## One-time, headless extraction of the pre-redesign Frost physics contract.
## Run only against the preserved five visual payloads; no game/save is loaded.
const SOURCES := {
	"toy_castle": "c24654a622051fede307d3181d8d7c4aa80d7782f7e5bccc4a48645e60e9a743",
	"grand_castle": "29038ac9435d677c34f241d3c252e9d9d551d19785d5e1007ee073f2cf0aca9d",
	"bubble_turret": "410f467c36edbcfe439a16cb6ec5e51fb13f52d03baae3dc0d86d2206c7d7c6f",
	"toy_arch": "1b9916dd6596a76b99ca344a5d239a9a3af612a9f2d142246f2d76f4afeb1c46",
	"block_tower": "7b05733cd4683a41568f7d757aacf505552ae117ddf1e2a0ca72bafdb7c46d06",
}
const PROVIDER_SHA := "a7218bb3eb43dbc599af6aefa0ef2c43d373029fb61a64c9aeedede9b5999bb5"
const PLAN_SHA := "cf5c1ea74ba23b6b1a90733df40bd84a9f6aaf6a9b78e8355badc7d096d86dc3"

func _initialize() -> void:
	run.call_deferred()

func vector_row(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func points_sha256(points: PackedVector3Array) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(points.to_byte_array())
	return context.finish().hex_encode()

func run() -> void:
	var source := ""
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-source="): source = argument.trim_prefix("--legacy-source=")
		if argument.begins_with("--out="): output = argument.trim_prefix("--out=")
	assert(not source.is_empty() and not output.is_empty(), "Provide --legacy-source and --out")
	assert(not FileAccess.file_exists(output), "Preserve previous extraction evidence")
	var assets := {}
	for kind: String in SOURCES:
		var path := source.path_join(kind + ".json")
		assert(FileAccess.get_sha256(path) == SOURCES[kind], "Unexpected historical source: " + kind)
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var vertices := PackedVector3Array()
		for row: Array in payload.vertices: vertices.append(Vector3(row[0], row[1], row[2]))
		var indices := PackedInt32Array()
		for index in payload.indices: indices.append(int(index))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# These are the exact same engine arguments used by the historical ToyCity.
		var compact: ConvexPolygonShape3D = mesh.create_convex_shape(true, true)
		var hull := []
		for point in compact.points: hull.append(vector_row(point))
		var horizontal := []
		var seen := {}
		for point in vertices:
			var at := Vector2(point.x, point.z)
			if seen.has(at): continue
			seen[at] = true
			horizontal.append([at.x, at.y])
		var bounds := mesh.get_aabb()
		assets[kind] = {
			"source_payload_sha256": SOURCES[kind],
			"source_geometry_sha256": payload.source_geometry_sha256,
			"aabb": {"position": vector_row(bounds.position), "size": vector_row(bounds.size)},
			"horizontal_vertices": horizontal,
			"rim_hull": hull,
			"rim_hull_f32_sha256": points_sha256(compact.points),
			"collision_parts": payload.collision_parts,
		}
	var result := {
		"schema": 1,
		"name": "Frozen pre-royal-redesign Frost castle physics",
		"purpose": "Frost-only geometry-derived admission, rim sampling and compound collision; no render geometry",
		"coordinates": "Godot Y-up; normalized x/z centered, bottom y=0; full-precision JSON round-trips Vector3 floats",
		"source_provider_sha256": PROVIDER_SHA,
		"source_plan_sha256": PLAN_SHA,
		"extraction_engine": Engine.get_version_info(),
		"extractor_sha256": FileAccess.get_sha256("res://tools/extract_frost_legacy_castle_physics.gd"),
		"assets": assets,
	}
	assert(DirAccess.make_dir_recursive_absolute(output.get_base_dir()) == OK)
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(result, "", false, true) + "\n")
	file.close()
	print("FROST_LEGACY_EXTRACTION " + JSON.stringify({"path": output, "sha256": FileAccess.get_sha256(output), "kinds": assets.keys(), "bytes": FileAccess.get_file_as_bytes(output).size()}))
	quit()
