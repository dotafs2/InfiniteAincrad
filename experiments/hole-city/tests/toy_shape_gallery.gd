extends SceneTree
## Actual toy shader/mesh GPU gallery, separate from gameplay acceptance.
const Shapes=preload("res://fidelity/toy_shapes.gd")
const Preview=preload("res://fidelity/toy_preview.gd")
const CourtShapes=preload("res://fidelity/toy_guard_shapes.gd")
var directory:=""
var scene:Node3D
var camera:Camera3D

func _initialize()->void:run.call_deferred()

func capture(label:String)->void:
	for _i in 8:await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image!=null and not image.is_empty())
	assert(image.save_png(directory+"/"+label+".png")==OK)

func run()->void:
	assert(OS.get_cmdline_user_args().has("--test") and DisplayServer.get_name()!="headless")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):directory=argument.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,960)
	scene=Node3D.new();root.add_child(scene)
	var environment_node:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("d5e8f4")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color.WHITE
	environment.ambient_light_energy=.42
	environment_node.environment=environment;scene.add_child(environment_node)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-52,-38,0);sun.light_energy=.64
	sun.shadow_enabled=true;scene.add_child(sun)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=20;scene.add_child(camera);camera.current=true
	camera.position=Vector3(9,14,21);camera.look_at(Vector3(0,1,0))
	var gallery:=Node3D.new();scene.add_child(gallery)
	var floor_view:=MeshInstance3D.new()
	var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(24,19)
	var floor_material:=StandardMaterial3D.new()
	floor_material.albedo_color=Color("a9bdb5");floor_material.roughness=1.0
	floor_view.mesh=floor_mesh;floor_view.material_override=floor_material
	floor_view.position.y=-.015;gallery.add_child(floor_view)
	for index in Shapes.KINDS.size():
		var kind:String=Shapes.KINDS[index]
		var visual:=MeshInstance3D.new();visual.mesh=Shapes.mesh_for(kind,index)
		visual.material_override=Shapes.material()
		var natural:=Shapes.natural_size_for(kind)
		var extent:=natural*(2.4/maxf(natural.x,maxf(natural.y,natural.z)))
		visual.scale=extent
		visual.position=Vector3(-6.4+float(index%5)*3.2,0,-2.2+float(index/5)*4.4)
		gallery.add_child(visual)
	await capture("toy-shape-vocabulary")
	gallery.free()
	var court_gallery:=Node3D.new();scene.add_child(court_gallery)
	var court_floor:=MeshInstance3D.new();court_gallery.add_child(court_floor)
	court_floor.mesh=floor_mesh;court_floor.material_override=floor_material
	court_floor.position.y=-.015
	camera.size=16;camera.position=Vector3(8,12,23)
	camera.look_at(Vector3(0,1,0))
	var court_rows:=ceili(float(CourtShapes.KINDS.size())/6.0)
	for index in CourtShapes.KINDS.size():
		var role:String=CourtShapes.KINDS[index]
		var figure:=MeshInstance3D.new();court_gallery.add_child(figure)
		figure.mesh=CourtShapes.mesh_for(role,index)
		figure.material_override=CourtShapes.material()
		var natural:=CourtShapes.natural_size_for(role)
		figure.scale=natural*(2.6/maxf(natural.x,maxf(natural.y,natural.z)))
		figure.position=Vector3(-8.0+float(index%6)*3.2,0,(float(index/6)-float(court_rows-1)*.5)*4.5)
	await capture("toy-court-vocabulary")
	court_gallery.free()
	var preview:=Preview.new();scene.add_child(preview);preview.build_preview()
	preview.set_process(false)
	camera.size=21;camera.position=Vector3(19,24,26)
	camera.look_at(Vector3(0,4,0))
	await capture("toy-miniature")
	preview.preview.rotation.y=-.65
	await capture("toy-miniature-turn")
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({
		"version":ProjectSettings.get_setting("application/config/version"),
		"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),
		"scope":"Actual desktop GPU toy/royal-role geometry and miniature, no physical iPhone, NPC behavior or gameplay pacing claim",
		"court_role_order":CourtShapes.KINDS,"muted":true},"\t"))
	scene.free();await process_frame;quit()
