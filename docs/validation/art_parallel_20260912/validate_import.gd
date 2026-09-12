extends SceneTree

func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected absolute glb_audit.json and output JSON")
		quit(2)
		return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var source_root: String = args[0].get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	var results: Array = []
	var failed: Array = []
	for record in input.get("files", []):
		var path: String = source_root.path_join(record.file)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var code := document.append_from_file(path, state)
		if code != OK:
			failed.append({"file":record.file,"error":code})
			continue
		var model := document.generate_scene(state)
		if model == null:
			failed.append({"file":record.file,"error":"null scene"})
			continue
		var nodes: Array[Node] = [model]
		var mesh_count := 0
		var surface_count := 0
		var material_count := 0
		var vertex_count := 0
		while not nodes.is_empty():
			var node := nodes.pop_back() as Node
			for child in node.get_children():
				nodes.append(child)
			if node is MeshInstance3D:
				var mesh := (node as MeshInstance3D).mesh
				if mesh == null:
					continue
				mesh_count += 1
				surface_count += mesh.get_surface_count()
				for index in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(index)
					vertex_count += arrays[Mesh.ARRAY_VERTEX].size()
					if mesh.surface_get_material(index) != null:
						material_count += 1
		if mesh_count == 0 or vertex_count == 0 or surface_count != material_count:
			failed.append({"file":record.file,"error":"missing geometry or material"})
		results.append({"file":record.file,"mesh_count":mesh_count,"surface_count":surface_count,"material_surfaces":material_count,"vertices":vertex_count})
		model.free()
		print("ART_IMPORT ", record.file)
	var output := {"engine":Engine.get_version_info().string,"mode":"offline GLTFDocument import; no world scene or save loaded","tested":results.size(),"failures":failed,"results":results}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	print("ART_IMPORT_COMPLETE ", results.size(), " failures=", failed.size())
	quit(0 if failed.is_empty() else 1)
