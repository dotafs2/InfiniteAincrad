extends SceneTree
## Color regression for the actual Compatibility batch setup. The headless
## renderer discards instance-buffer readback, so native setter calls are
## transparently recorded in a copy of the shipped script, not inferred from
## dummy getters. Windowless packed-attribute GL execution is separate evidence.
const Game=preload("res://fidelity/game.gd")
const FoodCity=preload("res://fidelity/food_city.gd")
const GLAZE_SHA:="54a890cdf065e4613a203e7fc9834d4440dd73d27ab6a47e3179aa27f721e2cc"
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func digest(data:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data);return hash.finish().hex_encode()
func mesh_inventory(city:Node3D)->Dictionary:
	var result:Dictionary={}
	for key in city.mesh_cache:result[key]=digest(var_to_bytes(city.mesh_cache[key].surface_get_arrays(0)))
	return result
func inspect_flags(city:Node3D)->Array:
	var rows:Array=[]
	for view in city.find_children("*","MultiMeshInstance3D",false,false):
		if view.material_override!=city.food_batch_material:continue
		rows.append(view.multimesh)
	check(rows.size()>500,"Actual initial city retains hundreds of spatial food batches")
	check(rows.all(func(mm):return mm.use_colors and mm.use_custom_data),"Every actual static food batch explicitly enables its identity-color channel")
	check(rows.all(func(mm):return mm.visible_instance_count==mm.instance_count),"Color initialization does not drop visible initial instances")
	return rows
func writes_match(city:Node3D,mm:MultiMesh,label:String)->void:
	var id:=mm.get_instance_id();var slots:Dictionary={};var wrong:=0
	for row in city.qa_color_writes:
		if row.batch_id!=id or row.capacity!=mm.instance_count:continue
		slots[row.slot]=true
		if row.value!=Color.WHITE:wrong+=1
	check(slots.size()==mm.instance_count,label+": current allocation writes every color slot after creation or resize")
	check(wrong==0,label+": all four multiplier components are exactly one, preserving RGB and roughness alpha")
func rain(city:Node3D)->Node3D:
	city.rain_serial=0
	var body:Node3D=city.spawn_rain("cake",Vector2(35,35),.3)
	# Material lifecycle fixture: settlement is supplied, not claimed as a
	# new physics test. Existing collision/rain suites test natural settling.
	body.freeze=true;body.sleeping=true;body.rain_landed=true;body.set_physics_process(false)
	city.batch_settled_rain();return body
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:=Game.new();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false);game.world.process_mode=Node.PROCESS_MODE_DISABLED
	var inventory:=mesh_inventory(game.city);var actual_batches:=inspect_flags(game.city)
	check(digest(game.city.food_material.shader.code.to_utf8_buffer())==GLAZE_SHA,"Original ingredient shader, gloss and color equations remain byte-identical")
	var colored_vertices:=0;var invalid_colors:=0
	for key in game.city.mesh_cache:
		var arrays:Array=game.city.mesh_cache[key].surface_get_arrays(0);var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		check(colors.size()==arrays[Mesh.ARRAY_VERTEX].size(),str(key)+": every real geometry vertex carries its ingredient finish")
		for color in colors:
			colored_vertices+=1
			if maxf(color.r,maxf(color.g,color.b))<=.1 or color.a<.18 or color.a>.71:invalid_colors+=1
	check(invalid_colors==0 and colored_vertices>10000,"Authored food RGB is nonblack and finish alpha is present before instancing")
	# Observe the actual production call sites without changing the supplied
	# values or native setter. This avoids the known dummy-renderer getter trap.
	var production:Script=load("res://fidelity/food_city.gd")
	var source:String=production.get_source_code()
	var observer:=GDScript.new()
	observer.source_code=source.replace("mm.set_instance_color(","_qa_set_color(mm,")+"\nvar qa_color_writes:Array=[]\nfunc _qa_set_color(mm:MultiMesh,index:int,value:Color)->void:\n\tqa_color_writes.append({\"batch_id\":mm.get_instance_id(),\"capacity\":mm.instance_count,\"slot\":index,\"value\":value})\n\tmm.set_instance_color(index,value)\n"
	check(observer.reload()==OK,"Transparent native color-setter observation compiles from the actual shipped script")
	var parent:Node=game.city.get_parent();game.city.free()
	var city:Node3D=observer.new();parent.add_child(city);game.city=city;city.build(game);city.set_process(false);city.set_physics_process(false);city.rain_enabled=false
	var batches:=inspect_flags(city)
	check(mesh_inventory(city)==inventory and batches.size()==actual_batches.size(),"Observation preserves all actual generated food geometry and batching")
	for index in batches.size():writes_match(city,batches[index],"Initial batch %d"%index)
	var rain_bodies:Array[Node3D]=[]
	for index in 33:
		var body:=rain(city);rain_bodies.append(body)
		if index in [0,15,16,31,32]:
			check(body.batch.use_colors and body.batch.use_custom_data,"Rain retains explicit color and custom channels at population %d"%(index+1))
			writes_match(city,body.batch,"Rain population %d"%(index+1))
	var mm:MultiMesh=rain_bodies[0].batch
	check(mm.instance_count==64 and mm.visible_instance_count==33,"Rain test crosses two actual capacity reallocations")
	var released:=rain_bodies[4];var moved:Node3D=rain_bodies.back();var mesh:Mesh=released.food_visual.mesh
	released.expose_visual()
	check(released.batch==null and released.food_visual.visible and released.food_visual.mesh==mesh,"Independent release exposes the original colored ingredient mesh")
	check(moved.batch_index==4 and mm.visible_instance_count==32,"Removal compacts exactly one slot without hidden duplicate geometry")
	var previous_writes:int=city.qa_color_writes.size()
	var replacement:=rain(city)
	check(replacement.batch==mm and replacement.batch_index==32 and mm.visible_instance_count==33,"New settled food reuses the vacated batch capacity")
	var reused_white:=false
	for index in range(previous_writes,city.qa_color_writes.size()):
		var row:Dictionary=city.qa_color_writes[index]
		if row.batch_id==mm.get_instance_id() and row.slot==32 and row.value==Color.WHITE:reused_white=true
	check(reused_white,"Reused rain slot explicitly rewrites full identity RGBA")
	writes_match(city,mm,"Compacted and reused rain")
	evidence={"static_batches":batches.size(),"colored_vertices":colored_vertices,"rain_capacity":mm.instance_count,"rain_population":mm.visible_instance_count,"native_color_writes_observed":city.qa_color_writes.size(),"shader_sha256":GLAZE_SHA,"source_sha256":digest(source.to_utf8_buffer()),"scope":"Headless real scene flags/geometry and transparent production setter instrumentation; no GPU getter or browser pixel claim."}
	game.free();await process_frame
	var report:={"checks":checks,"failures":failures,"evidence":evidence};print("FOOD_COLOR_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
