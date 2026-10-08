extends RefCounted
## Frozen Frost-only physics inputs from the pre-royal-redesign castle meshes.
## No legacy render mesh, normals, colors, or source Blender scene is retained.
const KINDS := ["toy_castle", "grand_castle", "bubble_turret", "toy_arch", "block_tower"]
const DATA_PATH := "res://assets/frost_legacy_castle_physics/legacy.json"
const DATA_SHA256 := "e8896a669b60ce8258fe7387ec305a6ec8840b665abd67505d0b626d0cbc7c84"
static var _data: Dictionary = {}
static var _geometry: Dictionary = {}
static var _collisions: Dictionary = {}
static var _placeholder: ArrayMesh

static func source_data() -> Dictionary:
	return _source().duplicate(true)

static func _source() -> Dictionary:
	if _data.is_empty():
		assert(FileAccess.get_sha256(DATA_PATH) == DATA_SHA256, "Frozen Frost physics payload drift")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		assert(parsed is Dictionary and int(parsed.get("schema", 0)) == 1)
		_data = parsed
	return _data

static func geometry_for(kind: String) -> Dictionary:
	assert(kind in KINDS)
	if not _geometry.has(kind):
		var row: Dictionary = _source().assets[kind]
		var vertices := PackedVector3Array()
		# Only x/z participate in admission. Keep every distinct original float32
		# pair so any nonuniform placement size produces the identical maximum.
		for at: Array in row.horizontal_vertices: vertices.append(Vector3(at[0], 0.0, at[1]))
		var hull := PackedVector3Array()
		for at: Array in row.rim_hull: hull.append(Vector3(at[0], at[1], at[2]))
		var position: Array = row.aabb.position
		var size: Array = row.aabb.size
		_geometry[kind] = {
			"vertices": vertices, "hull": hull,
			"aabb": AABB(Vector3(position[0], position[1], position[2]), Vector3(size[0], size[1], size[2])),
		}
	return _geometry[kind].duplicate(true)

static func collision_parts_for(kind: String) -> Array[PackedVector3Array]:
	assert(kind in KINDS)
	if not _collisions.has(kind):
		var parts: Array[PackedVector3Array] = []
		for part: Dictionary in _source().assets[kind].collision_parts:
			var points := PackedVector3Array()
			for at: Array in part.points: points.append(Vector3(at[0], at[1], at[2]))
			parts.append(points)
		_collisions[kind] = parts
	var result: Array[PackedVector3Array] = []
	for points: PackedVector3Array in _collisions[kind]: result.append(points.duplicate())
	return result

static func placeholder_mesh() -> ArrayMesh:
	if _placeholder == null:
		# ToyCity briefly creates visual owners and batches during its synchronous
		# build. Frost removes these owners before its first rendered frame and
		# installs its existing ice meshes. The proxy is never a physics input.
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		_placeholder = ArrayMesh.new()
		_placeholder.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cube.surface_get_arrays(0))
		_placeholder.set_meta("frost_temporary_visual", true)
	return _placeholder
