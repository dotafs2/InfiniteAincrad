extends RefCounted
## Original Blender-authored fairytale architecture. No scene/physics side effects.
## Unit AABB: x/z centered, bottom y=0; world callers scale by an explicit extent.
const ToySurface = preload("res://fidelity/toy_surface.gdshader")
const KINDS := ["toy_castle", "grand_castle", "bubble_turret", "toy_arch", "block_tower"]
const ROOF_PALETTES := [Color("20a8a5"), Color("df4163"), Color("8251bd"),
	Color("d99a31"), Color("377dc6")]
const ASSET_ROOT := "res://assets/fairytale_castles/"
static var payloads: Dictionary = {}
static var mesh_cache: Dictionary = {}
static var collision_cache: Dictionary = {}
static var manifest: Dictionary = {}
static var shared_material: ShaderMaterial

static func material() -> ShaderMaterial:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = ToySurface
		shared_material.set_shader_parameter("reveal_occluder", 0.0)
	return shared_material

static func building_material() -> ShaderMaterial:
	var result: ShaderMaterial = material().duplicate()
	result.set_shader_parameter("reveal_occluder", 0.0)
	return result

static func asset_manifest() -> Dictionary:
	if manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT + "manifest.json"))
		assert(parsed is Dictionary, "Generated Blender fairytale manifest is required")
		manifest = parsed
	return manifest.duplicate(true)

static func _payload(kind: String) -> Dictionary:
	assert(kind in KINDS, "Unknown authored fairytale kind")
	if payloads.has(kind): return payloads[kind]
	var path: String = ASSET_ROOT + kind + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Generated Blender fairytale mesh is required")
	var data: Dictionary = parsed
	assert(data.kind == kind and data.authoring_tool == "Blender")
	var proof: Dictionary = asset_manifest()
	assert(FileAccess.get_sha256(path) == str(proof.assets[kind].sha256), "Authored fairytale payload drift")
	payloads[kind] = data
	return data

static func mesh_for(kind: String, palette: int = 0) -> ArrayMesh:
	var variant: int = posmod(palette, ROOF_PALETTES.size())
	var key: String = "%s/%d" % [kind, variant]
	if mesh_cache.has(key): return mesh_cache[key]
	var data: Dictionary = _payload(kind)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for index in data.vertices.size():
		var point: Array = data.vertices[index]
		var normal: Array = data.normals[index]
		vertices.append(Vector3(point[0], point[1], point[2]))
		normals.append(Vector3(normal[0], normal[1], normal[2]).normalized())
		var color: Array = data.colors[index]
		var tint := Color(color[0], color[1], color[2], 1.0)
		var role: String = data.role_names[int(data.color_roles[index])]
		if role == "roof": tint = ROOF_PALETTES[variant]
		elif role == "roof_dark": tint = ROOF_PALETTES[variant].darkened(0.28)
		elif role == "banner": tint = ROOF_PALETTES[(variant + 1) % ROOF_PALETTES.size()]
		colors.append(tint)
	for index in data.indices: indices.append(int(index))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	mesh.set_meta("toy_kind", kind)
	mesh.set_meta("toy_palette", variant)
	mesh.set_meta("fairytale_authored", true)
	mesh.set_meta("authoring_tool", "Blender")
	mesh.set_meta("natural_size", natural_size_for(kind))
	mesh.set_meta("source_geometry_sha256", str(data.source_geometry_sha256))
	var proof: Dictionary = asset_manifest()
	mesh.set_meta("source_asset_sha256", str(proof.assets[kind].sha256))
	mesh.set_meta("source_blend_sha256", str(proof.source_blend_sha256))
	mesh.set_meta("generator_sha256", str(proof.generator_sha256))
	mesh_cache[key] = mesh
	return mesh

static func natural_size_for(kind: String) -> Vector3:
	var data: Dictionary = _payload(kind)
	var values: Array = data.natural_size
	return Vector3(values[0], values[1], values[2])

static func collision_parts_for(kind: String) -> Array[PackedVector3Array]:
	if not collision_cache.has(kind):
		var data: Dictionary = _payload(kind)
		var parts: Array[PackedVector3Array] = []
		for part in data.collision_parts:
			var points := PackedVector3Array()
			for point in part.points: points.append(Vector3(point[0], point[1], point[2]))
			parts.append(points)
		collision_cache[kind] = parts
	var result: Array[PackedVector3Array] = []
	for points in collision_cache[kind]: result.append(points.duplicate())
	return result
