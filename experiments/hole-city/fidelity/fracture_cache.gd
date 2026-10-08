extends Resource
## Precut original exterior geometry; no runtime triangle clipping.
@export var meshes:Array[ArrayMesh]=[]
@export var cells:Array[AABB]=[]
@export var exterior_vertex_counts:Array[int]=[]
var _exterior_meshes:Array[ArrayMesh]=[]

func exterior_mesh(index:int)->ArrayMesh:
	if index<0 or index>=meshes.size() or index>=exterior_vertex_counts.size():return null
	var count:int=exterior_vertex_counts[index]
	if count<3 or count%3!=0 or meshes[index]==null or meshes[index].get_surface_count()!=1:return null
	if _exterior_meshes.size()!=meshes.size():_exterior_meshes.resize(meshes.size())
	if _exterior_meshes[index]!=null:return _exterior_meshes[index]
	var source:Array=meshes[index].surface_get_arrays(0)
	if source[Mesh.ARRAY_VERTEX].size()<count:return null
	if source[Mesh.ARRAY_VERTEX].size()==count:
		_exterior_meshes[index]=meshes[index]
		return meshes[index]
	# Older bakes append full rectangular cell caps. Those span empty rooms
	# and roof gaps, so separating the pieces reveals invented wall panels.
	# Retain only clipped triangles from the original building, with their
	# original normals, colors and UVs. The shared resource builds this once.
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:
		if source[attribute]!=null:arrays[attribute]=source[attribute].slice(0,count)
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_exterior_meshes[index]=result
	return result
