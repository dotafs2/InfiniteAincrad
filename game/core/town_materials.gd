extends "res://core/town_trade.gd"
## Optional finite, public material recovery. No stock regeneration or auto-install.
const MATERIAL_WORK_SECONDS := 60.0
const MATERIAL_OBSERVATION_RANGE := 3.0

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
		_state.godot.materials = {"schema_version": 1, "sources": {}, "jobs": {}, "commands": {}, "known": {}, "installs": {}}
	return _state.godot.materials

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
	if not command_id.begins_with("development_gm:") or not _validate_decision_command_id(command_id).ok:
		return _failure("development_gm_required")
	if not _valid_material_spec(spec):
		return _failure("invalid_material_source")
	var payload := {"spec": spec.duplicate(true), "source_seq": source_seq}
	var old: Dictionary = _materials().get("installs", {}).get(command_id, {})
	if not old.is_empty():
		var same: bool = old.payload.source_seq == source_seq and old.payload.spec.id == spec.id and old.payload.spec.label == spec.label and old.payload.spec.material == spec.material and old.payload.spec.initial_stock == spec.initial_stock and old.payload.spec.access == spec.access and _vector(old.payload.spec.position) == _vector(spec.position)
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	var need := _material_need(source_seq)
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
	_append_life_event({"type": "material_source_installed", "actor_id": "development_gm", "recipient_ids": [], "operation_id": command_id, "source": "development_gm_review", "source_id": spec.id, "material": spec.material, "initial_stock": spec.initial_stock, "source_seq": source_seq})
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

func trade_options(id: String) -> Array:
	var result := super.trade_options(id)
	if id not in active_ids() or _busy(id) or _trade_account(id).is_empty():
		return result
	for source_id in _known_materials(id):
		if _known_materials(id)[source_id].stock <= 0:
			continue
		var source: Dictionary = _materials().sources[source_id]
		result.append({"id": "material:recover:" + source_id, "action": "recover_material", "label": "到%s整理60秒，现场有余料则取得1份%s；公共、免费、有限，不保证库存" % [source.label, "铁" if source.material == "iron" else "木"], "speech_allowed": false})
	return result

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
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
	if not m is Dictionary or not _exact_keys(m, ["schema_version", "sources", "jobs", "commands", "known", "installs"]) or m.schema_version != 1:
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
		if not command_id is String or not command_id.begins_with("development_gm:") or not _validate_decision_command_id(command_id).ok or not install is Dictionary or not _exact_keys(install, ["payload"]) or not install.payload is Dictionary or not _exact_keys(install.payload, ["spec", "source_seq"]) or not install.payload.spec is Dictionary or not _valid_material_spec(install.payload.spec):
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
		if not need is Dictionary or not _exact_keys(need, ["seq", "actor_id", "text"]) or not m.installs.has(source.install_command):
			return _failure("invalid_material_evidence")
		var recorded: Dictionary = m.installs[source.install_command].payload
		if recorded.source_seq != need.seq or not value.godot.positions.has(need.actor_id):
			return _failure("invalid_material_evidence")
		for key in spec:
			if (key == "position" and _vector(spec[key]) != _vector(recorded.spec[key])) or (key != "position" and spec[key] != recorded.spec[key]):
				return _failure("material_install_spec_changed")
		var matching := false
		var installed := false
		for event in value.life.events:
			if event.get("seq") == need.seq and event.get("actor_id") == need.actor_id and event.get("text") == need.text and event.get("type") in ["ask_help", "reply_help", "visitor_reply"]:
				matching = true
			if event.get("type") == "material_source_installed" and event.get("operation_id") == source.install_command and event.get("source_id") == source_id and event.get("source_seq") == need.seq and event.get("initial_stock") == source.initial_stock and event.get("material") == source.material and event.get("actor_id") == "development_gm" and event.get("recipient_ids") == []:
				installed = true
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
	return base
