extends SceneTree
func _initialize()->void:
	var root:Node3D=load("res://assets/trains/sushi_salmon.glb").instantiate()
	for view in root.find_children("*","MeshInstance3D",true,false):
		var surface=view.mesh.surface_get_material(0)
		var active=view.get_active_material(0)
		print("TRAIN_MATERIAL ",var_to_str({"node":view.name,"surface":surface,"active":active,"override":view.material_override,"surface_override":view.get_surface_override_material(0),"surface_vertex":surface.vertex_color_use_as_albedo if surface!=null else null,"active_vertex":active.vertex_color_use_as_albedo if active!=null else null,"active_albedo":active.albedo_color if active!=null else null}))
	root.free();quit()
