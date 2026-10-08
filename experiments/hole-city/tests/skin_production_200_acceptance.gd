extends SceneTree
## Exact catalog, variant resource isolation and actual GPU callback acceptance.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func material_fingerprint(mat:Material)->String:
	if mat==null:return "none"
	if mat is StandardMaterial3D:return str([mat.albedo_color,mat.roughness,mat.metallic,mat.emission,mat.vertex_color_use_as_albedo])
	if mat is ShaderMaterial:
		var values:Array=[]
		for u in mat.shader.get_shader_uniform_list():
			var value=mat.get_shader_parameter(u.name)
			if value is Color or value is float or value is int:values.append([u.name,value])
		return str([mat.shader.code,values])
	return mat.get_class()
func model_fingerprint(model:Node)->String:
	var result:Array=[]
	var nodes:Array[Node]=[model]
	while not nodes.is_empty():
		var n:Node=nodes.pop_back();nodes.append_array(n.get_children())
		if n is MeshInstance3D:
			result.append(material_fingerprint(n.material_override))
			if n.mesh!=null:
				for i in n.mesh.get_surface_count():result.append(material_fingerprint(n.mesh.surface_get_material(i)))
	return str(result).sha256_text()
func triangle_count(model:Node)->int:
	var count:=0
	var nodes:Array[Node]=[model]
	while not nodes.is_empty():
		var n:Node=nodes.pop_back();nodes.append_array(n.get_children())
		var mesh:Mesh;var instances:=1
		if n is MeshInstance3D:mesh=n.mesh
		elif n is MultiMeshInstance3D and n.multimesh!=null:mesh=n.multimesh.mesh;instances=n.multimesh.instance_count
		if mesh==null:continue
		for i in mesh.get_surface_count():
			var a:Array=mesh.surface_get_arrays(i)
			count+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and not a[Mesh.ARRAY_INDEX].is_empty() else a[Mesh.ARRAY_VERTEX].size())/3*instances
	return count
func controller(s:Node3D)->Node3D:
	if is_instance_valid(s.common):return s.common
	if is_instance_valid(s.collection):return s.collection
	if is_instance_valid(s.tempest):return s.tempest
	return s.rainfall
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	check(DisplayServer.get_name()!="headless","Real GPU display required")
	check(Catalog.DEFS.size()==200,"Exactly200 equipped catalog entries")
	var counts:Dictionary={};var ids:Dictionary={};var families:Dictionary={}
	for definition in Catalog.DEFS:
		check(not ids.has(definition.id),"Unique owned identity: "+definition.id);ids[definition.id]=true
		check(Rarity.for_skin(definition.id)==definition.rarity,"Registry tier agrees: "+definition.id)
		counts[definition.rarity]=int(counts.get(definition.rarity,0))+1
		if not families.has(definition.model_id):families[definition.model_id]=[]
		families[definition.model_id].append(definition)
	check(counts=={"common":40,"uncommon":60,"rare":48,"epic":28,"legendary":16,"prismatic":8},"Exact graded tier allocation")
	check(families.size()==68,"68 named model families including intentional colorvariants")
	for family in families:
		var definitions:Array=families[family]
		var base:Node3D=Visual.new();root.add_child(base);base.build(definitions[0],true);base.set_process(false)
		var original:=model_fingerprint(base)
		var appearances:Dictionary={}
		for definition in definitions:
			var skin:Node3D=Visual.new();root.add_child(skin);skin.build(definition,true);skin.set_process(false)
			var actor:Node3D=controller(skin)
			check(skin.skin_id==definition.id and skin.model_id==family,"Owned ID is separate from renderer family: "+definition.id)
			check(is_instance_valid(actor),"Every skin has cosmetic item/rival controller: "+definition.id)
			check(is_instance_valid(skin.main_ring) and skin.main_ring.mesh!=null,"Actual runtime mesh: "+definition.id)
			check(not skin.find_children("*","CollisionObject3D",true,false).size(),"No cosmetic physics bodies: "+definition.id)
			var signature:=model_fingerprint(skin)
			check(not appearances.has(signature),"Family variants have different actual materials: "+definition.id)
			appearances[signature]=true
			check(model_fingerprint(base)==original,"Sibling never recolors base resources: "+definition.id)
			var tris:=triangle_count(skin)
			check(tris>0 and tris<=8000,"Complete model and reservedFX triangle ceiling: "+definition.id)
			var items:int=int(actor.get("item_events")) if actor.get("item_events")!=null else int(actor.get("object_events"))
			var rivals:int=int(actor.get("rival_events"))
			skin.absorb_object()
			check((int(actor.get("item_events")) if actor.get("item_events")!=null else int(actor.get("object_events")))==items+1,"One item callback: "+definition.id)
			check(skin.absorb_rival(Color("da789c")),"Dedicated rival effect handles event: "+definition.id)
			check(int(actor.get("rival_events"))==rivals+1,"One rival callback: "+definition.id)
			skin._process(.18)
			if is_instance_valid(skin.collection) or is_instance_valid(skin.common):
				check(actor.active_count>=4 and actor.rival_active,"Visible stronger rival pool: "+definition.id)
				var count:int=actor.active_count
				skin.absorb_object()
				check(actor.active_count==count and actor.rival_active,"Item cannot erase rival feedback: "+definition.id)
				for i in 20:skin._process(.1)
				check(actor.active_count==0 and actor.particles.multimesh.visible_instance_count==0,"Feedback retires without node creation: "+definition.id)
			else:
				for i in 20:skin._process(.1)
				check(actor.rival_energy==0.0,"Weather rival energy retires: "+definition.id)
			for _f in 2:await process_frame;await RenderingServer.frame_post_draw
			rows.append({"id":definition.id,"family":family,"tier":definition.rarity,"material_sha256":signature,"triangle_capacity":tris,"controller":actor.get_script().resource_path})
			skin.free();await process_frame
		base.free();await process_frame
	var result:={"checks":checks,"failures":failures,"tiers":counts,"families":families.size(),"skins":rows,"scope":"ActualGPU model/material isolation and feedback events; --test, noGame/Save/commerce. Renderedart and fullgameplay evaluated separately."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:String=arg.trim_prefix("--report=")
			assert(path.is_absolute_path() and not FileAccess.file_exists(path))
			FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("SKIN_PRODUCTION_200_ACCEPTANCE "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
