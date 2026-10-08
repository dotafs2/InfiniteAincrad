extends SceneTree
## Non-author semantic, material and actual-house obstruction review.
class Fixture:
	extends RigidBody3D
	var category:="building"
	var half_size:=Vector3.ONE
	var height:=2.0
	var consumed:=false
	var claimed_by:Node3D
var game:Node3D
var fixtures:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(size:Vector3,category:="building",opt_in:=true)->Fixture:
	var body:=Fixture.new();body.category=category;body.half_size=size*.5;body.height=size.y
	body.freeze=true;body.collision_layer=0;body.collision_mask=0
	if opt_in:body.set_meta("dither_building",true)
	fixtures.add_child(body)
	return body
func shader_weight(material:Material)->float:
	if not material is ShaderMaterial:return 0.0
	var value:Variant=material.get_shader_parameter("reveal_occluder")
	return float(value) if value!=null else 0.0
func meshes(body:Node3D)->Array:
	return body.find_children("*","MeshInstance3D",true,false)
func snapshot(body:Node3D)->Dictionary:
	return {"pose":body.transform,"freeze":body.freeze,"layer":body.collision_layer,"mask":body.collision_mask,"mass":body.mass,"linear":body.linear_velocity,"angular":body.angular_velocity}
func policy()->void:
	var reveal:RefCounted=game.reveal
	check(is_equal_approx(reveal.dither_min_height,3.0) and is_equal_approx(reveal.dither_min_width,2.4),"Declared default building thresholds are three metres high and 2.4 metres maximum horizontal extent")
	var cases:=[
		{"size":Vector3(2.4,3.0,.2),"expected":true,"label":"Explicitly authored thin building component exactly at threshold"},
		{"size":Vector3(.2,3.0,2.4),"expected":true,"label":"Depth may supply the declared maximum-horizontal-width threshold"},
		{"size":Vector3(2.4,2.999,.2),"expected":false,"label":"Just below individual height"},
		{"size":Vector3(2.399,3.0,2.399),"expected":false,"label":"Just below both horizontal extents"},
		{"size":Vector3(8,4,.2),"expected":true,"label":"Thin walls require explicit building opt-in but no invented depth threshold"}]
	for row in cases:
		var body:=fixture(row.size)
		check(reveal.is_structural_candidate(body)==row.expected,row.label)
	var absent:=fixture(Vector3(20,20,20),"building",false)
	check(not reveal.is_structural_candidate(absent),"A generic building category without author opt-in cannot reveal")
	absent.set_meta("dither_building",false)
	check(not reveal.is_structural_candidate(absent),"An explicit false opt-in cannot reveal")
	for category in ["tree","sign","vehicle","person","authored_actor","building_fragment","food_cake"]:
		var wrong:=fixture(Vector3(20,20,20),category,true)
		check(not reveal.is_structural_candidate(wrong),"Oversized "+category+" is excluded even if it carries the building opt-in")
	for metadata in ["food_kind","food_building","building_fragment"]:
		var spoof:=fixture(Vector3(20,20,20))
		spoof.set_meta(metadata,"cake" if metadata=="food_kind" else true)
		check(not reveal.is_structural_candidate(spoof),"Spoofed building identity cannot override "+metadata)
	var empty_kind:=fixture(Vector3(20,20,20));empty_kind.set_meta("food_kind","")
	check(not reveal.is_structural_candidate(empty_kind),"Even an empty food-kind marker excludes food from the building route")
	var scaled:=fixture(Vector3(1.2,1.5,.1));scaled.scale=Vector3(2,2,2)
	check(reveal.is_structural_candidate(scaled),"Uniform scale is included in the individual's actual dimensions")
	scaled.scale.y=1.99
	check(not reveal.is_structural_candidate(scaled),"Below-threshold scaled height stays opaque")
	scaled.scale=Vector3(2,2,2);scaled.rotation=Vector3(.45,.8,.2)
	check(reveal.is_structural_candidate(scaled),"Rotation does not invent a new size threshold")
	var reflected:=fixture(Vector3(2.4,3,.2));reflected.scale=Vector3(-1,1,1)
	check(reveal.is_structural_candidate(reflected),"Reflected geometry uses magnitude rather than negative dimensions")
	var parent:=Node3D.new();fixtures.add_child(parent);parent.scale=Vector3(2,2,2)
	var inherited:=fixture(Vector3(1.2,1.5,.1));inherited.reparent(parent,false)
	check(reveal.is_structural_candidate(inherited),"Inherited global scale participates in building size")
	var lying_height:=fixture(Vector3(4,.4,4));lying_height.height=100
	lying_height.set_meta("structure_height",100);lying_height.set_meta("structure_width",100)
	check(not reveal.is_structural_candidate(lying_height),"An individual thin piece cannot borrow declared group height or a stale height field")
	var adjustable:=fixture(Vector3(4,4,4));reveal.dither_min_height=4.01
	check(not reveal.is_structural_candidate(adjustable),"The configurable height threshold is effective")
	reveal.dither_min_height=3.0;reveal.dither_min_width=4.01
	check(not reveal.is_structural_candidate(adjustable),"The configurable width threshold is effective")
	reveal.dither_min_width=2.4
	check(reveal.is_structural_candidate(adjustable),"Restoring defaults restores legitimate building eligibility")
func actual_catalog()->void:
	var buildings:=0;var other_bodies:=0;var wrongly_opted:=[];var wrong_materials:=[]
	for body in game.city.foods:
		if body.category=="building":
			buildings+=1
			check(body.get_meta("catalog_group","")=="building" and body.get_meta("dither_building",false) and game.reveal.is_structural_candidate(body),str(body.get_meta("asset_id"))+": real catalog house has both building provenance and explicit opt-in")
			check(game.reveal.entries.has(body.get_instance_id()),str(body.get_meta("asset_id"))+": real house is registered for material control")
		else:
			other_bodies+=1
			if body.get_meta("dither_building",false) or game.reveal.is_structural_candidate(body) or game.reveal.entries.has(body.get_instance_id()):wrongly_opted.append(str(body.name))
			for mesh in meshes(body):
				if shader_weight(mesh.material_override)!=0.0:wrong_materials.append(str(body.name))
	check(buildings==48 and other_bodies>500,"Actual full city exercises all 48 buildings and hundreds of ordinary physics owners")
	check(wrongly_opted.is_empty() and wrong_materials.is_empty(),"No actual city prop, actor or traffic body receives building eligibility or a nonzero dither material")
	check(game.reveal.entries.size()==48,"Only the 48 catalog buildings are initially registered")
	metrics["actual_city"]={"buildings":buildings,"other_bodies":other_bodies,"wrongly_opted":wrongly_opted,"wrong_materials":wrong_materials}
	var ids:=["159_palm_03","160_palm_04","164_birch_04","168_maple_04","172_oak_04"]
	var negative_entries:Array=[]
	for id in ids:negative_entries.append(game.city.catalog.filter(func(entry):return entry.id==id)[0])
	for kind in ["sign","vehicle","person"]:
		negative_entries.append(game.city.catalog.filter(func(entry):return entry.kind==kind or entry.group==kind)[0])
	var negatives:Array[Node3D]=[]
	for entry in negative_entries:
		var body:Node3D=game.city.place(entry,Vector2(70,16))
		var size:Vector3=body.half_size*2.0
		body.scale=Vector3.ONE*maxf(1.0,maxf(4.0/size.y,4.0/maxf(size.x,size.z)))
		negatives.append(body)
		check(not game.reveal.is_structural_candidate(body),entry.id+": real oversized nonbuilding mesh is excluded")
		check(meshes(body).all(func(mesh):return mesh.material_override is StandardMaterial3D),entry.id+": original ordinary material stays intact")
	var actor:Node3D=game.city.recipe_actors[0].body
	var original_scale:Vector3=actor.scale;actor.scale=Vector3.ONE*12
	check(not game.reveal.is_structural_candidate(actor),"Actual oversized recipe actor is excluded")
	actor.scale=original_scale
	game.reveal.bind_city(game.city)
	check(game.reveal.entries.size()==48,"Registering again cannot admit oversized ordinary props or duplicate houses")
	for body in negatives:body.free()
func real_food_spoof()->void:
	var food_city:Node3D=load("res://fidelity/food_city.gd").new();game.add_child(food_city);food_city.game=game
	var food:Node3D=food_city.food("cake",Vector2(70,16),4.0,3,true)
	food.category="building";food.set_meta("dither_building",true);food.set_meta("food_building",true)
	food.set_meta("structure_height",100);food.set_meta("structure_width",100)
	check(not game.reveal.is_structural_candidate(food),"A real oversized cake building cannot spoof a city building")
	game.reveal.bind_city(food_city)
	check(not game.reveal.entries.has(food.get_instance_id()),"Actual food is absent from registered dither entries")
	food.set_reveal_weight(1.0)
	check(food.reveal_weight==0.0,"Actual food body rejects a nonzero dither setter")
	check(not "discard" in food_city.food_material.shader.code and not "hole_reveal_mask" in food_city.food_material.shader.code,"Food shader contains no discard or reveal-mask execution path")
	food_city.free()
func actual_obstruction()->void:
	var body:Node3D=game.city.building_visuals[0].body
	body.position=Vector3(70,body.half_size.y+.025,16);body.rotation=Vector3.ZERO
	game.player.position=Vector3(70,0,10);game.player.radius=1.2;game.player.velocity=Vector3.ZERO
	game.camera.position=Vector3(70,18,32);game.camera.look_at(game.player.position)
	var physics_before:=snapshot(body)
	var material:ShaderMaterial=meshes(body)[0].material_override
	var tint:Color=material.get_shader_parameter("building_tint")
	game.reveal.tick(game.camera,game.player,1.0,true)
	check(game.reveal.blocks_core(body,game.camera,game.player) and game.reveal.body_reveal_weight(body)>.99,"Actual catalog-house triangles obstruct the real mouth and receive reveal weight")
	check(shader_weight(material)>.99,"Actual obstruction reaches the house's actual render material")
	check(snapshot(body)==physics_before and material.get_shader_parameter("building_tint")==tint,"Revealing preserves the original building physics, pose and color")
	body.position.x=85;game.reveal.tick(game.camera,game.player,1.0,true)
	check(not game.reveal.blocks_core(body,game.camera,game.player) and shader_weight(material)==0,"An actual house outside the view path remains opaque")
	body.position=Vector3(70,body.half_size.y+.025,-1);game.reveal.tick(game.camera,game.player,1.0,true)
	check(not game.reveal.blocks_core(body,game.camera,game.player) and shader_weight(material)==0,"An actual house behind the player remains opaque")
	body.position=Vector3(70,body.half_size.y+.025,16);game.update_reveal(1)
	var saved_weight:=shader_weight(material);var saved_target:Vector4=game.reveal.target
	game.toggle_pause();game.update_reveal(1)
	check(saved_weight>.99 and shader_weight(material)==saved_weight and game.reveal.target==saved_target,"Pause preserves the real building's current reveal backdrop")
	game.toggle_pause();body.freeze=false;game.update_reveal(.016)
	check(shader_weight(material)==0,"A physically released building immediately becomes opaque")
	body.freeze=true;game.update_reveal(1);body.claimed_by=game.player;game.update_reveal(.016)
	check(shader_weight(material)==0,"A claimed building immediately becomes opaque before fracture")
	body.claimed_by=null;game.update_reveal(1);game.player.active=false;game.update_reveal(.016)
	check(shader_weight(material)==0 and game.reveal.target.w==0,"Inactive player clears building weight and aperture")
	game.player.active=true;game.update_reveal(1)
	var parent_name:String=body.name;body.fracture_building(game.player)
	var pieces:=0
	for piece in game.city.foods:
		if is_instance_valid(piece) and piece.get_meta("fracture_parent","")==parent_name:
			pieces+=1;piece.freeze=true;piece.set_physics_process(false)
			piece.set_meta("dither_building",true)
			check(not game.reveal.is_structural_candidate(piece) and meshes(piece).all(func(mesh):return shader_weight(mesh.material_override)==0),"Actual cached facade fragment cannot inherit building dither")
	check(pieces==16,"Actual fracture branch produces sixteen independently checked opaque pieces")
	game.back_home();game.set_process(true)
	for i in 8:await process_frame
	check(game.phase=="title" and not is_instance_valid(game.player) and game.reveal.target.w==0,"Return home naturally clears stale-player dither state")
	metrics["actual_fracture_pieces"]=pieces
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for hole in game.holes:hole.enabled=false
	fixtures=Node3D.new();game.add_child(fixtures)
	policy();actual_catalog();real_food_spoof();await actual_obstruction()
	print("BUILDING_ONLY_REVEAL_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Non-author real catalog/material/mesh obstruction and strict semantic/size/lifecycle policy. Synthetic thresholds are identified; no browser image or device-performance claim."}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
