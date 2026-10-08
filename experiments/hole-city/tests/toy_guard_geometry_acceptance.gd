extends SceneTree
## Sixteen original living costumes plus one drone and their real payloads.
const Guards=preload("res://fidelity/toy_guard_shapes.gd")
const Shapes=preload("res://fidelity/toy_shapes.gd")
const ROLES:=["guard","sentry","king","courier","courtier","jester","royal_drone","queen","captain","drummer","toymaker","balloon_vendor","page","herald","knight","steward","princess"]
const EXPECTED_BEHAVIOR:={"guard":"guard","sentry":"sentry","king":"king","courier":"courier","courtier":"courtier","jester":"jester","royal_drone":"royal_drone","queen":"king","captain":"guard","drummer":"jester","toymaker":"courtier","balloon_vendor":"courtier","page":"courier","herald":"courier","knight":"guard","steward":"king","princess":"king"}
const ORIGINAL_GEOMETRY:={"guard":"3338695931","sentry":"3667580554","king":"3109820019","courier":"2598940603","courtier":"1889387602","jester":"2431557404","royal_drone":"2952129320"}
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func point_key(point:Vector3)->String:
	return "%d/%d/%d"%[roundi(point.x*100000),roundi(point.y*100000),roundi(point.z*100000)]
func signature(mesh:Mesh)->String:
	var payload:Array=[]
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		payload.append([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX]])
	return str(hash(payload))
@warning_ignore("integer_division")
func inspect(role:String)->Dictionary:
	var mesh:ArrayMesh=Guards.mesh_for(role,0)
	check(mesh!=null and mesh.get_surface_count()==1 and Guards.mesh_for(role,0)==mesh,role+": repeated requests reuse one original mesh surface")
	if mesh==null:return {}
	var box:AABB=mesh.get_aabb()
	check(box.size.is_equal_approx(Vector3.ONE) and box.get_center().is_equal_approx(Vector3(0,.5,0)),role+": unit geometry preserves a centered footprint and grounded base")
	check(mesh.get_meta("model_forward",Vector3.ZERO)==Vector3.BACK,role+": the original court silhouette declares +Z forward for actual heading control")
	check(mesh.get_meta("court_role","")==role and mesh.get_meta("toy_npc_role","")==role and mesh.get_meta("behavior_group","")==EXPECTED_BEHAVIOR[role] and Guards.behavior_group_for(role)==EXPECTED_BEHAVIOR[role] and Guards.BEHAVIOR_GROUPS.has(role),role+": original identity and behavior family remain explicit and truthful")
	var natural:Vector3=Guards.natural_size_for(role)
	check(natural.is_finite() and natural.x>0 and natural.y>0 and natural.z>0,role+": natural dimensions preserve the role's real proportions")
	var arrays:Array=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var payload_ok:bool=not vertices.is_empty() and normals.size()==vertices.size() and colors.size()==vertices.size()
	for vertex in vertices:payload_ok=payload_ok and vertex.is_finite() and box.grow(.0001).has_point(vertex)
	for normal in normals:payload_ok=payload_ok and normal.is_finite() and absf(normal.length()-1)<.002
	for color in colors:payload_ok=payload_ok and is_equal_approx(color.a,1) and is_finite(color.r) and is_finite(color.g) and is_finite(color.b)
	check(payload_ok,role+": actual vertices, unit normals and opaque vertex colors are finite")
	if indices.is_empty():
		for index in vertices.size():indices.append(index)
	var topology_ok:bool=indices.size()%3==0 and mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES
	for index in indices:topology_ok=topology_ok and index>=0 and index<vertices.size()
	var edges:Dictionary={}
	if topology_ok:
		for offset in range(0,indices.size(),3):
			var a:int=indices[offset];var b:int=indices[offset+1];var c:int=indices[offset+2]
			var cross:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			topology_ok=topology_ok and cross.length_squared()>1.0e-15
			var keys:=[point_key(vertices[a]),point_key(vertices[b]),point_key(vertices[c])]
			for pair in [[keys[0],keys[1]],[keys[1],keys[2]],[keys[2],keys[0]]]:
				var key:String=pair[0]+"|"+pair[1] if pair[0]<pair[1] else pair[1]+"|"+pair[0]
				edges[key]=int(edges.get(key,0))+1
	check(topology_ok and not edges.is_empty() and edges.values().all(func(count):return int(count)>=2 and int(count)%2==0),role+": real triangles are nondegenerate and the welded geometry has no open boundary")
	check(indices.size()/3<=3200,role+": modeled props and soft forms stay inside the declared court mesh budget")
	check(signature(Guards.mesh_for(role,1))==signature(mesh),role+": changing the palette preserves role geometry and admission dimensions")
	var parts:Array=Guards.collision_parts_for(role)
	var collision_ok:bool=parts.size()==1 and parts[0].size()>=4
	if collision_ok:
		for point in parts[0]:collision_ok=collision_ok and point.is_finite() and box.grow(.0001).has_point(point)
	check(collision_ok,role+": one finite whole-body hull retains the original character envelope")
	if not parts.is_empty() and not parts[0].is_empty():
		var original:Vector3=parts[0][0]
		parts[0][0]+=Vector3.ONE
		var fresh:Array=Guards.collision_parts_for(role)
		check(fresh[0][0]==original,role+": returned hull copies cannot corrupt cached collision for another character")
	return {"vertices":vertices.size(),"triangles":indices.size()/3,"natural_size":natural,"signature":signature(mesh),"collision_parts":parts.size()}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	check(Array(Guards.KINDS)==ROLES,"Court shapes expose sixteen original living costumes plus a drone")
	var signatures:Dictionary={};var dimensions:Dictionary={}
	for role:String in ROLES:
		var info:=inspect(role);metrics[role]=info
		if info.has("signature"):signatures[info.signature]=true;dimensions[str(info.natural_size)]=true
	check(signatures.size()==17 and dimensions.size()>=4,"Seventeen silhouettes are actual modeled distinctions, with varied proportions instead of palette clones")
	check(ORIGINAL_GEOMETRY.keys().all(func(role):return metrics.has(role) and metrics[role].signature==ORIGINAL_GEOMETRY[role]),"The first seven accepted geometry signatures remain exact after adding ten costumes")
	check(Guards.material()==Shapes.material(),"Ordinary court bodies reuse the same opaque toy material")
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual arrays, normalized bounds, closed geometry, shared resources and hull-copy ownership; no GPU pixels or phone performance claim"}
	print("TOY_GUARD_GEOMETRY_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
