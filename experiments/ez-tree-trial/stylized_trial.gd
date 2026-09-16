extends "res://trial.gd"
## Reuses EZ-Tree skeletons and FaRu85's foliage shader. No new tree generator.
const ToonFoliage = preload("res://stylized/foliage_toon.gdshader")
const LeafMask = preload("res://stylized/third_party/godot_foliage/Textures/Leaves001-04.png")
var style_meshes: Array[ArrayMesh] = []

func _build_specimens() -> void:
	var source: Node3D = TreeGenerator.new()
	source.set("rng_seed", 91627)
	source.set("branch_length", PackedFloat32Array([6.8, 3.8, 3.1, 1.5]))
	source.set("branch_angle", PackedFloat32Array([0, 68, 53, 35]))
	source.set("branch_children", PackedInt32Array([8, 5, 3, 0]))
	source.set("branch_start", PackedFloat32Array([0, 0.50, 0.08, 0.12]))
	source.set("leaf_count", 22)
	source.set("leaf_size", 0.70)
	source.set("leaf_size_variance", 0.45)
	source.set("leaf_tint", Color8(230, 236, 191))
	# Static comparison uses identical geometry and lighting without different wind phases.
	source.set("wind_enabled", not capture)
	add_child(source)
	var original: ArrayMesh = source.get_tree_mesh()
	style_meshes.append(original)
	style_meshes.append(_make_stylized_mesh(original))
	source.queue_free()
	var names := ["调整前 · 原始材质", "调整后 · 叶簇与柔和色块"]
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output.path_join("trees"))
	for i in 2:
		var specimen := MeshInstance3D.new()
		specimen.name = "Original" if i == 0 else "Stylized"
		specimen.mesh = style_meshes[i]
		specimen.extra_cull_margin = 2.5
		var tris := 0
		for surface in specimen.mesh.get_surface_count(): tris += specimen.mesh.surface_get_array_index_len(surface) / 3
		descriptions.append({"id":"original" if i == 0 else "stylized", "label":names[i], "triangles":tris})
		add_child(specimen)
		if not output.is_empty():
			var packed := PackedScene.new()
			assert(packed.pack(specimen) == OK)
			assert(ResourceSaver.save(packed, output.path_join("trees/" + str(descriptions[i].id) + ".tscn")) == OK)
		specimen.position.x = -10.0 if i == 0 else 10.0
		specimens.append(specimen)
		print("EZTREE_STYLE ", JSON.stringify(descriptions[i]))

func _make_stylized_mesh(original: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	# Exact same branch vertices/indices as the generated source tree.
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original.surface_get_arrays(0))
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("927452")
	bark.roughness = 1.0
	bark.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	bark.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.surface_set_material(0, bark)
	var leaves: Array = original.surface_get_arrays(1)
	var source_vertices: PackedVector3Array = leaves[Mesh.ARRAY_VERTEX]
	var source_uvs: PackedVector2Array = leaves[Mesh.ARRAY_TEX_UV]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	var original_bounds := original.get_aabb()
	var canopy_center := Vector3(original_bounds.get_center().x, 10.3, original_bounds.get_center().z)
	# Native EZTree emits two four-vertex cards per leaf. Retain one card from
	# every fourth leaf. The existing shader expands each card from its center;
	# collapse to that center so native quad rotation cannot shear the billboard.
	for leaf in range(0, source_vertices.size() / 8, 4):
		var base := leaf * 8
		var anchor := (source_vertices[base] + source_vertices[base + 2]) * 0.5
		var card_size := source_vertices[base].distance_to(source_vertices[base + 1]) * 2.3
		var offset := vertices.size()
		for corner in 4:
			vertices.append(anchor)
			var smooth_normal := (anchor - canopy_center) * Vector3(1, 0.65, 1)
			normals.append(smooth_normal.normalized())
			uv.append(source_uvs[base + corner])
			uv2.append(Vector2(fposmod(leaf * 0.618033989, 1.0), card_size))
		indices.append_array(PackedInt32Array([offset + 2, offset + 1, offset, offset + 3, offset + 2, offset]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var foliage := ShaderMaterial.new()
	foliage.shader = ToonFoliage
	foliage.set_shader_parameter("Alpha", LeafMask)
	foliage.set_shader_parameter("TopColor", Color("709654"))
	foliage.set_shader_parameter("BottomColor", Color("315c49"))
	foliage.set_shader_parameter("FresnelColor", Color("a0b974"))
	foliage.set_shader_parameter("ColorRamp", 0.065)
	foliage.set_shader_parameter("MeshScale", -0.5)
	foliage.set_shader_parameter("DistanceScale", 0.0)
	# Upstream also changes alpha by distance independently of DistanceScale.
	# Keep the same leaf silhouette throughout this comparison.
	foliage.set_shader_parameter("DistanceStart", 1000.0)
	foliage.set_shader_parameter("DistanceScaleRange", 100.0)
	foliage.set_shader_parameter("FresnelStrength", 0.035)
	foliage.set_shader_parameter("FresnelBlend", 0.5)
	foliage.set_shader_parameter("WindStrength", 0.0 if capture else 0.5)
	foliage.set_shader_parameter("WindScale", 4.0)
	foliage.set_shader_parameter("WiggleStrength", 0.0)
	result.surface_set_material(1, foliage)
	return result

func _show_overview() -> void:
	selected = -1
	heading.visible = true
	detail.visible = true
	for tree in specimens: tree.visible = true
	camera.size = 27.0
	camera.position = Vector3(0, 15.0, 58.0)
	camera.look_at(Vector3(0, 7.8, 0))
	heading.text = "EZ-Tree 风格化对照 | Godot 实渲"
	detail.text = "左：原始写实材质    右：简化叶簇 / 柔和明暗    ·    同一枝干、同灯光、同机位"

func _show_tree(index: int, closeup := false) -> void:
	if index >= specimens.size(): return
	selected = index
	heading.visible = not closeup
	detail.visible = not closeup
	for i in specimens.size(): specimens[i].visible = i == index
	var tree := specimens[index]
	var bounds := style_meshes[0].get_aabb()
	var target := tree.position + bounds.get_center()
	if closeup:
		target.y = bounds.position.y + bounds.size.y * 0.73
		camera.size = 5.0
	else: camera.size = 20.5
	camera.position = target + Vector3(sin(orbit) * cos(elevation), sin(elevation), cos(orbit) * cos(elevation)) * 42.0
	camera.look_at(target)
	heading.text = str(descriptions[index].label)
	detail.text = "%s 三角面 · EZ-Tree 原生枝干 / 风格化材质适配" % descriptions[index].triangles

func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await _save_frame("01-before-after.png")
	for i in 2:
		_show_tree(i)
		await _save_frame("02-original.png" if i == 0 else "03-stylized.png")
		_show_tree(i, true)
		await _save_frame("04-original-close.png" if i == 0 else "05-stylized-close.png")
	orbit = 1.3
	_show_tree(1)
	await _save_frame("06-stylized-side.png")
	var a: Array = style_meshes[0].surface_get_arrays(0)
	var b: Array = style_meshes[1].surface_get_arrays(0)
	assert(a[Mesh.ARRAY_VERTEX] == b[Mesh.ARRAY_VERTEX])
	assert(a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX])
	var report := {"specimens":descriptions, "identical_branch_geometry":true,
		"same_lighting_and_camera":true,"wind_paused_for_comparison":true,
		"leaf_processing":"retain center of every fourth native leaf; adapt to upstream billboard layout; card width 2.3 times original; bend shading normals",
		"foliage_shader":"FaRu85/Godot-Foliage MIT, adapted for two-sided toon/cutout",
		"leaf_mask":"FaRu85 Leaves001-04.png CC0", "paid_calls":0,
		"leaf_shadow_reception":false,"ground_shadow_casting":true,
		"town_placement":false}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	get_tree().quit()
