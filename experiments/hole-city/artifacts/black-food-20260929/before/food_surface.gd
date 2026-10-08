extends RefCounted
## Bounded rounded food geometry. Outer dimensions remain the collision contract.

static func commit(vertices:PackedVector3Array,normals:PackedVector3Array,indices:PackedInt32Array)->ArrayMesh:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func rounded_box(size:Vector3)->ArrayMesh:
	var h:=size*.5
	var radius:=Vector3(minf(size.x*.14,size.z*.14),size.y*.26,minf(size.x*.14,size.z*.14))
	var inner:=h-radius
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	# Two segments per curved edge, plus large flat faces; 300 triangles per box.
	for axis in 3:
		var u:int=(axis+1)%3;var v:int=(axis+2)%3
		var us:=[-h[u],-h[u]+radius[u]*.292893,-inner[u],inner[u],h[u]-radius[u]*.292893,h[u]]
		var vs:=[-h[v],-h[v]+radius[v]*.292893,-inner[v],inner[v],h[v]-radius[v]*.292893,h[v]]
		for side in [-1.0,1.0]:
			var base:=vertices.size()
			for j in 6:
				for i in 6:
					var p:=Vector3.ZERO;p[axis]=h[axis]*side;p[u]=us[i];p[v]=vs[j]
					var center:=p.clamp(-inner,inner)
					var n:=((p-center)/radius).normalized()
					vertices.append(center+n*radius);normals.append((n/radius).normalized())
			for j in 5:
				for i in 5:
					var a:=base+j*6+i;var b:=a+1;var c:=a+6;var d:=c+1
					# Godot uses clockwise front faces.
					indices.append_array([a,c,b,b,c,d] if side>0 else [a,b,c,b,d,c])
	return commit(vertices,normals,indices)

static func rounded_disc(radius:float,height:float)->ArrayMesh:
	var h:=height*.5;var bevel:=minf(radius*.16,height*.32)
	var profile:=[Vector2(0,h),Vector2(radius-bevel,h),
		Vector2(radius-bevel+bevel*.707107,h-bevel+bevel*.707107),Vector2(radius,h-bevel),
		Vector2(radius,-h+bevel),Vector2(radius-bevel+bevel*.707107,-h+bevel-bevel*.707107),
		Vector2(radius-bevel,-h),Vector2(0,-h)]
	var slopes:=[Vector2(0,1),Vector2(0,1),Vector2(.707107,.707107),Vector2(1,0),
		Vector2(1,0),Vector2(.707107,-.707107),Vector2(0,-1),Vector2(0,-1)]
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	const SEGMENTS:=20
	for row in profile.size():
		for i in SEGMENTS:
			var a:float=TAU*i/SEGMENTS
			vertices.append(Vector3(cos(a)*profile[row].x,profile[row].y,sin(a)*profile[row].x))
			normals.append(Vector3(cos(a)*slopes[row].x,slopes[row].y,sin(a)*slopes[row].x))
	for row in profile.size()-1:
		for i in SEGMENTS:
			var a:=row*SEGMENTS+i;var b:=row*SEGMENTS+(i+1)%SEGMENTS;var c:=a+SEGMENTS;var d:=b+SEGMENTS
			if row>0:indices.append_array([a,c,b])
			if row<profile.size()-2:indices.append_array([b,c,d])
	return commit(vertices,normals,indices)

static func roughness(tint:Color)->float:
	# Bake each ingredient's finish into vertex alpha while keeping one opaque draw.
	if tint in [Color("ff398c"),Color("49d6fa"),Color("9854ed"),Color("65df46"),Color("ffbf00"),Color("c76b16")]:return .20
	if tint in [Color("f72f35"),Color("ff633e"),Color("ffd82a"),Color("ffcf04")]:return .27
	if tint in [Color("ffab12"),Color("ffae21"),Color("ffc045"),Color("ffc24d"),Color("f7a32d"),Color("ffdc58")]:return .58
	return .40
