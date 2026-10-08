extends SceneTree
## Rarity is cosmetic; verify actual surfaces and the pre-change identity/skill
## baseline, not just the existence of six labels in the catalog.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const Solid=preload("res://fidelity/shaders/solid_skin.gdshader")
const CommonSurface=preload("res://fidelity/common_surface.gdshader")
const Water=preload("res://fidelity/shaders/tide.gdshader")
const Accretion=preload("res://fidelity/shaders/accretion.gdshader")
const Flame=preload("res://fidelity/cinder_flame.gdshader")
const Aurora=preload("res://fidelity/shaders/aurora.gdshader")
var checks:=0
var failures:Array[String]=[]
var forms:Array[Dictionary]=[]

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func meshes(node:Node)->Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D:result.append(child)
		result.append_array(meshes(child))
	return result
func triangles(mesh:Mesh)->int:
	# Unused pooled render views have no mesh until an intake starts.
	if mesh==null:return 0
	var count:=0
	for i in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(i)
		count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	return count
func write_report(result:Dictionary)->bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var path:=argument.trim_prefix("--report=")
			if not path.is_absolute_path() or "://" in path:return false
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file==null:return false
			file.store_string(JSON.stringify(result,"\t")+"\n");file.flush()
			var ok:=file.get_error()==OK;file.close();return ok
	return true

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	check(Rarity.ORDER==["common","uncommon","rare","epic","legendary","prismatic"],"Six ordered rarity identifiers")
	check(Rarity.NAMES==["Common","Uncommon","Rare","Epic","Legendary","Prismatic"],"Six requested English labels")
	check(Rarity.BASE_WEIGHTS==[4500,2800,1600,800,250,50],"Base draw odds retain exact 45/28/16/8/2.5/0.5 percent integer units")
	var weight_sum:=0
	for i in Rarity.ORDER.size():
		var id:String=Rarity.ORDER[i]
		var metadata:Dictionary=Rarity.data(id)
		check(metadata.id==id and metadata.rank==i and Rarity.index_of(id)==i,"Ordered metadata lookup: "+id)
		check(metadata.name==Rarity.NAMES[i] and metadata.color==Rarity.COLORS[i] and metadata.base_weight>0,"Complete presentation and weight metadata: "+id)
		weight_sum+=int(metadata.base_weight)
		metadata.name="changed by consumer"
		check(Rarity.data(id).name==Rarity.NAMES[i],"Metadata lookup returns a fresh record: "+id)
	check(weight_sum==10000,"Integer base weights total exactly 100 percent")
	check(Rarity.index_of("missing")==-1 and Rarity.data("missing").is_empty() and Rarity.for_skin("missing").is_empty(),"Unknown identities cannot silently become Common or a valid reward")
	check(Rarity.COLORS[0].s<.15 and Rarity.COLORS[1].g>Rarity.COLORS[1].r and Rarity.COLORS[2].b>Rarity.COLORS[2].r,"First three badges read gray, green and blue")
	check(Rarity.COLORS[3].b>Rarity.COLORS[3].g and Rarity.COLORS[4].r>Rarity.COLORS[4].g and Rarity.COLORS[4].g>Rarity.COLORS[4].b,"Epic badge is purple; Legendary badge is orange")
	check(Rarity.RAINBOW_COLORS.size()>=6 and Rarity.RAINBOW_COLORS[0]!=Rarity.RAINBOW_COLORS[3],"Prismatic exposes a real multicolor palette")
	var identities:=PackedStringArray()
	var tiers:={"common":0,"uncommon":0,"rare":0,"epic":0,"legendary":0,"prismatic":0}
	var seen:={}
	var common_geometry:={}
	var common_ids:Array[String]=[]
	var model:=Visual.new();root.add_child(model);model.set_process(false)
	for d in Catalog.DEFS:
		var label:String=d.id
		if Catalog.DEFS.find(d)<44:identities.append("%s|%s|%d|%s|%d"%[d.id,d.group,int(d.legacy_score),d.kind,int(d.cooldown)])
		check(not seen.has(d.id),"Stable skin ID remains unique: "+label);seen[d.id]=true
		check(Rarity.index_of(d.rarity)>=0 and d.rarity==Rarity.for_skin(d.id),"Catalog and lookup assign the same rarity: "+label)
		tiers[d.rarity]+=1
		model.build(d,false)
		var all:=meshes(model);var visible_count:=0;var triangle_count:=0
		for m in all:
			if m.mesh==null:check(not m.visible,"An empty pooled view must stay hidden: "+label+" "+str(m.get_path()))
			if m.visible:visible_count+=1
			triangle_count+=triangles(m.mesh)
		check(model.get_meta("rarity")==d.rarity and model.visual_profile==Rarity.data(d.rarity).profile,"Runtime visual receives the rarity profile: "+label)
		check(model.mouth==null and model.find_children("*","CollisionObject3D",true,false).is_empty(),"Rarity does not add physics or cover gameplay mouth: "+label)
		check(model.find_children("*","GPUParticles3D",true,false).is_empty() and model.find_children("*","CPUParticles3D",true,false).is_empty(),"No unbounded particle emitters: "+label)
		check(all.size()<=18 and triangle_count<=4500,"Existing geometry budget is retained: "+label)
		if d.model_id in Visual.Common.IDS:
			if int(d.variant_index)==0:common_ids.append(d.id)
			check(is_instance_valid(model.common) and model.fx_family==d.model_id and model.model_id==d.model_id,"Common builds its authored model and bounded theme controller: "+label)
			var main_material:Material=model.main_ring.material_override
			if main_material==null and model.main_ring.mesh.get_surface_count()>0:main_material=model.main_ring.mesh.surface_get_material(0)
			var authored_lit:bool=main_material is ShaderMaterial and main_material.shader==CommonSurface
			for surface in model.main_ring.mesh.get_surface_count():
				var surface_material:Material=model.main_ring.mesh.surface_get_material(surface)
				authored_lit=authored_lit and surface_material is ShaderMaterial and surface_material.shader==CommonSurface
			check(authored_lit and model.skin_shader==CommonSurface,"Common uses authored lit materials on real mesh surfaces: "+label)
			check(d.kind=="cosmetic" and d.cooldown==0,"Common sculpture adds no gameplay ability: "+label)
			var geometry:Array=[]
			for part in all:
				if not part.visible or part.mesh==null:continue
				for surface in part.mesh.get_surface_count():
					var arrays:Array=part.mesh.surface_get_arrays(surface)
					geometry.append([model.global_transform.affine_inverse()*part.global_transform,arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX]])
			var signature:=var_to_bytes(geometry).hex_encode().sha256_text()
			if int(d.variant_index)==0:
				check(not common_geometry.values().has(signature),"Original authored object families differ without material colors: "+label)
				common_geometry[d.model_id]=signature
			else:check(common_geometry.get(d.model_id)==signature,"Palette variant preserves the exact authored family geometry: "+label)
		elif d.model_id in Visual.SIMPLE_MODELS:
			check(visible_count==2,"Existing trim family keeps its surface and trim: "+label)
			check(model.motes.is_empty() and model.parts.is_empty() and model.ornaments.get_child_count()==0,"Existing trim family retains no concealed motif or emitter: "+label)
			check(model.materials.size()==1 and model.materials[0].shader==Solid,"Existing trim family uses its existing surface shader: "+label)
			check(model.materials[0].get_shader_parameter("style")==1,"Trim family keeps the existing basic sheen: "+label)
			check(d.kind=="cosmetic" and d.cooldown==0,"Trim family does not advertise an ability: "+label)
			check(triangle_count<1800,"Existing trim family keeps its original triangle budget: "+label)
		else:
			check(model.fx_family not in ["solid_recolor","simple_trim"],"Higher rarity retains an actual sculpted/effect form: "+label)
		if d.id in ["core_shell","tide","cinder"]:
			check(d.rarity=="legendary","Signature black-hole, water and flame effects are Legendary: "+label)
		if d.id in ["tempest","rainfall"]:
			check(d.rarity==Rarity.ORDER.back() and model.rarity_id==Rarity.ORDER.back(),"Weather skin reaches the actual highest catalog and runtime tier: "+label)
			check(d.kind=="cosmetic" and d.cooldown==0.0 and d.legacy_score==2147483647,"Promotion never grants gameplay power or a legacy-score entitlement: "+label)
		if d.id=="core_shell":check(model.main_ring.material_override.shader==Accretion and model.main_ring.material_override.get_shader_parameter("core_blue")==1.0,"Core Shell keeps its blue accretion shader")
		if d.id=="tide":check(model.main_ring.material_override.shader==Water and model.motes.is_empty(),"Tide keeps continuous animated water rather than particles")
		if d.id=="cinder":check(model.motes.size()==10 and model.materials.any(func(mat):return mat.shader==Flame),"Cinder keeps its bounded flame ribbons and ten embers")
		if d.id=="prism_vale":check(d.rarity=="legendary" and model.materials.any(func(mat):return mat.shader==Aurora),"Prism Vale keeps its animated rainbow curtains")
		if d.id=="rainbow_bridge":check(d.rarity=="legendary" and model.main_ring.material_override.get_shader_parameter("style")==7,"Rainbow Bridge gains the animated multicolor surface")
		var count_before:=all.size();model._process(.35);model.flash();model._process(.2)
		check(model.wave.visible and meshes(model).size()==count_before,"Feedback reuses its bounded existing mesh: "+label)
		model._process(.8);check(not model.wave.visible,"Feedback retires normally: "+label)
		model.build(d,false)
		check(meshes(model).size()==count_before and model.effect_time==0.0 and not model.wave.visible,"Rebuild clears previous effects without accumulating nodes: "+label)
		forms.append({"id":d.id,"rarity":d.rarity,"family":model.fx_family,"visible_meshes":visible_count,"all_meshes":all.size(),"triangles":triangle_count,"sparks":model.motes.size()})
	check(tiers=={"common":40,"uncommon":60,"rare":48,"epic":28,"legendary":16,"prismatic":8},"Exactly two hundred skins use the authorized graded tier counts")
	check(common_geometry.size()==20 and common_ids.size()==20,"Twenty Common skins have distinct actual geometry, not palette-only variants")
	check(seen.size()==200 and Rarity.SKIN_TIERS.size()==200,"No legacy ID is dropped or replaced with a new unlock")
	check(Rarity.NEW_PLAYER_SKIN=="cocoa_square" and Rarity.for_skin(Rarity.NEW_PLAYER_SKIN)=="common","New-player default references an existing Common ID")
	var starter:Dictionary={}
	for d in Catalog.DEFS:
		if d.id==Rarity.NEW_PLAYER_SKIN:starter=d
	check(not starter.is_empty() and Color(starter.tint).s<.15 and starter.name=="Slate Ring","New-player visual is a clearly named gray base ring")
	# Generated from the preserved pre-edit catalog, covering IDs, groups, legacy
	# migration thresholds, skill kinds and cooldowns; never derived as expected
	# from the current catalog during this test.
	var identity_hash:="\n".join(identities).sha256_text()
	check(identity_hash=="1ac110ae13f762658a63741dd75912504aae98fc1caf4f637eccc11bc6663748","All existing identity, save-migration and gameplay fields match the pre-rarity catalog")
	model.free()
	var result:={"checks":checks,"failures":failures,"tiers":tiers,"identity_gameplay_sha256":identity_hash,"forms":forms,"scope":"Actual catalog/resources/lifecycle; no draw-economy, GPU, browser or phone-performance claim"}
	var report_ok:=write_report(result)
	print("SKIN_RARITY_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() and report_ok else 1)
