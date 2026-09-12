extends SceneTree
## OPEN travel+recovery probe. Standalone SceneTree diagnostic; NOT executed here.
## Scope: legitimate ask_help -> development_gm install -> real physics travel ->
## material recovery receipt. No crate phase, no host_move, no clock changes.
## No conservation/stable-state/cold-reload checks (covered by accepted suites).

const Runtime := preload("res://core/town_runtime.gd")
const TownScene := preload("res://scenes/town_street.tscn")

const ALLOWED_ROOT_REL := "../tmp/overnight-20260912"
const PRIME_MS := 1200
const TRAVEL_LIMIT_MS := 85000
const SAMPLE_MS := 500
const MAX_SAMPLES := 200
const PROGRESS_MS := 10000

var _save_path := ""
var _out_path := ""
var _allowed_root := ""
var _scene: Node = null
var _runtime: RefCounted = null
var _writer_held := false
var _output_authorized := false
var _prepared_bytes := PackedByteArray()
var _open_passed := false
var _failures: Array = []
var _samples: Array = []
var _receipt: Dictionary = {}
var _final_position := Vector3.ZERO
var _final_distance := -1.0
var _pending_elapsed := -1.0
var _wall_elapsed := 0
var _source_stock := -1
var _smith_iron := -1
var _exit_code := 0
var _rejected_mode := false
var _crate_mode := false
var _crate_diagnosis: Dictionary = {}
var _crate_samples: Array = []
var _crate_visible_samples := 0
var _crate_blocked_samples := 0
var _crate_collider_hits := 0
var _crate_pending_job: Dictionary = {}
var _crate_receipt: Dictionary = {}
var _crate_stock := -1
var _crate_iron := -1
var _crate_distance := -1.0
var _crate_last5s_displacement := -1.0
var _crate_wall_elapsed_ms := 0
var _crate_blocked_reproduced := false
var _crate_fixture_relocation := false
var _crate_start_stock := -1
var _crate_start_iron := -1

class CrateSampler extends Node:
	var sight: Callable
	var body: CharacterBody3D
	var crate: StaticBody3D
	var visible := 0
	var blocked := 0
	var collider_hits := 0

	func _physics_process(_delta: float) -> void:
		if sight.is_valid() and sight.call("fixture:smith", "fixture:travel-iron"):
			visible += 1
		else:
			blocked += 1
		if body != null and body.get_slide_collision_count() > 0:
			for i in body.get_slide_collision_count():
				var c := body.get_slide_collision(i)
				if c.get_collider() == crate:
					collider_hits += 1

func _fail(code: String) -> void:
	_failures.append(code)

func _norm(p: String) -> String:
	return p.replace("\\", "/").simplify_path()

func _under_root(p: String) -> bool:
	var root := _norm(_allowed_root)
	var q := _norm(p)
	if OS.get_name() == "Windows":
		root = root.to_lower()
		q = q.to_lower()
	if not q.begins_with(root + "/"):
		return false
	return true

func _read_bytes(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _parse_args() -> void:
	_allowed_root = _norm(ProjectSettings.globalize_path("res://").path_join(ALLOWED_ROOT_REL))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--town-save="):
			_save_path = _norm(ProjectSettings.globalize_path(a.trim_prefix("--town-save=")))
		elif a.begins_with("--travel-probe-output="):
			_out_path = _norm(ProjectSettings.globalize_path(a.trim_prefix("--travel-probe-output=")))
		elif a == "--travel-probe-crate":
			_crate_mode = true
		elif a == "--town-gateway" or a == "--town-restore" or a == "--town-repair-fixture" or a == "--town-capture" or a.begins_with("--town-capture="):
			_fail("forbidden_mode:" + a.trim_prefix("--"))
			_rejected_mode = true

func _validate_paths() -> bool:
	if _save_path.is_empty() or _out_path.is_empty():
		_fail("missing_args")
		return false
	if not _save_path.is_absolute_path() or not _out_path.is_absolute_path():
		_fail("not_absolute")
		return false
	if not _under_root(_save_path) or not _under_root(_out_path):
		_fail("outside_allowed_root")
		return false
	if _save_path.to_lower() == _out_path.to_lower():
		_fail("output_equals_input")
		return false
	if FileAccess.file_exists(_out_path):
		_fail("output_exists")
		return false
	var parent := _out_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if not _under_root(parent):
			_fail("parent_outside_root")
			return false
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			_fail("parent_create_failed")
			return false
	_output_authorized = true
	return true

func _preflight() -> bool:
	var preflight_bytes := _read_bytes(_save_path)
	if preflight_bytes.is_empty():
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
	if int(world.life.get("seq", -1)) != 0:
		_fail("seq_not_zero")
		return false
	if world.godot.has("materials"):
		_fail("materials_present")
		return false
	var positions: Dictionary = world.godot.get("positions", {})
	var expected := {
		"fixture:smith": Vector3(0, 0.22, 7),
		"fixture:innkeeper": Vector3(-2, 0.22, 7),
		"fixture:carpenter": Vector3(-2, 0.22, 5),
	}
	for id in expected:
		if not positions.has(id):
			_fail("missing_position:" + id)
			return false
		var actual: Vector3 = _runtime.position_of(id)
		if actual.distance_to(expected[id]) > 0.001:
			_fail("wrong_position:" + id)
			return false
	if _read_bytes(_save_path) != preflight_bytes:
		_fail("bytes_changed_on_load")
		return false
	return true

func _ask_and_install() -> bool:
	var ask: Dictionary = _runtime.transaction(_save_path, func(): return _runtime.submit_trade("fixture:smith", "ask:fixture:innkeeper", "fixture:travel-need", "opengameagent_fixture", "I need a finite source of iron."))
	if not ask.get("ok", false):
		_fail("ask_failed")
		return false
	var world: Dictionary = _runtime.snapshot()
	var last_type := ""
	for e in world.life.events:
		last_type = str(e.get("type", ""))
	if last_type != "ask_help":
		_fail("last_event_not_ask_help")
		return false
	var seq := int(world.life.seq)
	var spec := {
		"id": "fixture:travel-iron",
		"label": "Travel probe iron",
		"material": "iron",
		"initial_stock": 3,
		"position": [0, 0.22, 5],
		"access": "public",
	}
	var install: Dictionary = _runtime.transaction(_save_path, func(): return _runtime.install_material_source(spec, seq, "development_gm:travel-source"))
	if not install.get("ok", false):
		_fail("install_failed")
		return false
	var after: Dictionary = _runtime.snapshot()
	var src: Dictionary = after.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	if int(src.get("stock", -1)) != 3:
		_fail("install_stock_not_3")
		return false
	var known: Dictionary = after.godot.get("materials", {}).get("known", {})
	if not known.is_empty():
		_fail("premature_broadcast")
		return false
	return true

func _prime_physics() -> bool:
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
	for id in ["fixture:innkeeper", "fixture:smith", "fixture:carpenter"]:
		if not _scene.bodies.has(id):
			_fail("scene_missing_body:" + id)
			return false
	if _read_bytes(_save_path) != _prepared_bytes:
		_fail("bytes_changed_after_scene")
		return false
	if _scene.model_turns != null:
		_fail("model_turns_not_null")
		return false
	_scene.scripted_trade = true
	_scene.paused = false
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < PRIME_MS:
		await physics_frame
		await process_frame
	_scene.paused = true
	var world: Dictionary = _scene.town.snapshot()
	var src: Dictionary = world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	if int(src.get("stock", -1)) != 3:
		_fail("source_stock_changed_in_prime")
		return false
	var opts: Array = _scene.town.trade_options("fixture:smith")
	var found := false
	for o in opts:
		if str(o.get("id", "")) == "material:recover:fixture:travel-iron":
			found = true
	if not found:
		_fail("recover_option_missing")
		return false
	return true

func _run_travel() -> bool:
	var submit: Dictionary = _scene.town.transaction(_save_path, func(): return _scene.town.submit_trade("fixture:smith", "material:recover:fixture:travel-iron", "fixture:travel-open", "opengameagent_fixture"))
	if not submit.get("ok", false):
		_fail("submit_failed")
		return false
	_scene.paused = false
	var start := Time.get_ticks_msec()
	var last_progress := start
	var count := 0
	while Time.get_ticks_msec() - start < TRAVEL_LIMIT_MS:
		await physics_frame
		await process_frame
		var now := Time.get_ticks_msec()
		if now - start >= count * SAMPLE_MS and count < MAX_SAMPLES:
			count += 1
			var w: Dictionary = _scene.town.snapshot()
			var body: Node3D = _scene.bodies.get("fixture:smith")
			var pos: Vector3 = body.global_position if body != null else Vector3.ZERO
			var core: Vector3 = _scene.town.position_of("fixture:smith")
			var dist: float = pos.distance_to(Vector3(0, 0.22, 5))
			var job: Dictionary = _scene.town.pending_job("fixture:smith")
			var src: Dictionary = w.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
			_samples.append({
				"t_ms": now - start,
				"position": [pos.x, pos.y, pos.z],
				"core": [core.x, core.y, core.z],
				"distance": dist,
				"pending_elapsed": float(job.get("elapsed", -1.0)),
				"stock": int(src.get("stock", -1)),
			})
			if now - last_progress >= PROGRESS_MS:
				last_progress = now
				print("progress t=%d dist=%.2f stock=%d" % [now - start, dist, int(src.get("stock", -1))])
		var job_now: Dictionary = _scene.town.pending_job("fixture:smith")
		if job_now.is_empty():
			break
	_scene.paused = true
	_wall_elapsed = Time.get_ticks_msec() - start
	var final_world: Dictionary = _scene.town.snapshot()
	var body2: Node3D = _scene.bodies.get("fixture:smith")
	_final_position = body2.global_position if body2 != null else Vector3.ZERO
	_final_distance = _final_position.distance_to(Vector3(0, 0.22, 5))
	var job_final: Dictionary = _scene.town.pending_job("fixture:smith")
	_pending_elapsed = float(job_final.get("elapsed", -1.0))
	var src_final: Dictionary = final_world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	_source_stock = int(src_final.get("stock", -1))
	_smith_iron = -1
	for a in final_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			_smith_iron = int(a.get("iron", -1))
	_receipt = final_world.godot.get("materials", {}).get("commands", {}).get("fixture:travel-open", {}).get("result", {})
	return true

func _check_open() -> void:
	if _receipt.is_empty():
		_fail("no_receipt")
		return
	if str(_receipt.get("code", "")) != "material_recovered":
		_fail("receipt_code")
	if not _receipt.get("ok", false):
		_fail("receipt_not_ok")
	if int(_receipt.get("quantity", 0)) != 1:
		_fail("receipt_quantity")
	if str(_receipt.get("command_id", "")) != "fixture:travel-open":
		_fail("receipt_command_id")
	if _source_stock != 2:
		_fail("source_stock_not_2")
	if _smith_iron != 2:
		_fail("smith_iron_not_2")
	if not _scene.town.pending_job("fixture:smith").is_empty():
		_fail("pending_not_empty")
	if _failures.is_empty():
		_open_passed = true

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
	_write_output()
	var crate_summary := _crate_diagnosis.duplicate()
	crate_summary.erase("samples")
	print(JSON.stringify({"failure_count": _failures.size(), "open_path_passed": _open_passed, "crate_diagnosis": crate_summary, "failures": _failures}))
	if not _failures.is_empty():
		_exit_code = 1
	quit(_exit_code)

func _write_output() -> void:
	if not _output_authorized:
		return
	var payload := {
		"mode": "offline_scripted_open_travel",
		"failures": _failures,
		"failure_count": _failures.size(),
		"open_path_passed": _open_passed,
		"final_position": [_final_position.x, _final_position.y, _final_position.z],
		"final_distance": _final_distance,
		"pending_elapsed": _pending_elapsed,
		"receipt": _receipt,
		"source_stock": _source_stock,
		"smith_iron": _smith_iron,
		"wall_elapsed_ms": _wall_elapsed,
		"samples": _samples,
		"crate_diagnosis": _crate_diagnosis,
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

func _run() -> void:
	_parse_args()
	if _rejected_mode:
		await _finish()
		return
	if not _validate_paths():
		await _finish()
		return
	if not _preflight():
		await _finish()
		return
	_writer_held = true
	if not _ask_and_install():
		await _finish()
		return
	_prepared_bytes = _read_bytes(_save_path)
	if _writer_held:
		_runtime.release_writer(_save_path)
		_writer_held = false
	if not await _prime_physics():
		await _finish()
		return
	if not await _run_travel():
		await _finish()
		return
	_check_open()
	if _open_passed and _crate_mode:
		await _run_crate_diagnosis()
	await _finish()

func _run_crate_diagnosis() -> void:
	# Fixture setup only: this relocation is NOT NPC autonomous travel.
	var body: CharacterBody3D = _scene.bodies.get("fixture:smith") as CharacterBody3D
	if body == null:
		_fail("crate_body_missing")
		return
	body.position = Vector3(0, 0.22, 7)
	body.velocity = Vector3.ZERO
	var before_world: Dictionary = _scene.town.snapshot()
	var before_src: Dictionary = before_world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	_crate_start_stock = int(before_src.get("stock", -1))
	_crate_start_iron = -1
	for a in before_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			_crate_start_iron = int(a.get("iron", -1))
	if _crate_start_stock != 2 or _crate_start_iron != 2:
		_fail("crate_initial_state_not_2_2")
		return
	if not _scene.town.pending_job("fixture:smith").is_empty():
		_fail("crate_initial_pending_job")
		return
	var move: Dictionary = _scene.town.transaction(_save_path, func():
		_scene.town.host_move("fixture:smith", body.position)
		return {"ok": true, "code": "fixture_relocation"}
	)
	if not move.get("ok", false):
		_fail("crate_relocation_failed")
		return
	_crate_fixture_relocation = true
	var crate := StaticBody3D.new()
	crate.name = "FixtureTravelCrate"
	crate.collision_layer = 1
	crate.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.55, 0.5)
	shape.shape = box
	crate.add_child(shape)
	var mesh := MeshInstance3D.new()
	var boxmesh := BoxMesh.new()
	boxmesh.size = Vector3(1.2, 0.55, 0.5)
	mesh.mesh = boxmesh
	crate.add_child(mesh)
	crate.position = Vector3(0, 0.495, 6)
	_scene.add_child(crate)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	var sampler := CrateSampler.new()
	sampler.process_physics_priority = 10
	sampler.sight = Callable(_scene.material_visibility, "can_observe")
	sampler.body = body
	sampler.crate = crate
	_scene.add_child(sampler)
	var submit: Dictionary = _scene.town.transaction(_save_path, func(): return _scene.town.submit_trade("fixture:smith", "material:recover:fixture:travel-iron", "fixture:travel-crate", "opengameagent_fixture"))
	if not submit.get("ok", false):
		_fail("crate_submit_failed")
		return
	_scene.paused = false
	var start := Time.get_ticks_msec()
	var last_progress := start
	var count := 0
	var positions: Array = []
	while Time.get_ticks_msec() - start < 12000:
		await physics_frame
		await process_frame
		var now := Time.get_ticks_msec()
		if now - start >= count * SAMPLE_MS and count < 40:
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
			positions.append({"t_ms": now - start, "position": [pos.x, pos.y, pos.z]})
			_crate_samples.append({
				"t_ms": now - start,
				"position": [pos.x, pos.y, pos.z],
				"core": [core.x, core.y, core.z],
				"distance": dist,
				"pending_elapsed": float(job.get("elapsed", -1.0)),
				"stock": int(src.get("stock", -1)),
				"iron": sample_iron,
			})
			if now - last_progress >= 6000:
				last_progress = now
				print("crate progress t=%d dist=%.2f stock=%d" % [now - start, dist, int(src.get("stock", -1))])
		if _scene.paused:
			_fail("crate_scene_paused")
			break
		var job_now: Dictionary = _scene.town.pending_job("fixture:smith")
		if job_now.is_empty():
			break
	_scene.paused = true
	_crate_wall_elapsed_ms = Time.get_ticks_msec() - start
	_crate_visible_samples = sampler.visible
	_crate_blocked_samples = sampler.blocked
	_crate_collider_hits = sampler.collider_hits
	var final_world: Dictionary = _scene.town.snapshot()
	_crate_distance = body.global_position.distance_to(Vector3(0, 0.22, 5))
	_crate_pending_job = _scene.town.pending_job("fixture:smith")
	var src_final: Dictionary = final_world.godot.get("materials", {}).get("sources", {}).get("fixture:travel-iron", {})
	_crate_stock = int(src_final.get("stock", -1))
	_crate_iron = -1
	for a in final_world.life.accounts:
		if a.get("resident_id") == "fixture:smith":
			_crate_iron = int(a.get("iron", -1))
	_crate_receipt = final_world.godot.get("materials", {}).get("commands", {}).get("fixture:travel-crate", {}).get("result", {})
	var last5s := -1.0
	if positions.size() >= 2:
		var cutoff: int = _crate_wall_elapsed_ms - 5000
		var first: Dictionary = {}
		var last: Dictionary = {}
		for p in positions:
			if int(p.t_ms) <= cutoff:
				first = p
			last = p
		if not first.is_empty() and not last.is_empty():
			var span_ms := int(last.t_ms) - int(first.t_ms)
			if span_ms >= 5000:
				var a := Vector3(first.position[0], first.position[1], first.position[2])
				var b := Vector3(last.position[0], last.position[1], last.position[2])
				last5s = a.distance_to(b)
	_crate_last5s_displacement = last5s
	var pending_ok := (not _crate_pending_job.is_empty()) and str(_crate_pending_job.get("action", "")) == "recover_material" and float(_crate_pending_job.get("elapsed", -1.0)) == 0.0
	var last5s_ok := last5s >= 0.0 and last5s < 0.05
	_crate_blocked_reproduced = _failures.is_empty() and _crate_wall_elapsed_ms >= 12000 and _crate_samples.size() >= 20 and _crate_collider_hits > 0 and _crate_visible_samples > 0 and _crate_distance > 0.45 and pending_ok and last5s_ok and _crate_stock == 2 and _crate_iron == 2 and _crate_receipt.is_empty()
	_crate_diagnosis = {
		"attempted": true,
		"fixture_relocation": _crate_fixture_relocation,
		"start_stock": _crate_start_stock,
		"start_iron": _crate_start_iron,
		"visible_samples": _crate_visible_samples,
		"blocked_samples": _crate_blocked_samples,
		"collider_hit_count": _crate_collider_hits,
		"samples": _crate_samples,
		"pending_job": _crate_pending_job,
		"receipt": _crate_receipt,
		"stock": _crate_stock,
		"iron": _crate_iron,
		"distance": _crate_distance,
		"last5s_displacement": _crate_last5s_displacement,
		"wall_elapsed_ms": _crate_wall_elapsed_ms,
		"blocked_reproduced": _crate_blocked_reproduced,
	}

func _initialize() -> void:
	_run.call_deferred()
