@tool
extends EditorScenePostImport
## Keep mobile vertex palettes active after cold import in the actual package.
func _post_import(scene:Node) -> Object:
	apply_palette(scene)
	return scene

func apply_palette(node:Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(i)
			if arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty():
				var material=node.get_active_material(i)
				if material is StandardMaterial3D:
					material.vertex_color_use_as_albedo=true
					material.vertex_color_is_srgb=false
	for child in node.get_children():apply_palette(child)
