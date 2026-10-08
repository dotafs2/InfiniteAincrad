extends SceneTree
## Export the real mesh/material inputs for an isolated, windowless shader QA.
const Visual=preload("res://fidelity/skin_visual.gd")
const Game=preload("res://fidelity/game.gd")
func _initialize() -> void:run.call_deferred()
func visit(node:Node,result:Array) -> void:
	if node is MeshInstance3D and node.visible:
		var mat:Material=node.material_override
		var record:={"positions":[],"uvs":[],"indices":[],"shader":"","params":{},"transparent":false}
		if mat is ShaderMaterial:
			record.shader=mat.shader.resource_path
			record.transparent=mat.shader.code.contains("ALPHA")
			for param in ["base_color","accent_color","style","spectral","lensed","splash","phase_shift","warmth"]:
				var value=mat.get_shader_parameter(param)
				if value!=null:record.params[param]=[value.r,value.g,value.b,value.a] if value is Color else value
		else:
			var color:Color=mat.albedo_color
			record.params.color=[color.r,color.g,color.b,color.a]
			record.transparent=mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var offset:int=record.positions.size()/3
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var p:Vector3=node.global_transform*vertex
				record.positions.append_array([p.x,p.y,p.z])
			for uv in arrays[Mesh.ARRAY_TEX_UV]:record.uvs.append_array([uv.x,uv.y])
			if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0:
				for index in arrays[Mesh.ARRAY_INDEX]:record.indices.append(index+offset)
			else:
				for i in arrays[Mesh.ARRAY_VERTEX].size():record.indices.append(offset+i)
		result.append(record)
	for child in node.get_children():visit(child,result)
func run() -> void:
	var result:=[]
	for definition in Game.SKIN_DEFS:
		var visual:=Visual.new();root.add_child(visual);visual.build(definition,true);visual.set_process(false);visual._process(.5)
		var meshes:=[];visit(visual,meshes)
		result.append({"id":definition.id,"name":definition.name,"meshes":meshes})
		visual.free()
	var file:=FileAccess.open("res://artifacts/skin-ui/render-inputs.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close()
	print("SKIN_RENDER_FIXTURE exported ten real mesh/material sets")
	quit()
