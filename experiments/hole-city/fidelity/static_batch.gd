extends RefCounted
## Keep independent physics owners while instancing identical stationary meshes.
class Pool:
	extends RefCounted
	var mesh:MultiMesh
	var handles:Array[Dictionary]=[]

static func build(city:Node3D)->Dictionary:
	var groups:={};var result:={"batches":0,"meshes":0}
	for body in city.foods:
		if not body.has_meta("asset_id") or body.get_meta("traffic",false) or body.get_meta("scripted_actor",false) or body.category=="building":continue
		for visual in body.find_children("*","MeshInstance3D",true,false):
			if visual.mesh==null or visual.skin!=null or not visual.visible:continue
			var cell:=Vector2i(floori(body.position.x/24),floori(body.position.z/24))
			var material_id:int=visual.material_override.get_instance_id() if visual.material_override else 0
			var key:=Vector4i(visual.mesh.get_instance_id(),material_id,cell.x,cell.y)
			if not groups.has(key):groups[key]=[]
			groups[key].append({"body":body,"visual":visual})
	for key in groups:
		var entries:Array=groups[key]
		if entries.size()<2:continue
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=entries[0].visual.mesh;mm.instance_count=entries.size();mm.visible_instance_count=entries.size()
		var view:=MultiMeshInstance3D.new();view.multimesh=mm;view.material_override=entries[0].visual.material_override
		city.add_child(view)
		var pool:=Pool.new();pool.mesh=mm;view.set_meta("instance_pool",pool)
		var bounds:=AABB()
		for i in entries.size():
			var entry:Dictionary=entries[i];var visual:MeshInstance3D=entry.visual
			var pose:Transform3D=city.global_transform.affine_inverse()*visual.global_transform
			var at:AABB=pose*mm.mesh.get_aabb();bounds=at if i==0 else bounds.merge(at)
			var handle:={"pool":weakref(pool),"index":i,"visual":visual,"pose":pose}
			pool.handles.append(handle);entry.body.static_instances.append(handle)
			mm.set_instance_transform(i,pose);visual.visible=false
		mm.custom_aabb=bounds
		result.batches+=1;result.meshes+=entries.size()
	return result

static func release(handles:Array[Dictionary])->void:
	for handle in handles:
		var pool:Pool=handle.pool.get_ref()
		if pool==null:continue
		var mm:MultiMesh=pool.mesh
		var index:int=handle.index;var last:int=pool.handles.size()-1
		if index!=last:
			var moved:Dictionary=pool.handles[last]
			mm.set_instance_transform(index,moved.pose)
			moved.index=index;pool.handles[index]=moved
		pool.handles.pop_back();mm.visible_instance_count=last
		if is_instance_valid(handle.visual):handle.visual.visible=true
	handles.clear()
