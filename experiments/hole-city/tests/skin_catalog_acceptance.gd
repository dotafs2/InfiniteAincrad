extends SceneTree
## Validate actual shipped forms, not just the catalog counters. Rendering and
## phone GPU costs remain a separate device gate.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func meshes(node:Node)->Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	for c in node.get_children():
		if c is MeshInstance3D:result.append(c)
		result.append_array(meshes(c))
	return result
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var old:={"core_shell":0,"copper_ring":25,"moss_bloom":70,"gravitas":120,"lantern":180,"shard":240,"cinder":300,"tide":340,"orbit":380,"prism_vale":420}
	var ids:={};var fingerprints:={};var groups:={"foundation":0,"resonance":0};var families:={}
	var view:=SubViewport.new();view.size=Vector2i(144,106);root.add_child(view)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.1
	view.add_child(camera);camera.position=Vector3(0,6.6,8);camera.look_at(Vector3(0,.14,0));camera.current=true
	check(Catalog.DEFS.size()==200,"Collection contains exactly 200 real definitions across 68 model families")
	for d in Catalog.DEFS:
		check(not ids.has(d.id),"Stable ID is unique: "+d.id);ids[d.id]=true
		check(groups.has(d.group),"Known collection group: "+d.id);groups[d.group]+=1
		check(not d.skill_desc.is_empty() and not d.play_desc.is_empty(),"Description explains actual form: "+d.id)
		check(d.legacy_score==old[d.id] if old.has(d.id) else d.legacy_score>420,"Migration preserves legacy thresholds without gifting new forms: "+d.id)
		if not old.has(d.id):check(d.kind=="cosmetic" and d.cooldown==0 and d.play_desc.contains("Cosmetic"),"New Special forms never promise an absent ability: "+d.id)
		var model:=Visual.new();view.add_child(model);model.build(d,true);model.set_process(false);model.frame_preview(camera)
		var all:=meshes(model);var vertices:=PackedVector3Array();var triangles:=0;var fits:=true;var opening_clear:=true
		var bound:=Rect2();var first:=true
		for m in all:
			if m.mesh==null:
				check(not m.visible,"Empty render-pool view stays hidden: "+d.id);continue
			if not m.visible:continue
			var reversed_faces:=0
			for surface in m.mesh.get_surface_count():
				var arrays:Array=m.mesh.surface_get_arrays(surface)
				if not old.has(d.model_id) and m.mesh is ArrayMesh:
					var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
					var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					for i in range(0,indices.size() if not indices.is_empty() else vs.size(),3):
						var a:int=indices[i] if not indices.is_empty() else i
						var b:int=indices[i+1] if not indices.is_empty() else i+1
						var c:int=indices[i+2] if not indices.is_empty() else i+2
						var cross:Vector3=(vs[b]-vs[a]).cross(vs[c]-vs[a])
						if cross.dot(normals[a]+normals[b]+normals[c])>.000001:reversed_faces+=1
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
				for v in arrays[Mesh.ARRAY_VERTEX]:
					var point:Vector3=m.global_transform*v
					var px:=camera.unproject_position(point)
					if first:bound=Rect2(px,Vector2.ZERO);first=false
					else:bound=bound.expand(px)
					if not Rect2(4,4,136,98).has_point(px):fits=false
					vertices.append(point.snapped(Vector3.ONE*.0001))
			check(not m.mesh is SphereMesh,"No shared orbiting-sphere template: "+d.id)
			if not old.has(d.model_id) and m.mesh is ArrayMesh:check(reversed_faces==0,"Authored polygon front faces survive backface culling: "+d.id)
		check(fits,"Entire thumbnail silhouette fits four-pixel margins: "+d.id+" "+str(bound))
		check(all.size()-1<=18 and triangles<=4500,"Player skin stays within 18 meshes and 4500 triangles: "+d.id)
		check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"Skin does not own physics: "+d.id)
		if d.model_id in Visual.SIMPLE_MODELS:
			check(model.fx_family=="simple_trim","Original trim model family retains its geometry: "+d.id)
		elif int(d.variant_index)==0:check(model.fx_family!="" and not families.has(model.fx_family),"Base sculpted and effect models retain distinct visual families: "+d.id)
		else:check(model.model_id==d.model_id and families.has(model.fx_family),"Palette variants route to a previously built base family: "+d.id)
		families[model.fx_family]=true
		if int(d.variant_index)==0 and not old.has(d.model_id) and d.model_id not in Visual.SIMPLE_MODELS:
			var fingerprint:=var_to_bytes(vertices).hex_encode().sha256_text()
			check(not fingerprints.has(fingerprint),"Geometry differs without considering colors: "+d.id)
			fingerprints[fingerprint]=d.id
		var before:float=model.clock_time;model._process(.25)
		check(is_equal_approx(model.clock_time-before,.25),"Selected form supports an advancing preview clock: "+d.id)
		if d.id=="core_shell":check(model.main_ring.material_override.get_shader_parameter("core_blue")==1.0 and Color(d.tint)==Color("249cff"),"Default skin is blue in definition and actual shader")
		metrics.append({"id":d.id,"draw_meshes_player":all.size()-1,"triangles_preview":triangles,"bounds":str(bound),"family":model.fx_family})
		model.free()
	check(groups.foundation==154 and groups.resonance==46,"Append-only catalog contains 154 foundation and 46 resonance identities with the legacy groups preserved")
	check(fingerprints.size()==50,"Fifty later authored object/effect base models have distinct geometry independent of their palette variants")
	view.free()
	var result:={"checks":checks,"failures":failures,"groups":groups,"skins":metrics,"scope":"Actual geometry and definitions; no GPU/image claim"}
	print("SKIN_CATALOG_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
