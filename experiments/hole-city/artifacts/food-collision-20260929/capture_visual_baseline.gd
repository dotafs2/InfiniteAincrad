extends SceneTree
const KINDS:=["bacon","egg","cake","donut","burger","cookie","berry","sushi","pancake","pizza"]
func _initialize()->void:run.call_deferred()
func digest(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for kind in KINDS:
		for tower in [false,true]:
			for flavor in [0,2,4]:game.city.food(kind,Vector2(70,70),.6,3,tower,flavor)
	var meshes:Dictionary={}
	for key in game.city.mesh_cache:
		var mesh:Mesh=game.city.mesh_cache[key];var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
		for surface in mesh.get_surface_count():hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
		meshes[key]={"arrays_sha256":hash.finish().hex_encode(),"bounds_position":str(mesh.get_aabb().position),"bounds_size":str(mesh.get_aabb().size),"surfaces":mesh.get_surface_count()}
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"mesh_fingerprints":meshes,"shader_code_sha256":digest(game.city.food_material.shader.code.to_utf8_buffer()),"shader_path":game.city.food_material.shader.resource_path,"scope":"Read-only resource arrays and shader text from preserved prior release; no render capture"}
	print("FOOD_COLLISION_BASELINE "+JSON.stringify(result))
	game.free();await process_frame;quit()
