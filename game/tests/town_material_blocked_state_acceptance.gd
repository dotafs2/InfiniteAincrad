extends "res://tests/town_materials_acceptance.gd"
## State-level acceptance for the blocked material travel chain: command journals,
## recurring episodes on one job, closed-history immutability and roster bounds.
## Offline world API only: no scene, no model call, clearly fictional fixture.

const STATE_SOURCE := "fixture:iron-source"
const TurnsScript = preload("res://agents/town_turns.gd")

var _path := ""

func _near_source(town, ids: Array) -> void:
	for id in ids:
		town.host_move(id, Vector3(0, 0, 3.5))

func _start_trip(town, id: String, command: String) -> void:
	var trip_command := command
	var started: Dictionary = town.transaction(_path, func(): return town.submit_trade(id, "material:recover:" + STATE_SOURCE, trip_command, "opengameagent_fixture"))
	check(started.ok, "trip started: " + command + " " + str(started.get("code", "")))
	var observed: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(id, Vector3(9, 0, 4), 9.0))
	check(observed.ok and observed.get("code", "") == "material_travel_open", "blocked observation opened: " + command + " " + str(observed.get("code", "")))

func _cancel_trip(town, id: String, trip_command: String, cancel_command: String) -> Dictionary:
	var target := trip_command
	var cancel_id := cancel_command
	return town.transaction(_path, func(): return town.submit_trade(id, "material:cancel:" + target, cancel_id, "opengameagent_fixture"))

func _record_by_id(town, episode_id: String) -> Dictionary:
	for record in town.snapshot().godot.materials.get("blocked", {}).values():
		if str(record.get("episode_id", "")) == episode_id:
			return record
	return {}

func _blocked_events(town, trip_command: String) -> Array:
	var result: Array = []
	for event in town.snapshot().life.events:
		if event.get("type") == "material_travel_blocked" and str(event.get("operation_id", "")) == trip_command:
			result.append(event)
	return result

func run() -> void:
	_path = "user://focused-blocked-state-%d.json" % Time.get_ticks_usec()
	_write_fixture(_path, material_fixture())
	var town = load_materials(_path)
	var residents := ["fictional:ember", "fictional:birch", "fictional:forge"]
	var ember: String = residents[0]
	var birch: String = residents[1]
	elapse(town, _path, 1.0)
	check(town.transaction(_path, func(): return town.install_material_source(spec(3), 1, "development_gm:focused")).ok, "focused finite source installed")
	_near_source(town, residents)
	elapse(town, _path, 0)
	for id in residents:
		check(town.resident_view(id).material_sources.size() == 1, "resident knows the source: " + id)

	# --- Journal safety: a cancel may not reuse or overwrite another command id.
	execute(town, _path, ember, "wait", "focused:wait")
	var wait_before: Dictionary = town.snapshot().godot.trade.commands["focused:wait"].duplicate(true)
	_start_trip(town, ember, "focused:trip-a")
	check(town.blocked_material_episode(ember).get("command_id", "") == "focused:trip-a", "trip a episode open")
	var seq_before := int(town.snapshot().life.seq)
	var conflict_wait: Dictionary = _cancel_trip(town, ember, "focused:trip-a", "focused:wait")
	check(not conflict_wait.ok and conflict_wait.code == "command_conflict", "cancel cannot reuse an accepted command id: " + str(conflict_wait.code))
	check(town.snapshot().godot.trade.commands["focused:wait"] == wait_before, "accepted journal entry preserved")
	check(not town.pending_job(ember).is_empty(), "trip still pending after conflict")
	check(town.blocked_material_episode(ember).get("status", "") == "open", "episode still open after conflict")
	check(int(town.snapshot().life.seq) == seq_before, "conflict appended no history")
	var conflict_own: Dictionary = _cancel_trip(town, ember, "focused:trip-a", "focused:trip-a")
	check(not conflict_own.ok and conflict_own.code == "command_conflict", "cancel cannot reuse the original material command id")
	_start_trip(town, birch, "focused:trip-b")
	var conflict_cross: Dictionary = _cancel_trip(town, ember, "focused:trip-a", "focused:trip-b")
	check(not conflict_cross.ok and conflict_cross.code == "command_conflict", "cancel cannot reuse another material command id")
	check(town.blocked_material_episode(birch).get("status", "") == "open", "other resident trip untouched")
	var foreign: Dictionary = _cancel_trip(town, birch, "focused:trip-a", "focused:foreign-cancel")
	check(not foreign.ok and foreign.code == "option_unavailable", "another resident cannot cancel this trip")
	check(town.blocked_material_episode(ember).get("status", "") == "open", "episode untouched by foreign cancel")
	var unknown: Dictionary = _cancel_trip(town, ember, "focused:missing", "focused:unknown-cancel")
	check(not unknown.ok and unknown.code == "option_unavailable", "unknown trip unavailable")
	var bad_provenance: Dictionary = town.transaction(_path, func(): return town.submit_trade(ember, "material:cancel:focused:trip-a", "focused:bad-prov", "resident_self"))
	check(not bad_provenance.ok and bad_provenance.code == "invalid_actor_command_or_provenance", "unlisted provenance rejected")
	var with_speech: Dictionary = town.transaction(_path, func(): return town.submit_trade(ember, "material:cancel:focused:trip-a", "focused:speech", "opengameagent_fixture", "let me explain"))
	check(not with_speech.ok and with_speech.code == "speech_not_supported_for_action", "cancel does not accept speech")
	var cancelled: Dictionary = _cancel_trip(town, ember, "focused:trip-a", "focused:cancel-a")
	check(cancelled.ok and cancelled.code == "material_cancelled", "legitimate cancel accepted")
	var receipt: Dictionary = town.snapshot().godot.materials.commands["focused:trip-a"].get("result", {})
	check(str(town.snapshot().godot.materials.commands["focused:trip-a"].get("status", "")) == "rejected" and str(receipt.get("code", "")) == "material_cancelled" and int(receipt.get("quantity", -1)) == 0, "original command terminal with zero transfer")
	var after_cancel: Dictionary = town.snapshot()
	var replay: Dictionary = _cancel_trip(town, ember, "focused:trip-a", "focused:cancel-a")
	check(replay.ok and replay.duplicate, "same cancel command is idempotent")
	check(town.snapshot() == after_cancel, "replayed cancel changes nothing")
	var second_cancel: Dictionary = _cancel_trip(town, ember, "focused:trip-a", "focused:cancel-a2")
	check(not second_cancel.ok and second_cancel.code == "option_unavailable", "closed trip cannot be cancelled again")
	# The author's next personal feedback must read both actions truthfully.
	var turns := TurnsScript.new()
	turns.town = town
	var cancel_feedback: Array = turns._feedback_history(ember, {"history": [{"command_id": "focused:cancel-a", "status": "settled"}]})
	check(cancel_feedback.size() == 1 and bool(cancel_feedback[0].get("result", {}).get("ok", false)), "completed cancel reports success to its author: " + JSON.stringify(cancel_feedback[0].get("result", {})))
	check(str(cancel_feedback[0].get("result", {}).get("target_command_id", "")) == "focused:trip-a", "cancel feedback names the original trip")
	check(int(cancel_feedback[0].get("result", {}).get("quantity", -1)) == 0, "cancel feedback transfers nothing")
	var trip_feedback: Array = turns._feedback_history(ember, {"history": [{"command_id": "focused:trip-a", "status": "settled"}]})
	check(trip_feedback.size() == 1 and not bool(trip_feedback[0].get("result", {}).get("ok", true)), "original trip reports its terminal failure")
	check(str(trip_feedback[0].get("result", {}).get("code", "")) == "material_cancelled", "original trip receipt code")
	turns.free()

	# --- Recurring blockage on one still-pending job keeps producing decisions.
	_start_trip(town, ember, "focused:trip-c")
	var first_episode: String = str(town.blocked_material_episode(ember).get("episode_id", ""))
	var progressed: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(ember, Vector3(0, 0, 3.5), 0.5))
	check(progressed.ok, "progress observation accepted")
	check(town.blocked_material_episode(ember).is_empty(), "progress closed the episode")
	check(str(_record_by_id(town, first_episode).get("closed_reason", "")) == "progress_resumed", "first episode recorded as resumed")
	var second_stall: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(ember, Vector3(9, 0, 4), 9.0))
	check(second_stall.ok, "second stall observation accepted")
	var second_record: Dictionary = town.blocked_material_episode(ember)
	check(not second_record.is_empty() and str(second_record.get("episode_id", "")) != first_episode, "new attributable episode for the same job")
	check(_blocked_events(town, "focused:trip-c").size() == 2, "each episode keeps its own personal fact")
	var repeat_stall: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(ember, Vector3(9, 0, 4), 9.0))
	check(repeat_stall.ok, "repeated stall observation accepted")
	check(_blocked_events(town, "focused:trip-c").size() == 2, "repeated stall does not reissue the episode event")
	var cancel_second: Dictionary = _cancel_trip(town, ember, "focused:trip-c", "focused:cancel-c")
	check(cancel_second.ok, "second episode can be decided on the same job")
	check(str(_record_by_id(town, first_episode).get("closed_reason", "")) == "progress_resumed", "earlier episode facts preserved")
	check(str(_record_by_id(town, str(second_record.get("episode_id", ""))).get("closed_reason", "")) == "resident_cancelled", "second episode records the voluntary cancel")

	# --- Closed outcomes survive later observations and later trips.
	_start_trip(town, ember, "focused:trip-d")
	var d_episode: String = str(town.blocked_material_episode(ember).get("episode_id", ""))
	check(_cancel_trip(town, ember, "focused:trip-d", "focused:cancel-d").ok, "trip d cancelled")
	_start_trip(town, ember, "focused:trip-e")
	for _index in 3:
		var later: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(ember, Vector3(9, 0, 4), 1.0))
		check(later.ok, "later observation accepted")
	check(str(_record_by_id(town, d_episode).get("closed_reason", "")) == "resident_cancelled", "closed outcome not rewritten by later ticks")
	check(town._validate_state(town.snapshot()).ok, "state valid after later observations")
	check(_cancel_trip(town, ember, "focused:trip-e", "focused:cancel-e").ok, "trip e cancelled")
	check(_cancel_trip(town, birch, "focused:trip-b", "focused:cancel-b").ok, "trip b cancelled")

	# --- Ten residents plus a full closed history must still save and reload.
	var all: Array = residents.duplicate()
	for index in 7:
		var stable_id := "fictional:extra%d" % index
		var person := {"stable_id": stable_id, "name": "Extra %d" % index, "role": "resident", "story": "explicit fictional bound fixture"}
		var admission_command := "focused:admit-%d" % index
		var admitted: Dictionary = town.transaction(_path, func(): return town.admit_resident(person, "focused_maintainer", Vector3(0, 0, 3.5), admission_command))
		check(admitted.ok, "resident admitted: " + stable_id + " " + str(admitted.get("code", "")))
		all.append(stable_id)
	check(town.active_ids().size() == 10, "ten residents active")
	_near_source(town, all)
	elapse(town, _path, 0)
	for id in all:
		check(town.resident_view(id).material_sources.size() == 1, "all ten know the source: " + id)
	# A legally maximum-length request id must not overflow the derived episode identity.
	var long_resident: String = all[9]
	var long_trip := "focused:" + "x".repeat(120)
	var long_cancel_id := "focused:cancel-" + "y".repeat(100)
	check(long_trip.length() == 128, "long trip command is the accepted maximum length")
	var long_started: Dictionary = town.transaction(_path, func(): return town.submit_trade(long_resident, "material:recover:" + STATE_SOURCE, long_trip, "opengameagent_fixture"))
	check(long_started.ok, "max-length trip command accepted: " + str(long_started.get("code", "")))
	var long_observed: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(long_resident, Vector3(9, 0, 4), 9.0))
	check(long_observed.ok and long_observed.get("code", "") == "material_travel_open", "max-length trip observation saves: " + str(long_observed.get("code", "")))
	var long_episode := str(town.blocked_material_episode(long_resident).get("episode_id", ""))
	check(not long_episode.is_empty() and long_episode.length() <= 128, "derived episode identity stays bounded: " + str(long_episode.length()))
	var long_progress: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(long_resident, Vector3(0, 0, 3.5), 0.5))
	check(long_progress.ok, "max-length trip progress observation saves")
	var long_repeat: Dictionary = town.transaction(_path, func(): return town.observe_material_travel(long_resident, Vector3(9, 0, 4), 9.0))
	check(long_repeat.ok and long_repeat.get("code", "") == "material_travel_open", "max-length trip recurrence saves: " + str(long_repeat.get("code", "")))
	var long_cancel: Dictionary = _cancel_trip(town, long_resident, long_trip, long_cancel_id)
	check(long_cancel.ok, "max-length trip cancel accepted: " + str(long_cancel.get("code", "")))
	var events_before_bulk := 0
	for event in town.snapshot().life.events:
		if event.get("type") == "material_travel_blocked":
			events_before_bulk += 1
	for round_index in 4:
		for id in all:
			var trip_command := "focused:bulk-%d-%s" % [round_index, id]
			_start_trip(town, id, trip_command)
			var bulk_cancel := _cancel_trip(town, id, trip_command, "focused:bulkcancel-%d-%s" % [round_index, id])
			check(bulk_cancel.ok, "bulk trip decided: " + trip_command)
	var materials: Dictionary = town.snapshot().godot.materials
	var closed_count := 0
	var active_count := 0
	for record in materials.blocked.values():
		if str(record.get("status", "")) == "closed":
			closed_count += 1
		else:
			active_count += 1
	check(closed_count <= 32, "closed history bounded: " + str(closed_count))
	check(active_count <= 10, "active records bounded by residents: " + str(active_count))
	var events_after_bulk := 0
	for event in town.snapshot().life.events:
		if event.get("type") == "material_travel_blocked":
			events_after_bulk += 1
	check(events_after_bulk == events_before_bulk + 40, "personal blocked facts preserved beyond the projection bound")
	check(town._validate_state(town.snapshot()).ok, "state valid at the bound")
	var saved_bytes := FileAccess.get_file_as_bytes(_path)
	town.release_writer(_path)
	var restored = load_materials(_path)
	check(FileAccess.get_file_as_bytes(_path) == saved_bytes, "cold reload keeps exact bytes")
	check(restored._validate_state(restored.snapshot()).ok, "cold reload validates at the bound")
	var restored_closed := 0
	for record in restored.snapshot().godot.materials.blocked.values():
		if str(record.get("status", "")) == "closed":
			restored_closed += 1
	check(restored_closed == closed_count, "cold reload keeps the pruned bound")
	var idle_resident: String = all[2]
	execute(restored, _path, idle_resident, "material:recover:" + STATE_SOURCE, "focused:post-bound")
	var post_bound: Dictionary = restored.transaction(_path, func(): return restored.observe_material_travel(idle_resident, Vector3(9, 0, 4), 9.0))
	check(post_bound.ok and post_bound.get("code", "") == "material_travel_open", "new episode accepted after the bound")
	check(restored.blocked_material_diagnostics().size() == 1, "exactly one actionable issue at the bound")
	# --- The exact requested coexistence: 32 closed PLUS 10 simultaneously active
	# records (one current watch/open episode per resident), then one resident is
	# decided while the other nine keep their identities and pending jobs.
	for id in all:
		if id == idle_resident:
			continue
		_start_trip(restored, id, "focused:coexist-" + id)
	var coexist_materials: Dictionary = restored.snapshot().godot.materials
	var coexist_closed := 0
	var coexist_active := 0
	var coexist_open: Dictionary = {}
	for key in coexist_materials.blocked:
		var record: Dictionary = coexist_materials.blocked[key]
		if str(record.get("status", "")) == "closed":
			coexist_closed += 1
		else:
			coexist_active += 1
			coexist_open[str(record.get("resident_id", ""))] = str(record.get("episode_id", ""))
	check(coexist_closed == 32 and coexist_active == 10, "exactly 32 closed plus 10 active records: %d/%d" % [coexist_closed, coexist_active])
	check(coexist_open.size() == 10 and restored.blocked_material_diagnostics().size() == 10, "one active issue per resident")
	check(restored._validate_state(restored.snapshot()).ok, "coexistence state validates")
	var coexist_bytes := FileAccess.get_file_as_bytes(_path)
	restored.release_writer(_path)
	var coexist_town = load_materials(_path)
	check(FileAccess.get_file_as_bytes(_path) == coexist_bytes, "coexistence cold reload keeps exact bytes")
	var reloaded_counts := {"closed": 0, "active": 0}
	for record in coexist_town.snapshot().godot.materials.blocked.values():
		if str(record.get("status", "")) == "closed":
			reloaded_counts.closed += 1
		else:
			reloaded_counts.active += 1
	check(reloaded_counts.closed == 32 and reloaded_counts.active == 10, "coexistence survives cold reload: %d/%d" % [reloaded_counts.closed, reloaded_counts.active])
	var continue_resident: String = all[1]
	var cancelled_resident: String = all[0]
	var cancelled_trip := "focused:coexist-" + cancelled_resident
	var continued: Dictionary = coexist_town.transaction(_path, func(): return coexist_town.observe_material_travel(continue_resident, Vector3(9, 0, 4), 2.0))
	check(continued.ok and continued.get("code", "") == "material_travel_open", "continuing trip stays reported")
	check(not coexist_town.pending_job(continue_resident).is_empty(), "continuing job stays pending")
	var coexist_cancel: Dictionary = _cancel_trip(coexist_town, cancelled_resident, cancelled_trip, "focused:coexist-cancel")
	check(coexist_cancel.ok, "one coexistence trip cancelled: " + str(coexist_cancel.get("code", "")))
	check(coexist_town.active_ids().size() == 10, "ten identities kept after the coexistence decision")
	var after_materials: Dictionary = coexist_town.snapshot().godot.materials
	var after_closed := 0
	var after_active := 0
	var after_open: Dictionary = {}
	for key in after_materials.blocked:
		var record: Dictionary = after_materials.blocked[key]
		if str(record.get("status", "")) == "closed":
			after_closed += 1
		else:
			after_active += 1
			after_open[str(record.get("resident_id", ""))] = str(record.get("episode_id", ""))
	check(after_closed == 32 and after_active == 9, "closed bound held after one decision: %d/%d" % [after_closed, after_active])
	check(not after_open.has(cancelled_resident), "cancelled resident has no active episode")
	var nine_unchanged := true
	for id in all:
		if id == cancelled_resident:
			continue
		if str(after_open.get(id, "")) != str(coexist_open.get(id, "")) or coexist_town.pending_job(id).is_empty():
			nine_unchanged = false
	check(nine_unchanged, "the other nine active episodes and jobs are unchanged")
	check(coexist_town.blocked_material_diagnostics().size() == 9, "nine actionable issues remain")
	check(coexist_town._validate_state(coexist_town.snapshot()).ok, "post-decision coexistence state validates")
	var coexist_after_bytes := FileAccess.get_file_as_bytes(_path)
	coexist_town.release_writer(_path)
	var coexist_final = load_materials(_path)
	check(FileAccess.get_file_as_bytes(_path) == coexist_after_bytes, "post-decision cold reload keeps exact bytes")
	var reload_turns := TurnsScript.new()
	reload_turns.town = coexist_final
	var reload_feedback: Array = reload_turns._feedback_history(ember, {"history": [{"command_id": "focused:cancel-a", "status": "settled"}]})
	check(reload_feedback.size() == 1 and bool(reload_feedback[0].get("result", {}).get("ok", false)) and str(reload_feedback[0].get("result", {}).get("target_command_id", "")) == "focused:trip-a", "cancel feedback survives cold reload")
	reload_turns.free()
	coexist_final.release_writer(_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	print(JSON.stringify({"suite": "town_material_blocked_state", "checks": checks, "failures": failures,
		"closed_history": closed_count, "active_records": active_count, "blocked_events": events_after_bulk,
		"coexistence_closed": coexist_closed, "coexistence_active": coexist_active, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
