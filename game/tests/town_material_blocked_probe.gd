extends SceneTree
## BLOCKED MATERIAL TRAVEL probe. Offline SceneTree diagnostic; deterministic
## fixture controller only — this is NOT a paid Kimi run and makes no model call.
##
## Scope: a resident whose material-recovery travel makes no physical progress
## for a bounded threshold receives one personal failure observation, keeps the
## still-pending job, can be scheduled to choose wait or to cancel that one trip,
## and is exposed to the background-GM layer only through a separate read-only
## diagnostic. Exclusions are exercised explicitly: paused time and a worker
## already at the target never report, and a progressing detour stays clean.

const Runtime := preload("res://core/town_runtime.gd")
const Turns := preload("res://agents/town_turns.gd")
const TownScene := preload("res://scenes/town_street.tscn")

const ALLOWED_ROOT_REL := "../tmp/chain-20260912/task01-tests"
const SMITH := "fixture:smith"
const INNKEEPER := "fixture:innkeeper"
const CARPENTER := "fixture:carpenter"
const SOURCE_ID := "fixture:blocked-iron"
const SOURCE_POSITION := Vector3(0, 0.22, 5)
const START_POSITION := Vector3(0, 0.22, 7)
const BLOCKED_EVENT := "material_travel_blocked"
const CANCEL_EVENT := "material_travel_cancelled"
const SCENARIOS := ["paused-enclosed", "at-target", "blocked-enclosed", "detour-crate", "recurring-block", "gm-evidence"]

class FixtureController extends Node:
	## Deterministic offline fixture controller. It performs no network call and
	## always chooses the same supported option for the same view.
	var preference := "wait"
	var calls := 0
	var selected := ""
	var need: Variant = null
	var fail_response := false
	var private_reason := "deterministic fixture controller choice"
	var last_reply: Dictionary = {}
	var last_view: Dictionary = {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		last_view = view.duplicate(true)
		if fail_response:
			last_reply = {"ok": false, "code": "provider_error", "command_id": "fixture-controller:%d" % calls, "provenance": "opengameagent_fixture"}
			return last_reply
		var wanted := "Wait" if preference == "wait" else "放弃"
		var alias := ""
		for detail in view.get("action_details", []):
			if str(detail.get("label", "")).begins_with(wanted):
				alias = str(detail.get("id", ""))
		selected = alias
		var decision := {"action": alias, "reason": private_reason}
		if need != null:
			decision.need = need
		last_reply = {"ok": true, "decision": decision, "command_id": "fixture-controller:%d" % calls, "provenance": "opengameagent_fixture"}
		return last_reply

var _fixture_path := ""
var _save_path := ""
var _restart_path := ""
var _out_path := ""
var _scenario := ""
var _gm_export_dir := ""
var _cancel_diag: Dictionary = {}
var _allowed_root := ""
var _scene: Node = null
var _writer_path := ""
var _turns: Node = null
var _controller: FixtureController = null
var _writer_held := false
var _runtime: RefCounted = null
var _failures: Array = []
var _checks := 0
var _result: Dictionary = {}

func _check(condition: bool, code: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(code)
	return condition

func _fail(code: String) -> void:
	_failures.append(code)

func _norm(path: String) -> String:
	return path.replace("\\", "/").simplify_path()

func _under_root(path: String) -> bool:
	var root := _norm(_allowed_root)
	var candidate := _norm(path)
	if OS.get_name() == "Windows":
		root = root.to_lower()
		candidate = candidate.to_lower()
	return candidate.begins_with(root + "/")

func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes

func _parse_args() -> void:
	_allowed_root = _norm(ProjectSettings.globalize_path("res://").path_join(ALLOWED_ROOT_REL))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			_fixture_path = _norm(ProjectSettings.globalize_path(arg.trim_prefix("--fixture=")))
		elif arg.begins_with("--town-save="):
			_save_path = _norm(ProjectSettings.globalize_path(arg.trim_prefix("--town-save=")))
		elif arg.begins_with("--blocked-probe-restart="):
			_restart_path = _norm(ProjectSettings.globalize_path(arg.trim_prefix("--blocked-probe-restart=")))
		elif arg.begins_with("--blocked-probe-output="):
			_out_path = _norm(ProjectSettings.globalize_path(arg.trim_prefix("--blocked-probe-output=")))
		elif arg.begins_with("--blocked-probe-scenario="):
			_scenario = arg.trim_prefix("--blocked-probe-scenario=")
		elif arg.begins_with("--gm-export-dir="):
			_gm_export_dir = _norm(ProjectSettings.globalize_path(arg.trim_prefix("--gm-export-dir=")))
		elif arg == "--town-gateway" or arg == "--town-restore":
			_fail("forbidden_mode:" + arg.trim_prefix("--"))
	if _scenario == "gm-evidence" and (_gm_export_dir.is_empty() or not _under_root(_gm_export_dir)):
		_fail("gm_export_dir_required")

func _validate_paths() -> bool:
	if _fixture_path.is_empty() or _save_path.is_empty() or _out_path.is_empty() or _scenario.is_empty():
		_fail("missing_args")
		return false
	if _scenario not in SCENARIOS:
		_fail("unknown_scenario")
		return false
	if not _fixture_path.is_absolute_path() or not _save_path.is_absolute_path() or not _out_path.is_absolute_path():
		_fail("not_absolute")
		return false
	if not _under_root(_save_path) or not _under_root(_out_path) or not _under_root(_fixture_path):
		_fail("outside_allowed_root")
		return false
	if _save_path.to_lower() == _out_path.to_lower() or FileAccess.file_exists(_out_path) or FileAccess.file_exists(_save_path):
		_fail("output_target_not_fresh")
		return false
	if _scenario == "blocked-enclosed":
		if _restart_path.is_empty() or not _restart_path.is_absolute_path() or not _under_root(_restart_path) or FileAccess.file_exists(_restart_path):
			_fail("restart_target_not_fresh")
			return false
	if not FileAccess.file_exists(_fixture_path):
		_fail("fixture_missing")
		return false
	for parent in [_out_path.get_base_dir(), _save_path.get_base_dir()]:
		if not DirAccess.dir_exists_absolute(parent):
			if not _under_root(parent) or DirAccess.make_dir_recursive_absolute(parent) != OK:
				_fail("parent_create_failed")
				return false
	if not _gm_export_dir.is_empty() and not DirAccess.dir_exists_absolute(_gm_export_dir):
		if not _under_root(_gm_export_dir) or DirAccess.make_dir_recursive_absolute(_gm_export_dir) != OK:
			_fail("gm_export_dir_create_failed")
			return false
	return true

func _copy_fixture() -> bool:
	var bytes := _read_bytes(_fixture_path)
	if bytes.is_empty():
		_fail("fixture_unreadable")
		return false
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		_fail("copy_open_failed")
		return false
	file.store_buffer(bytes)
	file.close()
	return _check(_read_bytes(_save_path) == bytes, "copy_bytes_mismatch")

func _prepare_world(path: String) -> bool:
	# Fresh labelled fixture: one attributed ask_help, then a reviewed public iron
	# source. No other world mutation and no model call.
	_runtime = Runtime.new()
	var loaded: Dictionary = _runtime.load_from(path)
	if not _check(loaded.get("ok", false), "fixture_load_failed"):
		return false
	if not _check(_runtime.snapshot().get("fixture", false), "fixture_not_labelled"):
		return false
	if not _check(str(_runtime.snapshot().get("world_id", "")) == "fixture:town-trade-validation", "wrong_world_id"):
		return false
	if not _check(not _runtime.snapshot().godot.has("materials"), "fixture_not_fresh"):
		return false
	var ask: Dictionary = _runtime.transaction(path, func(): return _runtime.submit_trade(SMITH, "ask:" + INNKEEPER, "fixture:blocked-need", "opengameagent_fixture", "I need a finite source of iron."))
	_writer_held = true
	if not _check(ask.get("ok", false), "ask_failed"):
		return false
	var seq := int(_runtime.snapshot().life.seq)
	var spec := {"id": SOURCE_ID, "label": "Public iron offcuts", "material": "iron", "initial_stock": 3,
		"position": [SOURCE_POSITION.x, SOURCE_POSITION.y, SOURCE_POSITION.z], "access": "public"}
	var install: Dictionary = _runtime.transaction(path, func(): return _runtime.install_material_source(spec, seq, "development_gm:blocked-source"))
	if not _check(install.get("ok", false), "install_failed"):
		return false
	var released: Dictionary = _runtime.release_writer(path)
	_writer_held = false
	if not _check(released.get("ok", false), "writer_release_failed"):
		return false
	return true

func _load_scene(path: String) -> bool:
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	await process_frame
	await process_frame
	if not _check(_scene._market_loaded, "market_not_loaded"):
		return false
	if not _check(_scene.paused, "scene_started_unpaused"):
		return false
	if not _check(_scene.town._material_visibility_required, "material_visibility_not_required"):
		return false
	if not _check(_scene.bodies.has(SMITH), "scene_missing_smith_body"):
		return false
	if not _check(_scene.model_turns == null, "model_turns_unexpected"):
		return false
	_scene.scripted_trade = true
	_writer_path = str(_scene._save_path)
	return true

func _unpause_for(milliseconds: int) -> void:
	_scene.paused = false
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < milliseconds:
		await physics_frame
		await process_frame
	_scene.paused = true

func _obstacle_specs(enclosed: bool) -> Array:
	if enclosed:
		return [{"name": "ProbeBack", "size": Vector3(4, 0.55, 0.5), "center": Vector3(0, 0.495, 4)},
			{"name": "ProbeLeft", "size": Vector3(0.5, 0.55, 2), "center": Vector3(-2, 0.495, 5)},
			{"name": "ProbeRight", "size": Vector3(0.5, 0.55, 2), "center": Vector3(2, 0.495, 5)},
			{"name": "ProbeFront", "size": Vector3(4, 0.55, 0.5), "center": Vector3(0, 0.495, 6)}]
	return [{"name": "ProbeCrate", "size": Vector3(1.2, 0.55, 0.5), "center": Vector3(0, 0.495, 6)}]

func _add_fixture_obstacles(enclosed: bool) -> void:
	# Labelled fixture geometry only; the resident still has to move its own body.
	for spec in _obstacle_specs(enclosed):
		var body := StaticBody3D.new()
		body.name = str(spec.name)
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec.size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var mesh_box := BoxMesh.new()
		mesh_box.size = spec.size
		mesh.mesh = mesh_box
		body.add_child(mesh)
		body.position = spec.center
		_scene.add_child(body)
	await physics_frame
	await physics_frame
	await process_frame

func _submit_job(command_id: String) -> bool:
	var submit: Dictionary = _scene.town.transaction(_writer_path, func(): return _scene.town.submit_trade(SMITH, "material:recover:" + SOURCE_ID, command_id, "opengameagent_fixture"))
	if not _check(submit.get("ok", false), "submit_failed:" + command_id):
		_failures.append("submit_detail:" + JSON.stringify(submit))
		return false
	return true

func _blocked_event_count() -> int:
	var count := 0
	for event in _scene.town.snapshot().life.events:
		if event.get("type") == BLOCKED_EVENT:
			count += 1
	return count

func _blocked_event() -> Dictionary:
	for event in _scene.town.snapshot().life.events:
		if event.get("type") == BLOCKED_EVENT:
			return event
	return {}

func _body_position() -> Vector3:
	var body: Node3D = _scene.bodies.get(SMITH)
	return body.position if body != null else Vector3.INF

func _town_blocked_records(command_id: String = "", status: String = "") -> Array:
	var result: Array = []
	for record in _scene.town.snapshot().godot.materials.get("blocked", {}).values():
		if not command_id.is_empty() and str(record.get("command_id", "")) != command_id:
			continue
		if not status.is_empty() and str(record.get("status", "")) != status:
			continue
		result.append(record)
	return result

func _town_blocked_events(command_id: String = "") -> Array:
	var result: Array = []
	for event in _scene.town.snapshot().life.events:
		if event.get("type") != BLOCKED_EVENT:
			continue
		if not command_id.is_empty() and str(event.get("operation_id", "")) != command_id:
			continue
		result.append(event)
	return result

func _conservation() -> Dictionary:
	var world: Dictionary = _scene.town.snapshot()
	var coins := 0
	var iron := 0
	for person in world.residents:
		coins += int(person.get("coins_col", 0))
	for account in world.life.accounts:
		coins += int(account.get("reserved_col", 0))
		iron += int(account.get("iron", 0))
	var stock := 0
	for source in world.godot.get("materials", {}).get("sources", {}).values():
		if str(source.get("material", "")) == "iron":
			stock += int(source.get("stock", 0))
	return {"coins": coins, "iron": iron, "stock": stock, "items": world.life.items.duplicate(true),
		"contracts": world.life.contracts.duplicate(true)}

func _fingerprint() -> Dictionary:
	var world: Dictionary = _scene.town.snapshot()
	var fingerprint := _conservation()
	fingerprint["positions"] = world.godot.positions.duplicate(true)
	fingerprint["life_seq"] = int(world.life.seq)
	return fingerprint

func _smith_iron() -> int:
	for account in _scene.town.snapshot().life.accounts:
		if account.get("resident_id") == SMITH:
			return int(account.get("iron", -1))
	return -1

func _scenario_paused_enclosed() -> void:
	if not await _load_scene(_save_path):
		return
	await _unpause_for(1200)
	if not _check(_scene.town.resident_view(SMITH).material_sources.size() > 0, "paused_source_not_observed"):
		return
	await _add_fixture_obstacles(true)
	if not _submit_job("fixture:paused-job"):
		return
	var before := _conservation()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 10000:
		await physics_frame
		await process_frame
	var job: Dictionary = _scene.town.pending_job(SMITH)
	_result = {"scenario": "paused-enclosed", "paused_ms": 10000, "threshold_seconds": Runtime.MATERIAL_BLOCKED_NO_PROGRESS_SECONDS,
		"episode": _scene.town.blocked_material_episode(SMITH), "blocked_events": _blocked_event_count(),
		"pending": not job.is_empty(), "pending_elapsed": float(job.get("elapsed", -1.0)),
		"diagnostics": _scene.town.blocked_material_diagnostics().size(),
		"conserved": _conservation() == before}
	_check(_scene.town.blocked_material_episode(SMITH).is_empty(), "paused_nonempty_episode")
	_check(_blocked_event_count() == 0, "paused_reported_event")
	_check(not job.is_empty(), "paused_job_lost")
	_check(float(job.get("elapsed", -1.0)) == 0.0, "paused_job_progressed")
	_check(_scene.town.blocked_material_diagnostics().is_empty(), "paused_gm_diagnostic")
	_check(_conservation() == before, "paused_conservation_changed")

func _scenario_at_target() -> void:
	if not await _load_scene(_save_path):
		return
	await _unpause_for(1200)
	if not _check(_scene.town.resident_view(SMITH).material_sources.size() > 0, "at_target_source_not_observed"):
		return
	var body: CharacterBody3D = _scene.bodies[SMITH]
	body.position = SOURCE_POSITION
	var moved: Dictionary = _scene.town.transaction(_writer_path, func():
		_scene.town.host_move(SMITH, SOURCE_POSITION)
		return {"ok": true, "code": "fixture_relocation"})
	if not _check(moved.get("ok", false), "at_target_relocation_failed"):
		return
	if not _submit_job("fixture:at-target-job"):
		return
	var before := _conservation()
	var max_distance := 0.0
	_scene.paused = false
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 12000:
		await physics_frame
		await process_frame
		max_distance = maxf(max_distance, _body_position().distance_to(SOURCE_POSITION))
	_scene.paused = true
	var job: Dictionary = _scene.town.pending_job(SMITH)
	_result = {"scenario": "at-target", "unpaused_ms": 12000, "episode": _scene.town.blocked_material_episode(SMITH),
		"blocked_events": _blocked_event_count(), "pending": not job.is_empty(),
		"pending_elapsed": float(job.get("elapsed", -1.0)), "max_distance": max_distance,
		"diagnostics": _scene.town.blocked_material_diagnostics().size(), "conserved": _conservation() == before}
	_check(_scene.town.blocked_material_episode(SMITH).is_empty(), "at_target_nonempty_episode")
	_check(_blocked_event_count() == 0, "at_target_reported_event")
	_check(not job.is_empty(), "at_target_job_lost")
	_check(float(job.get("elapsed", -1.0)) > 5.0, "at_target_no_work_progress")
	_check(max_distance <= Runtime.MATERIAL_ARRIVAL_RADIUS, "at_target_left_work_site")
	_check(_scene.town.blocked_material_diagnostics().is_empty(), "at_target_gm_diagnostic")
	_check(_conservation() == before, "at_target_conservation_changed")

func _blocked_open(limit_ms: int) -> Dictionary:
	# Drives real physics until the blocked episode is reported or the bound ends.
	_scene.paused = false
	var start := Time.get_ticks_msec()
	var first_sample_before_threshold := true
	var samples: Array = []
	while Time.get_ticks_msec() - start < limit_ms:
		await physics_frame
		await process_frame
		var now := Time.get_ticks_msec() - start
		var episode: Dictionary = _scene.town.blocked_material_episode(SMITH)
		if samples.size() < 60:
			var position := _body_position()
			samples.append({"t_ms": now, "distance": position.distance_to(SOURCE_POSITION), "x": position.x, "episode": not episode.is_empty()})
		if first_sample_before_threshold and now >= 6000:
			first_sample_before_threshold = false
			_check(episode.is_empty(), "reported_before_threshold")
		if not episode.is_empty():
			_scene.paused = true
			return {"episode": episode, "wall_ms": now, "samples": samples}
	_scene.paused = true
	return {"episode": {}, "wall_ms": Time.get_ticks_msec() - start, "samples": samples}

func _scenario_blocked_enclosed() -> void:
	if not await _load_scene(_save_path):
		return
	await _unpause_for(1200)
	if not _check(_scene.town.resident_view(SMITH).material_sources.size() > 0, "blocked_source_not_observed"):
		return
	await _add_fixture_obstacles(true)
	_controller = FixtureController.new()
	root.add_child(_controller)
	_turns = Turns.new()
	_turns.town = _scene.town
	_turns.save_path = _writer_path
	_turns.brains[SMITH] = _controller
	root.add_child(_turns)
	if not _submit_job("fixture:blocked-open"):
		return
	var start_position := _body_position()
	_check(_turns.ready_resident() != SMITH, "unblocked_pending_job_was_schedulable")
	var before := _conservation()
	var smith_iron_before := _smith_iron()
	var observed: Dictionary = await _blocked_open(40000)
	var episode: Dictionary = observed.episode
	if not _check(not episode.is_empty(), "blocked_episode_missing"):
		_result = {"scenario": "blocked-enclosed", "observed": observed, "conserved": _conservation() == before}
		return
	var stall_displacement := start_position.distance_to(_body_position())
	var job_after: Dictionary = _scene.town.pending_job(SMITH)
	var event := _blocked_event()
	var personal: Dictionary = _scene.town.resident_view(SMITH)
	var personal_json := JSON.stringify(personal)
	var diagnostics: Array = _scene.town.blocked_material_diagnostics()
	_check(float(episode.get("no_progress_seconds", 0.0)) >= Runtime.MATERIAL_BLOCKED_NO_PROGRESS_SECONDS, "stall_below_threshold")
	_check(str(episode.get("status", "")) == "open" and bool(episode.get("reported", false)), "episode_not_open_reported")
	var episode_id_text := str(episode.get("episode_id", ""))
	var episode_serial := episode_id_text.trim_prefix("material_blocked:")
	_check(episode_id_text.begins_with("material_blocked:") and episode_serial.is_valid_int() and int(episode_serial) >= 1 and episode_id_text.length() <= 128, "episode_id_unstable:" + episode_id_text)
	_check(str(episode.get("command_id", "")) == "fixture:blocked-open", "episode_command_mismatch")
	_check(not job_after.is_empty() and float(job_after.get("elapsed", -1.0)) == 0.0, "blocked_job_changed")
	_check(stall_displacement < Runtime.MATERIAL_BLOCKED_PROGRESS_EPSILON, "blocked_body_moved")
	_check(_blocked_event_count() == 1, "personal_event_not_once")
	_check(str(event.get("actor_id", "")) == SMITH, "personal_event_actor")
	_check(event.get("recipient_ids", []) == [SMITH], "personal_event_recipient")
	_check(str(event.get("operation_id", "")) == "fixture:blocked-open", "personal_event_operation")
	var text := str(event.get("text", ""))
	_check(str(event.get("episode_id", "")) == str(episode.get("episode_id", "")) and not str(event.get("episode_id", "")).is_empty(), "personal_event_episode_attribution")
	var technical := ["observed_position", "target_position", "no_progress_seconds", "collision", "collider", "velocity"]
	var leaks := false
	for key in technical:
		if JSON.stringify(event).contains(key):
			leaks = true
	for digit in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "(", ")", "[", "]"]:
		if text.contains(digit):
			leaks = true
	_check(not leaks, "personal_event_leaked_technical_detail")
	var expected_event_keys: Array = ["actor_id", "episode_id", "event_id", "material", "operation_id", "recipient_ids", "seq", "source", "source_id", "text", "type"]
	var missing_keys := 0
	for expected_key in expected_event_keys:
		if not event.has(expected_key):
			missing_keys += 1
	var extra_keys := 0
	for own_key in event.keys():
		if own_key not in expected_event_keys:
			extra_keys += 1
	_check(missing_keys == 0 and extra_keys == 0, "personal_event_extra_fields:missing=%d extra=%d" % [missing_keys, extra_keys])
	_check(personal_json.contains(BLOCKED_EVENT), "personal_view_missing_observation")
	# The resident keeps its own attributed observation (including the opaque episode
	# id); the GM-only measurements and the diagnostics projection stay out.
	var gm_only := ["no_progress_seconds", "observed_position", "target_position", "remaining_distance", "progress_evidence", "blocked_material_diagnostics"]
	var gm_leak := false
	for key in gm_only:
		if personal_json.contains(key):
			gm_leak = true
	_check(not gm_leak, "personal_view_leaked_gm_fields")
	_check(diagnostics.size() == 1, "gm_diagnostic_count")
	var diagnostic: Dictionary = diagnostics[0] if diagnostics.size() == 1 else {}
	_check(str(diagnostic.get("world_id", "")) == "fixture:town-trade-validation", "gm_world_id")
	_check(str(diagnostic.get("resident_id", "")) == SMITH and str(diagnostic.get("job_command_id", "")) == "fixture:blocked-open", "gm_ids")
	_check(str(diagnostic.get("episode_id", "")) == str(episode.get("episode_id", "")), "gm_episode_id")
	_check(str(diagnostic.get("source_id", "")) == SOURCE_ID and str(diagnostic.get("material", "")) == "iron", "gm_source")
	_check(str(diagnostic.get("status", "")) == "open" and int(diagnostic.get("report_count", 0)) == 1, "gm_dedup")
	_check(float(diagnostic.get("remaining_distance", -1.0)) > Runtime.MATERIAL_ARRIVAL_RADIUS, "gm_remaining_distance")
	_check(diagnostic.get("progress_evidence", {}).has("observed_position") and diagnostic.get("progress_evidence", {}).has("target_position") and float(diagnostic.get("progress_evidence", {}).get("no_progress_seconds", 0.0)) >= Runtime.MATERIAL_BLOCKED_NO_PROGRESS_SECONDS, "gm_progress_evidence")
	# A later duplicate observation may not re-issue the personal event or the issue.
	var dup_start := Time.get_ticks_msec()
	_scene.paused = false
	while Time.get_ticks_msec() - dup_start < 6000:
		await physics_frame
		await process_frame
	_scene.paused = true
	_check(_blocked_event_count() == 1, "duplicate_personal_event")
	_check(_scene.town.blocked_material_diagnostics().size() == 1, "duplicate_gm_issue")
	_check(not _scene.town.pending_job(SMITH).is_empty(), "duplicate_closed_job")
	_check(_conservation() == before, "blocked_conservation_changed")
	# New persisted fields are validated, not trusted: each tamper must be rejected.
	var tamper_labels := ["missing_event", "duplicate_event", "open_without_reason", "unreported_open", "command_mismatch", "missing_job", "wrong_resident", "episode_mismatch", "report_count", "bad_sequence", "duplicate_episode_id", "event_of_other_episode"]
	for label in tamper_labels:
		var tampered: Dictionary = _scene.town.snapshot()
		var record: Dictionary = {}
		var record_key := ""
		for candidate_key in tampered.godot.materials.blocked:
			var candidate: Dictionary = tampered.godot.materials.blocked[candidate_key]
			if str(candidate.get("command_id", "")) == "fixture:blocked-open" and candidate.get("status") == "open":
				record = candidate
				record_key = str(candidate_key)
				break
		match label:
			"missing_event":
				var kept: Array = []
				for candidate_event in tampered.life.events:
					if candidate_event.get("type") != BLOCKED_EVENT:
						kept.append(candidate_event)
				tampered.life.events = kept
			"duplicate_event":
				for candidate_event in tampered.life.events:
					if candidate_event.get("type") == BLOCKED_EVENT:
						tampered.life.events.append(candidate_event.duplicate(true))
						break
			"open_without_reason":
				record.closed_reason = "progress_resumed"
			"unreported_open":
				record.reported = false
			"command_mismatch":
				record.command_id = "fixture:other-command"
			"missing_job":
				tampered.godot.materials.jobs.erase(SMITH)
			"wrong_resident":
				record.resident_id = INNKEEPER
			"episode_mismatch":
				record.episode_id = "material_blocked:elsewhere"
			"report_count":
				record.status = "closed"
			"bad_sequence":
				tampered.godot.materials.blocked_seq = -1
			"duplicate_episode_id":
				tampered.godot.materials.blocked[record_key + ":copy"] = record.duplicate(true)
			"event_of_other_episode":
				for candidate_event in tampered.life.events:
					if candidate_event.get("type") == BLOCKED_EVENT:
						candidate_event.episode_id = "material_blocked:elsewhere:elsewhere:99"
						break
		_check(not _scene.town._validate_state(tampered).ok, "blocked_tamper_accepted:" + label)
	var summary := {"scenario": "blocked-enclosed", "wall_ms_to_report": observed.wall_ms,
		"no_progress_seconds": episode.no_progress_seconds, "opened_elapsed": episode.opened_elapsed,
		"stall_displacement": stall_displacement, "personal_text": text, "personal_event_keys": event.keys(),
		"diagnostics": diagnostics, "samples": observed.samples,
		"before_threshold_reported": false, "conserved": _conservation() == before}
	# Cold restart on a byte-exact copy: the episode and its personal fact persist
	# once, and a fresh scene may not re-issue either.
	var bytes := _read_bytes(_save_path)
	_scene.town.release_writer(_writer_path)
	_scene.queue_free()
	await process_frame
	await process_frame
	summary["saved_bytes_sha_len"] = bytes.size()
	summary["smith_iron_before"] = smith_iron_before
	# Older-save compatibility: the same world with the blocked projection absent
	# must still load and expose no episode or GM issue.
	var legacy_path := _save_path + ".legacy.json"
	var legacy_world: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if not _check(legacy_world is Dictionary, "legacy_parse_failed"):
		return
	legacy_world.godot.materials.erase("blocked")
	legacy_world.godot.materials.erase("blocked_seq")
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	if not _check(legacy_file != null, "legacy_write_failed"):
		return
	legacy_file.store_string(JSON.stringify(legacy_world))
	legacy_file.close()
	var legacy: RefCounted = Runtime.new()
	var legacy_loaded: Dictionary = legacy.load_from(legacy_path)
	_check(legacy_loaded.get("ok", false), "legacy_load_failed")
	_check(legacy.blocked_material_diagnostics().is_empty(), "legacy_gm_diagnostic")
	_check(legacy.blocked_material_episode(SMITH).is_empty(), "legacy_episode_present")
	# Second older shape: blocked present but the episode sequence field absent.
	var prior_shape_path := _save_path + ".prior.json"
	var prior_world: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	var prior_shape_ok := false
	if _check(prior_world is Dictionary, "prior_shape_parse_failed"):
		prior_world.godot.materials.erase("blocked_seq")
		var prior_file := FileAccess.open(prior_shape_path, FileAccess.WRITE)
		if _check(prior_file != null, "prior_shape_write_failed"):
			prior_file.store_string(JSON.stringify(prior_world))
			prior_file.close()
			var prior: RefCounted = Runtime.new()
			prior_shape_ok = bool(prior.load_from(prior_shape_path).get("ok", false))
	_check(prior_shape_ok, "prior_shape_load_failed")
	summary["legacy_without_blocked_key"] = {"loaded": legacy_loaded.get("ok", false), "code": legacy_loaded.get("code", ""), "prior_shape_loaded": prior_shape_ok}
	if not await _restart_phase(bytes, summary):
		_result = summary
		return
	_result = summary

func _restart_phase(bytes: PackedByteArray, summary: Dictionary) -> bool:
	var copy := FileAccess.open(_restart_path, FileAccess.WRITE)
	if copy == null:
		_fail("restart_copy_open_failed")
		return false
	copy.store_buffer(bytes)
	copy.close()
	if not _check(_read_bytes(_restart_path) == bytes, "restart_copy_bytes_mismatch"):
		return false
	var cold: RefCounted = Runtime.new()
	var loaded: Dictionary = cold.load_from(_restart_path)
	if not _check(loaded.get("ok", false), "restart_load_failed"):
		return false
	var cold_episode: Dictionary = cold.blocked_material_episode(SMITH)
	var cold_diagnostics: Array = cold.blocked_material_diagnostics()
	var cold_job: Dictionary = cold.pending_job(SMITH)
	var cold_world: Dictionary = cold.snapshot()
	var cold_events := 0
	for event in cold_world.life.events:
		if event.get("type") == BLOCKED_EVENT:
			cold_events += 1
	var cold_iron := -1
	for account in cold_world.life.accounts:
		if account.get("resident_id") == SMITH:
			cold_iron = int(account.get("iron", -1))
	_check(str(cold_episode.get("episode_id", "")) == str(summary.diagnostics[0].episode_id if summary.diagnostics.size() == 1 else ""), "restart_episode_lost")
	_check(cold_diagnostics.size() == 1, "restart_diagnostic_count")
	_check(cold_events == 1, "restart_personal_event_count")
	_check(not cold_job.is_empty() and str(cold_job.get("command_id", "")) == "fixture:blocked-open", "restart_job_lost")
	_check(cold_iron == int(summary.smith_iron_before) and int(cold_world.godot.materials.sources[SOURCE_ID].stock) == 3, "restart_resources_changed")
	_check(cold_world.life.contracts.is_empty(), "restart_contracts_changed")
	cold.release_writer(_restart_path)
	# Fresh scene on the same save: no re-issue, and the resident stays schedulable.
	if not await _load_scene(_save_path):
		return false
	await _add_fixture_obstacles(true)
	var restart_start := Time.get_ticks_msec()
	_scene.paused = false
	while Time.get_ticks_msec() - restart_start < 8000:
		await physics_frame
		await process_frame
	_scene.paused = true
	_check(_blocked_event_count() == 1, "restart_reissued_personal_event")
	_check(_scene.town.blocked_material_diagnostics().size() == 1, "restart_reissued_gm_issue")
	_check(not _scene.town.pending_job(SMITH).is_empty(), "restart_job_missing")
	var turns: Node = Turns.new()
	_turns = turns
	_turns.town = _scene.town
	_turns.save_path = _writer_path
	_controller = FixtureController.new()
	_controller.preference = "wait"
	root.add_child(_controller)
	_turns.brains[SMITH] = _controller
	root.add_child(_turns)
	summary["restart"] = {"episode": cold_episode, "diagnostics": cold_diagnostics.size(), "events": cold_events,
		"pending_elapsed": float(cold_job.get("elapsed", -1.0))}
	if not _check(_turns.ready_resident() == SMITH, "blocked_resident_not_schedulable"):
		return false
	var state_before_turns := _conservation()
	var wait_result: Dictionary = await _turns.step(SMITH)
	_check(wait_result.get("ok", false), "wait_turn_failed")
	_check(str(wait_result.get("record", {}).get("action", "")) == "wait", "wait_alias_not_selected")
	_check(str(_controller.selected) != "", "fixture_controller_alias_empty")
	_check(not _scene.town.pending_job(SMITH).is_empty(), "wait_dropped_pending_job")
	_check(not _scene.town.blocked_material_episode(SMITH).is_empty(), "wait_cleared_episode")
	_check(_blocked_event_count() == 1, "wait_created_event")
	_check(_turns.ready_resident() != SMITH, "wait_allowed_immediate_busy_loop")
	_check(_conservation() == state_before_turns, "wait_changed_state")
	summary["wait_turn"] = {"ok": wait_result.get("ok", false), "action": str(wait_result.get("record", {}).get("action", "")),
		"schedulable_after": _turns.ready_resident() == SMITH}
	# The resident now explicitly cancels that one still-pending trip.
	_controller.preference = "cancel"
	var cancel_result: Dictionary = await _turns.step(SMITH)
	var cancel_record: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	var cancel_command := str(cancel_record.get("request_id", ""))
	var materials: Dictionary = _scene.town.snapshot().godot.materials
	var original: Dictionary = materials.commands.get("fixture:blocked-open", {})
	var closed_episode: Dictionary = {}
	for candidate in materials.get("blocked", {}).values():
		if str(candidate.get("command_id", "")) == "fixture:blocked-open" and str(candidate.get("status", "")) == "closed":
			closed_episode = candidate
	_check(cancel_result.get("ok", false), "cancel_turn_failed")
	_check(str(cancel_result.get("record", {}).get("action", "")) == "material:cancel:fixture:blocked-open", "cancel_alias_not_selected")
	var cancel_events := 0
	for event in _scene.town.snapshot().life.events:
		if event.get("type") == CANCEL_EVENT and event.get("actor_id") == SMITH:
			cancel_events += 1
	_check(cancel_events == 1, "cancel_personal_event_count")
	_check(str(original.get("status", "")) == "rejected", "original_command_not_terminal")
	_check(str(original.get("result", {}).get("code", "")) == "material_cancelled", "original_receipt_code")
	_check(int(original.get("result", {}).get("quantity", -1)) == 0 and not original.get("result", {}).get("ok", true), "original_receipt_transferred")
	_check(_scene.town.pending_job(SMITH).is_empty(), "cancel_kept_job")
	_check(_scene.town.blocked_material_episode(SMITH).is_empty(), "cancel_kept_episode_open")
	_check(str(closed_episode.get("closed_reason", "")) == "resident_cancelled" and str(closed_episode.get("cancel_command_id", "")) == cancel_command, "cancel_episode_record")
	_check(_scene.town.blocked_material_diagnostics().is_empty(), "cancel_left_gm_issue")
	_check(_blocked_event_count() == 1, "cancel_changed_personal_history")
	_check(_conservation() == state_before_turns, "cancel_changed_resources")
	_check(_turns.ready_resident() != SMITH, "cancel_allowed_immediate_busy_loop")
	# The author's next personal projection must read both actions truthfully.
	var cancel_feedback: Array = _turns._feedback_history(SMITH, _scene.town._state.godot.resident_turns.get(SMITH, {}))
	var cancel_projection: Dictionary = cancel_feedback[-1].get("result", {}) if not cancel_feedback.is_empty() else {}
	_check(not cancel_projection.is_empty() and bool(cancel_projection.get("ok", false)), "cancel_turn_feedback_not_success:" + JSON.stringify(cancel_projection))
	_check(str(cancel_projection.get("target_command_id", "")) == "fixture:blocked-open" and int(cancel_projection.get("quantity", -1)) == 0, "cancel_turn_feedback_attribution")
	var trip_feedback: Array = _turns._feedback_history(SMITH, {"history": [{"command_id": "fixture:blocked-open", "status": "settled"}]})
	var trip_projection: Dictionary = trip_feedback[0].get("result", {}) if not trip_feedback.is_empty() else {}
	_check(not bool(trip_projection.get("ok", true)) and str(trip_projection.get("code", "")) == "material_cancelled", "original_trip_feedback_not_failure:" + JSON.stringify(trip_projection))
	var options: Array = _scene.town.trade_options(SMITH)
	var cancel_offered := false
	var recover_offered := false
	for option in options:
		if str(option.get("id", "")).begins_with("material:cancel:"):
			cancel_offered = true
		if str(option.get("id", "")) == "material:recover:" + SOURCE_ID:
			recover_offered = true
	_check(not cancel_offered, "stale_cancel_still_offered")
	_check(recover_offered, "next_choices_missing")
	# Duplicate cancel replay of the same turn command changes nothing.
	var duplicate: Dictionary = _scene.town.transaction(_writer_path, func(): return _scene.town.submit_trade(SMITH, "material:cancel:fixture:blocked-open", cancel_command, "opengameagent_fixture"))
	_check(duplicate.get("duplicate", false) and duplicate.get("ok", false), "duplicate_cancel_not_deduplicated")
	_check(_conservation() == state_before_turns, "duplicate_cancel_changed_state")
	# A replaced trip cannot inherit the old episode's cancel or diagnostic.
	_check(_submit_job("fixture:blocked-open-2"), "stale_replacement_submit_failed")
	var stale_cancel := false
	for option in _scene.town.trade_options(SMITH):
		if str(option.get("id", "")).begins_with("material:cancel:"):
			stale_cancel = true
	_check(not stale_cancel, "stale_episode_offered_cancel")
	_check(_scene.town.blocked_material_episode(SMITH).is_empty(), "stale_episode_reused")
	_check(_scene.town.blocked_material_diagnostics().is_empty(), "stale_episode_diagnostic")
	_check(str(closed_episode.get("closed_reason", "")) == "resident_cancelled", "cancel_history_erased")
	# The replacement trip now runs on REAL physics: closed history must survive,
	# the new trip must get its own episode, and every save must stay valid.
	var replacement_start := Time.get_ticks_msec()
	_scene.paused = false
	var save_paused := false
	var replacement_episode: Dictionary = {}
	var saved_closed_reason := ""
	while Time.get_ticks_msec() - replacement_start < 16000:
		await physics_frame
		await process_frame
		if _scene.paused:
			save_paused = true
			break
		if replacement_episode.is_empty():
			replacement_episode = _scene.town.blocked_material_episode(SMITH)
	_scene.paused = true
	if saved_closed_reason.is_empty():
		for candidate in _town_blocked_records("fixture:blocked-open"):
			saved_closed_reason = str(candidate.get("closed_reason", ""))
	_check(not save_paused, "replacement_observation_save_failed")
	_check(not str(_scene.latest).begins_with("保存失败"), "replacement_scene_reported_save_failure")
	_check(saved_closed_reason == "resident_cancelled", "closed_history_rewritten_by_later_ticks")
	_check(not replacement_episode.is_empty(), "replacement_episode_missing")
	_check(str(replacement_episode.get("episode_id", "")) != str(closed_episode.get("episode_id", "")), "replacement_reused_closed_episode_id")
	_check(str(replacement_episode.get("command_id", "")) == "fixture:blocked-open-2", "replacement_episode_command")
	_check(len(_town_blocked_events("fixture:blocked-open-2")) == 1, "replacement_episode_event_count")
	var replacement_bytes := _read_bytes(_save_path)
	var reloaded: RefCounted = Runtime.new()
	var reload_ok: Dictionary = reloaded.load_from(_save_path)
	_check(reload_ok.get("ok", false), "replacement_reload_failed")
	if reload_ok.get("ok", false):
		_check(len(reloaded.blocked_material_diagnostics()) == 1, "replacement_reload_diagnostics")
		var reloaded_records: Dictionary = reloaded.snapshot().godot.materials.get("blocked", {})
		var closed_kept := false
		for candidate in reloaded_records.values():
			if str(candidate.get("command_id", "")) == "fixture:blocked-open" and str(candidate.get("closed_reason", "")) == "resident_cancelled":
				closed_kept = true
		_check(closed_kept, "replacement_reload_lost_closed_history")
		_check(int(reloaded.snapshot().godot.materials.get("blocked_seq", 0)) >= 2, "replacement_sequence")
	_check(replacement_bytes.size() > 0, "replacement_bytes_empty")
	summary["cancel_turn"] = {"ok": cancel_result.get("ok", false), "action": str(cancel_result.get("record", {}).get("action", "")),
		"cancel_command": cancel_command, "original_receipt": original.get("result", {}), "episode": closed_episode,
		"duplicate": duplicate, "next_options": options.size(), "recover_offered": recover_offered}
	summary["replacement_trip"] = {"episode": replacement_episode, "closed_reason": saved_closed_reason,
		"save_paused": save_paused, "events": len(_town_blocked_events("fixture:blocked-open-2"))}
	return true

# World-to-GM evidence bridge scenario: one real scene run produces one blocked
# travel issue plus one validated capability proposal, both exported through the
# explicit read-only snapshot for a separate GM process.
func _scenario_gm_evidence() -> void:
	var primary := _gm_export_dir + "/gm-evidence-primary.json"
	var secondary := _gm_export_dir + "/gm-evidence-secondary.json"
	var tertiary := _gm_export_dir + "/gm-evidence-inactive.json"
	# The scene is launched with the real --town-gm-export flag: the file must update
	# from the committed world/turn flow without any manual exporter call.
	if not await _load_scene(_save_path):
		return
	if not _check(FileAccess.file_exists(primary), "gm_flag_export_missing"):
		return
	var baseline := _read_export(primary)
	_check(int(baseline.get("counts", {}).get("issues", -1)) == 0 and int(baseline.get("counts", {}).get("proposals", -1)) == 0, "gm_startup_not_baseline:" + JSON.stringify(baseline.get("counts", {})))
	await _unpause_for(1200)
	if not _check(_scene.town.resident_view(SMITH).material_sources.size() > 0, "gm_source_not_observed"):
		return
	await _add_fixture_obstacles(true)
	if not _submit_job("fixture:gm-open"):
		return
	var observed: Dictionary = await _blocked_open(40000)
	if not _check(not observed.episode.is_empty(), "gm_issue_missing"):
		_result = {"scenario": "gm-evidence", "observed": observed}
		return
	var episode_id := str(observed.episode.get("episode_id", ""))
	# The blockage reached the FILE during physics, with no manual export call.
	var after_blockage := _read_export(primary)
	var blocked_evidence := _first_entry(after_blockage.get("evidence", []))
	_check(int(after_blockage.get("counts", {}).get("issues", -1)) == 1 and str(blocked_evidence.get("issue_id", "")) == episode_id, "gm_physics_export_missing_issue")
	_check(str(_scene.gm_export_status).begins_with("GM证据已更新"), "gm_export_status_not_surfaced:" + str(_scene.gm_export_status))
	# Timer-only advance must not rewrite or re-date the export.
	var stable_bytes := _read_bytes(primary)
	await _unpause_for(4000)
	_check(_read_bytes(primary) == stable_bytes, "gm_timer_only_rewrite")
	_check(int(_read_export(primary).get("counts", {}).get("issues", -1)) == 1, "gm_timer_only_issue_lost")
	# A real apply_reply need reaches the same file through the turn flow.
	_controller = FixtureController.new()
	_controller.preference = "wait"
	_controller.private_reason = "PRIVATE_DELIBERATION_TEXT"
	_controller.need = {"capability_id": "iron_source_waypoint", "reason": "NEED_REASON_TEXT"}
	root.add_child(_controller)
	var innkeeper_controller := FixtureController.new()
	innkeeper_controller.preference = "wait"
	innkeeper_controller.private_reason = "PRIVATE_DELIBERATION_TEXT"
	root.add_child(innkeeper_controller)
	_turns = Turns.new()
	_turns.town = _scene.town
	_turns.save_path = _writer_path
	_turns.brains[SMITH] = _controller
	_turns.brains[INNKEEPER] = innkeeper_controller
	root.add_child(_turns)
	_scene.model_turns = _turns
	await _scene._run_model_turn(SMITH)
	var turn_one: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	var record_one: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	var request_one := str(record_one.get("request_id", ""))
	_check(str(turn_one.get("status", "")) == "settled", "gm_turn_failed:" + str(turn_one.get("status", "")))
	_check(str(record_one.get("need_status", "")) == "capability_proposed", "gm_need_not_recorded:" + str(record_one.get("need_status", "")))
	var after_turn_one := _read_export(primary)
	var proposal_one := _first_entry(after_turn_one.get("proposals", []))
	_check(int(after_turn_one.get("counts", {}).get("proposals", -1)) == 1, "gm_turn_export_missing_proposal")
	_check(str(proposal_one.get("capability_id", "")) == "iron_source_waypoint" and str(proposal_one.get("first", {}).get("reason", "")) == "NEED_REASON_TEXT" and str(proposal_one.get("first", {}).get("request_id", "")) == request_one and str(proposal_one.get("latest", {}).get("request_id", "")) == request_one and int(proposal_one.get("occurrences", 0)) == 1, "gm_proposal_content")
	# Canonical private journal keeps the exact accepted need and its attribution.
	var journal_one: Array = _need_entries(record_one)
	_check(journal_one.size() == 1 and str(journal_one[0].get("need", {}).get("capability_id", "")) == "iron_source_waypoint" and str(journal_one[0].get("need", {}).get("reason", "")) == "NEED_REASON_TEXT" and str(journal_one[0].get("need_request_id", "")) == request_one and int(journal_one[0].get("need_controller_epoch", -1)) == 0 and int(journal_one[0].get("need_source_sequence", -1)) > 0, "gm_canonical_need_missing")
	# Replaying the identical accepted reply must not duplicate or rewrite anything.
	var save_before_replay := _read_bytes(_writer_path)
	var export_before_replay := _read_bytes(primary)
	var replay: Dictionary = _turns.apply_reply(SMITH, 0, request_one, _controller.last_reply)
	_check(replay.get("duplicate", false), "gm_duplicate_reply_not_deduplicated")
	_check(_read_bytes(_writer_path) == save_before_replay and _read_bytes(primary) == export_before_replay, "gm_duplicate_reply_changed_state")
	# A later accepted turn with changed content aggregates without rewriting originals.
	_controller.need = {"capability_id": "iron_source_waypoint", "reason": "NEED_REASON_TEXT_TWO"}
	await _scene._run_model_turn(SMITH)
	var turn_two: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	var record_two: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	var request_two := str(record_two.get("request_id", ""))
	_check(str(turn_two.get("status", "")) == "settled" and request_two != request_one, "gm_second_turn_failed")
	var journal_two: Array = _need_entries(record_two)
	_check(journal_two.size() == 2, "gm_canonical_need_loss:" + str(journal_two.size()))
	var after_turn_two := _read_export(primary)
	var proposal_two := _first_entry(after_turn_two.get("proposals", []))
	_check(int(after_turn_two.get("counts", {}).get("proposals", -1)) == 1 and int(proposal_two.get("occurrences", 0)) == 2, "gm_proposal_no_aggregate")
	_check(str(proposal_two.get("first", {}).get("reason", "")) == "NEED_REASON_TEXT" and str(proposal_two.get("first", {}).get("request_id", "")) == request_one, "gm_proposal_original_rewritten")
	_check(str(proposal_two.get("latest", {}).get("request_id", "")) == request_two and str(proposal_two.get("latest", {}).get("reason", "")) == "NEED_REASON_TEXT_TWO", "gm_proposal_latest_missing")
	# The ACTUALLY prepared NPC context for this ordinary turn — not a lower-level view —
	# must still carry the personal consequence, the previous choice and the resident's
	# OWN authored intention text, without the GM/developer source metadata. The
	# canonical journal above keeps that metadata intact.
	var canonical_first: Dictionary = _need_entries(record_two)[0]
	var prepared_memory: Array = _controller.last_view.get("memory", {}).get("previous_decisions", [])
	var prepared_text := JSON.stringify(prepared_memory)
	_check(prepared_memory.size() == 1 and prepared_memory[0].get("result") is Dictionary and prepared_memory[0].get("result").has("code"), "gm_context_lost_personal_consequence:" + prepared_text)
	_check(str(prepared_memory[0].get("action", "")) == str(canonical_first.get("action", "")) and str(prepared_memory[0].get("command_id", "")) == request_one and str(prepared_memory[0].get("model_choice", "")) == str(canonical_first.get("model_choice", "")) and str(prepared_memory[0].get("status", "")) == str(canonical_first.get("status", "")), "gm_context_lost_previous_choice:" + prepared_text)
	_check(str(prepared_memory[0].get("need", {}).get("reason", "")) == "NEED_REASON_TEXT" and prepared_memory[0].get("need").keys() == ["reason"], "gm_context_lost_own_intention:" + prepared_text)
	_check(not prepared_text.contains("capability_id") and not prepared_text.contains("need_request_id") and not prepared_text.contains("need_controller_epoch") and not prepared_text.contains("need_source_sequence"), "gm_context_developer_metadata:" + prepared_text)
	_check(not prepared_text.contains("proposal_id") and not prepared_text.contains("need_status") and not prepared_text.contains("background_gm"), "gm_context_gm_metadata:" + prepared_text)
	_check(str(canonical_first.get("need", {}).get("capability_id", "")) == "iron_source_waypoint" and str(canonical_first.get("need_request_id", "")) == request_one, "gm_context_canonical_history_altered")
	# Invalid proposals and stale replies cannot create work or provenance.
	var before_invalid := _read_bytes(primary)
	_controller.need = {"capability_id": "Bad Id!", "reason": "y"}
	await _scene._run_model_turn(SMITH)
	_check(str(_scene.town._state.godot.resident_turns.get(SMITH, {}).get("need_status", "")) == "invalid_capability_need", "gm_invalid_capability_recorded")
	_controller.need = {"capability_id": "valid_id", "reason": "   "}
	await _scene._run_model_turn(SMITH)
	_controller.need = "not-a-dictionary"
	await _scene._run_model_turn(SMITH)
	var record_after_invalid: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	_check(str(record_after_invalid.get("need_status", "")) == "invalid_capability_need", "gm_invalid_shape_recorded")
	_check(_need_entries(record_after_invalid).size() == 2, "gm_invalid_acquired_provenance")
	var stale_request := str(record_after_invalid.get("request_id", ""))
	var stale: Dictionary = _turns.apply_reply(SMITH, 99, stale_request, _controller.last_reply)
	_check(not stale.get("ok", true) and str(stale.get("code", "")) == "stale_controller_reply", "gm_stale_reply_accepted")
	_check(_read_bytes(primary) == before_invalid and _need_entries(record_after_invalid).size() == 2, "gm_invalid_changed_export_or_history")
	# A rejected provider reply cannot acquire proposal provenance either. It uses a
	# third resident so the acting resident stays schedulable for the cancel turn.
	var carpenter_controller := FixtureController.new()
	carpenter_controller.preference = "wait"
	carpenter_controller.need = {"capability_id": "never_proposed", "reason": "provider failure must not propose"}
	carpenter_controller.fail_response = true
	root.add_child(carpenter_controller)
	_turns.brains[CARPENTER] = carpenter_controller
	await _scene._run_model_turn(CARPENTER)
	var record_after_error: Dictionary = _scene.town._state.godot.resident_turns.get(CARPENTER, {})
	_check(str(record_after_error.get("status", "")) == "provider_error", "gm_provider_error_not_quarantined")
	_check(_need_entries(record_after_error).is_empty() and int(_read_export(primary).get("counts", {}).get("proposals", -1)) == 1, "gm_provider_error_acquired_provenance")
	# A second resident's proposal reaches the same file (subject for inactivity below).
	innkeeper_controller.need = {"capability_id": "innkeeper_lantern", "reason": "INNKEEPER_NEED_TEXT"}
	await _scene._run_model_turn(INNKEEPER)
	var innkeeper_turn: Dictionary = _scene.town._state.godot.resident_turns.get(INNKEEPER, {})
	var innkeeper_record: Dictionary = _scene.town._state.godot.resident_turns.get(INNKEEPER, {})
	_check(str(innkeeper_turn.get("status", "")) == "settled" and str(innkeeper_record.get("need_status", "")) == "capability_proposed", "gm_second_resident_need_missing")
	_check(int(_read_export(primary).get("counts", {}).get("proposals", -1)) == 2, "gm_second_proposal_missing")
	# Closing the issue must reach the file as well.
	_controller.fail_response = false
	_controller.need = null
	_controller.preference = "cancel"
	var cancel_result: Dictionary = await _scene._run_model_turn(SMITH)
	var cancel_turn: Dictionary = _scene.town._state.godot.resident_turns.get(SMITH, {})
	var cancel_episode: Dictionary = {}
	for candidate in _town_blocked_records("fixture:gm-open"):
		cancel_episode = candidate
	_check(str(cancel_episode.get("closed_reason", "")) == "resident_cancelled" and str(cancel_turn.get("status", "")) == "settled", "gm_cancel_turn_failed:" + str(cancel_episode.get("closed_reason", "")) + ":" + JSON.stringify(_turns.last_result))
	# A normal no-need turn keeps the canonical journal and the personal projection
	# intact: need_absent is reported, nothing new is projected, and the resident still
	# remembers its own earlier intentions without any GM/developer metadata.
	_check(str(cancel_turn.get("need_status", "")) == "need_absent", "gm_no_need_turn_status:" + str(cancel_turn.get("need_status", "")))
	_check(_need_entries(cancel_turn).size() == 2, "gm_no_need_turn_changed_journal:" + str(_need_entries(cancel_turn).size()))
	var no_need_memory: Array = _controller.last_view.get("memory", {}).get("previous_decisions", [])
	var no_need_text := JSON.stringify(no_need_memory)
	var projected_needs := 0
	var projection_shape_ok := true
	for decision in no_need_memory:
		if not decision.get("result") is Dictionary or not str(decision.get("command_id", "")).begins_with("turn:"):
			projection_shape_ok = false
		if decision.get("need", null) is Dictionary:
			projected_needs += 1
			if decision.need.keys() != ["reason"]:
				projection_shape_ok = false
	_check(projected_needs == 2 and projection_shape_ok, "gm_no_need_context_projection:" + no_need_text)
	_check(no_need_text.contains("NEED_REASON_TEXT") and no_need_text.contains("NEED_REASON_TEXT_TWO") and not no_need_text.contains("capability_id") and not no_need_text.contains("need_request_id") and not no_need_text.contains("proposal_id") and not no_need_text.contains("need_status"), "gm_no_need_context_metadata:" + no_need_text)
	var after_cancel := _read_export(primary)
	_cancel_diag = {"record_status": str(cancel_turn.get("status", "")), "closed_reason": str(cancel_episode.get("closed_reason", "")),
		"blocked_records": _town_blocked_records("fixture:gm-open").size(), "export_counts": after_cancel.get("counts", {}),
		"last_result": _turns.last_result, "cancel_result": cancel_result, "export_status": gm_export_status_for_test()}
	_check(int(after_cancel.get("counts", {}).get("issues", -1)) == 0 and int(after_cancel.get("counts", {}).get("proposals", -1)) == 2, "gm_resolution_not_exported:" + JSON.stringify(after_cancel.get("counts", {})))
	# Explicit host export stays available and matches the automatic file.
	var save_before_manual := _read_bytes(_writer_path)
	_scene.gm_export_path = secondary
	var manual: Dictionary = _scene.write_gm_evidence_export()
	_check(manual.get("ok", false), "gm_manual_export_failed")
	var manual_payload := _read_export(secondary)
	_check(int(manual_payload.get("counts", {}).get("issues", -1)) == int(after_cancel.get("counts", {}).get("issues", -1)) and int(manual_payload.get("counts", {}).get("proposals", -1)) == int(after_cancel.get("counts", {}).get("proposals", -1)), "gm_manual_export_differs")
	_check(_read_bytes(_writer_path) == save_before_manual, "gm_export_touched_source_save")
	# A configured export failure must be inspectable in real startup/tick execution on
	# the small existing host status line, must never relabel the older file as current,
	# and must not rewrite anything on every half-second tick. The world save path is a
	# deterministic failure: it conflicts with the writer lock this scene holds.
	_check(str(_scene.gm_export_status).begins_with("GM证据已更新"), "gm_export_status_not_displayed:" + str(_scene.gm_export_status))
	_check(str(_scene.status.text).contains("GM证据已更新"), "gm_export_status_not_in_hud")
	var primary_before_failure := _read_bytes(primary)
	_scene.gm_export_path = _writer_path
	await _unpause_for(1200)
	_check(str(_scene.gm_export_status).begins_with("GM证据导出失败") and str(_scene.gm_export_status).contains("conflicts"), "gm_failed_export_not_surfaced:" + str(_scene.gm_export_status))
	_check(str(_scene.status.text).contains("GM证据导出失败"), "gm_failed_export_not_in_hud:" + str(_scene.status.text))
	_check(_read_bytes(primary) == primary_before_failure, "gm_failed_export_rewrote_older_file")
	await _unpause_for(1200)
	_check(str(_scene.gm_export_status).contains("沿用旧文件"), "gm_failed_export_relabelled_as_current:" + str(_scene.gm_export_status))
	_check(_read_bytes(primary) == primary_before_failure, "gm_stale_export_rewrote_older_file")
	_scene.gm_export_path = primary
	var retry: Dictionary = _scene.write_gm_evidence_export()
	_check(retry.get("ok", false) and str(_scene.gm_export_status).begins_with("GM证据已更新"), "gm_explicit_retry_not_recovered:" + str(_scene.gm_export_status))
	_check(int(_read_export(primary).get("counts", {}).get("proposals", -1)) == 2, "gm_explicit_retry_lost_proposals")
	var export_text := _read_bytes(primary).get_string_from_utf8()
	_check(not export_text.contains("PRIVATE_DELIBERATION_TEXT") and export_text.contains("NEED_REASON_TEXT") and export_text.contains("INNKEEPER_NEED_TEXT"), "gm_export_private_reason_leak")
	_check(not export_text.contains("experiences") and not export_text.contains("inventory") and not export_text.contains("我没能到达"), "gm_export_contains_npc_context")
	_check(not _read_export(primary).get("evidence", []).size() > 0, "gm_closed_issue_still_exported")
	var personal := JSON.stringify(_scene.town.resident_view(SMITH))
	var other_personal := JSON.stringify(_scene.town.resident_view(INNKEEPER))
	_check(not personal.contains("background_gm") and not personal.contains("capability_id") and not personal.contains("proposal_id") and not personal.contains("need_status"), "gm_fields_in_personal_view")
	_check(not personal.contains("NEED_REASON_TEXT") and not other_personal.contains("NEED_REASON_TEXT") and not other_personal.contains("iron_source_waypoint"), "gm_proposal_broadcast_to_npcs")
	var proposals_before_reload: Array = _read_export(primary).get("proposals", [])
	# Fresh-object cold reload: one proposal per resident, original sources intact.
	var bytes := _read_bytes(_writer_path)
	_scene.town.release_writer(_writer_path)
	_scene.queue_free()
	await process_frame
	await process_frame
	_scene = null
	var cold: RefCounted = Runtime.new()
	var reload_ok: Dictionary = cold.load_from(_writer_path)
	_check(reload_ok.get("ok", false), "gm_reload_failed:" + JSON.stringify(reload_ok))
	var cold_snapshot: Dictionary = cold.background_gm_snapshot()
	_check(int(cold_snapshot.get("counts", {}).get("proposals", -1)) == 2 and int(cold_snapshot.get("counts", {}).get("issues", -1)) == 0, "gm_reload_counts")
	var cold_smith := _entry_by_id(cold_snapshot.get("proposals", []), "resident_id", SMITH)
	_check(str(cold_smith.get("proposal_id", "")) == str(_entry_by_id(proposals_before_reload, "resident_id", SMITH).get("proposal_id", "")) and int(cold_smith.get("occurrences", 0)) == 2 and str(cold_smith.get("first", {}).get("request_id", "")) == request_one and str(cold_smith.get("first", {}).get("reason", "")) == "NEED_REASON_TEXT" and str(cold_smith.get("latest", {}).get("request_id", "")) == request_two and str(cold_smith.get("latest", {}).get("reason", "")) == "NEED_REASON_TEXT_TWO", "gm_reload_proposal_not_one")
	var cold_bytes_before := _read_bytes(_writer_path)
	var cold_export: Dictionary = cold.write_background_gm_snapshot(tertiary)
	_check(cold_export.get("ok", false) and int(cold_export.get("proposals", 0)) == 2, "gm_cold_export_failed:" + JSON.stringify(cold_export))
	_check(_read_bytes(_writer_path) == cold_bytes_before and _read_bytes(_writer_path) == bytes, "gm_cold_export_touched_source_save")
	# A pre-bridge save has no projection at all and must still load unchanged; the
	# bridge adds evidence only, never a compatibility break for older worlds.
	var legacy_path := _save_path + ".legacy.json"
	var legacy_world: Variant = cold._parse_json_text(FileAccess.get_file_as_string(_writer_path))
	var legacy_ok := _check(legacy_world is Dictionary, "gm_legacy_parse_failed")
	if legacy_ok:
		legacy_world.godot.erase("background_gm")
		var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
		if _check(legacy_file != null, "gm_legacy_write_failed"):
			legacy_file.store_string(JSON.stringify(legacy_world, "", true, true))
			legacy_file.close()
			var legacy: RefCounted = Runtime.new()
			var legacy_loaded: Dictionary = legacy.load_from(legacy_path)
			_check(legacy_loaded.get("ok", false), "gm_legacy_save_rejected:" + JSON.stringify(legacy_loaded))
			_check(int(legacy.background_gm_snapshot().get("counts", {}).get("proposals", -1)) == 0, "gm_legacy_save_invented_projection")
	# Historical evidence survives its resident becoming inactive. The town has no
	# general deactivation flow, so this is tested directly against the proposal
	# validator with a stable identity the world no longer drives: the candidate state
	# drops that resident's live activity while its canonical accepted need stays.
	# No original history is deleted to build this fixture.
	var inactive_path := _save_path + ".inactive.json"
	var inactive_world: Variant = cold._parse_json_text(FileAccess.get_file_as_string(_writer_path))
	var inactive_ok := _check(inactive_world is Dictionary, "gm_inactive_parse_failed")
	if inactive_ok:
		for key in ["positions", "homes", "observations"]:
			inactive_world.godot[key].erase(INNKEEPER)
		var remaining: Array = []
		for account in inactive_world.survival.accounts:
			if account.get("resident_id") != INNKEEPER:
				remaining.append(account)
		inactive_world.survival.accounts = remaining
		inactive_world.godot.materials.known.erase(INNKEEPER)
		var kept_commands: Dictionary = {}
		for cid in inactive_world.godot.trade.commands:
			if str(inactive_world.godot.trade.commands[cid].get("payload", {}).get("actor_id", "")) != INNKEEPER:
				kept_commands[cid] = inactive_world.godot.trade.commands[cid]
		inactive_world.godot.trade.commands = kept_commands
		var inactive_file := FileAccess.open(inactive_path, FileAccess.WRITE)
		if _check(inactive_file != null, "gm_inactive_write_failed"):
			inactive_file.store_string(JSON.stringify(inactive_world, "", true, true))
			inactive_file.close()
			_check(not inactive_world.godot.positions.has(INNKEEPER), "gm_inactive_still_active")
			var inactive_valid: Dictionary = cold._validate_background_gm(inactive_world, inactive_world.godot)
			_check(inactive_valid.ok, "gm_inactive_proposal_rejected:" + str(inactive_valid.get("code", "")))
			var inactive_records: Array = []
			for key in inactive_world.godot.background_gm.proposals:
				inactive_records.append(inactive_world.godot.background_gm.proposals[key])
			var inactive_proposal := _entry_by_id(inactive_records, "resident_id", INNKEEPER)
			var expected_inactive := _entry_by_id(proposals_before_reload, "resident_id", INNKEEPER)
			_check(inactive_records.size() == 2 and str(inactive_proposal.get("proposal_id", "")) == str(expected_inactive.get("proposal_id", "")) and str(inactive_proposal.get("capability_id", "")) == "innkeeper_lantern" and str(inactive_proposal.get("reason", "")) == "INNKEEPER_NEED_TEXT" and str(inactive_proposal.get("latest_reason", "")) == "INNKEEPER_NEED_TEXT", "gm_inactive_history_lost")
			_check(JSON.stringify(inactive_world.godot.get("resident_turns", {}).get(INNKEEPER, {})).contains("innkeeper_lantern"), "gm_inactive_deleted_canonical_need")
			# The removed host-injection exception: a projection whose source was never
			# accepted must not validate, even with a stable identity and valid fields.
			var tampered: Variant = cold._parse_json_text(FileAccess.get_file_as_string(_writer_path))
			var tampered_key := str(inactive_proposal.get("proposal_id", ""))
			tampered.godot.background_gm.proposals[tampered_key].reason = "never accepted content"
			tampered.godot.background_gm.proposals[tampered_key].latest_reason = "never accepted content"
			var tampered_valid: Dictionary = cold._validate_background_gm(tampered, tampered.godot)
			_check(not tampered_valid.ok and str(tampered_valid.get("code", "")) == "background_gm_proposal_source_mismatch", "gm_invented_provenance_accepted:" + str(tampered_valid.get("code", "")))
	_result = {"scenario": "gm-evidence", "cancel": _cancel_diag, "issue_id": episode_id, "export_primary": primary, "export_secondary": secondary,
		"export_inactive": tertiary, "export_bytes": _read_bytes(primary).size(), "reload_ok": reload_ok.get("ok", false),
		"counts_after_cancel": after_cancel.get("counts", {}), "proposals": cold_snapshot.get("counts", {}).get("proposals", 0)}

func gm_export_status_for_test() -> String:
	var scene: Variant = _scene
	return str(scene.gm_export_status) if scene != null else ""

func _read_export(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _first_entry(entries: Array) -> Dictionary:
	return entries[0] if not entries.is_empty() and entries[0] is Dictionary else {}

func _entry_by_id(entries: Array, field: String, value: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str(entry.get(field, "")) == value:
			return entry
	return {}

func _need_entries(record: Dictionary) -> Array:
	var result: Array = []
	for entry in record.get("history", []):
		if not entry is Dictionary:
			continue
		var need_value: Variant = entry.get("need", null)
		if need_value is Dictionary:
			result.append(entry)
	return result

func _scenario_recurring_block() -> void:
	# One still-pending job: blocked -> genuine progress -> blocked again at
	# another obstacle, and the resident still gets a voluntary decision for the
	# SAME original trip instead of being permanently skipped.
	if not await _load_scene(_save_path):
		return
	await _unpause_for(1200)
	if not _check(_scene.town.resident_view(SMITH).material_sources.size() > 0, "recurring_source_not_observed"):
		return
	await _add_fixture_obstacles(true)
	if not _submit_job("fixture:recurring"):
		return
	var first: Dictionary = await _blocked_open(30000)
	if not _check(not first.episode.is_empty(), "recurring_first_episode_missing"):
		_result = {"scenario": "recurring-block", "first": first.episode}
		return
	var first_id := str(first.episode.get("episode_id", ""))
	# Labelled fixture relocation: the resident physically changes position (a real
	# movement observation), still unable to reach the enclosed source.
	var body: CharacterBody3D = _scene.bodies[SMITH]
	body.position = Vector3(0, 0.22, 6.5)
	body.velocity = Vector3.ZERO
	var moved: Dictionary = _scene.town.transaction(_writer_path, func():
		_scene.town.host_move(SMITH, Vector3(0, 0.22, 6.5))
		return {"ok": true, "code": "fixture_relocation"})
	if not _check(moved.get("ok", false), "recurring_relocation_failed"):
		return
	_scene.paused = false
	var second: Dictionary = {}
	var resume_seen := false
	var save_ok := true
	var start := Time.get_ticks_msec()
	var last_sample := 0
	while Time.get_ticks_msec() - start < 20000:
		await physics_frame
		await process_frame
		if _scene.paused:
			save_ok = false
			break
		var now := Time.get_ticks_msec() - start
		if now - last_sample < 250:
			continue
		last_sample = now
		for record in _town_blocked_records("fixture:recurring"):
			if str(record.get("episode_id", "")) == first_id and str(record.get("closed_reason", "")) == "progress_resumed":
				resume_seen = true
		if second.is_empty():
			var candidate: Dictionary = _scene.town.blocked_material_episode(SMITH)
			if not candidate.is_empty() and str(candidate.get("episode_id", "")) != first_id:
				second = candidate
		if resume_seen and not second.is_empty():
			break
	_scene.paused = true
	var first_record: Dictionary = {}
	for record in _town_blocked_records("fixture:recurring"):
		if str(record.get("episode_id", "")) == first_id:
			first_record = record
	var events_for_job := _town_blocked_events("fixture:recurring")
	_check(save_ok, "recurring_save_failed")
	_check(resume_seen and str(first_record.get("closed_reason", "")) == "progress_resumed", "recurring_progress_not_recorded")
	_check(not second.is_empty(), "recurring_second_episode_missing")
	_check(not str(second.get("episode_id", "")).is_empty() and str(second.get("episode_id", "")) != first_id, "recurring_episode_id_reused")
	_check(str(second.get("command_id", "")) == "fixture:recurring" and str(second.get("status", "")) == "open", "recurring_second_not_open_same_job")
	_check(events_for_job.size() == 2 and str(events_for_job[0].get("episode_id", "")) != str(events_for_job[1].get("episode_id", "")), "recurring_personal_facts")
	_check(not _scene.town.pending_job(SMITH).is_empty(), "recurring_job_lost")
	# Future choices must not be permanently skipped for the same original job.
	_controller = FixtureController.new()
	root.add_child(_controller)
	_turns = Turns.new()
	_turns.town = _scene.town
	_turns.save_path = _writer_path
	_turns.brains[SMITH] = _controller
	root.add_child(_turns)
	_check(_turns.ready_resident() == SMITH, "recurring_resident_not_schedulable")
	var offered := false
	for option in _scene.town.trade_options(SMITH):
		if str(option.get("id", "")) == "material:cancel:fixture:recurring":
			offered = true
	_check(offered, "recurring_cancel_not_offered")
	_controller.preference = "cancel"
	var decision: Dictionary = await _turns.step(SMITH)
	var final_materials: Dictionary = _scene.town.snapshot().godot.materials
	var receipt: Dictionary = final_materials.commands.get("fixture:recurring", {}).get("result", {})
	var closed_second: Dictionary = {}
	for record in _town_blocked_records("fixture:recurring"):
		if str(record.get("episode_id", "")) == str(second.get("episode_id", "")):
			closed_second = record
	_check(decision.get("ok", false), "recurring_cancel_turn_failed")
	_check(str(receipt.get("code", "")) == "material_cancelled" and int(receipt.get("quantity", -1)) == 0, "recurring_cancel_receipt")
	_check(str(closed_second.get("closed_reason", "")) == "resident_cancelled" and str(first_record.get("closed_reason", "")) == "progress_resumed", "recurring_episode_outcomes")
	_check(events_for_job.size() == 2, "recurring_events_after_cancel")
	var bytes := _read_bytes(_save_path)
	var reloaded: RefCounted = Runtime.new()
	var reload_ok: Dictionary = reloaded.load_from(_save_path)
	_check(reload_ok.get("ok", false), "recurring_reload_failed")
	_result = {"scenario": "recurring-block", "first_episode_id": first_id, "second_episode_id": str(second.get("episode_id", "")),
		"first_closed_reason": str(first_record.get("closed_reason", "")), "second_closed_reason": str(closed_second.get("closed_reason", "")),
		"events": events_for_job.size(), "receipt": receipt, "schedulable": _turns.ready_resident() == SMITH,
		"reload_ok": reload_ok.get("ok", false), "bytes": bytes.size()}

func _scenario_detour() -> void:
	if not await _load_scene(_save_path):
		return
	await _unpause_for(1200)
	if not _check(_scene.town.resident_view(SMITH).material_sources.size() > 0, "detour_source_not_observed"):
		return
	await _add_fixture_obstacles(false)
	# H24 resume pose: the resident is already standing against the crate, the
	# pose in which the accepted H24 steering actually detours.
	var pose := Vector3(0, 0.22, 6.5)
	var body: CharacterBody3D = _scene.bodies[SMITH]
	body.position = pose
	body.velocity = Vector3.ZERO
	var moved: Dictionary = _scene.town.transaction(_writer_path, func():
		_scene.town.host_move(SMITH, pose)
		return {"ok": true, "code": "fixture_relocation"})
	if not _check(moved.get("ok", false), "detour_relocation_failed"):
		return
	if not _submit_job("fixture:detour"):
		return
	var before := _conservation()
	var smith_iron_before := _smith_iron()
	var max_x := 0.0
	_scene.paused = false
	var start := Time.get_ticks_msec()
	var reported_while_travelling := false
	while Time.get_ticks_msec() - start < 90000:
		await physics_frame
		await process_frame
		max_x = maxf(max_x, absf(_body_position().x))
		if not _scene.town.blocked_material_episode(SMITH).is_empty():
			reported_while_travelling = true
		if _scene.town.pending_job(SMITH).is_empty():
			break
	_scene.paused = true
	var world: Dictionary = _scene.town.snapshot()
	var receipt: Dictionary = world.godot.materials.commands.get("fixture:detour", {}).get("result", {})
	var stock := int(world.godot.materials.sources[SOURCE_ID].stock)
	var iron := _smith_iron()
	var after := _conservation()
	_result = {"scenario": "detour-crate", "detour_x": max_x, "reported_while_travelling": reported_while_travelling,
		"blocked_events": _blocked_event_count(), "receipt": receipt, "stock": stock, "iron": iron,
		"wall_ms": Time.get_ticks_msec() - start, "coins_conserved": after.coins == before.coins}
	_check(not reported_while_travelling and _blocked_event_count() == 0, "detour_reported_blocked")
	_check(max_x > 0.7, "detour_did_not_detour")
	_check(str(receipt.get("code", "")) == "material_recovered" and int(receipt.get("quantity", 0)) == 1, "detour_no_recovery")
	_check(stock == before.stock - 1 and iron == smith_iron_before + 1, "detour_material_not_transferred")
	_check(after.stock + after.iron == before.stock + before.iron, "detour_material_not_conserved")
	_check(after.coins == before.coins, "detour_coins_changed")

func _write_output() -> void:
	var payload := {"mode": "offline_fixture_blocked_material_probe", "scenario": _scenario, "checks": _checks,
		"failures": _failures, "failure_count": _failures.size(), "paid_kimi_calls": 0,
		"fixture_controller": {"deterministic": true, "network_calls": 0, "calls": 0 if _controller == null else _controller.calls},
		"threshold_seconds": Runtime.MATERIAL_BLOCKED_NO_PROGRESS_SECONDS, "result": _result}
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file == null:
		_failures.append("output_write_failed")
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

func _finish() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.paused = true
		if _scene.town != null and is_instance_valid(_scene.town):
			_scene.town.release_writer(_scene._save_path)
		_scene.queue_free()
	if _runtime != null and _writer_held:
		_runtime.release_writer(_save_path)
		_writer_held = false
	await process_frame
	_write_output()
	print(JSON.stringify({"scenario": _scenario, "checks": _checks, "failure_count": _failures.size(), "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)

func _run() -> void:
	_parse_args()
	if _failures.is_empty():
		if _validate_paths():
			if _copy_fixture() and _prepare_world(_save_path):
				match _scenario:
					"paused-enclosed":
						await _scenario_paused_enclosed()
					"at-target":
						await _scenario_at_target()
					"blocked-enclosed":
						await _scenario_blocked_enclosed()
					"detour-crate":
						await _scenario_detour()
					"recurring-block":
						await _scenario_recurring_block()
					"gm-evidence":
						await _scenario_gm_evidence()
	await _finish()

func _initialize() -> void:
	_run.call_deferred()
