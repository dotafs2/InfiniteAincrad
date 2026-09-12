extends "res://tests/town_material_travel_probe.gd"
## SAME-WORLD MATERIAL RESUME probe. Standalone SceneTree diagnostic; NOT executed here.
## Continues the persisted blocked fixture:travel-crate job from the immutable baseline
## on a byte-exact copy. Recreates the labelled fixture crate while paused, then lets
## real physics resume the existing pending job. No host_move, no clock overrides,
## no completion fabrication, no cold write.

const RESUME_LIMIT_MS := 85000
const RESUME_SAMPLE_MS := 500
const RESUME_MAX_SAMPLES := 180
const RESUME_PROGRESS_MS := 10000
const RESUME_ARRIVAL := 0.45
const RESUME_DETOUR_X := 0.7
const RESUME_ENCLOSED_LIMIT_MS := 5000
const RESUME_ENCLOSED_DISPLACEMENT := 0.05

var _resumed_previous_command := false
var _resume_samples: Array = []
var _resume_receipt: Dictionary = {}
var _resume_stock := -1
var _resume_iron := -1
var _resume_distance := -1.0
var _resume_wall_ms := 0
var _resume_detour_x := 0.0
var _resume_collider_hits := 0
var _resume_elapsed_zero_while_far := true
var _resume_elapsed_violation := false
var _resume_pending_empty := false
var _resume_pending_job: Dictionary = {}
var _resume_start_stock := -1
var _resume_start_iron := -1
var _resume_start_coin := -1
var _resume_start_total_iron := -1
var _resume_final_total_iron := -1
var _resume_final_coin := -1
var _resume_sample_frames := 0
var _resume_overlap_frames := 0
var _resume_invalid_frames := 0
var _resume_cold_bytes_equal := false
var _resume_history_prefix_equal := false
var _resume_life_stable := false
var _resume_residents_stable := false
var _resume_cold_receipt: Dictionary = {}
var _resume_cold_pending: Dictionary = {}
var _resume_cold_stock := -1
var _resume_cold_iron := -1
var _resume_cold_source: Dictionary = {}
var _resume_final_source: Dictionary = {}
var _resume_final_bytes := PackedByteArray()
var _resume_original_bytes := PackedByteArray()
var _resume_original_events: Array = []
var _resume_original_items: Array = []
var _resume_original_contracts: Array = []
var _resume_original_skills: Array = []
var _resume_original_residents: Array = []
var _resume_original_open_receipt: Dictionary = {}
var _resume_original_pending: Dictionary = {}
var _resume_crate: StaticBody3D = null
var _resume_sampler: Node = null
var _resume_preflight_ok := false
var _enclosed_mode := false
var _resume_obstacles: Array = []
var _resume_initial_body_position := Vector3.ZERO
var _resume_body_displacement := -1.0
var _resume_blocked_animation_correct := false
var _resume_blocked_animation_samples := 0
var _resume_geometry: Dictionary = {}

class ResumeSampler extends Node:
	var body: CharacterBody3D
	var crate: StaticBody3D
	var obstacles: Array = []
	var collider_hits := 0
	var sample_frames := 0
	var overlap_frames := 0
	var invalid_frames := 0

	func _capsule_shape() -> CollisionShape3D:
		if body == null:
			return null
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:
				return child
		return null

	func _physics_process(_delta: float) -> void:
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			invalid_frames += 1
			return
		if crate == null or not is_instance_valid(crate) or not crate.is_inside_tree():
			invalid_frames += 1
			return
		for obstacle in obstacles:
			if obstacle == null or not is_instance_valid(obstacle) or not obstacle.is_inside_tree():
				invalid_frames += 1
				return
		var world_3d: World3D = body.get_world_3d()
		if world_3d == null:
			invalid_frames += 1
			return
		var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
		if space == null:
			invalid_frames += 1
			return
		var shape_node: CollisionShape3D = _capsule_shape()
		if shape_node == null or not is_instance_valid(shape_node) or shape_node.shape == null or shape_node.disabled:
			invalid_frames += 1
			return
		if not body.has_method("get_rid"):
			invalid_frames += 1
			return
		if body.get_slide_collision_count() > 0:
			for i in body.get_slide_collision_count():
				var c := body.get_slide_collision(i)
				if c.get_collider() == crate:
					collider_hits += 1
				elif obstacles.has(c.get_collider()):
					collider_hits += 1
		sample_frames += 1
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.collision_mask = crate.collision_layer
		query.margin = 0.0
		query.exclude = [body.get_rid()]
		var results := space.intersect_shape(query, 32)
		var overlapped := false
		for r in results:
			var hit_collider = r.get("collider")
			if hit_collider == crate or obstacles.has(hit_collider):
				overlapped = true
				break
		if overlapped:
			overlap_frames += 1

func _resume_preflight() -> bool:
	_resume_original_bytes = _read_bytes(_save_path)
	if _resume_original_bytes.is_empty():
		_fail("fixture_unreadable")
		return false
	_runtime = Runtime.new()
	var loaded: Dictionary = _runtime.load_from(_save_path)
	if not loaded.get("ok", false):
		_fail("load_failed")
		return false
	var world: Dictionary = _runtime.snapshot()
	if not world.get("fixture", false):
		_fail("not_fixture")
		return false
	if str(world.get("world_id", "")) != "fixture:town-trade-validation":
		_fail("wrong_world_id")
		return false
	var positions: Dictionary = world.godot.get("positions", {})
	var expected_ids := ["fixture:carpenter", "fixture:innkeeper", "fixture:smith"]
	if JSON.stringify(_resident_ids(world)) != JSON.stringify(expected_ids):
		_fail("resident_id_set_mismatch")
		return false
	for id in expected_ids:
		if not positions.has(id):
			_fail("missing_position:" + id)
			return false
		var actual: Vector3 = _runtime.position_of(id)
		if not actual.is_finite():
			_fail("nonfinite_position:" + id)
			return false
	var materials: Dictionary = world.godot.get("materials", {})
	var sources: Dictionary = materials.get("sources", {})
	if not sources.has("fixture:travel-iron"):
		_fail("missing_material_source")
		return false
	var src: Dictionary = sources.get("fixture:travel-iron", {})
	if str(src.get("id", "")) != "fixture:travel-iron":
		_fail("source_id_mismatch")
		return false
	if str(src.get("material", "")) != "iron":
		_fail("material_id_mismatch")
		return false
	if int(src.get("initial_stock", -1)) != 3:
		_fail("source_initial_stock_not_3")
		return false
	if int(src.get("stock", -1)) != 2:
		_fail("source_stock_not_2")
		return false
	if int(src.get("recovered", -1)) != 1:
		_fail("source_recovered_not_1")
		return false
	var src_pos: Array = src.get("position", [])
	if src_pos.size() != 3 or absf(float(src_pos[0])) > 0.001 or absf(float(src_pos[1]) - 0.22) > 0.001 or absf(float(src_pos[2]) - 5.0) > 0.001:
		_fail("source_position_mismatch")
		return false
	var smith_iron := -1
	for a in world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			smith_iron = int(a.get("iron", -1))
	if smith_iron != 2:
		_fail("smith_iron_not_2")
		return false
	_resume_start_stock = 2
	_resume_start_iron = 2
	_resume_start_coin = _coins_total(world)
	_resume_start_total_iron = _total_iron(world)
	var commands: Dictionary = materials.get("commands", {})
	var open_cmd: Dictionary = commands.get("fixture:travel-open", {})
	var open_result: Dictionary = open_cmd.get("result", {})
	if open_result.is_empty():
		_fail("missing_open_receipt")
		return false
	if not open_result.get("ok", false):
		_fail("open_receipt_not_ok")
		return false
	if str(open_result.get("code", "")) != "material_recovered":
		_fail("open_receipt_code")
		return false
	if int(open_result.get("quantity", 0)) != 1:
		_fail("open_receipt_quantity")
		return false
	_resume_original_open_receipt = open_result.duplicate(true)
	if commands.has("fixture:travel-crate"):
		var crate_cmd: Dictionary = commands.get("fixture:travel-crate", {})
		if not crate_cmd.get("result", {}).is_empty():
			_fail("second_completion_receipt")
			return false
	var pending: Dictionary = _runtime.pending_job("fixture:smith")
	if pending.is_empty():
		_fail("missing_pending_job")
		return false
	if str(pending.get("command_id", "")) != "fixture:travel-crate":
		_fail("pending_command_mismatch")
		return false
	if str(pending.get("action", "")) != "recover_material":
		_fail("pending_action_mismatch")
		return false
	if str(pending.get("source_id", "")) != "fixture:travel-iron":
		_fail("pending_source_id_mismatch")
		return false
	if str(pending.get("provenance", "")) != "opengameagent_fixture":
		_fail("pending_provenance_mismatch")
		return false
	if float(pending.get("elapsed", -1.0)) != 0.0:
		_fail("pending_elapsed_not_zero")
		return false
	if float(pending.get("duration_seconds", -1.0)) != 60.0:
		_fail("pending_duration_not_60")
		return false
	_resume_original_pending = pending.duplicate(true)
	_resume_original_events = world.life.events.duplicate(true)
	_resume_original_items = world.life.items.duplicate(true)
	_resume_original_contracts = world.life.contracts.duplicate(true)
	_resume_original_skills = world.life.skills.duplicate(true)
	_resume_original_residents = _resident_ids(world)
	if _read_bytes(_save_path) != _resume_original_bytes:
		_fail("bytes_changed_on_load")
		return false
	_resume_preflight_ok = true
	return true

func _resident_ids(world: Dictionary) -> Array:
	var ids: Array = []
	for r in world.residents:
		ids.append(str(r.get("stable_id", "")))
	ids.sort()
	return ids

func _coins_total(world: Dictionary) -> int:
	var total := 0
	for r in world.residents:
		total += int(r.get("coins_col", 0))
	for a in world.life.get("accounts", []):
		total += int(a.get("reserved_col", 0))
	return total

func _total_iron(world: Dictionary) -> int:
	var total := 0
	for a in world.life.accounts:
		total += int(a.get("iron", 0))
	var sources: Dictionary = world.godot.get("materials", {}).get("sources", {})
	for key in sources.keys():
		var s: Dictionary = sources[key]
		if str(s.get("material", "")) == "iron":
			total += int(s.get("stock", 0))
	return total

func _resume_prime() -> bool:
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	await process_frame
	await process_frame
	if not _scene._market_loaded:
		_fail("market_not_loaded")
		return false
	if not _scene.paused:
		_fail("scene_not_paused")
		return false
	if _scene.model_turns != null:
		_fail("model_turns_not_null")
		return false
	if not is_instance_valid(_scene.material_visibility):
		_fail("material_visibility_missing")
		return false
	if not _scene.town._material_visibility_required:
		_fail("material_visibility_not_required")
		return false
	if not _scene.town._material_visibility_probe.is_valid():
		_fail("material_visibility_probe_invalid")
		return false
	if _scene.town._material_visibility_probe.get_object() != _scene.material_visibility:
		_fail("material_visibility_probe_mismatch")
		return false
	if not is_instance_valid(_scene.material_steering):
		_fail("material_steering_missing")
		return false
	for id in ["fixture:innkeeper", "fixture:smith", "fixture:carpenter"]:
		if not _scene.bodies.has(id):
			_fail("scene_missing_body:" + id)
			return false
	if _read_bytes(_save_path) != _resume_original_bytes:
		_fail("bytes_changed_after_scene")
		return false
	_scene.scripted_trade = true
	var crate_size := Vector3(1.2, 0.55, 0.5)
	if _enclosed_mode:
		crate_size = Vector3(4, 0.55, 0.5)
	_resume_crate = StaticBody3D.new()
	_resume_crate.name = "FixtureTravelCrate"
	_resume_crate.collision_layer = 1
	_resume_crate.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = crate_size
	shape.shape = box
	_resume_crate.add_child(shape)
	var mesh := MeshInstance3D.new()
	var boxmesh := BoxMesh.new()
	boxmesh.size = crate_size
	mesh.mesh = boxmesh
	_resume_crate.add_child(mesh)
	_resume_crate.position = Vector3(0, 0.495, 6)
	_scene.add_child(_resume_crate)
	_resume_obstacles = [_resume_crate]
	_resume_geometry = {
		"front_crate": {"size": [crate_size.x, crate_size.y, crate_size.z], "center": [0, 0.495, 6]},
	}
	if _enclosed_mode:
		var wall_specs := [
			{"name": "FixtureEnclosureBack", "size": Vector3(4, 0.55, 0.5), "center": Vector3(0, 0.495, 4)},
			{"name": "FixtureEnclosureSideLeft", "size": Vector3(0.5, 0.55, 2), "center": Vector3(-2, 0.495, 5)},
			{"name": "FixtureEnclosureSideRight", "size": Vector3(0.5, 0.55, 2), "center": Vector3(2, 0.495, 5)},
		]
		for spec in wall_specs:
			var wall := StaticBody3D.new()
			wall.name = str(spec.get("name", "FixtureEnclosureWall"))
			wall.collision_layer = 1
			wall.collision_mask = 1
			var wall_shape := CollisionShape3D.new()
			var wall_box := BoxShape3D.new()
			wall_box.size = spec.get("size", Vector3(1, 1, 1))
			wall_shape.shape = wall_box
			wall.add_child(wall_shape)
			var wall_mesh := MeshInstance3D.new()
			var wall_boxmesh := BoxMesh.new()
			wall_boxmesh.size = spec.get("size", Vector3(1, 1, 1))
			wall_mesh.mesh = wall_boxmesh
			wall.add_child(wall_mesh)
			wall.position = spec.get("center", Vector3.ZERO)
			_scene.add_child(wall)
			_resume_obstacles.append(wall)
			_resume_geometry[str(spec.get("name", "FixtureEnclosureWall"))] = {
				"size": [wall_box.size.x, wall_box.size.y, wall_box.size.z],
				"center": [wall.position.x, wall.position.y, wall.position.z],
			}
	await physics_frame
	await physics_frame
	await process_frame
	if _read_bytes(_save_path) != _resume_original_bytes:
		_fail("bytes_changed_after_crate")
		return false
	var sampler := ResumeSampler.new()
	sampler.process_physics_priority = 10
	sampler.body = _scene.bodies.get("fixture:smith") as CharacterBody3D
	sampler.crate = _resume_crate
	sampler.obstacles = _resume_obstacles
	_scene.add_child(sampler)
	_resume_sampler = sampler
	return true

func _resume_run() -> bool:
	var body: CharacterBody3D = _scene.bodies.get("fixture:smith") as CharacterBody3D
	if body == null:
		_fail("resume_body_missing")
		return false
	var pending: Dictionary = _scene.town.pending_job("fixture:smith")
	if pending.is_empty():
		_fail("resume_pending_missing")
		return false
	_resumed_previous_command = true
	_resume_initial_body_position = body.global_position
	var limit_ms := RESUME_LIMIT_MS
	if _enclosed_mode:
		limit_ms = RESUME_ENCLOSED_LIMIT_MS
	var blocked_animation_aggregate := true
	if _enclosed_mode:
		_resume_blocked_animation_samples = 0
	_scene.paused = false
	var start := Time.get_ticks_msec()
	var last_progress := start
	var count := 0
	while Time.get_ticks_msec() - start < limit_ms:
		await physics_frame
		await process_frame
		var now := Time.get_ticks_msec()
		if now - start >= count * RESUME_SAMPLE_MS and count < RESUME_MAX_SAMPLES:
			count += 1
			var w: Dictionary = _scene.town.snapshot()
			var pos: Vector3 = body.global_position
			var core: Vector3 = _scene.town.position_of("fixture:smith")
			var dist: float = pos.distance_to(Vector3(0, 0.22, 5))
			var job: Dictionary = _scene.town.pending_job("fixture:smith")
			var src: Dictionary = w.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
			var sample_iron := -1
			for a in w.life.accounts:
				if a.get("resident_id") == "fixture:smith":
					sample_iron = int(a.get("iron", -1))
			var elapsed := float(job.get("elapsed", -1.0))
			if dist > RESUME_ARRIVAL and elapsed != 0.0:
				_resume_elapsed_violation = true
				_resume_elapsed_zero_while_far = false
			_resume_detour_x = maxf(_resume_detour_x, absf(pos.x))
			if _enclosed_mode and dist > RESUME_ARRIVAL:
				var sample_actor = _scene.actors.get("fixture:smith")
				var sample_actor_idle := false
				if sample_actor != null and is_instance_valid(sample_actor):
					sample_actor_idle = str(sample_actor._gesture) == "idle" and sample_actor._walking == false
				blocked_animation_aggregate = blocked_animation_aggregate and sample_actor_idle
				_resume_blocked_animation_samples += 1
			_resume_samples.append({
				"t_ms": now - start,
				"position": [pos.x, pos.y, pos.z],
				"core": [core.x, core.y, core.z],
				"distance": dist,
				"pending_elapsed": elapsed,
				"stock": int(src.get("stock", -1)),
				"iron": sample_iron,
			})
			if now - last_progress >= RESUME_PROGRESS_MS:
				last_progress = now
				print("resume progress t=%d dist=%.2f stock=%d" % [now - start, dist, int(src.get("stock", -1))])
		if _scene.paused:
			_fail("resume_scene_paused")
			break
		var job_now: Dictionary = _scene.town.pending_job("fixture:smith")
		if job_now.is_empty():
			break
	_scene.paused = true
	_resume_wall_ms = Time.get_ticks_msec() - start
	_resume_body_displacement = body.global_position.distance_to(_resume_initial_body_position)
	var final_world: Dictionary = _scene.town.snapshot()
	_resume_distance = body.global_position.distance_to(Vector3(0, 0.22, 5))
	_resume_pending_job = _scene.town.pending_job("fixture:smith")
	_resume_pending_empty = _resume_pending_job.is_empty()
	var src_final: Dictionary = final_world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	_resume_final_source = src_final.duplicate(true)
	_resume_stock = int(src_final.get("stock", -1))
	_resume_iron = -1
	for a in final_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			_resume_iron = int(a.get("iron", -1))
	_resume_final_coin = _coins_total(final_world)
	_resume_final_total_iron = _total_iron(final_world)
	_resume_receipt = final_world.godot.get("materials", {}).get("commands", {}).get("fixture:travel-crate", {}).get("result", {})
	if _resume_sampler != null and is_instance_valid(_resume_sampler):
		_resume_collider_hits = _resume_sampler.collider_hits
		_resume_sample_frames = _resume_sampler.sample_frames
		_resume_overlap_frames = _resume_sampler.overlap_frames
		_resume_invalid_frames = _resume_sampler.invalid_frames
	if _enclosed_mode:
		var smith = _scene.actors.get("fixture:smith")
		var final_actor_idle := false
		if smith != null and is_instance_valid(smith):
			final_actor_idle = str(smith._gesture) == "idle" and smith._walking == false
		_resume_blocked_animation_correct = blocked_animation_aggregate and final_actor_idle
	return true

func _resume_check() -> void:
	if _enclosed_mode:
		_resume_check_enclosed()
		return
	if _resume_receipt.is_empty():
		_fail("no_resume_receipt")
		return
	if not _resume_receipt.get("ok", false):
		_fail("resume_receipt_not_ok")
	if str(_resume_receipt.get("code", "")) != "material_recovered":
		_fail("resume_receipt_code")
	if int(_resume_receipt.get("quantity", 0)) != 1:
		_fail("resume_receipt_quantity")
	if str(_resume_receipt.get("command_id", "")) != "fixture:travel-crate":
		_fail("resume_receipt_command_id")
	if str(_resume_receipt.get("actor_id", "")) != "fixture:smith":
		_fail("resume_receipt_actor")
	if str(_resume_receipt.get("source_id", "")) != "fixture:travel-iron":
		_fail("resume_receipt_source")
	if _resume_stock != 1:
		_fail("resume_stock_not_1")
	if _resume_iron != 3:
		_fail("resume_iron_not_3")
	if not _resume_pending_empty:
		_fail("resume_pending_not_empty")
	if _resume_detour_x <= RESUME_DETOUR_X:
		_fail("no_horizontal_detour")
	if _resume_sample_frames <= 0:
		_fail("no_overlap_samples")
	if _resume_overlap_frames != 0:
		_fail("capsule_overlapped_crate")
	if _resume_invalid_frames != 0:
		_fail("invalid_overlap_frames")
	if _resume_elapsed_violation:
		_fail("elapsed_advanced_while_far")
	if _resume_distance > RESUME_ARRIVAL:
		_fail("final_distance_too_large")
	if _resume_final_total_iron != _resume_start_total_iron:
		_fail("iron_not_conserved")
	if _resume_final_coin != _resume_start_coin:
		_fail("coin_not_stable")

func _resume_check_enclosed() -> void:
	if not _resume_receipt.is_empty():
		_fail("enclosed_unexpected_receipt")
	if _resume_pending_empty:
		_fail("enclosed_pending_empty")
	if JSON.stringify(_resume_pending_job) != JSON.stringify(_resume_original_pending):
		_fail("enclosed_pending_changed")
	if _resume_stock != 2:
		_fail("enclosed_stock_not_2")
	if _resume_iron != 2:
		_fail("enclosed_iron_not_2")
	if _resume_final_total_iron != _resume_start_total_iron:
		_fail("enclosed_iron_not_conserved")
	if _resume_final_coin != _resume_start_coin:
		_fail("enclosed_coin_not_stable")
	if _resume_distance <= RESUME_ARRIVAL:
		_fail("enclosed_final_distance_too_small")
	if _resume_body_displacement < 0.0 or _resume_body_displacement >= RESUME_ENCLOSED_DISPLACEMENT:
		_fail("enclosed_body_displacement_too_large")
	if _resume_wall_ms < RESUME_ENCLOSED_LIMIT_MS:
		_fail("enclosed_wall_elapsed_short")
	if _resume_sample_frames <= 0:
		_fail("enclosed_no_shape_queries")
	if _resume_overlap_frames != 0:
		_fail("enclosed_capsule_overlapped")
	if _resume_invalid_frames != 0:
		_fail("enclosed_invalid_frames")
	if _resume_elapsed_violation:
		_fail("enclosed_elapsed_advanced_while_far")
	for sample in _resume_samples:
		if float(sample.get("distance", 0.0)) > RESUME_ARRIVAL and float(sample.get("pending_elapsed", -1.0)) != 0.0:
			_fail("enclosed_far_sample_elapsed_nonzero")
			break
	if _resume_blocked_animation_samples < 8:
		_fail("enclosed_blocked_animation_samples_insufficient")
	if not _resume_blocked_animation_correct:
		_fail("enclosed_blocked_animation_incorrect")

func _resume_finalize() -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_scene.paused = true
	_resume_final_bytes = _read_bytes(_save_path)
	var final_world: Dictionary = _scene.town.snapshot()
	var events: Array = final_world.life.events
	_resume_history_prefix_equal = events.size() >= _resume_original_events.size()
	if _resume_history_prefix_equal:
		for i in _resume_original_events.size():
			if JSON.stringify(events[i]) != JSON.stringify(_resume_original_events[i]):
				_resume_history_prefix_equal = false
				break
	if not _resume_history_prefix_equal:
		_fail("history_prefix_changed")
	_resume_life_stable = JSON.stringify(final_world.life.items) == JSON.stringify(_resume_original_items) and JSON.stringify(final_world.life.contracts) == JSON.stringify(_resume_original_contracts) and JSON.stringify(final_world.life.skills) == JSON.stringify(_resume_original_skills)
	if not _resume_life_stable:
		_fail("life_not_stable")
	_resume_residents_stable = JSON.stringify(_resident_ids(final_world)) == JSON.stringify(_resume_original_residents)
	if not _resume_residents_stable:
		_fail("residents_not_stable")
	var preserved_open: Dictionary = final_world.godot.get("materials", {}).get("commands", {}).get("fixture:travel-open", {}).get("result", {})
	if JSON.stringify(preserved_open) != JSON.stringify(_resume_original_open_receipt):
		_fail("open_receipt_not_preserved")
	var final_src: Dictionary = final_world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	var final_commands: Dictionary = final_world.godot.get("materials", {}).get("commands", {})
	var final_jobs: Dictionary = final_world.godot.get("materials", {}).get("jobs", {})
	var final_iron_account := -1
	for a in final_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			final_iron_account = int(a.get("iron", -1))
	var final_coins := _coins_total(final_world)
	var final_pending: Dictionary = _scene.town.pending_job("fixture:smith")
	var release_result: Dictionary = {"ok": false, "code": "not_attempted"}
	if _scene.town != null and is_instance_valid(_scene.town):
		release_result = _scene.town.release_writer(_scene._save_path)
	if not release_result.get("ok", false):
		_fail("writer_release_failed:" + str(release_result.get("code", "unknown")))
	else:
		_scene._owns_writer = false
	_scene.queue_free()
	await process_frame
	_scene = null
	var cold := Runtime.new()
	var cold_loaded: Dictionary = cold.load_from(_save_path)
	if not cold_loaded.get("ok", false):
		_fail("cold_load_failed")
		return
	_resume_cold_bytes_equal = _read_bytes(_save_path) == _resume_final_bytes
	if not _resume_cold_bytes_equal:
		_fail("cold_bytes_changed")
	var cold_world: Dictionary = cold.snapshot()
	_resume_cold_receipt = cold_world.godot.get("materials", {}).get("commands", {}).get("fixture:travel-crate", {}).get("result", {})
	_resume_cold_pending = cold.pending_job("fixture:smith")
	var cold_src: Dictionary = cold_world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	_resume_cold_stock = int(cold_src.get("stock", -1))
	_resume_cold_iron = -1
	for a in cold_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			_resume_cold_iron = int(a.get("iron", -1))
	if JSON.stringify(_resume_cold_receipt) != JSON.stringify(_resume_receipt):
		_fail("cold_receipt_mismatch")
	if _resume_cold_stock != _resume_stock:
		_fail("cold_stock_mismatch")
	if _resume_cold_iron != _resume_iron:
		_fail("cold_iron_mismatch")
	if JSON.stringify(cold_world.life.events) != JSON.stringify(final_world.life.events):
		_fail("cold_events_mismatch")
	if JSON.stringify(cold_world.life.items) != JSON.stringify(final_world.life.items):
		_fail("cold_items_mismatch")
	if JSON.stringify(cold_world.life.contracts) != JSON.stringify(final_world.life.contracts):
		_fail("cold_contracts_mismatch")
	if JSON.stringify(cold_world.life.skills) != JSON.stringify(final_world.life.skills):
		_fail("cold_skills_mismatch")
	if JSON.stringify(cold_src) != JSON.stringify(final_src):
		_fail("cold_source_mismatch")
	if JSON.stringify(cold_world.godot.get("materials", {}).get("commands", {})) != JSON.stringify(final_commands):
		_fail("cold_commands_mismatch")
	if JSON.stringify(cold_world.godot.get("materials", {}).get("jobs", {})) != JSON.stringify(final_jobs):
		_fail("cold_jobs_mismatch")
	if _coins_total(cold_world) != final_coins:
		_fail("cold_coins_mismatch")
	var cold_iron_account := -1
	for a in cold_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			cold_iron_account = int(a.get("iron", -1))
	if cold_iron_account != final_iron_account:
		_fail("cold_iron_account_mismatch")
	if JSON.stringify(_resume_cold_pending) != JSON.stringify(final_pending):
		_fail("cold_pending_mismatch")

func _write_output() -> void:
	if not _output_authorized:
		return
	var mode_name := "offline_scripted_same_world_material_resume"
	if _enclosed_mode:
		mode_name = "offline_scripted_same_world_material_enclosed"
	var payload := {
		"mode": mode_name,
		"enclosed_mode": _enclosed_mode,
		"resumed_previous_command": _resumed_previous_command,
		"success": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"before_stock": _resume_start_stock,
		"after_stock": _resume_stock,
		"before_iron": _resume_start_iron,
		"after_iron": _resume_iron,
		"cold_bytes_equal": _resume_cold_bytes_equal,
		"history_prefix_equal": _resume_history_prefix_equal,
		"life_stable": _resume_life_stable,
		"residents_stable": _resume_residents_stable,
		"final_distance": _resume_distance,
		"detour_x": _resume_detour_x,
		"collider_hits": _resume_collider_hits,
		"sample_frames": _resume_sample_frames,
		"overlap_frames": _resume_overlap_frames,
		"invalid_frames": _resume_invalid_frames,
		"wall_elapsed_ms": _resume_wall_ms,
		"body_displacement": _resume_body_displacement,
		"blocked_animation_correct": _resume_blocked_animation_correct,
		"blocked_animation_samples": _resume_blocked_animation_samples,
		"pending_job": _resume_pending_job,
		"cold_pending": _resume_cold_pending,
		"total_iron_before": _resume_start_total_iron,
		"total_iron_after": _resume_final_total_iron,
		"coins_before": _resume_start_coin,
		"coins_after": _resume_final_coin,
		"geometry": _resume_geometry,
		"receipt": _resume_receipt,
		"cold_receipt": _resume_cold_receipt,
		"samples": _resume_samples,
	}
	var f := FileAccess.open(_out_path, FileAccess.WRITE)
	if f == null:
		_fail("output_write_failed")
		return
	f.store_string(JSON.stringify(payload, "  "))
	var store_err := f.get_error()
	f.close()
	if store_err != OK:
		_fail("output_store_failed")

func _finish() -> void:
	if _writer_held:
		_runtime.release_writer(_save_path)
		_writer_held = false
	if _scene != null and is_instance_valid(_scene):
		_scene.paused = true
		if _scene.town != null and is_instance_valid(_scene.town):
			_scene.town.release_writer(_scene._save_path)
		_scene.queue_free()
		await process_frame
		_scene = null
	_write_output()
	var mode_name := "offline_scripted_same_world_material_resume"
	if _enclosed_mode:
		mode_name = "offline_scripted_same_world_material_enclosed"
	print(JSON.stringify({
		"mode": mode_name,
		"enclosed_mode": _enclosed_mode,
		"resumed_previous_command": _resumed_previous_command,
		"success": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"before_stock": _resume_start_stock,
		"after_stock": _resume_stock,
		"before_iron": _resume_start_iron,
		"after_iron": _resume_iron,
		"cold_bytes_equal": _resume_cold_bytes_equal,
		"history_prefix_equal": _resume_history_prefix_equal,
		"sample_count": _resume_samples.size(),
		"sample_frames": _resume_sample_frames,
		"overlap_frames": _resume_overlap_frames,
		"invalid_frames": _resume_invalid_frames,
		"body_displacement": _resume_body_displacement,
		"blocked_animation_correct": _resume_blocked_animation_correct,
		"blocked_animation_samples": _resume_blocked_animation_samples,
		"pending_job": _resume_pending_job,
		"cold_pending": _resume_cold_pending,
		"geometry": _resume_geometry,
		"receipt": _resume_receipt,
	}))
	if not _failures.is_empty():
		_exit_code = 1
	quit(_exit_code)

func _run() -> void:
	_parse_args()
	_enclosed_mode = false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--travel-probe-enclosed":
			_enclosed_mode = true
	if _rejected_mode:
		await _finish()
		return
	if not _validate_paths():
		await _finish()
		return
	if not _resume_preflight():
		await _finish()
		return
	if not await _resume_prime():
		await _finish()
		return
	if not await _resume_run():
		await _finish()
		return
	_resume_check()
	await _resume_finalize()
	await _finish()

func _initialize() -> void:
	_run.call_deferred()
