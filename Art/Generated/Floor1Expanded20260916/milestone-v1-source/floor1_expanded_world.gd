extends Node3D
## Independent, continuous first-floor art sample; no canonical-world startup.
## All coordinates are Godot metres. Plaza (0,0,0); north is negative Z.

const MODULAR_SCRIPT: GDScript = preload("res://spatial/modular_house_component.gd")
const MESHY_SCRIPT: GDScript = preload("res://spatial/meshy_house_lod_component.gd")
const WALKER_SCRIPT: GDScript = preload("res://spatial/floor1_art_walker.gd")
const HERO_PATH := "res://assets/floor1/StartingTown_Floor1_HeroKit.glb"
const MARKET_PATH := "res://assets/market/StartingTown_Market_CraftV5.glb"
const FOUNTAIN_PATH := "res://assets/floor1/plaza_fountain_20260916/F1_plaza_fountain.glb"
const ENV_PATH := "res://assets/floor1/environment_kit_20/"
const CARGO_PATH := "res://assets/generated/travel_cargo_20260912/"
const VARIANTS := ["01_hearth_cottage", "02_market_house", "03_corner_turret"]

@export var review_mode := false
var interactive_houses: Array[Node3D] = []
var exterior_houses: Array[Node3D] = []
var layout_rows: Array[Dictionary] = []
var _asset_cache: Dictionary = {}
var _palette: Dictionary = {}
var _surface_shader: Shader
var _capture_dir := ""
var _tour_output := ""
var _tour_frame := 0
var _tour_keyframes: Array[Dictionary] = []
var _tour_finishing := false
var _review_camera: Camera3D
var _walker: CharacterBody3D
var _sun: DirectionalLight3D
var _collidable_boxes := 0
var _vegetation_instances := 0
var _tree_instances := 0
var _prop_instances := 0
var _fountain_scale := 0.0
var _farm_plots := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--tour-output="):
			_tour_output = arg.trim_prefix("--tour-output=")
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
			_pose(current_position.lerp(next_position, ease),
				current_target.lerp(next_target, ease))
			break
		start_s += duration_s
	_tour_frame += 1
	if _tour_frame >= 901:
		_tour_finishing = true
		_finish_tour.call_deferred()


func _init_tour() -> void:
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


func _finish_tour() -> void:
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
		"route":rows, "duration_s":30, "fixed_movie_fps":30, "frames_submitted":_tour_frame,
		"camera_mode":"continuous interpolated camera in actual walkable scene",
		"movie_frames_are_not_performance_evidence":true, "world_state_mutations":0,
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
			var mode := 1 if key in ["cobble", "plaza", "walk"] else (2 if key == "earth" else 0)
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
uniform int pattern_mode = 0;
varying vec2 world_xz;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
    vec3 colour = tone_a;
    if (pattern_mode == 1) {
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
	material.set_shader_parameter("tone_a", Vector3(base.r, base.g, base.b))
	material.set_shader_parameter("pattern_mode", mode)
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


func _add_modular(x: float, z: float, yaw: float, variant: String, district: String) -> void:
	var house: Node3D = MODULAR_SCRIPT.new()
	house.name = "Modular_%02d_%s" % [interactive_houses.size() + 1, variant]
	house.set("variant_id", variant)
	house.position = Vector3(x, 0, z)
	house.rotation_degrees.y = yaw
	add_child(house)
	interactive_houses.append(house)
	_record_building(house, "interactive", district, variant, 6.7)


func _add_exterior(x: float, z: float, yaw: float, variant: String, district: String) -> void:
	var house: Node3D = MESHY_SCRIPT.new()
	house.name = "Exterior_%02d_%s" % [exterior_houses.size() + 1, variant]
	house.set("house_id", variant)
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
	# Low hills add depth without obscuring the actual buildings or gate.
	for hill in [Vector3(-166, 1.8, -126), Vector3(166, 2.0, -155),
		Vector3(-180, 3.1, -211), Vector3(175, 2.6, -215)]:
		var mesh := SphereMesh.new()
		mesh.radial_segments = 12
		mesh.rings = 6
		var visual := _mesh("EdgeHill", mesh, _palette["mist_hill"], hill)
		visual.scale = Vector3(26, 4.0, 18)


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
	var layer := CanvasLayer.new()
	add_child(layer)
	var plate := ColorRect.new()
	plate.color = Color(0.08, 0.13, 0.16, 0.52)
	plate.position = Vector2(12, 10)
	plate.size = Vector2(735, 35)
	layer.add_child(plate)
	var label := Label.new()
	label.text = "第一层 · 原创美术样板   |   WASD WALK · E DOOR · F WINDOW · ESC MOUSE"
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
		"exterior_lod_houses": exterior_houses.size(), "vegetation_instances": _vegetation_instances,
		"tree_instances": _tree_instances,
		"props": _prop_instances, "farm_plots": _farm_plots,
		"fountain_uniform_scale": _fountain_scale,
		"fountain_intended_height_m": 2.2, "collision_bodies_created": _collidable_boxes,
		"labyrinth_entry_art": "grounded visual-only silhouette; playable maze not authored",
		"building_layout": layout_rows}


func _pose(camera_position: Vector3, target: Vector3) -> void:
	_review_camera.position = camera_position
	_review_camera.look_at(target, Vector3.UP)


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
	var totals := _current_visible_mesh_counts()
	var captured_pixels := get_viewport().get_texture().get_image().get_size()
	var report := {"suite": "floor1_expanded_art_world_gpu_capture", "fixture": "independent_art_sample",
		"capture_png_px": [captured_pixels.x, captured_pixels.y],
		"engine_visible_rect": [get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y],
		"saved_shots": saved, "shot_rows": shot_rows,
		"rendered_frame_interval_ms_median_market": shot_rows[2]["median_frame_interval_ms"],
		"rendered_frame_interval_ms_p95_market": shot_rows[2]["p95_frame_interval_ms"],
		"benchmark_frames_per_view": 120,
		"frame_interval_definition": "time between actual non-headless RenderingServer.frame_post_draw events; includes presentation/vsync and CPU waits; not pure GPU kernel time",
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "engine_max_fps": Engine.max_fps,
		"shadow_light_count": 1, "directional_shadow_max_distance_m": _sun.directional_shadow_max_distance,
		"mesh_counts": totals, "layout": layout_metrics(), "world_state_mutations": 0,
		"model_calls": 0}
	var file := FileAccess.open(_capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite": report.suite, "saved": saved.size(),
		"median_ms_market": report.rendered_frame_interval_ms_median_market,
		"p95_ms_market": report.rendered_frame_interval_ms_p95_market,
		"draw_calls": shot_rows[0]["draw_calls_with_shadows"]}))
	get_tree().quit(0 if saved.size() >= 8 else 1)


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
