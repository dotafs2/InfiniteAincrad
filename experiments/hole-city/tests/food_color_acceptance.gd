extends SceneTree
## Actual Compatibility batch flags, geometry and rain allocation lifecycle.
## Headless instance-color getters are not evidence of the native GPU buffer.
## Source-only native-call instrumentation and packed-attribute GL execution
## are retained separately in artifacts/black-food-20260929/.
const Game=preload("res://fidelity/game.gd")
const GLAZE_SHA:="4ad2f69f971fcc536dadd94c1892b7e117283e54c5f94d2022b0e60d33a5ed17"
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
	check(digest(game.city.food_material.shader.code.to_utf8_buffer())==GLAZE_SHA,"Approved ingredient shader includes the renderer-specific single color decode")
	var colored_vertices:=0;var invalid_colors:=0
	for key in game.city.mesh_cache:
		var arrays:Array=game.city.mesh_cache[key].surface_get_arrays(0);var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		check(colors.size()==arrays[Mesh.ARRAY_VERTEX].size(),str(key)+": every real geometry vertex carries its ingredient finish")
		for color in colors:
			colored_vertices+=1
			if maxf(color.r,maxf(color.g,color.b))<=.1 or color.a<.18 or color.a>.71:invalid_colors+=1
	check(invalid_colors==0 and colored_vertices>10000,"Authored food RGB is nonblack and finish alpha is present before instancing")
	var city:Node3D=game.city
	city.set_process(false);city.set_physics_process(false);city.rain_enabled=false
	var rain_bodies:Array[Node3D]=[]
	for index in 33:
		var body:=rain(city);rain_bodies.append(body)
		if index in [0,15,16,31,32]:
			check(body.batch.use_colors and body.batch.use_custom_data,"Rain retains explicit color and custom channels at population %d"%(index+1))
			check(body.batch.visible_instance_count==index+1,"Rain population %d preserves every visible independently owned food"%(index+1))
	var mm:MultiMesh=rain_bodies[0].batch
	check(mm.instance_count==64 and mm.visible_instance_count==33,"Rain test crosses two actual capacity reallocations")
	var released:=rain_bodies[4];var moved:Node3D=rain_bodies.back();var mesh:Mesh=released.food_visual.mesh
	released.start_fall(game.player)
	check(released.batch==null and released.food_visual.visible and released.food_visual.mesh==mesh,"Independent release exposes the original colored ingredient mesh")
	check(moved.batch_index==4 and mm.visible_instance_count==32,"Removal compacts exactly one slot without hidden duplicate geometry")
	var replacement:=rain(city)
	check(replacement.batch==mm and replacement.batch_index==32 and mm.visible_instance_count==33,"New settled food reuses the vacated batch capacity")
	check(mm.use_colors and mm.use_custom_data and moved.batch_index==4,"Compacted/reused batch retains its identity-color channel and moved owner index")
	var final_inventory:=mesh_inventory(city)
	check(inventory.keys().all(func(key):return final_inventory.has(key) and final_inventory[key]==inventory[key]),"Rain and release do not rewrite any original ingredient geometry or color")
	evidence={"static_batches":actual_batches.size(),"colored_vertices":colored_vertices,"rain_capacity":mm.instance_count,"rain_population":mm.visible_instance_count,"shader_sha256":GLAZE_SHA,"scope":"Actual headless scene resource/flag/lifecycle checks; no native GPU getter, browser pixel, or source-code availability claim."}
	game.free();await process_frame
	var report:={"checks":checks,"failures":failures,"evidence":evidence};print("FOOD_COLOR_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
