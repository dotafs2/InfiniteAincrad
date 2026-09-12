extends Node
## One world's model turns. The world owns action effects; OGA owns inference.
## A pending/failed request isolates its resident; the rest of the world continues.
const Brain = preload("res://agents/resident_brain.gd")
const IDLE_COOLDOWN := 1800.0
var town
var save_path := ""
var brains: Dictionary = {}
var inflight: Dictionary = {}
var busy: bool:
	get:
		return not inflight.is_empty()
var max_parallel := 3
var _next_resident_index := 0
var last_result: Dictionary = {}

func configure(world, path: String) -> void:
	town = world
	save_path = path
	max_parallel = _configured_gateway_concurrency()
	for id in town.active_ids():
		ensure_brain(id)

func _configured_gateway_concurrency() -> int:
	var config_path := OS.get_environment("AINCRAD_GATEWAY_RUN_CONFIG")
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary:
		return 1
	var value: Variant = parsed.get("concurrency", 1)
	if not (value is int or value is float):
		return 1
	return int(value) if value >= 1 and value <= 3 and float(value) == floorf(float(value)) else 1

func ensure_brain(id: String) -> void:
	if brains.has(id) or id not in town.active_ids():
		return
	var brain := Brain.new()
	add_child(brain)
	brain.configure("gateway")
	brains[id] = brain

func connect_controller(id: String, brain: Node, controller: String) -> Dictionary:
	if id not in town.active_ids() or not is_instance_valid(brain) or not brain.has_method("propose") or controller.is_empty() or controller.length() > 128:
		return {"ok": false, "code": "invalid_controller"}
	if brains.get(id) == brain:
		return {"ok": false, "code": "controller_already_attached"}
	var updated: Dictionary = town.transaction(save_path, func():
		var record := _record(id).duplicate(true)
		var reviews: Array = record.get("reviews", []).duplicate(true)
		if not record.is_empty():
			reviews.append({"status": record.get("status", ""), "error": record.get("error", ""), "request_id": record.get("request_id", ""), "epoch": record.get("controller_epoch", 0), "reason": "host_controller_replaced"})
		record.reviews = reviews
		record.controller_epoch = int(record.get("controller_epoch", 0)) + 1
		record.controller_id = controller
		record.status = "ready"
		record.next_due = 0
		if not town._state.godot.has("resident_turns"):
			town._state.godot.resident_turns = {}
		town._state.godot.resident_turns[id] = record
		return {"ok": true, "code": "controller_connected", "epoch": record.controller_epoch})
	if not updated.ok:
		return updated
	_retire_brain(id)
	if brain.get_parent() == null:
		add_child(brain)
	brains[id] = brain
	return updated

func disconnect_controller(id: String, controller: String, epoch: int) -> Dictionary:
	var current := _record(id)
	if current.get("controller_id", "") != controller or int(current.get("controller_epoch", 0)) != epoch:
		return {"ok": false, "code": "stale_controller"}
	var updated: Dictionary = town.transaction(save_path, func():
		var record: Dictionary = town._state.godot.resident_turns[id]
		if not record.has("reviews"):
			record.reviews = []
		record.reviews.append({"status": record.status, "error": record.get("error", ""), "request_id": record.get("request_id", ""), "epoch": epoch, "reason": "host_controller_disconnected"})
		record.controller_epoch = epoch + 1
		record.status = "disconnected"
		return {"ok": true, "code": "controller_disconnected"})
	if updated.ok:
		_retire_brain(id)
	return updated

func _retire_brain(id: String) -> void:
	var old: Node = brains.get(id)
	var was_running := inflight.has(id)
	inflight.erase(id)
	brains.erase(id)
	if is_instance_valid(old):
		if old.has_method("cancel_pending"):
			old.cancel_pending()
		# The outstanding coroutine owns cleanup after its fenced reply returns.
		if not was_running:
			old.queue_free()

func _record(id: String) -> Dictionary:
	return town._state.godot.get("resident_turns", {}).get(id, {})

func _own_seq(id: String) -> int:
	var seq := 0
	for event in town._state.life.events:
		if id in event.get("recipient_ids", []):
			seq = maxi(seq, int(event.seq))
	return seq

func _requires_review(record: Dictionary) -> bool:
	if record.get("status", "") in ["pending", "provider_error", "disconnected"]:
		return true
	if record.get("status", "") != "rule_rejection":
		return false
	# Only newly classified, terminal stale-option results may replan. Old or
	# unknown failures retain their review boundary; no provider call is replayed.
	var due: Variant = record.get("replan_not_before")
	return not (record.get("replan_policy") == "stale_option_v1"
		and record.get("result", {}).get("code") == "option_unavailable"
		and (due is int or due is float) and is_finite(float(due)) and float(due) >= 0.0)

func _replan_cooling(record: Dictionary) -> bool:
	return record.get("status", "") == "rule_rejection" and town._state.godot.elapsed_seconds < float(record.get("replan_not_before", INF))

func ready_resident() -> String:
	if inflight.size() >= max_parallel:
		return ""
	var residents: Array = town.active_ids()
	for offset in residents.size():
		var id: String = residents[(_next_resident_index + offset) % residents.size()]
		var record := _record(id)
		if not brains.has(id) or inflight.has(id) or _requires_review(record) or _replan_cooling(record):
			continue
		# A pending job normally excludes the resident. A reported blocked material
		# travel episode is the explicit exception: the resident observes the
		# failure and may choose to continue waiting or to cancel that one trip.
		if not town.pending_job(id).is_empty() and town.blocked_material_episode(id).is_empty():
			continue
		if record.is_empty() or _own_seq(id) > int(record.get("seen_seq", 0)) or town._state.godot.elapsed_seconds >= float(record.get("next_due", INF)):
			return id
	return ""

func step(requested_id: String = "") -> Dictionary:
	var id := ready_resident() if requested_id.is_empty() else requested_id
	if id.is_empty():
		return {"ok": true, "code": "no_due_turn"}
	var previous := _record(id)
	if not brains.has(id) or inflight.has(id) or inflight.size() >= max_parallel:
		return {"ok": false, "code": "controller_unavailable", "actor_id": id}
	if _requires_review(previous):
		return {"ok": false, "code": "saved_model_turn_requires_review", "actor_id": id}
	if _replan_cooling(previous):
		return {"ok": false, "code": "replan_cooldown", "actor_id": id}
	if not town.pending_job(id).is_empty() and town.blocked_material_episode(id).is_empty():
		return {"ok": false, "code": "resident_working", "actor_id": id}
	var epoch := int(previous.get("controller_epoch", 0))
	var number := int(previous.get("request_number", 0)) + 1
	var request_id := "turn:%s:%d:%d" % [id, epoch, number]
	var view: Dictionary = town.resident_view(id)
	view.world_id = town._state.world_id
	# Legacy 'hunger' is actually fullness (food increases it). Normalize the
	# model-facing sensor without renaming or rewriting the canonical old field.
	if view.needs.has("hunger"):
		view.needs.satiety = view.needs.hunger
		view.needs.erase("hunger")
		view.needs.scale_explanation = "satiety 是饱食程度：0 为空腹，100 为饱。energy 越高精力越充足。"
	view.needs.energy = view.inventory.get("energy", 0)
	view.memory = {"previous_decisions": _feedback_history(id, previous).slice(-6)}
	for key in ["story", "personality", "faction"]:
		if town.resident(id).has(key):
			view.identity[key] = town.resident(id)[key]
	var options: Array = town.trade_options(id)
	view.available_actions = []
	view.action_details = []
	var aliases: Dictionary = {}
	var speech_actions: Array = []
	for option in options:
		var alias := "a%d" % aliases.size()
		aliases[alias] = option.id
		view.available_actions.append(alias)
		if option.get("speech_allowed", false):
			speech_actions.append(alias)
		view.action_details.append({"id": alias, "label": option.label, "speech_allowed": option.get("speech_allowed", false)})
	# Context is bounded; canonical full history remains in the world save.
	view.experiences = view.get("experiences", []).slice(-16)
	var seen := _own_seq(id)
	var prepared: Dictionary = town.transaction(save_path, func():
		if not town._state.godot.has("resident_turns"):
			town._state.godot.resident_turns = {}
		town._state.godot.resident_turns[id] = {"status": "pending", "seen_seq": seen, "history": previous.get("history", []).duplicate(true),
			"controller_epoch": epoch, "controller_id": previous.get("controller_id", "local:gateway"), "request_number": number, "request_id": request_id,
			"choice_protocol": 2, "offered_actions": aliases.duplicate(true), "speech_actions": speech_actions.duplicate(), "reviews": previous.get("reviews", []).duplicate(true)}
		return {"ok": true})
	if not prepared.ok:
		return prepared
	_next_resident_index = (town.active_ids().find(id) + 1) % town.active_ids().size()
	var brain: Node = brains[id]
	inflight[id] = {"epoch": epoch, "request_id": request_id}
	var reply: Dictionary = await brain.propose(view, int(town._state.life.seq))
	var result := apply_reply(id, epoch, request_id, reply)
	if inflight.get(id, {}).get("request_id") == request_id:
		inflight.erase(id)
	if brains.get(id) != brain and is_instance_valid(brain):
		brain.queue_free()
	return result

func apply_reply(id: String, epoch: int, request_id: String, reply: Dictionary) -> Dictionary:
	var current := _record(id)
	if int(current.get("controller_epoch", -1)) != epoch or current.get("request_id", "") != request_id:
		return {"ok": false, "code": "stale_controller_reply", "actor_id": id}
	if current.get("status") != "pending":
		var duplicate: bool = current.get("accepted_reply", {}) == reply
		return {"ok": duplicate, "duplicate": duplicate, "code": "duplicate" if duplicate else "reply_conflict", "actor_id": id}
	var aliases: Dictionary = current.offered_actions
	var applied: Dictionary = town.transaction(save_path, func():
		var record: Dictionary = town._state.godot.resident_turns[id]
		record.accepted_reply = reply.duplicate(true)
		record.command_id = request_id
		record.provider_command_id = reply.get("command_id", "")
		record.provenance = reply.get("provenance", "")
		if not reply.get("ok", false):
			record.status = "provider_error"
			record.error = reply.get("code", "unknown_provider_error")
			return {"ok": true, "code": "provider_error"}
		var decision = reply.get("decision")
		if not decision is Dictionary or not decision.get("action") is String or not decision.get("reason") is String or decision.reason.length() > 512 or (decision.has("speech") and (not decision.speech is String or decision.speech.length() > 512)):
			record.status = "provider_error"
			record.error = "invalid_decision"
			return {"ok": true, "code": "provider_error"}
		record.model_choice = decision.action
		record.action = aliases.get(decision.action, "")
		record.reason = decision.reason
		# Incoming events received while thinking still require a new observation.
		var arrived_while_thinking: bool = _own_seq(id) > int(record.get("seen_seq", 0))
		var effect: Dictionary = {"ok": false, "code": "choice_not_offered"}
		var speech_delivery := {}
		if aliases.has(decision.action):
			if str(decision.get("speech", "")).is_empty():
				effect = town.submit_trade(id, record.action, request_id, record.provenance)
			elif decision.action in record.get("speech_actions", []):
				effect = town.submit_trade(id, record.action, request_id, record.provenance, decision.speech)
			else:
				# Optional public words do not invalidate an independently legal
				# action. Keep the unsent words in the private accepted reply and
				# report non-delivery; never claim the counterparty heard them.
				effect = town.submit_trade(id, record.action, request_id, record.provenance)
				speech_delivery = {"ok": false, "code": "speech_not_supported_for_action", "delivered": false}
				effect["speech_delivery"] = speech_delivery.duplicate(true)
		record.status = "settled" if effect.ok else "rule_rejection"
		record.result = effect.duplicate(true)
		# A validated capability proposal becomes a bounded, deduplicated world-scoped
		# proposal for the separate GM projection. It is never an achieved capability,
		# never public speech, and the reply's private reason is not exported.
		var accepted_need: Dictionary = {}
		if town.has_method("record_capability_need"):
			var need_outcome: Variant = town.record_capability_need(id, decision.get("need", null), request_id, epoch, int(town._state.life.seq))
			if need_outcome is Dictionary:
				record.need_status = need_outcome.get("code", "unknown")
				if need_outcome.has("proposal_id"):
					record.need_proposal_id = need_outcome.proposal_id
				var accepted_value: Variant = need_outcome.get("accepted", {})
				if accepted_value is Dictionary:
					accepted_need = accepted_value
			else:
				record.need_status = "invalid_need_outcome"
		else:
			# A partial/lower-level fixture runtime owns no GM projection.
			record.need_status = "unsupported_runtime"
		var history_entry := {"action": record.action, "model_choice": decision.action, "reason": decision.reason, "command_id": request_id,
			"provenance": record.provenance, "status": record.status, "result": effect.duplicate(true)}
		if not accepted_need.is_empty():
			# Canonical private history keeps the exact validated need and its source
			# attribution, independent of the bounded GM projection. The reply's private
			# deliberation reason is not duplicated into the need record.
			history_entry.need = {"capability_id": accepted_need.get("capability_id", ""), "reason": accepted_need.get("reason", "")}
			history_entry.need_request_id = accepted_need.get("request_id", "")
			history_entry.need_controller_epoch = int(accepted_need.get("controller_epoch", 0))
			history_entry.need_source_sequence = int(accepted_need.get("source_sequence", 0))
		record.history.append(history_entry)
		if not speech_delivery.is_empty():
			record.history[-1]["speech_delivery"] = speech_delivery.duplicate(true)
		# The immediate effect of this decision is already known to its author.
		# Later job completion remains a new event; concurrent incoming messages
		# get an immediate next turn rather than being swallowed by this watermark.
		record.seen_seq = _own_seq(id)
		record.next_due = town._state.godot.elapsed_seconds + (0.0 if arrived_while_thinking else IDLE_COOLDOWN)
		if not effect.ok and aliases.has(decision.action) and effect.get("code") == "option_unavailable":
			# The world changed while a valid choice was being considered. Observe
			# afresh later, including the rejection. Messages cannot bypass this
			# floor and turn repeated stale replies into an immediate paid loop.
			record.replan_policy = "stale_option_v1"
			record.replan_not_before = town._state.godot.elapsed_seconds + IDLE_COOLDOWN
			record.next_due = record.replan_not_before
		return {"ok": true, "code": record.status, "effect": effect})
	last_result = {"ok": applied.ok and applied.get("code") == "settled", "actor_id": id,
		"code": applied.get("code", "save_failed"), "record": _record(id).duplicate(true)}
	return last_result

func _feedback_history(id: String, record: Dictionary) -> Array:
	# A personal, current projection; never overwrite the original submission history.
	var history: Array = record.get("history", []).slice(-6).duplicate(true)
	var trade_commands: Dictionary = town._state.godot.get("trade", {}).get("commands", {})
	var life_commands: Dictionary = town._state.godot.get("commands", {})
	var material_commands: Dictionary = town._state.godot.get("materials", {}).get("commands", {})
	# Voluntary place trips and place-bound rest keep their own journal; without it an accepted
	# travel choice would still look like "no authoritative execution receipt" after arrival.
	var place_commands: Dictionary = town._state.godot.get("places", {}).get("commands", {})
	for item in history:
		if not item is Dictionary:
			continue
		var command_id := str(item.get("command_id", ""))
		var command: Dictionary = trade_commands.get(command_id, life_commands.get(command_id,
			material_commands.get(command_id, place_commands.get(command_id, {}))))
		var feedback := {"ok": false, "code": "unknown", "reason": "no authoritative execution receipt"}
		if command.get("payload", {}).get("actor_id", "") == id:
			# Older trade wrappers may still say pending while the life command settled.
			var life_command: Dictionary = life_commands.get(command_id, {})
			if command.get("status") == "pending" and life_command.get("payload", {}).get("actor_id") == id and life_command.get("status") in ["completed", "rejected"]:
				command = life_command
			var state: String = str(command.get("status", "unknown"))
			if state == "pending":
				feedback = {"ok": true, "code": "pending", "pending": true}
			elif state in ["completed", "rejected"]:
				feedback = {"ok": state == "completed", "code": state}
				if command.get("result") is Dictionary:
					feedback = command.result.duplicate(true)
				# Legacy saves have terminal status but no detailed receipt. Only use
				# this actor's matching operation; a request ID can name someone else's reply.
				elif state == "completed":
					for event in town._state.life.get("events", []):
						if event.get("operation_id", "") == command_id and event.get("actor_id", "") == id and id in event.get("recipient_ids", []):
							feedback = {"ok": true, "code": event.get("type", "completed"), "event_seq": event.get("seq", 0)}
							if event.has("reply_choice"):
								feedback.reply_choice = event.reply_choice
							break
		elif command.is_empty() and item.get("status") == "rule_rejection":
			feedback = item.get("result", feedback).duplicate(true)
		item.result = feedback
		# The resident's own previous-decision memory keeps its personal consequence and
		# its OWN authored intention text, but not the developer/source attribution the
		# world uses to link a validated capability proposal to a GM-visible episode.
		# Canonical history is untouched: this is a personal projection only.
		var own_need: Variant = item.get("need", null)
		if own_need is Dictionary:
			var own_reason := str(own_need.get("reason", ""))
			if own_reason.is_empty():
				item.erase("need")
			else:
				item.need = {"reason": own_reason}
		item.erase("need_request_id")
		item.erase("need_controller_epoch")
		item.erase("need_source_sequence")
	return history
