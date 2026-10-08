extends "res://artifacts/video-showcase-20260928/city/export_city.gd"
## The real home-screen miniature roots and cameras, exported offline.
func geometry(source:Mesh,override_:Material=null,skin_node:MeshInstance3D=null)->Dictionary:
	var record:=super.geometry(source,override_,skin_node)
	record["uvs"]=[]
	for surface in source.get_surface_count():
		var a:Array=source.surface_get_arrays(surface)
		var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
		for i in a[Mesh.ARRAY_VERTEX].size():
			var at:=uv[i] if i<uv.size() else Vector2.ZERO
			record.uvs.append_array([at.x,at.y])
	if override_ is ShaderMaterial and override_.shader.resource_path.ends_with("facade.gdshader"):
		record["facade"]={}
		for key in ["wall_color","glass_color","floors","columns","glass_tower"]:
			var v=override_.get_shader_parameter(key)
			if v is Color:record.facade[key]=color_array(v.srgb_to_linear())
			else:record.facade[key]=v
	return record
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):push_error("Requires --test");quit(1);return
	output+="/hero";DirAccess.make_dir_recursive_absolute(output)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	for map_id in ["city","food"]:
		game.select_map(map_id)
		await process_frame
		var camera:Camera3D=game.ui.hero_view.get_camera_3d()
		frame_tag="home-"+map_id+"-miniature"
		var instances:Array=[];gather(game.ui.hero_models,instances)
		var result:={"width":640,"height":560,"transparent":true,"projection":projection(camera.get_camera_projection()),"view":matrix(camera.global_transform.affine_inverse()),"instances":instances,"ground":{"vertices":[],"normals":[],"colors":[],"indices":[]},"openings":[],"ground_uniforms":{},"elapsed":0,"scope":"Actual home miniature root and camera, rendered in offline CGL with approximate lighting; not a Godot viewport"}
		FileAccess.open(output+"/"+frame_tag+".json",FileAccess.WRITE).store_string(JSON.stringify(result))
		print("CITY_HOME_MINIATURE "+JSON.stringify({"map":map_id,"instances":instances.size(),"camera_size":camera.size}))
	FileAccess.open(output+"/render-meshes.json",FileAccess.WRITE).store_string(JSON.stringify(meshes))
	game.free();await process_frame;quit()
