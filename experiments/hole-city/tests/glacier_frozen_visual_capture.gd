extends SceneTree
const Ice=preload("res://fidelity/frost_ice.gd")
var directory:=""
var game:Node3D
func _initialize()->void:run.call_deferred()
func snap(label:String)->void:
	for _i in 6:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/"+label+".png")
func run()->void:
	assert(OS.get_cmdline_user_args().has("--test"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture-dir="):directory=a.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,960)
	game=load("res://fidelity/main.tscn").instantiate();game.selected_map="frost"
	game.test_progress_path="/tmp/hole-feast-glacier-visual-%d.cfg"%OS.get_process_id()
	root.add_child(game)
	await process_frame
	await snap("home-preview")
	game.ui.open_maps();await snap("world-chooser");game.ui.close_menu()
	game.start_level()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.court.set_process(false)
	for h in game.holes:h.enabled=false
	game.ui.visible=false
	game.camera.far=800;game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=225;game.camera.position=Vector3(125,155,150);game.camera.look_at(Vector3(0,2,0))
	await snap("world-overview")
	game.camera.size=44;game.camera.position=Vector3(116,34,-28);game.camera.look_at(Vector3(72,1,-70))
	await snap("polar-life")
	game.camera.size=49;game.camera.position=Vector3(32,33,75);game.camera.look_at(Vector3(20,1,40))
	await snap("opening-basin")
	game.world.visible=false
	var stage:=Node3D.new();root.add_child(stage)
	var shelf:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(80,80);shelf.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("183c60");mat.roughness=.6;shelf.material_override=mat;stage.add_child(shelf)
	for index in Ice.ASSETS.size():
		var asset:=Ice.make(index,Vector3(7,5.5 if index<4 else 2.7,5.8));stage.add_child(asset)
		game.camera.size=11;game.camera.position=Vector3(8,6.5,10);game.camera.look_at(Vector3(0,2,0))
		await snap(Ice.NAMES[index])
		if index==0:
			game.camera.position=Vector3(-9,5.8,7);game.camera.look_at(Vector3(0,2,0))
			await snap("calving-cliff-reverse")
		asset.queue_free();await process_frame
	game.free();stage.free();await process_frame;quit()
