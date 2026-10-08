extends RefCounted
## Original soft-vinyl palace folk, facing +Z. Geometry-only, safe off-tree.
## Unit AABB centered x/z, bottom y=0; natural_size_for preserves proportions.
const Shapes = preload("res://fidelity/toy_shapes.gd")
const KINDS := ["guard", "sentry", "king", "courier", "courtier", "jester", "royal_drone",
	"queen", "captain", "drummer", "toymaker", "balloon_vendor", "page", "herald",
	"knight", "steward", "princess"]
const BEHAVIOR_GROUPS := {"guard": "guard", "sentry": "sentry", "king": "king",
	"courier": "courier", "courtier": "courtier", "jester": "jester", "royal_drone": "royal_drone",
	"queen": "king", "captain": "guard", "drummer": "jester", "toymaker": "courtier",
	"balloon_vendor": "courtier", "page": "courier", "herald": "courier", "knight": "guard",
	"steward": "king", "princess": "king"}
static var mesh_cache: Dictionary = {}
static var natural_sizes: Dictionary = {}
static var collision_cache: Dictionary = {}

static func material() -> ShaderMaterial:
	return Shapes.material()

static func mesh_for(role: String, palette: int = 0) -> ArrayMesh:
	var canonical: String = role if role in KINDS else "courtier"
	var variant: int = posmod(palette, Shapes.PALETTES.size())
	var key: String = "%s/%d" % [canonical, variant]
	if mesh_cache.has(key): return mesh_cache[key]
	var colors: Array[Color] = [Shapes.PALETTES[variant], Shapes.PALETTES[(variant + 2) % Shapes.PALETTES.size()],
		Shapes.PALETTES[(variant + 3) % Shapes.PALETTES.size()], Shapes.CREAM, Shapes.INK]
	var data := {"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array(), "parts": []}
	if canonical == "royal_drone": _drone(data, colors)
	else:
		_humanoid(data, canonical, colors)
		_costume(data, canonical, colors)
	var vertices: PackedVector3Array = data.vertices
	var normals: PackedVector3Array = data.normals
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: bounds = bounds.expand(vertex)
	var source_size: Vector3 = bounds.size
	var origin := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	for index in vertices.size():
		vertices[index] = (vertices[index] - origin) / source_size
		normals[index] = (normals[index] * source_size).normalized()
	if not natural_sizes.has(canonical): natural_sizes[canonical] = source_size
	if not collision_cache.has(canonical): collision_cache[canonical] = vertices.duplicate()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = data.colors; arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	mesh.set_meta("toy_npc_role", canonical); mesh.set_meta("court_role", canonical)
	mesh.set_meta("behavior_group", behavior_group_for(canonical))
	mesh.set_meta("toy_palette", variant)
	mesh.set_meta("natural_size", source_size); mesh.set_meta("model_forward", Vector3.BACK)
	mesh_cache[key] = mesh
	return mesh

static func natural_size_for(role: String) -> Vector3:
	var canonical: String = role if role in KINDS else "courtier"
	if not natural_sizes.has(canonical): mesh_for(canonical)
	return natural_sizes[canonical]

static func behavior_group_for(role: String) -> String:
	return str(BEHAVIOR_GROUPS.get(role, "courtier"))

static func collision_parts_for(role: String) -> Array[PackedVector3Array]:
	var canonical: String = role if role in KINDS else "courtier"
	if not collision_cache.has(canonical): mesh_for(canonical)
	var result: Array[PackedVector3Array] = []
	result.append(collision_cache[canonical].duplicate())
	return result

static func _ball(data: Dictionary, at: Vector3, radii: Vector3, tint: Color, mass: bool = false) -> void:
	Shapes._sphere(data, at, radii, tint, mass)

static func _box(data: Dictionary, at: Vector3, size: Vector3, tint: Color) -> void:
	Shapes._box(data, at, size, tint, false)

static func _disc(data: Dictionary, at: Vector3, radius: float, height: float, tint: Color, angles: Vector3 = Vector3.ZERO) -> void:
	Shapes._disc(data, at, radius, height, tint, false, angles)

static func _rod(data: Dictionary, from: Vector3, to: Vector3, radius: float, tint: Color) -> void:
	var direction: Vector3 = to - from
	var up: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK
	var back: Vector3 = reference.cross(up).normalized()
	var right: Vector3 = up.cross(back).normalized()
	_disc(data, (from + to) * 0.5, radius, direction.length(), tint, Basis(right, up, back).get_euler())

static func _humanoid(data: Dictionary, role: String, colors: Array[Color]) -> void:
	# Padded boots/legs, rounded torso and mittens; a family of dolls, not uniforms
	# copied from a real palace or an existing collectible-toy brand.
	_box(data, Vector3(0, 0.65, 0), Vector3(0.49, 0.66, 0.32), colors[0])
	_ball(data, Vector3(0, 1.19, 0.015), Vector3(0.255, 0.265, 0.235), Shapes.CREAM, true)
	for side in [-1.0, 1.0]:
		_ball(data, Vector3(side * 0.13, 0.29, 0), Vector3(0.082, 0.21, 0.090), colors[1])
		_ball(data, Vector3(side * 0.13, 0.081, 0.035), Vector3(0.12, 0.081, 0.17), colors[1])
		var arm_y: float = 0.75 if role != "jester" or side < 0 else 0.99
		var hand_y: float = 0.56 if role != "jester" or side < 0 else 1.15
		_ball(data, Vector3(side * 0.305, arm_y, 0.02), Vector3(0.083, 0.22, 0.085), colors[0])
		_ball(data, Vector3(side * 0.31, hand_y, 0.07), Vector3(0.087, 0.10, 0.085), Shapes.CREAM)
		_ball(data, Vector3(side * 0.096, 1.218, 0.234), Vector3(0.033, 0.047, 0.022), Shapes.INK)
	_ball(data, Vector3(0, 1.12, 0.247), Vector3(0.069, 0.025, 0.018), colors[1])
	_ball(data, Vector3(0, 0.73, 0.168), Vector3(0.070, 0.077, 0.023), colors[2])

static func _helmet(data: Dictionary, colors: Array[Color], sentry: bool) -> void:
	_ball(data, Vector3(0, 1.395, -0.040), Vector3(0.277, 0.21, 0.253), colors[1])
	_disc(data, Vector3(0, 1.36, -0.025), 0.29, 0.075, colors[2])
	if sentry:
		for side in [-1.0, 1.0]:
			_ball(data, Vector3(side * 0.255, 1.25, -0.035), Vector3(0.075, 0.13, 0.11), colors[1])
	else:
		_ball(data, Vector3(0, 1.61, -0.040), Vector3(0.080, 0.10, 0.080), colors[2])

static func _shield_and_staff(data: Dictionary, colors: Array[Color], sentry: bool) -> void:
	var width: float = 0.23 if sentry else 0.205
	_ball(data, Vector3(-0.43, 0.61, 0.16), Vector3(width, 0.29, 0.070), colors[1])
	_ball(data, Vector3(-0.43, 0.64, 0.227), Vector3(0.10, 0.12, 0.027), colors[2])
	_disc(data, Vector3(0.50, 0.78, 0.11), 0.039, 1.27, colors[2])
	_ball(data, Vector3(0.50, 1.46, 0.11), Vector3(0.11, 0.13, 0.11), colors[1])

static func _crown(data: Dictionary, at: Vector3, scale: float = 1.0) -> void:
	_disc(data, at, 0.263 * scale, 0.13 * scale, Shapes.PALETTES[3])
	for index in 3:
		var x: float = (index - 1) * 0.145 * scale
		_ball(data, at + Vector3(x, (0.12 + (0.04 if index == 1 else 0.0)) * scale, 0),
			Vector3(0.088, 0.12, 0.095) * scale, Shapes.PALETTES[3])

static func _costume(data: Dictionary, role: String, colors: Array[Color]) -> void:
	match role:
		"guard", "sentry":
			_helmet(data, colors, role == "sentry")
			_shield_and_staff(data, colors, role == "sentry")
			_box(data, Vector3(0, 0.49, 0.012), Vector3(0.51, 0.07, 0.34), colors[2])
		"king":
			_box(data, Vector3(0, 0.66, -0.20), Vector3(0.61, 0.84, 0.16), colors[1])
			_ball(data, Vector3(0, 0.37, 0), Vector3(0.29, 0.18, 0.22), colors[0])
			_crown(data, Vector3(0, 1.46, 0))
			_disc(data, Vector3(0.42, 0.77, 0.15), 0.042, 0.57, colors[2])
			_ball(data, Vector3(0.42, 1.09, 0.15), Vector3(0.12, 0.12, 0.12), colors[1])
		"courier":
			_box(data, Vector3(0, 0.76, -0.20), Vector3(0.37, 0.46, 0.27), colors[1])
			_ball(data, Vector3(-0.28, 0.58, 0.16), Vector3(0.14, 0.17, 0.10), colors[2])
			_box(data, Vector3(0.21, 0.62, 0.25), Vector3(0.29, 0.23, 0.10), Shapes.CREAM)
			_ball(data, Vector3(0, 1.40, -0.045), Vector3(0.265, 0.125, 0.24), colors[1])
			_disc(data, Vector3(0, 1.365, 0.03), 0.265, 0.065, colors[2])
		"courtier":
			_box(data, Vector3(0, 0.60, 0.03), Vector3(0.56, 0.67, 0.31), colors[1])
			for index in 3:
				_ball(data, Vector3((index - 1) * 0.17, 1.435, -0.025), Vector3(0.13, 0.13, 0.16), colors[2])
			_ball(data, Vector3(0, 0.88, 0.18), Vector3(0.22, 0.062, 0.055), Shapes.CREAM)
		"jester":
			for index in 3:
				var x: float = (index - 1) * 0.18
				var height: float = 1.47 + (0.06 if index == 1 else 0.0)
				_ball(data, Vector3(x, height, -0.03), Vector3(0.14, 0.16, 0.18), colors[index])
				_ball(data, Vector3(x * 1.3, height + 0.125, 0.035), Vector3.ONE * 0.068, Shapes.CREAM)
			_disc(data, Vector3(0, 0.96, 0.01), 0.265, 0.075, colors[1])
			for index in 2:
				_ball(data, Vector3(0, 0.54 + index * 0.14, 0.185), Vector3(0.048, 0.051, 0.027), colors[2])
		"queen":
			# A broad padded dress, looped hair and scalloped fan distinguish the queen.
			_ball(data, Vector3(0, 0.38, 0), Vector3(0.40, 0.32, 0.30), colors[0])
			_box(data, Vector3(0, 0.69, -0.205), Vector3(0.59, 0.86, 0.15), colors[2])
			for side in [-1.0, 1.0]:
				_ball(data, Vector3(side * 0.245, 1.29, -0.05), Vector3(0.11, 0.21, 0.12), colors[1])
			_crown(data, Vector3(0, 1.51, 0), 1.05)
			_rod(data, Vector3(0.31, 0.60, 0.08), Vector3(0.46, 0.80, 0.16), 0.025, colors[2])
			for index in 3:
				_ball(data, Vector3(0.37 + index * 0.09, 0.90 + (0.035 if index == 1 else 0.0), 0.17),
					Vector3(0.075, 0.12, 0.05), colors[1])
		"captain":
			_helmet(data, colors, false)
			_shield_and_staff(data, colors, false)
			_box(data, Vector3(0, 0.68, -0.22), Vector3(0.60, 0.84, 0.14), colors[2])
			for side in [-1.0, 1.0]:
				_ball(data, Vector3(side * 0.30, 0.93, 0), Vector3(0.13, 0.095, 0.115), colors[2])
		"drummer":
			_ball(data, Vector3(0, 1.41, -0.03), Vector3(0.27, 0.13, 0.245), colors[1])
			_disc(data, Vector3(0, 1.36, 0), 0.265, 0.065, colors[2])
			_disc(data, Vector3(0, 0.57, 0.29), 0.275, 0.27, colors[1], Vector3(PI * 0.5, 0, 0))
			_disc(data, Vector3(0, 0.57, 0.44), 0.242, 0.035, Shapes.CREAM, Vector3(PI * 0.5, 0, 0))
			_box(data, Vector3(0, 0.76, 0.171), Vector3(0.065, 0.47, 0.05), colors[2])
			for side in [-1.0, 1.0]:
				_rod(data, Vector3(side * 0.31, 0.58, 0.12), Vector3(side * 0.23, 0.89, 0.34), 0.027, colors[2])
				_ball(data, Vector3(side * 0.23, 0.89, 0.34), Vector3.ONE * 0.075, Shapes.CREAM)
		"toymaker":
			# The apron, little molded block and soft hammer remain one intact figure.
			_box(data, Vector3(0, 0.57, 0.182), Vector3(0.42, 0.48, 0.05), colors[1])
			_ball(data, Vector3(0, 1.41, -0.035), Vector3(0.27, 0.13, 0.245), colors[2])
			_box(data, Vector3(-0.34, 0.57, 0.23), Vector3(0.20, 0.21, 0.18), colors[2])
			_ball(data, Vector3(-0.34, 0.60, 0.328), Vector3(0.047, 0.047, 0.016), Shapes.CREAM)
			_rod(data, Vector3(0.31, 0.55, 0.10), Vector3(0.43, 0.85, 0.17), 0.032, colors[2])
			_box(data, Vector3(0.43, 0.87, 0.17), Vector3(0.23, 0.13, 0.13), colors[1])
		"balloon_vendor":
			_ball(data, Vector3(0, 1.40, -0.035), Vector3(0.26, 0.12, 0.24), colors[1])
			_disc(data, Vector3(0, 1.35, 0), 0.265, 0.065, colors[2])
			_ball(data, Vector3(-0.29, 0.55, 0.15), Vector3(0.13, 0.16, 0.10), colors[1])
			for index in 3:
				var top := Vector3(0.22 + index * 0.19, 1.90 + (0.23 if index == 1 else 0.0), -0.015)
				_rod(data, Vector3(0.31, 0.64, 0.09), top - Vector3(0, 0.25, 0), 0.017, colors[2])
				_ball(data, top, Vector3(0.20, 0.28, 0.18), colors[index], true)
		"page":
			_ball(data, Vector3(0, 1.40, -0.04), Vector3(0.265, 0.12, 0.24), colors[1])
			_disc(data, Vector3(0, 1.35, 0.025), 0.263, 0.065, colors[2])
			_ball(data, Vector3(0, 0.91, 0.15), Vector3(0.235, 0.064, 0.07), Shapes.CREAM)
			_box(data, Vector3(-0.28, 0.55, 0.16), Vector3(0.24, 0.28, 0.15), colors[1])
			_disc(data, Vector3(0.31, 0.58, 0.18), 0.075, 0.39, Shapes.CREAM, Vector3(0, 0, PI * 0.5))
			for side in [-1.0, 1.0]:
				_ball(data, Vector3(0.31 + side * 0.19, 0.58, 0.18), Vector3.ONE * 0.079, colors[2])
		"herald":
			_ball(data, Vector3(0, 1.40, -0.04), Vector3(0.265, 0.12, 0.24), colors[1])
			_disc(data, Vector3(0, 1.35, 0.025), 0.263, 0.065, colors[2])
			_rod(data, Vector3(0.46, 0.13, 0.12), Vector3(0.46, 1.70, 0.12), 0.036, colors[2])
			_box(data, Vector3(0.62, 1.38, 0.12), Vector3(0.35, 0.44, 0.075), colors[1])
			_ball(data, Vector3(0.62, 1.39, 0.174), Vector3(0.075, 0.11, 0.023), colors[2])
			_ball(data, Vector3(0.46, 1.72, 0.12), Vector3.ONE * 0.07, Shapes.CREAM)
			_ball(data, Vector3(0, 0.94, 0.06), Vector3(0.25, 0.055, 0.16), colors[2])
		"knight":
			_ball(data, Vector3(0, 1.38, -0.01), Vector3(0.30, 0.23, 0.27), colors[1])
			_disc(data, Vector3(0, 1.26, -0.01), 0.30, 0.13, colors[2])
			_box(data, Vector3(0, 1.23, 0.264), Vector3(0.40, 0.08, 0.065), Shapes.INK)
			_ball(data, Vector3(-0.43, 0.61, 0.17), Vector3(0.24, 0.31, 0.07), colors[1])
			_ball(data, Vector3(-0.43, 0.64, 0.238), Vector3(0.11, 0.13, 0.028), colors[2])
			_disc(data, Vector3(0.49, 0.61, 0.14), 0.035, 0.18, colors[2])
			_box(data, Vector3(0.49, 0.99, 0.14), Vector3(0.083, 0.65, 0.085), Shapes.CREAM)
			_ball(data, Vector3(0.49, 0.52, 0.14), Vector3.ONE * 0.064, colors[1])
		"steward":
			_ball(data, Vector3(0, 1.42, -0.04), Vector3(0.27, 0.12, 0.24), colors[1])
			_ball(data, Vector3(0, 0.92, 0.12), Vector3(0.245, 0.065, 0.095), Shapes.CREAM)
			_box(data, Vector3(0, 0.62, 0.27), Vector3(0.42, 0.35, 0.17), colors[1])
			_box(data, Vector3(0.015, 0.62, 0.367), Vector3(0.31, 0.26, 0.04), Shapes.CREAM)
			for side in [-1.0, 1.0]:
				_ball(data, Vector3(side * 0.14, 0.88, 0.213), Vector3.ONE * 0.043, colors[2])
		"princess":
			_ball(data, Vector3(0, 0.40, 0), Vector3(0.34, 0.27, 0.27), colors[1])
			for side in [-1.0, 1.0]:
				_ball(data, Vector3(side * 0.27, 1.34, -0.045), Vector3(0.12, 0.12, 0.13), colors[2])
			_disc(data, Vector3(0, 1.465, -0.015), 0.24, 0.07, Shapes.PALETTES[3])
			for index in 3:
				_ball(data, Vector3((index - 1) * 0.13, 1.535 + (0.045 if index == 1 else 0.0), -0.015),
					Vector3(0.068, 0.084, 0.075), Shapes.PALETTES[3])
			_rod(data, Vector3(0.31, 0.58, 0.08), Vector3(0.46, 1.03, 0.16), 0.026, colors[2])
			for side in [-1.0, 1.0]:
				_ball(data, Vector3(0.46 + side * 0.047, 1.075, 0.16), Vector3(0.06, 0.072, 0.06), colors[0])

static func _drone(data: Dictionary, colors: Array[Color]) -> void:
	_ball(data, Vector3(0, 0.44, 0), Vector3(0.34, 0.30, 0.30), colors[0], true)
	_disc(data, Vector3(0, 0.39, 0), 0.35, 0.14, colors[1])
	for side in [-1.0, 1.0]:
		for back in [-1.0, 1.0]:
			_ball(data, Vector3(side * 0.28, 0.38, back * 0.22), Vector3(0.22, 0.055, 0.07), colors[2])
			_ball(data, Vector3(side * 0.43, 0.37, back * 0.23), Vector3(0.13, 0.10, 0.16), colors[1])
	for side in [-1.0, 1.0]:
		_ball(data, Vector3(side * 0.10, 0.47, 0.284), Vector3(0.041, 0.051, 0.025), Shapes.INK)
	_ball(data, Vector3(0, 0.38, 0.309), Vector3(0.073, 0.026, 0.022), Shapes.CREAM)
	_crown(data, Vector3(0, 0.77, 0), 0.68)
