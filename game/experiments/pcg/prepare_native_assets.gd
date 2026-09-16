extends SceneTree
## Save plugin-generated meshes once, so scatter instances do not regenerate trees.
const TreeGenerator = preload("res://addons/ez-tree-godot-port/ez_tree.gd")
const OUTPUT := "res://assets/floor1/pcg_native/"

func _initialize() -> void:
	_prepare.call_deferred()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var records: Array = []
	for index in 2:
		var generator := TreeGenerator.new()
		generator.rng_seed = 91627 + index * 6
		generator.branch_length = PackedFloat32Array([6.8, 3.8, 3.1, 1.5]) if index == 0 else PackedFloat32Array([5.5, 2.3, 1.8, 1.0])
		generator.branch_angle = PackedFloat32Array([0, 68, 53, 35])
		generator.branch_children = PackedInt32Array([8, 5, 3, 0])
		generator.branch_start = PackedFloat32Array([0, .50, .08, .12])
		generator.leaf_count = 14
		generator.leaf_size = .85 if index == 0 else .66
		generator.leaf_size_variance = .35
		generator.leaf_tint = Color8(230, 236, 207)
		generator.wind_strength = Vector3(.10, 0, .10)
		root.add_child(generator)
		var tree_mesh: ArrayMesh = generator.get_tree_mesh()
		var asset := Node3D.new()
		asset.name = "EZTreePBR"
		var visual := MeshInstance3D.new()
		visual.mesh = tree_mesh
		asset.add_child(visual)
		visual.owner = asset
		var trunk := StaticBody3D.new()
		trunk.collision_layer = 1
		trunk.collision_mask = 0
		asset.add_child(trunk)
		trunk.owner = asset
		var collision := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.height = 4.0
		cylinder.radius = .47
		collision.shape = cylinder
		collision.position.y = 2.0
		trunk.add_child(collision)
		collision.owner = asset
		var id := "ez-oak" if index == 0 else "ez-small-oak"
		_save(asset, id)
		var triangles := 0
		for surface in tree_mesh.get_surface_count(): triangles += tree_mesh.surface_get_array_index_len(surface) / 3
		records.append({"asset":id,"triangles":triangles,"bark":"original albedo + normal + roughness maps", "leaves":"original textured lit wind shader; receives shadows"})
		asset.free()
		generator.free()
	var grass := MeshInstance3D.new()
	grass.name = "SimpleGrassTextured"
	grass.mesh = load("res://addons/simplegrasstextured/default_mesh.tres")
	var material: ShaderMaterial = load("res://addons/simplegrasstextured/materials/grass.tres").duplicate()
	material.set_shader_parameter("texture_albedo", load("res://addons/simplegrasstextured/textures/grassbushcc008.png"))
	material.set_shader_parameter("interactive_mode", false)
	material.set_shader_parameter("light_mode", 1)
	material.set_shader_parameter("normal_scale", 0.0)
	material.set_shader_parameter("scale_h", .46)
	material.set_shader_parameter("scale_w", .78)
	material.set_shader_parameter("albedo", Color("b8cb98"))
	material.set_shader_parameter("roughness", .88)
	material.set_shader_parameter("specular", .22)
	material.set_shader_parameter("optimization_by_distance", false)
	grass.material_override = material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_save(grass, "simple-grass")
	grass.free()
	records.append({"asset":"simple-grass","triangles":4,"mesh_shader_texture":"SimpleGrassTextured 2.1.0 originals", "placement_and_multimesh":"ProtonScatter", "interactive_trampling":false})
	var file := FileAccess.open(OUTPUT + "provenance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	print("PCG_NATIVE_ASSETS ", JSON.stringify(records))
	quit()

func _save(node: Node3D, id: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, OUTPUT + id + ".tscn") == OK)
