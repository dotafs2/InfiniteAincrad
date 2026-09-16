extends Node3D
## Independent, continuous first-floor art sample; no canonical-world startup.
## All coordinates are Godot metres. Plaza (0,0,0); north is negative Z.

const MODULAR_SCRIPT: GDScript = preload("res://spatial/modular_house_component.gd")
const INTERIOR_SCRIPT: GDScript = preload("res://spatial/floor1_modular_interior.gd")
const MESHY_SCRIPT: GDScript = preload("res://spatial/meshy_house_lod_component.gd")
const WALKER_SCRIPT: GDScript = preload("res://spatial/floor1_art_walker.gd")
const HERO_PATH := "res://assets/floor1/StartingTown_Floor1_HeroKit.glb"
const MARKET_PATH := "res://assets/market/StartingTown_Market_CraftV5.glb"
const FOUNTAIN_PATH := "res://assets/floor1/plaza_fountain_20260916/F1_plaza_fountain.glb"
const COURTYARD_OAK_PATH := "res://assets/floor1/courtyard_oak_20260916/F1_courtyard_oak_100k.glb"
const NATIVE_FOREST_OAK_TRIAL_PATH := "res://assets/floor1/courtyard_oak_20260916/F1_oak_smart15k_forest_trial.glb"
const MEADOW_ALBEDO_PATH := "res://assets/floor1/ground_textures_20260916/meadow_grass_albedo_v1.png"
const ENV_PATH := "res://assets/floor1/environment_kit_20/"
const CARGO_PATH := "res://assets/generated/travel_cargo_20260912/"
const VARIANTS := ["01_hearth_cottage", "02_market_house", "03_corner_turret"]

@export var review_mode := false
@export_enum("4k", "2k") var exterior_texture_tier := "2k"
@export_range(0.0, 0.40, 0.01) var meadow_texture_mix := 0.22
var interactive_houses: Array[Node3D] = []
var furnished_interiors: Array[Node3D] = []
var exterior_houses: Array[Node3D] = []
var layout_rows: Array[Dictionary] = []
var _asset_cache: Dictionary = {}
var _palette: Dictionary = {}
var _surface_shader: Shader
var _capture_dir := ""
var _window_probe_dir := ""
var _lod_near_probe_dir := ""
var _landscape_probe_dir := ""
var _oak_probe_dir := ""
var _forest_edge_probe_dir := ""
var _meadow_probe_dir := ""
var _lantern_probe_dir := ""
var _north_sector_probe_dir := ""
var _bakery_sign_probe_dir := ""
var _native_oak_probe_dir := ""
var _native_oak_trial := true
var _tour_output := ""
var _tour_version := "v1"
var _tour_stills_dir := ""
var _tour_frame := 0
var _tour_keyframes: Array[Dictionary] = []
var _tour_finishing := false
var _tour_demo_house: Node3D
var _review_camera: Camera3D
var _walker: CharacterBody3D
var _sun: DirectionalLight3D
var _collidable_boxes := 0
var _vegetation_instances := 0
var _tree_instances := 0
var _prop_instances := 0
var _fountain_scale := 0.0
var _farm_plots := 0
var _perimeter_ridge_bodies := 0
var _perimeter_ridge_triangles := 0
var _perimeter_ridge_max_height_m := 0.0
var _forest_bank_bodies := 0
var _forest_bank_triangles := 0
var _forest_bank_max_height_m := 0.0
var _north_sector_collision_bodies := 0
var _north_sector_triangles := 0
var _north_sector_max_height_m := 0.0
var _north_sector_trees: Array[Node3D] = []
var _courtyard_oak: Node3D
var _native_forest_oak_trial: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--window-probe-dir="):
			_window_probe_dir = arg.trim_prefix("--window-probe-dir=")
		elif arg.begins_with("--lod-near-probe-dir="):
			_lod_near_probe_dir = arg.trim_prefix("--lod-near-probe-dir=")
		elif arg.begins_with("--landscape-probe-dir="):
			_landscape_probe_dir = arg.trim_prefix("--landscape-probe-dir=")
		elif arg.begins_with("--oak-probe-dir="):
			_oak_probe_dir = arg.trim_prefix("--oak-probe-dir=")
		elif arg.begins_with("--forest-edge-probe-dir="):
			_forest_edge_probe_dir = arg.trim_prefix("--forest-edge-probe-dir=")
		elif arg.begins_with("--meadow-probe-dir="):
			_meadow_probe_dir = arg.trim_prefix("--meadow-probe-dir=")
		elif arg.begins_with("--lantern-probe-dir="):
			_lantern_probe_dir = arg.trim_prefix("--lantern-probe-dir=")
		elif arg.begins_with("--north-sector-probe-dir="):
			_north_sector_probe_dir = arg.trim_prefix("--north-sector-probe-dir=")
		elif arg.begins_with("--bakery-sign-probe-dir="):
			_bakery_sign_probe_dir = arg.trim_prefix("--bakery-sign-probe-dir=")
		elif arg.begins_with("--native-oak-probe-dir="):
			_native_oak_probe_dir = arg.trim_prefix("--native-oak-probe-dir=")
		elif arg == "--native-oak-trial":
			_native_oak_trial = true
		elif arg.begins_with("--native-oak-trial="):
			var tree_switch := arg.trim_prefix("--native-oak-trial=")
			if tree_switch in ["off", "false", "0"]:
				_native_oak_trial = false
			elif tree_switch in ["on", "true", "1"]:
				_native_oak_trial = true
			else:
				push_error("Unknown native forest oak switch: " + tree_switch)
		elif arg.begins_with("--meadow-texture-mix="):
			meadow_texture_mix = clampf(float(arg.trim_prefix("--meadow-texture-mix=")), 0.0, 0.40)
		elif arg.begins_with("--tour-output="):
			_tour_output = arg.trim_prefix("--tour-output=")
		elif arg.begins_with("--tour-version="):
			_tour_version = arg.trim_prefix("--tour-version=")
		elif arg.begins_with("--tour-stills-dir="):
			_tour_stills_dir = arg.trim_prefix("--tour-stills-dir=")
		elif arg.begins_with("--lod-texture-tier="):
			var requested_tier := arg.trim_prefix("--lod-texture-tier=")
			if requested_tier in ["4k", "2k"]:
				exterior_texture_tier = requested_tier
			else:
				push_error("Unknown expanded-world exterior texture tier: " + requested_tier)
	_make_palette()
	_sky_and_sun()
	_ground_and_roads()
	_plaza()
	_fortifications()
	_place_houses()
	_residential_details()
	_market_details()
	_countryside()
	_labyrinth_silhouette()
	if not review_mode:
		if not _tour_output.is_empty():
			_make_review_camera()
			_init_tour()
		elif not _tour_stills_dir.is_empty():
			_make_review_camera()
			_init_tour()
			_capture_tour_v2_stills.call_deferred()
		elif not _window_probe_dir.is_empty():
			_make_review_camera()
			_capture_window_probe.call_deferred()
		elif not _lod_near_probe_dir.is_empty():
			_make_review_camera()
			_capture_lod_near_probe.call_deferred()
		elif not _landscape_probe_dir.is_empty():
			_make_review_camera()
			_capture_landscape_probe.call_deferred()
		elif not _oak_probe_dir.is_empty():
			_make_review_camera()
			_capture_oak_probe.call_deferred()
		elif not _forest_edge_probe_dir.is_empty():
			_make_review_camera()
			_capture_forest_edge_probe.call_deferred()
		elif not _meadow_probe_dir.is_empty():
			_make_review_camera()
			_capture_meadow_probe.call_deferred()
		elif not _lantern_probe_dir.is_empty():
			_make_review_camera()
			_capture_lantern_probe.call_deferred()
		elif not _north_sector_probe_dir.is_empty():
			_make_review_camera()
			_capture_north_sector_probe.call_deferred()
		elif not _bakery_sign_probe_dir.is_empty():
			_make_review_camera()
			_capture_bakery_sign_probe.call_deferred()
		elif not _native_oak_probe_dir.is_empty():
			_make_review_camera()
			_capture_native_oak_probe.call_deferred()
		elif _capture_dir.is_empty():
			_make_walker()
		else:
			_make_review_camera()
			_capture_tour.call_deferred()
	_make_small_label()
	set_meta("fixture", "standalone_floor1_art_sample")
	set_meta("world_state_mutations", 0)


func _process(_delta: float) -> void:
	if _tour_output.is_empty() or _review_camera == null or _tour_finishing:
		return
	var time_s := float(_tour_frame) / 30.0
	if _tour_version == "v2":
		_stage_tour_v2_door(time_s)
	var pose: Dictionary = _tour_pose_at(time_s)
	_pose(pose["position"], pose["target"])
	_tour_frame += 1
	if _tour_frame >= (1801 if _tour_version == "v2" else 901):
		_tour_finishing = true
		_finish_tour.call_deferred()


func _tour_pose_at(time_s: float) -> Dictionary:
	var start_s := 0.0
	for index in range(_tour_keyframes.size() - 1):
		var current: Dictionary = _tour_keyframes[index]
		var next: Dictionary = _tour_keyframes[index + 1]
		var duration_s := float(current["duration_to_next_s"])
		if time_s <= start_s + duration_s or index == _tour_keyframes.size() - 2:
			var phase := clampf((time_s - start_s) / duration_s, 0.0, 1.0)
			var ease := phase * phase * (3.0 - 2.0 * phase)
			var current_position: Vector3 = current["position"]
			var next_position: Vector3 = next["position"]
			var current_target: Vector3 = current["target"]
			var next_target: Vector3 = next["target"]
			return {"position": current_position.lerp(next_position, ease),
				"target": current_target.lerp(next_target, ease)}
		start_s += duration_s
	return {"position": _tour_keyframes[-1]["position"],
		"target": _tour_keyframes[-1]["target"]}


func _init_tour() -> void:
	if _tour_version == "v2":
		_init_tour_v2()
		return
	# This is an interpolated camera inside the one real world. It follows the
	# main road, residential lane, north gate opening and countryside path.
	_tour_keyframes = [
		{"position": Vector3(0, 1.72, 66), "target": Vector3(0, 2, 18), "duration_to_next_s": 3.0},
		{"position": Vector3(0, 1.72, 18), "target": Vector3(0, 2.4, -28), "duration_to_next_s": 5.0},
		{"position": Vector3(0, 1.72, -45), "target": Vector3(0, 4, -85), "duration_to_next_s": 2.0},
		{"position": Vector3(0, 1.72, -69), "target": Vector3(-35, 2.0, -69), "duration_to_next_s": 3.0},
		{"position": Vector3(-35, 1.72, -69), "target": Vector3(-35, 3.6, -29), "duration_to_next_s": 4.0},
		{"position": Vector3(-35, 1.72, -29), "target": Vector3(-35, 4, -55), "duration_to_next_s": 3.0},
		{"position": Vector3(-35, 10, -74), "target": Vector3(0, 6, -85), "duration_to_next_s": 2.0},
		{"position": Vector3(0, 3.0, -79), "target": Vector3(0, 3.0, -98), "duration_to_next_s": 2.0},
		{"position": Vector3(0, 1.72, -99), "target": Vector3(0, 2.0, -150), "duration_to_next_s": 3.0},
		{"position": Vector3(0, 1.72, -150), "target": Vector3(35, 6, -205), "duration_to_next_s": 3.0},
		{"position": Vector3(0, 1.72, -192), "target": Vector3(45, 20, -222), "duration_to_next_s": 0.0}
	]
	_pose(_tour_keyframes[0]["position"], _tour_keyframes[0]["target"])
	set_meta("tour", "30s camera path through one real scene; fixed movie fps is not a performance measurement")


func _init_tour_v2() -> void:
	# A 60s single-scene camera route. The bakery centre line is derived from
	# the actual merchant opening: world (-29.0, 1.1, -0.9) at yaw -90deg.
	# At 17s its real DoorUnit opens before the camera moves through; it closes
	# only after the camera is outside at 30s. There is no cut or teleport.
	for house in interactive_houses:
		if (String(house.get("variant_id")) == "02_market_house" and
			String(house.get_meta("district", "")) == "LaneInner" and
			house.position.x < 0.0):
			_tour_demo_house = house
			break
	if _tour_demo_house == null:
		push_error("v2 camera tour cannot find furnished western-inner bakery")
		return
	var opening: Dictionary = _tour_demo_house.call("door_opening_godot")
	var centre: Vector3 = _tour_demo_house.global_transform * opening["centre"]
	if absf(centre.x + 29.0) > 0.08 or absf(centre.z + 0.9) > 0.08:
		push_error("v2 tour doorway centre changed; route requires re-authoring")
		return
	_tour_demo_house.call("set_door_open", false)
	_tour_keyframes = [
		{"position": Vector3(0, 1.72, 60), "target": Vector3(0, 2.1, 16), "duration_to_next_s": 4.0},
		{"position": Vector3(0, 1.72, 24), "target": Vector3(0, 2.4, 0), "duration_to_next_s": 3.0},
		{"position": Vector3(0, 1.72, 6), "target": Vector3(0, 1.6, 0), "duration_to_next_s": 2.0},
		{"position": Vector3(0, 1.72, -15), "target": Vector3(-17, 3.2, -8), "duration_to_next_s": 3.0},
		{"position": Vector3(-35, 1.72, -16), "target": Vector3(-29, 2.8, -1), "duration_to_next_s": 2.0},
		{"position": Vector3(-35, 1.62, -0.9), "target": Vector3(-29.1, 3.05, -2.35), "duration_to_next_s": 3.0},
		{"position": Vector3(-35, 1.62, -0.9), "target": Vector3(-29, 1.65, -0.9), "duration_to_next_s": 2.0},
		{"position": Vector3(-31.5, 1.62, -0.9), "target": Vector3(-25, 1.7, -0.9), "duration_to_next_s": 4.0},
		{"position": Vector3(-24.7, 1.62, -0.9), "target": Vector3(-20.5, 1.3, -2.2), "duration_to_next_s": 4.0},
		{"position": Vector3(-24.7, 1.62, -0.9), "target": Vector3(-24.7, 1.7, 1.15), "duration_to_next_s": 3.0},
		{"position": Vector3(-35, 1.62, -0.9), "target": Vector3(-29, 2.2, -0.9), "duration_to_next_s": 4.0},
		{"position": Vector3(-35, 1.72, 19), "target": Vector3(-24.8, 4.5, 16.8), "duration_to_next_s": 3.0},
		{"position": Vector3(-35, 1.72, 25), "target": Vector3(-24.8, 4.5, 16.8), "duration_to_next_s": 5.0},
		{"position": Vector3(-35, 1.72, -73), "target": Vector3(0, 5, -85), "duration_to_next_s": 3.0},
		{"position": Vector3(0, 1.72, -79), "target": Vector3(0, 4.5, -87), "duration_to_next_s": 3.0},
		{"position": Vector3(0, 1.72, -118), "target": Vector3(-13, 2.2, -150), "duration_to_next_s": 5.0},
		{"position": Vector3(0, 1.72, -175), "target": Vector3(-35, 2.8, -205), "duration_to_next_s": 4.0},
		{"position": Vector3(0, 1.72, -225), "target": Vector3(-55, 5.5, -275), "duration_to_next_s": 3.0},
		{"position": Vector3(-25, 1.72, -262), "target": Vector3(-55, 6, -275), "duration_to_next_s": 0.0}
	]
	if _review_camera != null:
		_pose(_tour_keyframes[0]["position"], _tour_keyframes[0]["target"])
	set_meta("tour", "60s continuous actual-scene camera path with one real staged DoorUnit open/close; fixed fps is visual evidence only")


func _stage_tour_v2_door(time_s: float) -> void:
	if _tour_demo_house == null:
		return
	var should_open := time_s >= 17.0 and time_s < 30.0
	if bool(_tour_demo_house.call("is_door_open")) != should_open:
		_tour_demo_house.call("set_door_open", should_open)


func _capture_tour_v2_stills() -> void:
	if _tour_version != "v2" or _tour_keyframes.size() != 19 or _tour_demo_house == null:
		push_error("A 60s v2 route and furnished bakery are required for draft stills")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tour_stills_dir)
	var shots := [
		["01_market_street", 4.0], ["02_plaza_fountain", 6.5],
		["03_west_market_pocket", 11.5], ["04_bakery_sign_closed", 15.0],
		["05_bakery_door_open", 17.25],
		["05b_shopbay_fix_exact_previous_eye", 18.5],
		["06_true_doorway_crossing", 22.0],
		["07_furnished_bakery_inside", 23.7], ["08_exit_open_door", 28.5],
		["09_courtyard_oak", 35.0], ["10_northern_gate", 44.0],
		["11_farm_path", 49.0], ["12_true_north_extension", 56.0],
		["13_new_forest_edge", 59.5]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		var time_s := float(shot[1])
		_stage_tour_v2_door(time_s)
		await get_tree().physics_frame
		var pose: Dictionary = _tour_pose_at(time_s)
		if String(shot[0]) == "05b_shopbay_fix_exact_previous_eye":
			# Precisely the rejected pre-fix 05 frame camera from its saved
			# capture.json, so root can inspect the actual geometry repair A/B.
			pose = {"position": Vector3(-31.73438, 1.62, -0.9),
				"target": Vector3(-25.625, 1.692188, -0.9)}
		_pose(pose["position"], pose["target"])
		var perf: Dictionary = await _measure_view_frames()
		var name := String(shot[0])
		var image := get_viewport().get_texture().get_image()
		var png_saved := image.save_png(_tour_stills_dir.path_join(name + ".png")) == OK
		if png_saved: saved.append(name)
		rows.append({"name": name, "time_s": time_s, "camera_position_m": pose["position"],
			"look_target_m": pose["target"], "bakery_door_open":
			bool(_tour_demo_house.call("is_door_open")),
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": png_saved})
	_stage_tour_v2_door(60.0)
	var route_rows := []
	var elapsed := 0.0
	for key: Dictionary in _tour_keyframes:
		route_rows.append({"time_s": elapsed, "position_m": key["position"],
			"look_target_m": key["target"], "duration_to_next_s": key["duration_to_next_s"]})
		elapsed += float(key["duration_to_next_s"])
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_v2_60s_continuous_camera_tour_draft_actual_world_stills",
		"route": route_rows, "route_duration_s": elapsed, "still_rows": rows,
		"saved_images": saved, "saved_png_px": [pixels.x, pixels.y],
		"actual_staged_door_open_close_s": [17, 30],
		"actual_bakery_opening_world_centre_m": _tour_demo_house.global_transform *
			_tour_demo_house.call("door_opening_godot")["centre"],
		"native_t2_forest_oak_trial_enabled": _native_forest_oak_trial != null,
		"grounded_nw_added_area_m2": 29500,
		"continuous_camera_not_recorded_player_walking": true,
		"fixed_movie_frames_not_performance_evidence": true,
		"performance_interval_definition": "non-headless frame_post_draw includes VSync/presentation and CPU waits",
		"persistent_world_state_mutations": 0, "model_calls": 0}
	var file := FileAccess.open(_tour_stills_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(),
		"duration": elapsed, "png_px": report.saved_png_px}))
	get_tree().quit(0 if saved.size() == shots.size() and file != null and
		is_equal_approx(elapsed, 60.0) else 1)


func _finish_tour() -> void:
	if _tour_version == "v2": _stage_tour_v2_door(60.0)
	var rows := []
	var elapsed := 0.0
	for key: Dictionary in _tour_keyframes:
		var p: Vector3 = key["position"]
		var target: Vector3 = key["target"]
		rows.append({"time_s": elapsed, "position_m": [p.x, p.y, p.z],
			"look_target_m": [target.x, target.y, target.z],
			"duration_to_next_s": key["duration_to_next_s"]})
		elapsed += float(key["duration_to_next_s"])
	var report := {"suite":"floor1_expanded_world_continuous_tour", "scene":"res://scenes/floor1_expanded_world.tscn",
		"tour_version": _tour_version, "route":rows,
		"duration_s":60 if _tour_version == "v2" else 30,
		"fixed_movie_fps":30, "frames_submitted":_tour_frame,
		"camera_mode":"continuous interpolated camera in actual walkable scene",
		"v2_staged_real_bakery_door_open_s":17 if _tour_version == "v2" else -1,
		"v2_staged_real_bakery_door_close_s":30 if _tour_version == "v2" else -1,
		"v2_temporary_door_actions":2 if _tour_version == "v2" else 0,
		"movie_frames_are_not_performance_evidence":true,
		"persistent_world_state_mutations":0,
		"model_calls":0}
	var parent := _tour_output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(_tour_output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite":report.suite,"frames":_tour_frame,"metadata":_tour_output}))
	get_tree().quit(0 if file != null else 1)


func _make_palette() -> void:
	for key in ["grass", "town_grass", "cobble", "plaza", "walk", "earth", "field", "field_dark",
			"stone", "stone_dark", "wood", "water", "mist_hill", "maze", "maze_roof", "maze_void", "accent"]:
		var colors := {"grass":"66885f", "town_grass":"718d6b", "cobble":"92908a", "plaza":"b5a995",
			"walk":"a99f8e", "earth":"aa906e", "field":"89985b", "field_dark":"6f8151",
			"stone":"aaa69c", "stone_dark":"797d7a", "wood":"94724a", "water":"5f9eaa",
			"mist_hill":"708981", "maze":"626f71", "maze_roof":"526a6d",
			"maze_void":"344446", "accent":"5f8f9d"}
		var material := StandardMaterial3D.new()
		material.resource_name = "Expanded_" + key
		material.albedo_color = Color(colors[key])
		material.roughness = 0.88
		if key in ["grass", "town_grass", "cobble", "plaza", "walk", "earth"]:
			var mode := 1 if key in ["cobble", "plaza", "walk"] else (2 if key == "earth" else (3 if key == "grass" else 0))
			_palette[key] = _procedural_surface(Color(colors[key]), mode)
		else:
			_palette[key] = material


func _procedural_surface(base: Color, mode: int) -> ShaderMaterial:
	if _surface_shader == null:
		_surface_shader = Shader.new()
		_surface_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 tone_a;
uniform vec3 tone_b;
uniform int pattern_mode = 0;
uniform sampler2D meadow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float meadow_mix = 0.0;
varying vec2 world_xz;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float smooth_noise(vec2 p) {
    vec2 tile = floor(p);
    vec2 fraction = fract(p);
    fraction = fraction * fraction * (3.0 - 2.0 * fraction);
    return mix(mix(hash21(tile), hash21(tile + vec2(1.0, 0.0)), fraction.x),
        mix(hash21(tile + vec2(0.0, 1.0)), hash21(tile + vec2(1.0, 1.0)), fraction.x), fraction.y);
}
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
    vec3 colour = tone_a;
    if (pattern_mode == 3) {
        // Coherent field-scale dry/damp grass, with gently worn earth patches.
        // World coordinates keep this continuous across the ground and slopes.
        float broad = smooth_noise(world_xz / 49.0 + vec2(2.4, 7.1));
        float mid = smooth_noise(world_xz / 18.0 + vec2(9.8, 1.6));
        float field = broad * 0.64 + mid * 0.36;
        float dry = smoothstep(0.47, 0.70, field) * 0.42;
        float damp = (1.0 - smoothstep(0.23, 0.39, field)) * 0.17;
        colour = mix(tone_a, tone_b, dry) * (1.0 - damp);
        colour *= 0.955 + 0.09 * smooth_noise(world_xz / 3.4 + vec2(4.1, 8.5));
        if (meadow_mix > 0.0) {
            // 2 metres per painted tile. source_color converts the bitmap's
            // sRGB sample to shader-linear RGB exactly once before ALBEDO.
            colour = mix(colour, texture(meadow_albedo, world_xz / 2.0).rgb, meadow_mix);
        }
    } else if (pattern_mode == 1) {
        vec2 p = world_xz * vec2(1.28, 0.91);
        p.x += mod(floor(p.y), 2.0) * 0.48;
        p.x += hash21(vec2(floor(p.y), 4.0)) * 0.12 - 0.06;
        vec2 cell = floor(p);
        vec2 within = fract(p);
        float variation = hash21(cell) * 0.30 - 0.15;
        colour *= 1.0 + variation;
        float edge = min(min(within.x, 1.0-within.x), min(within.y, 1.0-within.y));
        edge += (hash21(floor(world_xz * 5.0)) - 0.5) * 0.015;
        float grout = 1.0 - smoothstep(0.015, 0.050, edge);
        colour = mix(colour, tone_a * 0.73, grout);
    } else {
        vec2 broad = floor(world_xz / 7.0);
        float variation = hash21(broad) * 0.13 - 0.06;
        float finer = hash21(floor(world_xz * 0.52)) * 0.045 - 0.02;
        colour *= 1.0 + variation + finer;
        if (pattern_mode == 2) {
            float cart_rut = 1.0 - smoothstep(0.18, 0.31, abs(abs(world_xz.x) - 1.4));
            colour *= 1.0 - cart_rut * 0.07;
        }
    }
    ALBEDO = colour;
    ROUGHNESS = 0.93;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _surface_shader
	# Hex Color values are sRGB; this unhinted vec3 uniform/ALBEDO operates
	# in linear colour space under Forward+. Match StandardMaterial3D's albedo
	# conversion exactly once, while leaving the authored RGB palette intact.
	var linear_base := base.srgb_to_linear()
	material.set_shader_parameter("tone_a", Vector3(linear_base.r, linear_base.g, linear_base.b))
	var dry_field := Color("8b7a61") if mode == 3 else base
	var linear_dry := dry_field.srgb_to_linear()
	material.set_shader_parameter("tone_b", Vector3(linear_dry.r, linear_dry.g, linear_dry.b))
	material.set_shader_parameter("pattern_mode", mode)
	material.set_shader_parameter("meadow_mix", meadow_texture_mix if mode == 3 else 0.0)
	if mode == 3 and meadow_texture_mix > 0.0:
		var meadow := load(MEADOW_ALBEDO_PATH) as Texture2D
		if meadow == null:
			push_error("Selectable meadow albedo could not import: " + MEADOW_ALBEDO_PATH)
		else:
			material.set_shader_parameter("meadow_albedo", meadow)
	return material


func _sky_and_sun() -> void:
	var world := WorldEnvironment.new()
	world.name = "SoftDaylightAndAir"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("315d86")
	sky_material.sky_horizon_color = Color("719bb0")
	sky_material.ground_horizon_color = Color("719bb0")
	sky_material.ground_bottom_color = Color("6f9486")
	sky.sky_material = sky_material
	env.sky = sky
	env.background_energy_multiplier = 0.78
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("a9bfbb")
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.18
	world.environment = env
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.name = "GentleTownSun"
	_sun.light_color = Color("fff0d5")
	_sun.light_energy = 0.88
	_sun.rotation_degrees = Vector3(-47, -28, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 85.0
	_sun.shadow_blur = 1.3
	add_child(_sun)


func _ground_and_roads() -> void:
	_plane("Continuous420x460Ground", 420, 460, 0, -5, "grass", -0.05)
	_box_collision("ContinuousGroundCollision", Vector3(420, 0.4, 460), Vector3(0, -0.24, -5))
	_plane("Town170mPatch", 180, 170, 0, -4, "town_grass", -0.035)
	_plane("MainTownStreet8m", 8, 160, 0, -5, "cobble", 0.012)
	_plane("NorthernCountrysidePath5m", 5, 145, 0, -157.5, "earth", 0.013)
	_branch_path("EastFarmFootpath", [Vector3(2, 0, -123), Vector3(13, 0, -129),
		Vector3(21, 0, -137), Vector3(27, 0, -141)])
	_branch_path("WestShelterFootpath", [Vector3(-2, 0, -180), Vector3(-12, 0, -189),
		Vector3(-21, 0, -198), Vector3(-28, 0, -208)])
	_branch_path("WestForestEdgeApproach", [Vector3(-28, 0, -208),
		Vector3(-34, 0, -211), Vector3(-40, 0, -214)])
	for side in [-1, 1]:
		_plane("TownSidewalk%d" % side, 2.2, 160, side * 5.5, -5, "walk", 0.018)
		_plane("MainStreetStoneCurb%d" % side, 0.32, 160,
			side * 4.3, -5, "stone_dark", 0.029)
		_plane("CurbDrainageLine%d" % side, 0.09, 160,
			side * 4.52, -5, "earth", 0.031)
		_plane("ResidentialLane%d" % side, 5, 130, side * 35, -5, "cobble", 0.019)
		for frontage_z in [26.0, 12.0, -8.0, -26.0, -44.0]:
			_plane("MerchantStoneApron%d_%d" % [side, int(frontage_z)],
				3.4, 5.4, side * 8.9, frontage_z, "walk", 0.026)
		for endpoint in [70, -70]:
			_plane("LaneConnection%d_%d" % [side, endpoint], 35, 5, side * 17.5, endpoint,
				"cobble", 0.023)
			_plane("LaneFootway%d_%d" % [side, endpoint], 35, 1.0, side * 17.5,
				endpoint + 3.0, "walk", 0.027)
	# A short plaza ring keeps the centre walkable around the off-axis focus.
	for z in [-10, 10]:
		_plane("PlazaCrossing%d" % z, 24, 2.5, 0, z, "walk", 0.03)


func _plaza() -> void:
	var paving := CylinderMesh.new()
	paving.top_radius = 12.0
	paving.bottom_radius = 12.0
	paving.height = 0.05
	paving.radial_segments = 32
	_mesh("CircularPlaza24m", paving, _palette["plaza"], Vector3(0, 0.004, 0))
	# Reviewed Meshy quad basin, uniformly normalized to 2.2 m; source GLB stays
	# untouched. Off-axis placement leaves the 8 m main street unobstructed.
	var focus := Vector3(-7.5, 0, 0)
	_fountain(focus)
	var basin_body := StaticBody3D.new()
	basin_body.name = "ReviewedFountainBasinCollision"
	var basin_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.88
	cylinder.height = 0.82
	basin_shape.shape = cylinder
	basin_body.add_child(basin_shape)
	basin_body.position = focus + Vector3(0, 0.41, 0)
	add_child(basin_body)
	_collidable_boxes += 1
	for side in [-1, 1]:
		_plaza_bench(side * 11.25)
	_add_hero_selection(["F1_arrival_waystone"], Vector3(3, 0, 5), "PlazaWaystone", false)


func _plaza_bench(x: float) -> void:
	var side := signf(x)
	_box("PlazaBenchSeat%d" % int(side), Vector3(0.62, 0.16, 2.4),
		Vector3(x, 0.58, 0), "wood", false)
	_box("PlazaBenchBack%d" % int(side), Vector3(0.14, 0.68, 2.4),
		Vector3(x + side * 0.24, 0.97, 0), "wood", false)
	for z in [-0.95, 0.95]:
		_box("PlazaBenchLeg%d_%d" % [int(side), int(z * 10)],
			Vector3(0.24, 0.55, 0.24), Vector3(x, 0.275, z), "stone_dark", false)
	_box_collision("PlazaBenchProxy%d" % int(side), Vector3(0.72, 1.25, 2.5),
		Vector3(x, 0.625, 0))
	_prop_instances += 1


func _fountain(focus: Vector3) -> void:
	var packed := load(FOUNTAIN_PATH) as PackedScene
	if packed == null:
		push_error("Reviewed plaza fountain not imported: " + FOUNTAIN_PATH)
		return
	var holder := Node3D.new()
	holder.name = "ReviewedPlazaFountainAt7_5West"
	add_child(holder)
	var normalization := Node3D.new()
	normalization.name = "Uniform2_2mHeightFloorCentre"
	holder.add_child(normalization)
	var fountain := packed.instantiate() as Node3D
	normalization.add_child(fountain)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for item: MeshInstance3D in fountain.find_children("*", "MeshInstance3D", true, false):
		if item.mesh == null: continue
		var box := item.mesh.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var point := item.global_transform * Vector3(x, y, z)
					low = low.min(point)
					high = high.max(point)
	if not low.is_finite() or high.y <= low.y:
		push_error("Fountain bounds invalid")
		return
	_fountain_scale = 2.2 / (high.y - low.y)
	normalization.position = -Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)
	holder.scale = Vector3.ONE * _fountain_scale
	holder.position = focus
	holder.set_meta("source_glb", FOUNTAIN_PATH)
	holder.set_meta("authored_height_m", 2.2)


func _fortifications() -> void:
	_add_hero_selection(["F1_gate_", "F1_gatehouse_", "COL_F1_gatehouse"],
		Vector3(0, 0, -56), "OriginalGateAtNorth85", true)
	for side in [-1, 1]:
		_box("NorthCurtainWall%d" % side, Vector3(81, 8.2, 2.8),
			Vector3(side * 49.5, 4.1, -85), "stone", true)
		for level in [2.1, 4.1, 6.2]:
			_box("NorthWallStoneCourse%d_%d" % [side, int(level * 10)],
				Vector3(81, 0.14, 0.2),
				Vector3(side * 49.5, level, -83.48), "stone_dark", false)
		_box("NorthCurtainCap%d" % side, Vector3(81, 0.45, 3.5),
			Vector3(side * 49.5, 8.45, -85), "stone_dark", false)
		for step in range(10):
			_box("CurtainMerlon%d_%02d" % [side, step], Vector3(3.8, 1.1, 3.3),
				Vector3(side * (14.0 + step * 8.0), 9.15, -85), "stone", false)
		_box("TownSideWall%d" % side, Vector3(2.4, 6.2, 145),
			Vector3(side * 88, 3.1, -8), "stone", true)
		for level in [1.7, 3.6, 5.4]:
			_box("SideWallStoneCourse%d_%d" % [side, int(level * 10)],
				Vector3(0.18, 0.16, 145),
				Vector3(side * 86.73, level, -8), "stone_dark", false)
		for z in [-77, -59, -41, -23, -5, 13, 31, 49]:
			_box("WallPier%d_%d" % [side, z], Vector3(3.2, 7.1, 3.2),
				Vector3(side * 88, 3.55, z), "stone_dark", false)
		_box("GateFlankButtress%d" % side, Vector3(2.6, 9.0, 5.0),
			Vector3(side * 9.2, 4.5, -85), "stone_dark", true)
		# Just two low accent lamps, not a rune-heavy gate.
		_cylinder("GateBlueLantern%d" % side, 0.22, 0.32,
			Vector3(side * 8.7, 7.4, -82.9), "accent")


func _place_houses() -> void:
	# Three staggered modular homes on each side of each residential lane.
	for side in [-1, 1]:
		for index in range(3):
			var front_z: float = [35.0, 0.0, -59.0][index]
			var back_z: float = [43.0, 8.0, -30.0][index]
			_add_modular(side * 24.5, front_z, -90.0 if side < 0 else 90.0,
				VARIANTS[index], "LaneInner")
			_add_modular(side * 45.5, back_z, 90.0 if side < 0 else -90.0,
				VARIANTS[(index + 1) % 3], "LaneOuter")
	# 10 merchant frontages, 8 lane-backfill houses, 14 perimeter houses.
	for side in [-1, 1]:
		var front_yaw := 90.0 if side < 0 else -90.0
		for index in range(5):
			var frontage_z: float = [26.0, 12.0, -8.0, -26.0, -44.0][index]
			if side > 0: frontage_z += [1.0, -0.5, -1.0, 1.0, 0.5][index]
			_add_exterior(side * 14.2 + side * [0.0, 0.8, -0.3, 1.2, 0.1][index],
				frontage_z, front_yaw + [3.0, -2.5, 1.0, -4.0, 2.0][index],
				VARIANTS[(index + 1) % 3], "MarketFrontage")
		for index in range(4):
			_add_exterior(side * (52.0 + [0.0, 1.6, -0.8, 0.6][index]),
				[60.0, 27.0, -6.0, -49.0][index] + ([-2.0, 2.0, 0.0, -2.0][index] if side > 0 else 0.0),
				front_yaw + [2.0, -3.0, 4.0, -1.0][index],
				VARIANTS[(index + 2) % 3], "LaneBackfill")
		for index in range(7):
			_add_exterior(side * (69.0 + [1.5, -0.3, 1.2, -1.0, 0.2, 1.7, -0.6][index]),
				[60.0, 42.0, 24.0, 6.0, -16.0, -36.0, -56.0][index] +
					([0.0, 3.0, -1.0, 2.0, -2.0, 1.0, 0.0][index] if side > 0 else 0.0),
				front_yaw + [0.0, 4.0, -3.0, 2.0, -1.0, 3.0, -2.0][index],
				VARIANTS[index % 3], "PerimeterRoofline")
	for house in interactive_houses:
		var opening: Dictionary = house.call("door_opening_godot")
		if opening.is_empty(): continue
		var centre: Vector3 = house.global_transform * opening["centre"]
		var outward: Vector3 = (house.global_basis * opening["outward"]).normalized()
		var apron := PlaneMesh.new()
		apron.size = Vector2(2.4, 6.8)
		var walkway := _mesh("EntranceWalkway_" + String(house.name), apron,
			_palette["walk"], Vector3(centre.x, 0.028, centre.z) + outward * 3.3)
		walkway.rotation.y = atan2(outward.x, outward.z)


func _residential_details() -> void:
	# Two planted court gaps per lane side; short rails sit between staggered
	# dwellings, away from every doorway and the 5 m lane centreline.
	for side in [-1, 1]:
		for court in [Vector3(29.0, 0, 18.0), Vector3(29.0, 0, -30.0),
				Vector3(42.0, 0, 25.0), Vector3(42.0, 0, -11.0)]:
			var site := Vector3(side * court.x, 0, court.z)
			_box("ResidenceCourtRail%d_%d_%d" % [side, int(site.x), int(site.z)],
				Vector3(0.16, 0.67, 5.8), site + Vector3(0, 0.335, 0), "wood", false)
			_box_collision("ResidenceCourtRailProxy%d_%d_%d" % [side, int(site.x), int(site.z)],
				Vector3(0.2, 0.7, 5.8), site + Vector3(0, 0.35, 0))
			for offset_z in [-2.1, 2.1]:
				_vegetation("F1_herb_planter", site + Vector3(side * 1.1, 0, offset_z), 0.78)
		# The inner and outer gaps become small usable yards: a maple above a
		# cultivated border, a low seat, and a short stone apron reached from
		# the lane. Their trunks and seats lie between house z-footprints; the
		# lane's x=±35 centreline and all door aprons remain open.
		for garden_z in [18.0, -30.0]:
			var near_x: float = float(side) * 25.6
			_plane("ResidenceGardenSoil%d_%d" % [side, int(garden_z)],
				3.0, 5.3, near_x, garden_z, "field_dark", -0.016)
			_plane("ResidenceGardenAccess%d_%d" % [side, int(garden_z)],
				1.65, 3.4, side * 31.4, garden_z, "walk", 0.026)
			if side < 0 and garden_z == 18.0:
				_place_courtyard_oak(Vector3(-24.8, 0, 16.8))
			else:
				_vegetation("F1_young_maple", Vector3(side * 24.8, 0, garden_z - 1.2), 0.77)
			for offset in [-1.75, 1.75]:
				_vegetation("F1_flowering_shrub",
					Vector3(side * 27.0, 0, garden_z + offset), 0.63)
			_box("ResidenceGardenSeat%d_%d" % [side, int(garden_z)],
				Vector3(1.35, 0.47, 0.56),
				Vector3(side * 29.5, 0.235, garden_z + 2.25), "wood", true)
		for outer_z in [25.0, -11.0]:
			_plane("ResidenceOuterCourtSoil%d_%d" % [side, int(outer_z)],
				3.0, 5.1, side * 47.8, outer_z, "field", -0.016)
			_vegetation("F1_young_maple", Vector3(side * 48.3, 0, outer_z - 1.6), 0.68)
			for offset in [-1.9, 1.9]:
				_vegetation("F1_berry_bush",
					Vector3(side * 46.8, 0, outer_z + offset), 0.59)
	# Two clustered old-tree street corners close the town sightline instead
	# of leaving all canopy out at the 180 m patch's distant edge.
	for side in [-1, 1]:
		_vegetation("F1_ancient_oak", Vector3(side * 21.5, 0, 61.0), 0.86)
		_vegetation("F1_young_maple", Vector3(side * 29.0, 0, 64.0), 0.71)
		for back_z in [56.5, 65.0]:
			_vegetation("F1_berry_bush", Vector3(side * 17.5, 0, back_z), 0.63)


func _place_courtyard_oak(site: Vector3) -> void:
	# Exactly one root-approved original-topology 100K tree takes the place of
	# the old maple in this garden. The 4.78M raw/31K damaged remesh are never
	# imported. Only the low trunk blocks walking; the leaf crown is visual.
	var packed := load(COURTYARD_OAK_PATH) as PackedScene
	if packed == null:
		push_error("Approved courtyard oak asset failed to import")
		return
	var holder := Node3D.new()
	holder.name = "FocalCourtyardOakWest"
	holder.position = site
	add_child(holder)
	var visual := Node3D.new()
	visual.name = "Approved100kOakVisual8_5m"
	visual.scale = Vector3.ONE * 4.525113486
	visual.position.y = 4.252027469
	holder.add_child(visual)
	var oak := packed.instantiate() as Node3D
	visual.add_child(oak)
	var trunk := StaticBody3D.new()
	trunk.name = "CourtyardOakTrunkOnlyCollision"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.52
	cylinder.height = 2.8
	shape.shape = cylinder
	shape.position.y = 1.4
	trunk.add_child(shape)
	holder.add_child(trunk)
	holder.set_meta("asset_path", COURTYARD_OAK_PATH)
	holder.set_meta("source_approved_triangles", 100000)
	holder.set_meta("authored_display_height_m", 8.5)
	holder.set_meta("trunk_proxy_only", true)
	_courtyard_oak = holder
	_tree_instances += 1
	_vegetation_instances += 1


func _add_modular(x: float, z: float, yaw: float, variant: String, district: String) -> void:
	var house: Node3D = MODULAR_SCRIPT.new()
	house.name = "Modular_%02d_%s" % [interactive_houses.size() + 1, variant]
	house.set("variant_id", variant)
	house.position = Vector3(x, 0, z)
	house.rotation_degrees.y = yaw
	add_child(house)
	interactive_houses.append(house)
	# Furnish one of each ground-floor variant on the western inner lane.
	# Inserts are direct children of the separately owned modular component.
	if district == "LaneInner" and x < 0.0:
		var insert: Node3D = INTERIOR_SCRIPT.new()
		insert.name = "GroundFloorInsert_" + variant
		insert.set("build_on_ready", false)
		house.add_child(insert)
		assert(insert.call("build"), "Failed to build a modular ground-floor insert")
		furnished_interiors.append(insert)
	_record_building(house, "interactive", district, variant, 6.7)


func _add_exterior(x: float, z: float, yaw: float, variant: String, district: String) -> void:
	var house: Node3D = MESHY_SCRIPT.new()
	house.name = "Exterior_%02d_%s" % [exterior_houses.size() + 1, variant]
	house.set("house_id", variant)
	house.set("texture_tier", exterior_texture_tier)
	house.set("near_end_m", 28.0)
	house.set("mid_end_m", 68.0)
	house.position = Vector3(x, 0, z)
	house.rotation_degrees.y = yaw
	add_child(house)
	exterior_houses.append(house)
	_record_building(house, "exterior_lod", district, variant, 8.0 if variant == "03_corner_turret" else 5.5)


func _record_building(house: Node3D, role: String, district: String, variant: String, radius: float) -> void:
	house.set_meta("building_role", role)
	house.set_meta("footprint_radius_m", radius)
	house.set_meta("district", district)
	layout_rows.append({"id": String(house.name), "role": role, "district": district,
		"variant": variant, "x": house.position.x, "z": house.position.z,
		"yaw_deg": house.rotation_degrees.y, "footprint_radius_m": radius})


func _market_details() -> void:
	# Planted plaza pockets and storefront aprons give the dense street a
	# small rhythm, while every piece stays outside the main road and doors.
	for z in [-5.8, 5.8]:
		_asset(ENV_PATH + "F1_herb_planter.glb", Vector3(-10.4, 0, z),
			90, 0.9, true)
		_asset(ENV_PATH + "F1_herb_planter.glb", Vector3(10.1, 0, z),
			-90, 0.9, true)
	for side in [-1, 1]:
		for z in [6.0, -6.0, -52.0]:
			_vegetation("F1_flowering_shrub", Vector3(side * 9.2, 0, z), 0.78)
		for z in [53.0, -51.0]:
			_vegetation("F1_herb_planter", Vector3(side * 18.0, 0, z), 0.8)
		_vegetation("F1_ancient_oak", Vector3(side * 102, 0, 30), 0.98)
		_vegetation("F1_ancient_oak", Vector3(side * 104, 0, -46), 0.94)
	var stall_mesh := _selected_mesh(MARKET_PATH, "V5_produce_stall")
	if stall_mesh != null:
		for index in range(4):
			var stall := MeshInstance3D.new()
			stall.name = "MarketStall%d" % index
			stall.mesh = stall_mesh
			stall.position = Vector3(-8.8 if index < 2 else 8.8, 0.0,
				[-20.0, -39.0, -14.0, -34.0][index])
			stall.rotation_degrees.y = 180.0 if index >= 2 else 0.0
			add_child(stall)
			_prop_instances += 1
	var cart_mesh := _selected_mesh(HERO_PATH, "F1_merchant_handcart")
	if cart_mesh != null:
		for index in range(3):
			var cart := MeshInstance3D.new()
			cart.name = "MerchantHandcart%d" % index
			cart.mesh = cart_mesh
			cart.position = Vector3([-9.5, 9.3, -9.8][index], 0,
				[16.0, -3.0, -48.0][index])
			cart.rotation_degrees.y = [15.0, -20.0, 45.0][index]
			add_child(cart)
			_prop_instances += 1
	for index in range(4):
		_asset(CARGO_PATH + ["partitioned_ceramic_crate.glb", "rope_bound_cloth_bale.glb",
			"open_travel_ration_case.glb", "stacked_timber_pallets.glb"][index],
			Vector3([-11.0, 11.5, -11.1, 10.7][index], 0,
				[18.0, -17.0, -32.0, -42.0][index]), 0.0, 1.0, true)


func _countryside() -> void:
	# Four clearly separated cultivated plots, away from the central path.
	var fields := [Vector3(-38, 0, -124), Vector3(38, 0, -136),
		Vector3(-36, 0, -172), Vector3(42, 0, -186)]
	for index in range(fields.size()):
		var centre: Vector3 = fields[index]
		_plane("FarmPlot%d" % index, 26, 30, centre.x, centre.z, "field", 0.004)
		_farm_plots += 1
		for row in range(8):
			_plane("Furrow%d_%d" % [index, row], 0.45, 28,
				centre.x - 11.5 + row * 3.2, centre.z, "field_dark", 0.014)
		for side in [-1, 1]:
			_box("FarmRail%d_%d" % [index, side], Vector3(0.12, 0.7, 30),
				Vector3(centre.x + side * 13.1, 0.35, centre.z), "wood", false)
			for post in range(5):
				_box("FarmFencePost%d_%d_%d" % [index, side, post],
					Vector3(0.35, 1.1, 0.35),
					Vector3(centre.x + side * 13.1, 0.55,
						centre.z - 13.0 + post * 6.5), "wood", false)
			for hedge in range(4):
				_vegetation("F1_berry_bush", Vector3(centre.x + side * 16.0, 0,
					centre.z - 10.0 + hedge * 6.8), 0.65)
		for crop in range(6):
			_vegetation("F1_meadow_grass", Vector3(centre.x - 9.5 + crop * 3.5,
				0, centre.z + 7.0), 0.65)
	_roadside_groves()
	# Orchards form a tight cultivated group; woods form larger uneven edges.
	for x in [-76.0, -63.0, -50.0]:
		for z in [-112.0, -128.0, -145.0]:
			_vegetation("F1_orchard_apple", Vector3(x + fmod(abs(x + z), 3.0), 0, z), 0.92)
	for side in [-1, 1]:
		for index in range(13):
			var x: float = side * (112.0 + [0.0, 8.0, 17.0, 23.0][index % 4])
			var z: float = -101.0 - float(index) * 9.7 + [0.0, -3.0, 4.0][index % 3]
			var species: String = ["F1_cypress_column", "F1_stone_pine", "F1_birch_grove",
				"F1_ancient_oak"][index % 4]
			_vegetation(species, Vector3(x, 0, z), 0.83 + float(index % 3) * 0.12)
		for index in range(12):
			var x: float = side * (92.0 + float(index % 4) * 7.0)
			var z := -96.0 - float(index / 4) * 54.0 - float(index % 3) * 6.0
			_vegetation(["F1_flowering_shrub", "F1_fern_patch", "F1_berry_bush"][index % 3],
				Vector3(x, 0, z), 0.8)
		# Broad-canopy woods sit behind the cultivated hedgerows. The fixed
		# grid is offset by species and depth, forming groves rather than scatter.
		for depth in range(6):
			for band in range(3):
				var grove_x: float = side * (57.0 + band * 13.0 + float(depth % 2) * 3.0)
				var grove_z: float = -105.0 - depth * 17.5 - float(band % 2) * 5.0
				var species: String = ["F1_ancient_oak", "F1_birch_grove", "F1_stone_pine"][(depth + band) % 3]
				_vegetation(species, Vector3(grove_x, 0, grove_z),
					0.74 + float((depth + band) % 3) * 0.09)
	for index in range(15):
		var side := -1.0 if index % 2 == 0 else 1.0
		_vegetation(["F1_meadow_grass", "F1_wildflower_patch"][index % 2],
			Vector3(side * (12.0 + float(index % 4) * 8.0), 0,
				-99.0 - float(index) * 7.2), 0.9)
	for z in [-101.0, -124.0, -150.0, -179.0, -206.0]:
		for side in [-1, 1]:
			_vegetation("F1_cypress_column", Vector3(side * (9.5 + absf(z) * 0.015), 0, z), 0.72)
	for grove in [Vector3(-23, 0, -116), Vector3(26, 0, -137),
			Vector3(-27, 0, -158), Vector3(23, 0, -189)]:
		_vegetation("F1_ancient_oak", grove, 0.86)
		_vegetation("F1_birch_grove", grove + Vector3(5.5, 0, -6.5), 0.68)
	_asset(ENV_PATH + "F1_roadside_milestone.glb", Vector3(6.0, 0, -108.0),
		-30.0, 1.0, true)
	_asset(CARGO_PATH + "water_delivery_cart.glb", Vector3(8.8, 0, -140.0),
		-23.0, 1.0, true)
	_asset(CARGO_PATH + "covered_caravan_wagon.glb", Vector3(-12.0, 0, -186.0),
		15.0, 1.0, true)
	_asset(ENV_PATH + "F1_canvas_rest_shelter.glb", Vector3(-27, 0, -208),
		30.0, 1.0, true)
	for rock in [Vector3(-28, 0, -218), Vector3(31, 0, -209),
			Vector3(-72, 0, -214), Vector3(77, 0, -224)]:
		_asset(ENV_PATH + "F1_mossy_boulder_cluster.glb", rock, 0, 0.85, true)
	# Two walkable, grounded ridges replace four detached round hill props.
	# Their inner edge starts at |x|=144, beyond existing woods rooted at <=136.
	_perimeter_ridges()
	# A separate near, low walkable bank joins the west shelter's forest margin.
	_west_forest_edge_bank()
	# Extend the actual northwestern ground beyond the original z=-235 edge.
	_northwest_ground_sector()


func _perimeter_ridge_height(abs_x: float, z: float, side: int) -> float:
	var lateral := sin(PI * clampf((abs_x - 144.0) / 66.0, 0.0, 1.0))
	var north := pow(maxf(0.0, sin(PI * clampf((-z - 92.0) / 138.0, 0.0, 1.0))), 0.55)
	var contour := 0.77 + 0.17 * sin(z * 0.115 + float(side) * 0.6) + 0.06 * sin(z * 0.31)
	return maxf(0.0, 8.5 * lateral * north * contour)


func _perimeter_ridges() -> void:
	# Low polygonal contours use existing palette materials; coherent exposed
	# stone follows the crest. The terrain itself gets a true static triangle
	# collision, with the continuous flat ground still under its grounded edges.
	var x_bands := [144.0, 153.0, 162.0, 171.0, 180.0, 190.0, 201.0, 210.0]
	for side in [-1, 1]:
		var grid: Array = []
		var highest := 0.0
		for row in range(29):
			var line: Array[Vector3] = []
			var base_z := -92.0 - float(row) * 138.0 / 28.0
			for column in range(x_bands.size()):
				var abs_x: float = x_bands[column]
				var z := base_z
				if column > 0 and column < x_bands.size() - 1:
					abs_x += 1.35 * sin(float(row) * 0.42 + float(column) * 0.73 + float(side))
				if row > 0 and row < 28:
					z += 0.55 * sin(float(row) * 0.65 + float(column) * 0.91)
				var height := _perimeter_ridge_height(abs_x, z, side)
				highest = maxf(highest, height)
				line.append(Vector3(float(side) * abs_x, height + 0.01, z))
			grid.append(line)
		var surfaces: Dictionary = {}
		var counts := {"grass": 0, "mist_hill": 0, "stone_dark": 0}
		for key in counts.keys():
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(_palette[key])
			surfaces[key] = tool
		for row in range(28):
			for column in range(x_bands.size() - 1):
				var a: Vector3 = grid[row][column]
				var b: Vector3 = grid[row][column + 1]
				var c: Vector3 = grid[row + 1][column]
				var d: Vector3 = grid[row + 1][column + 1]
				var centre_x := (absf(a.x) + absf(b.x) + absf(c.x) + absf(d.x)) * 0.25
				var centre_z := (a.z + b.z + c.z + d.z) * 0.25
				var centre_height := (a.y + b.y + c.y + d.y) * 0.25
				var rock_threshold := 175.0 + 3.2 * sin(centre_z * 0.058 + float(side))
				var key := "grass" if centre_x < 161.0 or centre_height < 1.1 else "mist_hill"
				if centre_x > rock_threshold and centre_height > 3.5:
					key = "stone_dark"
				var tool: SurfaceTool = surfaces[key]
				# SurfaceTool/Godot uses this winding for upward-facing normals;
				# an inverted ridge would render its underside and ray through it.
				var first := [a, c, b] if side > 0 else [a, b, c]
				var second := [b, c, d] if side > 0 else [b, d, c]
				for point: Vector3 in first:
					tool.add_vertex(point)
				for point: Vector3 in second:
					tool.add_vertex(point)
				counts[key] += 2
		var terrain := ArrayMesh.new()
		for key in counts.keys():
			var tool: SurfaceTool = surfaces[key]
			tool.generate_normals()
			tool.commit(terrain)
		var visual := MeshInstance3D.new()
		visual.name = "PerimeterGroundedRidge" + ("West" if side < 0 else "East")
		visual.mesh = terrain
		add_child(visual)
		var body := StaticBody3D.new()
		body.name = "PerimeterRidgeCollision" + ("West" if side < 0 else "East")
		var shape := CollisionShape3D.new()
		shape.shape = terrain.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
		_perimeter_ridge_bodies += 1
		_perimeter_ridge_triangles += int(counts["grass"] + counts["mist_hill"] + counts["stone_dark"])
		_perimeter_ridge_max_height_m = maxf(_perimeter_ridge_max_height_m, highest)


func _west_forest_bank_height(abs_x: float, z: float) -> float:
	var across := pow(maxf(0.0, sin(PI * clampf((abs_x - 40.0) / 29.0, 0.0, 1.0))), 1.15)
	var along := pow(maxf(0.0, sin(PI * clampf((-z - 204.0) / 25.0, 0.0, 1.0))), 0.7)
	var shape := 0.89 + 0.11 * sin(z * 0.32 + abs_x * 0.19)
	return maxf(0.0, 1.35 * across * along * shape)


func _west_forest_edge_bank() -> void:
	# The bank starts south of the last west farm and grove roots. It fades to
	# the collidable 420x460 ground before z=-229 (ground ends at -235). One
	# The accepted country grass material follows the hill continuously. A
	# hard earth-material polygon wedge was captured and rejected; later
	# painterly texture A/B can supply a softer soil transition.
	var x_bands := [-40.0, -44.0, -48.0, -52.0, -56.0, -60.0, -64.0, -69.0]
	var grid: Array = []
	var highest := 0.0
	for row in range(13):
		var line: Array[Vector3] = []
		var base_z := -204.0 - float(row) * 25.0 / 12.0
		for column in range(x_bands.size()):
			var x: float = x_bands[column]
			var z := base_z
			if column > 0 and column < x_bands.size() - 1:
				x += 0.42 * sin(float(row) * 0.51 + float(column) * 0.83)
			if row > 0 and row < 12:
				z += 0.33 * sin(float(row) * 0.69 + float(column) * 0.43)
			var height := _west_forest_bank_height(absf(x), z)
			highest = maxf(highest, height)
			line.append(Vector3(x, height + 0.015, z))
		grid.append(line)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_palette["grass"])
	var triangle_count := 0
	for row in range(12):
		for column in range(x_bands.size() - 1):
			var a: Vector3 = grid[row][column]
			var b: Vector3 = grid[row][column + 1]
			var c: Vector3 = grid[row + 1][column]
			var d: Vector3 = grid[row + 1][column + 1]
			# X and Z both decrease across this grid: these triangles face up.
			for point: Vector3 in [a, b, c]:
				tool.add_vertex(point)
			for point: Vector3 in [b, d, c]:
				tool.add_vertex(point)
			triangle_count += 2
	var terrain := ArrayMesh.new()
	tool.generate_normals()
	tool.commit(terrain)
	var visual := MeshInstance3D.new()
	visual.name = "WestForestEdgeWalkableBank"
	visual.mesh = terrain
	add_child(visual)
	var body := StaticBody3D.new()
	body.name = "WestForestEdgeBankCollision"
	var shape := CollisionShape3D.new()
	shape.shape = terrain.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
	_forest_bank_bodies += 1
	_forest_bank_triangles += triangle_count
	_forest_bank_max_height_m = maxf(_forest_bank_max_height_m, highest)


func _north_sector_height(x: float, z: float) -> float:
	# Every point on the old north edge is exactly y=0. The established road
	# axis remains flat while real west-side land rises into a low skyline.
	var depth := clampf((-z - 235.0) / 100.0, 0.0, 1.0)
	var rise := smoothstep(0.14, 0.77, depth)
	var west_mass := 1.0 - smoothstep(-82.0, -28.0, x)
	var contour := (10.6 + 1.75 * sin(x * 0.055 + z * 0.025) +
		1.20 * sin(x * 0.116 - z * 0.061))
	return maxf(0.0, rise * west_mass * contour)


func _north_sector_surface_y(x: float, z: float, x_bands: Array, z_bands: Array) -> float:
	# Sample the exact two triangle planes rather than the smoother contour
	# function. This grounds tree pivots on the real collidable low-poly mesh.
	var column := 0
	for index in range(x_bands.size() - 1):
		if x >= float(x_bands[index]) and x <= float(x_bands[index + 1]):
			column = index
			break
	var row := 0
	for index in range(z_bands.size() - 1):
		if z <= float(z_bands[index]) and z >= float(z_bands[index + 1]):
			row = index
			break
	var x0 := float(x_bands[column])
	var x1 := float(x_bands[column + 1])
	var z0 := float(z_bands[row])
	var z1 := float(z_bands[row + 1])
	var u := clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var v := clampf((z0 - z) / (z0 - z1), 0.0, 1.0)
	var a := _north_sector_height(x0, z0) - (0.05 if row == 0 else 0.0)
	var b := _north_sector_height(x1, z0) - (0.05 if row == 0 else 0.0)
	var c := _north_sector_height(x0, z1)
	var d := _north_sector_height(x1, z1)
	if u + v <= 1.0:
		return a * (1.0 - u - v) + b * u + c * v
	return b * (1.0 - v) + c * (1.0 - u) + d * (u + v - 1.0)


func _northwest_ground_sector() -> void:
	# One actual 29,500 m² ground polygon adjoins only the existing base's
	# x[-210,85], z=-235 edge. The rectangular *bounding box* is not a claim
	# that the whole 420x560m region is grounded. No old terrain is moved.
	var x_bands := [-210.0, -192.0, -174.0, -156.0, -138.0, -120.0, -102.0,
		-84.0, -66.0, -48.0, -30.0, -12.0, 0.0, 12.0, 30.0, 50.0, 70.0, 85.0]
	var z_bands := [-235.0, -243.0, -251.0, -260.0, -270.0, -280.0,
		-290.0, -300.0, -310.0, -320.0, -335.0]
	var grid: Array = []
	var highest := 0.0
	for row in range(z_bands.size()):
		var line: Array[Vector3] = []
		for column in range(x_bands.size()):
			var x: float = x_bands[column]
			var z: float = z_bands[row]
			var h := _north_sector_height(x, z)
			# The old PlaneMesh is rendered at -0.05m (while its collision top
			# is -0.04m). Match the *actual* old visual edge vertex-for-vertex;
			# a nominal y=0 first row made a 5cm sky-coloured raster gap.
			if row == 0: h = -0.05
			highest = maxf(highest, h)
			line.append(Vector3(x, h, z))
		grid.append(line)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_palette["grass"])
	var triangle_count := 0
	for row in range(z_bands.size() - 1):
		for column in range(x_bands.size() - 1):
			var a: Vector3 = grid[row][column]
			var b: Vector3 = grid[row][column + 1]
			var c: Vector3 = grid[row + 1][column]
			var d: Vector3 = grid[row + 1][column + 1]
			# X increases and Z decreases; these triangles have upward normals.
			for point: Vector3 in [a, c, b]: tool.add_vertex(point)
			for point: Vector3 in [b, c, d]: tool.add_vertex(point)
			triangle_count += 2
	var terrain := ArrayMesh.new()
	tool.generate_normals()
	tool.commit(terrain)
	var visual := MeshInstance3D.new()
	visual.name = "NorthwestContinuousGroundSector"
	visual.mesh = terrain
	add_child(visual)
	var body := StaticBody3D.new()
	body.name = "NorthwestSectorTerrainCollision"
	var shape := CollisionShape3D.new()
	shape.shape = terrain.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
	_north_sector_collision_bodies = 1
	_north_sector_triangles = triangle_count
	_north_sector_max_height_m = highest
	# The existing 5m earth path terminates at z=-230, just 5m inside the
	# original edge. One matching 5m continuation crosses its old/new seam.
	_plane("NorthPathPastOriginalGroundEdge", 5.0, 39.0, 0.0, -249.5, "earth", 0.013)
	# Original, low-poly kit trees form three asymmetrical forest-line pockets.
	# Their parent root Y is sampled from this actual collidable slope; the
	# main path axis x±12 and all existing grove/farm/tree roots stay clear.
	var tree_sites := [
		Vector2(-190, -281), Vector2(-177, -292), Vector2(-166, -303), Vector2(-183, -312),
		Vector2(-171, -321), Vector2(-155, -287), Vector2(-198, -298), Vector2(-160, -325),
		Vector2(-145, -294), Vector2(-133, -304), Vector2(-124, -315), Vector2(-149, -323),
		Vector2(-115, -282), Vector2(-136, -287), Vector2(-128, -326), Vector2(-107, -302),
		Vector2(-96, -296), Vector2(-83, -309), Vector2(-75, -319), Vector2(-92, -327),
		Vector2(-87, -283), Vector2(-69, -291), Vector2(-79, -300), Vector2(-63, -322)
	]
	var species := ["F1_ancient_oak", "F1_birch_grove", "F1_cypress_column"]
	for index in range(tree_sites.size()):
		var site: Vector2 = tree_sites[index]
		var x := site.x
		var z := site.y
		var tree := _asset(ENV_PATH + species[(index + int(index / 8)) % species.size()] + ".glb",
			Vector3(x, _north_sector_surface_y(x, z, x_bands, z_bands), z),
			fmod(absf(x * 2.7 + z), 330.0), 0.78 + float(index % 4) * 0.055)
		if tree == null: continue
		tree.name = "NorthSectorForestLineTree%02d" % index
		_north_sector_trees.append(tree)
		_vegetation_instances += 1
		_tree_instances += 1
	if _native_oak_trial:
		# Root-approved one-tree forest-edge placement; explicit CLI-off keeps
		# the exact same-world baseline. It does not replace the 100K garden oak
		# and has not been approved for forest-wide repetition.
		var trial_x := -55.0
		var trial_z := -275.0
		_place_native_forest_oak_trial(Vector3(trial_x,
			_north_sector_surface_y(trial_x, trial_z, x_bands, z_bands), trial_z))


func _place_native_forest_oak_trial(site: Vector3) -> void:
	var packed := load(NATIVE_FOREST_OAK_TRIAL_PATH) as PackedScene
	if packed == null:
		push_error("Native T2 forest oak trial failed to import")
		return
	var holder := Node3D.new()
	holder.name = "NativeT2ForestOakTrialOne"
	holder.position = site
	add_child(holder)
	var visual := Node3D.new()
	visual.name = "NativeT2OakVisual7_2m"
	# Actual immutable GLB accessor bounds: Y [-0.4960939884, +0.4980469942].
	# Scale and lift preserve all GLB materials and put the bottom at parent Y.
	visual.scale = Vector3.ONE * 7.242433543950513
	visual.position.y = 3.592927742674915
	holder.add_child(visual)
	visual.add_child(packed.instantiate())
	var trunk := StaticBody3D.new()
	trunk.name = "NativeT2OakTrunkOnlyCollision"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.36
	cylinder.height = 2.2
	shape.shape = cylinder
	shape.position.y = 1.1
	trunk.add_child(shape)
	holder.add_child(trunk)
	holder.set_meta("asset_path", NATIVE_FOREST_OAK_TRIAL_PATH)
	holder.set_meta("source_triangles", 14783)
	holder.set_meta("authored_display_height_m", 7.2)
	holder.set_meta("trunk_proxy_only", true)
	_native_forest_oak_trial = holder
	_tree_instances += 1
	_vegetation_instances += 1


func _roadside_groves() -> void:
	# A six-pocket forest edge follows the actual northward walking sightline:
	# separated broad crowns in front, clustered birch/maple behind and a
	# shorter shrub/grass layer. The main 5 m path and cultivated plots stay
	# open. Existing distant woods remain as a deep background, not a grid.
	var centres := [Vector3(-18, 0, -105), Vector3(19, 0, -107),
		Vector3(-18, 0, -145), Vector3(18, 0, -160),
		Vector3(-17, 0, -205), Vector3(18, 0, -213)]
	for index in range(centres.size()):
		var centre: Vector3 = centres[index]
		var side := -1.0 if centre.x < 0.0 else 1.0
		_vegetation("F1_ancient_oak", centre, 0.78 + float(index % 3) * 0.07)
		_vegetation("F1_birch_grove",
			centre + Vector3(side * 5.2, 0, -6.0), 0.65 + float(index % 2) * 0.08)
		_vegetation("F1_young_maple",
			centre + Vector3(-side * 3.4, 0, 5.8), 0.73)
		_vegetation("F1_cypress_column",
			centre + Vector3(side * 8.5, 0, 7.2), 0.64)
		for shrub in range(3):
			_vegetation(["F1_berry_bush", "F1_fern_patch", "F1_flowering_shrub"][shrub],
				centre + Vector3(-side * (4.5 + shrub * 2.4), 0, -2.5 + shrub * 3.0),
				0.58 + float(shrub) * 0.08)
		for tuft in range(4):
			_vegetation("F1_meadow_grass",
				Vector3(side * (8.1 + float(tuft % 2) * 3.5), 0,
					centre.z + float(tuft - 1) * 3.7), 0.74)
	# Short roadside rail stretches and hedged verge make fields feel
	# connected to the lane instead of floating on an uninterrupted grass slab.
	for side in [-1, 1]:
		for rail_z in [-122.0, -163.0, -196.0]:
			_box("CountryHedgeRail%d_%d" % [side, int(rail_z)],
				Vector3(0.13, 0.65, 11.5),
				Vector3(side * 6.9, 0.325, rail_z), "wood", true)
			for post in [-4.9, 0.0, 4.9]:
				_box("CountryHedgePost%d_%d_%d" % [side, int(rail_z), int(post * 10)],
					Vector3(0.27, 0.9, 0.27),
					Vector3(side * 6.9, 0.45, rail_z + post), "wood", false)
			for hedge in [-3.9, 0.2, 4.1]:
				_vegetation("F1_berry_bush",
					Vector3(side * 8.3, 0, rail_z + hedge), 0.57)


func _labyrinth_silhouette() -> void:
	# An authored distant maze-entry silhouette, grounded directly in the
	# landscape. The dark recess is visual only; no playable labyrinth claim.
	for side in [-1, 1]:
		_box("LabyrinthSideRampart%d" % side, Vector3(22, 7, 8),
			Vector3(45 + side * 16, 3.5, -220), "maze", false)
		for level in [2.6, 5.2]:
			_box("LabyrinthRampartCourse%d_%d" % [side, int(level * 10)],
				Vector3(22, 0.16, 0.2),
				Vector3(45 + side * 16, level, -215.88), "stone_dark", false)
		_cylinder("LabyrinthRoundWatch%d" % side, 4.5, 14,
			Vector3(45 + side * 17, 7, -218), "maze", 11)
		_cylinder("LabyrinthWatchCap%d" % side, 4.9, 0.55,
			Vector3(45 + side * 17, 14.25, -218), "maze_roof", 11)
		for step in range(4):
			_box("LabyrinthRampartMerlon%d_%d" % [side, step],
				Vector3(2.4, 1.3, 2.0),
				Vector3(45 + side * (9.0 + step * 5.2), 7.65, -216.2),
				"maze", false)
		_box("LabyrinthGateJamb%d" % side, Vector3(4, 11, 7),
			Vector3(45 + side * 5, 5.5, -218), "maze", false)
	_box("LabyrinthGateLintel", Vector3(14, 3, 7),
		Vector3(45, 11.5, -218), "maze", false)
	_box("LabyrinthRecessShadow", Vector3(6.3, 9.3, 0.25),
		Vector3(45, 4.65, -223), "maze_void", false)
	_box("LabyrinthRearWatchKeep", Vector3(9, 17, 7),
		Vector3(45, 8.5, -229), "maze", false)
	_box("LabyrinthRearWatchCap", Vector3(9.5, 0.5, 7.5),
		Vector3(45, 17.25, -229), "maze_roof", false)
	for side in [-1, 1]:
		_box("LabyrinthRearWatchSlit%d" % side, Vector3(0.65, 2.5, 0.16),
			Vector3(45 + side * 2.2, 12.2, -225.4), "stone_dark", false)
	for rock in [Vector3(23, 0, -213), Vector3(28, 0, -222),
			Vector3(66, 0, -214), Vector3(72, 0, -224)]:
		_asset(ENV_PATH + "F1_mossy_boulder_cluster.glb", rock, 0, 1.8, true)
	for back_tree in [Vector3(22, 0, -228), Vector3(29, 0, -229),
			Vector3(69, 0, -226), Vector3(76, 0, -225)]:
		_vegetation("F1_stone_pine", back_tree, 1.05)


func _make_walker() -> void:
	_walker = WALKER_SCRIPT.new() as CharacterBody3D
	_walker.name = "LocalArtWalker"
	_walker.position = Vector3(0, 1.04, 75)
	add_child(_walker)
	_walker.set("houses", interactive_houses)


func _make_review_camera() -> void:
	_review_camera = Camera3D.new()
	_review_camera.name = "SameWorldReviewCamera"
	_review_camera.fov = 65.0
	_review_camera.current = true
	add_child(_review_camera)


func _make_small_label() -> void:
	if review_mode: return
	var short_tour_label := (_tour_version == "v2" and
		(not _tour_output.is_empty() or not _tour_stills_dir.is_empty()))
	var layer := CanvasLayer.new()
	add_child(layer)
	var plate := ColorRect.new()
	plate.color = Color(0.08, 0.13, 0.16, 0.52)
	plate.position = Vector2(12, 10)
	plate.size = Vector2(222, 35) if short_tour_label else Vector2(735, 35)
	layer.add_child(plate)
	var label := Label.new()
	label.text = ("第一层 · 美术样板" if short_tour_label else
		"第一层 · 原创美术样板   |   WASD WALK · E DOOR · F WINDOW · ESC MOUSE")
	label.position = Vector2(22, 17)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color("e5e8de")
	layer.add_child(label)


func _asset(path: String, where: Vector3, yaw_deg: float, scale_factor: float, prop: bool = false) -> Node3D:
	if not _asset_cache.has(path):
		_asset_cache[path] = load(path) as PackedScene
	var packed: PackedScene = _asset_cache[path]
	if packed == null:
		push_error("Expanded art asset missing: " + path)
		return null
	var instance := packed.instantiate() as Node3D
	instance.name = path.get_file().get_basename() + "_%d" % (_vegetation_instances + _prop_instances)
	instance.position = where
	instance.rotation_degrees.y = yaw_deg
	instance.scale = Vector3.ONE * scale_factor
	add_child(instance)
	for mi: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("COL_"):
			mi.visible = false
	if prop: _prop_instances += 1
	return instance


func _vegetation(asset_id: String, where: Vector3, scale_factor: float) -> void:
	var path := ENV_PATH + asset_id + ".glb"
	if _asset(path, where, fmod(abs(where.x * 2.7 + where.z), 330.0), scale_factor) != null:
		_vegetation_instances += 1
		if asset_id in ["F1_ancient_oak", "F1_birch_grove", "F1_cypress_column",
				"F1_stone_pine", "F1_orchard_apple", "F1_young_maple"]:
			_tree_instances += 1


func _add_hero_selection(prefixes: Array[String], offset: Vector3, holder_name: String, collision: bool) -> void:
	var packed := load(HERO_PATH) as PackedScene
	if packed == null: return
	var kit := packed.instantiate() as Node3D
	add_child(kit)
	var holder := Node3D.new()
	holder.name = holder_name
	add_child(holder)
	for item: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var selected := false
		for prefix in prefixes:
			if String(item.name).begins_with(prefix): selected = true
		if not selected: continue
		item.reparent(holder)
		if String(item.name).begins_with("COL_"):
			item.visible = false
			if collision: _trimesh_collision(item)
	holder.position = offset
	kit.queue_free()


func _selected_mesh(path: String, node_name: String) -> Mesh:
	var packed := load(path) as PackedScene
	if packed == null: return null
	var temp := packed.instantiate() as Node3D
	var source := temp.find_child(node_name, true, false) as MeshInstance3D
	if source == null:
		temp.free()
		return null
	var result := source.mesh
	temp.free()
	return result


func _trimesh_collision(item: MeshInstance3D) -> void:
	if item.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "GateSelectedOriginalCollision"
	var shape := CollisionShape3D.new()
	shape.shape = item.mesh.create_trimesh_shape()
	body.add_child(shape)
	item.add_child(body)
	_collidable_boxes += 1


func _plane(label: String, width: float, length: float, x: float, z: float,
		material_key: String, height: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	_mesh(label, plane, _palette[material_key], Vector3(x, height, z))


func _branch_path(label: String, points: Array[Vector3]) -> void:
	for index in range(points.size() - 1):
		var start: Vector3 = points[index]
		var end: Vector3 = points[index + 1]
		var direction := end - start
		var segment := PlaneMesh.new()
		segment.size = Vector2(2.7, direction.length() + 1.0)
		var visual := _mesh(label + "_%02d" % index, segment,
			_palette["earth"], (start + end) * 0.5 + Vector3(0, 0.017, 0))
		visual.rotation.y = atan2(direction.x, direction.z)


func _box(label: String, size: Vector3, at: Vector3, material_key: String,
		collision: bool) -> void:
	var box := BoxMesh.new()
	box.size = size
	_mesh(label, box, _palette[material_key], at)
	if collision: _box_collision(label + "Collision", size, at)


func _cylinder(label: String, radius: float, height: float, at: Vector3,
		material_key: String, sides: int = 16, upper_radius: float = -1.0) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius if upper_radius < 0 else upper_radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = sides
	_mesh(label, cylinder, _palette[material_key], at)


func _mesh(label: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	add_child(visual)
	return visual


func _box_collision(label: String, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	shape.shape = volume
	body.add_child(shape)
	body.position = at
	add_child(body)
	_collidable_boxes += 1


func layout_metrics() -> Dictionary:
	return {"world_extent_m": [420, 460], "ground_centre_z_m": -5,
		"town_extent_m": [180, 170],
		"plaza_diameter_m": 24, "town_street_width_m": 8,
		"residential_lane_width_m": 5, "northern_gate_z_m": -85,
		"countryside_path_end_z_m": -230, "interactive_houses": interactive_houses.size(),
		"furnished_ground_floor_instances": furnished_interiors.size(),
		"furnished_interior_metrics": furnished_interiors.map(
			func(insert: Node3D) -> Dictionary: return insert.call("art_metrics")),
		"exterior_lod_houses": exterior_houses.size(), "vegetation_instances": _vegetation_instances,
		"tree_instances": _tree_instances,
		"props": _prop_instances, "farm_plots": _farm_plots,
		"fountain_uniform_scale": _fountain_scale,
		"fountain_intended_height_m": 2.2, "collision_bodies_created": _collidable_boxes,
		"perimeter_grounded_ridge_collision_bodies": _perimeter_ridge_bodies,
		"perimeter_grounded_ridge_triangles": _perimeter_ridge_triangles,
		"perimeter_ridge_max_height_m": _perimeter_ridge_max_height_m,
		"west_forest_bank_collision_bodies": _forest_bank_bodies,
		"west_forest_bank_triangles": _forest_bank_triangles,
		"west_forest_bank_max_height_m": _forest_bank_max_height_m,
		"north_sector_bounds_m": {"x": [-210, 85], "z": [-335, -235]},
		"north_sector_added_area_m2": 29500,
		"ground_union_area_m2": 222700,
		"ground_union_is_rectangular": false,
		"north_sector_collision_bodies": _north_sector_collision_bodies,
		"north_sector_actual_triangles": _north_sector_triangles,
		"north_sector_max_height_m": _north_sector_max_height_m,
		"north_sector_kit_tree_instances": _north_sector_trees.size(),
		"meadow_texture_mix": meadow_texture_mix,
		"meadow_texture_path": MEADOW_ALBEDO_PATH if meadow_texture_mix > 0.0 else "",
		"approved_courtyard_oak_instances": 1 if _courtyard_oak != null else 0,
		"approved_courtyard_oak_display_height_m": 8.5 if _courtyard_oak != null else 0.0,
		"approved_courtyard_oak_site_m": _courtyard_oak.position if _courtyard_oak != null else Vector3.ZERO,
		"native_forest_oak_trial_instances": 1 if _native_forest_oak_trial != null else 0,
		"native_forest_oak_trial_site_m": _native_forest_oak_trial.position if _native_forest_oak_trial != null else Vector3.ZERO,
		"native_forest_oak_trial_display_height_m": 7.2 if _native_forest_oak_trial != null else 0.0,
		"native_forest_oak_one_tree_default_adopted": _native_oak_trial,
		"labyrinth_entry_art": "grounded visual-only silhouette; playable maze not authored",
		"exterior_texture_tier": exterior_texture_tier,
		"building_layout": layout_rows}


func _pose(camera_position: Vector3, target: Vector3) -> void:
	_review_camera.position = camera_position
	_review_camera.look_at(target, Vector3.UP)


func _capture_lod_near_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_lod_near_probe_dir)
	var target_house: Node3D = null
	for exterior in exterior_houses:
		var is_cottage := String(exterior.get("house_id")) == "01_hearth_cottage"
		var is_west_market := String(exterior.name).begins_with("Exterior_03_")
		if is_cottage and is_west_market:
			target_house = exterior
			break
	if target_house == null:
		push_error("Near texture tier probe cannot locate western cottage market frontage")
		get_tree().quit(1)
		return
	var front: Vector3 = (target_house.global_basis * Vector3(0, 0, 1)).normalized()
	var side: Vector3 = (target_house.global_basis * Vector3(1, 0, 0)).normalized()
	var eye := target_house.global_position + front * 10.0 + side * 1.4 + Vector3(0, 3.1, 0)
	var look := target_house.global_position + Vector3(0, 4.5, 0)
	_pose(eye, look)
	var perf: Dictionary = await _measure_view_frames()
	var image := get_viewport().get_texture().get_image()
	var code := image.save_png(_lod_near_probe_dir.path_join("meshy_cottage_market_close.png"))
	var report := {"suite": "meshy_house_real_world_close_texture_tier_probe",
		"fixture": "actual Meshy cottage GLB LOD in expanded town, same world camera/lighting",
		"house": target_house.name, "house_id": target_house.get("house_id"),
		"asset_path": target_house.get_meta("asset_path", ""),
		"texture_tier": target_house.get_meta("texture_tier", ""),
		"active_lod": target_house.get("active_lod"),
		"camera_eye": eye, "camera_target": look, "saved_png_px": [image.get_width(), image.get_height()],
		"draw_calls_with_shadows": perf["draw_calls_with_shadows"],
		"p95_frame_interval_ms": perf["p95_ms"], "png_saved": code == OK,
		"world_state_mutations": 0, "model_calls": 0}
	var file := FileAccess.open(_lod_near_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite": report.suite, "tier": report.texture_tier,
		"lod": report.active_lod, "saved": report.png_saved}))
	get_tree().quit(0 if code == OK and int(report.active_lod) == 0 else 1)


func _capture_window_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_window_probe_dir)
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for insert in furnished_interiors:
		var metrics: Dictionary = insert.call("art_metrics")
		var kind := String(metrics.get("kind", ""))
		if kind not in ["home", "bakery"]: continue
		var host := insert.get_parent() as Node3D
		host.call("set_door_open", true)
		var eye := Vector3(0.0, 1.62, 1.70) if kind == "home" else Vector3(-0.9, 1.62, 2.45)
		var target := Vector3(0.25, 0.85, -1.50) if kind == "home" else Vector3(0.0, 0.90, -1.50)
		_pose(host.global_transform * eye, host.global_transform * target)
		for opened in [false, true]:
			host.call("set_window_open", opened)
			var perf: Dictionary = await _measure_view_frames()
			var name := "furnished_%s_windows_%s" % [kind, "open" if opened else "closed"]
			var code := get_viewport().get_texture().get_image().save_png(
				_window_probe_dir.path_join(name + ".png"))
			if code == OK: saved.append(name)
			rows.append({"name": name, "host": host.name, "same_local_camera_eye": eye,
				"same_local_target": target, "window_state": host.call("is_window_open"),
				"draw_calls_with_shadows": perf["draw_calls_with_shadows"],
				"p95_frame_interval_ms": perf["p95_ms"], "png_saved": code == OK})
		host.call("set_window_open", false)
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "furnished_real_window_open_visual_probe",
		"fixture": "independent whole expanded art world; actual built house openings",
		"texture_tier": exterior_texture_tier, "furnished_houses": furnished_interiors.size(),
		"capture_png_px": [pixels.x, pixels.y], "saved_shots": saved, "rows": rows,
		"world_state_mutations": 0, "model_calls": 0}
	var file := FileAccess.open(_window_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "texture_tier": exterior_texture_tier}))
	get_tree().quit(0 if saved.size() == 4 else 1)


func _capture_landscape_probe() -> void:
	# Fixed terrain cameras make the outer ridge and road-side floor comparable
	# between visual revisions. None changes building/door/window state.
	DirAccess.make_dir_recursive_absolute(_landscape_probe_dir)
	var shots := [
		["country_road_eye", Vector3(-2.0, 1.72, -121.0), Vector3(-17.0, 2.5, -185.0)],
		["west_field_ridge_eye", Vector3(-72.0, 1.72, -151.0), Vector3(-178.0, 5.0, -162.0)],
		["west_field_ridge_overview", Vector3(-67.0, 14.0, -169.0), Vector3(-178.0, 4.0, -160.0)],
		["east_field_ridge_eye", Vector3(73.0, 1.72, -158.0), Vector3(178.0, 5.0, -158.0)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		_pose(shot[1], shot[2])
		var perf: Dictionary = await _measure_view_frames()
		var code := get_viewport().get_texture().get_image().save_png(
			_landscape_probe_dir.path_join(String(shot[0]) + ".png"))
		if code == OK: saved.append(String(shot[0]))
		rows.append({"name": shot[0], "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_country_landscape_fixed_camera_probe",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"terrain_collision_bodies": _perimeter_ridge_bodies,
		"terrain_actual_triangles": _perimeter_ridge_triangles,
		"world_state_mutations": 0, "model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_landscape_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px}))
	get_tree().quit(0 if saved.size() == shots.size() and file != null else 1)


func _capture_oak_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_oak_probe_dir)
	var shots := [
		["west_lane_to_oak", Vector3(-35.0, 1.72, 26.0), Vector3(-24.8, 4.2, 16.8)],
		["west_garden_oak_eye", Vector3(-30.2, 1.72, 11.0), Vector3(-24.8, 4.0, 16.8)],
		["west_court_oak_overview", Vector3(-40.0, 10.5, 29.0), Vector3(-24.8, 3.9, 16.8)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		_pose(shot[1], shot[2])
		var perf: Dictionary = await _measure_view_frames()
		var code := get_viewport().get_texture().get_image().save_png(
			_oak_probe_dir.path_join(String(shot[0]) + ".png"))
		if code == OK: saved.append(String(shot[0]))
		rows.append({"name": shot[0], "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_one_approved_courtyard_oak_in_actual_world",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"asset_path": COURTYARD_OAK_PATH, "one_tree": _courtyard_oak != null,
		"authored_height_m": 8.5, "placement_m": _courtyard_oak.position if _courtyard_oak != null else Vector3.ZERO,
		"trunk_collision_only": _courtyard_oak != null,
		"world_state_mutations": 0, "model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_oak_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px}))
	get_tree().quit(0 if saved.size() == shots.size() and _courtyard_oak != null and file != null else 1)


func _capture_forest_edge_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_forest_edge_probe_dir)
	var bank_eye := 1.72 + _west_forest_bank_height(50.0, -216.0)
	var shots := [
		["country_path_to_west_bank", Vector3(-11.0, 1.72, -191.0), Vector3(-54.0, 1.0, -218.0)],
		["west_shelter_bank_eye", Vector3(-34.0, 1.72, -209.0), Vector3(-58.0, 1.0, -220.0)],
		["west_bank_walk_eye", Vector3(-50.0, bank_eye, -216.0), Vector3(-62.0, 0.8, -222.0)],
		["west_bank_overview", Vector3(-30.0, 12.0, -196.0), Vector3(-55.0, 0.9, -218.0)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		_pose(shot[1], shot[2])
		var perf: Dictionary = await _measure_view_frames()
		var code := get_viewport().get_texture().get_image().save_png(
			_forest_edge_probe_dir.path_join(String(shot[0]) + ".png"))
		if code == OK: saved.append(String(shot[0]))
		rows.append({"name": shot[0], "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_actual_west_forest_edge_walkable_bank_views",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"bank_collision_bodies": _forest_bank_bodies,
		"bank_actual_triangles": _forest_bank_triangles,
		"bank_max_height_m": _forest_bank_max_height_m,
		"on_bank_camera_nominal_eye_above_authored_floor_m": 1.72,
		"world_state_mutations": 0, "model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_forest_edge_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px}))
	get_tree().quit(0 if saved.size() == shots.size() and _forest_bank_bodies == 1 and file != null else 1)


func _capture_meadow_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_meadow_probe_dir)
	var bank_eye := 1.72 + _west_forest_bank_height(50.0, -216.0)
	var shots := [
		["country_road_eye", Vector3(-7.0, 1.72, -179.0), Vector3(-15.0, 0.2, -205.0)],
		["forest_bank_walk_eye", Vector3(-50.0, bank_eye, -216.0), Vector3(-62.0, 0.8, -222.0)],
		["painted_tile_overhead", Vector3(-43.0, 13.0, -194.0), Vector3(-42.0, 0.0, -194.0)],
		["painted_tile_eye", Vector3(-42.0, 1.72, -194.0), Vector3(-42.0, 0.65, -210.0)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		_pose(shot[1], shot[2])
		var perf: Dictionary = await _measure_view_frames()
		var code := get_viewport().get_texture().get_image().save_png(
			_meadow_probe_dir.path_join(String(shot[0]) + ".png"))
		if code == OK: saved.append(String(shot[0]))
		rows.append({"name": shot[0], "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var pixels := get_viewport().get_texture().get_image().get_size()
	var meadow := load(MEADOW_ALBEDO_PATH) as Texture2D if meadow_texture_mix > 0.0 else null
	var imported_image := meadow.get_image() if meadow != null else null
	var report := {"suite": "floor1_meadow_albedo_actual_world_tiling_probe",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"meadow_texture_mix": meadow_texture_mix, "painted_tile_repeat_m": 2.0,
		"meadow_texture_path": MEADOW_ALBEDO_PATH if meadow != null else "",
		"imported_texture_px": [meadow.get_width(), meadow.get_height()] if meadow != null else [],
		"imported_image_has_mipmaps": imported_image.has_mipmaps() if imported_image != null else false,
		"world_state_mutations": 0, "model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_meadow_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px,
		"mix": meadow_texture_mix}))
	get_tree().quit(0 if saved.size() == shots.size() and file != null and
		(meadow_texture_mix == 0.0 or meadow != null) else 1)


func _capture_lantern_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_lantern_probe_dir)
	var shots := [
		["home", Vector3(0.0, 1.62, 1.70), Vector3(0.25, 0.85, -1.50),
			Vector3(-0.8, 1.62, 1.05), Vector3(0.35, 2.52, -0.85)],
		["bakery", Vector3(-0.9, 1.62, 2.45), Vector3(0.0, 0.90, -1.50),
			Vector3(-0.65, 1.62, 1.45), Vector3(0.35, 2.52, -0.85)],
		["artisan", Vector3(2.2, 1.62, 1.55), Vector3(-1.85, 0.88, -0.92),
			Vector3(0.55, 1.62, 1.15), Vector3(-1.35, 2.52, -0.78)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		var furnished: Node3D = null
		for insert in furnished_interiors:
			if String(insert.call("art_metrics").get("kind", "")) == String(shot[0]):
				furnished = insert
				break
		if furnished == null: continue
		var host := furnished.get_parent() as Node3D
		host.call("set_door_open", true)
		var light := furnished.find_child("WarmInteriorFill", true, false) as OmniLight3D
		var visual := furnished.find_child("CagedLanternVisual", true, false) as Node3D
		for pose_name in ["from_door", "at_lantern"]:
			var eye: Vector3 = shot[1] if pose_name == "from_door" else shot[3]
			var target: Vector3 = shot[2] if pose_name == "from_door" else shot[4]
			_pose(host.global_transform * eye, host.global_transform * target)
			var perf: Dictionary = await _measure_view_frames()
			var name: String = String(shot[0]) + "_" + String(pose_name)
			var code := get_viewport().get_texture().get_image().save_png(
				_lantern_probe_dir.path_join(name + ".png"))
			if code == OK: saved.append(name)
			rows.append({"name": name, "kind": shot[0], "host": host.name,
				"camera_eye_local": eye, "target_local": target,
				"one_original_omni_light": light != null,
				"light_energy": light.light_energy if light != null else -1.0,
				"light_range_m": light.omni_range if light != null else -1.0,
				"light_shadows_enabled": light.shadow_enabled if light != null else false,
				"caged_lantern_visual": visual != null,
				"period_mount": furnished.find_child("LampCeilingMount", true, false) != null,
				"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
				"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
				"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var pixels := get_viewport().get_texture().get_image().get_size()
	var environment := find_child("SoftDaylightAndAir", true, false) as WorldEnvironment
	var report := {"suite": "floor1_period_mount_lantern_in_actual_ambient_world",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"furnished_insert_count": furnished_interiors.size(),
		"world_ambient_energy": environment.environment.ambient_light_energy if environment != null else -1.0,
		"world_sun_energy": _sun.light_energy,
		"world_state_mutations": 0, "model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_lantern_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px,
		"ambient": report.world_ambient_energy}))
	get_tree().quit(0 if saved.size() == shots.size() * 2 and file != null and
		is_equal_approx(float(report.world_ambient_energy), 0.42) else 1)


func _capture_north_sector_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_north_sector_probe_dir)
	var bank_eye := 1.72 + _west_forest_bank_height(50.0, -216.0)
	var shots := [
		# The first two exactly match the preserved 0.22 meadow A/B cameras.
		["country_road_eye", Vector3(-7.0, 1.72, -179.0), Vector3(-15.0, 0.2, -205.0)],
		["forest_bank_walk_eye", Vector3(-50.0, bank_eye, -216.0), Vector3(-62.0, 0.8, -222.0)],
		["west_bank_overview", Vector3(-30.0, 12.0, -196.0), Vector3(-55.0, 0.9, -218.0)],
		["north_path_edge_eye", Vector3(0.0, 1.72, -222.0), Vector3(-37.0, 4.4, -285.0)],
		["north_sector_forestline_eye", Vector3(-80.0, 2.1, -255.0), Vector3(-135.0, 8.0, -307.0)],
		["north_sector_overview", Vector3(0.0, 42.0, -207.0), Vector3(-122.0, 7.0, -294.0)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		_pose(shot[1], shot[2])
		var perf: Dictionary = await _measure_view_frames()
		var code := get_viewport().get_texture().get_image().save_png(
			_north_sector_probe_dir.path_join(String(shot[0]) + ".png"))
		if code == OK: saved.append(String(shot[0]))
		rows.append({"name": shot[0], "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_northwest_real_ground_extension_actual_world_views",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"old_camera_baseline": "tmp/floor1-art-20260916/world/meadow-v11-captures-on/capture.json",
		"root_approved_sector_bounds_m": {"x": [-210, 85], "z": [-335, -235]},
		"base_world_extent_m": [420, 460], "authored_ground_union_area_m2": 222700,
		"north_sector_real_tris": _north_sector_triangles,
		"north_sector_collision_bodies": _north_sector_collision_bodies,
		"north_sector_real_max_height_m": _north_sector_max_height_m,
		"height_sampled_original_kit_trees": _north_sector_trees.size(),
		"default_painted_meadow_mix": meadow_texture_mix,
		"world_state_mutations": 0, "model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_north_sector_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px,
		"tris": _north_sector_triangles}))
	get_tree().quit(0 if saved.size() == shots.size() and file != null and
		_north_sector_collision_bodies == 1 else 1)


func _capture_native_oak_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_native_oak_probe_dir)
	# Each off/on pass is a separate actual scene build with identical camera
	# and lighting. Explicit CLI-off removes both tree and trunk collision.
	var shots := [
		["north_path_edge_eye", Vector3(0.0, 1.72, -222.0), Vector3(-37.0, 4.4, -285.0)],
		["forest_oak_walk_eye", Vector3(-31.0, 2.05, -255.0), Vector3(-55.0, 5.5, -275.0)],
		["forest_oak_bank_overview", Vector3(-40.0, 10.5, -240.0), Vector3(-72.0, 5.0, -290.0)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	for shot in shots:
		_pose(shot[1], shot[2])
		var perf: Dictionary = await _measure_view_frames()
		var image := get_viewport().get_texture().get_image()
		var name := String(shot[0])
		if image.save_png(_native_oak_probe_dir.path_join(name + ".png")) == OK:
			saved.append(name)
		rows.append({"name": name, "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
			"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"]})
	var image_size := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "one_native_t2_oak_isolated_actual_world_forestline_trial",
		"scene": "res://scenes/floor1_expanded_world.tscn", "trial_enabled": _native_forest_oak_trial != null,
		"trial_asset_path": NATIVE_FOREST_OAK_TRIAL_PATH if _native_forest_oak_trial != null else "",
		"trial_source_triangles": 14783 if _native_forest_oak_trial != null else 0,
		"trial_display_height_m": 7.2 if _native_forest_oak_trial != null else 0.0,
		"trial_parent_position_m": _native_forest_oak_trial.position if _native_forest_oak_trial != null else Vector3.ZERO,
		"approved_100k_courtyard_oak_instances": 1 if _courtyard_oak != null else 0,
		"old_kit_north_sector_trees": _north_sector_trees.size(), "capture_png_px": [image_size.x, image_size.y],
		"saved_shots": saved, "shot_rows": rows,
		"frame_interval_definition": "non-headless frame_post_draw includes VSync/presentation and CPU waits",
		"world_state_mutations": 0, "model_calls": 0}
	var file := FileAccess.open(_native_oak_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "enabled": report.trial_enabled,
		"saved": saved.size(), "png_px": report.capture_png_px}))
	get_tree().quit(0 if saved.size() == shots.size() and file != null else 1)


func _capture_bakery_sign_probe() -> void:
	DirAccess.make_dir_recursive_absolute(_bakery_sign_probe_dir)
	var furnished: Node3D = null
	for insert in furnished_interiors:
		if String(insert.call("art_metrics").get("kind", "")) == "bakery":
			furnished = insert
			break
	if furnished == null:
		push_error("No one-each furnished bakery in independent art world")
		get_tree().quit(1)
		return
	var host := furnished.get_parent() as Node3D
	var sign := furnished.find_child("BakeryExteriorSign", true, false) as Node3D
	if sign == null:
		push_error("Accepted independently removable bakery sign missing in actual art world")
		get_tree().quit(1)
		return
	var shots := [
		["bakery_front_lane", Vector3(-0.70, 1.72, 10.7), Vector3(-1.40, 2.6, 4.8)],
		["bakery_sign_eye", Vector3(-2.10, 1.62, 7.25), Vector3(-2.35, 3.05, 5.05)]
	]
	var saved: Array[String] = []
	var rows: Array[Dictionary] = []
	var toggles := 0
	for shot in shots:
		_pose(host.global_transform * shot[1], host.global_transform * shot[2])
		for state in [false, true]:
			sign.visible = state
			toggles += 1
			var perf: Dictionary = await _measure_view_frames()
			var name: String = String(shot[0]) + ("_with_sign" if state else "_baseline_hidden")
			var code := get_viewport().get_texture().get_image().save_png(
				_bakery_sign_probe_dir.path_join(name + ".png"))
			if code == OK: saved.append(name)
			rows.append({"name": name, "camera_eye_local": shot[1], "target_local": shot[2],
				"bakery_host": host.name, "sign_visible": state,
				"median_frame_interval_ms": perf["median_ms"], "p95_frame_interval_ms": perf["p95_ms"],
				"benchmark_frames": perf["frames"], "draw_calls_with_shadows": perf["draw_calls_with_shadows"],
				"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	sign.visible = true
	var pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_one_real_bakery_exterior_sign_in_actual_world",
		"scene": "res://scenes/floor1_expanded_world.tscn", "saved_shots": saved,
		"capture_png_px": [pixels.x, pixels.y], "shot_rows": rows,
		"one_bakery_host": host.name, "independent_sign_local_anchor": sign.position,
		"after_probe_sign_restored_visible": sign.visible,
		"temporary_visual_visibility_assignments": toggles,
		"persistent_world_state_mutations": 0,
		"real_12_house_3_furnished_walker_routes": "see world physics companion receipt",
		"model_calls": 0,
		"frame_interval_definition": "actual non-headless frame_post_draw intervals include VSync/presentation and CPU waits"}
	var file := FileAccess.open(_bakery_sign_probe_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(), "png_px": report.capture_png_px}))
	get_tree().quit(0 if saved.size() == shots.size() * 2 and sign.visible and file != null else 1)


func _capture_tour() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var saved: Array[String] = []
	var shot_rows: Array[Dictionary] = []
	var shots := [
		["panorama", Vector3(77, 52, 94), Vector3(0, 3, -23)],
		["residence_near", Vector3(-34, 3.2, 49), Vector3(-34, 3.6, 32)],
		["market_street", Vector3(3.1, 3.0, 30), Vector3(0, 3.5, -38)],
		["north_gate", Vector3(3.5, 3.5, -58), Vector3(0, 6, -87)],
		["countryside_path", Vector3(-2, 3.0, -121), Vector3(-17, 4.0, -185)]
	]
	for shot in shots:
		_pose(shot[1], shot[2])
		var performance: Dictionary = await _measure_view_frames()
		var path := _capture_dir.path_join(String(shot[0]) + ".png")
		var error := get_viewport().get_texture().get_image().save_png(path)
		if error == OK: saved.append(shot[0])
		shot_rows.append({"name": shot[0], "camera": shot[1], "target": shot[2],
			"median_frame_interval_ms": performance["median_ms"],
			"p95_frame_interval_ms": performance["p95_ms"],
			"benchmark_frames": performance["frames"],
			"draw_calls_with_shadows": performance["draw_calls_with_shadows"],
			"primitives_with_shadows": performance["primitives_with_shadows"],
			"png_saved": error == OK})
	if not interactive_houses.is_empty():
		var house := interactive_houses[0]
		var opening: Dictionary = house.call("door_opening_godot")
		if not opening.is_empty():
			var centre: Vector3 = house.global_transform * opening["centre"]
			var outward: Vector3 = (house.global_basis * opening["outward"]).normalized()
			var camera_right := Vector3(-outward.z, 0, outward.x)
			var exterior_eye := Vector3(centre.x, 1.72, centre.z) + outward * 5.5 + camera_right * 1.2
			var exterior_target := Vector3(centre.x, 1.5, centre.z) - outward * 1.8
			_pose(exterior_eye, exterior_target)
			var closed_perf: Dictionary = await _measure_view_frames()
			var closed := get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join("door_closed.png"))
			if closed == OK: saved.append("door_closed")
			shot_rows.append({"name":"door_closed", "median_frame_interval_ms":closed_perf["median_ms"],
				"p95_frame_interval_ms":closed_perf["p95_ms"], "benchmark_frames":closed_perf["frames"],
				"draw_calls_with_shadows":closed_perf["draw_calls_with_shadows"],
				"primitives_with_shadows":closed_perf["primitives_with_shadows"], "png_saved":closed == OK})
			house.call("set_door_open", true)
			var opened_perf: Dictionary = await _measure_view_frames()
			var opened := get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join("door_open_exterior.png"))
			if opened == OK: saved.append("door_open_exterior")
			shot_rows.append({"name": "door_open_exterior", "camera": _review_camera.position,
				"target": exterior_target, "door_state_independent": house.call("is_door_open"),
				"median_frame_interval_ms":opened_perf["median_ms"],
				"p95_frame_interval_ms":opened_perf["p95_ms"],
				"benchmark_frames":opened_perf["frames"],
				"draw_calls_with_shadows":opened_perf["draw_calls_with_shadows"],
				"primitives_with_shadows":opened_perf["primitives_with_shadows"],
				"png_saved": closed == OK and opened == OK})
			var interior_eye := Vector3(centre.x, 1.57, centre.z) - outward * 1.9 + camera_right * 0.55
			var interior_target := Vector3(centre.x, 1.42, centre.z) + outward * 1.5
			_pose(interior_eye, interior_target)
			var interior_perf: Dictionary = await _measure_view_frames()
			var interior := get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join("open_door_interior.png"))
			if interior == OK: saved.append("open_door_interior")
			shot_rows.append({"name":"open_door_interior", "camera": _review_camera.position,
				"target": interior_target,
				"median_frame_interval_ms":interior_perf["median_ms"],
				"p95_frame_interval_ms":interior_perf["p95_ms"],
				"benchmark_frames":interior_perf["frames"],
				"draw_calls_with_shadows":interior_perf["draw_calls_with_shadows"],
				"primitives_with_shadows":interior_perf["primitives_with_shadows"],
				"png_saved": interior == OK})
	# Capture actual 1.62 m eye positions inside one built room per variant.
	# House transforms place these fixture positions in the whole district.
	var furnished_shots := [
		["furnished_home_from_door", "home", Vector3(0.0, 1.62, 1.70),
			Vector3(0.25, 0.85, -1.50)],
		["furnished_home_at_table", "home", Vector3(0.20, 1.62, -0.10),
			Vector3(2.35, 0.82, -1.25)],
		["furnished_bakery_from_door", "bakery", Vector3(-0.9, 1.62, 2.45),
			Vector3(0.0, 0.90, -1.50)],
		["furnished_bakery_at_oven", "bakery", Vector3(-0.65, 1.62, -1.40),
			Vector3(-2.22, 0.72, -4.02)],
		["furnished_artisan_from_door", "artisan", Vector3(2.2, 1.62, 1.55),
			Vector3(-1.85, 0.88, -0.92)],
		["furnished_artisan_at_workbench", "artisan", Vector3(0.48, 1.62, 0.10),
			Vector3(-3.10, 0.86, 0.55)],
		["furnished_artisan_at_forge", "artisan", Vector3(-0.65, 1.62, 0.25),
			Vector3(-3.12, 0.72, -2.10)]
	]
	for shot in furnished_shots:
		var furnished: Node3D = null
		for insert in furnished_interiors:
			var metrics: Dictionary = insert.call("art_metrics")
			if String(metrics.get("kind", "")) == String(shot[1]):
				furnished = insert
				break
		if furnished == null: continue
		var host := furnished.get_parent() as Node3D
		host.call("set_door_open", true)
		_pose(host.global_transform * shot[2], host.global_transform * shot[3])
		var perf: Dictionary = await _measure_view_frames()
		var file_name := String(shot[0]) + ".png"
		var code := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(file_name))
		if code == OK: saved.append(String(shot[0]))
		shot_rows.append({"name": shot[0], "kind": shot[1], "host": host.name,
			"camera_eye_local": shot[2], "target_local": shot[3],
			"median_frame_interval_ms": perf["median_ms"],
			"p95_frame_interval_ms": perf["p95_ms"], "benchmark_frames": perf["frames"],
			"draw_calls_with_shadows": perf["draw_calls_with_shadows"],
			"primitives_with_shadows": perf["primitives_with_shadows"], "png_saved": code == OK})
	var totals := _current_visible_mesh_counts()
	var captured_pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_expanded_art_world_gpu_capture", "fixture": "independent_art_sample",
		"capture_png_px": [captured_pixels.x, captured_pixels.y],
		"engine_visible_rect": [get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y],
		"saved_shots": saved, "shot_rows": shot_rows,
		"furnished_insert_count": furnished_interiors.size(), "furnished_shots_expected": furnished_shots.size(),
		"rendered_frame_interval_ms_median_market": shot_rows[2]["median_frame_interval_ms"],
		"rendered_frame_interval_ms_p95_market": shot_rows[2]["p95_frame_interval_ms"],
		"benchmark_frames_per_view": 120,
		"frame_interval_definition": "time between actual non-headless RenderingServer.frame_post_draw events; includes presentation/vsync and CPU waits; not pure GPU kernel time",
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "engine_max_fps": Engine.max_fps,
		"shadow_light_count": 1 + furnished_interiors.size(),
		"directional_shadow_max_distance_m": _sun.directional_shadow_max_distance,
		"mesh_counts": totals, "layout": layout_metrics(), "world_state_mutations": 0,
		"model_calls": 0}
	var file := FileAccess.open(_capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(),
		"median_ms_market": report.rendered_frame_interval_ms_median_market,
		"p95_ms_market": report.rendered_frame_interval_ms_p95_market,
		"draw_calls": shot_rows[0]["draw_calls_with_shadows"]}))
	get_tree().quit(0 if saved.size() >= 8 + furnished_shots.size() else 1)


func _measure_view_frames() -> Dictionary:
	for i in range(8): await RenderingServer.frame_post_draw
	var intervals: Array[float] = []
	var last_us := Time.get_ticks_usec()
	for i in range(120):
		await RenderingServer.frame_post_draw
		var now_us := Time.get_ticks_usec()
		intervals.append(float(now_us - last_us) / 1000.0)
		last_us = now_us
	intervals.sort()
	return {"median_ms": intervals[60], "p95_ms": intervals[114], "frames": 120,
		"draw_calls_with_shadows": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives_with_shadows": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))}


func _current_visible_mesh_counts() -> Dictionary:
	var instances := 0
	var triangles := 0
	for item: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if item.mesh == null or not item.is_visible_in_tree(): continue
		instances += 1
		for surface in range(item.mesh.get_surface_count()):
			var arrays := item.mesh.surface_get_arrays(surface)
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			triangles += indices.size() / 3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size() / 3
	return {"scene_visible_mesh_instances_not_frustum_culled": instances,
		"scene_visible_mesh_triangles_not_frustum_culled": triangles}
