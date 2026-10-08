extends SceneTree
const Catalog=preload("res://fidelity/skin_catalog.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var old_path:="";var out_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--old-visual="):old_path=arg.trim_prefix("--old-visual=")
		if arg.begins_with("--report="):out_path=arg.trim_prefix("--report=")
	var script:Script=load(old_path);var model:Node3D=script.new();root.add_child(model);model.set_process(false)
	var report:Dictionary={}
	for definition in Catalog.DEFS:
		model.build(definition,false)
		var triangles:=0;var visible:=0;var meshes:=model.find_children("*","MeshInstance3D",true,false)
		for mesh in meshes:
			if mesh.visible:visible+=1
			for surface in mesh.mesh.get_surface_count():
				var arrays:Array=mesh.mesh.surface_get_arrays(surface)
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		report[definition.id]={"visible":visible,"meshes":meshes.size(),"triangles":triangles,"motes":model.motes.size(),"parts":model.parts.size()}
	FileAccess.open(out_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");model.free();await process_frame;print("OLD_RARITY_GEOMETRY 44");quit()
