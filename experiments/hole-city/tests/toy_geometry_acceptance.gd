extends SceneTree
## Actual generated geometry and preview ownership; not a rendered-pixel claim.
const Shapes=preload("res://fidelity/toy_shapes.gd")
const Preview=preload("res://fidelity/toy_preview.gd")
const EXPECTED_KINDS:=["toy_ball","toy_duck","toy_car","toy_block","toy_train","toy_arch","bubble_turret","block_tower","toy_castle","grand_castle"]
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func descendants(node:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in node.get_children():
		result.append(child);result.append_array(descendants(child))
	return result
func vertex_key(v:Vector3)->String:
	return "%d,%d,%d"%[roundi(v.x*100000),roundi(v.y*100000),roundi(v.z*100000)]
func mesh_geometry(mesh:Mesh)->String:
	var vertices:PackedVector3Array=[]
	var indices:PackedInt32Array=[]
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		vertices.append_array(arrays[Mesh.ARRAY_VERTEX]);indices.append_array(arrays[Mesh.ARRAY_INDEX])
	return str(hash([vertices,indices]))
@warning_ignore("integer_division")
func inspect_kind(kind:String)->Dictionary:
	var mesh:ArrayMesh=Shapes.mesh_for(kind,0)
	check(mesh!=null and mesh.get_surface_count()>0,kind+": generated triangle surfaces exist")
	if mesh==null:return {}
	check(Shapes.mesh_for(kind,0)==mesh,kind+": repeated requests reuse the same cached mesh")
	var box:AABB=mesh.get_aabb()
	check(box.size.is_equal_approx(Vector3.ONE) and box.get_center().is_equal_approx(Vector3(0,.5,0)),kind+": exact normalized bounds preserve a centered footprint and grounded base")
	var natural:Vector3=Shapes.natural_size_for(kind)
	check(natural.is_finite() and natural.x>0 and natural.y>0 and natural.z>0,kind+": original proportions have finite positive dimensions")
	var triangle_count:=0
	var vertex_count:=0
	var valid_vertices:=true
	var valid_normals:=true
	var opaque_colors:=true
	var valid_indices:=true
	var nondegenerate:=true
	var normal_agreement:=true
	var edges:Dictionary={}
	for surface in mesh.get_surface_count():
		check(mesh.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_TRIANGLES,kind+": surface uses actual triangles")
		var arrays:Array=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		vertex_count+=vertices.size()
		valid_normals=valid_normals and normals.size()==vertices.size()
		opaque_colors=opaque_colors and colors.size()==vertices.size()
		for v in vertices:
			valid_vertices=valid_vertices and v.is_finite() and v.x>=-.50001 and v.x<=.50001 and v.y>=-.00001 and v.y<=1.00001 and v.z>=-.50001 and v.z<=.50001
		for n in normals:valid_normals=valid_normals and n.is_finite() and absf(n.length()-1.0)<.002
		for color in colors:opaque_colors=opaque_colors and is_equal_approx(color.a,1.0) and is_finite(color.r) and is_finite(color.g) and is_finite(color.b)
		if indices.is_empty():
			for index in vertices.size():indices.append(index)
		valid_indices=valid_indices and indices.size()%3==0
		for index in indices:valid_indices=valid_indices and index>=0 and index<vertices.size()
		if not valid_indices:continue
		triangle_count+=indices.size()/3
		for offset in range(0,indices.size(),3):
			var a:int=indices[offset];var b:int=indices[offset+1];var c:int=indices[offset+2]
			var cross:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			if cross.length_squared()<1.0e-15:
				nondegenerate=false;continue
			if normals.size()==vertices.size():
				# Agreement magnitude is independent of Godot's clockwise convention.
				var average:Vector3=normals[a]+normals[b]+normals[c]
				normal_agreement=normal_agreement and absf(cross.normalized().dot(average.normalized()))>.05
			var keys:=[vertex_key(vertices[a]),vertex_key(vertices[b]),vertex_key(vertices[c])]
			for edge in [[keys[0],keys[1]],[keys[1],keys[2]],[keys[2],keys[0]]]:
				var key:String=(edge[0]+"|"+edge[1]) if edge[0]<edge[1] else (edge[1]+"|"+edge[0])
				edges[key]=int(edges.get(key,0))+1
	check(vertex_count>0 and valid_vertices,kind+": every actual vertex is finite and inside the declared normalized envelope")
	check(valid_normals and normal_agreement,kind+": actual normal payload is finite, normalized and agrees with real triangles")
	check(opaque_colors,kind+": every vertex has a finite opaque color")
	check(valid_indices and nondegenerate,kind+": indices are valid and no pole/cap produces zero-area triangles")
	# Coincident closed primitives can contribute four or more edges; a positive
	# even count still proves there is no exposed one-sided seam after welding.
	check(not edges.is_empty() and edges.values().all(func(count):return int(count)>=2 and int(count)%2==0),kind+": welded triangle edges have no open boundaries")
	var budget:=12000 if kind in ["bubble_turret","block_tower","toy_castle","grand_castle"] else 2500
	check(triangle_count<=budget,kind+": rounded detail remains within the declared mesh budget")
	var alternative:ArrayMesh=Shapes.mesh_for(kind,1)
	check(alternative!=null and mesh_geometry(alternative)==mesh_geometry(mesh),kind+": palette selection changes color without changing collision geometry")
	return {"triangles":triangle_count,"vertices":vertex_count,"natural_size":natural,"signature":mesh_geometry(mesh),"welded_edges":edges.size()}
func inspect_preview()->void:
	var preview:=Preview.new();root.add_child(preview);preview.build_preview()
	var nodes:=descendants(preview)
	var meshes:Array[MeshInstance3D]=[]
	var kinds:Dictionary={};var materials:Dictionary={};var resources:Dictionary={};var court_roles:Dictionary={}
	var court_visual_only:=true
	var forbidden:=false
	for node in nodes:
		if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D or node is Light3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer:forbidden=true
		if node is MeshInstance3D:
			meshes.append(node)
			if node.has_meta("toy_kind"):kinds[node.get_meta("toy_kind")]=true
			if node.has_meta("toy_npc_role"):
				court_roles[node.get_meta("toy_npc_role")]=true
				court_visual_only=court_visual_only and node.get_script()==null
			if node.mesh!=null:resources[node.mesh.get_instance_id()]=true
			if node.material_override!=null:materials[node.material_override.get_instance_id()]=true
	check(not forbidden,"Preview has no bodies, colliders, lights, cameras, environments or audio owners")
	check(not meshes.is_empty() and meshes.size()<=70,"Preview contains real bounded geometry instead of a full playable city")
	check(meshes.size()==37 and nodes.size()==38 and preview.toy_piece_count==26 and preview.court_piece_count==6 and int(preview.layer_counts.foreground)+int(preview.layer_counts.midground)+int(preview.layer_counts.background)==26,"The authored preview has exactly 26 toys, six pure court figures and five play-mat surfaces without extra node owners")
	check(kinds.keys().all(func(kind):return EXPECTED_KINDS.has(kind)) and kinds.size()==10,"Preview retains all ten original toy silhouettes across a varied skyline")
	check(court_roles.size()==6 and court_visual_only,"Six distinct court figures are pure original mesh previews without NPC controllers")
	check(resources.size()<meshes.size() and materials.size()<=3,"Preview shares mesh/material resources across independent visible toys")
	var old:WeakRef=weakref(preview.preview)
	var before_count:=meshes.size()
	preview.build_preview()
	await process_frame;await process_frame
	check(old.get_ref()==null and descendants(preview).filter(func(node):return node is MeshInstance3D).size()==before_count,"Rebuilding frees only the previous preview subtree without leaking visuals")
	metrics["preview"]={"meshes":before_count,"nodes":nodes.size(),"kinds":kinds.keys(),"court_roles":court_roles.keys(),"unique_meshes":resources.size(),"unique_materials":materials.size()}
	preview.free()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	check(Array(Shapes.KINDS)==EXPECTED_KINDS,"Ten stable original toy kinds form the declared vocabulary")
	var signatures:Dictionary={};var geometry:Dictionary={}
	for kind:String in EXPECTED_KINDS:
		var info:=inspect_kind(kind);geometry[kind]=info
		if info.has("signature"):signatures[info.signature]=true
	check(signatures.size()==10,"Ten recipes have genuinely distinct geometry rather than recolored clones")
	var material:Material=Shapes.material()
	check(material!=null and material==Shapes.material(),"Ordinary toy rendering reuses one material")
	if material is ShaderMaterial:
		var reveal=material.get_shader_parameter("reveal_occluder")
		check(reveal!=null and is_zero_approx(float(reveal)),"Ordinary toys stay opaque and do not opt into building reveal")
	elif material is BaseMaterial3D:
		check(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.vertex_color_use_as_albedo,"Ordinary toy material uses opaque authored vertex colors")
	else:check(false,"Toy material has an inspectable opaque rendering contract")
	metrics["geometry"]=geometry
	await inspect_preview()
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual generated arrays, cache reuse, bounds/topology and visual-only ownership; no GPU pixels or phone performance claimed."}
	print("TOY_GEOMETRY_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	await process_frame;quit(0 if failures.is_empty() else 1)
