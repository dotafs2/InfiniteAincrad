extends SceneTree
## Non-author batch color identity and actual resource preservation checks.
## Optional baseline mode records the old package defect; the release gate
## always runs the default corrected-state assertions. Dummy rendering does
## not retain instance color values; setter trace and GPU checks live in the
## bound independent artifacts instead of trusting those dummy getters.
const Game=preload("res://fidelity/game.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
var baseline:=false
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func digest(data:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(data);return context.finish().hex_encode()
func state(mm:MultiMesh)->Dictionary:
	return {"uses_colors":mm.use_colors,"uses_custom_data":mm.use_custom_data,"capacity":mm.instance_count,"visible":mm.visible_instance_count,"gpu_colors":"Not observable with the headless Dummy renderer"}
func verify_batch(mm:MultiMesh,label:String)->void:
	var row:=state(mm)
	check(row.uses_colors!=baseline,label+": color attribute enabled only in corrected package")
	check(row.uses_custom_data,label+": custom-data path remains exercised")
func rain_piece()->Node3D:
	game.city.rain_serial=0
	var body:Node3D=game.city.spawn_rain("cake",Vector2(35,35),.25)
	body.freeze=true;body.sleeping=true;body.rain_landed=true;body.collision_layer=0;body.collision_mask=0
	body.set_physics_process(false)
	game.city.batch_settled_rain()
	return body
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	baseline=OS.get_cmdline_user_args().has("--baseline")
	game=Game.new();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.selected_map="food";game.start_level();game.world.process_mode=Node.PROCESS_MODE_DISABLED
	game.set_process(false);game.set_physics_process(false);game.city.rain_enabled=false
	for body in game.city.foods:
		if is_instance_valid(body):body.freeze=true
	var sentinel:=MultiMesh.new();sentinel.transform_format=MultiMesh.TRANSFORM_3D
	sentinel.use_colors=true;sentinel.instance_count=1;sentinel.set_instance_color(0,Color.WHITE)
	var sentinel_read:Color=sentinel.get_instance_color(0)
	var palette:Dictionary={};var meshes:Dictionary={}
	for key in game.city.mesh_cache:
		var mesh:Mesh=game.city.mesh_cache[key];var arrays:=mesh.surface_get_arrays(0);var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		check(not colors.is_empty() and colors.size()==arrays[Mesh.ARRAY_VERTEX].size(),str(key)+": actual mesh has authored per-vertex finish colors")
		for color in colors:palette[color.to_html()]=[color.r,color.g,color.b,color.a]
		meshes[key]=digest(var_to_bytes(arrays))
	var all_batches:Array=[];var count:=0
	for view in game.city.find_children("*","MultiMeshInstance3D",false,false):
		if view.material_override!=game.city.food_batch_material:continue
		verify_batch(view.multimesh,"Initial food batch %d"%count)
		all_batches.append(state(view.multimesh));count+=1
	check(count>500,"Full initial city exercises hundreds of actual food batches")
	var shader:String=game.city.food_material.shader.code
	check(digest(shader.to_utf8_buffer())=="4ad2f69f971fcc536dadd94c1892b7e117283e54c5f94d2022b0e60d33a5ed17","Ingredient shader matches the approved renderer-specific color fix; finish remains opaque")
	var rain:Array[Node3D]=[]
	for i in 33:
		var piece:=rain_piece();rain.append(piece)
		if i in [0,15,16,31,32]:verify_batch(piece.batch,"Rain population %d"%(i+1))
	var mm:MultiMesh=rain[0].batch
	check(mm.instance_count==64 and mm.visible_instance_count==33,"Actual settled rain crosses both 16-to-32 and 32-to-64 resize boundaries")
	var remove:=rain[3];var moved:Node3D=rain.back();var mesh_id:int=remove.food_visual.mesh.get_instance_id()
	remove.start_fall(game.player)
	check(remove.batch==null and remove.food_visual.visible and remove.food_visual.mesh.get_instance_id()==mesh_id,"Independent release exposes the same colored mesh rather than replacing geometry")
	check(moved.batch_index==3 and mm.visible_instance_count==32,"Releasing a middle member compacts its last actual neighbor")
	verify_batch(mm,"After middle removal")
	var replacement:=rain_piece()
	check(replacement.batch==mm and replacement.batch_index==32 and mm.visible_instance_count==33,"New rain reuses the vacated allocated slot")
	verify_batch(mm,"After slot reuse")
	replacement.set_reveal_weight(1.0)
	check(replacement.reveal_weight==0.0 and mm.get_instance_custom_data(32).r==0.0,"Legacy dither writes cannot change food opacity or instance finish")
	evidence={"dummy_getter_control":{"written":[1,1,1,1],"read":[sentinel_read.r,sentinel_read.g,sentinel_read.b,sentinel_read.a]},"mode":"prior-package-defect" if baseline else "corrected-source","source_tool_visible":FileAccess.file_exists("res://tools/release_web.py"),"mesh_hashes":meshes,"palette":palette,"shader_code":shader,"shader_sha256":digest(shader.to_utf8_buffer()),"batches":all_batches,"rain_final":state(mm),"scope":"Actual scene and resource state; separately bound windowless GPU equation checks are required for pixel evidence."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			var path:=arg.trim_prefix("--capture=")
			if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):check(false,"Capture path is an explicit native absolute path");continue
			var output:=FileAccess.open(path,FileAccess.WRITE)
			if output==null:check(false,"Capture output can be opened");continue
			output.store_string(JSON.stringify(evidence,"\t")+"\n")
	game.free();await process_frame;await process_frame
	print("FOOD_COLOR_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"mesh_count":meshes.size(),"batches":count,"palette_count":palette.size(),"baseline":baseline}))
	quit(0 if failures.is_empty() else 1)
