extends "res://spatial/street_trial.gd"
## The same market/player scene, using the continuation module instead of Luna's fixture.
##
## Merge note: this scene combines the Mac art/legacy-repair branch with the Windows
## canonical functional roadmap. Legacy Mac repair execution (hand-axe HUD, R shortcut,
## _request_edge_repair, _progress_repair, repair route auto-movement) is supported ONLY
## in clearly labelled offline/local_rule_policy mode and is never executed in
## gateway_mode or restore_only.

# The playable world class: the public places runtime plus the bounded public baking route
# (one reviewed finite-flour baking point, personal line-of-sight knowledge only).
const Town = preload("res://core/town_baking.gd")
const TownTurns = preload("res://agents/town_turns.gd")
const TownTools = preload("res://spatial/town_tools.gd")
const TownNameplates = preload("res://spatial/town_nameplates.gd")
const MaterialSources = preload("res://spatial/town_material_sources.gd")
const MaterialVisibility = preload("res://spatial/town_material_visibility.gd")
const MaterialSteering = preload("res://spatial/town_material_steering.gd")
const BakingPoints = preload("res://spatial/town_baking_points.gd")
const ForagingLayout = preload("res://spatial/town_foraging_layout.gd")
const ForagingSteering = preload("res://spatial/town_foraging_steering.gd")
const SocialSteering = preload("res://spatial/town_social_steering.gd")
const TownExpansion = preload("res://spatial/town_expansion.gd")
const PlaceNotice = preload("res://spatial/town_place_notice.gd")
const PlaceSteering = preload("res://spatial/town_place_steering.gd")
const TownNavigation = preload("res://spatial/town_navigation.gd")
var town := Town.new()
var actors: Dictionary = {}
var bodies: Dictionary = {}
var cards: Dictionary = {}
var paused := true
var tick := 0.0
var capture_dir := ""
var capture_age := 0.0
var capture_started := false
var status: Label
var berry_visuals: Array[Node3D] = []
var latest := "世界已暂停。按空格继续；原事件与钱物已经载入。"
var dialogue: Label
var dialogue_input: LineEdit
var life_roster: Label
var life_feed: Label
var life_panel: PanelContainer
var session_start_life_seq := -1
var session_start_request_ids: Dictionary = {}
var dialogue_target := ""
var last_public_reply_seq := -1
var last_inquiry_seconds := -10.0
var dialogue_fixture := false
var fixture_inquiry_text := "这里有什么需要我帮忙的吗？"
var dialogue_fixture_done := false
var dialogue_resident_id := ""
var model_turns: Node
var gateway_mode := false
var last_model_note := ""
var capture_seconds := 90.0
var scripted_trade := false
var restore_only := false
var stop_on_idle := false # Bounded validation only, never normal gameplay.
var stop_on_decision_limit := false # Keep legitimate idle time; stop only after the cap's in-flight model turn returns.
var validation_decision_limit := -1
var validation_decisions_started := 0
## Bounded gateway-episode shutdown. When the episode duration expires, admission
## to NEW resident decisions closes, then the host awaits the already-started
## replies and their authoritative application before it persists and exits. The
## wait is finite: an owed reply is reported honestly instead of holding the
## engine until the launcher's own timeout kills it. --town-shutdown-wait sets the
## bound, and the launcher budgets the same single value for the engine.
var shutdown_wait_limit := 45.0
var capture_shutdown_reason := ""
var shutdown_exit_code := 0
# Legacy Mac repair demo state (offline/local_rule_policy only).
var repair_fixture := false
var town_tools: Node = null
var repair_fixture_started := false
var repair_fixture_finished_at := -1.0
var repair_initial_money := -1
var repair_initial_iron := -1
var nameplates: Node = null
var material_visibility: Node3D = null
var material_steering: RefCounted = null
var baking_visibility: Node3D = null
var town_expansion_evidence: Dictionary = {}
var foraging_steering: RefCounted = null
var social_steering: RefCounted = null
var place_notice: Node3D = null
var place_steering: RefCounted = null
var town_navigation: Node3D = null
var place_notice_evidence: Dictionary = {}
var foraging_layout_status: Dictionary = {}
var _foraging_layout_attempted := false
var _spaced_foraging := false
var _foraging_exit_targets: Dictionary = {}
var gm_export_path := ""
var gm_export_status := ""

func _ready() -> void:
	restore_only = OS.get_cmdline_user_args().has("--town-restore")
	stop_on_idle = OS.get_cmdline_user_args().has("--town-stop-on-idle")
	stop_on_decision_limit = OS.get_cmdline_user_args().has("--town-stop-on-decision-limit")
	for arg in OS.get_cmdline_user_args():
		if arg == "--town-gateway":
			gateway_mode = true
		if arg.begins_with("--town-duration="):
			capture_seconds = clampf(float(arg.trim_prefix("--town-duration=")), 3, 900)
		if arg.begins_with("--town-max-decisions="):
			var count_text := arg.trim_prefix("--town-max-decisions=")
			if not count_text.is_valid_int() or int(count_text) < 0 or int(count_text) > 32:
				push_error("Invalid bounded validation decision limit")
				get_tree().quit(2)
				return
			validation_decision_limit = int(count_text)
		if arg.begins_with("--town-shutdown-wait="):
			var wait_text := arg.trim_prefix("--town-shutdown-wait=")
			if not wait_text.is_valid_float() or float(wait_text) < 0.0 or float(wait_text) > 120.0:
				push_error("Invalid bounded episode shutdown wait")
				get_tree().quit(2)
				return
			shutdown_wait_limit = float(wait_text)
		if arg == "--town-dialogue-fixture":
			dialogue_fixture = true
		if arg.begins_with("--town-inquire-text="):
			fixture_inquiry_text = arg.trim_prefix("--town-inquire-text=")
			if fixture_inquiry_text.strip_edges().is_empty() or fixture_inquiry_text.length() > 512:
				push_error("Scripted inquiry must contain 1..512 characters")
				get_tree().quit(2)
				return
		if arg.begins_with("--town-inquire-resident="):
			dialogue_resident_id = arg.trim_prefix("--town-inquire-resident=")
		if arg == "--town-repair-fixture":
			repair_fixture = true
		if arg.begins_with("--town-save="):
			_save_path = arg.trim_prefix("--town-save=")
		if arg.begins_with("--town-capture="):
			capture_dir = arg.trim_prefix("--town-capture=")
		if arg.begins_with("--town-gm-export="):
			gm_export_path = arg.trim_prefix("--town-gm-export=")
			if gm_export_path.strip_edges().is_empty():
				push_error("--town-gm-export requires a path")
				get_tree().quit(2)
				return
	# The legacy Mac repair demo is an offline/local_rule_policy path only. It must
	# never run in gateway_mode or restore_only, and incompatible startup is rejected
	# before any world mutation.
	if repair_fixture and (gateway_mode or restore_only):
		push_error("--town-repair-fixture is incompatible with --town-gateway/--town-restore")
		get_tree().quit(2)
		return
	if _save_path == DEFAULT_SAVE_PATH:
		push_error("Town mode requires an explicit separately migrated --town-save path")
		get_tree().quit(2)
		return
	var loaded := town.load_from(_save_path)
	if not loaded.ok:
		push_error(JSON.stringify(loaded))
		get_tree().quit(2)
		return
	var startup_snapshot: Dictionary = town.snapshot()
	session_start_life_seq = int(startup_snapshot.life.get("seq", -1))
	for startup_id in town.active_ids():
		var startup_turn: Variant = startup_snapshot.godot.get("resident_turns", {}).get(startup_id, {})
		if startup_turn is Dictionary:
			session_start_request_ids[startup_id] = str(startup_turn.get("request_id", ""))
	if not dialogue_resident_id.is_empty() and dialogue_resident_id not in town.active_ids():
		push_error("Scripted inquiry target is not an active resident: " + dialogue_resident_id)
		get_tree().quit(2)
		return
	var lock := town.acquire_writer(_save_path)
	if not lock.ok:
		push_error(JSON.stringify(lock))
		get_tree().quit(2)
		return
	_owns_writer = true
	_kernel = town
	_build_environment()
	_build_ground_collision()
	_load_market_runtime()
	if not _market_loaded:
		push_error("Market asset import is missing; town simulation has not started")
		get_tree().quit(2)
		return
	# Mac environment dressing runs only after a successful market load.
	_load_floor1_environment_dressing()
	_load_town_expansion()
	town_navigation = TownNavigation.new()
	town_navigation.name = "TownNavigation"
	add_child(town_navigation)
	_configure_navigation()
	town_navigation.build()
	_build_player()
	_player.position = Vector3(0, 1.22, 12)
	_camera_pivot.rotation.y = 0
	_camera_pitch.rotation.x = -0.05
	_sync_residents()
	_build_berry_patch()
	var tools := TownTools.new()
	add_child(tools)
	tools.configure(town, actors)
	town_tools = tools
	var material_sources := MaterialSources.new()
	add_child(material_sources)
	material_sources.configure(town)
	# Bind real line-of-sight sensing for the actual town street BEFORE any tick
	# or model decision, in every mode (offline, gateway, restore).
	material_visibility = MaterialVisibility.new()
	add_child(material_visibility)
	material_visibility.configure(town, bodies, material_sources)
	material_steering = MaterialSteering.new()
	foraging_steering = ForagingSteering.new()
	social_steering = SocialSteering.new()
	place_steering = PlaceSteering.new()
	town.require_material_visibility(Callable(material_visibility, "can_observe"))
	# The public baking point's own oven/flour visual is the LOS target of the same reviewed
	# physics component, bound BEFORE any tick or model decision in every mode, so a resident can
	# only ever learn a point its own sight really reaches.
	var baking_points := BakingPoints.new()
	add_child(baking_points)
	baking_points.configure(town)
	baking_visibility = MaterialVisibility.new()
	add_child(baking_visibility)
	baking_visibility.configure(town, bodies, baking_points)
	if town.has_method("require_baking_visibility"):
		town.require_baking_visibility(Callable(baking_visibility, "can_observe"))
	# The public wayfinding notice is one real prop with real line-of-sight sensing. It only
	# answers "can this resident read/see it"; the world grants and persists the knowledge.
	_load_public_notice()
	_build_town_hud()
	_build_nameplates()
	if gateway_mode:
		model_turns = TownTurns.new()
		add_child(model_turns)
		model_turns.configure(town, _save_path)
		model_turns.shutdown_wait_limit = shutdown_wait_limit
	# One explicit, bounded evidence snapshot for a separate GM process. No daemon and
	# no loop; nothing from this export enters a resident model context. The startup
	# result is not ignored: a failed configured export shows on the host status line.
	if not gm_export_path.is_empty():
		write_gm_evidence_export()
	_refresh_public_dialogue(town.snapshot().life.events, true)
	_refresh()
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		paused = restore_only
		if not restore_only:
			latest = "生活继续；时间只在运行时流逝"
		_refresh()
		_camera.global_position = Vector3(0.0, 5.0, 14.0)
		_camera.look_at(Vector3(0, 0.9, 4.0))
		if dialogue_fixture or (restore_only and not dialogue_resident_id.is_empty()):
			var fixture_id: String = dialogue_resident_id if not dialogue_resident_id.is_empty() else town.active_ids()[1]
			_player.position = town.position_of(fixture_id) + Vector3(0, 0.9, 1.5)
			_camera.global_position = _player.position + Vector3(-2, 1.6, 2)
			_camera.look_at(town.position_of(fixture_id) + Vector3(0, 1.1, 0))
		elif repair_fixture:
			var candidate := town.repair_candidate("edge")
			if not candidate.is_empty():
				_player.position = town.position_of(candidate.owner_id) + Vector3(0, 0.9, 1.5)
				_camera.global_position = Vector3(0, 5.2, 13.0)
				_camera.look_at(town.home_point(candidate.worker_id) + Vector3(0, 1.0, 0))

func _configure_navigation() -> void:
	pass

func _sync_residents() -> void:
	var palette := [Color("954f42"), Color("345f79"), Color("657448")]
	for id in town.active_ids():
		if actors.has(id):
			continue
		var index := actors.size()
		var body := CharacterBody3D.new()
		body.name = "ResidentBody%d" % index
		add_child(body)
		body.position = town.position_of(id)
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.5
		collider.shape = shape
		collider.position.y = 0.75
		body.add_child(collider)
		var actor: Node3D = RESIDENT_SCRIPT.new()
		actor.shirt_color = palette[index % palette.size()]
		actor.hair_color = [Color("563827"), Color("302d2a"), Color("766953")][index % 3]
		body.add_child(actor)
		actor.get_node("OriginalResidentBody/Torso").material_override = _simple_material(palette[index % palette.size()])
		actors[id] = actor
		bodies[id] = body
		if town_navigation != null:
			town_navigation.register_body(id, body)
		var title := Label3D.new()
		title.position.y = 2.05
		title.font_size = 38
		title.outline_size = 8
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.modulate = Color("f5e6c8")
		body.add_child(title)
		cards[id] = title
		## Home/work marker only: the fixed saved home, never a resident's transient public rest.
		_work_marker(town.home_point(id), str(town.resident(id).name) + " · 工作点")
		if gateway_mode and model_turns != null:
			model_turns.ensure_brain(id)

func admit_resident(person: Dictionary, maintainer: String, point: Vector3, command: String) -> Dictionary:
	var admitted := town.transaction(_save_path, func(): return town.admit_resident(person, maintainer, point, command))
	if admitted.ok:
		_sync_residents()
		_refresh()
	return admitted

func _ensure_foraging_layout() -> bool:
	if _foraging_layout_attempted:
		return bool(foraging_layout_status.get("ok", true))
	_foraging_layout_attempted = true
	var snap := town.snapshot()
	if snap.godot.has("foraging_work_spots"):
		_spaced_foraging = true
		town.require_foraging_access(Callable(self, "_foraging_can_work"))
		foraging_layout_status = {"ok": true, "code": "foraging_layout_restored"}
		return true
	var independent: bool = not str(snap.world_id).begins_with("fixture:") and (bool(snap.godot.get("new_world_seed", false)) or str(snap.get("origin", {}).get("kind", "")) == "new_world_seed")
	if restore_only or not independent or town.active_ids().size() != 10:
		foraging_layout_status = {"ok": true, "code": "foraging_layout_not_applicable"}
		return true
	var exclude: Array[RID] = [_player.get_rid()]
	foraging_layout_status = ForagingLayout.new().build(town, bodies, get_world_3d().direct_space_state, exclude)
	if foraging_layout_status.get("ok", false):
		var spots: Dictionary = foraging_layout_status.spots
		var installed := town.transaction(_save_path, func():
			return town.configure_foraging_work_spots(spots, "development_gm:foraging-layout:v1"))
		foraging_layout_status["installation"] = installed
		foraging_layout_status["ok"] = installed.get("ok", false)
		_spaced_foraging = bool(installed.get("ok", false))
		if _spaced_foraging:
			town.require_foraging_access(Callable(self, "_foraging_can_work"))
	if not _spaced_foraging:
		paused = true
		latest = "采集工作点未通过物理检查，生活已暂停：" + str(foraging_layout_status.get("code", "invalid_layout"))
		_refresh()
	return _spaced_foraging

func _foraging_can_work(id: String) -> bool:
	var exclude: Array[RID] = [_player.get_rid()]
	return ForagingLayout.new().can_work(town, bodies, get_world_3d().direct_space_state, id, exclude)

func _foraging_idle_exit(id: String, body: CharacterBody3D) -> Vector3:
	if _foraging_exit_targets.has(id):
		var prior: Vector3 = _foraging_exit_targets[id]
		if body.position.distance_to(prior) > 0.30:
			return prior
		_foraging_exit_targets.erase(id)
	var center: Vector3 = town.berry_center()
	var outward := body.position - center
	outward.y = 0.0
	if outward.length() > 2.35:
		return Vector3.INF
	if outward.length() < 0.1:
		outward = town.destination(id, "harvest_ration") - center
		outward.y = 0.0
	if outward.length() < 0.1:
		return Vector3.INF
	var point := center + outward.normalized() * 2.7
	point.y = body.position.y
	_foraging_exit_targets[id] = point
	return point

func _process(delta: float) -> void:
	if status == null:
		return
	var capture_timeout := 150.0 if (repair_fixture and not gateway_mode and not restore_only) else (3.0 if paused else capture_seconds)
	# The episode's own duration boundary is decided BEFORE any new resident is
	# chosen, and on the same elapsed+delta value the capture below uses. A resident
	# that becomes ready exactly on the boundary frame is therefore never admitted
	# into an episode that has already expired.
	if not capture_dir.is_empty() and not capture_started and gateway_mode and model_turns != null \
			and capture_age + delta > capture_timeout and _owns_shutdown_gate():
		model_turns.close_admission("episode_duration_elapsed")
	if gateway_mode and model_turns != null and not paused and not _validation_limit_reached() and not _model_admission_closed():
		var ready: String = model_turns.ready_resident()
		if not ready.is_empty():
			_run_model_turn(ready)
	if not capture_dir.is_empty():
		capture_age += delta
		if dialogue_fixture and capture_age > 1.0 and not dialogue_fixture_done:
			dialogue_fixture_done = true
			_inquire_nearby(true)
		# Legacy Mac repair demo: offline/local_rule_policy only.
		if repair_fixture and not gateway_mode and not restore_only and capture_age > 0.1 and not repair_fixture_started:
			repair_fixture_started = true
			_request_edge_repair(true)
		if repair_fixture and not gateway_mode and not restore_only and repair_fixture_started and not _has_active_repair() and town.repair_candidate("edge").is_empty() and repair_fixture_finished_at < 0:
			repair_fixture_finished_at = capture_age
		# Unlike stop-on-idle, this boundary deliberately does not wait for physical
		# jobs. Their accepted command IDs, targets and progress already live in the
		# save and must cold-continue. Only the model coroutine may still own an
		# unsettled provider/accounting/world transaction, so wait for busy=false.
		if _decision_limit_capture_ready():
			_close_admission_for_capture("validation_decision_limit")
			_begin_capture("decision_limit")
		if stop_on_idle and gateway_mode and not restore_only and capture_age > 8.0 and not capture_started and not model_turns.busy and (_validation_limit_reached() or model_turns.ready_resident().is_empty()):
			var idle := true
			for id in town.active_ids():
				if not town.pending_job(id).is_empty():
					idle = false
			if idle:
				_close_admission_for_capture("idle_world")
				_begin_capture("idle_world")
		if not capture_started and repair_fixture and not gateway_mode and not restore_only and repair_fixture_finished_at >= 0 and capture_age - repair_fixture_finished_at > 1.5:
			_begin_capture("repair_fixture_settled")
		if not capture_started and capture_age > capture_timeout:
			# The episode's own duration expired. In a gateway episode this is the
			# ordered shutdown: stop admitting NEW resident decisions, await the
			# already-started replies and their authoritative application within a
			# finite bound, persist/capture, exit the engine - and only then does the
			# launcher drain its gateway. A request this engine already accepted is
			# never abandoned for the drain to settle into a save nobody owns.
			if not gateway_mode or model_turns == null or not _owns_shutdown_gate():
				# A lightweight host adapter that owns no shutdown gate keeps the
				# unchanged bounded-episode behavior: it stops as soon as it reports
				# no turn in flight.
				if model_turns != null and model_turns.busy:
					pass
				else:
					_begin_capture("duration_elapsed")
			else:
				model_turns.close_admission("episode_duration_elapsed")
				var readiness: Dictionary = model_turns.shutdown_readiness(delta)
				if readiness.ready:
					_begin_capture("episode_duration_elapsed_unresolved" if readiness.timed_out else "episode_duration_elapsed")

func _owns_shutdown_gate() -> bool:
	## The bounded shutdown protocol lives on the turn module that owns the requests.
	## A lighter host controller keeps its existing behavior instead of failing here.
	return model_turns != null and model_turns.has_method("admission_closed") \
		and model_turns.has_method("close_admission") and model_turns.has_method("shutdown_readiness") \
		and model_turns.has_method("shutdown_evidence")

func _model_admission_closed() -> bool:
	return _owns_shutdown_gate() and model_turns.admission_closed()

func _close_admission_for_capture(reason: String) -> void:
	## Every bounded capture closes admission first, so the shutdown evidence states
	## the truth for a decision-limit or idle stop too: nothing may be admitted after
	## the episode decided to stop. Physical jobs are untouched.
	if gateway_mode and _owns_shutdown_gate():
		model_turns.close_admission(reason)

func _begin_capture(reason: String) -> void:
	if capture_started:
		return
	capture_started = true
	capture_shutdown_reason = reason
	# Honest engine status: an episode that ends with a reply still owed is not a
	# clean stop. The record keeps the status it really has, so a later start can
	# reconcile that request instead of reading a fabricated success.
	shutdown_exit_code = 3 if (_owns_shutdown_gate() and model_turns.shutdown_wait_timed_out) else 0
	_capture_town.call_deferred()

func _physics_process(delta: float) -> void:
	if status == null:
		return
	if capture_dir.is_empty() and not _composing_dialogue():
		super._physics_process(delta)
	town.host_visitor_position(_player.position)
	if paused:
		return
	if not _ensure_foraging_layout():
		return
	if material_steering != null:
		material_steering.retain_active(town.active_ids())
	if foraging_steering != null:
		foraging_steering.retain_active(town.active_ids())
	if social_steering != null:
		social_steering.retain_active(town.active_ids())
	if place_steering != null:
		place_steering.retain_active(town.active_ids())
	for id in town.active_ids():
		var job: Dictionary = town.pending_job(id)
		var body: CharacterBody3D = bodies[id]
		var actor: Node3D = actors[id]
		var moving := false
		if not job.is_empty():
			_foraging_exit_targets.erase(id)
			var target := town.destination(id, job.action)
			var direction := Vector3.ZERO
			## The navmesh route is authoritative only while it really reaches THIS journey's target.
			## The bake has a measured gap across the market/field junction (cell_size 0.10 with
			## agent_max_climb 0.04): from the market floor the server returns a partial path, the
			## helper calls the trip unreachable and used to leave the body standing still while the
			## world's own stall rule counted zero movement and closed the accepted journey as
			## travel_blocked. A route that does not reach the target - or a map that is not baked
			## yet - now falls back to the same road-graph steering the place trips, place-bound
			## rests and home trips already use. The destination, the 0.45 m arrival gate, the job
			## timers and every collider stay exactly the world's own.
			var nav_reaches_target := false
			if town_navigation != null:
				direction = town_navigation.direction_for(id, str(job.command_id), body, target)
				nav_reaches_target = town_navigation.enabled and not town_navigation.is_unreachable(id)
			## A public-place trip (and its place-bound rest) keeps the accepted place steering.
			var place_trip: bool = job.action == "travel" or (job.action == "rest" and job.has("place_id"))
			## The public bake trip walks to its own baking point over the same verified road graph
			## the place trips and home trips use; the destination, the world's own 0.45 m arrival
			## gate and the job's timers stay exactly the world's.
			var bake_trip: bool = job.action == "bake_bread"
			## Basic-life travel to the resident's own fixed point: eat_ration, harvest_ration, and
			## rest with no public place target. With the spaced-foraging layout installed those
			## bodies walk the lower field, where the straight local push stops at the market
			## floor's south lip (a vertical step outside the junction ramp) and the accepted job
			## accrues no time and never reaches its own point. The same verified road graph the
			## place trips use crosses that junction on the ramp, so the body can come home and
			## satisfy the world's own 0.45 m gate. The accepted harvest keeps its own target, its
			## collisions and its 20 s work; only the walking route changes, and when the road
			## method yields no direction the pre-existing bounded local push still applies.
			var home_trip: bool = _spaced_foraging and (job.action in ["eat_ration", "harvest_ration"] or (job.action == "rest" and not job.has("place_id")))
			if nav_reaches_target:
				pass
			elif place_trip and place_steering != null:
				direction = place_steering.direction_for(id, str(job.command_id), body, target)
			elif home_trip and place_steering != null:
				direction = place_steering.direction_to_point(id, str(job.command_id), body, target)
			elif job.action == "recover_material" and material_steering != null:
				direction = material_steering.direction_for(id, str(job.command_id), body, target)
			elif bake_trip and place_steering != null:
				direction = place_steering.direction_to_point(id, str(job.command_id), body, target)
			elif _spaced_foraging and job.action in ["harvest_ration", "eat_ration", "rest"] and foraging_steering != null:
				direction = foraging_steering.direction_for(id, str(job.command_id), body, target)
			elif job.action == "approach" and social_steering != null:
				direction = social_steering.direction_for(id, str(job.command_id), body, target)
			else:
				if material_steering != null:
					material_steering.clear_route(id)
				if social_steering != null:
					social_steering.clear_route(id)
				var offset := target - body.position
				offset.y = 0
				if offset.length() > 0.30:
					direction = offset.normalized()
			if town_navigation != null and not nav_reaches_target:
				## The status line stays honest: the street route is reported only when the body
				## really has a steering direction to walk, otherwise the stop is still stated.
				var resident_name: String = str(town.resident(id).name)
				if direction.length() > 0.0:
					latest = "%s 的导航路线到不了当前目的地，改沿街道前往。" % resident_name
				elif town_navigation.enabled:
					latest = "%s 无法到达当前目的地，已停止移动。" % resident_name
				else:
					latest = "导航地图尚未就绪，暂不移动。"
			if not place_trip and not home_trip and not bake_trip:
				if place_steering != null:
					place_steering.clear_route(id)
			moving = direction.length() > 0.0
			if moving:
				body.velocity.x = direction.x * 1.35
				body.velocity.z = direction.z * 1.35
				actor.look_at(actor.global_position + direction)
			else:
				body.velocity.x = 0
				body.velocity.z = 0
			var worksite_blocked: bool = job.action in ["recover_material", "harvest_ration", "bake_bread"] and not moving and direction.length() <= 0.0 and body.position.distance_to(target) > 0.45
			actor.set_gesture("idle" if (moving or worksite_blocked) else {"eat_ration": "eat", "rest": "rest", "harvest_ration": "harvest", "repair_edge": "repair", "repair_handle": "repair", "work": "work", "use_tool": "work", "recover_material": "work", "bake_bread": "work"}.get(job.action, "idle"))
		else:
			if town_navigation != null:
				town_navigation.clear_route(id)
			if material_steering != null:
				material_steering.clear_route(id)
			if social_steering != null:
				social_steering.clear_route(id)
			if place_steering != null:
				place_steering.clear_route(id)
			# Legacy Mac repair hand-offs temporarily route the owner to the worker.
			# This route auto-movement is offline/local_rule_policy only and is never
			# executed in gateway_mode or restore_only.
			var route_target := Vector3.INF
			if not gateway_mode and not restore_only:
				route_target = _repair_route_target(id)
			var home_offset := Vector3.ZERO if gateway_mode or scripted_trade else (route_target if route_target.is_finite() else town.home_point(id)) - body.position
			home_offset.y = 0
			if _spaced_foraging and foraging_steering != null and not gateway_mode and not scripted_trade and not restore_only:
				var exit_target := _foraging_idle_exit(id, body)
				if exit_target.is_finite():
					home_offset = foraging_steering.direction_for(id, "foraging-clearance:" + id, body, exit_target)
			moving = home_offset.length() > 0.30
			body.velocity.x = home_offset.normalized().x * 1.35 if moving else 0.0
			body.velocity.z = home_offset.normalized().z * 1.35 if moving else 0.0
			if moving:
				actor.look_at(actor.global_position + home_offset.normalized())
			actor.set_gesture("carry" if moving and route_target.is_finite() else "idle")
		actor.set_walking(moving)
		body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 18 * delta
		body.move_and_slide()
		town.host_move(id, body.position)
	tick += delta
	if tick < 0.5:
		return
	var step := tick
	tick = 0
	var result := town.transaction(_save_path, func():
		var advanced := town.advance(step)
		if not advanced.ok:
			return advanced
		# Physical travel observation for material recovery: the collision-resolved
		# body position and the unpaused seconds of this batch. The world owns the
		# bounded stagnant-travel verdict and the personal consequence.
		for id in town.active_ids():
			if not bodies.has(id):
				continue
			if town.pending_job(id).get("action", "") == "recover_material":
				town.observe_material_travel(id, bodies[id].position, step)
			if town.pending_job(id).get("action", "") == "travel":
				town.observe_place_travel(id, bodies[id].position, step)
			## H36 journey-stall evidence: the same physical position stream feeds the world-scoped
			## stall record for an ACTIVE social approach or public trip. The world only states the
			## facts; a separate GM decides whether that is a defect, contention or slow going.
			var journey_action := str(town.pending_job(id).get("action", ""))
			if journey_action == "approach" and town.has_method("observe_journey_stall"):
				town.observe_journey_stall(id, "approach", bodies[id].position, step)
			elif journey_action == "travel" and town.has_method("observe_journey_stall"):
				town.observe_journey_stall(id, "place_travel", bodies[id].position, step)
		# Public-notice perception: the real scene answers the physics line-of-sight question
		# and the world grants attributed knowledge only to the resident who could actually
		# read or see it. Restore-only/paused runs never reach here.
		if place_notice != null:
			var observed: Variant = place_notice.observe()
			if observed is Dictionary and not (observed as Dictionary).get("ok", false):
				place_notice_evidence = place_notice.evidence()
		# Legacy Mac repair progression is offline/local_rule_policy only.
		if not gateway_mode and not restore_only:
			var repair_step := _progress_repair()
			if not repair_step.ok:
				return repair_step
			if repair_step.code != "repair_waiting":
				advanced["repair_step"] = repair_step
			if repair_fixture and repair_step.code == "repair_collected":
				return advanced
		for id in town.active_ids():
			if not gateway_mode and not scripted_trade and town.pending_job(id).is_empty() and town.active_repair_for(id).is_empty():
				var choice := town.choose_local(id)
				if choice != "wait":
					var command := "godot-life:%s:%d" % [id, town.command_count()]
					town.start_action(id, choice, command)
		return advanced)
	if not result.ok:
		paused = true
		latest = "保存失败，生活已暂停：" + str(result.code)
	else:
		if not gm_export_path.is_empty():
			_note_gm_export(town.maybe_write_background_gm_snapshot(gm_export_path))
		for receipt in result.completed:
			latest = str(town.resident(receipt.actor_id).name) + " · " + _action_label(receipt.code)
			actors[receipt.actor_id].set_gesture("idle")
		if result.has("repair_step"):
			latest = _repair_step_label(result.repair_step)
			dialogue.text = latest + "\n（玩家促成 · 居民步骤为离线规则 · 已保存）"
			if result.repair_step.code == "repair_collected" and repair_fixture:
				paused = true
	_refresh()

func _validation_limit_reached() -> bool:
	return gateway_mode and not capture_dir.is_empty() and validation_decision_limit >= 0 and validation_decisions_started >= validation_decision_limit

func _decision_limit_capture_ready() -> bool:
	return stop_on_decision_limit and gateway_mode and not restore_only and not capture_started \
		and _validation_limit_reached() and model_turns != null and not model_turns.busy

func _load_town_expansion() -> void:
	## Visible walkable expansion south of the plaza, built from existing residence and
	## environment v2 art. Art only: no resident moves, no home rewrite, no new resources.
	var expansion := TownExpansion.new()
	add_child(expansion)
	expansion.build()
	town_expansion_evidence = expansion.evidence
	set_meta("town_expansion", expansion.evidence)

func _load_public_notice() -> void:
	## The public wayfinding notice stands at the old-market exit. It is one existing-art prop
	## plus a straight line-of-sight sensor. The prop is built here during scene load; the sensor
	## only runs inside the world step, so a paused/restore-only run renders the notice but never
	## lets anybody read it and never grants knowledge by itself.
	var notice := PlaceNotice.new()
	add_child(notice)
	notice.configure(town, bodies)
	notice.build()
	place_notice = notice
	place_notice_evidence = notice.evidence()
	set_meta("town_place_notice", place_notice_evidence)


func write_gm_evidence_export() -> Dictionary:
	if gm_export_path.is_empty():
		return {"ok": false, "code": "gm_export_path_missing"}
	var result: Dictionary = town.write_background_gm_snapshot(gm_export_path)
	_note_gm_export(result)
	return result

func _note_gm_export(result: Dictionary) -> void:
	# Host status line only. A failed or stale export keeps an explicit failure status,
	# shown in the HUD until a successful export or explicit retry replaces it. It is
	# never written into resident dialogue and never enters a resident model context.
	var code := str(result.get("code", "unknown"))
	if result.get("ok", false):
		if code == "gm_export_written":
			gm_export_status = "GM证据已更新：%d个问题/%d个提议" % [int(result.get("issues", 0)), int(result.get("proposals", 0))]
	elif code == "gm_export_stale":
		gm_export_status = "GM证据导出失败（沿用旧文件）：" + str(result.get("last_error", "unknown"))
	else:
		gm_export_status = "GM证据导出失败：" + code

func _run_model_turn(id: String) -> Dictionary:
	# Validation cap stops BEFORE preparing another durable resident request.
	# The gateway ledger remains the independent fee authority.
	if _validation_limit_reached():
		return {"ok": false, "code": "validation_limit_reached", "actor_id": id}
	# The episode's own cutoff stops admission before this call can prepare a new
	# durable request or spend a decision from the bounded episode.
	if _model_admission_closed():
		return {"ok": false, "code": "admission_closed", "actor_id": id}
	validation_decisions_started += 1
	var result: Dictionary = await model_turns.step(id)
	if not is_instance_valid(status):
		return result
	if result.get("code") == "stale_controller_reply":
		return result # An obsolete connection must not overwrite the replacement's UI.
	if not result.ok:
		latest = "%s 的连接待处理：%s；其他居民继续。" % [town.resident(id).name, result.code]
	elif result.has("actor_id"):
		# A model's reason is private deliberation, not something it said aloud.
		last_model_note = "%s 已作出选择。" % town.resident(result.actor_id).name
		if not gm_export_path.is_empty():
			_note_gm_export(town.maybe_write_background_gm_snapshot(gm_export_path))
	_refresh()
	return result

func _unhandled_input(event: InputEvent) -> void:
	if _composing_dialogue():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		paused = not paused
		latest = "生活已暂停" if paused else "生活继续；时间只在运行时流逝"
		_refresh()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		if not dialogue_resident_id.is_empty():
			return
		_open_dialogue()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		# Legacy Mac repair suggestion: offline/local_rule_policy only. Never force
		# actions in model mode or restore_only.
		if gateway_mode or restore_only:
			return
		_request_edge_repair()
		return
	if event is InputEventKey and event.keycode in [KEY_E, KEY_F8]:
		return
	super._unhandled_input(event)

func _build_town_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.10, 0.91)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 19)
	panel.add_child(status)
	var dialogue_panel := PanelContainer.new()
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = 22
	dialogue_panel.offset_right = 742
	dialogue_panel.offset_top = -250
	dialogue_panel.offset_bottom = -20
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialogue_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(dialogue_panel)
	var conversation := VBoxContainer.new()
	dialogue_panel.add_child(conversation)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conversation.add_child(scroll)
	dialogue = Label.new()
	dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_size_override("font_size", 20)
	dialogue.text = "走近居民，按 H 输入你想说的话。"
	scroll.add_child(dialogue)
	dialogue_input = LineEdit.new()
	dialogue_input.max_length = 512
	dialogue_input.placeholder_text = "Enter 发送 · Esc 取消（世界继续运行）"
	dialogue_input.add_theme_font_size_override("font_size", 20)
	dialogue_input.visible = false
	dialogue_input.text_submitted.connect(_submit_dialogue)
	dialogue_input.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_dialogue()
			get_viewport().set_input_as_handled())
	conversation.add_child(dialogue_input)
	# A read-only window onto the same authoritative state that drives the bodies.
	# It creates no dialogue and chooses no action: every line comes from a current
	# pending job, a durable resident-turn record, or a public world event.
	life_panel = PanelContainer.new()
	life_panel.anchor_left = 1.0
	life_panel.anchor_right = 1.0
	life_panel.offset_left = -400
	life_panel.offset_right = -22
	life_panel.offset_top = 20
	life_panel.offset_bottom = 620
	life_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	life_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(life_panel)
	var life_column := VBoxContainer.new()
	life_panel.add_child(life_column)
	var roster_title := Label.new()
	roster_title.text = "十位居民 · 当前身体活动"
	roster_title.add_theme_font_size_override("font_size", 20)
	roster_title.add_theme_color_override("font_color", Color("f0cf88"))
	life_column.add_child(roster_title)
	life_roster = Label.new()
	life_roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	life_roster.add_theme_font_size_override("font_size", 16)
	life_column.add_child(life_roster)
	var separator := HSeparator.new()
	life_column.add_child(separator)
	var feed_title := Label.new()
	feed_title.text = "最近公开交流 / 生活结果"
	feed_title.add_theme_font_size_override("font_size", 20)
	feed_title.add_theme_color_override("font_color", Color("f0cf88"))
	life_column.add_child(feed_title)
	var feed_scroll := ScrollContainer.new()
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	life_column.add_child(feed_scroll)
	life_feed = Label.new()
	life_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	life_feed.add_theme_font_size_override("font_size", 15)
	feed_scroll.add_child(life_feed)

func _build_nameplates() -> void:
	var overlay := TownNameplates.new()
	add_child(overlay)
	var hud_controls: Array[Control] = []
	if is_instance_valid(status):
		var status_panel := status.get_parent() as Control
		if status_panel != null:
			hud_controls.append(status_panel)
	if is_instance_valid(dialogue):
		var dialogue_panel: Node = dialogue.get_parent()
		while dialogue_panel != null and not (dialogue_panel is PanelContainer):
			dialogue_panel = dialogue_panel.get_parent()
		if dialogue_panel is Control:
			hud_controls.append(dialogue_panel as Control)
	if is_instance_valid(life_panel):
		hud_controls.append(life_panel)
	overlay.configure(town, actors, cards, _camera, _player, hud_controls)
	if town_tools != null:
		town_tools.facts_enabled = false
	nameplates = overlay

func _composing_dialogue() -> bool:
	return is_instance_valid(dialogue_input) and dialogue_input.visible

func _nearest_dialogue_resident() -> String:
	var nearest := ""
	var distance := town.HEARING_RANGE
	for id in town.active_ids():
		var candidate := _player.position.distance_to(town.position_of(id))
		if candidate < distance:
			nearest = id
			distance = candidate
	return nearest

func _open_dialogue() -> void:
	dialogue_target = _nearest_dialogue_resident()
	if dialogue_target.is_empty():
		dialogue.text = "离得太远了。靠近居民再交谈。"
		return
	dialogue.text = "对 %s 说：" % town.resident(dialogue_target).name
	dialogue_input.visible = true
	dialogue_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_dialogue() -> void:
	dialogue_input.visible = false
	dialogue_input.release_focus()
	dialogue_target = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _submit_dialogue(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if _inquire_nearby(false, text, dialogue_target):
		dialogue_input.clear()
		_close_dialogue()

func _inquire_nearby(fixture_input: bool = false, message: String = "这里有什么需要我帮忙的吗？", target: String = "") -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_inquiry_seconds < 3.0:
		dialogue.text = "请稍等片刻再说。"
		return false
	var nearest := dialogue_resident_id if fixture_input else target
	if nearest.is_empty():
		nearest = _nearest_dialogue_resident()
	if nearest.is_empty():
		dialogue.text = "离得太远了。靠近居民再交谈。"
		return false
	var command := "visitor:%d" % town.command_count()
	var result := town.transaction(_save_path, func():
		return town.visitor_inquiry(nearest, fixture_inquiry_text if fixture_input else message, command, "scripted_player_fixture" if fixture_input else "human_player"))
	if not result.ok:
		dialogue.text = "交流未送达：" + str(result.code)
		return false
	last_inquiry_seconds = now
	if gateway_mode:
		dialogue.text = "询问已送达，居民会根据自己的处境决定是否回应。"
		return true
	# This explicitly labelled local policy uses only the selected resident's view.
	var view := town.resident_view(nearest)
	var choice := "unsure"
	var response := "暂时没有急事。我会留意工作点和口粮的情况。"
	if view.inventory.energy <= 50:
		choice = "unavailable"
		response = "我得先休息一下，等恢复精神再聊吧。"
	elif view.inventory.food == 0:
		choice = "willing"
		response = "我的口粮用完了。如果你找到食物来源，我愿意一起商量。"
	var replied := town.transaction(_save_path, func():
		return town.reply_to_visitor(nearest, result.request_id, choice, response, command + ":reply"))
	dialogue.text = "%s\n%s\n（离线规则回应 · 交流已保存）" % [view.identity.name, response] if replied.ok else "回复未送达：" + str(replied.code)
	_refresh()
	return true

func _refresh_public_dialogue(events: Array, replay: bool = false) -> void:
	for event in events:
		if event.get("type") != "visitor_reply" or "visitor:local" not in event.get("recipient_ids", []) or int(event.get("seq", -1)) <= last_public_reply_seq:
			continue
		last_public_reply_seq = int(event.seq)
		var source := "AI 居民回应" if event.get("source") == "opengameagent_live" else "离线回应"
		if replay:
			source += " · 历史对话"
		dialogue.text = "%s：\n%s\n（%s · 已保存）" % [town.resident(event.actor_id).name, event.get("text", ""), source]

func _request_edge_repair(fixture_input: bool = false) -> void:
	# Legacy Mac repair demo: offline/local_rule_policy only.
	if gateway_mode or restore_only:
		return
	var candidate := town.repair_candidate("edge")
	if candidate.is_empty():
		dialogue.text = "当前没有材料、技能和余额都满足的待修斧刃。"
		return
	if _player.position.distance_to(town.position_of(candidate.owner_id)) > Town.HEARING_RANGE:
		dialogue.text = "先靠近%s，再按 R 建议修理。" % town.resident(candidate.owner_id).name
		return
	if fixture_input:
		repair_initial_money = _money_total()
		repair_initial_iron = _work_material_total("iron")
	var command := "godot-repair:propose:%d" % town.command_count()
	var result := town.transaction(_save_path, func():
		return town.propose_repair(candidate.owner_id, candidate.item_id, candidate.worker_id,
			candidate.part, candidate.price_col, command))
	if not result.ok:
		dialogue.text = "修理建议未建立：" + str(result.code)
		return
	paused = false
	dialogue.text = "%s提出修刃委托；%s将按离线规则决定是否接下。\n（%s · 不是模型调用）" % [town.resident(candidate.owner_id).name,
		town.resident(candidate.worker_id).name, "脚本玩家输入" if fixture_input else "玩家介入"]
	latest = "玩家促成了一份待回应的修刃委托"
	_refresh()

func _repair_route_target(id: String) -> Vector3:
	var contract := town.active_repair_for(id)
	if contract.is_empty():
		return Vector3.INF
	if id == contract.owner_id and contract.status in ["accepted", "delivered", "completed"]:
		return town.home_point(contract.worker_id)
	return town.home_point(id)

func _progress_repair() -> Dictionary:
	var contract: Dictionary = {}
	for value in town.repair_contracts():
		if str(value.get("id", "")).begins_with("godot_repair:") and value.status in Town.REPAIR_ACTIVE_STATUSES:
			contract = value
			break
	if contract.is_empty():
		return {"ok": true, "code": "repair_waiting"}
	var owner_id: String = contract.owner_id
	var worker_id: String = contract.worker_id
	var worker_home: Vector3 = town.home_point(worker_id)
	var owner_at_work := town.position_of(owner_id).distance_to(worker_home) <= Town.WORK_STATION_RANGE
	var worker_at_work := town.position_of(worker_id).distance_to(worker_home) <= Town.WORK_STATION_RANGE
	match contract.status:
		"proposed":
			var material := "iron" if contract.part == "edge" else "wood"
			if worker_at_work and town.pending_job(worker_id).is_empty() and town.work_account(worker_id).get(material, 0) >= 1 and town.resident(owner_id).coins_col >= contract.price_col:
				return town.respond_repair(worker_id, contract.id, "accept", "godot-repair:accept:%d" % town.command_count())
		"accepted":
			if owner_at_work and worker_at_work and town.position_of(owner_id).distance_to(town.position_of(worker_id)) <= Town.HANDOFF_RANGE:
				return town.deliver_repair(owner_id, contract.id, "godot-repair:deliver:%d" % town.command_count())
		"delivered":
			if worker_at_work and town.pending_job(worker_id).is_empty():
				return town.start_repair_work(worker_id, contract.id, "godot-repair:work:%d" % town.command_count())
		"completed":
			if owner_at_work and worker_at_work and town.position_of(owner_id).distance_to(town.position_of(worker_id)) <= Town.HANDOFF_RANGE:
				return town.collect_repair(owner_id, contract.id, "godot-repair:collect:%d" % town.command_count())
	return {"ok": true, "code": "repair_waiting"}

func _repair_step_label(result: Dictionary) -> String:
	return {"repair_accept": "修理工接受委托，费用已预留",
		"repair_delivered": "柴斧已当面交到修理岗位",
		"repair_work_started": "修理工开始修刃（60 秒）",
		"repair_collected": "修好的柴斧已归还，2 Col 已结算"}.get(result.code, str(result.code))

func _has_active_repair() -> bool:
	for id in town.active_ids():
		if not town.active_repair_for(id).is_empty():
			return true
	return false

func _money_total() -> int:
	var total := 0
	for person in town.snapshot().residents:
		total += int(person.coins_col)
	for value in town.snapshot().life.get("accounts", []):
		total += int(value.get("reserved_col", 0))
	return total

func _work_material_total(material: String) -> int:
	var total := 0
	for value in town.snapshot().life.get("accounts", []):
		total += int(value.get(material, 0))
	return total

func _refresh() -> void:
	var snap := town.snapshot()
	_refresh_public_dialogue(snap.life.events)
	var mode_label := "独立 AI 连接（每人单独等待）" if gateway_mode else "离线生活规则"
	if scripted_trade:
		mode_label = "脚本化交易验收（无模型调用）"
	if restore_only:
		mode_label = "冷启动检查 · 暂停 · 无新增选择"
	if repair_fixture and not gateway_mode and not restore_only:
		mode_label = "离线自动修理演示（local_rule_policy）"
	var title := "交易流程测试 · 非原镇存档" if str(snap.world_id).begins_with("fixture:") else "起始之城 · 生活移植验证"
	if not str(snap.world_id).begins_with("fixture:") and (bool(snap.godot.get("new_world_seed", false)) or str(snap.get("origin", {}).get("kind", "")) == "new_world_seed"):
		title = "起始之城 · 独立新世界"
	var repair_text := ""
	if not snap.life.get("contracts", []).is_empty():
		var contract: Dictionary = snap.life.contracts[-1]
		repair_text = " · 修理：%s · %s" % [_repair_part_label(contract.part), _repair_status_label(contract.status)]
	var gm_text := "" if gm_export_status.is_empty() else "\n" + gm_export_status
	status.text = "%s\n%d 个存档身份 · %d 人活动 · %s\n空格 暂停/继续 · WASD 行走 · H 询问 · ESC 释放\n%s\n公共浆果 %d / %d · 生活事件 %d%s%s" % [title, snap.residents.size(), town.active_ids().size(), mode_label, latest, snap.foraging.stock, snap.foraging.capacity, snap.life.seq, repair_text, gm_text]
	var axe: Dictionary = {}
	for item in snap.life.get("items", []):
		if item.get("kind") == "axe":
			axe = item
			break
	# Build held-item projection lines ONCE from the snapshot already taken above.
	# projection_lines(snap) avoids re-snapshotting the town for every resident.
	var held_lines: Dictionary = {}
	if town_tools != null:
		held_lines = town_tools.projection_lines(snap)
	for id in town.active_ids():
		var a := town.account(id)
		var job: Dictionary = town.pending_job(id)
		var held: String = str(held_lines.get(id, ""))
		var base := "%s\n%s · 口粮 %d" % [town.resident(id).name, "休整" if job.is_empty() else _action_label(job.action), a.food]
		cards[id].text = base if held.is_empty() else base + "\n" + held
		if nameplates != null and nameplates.has_method("set_card_hidden"):
			nameplates.set_card_hidden(id, true)
		# Projection policy: each world axe is shown only through TownTools in every
		# mode except the explicitly labelled legacy --town-repair-fixture demo, where
		# the Mac hand-axe HUD is the projector and the duplicate TownTools axe for the
		# same item is suppressed (material piles/facts are preserved). The legacy path
		# also excludes gateway_mode, restore_only and scripted_trade.
		var legacy_hand_axe := repair_fixture and not gateway_mode and not restore_only and not scripted_trade
		actors[id].set_holds_axe(legacy_hand_axe and not axe.is_empty() and axe.get("custodian_id") == id, axe.get("edge", 0) == 100)
	if town_tools != null:
		var tools_axes: Dictionary = town_tools.axes
		for item_id in tools_axes.keys():
			var node: Node3D = tools_axes[item_id]
			if is_instance_valid(node):
				node.visible = not (repair_fixture and not gateway_mode and not restore_only and not scripted_trade and not axe.is_empty() and item_id == axe.get("id"))
	for index in berry_visuals.size():
		berry_visuals[index].visible = index < snap.foraging.stock
	_refresh_life_window(snap)

func _refresh_life_window(snap: Dictionary) -> void:
	if not is_instance_valid(life_roster) or not is_instance_valid(life_feed):
		return
	var roster_lines: Array[String] = []
	var resident_turns: Dictionary = snap.godot.get("resident_turns", {})
	for id in town.active_ids():
		var job: Dictionary = town.pending_job(id)
		var activity := "休整" if job.is_empty() else _action_label(str(job.get("action", "")))
		var moving := false
		var body: CharacterBody3D = bodies.get(id)
		if is_instance_valid(body):
			moving = Vector2(body.velocity.x, body.velocity.z).length() > 0.05
		if moving:
			activity += " · 行走中"
		var turn_note := ""
		if gateway_mode or restore_only:
			var turn: Variant = resident_turns.get(id, {})
			var turn_status := str(turn.get("status", "尚无记录")) if turn is Dictionary else "尚无记录"
			var request_id := str(turn.get("request_id", "")) if turn is Dictionary else ""
			var current_run := not request_id.is_empty() and request_id != str(session_start_request_ids.get(id, ""))
			var when := "本次" if current_run else "历史"
			turn_note = " · " + {"pending": "%s正在独立决定" % when, "settled": "%s决定已结算" % when, "provider_error": "%s连接失败待后续" % when}.get(turn_status, "%s%s" % [when, turn_status])
		roster_lines.append("%s  %s%s" % [str(town.resident(id).name), activity, turn_note])
	life_roster.text = "\n".join(roster_lines)

	var feed_lines: Array[String] = []
	var events: Array = snap.life.get("events", [])
	for offset in range(1, mini(events.size(), 24) + 1):
		var event: Variant = events[events.size() - offset]
		if not event is Dictionary:
			continue
		var row: Dictionary = event
		var kind := str(row.get("type", ""))
		var actor_id := str(row.get("actor_id", ""))
		var actor_name := actor_id
		if actor_id in town.active_ids():
			actor_name = str(town.resident(actor_id).name)
		var words := str(row.get("speech", row.get("text", ""))).strip_edges().replace("\n", " ")
		var is_new := int(row.get("seq", -1)) > session_start_life_seq
		var source := ("本次AI" if is_new else "历史AI") if row.get("source", "") == "opengameagent_live" else ("本次世界" if is_new else "历史世界")
		if not words.is_empty():
			if words.length() > 72:
				words = words.left(72) + "…"
			feed_lines.push_front("[%s · #%d] %s：%s" % [source, int(row.get("seq", -1)), actor_name, words])
		elif kind in ["eat_ration", "harvest_ration", "rest", "bread_baked", "bread_eaten", "repair_completed", "resident_moved", "place_visited"]:
			feed_lines.push_front("[%s · #%d] %s · %s" % [source, int(row.get("seq", -1)), actor_name, _action_label(kind)])
		if feed_lines.size() >= 5:
			break
	life_feed.text = "\n\n".join(feed_lines) if not feed_lines.is_empty() else "还没有可公开展示的事件。"

func _action_label(action: String) -> String:
	return {"eat_ration": "进食", "rest": "休息", "harvest_ration": "采集", "approach": "走近交谈", "deliver": "交付工具", "work": "修理", "collect": "取回工具", "use_tool": "使用工具", "recover_material": "整理余料", "material_recovered": "已取得材料", "material_depleted": "余料已取完，本次未取得", "bake_bread": "烤面包", "bread_baked": "烤好一个自己的面包", "bread_eaten": "吃掉自己烤的面包", "baking_point_observed": "看到公共烤炉", "baking_route_installed": "公共烤炉已就位", "repair_edge": "修刃", "repair_handle": "修柄", "repair_completed": "修理完成", "resources_unavailable": "资源不足，未完成"}.get(action, action)

func _repair_part_label(part: String) -> String:
	return "斧刃" if part == "edge" else "斧柄"

func _repair_status_label(value: String) -> String:
	return {"proposed": "待回应", "accepted": "已接单/费用预留", "delivered": "已交付/修理中",
		"completed": "已完成/待取回", "collected": "已归还/已付款", "rejected": "已拒绝",
		"cancelled": "已取消"}.get(value, value)

func _work_marker(point: Vector3, title: String) -> void:
	var marker := Label3D.new()
	marker.text = title
	marker.font_size = 36
	marker.outline_size = 8
	marker.position = point + Vector3(0, 0.12, -0.7)
	marker.rotation_degrees.x = -70
	marker.modulate = Color("e2c591")
	add_child(marker)

func _build_berry_patch() -> void:
	var point := town.berry_center()
	_work_marker(point, "公共浆果地")
	for i in 3:
		var bush := MeshInstance3D.new()
		var foliage := SphereMesh.new()
		foliage.radius = 0.3
		foliage.height = 0.45
		foliage.radial_segments = 8
		foliage.rings = 4
		bush.mesh = foliage
		bush.material_override = _simple_material(Color("536d35"))
		bush.position = point + Vector3((i - 1) * 0.65, 0.2, -0.8)
		add_child(bush)
		var fruit := MeshInstance3D.new()
		var fruit_mesh := SphereMesh.new()
		fruit_mesh.radius = 0.08
		fruit_mesh.height = 0.16
		fruit.mesh = fruit_mesh
		fruit.material_override = _simple_material(Color("a43d53"))
		fruit.position = Vector3(0, 0.15, 0.2)
		bush.add_child(fruit)
		berry_visuals.append(fruit)

func pending_breakdown(snap: Dictionary) -> Dictionary:
	# Truthful pending work for every journey source. The reviewed shared-world
	# capture reported pending_count 0 while one accepted social approach was still
	# unfinished, because only godot.pending (life and material jobs) was counted.
	# Trade jobs live in godot.trade.jobs, so they are counted here and named
	# separately, and a future report cannot silently drop a social job again.
	# Place travel and place-bound rest live in godot.places, so they are counted too.
	# A public bake lives in godot.baking.jobs and is named separately in the same way, so an
	# unfinished bake can never be reported as an idle world.
	var zero := {"pending_life_count": 0, "pending_trade_count": 0, "pending_baking_count": 0, "pending_place_count": 0, "pending_count": 0}
	var godot_state: Variant = snap.get("godot", {})
	if not godot_state is Dictionary:
		return zero
	var life_jobs: Variant = godot_state.get("pending", {})
	var trade: Variant = godot_state.get("trade", {})
	var trade_jobs: Variant = trade.get("jobs", {}) if trade is Dictionary else {}
	var baking: Variant = godot_state.get("baking", {})
	var baking_jobs: Variant = baking.get("jobs", {}) if baking is Dictionary else {}
	var places: Variant = godot_state.get("places", {})
	var place_jobs: Variant = places.get("jobs", {}) if places is Dictionary else {}
	var life_count: int = life_jobs.size() if life_jobs is Dictionary else 0
	var trade_count: int = trade_jobs.size() if trade_jobs is Dictionary else 0
	var baking_count: int = baking_jobs.size() if baking_jobs is Dictionary else 0
	var place_count: int = place_jobs.size() if place_jobs is Dictionary else 0
	return {"pending_life_count": life_count, "pending_trade_count": trade_count,
		"pending_baking_count": baking_count, "pending_place_count": place_count,
		"pending_count": life_count + trade_count + baking_count + place_count}

func _shutdown_evidence() -> Dictionary:
	## The engine's own stopping facts, so a host report never has to guess whether
	## the episode closed admission, what it waited for, or what it left owed. A
	## resident request whose reply was never applied is named here and keeps its
	## pending status in the save; nothing in this path rewrites it as settled.
	var owed: Array = []
	for id in town.active_ids():
		var record: Variant = town._state.godot.get("resident_turns", {}).get(id, {})
		if record is Dictionary and record.get("status", "") == "pending":
			owed.append({"actor_id": id, "request_id": str(record.get("request_id", ""))})
	var reported := {"capture_reason": capture_shutdown_reason, "exit_code": shutdown_exit_code,
		"wait_limit_seconds": shutdown_wait_limit, "resident_requests_owed": owed}
	if _owns_shutdown_gate():
		reported.merge(model_turns.shutdown_evidence(), true)
	return reported

func _capture_town() -> void:
	paused = true
	_refresh()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("town.png"))
	var snap := town.snapshot()
	var is_fixture := str(snap.world_id).begins_with("fixture:")
	var is_new_world := bool(snap.godot.get("new_world_seed", false)) or str(snap.get("origin", {}).get("kind", "")) == "new_world_seed"
	var pending := pending_breakdown(snap)
	var evidence := {"original_identities": 0 if is_fixture or is_new_world else snap.residents.size(), "active": town.active_ids().size(), "life_seq": snap.life.seq,
		"source_seq": snap.godot.source_life_seq, "new_events": snap.godot.new_events,
		"new_decisions": "none_restore" if restore_only else "scripted_trade_fixture" if scripted_trade else "controller_records" if gateway_mode else "local_rule_policy", "foraging": snap.foraging, "pending_count": pending.pending_count,
		"pending_life_count": pending.pending_life_count, "pending_trade_count": pending.pending_trade_count, "resident_turns": snap.godot.get("resident_turns", {})}
	evidence["world_id"] = snap.world_id
	evidence["is_fixture"] = is_fixture
	evidence["identity_count"] = snap.residents.size()
	evidence["world_origin"] = "fixture" if is_fixture else "independent_new_world" if is_new_world else "migration_validation"
	evidence["scripted_trade"] = scripted_trade
	evidence["validation_decisions_started"] = validation_decisions_started
	evidence["validation_decision_limit"] = validation_decision_limit
	evidence["validation_limit_reached"] = _validation_limit_reached()
	evidence["stop_on_decision_limit"] = stop_on_decision_limit
	evidence["shutdown"] = _shutdown_evidence()
	evidence["trade_items"] = snap.life.get("items", [])
	evidence["trade_contracts"] = snap.life.get("contracts", [])
	if dialogue_fixture:
		evidence["player_input"] = "scripted_player_fixture"
		evidence["player_message"] = fixture_inquiry_text
		evidence["dialogue"] = dialogue.text
	if repair_fixture:
		evidence["repair_input"] = "scripted_player_fixture"
		var repair_contract: Dictionary = snap.life.get("contracts", [])[-1] if not snap.life.get("contracts", []).is_empty() else {}
		var repair_item: Dictionary = {}
		for item in snap.life.get("items", []):
			if item.get("id") == repair_contract.get("item_id"):
				repair_item = item
				break
		evidence["repair_contract"] = repair_contract
		evidence["repair_items"] = snap.life.get("items", [])
		evidence["repair_accounts"] = snap.life.get("accounts", [])
		evidence["dialogue"] = dialogue.text
		evidence["repair_checks"] = {
			"contract_collected": repair_contract.get("status") == "collected",
			"edge_repaired": repair_item.get("edge") == 100,
			"custody_returned": repair_item.get("custodian_id") == repair_contract.get("owner_id"),
			"one_iron_consumed": repair_initial_iron >= 1 and _work_material_total("iron") == repair_initial_iron - 1,
			"money_conserved": repair_initial_money >= 0 and _money_total() == repair_initial_money,
			"fee_settled": repair_contract.get("reserved_col") == 0,
			"paid_calls_zero": true}
		evidence["repair_passed"] = not evidence.repair_checks.values().has(false)
	var file := FileAccess.open(capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	file.close()
	if not gm_export_path.is_empty():
		_note_gm_export(town.write_background_gm_snapshot(gm_export_path))
	# A nonzero exit is the engine's own statement that this bounded episode ended
	# with a reply still owed; the launcher reports it instead of a clean pass.
	get_tree().quit(shutdown_exit_code)
