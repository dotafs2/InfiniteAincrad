extends RefCounted
## Game-facing factory: same IDs across three LODs, shared materials, static physics.

const ROOT := "res://assets/floor1/environment_kit_v2/"
const SHADER := preload("res://spatial/environment_v2.gdshader")
const IDS := ["ancient_oak", "birch_grove", "cypress_column", "stone_pine", "orchard_apple", "young_maple", "flowering_shrub", "berry_bush", "fern_patch", "meadow_grass", "wildflower_patch", "ivy_wall_panel", "reed_cluster", "mossy_fallen_log", "herb_planter", "mossy_boulder_cluster", "roadside_milestone", "timber_fence_vine", "stone_water_trough", "canvas_rest_shelter"]
static var _materials: Dictionary = {}


static func create(asset_id: String, collision: bool = false, force_lod: int = -1) -> Node3D:
	var root := Node3D.new()
	root.name = asset_id
	root.set_meta("asset_id", asset_id)
	root.set_meta("art_revision", "environment_v2")
	root.set_meta("wind_mode", "weighted_vertex")
	var tree_asset := IDS.find(asset_id.trim_prefix("F1_")) < 6
	var thresholds := [0.0, 22.0 if tree_asset else 12.0, 48.0 if tree_asset else 28.0, 0.0]
	for lod in range(3):
		if force_lod >= 0 and lod != force_lod:
			continue
		var path := ROOT + asset_id + "_LOD%d.glb" % lod
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Missing V2 component: " + path)
			continue
		var instance := packed.instantiate() as Node3D
		instance.name = "LOD%d" % lod
		root.add_child(instance)
		_prepare_meshes(instance, thresholds[lod] if force_lod < 0 else 0.0, thresholds[lod + 1] if force_lod < 0 else 0.0)
	# Match all LOD AABB centres as well as thresholds, including sparse far foliage.
	var lod_meshes := root.find_children("*", "MeshInstance3D", true, false)
	if not lod_meshes.is_empty():
		var bounds: AABB = lod_meshes[0].mesh.get_aabb()
		for mesh_node in lod_meshes: bounds = bounds.merge(mesh_node.mesh.get_aabb())
		for mesh_node in lod_meshes: mesh_node.custom_aabb = bounds
	if collision:
		_add_collision(root, asset_id.trim_prefix("F1_"))
	return root


static func _prepare_meshes(node: Node, near_distance: float, far_distance: float) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.visibility_range_begin = near_distance
		mesh_node.visibility_range_end = far_distance
		# Adjacent independent meshes must share exact boundaries. Symmetric
		# hysteresis on initially invisible siblings can leave a 2 m empty band.
		mesh_node.visibility_range_begin_margin = 0.0
		mesh_node.visibility_range_end_margin = 0.0
		mesh_node.extra_cull_margin = 0.22
		for surface in range(mesh_node.mesh.get_surface_count()):
			var source := mesh_node.mesh.surface_get_material(surface)
			var kind := str(source.resource_name).trim_prefix("F2_")
			if not _materials.has(kind):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER
				mat.set_shader_parameter("surface_kind", {"foliage": 1, "wood": 2, "fabric": 3, "water": 4}.get(kind, 0))
				_materials[kind] = mat
			mesh_node.set_surface_override_material(surface, _materials[kind])
	for child in node.get_children():
		_prepare_meshes(child, near_distance, far_distance)


static func set_review_time(seconds: float) -> void:
	for mat in _materials.values():
		mat.set_shader_parameter("review_time", seconds)


static func set_wind_strength(strength: float) -> void:
	for mat in _materials.values():
		mat.set_shader_parameter("wind_strength", clampf(strength, 0.0, 2.0))


static func _box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


static func _add_collision(root: Node3D, id: String) -> void:
	var body := StaticBody3D.new()
	body.name = "StaticStructureCollision"
	root.add_child(body)
	if IDS.find(id) < 6:
		var trunks := [[Vector3.ZERO, 0.28, 3.5]]
		if id == "ancient_oak": trunks = [[Vector3.ZERO, 0.48, 4.0]]
		if id == "birch_grove": trunks = [[Vector3(-0.55, 0, -0.22), 0.17, 3.5], [Vector3(0.56, 0, -0.17), 0.13, 3.0], [Vector3(0.08, 0, 0.5), 0.13, 2.7]]
		for trunk in trunks:
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = trunk[1]
			cylinder.height = trunk[2]
			shape.shape = cylinder
			shape.position = trunk[0] + Vector3.UP * trunk[2] * 0.5
			body.add_child(shape)
	elif id == "herb_planter": _box(body, Vector3(2.45, 0.65, 0.92), Vector3(0, 0.325, 0))
	elif id == "roadside_milestone": _box(body, Vector3(0.72, 1.92, 0.52), Vector3(0, 0.96, 0))
	elif id == "mossy_fallen_log": _box(body, Vector3(3.9, 0.72, 0.8), Vector3(0, 0.36, 0))
	elif id == "mossy_boulder_cluster": _box(body, Vector3(2.35, 0.9, 1.5), Vector3(0, 0.45, 0))
	elif id == "timber_fence_vine": _box(body, Vector3(4.6, 1.6, 0.22), Vector3(0, 0.8, 0))
	elif id == "stone_water_trough":
		for side in [-1, 1]:
			_box(body, Vector3(3.32, 0.85, 0.29), Vector3(0, 0.58, side * 0.54))
			_box(body, Vector3(0.29, 0.85, 1.08), Vector3(side * 1.51, 0.58, 0))
	elif id == "canvas_rest_shelter":
		for x in [-2.0, 2.0]:
			for z in [-1.25, 1.25]: _box(body, Vector3(0.24, 2.95, 0.24), Vector3(x, 1.475, z))
		_box(body, Vector3(3.42, 1.15, 0.60), Vector3(0, 0.575, -0.70))
	if body.get_child_count() == 0:
		root.remove_child(body)
		body.free()
