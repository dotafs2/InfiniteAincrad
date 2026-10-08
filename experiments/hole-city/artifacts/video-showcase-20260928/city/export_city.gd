extends SceneTree
## Actual current geometry/poses exported for an explicitly offline CGL preview.
var output:="res://artifacts/video-showcase-20260928/city"
var game:Node3D
var meshes:Dictionary={}
var skinned_count:=0
var omissions:Array[String]=[]
var frame_tag:=""
func _initialize()->void:run.call_deferred()
func matrix(t:Transform3D)->Array:
	return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
func projection(p:Projection)->Array:
	return [p.x.x,p.x.y,p.x.z,p.x.w,p.y.x,p.y.y,p.y.z,p.y.w,p.z.x,p.z.y,p.z.z,p.z.w,p.w.x,p.w.y,p.w.z,p.w.w]
func color_array(c:Color)->Array:return [c.r,c.g,c.b,c.a]
func geometry(source:Mesh,override_:Material=null,skin_node:MeshInstance3D=null)->Dictionary:
	var record:={"vertices":[],"normals":[],"colors":[],"indices":[]}
	var skeleton:Skeleton3D=null
	var skin:Skin=null
	var bone_matrices:Array[Transform3D]=[]
	if skin_node!=null and skin_node.skin!=null:
		skin=skin_node.skin;skeleton=skin_node.get_node_or_null(skin_node.skeleton) as Skeleton3D
		if skeleton!=null:
			for bind in skin.get_bind_count():
				var bone:=skin.get_bind_bone(bind)
				if bone<0:bone=skeleton.find_bone(skin.get_bind_name(bind))
				bone_matrices.append(skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
			skinned_count+=1
		else:omissions.append("Skeleton unavailable: "+str(skin_node.get_path()))
	for surface in source.get_surface_count():
		if source is ArrayMesh and source.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
		var a:Array=source.surface_get_arrays(surface)
		var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var ns:PackedVector3Array=a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
		var cs:PackedColorArray=a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
		var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var mat:Material=override_ if override_!=null else source.surface_get_material(surface)
		var tint:=Color.WHITE;var use_vertex:=true
		var building_tint:=Color.WHITE;var tint_amount:=0.0
		if mat is StandardMaterial3D:
			tint=mat.albedo_color;use_vertex=mat.vertex_color_use_as_albedo
		elif mat is ShaderMaterial:
			var tint_value=mat.get_shader_parameter("building_tint")
			if tint_value is Color:building_tint=tint_value
			var amount=mat.get_shader_parameter("tint_amount")
			if amount!=null:tint_amount=float(amount)
		var offset:int=record.vertices.size()/3
		for i in vs.size():
			var v:=vs[i];var n:=ns[i] if i<ns.size() else Vector3.UP
			if not bone_matrices.is_empty() and a[Mesh.ARRAY_BONES]!=null and a[Mesh.ARRAY_WEIGHTS]!=null:
				var bones=a[Mesh.ARRAY_BONES];var weights=a[Mesh.ARRAY_WEIGHTS]
				var stride:int=bones.size()/vs.size()
				var sv:=Vector3.ZERO;var sn:=Vector3.ZERO;var total:=0.0
				for k in stride:
					var bi:int=bones[i*stride+k];var weight:float=weights[i*stride+k]
					if weight<=0.0 or bi<0 or bi>=bone_matrices.size():continue
					sv+=(bone_matrices[bi]*v)*weight;sn+=(bone_matrices[bi].basis*n)*weight;total+=weight
				if total>.0001:v=sv/total;n=sn.normalized()
			var c:Color=tint*(cs[i] if use_vertex and i<cs.size() else Color.WHITE)
			c=c.lerp(c*building_tint,tint_amount)
			record.vertices.append_array([v.x,v.y,v.z]);record.normals.append_array([n.x,n.y,n.z]);record.colors.append_array(color_array(c))
		if indices.is_empty():
			for i in vs.size():record.indices.append(offset+i)
		else:
			for i in indices:record.indices.append(offset+i)
	return record
func mesh_key(mesh:Mesh,mat:Material,skin_node:MeshInstance3D=null)->String:
	var key:="m%d_%d"%[mesh.get_instance_id(),mat.get_instance_id() if mat!=null else 0]
	if skin_node!=null and skin_node.skin!=null:key+="_"+str(skin_node.get_instance_id())+"_"+frame_tag
	if not meshes.has(key):meshes[key]=geometry(mesh,mat,skin_node)
	return key
func gather(node:Node,instances:Array)->void:
	if node is Node3D and not node.is_visible_in_tree():return
	if node is MeshInstance3D and node.mesh!=null:
		instances.append({"key":mesh_key(node.mesh,node.material_override,node),"matrix":matrix(node.global_transform)})
	elif node is MultiMeshInstance3D and node.multimesh!=null:
		var mm:MultiMesh=node.multimesh
		var count:int=mm.visible_instance_count if mm.visible_instance_count>=0 else mm.instance_count
		var key:=mesh_key(mm.mesh,node.material_override)
		for i in count:instances.append({"key":key,"matrix":matrix(node.global_transform*mm.get_instance_transform(i))})
	for child in node.get_children():gather(child,instances)
func capture(name:String,width:int,height:int,at:Vector3,target:Vector3)->void:
	frame_tag=name;skinned_count=0
	game.ground.sync()
	var instances:Array=[];gather(game.city,instances)
	var openings:=[]
	for hole in game.holes:
		if hole.active:
			openings.append([hole.position.x,hole.position.z,hole.radius])
			# Procedural animated skin surfaces are intentionally omitted; the
			# exact cut is visible, and UI/skins have their own offline panels.
	var camera:=Transform3D(Basis.IDENTITY,at).looking_at(target,Vector3.UP)
	var view:=camera.affine_inverse()
	var params:={}
	for key in ["road_x","road_z","road_half_width","sidewalk_0","sidewalk_1","sidewalk_2","sidewalk_3","city_walk_0","city_walk_1","city_walk_2","city_walk_3","city_park_0","city_park_1","city_park_2","city_park_3","city_courtyard"]:
		var v=game.ground.surface.get_shader_parameter(key)
		if v is Vector2:params[key]=[v.x,v.y]
		elif v is Vector4:params[key]=[v.x,v.y,v.z,v.w]
		else:params[key]=v
	var result:={"width":width,"height":height,"projection":projection(Projection.create_perspective(58,float(width)/height,.1,500)),"view":matrix(view),"instances":instances,"ground":geometry(game.ground.visual.mesh),"openings":openings,"ground_uniforms":params,"elapsed":game.elapsed,"skinned_meshes":skinned_count,"scope":"Offline CGL preview of actual game geometry and headless poses; approximate lighting, no Godot viewport/UI/shader skin capture"}
	FileAccess.open(output+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print("CITY_OFFLINE_FRAME "+JSON.stringify({"name":name,"instances":instances.size(),"skinned_meshes":skinned_count,"elapsed":game.elapsed}))
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):push_error("Requires --test");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="city";game.start_level();game.begin_play()
	for hole in game.holes:hole.enabled=false
	for i in 30:await physics_frame
	game.update_camera(0,true)
	capture("opening",720,1280,game.camera.position,game.player.position)
	capture("overview",1280,1280,Vector3(101,143,144),Vector3(0,0,-3))
	capture("street-close",1280,960,Vector3(-3,16,17),Vector3(-12,0,-4))
	FileAccess.open(output+"/render-meshes.json",FileAccess.WRITE).store_string(JSON.stringify(meshes))
	FileAccess.open(output+"/export-summary.json",FileAccess.WRITE).store_string(JSON.stringify({"unique_meshes":meshes.size(),"omissions":omissions,"source_scope":"current city, visible static MultiMesh instances, CPU-skinned current NPC poses; no GUI", "runtime_source_sha256":{"catalog_city":FileAccess.get_sha256("res://fidelity/catalog_city.gd"),"asphalt":FileAccess.get_sha256("res://fidelity/asphalt.gdshader"),"districts":FileAccess.get_sha256("res://fidelity/city_districts.gd"),"street_layout":FileAccess.get_sha256("res://fidelity/street_layout.gd")}},"\t"))
	game.free();await process_frame;quit()
