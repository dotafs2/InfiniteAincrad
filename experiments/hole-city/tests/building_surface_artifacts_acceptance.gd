extends SceneTree
## Runtime whole-building regression checks. Historical precuts remain resources,
## but they are never the geometry or collision oracle for a falling building.
const City=preload("res://fidelity/catalog_city.gd")
const Cache=preload("res://fidelity/fracture_cache.gd")
class Collector:
	extends Node
	var city:Node3D
	var notice:=""
	var notice_time:=0.0
	var receipts:Dictionary={}
	func collect(body:Node3D,_hole:Node3D)->void:
		var id:int=body.get_instance_id()
		var result:Dictionary=receipts.get(id,{"calls":0,"points":0})
		result.calls+=1;result.points+=body.points;receipts[id]=result
class Mouth:
	extends Node3D
	var radius:=1000.0
var checks:=0
var failures:Array[String]=[]
var buildings:Array[Dictionary]=[]
var collector:Collector
var prop_entry:Dictionary

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func receipt(body_id:int)->Dictionary:
	return collector.receipts.get(body_id,{"calls":0,"points":0})
func visuals(body:Node3D)->Array[Dictionary]:
	var rows:Array[Dictionary]=[]
	for node in body.find_children("*","MeshInstance3D",true,false):
		var view:MeshInstance3D=node
		var active:Array=[];var arrays:Array=[]
		if view.mesh!=null:
			for surface in view.mesh.get_surface_count():
				active.append(view.get_active_material(surface))
				arrays.append(view.mesh.surface_get_arrays(surface).duplicate(true))
		rows.append({"node":view,"mesh":view.mesh,"local":view.transform,"global":view.global_transform,"material":view.material_override,"active":active,"arrays":arrays,"visible":view.visible})
	return rows
func colliders(body:Node3D)->Array[Dictionary]:
	var rows:Array[Dictionary]=[]
	for node in body.find_children("*","CollisionShape3D",true,false):
		var shape:CollisionShape3D=node
		rows.append({"node":shape,"shape":shape.shape,"pose":shape.transform,"disabled":shape.disabled,"size":shape.shape.size if shape.shape is BoxShape3D else Vector3.ZERO})
	return rows
func physical_state(body:Node3D)->Dictionary:
	return {"pose":body.global_transform,"layer":body.collision_layer,"mask":body.collision_mask,"mass":body.mass,"linear":body.linear_velocity,"angular":body.angular_velocity,"gravity":body.gravity_scale,"locked":body.lock_rotation,"freeze":body.freeze,"extent":body.half_size,"height":body.height,"footprint":body.footprint,"surface":body.physics_material_override}
func same_visuals(before:Array[Dictionary],body:Node3D,part:String)->bool:
	var after:Array[Dictionary]=visuals(body)
	if before.size()!=after.size():return false
	for index in before.size():
		var a:Dictionary=before[index];var b:Dictionary=after[index]
		if a.node!=b.node:return false
		if part=="geometry" and (a.mesh!=b.mesh or a.arrays!=b.arrays):return false
		if part=="materials" and (a.material!=b.material or a.active!=b.active):return false
		if part=="pose" and (a.local!=b.local or a.global!=b.global or a.visible!=b.visible):return false
	return true
func cache_snapshot(cache:Resource)->Dictionary:
	if cache==null:return {}
	var arrays:Array=[]
	for mesh in cache.meshes:
		var surfaces:Array=[]
		if mesh!=null:
			for surface in mesh.get_surface_count():surfaces.append(mesh.surface_get_arrays(surface).duplicate(true))
		arrays.append(surfaces)
	return {"cells":cache.cells.duplicate(),"meshes":cache.meshes.duplicate(),"arrays":arrays,"counts":cache.exterior_vertex_counts.duplicate()}
func fragments(city:Node3D)->int:
	var count:=0
	for child in city.get_children():
		if child is Node3D and (child.get_meta("building_fragment",false) or child.get_meta("fracture_parent","")!="" or ("category" in child and child.category=="building_fragment")):count+=1
	return count
func new_city(world:Node3D)->Node3D:
	var city:=City.new();city.game=collector;world.add_child(city);city.read_catalog()
	city.set_process(false);city.set_physics_process(false);collector.city=city
	return city
func collapse_case(city:Node3D,entry:Dictionary,hole:Mouth,mode:String,label:String)->void:
	var body:Node3D=city.place(entry,Vector2.ZERO,.43)
	var body_id:int=body.get_instance_id()
	var original_cache:Resource=body.fracture_cache
	check(original_cache!=null and original_cache.cells.size()==16,label+": the preserved historical cache is available")
	if mode=="missing":body.fracture_cache=null
	elif mode=="incomplete":
		var incomplete:=Cache.new()
		if original_cache!=null:
			incomplete.cells=original_cache.cells.duplicate()
			incomplete.meshes=original_cache.meshes.duplicate()
			incomplete.exterior_vertex_counts=original_cache.exterior_vertex_counts.duplicate()
			incomplete.meshes[7]=null
		check(incomplete.exterior_mesh(7)==null,label+": a missing legacy mesh remains a safe historical fallback")
		body.fracture_cache=incomplete
	var cache_before:Dictionary=cache_snapshot(body.fracture_cache)
	var cache_ref:Resource=body.fracture_cache
	var material:ShaderMaterial=body.fracture_material
	material.set_shader_parameter("visibility",.4);material.set_shader_parameter("reveal_occluder",.8)
	check(body.begin_swallow(hole),label+": the real size gate admits the complete building")
	body.set_physics_process(false)
	check(material.get_shader_parameter("visibility")==1.0 and material.get_shader_parameter("reveal_occluder")==0.0,label+": admission clears the actual reveal material before any frame")
	check(body.points==48 and receipt(body_id).calls==0,label+": admission reserves 48 points without awarding them")
	body.rotation=Vector3(.12,.43,-.09)
	body.linear_velocity=Vector3(.31,-.72,-.19);body.angular_velocity=Vector3(.08,.13,-.05)
	var item:Node3D=city.place(prop_entry,Vector2.ZERO)
	item.support_parent=body;body.contents.append(item)
	var item_pose:Transform3D=item.global_transform
	var before:Array[Dictionary]=visuals(body);var shapes:Array[Dictionary]=colliders(body)
	var physics:Dictionary=physical_state(body)
	var tint:Variant=material.get_shader_parameter("building_tint")
	var amount:Variant=material.get_shader_parameter("tint_amount")
	check(not before.is_empty() and not shapes.is_empty(),label+": checks use actual imported geometry and collision")
	material.set_shader_parameter("visibility",.3);material.set_shader_parameter("reveal_occluder",1.0)
	body.fracture_building(hole)
	check(body.fractured and body.fracture_piece_count==0 and fragments(city)==0,label+": collapse never creates facade patches or replacement boxes")
	check(body.visible and not body.consumed and not body.is_queued_for_deletion(),label+": the original complete building remains the falling body")
	check(same_visuals(before,body,"geometry"),label+": every original mesh and all surface attributes remain intact")
	check(same_visuals(before,body,"materials"),label+": original material resources remain attached to every surface")
	check(same_visuals(before,body,"pose"),label+": every original local and world mesh pose remains unchanged")
	check(colliders(body)==shapes,label+": original collision shapes, dimensions and local poses remain unchanged")
	check(physical_state(body)==physics,label+": collapse preserves actual body pose, collision, mass and velocities")
	check(material.get_shader_parameter("building_tint")==tint and material.get_shader_parameter("tint_amount")==amount,label+": collapse preserves the placed building's own tint")
	check(material.get_shader_parameter("visibility")==1.0 and material.get_shader_parameter("reveal_occluder")==0.0,label+": even stale reveal state clears synchronously at collapse")
	check(body.fracture_cache==cache_ref and cache_snapshot(cache_ref)==cache_before,label+": legacy cache identity and geometry remain untouched")
	check(body.contents.is_empty() and not is_instance_valid(item.support_parent),label+": loose contents immediately lose structural support")
	check(item.claimed_by==hole and not item.freeze and item.gravity_scale==1.0 and item.collision_mask==1,label+": contents enter their own real physical fall and claim")
	check(item.global_transform==item_pose,label+": contents are released without teleporting their original pose")
	check(receipt(body_id).calls==0 and receipt(body_id).points==0,label+": the collapse trigger itself awards no points")
	body.fracture_building(hole)
	check(body.fracture_piece_count==0 and fragments(city)==0 and body.contents.is_empty() and physical_state(body)==physics,label+": repeating collapse changes no geometry, physics or contents")
	body.global_position=Vector3(0,-3.49-body.vertical_extent(),0)
	body._physics_process(.016)
	check(not body.consumed and receipt(body_id).calls==0,label+": the full body's actual top above -3.5 cannot score")
	body.global_position=Vector3(0,-3.51-body.vertical_extent(),0)
	body._physics_process(.016)
	check(body.consumed and body.is_queued_for_deletion(),label+": physical completion consumes the original whole building")
	check(receipt(body_id).calls==1 and receipt(body_id).points==48,label+": only the real complete-body fall awards exactly 48 points")
	body.finish_swallow();body.fracture_building(hole)
	check(receipt(body_id).calls==1 and receipt(body_id).points==48,label+": repeated completion cannot duplicate the receipt")
	buildings.append({"asset":entry.id,"mode":mode,"style":city.building_visuals.back().style,"meshes":before.size(),"colliders":shapes.size(),"spawned_fragments":0,"completion_calls":receipt(body_id).calls,"completion_points":receipt(body_id).points})
	item.set_physics_process(false);item.free()
	await process_frame
	check(not is_instance_valid(body),label+": only completed physical consumption removes the original body")
func admission_edges(city:Node3D,entry:Dictionary,hole:Mouth)->void:
	var body:Node3D=city.place(entry,Vector2.ZERO)
	var body_id:int=body.get_instance_id()
	var material:ShaderMaterial=body.fracture_material
	material.set_shader_parameter("visibility",.4);material.set_shader_parameter("reveal_occluder",.8)
	var physics:Dictionary=physical_state(body)
	var small:=Mouth.new();small.radius=.1;city.add_child(small)
	check(not body.begin_swallow(small) and not body.begin_pull(small),"Rejected small mouth cannot admit a complete building")
	check(physical_state(body)==physics and body.points==35 and receipt(body_id).calls==0,"Rejected admission preserves the real building and awards nothing")
	check(is_equal_approx(float(material.get_shader_parameter("visibility")),.4) and is_equal_approx(float(material.get_shader_parameter("reveal_occluder")),.8),"Rejected admission does not clear a still-supported reveal material")
	check(body.begin_pull(hole),"Accepted pull uses the real complete-building size gate")
	body.set_physics_process(false)
	check(material.get_shader_parameter("visibility")==1.0 and material.get_shader_parameter("reveal_occluder")==0.0 and body.points==48,"Accepted pull clears the actual material immediately and reserves the same total")
	check(not body.fractured and not body.consumed and receipt(body_id).calls==0,"Pull admission does not fabricate a collapse or score receipt")
	body.free();small.free()
	var fast:Node3D=city.place(entry,Vector2.ZERO)
	var fast_id:int=fast.get_instance_id()
	check(fast.begin_swallow(hole),"Fast-fall case admits an original complete building")
	fast.set_physics_process(false)
	var inside:Node3D=city.place(prop_entry,Vector2.ZERO)
	inside.support_parent=fast;fast.contents.append(inside)
	check(inside.freeze and inside.support_parent==fast,"Fast-fall contents really retain their structural support before completion")
	fast.global_position=Vector3(0,-3.51-fast.vertical_extent(),0)
	fast._physics_process(.016)
	check(fast.claim_elapsed<.18 and fast.consumed and receipt(fast_id).calls==1 and receipt(fast_id).points==48,"A complete fall before collapse's .18-second threshold still pays exactly 48")
	check(fast.contents.is_empty() and not is_instance_valid(inside.support_parent) and inside.claimed_by==hole and not inside.freeze,"Fast physical completion also releases the actual held contents")
	fast.finish_swallow()
	check(receipt(fast_id).calls==1 and receipt(fast_id).points==48,"Fast-fall completion remains idempotent")
	inside.set_physics_process(false);inside.free()
	await process_frame
func support_loss_edges(city:Node3D,entry:Dictionary,hole:Mouth)->void:
	for mode in ["unclaimed pull","canceled claim"]:
		var body:Node3D=city.place(entry,Vector2.ZERO)
		var body_id:int=body.get_instance_id()
		var admitted:bool=body.begin_pull(hole) if mode=="unclaimed pull" else body.begin_swallow(hole)
		check(admitted,mode+": setup uses the actual supported-building admission route")
		body.set_physics_process(false)
		if mode=="canceled claim":body.claimed_by=null
		check(not is_instance_valid(body.claimed_by) and not body.fractured and receipt(body_id).calls==0,mode+": there really is no current claimant or score receipt")
		var near_item:Node3D=city.place(prop_entry,Vector2.ZERO)
		var far_item:Node3D=city.place(prop_entry,Vector2(hole.radius*.95,0))
		for item in [near_item,far_item]:item.support_parent=body;body.contents.append(item)
		var far_pose:Transform3D=far_item.global_transform
		# This is an explicit support-loss pose fixture, not a gravity simulation.
		if mode=="unclaimed pull":body.rotation.x=deg_to_rad(9.0)
		else:body.position.y-=.19
		var before:Array[Dictionary]=visuals(body);var physics:Dictionary=physical_state(body)
		body.fracture_material.set_shader_parameter("reveal_occluder",1.0)
		body._physics_process(.10)
		check(not body.fractured and near_item.support_parent==body and far_item.freeze,mode+": a pose cue before .18 seconds does not prematurely release contents")
		body._physics_process(.09)
		check(body.fractured and body.contents.is_empty() and body.fracture_piece_count==0 and fragments(city)==0,mode+": actual support-loss logic releases contents without a current claimant")
		check(same_visuals(before,body,"geometry") and same_visuals(before,body,"materials") and physical_state(body)==physics,mode+": the actual cue preserves the complete placed model and physical state")
		check(body.fracture_material.get_shader_parameter("reveal_occluder")==0.0 and body.points==48 and receipt(body_id).calls==0,mode+": support loss clears the material and awards no premature score")
		check(not is_instance_valid(near_item.support_parent) and near_item.claimed_by==hole and not near_item.freeze,mode+": nearby released contents may use the existing physical owner")
		check(not is_instance_valid(far_item.support_parent) and not is_instance_valid(far_item.claimed_by) and not far_item.freeze and far_item.global_transform==far_pose and far_item.gravity_scale==1.0 and far_item.collision_mask==1,mode+": released contents outside the real admission margin fall without invented ownership or teleporting")
		body._physics_process(.02);body.fracture_building(hole)
		check(receipt(body_id).calls==0 and body.fracture_piece_count==0 and body.contents.is_empty(),mode+": subsequent support cues remain idempotent and cannot pay before full fall")
		for item in [near_item,far_item]:item.set_physics_process(false);item.free()
		body.free();await process_frame
func run()->void:
	var world:=Node3D.new();root.add_child(world)
	collector=Collector.new();root.add_child(collector)
	var hole:=Mouth.new();world.add_child(hole)
	var city:Node3D=new_city(world)
	var entries:Array=city.catalog.filter(func(entry):return entry.group=="building")
	prop_entry=city.catalog.filter(func(entry):return entry.group=="prop")[0]
	check(entries.size()==48,"All 48 imported catalog building models receive actual runtime checks")
	for entry in entries:await collapse_case(city,entry,hole,"cached",entry.id)
	await collapse_case(city,entries[0],hole,"missing","Missing legacy cache")
	await collapse_case(city,entries[0],hole,"incomplete","Incomplete legacy cache")
	await admission_edges(city,entries[0],hole)
	await support_loss_edges(city,entries[0],hole)
	var reordered:Node3D=new_city(world)
	var office:Dictionary=entries.filter(func(entry):return entry.id=="024_office_06")[0]
	var canonical_style:int=entries.find(office)%City.BUILDING_TINTS.size()
	check(canonical_style!=0,"The order-regression asset really differs from its original baked style when placed first")
	for style in City.BUILDING_TINTS.size():
		await collapse_case(reordered,office,hole,"cached","Reordered office style %d"%style)
		check(buildings.back().style==style,"Repeated office placements retain their actual style %d"%style)
	var report:={"checks":checks,"failures":failures,"buildings":buildings,"catalog_models":entries.size(),"scope":"Actual whole-building mesh/material/collision preservation, synchronous reveal/contents release, real physical completion boundary and idempotent 48-point receipts. Mock collector records the production finish_swallow call only; no GPU or physical-phone claim."}
	print("BUILDING_SURFACE_ARTIFACTS_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.free();collector.free();await process_frame;quit(0 if failures.is_empty() else 1)
