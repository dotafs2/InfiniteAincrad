extends SceneTree
## Export the real mesh/material inputs for an isolated, windowless shader QA.
const Visual=preload("res://fidelity/skin_visual.gd")
const Catalog=preload("res://fidelity/skin_catalog.gd")
func _initialize() -> void:run.call_deferred()
func visit(node:Node,result:Array) -> void:
	if node is MeshInstance3D and node.visible:
		var mat:Material=node.material_override
		var record:={"positions":[],"normals":[],"uvs":[],"indices":[],"shader":"","params":{},"transparent":false}
		if mat is ShaderMaterial:
			record.shader=mat.shader.resource_path
			record.transparent=mat.shader.code.contains("ALPHA")
			for param in ["base_color","accent_color","style","spectral","lensed","splash","phase_shift","warmth","core_blue"]:
				var value=mat.get_shader_parameter(param)
				if value!=null:record.params[param]=[value.r,value.g,value.b,value.a] if value is Color else value
		else:
			var color:Color=mat.albedo_color
			record.params.color=[color.r,color.g,color.b,color.a]
			record.params["roughness"]=mat.roughness
			record.params["metallic"]=mat.metallic
			record.params["specular"]=mat.metallic_specular
			record.params["unshaded"]=mat.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED
			record.transparent=mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var offset:int=record.positions.size()/3
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var p:Vector3=node.global_transform*vertex
				record.positions.append_array([p.x,p.y,p.z])
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				var n:Vector3=(node.global_transform.basis.inverse().transposed()*normal).normalized()
				record.normals.append_array([n.x,n.y,n.z])
			for uv in arrays[Mesh.ARRAY_TEX_UV]:record.uvs.append_array([uv.x,uv.y])
			if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0:
				for index in arrays[Mesh.ARRAY_INDEX]:record.indices.append(index+offset)
			else:
				for i in arrays[Mesh.ARRAY_VERTEX].size():record.indices.append(offset+i)
		result.append(record)
	for child in node.get_children():visit(child,result)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var result:=[]
	for definition in Catalog.DEFS:
		if not definition.id in ["pizza_party","frosted_cake","fox_den","bunny_burrow","rocket_port","dragon_roost"]:continue
		var visual:=Visual.new();root.add_child(visual);visual.build(definition,true);visual.set_process(false);visual._process(.5)
		var meshes:=[];visit(visual,meshes)
		result.append({"id":definition.id,"name":definition.name,"group":definition.group,"meshes":meshes,"tint":definition.tint,"accent":definition.accent})
		visual.free()
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_absolute_path():quit(2);return
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close()
	print("SKIN_RENDER_FIXTURE exported 6 current real mesh/material sets")
	quit()
