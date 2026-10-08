@tool
extends EditorScenePostImport
## Godot 4.7 imports the glTF COLOR_0 array without enabling material usage.
## Retain the one-surface palette for both ordinary and MultiMesh rendering.
func _post_import(scene: Node) -> Object:
 _enable_palette(scene)
 return scene
func _enable_palette(node: Node) -> void:
 if node is MeshInstance3D:
  for surface in range(node.mesh.get_surface_count()):
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_COLOR] == null: continue
   var mat = node.get_active_material(surface)
   if mat is BaseMaterial3D:
    mat.vertex_color_use_as_albedo = true
    mat.vertex_color_is_srgb = false
 for child in node.get_children(): _enable_palette(child)
