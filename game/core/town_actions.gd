extends "res://core/town_baking.gd"
## Common action boundary. New capabilities compose modules instead of extending
## the world inheritance chain. Existing options/save journals keep their identities.
const CapabilityRegistry = preload("res://core/actions/capability_registry.gd")
const LegacyCapabilities = preload("res://core/actions/legacy_capabilities.gd")
const SocialCapabilities = preload("res://core/actions/social_capabilities.gd")
const CooperationCapabilities = preload("res://core/actions/cooperation_capabilities.gd")
const SelfRepairCapability = preload("res://core/actions/self_repair_capability.gd")
const MaterialKnowledgeCapability = preload("res://core/actions/material_knowledge_capability.gd")
const MaterialHandoffCapability = preload("res://core/actions/material_handoff_capability.gd")
var _capability_registry = CapabilityRegistry.new()
var _capability_modules: Dictionary = {"social": SocialCapabilities.new(), "cooperation": CooperationCapabilities.new(), "self_repair": SelfRepairCapability.new(), "material_knowledge": MaterialKnowledgeCapability.new(), "material_handoff": MaterialHandoffCapability.new()}

func _init() -> void:
	for definition in LegacyCapabilities.definitions():
		_register_capability(definition)
	for module in _capability_modules.values():
		for definition in module.definitions():
			_register_capability(definition)

func _register_capability(definition: Dictionary) -> void:
	# Registration must execute in release builds, where assert expressions disappear.
	var registered: Dictionary = _capability_registry.register(definition)
	if not registered.ok: push_error("Invalid capability registration: " + str(registered))

func capability_definitions() -> Array:
	return _capability_registry.all()

func capability_store() -> Dictionary:
	return _state.get("godot", {}).get("capabilities", {})

func ensure_capability_store() -> Dictionary:
	if not _state.godot.has("capabilities"):
		_state.godot.capabilities = {"schema_version": 1, "commands": {}, "plans": {}}
	return _state.godot.capabilities

func capability_ready(id: String, capability_id: String, interval: float) -> bool:
	for record in capability_store().get("commands", {}).values():
		if record.payload.actor_id == id and record.capability_id == capability_id:
			if _state.godot.elapsed_seconds - record.created_elapsed < interval: return false
	return true

func legacy_action_option(id: String, option_id: String) -> Dictionary:
	for option in super.trade_options(id):
		if option.id == option_id: return option
	return {}

func action_options(id: String) -> Array:
	if id not in active_ids(): return []
	var result: Array = []
	var offered := {}
	var options: Array = super.trade_options(id)
	for module in _capability_modules.values(): options.append_array(module.options(self, id))
	for raw in options:
		var option: Dictionary = raw.duplicate(true)
		var capability_id := str(option.get("capability_id", LegacyCapabilities.capability(option)))
		var definition: Dictionary = _capability_registry.definition(capability_id)
		if definition.is_empty() or offered.has(option.id):
			push_error("Unregistered or duplicate action option: " + str(option.id))
			return []
		offered[option.id] = true
		option.capability_id = capability_id
		option.capability_version = definition.version
		if definition.owner == "legacy":
			var presentation: Dictionary = LegacyCapabilities.presentation(self, option)
			if not presentation.is_empty(): option["presentation"] = presentation
		result.append(option)
	return result

func trade_options(id: String) -> Array:
	# Compatibility for existing UI, tools and reducers. There is one option source.
	return action_options(id)

func execute_action(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if speech.length() > MAX_REASON_LENGTH or (not speech.is_empty() and speech.strip_edges().is_empty()):
		return _failure("invalid_public_speech")
	var payload := {"actor_id": id, "option_id": option_id, "provenance": provenance, "speech": speech}
	var prior: Dictionary = capability_store().get("commands", {}).get(command_id, {})
	if not prior.is_empty():
		var same: bool = prior.payload == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	var before := _state.duplicate(true)
	var result: Dictionary
	if not option_id.begins_with("ability:"):
		result = super.submit_trade(id, option_id, command_id, provenance, speech)
	else:
		if LegacyCapabilities.has_command(_state, command_id): return _failure("command_conflict")
		var option := {}
		for candidate in action_options(id):
			if candidate.id == option_id:
				option = candidate
				break
		if option.is_empty(): return _failure("option_unavailable")
		var definition: Dictionary = _capability_registry.definition(option.capability_id)
		if definition.speech == "forbidden" and not speech.is_empty(): return _failure("speech_not_supported_for_action")
		if definition.speech == "required" and speech.strip_edges().is_empty(): return _failure("speech_required")
		result = _capability_modules[definition.owner].execute(self, id, option, command_id, provenance, speech)
		if result.ok:
			ensure_capability_store().commands[command_id] = {"capability_id": option.capability_id,
				"version": definition.version, "payload": payload, "created_elapsed": _state.godot.elapsed_seconds,
				"status": "pending" if result.get("pending", false) else "completed",
				"event_seq": int(_state.life.seq), "result": result.duplicate(true)}
	if not result.get("ok", false):
		# This also protects callers that retain a rejected model reply in the outer
		# transaction. A half-executed composite cannot leak its first child's writes.
		_state = before
	return result

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	return execute_action(id, option_id, command_id, provenance, speech)

func perform_action(path: String, id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	return transaction(path, func(): return execute_action(id, option_id, command_id, provenance, speech))

func execute_atomic_actions(steps: Array) -> Dictionary:
	# Trusted composition API. NPCs only reach it through a consent-checked module.
	# Revalidate each step against earlier steps; a conflict rolls the whole batch back.
	if steps.is_empty() or steps.size() > 8: return _failure("invalid_action_batch")
	var before := _state.duplicate(true)
	var commands: Array = []
	for index in steps.size():
		var step: Variant = steps[index]
		if not step is Dictionary or not _exact_keys(step, ["actor_id", "option_id", "command_id", "provenance", "speech"]):
			_state = before
			return _failure("invalid_action_batch")
		for key in step:
			if not step[key] is String:
				_state = before
				return _failure("invalid_action_batch")
		if step.command_id in commands:
			_state = before
			return _failure("duplicate_batch_command")
		var effect := execute_action(step.actor_id, step.option_id, step.command_id, step.provenance, step.speech)
		if not effect.ok:
			_state = before
			return {"ok": false, "code": "action_batch_blocked", "failed_step": index, "cause": effect.code}
		commands.append(step.command_id)
	return {"ok": true, "code": "action_batch_applied", "command_ids": commands}

func action_receipt(command_id: String) -> Dictionary:
	var record: Dictionary = capability_store().get("commands", {}).get(command_id, {})
	if not record.is_empty():
		var result := record.duplicate(true)
		result["command_id"] = command_id
		return result
	return LegacyCapabilities.receipt(_state, command_id)

func capability_event(type: String, actor: String, recipients: Array, command: String, provenance: String, text: String) -> Dictionary:
	return {"type": type, "actor_id": actor, "subject_id": actor, "recipient_ids": recipients.duplicate(),
		"operation_id": command, "source": provenance, "provenance": provenance, "text": text, "contractual": false}

func _native_pending_job(id: String) -> Dictionary:
	for module in _capability_modules.values():
		if module.has_method("pending_job"):
			var job: Dictionary = module.pending_job(self, id)
			if not job.is_empty(): return job
	return {}

func _busy(id: String) -> bool:
	return super._busy(id) or not _native_pending_job(id).is_empty()

func pending_job(id: String) -> Dictionary:
	var job := _native_pending_job(id)
	return super.pending_job(id) if job.is_empty() else job

func destination(id: String, action: String) -> Vector3:
	var job := _native_pending_job(id)
	if not job.is_empty() and job.action == action: return _vector(job.target_position)
	return super.destination(id, action)

func advance(delta: float) -> Dictionary:
	var result := super.advance(delta)
	if result.ok:
		for module in _capability_modules.values():
			if module.has_method("advance"): result.completed.append_array(module.advance(self, delta))
		for module in _capability_modules.values():
			if module.has_method("reconcile"): module.reconcile(self)
	return result

func resident_view(id: String = "") -> Dictionary:
	var view := super.resident_view(id)
	if id not in active_ids(): return view
	var plans: Array = []
	for plan in capability_store().get("plans", {}).values():
		if id in plan.participants and plan.status in ["invited", "running"]:
			plans.append({"id": plan.id, "participants": plan.participants.duplicate(), "place_id": plan.place_id, "status": plan.status})
	view["shared_plans"] = plans
	return view

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok: return base
	if not value.godot.has("capabilities"):
		for event in value.life.events:
			var type: String = str(event.get("type", ""))
			if type in ["resident_said", "surroundings_observed", MaterialKnowledgeCapability.EVENT, MaterialHandoffCapability.EVENT] or type.begins_with("joint_visit_") or type in SelfRepairCapability.EVENTS:
				return _failure("capability_state_missing")
		return base
	var store: Variant = value.godot.capabilities
	if not store is Dictionary or not _exact_keys(store, ["schema_version", "commands", "plans"]) or store.schema_version != 1 or not store.commands is Dictionary or not store.plans is Dictionary:
		return _failure("invalid_capability_store")
	var active: Array = []
	for account_value in value.survival.accounts: active.append(account_value.resident_id)
	for command_id in store.commands:
		var row: Variant = store.commands[command_id]
		if not command_id is String or not _validate_decision_command_id(command_id).ok or not row is Dictionary:
			return _failure("invalid_capability_command")
		if not _exact_keys(row, ["capability_id", "version", "payload", "created_elapsed", "status", "event_seq", "result"]):
			return _failure("invalid_capability_command")
		var definition: Dictionary = _capability_registry.definition(str(row.capability_id))
		if definition.is_empty() or definition.owner == "legacy" or row.version != definition.version or not row.payload is Dictionary or not row.result is Dictionary:
			return _failure("invalid_capability_version")
		var payload: Dictionary = row.payload
		if not _exact_keys(payload, ["actor_id", "option_id", "provenance", "speech"]) or payload.actor_id not in active or payload.provenance not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_capability_payload")
		if not payload.option_id is String or not payload.option_id.begins_with("ability:") or not payload.speech is String or payload.speech.length() > MAX_REASON_LENGTH:
			return _failure("invalid_capability_payload")
		if row.status not in ["pending", "completed", "rejected"] or not _bounded(row.created_elapsed, value.godot.elapsed_seconds, false) or not _bounded(row.event_seq, value.life.seq) or row.event_seq < 1:
			return _failure("invalid_capability_receipt")
		if LegacyCapabilities.has_command(value, command_id): return _failure("capability_command_collision")
		var event: Dictionary = value.life.events[int(row.event_seq) - 1]
		if event.get("operation_id") != command_id or event.get("actor_id") != payload.actor_id or event.get("provenance") != payload.provenance:
			return _failure("capability_event_mismatch")
		if not row.result.get("ok") is bool or row.result.ok != (row.status != "rejected"):
			return _failure("invalid_capability_outcome")
		var specific: Dictionary = _capability_modules[definition.owner].validate_command(self, value, command_id, row, event)
		if not specific.ok: return specific
	for module in _capability_modules.values():
		if module.has_method("validate_state"):
			var specific: Dictionary = module.validate_state(self, value)
			if not specific.ok: return specific
	return {"ok": true}
