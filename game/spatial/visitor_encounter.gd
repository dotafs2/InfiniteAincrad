extends Node

# Optional encounter in the same street, kernel, writer lock and save.
# The engine delivers this observation only after physical arrival.
const VISITOR := "fixture:mira"
const DESTINATION := Vector3(3.3, 0.22, 2.1)
const START := Vector3(3.3, 0.22, -4.0)
var _street: Node
var _actor: Node3D
var _brain: Node
var _elapsed := 0.0
var _settled_at := -1.0
var _distance := 0.0
var _done := false
var _busy := false
var _capture_dir := ""
var _first_before: Dictionary
var _before: Dictionary
var _evidence := {"fixture": true, "decisions": 0, "errors": []}

func _ready() -> void:
	_street = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visitor-capture="):
			_capture_dir = arg.trim_prefix("--visitor-capture=")
			DirAccess.make_dir_recursive_absolute(_capture_dir)
	_before = _street._kernel.snapshot()
	_first_before = _before.get("residents", {}).get("fixture:luna", {}).duplicate(true)
	if not _street._loaded_existing or int(_first_before.get("consumed", {}).get("water", 0)) != 1:
		_fail("This encounter requires the existing completed street save.")
		return
	var existed: bool = _before.residents.has(VISITOR)
	var added: Dictionary = _street._kernel.add_fixture_visitor("visitor-arrival-1")
	if not added.get("ok", false):
		_fail("visitor_add_failed")
		return
	if not existed:
		_street._persist_world("visitor_arrived")
	var view: Dictionary = _street._kernel.resident_view(VISITOR)
	_evidence["before_observation"] = view.duplicate(true)
	_actor = load("res://spatial/trial_resident.gd").new()
	_street.add_child(_actor)
	_actor.position = START
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = Color("8e5143")
	_actor.get_node("OriginalResidentBody/Torso").material_override = shirt
	var tag := Label3D.new()
	tag.text = "Mira"
	tag.position.y = 1.95
	tag.font_size = 42
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_actor.add_child(tag)
	_brain = load("res://agents/resident_brain.gd").new()
	add_child(_brain)
	_brain.configure(_street._brain_mode)
	if not _capture_dir.is_empty():
		_street._player.position = Vector3(-2.8, 1.13, 6.1)
		_street._camera.look_at(Vector3(1.0, 1.0, 2.1), Vector3.UP)
	if not view.actions.is_empty():
		_actor.position = DESTINATION
		_done = true
		_settled_at = 0.0
		_evidence["restored"] = true
		_street._update_status("Mira：" + str(view.actions[-1].get("reason", "保留上次自己的决定。")))
	else:
		_street._update_status("Mira 走向井边；她还不知道这里发生过什么。")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 50.0 and not _capture_dir.is_empty():
		_fail("visitor_encounter_timeout")
		return
	if _busy:
		return
	if _done:
		if not _capture_dir.is_empty() and _elapsed - _settled_at >= 3.0:
			_finish.call_deferred()
			set_process(false)
		return
	var offset: Vector3 = DESTINATION - _actor.position
	if offset.length() > 0.08:
		var step: float = minf(offset.length(), delta * 2.2)
		_actor.position += offset.normalized() * step
		_actor.look_at(_actor.position + offset.normalized(), Vector3.UP)
		_actor.set_walking(true)
		_distance += step
		return
	_actor.set_walking(false)
	_busy = true
	var observed: Dictionary = _street._kernel.observe_well(VISITOR, "mira-observe-well-1")
	if not observed.get("ok", false):
		_fail("visitor_observe_failed")
		return
	_street._persist_world("visitor_observed_well")
	var personal: Dictionary = _street._kernel.resident_view(VISITOR)
	_evidence["after_observation"] = personal.duplicate(true)
	_evidence["observation_distance_m"] = _actor.position.distance_to(_street.WELL_POSITION)
	_evidence["decisions"] = 1
	var proposal: Dictionary = await _brain.propose(personal, int(_street._kernel.snapshot().turn))
	if not proposal.get("ok", false):
		_fail("visitor_model_failed:" + str(proposal.get("code", "unknown")))
		return
	var result: Dictionary = _street._kernel.submit_resident_decision(proposal.decision, proposal.command_id, proposal.provenance, VISITOR)
	if not result.get("ok", false):
		_fail("visitor_choice_rejected:" + str(result.get("code", "unknown")))
		return
	_evidence["decision"] = proposal.decision.duplicate(true)
	_evidence["provenance"] = proposal.provenance
	_street._persist_world("visitor_decided")
	_street._update_status("Mira：" + str(proposal.decision.get("reason", "我先等一等。")))
	_done = true
	_busy = false
	_settled_at = _elapsed

func _fail(reason: String) -> void:
	_evidence.errors.append(reason)
	_street._update_status(reason)
	_done = true
	_busy = false
	set_process(false)
	if not _capture_dir.is_empty():
		_finish.call_deferred()

func _finish() -> void:
	var after: Dictionary = _street._kernel.snapshot()
	var restored: bool = _evidence.get("restored", false)
	var visitor: Dictionary = after.get("residents", {}).get(VISITOR, {})
	var checks := {"no_errors": _evidence.errors.is_empty(),
		"first_resident_unchanged": after.get("residents", {}).get("fixture:luna", {}) == _first_before,
		"same_world": after.get("world_id") == _before.get("world_id"),
		"resources_unchanged": after.get("world") == _before.get("world"),
		"two_persistent_residents": after.get("residents", {}).size() == 2,
		"one_choice_or_stable_restore": _evidence.decisions == (0 if restored else 1),
		"visitor_choice_saved": visitor.get("actions", []).size() == 1}
	if restored:
		checks["restore_unchanged"] = after == _before
	else:
		checks["walked_before_observing"] = _distance > 5.0 and float(_evidence.get("observation_distance_m", 99.0)) < 3.0
		checks["no_imported_experience"] = _evidence.before_observation.experiences.is_empty() and _evidence.before_observation.actions.is_empty()
		checks["initially_no_well_action"] = _evidence.before_observation.available_actions == ["wait"]
	_evidence["checks"] = checks
	_evidence["passed"] = not checks.values().has(false)
	_evidence["walked_m"] = _distance
	_evidence["visitor_final"] = visitor
	if not _capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture_dir.path_join("visitor.png"))
		var file := FileAccess.open(_capture_dir.path_join("evidence.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(_evidence, "  "))
		file.close()
	print(JSON.stringify({"visitor_encounter_passed": _evidence.passed, "checks": checks}))
	get_tree().quit(0 if _evidence.passed else 1)
