extends SceneTree
## Validate shipped geometry, motion and preview/player parity, not mote counts.
const SkinVisual=preload("res://fidelity/skin_visual.gd")
const Game=preload("res://fidelity/game.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func meshes(node:Node) -> Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D:result.append(child)
		result.append_array(meshes(child))
	return result
func run() -> void:
	var families:={}
	for definition in Game.SKIN_DEFS:
		var preview:=SkinVisual.new();root.add_child(preview);preview.build(definition,true)
		var player:=SkinVisual.new();root.add_child(player);player.build(definition,false)
		preview.set_process(false);player.set_process(false)
		var rendered:=meshes(player)
		var main_material:Material=player.main_ring.material_override
		if main_material==null and player.main_ring.mesh.get_surface_count()>0:main_material=player.main_ring.mesh.surface_get_material(0)
		check(player.skin_id==definition.id and is_instance_valid(player.main_ring) and main_material!=null,"Actual render material and skin identity: "+definition.id)
		check(player.mouth==null and preview.mouth!=null,"Only the menu adds a flat mouth: "+definition.id)
		check(meshes(preview).size()==rendered.size()+1 and preview.fx_family==player.fx_family,"Same preview/player geometry: "+definition.id)
		check(rendered.all(func(m:MeshInstance3D):return not m.mesh is SphereMesh),"No orbiting sphere template: "+definition.id)
		check(player.find_children("*","CollisionObject3D",true,false).is_empty(),"Visuals cannot alter swallowing physics: "+definition.id)
		var triangles:=0
		for mesh in rendered:
			if mesh.mesh==null:
				check(not mesh.visible,"Empty pooled view stays hidden: "+definition.id);continue
			for i in mesh.mesh.get_surface_count():
				var arrays:Array=mesh.mesh.surface_get_arrays(i)
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
		check(rendered.size()<=18 and triangles<=4500,"Bounded skin geometry budget: "+definition.id)
		player._process(.5)
		for mat in player.materials:check(is_equal_approx(float(mat.get_shader_parameter("fx_time")),.5),"Shader clock advances: "+definition.id)
		if definition.model_id in ["tide","core_shell","orbit"]:
			check(player.motes.is_empty(),"Water and black holes have continuous surfaces: "+definition.id)
			var arrays:Array=player.main_ring.mesh.surface_get_arrays(0)
			var minimum:=10.0
			for vertex in arrays[Mesh.ARRAY_VERTEX]:minimum=minf(minimum,Vector2(vertex.x,vertex.z).length())
			check(minimum>=.985,"No effect surface covers the swallowing opening: "+definition.id)
		if definition.model_id=="cinder":
			var before:=player.motes[0].position
			player._process(.1)
			check(player.motes[0].position.y>before.y and Vector2(player.motes[0].position.x,player.motes[0].position.z).distance_to(Vector2(before.x,before.z))<.04,"Embers rise instead of orbiting")
		if definition.model_id=="moss_bloom":
			var before:float=player.parts[0].rotation.x
			player._process(.3)
			check(not is_equal_approx(before,player.parts[0].rotation.x) and player.ornaments.rotation==Vector3.ZERO,"Leaves bend locally without spinning the assembly")
		player.flash();player._process(.2);check(player.wave.visible,"Skill feedback appears: "+definition.id)
		player._process(.8);check(not player.wave.visible,"Skill feedback retires: "+definition.id)
		families[player.fx_family]=true
		metrics.append({"id":definition.id,"family":player.fx_family,"draw_meshes":rendered.size(),"triangles":triangles,"sparks":player.motes.size()})
		preview.free();player.free()
	check(families.size()==61,"Sixty-eight model IDs resolve to sixty-one effect families; the eight original trim IDs intentionally share one family")
	var result:={"checks":checks,"failures":failures,"skins":metrics}
	print("SKIN_FX_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
