extends "res://core/town_materials.gd"
## Trusted host admission, not a public authentication endpoint.
## Joining creates no money, materials or food. Reconnecting never calls admission.
##
## Also owns the world-scoped BACKGROUND-GM projection: bounded, validated resident
## capability proposals plus the read-only evidence snapshot a separate GM process
## consumes OUTSIDE every NPC model context. No GM service, provider call or repair
## task is implemented here: the export states evidence and explicit limits only.

const BACKGROUND_GM_SCHEMA_VERSION := 1
const BACKGROUND_GM_PROPOSAL_LIMIT := 32
const BACKGROUND_GM_EVIDENCE_LIMIT := 64
const BACKGROUND_GM_PROPOSAL_PREFIX := "gm_proposal:"
const CAPABILITY_ID_MAX_LENGTH := 48
const NEED_REASON_MAX_LENGTH := 512

var _gm_export_path := ""
var _gm_export_signature := ""
var _gm_export_failed_signature := ""
var _gm_export_failed_code := ""

func _background_gm() -> Dictionary:
	var projection: Variant = _state.godot.get("background_gm", {})
	return projection if projection is Dictionary else {}

func _ensure_background_gm() -> Dictionary:
	if not _state.godot.get("background_gm", null) is Dictionary:
		_state.godot.background_gm = {"schema_version": BACKGROUND_GM_SCHEMA_VERSION, "seq": 0, "proposals": {}}
	return _state.godot.background_gm

func _background_gm_records() -> Array:
	var proposals: Dictionary = _background_gm().get("proposals", {})
	var keys: Array = proposals.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var record: Variant = proposals[key]
		if record is Dictionary:
			result.append(record)
	return result

func _valid_capability_id(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.is_empty() or text.length() > CAPABILITY_ID_MAX_LENGTH or text != text.strip_edges():
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		var allowed := (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95 or code == 45 or code == 46 or code == 58
		if not allowed:
			return false
	return true

func _valid_need_text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= NEED_REASON_MAX_LENGTH

func _allocate_proposal_key() -> String:
	var projection := _ensure_background_gm()
	var sequence := int(projection.get("seq", 0))
	if sequence < 0:
		sequence = 0
	var proposals: Dictionary = projection.proposals
	var key := ""
	while true:
		sequence += 1
		key = "%s%d" % [BACKGROUND_GM_PROPOSAL_PREFIX, sequence]
		if not proposals.has(key):
			break
	projection.seq = sequence
	return key

func _prune_background_gm() -> void:
	var projection := _background_gm()
	var proposals: Dictionary = projection.get("proposals", {})
	if proposals.size() <= BACKGROUND_GM_PROPOSAL_LIMIT:
		return
	var keys: Array = proposals.keys()
	keys.sort_custom(func(first, second):
		var left := float(proposals[first].get("last_elapsed", 0.0))
		var right := float(proposals[second].get("last_elapsed", 0.0))
		if left != right:
			return left < right
		# Deterministic tiebreak on the monotone serial: never prune a newer ask first.
		return int(str(first).trim_prefix(BACKGROUND_GM_PROPOSAL_PREFIX)) < int(str(second).trim_prefix(BACKGROUND_GM_PROPOSAL_PREFIX)))
	while proposals.size() > BACKGROUND_GM_PROPOSAL_LIMIT and not keys.is_empty():
		proposals.erase(keys.pop_front())

func record_capability_need(resident_id: String, need: Variant, request_id: String, controller_epoch: int, source_sequence: int) -> Dictionary:
	# A validated resident proposal is a PROPOSAL: it is never an achieved capability,
	# never public speech, and never a repair task. Canonical turn history keeps the
	# original reply; this projection stays bounded and deduplicated per resident+capability.
	if resident_id not in active_ids() or not _validate_decision_command_id(request_id).ok:
		return _failure("invalid_proposal_source")
	if not _bounded(controller_epoch, 1000000000) or not _bounded(source_sequence, _state.life.seq):
		return _failure("invalid_proposal_source")
	if need == null:
		return {"ok": true, "code": "need_absent"}
	if not need is Dictionary or not _exact_keys(need, ["capability_id", "reason"]) or not _valid_capability_id(need.capability_id) or not _valid_need_text(need.reason):
		return _failure("invalid_capability_need")
	var accepted := {"capability_id": need.capability_id, "reason": need.reason, "request_id": request_id,
		"controller_epoch": controller_epoch, "source_sequence": source_sequence, "accepted_elapsed": _state.godot.elapsed_seconds}
	var projection := _ensure_background_gm()
	var proposals: Dictionary = projection.proposals
	for key in proposals.keys():
		var candidate: Dictionary = proposals[key]
		if str(candidate.get("resident_id", "")) != resident_id or str(candidate.get("capability_id", "")) != need.capability_id:
			continue
		if str(candidate.get("request_id", "")) == request_id:
			return {"ok": true, "duplicate": true, "code": "duplicate", "proposal_id": str(key), "accepted": accepted}
		# Aggregation never rewrites the original accepted facts: the first content,
		# request, epoch and sequence stay, and later sources are recorded separately.
		candidate.occurrences = int(candidate.occurrences) + 1
		candidate.last_elapsed = _state.godot.elapsed_seconds
		candidate.latest_reason = need.reason
		candidate.latest_request_id = request_id
		candidate.latest_controller_epoch = controller_epoch
		candidate.latest_source_sequence = source_sequence
		_prune_background_gm()
		return {"ok": true, "code": "capability_proposal_repeated", "proposal_id": str(key), "accepted": accepted}
	var proposal_key := _allocate_proposal_key()
	proposals[proposal_key] = {"proposal_id": proposal_key, "resident_id": resident_id, "capability_id": need.capability_id,
		"reason": need.reason, "request_id": request_id, "controller_epoch": controller_epoch, "source_sequence": source_sequence,
		"occurrences": 1, "status": "proposed", "first_elapsed": _state.godot.elapsed_seconds, "last_elapsed": _state.godot.elapsed_seconds,
		"latest_reason": need.reason, "latest_request_id": request_id, "latest_controller_epoch": controller_epoch,
		"latest_source_sequence": source_sequence}
	_prune_background_gm()
	return {"ok": true, "code": "capability_proposed", "proposal_id": proposal_key, "accepted": accepted}

func background_gm_snapshot() -> Dictionary:
	# Read-only. Never mutates world state, never takes the writer path, and never
	# enters a resident view or the personal provider whitelist.
	var issues: Array = []
	for diagnostic in blocked_material_diagnostics():
		if issues.size() >= BACKGROUND_GM_EVIDENCE_LIMIT:
			break
		var observed: Array = diagnostic.get("progress_evidence", {}).get("observed_position", [])
		var target: Array = diagnostic.get("progress_evidence", {}).get("target_position", [])
		issues.append({"evidence_kind": "movement_blocked", "issue_id": diagnostic.get("episode_id", ""),
			"episode_id": diagnostic.get("episode_id", ""), "world_id": diagnostic.get("world_id", ""),
			"resident_id": diagnostic.get("resident_id", ""), "job_command_id": diagnostic.get("job_command_id", ""),
			"source_id": diagnostic.get("source_id", ""), "material": diagnostic.get("material", ""),
			"status": diagnostic.get("status", ""), "opened_elapsed": diagnostic.get("opened_elapsed", 0.0),
			"physical_facts": {"observed_position": observed.duplicate(), "target_position": target.duplicate(),
				"remaining_distance": diagnostic.get("remaining_distance", -1.0),
				"no_progress_seconds": diagnostic.get("no_progress_seconds", 0.0),
				"arrival_radius": diagnostic.get("progress_evidence", {}).get("arrival_radius", 0.0),
				"progress_epsilon": diagnostic.get("progress_evidence", {}).get("travel_epsilon", 0.0),
				"observation_source": "host_physics_frame_position"},
			"discriminators": {"movement_blocked": true, "collision_proved": false, "contact_recorded": false,
				"obstacle_identified": false, "image_analysis": false, "repair_task_inferred": false,
				"note": "no-progress evidence only; a deliberate or legitimate obstacle is not distinguishable here from a defect"}})
	var proposals: Array = []
	for record in _background_gm_records():
		proposals.append({"evidence_kind": "capability_proposed", "proposal_id": record.get("proposal_id", ""),
			"resident_id": record.get("resident_id", ""), "capability_id": record.get("capability_id", ""),
			# First vs latest are labelled explicitly: a repeated ask whose private reason
			# changed must not hide the change behind the original content.
			"first": {"reason": record.get("reason", ""), "request_id": record.get("request_id", ""),
				"controller_epoch": record.get("controller_epoch", 0), "source_sequence": record.get("source_sequence", 0)},
			"latest": {"reason": record.get("latest_reason", ""), "request_id": record.get("latest_request_id", ""),
				"controller_epoch": record.get("latest_controller_epoch", 0), "source_sequence": record.get("latest_source_sequence", 0)},
			"occurrences": record.get("occurrences", 1), "status": record.get("status", ""),
			"claim": {"implemented": false, "public_utterance": false, "verified_in_world": false,
				"note": "resident proposal from an accepted turn; not an achieved capability and not spoken publicly"}})
	var projection := _background_gm()
	return {"schema_version": 1, "kind": "background_gm_evidence_snapshot", "world_id": _state.world_id,
		"source_revision": {"life_seq": int(_state.life.seq), "godot_elapsed_seconds": float(_state.godot.elapsed_seconds),
			"world_elapsed_seconds": float(_state.elapsed_seconds), "proposal_sequence": int(projection.get("seq", 0))},
		"boundaries": {"consumed_by_npc_model": false, "image_analysis": false, "contains_private_reply_reason": false,
			"contains_other_resident_memories": false, "note": "world-scoped evidence for a separate GM process only"},
		"limits": {"evidence_limit": BACKGROUND_GM_EVIDENCE_LIMIT, "proposal_limit": BACKGROUND_GM_PROPOSAL_LIMIT},
		"projection_note": "bounded GM-visible projection; the canonical accepted-need record stays in the world's private turn journal",
		"counts": {"issues": issues.size(), "proposals": proposals.size()}, "evidence": issues, "proposals": proposals}

func background_gm_content_signature() -> String:
	# Meaningful GM-visible content only: advancing timers (no_progress_seconds) and
	# clocks are excluded, so a stagnant-but-unchanged issue never rewrites the file.
	var snapshot := background_gm_snapshot()
	var evidence: Array = []
	for entry in snapshot.evidence:
		var trimmed: Dictionary = entry.duplicate(true)
		if trimmed.get("physical_facts", {}) is Dictionary:
			trimmed.physical_facts.erase("no_progress_seconds")
		evidence.append(trimmed)
	return JSON.stringify({"evidence": evidence, "proposals": snapshot.proposals})

func maybe_write_background_gm_snapshot(path: String) -> Dictionary:
	# Opt-in update driven by real content change only; no daemon and no timer loop.
	if typeof(path) != TYPE_STRING or path.is_empty() or not path.is_absolute_path():
		return _failure("gm_export_path_required")
	var signature := background_gm_content_signature()
	if _gm_export_path != path:
		# A different target has no successful export of any content yet: the previous
		# path's success/failure memos must never be inherited by it.
		_gm_export_path = path
		_gm_export_signature = ""
		_gm_export_failed_signature = ""
		_gm_export_failed_code = ""
	if _gm_export_signature == signature and FileAccess.file_exists(path):
		return {"ok": true, "code": "gm_export_unchanged", "path": path}
	if _gm_export_failed_signature == signature:
		# The identical content already failed to export. Retrying every call would be
		# spam, and an older file must never be relabelled as successfully current:
		# keep reporting the memoized failure until a real success replaces it.
		return {"ok": false, "code": "gm_export_stale", "path": path, "last_error": _gm_export_failed_code}
	var result := write_background_gm_snapshot(path)
	if result.get("ok", false):
		_gm_export_signature = signature
		_gm_export_failed_signature = ""
		_gm_export_failed_code = ""
	else:
		_gm_export_failed_signature = signature
		_gm_export_failed_code = str(result.get("code", "unknown"))
	return result

func write_background_gm_snapshot(path: String) -> Dictionary:
	# Explicit host path only: no daemon, no auto loop, no writer-lock or save change.
	if typeof(path) != TYPE_STRING or path.is_empty() or not path.is_absolute_path():
		return _failure("gm_export_path_required")
	if not _writer_lock_path.is_empty() and _lock_path(path) == _writer_lock_path:
		return _failure("gm_export_path_conflicts_with_world")
	var snapshot := background_gm_snapshot()
	var payload := JSON.stringify(snapshot, "  ")
	var parent := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent) and DirAccess.make_dir_recursive_absolute(parent) != OK:
		return _failure("gm_export_parent_failed")
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _failure("gm_export_open_failed")
	file.store_string(payload)
	file.flush()
	file.close()
	# A derived artifact never destroys the previous good export on a failed replace.
	var backup_path := path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	var had_previous := FileAccess.file_exists(path)
	if had_previous and DirAccess.rename_absolute(path, backup_path) != OK:
		DirAccess.remove_absolute(temp_path)
		return _failure("gm_export_backup_failed")
	if DirAccess.rename_absolute(temp_path, path) != OK:
		if had_previous and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_path, path)
		DirAccess.remove_absolute(temp_path)
		return _failure("gm_export_replace_failed")
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if _gm_export_path == path:
		# An explicit host export is a real successful retry of the configured path:
		# clear the memoized failure so automatic updates are judged on fresh facts.
		_gm_export_failed_signature = ""
		_gm_export_failed_code = ""
	return {"ok": true, "code": "gm_export_written", "path": path, "bytes": payload.to_utf8_buffer().size(),
		"issues": snapshot.counts.issues, "proposals": snapshot.counts.proposals}

func _validate_background_gm(value: Dictionary, g: Dictionary) -> Dictionary:
	var projection: Variant = g.background_gm
	if not projection is Dictionary or not _exact_keys(projection, ["schema_version", "seq", "proposals"]) or projection.schema_version != BACKGROUND_GM_SCHEMA_VERSION:
		return _failure("invalid_background_gm_projection")
	if typeof(projection.seq) != TYPE_INT or not _bounded(projection.seq, 1000000000) or not projection.proposals is Dictionary or projection.proposals.size() > BACKGROUND_GM_PROPOSAL_LIMIT:
		return _failure("invalid_background_gm_projection")
	var seen: Dictionary = {}
	var max_serial := 0
	# Validation always reads the CANDIDATE state, never the live instance: a cold
	# load validates before `_state` holds this world. Stable identity, not current
	# activity, decides whether historical evidence exists.
	var loaded_identities: Array = []
	for person in value.residents:
		if person.get("stable_id") is String:
			loaded_identities.append(person.stable_id)
	for key in projection.proposals:
		var record: Variant = projection.proposals[key]
		var keys: Array = ["proposal_id", "resident_id", "capability_id", "reason", "request_id", "controller_epoch",
			"source_sequence", "occurrences", "status", "first_elapsed", "last_elapsed",
			"latest_reason", "latest_request_id", "latest_controller_epoch", "latest_source_sequence"]
		if not key is String or not _validate_decision_command_id(key).ok or not record is Dictionary or not _exact_keys(record, keys):
			return _failure("invalid_background_gm_proposal")
		var key_text := str(key)
		var serial_text := key_text.trim_prefix(BACKGROUND_GM_PROPOSAL_PREFIX)
		if record.proposal_id != key_text or not key_text.begins_with(BACKGROUND_GM_PROPOSAL_PREFIX) or key_text.length() > MAX_COMMAND_ID_LENGTH or not serial_text.is_valid_int() or int(serial_text) < 1:
			return _failure("invalid_background_gm_proposal")
		max_serial = maxi(max_serial, int(serial_text))
		if record.resident_id not in loaded_identities or not _valid_capability_id(record.capability_id) or not _valid_need_text(record.reason) or not _valid_need_text(record.latest_reason):
			return _failure("invalid_background_gm_proposal_content")
		if not _validate_decision_command_id(record.request_id).ok or not _validate_decision_command_id(record.latest_request_id).ok or record.status != "proposed":
			return _failure("invalid_background_gm_proposal_source")
		if typeof(record.occurrences) != TYPE_INT or not _bounded(record.occurrences, 1000000000) or int(record.occurrences) < 1:
			return _failure("invalid_background_gm_proposal_occurrences")
		if typeof(record.controller_epoch) != TYPE_INT or not _bounded(record.controller_epoch, 1000000000) or typeof(record.source_sequence) != TYPE_INT or not _bounded(record.source_sequence, value.life.seq):
			return _failure("invalid_background_gm_proposal_source")
		if typeof(record.latest_controller_epoch) != TYPE_INT or not _bounded(record.latest_controller_epoch, 1000000000) or typeof(record.latest_source_sequence) != TYPE_INT or not _bounded(record.latest_source_sequence, value.life.seq):
			return _failure("invalid_background_gm_proposal_source")
		if not _bounded(record.first_elapsed, value.godot.elapsed_seconds, false) or not _bounded(record.last_elapsed, value.godot.elapsed_seconds, false) or float(record.last_elapsed) < float(record.first_elapsed):
			return _failure("invalid_background_gm_proposal_clock")
		if int(record.occurrences) == 1 and (str(record.latest_request_id) != str(record.request_id) or int(record.latest_controller_epoch) != int(record.controller_epoch) or int(record.latest_source_sequence) != int(record.source_sequence)):
			return _failure("invalid_background_gm_proposal_aggregate")
		# Every projected proposal must match a real accepted need in that resident's
		# canonical turn journal: matching identity and field shape is not provenance.
		# A host-injected projection in a world with no such accepted need has invented
		# provenance and is rejected. Pre-bridge saves carry no projection at all, so
		# they never reach this check.
		var turn_record: Variant = value.godot.get("resident_turns", {}).get(record.resident_id, {})
		if not (turn_record is Dictionary) or not (turn_record.get("history", null) is Array):
			return _failure("background_gm_proposal_source_mismatch")
		var journal: Array = turn_record.history
		var original_matched := 0
		var latest_matched := 0
		var capability_entries := 0
		for entry in journal:
			if not entry is Dictionary:
				continue
			var entry_need: Variant = entry.get("need", {})
			if not entry_need is Dictionary or str(entry_need.get("capability_id", "")) != str(record.capability_id):
				continue
			capability_entries += 1
			var entry_request := str(entry.get("need_request_id", ""))
			if entry_request != str(entry.get("command_id", "")):
				continue
			if entry_request == str(record.request_id) and int(entry.get("need_controller_epoch", -1)) == int(record.controller_epoch) and int(entry.get("need_source_sequence", -1)) == int(record.source_sequence) and str(entry_need.get("reason", "")) == str(record.reason):
				original_matched += 1
			if entry_request == str(record.latest_request_id) and int(entry.get("need_controller_epoch", -1)) == int(record.latest_controller_epoch) and int(entry.get("need_source_sequence", -1)) == int(record.latest_source_sequence) and str(entry_need.get("reason", "")) == str(record.latest_reason):
				latest_matched += 1
		# Each occurrence is one accepted turn, so a projection episode can never hold
		# more occurrences than its resident has accepted needs for that capability.
		# Same-capability entries from another (e.g. pruned) episode are not this
		# episode's occurrences.
		if original_matched != 1 or latest_matched != 1 or capability_entries < int(record.occurrences):
			return _failure("background_gm_proposal_source_mismatch")
		var pair := "%s:%s" % [record.resident_id, record.capability_id]
		if seen.has(pair):
			return _failure("duplicate_background_gm_proposal")
		seen[pair] = true
	if int(projection.seq) < max_serial:
		return _failure("invalid_background_gm_sequence")
	return {"ok": true, "code": "background_gm_valid"}

func admit_resident(person: Dictionary, maintainer: String, point: Vector3, command: String) -> Dictionary:
	if not _exact_keys(person, ["stable_id", "name", "role", "story"]) or not _validate_decision_command_id(command).ok:
		return _failure("invalid_admission")
	for key in person:
		if not person[key] is String or person[key].strip_edges().is_empty() or person[key].length() > (2048 if key == "story" else 64):
			return _failure("invalid_identity")
	if maintainer.is_empty() or maintainer.length() > 128 or not point.is_finite() or absf(point.x) > 64 or absf(point.z) > 64 or point.y < 0 or point.y > 2:
		return _failure("invalid_admission_location_or_maintainer")
	var payload := {"person": person.duplicate(true), "maintainer": maintainer, "position": [point.x, point.y, point.z]}
	var admissions: Dictionary = _state.godot.get("admissions", {})
	if admissions.has(command):
		var prior: Dictionary = admissions[command]
		# JSON can restore integral coordinates as int instead of float. Compare
		# the authoritative Vector3 value, not the Array's variant element types.
		var same: bool = prior.person == person and prior.maintainer == maintainer and _vector(prior.position) == point
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict", "actor_id": person.stable_id}
	if not resident(person.stable_id).is_empty():
		return _failure("identity_already_exists")
	if active_ids().size() >= 10:
		return _failure("resident_capacity")
	var id: String = person.stable_id
	var newcomer := person.duplicate(true)
	newcomer.needs = {"hunger": 60}
	newcomer.coins_col = 0
	_state.residents.append(newcomer)
	_state.survival.accounts.append({"resident_id": id, "food": 0, "energy": 50})
	if not _state.life.has("accounts"):
		_state.life.accounts = []
	_state.life.accounts.append({"resident_id": id, "wood": 0, "iron": 0, "kindling": 0, "reserved_col": 0})
	_state.godot.positions[id] = payload.position.duplicate()
	_state.godot.homes[id] = payload.position.duplicate()
	_state.godot.observations[id] = []
	if not _state.godot.has("maintainers"):
		_state.godot.maintainers = {}
	_state.godot.maintainers[id] = maintainer
	_state.godot.admissions = admissions
	admissions[command] = payload
	# Existing residents learn about the newcomer only through normal nearby views.
	_append_life_event({"type": "resident_joined", "actor_id": id, "recipient_ids": [id], "operation_id": command, "source": "host_admission"})
	return {"ok": true, "code": "resident_joined", "actor_id": id}

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok:
		return base
	for key in ["admissions", "maintainers", "resident_turns"]:
		if value.godot.has(key) and not value.godot[key] is Dictionary:
			return _failure("invalid_" + key)
	# Older saves have no background-GM projection; both shapes stay loadable.
	if value.godot.has("background_gm"):
		var gm_valid := _validate_background_gm(value, value.godot)
		if not gm_valid.ok:
			return gm_valid
	for id in value.godot.get("resident_turns", {}):
		var record = value.godot.resident_turns[id]
		if not value.godot.positions.has(id) or not record is Dictionary or not record.get("history", []) is Array or not record.get("reviews", []) is Array:
			return _failure("invalid_resident_turn")
		if record.get("status", "ready") not in ["ready", "pending", "settled", "provider_error", "rule_rejection", "disconnected", "reviewed"]:
			return _failure("invalid_controller_status")
		for key in ["controller_epoch", "request_number"]:
			if not _bounded(record.get(key, 0), 1000000000):
				return _failure("invalid_controller_counter")
	return base
