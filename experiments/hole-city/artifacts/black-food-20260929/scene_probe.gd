extends SceneTree
const Game=preload("res://fidelity/game.gd")
var out_path:=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):out_path=arg.trim_prefix("--report=")
	run.call_deferred()
func digest(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:=Game.new();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false)
	game.city.set_process(false);game.city.set_physics_process(false);game.city.rain_enabled=false
	var rows:Array=[];var palette:Dictionary={};var meshes:Dictionary={};var all_colorful:=true
	for key in game.city.mesh_cache:
		var mesh:Mesh=game.city.mesh_cache[key];var a:=mesh.surface_get_arrays(0);var colors:PackedColorArray=a[Mesh.ARRAY_COLOR]
		var min_value:=1.0;var max_value:=0.0
		for color in colors:
			min_value=minf(min_value,maxf(color.r,maxf(color.g,color.b)));max_value=maxf(max_value,maxf(color.r,maxf(color.g,color.b)))
			palette[color.to_html()]=[color.r,color.g,color.b,color.a]
		meshes[key]={"sha256":digest(var_to_bytes(a)),"vertices":colors.size(),"minimum_max_rgb":min_value,"maximum_rgb":max_value}
		all_colorful=all_colorful and colors.size()==a[Mesh.ARRAY_VERTEX].size() and min_value>.1
	for view in game.city.find_children("*","MultiMeshInstance3D",false,false):
		if view.material_override!=game.city.food_batch_material:continue
		rows.append({"instances":view.multimesh.instance_count,"use_colors":view.multimesh.use_colors,"use_custom_data":view.multimesh.use_custom_data})
	var report:={"package_root":ProjectSettings.globalize_path("res://"),"source_tool_visible":FileAccess.file_exists("res://tools/release_web.py"),"shader_sha256":digest(game.city.food_material.shader.code.to_utf8_buffer()),"mesh_count":meshes.size(),"meshes":meshes,"palette":palette,"all_vertex_colors_present_and_nonblack":all_colorful,"batches":rows,"hazardous_custom_without_color":rows.filter(func(row):return row.use_custom_data and not row.use_colors).size()}
	print("FOOD_COLOR_SCENE "+JSON.stringify(report))
	FileAccess.open(out_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	game.free();await process_frame;quit()
