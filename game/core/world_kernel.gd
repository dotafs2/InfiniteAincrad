extends RefCounted

# This is a deliberately small, offline fixture kernel.  It has no model or
# script execution path: a resident policy can choose only validated actions.

const STATE_VERSION := 1
const WORLD_ID := "fixture:well-street"
const RESIDENT_ID := "fixture:luna"
const RESIDENT_NAME := "Luna (test resident)"
const MIRA_RESIDENT_ID := "fixture:mira"
const MIRA_RESIDENT_NAME := "Mira (test resident)"
const CAPABILITY_ID := "well_bucket"
const CAPABILITY_VERSION := "1.0.0"
const LOCK_SUFFIX := ".writer-lock"
const ALLOWED_DECISION_PROVENANCE := ["local_rule_policy", "opengameagent_fixture", "opengameagent_live"]
const MAX_COMMAND_ID_LENGTH := 128
const MAX_PROVENANCE_LENGTH := 64
const MAX_ACTION_LENGTH := 32
const MAX_REASON_LENGTH := 512
const MAX_CAPABILITY_ID_LENGTH := 128

var _state: Dictionary = {}
var _writer_lock_path := ""

func _init() -> void:
	_state = {}

func create_fixture() -> Dictionary:
	_state = {
		"state_version": STATE_VERSION,
		"world_id": WORLD_ID,
		"fixture": true,
		"turn": 0,
		"world": {
			"well_water": 1,
			"well_capacity": 1,
			"gm_resources": {"rope": 1, "bucket": 1},
			"gm_budget": 0
		},
		"residents": {
			RESIDENT_ID: {
				"identity": {"id": RESIDENT_ID, "name": RESIDENT_NAME},
				"observations": ["I can see a public well nearby, but I cannot safely draw its water."],
				"needs": {"thirst": 80, "capability_request": null},
				"experiences": [],
				"actions": [],
				"memory": {"last_action": "created", "water_drawn": 0, "water_drunk": 0},
				"inventory": {"water": 0},
				"consumed": {"water": 0}
			}
		},
		"plugins": {},
		"events": [],
		"receipts": {},
		"command_payloads": {},
		"gm_reviews": {},
		"install_history": {}
	}
	return {"ok": true, "code": "fixture_created", "world_id": WORLD_ID, "fixture": true}

func add_fixture_visitor(command_id: String) -> Dictionary:
	var payload := {"kind": "add_fixture_visitor", "resident_id": MIRA_RESIDENT_ID}
	var prior := _check_duplicate(command_id, payload)
	if not prior.is_empty():
		return prior
	var command_check := _validate_decision_command_id(command_id)
	if not command_check.ok:
		return command_check
	if not _state.has("residents") or not _state.residents.has(RESIDENT_ID):
		return {"ok": false, "code": "save_resident_missing"}
	if _state.residents.has(MIRA_RESIDENT_ID):
		return _record_command(command_id, payload, {"ok": true, "code": "fixture_visitor_exists", "resident_id": MIRA_RESIDENT_ID})
	_state.residents[MIRA_RESIDENT_ID] = _new_fixture_visitor()
	return _record_command(command_id, payload, {"ok": true, "code": "fixture_visitor_added", "resident_id": MIRA_RESIDENT_ID, "name": MIRA_RESIDENT_NAME})

func _new_fixture_visitor() -> Dictionary:
	return {
		"identity": {"id": MIRA_RESIDENT_ID, "name": MIRA_RESIDENT_NAME},
		"observations": ["I am standing on the street."],
		"needs": {"thirst": 80, "capability_request": null},
		"experiences": [],
		"actions": [],
		"memory": {"last_action": "created", "water_drawn": 0, "water_drunk": 0},
		"inventory": {"water": 0},
		"consumed": {"water": 0}
	}

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func resident_view(resident_id: String = RESIDENT_ID) -> Dictionary:
	if not _resident_exists(resident_id):
		return {}
	var resident: Dictionary = _state.residents[resident_id]
	return {
		"identity": resident.identity.duplicate(true),
		"observations": resident.observations.duplicate(true),
		"needs": resident.needs.duplicate(true),
		"experiences": resident.experiences.duplicate(true),
		"memory": resident.memory.duplicate(true),
		"inventory": resident.inventory.duplicate(true),
		"actions": resident.actions.duplicate(true),
		"available_actions": _available_actions_from_resident(resident)
	}

func resident_observation_snapshot(resident_id: String = RESIDENT_ID) -> Dictionary:
	var view: Dictionary = resident_view(resident_id)
	return {"ok": not view.is_empty(), "schema_version": 1, "resident_view": view, "provenance": "fixture_resident_observation"}

func resident_decision_request(resident_id: String = RESIDENT_ID) -> Dictionary:
	return resident_observation_snapshot(resident_id)

func submit_resident_decision(decision: Dictionary, command_id: String, provenance: String = "local_rule_policy", resident_id: String = RESIDENT_ID) -> Dictionary:
	if not _resident_exists(resident_id):
		return {"ok": false, "code": "resident_unknown", "resident_id": resident_id}
	var payload := {"kind": "resident_decision", "resident_id": resident_id, "decision": decision.duplicate(true), "provenance": provenance}
	var prior := _check_duplicate(command_id, payload)
	if not prior.is_empty():
		return prior
	var command_check := _validate_decision_command_id(command_id)
	if not command_check.ok:
		return command_check
	var provenance_check := _validate_decision_provenance(provenance)
	if not provenance_check.ok:
		return provenance_check
	var decision_check := _validate_resident_decision(decision)
	if not decision_check.ok:
		return decision_check
	var action: String = decision.action
	var action_check := _resident_action_preflight(action, resident_id)
	if not action_check.ok:
		return action_check

	# All validation and resource checks happen before advancing the world turn.
	# The only remaining operations below are the validated, single-writer commit.
	_state.turn = int(_state.turn) + 1
	var resident: Dictionary = _state.residents[resident_id]
	if decision.has("need") and resident.needs.capability_request == null:
		resident.needs.capability_request = {"need_id": "need-%d" % _state.turn, "capability_id": decision.need.capability_id, "reason": decision.need.reason, "status": "open", "created_turn": _state.turn}
		_state.events.append({"turn": _state.turn, "type": "resident_need_recorded", "resident_id": resident_id, "need_id": resident.needs.capability_request.need_id, "provenance": provenance})
	var result: Dictionary
	if action == "wait":
		resident.actions.append({"turn": _state.turn, "action": "wait", "provenance": provenance, "reason": decision.get("reason", "")})
		resident.memory.last_action = "wait"
		result = {"ok": true, "code": "resident_need_recorded" if decision.has("need") else "resident_waited", "action": "wait", "provenance": provenance, "turn": _state.turn}
	else:
		result = _execute_resident_action(action, provenance, command_id, resident_id)
	return _record_command(command_id, payload, result)

func _validate_decision_command_id(command_id: String) -> Dictionary:
	if typeof(command_id) != TYPE_STRING or command_id.is_empty() or command_id.length() > MAX_COMMAND_ID_LENGTH:
		return {"ok": false, "code": "command_id_required"}
	return {"ok": true, "code": "command_id_valid"}

func _validate_decision_provenance(provenance: String) -> Dictionary:
	if typeof(provenance) != TYPE_STRING or provenance.is_empty() or provenance.length() > MAX_PROVENANCE_LENGTH or not ALLOWED_DECISION_PROVENANCE.has(provenance):
		return {"ok": false, "code": "decision_provenance_invalid"}
	return {"ok": true, "code": "decision_provenance_valid"}

func _validate_resident_decision(decision: Dictionary) -> Dictionary:
	if typeof(decision) != TYPE_DICTIONARY or not decision.has("action"):
		return {"ok": false, "code": "decision_fields_invalid"}
	for key in decision.keys():
		if not ["action", "reason", "need"].has(str(key)):
			return {"ok": false, "code": "decision_fields_invalid", "field": str(key)}
	if typeof(decision.action) != TYPE_STRING or decision.action.is_empty() or decision.action.length() > MAX_ACTION_LENGTH or not ["wait", "draw_water", "drink_water"].has(decision.action):
		return {"ok": false, "code": "decision_action_invalid"}
	if decision.has("reason") and (typeof(decision.reason) != TYPE_STRING or decision.reason.is_empty() or decision.reason.length() > MAX_REASON_LENGTH):
		return {"ok": false, "code": "decision_reason_invalid"}
	if decision.has("need"):
		if decision.action != "wait" or typeof(decision.need) != TYPE_DICTIONARY or not _exact_keys(decision.need, ["capability_id", "reason"]):
			return {"ok": false, "code": "decision_need_invalid"}
		if typeof(decision.need.capability_id) != TYPE_STRING or decision.need.capability_id.is_empty() or decision.need.capability_id.length() > MAX_CAPABILITY_ID_LENGTH:
			return {"ok": false, "code": "decision_need_invalid"}
		if typeof(decision.need.reason) != TYPE_STRING or decision.need.reason.is_empty() or decision.need.reason.length() > MAX_REASON_LENGTH:
			return {"ok": false, "code": "decision_need_invalid"}
	return {"ok": true, "code": "decision_valid"}

func _resident_action_preflight(action: String, resident_id: String = RESIDENT_ID) -> Dictionary:
	if action == "draw_water":
		if not _capability_enabled(CAPABILITY_ID):
			return {"ok": false, "code": "capability_unavailable", "action": action}
		if int(_state.world.well_water) <= 0:
			return {"ok": false, "code": "well_empty", "action": action}
	if action == "drink_water" and int(_state.residents[resident_id].inventory.water) <= 0:
		return {"ok": false, "code": "resident_has_no_water", "action": action}
	var view: Dictionary = resident_view(resident_id)
	if not view.available_actions.has(action):
		return {"ok": false, "code": "decision_action_unavailable", "action": action}
	return {"ok": true, "code": "resident_action_ready", "action": action}

func _available_actions_from_resident(resident: Dictionary) -> Array:
	var actions: Array = ["wait"]
	if int(resident.needs.get("thirst", 0)) > 0 and int(resident.inventory.get("water", 0)) > 0:
		actions.append("drink_water")
	for observation in resident.observations:
		if (str(observation).contains("working bucket") or str(observation).contains("there is a usable bucket")) and int(resident.needs.get("thirst", 0)) > 0 and _capability_enabled(CAPABILITY_ID) and int(_state.world.well_water) > 0:
			actions.append("draw_water")
			break
	return actions

func _resident_exists(resident_id: String) -> bool:
	return _state.has("residents") and _state.residents.has(resident_id) and resident_id in [RESIDENT_ID, MIRA_RESIDENT_ID]

func observe_well(resident_id: String, command_id: String) -> Dictionary:
	if not _resident_exists(resident_id):
		return {"ok": false, "code": "resident_unknown", "resident_id": resident_id}
	var payload := {"kind": "observe_well", "resident_id": resident_id}
	var prior := _check_duplicate(command_id, payload)
	if not prior.is_empty():
		return prior
	var command_check := _validate_decision_command_id(command_id)
	if not command_check.ok:
		return command_check
	var resident: Dictionary = _state.residents[resident_id]
	var observation := "I observe the public well: %s and %s." % ["there is a usable bucket" if _capability_enabled(CAPABILITY_ID) else "there is no usable bucket", "it has water" if int(_state.world.well_water) > 0 else "it has no water"]
	resident.observations.append(observation)
	resident.experiences.append({"turn": _state.turn, "event": "observed_well", "memory": observation, "provenance": "resident_observation"})
	return _record_command(command_id, payload, {"ok": true, "code": "well_observed", "resident_id": resident_id, "observation": observation})

func validate_manifest(manifest: Variant) -> Dictionary:
	return _validate_manifest(manifest)

func load_builtin_manifest() -> Dictionary:
	var file := FileAccess.open("res://capabilities/well_bucket.v1.json", FileAccess.READ)
	if file == null:
		return {"ok": false, "code": "manifest_missing"}
	var parsed = _parse_json_text(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": "manifest_json_invalid"}
	return _validate_manifest(parsed)

func resident_command(command: Dictionary) -> Dictionary:
	if typeof(command) != TYPE_DICTIONARY:
		return {"ok": false, "code": "command_invalid"}
	if command.has("resident_id") and command.resident_id != RESIDENT_ID:
		return {"ok": false, "code": "resident_identity_mismatch"}
	if command.has("role") or command.has("gm") or command.has("manifest"):
		return {"ok": false, "code": "resident_not_gm"}
	var allowed := {"command_id": true, "action": true}
	for key in command.keys():
		if not allowed.has(str(key)):
			return {"ok": false, "code": "command_field_not_allowed", "field": str(key)}
	if not command.has("command_id") or typeof(command.command_id) != TYPE_STRING or command.command_id.is_empty():
		return {"ok": false, "code": "command_id_required"}
	if not command.has("action") or typeof(command.action) != TYPE_STRING:
		return {"ok": false, "code": "action_required"}
	return submit_resident_decision({"action": command.action}, command.command_id)

func gm_review_need(command_id: String, decision: String, capability_id: String, reason: String) -> Dictionary:
	var payload := {"kind": "gm_review", "decision": decision, "capability_id": capability_id, "reason": reason}
	var prior := _check_duplicate(command_id, payload)
	if not prior.is_empty():
		return prior
	var resident: Dictionary = _state.residents[RESIDENT_ID]
	var need = resident.needs.get("capability_request", null)
	if need == null or need.status != "open":
		return {"ok": false, "code": "gm_need_missing"}
	if typeof(reason) != TYPE_STRING or reason.is_empty() or typeof(capability_id) != TYPE_STRING:
		return {"ok": false, "code": "gm_review_invalid"}
	if decision == "reject":
		need.status = "rejected"
		need.review_reason = reason
		_state.gm_reviews[command_id] = {"status": "rejected", "need_id": need.need_id, "capability_id": capability_id, "reason": reason}
		_state.events.append({"turn": _state.turn, "type": "gm_need_rejected", "need_id": need.need_id, "provenance": "gm_review"})
		return _record_command(command_id, payload, {"ok": true, "code": "gm_need_rejected", "need_id": need.need_id, "provenance": "gm_review"})
	if decision != "approve" or capability_id != need.capability_id:
		return {"ok": false, "code": "gm_review_capability_mismatch"}
	need.status = "approved"
	need.approval_id = command_id
	need.review_reason = reason
	_state.gm_reviews[command_id] = {"status": "approved", "need_id": need.need_id, "capability_id": capability_id, "reason": reason}
	_state.events.append({"turn": _state.turn, "type": "gm_need_approved", "need_id": need.need_id, "capability_id": capability_id, "provenance": "gm_review"})
	return _record_command(command_id, payload, {"ok": true, "code": "gm_need_approved", "need_id": need.need_id, "approval_id": command_id, "provenance": "gm_review"})

func gm_install(manifest: Dictionary, command_id: String, approval_id: String = "") -> Dictionary:
	var payload := {"kind": "gm_install", "manifest": manifest.duplicate(true), "approval_id": approval_id}
	var prior := _check_duplicate(command_id, payload)
	if not prior.is_empty():
		return prior
	if typeof(command_id) != TYPE_STRING or command_id.is_empty():
		return {"ok": false, "code": "command_id_required"}
	var valid := _validate_manifest(manifest)
	if not valid.ok:
		return valid
	if not _state.gm_reviews.has(approval_id) or _state.gm_reviews[approval_id].status != "approved" or _state.gm_reviews[approval_id].capability_id != manifest.capability_id:
		return {"ok": false, "code": "gm_approval_required"}
	if _state.plugins.has(CAPABILITY_ID) and _state.plugins[CAPABILITY_ID].status == "enabled":
		return {"ok": false, "code": "capability_already_enabled"}
	if _state.plugins.has(CAPABILITY_ID) and _state.plugins[CAPABILITY_ID].status == "disabled":
		_state.plugins[CAPABILITY_ID].status = "enabled"
		_state.events.append({"turn": _state.turn, "type": "capability_reenabled", "capability_id": CAPABILITY_ID, "provenance": "gm_validated_manifest"})
		return _record_command(command_id, payload, {"ok": true, "code": "capability_reenabled", "capability_id": CAPABILITY_ID, "version": CAPABILITY_VERSION, "provenance": "gm_validated_manifest"})
	var materials: Dictionary = manifest.install.materials
	for material in materials.keys():
		if int(_state.world.gm_resources.get(material, 0)) < int(materials[material]):
			return {"ok": false, "code": "gm_material_missing", "material": material}
	for material in materials.keys():
		_state.world.gm_resources[material] = int(_state.world.gm_resources[material]) - int(materials[material])
	_state.plugins[CAPABILITY_ID] = {
			"status": "enabled",
			"version": CAPABILITY_VERSION,
			"manifest": manifest.duplicate(true),
			"installed_by": "gm",
			"install_command_id": command_id
	}
	_state.residents[RESIDENT_ID].observations.append("I see a working bucket at the well; I can draw water when I am thirsty.")
	_state.residents[RESIDENT_ID].needs.capability_request.status = "fulfilled"
	_state.install_history[CAPABILITY_ID] = {"version": CAPABILITY_VERSION, "materials_consumed": materials.duplicate(true)}
	var result := {"ok": true, "code": "capability_installed", "capability_id": CAPABILITY_ID, "version": CAPABILITY_VERSION, "provenance": "gm_validated_manifest"}
	return _record_command(command_id, payload, result)

func gm_disable(command_id: String) -> Dictionary:
	var payload := {"kind": "gm_disable", "capability_id": CAPABILITY_ID}
	var prior := _check_duplicate(command_id, payload)
	if not prior.is_empty():
		return prior
	if typeof(command_id) != TYPE_STRING or command_id.is_empty():
		return {"ok": false, "code": "command_id_required"}
	if not _state.plugins.has(CAPABILITY_ID) or _state.plugins[CAPABILITY_ID].status != "enabled":
		var already := {"ok": true, "code": "capability_already_disabled", "capability_id": CAPABILITY_ID}
		return _record_command(command_id, payload, already)
	_state.plugins[CAPABILITY_ID].status = "disabled"
	_state.events.append({"turn": _state.turn, "type": "capability_disabled", "capability_id": CAPABILITY_ID})
	var result := {"ok": true, "code": "capability_disabled", "capability_id": CAPABILITY_ID}
	return _record_command(command_id, payload, result)

func resident_step() -> Dictionary:
	var request: Dictionary = resident_decision_request()
	if not request.ok:
		return request
	var view: Dictionary = request.resident_view
	var decision: Dictionary = {"action": "wait", "reason": "I cannot safely reach water."}
	if view.available_actions.has("drink_water"):
		decision = {"action": "drink_water", "reason": "I have water with me."}
	elif view.available_actions.has("draw_water"):
		decision = {"action": "draw_water", "reason": "I can see a working way to draw water."}
	elif int(view.needs.get("thirst", 0)) > 0 and view.needs.get("capability_request", null) == null:
		decision["need"] = {"capability_id": CAPABILITY_ID, "reason": "I am thirsty and can see water, but I cannot safely draw it."}
	return submit_resident_decision(decision, "resident-step-%d" % Time.get_ticks_usec())

func export_resident_decision_request(path: String) -> Dictionary:
	if typeof(path) != TYPE_STRING or path.is_empty():
		return {"ok": false, "code": "request_path_required"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "request_open_failed", "path": path}
	file.store_string(JSON.stringify(resident_decision_request()))
	file.flush()
	file.close()
	return {"ok": true, "code": "resident_decision_request_exported", "path": path, "provenance": "fixture_resident_observation"}

func save_to(path: String) -> Dictionary:
	if typeof(path) != TYPE_STRING or path.is_empty():
		return {"ok": false, "code": "save_path_required"}
	var owned_here := _writer_lock_path == _lock_path(path)
	if not owned_here:
		var lock_result := acquire_writer(path)
		if not lock_result.ok:
			return lock_result
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		if not owned_here:
			release_writer(path)
		return {"ok": false, "code": "save_temp_open_failed", "path": path}
	# Full precision is required for preserved source coordinates/timers/history.
	file.store_string(_serialize_state())
	file.flush()
	file.close()
	var marker_path := path + ".replace-pending"
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker == null:
		if not owned_here:
			release_writer(path)
		return {"ok": false, "code": "save_marker_failed", "path": path}
	marker.store_string(JSON.stringify({"target": path, "backup": path + ".bak", "temp": temp_path}))
	marker.flush()
	marker.close()
	var backup_path := path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(path):
		var moved_old := DirAccess.rename_absolute(path, backup_path)
		if moved_old != OK:
			DirAccess.remove_absolute(marker_path)
			DirAccess.remove_absolute(temp_path)
			if not owned_here:
				release_writer(path)
			return {"ok": false, "code": "save_backup_failed", "path": path}
	var moved_new := DirAccess.rename_absolute(temp_path, path)
	if moved_new != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_path, path)
		DirAccess.remove_absolute(temp_path)
		DirAccess.remove_absolute(marker_path)
		if not owned_here:
			release_writer(path)
		return {"ok": false, "code": "save_replace_failed", "path": path}
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	DirAccess.remove_absolute(marker_path)
	if not owned_here:
		release_writer(path)
	return {"ok": true, "code": "saved", "path": path, "state_version": STATE_VERSION}

func _serialize_state() -> String:
	return JSON.stringify(_state, "", true, true)

func load_from(path: String) -> Dictionary:
	if typeof(path) != TYPE_STRING or path.is_empty():
		return {"ok": false, "code": "save_path_required"}
	_recover_pending_save(path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "code": "save_missing", "path": path}
	var parsed = _parse_json_text(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": "save_json_invalid"}
	var checked := _validate_state(parsed)
	if not checked.ok:
		return checked
	_state = parsed.duplicate(true)
	return {"ok": true, "code": "loaded", "path": path, "state_version": STATE_VERSION, "world_id": WORLD_ID}

func _recover_pending_save(path: String) -> void:
	var marker_path := path + ".replace-pending"
	if not FileAccess.file_exists(marker_path):
		return
	var backup_path := path + ".bak"
	var temp_path := path + ".tmp"
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(backup_path, path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	if FileAccess.file_exists(backup_path) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(backup_path)
	DirAccess.remove_absolute(marker_path)

func acquire_writer(path: String) -> Dictionary:
	if typeof(path) != TYPE_STRING or path.is_empty():
		return {"ok": false, "code": "save_path_required"}
	var lock_path := _lock_path(path)
	if _writer_lock_path == lock_path:
		return {"ok": true, "code": "writer_lock_owned", "path": path}
	if DirAccess.dir_exists_absolute(lock_path) or FileAccess.file_exists(lock_path):
		return {"ok": false, "code": "writer_lock_busy", "path": path}
	var error := DirAccess.make_dir_absolute(lock_path)
	if error != OK:
		return {"ok": false, "code": "writer_lock_busy", "path": path}
	_writer_lock_path = lock_path
	return {"ok": true, "code": "writer_lock_acquired", "path": path}

func release_writer(path: String) -> Dictionary:
	var lock_path := _lock_path(path)
	if _writer_lock_path != lock_path:
		return {"ok": false, "code": "writer_lock_not_owned", "path": path}
	var error := DirAccess.remove_absolute(lock_path)
	if error != OK:
		return {"ok": false, "code": "writer_lock_release_failed", "path": path}
	_writer_lock_path = ""
	return {"ok": true, "code": "writer_lock_released", "path": path}

func _execute_resident_action(action: String, provenance: String, command_id: String, resident_id: String = RESIDENT_ID) -> Dictionary:
	var resident: Dictionary = _state.residents[resident_id]
	if action == "draw_water":
		if not _capability_enabled(CAPABILITY_ID):
			return {"ok": false, "code": "capability_unavailable", "action": action}
		if int(_state.world.well_water) <= 0:
			return {"ok": false, "code": "well_empty", "action": action}
		_state.world.well_water = int(_state.world.well_water) - 1
		resident.inventory.water = int(resident.inventory.water) + 1
		resident.memory.water_drawn = int(resident.memory.water_drawn) + 1
		resident.memory.last_action = action
		resident.actions.append({"turn": _state.turn, "action": action, "provenance": provenance})
		resident.experiences.append({"turn": _state.turn, "event": "drew_water", "memory": "The well bucket can provide water when the well has water."})
		_state.events.append({"turn": _state.turn, "type": "water_drawn", "resident_id": resident_id, "amount": 1, "provenance": provenance})
		return {"ok": true, "code": "water_drawn", "action": action, "amount": 1, "provenance": provenance, "command_id": command_id}
	if action == "drink_water":
		if int(resident.inventory.water) <= 0:
			return {"ok": false, "code": "resident_has_no_water", "action": action}
		resident.inventory.water = int(resident.inventory.water) - 1
		resident.consumed = resident.get("consumed", {"water": 0})
		resident.consumed.water = int(resident.consumed.get("water", 0)) + 1
		resident.needs.thirst = maxi(0, int(resident.needs.thirst) - 60)
		resident.memory.water_drunk = int(resident.memory.water_drunk) + 1
		resident.memory.last_action = action
		resident.actions.append({"turn": _state.turn, "action": action, "provenance": provenance})
		resident.experiences.append({"turn": _state.turn, "event": "drank_water", "memory": "Drinking water relieved thirst."})
		_state.events.append({"turn": _state.turn, "type": "water_consumed", "resident_id": resident_id, "amount": 1, "provenance": provenance})
		return {"ok": true, "code": "water_consumed", "action": action, "amount": 1, "provenance": provenance, "command_id": command_id}
	return {"ok": false, "code": "action_not_validated", "action": action}

func _capability_enabled(capability_id: String) -> bool:
	return _state.plugins.has(capability_id) and _state.plugins[capability_id].status == "enabled"

func _record_command(command_id: String, payload: Dictionary, result: Dictionary) -> Dictionary:
	if typeof(command_id) != TYPE_STRING or command_id.is_empty():
		return result
	var saved := result.duplicate(true)
	_state.receipts[command_id] = saved
	_state.command_payloads[command_id] = _canonical_json(payload)
	return saved

func _check_duplicate(command_id: String, payload: Dictionary) -> Dictionary:
	if typeof(command_id) != TYPE_STRING or command_id.is_empty():
		return {}
	if not _state.receipts.has(command_id):
		return {}
	var stored_payload := str(_state.command_payloads.get(command_id, ""))
	var expected := _canonical_json(payload)
	var legacy_expected := ""
	if payload.get("kind", "") == "resident_decision":
		var legacy_payload := payload.duplicate(true)
		legacy_payload.erase("provenance")
		legacy_expected = _canonical_json(legacy_payload)
	if stored_payload != expected and stored_payload != legacy_expected:
		return {"ok": false, "code": "command_id_payload_mismatch", "command_id": command_id}
	var prior: Dictionary = _state.receipts[command_id].duplicate(true)
	prior["duplicate"] = true
	return prior

func _validate_manifest(manifest: Variant) -> Dictionary:
	if typeof(manifest) != TYPE_DICTIONARY:
		return {"ok": false, "code": "manifest_invalid"}
	var expected := ["schema_version", "capability_id", "version", "world_id", "provenance", "actions", "install"]
	if not _exact_keys(manifest, expected):
		return {"ok": false, "code": "manifest_fields_invalid"}
	if manifest.schema_version != 1 or manifest.capability_id != CAPABILITY_ID or manifest.version != CAPABILITY_VERSION or manifest.world_id != WORLD_ID or manifest.provenance != "fixture":
		return {"ok": false, "code": "manifest_version_or_identity_invalid"}
	if typeof(manifest.actions) != TYPE_ARRAY or manifest.actions.size() != 1 or typeof(manifest.actions[0]) != TYPE_DICTIONARY:
		return {"ok": false, "code": "manifest_actions_invalid"}
	var action: Dictionary = manifest.actions[0]
	if not _exact_keys(action, ["id", "from", "to", "amount"]):
		return {"ok": false, "code": "manifest_action_fields_invalid"}
	if action.id != "draw_water" or action.from != "world.well_water" or action.to != "resident.inventory.water" or action.amount != 1:
		return {"ok": false, "code": "manifest_action_invalid"}
	if typeof(manifest.install) != TYPE_DICTIONARY or not _exact_keys(manifest.install, ["materials"]):
		return {"ok": false, "code": "manifest_install_invalid"}
	var materials = manifest.install.materials
	if typeof(materials) != TYPE_DICTIONARY or not _exact_keys(materials, ["rope", "bucket"]):
		return {"ok": false, "code": "manifest_materials_invalid"}
	if materials.rope != 1 or materials.bucket != 1:
		return {"ok": false, "code": "manifest_material_quantity_invalid"}
	return {"ok": true, "code": "manifest_valid", "capability_id": CAPABILITY_ID, "version": CAPABILITY_VERSION, "provenance": "fixture"}

func _validate_state(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY:
		return {"ok": false, "code": "save_state_invalid"}
	if candidate.get("state_version", -1) != STATE_VERSION:
		return {"ok": false, "code": "save_version_unsupported", "state_version": candidate.get("state_version", null)}
	if candidate.get("world_id", "") != WORLD_ID or candidate.get("fixture", false) != true:
		return {"ok": false, "code": "save_world_identity_invalid"}
	var required := ["state_version", "world_id", "fixture", "turn", "world", "residents", "plugins", "events", "receipts", "command_payloads", "gm_reviews", "install_history"]
	for key in required:
		if not candidate.has(key):
			return {"ok": false, "code": "save_field_missing", "field": key}
	if typeof(candidate.turn) not in [TYPE_INT, TYPE_FLOAT] or candidate.turn < 0:
		return {"ok": false, "code": "save_turn_invalid"}
	if typeof(candidate.world) != TYPE_DICTIONARY or not _valid_nonnegative(candidate.world.get("well_water", -1)) or not _valid_nonnegative(candidate.world.get("well_capacity", -1)) or typeof(candidate.world.get("gm_resources", null)) != TYPE_DICTIONARY:
		return {"ok": false, "code": "save_world_invalid"}
	for resource in ["rope", "bucket"]:
		if not _valid_nonnegative(candidate.world.gm_resources.get(resource, -1)):
			return {"ok": false, "code": "save_resource_invalid", "resource": resource}
	if typeof(candidate.residents) != TYPE_DICTIONARY or not candidate.residents.has(RESIDENT_ID):
		return {"ok": false, "code": "save_resident_missing"}
	for resident_id in candidate.residents.keys():
		if resident_id not in [RESIDENT_ID, MIRA_RESIDENT_ID]:
			return {"ok": false, "code": "save_resident_identity_invalid"}
		var resident = candidate.residents[resident_id]
		var expected_name := RESIDENT_NAME if resident_id == RESIDENT_ID else MIRA_RESIDENT_NAME
		if typeof(resident) != TYPE_DICTIONARY:
			return {"ok": false, "code": "save_resident_invalid"}
		for key in ["identity", "observations", "needs", "experiences", "actions", "memory", "inventory", "consumed"]:
			if not resident.has(key):
				return {"ok": false, "code": "save_resident_field_missing", "field": key}
		if resident.identity.get("id", "") != resident_id or resident.identity.get("name", "") != expected_name:
			return {"ok": false, "code": "save_resident_identity_invalid"}
		if not _valid_nonnegative(resident.needs.get("thirst", -1)) or not _valid_nonnegative(resident.inventory.get("water", -1)) or not _valid_nonnegative(resident.consumed.get("water", -1)):
			return {"ok": false, "code": "save_resident_quantity_invalid"}
	if typeof(candidate.plugins) != TYPE_DICTIONARY or typeof(candidate.events) != TYPE_ARRAY or typeof(candidate.receipts) != TYPE_DICTIONARY or typeof(candidate.command_payloads) != TYPE_DICTIONARY or typeof(candidate.gm_reviews) != TYPE_DICTIONARY or typeof(candidate.install_history) != TYPE_DICTIONARY:
		return {"ok": false, "code": "save_history_invalid"}
	return {"ok": true, "code": "save_state_valid"}

func _valid_nonnegative(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return float(value) >= 0.0 and not is_nan(float(value)) and not is_inf(float(value))

func _exact_keys(dictionary: Dictionary, keys: Array) -> bool:
	if dictionary.size() != keys.size():
		return false
	for key in keys:
		if not dictionary.has(key):
			return false
	return true

func _canonical_json(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var keys: Array = value.keys()
		keys.sort()
		var ordered := {}
		for key in keys:
			ordered[str(key)] = _canonical_value(value[key])
		return JSON.stringify(ordered)
	return JSON.stringify(_canonical_value(value))

func _canonical_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var keys: Array = value.keys()
		keys.sort()
		var ordered := {}
		for key in keys:
			ordered[str(key)] = _canonical_value(value[key])
		return ordered
	if typeof(value) == TYPE_ARRAY:
		var items: Array = []
		for item in value:
			items.append(_canonical_value(item))
		return items
	return value

func _lock_path(path: String) -> String:
	return path + LOCK_SUFFIX

func _parse_json_text(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data
