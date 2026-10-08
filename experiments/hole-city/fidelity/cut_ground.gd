extends Node3D
## Scanline triangulation of a slab minus the union of 32-sided mouths.
## Preserves real rim/wall contacts without the general-purpose CSG rebuild.
const WorldBounds=preload("res://fidelity/world_bounds.gd")
const HALF:=WorldBounds.HALF
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
var section_y:=PackedFloat32Array()
var section_width:=PackedFloat32Array()
func build(owner_game:Node3D,mat:ShaderMaterial)->void:
	game=owner_game
	surface=mat
	surface.set_shader_parameter("world_half",HALF)
	surface.set_shader_parameter("city_outer_road",WorldBounds.CITY_RING)
	surface.set_shader_parameter("city_outer_half_width",WorldBounds.CITY_RING_HALF_WIDTH)
	for i in SIDES:unit_polygon.append(Vector2(cos(TAU*i/SIDES),sin(TAU*i/SIDES)))
	# The convex 32-gon has 16 monotonic right-edge sections. Locate one edge
	# per scan band instead of testing all 32 edges for every mouth and band.
	for i in SIDES/2+1:
		var angle:float=-PI*.5+TAU*float(i)/SIDES
		section_y.append(sin(angle));section_width.append(cos(angle))
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
			if Vector2(state[i].x-state[j].x,state[i].y-state[j].y).length_squared()>=pow(state[i].z+state[j].z,2):continue
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
			var h:=state[i]
			var normalized_mid:float=(mid-h.y)/h.z
			var low:=0;var high:int=SIDES/2
			while high-low>1:
				var k:int=(low+high)/2
				if section_y[k]<=normalized_mid:low=k
				else:high=k
			var slope:float=(section_width[high]-section_width[low])/(section_y[high]-section_y[low])
			var base_y:float=h.y+section_y[low]*h.z
			var base_width:float=section_width[low]*h.z
			var width0:float=maxf(0,base_width+(lo-base_y)*slope)
			var width1:float=maxf(0,base_width+(hi-base_y)*slope)
			spans.append(Vector4(clampf(h.x-width0,-HALF,HALF),clampf(h.x-width1,-HALF,HALF),clampf(h.x+width0,-HALF,HALF),clampf(h.x+width1,-HALF,HALF)))
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
	v.append(a);v.append(b);v.append(c);v.append(a);v.append(c);v.append(d)
	var ca:=Vector3(a.x,maxf(a.y,-RIM_DEPTH),a.z)
	var cb:=Vector3(b.x,maxf(b.y,-RIM_DEPTH),b.z)
	var cc:=Vector3(c.x,maxf(c.y,-RIM_DEPTH),c.z)
	var cd:=Vector3(d.x,maxf(d.y,-RIM_DEPTH),d.z)
	collision_vertices.append(ca);collision_vertices.append(cb);collision_vertices.append(cc)
	collision_vertices.append(ca);collision_vertices.append(cc);collision_vertices.append(cd)
	n.append(normal);n.append(normal);n.append(normal);n.append(normal);n.append(normal);n.append(normal)
