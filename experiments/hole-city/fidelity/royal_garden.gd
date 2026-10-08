extends RefCounted
## Small original edible garden assemblies, cached as two closed-solid meshes.
const KINDS := ["royal_topiary", "royal_flowerbed"]
static var meshes: Dictionary = {}

static func add_piece(out: SurfaceTool, primitive: PrimitiveMesh, at: Vector3, scale: Vector3, color: Color) -> void:
	var arrays: Array = primitive.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		out.set_color(color)
		out.set_normal((normals[index] / scale).normalized())
		out.add_vertex(vertices[index] * scale + at)

static func mesh_for(kind: String) -> ArrayMesh:
	if meshes.has(kind): return meshes[kind]
	assert(kind in KINDS)
	var out := SurfaceTool.new();out.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius=.5;cylinder.bottom_radius=.42;cylinder.height=1.0;cylinder.radial_segments=12;cylinder.rings=1
	var sphere := SphereMesh.new()
	sphere.radius=.5;sphere.height=1.0;sphere.radial_segments=12;sphere.rings=6
	var box := BoxMesh.new();box.size=Vector3.ONE
	if kind=="royal_topiary":
		add_piece(out,cylinder,Vector3(0,.115,0),Vector3(.66,.23,.66),Color("b2cbb7"))
		add_piece(out,cylinder,Vector3(0,.24,0),Vector3(.73,.055,.73),Color("edd4a0"))
		add_piece(out,cylinder,Vector3(0,.36,0),Vector3(.11,.22,.11),Color("665342"))
		add_piece(out,sphere,Vector3(0,.60,0),Vector3(1,.43,1),Color("257858"))
		add_piece(out,sphere,Vector3(0,.845,0),Vector3(.69,.31,.69),Color("479069"))
	else:
		add_piece(out,box,Vector3(0,.115,0),Vector3(1,.23,.78),Color("b2cbb7"))
		add_piece(out,box,Vector3(0,.25,0),Vector3(1,.04,.84),Color("edd4a0"))
		add_piece(out,box,Vector3(0,.285,0),Vector3(.88,.03,.7),Color("395843"))
		for i in 5:
			var x:float=(i-2)*.175
			add_piece(out,sphere,Vector3(x,.52,0),Vector3(.23,.46,.58),Color("367c56"))
			add_piece(out,sphere,Vector3(x,.82,-.09 if i%2==0 else .09),Vector3(.18,.36,.27),Color("a36acb"))
	out.index()
	var mesh: ArrayMesh=out.commit()
	mesh.set_meta("original_royal_garden",true)
	meshes[kind]=mesh
	return mesh
