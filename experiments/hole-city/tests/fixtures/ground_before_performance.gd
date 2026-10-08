extends Node3D
## Scanline triangulation of a slab minus the union of 32-sided mouths.
## Preserves real rim/wall contacts without the general-purpose CSG rebuild.
const HALF:=80.0
const SIDES:=32
const RIM_DEPTH:=.12
var game:Node3D
var body:StaticBody3D
var collider:ConcavePolygonShape3D
var visual:MeshInstance3D
var surface:ShaderMaterial
var last_state:Array[Vector3]=[]
var rebuilds:=0
var unit_polygon:=PackedVector2Array()
var collision_vertices:=PackedVector3Array()
func build(owner_game:Node3D,mat:ShaderMaterial)->void:
	game=owner_game
	surface=mat
	for i in SIDES:unit_polygon.append(Vector2(cos(TAU*i/SIDES),sin(TAU*i/SIDES)))
	body=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=1
	add_child(body)
	var shape:=CollisionShape3D.new()
	collider=ConcavePolygonShape3D.new()
	collider.backface_collision=true
	shape.shape=collider
	body.add_child(shape)
	visual=MeshInstance3D.new()
	visual.material_override=mat
	add_child(visual)
	process_physics_priority=10
	sync()
func _physics_process(_delta:float)->void:sync()
func sync()->void:
	var state:Array[Vector3]=[]
	for h in game.holes:
		if is_instance_valid(h) and h.active:state.append(Vector3(h.position.x,h.position.z,h.radius))
	if state==last_state and rebuilds>0:return
	last_state=state
	var mouths:Array[PackedVector2Array]=[]
	var bounds:Array[Vector2]=[]
	var levels:Array[float]=[-HALF,HALF]
	for h in state:
		var poly:=PackedVector2Array()
		for point in unit_polygon:
			var p:=Vector2(h.x,h.y)+point*h.z
			poly.append(p)
			if p.y>-HALF and p.y<HALF:levels.append(p.y)
		mouths.append(poly)
		bounds.append(Vector2(h.y-h.z,h.y+h.z))
	# Include crossings: within each resulting band, interval ordering and
	# polygon edge equations are fixed, including overlapping mouths.
	for i in mouths.size():
		for j in range(i+1,mouths.size()):
			if Vector2(state[i].x-state[j].x,state[i].y-state[j].y).length()>=state[i].z+state[j].z:continue
			for intersection in Geometry2D.intersect_polygons(mouths[i],mouths[j]):
				for p in intersection:
					if p.y>-HALF and p.y<HALF:levels.append(p.y)
	levels.sort()
	var unique:Array[float]=[]
	for z in levels:
		if unique.is_empty() or z-unique.back()>.0001:unique.append(z)
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	collision_vertices.clear()
	for row in range(unique.size()-1):
		var lo:=unique[row]
		var hi:=unique[row+1]
		var mid:float=(lo+hi)*.5
		var spans:Array[Vector4]=[]
		for i in mouths.size():
			if mid<=bounds[i].x or mid>=bounds[i].y:continue
			var edge:=Vector4(INF,INF,-INF,-INF)
			var poly:=mouths[i]
			for k in SIDES:
				var a:=poly[k]
				var b:=poly[(k+1)%SIDES]
				if mid<=minf(a.y,b.y) or mid>=maxf(a.y,b.y):continue
				var slope:float=(b.x-a.x)/(b.y-a.y)
				var x0:float=clampf(a.x+(lo-a.y)*slope,-HALF,HALF)
				var x1:float=clampf(a.x+(hi-a.y)*slope,-HALF,HALF)
				edge.x=minf(edge.x,x0);edge.y=minf(edge.y,x1)
				edge.z=maxf(edge.z,x0);edge.w=maxf(edge.w,x1)
			if is_finite(edge.x):spans.append(edge)
		spans.sort_custom(func(a:Vector4,b:Vector4):return a.x+a.y<b.x+b.y)
		var merged:Array[Vector4]=[]
		for span in spans:
			if not merged.is_empty() and span.x+span.y<=merged.back().z+merged.back().w+.0001:
				var previous:Vector4=merged.back()
				previous.z=maxf(previous.z,span.z);previous.w=maxf(previous.w,span.w)
				merged[-1]=previous
			else:merged.append(span)
		var left0:float=-HALF
		var left1:float=-HALF
		for span in merged:
			_quad(vertices,normals,Vector3(left0,0,lo),Vector3(span.x,0,lo),Vector3(span.y,0,hi),Vector3(left1,0,hi),Vector3.UP)
			_wall(vertices,normals,Vector3(span.x,0,lo),Vector3(span.y,0,hi))
			_wall(vertices,normals,Vector3(span.w,0,hi),Vector3(span.z,0,lo))
			left0=span.z;left1=span.w
		_quad(vertices,normals,Vector3(left0,0,lo),Vector3(HALF,0,lo),Vector3(HALF,0,hi),Vector3(left1,0,hi),Vector3.UP)
	# The visible dark wall is not a three-metre narrow pipe. A shallow solid
	# rim keeps real edge contacts while leaving room to tip below the surface.
	collider.set_faces(collision_vertices)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	visual.mesh=mesh
	rebuilds+=1
func _wall(v:PackedVector3Array,n:PackedVector3Array,a:Vector3,b:Vector3)->void:
	var normal:Vector3=(b-a).cross(Vector3.DOWN).normalized()
	_quad(v,n,a,b,b+Vector3.DOWN*3,a+Vector3.DOWN*3,normal)
func _quad(v:PackedVector3Array,n:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3)->void:
	if a.distance_squared_to(b)+c.distance_squared_to(d)<.0000001:return
	v.append_array(PackedVector3Array([a,b,c,a,c,d]))
	var ca:=Vector3(a.x,maxf(a.y,-RIM_DEPTH),a.z)
	var cb:=Vector3(b.x,maxf(b.y,-RIM_DEPTH),b.z)
	var cc:=Vector3(c.x,maxf(c.y,-RIM_DEPTH),c.z)
	var cd:=Vector3(d.x,maxf(d.y,-RIM_DEPTH),d.z)
	collision_vertices.append_array(PackedVector3Array([ca,cb,cc,ca,cc,cd]))
	for i in 6:n.append(normal)
