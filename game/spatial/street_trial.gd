extends Node3D

const MARKET_GLB: String = "res://assets/market/StartingTown_Market_CraftV5.glb"
const MANIFEST_PATH: String = "res://capabilities/well_bucket.v1.json"
const DEFAULT_SAVE_PATH: String = "user://street-trial/world.json"
const RESIDENT_SCRIPT: GDScript = preload("res://spatial/trial_resident.gd")
const KERNEL_SCRIPT: GDScript = preload("res://core/world_kernel.gd")
const BRAIN_SCRIPT: GDScript = preload("res://agents/resident_brain.gd")
const WELL_POSITION: Vector3 = Vector3(1.8, 0.22, 3.0)
const RESIDENT_START: Vector3 = Vector3(-2.0, 0.22, 10.0)
const RESIDENT_SIDE: Vector3 = Vector3(-1.4, 0.22, 1.0)
const WELL_APPROACH: Vector3 = WELL_POSITION + Vector3(-1.5, 0.0, 0.0)
const WALK_SPEED: float = 1.35
const SMOKE_WALK_SPEED: float = 5.0
const MOUSE_SENSITIVITY: float = 0.0024

enum ResidentPhase { TO_WELL, WAIT_FOR_HELP, DRAWING, TO_SIDE, DRINKING, COMPLETE }

var _owns_writer: bool = false
var _phase_elapsed: float = 0.0
var _elapsed: float = 0.0
var _restore_start: Dictionary = {}
var _kernel: RefCounted = KERNEL_SCRIPT.new()
var _brain: Node
var _brain_busy := false
var _brain_blocked := false
var _brain_mode: String = "normal"
var _save_path: String = DEFAULT_SAVE_PATH
var _smoke_dir: String = ""
var _smoke_mode: bool = false
var _street_expect: String = ""
var _smoke_busy: bool = false
var _persistence_writable: bool = true
var _loaded_existing: bool = false
var _world_error: String = ""
var _phase: ResidentPhase = ResidentPhase.TO_WELL
var _resident_at_well: bool = false
var _need_submitted: bool = false
var _help_attempted: bool = false
var _waiting_after_decision: bool = false
var _side_decision_requested: bool = false
var _decision_requests: int = 0
var _wait_request_count: int = -1
var _deferred_wait_started: float = -1.0
var _resume_stable_started: float = -1.0
var _route_distance: float = 0.0
var _last_resident_position: Vector3
var _player: CharacterBody3D
var _camera_pivot: Node3D
var _camera_pitch: Node3D
var _camera: Camera3D
var _resident: Node3D
var _well: Node3D
var _hanging_bucket: Node3D
var _market_root: Node3D
var _environment: WorldEnvironment
var _status_label: Label
var _debug_label: Label
var _debug_visible: bool = false
var _market_loaded: bool = false
var _collision_count: int = 0
var _smoke_stage: int = 0
var _smoke_player_target: Vector3 = Vector3(3.35, 1.13, 5.0)
var _smoke_e_done: bool = false
var _evidence: Dictionary = {}

func _ready() -> void:
	_parse_command_line()
	_build_environment()
	_build_ground_collision()
	_load_market_runtime()
	_build_well()
	_build_player()
	_build_resident()
	_build_hud()
	_load_or_create_world()
	if not _world_error.is_empty():
		_show_error(_world_error)
		return
	_reconcile_loaded_world()
	_brain = BRAIN_SCRIPT.new()
	add_child(_brain)
	_brain.configure(_brain_mode)
	if _capability_enabled() and _phase == ResidentPhase.WAIT_FOR_HELP and not _waiting_after_decision:
		_request_draw_after_install.call_deferred()
	if _street_expect == "deferred" and _loaded_existing and _is_installed_wait_state():
		_evidence["restored"] = true
		_evidence["restored_deferred_wait"] = true
		_evidence["restored_turn"] = int(_kernel.snapshot().get("turn", -1))
		_evidence["restored_without_repeat"] = _water_drawn() == 0 and _water_consumed() == 0
		_evidence["wait_receipt"] = _last_wait_receipt()
		_evidence["deferred_wait_stable"] = true
		_smoke_stage = 99
	if _street_expect == "resume-stable" and _loaded_existing and (_waiting_after_decision or _phase == ResidentPhase.COMPLETE or (_need_submitted and not _capability_enabled())):
		_evidence["restored"] = true
		_evidence["resume_state"] = "complete" if _phase == ResidentPhase.COMPLETE else "wait"
		_resume_stable_started = _elapsed
		_smoke_stage = 99
	if _smoke_mode and _loaded_existing and _phase == ResidentPhase.COMPLETE:
		_evidence["restored"] = true
		_evidence["restored_without_repeat"] = _water_consumed() == 1
		_smoke_stage = 99
		_update_status("已恢复同一身份与经历；饮水没有重复转移。")
	if OS.get_cmdline_user_args().has("--visitor-encounter"):
		var encounter: Node = load("res://spatial/visitor_encounter.gd").new()
		add_child(encounter)

func _process(delta: float) -> void:
	_elapsed += delta
	if _smoke_mode and _elapsed > (55.0 if _brain_mode == "gateway" else 40.0):
		_world_error = "3D acceptance timed out"
		_finish_smoke(1)
		return
	_update_debug()
	if _smoke_mode and not _smoke_busy:
		_smoke_busy = true
		await _run_smoke_step()
		_smoke_busy = false
	if _resident != null and not _smoke_mode:
		_process_resident(delta)
	elif _resident != null and _phase != ResidentPhase.COMPLETE and _smoke_stage < 99:
		_process_resident(delta)

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var wish: Vector3 = Vector3.ZERO
	if _smoke_mode:
		var offset: Vector3 = _smoke_player_target - _player.global_position
		offset.y = 0.0
		if offset.length() > 0.15:
			wish = offset.normalized()
	else:
		var axes := Vector3(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), 0.0, float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		wish = _camera_pivot.global_basis * axes.normalized()
	_player.velocity.x = wish.x * 3.8
	_player.velocity.z = wish.z * 3.8
	_player.velocity.y = -0.2 if _player.is_on_floor() else _player.velocity.y - 18.0 * delta
	_player.move_and_slide()
	if _smoke_mode and _camera != null:
		_camera.look_at(WELL_APPROACH + Vector3(0.0, 1.1, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_camera_pivot.rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		_camera_pitch.rotation.x = clampf(_camera_pitch.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -1.25, 1.25)
	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key_event.keycode == KEY_F8:
			_debug_visible = not _debug_visible
			_debug_label.visible = _debug_visible
		elif key_event.keycode == KEY_E:
			_try_player_help(false)

func _process_resident(delta: float) -> void:
	if not _world_error.is_empty() or not _persistence_writable or _brain_busy or _brain_blocked:
		return
	_phase_elapsed += delta
	if _phase == ResidentPhase.TO_WELL:
		_move_resident_to(WELL_APPROACH, delta)
		if _resident.global_position.distance_to(WELL_APPROACH) < 0.18:
			_resident_at_well = true
			_evidence["arrived_before_water"] = _water_drawn() == 0
			_resident.set_walking(false)
			_phase = ResidentPhase.WAIT_FOR_HELP
			_submit_need_at_well()
	elif _phase == ResidentPhase.WAIT_FOR_HELP:
		_resident.set_walking(false)
		return
	elif _phase == ResidentPhase.TO_SIDE:
		_move_resident_to(RESIDENT_SIDE, delta)
		_resident.set_gesture("carry")
		if _resident.global_position.distance_to(RESIDENT_SIDE) < 0.18:
			_phase = ResidentPhase.DRINKING
			_phase_elapsed = 0.0
			_resident.set_walking(false)
			_request_drink_at_side()
	elif _phase == ResidentPhase.DRINKING and not _waiting_after_decision and _side_decision_requested and _water_consumed() > 0 and _phase_elapsed > 1.1:
		_phase = ResidentPhase.COMPLETE
		_persist_world("complete")
		_update_status("谢谢你的绳子和桶。喝过水，舒服多了。")
		_evidence["completed"] = true

func _move_resident_to(target: Vector3, delta: float) -> void:
	var offset: Vector3 = target - _resident.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance <= 0.001:
		_resident.set_walking(false)
		return
	var step_speed: float = SMOKE_WALK_SPEED if _smoke_mode else WALK_SPEED
	var step: float = minf(step_speed * delta, distance)
	var direction: Vector3 = offset / distance
	_resident.global_position += direction * step
	_resident.look_at(_resident.global_position + direction, Vector3.UP)
	_resident.set_walking(true)
	_route_distance += step
	_last_resident_position = _resident.global_position

func _submit_need_at_well() -> void:
	if _need_submitted:
		return
	var result: Dictionary = await _ask_resident()
	_need_submitted = _has_event("resident_need_recorded")
	if _need_submitted:
		_evidence["arrived_before_water"] = _water_drawn() == 0
		_evidence["need_source"] = "fixture_resident_observation"
		_evidence["decision_source"] = result.get("provenance", "unknown")
		_persist_world("need")
		_update_status(str(result.get("_decision_reason", "井水够不到，我需要帮忙。")) + "  走近按 E 帮忙。")
	elif not bool(result.get("ok", false)):
		_show_error("记录 need 失败：" + str(result.get("code", "unknown")))
	elif result.get("code") == "resident_waited":
		_enter_decision_wait(result, "initial_wait")

func _request_draw_after_install() -> void:
	if _waiting_after_decision or _phase != ResidentPhase.WAIT_FOR_HELP:
		return
	var result: Dictionary = await _ask_resident()
	if not bool(result.get("ok", false)):
		_show_error("安装后决策失败：" + str(result.get("code", "unknown")))
		return
	var code := str(result.get("code", ""))
	if code == "resident_waited":
		_enter_decision_wait(result, "deferred_wait")
	elif code == "water_drawn" and str(result.get("action", "")) == "draw_water":
		_phase = ResidentPhase.TO_SIDE
		_phase_elapsed = 0.0
		_resident.set_gesture("carry")
		_persist_world("draw")
		_update_status("取到水了。我去旁边歇一会儿。")
	else:
		_show_error("安装后动作未完成：" + code)

func _request_drink_at_side() -> void:
	if _side_decision_requested:
		return
	_side_decision_requested = true
	var result: Dictionary = await _ask_resident()
	if not bool(result.get("ok", false)):
		_show_error("饮水决策失败：" + str(result.get("code", "unknown")))
		return
	var code := str(result.get("code", ""))
	if code == "resident_waited":
		_side_decision_requested = false
		_enter_decision_wait(result, "rest_wait")
	elif code == "water_consumed" and str(result.get("action", "")) == "drink_water":
		_resident.set_gesture("drink")
		_update_status("水带到身边了，先喝一口。")
	else:
		_show_error("休息处动作未完成：" + code)

func _enter_decision_wait(result: Dictionary, reason: String) -> void:
	_waiting_after_decision = true
	_wait_request_count = _decision_requests
	_resident.set_walking(false)
	_resident.set_gesture("idle")
	_evidence["wait_receipt"] = result.duplicate(true)
	_evidence["wait_reason"] = reason
	_evidence["wait_turn"] = int(result.get("turn", _kernel.snapshot().get("turn", -1)))
	if reason == "deferred_wait":
		_deferred_wait_started = _elapsed
		_evidence["deferred_wait_started"] = _elapsed
		_evidence["decision_requests_at_wait"] = _decision_requests
		_persist_world("deferred_wait")
		_update_status(str(result.get("_decision_reason", "水桶已经装好了，但我现在想先等一等。")))
	else:
		_persist_world(reason)
		_update_status(str(result.get("_decision_reason", "我先歇一会儿。")))
		if reason == "rest_wait":
			_deferred_wait_started = _elapsed
			_evidence["waited_with_water_started"] = _elapsed

func _ask_resident() -> Dictionary:
	_brain_busy = true
	_decision_requests += 1
	_evidence["decision_requests"] = _decision_requests
	var turn: int = int(_kernel.snapshot().get("turn", 0))
	var proposal: Dictionary = await _brain.propose(_kernel.resident_view(), turn)
	_brain_busy = false
	if not proposal.get("ok", false):
		_brain_blocked = true
		return proposal
	_evidence["decision_runtime"] = "OpenGameAgent"
	_evidence["decision_source"] = proposal.provenance
	var applied: Dictionary = _kernel.submit_resident_decision(proposal.decision, proposal.command_id, proposal.provenance).duplicate(true)
	_evidence["last_decision_accepted"] = applied.get("ok", false)
	applied["_decision_reason"] = str(proposal.decision.get("reason", ""))
	return applied

func _try_player_help(automatic: bool) -> void:
	if _help_attempted or _phase != ResidentPhase.WAIT_FOR_HELP or not _need_submitted:
		return
	var near_well: bool = _player.global_position.distance_to(WELL_POSITION + Vector3(0.0, 1.0, 0.0)) < 3.0
	if not near_well:
		_update_status("请走近井边再按 E。")
		return
	_help_attempted = true
	var review: Dictionary = _kernel.gm_review_need("street-gm-review", "approve", "well_bucket", "玩家在井边提供绳与桶，满足已记录的取水需要。")
	_evidence["need_approval"] = review.duplicate(true)
	if not bool(review.get("ok", false)):
		_show_error("GM 审查未通过：" + str(review.get("code", "unknown")))
		return
	var manifest: Dictionary = _load_manifest()
	if manifest.is_empty():
		_show_error("缺少市场能力清单，安装已停止。")
		return
	var install: Dictionary = _kernel.gm_install(manifest, "street-gm-install", "street-gm-review")
	_evidence["need_install"] = install.duplicate(true)
	if bool(install.get("ok", false)):
		_spawn_hanging_bucket()
		_persist_world("install")
		_update_status("绳子和桶装好了，现在可以安全取水了。")
		_request_draw_after_install()
	else:
		_show_error("安装未完成：" + str(install.get("code", "unknown")))

func _load_or_create_world() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_path).get_base_dir())
	var locked: Dictionary = _kernel.acquire_writer(_save_path)
	if not locked.get("ok", false):
		_persistence_writable = false
		_show_error("这个测试存档已被另一个窗口占用。")
		return
	_owns_writer = true
	var load_result: Dictionary
	if FileAccess.file_exists(_save_path):
		_loaded_existing = true
		load_result = _kernel.load_from(_save_path)
		if not bool(load_result.get("ok", false)):
			_persistence_writable = false
			_world_error = "存档损坏或不受支持，已禁止写入：" + str(load_result.get("code", "unknown"))
			_show_error(_world_error)
			return
	else:
		var created: Dictionary = _kernel.create_fixture()
		if not bool(created.get("ok", false)):
			_persistence_writable = false
			_show_error("fixture 创建失败。")
			return
		_persist_world("fixture")

func _persist_world(reason: String) -> void:
	if not _persistence_writable:
		return
	var saved: Dictionary = _kernel.save_to(_save_path)
	if not bool(saved.get("ok", false)):
		_persistence_writable = false
		_show_error("世界保存失败，后续写入已停止：" + str(saved.get("code", "unknown")))
	else:
		_evidence["last_save_reason"] = reason

func _reconcile_loaded_world() -> void:
	var snapshot: Dictionary = _kernel.snapshot()
	_restore_start = snapshot.duplicate(true)
	var resident_state: Dictionary = snapshot.get("residents", {}).get("fixture:luna", {})
	var memory: Dictionary = resident_state.get("memory", {})
	var need: Variant = resident_state.get("needs", {}).get("capability_request", null)
	if _is_installed_wait_state():
		# A valid wait after GM installation is a stable continuation point.  It
		# must not be turned into a new decision merely because the capability is on.
		_waiting_after_decision = true
		_help_attempted = true
		_resident_at_well = true
		_phase = ResidentPhase.WAIT_FOR_HELP
		_resident.global_position = WELL_APPROACH
		_resident.set_walking(false)
		_resident.set_gesture("idle")
	elif int(memory.get("water_drunk", 0)) > 0:
		_phase = ResidentPhase.COMPLETE
		_resident.global_position = RESIDENT_SIDE
		_resident.set_gesture("drink")
	elif int(memory.get("water_drawn", 0)) > 0:
		_waiting_after_decision = str(memory.get("last_action", "")) == "wait"
		_phase = ResidentPhase.DRINKING if _waiting_after_decision else ResidentPhase.TO_SIDE
		_resident.global_position = RESIDENT_SIDE if _waiting_after_decision else WELL_APPROACH
		_resident.set_gesture("idle" if _waiting_after_decision else "carry")
	elif typeof(need) == TYPE_DICTIONARY:
		_need_submitted = true
		_phase = ResidentPhase.WAIT_FOR_HELP
		_resident_at_well = true
		_resident.global_position = WELL_APPROACH
		_resident.set_walking(false)
		_resident.set_gesture("idle")
	elif str(memory.get("last_action", "")) == "wait":
		_waiting_after_decision = true
		_phase = ResidentPhase.WAIT_FOR_HELP
		_resident.global_position = WELL_APPROACH
	elif _capability_enabled():
		_phase = ResidentPhase.TO_WELL
		_resident.global_position = RESIDENT_START
	if _capability_enabled():
		_spawn_hanging_bucket()

func _is_installed_wait_state() -> bool:
	var snapshot: Dictionary = _kernel.snapshot()
	var resident: Dictionary = snapshot.get("residents", {}).get("fixture:luna", {})
	var memory: Dictionary = resident.get("memory", {})
	var need: Variant = resident.get("needs", {}).get("capability_request", null)
	var inventory: Dictionary = resident.get("inventory", {})
	if not _capability_enabled() or str(memory.get("last_action", "")) != "wait":
		return false
	if int(memory.get("water_drawn", 0)) != 0 or int(memory.get("water_drunk", 0)) != 0 or int(inventory.get("water", 0)) != 0:
		return false
	if typeof(need) != TYPE_DICTIONARY or str(need.get("status", "")) != "fulfilled":
		return false
	var actions: Array = resident.get("actions", [])
	if actions.is_empty() or str(actions[actions.size() - 1].get("action", "")) != "wait":
		return false
	# In this street review and installation are one uninterrupted player event.
	# Its preceding need/wait must not masquerade as a response to installation.
	var review_turn := -1
	for event: Dictionary in snapshot.get("events", []):
		if event.get("type") == "gm_need_approved":
			review_turn = maxi(review_turn, int(event.get("turn", -1)))
	return review_turn >= 0 and int(actions[-1].get("turn", -1)) > review_turn and not _last_wait_receipt().is_empty()

func _last_wait_receipt() -> Dictionary:
	var snap: Dictionary = _kernel.snapshot()
	var resident: Dictionary = snap.get("residents", {}).get("fixture:luna", {})
	var actions: Array = resident.get("actions", [])
	if actions.is_empty() or actions[-1].get("action") != "wait":
		return {}
	for receipt: Dictionary in snap.get("receipts", {}).values():
		if receipt.get("code") == "resident_waited" and receipt.get("turn") == actions[-1].get("turn"):
			return receipt.duplicate(true)
	return {}

func _build_environment() -> void:
	_environment = WorldEnvironment.new()
	_environment.name = "StreetEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#6a91b4")
	sky_material.sky_horizon_color = Color("#d9c9a7")
	sky_material.ground_bottom_color = Color("#283332")
	sky_material.ground_horizon_color = Color("#aa9671")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = environment
	add_child(_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-53.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

func _build_ground_collision() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "FallbackGroundCollision"
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(200.0, 0.2, 200.0)
	collider.shape = shape
	collider.position.y = -0.12
	ground.add_child(collider)
	add_child(ground)

func _load_market_runtime() -> void:
	_market_root = Node3D.new()
	_market_root.name = "MarketGLTFRuntime"
	add_child(_market_root)
	if not FileAccess.file_exists(MARKET_GLB):
		_show_error("找不到市场 GLB：" + MARKET_GLB)
		_evidence["market_import_error"] = "asset_missing"
		return
	var file: FileAccess = FileAccess.open(MARKET_GLB, FileAccess.READ)
	if file == null:
		_show_error("市场 GLB 无法读取。")
		_evidence["market_import_error"] = "open_failed"
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var parse_error: Error = document.append_from_buffer(bytes, "", state)
	if parse_error != OK:
		_show_error("GLTFDocument 运行时解析失败：" + str(parse_error))
		_evidence["market_import_error"] = str(parse_error)
		return
	var instance: Node = document.generate_scene(state)
	if instance == null:
		_show_error("GLTFDocument 未生成场景。")
		_evidence["market_import_error"] = "generate_failed"
		return
	instance.name = "StartingTownMarketCraftV5"
	_market_root.add_child(instance)
	_market_loaded = true
	_hide_proxy_visuals_and_build_collision(instance, false)
	_evidence["market_import"] = {"loader": "GLTFDocument", "path": MARKET_GLB, "preserved_scale": true, "root_scale": str(instance.scale)}

func _hide_proxy_visuals_and_build_collision(node: Node, inherited_hidden: bool) -> void:
	var lower_name: String = str(node.name).to_lower()
	var is_proxy: bool = lower_name.contains("col_") or lower_name.contains("collision") or lower_name.contains("代理")
	var is_static_person: bool = lower_name.contains("visual_person")
	var hidden_visual: bool = inherited_hidden or is_proxy or is_static_person
	if hidden_visual:
		if node is GeometryInstance3D:
			var geometry: GeometryInstance3D = node
			geometry.visible = false
		if is_proxy and node is MeshInstance3D:
			var source: MeshInstance3D = node
			if source.mesh != null:
				var body: StaticBody3D = StaticBody3D.new()
				body.name = "GeneratedCollision_" + node.name
				var collision: CollisionShape3D = CollisionShape3D.new()
				collision.shape = source.mesh.create_trimesh_shape()
				body.add_child(collision)
				add_child(body)
				body.global_transform = source.global_transform
				_collision_count += 1
	for child: Node in node.get_children():
		_hide_proxy_visuals_and_build_collision(child, hidden_visual)

func _build_well() -> void:
	_well = Node3D.new()
	_well.name = "OpenMarketWell"
	_well.position = WELL_POSITION
	add_child(_well)
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 1.0
	base_mesh.bottom_radius = 1.15
	base_mesh.height = 0.95
	base.position.y = 0.475
	base.mesh = base_mesh
	base.material_override = _simple_material(Color("#7b6650"))
	_well.add_child(base)
	var rim: MeshInstance3D = MeshInstance3D.new()
	var rim_mesh: TorusMesh = TorusMesh.new()
	rim_mesh.inner_radius = 0.82
	rim_mesh.outer_radius = 1.0
	rim_mesh.rings = 12
	rim_mesh.ring_segments = 24
	rim.mesh = rim_mesh
	rim.position.y = 0.96
	rim.material_override = _simple_material(Color("#b18b5d"))
	_well.add_child(rim)
	var water: MeshInstance3D = MeshInstance3D.new()
	var water_mesh: CylinderMesh = CylinderMesh.new()
	water_mesh.top_radius = 0.78
	water_mesh.bottom_radius = 0.78
	water_mesh.height = 0.04
	water.mesh = water_mesh
	water.position.y = 0.78
	water.material_override = _simple_material(Color("#3a8da5"))
	_well.add_child(water)
	for offset: float in [-1.05, 1.05]:
		var post := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.14, 2.15, 0.14)
		post.mesh = shape
		post.position = Vector3(offset, 1.075, 0)
		post.material_override = _simple_material(Color("796046"))
		_well.add_child(post)
	var beam := MeshInstance3D.new()
	var beam_shape := BoxMesh.new()
	beam_shape.size = Vector3(2.4, 0.18, 0.18)
	beam.mesh = beam_shape
	beam.position.y = 2.1
	beam.material_override = _simple_material(Color("796046"))
	_well.add_child(beam)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.13
	shape.height = 0.95
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.475
	body.add_child(collision)
	_well.add_child(body)

func _spawn_hanging_bucket() -> void:
	if _hanging_bucket != null:
		return
	_hanging_bucket = Node3D.new()
	_hanging_bucket.name = "InstalledWellBucket"
	_hanging_bucket.position = WELL_POSITION + Vector3(0.0, 1.55, 0.0)
	add_child(_hanging_bucket)
	var bucket: MeshInstance3D = MeshInstance3D.new()
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = 0.2
	shape.bottom_radius = 0.15
	shape.height = 0.34
	bucket.mesh = shape
	bucket.position.y = -0.38
	bucket.material_override = _simple_material(Color("#b87735"))
	_hanging_bucket.add_child(bucket)
	var rope: MeshInstance3D = MeshInstance3D.new()
	var rope_mesh: CylinderMesh = CylinderMesh.new()
	rope_mesh.top_radius = 0.025
	rope_mesh.bottom_radius = 0.025
	rope_mesh.height = 1.1
	rope.mesh = rope_mesh
	rope.material_override = _simple_material(Color("#563d25"))
	_hanging_bucket.add_child(rope)

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "PlayerCapsule"
	_player.position = Vector3(4.0, 1.22, 7.0)
	add_child(_player)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	collider.shape = capsule
	_player.add_child(collider)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraYaw"
	_player.add_child(_camera_pivot)
	_camera_pitch = Node3D.new()
	_camera_pitch.name = "CameraPitch"
	_camera_pitch.position.y = 0.55
	_camera_pivot.add_child(_camera_pitch)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position = Vector3.ZERO
	_camera.current = true
	_camera.fov = 72.0
	_camera_pitch.add_child(_camera)
	_camera_pivot.rotation.y = 0.3
	_camera_pitch.rotation.x = -0.08

func _build_resident() -> void:
	_resident = RESIDENT_SCRIPT.new()
	_resident.name = "LunaResident"
	_resident.position = RESIDENT_START
	add_child(_resident)
	_last_resident_position = _resident.position

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SmallWorldHud"
	add_child(layer)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 22.0)
	_status_label.size = Vector2(get_viewport().get_visible_rect().size.x - 48.0, 86.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color("#f4ead7"))
	layer.add_child(_status_label)
	_status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	var label := Label.new()
	label.text = "起始之城 · 街角的井    |    " + ("预算网关决策 · 独立测试世界" if _brain_mode == "gateway" else "离线行为演示")
	label.position = Vector2(24, 112)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(label)
	_debug_label = Label.new()
	_debug_label.position = Vector2(24.0, 142.0)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color("#b9e2d0"))
	_debug_label.visible = false
	layer.add_child(_debug_label)
	_update_status("WASD 移动 · 点击后鼠标观察 · ESC 释放 · 井边 E 帮忙")

func _update_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _show_error(message: String) -> void:
	_world_error = message
	if _status_label != null:
		_status_label.text = "错误：" + message
		_status_label.add_theme_color_override("font_color", Color("#ff9d8e"))
	if _smoke_mode:
		var errors: Array = _evidence.get("errors", [])
		errors.append(message)
		_evidence["errors"] = errors

func _update_debug() -> void:
	if not _debug_visible or _debug_label == null:
		return
	var snap: Dictionary = _kernel.snapshot()
	_debug_label.text = "F8 debug | phase=%s resident=(%.1f, %.1f, %.1f) collisions=%d gltf=%s save=%s" % [ResidentPhase.keys()[_phase], _resident.position.x, _resident.position.y, _resident.position.z, _collision_count, str(_market_loaded), _save_path]

func _capability_enabled() -> bool:
	var snap: Dictionary = _kernel.snapshot()
	var plugins: Dictionary = snap.get("plugins", {})
	var plugin: Dictionary = plugins.get("well_bucket", {})
	return str(plugin.get("status", "")) == "enabled"

func _water_drawn() -> int:
	var resident_state: Dictionary = _kernel.snapshot().get("residents", {}).get("fixture:luna", {})
	return int(resident_state.get("memory", {}).get("water_drawn", 0))

func _water_consumed() -> int:
	var resident_state: Dictionary = _kernel.snapshot().get("residents", {}).get("fixture:luna", {})
	return int(resident_state.get("memory", {}).get("water_drunk", 0))

func _has_event(event_type: String) -> bool:
	var events: Array = _kernel.snapshot().get("events", [])
	for event_value: Variant in events:
		if typeof(event_value) == TYPE_DICTIONARY and str(event_value.get("type", "")) == event_type:
			return true
	return false

func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data

func _parse_command_line() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--street-smoke="):
			_smoke_dir = argument.trim_prefix("--street-smoke=")
			_smoke_mode = not _smoke_dir.is_empty()
		elif argument.begins_with("--brain-mode="):
			_brain_mode = argument.trim_prefix("--brain-mode=")
		elif argument.begins_with("--street-expect="):
			_street_expect = argument.trim_prefix("--street-expect=")
		elif argument.begins_with("--save-path="):
			_save_path = argument.trim_prefix("--save-path=")
	if _smoke_mode:
		DirAccess.make_dir_recursive_absolute(_smoke_dir)
		_evidence = {"automatic_acceptance": true, "errors": [], "save_path": _save_path, "restored": false, "restored_without_repeat": false, "brain_mode": _brain_mode, "street_expect": _street_expect}

func _run_smoke_step() -> void:
	if _smoke_stage == 99:
		_smoke_player_target = Vector3(-2.5, 1.13, 8.0)
		if _player.global_position.distance_to(_smoke_player_target) > 0.25:
			return
		if _street_expect == "resume-stable" and (_resume_stable_started < 0.0 or _elapsed - _resume_stable_started < 5.0):
			return
		await _capture_smoke("restored")
		_finish_smoke(0)
		return
	if _world_error != "":
		await _capture_smoke("approach")
		_smoke_stage = 98
		_finish_smoke(1)
		return
	if _street_expect == "model-first" and _resident_at_well and _decision_requests == 1 and not _brain_busy:
		await _capture_smoke("model-choice")
		_finish_smoke(0)
		return
	if _smoke_stage == 0:
		await _capture_smoke("approach")
		_smoke_stage = 1
	elif _smoke_stage == 1 and _resident_at_well and _need_submitted and not _brain_busy:
		await _capture_smoke("need")
		_smoke_stage = 2
	elif _smoke_stage == 2:
		if _player.global_position.distance_to(_smoke_player_target) < 0.25:
			if _street_expect == "unassisted":
				if _elapsed >= 8.0:
					_evidence["unassisted_deadline_seconds"] = _elapsed
					await _capture_smoke("unassisted")
					_smoke_stage = 100
					_finish_smoke(0)
			else:
				_try_player_help(true)
				if _help_attempted:
					_smoke_stage = 3
	elif _smoke_stage == 3:
		if _street_expect == "model-assisted" and _deferred_wait_started >= 0.0 and _elapsed - _deferred_wait_started >= 3.0:
			_evidence["waited_before_draw"] = true
			_evidence["wait_seconds"] = _elapsed - _deferred_wait_started
			_evidence["wait_stable"] = _decision_requests == _wait_request_count
			await _capture_smoke("waited-before-draw")
			_smoke_stage = 100
			_finish_smoke(0)
		elif _street_expect != "deferred" and _water_drawn() > 0:
			await _capture_smoke("draw")
			_smoke_stage = 4
		elif _street_expect == "deferred" and _deferred_wait_started >= 0.0 and _elapsed - _deferred_wait_started >= 3.0:
			_evidence["deferred_wait_stable"] = _decision_requests == _wait_request_count
			_evidence["deferred_wait_seconds"] = _elapsed - _deferred_wait_started
			await _capture_smoke("deferred")
			_smoke_stage = 100
			_finish_smoke(0)
	elif _smoke_stage == 4 and _street_expect == "model-assisted" and _waiting_after_decision and _deferred_wait_started >= 0.0 and _elapsed - _deferred_wait_started >= 3.0:
		_evidence["waited_with_water"] = true
		_evidence["wait_seconds"] = _elapsed - _deferred_wait_started
		_evidence["wait_stable"] = _decision_requests == _wait_request_count
		await _capture_smoke("waited-with-water")
		_smoke_stage = 100
		_finish_smoke(0)
	elif _smoke_stage == 4 and _phase == ResidentPhase.COMPLETE:
		_smoke_player_target = Vector3(-2.5, 1.13, 8.0)
		if _player.global_position.distance_to(_smoke_player_target) > 0.25:
			return
		await _capture_smoke("complete")
		_smoke_stage = 100
		_finish_smoke(0)

func _capture_smoke(label: String) -> void:
	await RenderingServer.frame_post_draw
	if _smoke_dir.is_empty():
		return
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_smoke_dir.path_join(label + ".png"))
	_evidence["screenshot_" + label] = label + ".png"

func _finish_smoke(exit_code: int) -> void:
	set_process(false)
	set_physics_process(false)
	var snap: Dictionary = _kernel.snapshot()
	_evidence["used"] = _water_consumed() > 0
	var water: int = int(snap.get("world", {}).get("well_water", -1))
	var carried: int = int(snap.get("residents", {}).get("fixture:luna", {}).get("inventory", {}).get("water", -1))
	var checks: Dictionary = {"3d_root": self is Node3D, "camera": _camera != null and _camera.current, "market_imported": _market_loaded, "collision_proxies": _collision_count >= 20, "need": _has_event("resident_need_recorded"), "no_errors": _world_error.is_empty()}
	if _street_expect == "model-first":
		checks.erase("need")
		checks["one_decision"] = _decision_requests == 1
		checks["accepted_choice"] = _evidence.get("last_decision_accepted", false)
		checks["water_conserved"] = water + carried + _water_consumed() == 1
	elif _street_expect == "model-assisted":
		checks["approved"] = _has_event("gm_need_approved")
		checks["installed"] = _capability_enabled()
		checks["accepted_choice"] = _evidence.get("last_decision_accepted", false)
		checks["water_conserved"] = water >= 0 and carried >= 0 and water + carried + _water_consumed() == 1
		checks["one_install"] = snap.get("install_history", {}).size() == 1 and snap.get("install_history", {}).has("well_bucket") and snap.world.gm_resources == {"rope": 0, "bucket": 0}
		checks["decision_limit"] = _decision_requests >= 1 and _decision_requests <= 2
		checks["valid_outcome"] = (_evidence.get("used", false) and _water_consumed() == 1) or _evidence.get("waited_before_draw", false) or _evidence.get("waited_with_water", false)
		if _waiting_after_decision:
			checks["wait_stable"] = _evidence.get("wait_stable", false) and _evidence.get("wait_seconds", 0.0) >= 3.0
			checks["no_consumption_while_waiting"] = _water_consumed() == 0 and _phase != ResidentPhase.COMPLETE
		if _loaded_existing:
			checks["identity_preserved"] = _same_identity_prefix(_restore_start, snap)
			checks["history_prefix_preserved"] = _same_history_prefix(_restore_start, snap)
	elif _street_expect == "deferred":
		checks["approved"] = _has_event("gm_need_approved")
		checks["installed"] = _capability_enabled()
		checks["valid_wait"] = _evidence.get("wait_receipt", {}).get("code", "") == "resident_waited"
		checks["no_water_drawn"] = _water_drawn() == 0 and not _has_event("water_drawn")
		checks["no_water_consumed"] = _water_consumed() == 0 and not _has_event("water_consumed")
		checks["water_conserved"] = water >= 0 and carried >= 0 and water + carried + _water_consumed() == 1
		checks["no_repeat_decision"] = _evidence.get("deferred_wait_stable", false) or (_loaded_existing and _decision_requests == 0)
		checks["restored_wait"] = not _loaded_existing or (_evidence.get("restored_deferred_wait", false) and _restore_start == snap)
	elif _street_expect == "unassisted":
		checks["not_installed"] = not _capability_enabled()
		checks["water_conserved"] = water >= 0 and carried >= 0 and water + carried + _water_consumed() == 1
	elif _street_expect == "resume-stable":
		checks.erase("need")
		checks["restored_stable"] = _loaded_existing and _evidence.get("resume_state", "") in ["wait", "complete"]
		checks["zero_new_decisions"] = _decision_requests == 0
		checks["facts_unchanged"] = snap == _restore_start
	else:
		checks["approved"] = _has_event("gm_need_approved")
		checks["installed"] = _capability_enabled()
		checks["actual_use"] = _has_event("water_drawn") and _has_event("water_consumed")
		checks["water_conserved"] = water >= 0 and carried >= 0 and water + carried + _water_consumed() == 1
		checks["one_consumption"] = _water_consumed() == 1
	if _street_expect == "unassisted":
		checks["no_player_help"] = not _help_attempted
		checks["need_remains_open"] = _need_is_open()
		checks["gm_resources_unchanged"] = _gm_resources_match_fixture()
		checks["no_consumption"] = _water_consumed() == 0 and not _has_event("water_consumed")
		checks["no_repeat_decision"] = _decision_requests == (0 if _loaded_existing else 1)
	if _loaded_existing:
		if _street_expect != "model-assisted":
			checks["unchanged_restored_facts"] = snap == _restore_start
	else:
		checks["resident_walked"] = _route_distance > 5.0
		checks["arrived_before_transfer"] = _evidence.get("arrived_before_water", false)
	for passed: Variant in checks.values():
		if not passed: exit_code = 1
	_evidence["checks"] = checks
	_evidence["passed"] = exit_code == 0
	_evidence["route_distance_m"] = _route_distance
	_evidence["collision_count"] = _collision_count
	_evidence["water"] = {"well": water, "inventory": carried, "consumed": _water_consumed()}
	_evidence["world_id"] = snap.get("world_id", "")
	_evidence["events"] = snap.get("events", [])
	_evidence["resident_position"] = [_resident.position.x, _resident.position.y, _resident.position.z]
	_evidence["player_position"] = [_player.position.x, _player.position.y, _player.position.z]
	_evidence["errors"] = [_world_error] if not _world_error.is_empty() else []
	if _street_expect == "model-assisted" and not _evidence.get("waited_before_draw", false):
		_evidence["waited_with_water"] = _evidence.get("waited_with_water", false)
	var file: FileAccess = FileAccess.open(_smoke_dir.path_join("evidence.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_evidence, "  "))
		file.close()
	print(JSON.stringify({"street_3d_passed": exit_code == 0, "checks": checks}))
	get_tree().quit(exit_code)

func _need_is_open() -> bool:
	var resident: Dictionary = _kernel.snapshot().get("residents", {}).get("fixture:luna", {})
	var need: Variant = resident.get("needs", {}).get("capability_request", null)
	return typeof(need) == TYPE_DICTIONARY and str(need.get("status", "")) == "open"

func _gm_resources_match_fixture() -> bool:
	var resources: Dictionary = _kernel.snapshot().get("world", {}).get("gm_resources", {})
	return int(resources.get("rope", -1)) == 1 and int(resources.get("bucket", -1)) == 1

func _count_events(event_type: String) -> int:
	var count := 0
	for event: Dictionary in _kernel.snapshot().get("events", []):
		if str(event.get("type", "")) == event_type:
			count += 1
	return count

func _same_identity_prefix(before: Dictionary, after: Dictionary) -> bool:
	return before.get("world_id", "") == after.get("world_id", "") and before.get("residents", {}).get("fixture:luna", {}).get("identity", {}) == after.get("residents", {}).get("fixture:luna", {}).get("identity", {})

func _same_history_prefix(before: Dictionary, after: Dictionary) -> bool:
	var old_resident: Dictionary = before.get("residents", {}).get("fixture:luna", {})
	var new_resident: Dictionary = after.get("residents", {}).get("fixture:luna", {})
	var old_actions: Array = old_resident.get("actions", [])
	var new_actions: Array = new_resident.get("actions", [])
	var old_events: Array = before.get("events", [])
	var new_events: Array = after.get("events", [])
	return new_actions.size() >= old_actions.size() and new_actions.slice(0, old_actions.size()) == old_actions and new_events.size() >= old_events.size() and new_events.slice(0, old_events.size()) == old_events

func _exit_tree() -> void:
	if _owns_writer:
		_kernel.release_writer(_save_path)

func _simple_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
