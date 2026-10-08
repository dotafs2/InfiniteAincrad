extends SceneTree
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const CommonSurface=preload("res://fidelity/common_surface.gdshader")
const TempestSurface=preload("res://fidelity/shaders/tempest.gdshader")
const RainfallSurface=preload("res://fidelity/shaders/rainfall_water.gdshader")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func review_source_hash(path:String)->Variant:
	# Exported packages can contain compiled scripts without original source text.
	if not FileAccess.file_exists(path):return null
	var digest:=FileAccess.get_sha256(path)
	return null if digest.is_empty() else digest
func write_optional_report(result:Dictionary)->bool:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():return true
	if not output.is_absolute_path() or "://" in output:
		push_error("Review report requires an absolute filesystem path: "+output)
		return false
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		push_error("Could not write review report: %s (error %d)"%[output,FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(result,"\t")+"\n");file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:
		push_error("Could not finish review report: %s (error %d)"%[output,error])
		return false
	return true
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var model:=Visual.new();root.add_child(model);model.set_process(false)
	var metrics:Array=[]
	for definition in Catalog.DEFS:
		model.build(definition,false)
		var first_count:int=model.find_children("*","MeshInstance3D",true,false).size()
		model.build(definition,false)
		check(model.find_children("*","MeshInstance3D",true,false).size()==first_count,"Rebuilding does not accumulate old meshes: "+definition.id)
		check(model.mouth==null and model.find_children("*","CollisionObject3D",true,false).is_empty(),"Gameplay visual never plugs the physical opening: "+definition.id)
		model._process(.37)
		if definition.model_id in Visual.Common.IDS:
			var lit_surfaces:=true
			for index in model.main_ring.mesh.get_surface_count():
				var material:Material=model.main_ring.mesh.surface_get_material(index)
				lit_surfaces=lit_surfaces and material is ShaderMaterial and material.shader==CommonSurface
			check(is_instance_valid(model.common) and lit_surfaces and model.skin_shader==CommonSurface,"Common's batched sculpture uses its authored static lit shader: "+definition.id)
		elif definition.model_id in Visual.CollectionGeometry.IDS:
			check(is_instance_valid(model.collection) and model.main_ring.mesh.get_surface_count()>0,"New collection geometry is connected to its live cosmetic controller: "+definition.id)
		else:
			check(is_equal_approx(float(model.main_ring.material_override.get_shader_parameter("fx_time")),.37),"Actual ring shader receives advancing preview time: "+definition.id)
		if definition.model_id in ["tempest","rainfall"]:
			# Weather intentionally spans the opening with translucent effect surfaces.
			# Its one-entry/lifecycle/pool contracts are checked by the weather suites;
			# it is not an opaque closed extrusion from the original motif catalog.
			var expected:Shader=TempestSurface if definition.model_id=="tempest" else RainfallSurface
			var controller:Node3D=model.tempest if definition.model_id=="tempest" else model.rainfall
			check(is_instance_valid(controller) and model.main_ring.material_override is ShaderMaterial and model.skin_shader==expected,"Weather routes to the exact authored effect shader and controller: "+definition.id)
			metrics.append({"id":definition.id,"mesh_count":first_count,"geometry_scope":"Translucent weather effect; closed-solid and clear-triangle oracle intentionally inapplicable"})
			continue
		var clear:=true;var smallest:=INF
		var solid_motifs:=0;var inside_out:=0;var unclosed:=0
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if not mesh.visible:continue
			if definition.model_id=="aurora_rift" and mesh.name=="AuroraCurtain":
				check(mesh.material_override is ShaderMaterial and mesh.material_override.shader.resource_path.ends_with("collection_aurora.gdshader"),"Aurora curtain uses its exact bounded translucent effect shader: "+definition.id)
				continue
			var batch_volume:=0.0;var batch_edges:Dictionary={}
			for surface in mesh.mesh.get_surface_count():
				var arrays:Array=mesh.mesh.surface_get_arrays(surface)
				var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var volume:=0.0;var edges:Dictionary={}
				for i in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
					var triangle:=PackedVector2Array()
					var local:Array[Vector3]=[]
					for corner in 3:
						var vertex:Vector3=vertices[indices[i+corner] if not indices.is_empty() else i+corner]
						local.append(vertex)
						var at:Vector3=mesh.global_transform*vertex
						triangle.append(Vector2(at.x,at.z))
					volume+=local[0].dot(local[1].cross(local[2]))/6.0
					for edge in 3:
						var ends:Array[String]=[str(local[edge].snapped(Vector3.ONE*.00001)),str(local[(edge+1)%3].snapped(Vector3.ONE*.00001))]
						ends.sort();var key:=ends[0]+"/"+ends[1];edges[key]=int(edges.get(key,0))+1
					if Geometry2D.is_point_in_polygon(Vector2.ZERO,triangle):smallest=0.0
					for side in 3:smallest=minf(smallest,Geometry2D.get_closest_point_to_segment(Vector2.ZERO,triangle[side],triangle[(side+1)%3]).length())
					if smallest<.70:clear=false
				if (definition.model_id in Visual.Common.IDS or definition.model_id in Visual.CollectionGeometry.IDS) and mesh.mesh is ArrayMesh:
					batch_volume+=volume
					for key in edges:batch_edges[key]=int(batch_edges.get(key,0))+int(edges[key])
				elif definition.model_id not in ["core_shell","copper_ring","moss_bloom","gravitas","lantern","shard","cinder","tide","orbit","prism_vale"] and mesh.mesh is ArrayMesh:
					solid_motifs+=1
					if volume>=-.000001:inside_out+=1
					if edges.values().any(func(count):return count!=2):unclosed+=1
			if (definition.model_id in Visual.Common.IDS or definition.model_id in Visual.CollectionGeometry.IDS) and mesh.mesh is ArrayMesh:
				# Material regions partition one authored mesh; joins must be evaluated
				# across the full mesh rather than treating each color as a solid.
				solid_motifs+=1
				if batch_volume>=-.000001:inside_out+=1
				if batch_edges.values().any(func(count):return count!=2):unclosed+=1
		check(clear,"Authored triangles leave the center 70 percent of the mouth visibly clear: "+definition.id)
		if solid_motifs>0:
			check(inside_out==0,"Every extruded motif has outward clockwise closed-surface orientation: "+definition.id)
			check(unclosed==0,"Every extruded motif has two triangles per closed boundary edge: "+definition.id)
		metrics.append({"id":definition.id,"minimum_geometry_radius":smallest,"mesh_count":first_count,"extruded_meshes":solid_motifs,"inside_out":inside_out,"unclosed":unclosed})
	var hashes:={}
	for path in ["fidelity/skin_catalog.gd","fidelity/skin_motifs.gd","fidelity/skin_visual.gd","fidelity/shaders/accretion.gdshader"]:hashes[path]=review_source_hash("res://"+path)
	var result:={"checks":checks,"failures":failures,"source_hashes":hashes,"forms":metrics}
	model.free()
	result["source_hash_note"]="Null means source text is unavailable in this runtime; package identity is recorded by the release gate."
	var report_ok:=write_optional_report(result)
	print("CITY_REVIEW_SKIN_CATALOG "+JSON.stringify(result))
	quit(0 if failures.is_empty() and report_ok else 1)
