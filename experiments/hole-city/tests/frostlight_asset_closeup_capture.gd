extends SceneTree
## Dedicated Frostlight GLB close-up pixels. This is separate from the map
## overview capture so a single imported asset cannot hide behind scale.

const GLACIER: PackedScene = preload("res://assets/frost/glacier.glb")
const ICE_ROCK: PackedScene = preload("res://assets/frost/ice_rock.glb")

var directory := ""
var camera: Camera3D
var glacier: Node3D
var rock: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _wait_and_capture(label: String) -> void:
	for _index in 8:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(directory + "/" + label + ".png") == OK)

func _run() -> void:
	assert(OS.get_cmdline_user_args().has("--test"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	assert(not directory.is_empty())
	DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 960)

	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("102b43")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("8bbbd1")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.7
	sun.light_color = Color("d8f5ff")
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.55
	fill.light_color = Color("78b9d4")
	fill.rotation_degrees = Vector3(-25.0, 145.0, 0.0)
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(22.0, 22.0)
	ground.mesh = ground_mesh
	ground.position.y = -0.03
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("173b54")
	ground_material.roughness = 0.42
	ground.material_override = ground_material
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.position = Vector3(6.8, 5.0, 8.2)
	stage.add_child(camera)
	camera.current = true

	glacier = GLACIER.instantiate()
	glacier.scale = Vector3(3.8, 6.0, 4.5)
	glacier.position = Vector3(0.0, 0.0, 0.0)
	stage.add_child(glacier)
	camera.look_at(Vector3(0.0, 2.3, 0.0))
	await _wait_and_capture("glacier-hero-closeup")

	glacier.visible = false
	rock = ICE_ROCK.instantiate()
	rock.scale = Vector3(3.0, 3.0, 2.5)
	rock.position = Vector3(0.0, 0.0, 0.0)
	stage.add_child(rock)
	camera.size = 3.8
	camera.position = Vector3(4.2, 3.0, 5.0)
	camera.look_at(Vector3(0.0, 1.25, 0.0))
	await _wait_and_capture("ice-rock-hero-closeup")

	FileAccess.open(directory + "/capture.json", FileAccess.WRITE).store_string(JSON.stringify({
		"scope": "Dedicated imported Frostlight GLB close-up pixels; no gameplay or release claim",
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": root.size,
		"assets": ["res://assets/frost/glacier.glb", "res://assets/frost/ice_rock.glb"]
	}, "\t"))
	quit()
