extends SceneTree
## Actual six-model finish/geometry/lifecycle checks; no renderer or phone claim.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const IDS:Array[String]=["pizza_party","frosted_cake","fox_den","bunny_burrow","rocket_port","dragon_roost"]
const REWORKED_COMMON:Array[String]=["cookie_bite","citrus_slice","melon_munch","pancake_stack","bacon_curl","cocoa_square"]
const REQUIRED:Dictionary={"pizza_party":["ToastedCrust","MeltedCheese","Pepperoni0","Basil0"],"frosted_cake":["BakedSponge","BerryFilling","ScallopedIcing","Strawberry0"],"fox_den":["FoxMask","FoxNose"],"bunny_burrow":["PorcelainBunny","BunnyNose"],"rocket_port":["RoundedRocket","SweptFinRight","PortholeGlass","EngineNozzle"],"dragon_roost":["DragonCoil","DragonWingRight","IvoryHornRight","SlitPupilRight"]}
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func all_meshes(node:Node)->Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D:result.append(child)
		result.append_array(all_meshes(child))
	return result
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var view:=SubViewport.new();view.size=Vector2i(144,106);root.add_child(view)
	var camera:=Camera3D.new();view.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.1;camera.position=Vector3(0,6.6,8);camera.look_at(Vector3(0,.14,0));camera.current=true
	var model:=Visual.new();view.add_child(model);model.set_process(false)
	var forms:Array=[];var fingerprints:={};var identities:=PackedStringArray()
	for definition in Catalog.DEFS:
		if Catalog.DEFS.find(definition)<44:identities.append("%s|%s|%d|%s|%d"%[definition.id,definition.group,int(definition.legacy_score),definition.kind,int(definition.cooldown)])
		if not definition.id in IDS:continue
		var id:String=definition.id;model.build(definition,false)
		check(definition.rarity==("epic" if id in ["rocket_port","dragon_roost"] else "rare") and definition.kind=="cosmetic" and definition.cooldown==0,"Original rarity and cosmetic strength: "+id)
		check(model.get_meta("polish_revision",0)==1 and model.motes.is_empty() and model.parts.is_empty(),"Sculpted, static finish without a particle payload: "+id)
		check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"Polish adds no physics: "+id)
		for name in REQUIRED[id]:check(model.ornaments.has_node(NodePath(name)),"Recognizable authored part exists: "+id+"/"+name)
		var triangle_count:=0;var lit:=0;var data:=PackedVector3Array();var min_radius:=INF;var degenerate:=0;var bad_normals:=0;var inside_out:=0;var unclosed:=0
		var all:=all_meshes(model)
		for part in all:
			if part.get_meta("sculpted",false):
				lit+=1;var mat:StandardMaterial3D=part.material_override
				check(mat.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and mat.roughness>=.16 and mat.roughness<=.5 and mat.metallic_specular>=.5,"Real per-pixel material and broad bounded highlight: "+id+"/"+part.name)
				check(mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_texture==null and mat.normal_texture==null,"Opaque texture-free sculpt: "+id+"/"+part.name)
				check(part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Decoration does not darken the swallow opening: "+id+"/"+part.name)
			for surface in part.mesh.get_surface_count():
				var arrays:Array=part.mesh.surface_get_arrays(surface);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var ix:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				triangle_count+=(ix.size() if not ix.is_empty() else vs.size())/3
				if not part.visible:continue
				var volume:=0.0;var edges:={}
				for i in range(0,ix.size() if not ix.is_empty() else vs.size(),3):
					var local:Array[Vector3]=[];var projected:=PackedVector2Array()
					for c in 3:
						var index:int=ix[i+c] if not ix.is_empty() else i+c
						var v:Vector3=vs[index];local.append(v);var p:Vector3=part.global_transform*v;data.append(p)
						projected.append(Vector2(p.x,p.z))
						if not v.is_finite() or absf(ns[index].length()-1)>.001:bad_normals+=1
					if (local[1]-local[0]).cross(local[2]-local[0]).length_squared()<1e-14:degenerate+=1
					volume+=local[0].dot(local[1].cross(local[2]))/6.0
					for side in 3:
						min_radius=minf(min_radius,Geometry2D.get_closest_point_to_segment(Vector2.ZERO,projected[side],projected[(side+1)%3]).length())
						var ends:Array[String]=[str(local[side].snapped(Vector3.ONE*.00001)),str(local[(side+1)%3].snapped(Vector3.ONE*.00001))];ends.sort();var key:String=ends[0]+"/"+ends[1];edges[key]=int(edges.get(key,0))+1
					if Geometry2D.is_point_in_polygon(Vector2.ZERO,projected):min_radius=0
				if part.get_meta("sculpted",false):
					if volume>=-.000001:inside_out+=1
					if edges.values().any(func(n):return n!=2):unclosed+=1
		check(degenerate==0 and bad_normals==0 and inside_out==0 and unclosed==0,"Finite normalized, outward closed sculptures with no degenerate triangles: "+id)
		check(lit>=8 and all.size()<=18 and triangle_count<=4500,"Whole skin including reusable boost remains inside original budget: "+id)
		check(min_radius>=.70,"Actual triangles leave original 70-percent-radius opening clear: "+id)
		var smallest_margin:=INF
		for angle in 36:
			model.rotation.y=TAU*angle/36.0;var fits:=true
			for p in data:
				var px:Vector2=camera.unproject_position(model.transform*p)
				smallest_margin=minf(smallest_margin,minf(minf(px.x,144-px.x),minf(px.y,106-px.y)))
				if not Rect2(4,4,136,98).has_point(px):fits=false
			check(fits,"Every real vertex fits rotating 144x106 collection card: %s yaw%d"%[id,angle*10])
		model.rotation.y=0
		var signature:=var_to_bytes(data).hex_encode().sha256_text()
		check(not fingerprints.has(signature),"Six true geometry families, independent of palette: "+id);fingerprints[signature]=id
		var nodes:int=all.size();model._process(.5);model.flash();model._process(.2)
		check(all_meshes(model).size()==nodes and model.wave.visible,"Animation/feedback reuses bounded geometry: "+id)
		model.build(definition,false);check(all_meshes(model).size()==nodes and model.effect_time==0 and not model.wave.visible,"Rebuild clears old state: "+id)
		forms.append({"id":id,"all_meshes":nodes,"lit_parts":lit,"triangles":triangle_count,"minimum_card_margin_pixels":smallest_margin,"minimum_mouth_radius":min_radius,"geometry_sha256":signature})
	check(fingerprints.size()==6,"Exactly six requested existing forms are rebuilt")
	check("\n".join(identities).sha256_text()=="1ac110ae13f762658a63741dd75912504aae98fc1caf4f637eccc11bc6663748","All 44 identity/migration/gameplay fields remain unchanged")
	for definition in Catalog.DEFS:
		if definition.model_id not in Visual.SIMPLE_MODELS:continue
		model.build(definition,false)
		check(not model.has_meta("polish_revision") and model.ornaments.get_child_count()==0 and model.motes.is_empty(),"Existing trim families remain intentionally simple after regrading after polished rebuild: "+str(definition.id))
	for definition in Catalog.DEFS:
		if not REWORKED_COMMON.has(definition.id):continue
		model.build(definition,false)
		check(is_instance_valid(model.common) and model.common.skin_id==definition.id and model.fx_family==definition.id and model.main_ring.mesh is ArrayMesh and model.main_ring.get_meta("sculpted",false) and model.main_ring.mesh.get_surface_count()>=3 and not model.has_meta("polish_revision"),"Original Common identity now builds its own authored batched sculpture without stale high-tier polish state: "+str(definition.id))
	view.free()
	var result:={"checks":checks,"failures":failures,"forms":forms,"scope":"Actual geometry/material properties, 36-yaw projection and lifecycle; no game capture or device frame-rate claim"}
	var report_ok:=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:=arg.trim_prefix("--report=")
			if not path.is_absolute_path() or "://" in path:report_ok=false;continue
			var f:=FileAccess.open(path,FileAccess.WRITE)
			if f==null:report_ok=false;continue
			f.store_string(JSON.stringify(result,"\t")+"\n");f.close()
	print("SKIN_POLISH_ACCEPTANCE "+JSON.stringify(result));quit(0 if failures.is_empty() and report_ok else 1)
