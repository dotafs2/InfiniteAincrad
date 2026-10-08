extends RefCounted
## Original pillowy vinyl toys. Cached geometry is safe to create off-tree.
## Every mesh has unit AABB, centered x/z, with bottom y=0; natural_size_for()
## preserves its authored proportions for explicit world/preview extent scaling.
const Fairytale = preload("res://fidelity/fairytale_meshes.gd")
const Surface = preload("res://fidelity/food_surface.gd")
const ToySurface = preload("res://fidelity/toy_surface.gdshader")
const KINDS := ["toy_ball", "toy_duck", "toy_car", "toy_block", "toy_train",
	"toy_arch", "bubble_turret", "block_tower", "toy_castle", "grand_castle"]
const PALETTES := [Color("9ce3cc"), Color("ffad9e"), Color("c8b4eb"),
	Color("f7df8e"), Color("9ed7ee")]
const CREAM := Color("fff4dc")
const INK := Color("435b78")
static var mesh_cache: Dictionary = {}
static var natural_sizes: Dictionary = {}
static var collision_cache: Dictionary = {}
static var primitive_cache: Dictionary = {}
static var shared_material: ShaderMaterial

static func material() -> ShaderMaterial:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = ToySurface
		shared_material.set_shader_parameter("reveal_occluder", 0.0)
	return shared_material

static func building_material() -> ShaderMaterial:
	# CPU reveal writes only this unique whole-body material, never the shared one.
	var result: ShaderMaterial = material().duplicate()
	result.set_shader_parameter("reveal_occluder", 0.0)
	return result

static func mesh_for(kind: String, palette: int = 0) -> ArrayMesh:
	if kind in Fairytale.KINDS: return Fairytale.mesh_for(kind, palette)
	var canonical: String = kind if kind in KINDS else "toy_block"
	var variant: int = posmod(palette, PALETTES.size())
	var key: String = "%s/%d" % [canonical, variant]
	if mesh_cache.has(key): return mesh_cache[key]
	var data := {"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array(), "parts": []}
	var colors: Array[Color] = [PALETTES[variant], PALETTES[(variant + 2) % PALETTES.size()],
		PALETTES[(variant + 3) % PALETTES.size()], CREAM, INK]
	_build(data, canonical, colors)
	var vertices: PackedVector3Array = data.vertices
	var normals: PackedVector3Array = data.normals
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: bounds = bounds.expand(vertex)
	var source_size: Vector3 = bounds.size
	var origin := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	for index in vertices.size():
		vertices[index] = (vertices[index] - origin) / source_size
		# The inverse-transpose of unit-AABB normalization is diag(source_size).
		normals[index] = (normals[index] * source_size).normalized()
	if not natural_sizes.has(canonical): natural_sizes[canonical] = source_size
	if not collision_cache.has(canonical):
		var parts: Array[PackedVector3Array] = []
		if canonical in ["toy_arch", "toy_castle", "grand_castle"]:
			for raw in data.parts:
				var points: PackedVector3Array = raw.duplicate()
				for index in points.size(): points[index] = (points[index] - origin) / source_size
				parts.append(points)
		else:
			parts.append(vertices.duplicate())
		collision_cache[canonical] = parts
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	mesh.set_meta("toy_kind", canonical)
	mesh.set_meta("toy_palette", variant)
	mesh.set_meta("natural_size", source_size)
	mesh_cache[key] = mesh
	return mesh

static func natural_size_for(kind: String) -> Vector3:
	if kind in Fairytale.KINDS: return Fairytale.natural_size_for(kind)
	var canonical: String = kind if kind in KINDS else "toy_block"
	if not natural_sizes.has(canonical): mesh_for(canonical)
	return natural_sizes[canonical]

static func collision_parts_for(kind: String) -> Array[PackedVector3Array]:
	if kind in Fairytale.KINDS: return Fairytale.collision_parts_for(kind)
	var canonical: String = kind if kind in KINDS else "toy_block"
	if not collision_cache.has(canonical): mesh_for(canonical)
	var result: Array[PackedVector3Array] = []
	for points in collision_cache[canonical]: result.append(points.duplicate())
	return result

static func _append(data: Dictionary, source: Mesh, pose: Transform3D, tint: Color, collision: bool = true) -> void:
	var vertices: PackedVector3Array = data.vertices
	var normals: PackedVector3Array = data.normals
	var colors: PackedColorArray = data.colors
	var indices: PackedInt32Array = data.indices
	var points := PackedVector3Array()
	var normal_basis: Basis = pose.basis.inverse().transposed()
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var base: int = vertices.size()
		for index in source_vertices.size():
			var vertex: Vector3 = pose * source_vertices[index]
			vertices.append(vertex)
			normals.append((normal_basis * source_normals[index]).normalized())
			colors.append(Color(tint.r, tint.g, tint.b, 1.0))
			if collision: points.append(vertex)
		for index in source_indices: indices.append(base + index)
	data.vertices = vertices; data.normals = normals
	data.colors = colors; data.indices = indices
	if collision: data.parts.append(points)

static func _rounded_box(size: Vector3) -> ArrayMesh:
	var samples: int = 8 if maxf(size.x, maxf(size.y, size.z)) >= 1.70 else 6
	var key: String = "box/%s/%d" % [size, samples]
	if primitive_cache.has(key): return primitive_cache[key]
	var half: Vector3 = size * 0.5
	var radius := Vector3(size.x * 0.24, size.y * 0.30, size.z * 0.24)
	var inner: Vector3 = half - radius
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	# Large masses keep 588 triangles; small molded parts use 300. The same
	# pillowy profile, bounds and smooth normals survive the detail reduction.
	for axis in 3:
		var u: int = (axis + 1) % 3; var v: int = (axis + 2) % 3
		var us: Array[float] = [-half[u], -half[u] + radius[u] * 0.133975,
			-half[u] + radius[u] * 0.5, -inner[u], inner[u],
			half[u] - radius[u] * 0.5, half[u] - radius[u] * 0.133975, half[u]]
		var vs: Array[float] = [-half[v], -half[v] + radius[v] * 0.133975,
			-half[v] + radius[v] * 0.5, -inner[v], inner[v],
			half[v] - radius[v] * 0.5, half[v] - radius[v] * 0.133975, half[v]]
		if samples == 6:
			us = [-half[u], -half[u] + radius[u] * 0.292893, -inner[u],
				inner[u], half[u] - radius[u] * 0.292893, half[u]]
			vs = [-half[v], -half[v] + radius[v] * 0.292893, -inner[v],
				inner[v], half[v] - radius[v] * 0.292893, half[v]]
		for side in [-1.0, 1.0]:
			var base: int = vertices.size()
			for j in samples:
				for i in samples:
					var p := Vector3.ZERO
					p[axis] = half[axis] * side; p[u] = us[i]; p[v] = vs[j]
					var center: Vector3 = p.clamp(-inner, inner)
					var direction: Vector3 = ((p - center) / radius).normalized()
					vertices.append(center + direction * radius)
					normals.append((direction / radius).normalized())
			for j in samples - 1:
				for i in samples - 1:
					var a: int = base + j * samples + i; var b: int = a + 1
					var c: int = a + samples; var d: int = c + 1
					indices.append_array([a, c, b, b, c, d] if side > 0 else [a, b, c, b, d, c])
	var mesh: ArrayMesh = Surface.commit(vertices, normals, indices)
	primitive_cache[key] = mesh
	return mesh

static func _sphere_mesh(detail: bool = false) -> ArrayMesh:
	var key: String = "sphere/detail" if detail else "sphere/mass"
	if primitive_cache.has(key): return primitive_cache[key]
	var vertices := PackedVector3Array([Vector3.UP]); var normals := PackedVector3Array([Vector3.UP])
	var indices := PackedInt32Array()
	var sides: int = 10 if detail else 20
	var latitudes: int = 6 if detail else 8
	# Single pole vertices and triangle fans avoid zero-area pole triangles.
	for row in range(1, latitudes):
		var latitude: float = PI * float(row) / latitudes
		for column in sides:
			var angle: float = TAU * float(column) / sides
			var normal := Vector3(sin(latitude) * cos(angle), cos(latitude), sin(latitude) * sin(angle))
			vertices.append(normal); normals.append(normal)
	for column in sides:
		indices.append_array([0, 1 + column, 1 + (column + 1) % sides])
	for row in latitudes - 2:
		for column in sides:
			var a: int = 1 + row * sides + column
			var b: int = 1 + row * sides + (column + 1) % sides
			var c: int = a + sides; var d: int = b + sides
			indices.append_array([a, c, b, b, c, d])
	var bottom: int = vertices.size()
	vertices.append(Vector3.DOWN); normals.append(Vector3.DOWN)
	for column in sides:
		indices.append_array([bottom, 1 + (latitudes - 2) * sides + (column + 1) % sides,
			1 + (latitudes - 2) * sides + column])
	var mesh: ArrayMesh = Surface.commit(vertices, normals, indices)
	primitive_cache[key] = mesh
	return mesh

static func _box(data: Dictionary, at: Vector3, size: Vector3, tint: Color, collision: bool = true, yaw: float = 0.0) -> void:
	_append(data, _rounded_box(size), Transform3D(Basis(Vector3.UP, yaw), at), tint, collision)

static func _sphere(data: Dictionary, at: Vector3, radii: Vector3, tint: Color, collision: bool = true) -> void:
	_append(data, _sphere_mesh(not collision), Transform3D(Basis.from_scale(radii), at), tint, collision)

static func _disc(data: Dictionary, at: Vector3, radius: float, height: float, tint: Color, collision: bool = true, angles: Vector3 = Vector3.ZERO) -> void:
	var sides: int = 20 if collision else (12 if radius >= 0.28 else 8)
	var key: String = "disc/%.5f/%.5f/%d" % [radius, height, sides]
	if not primitive_cache.has(key):
		primitive_cache[key] = Surface.rounded_disc(radius, height) if collision else _detail_disc(radius, height, sides)
	_append(data, primitive_cache[key], Transform3D(Basis.from_euler(angles), at), tint, collision)

static func _detail_disc(radius: float, height: float, sides: int) -> ArrayMesh:
	var half: float = height * 0.5; var bevel: float = minf(radius * 0.16, height * 0.32)
	var profile: Array[Vector2] = [Vector2(0, half), Vector2(radius - bevel, half),
		Vector2(radius, half - bevel), Vector2(radius, -half + bevel),
		Vector2(radius - bevel, -half), Vector2(0, -half)]
	var slopes: Array[Vector2] = [Vector2(0, 1), Vector2(0.707107, 0.707107),
		Vector2(1, 0), Vector2(1, 0), Vector2(0.707107, -0.707107), Vector2(0, -1)]
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in profile.size():
		for column in sides:
			var angle: float = TAU * float(column) / sides
			vertices.append(Vector3(cos(angle) * profile[row].x, profile[row].y, sin(angle) * profile[row].x))
			normals.append(Vector3(cos(angle) * slopes[row].x, slopes[row].y, sin(angle) * slopes[row].x).normalized())
	for row in profile.size() - 1:
		for column in sides:
			var a: int = row * sides + column; var b: int = row * sides + (column + 1) % sides
			var c: int = a + sides; var d: int = b + sides
			if row > 0: indices.append_array([a, c, b])
			if row < profile.size() - 2: indices.append_array([b, c, d])
	return Surface.commit(vertices, normals, indices)

static func _bubble_shaft(radius: float, height: float) -> ArrayMesh:
	var key: String = "bubble_shaft/%.5f/%.5f" % [radius, height]
	if primitive_cache.has(key): return primitive_cache[key]
	# Eight closed lathe rings keep the original 240-triangle shaft budget.
	# A rounded belly and narrowed necks read as inflated vinyl rather than stone.
	var half: float = height * 0.5
	var profile: Array[Vector2] = [Vector2(0, half), Vector2(radius * 0.82, half),
		Vector2(radius * 0.98, height * 0.42), Vector2(radius * 1.055, height * 0.19),
		Vector2(radius * 1.055, -height * 0.19), Vector2(radius * 0.98, -height * 0.42),
		Vector2(radius * 0.82, -half), Vector2(0, -half)]
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES := 20
	for row in profile.size():
		var slope := Vector2(0, 1 if row == 0 else -1)
		if row > 0 and row < profile.size() - 1:
			var tangent: Vector2 = profile[row + 1] - profile[row - 1]
			slope = Vector2(-tangent.y, tangent.x).normalized()
		for column in SIDES:
			var angle: float = TAU * float(column) / SIDES
			vertices.append(Vector3(cos(angle) * profile[row].x, profile[row].y, sin(angle) * profile[row].x))
			normals.append(Vector3(cos(angle) * slope.x, slope.y, sin(angle) * slope.x).normalized())
	for row in profile.size() - 1:
		for column in SIDES:
			var a: int = row * SIDES + column; var b: int = row * SIDES + (column + 1) % SIDES
			var c: int = a + SIDES; var d: int = b + SIDES
			if row > 0: indices.append_array([a, c, b])
			if row < profile.size() - 2: indices.append_array([b, c, d])
	var mesh: ArrayMesh = Surface.commit(vertices, normals, indices)
	primitive_cache[key] = mesh
	return mesh

static func _tube_arc(radius: float, tube: float, from: float, to: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES := 12
	for row in segments + 1:
		var angle: float = lerpf(from, to, float(row) / segments)
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		for column in SIDES:
			var around: float = TAU * float(column) / SIDES
			var normal: Vector3 = radial * cos(around) + Vector3.BACK * sin(around)
			vertices.append(radial * radius + normal * tube); normals.append(normal)
	for row in segments:
		for column in SIDES:
			var a: int = row * SIDES + column
			var b: int = row * SIDES + (column + 1) % SIDES
			var c: int = a + SIDES; var d: int = b + SIDES
			indices.append_array([a, b, c, b, d, c])
	for end in [0, 1]:
		var angle: float = from if end == 0 else to
		var cap: int = vertices.size()
		var normal := Vector3(-sin(angle), cos(angle), 0.0) * (-1.0 if end == 0 else 1.0)
		vertices.append(Vector3(cos(angle), sin(angle), 0.0) * radius); normals.append(normal)
		var base: int = 0 if end == 0 else segments * SIDES
		for column in SIDES:
			var a: int = base + column; var b: int = base + (column + 1) % SIDES
			indices.append_array([cap, b, a] if end == 0 else [cap, a, b])
	return Surface.commit(vertices, normals, indices)

static func _arch(data: Dictionary, colors: Array[Color]) -> void:
	_box(data, Vector3(-0.48, 0.38, 0), Vector3(0.34, 0.76, 0.42), colors[0])
	_box(data, Vector3(0.48, 0.38, 0), Vector3(0.34, 0.76, 0.42), colors[0])
	var pose := Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0))
	_append(data, _tube_arc(0.48, 0.20, 0.0, PI, 24), pose, colors[0], false)
	# Three crown hulls plus two legs preserve the real central opening.
	for section in 3:
		var arrays: Array = _tube_arc(0.48, 0.20, PI * section / 3.0, PI * (section + 1) / 3.0, 8).surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for index in points.size(): points[index] = pose * points[index]
		data.parts.append(points)
	_sphere(data, Vector3(0, 1.29, -0.005), Vector3(0.13, 0.10, 0.215), colors[1], false)
	for x in [-0.48, 0.48]:
		_box(data, Vector3(x, 0.08, 0), Vector3(0.43, 0.15, 0.48), colors[2], false)

static func _turret(data: Dictionary, at: Vector3, height: float, radius: float, colors: Array[Color], collision: bool = true) -> void:
	_append(data, _bubble_shaft(radius, height), Transform3D(Basis.IDENTITY, at + Vector3(0, height * 0.5, 0)), colors[0], collision)
	_disc(data, at + Vector3(0, 0.10, 0), radius * 1.10, 0.20, colors[1], false)
	_disc(data, at + Vector3(0, height - 0.05, 0), radius * 1.09, 0.15, CREAM, false)
	_sphere(data, at + Vector3(0, height + radius * 0.68, 0), Vector3(radius * 1.25, radius * 0.93, radius * 1.25), colors[1], collision)
	_sphere(data, at + Vector3(0, height + radius * 1.51, 0), Vector3(radius * 0.30, radius * 0.35, radius * 0.30), colors[2], false)
	# The oval inlay follows the new swollen front instead of hiding inside it.
	_sphere(data, at + Vector3(0, height * 0.56, radius * 1.047), Vector3(radius * 0.35, height * 0.115, 0.036), INK, false)
	_sphere(data, at + Vector3(-radius * 0.075, height * 0.595, radius * 1.130), Vector3(radius * 0.15, height * 0.06, 0.018), CREAM, false)

static func _castle(data: Dictionary, colors: Array[Color], grand: bool) -> void:
	var width: float = 2.55 if grand else 2.15
	var height: float = 1.82 if grand else 1.40
	var depth: float = 1.70 if grand else 1.55
	_box(data, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), colors[0])
	_box(data, Vector3(0, 0.12, 0), Vector3(width + 0.10, 0.23, depth + 0.10), colors[2], false)
	_box(data, Vector3(0, height - 0.06, 0), Vector3(width + 0.09, 0.19, depth + 0.07), CREAM, false)
	for side in [-1.0, 1.0]:
		for index in 4:
			var x: float = (-1.5 + index) * width * 0.255
			_box(data, Vector3(x, height + 0.20, side * depth * 0.41), Vector3(width * 0.19, 0.45, 0.40), colors[0], false)
	for side in [-1.0, 1.0]:
		for back in [-1.0, 1.0]:
			var tower_colors: Array[Color] = [colors[0], colors[1] if back < 0 else colors[2], colors[2], CREAM, INK]
			_turret(data, Vector3(side * width * 0.46, 0.03, back * depth * 0.46),
				2.27 if grand else 1.94, 0.40 if grand else 0.34, tower_colors)
	if grand:
		var center_colors: Array[Color] = [colors[1], colors[2], colors[0], CREAM, INK]
		_turret(data, Vector3(0, height - 0.05, -0.18), 1.57, 0.44, center_colors)
	# Molded soft arch door and oval inlays; these are plastic patches, not glass.
	_box(data, Vector3(0, 0.44, depth * 0.505), Vector3(0.54, 0.76, 0.11), INK, false)
	_sphere(data, Vector3(0, 0.77, depth * 0.515), Vector3(0.27, 0.27, 0.06), INK, false)
	_box(data, Vector3(-0.03, 0.41, depth * 0.54), Vector3(0.39, 0.64, 0.045), colors[1], false)
	_sphere(data, Vector3(-0.03, 0.69, depth * 0.55), Vector3(0.195, 0.20, 0.035), colors[1], false)
	_sphere(data, Vector3(0.09, 0.42, depth * 0.58), Vector3(0.045, 0.045, 0.025), CREAM, false)
	for x in [-0.57, 0.57]:
		_sphere(data, Vector3(x, height * 0.56, depth * 0.505), Vector3(0.15, 0.21, 0.04), INK, false)
		_sphere(data, Vector3(x - 0.035, height * 0.59, depth * 0.535), Vector3(0.07, 0.115, 0.021), CREAM, false)

static func _vehicle(data: Dictionary, colors: Array[Color], train: bool) -> void:
	_box(data, Vector3(0, 0.32, 0), Vector3(0.98, 0.40, 1.58 if train else 1.34), colors[0])
	if train:
		_disc(data, Vector3(0, 0.61, -0.34), 0.33, 0.88, colors[1], true, Vector3(PI * 0.5, 0, 0))
		_box(data, Vector3(0, 0.78, 0.48), Vector3(0.81, 0.79, 0.64), colors[0])
		_box(data, Vector3(0, 1.19, 0.48), Vector3(1.03, 0.19, 0.83), colors[2], false)
		_disc(data, Vector3(0, 1.03, -0.40), 0.135, 0.35, colors[2], false)
		_sphere(data, Vector3(0, 0.63, -0.81), Vector3(0.27, 0.25, 0.06), CREAM, false)
	else:
		_box(data, Vector3(0, 0.69, 0.10), Vector3(0.85, 0.57, 0.81), colors[1])
		_box(data, Vector3(0, 0.73, -0.316), Vector3(0.59, 0.27, 0.045), CREAM, false)
	for side in [-1.0, 1.0]:
		for z in ([-0.53, 0.0, 0.53] if train else [-0.41, 0.41]):
			_disc(data, Vector3(side * 0.49, 0.22, z), 0.22, 0.16, INK, false, Vector3(0, 0, PI * 0.5))
			_disc(data, Vector3(side * 0.58, 0.22, z), 0.12, 0.022, colors[2], false, Vector3(0, 0, PI * 0.5))
	for side in [-1.0, 1.0]:
		_sphere(data, Vector3(side * 0.29, 0.41, -0.69 if not train else -0.82), Vector3(0.09, 0.09, 0.04), CREAM, false)

static func _build(data: Dictionary, kind: String, colors: Array[Color]) -> void:
	match kind:
		"toy_ball":
			_sphere(data, Vector3(0, 0.48, 0), Vector3(0.48, 0.48, 0.48), colors[0])
			for direction in [Vector3(0, 0.30, 0.37), Vector3(-0.38, 0.16, -0.18), Vector3(0.34, -0.12, 0.28)]:
				_sphere(data, Vector3(0, 0.48, 0) + direction, Vector3.ONE * 0.12, colors[1], false)
		"toy_duck":
			_sphere(data, Vector3(0, 0.31, 0.08), Vector3(0.43, 0.31, 0.49), colors[0])
			_sphere(data, Vector3(0, 0.67, -0.18), Vector3(0.285, 0.29, 0.285), colors[0])
			_box(data, Vector3(0, 0.60, -0.475), Vector3(0.34, 0.14, 0.25), colors[2], false)
			_sphere(data, Vector3(0, 0.38, 0.48), Vector3(0.23, 0.18, 0.22), colors[1], false)
			for side in [-1.0, 1.0]:
				_sphere(data, Vector3(side * 0.19, 0.72, -0.392), Vector3(0.043, 0.054, 0.025), INK, false)
				_sphere(data, Vector3(side * 0.41, 0.36, 0.05), Vector3(0.07, 0.16, 0.24), colors[1], false)
		"toy_car": _vehicle(data, colors, false)
		"toy_train": _vehicle(data, colors, true)
		"toy_block":
			_box(data, Vector3(0, 0.40, 0), Vector3(0.88, 0.80, 0.88), colors[0])
			_sphere(data, Vector3(0, 0.405, 0.433), Vector3(0.235, 0.235, 0.032), colors[1], false)
			_sphere(data, Vector3(-0.055, 0.46, 0.462), Vector3(0.09, 0.095, 0.013), CREAM, false)
		"toy_arch": _arch(data, colors)
		"bubble_turret": _turret(data, Vector3.ZERO, 1.68, 0.43, colors)
		"block_tower":
			for index in 3:
				var size: float = 1.08 - index * 0.15
				_box(data, Vector3(sin(index * 1.7) * 0.07, 0.29 + index * 0.54, 0),
					Vector3(size, 0.58, size), colors[index], true, -0.08 + index * 0.12)
			_sphere(data, Vector3(0.03, 1.83, 0), Vector3(0.30, 0.30, 0.30), CREAM, false)
		"toy_castle": _castle(data, colors, false)
		"grand_castle": _castle(data, colors, true)
