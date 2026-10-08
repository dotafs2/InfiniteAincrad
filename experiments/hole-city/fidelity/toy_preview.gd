extends Node3D
## Visual-only original Toy Town miniature; no physics, city or gameplay builder.
const Shapes = preload("res://fidelity/toy_shapes.gd")
const CourtShapes = preload("res://fidelity/toy_guard_shapes.gd")
const Surface = preload("res://fidelity/food_surface.gd")
const ROTATION_SPEED := 0.10
const SURFACE_Y := 0.105
static var surface_meshes: Dictionary = {}
static var garden_material: StandardMaterial3D
var preview: Node3D
var toy_piece_count := 0
var court_piece_count := 0
var layer_counts: Dictionary = {}

func build_preview() -> void:
	if is_instance_valid(preview): preview.free()
	preview = Node3D.new(); preview.name = "BubbleToyTownMiniature"; add_child(preview)
	toy_piece_count = 0
	court_piece_count = 0
	layer_counts = {"foreground": 0, "midground": 0, "background": 0}
	base_and_lanes()
	# Different toy silhouettes and roof heights remain readable as a tiny card.
	toy("grand_castle", Vector2(-1.70, -2.30), 0.93, 2, "background", -0.07)
	toy("toy_castle", Vector2(3.72, -2.10), 0.82, 0, "background", 0.13)
	toy("bubble_turret", Vector2(-5.15, -2.78), 0.84, 4, "background", -0.15)
	toy("block_tower", Vector2(0.58, -3.97), 0.76, 1, "background", 0.07)
	toy("toy_arch", Vector2(-3.24, 0.18), 1.22, 3, "midground", -0.18)
	toy("bubble_turret", Vector2(3.83, 0.49), 0.76, 1, "midground", 0.14)
	toy("block_tower", Vector2(0.85, -0.42), 0.85, 0, "midground", -0.09)
	toy("toy_train", Vector2(-0.25, 2.22), 1.00, 4, "foreground", -0.47)
	toy("toy_car", Vector2(4.72, 2.68), 0.79, 1, "foreground", 0.20)
	toy("toy_duck", Vector2(-4.95, 3.83), 0.75, 3, "foreground", -0.39)
	for index in 6:
		var at := Vector2(-3.35 + (index % 3) * 0.72, 3.66 + floori(index / 3.0) * 0.66)
		toy("toy_block", at, 0.51 + float(index % 2) * 0.035, index, "foreground", index * 0.17)
	for index in 7:
		var at := Vector2(-5.4 + index * 1.70, 1.17 + sin(index * 1.8) * 0.43)
		toy("toy_ball", at, 0.41 + float(index % 3) * 0.035, index + 1, "foreground", index * 0.43)
	toy("toy_duck", Vector2(3.72, 4.40), 0.48, 0, "foreground", 0.23)
	toy("toy_block", Vector2(0.12, 4.30), 0.60, 2, "foreground", -0.13)
	toy("toy_car", Vector2(-5.28, -0.46), 0.55, 2, "foreground", -0.80)
	# Pure mesh palace folk make the miniature lively; no actor AI is spawned.
	court_visual("guard", Vector2(-2.49, -0.93), 0.54, 0, -0.14)
	court_visual("sentry", Vector2(-0.78, -0.94), 0.54, 4, 0.16)
	court_visual("king", Vector2(3.41, -0.54), 0.57, 2, -0.11)
	court_visual("courier", Vector2(1.05, 3.08), 0.47, 1, -0.42)
	court_visual("jester", Vector2(-3.55, 2.91), 0.47, 0, 0.27)
	court_visual("royal_drone", Vector2(4.86, 0.25), 0.46, 3, 0.19, 0.24)

func _process(delta: float) -> void:
	if is_instance_valid(preview): preview.rotation.y += delta * ROTATION_SPEED

func toy(kind: String, at: Vector2, scale_factor: float, palette: int, layer: String, yaw: float = 0.0) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = Shapes.mesh_for(kind, palette)
	visual.material_override = Shapes.material()
	var extent: Vector3 = Shapes.natural_size_for(kind) * scale_factor
	# Keep Blender's authored proportions, with deliberate tabletop footprints.
	var architectural_widths: Dictionary = {"grand_castle": 3.9, "toy_castle": 3.3,
		"bubble_turret": 1.45, "block_tower": 1.8, "toy_arch": 1.7}
	if architectural_widths.has(kind):
		extent *= float(architectural_widths[kind]) / Shapes.natural_size_for(kind).x
	visual.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(extent), Vector3(at.x, SURFACE_Y, at.y))
	visual.name = "%s_%02d" % [kind, toy_piece_count]
	visual.set_meta("toy_kind", kind); visual.set_meta("palette", posmod(palette, Shapes.PALETTES.size()))
	visual.set_meta("preview_layer", layer)
	preview.add_child(visual)
	toy_piece_count += 1; layer_counts[layer] = int(layer_counts[layer]) + 1
	return visual

func court_visual(role: String, at: Vector2, scale_factor: float, palette: int, yaw: float = 0.0, hover: float = 0.0) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = CourtShapes.mesh_for(role, palette)
	visual.material_override = CourtShapes.material()
	var extent: Vector3 = CourtShapes.natural_size_for(role) * scale_factor
	visual.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(extent), Vector3(at.x, SURFACE_Y + hover, at.y))
	visual.name = "Court_%s_%02d" % [role, court_piece_count]
	visual.set_meta("toy_npc_role", role); visual.set_meta("court_role", role)
	visual.set_meta("preview_court", true)
	preview.add_child(visual); court_piece_count += 1
	return visual

func surface(size: Vector3, at: Vector3, palette: int, yaw: float = 0.0) -> MeshInstance3D:
	var key: String = "%s/%d" % [size, posmod(palette, Shapes.PALETTES.size())]
	if not surface_meshes.has(key):
		var source: ArrayMesh = Surface.rounded_box(size)
		var arrays: Array = source.surface_get_arrays(0)
		var colors := PackedColorArray()
		colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
		colors.fill(Shapes.PALETTES[posmod(palette, Shapes.PALETTES.size())])
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		surface_meshes[key] = mesh
	var visual := MeshInstance3D.new()
	visual.mesh = surface_meshes[key]
	visual.material_override = Shapes.material()
	visual.transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, size.y * 0.5, 0))
	visual.set_meta("preview_surface", true)
	preview.add_child(visual)
	return visual

func base_and_lanes() -> void:
	# A garden diorama uses the same green lawns and warm paths as the world.
	var base := surface(Vector3(14.0, 0.32, 12.0), Vector3(0, -0.32, 0), 0)
	base.name = "GardenDiorama"
	paint_ground(base, Color("487d30"))
	var lawn := surface(Vector3(13.82, 0.08, 11.82), Vector3(0, 0, 0), 3)
	lawn.name = "RoyalGarden"
	paint_ground(lawn, Color("74b23d"))
	lane(Vector2(-6.2, 1.60), Vector2(6.2, 1.60), 1.20)
	lane(Vector2(-1.55, 4.90), Vector2(-1.55, -4.60), 0.82)
	lane(Vector2(2.32, -4.62), Vector2(2.32, 0.98), 0.67)

func lane(from: Vector2, to: Vector2, width: float) -> void:
	var direction: Vector2 = to - from; var center: Vector2 = (from + to) * 0.5
	var visual: MeshInstance3D = surface(Vector3(direction.length(), 0.018, width),
		Vector3(center.x, 0.085, center.y), 4, -atan2(direction.y, direction.x))
	visual.name = "RoyalGardenPath"; visual.set_meta("preview_lane", true)
	paint_ground(visual, Color("dfc58a"))

func paint_ground(visual: MeshInstance3D, tint: Color) -> void:
	if garden_material == null:
		garden_material = StandardMaterial3D.new()
		garden_material.vertex_color_use_as_albedo = true
		garden_material.roughness = .88
	var arrays: Array = visual.mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(tint)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	visual.mesh = mesh
	visual.material_override = garden_material
