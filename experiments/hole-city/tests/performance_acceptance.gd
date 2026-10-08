extends SceneTree
## Exact geometry/query parity and instancing lifecycle regression coverage.
const Ground=preload("res://fidelity/cut_ground.gd")
var checks:=0
var failures:Array[String]=[]
var max_ground_error:=0.0
var pool_refs:Array[WeakRef]=[]
class GroundOwner:
	extends Node3D
	var holes:Array[Node3D]=[]
class Mouth:
	extends Node3D
	var active:=true
	var radius:=1.0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func ground_parity(reference:String)->void:
	var owner:=GroundOwner.new();root.add_child(owner)
	for i in 8:
		var mouth:=Mouth.new();owner.add_child(mouth);owner.holes.append(mouth)
	# Exercise the preserved pre-optimization algorithm at the same requested
	# slab extent. Only its scalar world extent changes; its geometry algorithm
	# remains byte-for-byte intact, and the original fixture stays immutable.
	var reference_source:=FileAccess.get_file_as_string(reference)
	check(reference_source.count("const HALF:=80.0")==1,"Preserved comparison fixture has one explicit old extent")
	var comparison:=GDScript.new()
	comparison.source_code=reference_source.replace("const HALF:=80.0","const HALF:=100.0")
	check(comparison.reload()==OK,"Independent old algorithm compiles at the expanded extent")
	var old:Node3D=comparison.new();owner.add_child(old)
	var fresh:=Ground.new();owner.add_child(fresh)
	old.build(owner,ShaderMaterial.new());fresh.build(owner,ShaderMaterial.new())
	var rng:=RandomNumberGenerator.new();rng.seed=202609285
	for trial in 72:
		for i in 8:
			var h:Node3D=owner.holes[i];h.active=i<([1,4,8][trial%3])
			h.radius=[.85,2.5,7.2][(trial/3)%3]
			var span:float=8 if trial%4==0 else 98
			h.position=Vector3(rng.randf_range(-span,span),0,rng.randf_range(-span,span))
		old.sync();fresh.sync()
		var a:PackedVector3Array=old.collision_vertices;var b:PackedVector3Array=fresh.collision_vertices
		check(a.size()==b.size(),"Ground keeps triangle topology for overlapping/edge mouths: %d"%trial)
		var error:=0.0
		if a.size()==b.size():
			for i in a.size():error=maxf(error,a[i].distance_to(b[i]))
		else:error=INF
		max_ground_error=maxf(max_ground_error,error)
		check(error<.0003,"Optimized ground keeps collision coordinates within 0.3 mm: %d"%trial)
	owner.free()
func queries(game:Node3D,map_id:String)->void:
	for i in 45:
		var at:=Vector3(-72+(i*31)%145,0,-72+(i*47)%145)
		var reach:float=[.85,7.2,18.0,48.0,256.0][i%5]
		var expected:=[];var actual:=[]
		for body in game.city.foods:
			if not is_instance_valid(body) or body.consumed:continue
			var p:Vector3=body.interaction_position()
			if Vector2(p.x-at.x,p.z-at.z).length_squared()<=reach*reach:expected.append(body.get_instance_id())
		for body in game.city.query_foods(at,reach):actual.append(body.get_instance_id())
		expected.sort();actual.sort()
		check(expected==actual,map_id+": spatial query matches exhaustive interaction positions %d"%i)
	game.player.radius=7.2
	for i in 12:
		game.player.position=Vector3(-60+i*10,0,-35+(i%4)*23)
		var distance:=INF
		for body in game.city.foods:
			if is_instance_valid(body) and body.can_fit(game.player):distance=minf(distance,body.interaction_position().distance_squared_to(game.player.position))
		var nearest:Node3D=game.nearest_food(game.player)
		check(nearest!=null and absf(nearest.interaction_position().distance_squared_to(game.player.position)-distance)<.001,map_id+": nearest edible matches full scan %d"%i)
func city_batches(game:Node3D)->void:
	var initial:=0;var intact:=true;var target:Node3D
	for body in game.city.foods:
		for handle in body.static_instances:
			var pool:RefCounted=handle.pool.get_ref();initial+=1
			pool_refs.append(weakref(pool))
			if not handle.pose.is_equal_approx(game.city.global_transform.affine_inverse()*handle.visual.global_transform):intact=false
			if pool.mesh.mesh!=handle.visual.mesh or handle.visual.visible:intact=false
			if target==null:target=body
	check(initial>70 and intact,"City instancing retains every original mesh, material and transform")
	var handle:Dictionary=target.static_instances[0];var pool:RefCounted=handle.pool.get_ref();var before:int=pool.mesh.visible_instance_count
	var colliders:int=target.find_children("*","CollisionShape3D",true,false).size()
	target.notify_moving()
	check(target.static_instances.is_empty() and handle.visual.visible and pool.mesh.visible_instance_count<before,"A released city prop leaves the batch and restores its original visual")
	check(target.find_children("*","CollisionShape3D",true,false).size()==colliders,"Batching preserves independent compound physics")
	for i in pool.handles.size():check(pool.handles[i].index==i,"Compacted city batch slot still belongs to its original body")
	target.position=Vector3(70,target.position.y,70)
	check(game.city.query_foods(Vector3(70,0,70),1).has(target),"Moved city prop remains discoverable after leaving its original cell")
func food_batches(game:Node3D)->void:
	var original:=0;var groups:={};var released:=0
	for body in game.city.foods:
		if not body.has_meta("food_kind") or body.batch==null:continue
		groups[body.batch.get_instance_id()]=body.batch;original+=1
		if original%5==0:
			var mesh:Mesh=body.food_visual.mesh;var material:Material=body.food_visual.material_override
			body.expose_visual();released+=1
			if body.food_visual.mesh!=mesh or body.food_visual.material_override!=material:released=-100000;break
	var active:=0
	for mm in groups.values():active+=mm.visible_instance_count
	check(released>400 and active==original-released,"Hundreds of released foods stop submitting hidden GPU instances")
	var valid_slots:=true
	for body in game.city.foods:
		if not body.has_meta("food_kind") or body.batch==null:continue
		if body.batch_members[body.batch_index]!=body or body.batch.visible_instance_count!=body.batch_members.size():valid_slots=false
	check(valid_slots,"Food compaction keeps remaining owner/slot associations correct")
	check(game.city.models.size()==2,"Food city loads only its two used character assets")
func run()->void:
	var reference:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference-ground="):reference=arg.trim_prefix("--reference-ground=")
	if reference=="":push_error("Pass the preserved pre-optimization ground fixture");quit(1);return
	ground_parity(reference)
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false)
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level();game.begin_play();game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for h in game.holes:h.enabled=false
		queries(game,map_id)
		if map_id=="city":city_batches(game)
		else:food_batches(game)
	check(pool_refs.all(func(ref):return ref.get_ref()==null),"Switching maps releases city batch resources without reference cycles")
	game.free();await process_frame
	print("PERFORMANCE_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"maximum_ground_coordinate_error":max_ground_error}))
	quit(0 if failures.is_empty() else 1)
