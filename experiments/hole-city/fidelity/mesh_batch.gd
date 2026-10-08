extends RefCounted
## Combine rigid primitive decorations without deleting geometry or lowering LOD.
static func combine(root:Node3D,exclude:Array=[],override_material:Material=null,encode_roughness:=false)->void:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	var merged:Array[MeshInstance3D]=[]
	for child in root.find_children("*","MeshInstance3D",true,false):
		var node:MeshInstance3D=child
		if node in exclude or node.mesh==null or node.skin!=null:continue
		# A partially merged mesh cannot be removed without losing its other surfaces.
		if override_material==null:
			var supported:=true
			for surface_index in node.mesh.get_surface_count():
				var source:Material=node.material_override if node.material_override else node.mesh.surface_get_material(surface_index)
				if source is ShaderMaterial:supported=false
			if not supported:continue
		var transform:Transform3D=root.global_transform.affine_inverse()*node.global_transform
		for s in node.mesh.get_surface_count():
			var mat:Material=node.material_override if node.material_override else node.mesh.surface_get_material(s)
			if mat is ShaderMaterial and override_material==null:continue
			var tint:=Color.WHITE
			var vertex_color:=true
			if mat is StandardMaterial3D:
				tint=mat.albedo_color
				vertex_color=mat.vertex_color_use_as_albedo
			var arrays:=node.mesh.surface_get_arrays(s)
			var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var cs:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var base:int=vertices.size()
			for i in vs.size():
				vertices.append(transform*vs[i])
				normals.append((transform.basis.inverse().transposed()*ns[i]).normalized())
				var color:Color=tint*(cs[i] if vertex_color and i<cs.size() else Color.WHITE)
				if encode_roughness and mat is StandardMaterial3D:color.a=mat.roughness
				colors.append(color)
			if ids.is_empty():
				for i in vs.size():indices.append(base+i)
			else:
				for i in ids:indices.append(base+i)
			if node not in merged:merged.append(node)
	if merged.size()<2:return
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=MeshInstance3D.new()
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.mesh=mesh
	if override_material:result.material_override=override_material
	else:
		var mat:=StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo=true
		mat.roughness=.86
		result.material_override=mat
	root.add_child(result)
	for node in merged:
		node.get_parent().remove_child(node)
		node.queue_free()
