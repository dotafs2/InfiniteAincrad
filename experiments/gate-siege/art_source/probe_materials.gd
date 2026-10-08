extends SceneTree
func _initialize():
 for kind in ["infantry","zombie","gunner"]:
  var scene=(load("res://assets/models/"+kind+".glb") as PackedScene).instantiate()
  inspect(scene,kind)
  scene.free()
 quit()
func inspect(n:Node,kind:String):
 if n is MeshInstance3D:
  print("PROBE ",kind," mesh=",n.mesh," override=",n.material_override)
  for s in range(n.mesh.get_surface_count()):
   var a=n.mesh.surface_get_arrays(s)
   var mat=n.get_active_material(s)
   print("surface ",s," active=",mat," override=",n.get_surface_override_material(s)," mesh_mat=",n.mesh.surface_get_material(s)," colors=",a[Mesh.ARRAY_COLOR].size() if a[Mesh.ARRAY_COLOR]!=null else -1)
   if mat is BaseMaterial3D:print("vertex=",mat.vertex_color_use_as_albedo," albedo=",mat.albedo_color," srgb=",mat.vertex_color_is_srgb)
   if a[Mesh.ARRAY_COLOR]!=null:print("first color=",a[Mesh.ARRAY_COLOR][0])
 for c in n.get_children():inspect(c,kind)
