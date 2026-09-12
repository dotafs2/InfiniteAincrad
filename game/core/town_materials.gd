extends "res://core/town_trade.gd"
## Optional finite, public material recovery. No stock regeneration or auto-install.
const MATERIAL_WORK_SECONDS := 60.0
const MATERIAL_OBSERVATION_RANGE := 3.0
# Bounded physical-travel observation. The host scene supplies the
# collision-resolved position and the unpaused seconds; the world derives
# stagnation, never a model or a rule guessing that a wall exists.
const MATERIAL_ARRIVAL_RADIUS := 0.45
const MATERIAL_BLOCKED_NO_PROGRESS_SECONDS := 8.0
const MATERIAL_BLOCKED_PROGRESS_EPSILON := 0.05
# Closed episode history is bounded separately from live watches/episodes, so a
# full resident roster can keep one active record each without breaking the bound.
const MATERIAL_BLOCKED_CLOSED_LIMIT := 32
const MATERIAL_BLOCKED_EVENT := "material_travel_blocked"
const MATERIAL_CANCELLED_EVENT := "material_travel_cancelled"
const MATERIAL_BLOCKED_KEY_PREFIX := "material_blocked:"

var _material_visibility_probe: Callable = Callable()
var _material_visibility_required := false

func require_material_visibility(probe: Callable) -> void:
	# Opt-in line-of-sight sensing for the actual town street. Legacy headless
	# fixtures keep the explicitly labelled proximity sensing by default so prior
	# offline evidence is preserved; this never claims standalone headless is LOS.
	_material_visibility_required = true
	_material_visibility_probe = probe

func _materials() -> Dictionary:
	return _state.godot.get("materials", {})

func _ensure_materials() -> Dictionary:
	if not _state.godot.has("materials"):
		_state.godot.materials = {"schema_version": 1, "sources": {}, "jobs": {}, "commands": {}, "known": {}, "installs": {}, "blocked": {}, "blocked_seq": 0}
	return _state.godot.materials

func _material_blocked() -> Dictionary:
	var blocked: Variant = _materials().get("blocked", {})
	return blocked if blocked is Dictionary else {}

func _ensure_blocked() -> Dictionary:
	var materials := _ensure_materials()
	if not materials.get("blocked", null) is Dictionary:
		materials.blocked = {}
	return materials.blocked

func _blocked_records() -> Array:
	# Deterministic read-only view; Dictionary values stay references.
	var blocked := _material_blocked()
	var keys: Array = blocked.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var record: Variant = blocked[key]
		if record is Dictionary:
			result.append(record)
	return result

func _active_blocked_entry(id: String, command_id: String) -> Dictionary:
	# Live watch or reported episode of one resident for one still-pending job.
	var blocked := _material_blocked()
	var keys: Array = blocked.keys()
	keys.sort()
	var watching: Dictionary = {}
	for key in keys:
		var record: Variant = blocked[key]
		if not record is Dictionary or str(record.get("resident_id", "")) != id or str(record.get("command_id", "")) != command_id:
			continue
		if record.get("status") == "open":
			return {"key": str(key), "record": record}
		if record.get("status") == "watching":
			watching = {"key": str(key), "record": record}
	return watching

func _allocate_blocked_key(id: String, command_id: String) -> String:
	# Monotone, persisted, deliberately OPAQUE episode identity: the original request
	# id may legally use all of MAX_COMMAND_ID_LENGTH, so the derived key must not
	# embed it (or the resident id) and overflow that same limit. Resident, job
	# command, source and world provenance stay explicit in the record and in the
	# background-GM projection instead.
	var materials := _ensure_materials()
	var sequence := int(materials.get("blocked_seq", 0))
	if sequence < 0:
		sequence = 0
	var blocked := _ensure_blocked()
	var key := ""
	# Never reuse a live key even if an older copy lost the persisted counter.
	while true:
		sequence += 1
		key = "%s%d" % [MATERIAL_BLOCKED_KEY_PREFIX, sequence]
		if not blocked.has(key):
			break
	materials.blocked_seq = sequence
	return key

func material_sources() -> Array:
	return _materials().get("sources", {}).values().duplicate(true)

func _valid_material_spec(spec: Dictionary) -> bool:
	if not _exact_keys(spec, ["id", "label", "material", "initial_stock", "position", "access"]):
		return false
	if not spec.id is String or spec.id.length() > 64 or not _validate_decision_command_id(spec.id).ok or not spec.label is String or spec.label.strip_edges().is_empty() or spec.label.length() > 80:
		return false
	if spec.material not in ["iron", "wood"] or spec.access != "public" or not _bounded(spec.initial_stock, 100) or spec.initial_stock < 1 or not _valid_position(spec.position):
		return false
	var point := _vector(spec.position)
	return absf(point.x) <= 64 and absf(point.z) <= 64 and point.y >= 0 and point.y <= 2

func _material_need(seq: int) -> Dictionary:
	for event in _state.life.events:
		if event.get("seq") == seq and event.get("type") in ["ask_help", "reply_help", "visitor_reply"] and event.get("actor_id") in active_ids() and not str(event.get("text", "")).strip_edges().is_empty():
			return {"seq": seq, "actor_id": event.actor_id, "text": event.text}
	return {}

func install_material_source(spec: Dictionary, source_seq: int, command_id: String) -> Dictionary:
	return _install_material_source(spec, source_seq, command_id, _material_need(source_seq))

func _material_private_need_in(_value: Dictionary, _resident_id: String, _request_id: String) -> Dictionary:
	# Only the full town runtime owns accepted resident turn journals.
	return {}

func install_material_source_from_need(spec: Dictionary, resident_id: String, request_id: String, command_id: String) -> Dictionary:
	# Host-reviewed installation may respond to a private accepted need. It does
	# not turn the resident's thought into speech or grant the resident GM powers.
	var need := _material_private_need_in(_state, resident_id, request_id)
	if need.is_empty():
		return _failure("source_need_missing")
	return _install_material_source(spec, int(need.seq), command_id, need)

func _install_material_source(spec: Dictionary, source_seq: int, command_id: String, need: Dictionary) -> Dictionary:
	if not command_id.begins_with("development_gm:") or not _validate_decision_command_id(command_id).ok:
		return _failure("development_gm_required")
	if not _valid_material_spec(spec):
		return _failure("invalid_material_source")
	var payload := {"spec": spec.duplicate(true), "source_seq": source_seq}
	if need.get("kind", "") == "resident_capability_need":
		payload["source_need"] = need.duplicate(true)
	var old: Dictionary = _materials().get("installs", {}).get(command_id, {})
	if not old.is_empty():
		var same: bool = old.payload.source_seq == source_seq and old.payload.get("source_need", {}) == payload.get("source_need", {}) and old.payload.spec.id == spec.id and old.payload.spec.label == spec.label and old.payload.spec.material == spec.material and old.payload.spec.initial_stock == spec.initial_stock and old.payload.spec.access == spec.access and _vector(old.payload.spec.position) == _vector(spec.position)
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if need.is_empty():
		return _failure("source_need_missing")
	if _materials().get("sources", {}).has(spec.id):
		return _failure("material_source_conflict")
	if _materials().get("sources", {}).size() >= 8:
		return _failure("material_source_capacity")
	var source := spec.duplicate(true)
	source.stock = spec.initial_stock
	source.recovered = 0
	source.source_need = need
	source.install_command = command_id
	var materials := _ensure_materials()
	materials.sources[spec.id] = source
	materials.installs[command_id] = {"payload": payload}
	var event := {"type": "material_source_installed", "actor_id": "development_gm", "recipient_ids": [], "operation_id": command_id, "source": "development_gm_review", "source_id": spec.id, "material": spec.material, "initial_stock": spec.initial_stock, "source_seq": source_seq}
	if payload.has("source_need"):
		event["source_need_request_id"] = need.need_request_id
		event["source_need_resident_id"] = need.actor_id
	_append_life_event(event)
	return {"ok": true, "code": "material_source_installed", "source_id": spec.id}

func _known_materials(id: String) -> Dictionary:
	return _materials().get("known", {}).get(id, {})

func _material_source_visible(id: String, source_id: String) -> bool:
	if not _material_visibility_required:
		return true
	if not _material_visibility_probe.is_valid():
		return false
	var verdict: Variant = _material_visibility_probe.call(id, source_id)
	if not verdict is bool:
		return false
	return verdict

func _observe_materials() -> void:
	for id in active_ids():
		for source in material_sources():
			if position_of(id).distance_to(_vector(source.position)) > MATERIAL_OBSERVATION_RANGE:
				continue
			var previous: Dictionary = _known_materials(id).get(source.id, {})
			if previous.get("stock", -1) == source.stock:
				continue
			if not _material_source_visible(id, source.id):
				continue
			var m := _ensure_materials()
			if not m.known.has(id):
				m.known[id] = {}
			# Attributed sensing: line-of-sight when the town street opted in,
			# otherwise the legacy explicitly labelled proximity sensing. Neither
			# is a camera/FOV claim.
			var observation_source := "host_line_of_sight_observation" if _material_visibility_required else "host_proximity_observation"
			_append_life_event({"type": "material_source_observed", "actor_id": id, "recipient_ids": [id], "operation_id": "material-observation:%s:%s:%d" % [id, source.id, int(_state.life.seq) + 1], "source": observation_source, "source_id": source.id, "stock": source.stock, "text": "%s：公共%s料，看到剩余%d份；每次整理60秒可取得1份，现场库存为准。" % [source.label, "铁" if source.material == "iron" else "木", source.stock]})
			m.known[id][source.id] = {"stock": source.stock, "observed_elapsed": _state.godot.elapsed_seconds, "event_seq": _state.life.seq}

func _busy(id: String) -> bool:
	return not _materials().get("jobs", {}).get(id, {}).is_empty() or super._busy(id)

func pending_job(id: String) -> Dictionary:
	var job: Dictionary = _materials().get("jobs", {}).get(id, {})
	return job.duplicate(true) if not job.is_empty() else super.pending_job(id)

func destination(id: String, action: String) -> Vector3:
	var job: Dictionary = _materials().get("jobs", {}).get(id, {})
	if not job.is_empty() and action == "recover_material":
		return _vector(_materials().sources[job.source_id].position)
	return super.destination(id, action)

func _travel_position(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _new_blocked_record(id: String, job: Dictionary, source: Dictionary, observed_position: Vector3) -> Dictionary:
	return {"episode_id": "", "resident_id": id, "command_id": str(job.command_id), "source_id": str(source.id),
		"status": "watching", "reported": false, "opened_elapsed": 0.0, "closed_elapsed": 0.0, "closed_reason": "",
		"cancel_command_id": "", "no_progress_seconds": 0.0, "observed_position": _travel_position(observed_position),
		"last_distance": observed_position.distance_to(_vector(source.position)), "target_position": source.position.duplicate()}

func _close_blocked(record: Dictionary, reason: String) -> void:
	record.status = "closed"
	record.closed_reason = reason
	record.closed_elapsed = _state.godot.elapsed_seconds

func _close_blocked_for_command(id: String, command_id: String, reason: String) -> void:
	var blocked := _material_blocked()
	for key in blocked.keys().duplicate():
		var record: Dictionary = blocked[key]
		if str(record.get("resident_id", "")) != id or str(record.get("command_id", "")) != command_id:
			continue
		if record.get("status") == "watching":
			blocked.erase(key)
		elif record.get("status") == "open":
			_close_blocked(record, reason)
	_prune_blocked()

func _prune_blocked() -> void:
	# Only closed history is pruned, and only beyond its own bound; live watches and
	# reported episodes are never dropped. The personal life event is the durable
	# fact and never depends on this bounded projection.
	var blocked := _material_blocked()
	var closed_ids: Array = []
	for key in blocked.keys():
		if blocked[key].get("status") == "closed":
			closed_ids.append(key)
	if closed_ids.size() <= MATERIAL_BLOCKED_CLOSED_LIMIT:
		return
	closed_ids.sort_custom(func(first, second): return float(blocked[first].get("closed_elapsed", 0.0)) < float(blocked[second].get("closed_elapsed", 0.0)))
	while closed_ids.size() > MATERIAL_BLOCKED_CLOSED_LIMIT:
		blocked.erase(closed_ids.pop_front())

func _open_blocked(record: Dictionary, key: String, observed_position: Vector3, job: Dictionary, source: Dictionary) -> void:
	record.status = "open"
	record.reported = true
	record.opened_elapsed = _state.godot.elapsed_seconds
	record.closed_elapsed = 0.0
	record.closed_reason = ""
	record.episode_id = key
	record.observed_position = _travel_position(observed_position)
	record.target_position = source.position.duplicate()
	record.last_distance = observed_position.distance_to(_vector(source.position))
	# Personal, non-technical consequence: no coordinates, collision or debug
	# detail reaches the resident or the model. The opaque episode id only
	# attributes this fact to one episode of the still-pending trip.
	_append_life_event({"type": MATERIAL_BLOCKED_EVENT, "actor_id": record.resident_id, "recipient_ids": [record.resident_id],
		"operation_id": record.command_id, "source": job.get("provenance", "local_rule_policy"), "source_id": record.source_id,
		"material": source.material, "episode_id": record.episode_id, "text": "我没能到达那个材料点；这次取材任务还没有完成。"})

func observe_material_travel(id: String, observed_position: Vector3, elapsed: float) -> Dictionary:
	# Host-supplied physical observation. Paused time never reaches this method
	# (the scene returns before physics), so a paused resident is never blocked.
	if id not in active_ids() or not observed_position.is_finite() or not is_finite(elapsed) or elapsed < 0.0 or elapsed > 120.0:
		return _failure("invalid_material_travel_observation")
	var materials := _ensure_materials()
	var blocked := _ensure_blocked()
	var job: Dictionary = materials.get("jobs", {}).get(id, {})
	var command_id := str(job.get("command_id", ""))
	for key in blocked.keys().duplicate():
		var stale: Dictionary = blocked[key]
		if str(stale.get("resident_id", "")) != id or str(stale.get("command_id", "")) == command_id:
			continue
		# Only a live watch or a reported episode follows the current job. Closed
		# episodes are history: no later tick may rewrite their recorded outcome.
		if stale.get("status") == "watching":
			blocked.erase(key)
		elif stale.get("status") == "open":
			_close_blocked(stale, "job_replaced")
	if command_id.is_empty():
		_prune_blocked()
		return {"ok": true, "code": "material_travel_no_job"}
	var source: Dictionary = materials.get("sources", {}).get(str(job.get("source_id", "")), {})
	if source.is_empty():
		return _failure("invalid_material_travel_job")
	var target := _vector(source.position)
	# Recurring failures on one still-pending job allocate a new episode record once
	# the previous one is closed; the active record is reused while it lives.
	var active := _active_blocked_entry(id, command_id)
	var record: Dictionary = active.get("record", {})
	var record_key := str(active.get("key", ""))
	if record.is_empty() or record.get("resident_id") != id or record.get("source_id") != source.id:
		record_key = _allocate_blocked_key(id, command_id)
		record = _new_blocked_record(id, job, source, observed_position)
	var last := _vector(record.get("observed_position", _travel_position(observed_position)))
	var last_distance := float(record.get("last_distance", observed_position.distance_to(target)))
	var distance := observed_position.distance_to(target)
	var displacement := Vector2(observed_position.x - last.x, observed_position.z - last.z).length()
	var closure := last_distance - distance
	if distance <= MATERIAL_ARRIVAL_RADIUS or displacement >= MATERIAL_BLOCKED_PROGRESS_EPSILON or closure >= MATERIAL_BLOCKED_PROGRESS_EPSILON:
		# Genuine travel progress, or arrival at the work site. The counterexample
		# cases (a worker already at the target, an ordinary walking detour, a
		# turning resident) therefore never accumulate blocked time.
		record.no_progress_seconds = 0.0
		record.observed_position = _travel_position(observed_position)
		record.last_distance = distance
		if record.get("status") == "open":
			_close_blocked(record, "progress_resumed")
	else:
		record.no_progress_seconds = float(record.get("no_progress_seconds", 0.0)) + elapsed
		if record.get("status") == "watching" and float(record.no_progress_seconds) >= MATERIAL_BLOCKED_NO_PROGRESS_SECONDS:
			_open_blocked(record, record_key, observed_position, job, source)
	blocked[record_key] = record
	_prune_blocked()
	return {"ok": true, "code": "material_travel_" + str(record.status)}

func blocked_material_episode(id: String) -> Dictionary:
	# The one reported, still-pending blocked travel episode of this resident.
	var job: Dictionary = _materials().get("jobs", {}).get(id, {})
	if job.is_empty():
		return {}
	var record: Dictionary = _active_blocked_entry(id, str(job.get("command_id", ""))).get("record", {})
	if record.is_empty() or record.get("status") != "open" or not record.get("reported", false):
		return {}
	return record.duplicate(true)

func blocked_material_diagnostics() -> Array:
	# Separate read-only background-GM projection. It is deliberately NOT a life
	# event recipient and is not part of resident_view, so no personal provider
	# whitelist can pass it to a resident. No GM service or provider call exists here.
	var result: Array = []
	var materials := _materials()
	for record in _blocked_records():
		if record.get("status") != "open" or not record.get("reported", false):
			continue
		var source: Dictionary = materials.get("sources", {}).get(str(record.get("source_id", "")), {})
		var observed := _vector(record.observed_position)
		var target := _vector(record.target_position)
		result.append({"world_id": _state.world_id, "resident_id": record.resident_id, "job_command_id": record.command_id,
			"episode_id": record.episode_id, "source_id": record.source_id, "material": source.get("material", ""),
			"status": "open", "opened_elapsed": record.opened_elapsed, "no_progress_seconds": record.no_progress_seconds,
			"remaining_distance": observed.distance_to(target), "report_count": 1,
			"progress_evidence": {"observed_position": record.observed_position.duplicate(), "target_position": record.target_position.duplicate(),
				"arrival_radius": MATERIAL_ARRIVAL_RADIUS, "no_progress_seconds": record.no_progress_seconds,
				"travel_epsilon": MATERIAL_BLOCKED_PROGRESS_EPSILON}})
	return result

func trade_options(id: String) -> Array:
	var result := super.trade_options(id)
	if id not in active_ids() or _busy(id) or _trade_account(id).is_empty():
		# A resident visibly stuck in a still-pending material trip may choose to
		# wait/continue or to cancel that one trip. Unrelated contracts add no
		# generic cancel here.
		var stuck := blocked_material_episode(id)
		if not stuck.is_empty():
			_option(result, {"id": "material:cancel:" + str(stuck.command_id), "action": "cancel_material",
				"label": "放弃这次取材出行（任务仍未完成，放弃后不获得材料）", "speech_allowed": false, "source_id": stuck.source_id})
		return result
	for source_id in _known_materials(id):
		if _known_materials(id)[source_id].stock <= 0:
			continue
		var source: Dictionary = _materials().sources[source_id]
		result.append({"id": "material:recover:" + source_id, "action": "recover_material", "label": "到%s整理60秒，现场有余料则取得1份%s；公共、免费、有限，不保证库存" % [source.label, "铁" if source.material == "iron" else "木"], "speech_allowed": false})
	return result

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if option_id.begins_with("material:cancel:"):
		return _cancel_material_travel(id, option_id, command_id, provenance, speech)
	if not option_id.begins_with("material:recover:"):
		if _materials().get("commands", {}).has(command_id):
			return _failure("command_conflict")
		return super.submit_trade(id, option_id, command_id, provenance, speech)
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if not speech.is_empty():
		return _failure("speech_not_supported_for_action")
	var source_id := option_id.trim_prefix("material:recover:")
	var payload := {"actor_id": id, "action": "recover_material", "source_id": source_id, "provenance": provenance}
	var old: Dictionary = _materials().get("commands", {}).get(command_id, {})
	if not old.is_empty():
		var same: bool = old.payload == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if _trade().get("commands", {}).has(command_id) or _state.godot.commands.has(command_id):
		return _failure("command_conflict")
	if not trade_options(id).any(func(option): return option.id == option_id):
		return _failure("option_unavailable")
	var m := _ensure_materials()
	m.commands[command_id] = {"payload": payload, "status": "pending"}
	m.jobs[id] = {"action": "recover_material", "command_id": command_id, "source_id": source_id, "provenance": provenance, "elapsed": 0.0, "duration_seconds": MATERIAL_WORK_SECONDS}
	return {"ok": true, "code": "material_started", "pending": true}

func _cancel_material_travel(id: String, option_id: String, command_id: String, provenance: String, speech: String) -> Dictionary:
	# The resident voluntarily ends one still-pending, blocked material trip. The
	# original command becomes terminal with zero resource transfer; intent and
	# history stay. No other contract gains a cancel.
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if not speech.is_empty():
		return _failure("speech_not_supported_for_action")
	var target_command := option_id.trim_prefix("material:cancel:")
	var payload := {"actor_id": id, "action": "trade_option", "option_id": option_id, "provenance": provenance}
	# A cancel may never reuse or overwrite another journal entry's command id.
	if command_id == target_command or _state.godot.commands.has(command_id) or _materials().get("commands", {}).has(command_id):
		return _failure("command_conflict")
	var prior: Dictionary = _trade().get("commands", {}).get(command_id, {})
	if not prior.is_empty():
		var same: bool = prior.get("payload") == payload
		return {"ok": true, "duplicate": true, "code": "duplicate"} if same else _failure("command_conflict")
	# The durable cancel journal above is the sole duplicate authority: repeating this
	# cancel command is answered from it, and a fresh command id against an already
	# closed trip is simply unavailable. Nothing is reissued or rewritten.
	var active := _active_blocked_entry(id, target_command)
	var record: Dictionary = active.get("record", {})
	if record.is_empty() or record.get("status") != "open" or not record.get("reported", false):
		return _failure("option_unavailable")
	var materials := _ensure_materials()
	var job: Dictionary = materials.get("jobs", {}).get(id, {})
	if job.is_empty() or str(job.get("command_id", "")) != target_command or str(job.get("source_id", "")) != str(record.get("source_id", "")):
		return _failure("option_unavailable")
	var source: Dictionary = materials.sources[job.source_id]
	var receipt := {"ok": false, "code": "material_cancelled", "actor_id": id, "command_id": target_command,
		"source_id": source.id, "material": source.material, "quantity": 0}
	materials.commands[target_command].status = "rejected"
	materials.commands[target_command].result = receipt.duplicate(true)
	materials.jobs.erase(id)
	_close_blocked(record, "resident_cancelled")
	record.cancel_command_id = command_id
	_prune_blocked()
	var trade := _ensure_trade()
	# The cancel command gets its OWN truthful success receipt. The original trip
	# keeps the terminal unsuccessful zero-quantity receipt above, so attributing the
	# original receipt to this completed cancel would tell the resident its successful
	# cancel failed.
	var cancel_receipt := {"ok": true, "code": "material_cancelled", "actor_id": id, "command_id": command_id,
		"target_command_id": target_command, "source_id": source.id, "material": source.material, "quantity": 0,
		"original_receipt": receipt.duplicate(true)}
	trade.commands[command_id] = {"payload": payload, "status": "completed", "result": cancel_receipt}
	_append_life_event({"type": MATERIAL_CANCELLED_EVENT, "actor_id": id, "recipient_ids": [id], "operation_id": command_id,
		"source": provenance, "source_id": source.id, "material": source.material,
		"text": "我决定放弃这次取材出行，任务就此结束；我没有取得材料。"})
	return {"ok": true, "code": "material_cancelled", "command_id": target_command}

func advance(delta: float) -> Dictionary:
	var result := super.advance(delta)
	if not result.ok or _materials().is_empty():
		return result
	_observe_materials()
	var m := _materials()
	for id in m.jobs.keys():
		var job: Dictionary = m.jobs[id]
		var source: Dictionary = m.sources[job.source_id]
		if position_of(id).distance_to(_vector(source.position)) > 0.45:
			continue
		job.elapsed += delta
		if job.elapsed < MATERIAL_WORK_SECONDS:
			continue
		var available: bool = source.stock > 0
		if available:
			source.stock -= 1
			source.recovered += 1
			_trade_account(id)[source.material] += 1
		var receipt := {"ok": available, "code": "material_recovered" if available else "material_depleted", "actor_id": id, "command_id": job.command_id, "source_id": source.id, "material": source.material, "quantity": 1 if available else 0}
		m.commands[job.command_id].status = "completed" if available else "rejected"
		m.commands[job.command_id].result = receipt.duplicate(true)
		_close_blocked_for_command(id, str(job.command_id), "job_completed")
		_append_life_event({"type": receipt.code, "actor_id": id, "recipient_ids": [id], "operation_id": job.command_id, "source": job.provenance, "source_id": source.id, "material": source.material, "quantity": receipt.quantity, "text": "整理完成，取得1份材料。" if available else "整理时发现余料已被取完，没有取得材料。"})
		m.jobs.erase(id)
		result.completed.append(receipt)
	_observe_materials()
	return result

func resident_view(id: String = "") -> Dictionary:
	var view := super.resident_view(id)
	if view.is_empty():
		return view
	view.material_sources = []
	for source_id in _known_materials(id):
		var source: Dictionary = _materials().sources[source_id]
		var observation: Dictionary = _known_materials(id)[source_id]
		view.material_sources.append({"id": source.id, "label": source.label, "material": source.material, "access": source.access, "position": source.position.duplicate(), "last_observed_stock": observation.stock, "observed_elapsed": observation.observed_elapsed, "observation_event_seq": observation.event_seq, "knowledge_source": _knowledge_source_for(id, source_id, observation), "work_seconds_per_unit": MATERIAL_WORK_SECONDS, "stock_may_have_changed": true})
	return view

func _knowledge_source_for(id: String, source_id: String, observation: Dictionary) -> String:
	# Derive the personal knowledge source from the exact observation event that
	# produced it. Old proximity observations are never relabelled as new LOS.
	for event in _state.life.events:
		if event.get("seq") == observation.get("event_seq") and event.get("type") == "material_source_observed" and event.get("actor_id") == id and event.get("source_id") == source_id and event.get("stock") == observation.get("stock"):
			var recorded := str(event.get("source", ""))
			if recorded == "host_line_of_sight_observation":
				return "personal_line_of_sight_observation"
			if recorded == "host_proximity_observation":
				return "personal_proximity_observation"
			return "historical_material_observation"
	return "historical_material_observation"

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok or not value.godot.has("materials"):
		return base
	var m: Variant = value.godot.materials
	# Older saves have no blocked-travel projection; both shapes stay loadable.
	var material_keys := ["schema_version", "sources", "jobs", "commands", "known", "installs"]
	if not m is Dictionary or m.schema_version != 1 or not (_exact_keys(m, material_keys) or _exact_keys(m, material_keys + ["blocked"]) or _exact_keys(m, material_keys + ["blocked", "blocked_seq"])):
		return _failure("invalid_material_state")
	for key in ["sources", "jobs", "commands", "known", "installs"]:
		if not m[key] is Dictionary:
			return _failure("invalid_material_state")
	if m.sources.size() > 8:
		return _failure("material_source_capacity")
	for source in m.sources.values():
		if not source is Dictionary:
			return _failure("invalid_material_source")
	for command in m.commands.values():
		if not command is Dictionary or not command.get("payload") is Dictionary:
			return _failure("invalid_material_command")
	for command_id in m.installs:
		var install: Variant = m.installs[command_id]
		if not command_id is String or not command_id.begins_with("development_gm:") or not _validate_decision_command_id(command_id).ok or not install is Dictionary or not _exact_keys(install, ["payload"]) or not install.payload is Dictionary or not (_exact_keys(install.payload, ["spec", "source_seq"]) or _exact_keys(install.payload, ["spec", "source_seq", "source_need"])) or not install.payload.spec is Dictionary or not _valid_material_spec(install.payload.spec):
			return _failure("invalid_material_install")
		if not m.sources.has(install.payload.spec.id) or m.sources[install.payload.spec.id].get("install_command") != command_id:
			return _failure("invalid_material_install")
	for source_id in m.sources:
		var source: Variant = m.sources[source_id]
		if not source is Dictionary or not _exact_keys(source, ["id", "label", "material", "initial_stock", "position", "access", "stock", "recovered", "source_need", "install_command"]):
			return _failure("invalid_material_source")
		var spec: Dictionary = source.duplicate(true)
		for key in ["stock", "recovered", "source_need", "install_command"]:
			spec.erase(key)
		if not _valid_material_spec(spec) or source.id != source_id or not _bounded(source.stock, source.initial_stock) or not _bounded(source.recovered, source.initial_stock) or source.stock + source.recovered != source.initial_stock:
			return _failure("material_conservation_failed")
		var need: Variant = source.source_need
		if not need is Dictionary or not m.installs.has(source.install_command):
			return _failure("invalid_material_evidence")
		var private_need: bool = need.get("kind", "") == "resident_capability_need"
		if not _exact_keys(need, ["seq", "actor_id", "text", "kind", "need_request_id", "need_controller_epoch", "capability_id"] if private_need else ["seq", "actor_id", "text"]):
			return _failure("invalid_material_evidence")
		var recorded: Dictionary = m.installs[source.install_command].payload
		if recorded.source_seq != need.seq or not value.godot.positions.has(need.actor_id):
			return _failure("invalid_material_evidence")
		if private_need:
			if not need.actor_id is String or not need.need_request_id is String or recorded.get("source_need", {}) != need or _material_private_need_in(value, need.actor_id, need.need_request_id) != need:
				return _failure("invalid_material_evidence")
		elif recorded.has("source_need"):
			return _failure("invalid_material_evidence")
		for key in spec:
			if (key == "position" and _vector(spec[key]) != _vector(recorded.spec[key])) or (key != "position" and spec[key] != recorded.spec[key]):
				return _failure("material_install_spec_changed")
		var matching := private_need
		var installed := false
		for event in value.life.events:
			if not private_need and event.get("seq") == need.seq and event.get("actor_id") == need.actor_id and event.get("text") == need.text and event.get("type") in ["ask_help", "reply_help", "visitor_reply"]:
				matching = true
			if event.get("type") == "material_source_installed" and event.get("operation_id") == source.install_command and event.get("source_id") == source_id and event.get("source_seq") == need.seq and event.get("initial_stock") == source.initial_stock and event.get("material") == source.material and event.get("actor_id") == "development_gm" and event.get("recipient_ids") == []:
				installed = (event.get("source_need_request_id", "") == need.need_request_id and event.get("source_need_resident_id", "") == need.actor_id) if private_need else not event.has("source_need_request_id") and not event.has("source_need_resident_id")
		if not matching or not installed:
			return _failure("invalid_material_evidence")
		var recovered := 0
		for command in m.commands.values():
			if command is Dictionary and command.get("payload", {}).get("source_id") == source_id and command.get("status") == "completed":
				recovered += 1
		if recovered != source.recovered:
			return _failure("material_receipt_conservation_failed")
	for command_id in m.commands:
		if value.godot.commands.has(command_id) or value.godot.get("trade", {}).get("commands", {}).has(command_id):
			return _failure("material_command_conflict")
		var command: Variant = m.commands[command_id]
		if not command is Dictionary or not command.get("payload") is Dictionary or command.get("status") not in ["pending", "completed", "rejected"]:
			return _failure("invalid_material_command")
		var payload: Dictionary = command.payload
		if not _exact_keys(payload, ["actor_id", "action", "source_id", "provenance"]) or payload.action != "recover_material" or not value.godot.positions.has(payload.actor_id) or not m.sources.has(payload.source_id) or payload.provenance not in ALLOWED_DECISION_PROVENANCE or not _validate_decision_command_id(command_id).ok:
			return _failure("invalid_material_command")
		if command.status == "pending":
			if m.jobs.get(payload.actor_id, {}).get("command_id") != command_id:
				return _failure("material_pending_job_missing")
		else:
			var receipt: Variant = command.get("result")
			if not receipt is Dictionary or receipt.get("command_id") != command_id or receipt.get("actor_id") != payload.actor_id or receipt.get("source_id") != payload.source_id or receipt.get("material") != m.sources[payload.source_id].material or receipt.get("quantity") != (1 if command.status == "completed" else 0) or receipt.get("ok") != (command.status == "completed"):
				return _failure("invalid_material_receipt")
	for id in m.jobs:
		var job: Variant = m.jobs[id]
		if not job is Dictionary or not _exact_keys(job, ["action", "command_id", "source_id", "provenance", "elapsed", "duration_seconds"]) or job.action != "recover_material" or not m.sources.has(job.source_id) or not _bounded(job.elapsed, MATERIAL_WORK_SECONDS, false) or job.duration_seconds != MATERIAL_WORK_SECONDS:
			return _failure("invalid_material_job")
		var command: Dictionary = m.commands.get(job.command_id, {})
		if command.get("status") != "pending" or command.get("payload", {}).get("actor_id") != id or command.payload.source_id != job.source_id or command.payload.provenance != job.provenance or value.godot.pending.has(id) or value.godot.get("trade", {}).get("jobs", {}).has(id):
			return _failure("material_job_conflict")
	for id in m.known:
		if not value.godot.positions.has(id) or not m.known[id] is Dictionary:
			return _failure("invalid_material_observer")
		for source_id in m.known[id]:
			var known: Variant = m.known[id][source_id]
			if not m.sources.has(source_id) or not known is Dictionary or not _exact_keys(known, ["stock", "observed_elapsed", "event_seq"]) or not _bounded(known.stock, m.sources[source_id].initial_stock) or not _bounded(known.observed_elapsed, value.godot.elapsed_seconds, false):
				return _failure("invalid_material_observation")
			var found := false
			for event in value.life.events:
				if event.get("seq") == known.event_seq and event.get("type") == "material_source_observed" and event.get("actor_id") == id and id in event.get("recipient_ids", []) and event.get("source_id") == source_id and event.get("stock") == known.stock:
					found = true
			if not found:
				return _failure("invalid_material_observation_evidence")
	if m.has("blocked"):
		var blocked_valid := _validate_material_blocked(value, m)
		if not blocked_valid.ok:
			return blocked_valid
	return base

func _validate_material_blocked(value: Dictionary, m: Dictionary) -> Dictionary:
	var blocked: Variant = m.blocked
	if not blocked is Dictionary:
		return _failure("invalid_material_blocked_state")
	if m.has("blocked_seq") and (typeof(m.blocked_seq) != TYPE_INT or not _bounded(m.blocked_seq, 1000000000)):
		return _failure("invalid_material_blocked_sequence")
	var active_residents: Dictionary = {}
	var closed_count := 0
	var max_serial := 0
	for episode_key in blocked:
		var record: Variant = blocked[episode_key]
		var record_keys: Array = ["episode_id", "resident_id", "command_id", "source_id", "status", "reported", "opened_elapsed",
			"closed_elapsed", "closed_reason", "cancel_command_id", "no_progress_seconds", "observed_position", "last_distance", "target_position"]
		if not episode_key is String or not _validate_decision_command_id(episode_key).ok or not record is Dictionary or not _exact_keys(record, record_keys):
			return _failure("invalid_material_blocked_record")
		if not _validate_decision_command_id(record.command_id).ok or not m.commands.has(record.command_id) or not m.sources.has(record.source_id):
			return _failure("invalid_material_blocked_record")
		if not record.resident_id is String or not value.godot.positions.has(record.resident_id):
			return _failure("invalid_material_blocked_resident")
		# Opaque bounded key: an opaque serial episode id (current) or the earlier
		# descriptive form, always ending in its positive serial. Provenance lives in
		# the record fields, so a maximum-length original request id cannot overflow.
		var key_text := str(episode_key)
		var tail_start := key_text.rfind(":")
		var serial := key_text.substr(tail_start + 1)
		if not key_text.begins_with(MATERIAL_BLOCKED_KEY_PREFIX) or key_text.length() > MAX_COMMAND_ID_LENGTH or not serial.is_valid_int() or int(serial) < 1:
			return _failure("invalid_material_blocked_identity")
		max_serial = maxi(max_serial, int(serial))
		if record.status not in ["watching", "open", "closed"] or typeof(record.reported) != TYPE_BOOL:
			return _failure("invalid_material_blocked_status")
		if not _valid_position(record.observed_position) or not _valid_position(record.target_position) or not _bounded(record.last_distance, 10000.0, false) or not _bounded(record.no_progress_seconds, 1000000.0, false):
			return _failure("invalid_material_blocked_measurement")
		if not _bounded(record.opened_elapsed, value.godot.elapsed_seconds, false) or not _bounded(record.closed_elapsed, value.godot.elapsed_seconds, false):
			return _failure("invalid_material_blocked_clock")
		if not record.cancel_command_id is String or record.closed_reason not in ["", "progress_resumed", "resident_cancelled", "job_completed", "job_replaced"]:
			return _failure("invalid_material_blocked_reason")
		if record.status == "watching":
			if record.reported or record.episode_id != "" or float(record.opened_elapsed) != 0.0 or record.closed_reason != "" or record.cancel_command_id != "":
				return _failure("invalid_material_blocked_watch")
		elif record.status == "open":
			if not record.reported or record.episode_id != str(episode_key) or float(record.opened_elapsed) <= 0.0 or record.closed_reason != "" or record.cancel_command_id != "":
				return _failure("invalid_material_blocked_open")
		else:
			if not record.reported or record.episode_id != str(episode_key) or float(record.opened_elapsed) <= 0.0 or record.closed_reason == "":
				return _failure("invalid_material_blocked_closed")
			if float(record.closed_elapsed) < float(record.opened_elapsed):
				return _failure("invalid_material_blocked_clock")
			if record.closed_reason == "resident_cancelled":
				if record.cancel_command_id == "" or not _validate_decision_command_id(record.cancel_command_id).ok:
					return _failure("invalid_material_blocked_cancel")
				# The original command must carry the terminal, zero-transfer receipt.
				var cancelled_command: Variant = m.commands[record.command_id]
				var cancelled_receipt: Variant = cancelled_command.get("result")
				if cancelled_command.get("status") != "rejected" or not cancelled_receipt is Dictionary or cancelled_receipt.get("code") != "material_cancelled" or cancelled_receipt.get("ok") != false or int(cancelled_receipt.get("quantity", -1)) != 0:
					return _failure("invalid_material_blocked_cancel")
			elif record.cancel_command_id != "":
				return _failure("invalid_material_blocked_cancel")
		if record.status in ["watching", "open"]:
			# A live watch/episode must still own its real pending job; a replaced or
			# finished trip can never keep an actionable blocked record.
			var live_job: Variant = m.jobs.get(record.resident_id, {})
			if not live_job is Dictionary or str(live_job.get("command_id", "")) != str(record.command_id) or str(live_job.get("source_id", "")) != record.source_id:
				return _failure("invalid_material_blocked_live_job")
			if active_residents.has(record.resident_id):
				return _failure("invalid_material_blocked_active")
			active_residents[record.resident_id] = true
		else:
			closed_count += 1
		# Deduplicated evidence per episode: a reported episode has exactly one
		# personal event carrying its episode id, and a pre-report watch has none,
		# so replays, restarts or a later trip cannot re-issue that episode.
		var matches := 0
		for event in value.life.events:
			if event.get("type") == MATERIAL_BLOCKED_EVENT and event.get("operation_id") == record.command_id and event.get("actor_id") == record.resident_id and record.resident_id in event.get("recipient_ids", []) and event.get("episode_id", "") == record.episode_id:
				matches += 1
		if matches != (1 if record.reported else 0):
			return _failure("material_blocked_evidence_mismatch")
	if active_residents.size() > value.godot.positions.size() or closed_count > MATERIAL_BLOCKED_CLOSED_LIMIT:
		return _failure("invalid_material_blocked_bound")
	if m.has("blocked_seq") and int(m.blocked_seq) < max_serial:
		return _failure("invalid_material_blocked_sequence")
	return {"ok": true, "code": "material_blocked_valid"}
