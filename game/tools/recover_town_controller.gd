extends RefCounted
class_name TownControllerRecovery

const Runtime := preload("res://core/town_runtime.gd")
const Turns := preload("res://agents/town_turns.gd")
const Brain := preload("res://agents/resident_brain.gd")

static func recover(owner: Node, town_save: String, resident: String, expected_request: String, expected_rule_error: String = "") -> Dictionary:
	if town_save.is_empty() or resident.is_empty() or expected_request.is_empty():
		return {"ok": false, "code": "missing_recovery_argument"}
	var town := Runtime.new()
	var locked: Dictionary = town.acquire_writer(town_save)
	if not locked.ok:
		return locked
	var loaded: Dictionary = town.load_from(town_save)
	if not loaded.ok:
		town.release_writer(town_save)
		return loaded
	var record: Dictionary = town._state.godot.get("resident_turns", {}).get(resident, {})
	if record.is_empty():
		town.release_writer(town_save)
		return {"ok": false, "code": "resident_turn_not_found", "resident": resident}
	var controller_id := "host:recovery:" + (resident + "|" + expected_request).sha256_text()
	if record.get("controller_id", "") == controller_id:
		town.release_writer(town_save)
		return {"ok": true, "duplicate": true, "code": "host_recovery_already_applied", "controller_id": controller_id,
			"epoch": int(record.get("controller_epoch", 0))}
	if record.get("request_id", "") != expected_request:
		town.release_writer(town_save)
		return {"ok": false, "code": "stale_request", "expected_request": expected_request,
			"actual_request": record.get("request_id", "")}
	if record.get("status", "") == "pending" or record.get("inflight", false):
		town.release_writer(town_save)
		return {"ok": false, "code": "request_inflight"}
	var reviewed_rule_error: bool = record.get("status") == "rule_rejection" and not expected_rule_error.is_empty() and record.get("result", {}).get("code") == expected_rule_error
	if record.get("status", "") != "provider_error" and not reviewed_rule_error:
		town.release_writer(town_save)
		return {"ok": false, "code": "not_provider_error", "status": record.get("status", "")}
	if town.has_method("pending_job") and not town.pending_job(resident).is_empty():
		town.release_writer(town_save)
		return {"ok": false, "code": "resident_working"}
	if not owner or not is_instance_valid(owner):
		town.release_writer(town_save)
		return {"ok": false, "code": "invalid_owner"}

	var turns := Turns.new()
	owner.add_child(turns)
	turns.town = town
	turns.save_path = town_save
	var brain := Brain.new()
	brain.configure("gateway")
	var connected: Dictionary = await turns.connect_controller(resident, brain, controller_id)
	if not connected.ok:
		brain.free()
		turns.free()
		town.release_writer(town_save)
		return connected
	turns.free()
	town.release_writer(town_save)
	return {"ok": true, "code": "host_recovery_recorded", "controller_id": controller_id,
		"epoch": int(connected.get("epoch", 0))}
