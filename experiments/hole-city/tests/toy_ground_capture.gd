extends SceneTree
## Actual play-mat shader on the production cut slab, isolated from changing NPC
## source. This staged GPU image is a lighting check, not gameplay acceptance.
const Ground=preload("res://fidelity/cut_ground.gd")
const Surface=preload("res://fidelity/toy_ground.gdshader")
class Owner:
	extends Node3D
	var holes:Array[Node3D]=[]
class Mouth:
	extends Node3D
	var active:=true
	var radius:=5.0
var directory:=""

func _initialize()->void:run.call_deferred()

func run()->void:
	assert(OS.get_cmdline_user_args().has("--test") and DisplayServer.get_name()!="headless")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):directory=argument.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,960)
	var scene:=Owner.new();root.add_child(scene)
	var mouth:=Mouth.new();scene.add_child(mouth)
	mouth.position=Vector3(10,0,28);scene.holes.append(mouth)
	var mat:=ShaderMaterial.new();mat.shader=Surface
	var ground:=Ground.new();scene.add_child(ground);ground.build(scene,mat)
	var environment_node:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("d5e8f4")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color.WHITE
	environment.ambient_light_energy=.42
	environment_node.environment=environment;scene.add_child(environment_node)
	var sun:=DirectionalLight3D.new();scene.add_child(sun)
	sun.rotation_degrees=Vector3(-52,-38,0);sun.light_energy=.64
	sun.shadow_enabled=true;sun.shadow_opacity=.58
	var camera:=Camera3D.new();scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=225
	camera.position=Vector3(125,155,150);camera.look_at(Vector3.ZERO);camera.current=true
	for _i in 8:await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	assert(picture!=null and not picture.is_empty())
	assert(picture.save_png(directory+"/toy-play-mat.png")==OK)
	FileAccess.open(directory+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({
		"scope":"Staged actual Mac GPU lighting check of the production cut slab and toy shader; no NPC, normal-play or iPhone claim",
		"renderer":RenderingServer.get_current_rendering_method(),"muted":true,
		"ground_triangles":ground.collision_vertices.size()/3,"mouth_radius":mouth.radius},"\t"))
	scene.free();await process_frame;quit()
