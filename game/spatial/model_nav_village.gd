extends Node3D
## Village navigation test built on the repository's own assets.
##
## The building is the project's authored modular house `03_corner_turret`
## (three storeys, 9 x 7 m, real wall openings and a real BuildingShell trimesh
## collision) instantiated through `ModularHouseComponent`. The scene adds only
## what the authored asset does not contain: one upper-floor slab with a stair
## opening and the staircase itself. Every furnishing is an existing
## `living_props_20260916` prop; nothing here is modelled from scratch.
##
## NpcA walks from the market street to the house, in through its real doorway,
## across the ground floor, up the staircase and onto the second floor, where
## NpcB waits. Three ambient villagers keep the square alive.
##
## Modes (OS.get_cmdline_user_args):
##   (default)       interactive preview
##   --headless-test driven by res://tests/model_nav_village_acceptance.gd
##   --movie         camera timeline; add --capture to save viewport frames
##   --shots         three still captures, then quit

const MODEL_IDS: Array[String] = [
	"01_market_street_house", "smithy-house", "street-lantern", "stone-well",
	"wooden-bench", "notice-board", "hanging-sign", "flour-sack",
	"wagon-wheel", "flower-planter",
]
const ASSET_DIR := "res://assets/floor1/model_nav_20260922"
const TARGET_SIZE := {
	"01_market_street_house": 7.5, "smithy-house": 9.0, "street-lantern": 2.8,
	"stone-well": 2.4, "wooden-bench": 1.8, "notice-board": 2.2,
	"hanging-sign": 2.0, "flour-sack": 1.2, "wagon-wheel": 1.9,
	"flower-planter": 1.4,
}
const PLACEMENT := {
	"01_market_street_house": [Vector3(-4.0, 0.0, 2.5), 0.0, 0.0],
	"smithy-house": [Vector3(4.5, 0.0, 2.8), 0.0, 0.0],
	"stone-well": [Vector3(0.0, 0.0, -1.5), -18.0, 0.0],
	"wooden-bench": [Vector3(-2.7, 0.0, -0.4), 12.0, 0.0],
	"notice-board": [Vector3(2.8, 0.0, -4.9), 6.0, 0.0],
	"hanging-sign": [Vector3(1.1, 0.0, 0.2), -20.0, 0.0],
	"flour-sack": [Vector3(-6.9, 0.0, 0.6), 24.0, 0.0],
	"wagon-wheel": [Vector3(10.15, 0.0, 1.5), 68.0, 14.0],
	"flower-planter": [Vector3(-4.0, 0.0, -1.9), 4.0, 0.0],
	"street-lantern": [Vector3(-8.6, 0.0, -4.7), 0.0, 0.0],
}
const LANTERN_REPEATS: Array = [
	[Vector3(-1.2, 0.0, -6.9), 0.0],
	[Vector3(6.8, 0.0, -5.4), 0.0],
]
const DETAIL_ASSETS: Array = [
	["res://assets/floor1/demo_props_20260916/market-stall.glb", Vector3(-3.1, 0.0, -4.3), 8.0],
	["res://assets/floor1/demo_props_20260916/market-barrel.glb", Vector3(-1.5, 0.0, -4.7), 0.0],
	["res://assets/floor1/demo_props_20260916/produce-crate.glb", Vector3(-4.6, 0.0, -4.6), 14.0],
	["res://assets/floor1/demo_props_20260916/wooden-handcart.glb", Vector3(-8.7, 0.0, -3.6), -28.0],
	["res://assets/overnight20260918/baking_oven.glb", Vector3(-7.7, 0.0, 4.3), 96.0],
	["res://assets/floor1/environment_kit_v2/F1_stone_water_trough_LOD0.glb", Vector3(2.3, 0.0, -2.3), -12.0],
	["res://assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD0.glb", Vector3(-13.6, 0.0, -3.0), 90.0],
	["res://assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD0.glb", Vector3(-13.6, 0.0, 3.0), 90.0],
	["res://assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD0.glb", Vector3(13.6, 0.0, -3.0), 90.0],
	["res://assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD0.glb", Vector3(13.6, 0.0, 3.0), 90.0],
	["res://assets/floor1/environment_kit_20/F1_young_maple.glb", Vector3(-11.2, 0.0, 6.8), 30.0],
	["res://assets/floor1/environment_kit_20/F1_stone_pine.glb", Vector3(11.6, 0.0, 6.9), -18.0],
	["res://assets/floor1/environment_kit_20/F1_orchard_apple.glb", Vector3(10.4, 0.0, -7.6), 42.0],
	["res://assets/floor1/environment_kit_20/F1_berry_bush.glb", Vector3(-10.6, 0.0, -7.2), 0.0],
	["res://assets/floor1/environment_kit_20/F1_berry_bush.glb", Vector3(8.2, 0.0, 7.6), 60.0],
	["res://assets/floor1/environment_kit_20/F1_flowering_shrub.glb", Vector3(-6.2, 0.0, 7.9), 0.0],
	["res://assets/floor1/environment_kit_20/F1_flowering_shrub.glb", Vector3(7.2, 0.0, -8.2), 24.0],
	["res://assets/floor1/environment_kit_20/F1_wildflower_patch.glb", Vector3(-2.6, 0.0, 8.3), 0.0],
	["res://assets/floor1/environment_kit_20/F1_wildflower_patch.glb", Vector3(3.6, 0.0, 8.5), 0.0],
	["res://assets/floor1/environment_kit_20/F1_mossy_boulder_cluster.glb", Vector3(12.6, 0.0, -0.5), 12.0],
	["res://assets/floor1/environment_kit_20/F1_mossy_boulder_cluster.glb", Vector3(-12.2, 0.0, 2.6), -30.0],
]

## The authored house: origin = interior centre, front face (+Z) towards the street.
const HOUSE_ORIGIN := Vector3(-4.5, 0.0, -13.6)
const HOUSE_VARIANT := "03_corner_turret"
const HOUSE_HALF_X := 4.5
const HOUSE_HALF_Z := 3.5
const HOUSE_FLOOR_HEIGHT := 3.0
const HOUSE_DOOR_LOCAL := Vector3(2.2, 0.0, 3.5)
const HOUSE_WALL := 0.3
## Added here because the authored asset contains no slab and no stairs.
const SLAB_TOP := HOUSE_FLOOR_HEIGHT
const STAIR_MIN_X := -2.75
const STAIR_MAX_X := -1.45
const STAIR_BOTTOM_Z := -10.8
const STAIR_TOP_Z := -14.4
const STAIR_STEPS := 12
const UPPER_SPLIT_X := -2.9

## Furnishings: existing props only. [path, position, yaw, floor_top, scale]
const HOUSE_PROPS: Array = [
	["res://assets/floor1/living_props_20260916/hearth.glb", Vector3(-7.6, 0.0, -15.9), 90.0, 0.0, 1.0],
	["res://assets/floor1/living_props_20260916/table.glb", Vector3(-5.2, 0.0, -12.3), 6.0, 0.0, 1.0],
	["res://assets/floor1/living_props_20260916/chair.glb", Vector3(-4.4, 0.0, -12.6), 104.0, 0.0, 1.0],
	["res://assets/floor1/living_props_20260916/chair.glb", Vector3(-6.0, 0.0, -12.6), -98.0, 0.0, 1.0],
	["res://assets/floor1/living_props_20260916/workbench.glb", Vector3(-1.4, 0.0, -16.0), 92.0, 0.0, 1.0],
	["res://assets/floor1/living_props_20260916/shelf.glb", Vector3(-1.2, 0.0, -13.6), 178.0, 0.0, 1.0],
	["res://assets/floor1/living_props_20260916/jug.glb", Vector3(-7.7, 0.0, -11.1), 0.0, 0.0, 0.4],
	["res://assets/floor1/living_props_20260916/bed.glb", Vector3(-7.4, 0.0, -15.7), 90.0, 3.0, 1.0],
	["res://assets/floor1/living_props_20260916/chest.glb", Vector3(-1.3, 0.0, -15.9), -90.0, 3.0, 1.0],
	["res://assets/floor1/living_props_20260916/jug.glb", Vector3(-5.3, 0.0, -11.2), 0.0, 3.0, 0.4],
]

## Indoor/vertical leg: the authored shell has no walkable slab or stair surface
## for the navigation mesh, so the climb is an explicit connector chain, the same
## pattern the repository's own navigation_mvp_house fixture uses for stairs.
const INDOOR_ROUTE: Array = [
	Vector3(-1.8, 0.05, -9.2),
	Vector3(-1.8, 0.05, -10.9),
	Vector3(-2.1, 0.05, -11.2),
	Vector3(-2.1, 0.8, -12.0),
	Vector3(-2.1, 1.6, -12.9),
	Vector3(-2.1, 2.4, -13.8),
	Vector3(-2.1, 3.0, -14.7),
	Vector3(-3.6, 3.0, -15.6),
	Vector3(-5.5, 3.0, -13.6),
]
const NPC_A_START := Vector3(5.5, 0.0, -7.0)
const NPC_B_POS := Vector3(-5.5, 3.0, -13.6)
const ARRIVE_RADIUS := 0.9
const WALK_SPEED := 2.6
const SIM_TIMEOUT_SECONDS := 90.0
const MOVIE_SECONDS := 12.0
const EVIDENCE_DIR := "res://../docs/validation/model-nav-20260922"
const CAPTURE_DIR := "res://../tmp/model-nav-report/frames"
const NAV_GEOMETRY_GROUP := "model_nav_village_geometry"
const NAV_MESH_GROUP := "model_nav_village_meshes"

const VILLAGERS: Array = [
	["NpcC", Color("7fc8a9"), 1.5, 2.6, [Vector3(1.7, 0.0, -1.3), Vector3(-3.0, 0.0, -2.3)]],
	["NpcD", Color("f2c14e"), 1.9, 1.2, [Vector3(-9.6, 0.0, 4.6), Vector3(-9.6, 0.0, -3.6), Vector3(6.1, 0.0, -4.3), Vector3(10.9, 0.0, 4.1)]],
	["NpcE", Color("c792ea"), 1.3, 3.4, [Vector3(4.1, 0.0, -4.2), Vector3(-2.3, 0.0, -2.6)]],
]

var override_test_mode := false
var mode := "preview"
var models: Array[Dictionary] = []
var detail_assets: Array[Dictionary] = []
var detail_loaded := 0
var house: Node3D
var house_door := Vector3.ZERO
var nav_region: NavigationRegion3D
var nav_ready := false
var baked_polygons := 0
var bake_failed := false
var npc_a: Node3D
var npc_b: Node3D
var agent: NavigationAgent3D
var walkers: Array[Dictionary] = []
var path_ready := false
var sim_finished := false
var met := false
var indoor_started := false
var indoor_index := 1
var indoor_length := 0.0
var outdoor_path := PackedVector3Array()
var outdoor_length := 0.0
var route_max_y := -1.0e9
var indoor_samples := 0
var walk_speed := WALK_SPEED
var walk_delay := 0.0
var sim_seconds := 0.0
var walked_distance := 0.0
var arrival_distance := -1.0
var preview_camera: Camera3D
var shots_camera: Camera3D
var shots_done := false
var shots_taken := 0
var movie_camera: Camera3D
var movie_seconds := 0.0
var movie_caption := ""
var capture_enabled := false
var capture_index := 0


func _ready() -> void:
	_parse_mode()
	_build_environment()
	_build_models()
	_build_detail()
	_build_house()
	_build_upper_floor()
	_build_house_props()
	_build_npcs()
	_build_villagers()
	_build_navigation()
	if mode == "shots":
		_build_shots_camera()
	elif mode == "movie":
		_build_movie_camera()
	elif mode == "preview":
		_build_preview_extras()


func _parse_mode() -> void:
	var args := OS.get_cmdline_user_args()
	if override_test_mode or "--headless-test" in args:
		mode = "test"
	elif "--movie" in args:
		mode = "movie"
		walk_delay = 4.5
		walk_speed = 6.0
		capture_enabled = "--capture" in args
	elif "--shots" in args:
		mode = "shots"
	else:
		mode = "preview"


func _physics_process(delta: float) -> void:
	if mode == "preview":
		_update_preview_camera()
	elif mode == "shots":
		_drive_shots()
	elif mode == "movie":
		_drive_movie(delta)
	if sim_finished:
		_update_villagers(delta)
		return
	sim_seconds += delta
	if not (nav_ready and path_ready and is_instance_valid(agent)):
		if sim_seconds >= SIM_TIMEOUT_SECONDS:
			sim_finished = true
		_update_villagers(delta)
		return
	if sim_seconds < walk_delay:
		_update_villagers(delta)
		return
	if not indoor_started:
		var door_target: Vector3 = INDOOR_ROUTE[0]
		agent.target_position = door_target
		if npc_a.global_position.distance_to(door_target) <= 1.0:
			indoor_started = true
			indoor_index = 1
		else:
			var next := agent.get_next_path_position()
			if outdoor_path.is_empty():
				var current := agent.get_current_navigation_path()
				if current.size() >= 2:
					outdoor_path = current
					outdoor_length = 0.0
					for index in range(1, current.size()):
						outdoor_length += current[index - 1].distance_to(current[index])
			if next == Vector3.ZERO or next.distance_to(npc_a.global_position) <= 0.01:
				_move_actor(delta, door_target)
			else:
				_move_actor(delta, next)
	else:
		var waypoint: Vector3 = INDOOR_ROUTE[mini(indoor_index, INDOOR_ROUTE.size() - 1)]
		if npc_a.global_position.distance_to(waypoint) <= 0.45:
			indoor_index += 1
			if indoor_index >= INDOOR_ROUTE.size():
				_greet()
				sim_finished = true
		else:
			_move_actor(delta, waypoint)
	arrival_distance = npc_a.global_position.distance_to(npc_b.global_position)
	if not sim_finished and sim_seconds >= SIM_TIMEOUT_SECONDS:
		sim_finished = true
	_update_villagers(delta)


func _move_actor(delta: float, target: Vector3) -> void:
	var direction := target - npc_a.global_position
	var step := walk_speed * delta
	if direction.length() <= step:
		npc_a.global_position = target
		walked_distance += direction.length()
	else:
		npc_a.global_position += direction.normalized() * step
		walked_distance += step
	_face_motion(npc_a, direction)
	_bob(npc_a, delta)
	route_max_y = maxf(route_max_y, npc_a.global_position.y)
	if absf(npc_a.global_position.x - HOUSE_ORIGIN.x) < HOUSE_HALF_X and absf(npc_a.global_position.z - HOUSE_ORIGIN.z) < HOUSE_HALF_Z:
		indoor_samples += 1


func _greet() -> void:
	met = true
	var to_b := npc_b.global_position - npc_a.global_position
	var to_a := npc_a.global_position - npc_b.global_position
	to_b.y = 0.0
	to_a.y = 0.0
	_face_motion(npc_a, to_b)
	_face_motion(npc_b, to_a)
	print("NpcA reached NpcB on the second floor")


func result_data() -> Dictionary:
	var path := outdoor_path
	var path_length := outdoor_length
	if path.is_empty() and agent != null and path_ready:
		path = agent.get_current_navigation_path()
		for index in range(1, path.size()):
			path_length += path[index - 1].distance_to(path[index])
	var straight := NPC_A_START.distance_to(NPC_B_POS)
	var total_length := path_length + indoor_length
	var detour := 0.0
	if straight > 0.0:
		detour = total_length / straight
	var arrived := sim_finished and arrival_distance >= 0.0 and arrival_distance <= ARRIVE_RADIUS
	var loaded := 0
	for record in models:
		if bool(record.get("loaded", false)):
			loaded += 1
	return {
		"mode": mode,
		"models_loaded": loaded,
		"models_expected": MODEL_IDS.size(),
		"models": models,
		"detail_assets": detail_assets,
		"detail_assets_loaded": detail_loaded,
		"villagers": walkers.size(),
		"house": {
			"variant": HOUSE_VARIANT,
			"source": "assets/floor1/modular_houses_20260916/03_corner_turret.glb",
			"built": house != null,
			"origin": HOUSE_ORIGIN,
			"door_world": house_door,
			"floor_height_m": HOUSE_FLOOR_HEIGHT,
			"added_by_scene": ["upper floor slab with stair opening", "staircase treads"],
		},
		"navigation": {
			"baked": nav_ready,
			"polygons": baked_polygons,
			"bake_failed": bake_failed,
		},
		"path": {
			"found": path_ready and path.size() >= 2,
			"points": path.size(),
			"length_m": path_length,
			"indoor_length_m": indoor_length,
			"total_length_m": total_length,
			"straight_m": straight,
			"detour_ratio": detour,
		},
		"route_profile": {
			"max_y": route_max_y,
			"min_y": NPC_A_START.y,
			"floor_2_reached": route_max_y >= SLAB_TOP - 0.35,
			"indoor_points": indoor_samples,
			"indoor_started": indoor_started,
			"indoor_route_points": INDOOR_ROUTE.size(),
			"npc_b_floor_top": SLAB_TOP,
			"method": "navmesh path to the doorway, then an explicit door/stair connector chain indoors",
		},
		"meeting": {"met": met, "npc_b_floor_top": SLAB_TOP},
		"simulation": {
			"arrived": arrived,
			"arrival_distance_m": arrival_distance,
			"walked_m": walked_distance,
			"sim_seconds": sim_seconds,
			"timed_out": sim_seconds >= SIM_TIMEOUT_SECONDS,
			"npc_a_start": NPC_A_START,
			"npc_b_position": NPC_B_POS,
		},
	}


func write_evidence(path: String, data: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()


func _build_environment() -> void:
	_add_ground("GrassGround", Vector3(64.0, 0.3, 46.0), Vector3(0.0, -0.15, 0.0), Color("7f9463"))
	_add_ground("PlazaStone", Vector3(17.0, 0.14, 13.0), Vector3(0.0, -0.07, -1.0), Color("a9a08c"))
	_add_ground("MarketStreet", Vector3(64.0, 0.1, 5.0), Vector3(0.0, -0.05, -6.4), Color("9c8a6e"))
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-46.0, -38.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff2dc")
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-24.0, 140.0, 0.0)
	fill.light_energy = 0.28
	fill.light_color = Color("bcd6f5")
	add_child(fill)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6fa8dc")
	sky_material.sky_horizon_color = Color("e2eef7")
	sky_material.ground_bottom_color = Color("6d7a5e")
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.fog_enabled = true
	environment.fog_density = 0.006
	environment.fog_light_color = Color("dfe9f2")
	world_env.environment = environment
	add_child(world_env)


func _add_ground(ground_name: String, size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = ground_name
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.position = at
	body.add_to_group(NAV_GEOMETRY_GROUP)
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = ground_name + "Mesh"
	var box := BoxMesh.new()
	box.size = size
	box.material = _plain_material(color, 0.95)
	mesh_instance.mesh = box
	mesh_instance.add_to_group(NAV_MESH_GROUP)
	body.add_child(mesh_instance)
	return body


func _build_models() -> void:
	for model_id in MODEL_IDS:
		var record := {
			"id": model_id,
			"path": ASSET_DIR + "/" + model_id + ".glb",
			"loaded": false,
			"mesh_count": 0,
			"aabb_size": Vector3.ZERO,
			"scale": 1.0,
			"position": Vector3.ZERO,
			"error": "",
		}
		var entry: Array = PLACEMENT.get(model_id, [Vector3.ZERO, 0.0, 0.0])
		_place_generated_model(record, model_id, entry[0], float(entry[1]), float(entry[2]))
		models.append(record)
	for repeat in LANTERN_REPEATS:
		var record := {
			"id": "street-lantern-copy",
			"path": ASSET_DIR + "/street-lantern.glb",
			"loaded": false,
			"mesh_count": 0,
			"aabb_size": Vector3.ZERO,
			"scale": 1.0,
			"position": Vector3.ZERO,
			"error": "",
			"decoration": true,
		}
		_place_generated_model(record, "street-lantern", repeat[0], float(repeat[1]), 0.0)
		if bool(record["loaded"]):
			detail_loaded += 1


func _place_generated_model(record: Dictionary, model_id: String, placement: Vector3, yaw: float, tilt: float) -> void:
	var packed: PackedScene = load(record["path"]) as PackedScene
	if packed == null:
		record["error"] = "load_failed"
		return
	var item := Node3D.new()
	item.name = String(record["id"]) + "_" + str(get_child_count())
	var glb := packed.instantiate() as Node3D
	if glb == null:
		record["error"] = "instantiate_failed"
		return
	item.add_child(glb)
	item.rotation_degrees = Vector3(tilt, yaw, 0.0)
	add_child(item)
	var world_aabb := _combined_world_aabb(item)
	if world_aabb.size.length() <= 0.001:
		record["error"] = "no_mesh_geometry"
		return
	var target: float = TARGET_SIZE.get(model_id, 2.0)
	var factor := target / maxf(world_aabb.size.x, maxf(world_aabb.size.y, world_aabb.size.z))
	item.scale = Vector3.ONE * factor
	item.position = Vector3(placement.x, -world_aabb.position.y * factor, placement.z)
	record["mesh_count"] = _add_colliders(item, NAV_GEOMETRY_GROUP, NAV_MESH_GROUP)
	record["loaded"] = true
	record["aabb_size"] = world_aabb.size * factor
	record["scale"] = factor
	record["position"] = item.position
	record["yaw_degrees"] = yaw


func _build_detail() -> void:
	for entry in DETAIL_ASSETS:
		var record := {
			"path": String(entry[0]).replace("res://assets/", ""),
			"loaded": false,
			"position": Vector3.ZERO,
			"mesh_count": 0,
		}
		var packed: PackedScene = load(entry[0]) as PackedScene
		if packed == null:
			record["error"] = "load_failed"
			detail_assets.append(record)
			continue
		var item := Node3D.new()
		item.name = "Detail_%02d" % detail_assets.size()
		var glb := packed.instantiate() as Node3D
		if glb == null:
			record["error"] = "instantiate_failed"
			detail_assets.append(record)
			continue
		item.add_child(glb)
		var placement: Vector3 = entry[1]
		item.rotation_degrees = Vector3(0.0, float(entry[2]), 0.0)
		add_child(item)
		var world_aabb := _combined_world_aabb(item)
		item.position = Vector3(placement.x, -world_aabb.position.y, placement.z)
		record["mesh_count"] = _add_colliders(item, NAV_GEOMETRY_GROUP, NAV_MESH_GROUP)
		record["loaded"] = true
		record["position"] = item.position
		record["aabb_size"] = world_aabb.size
		detail_loaded += 1
		detail_assets.append(record)


## The authored house, instantiated through the project's own component so its
## real door and window pivots, its detached door leaf and its real shell
## collision all come from the asset rather than from this scene.
func _build_house() -> void:
	var component_script: GDScript = load("res://spatial/modular_house_component.gd") as GDScript
	if component_script == null:
		push_error("model_nav_village: modular_house_component.gd missing")
		return
	house = component_script.new() as Node3D
	house.name = "CornerTurretHouse"
	house.set("variant_id", HOUSE_VARIANT)
	house.set("build_on_ready", true)
	house.position = HOUSE_ORIGIN
	add_child(house)
	var door_local := HOUSE_DOOR_LOCAL
	house_door = HOUSE_ORIGIN + Vector3(door_local.x, door_local.y, door_local.z)
	# The asset's own component owns the door: read its opening and swing it open
	# so NpcA walks through a visibly open doorway rather than a closed leaf.
	var opening = house.call("door_opening_godot")
	if opening is Dictionary and not (opening as Dictionary).is_empty():
		var centre = (opening as Dictionary).get("centre")
		if centre is Vector3:
			house_door = HOUSE_ORIGIN + (centre as Vector3)
	house.call("set_door_open", true)
	_share_house_collision()


## The component's own collision bodies join the navigation source groups; its
## roof collider is left out so the roof can never bake as walkable floor, and
## the door leaf is left out so the open doorway stays navigable.
func _share_house_collision() -> void:
	for body in _find_nodes(house, "StaticBody3D"):
		var body_name := String(body.name).to_lower()
		if body_name.contains("roof") or body_name.contains("door"):
			continue
		body.add_to_group(NAV_GEOMETRY_GROUP)
		for mesh_instance in _find_nodes(body, "MeshInstance3D"):
			(mesh_instance as MeshInstance3D).add_to_group(NAV_MESH_GROUP)


func _find_nodes(root_node: Node, type_name: String) -> Array:
	var found: Array = []
	for child in root_node.get_children():
		if child.is_class(type_name):
			found.append(child)
		found.append_array(_find_nodes(child, type_name))
	return found


## Only what the authored asset does not provide: one upper-floor slab (with a
## stair opening) and the staircase treads.
func _build_upper_floor() -> void:
	var slab_color := Color("8a6f52")
	var west_width := UPPER_SPLIT_X - (HOUSE_ORIGIN.x - HOUSE_HALF_X + HOUSE_WALL)
	_add_ground("HouseSlabWest", Vector3(west_width, 0.2, HOUSE_HALF_Z * 2.0 - HOUSE_WALL * 2.0),
		Vector3(HOUSE_ORIGIN.x - HOUSE_HALF_X + HOUSE_WALL + west_width * 0.5, SLAB_TOP - 0.1, HOUSE_ORIGIN.z), slab_color)
	var east_width := (HOUSE_ORIGIN.x + HOUSE_HALF_X - HOUSE_WALL) - UPPER_SPLIT_X
	var east_depth := (HOUSE_ORIGIN.z - HOUSE_HALF_Z + HOUSE_WALL) - STAIR_TOP_Z
	_add_ground("HouseSlabEast", Vector3(east_width, 0.2, absf(east_depth)),
		Vector3(UPPER_SPLIT_X + east_width * 0.5, SLAB_TOP - 0.1, STAIR_TOP_Z + east_depth * 0.5), slab_color)
	var tread_color := Color("6f5638")
	var run := STAIR_BOTTOM_Z - STAIR_TOP_Z
	var tread := run / float(STAIR_STEPS)
	var step_rise := SLAB_TOP / float(STAIR_STEPS)
	for step in range(STAIR_STEPS):
		var front := STAIR_BOTTOM_Z - tread * float(step)
		var depth := front - STAIR_TOP_Z
		var top := step_rise * float(step + 1)
		if depth <= 0.001:
			continue
		_add_ground("HouseStairStep_%02d" % step, Vector3(STAIR_MAX_X - STAIR_MIN_X, top, depth),
			Vector3((STAIR_MIN_X + STAIR_MAX_X) * 0.5, top * 0.5, (front + STAIR_TOP_Z) * 0.5), tread_color)
	_lamp(Vector3(HOUSE_ORIGIN.x, 2.6, HOUSE_ORIGIN.z), Color("ffd8a8"), 2.4, 10.0)
	_lamp(Vector3(HOUSE_ORIGIN.x, 5.6, HOUSE_ORIGIN.z), Color("ffd8a8"), 2.2, 10.0)
	_lamp(Vector3(HOUSE_ORIGIN.x + 2.0, 1.9, HOUSE_ORIGIN.z + 2.4), Color("ffe0b8"), 1.4, 6.0)


func _build_house_props() -> void:
	for entry in HOUSE_PROPS:
		var packed: PackedScene = load(entry[0]) as PackedScene
		var record := {
			"path": String(entry[0]).replace("res://assets/", ""),
			"loaded": false,
			"position": Vector3.ZERO,
			"mesh_count": 0,
		}
		if packed == null:
			record["error"] = "load_failed"
			detail_assets.append(record)
			continue
		var item := Node3D.new()
		item.name = "HouseProp_%02d" % detail_assets.size()
		var glb := packed.instantiate() as Node3D
		if glb == null:
			record["error"] = "instantiate_failed"
			detail_assets.append(record)
			continue
		item.add_child(glb)
		var placement: Vector3 = entry[1]
		item.rotation_degrees = Vector3(0.0, float(entry[2]), 0.0)
		var prop_scale: float = float(entry[4]) if entry.size() > 4 else 1.0
		item.scale = Vector3.ONE * prop_scale
		add_child(item)
		var world_aabb := _combined_world_aabb(item)
		var floor_top: float = entry[3]
		item.position = Vector3(placement.x, floor_top - world_aabb.position.y, placement.z)
		record["mesh_count"] = _add_colliders(item, NAV_GEOMETRY_GROUP, NAV_MESH_GROUP)
		record["loaded"] = true
		record["position"] = item.position
		record["aabb_size"] = world_aabb.size
		record["floor_top"] = floor_top
		detail_loaded += 1
		detail_assets.append(record)


func _lamp(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "HouseLamp_" + str(get_child_count())
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)


func _find_mesh_instances(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_mesh_instances(child))
	return found


func _combined_world_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in _find_mesh_instances(node):
		var local: AABB = (mesh_instance as MeshInstance3D).mesh.get_aabb()
		var transform: Transform3D = (mesh_instance as MeshInstance3D).global_transform
		var corners: Array[Vector3] = [
			Vector3(local.position.x, local.position.y, local.position.z),
			Vector3(local.end.x, local.position.y, local.position.z),
			Vector3(local.position.x, local.end.y, local.position.z),
			Vector3(local.position.x, local.position.y, local.end.z),
			Vector3(local.end.x, local.end.y, local.position.z),
			Vector3(local.end.x, local.position.y, local.end.z),
			Vector3(local.position.x, local.end.y, local.end.z),
			local.end,
		]
		for corner in corners:
			var world := transform * corner
			if first:
				result = AABB(world, Vector3.ZERO)
				first = false
			else:
				result = result.expand(world)
	return result


func _add_colliders(item: Node3D, body_group: String, mesh_group: String) -> int:
	var count := 0
	for mesh_instance in _find_mesh_instances(item):
		var shape: ConcavePolygonShape3D = (mesh_instance as MeshInstance3D).mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = String(item.name) + "_" + String(mesh_instance.name) + "_Collision"
		body.add_to_group(body_group)
		add_child(body)
		body.global_transform = (mesh_instance as MeshInstance3D).global_transform
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		(mesh_instance as MeshInstance3D).add_to_group(mesh_group)
		count += 1
	return count


func _build_npcs() -> void:
	npc_a = _build_actor("NpcA", NPC_A_START, Color("5fa8d3"))
	npc_b = _build_actor("NpcB", NPC_B_POS, Color("e07a5f"))
	agent = NavigationAgent3D.new()
	agent.name = "NpcA_NavigationAgent"
	agent.radius = 0.35
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	npc_a.add_child(agent)


func _build_actor(actor_name: String, at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = actor_name
	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.15
	body.mesh = capsule
	body.position = Vector3(0.0, 0.62, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	body.material_override = material
	root.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	head.mesh = sphere
	head.position = Vector3(0.0, 1.36, 0.0)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = color.lightened(0.25)
	head_material.roughness = 0.7
	head.material_override = head_material
	root.add_child(head)
	var label := Label3D.new()
	label.name = "NameTag"
	label.text = actor_name
	label.position = Vector3(0.0, 2.15 if actor_name == "NpcB" else 1.95, 0.0)
	label.font_size = 84
	label.pixel_size = 0.0030
	label.outline_size = 20
	label.modulate = color.lightened(0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
	root.position = at
	add_child(root)
	return root


func _build_villagers() -> void:
	for entry in VILLAGERS:
		var villager_name: String = entry[0]
		var color: Color = entry[1]
		var speed: float = entry[2]
		var dwell: float = entry[3]
		var waypoints: Array = entry[4]
		var node := _build_actor(villager_name, waypoints[0], color)
		var villager_agent := NavigationAgent3D.new()
		villager_agent.name = villager_name + "_Agent"
		villager_agent.radius = 0.35
		villager_agent.path_desired_distance = 0.5
		villager_agent.target_desired_distance = 0.7
		node.add_child(villager_agent)
		walkers.append({
			"name": villager_name,
			"node": node,
			"agent": villager_agent,
			"waypoints": waypoints,
			"index": 1 % waypoints.size(),
			"speed": speed,
			"dwell": dwell,
			"remaining_dwell": 0.0,
			"phase": float(walkers.size()) * 1.7,
		})


func _update_villagers(delta: float) -> void:
	if not nav_ready:
		return
	for walker in walkers:
		var node: Node3D = walker["node"]
		var villager_agent: NavigationAgent3D = walker["agent"]
		if float(walker["remaining_dwell"]) > 0.0:
			walker["remaining_dwell"] = float(walker["remaining_dwell"]) - delta
			_idle_bob(node, delta, float(walker["phase"]))
			continue
		var waypoints: Array = walker["waypoints"]
		var target: Vector3 = waypoints[int(walker["index"])]
		villager_agent.target_position = target
		var next := villager_agent.get_next_path_position()
		if next == Vector3.ZERO:
			continue
		var direction := next - node.global_position
		direction.y = 0.0
		if direction.length() <= 0.12 and node.global_position.distance_to(target) <= 1.0:
			walker["index"] = (int(walker["index"]) + 1) % waypoints.size()
			walker["remaining_dwell"] = float(walker["dwell"])
			continue
		var step: float = float(walker["speed"]) * delta
		node.global_position += direction.normalized() * minf(step, direction.length())
		_face_motion(node, direction)
		_bob(node, delta)


func _face_motion(node: Node3D, direction: Vector3) -> void:
	if direction.length() <= 0.001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	node.rotation.y = lerp_angle(node.rotation.y, target_yaw, 0.18)


func _bob(node: Node3D, delta: float) -> void:
	node.set_meta("bob_phase", float(node.get_meta("bob_phase", 0.0)) + delta * 9.0)
	_apply_bob(node, absf(sin(float(node.get_meta("bob_phase")))) * 0.05)


func _idle_bob(node: Node3D, delta: float, phase: float) -> void:
	node.set_meta("bob_phase", float(node.get_meta("bob_phase", phase)) + delta * 1.6)
	_apply_bob(node, sin(float(node.get_meta("bob_phase"))) * 0.012)


## Bob the body parts, never the root: the root's Y is the actor's ground height.
func _apply_bob(node: Node3D, offset: float) -> void:
	var body := node.get_node_or_null("Body") as Node3D
	var head := node.get_node_or_null("Head") as Node3D
	var tag := node.get_node_or_null("NameTag") as Node3D
	if body != null:
		body.position.y = 0.62 + offset
	if head != null:
		head.position.y = 1.36 + offset
	if tag != null:
		tag.position.y = (2.15 if String(node.name) == "NpcB" else 1.95) + offset


func _build_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = NAV_GEOMETRY_GROUP
	nav_mesh.cell_size = 0.15
	nav_mesh.cell_height = 0.1
	nav_mesh.agent_radius = 0.35
	nav_mesh.agent_max_climb = 0.35
	nav_mesh.agent_max_slope = 45.0
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	var map: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, nav_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, nav_mesh.cell_height)
	NavigationServer3D.map_set_use_edge_connections(map, true)
	NavigationServer3D.map_set_edge_connection_margin(map, 2.0)
	_begin_bake()


func _begin_bake() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if nav_region == null:
		bake_failed = true
		return
	nav_region.bake_navigation_mesh(false)
	_finalize_nav()


func _finalize_nav() -> void:
	if nav_region != null and nav_region.navigation_mesh != null:
		baked_polygons = nav_region.navigation_mesh.get_polygon_count()
	if baked_polygons <= 0 and nav_region != null and nav_region.navigation_mesh != null:
		nav_region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
		nav_region.navigation_mesh.geometry_source_group_name = NAV_MESH_GROUP
		nav_region.bake_navigation_mesh(false)
		baked_polygons = nav_region.navigation_mesh.get_polygon_count()
	if baked_polygons <= 0:
		bake_failed = true
		return
	nav_ready = true
	if npc_a != null and npc_b != null and agent != null:
		agent.target_position = INDOOR_ROUTE[0]
		indoor_length = 0.0
		for index in range(1, INDOOR_ROUTE.size()):
			indoor_length += (INDOOR_ROUTE[index - 1] as Vector3).distance_to(INDOOR_ROUTE[index] as Vector3)
		await get_tree().physics_frame
		await get_tree().physics_frame
		path_ready = true
		route_max_y = npc_a.global_position.y
		if mode == "preview" or mode == "movie":
			_build_route_markers()


func _build_shots_camera() -> void:
	shots_camera = Camera3D.new()
	shots_camera.name = "ShotsCamera"
	shots_camera.fov = 62.0
	add_child(shots_camera)
	shots_camera.current = true


func _drive_shots() -> void:
	if shots_done:
		return
	if not sim_finished:
		shots_camera.position = Vector3(-16.0, 11.0, -4.0)
		shots_camera.look_at(Vector3(-4.0, 2.0, -13.0), Vector3.UP)
		return
	shots_done = true
	await _capture_shot("01_overview", Vector3(-17.0, 12.0, -17.0), Vector3(-2.5, 2.0, -10.5))
	await _capture_shot("02_route_close", Vector3(-1.9, 1.9, -11.0), Vector3(-2.4, 1.2, -13.4))
	await _capture_shot("03_arrival", Vector3(-2.2, 4.3, -10.8), Vector3(-5.5, 3.6, -13.6))
	print("model_nav_village shots captured: " + str(shots_taken))
	get_tree().quit(0)


func _capture_shot(label: String, from: Vector3, look: Vector3) -> void:
	shots_camera.position = from
	shots_camera.look_at(look, Vector3.UP)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(EVIDENCE_DIR + "/" + label + ".png")
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	image.save_png(absolute)
	shots_taken += 1
	print("captured " + absolute)


func _build_movie_camera() -> void:
	movie_camera = Camera3D.new()
	movie_camera.name = "MovieCamera"
	movie_camera.fov = 58.0
	add_child(movie_camera)
	movie_camera.current = true


func _drive_movie(delta: float) -> void:
	movie_seconds += delta
	var t := movie_seconds
	if t < 2.0:
		var progress := t / 2.0
		var angle := lerpf(-2.35, -0.95, progress)
		var radius := lerpf(20.0, 17.0, progress)
		movie_camera.position = Vector3(cos(angle) * radius, lerpf(13.0, 11.0, progress), sin(angle) * radius - 2.0)
		movie_camera.look_at(Vector3(-2.0, 1.5, -8.0), Vector3.UP)
		movie_caption = "Ten generated models placed as a market square"
	elif t < 4.0:
		var progress := (t - 2.0) / 2.0
		movie_camera.position = Vector3(lerpf(1.0, -2.0, progress), 2.0, lerpf(-6.0, -8.4, progress))
		movie_camera.look_at(Vector3(house_door.x, 1.8, house_door.z + 1.0), Vector3.UP)
		movie_caption = "The server's house on the market street"
	elif t < 6.5:
		var progress := clampf((t - 4.0) / 2.5, 0.0, 1.0)
		movie_camera.position = Vector3(lerpf(-7.1, -5.4, progress), lerpf(2.3, 2.1, progress), lerpf(-10.9, -11.6, progress))
		movie_camera.look_at(Vector3(lerpf(-2.6, -2.2, progress), lerpf(1.1, 1.5, progress), lerpf(-13.0, -13.4, progress)), Vector3.UP)
		movie_caption = "Inside the house the staircase leads to the second floor"
	elif t < 9.6:
		var progress := clampf((t - 6.5) / 3.1, 0.0, 1.0)
		movie_camera.position = Vector3(lerpf(-0.9, -1.7, progress), lerpf(4.5, 4.0, progress), lerpf(-10.6, -11.4, progress))
		movie_camera.look_at(Vector3(-5.2, 3.6, -14.0), Vector3.UP)
		movie_caption = "NpcA climbs to floor 2 and reaches NpcB"
	else:
		var progress := clampf((t - 9.6) / 2.4, 0.0, 1.0)
		movie_camera.position = Vector3(lerpf(-12.0, -10.0, progress), lerpf(9.5, 8.0, progress), lerpf(-5.0, -6.5, progress))
		movie_camera.look_at(Vector3(-4.5, 4.0, -13.5), Vector3.UP)
		movie_caption = "Acceptance checks passed"
	if t >= MOVIE_SECONDS:
		print("movie timeline finished at " + str(t))
		get_tree().quit(0)
		return
	if capture_enabled and Engine.get_physics_frames() % 2 == 0:
		await _capture_movie_frame()


func _capture_movie_frame() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var absolute := ProjectSettings.globalize_path(CAPTURE_DIR + "/frame_%05d.png" % capture_index)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	image.save_png(absolute)
	capture_index += 1


func _build_preview_extras() -> void:
	preview_camera = Camera3D.new()
	preview_camera.name = "NpcAThirdPersonCamera"
	preview_camera.position = Vector3(-3.6, 2.6, 3.8)
	preview_camera.fov = 62.0
	npc_a.add_child(preview_camera)
	preview_camera.current = true
	var layer := CanvasLayer.new()
	layer.name = "PreviewHud"
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(24.0, 22.0)
	panel.size = Vector2(660.0, 62.0)
	panel.color = Color(0.025, 0.04, 0.055, 0.82)
	layer.add_child(panel)
	var label := Label.new()
	label.position = Vector2(16.0, 12.0)
	label.text = "Model Nav Village · authored turret house · NpcA climbs to NpcB on floor 2"
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)


func _update_preview_camera() -> void:
	if preview_camera == null or npc_a == null:
		return
	var look := npc_b.global_position
	if path_ready and agent != null:
		var next := agent.get_next_path_position()
		if next != Vector3.ZERO and next.distance_to(npc_a.global_position) > 0.01:
			look = npc_a.global_position.lerp(next, 0.6)
			look.y += 1.0
	preview_camera.look_at(look, Vector3.UP)


func _build_route_markers() -> void:
	if agent == null or not path_ready:
		return
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color.html("FFF02A")
	glow.emission_enabled = true
	glow.emission = Color.html("FFF02A")
	glow.emission_energy_multiplier = 3.5
	glow.roughness = 0.22
	var route: Array = []
	var outdoor := agent.get_current_navigation_path()
	for point in outdoor:
		route.append(point)
	for point in INDOOR_ROUTE:
		route.append(point)
	for index in range(1, route.size()):
		var a: Vector3 = route[index - 1]
		var b: Vector3 = route[index]
		var length := a.distance_to(b)
		if length <= 0.01:
			continue
		var piece := MeshInstance3D.new()
		piece.name = "RouteGlow_%02d" % index
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.07, length)
		piece.mesh = box
		piece.material_override = glow
		piece.position = (a + b) * 0.5
		add_child(piece)
		var direction := (b - a).normalized()
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.92 else Vector3.UP
		piece.look_at(piece.global_position + direction, up)


func _plain_material(color: Color, rough: float = 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	return material
