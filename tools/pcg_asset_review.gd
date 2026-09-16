extends SceneTree
## Read-only GLB review. Imports raw provider files at runtime in an isolated project.
var scene: Node3D
var camera: Camera3D
var output := ""
var catalog_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--catalog="): catalog_path=arg.trim_prefix("--catalog=")
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	_render.call_deferred()

func _render() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	DirAccess.make_dir_recursive_absolute(output)
	scene=Node3D.new()
	root.add_child(scene)
	var env:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.105,.12,.135)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.88,.91,1)
	environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=environment
	scene.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-30,0)
	sun.light_energy=1.35
	scene.add_child(sun)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-20,145,0)
	fill.light_energy=.45
	scene.add_child(fill)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=10000
	scene.add_child(camera)
	camera.make_current()
	var results:=[]
	for item: Dictionary in catalog.items:
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		var error:=doc.append_from_file(item.path,state)
		if error!=OK:
			push_error("GLB review import failed: "+item.id)
			quit(2)
			return
		var model: Node3D=doc.generate_scene(state)
		scene.add_child(model)
		var low:=Vector3.INF
		var high:=-Vector3.INF
		var meshes: Array[Node]=model.find_children("*","MeshInstance3D",true,false)
		if model is MeshInstance3D: meshes.append(model)
		for mesh: MeshInstance3D in meshes:
			var aabb:=mesh.mesh.get_aabb()
			for n in 8:
				var v: Vector3=mesh.global_transform*aabb.get_endpoint(n)
				low=low.min(v)
				high=high.max(v)
		var size:=high-low
		model.position-=(low+high)*.5
		var radius:=maxf(size.length()*.5,.05)
		camera.size=maxf(size.y,sqrt(size.x*size.x+size.z*size.z))*1.20
		var views:=[]
		for index in 4:
			var angle:=deg_to_rad(30+index*90)
			var elevation:=deg_to_rad(12 if item.id.ends_with("tree") else 24)
			camera.position=Vector3(sin(angle)*cos(elevation),sin(elevation),cos(angle)*cos(elevation))*radius*4
			camera.look_at(Vector3.ZERO)
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			var filename: String=item.id+"-"+str(index)+".png"
			root.get_texture().get_image().save_png(output.path_join(filename))
			views.append(filename)
		results.append({"id":item.id,"views":views,"bounds_size":[size.x,size.y,size.z],"meshes":meshes.size()})
		print("ASSET_REVIEW_RENDERED ",item.id)
		model.queue_free()
		await process_frame
	var file:=FileAccess.open(output.path_join("renders.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	quit()
