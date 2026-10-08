extends SceneTree
## Common-only integration probe. No Game/Save is loaded and no user save is read.
## Run with --test; stdout always preserves the full result, even on failure.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const Common=preload("res://fidelity/common_skin.gd")
const EXPECTED_IDS=["cookie_bite","citrus_slice","melon_munch","pancake_stack","bacon_curl","cocoa_square","paper_boat","toy_tire","leaf_cup","wooden_tub","rope_coil","clay_pot","shell_cup","woven_nest","paint_tin","denim_pocket","catchers_mitt","enamel_basin","acorn_cup","knit_cap"]
var checks:=0
var failures:Array[String]=[]
var rows:Array[Dictionary]=[]

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func node_count(node:Node)->int:
	var count:=1
	for child in node.get_children():count+=node_count(child)
	return count

func geometry_signature(mesh:Mesh)->String:
	var arrays:Array=[]
	for surface in mesh.get_surface_count():
		var data:Array=mesh.surface_get_arrays(surface)
		arrays.append([data[Mesh.ARRAY_VERTEX],data[Mesh.ARRAY_INDEX],data[Mesh.ARRAY_NORMAL]])
	return var_to_bytes(arrays).hex_encode().sha256_text()

func mesh_triangle_count(mesh:Mesh)->int:
	if mesh==null:return 0
	var count:=0
	for surface in mesh.get_surface_count():
		var data:Array=mesh.surface_get_arrays(surface)
		count+=(data[Mesh.ARRAY_INDEX].size() if data[Mesh.ARRAY_INDEX]!=null and not data[Mesh.ARRAY_INDEX].is_empty() else data[Mesh.ARRAY_VERTEX].size())/3
	return count

func triangle_capacity(node:Node)->int:
	var count:=0
	if node is MeshInstance3D:count+=mesh_triangle_count(node.mesh)
	elif node is MultiMeshInstance3D and node.multimesh!=null:
		# Include all reserved instances, even when idle/hidden, not just one mesh.
		count+=mesh_triangle_count(node.multimesh.mesh)*node.multimesh.instance_count
	for child in node.get_children():count+=triangle_capacity(child)
	return count

func largest_particle_size(pool:MultiMesh)->float:
	var largest:=0.0
	for i in pool.visible_instance_count:
		largest=maxf(largest,pool.get_instance_transform(i).basis.get_scale().length())
	return largest

func furthest_particle(pool:MultiMesh)->float:
	var furthest:=0.0
	for i in pool.visible_instance_count:
		var at:Vector3=pool.get_instance_transform(i).origin
		furthest=maxf(furthest,Vector2(at.x,at.z).length())
	return furthest

func write_report(result:Dictionary)->bool:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--report="):continue
		var path:=argument.trim_prefix("--report=")
		if not path.is_absolute_path() or "://" in path:return false
		# Never erase a previous failed receipt during a retry.
		if FileAccess.file_exists(path):path+=".%d-%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file==null:return false
		result["report_path"]=path
		file.store_string(JSON.stringify(result,"\t")+"\n");file.flush()
		var ok:=file.get_error()==OK;file.close()
		return ok
	return true

func finish_report(scope:String)->void:
	var result:={"checks":checks,"failures":failures,"skins":rows,"scope":scope}
	if not write_report(result):check(false,"Could not write the requested absolute report path")
	result["checks"]=checks;result["failures"]=failures
	print("COMMON_SKINS_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	check(DisplayServer.get_name()!="headless","A real GPU display server is required for truthful MultiMesh transform readback")
	if not failures.is_empty():
		finish_report("Stopped before model checks: headless Dummy rendering cannot verify the actual MultiMesh transforms. No Game/Save is loaded.");return
	var found:Array[String]=[]
	var shapes:Dictionary={}
	var profiles:Dictionary={}
	var definitions:Array[Dictionary]=[]
	for definition in Catalog.DEFS:
		if definition.model_id in Visual.Common.IDS and int(definition.variant_index)==0:definitions.append(definition)
	check(definitions.size()==20,"Exactly twenty original authored object families remain playable after regrading")
	for definition in definitions:
		var id:String=definition.id;found.append(id)
		check(EXPECTED_IDS.has(id),"Common uses an approved stable identity: "+id)
		var player:Node3D=Visual.new();root.add_child(player);player.build(definition,false);player.set_process(false)
		var preview:Node3D=Visual.new();root.add_child(preview);preview.build(definition,true);preview.set_process(false)
		var controller:Node3D=player.common
		check(is_instance_valid(controller) and controller.skin_id==id and player.fx_family==id,"Player dispatches to its authored Common controller: "+id)
		check(player.mouth==null and is_instance_valid(preview.mouth) and preview.mouth.visible,"Only menu preview adds the visible black opening: "+id)
		check(player.main_ring.mesh is ArrayMesh and player.main_ring.get_meta("sculpted",false),"Runtime uses an authored three-dimensional ArrayMesh: "+id)
		var signature:=geometry_signature(player.main_ring.mesh)
		check(not shapes.has(signature),"Actual vertex/index/normal geometry is unique without material colors: "+id)
		shapes[signature]=id
		check(player.main_ring.mesh==preview.main_ring.mesh,"Menu and runtime reuse the same cached authored mesh: "+id)
		check(player.common!=preview.common and player.common.animated_root!=preview.common.animated_root,"Preview and runtime retain independent effect controllers and transforms: "+id)
		check(controller.fx_profile==Common.profile_for(id) and not controller.fx_profile.is_empty(),"Theme routes to its named feedback profile: "+id)
		profiles[controller.fx_profile]=true
		check(Common.POOL_CAPACITY==8 and controller.particles.multimesh.instance_count==8,"Exactly eight preallocated feedback instances: "+id)
		check(controller.active_count==0 and not controller.particles.visible and controller.particles.multimesh.visible_instance_count==0,"New Common has no stale burst: "+id)
		check(player.find_children("*","CollisionObject3D",true,false).is_empty(),"Authored geometry and feedback add no physics body: "+id)
		check(player.find_children("*","GPUParticles3D",true,false).is_empty() and player.find_children("*","CPUParticles3D",true,false).is_empty(),"No continuous particle emitter: "+id)
		var baseline_nodes:=node_count(player)
		var player_triangles:=triangle_capacity(player)
		var preview_triangles:=triangle_capacity(preview)
		check(player_triangles<=4500 and preview_triangles<=4500,"Total worst-case triangle capacity includes every reserved FX instance, hidden wave and preview mouth: "+id)
		check(player.wave.mesh.rings==16,"Common's thin generic feedback wave uses reduced radial segmentation: "+id)
		var original_pose:Transform3D=player.transform
		var cached_mesh:Mesh=player.main_ring.mesh
		var pool:MultiMesh=controller.particles.multimesh

		player.absorb_object()
		check(controller.item_events==1 and controller.rival_events==0 and not controller.rival_active,"One confirmed object invokes only one item receipt: "+id)
		var item_count:int=controller.active_count
		var item_lifetime:float=controller.event_lifetime
		check(item_count>0 and item_count<Common.POOL_CAPACITY and pool.visible_instance_count==item_count and controller.particles.visible,"Item feedback is visible and uses fewer than all slots: "+id)
		player._process(.08)
		var item_pulse:float=absf(controller.animated_root.scale.y-1.0)
		check(item_pulse>0.0 and item_lifetime>0.0 and item_lifetime<=.35,"Item reaction is subtle and short: "+id)
		var item_size:=largest_particle_size(pool)
		var item_distance:=furthest_particle(pool)
		check(preview.common.item_events==0 and preview.common.animated_root.transform==Transform3D.IDENTITY,"Runtime feedback cannot animate the cached preview instance: "+id)
		player._process(1.0)
		check(controller.active_count==0 and not controller.particles.visible and pool.visible_instance_count==0,"Item pool retires completely: "+id)

		check(player.absorb_rival(Color("eb57bc")),"Rival callback reports handled so game skips its duplicate generic burst: "+id)
		check(controller.rival_events==1 and controller.item_events==1 and controller.rival_active,"One rival produces one stronger themed receipt: "+id)
		var rival_lifetime:float=controller.event_lifetime
		check(controller.active_count>item_count and controller.active_count<=Common.POOL_CAPACITY and pool.visible_instance_count==controller.active_count,"Rival fills a larger bounded burst: "+id)
		check(rival_lifetime>item_lifetime and rival_lifetime<=1.0,"Rival celebration lasts longer but remains brief: "+id)
		player._process(.08)
		check(absf(controller.animated_root.scale.y-1.0)>item_pulse*2.0 and largest_particle_size(pool)>item_size*1.5,"Rival has visibly stronger sculpture motion and larger flecks: "+id)
		# Compare trajectory at the same normalized age, not unequal event timing.
		player._process(rival_lifetime*(.08/item_lifetime)-.08)
		check(furthest_particle(pool)>item_distance,"Rival feedback travels further than item feedback at matched phase: "+id)
		var protected_age:float=controller.event_age
		var protected_count:int=controller.active_count
		var protected_pose:Transform3D=pool.get_instance_transform(0)
		for i in 32:player.absorb_object()
		check(controller.item_events==33 and controller.rival_events==1,"Dense item receipts remain accurately counted: "+id)
		check(controller.rival_active and is_equal_approx(controller.event_age,protected_age) and is_equal_approx(controller.event_lifetime,rival_lifetime) and controller.active_count==protected_count and pool.get_instance_transform(0)==protected_pose,"Items cannot erase, restart or weaken an active rival celebration: "+id)
		player._process(2.0)
		check(controller.active_count==0 and not controller.rival_active and not controller.particles.visible and pool.visible_instance_count==0,"Rival celebration fully retires: "+id)
		check(controller.animated_root.transform.is_equal_approx(Transform3D.IDENTITY),"Transient sculpture animation returns exactly to its idle pose: "+id)

		var stress_items:int=controller.item_events
		var stress_rivals:int=controller.rival_events
		var sent_items:=0;var sent_rivals:=0
		for index in 256:
			if index%7==0:
				player.absorb_rival(Color("31a6e6"));sent_rivals+=1
			else:
				player.absorb_object();sent_items+=1
			player._process(.012)
		check(controller.item_events==stress_items+sent_items and controller.rival_events==stress_rivals+sent_rivals,"Stress callbacks keep exact receipt counts: "+id)
		check(node_count(player)==baseline_nodes and controller.particles.multimesh==pool and pool.instance_count==8 and controller.active_count<=8,"Hundreds of bursts retain the same fixed nodes and eight-slot pool: "+id)
		check(player.transform==original_pose and player.main_ring.mesh==cached_mesh and geometry_signature(cached_mesh)==signature,"Feedback cannot move the player or mutate shared model geometry: "+id)
		check(player.find_children("*","CollisionObject3D",true,false).is_empty(),"Stress feedback still owns no physics: "+id)
		player._process(2.0)
		check(controller.active_count==0 and pool.visible_instance_count==0 and not controller.particles.visible,"Stress effects also retire: "+id)
		var old_controller_id:int=controller.get_instance_id()
		player.build(definition,false);player.set_process(false)
		check(not is_instance_id_valid(old_controller_id) and node_count(player)==baseline_nodes and player.common.item_events==0 and player.common.rival_events==0,"Rebuild frees the old controller and clears counters without node accumulation: "+id)
		check(player.main_ring.mesh==cached_mesh and player.common.active_count==0,"Rebuild reuses cached geometry with an empty effect pool: "+id)
		rows.append({"id":id,"geometry_sha256":signature,"feedback_profile":player.common.fx_profile,"nodes":baseline_nodes,"pool_capacity":8,"player_triangle_capacity":player_triangles,"preview_triangle_capacity":preview_triangles,"item_instances":item_count,"rival_instances":protected_count,"item_lifetime":item_lifetime,"rival_lifetime":rival_lifetime,"stress_receipts":256})
		preview.free();player.free()
	check(found.size()==EXPECTED_IDS.size() and EXPECTED_IDS.all(func(id):return found.has(id)),"Every approved Common ID is present exactly once")
	check(shapes.size()==20,"All twenty Commons have different actual geometry")
	check(profiles.size()>=7,"Feedback includes multiple material-specific shapes and trajectories")
	finish_report("No Game/Save loaded; --test guard and muted real GPU renderer. Actual Common model/cache/callback/pool lifecycle only. Physics settlement, save compatibility and visual quality use separate suites/captures.")
