extends Node3D
## Isolated visual review scene for F1_Residence_06.
## Loads only the DeepSeek wrapper and never reads or writes world/spatial/save
## state. --capture-dir=<absolute> waits warm frames, then captures three
## deterministic views and writes an evidence JSON with actual mesh counts,
## triangle totals and LOD states before quitting.

@export var capture_dir := ""
@export var warm_frames := 30

const WRAPPER_SCRIPT := "res://spatial/deepseek_residences_component.gd"
var _failure := 0

func _ready() -> void:
	_parse_args()
	_build_scene()
	if not capture_dir.is_empty():
		await _capture_all()
		get_tree().quit(_failure)

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.substr(len("--capture-dir="))
		elif arg.begins_with("--warm-frames="):
			warm_frames = int(arg.substr(len("--warm-frames=")))

func _build_scene() -> void:
	if get_node_or_null("ReviewCamera") == null:
		var cam := Camera3D.new()
		cam.name = "ReviewCamera"
		cam.current = true
		cam.fov = 42.0
		add_child(cam)
	if get_node_or_null("ReviewGround") == null:
		var floor := StaticBody3D.new()
		floor.name = "ReviewGround"
		var gmesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(80.0, 80.0)
		gmesh.mesh = plane
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.33, 0.32, 0.29)
		gm.roughness = 1.0
		gmesh.material_override = gm
		gmesh.position = Vector3(0.0, 0.0, 0.0)
		floor.add_child(gmesh)
		add_child(floor)
	if get_node_or_null("ReviewSun") == null:
		var sun := DirectionalLight3D.new()
		sun.name = "ReviewSun"
		sun.rotation_degrees = Vector3(-44.0, 36.0, 0.0)
		sun.light_energy = 1.15
		sun.shadow_enabled = true
		add_child(sun)
		var fill := DirectionalLight3D.new()
		fill.name = "ReviewFill"
		fill.rotation_degrees = Vector3(-24.0, -128.0, 0.0)
		fill.light_energy = 0.35
		add_child(fill)
	if get_node_or_null("ReviewEnv") == null:
		var env_node := WorldEnvironment.new()
		env_node.name = "ReviewEnv"
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.70, 0.76, 0.82)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.56, 0.58, 0.62)
		env.ambient_light_energy = 0.75
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env_node.environment = env
		add_child(env_node)
	# Forced LOD0 must be set BEFORE the wrapper builds so it never enables
	# distance-based visibility during the review pass.
	if get_node_or_null("DeepSeekResidence") == null:
		var wrapper := Node3D.new()
		wrapper.name = "DeepSeekResidence"
		wrapper.set_script(load(WRAPPER_SCRIPT))
		wrapper.set("force_lod", 0)
		wrapper.set("collision_enabled", true)
		add_child(wrapper)
	_place_camera(Vector3(15.0, 9.5, 13.5), Vector3(0.0, 3.0, 0.0))

func _place_camera(pos: Vector3, look: Vector3) -> void:
	var cam := get_node_or_null("ReviewCamera") as Camera3D
	if cam == null: return
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)

func _capture_all() -> void:
	var mk := DirAccess.make_dir_recursive_absolute(capture_dir)
	if mk != OK and mk != ERR_ALREADY_EXISTS:
		push_error("cannot create capture dir: " + str(mk))
		_failure = 3
		return
	var shots := [
		{"name": "front_three_quarter", "pos": Vector3(15.0, 9.5, 13.5), "look": Vector3(0.0, 2.8, 0.0)},
		{"name": "rear_three_quarter", "pos": Vector3(-13.5, 8.5, -14.0), "look": Vector3(0.0, 2.8, 0.0)},
		{"name": "near_facade_door", "pos": Vector3(-4.5, 2.4, 9.0), "look": Vector3(-1.6, 1.8, 0.0)},
	]
	var evidence := {
		"asset": "F1_Residence_06",
		"capture_dir": capture_dir,
		"forced_lod": 0,
		"warm_frames": warm_frames,
		"shots": [],
	}
	for shot in shots:
		_place_camera(shot["pos"], shot["look"])
		for i in range(warm_frames):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var png := capture_dir.path_join(String(shot["name"]) + ".png")
		var err := image.save_png(png)
		if err != OK:
			push_error("save_png failed for " + png + " err=" + str(err))
			_failure = 4
		evidence["shots"].append({"name": shot["name"], "file": png, "save_err": err})
	evidence["mesh_report"] = _mesh_report()
	evidence["lod_forced_state"] = _lod_forced_state()
	var json_path := capture_dir.path_join("deepseek_residences_evidence.json")
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open evidence json: " + json_path)
		_failure = 5
	else:
		f.store_string(JSON.stringify(evidence, "  "))
		f.close()
	print("DEEPSEEK_REVIEW_EVIDENCE " + json_path)

func _lod_forced_state() -> Array:
	var report: Array = []
	var root := get_node_or_null("DeepSeekResidence")
	if root == null: return report
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		report.append({
			"name": str(mi.name),
			"lod": int(mi.get_meta("lod", -1)),
			"visible": mi.is_visible_in_tree(),
		})
	return report

func _mesh_report() -> Array:
	var report: Array = []
	var root := get_node_or_null("DeepSeekResidence")
	if root == null: return report
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null: continue
		var verts := mesh.get_faces()
		var tris := verts.size() / 3
		var surfaces := mesh.get_surface_count()
		report.append({
			"name": str(mi.name),
			"lod": int(mi.get_meta("lod", -1)),
			"visible": mi.is_visible_in_tree(),
			"triangles": tris,
			"surfaces": surfaces,
		})
	return report
