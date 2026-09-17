extends Node
## One world's model turns. The world owns action effects; OGA owns inference.
## A pending/failed request isolates its resident; the rest of the world continues.
const Brain = preload("res://agents/resident_brain.gd")
const IDLE_COOLDOWN := 1800.0
## Request ids this process failed with the brain's process-local request limit.
## Their cause is in force here, so they are never treated as cold-restored.
var _local_limit_failures: Dictionary = {}
## Request ids this process received and refused only for an over-long reason.
## That refusal is a property of the held receipt, but the resident is still held
## here until a cold restart, so an ordinary turn never becomes an in-process
## paid retry. This channel is separate from the request-limit one: neither
## recovery class can spend the other's single allowance.
var _local_length_failures: Dictionary = {}
var town
var save_path := ""
var brains: Dictionary = {}
## Existing model-facing text bounds; disclosed in the request view so the
## provider can see them. The authoritative check below stays fail-closed.
const DECISION_TEXT_LIMIT := 512
## Structural detail of a received reply refused only for exceeding the unchanged
## text bound. The one locally recoverable invalid_decision class.
const REASON_TOO_LONG_DETAIL := "reason_too_long"
## Provider failures that never exposed a decision to this world. A reply already
## paid for and settled at the fee ledger may replace exactly one of these receipts,
## because nothing was ever chosen here; every other held state already has an
## authoritative outcome or an unresolved attempt that must never be rewritten.
const RECOVERABLE_PROVIDER_ERRORS := ["brain_run_failed", "brain_run_canceled", "brain_timeout",
	"brain_gateway_rejected_or_uncertain", "brain_provider_failed"]
var inflight: Dictionary = {}
var busy: bool:
	get:
		return not inflight.is_empty()
var max_parallel := 3
var _next_resident_index := 0
var last_result: Dictionary = {}
## Episode shutdown. A bounded episode's duration expiry closes admission to NEW
## resident decisions here; coroutines that were already started keep their own
## request and apply their own authoritative result. Nothing in this path rewrites
## a turn record, so a reply that is still owed stays pending for the next cold
## start instead of being reported as a settled turn or a plausible local error.
var _admission_closed := false
var admission_closed_reason := ""
## Finite bound on awaiting already-started replies. It sits above the brain's own
## gateway deadline (38s) so the host never waits longer than the client can still
## accept a reply, and it is finite so an unsettled provider request is reported
## instead of holding the engine until the launcher's own timeout kills it.
var shutdown_wait_limit := 45.0
var shutdown_wait_seconds := 0.0
var shutdown_wait_timed_out := false

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

func _cold_recoverable(id: String, record: Dictionary) -> bool:
	return not _cold_recovery_class(id, record).is_empty()

func _cold_recovery_class(id: String, record: Dictionary) -> String:
	## Two saved provider_error receipts describe a cause the next cold process no
	## longer has: the brain's per-process request counter, and a reply that was
	## genuinely received and refused only because its reason exceeded the unchanged
	## text bound. A checkpoint holding one of them is admitted for exactly one
	## fresh turn under that class's own bookkeeping - two separate attempt/spent
	## channels, so one class never consumes the other's allowance - and the fresh
	## turn is a new request, never a replay of the settled one. Every other held
	## state keeps its review boundary, and so does a failure this process created
	## or a receipt whose own single recovery failed.
	if record.get("status", "") != "provider_error":
		return ""
	var request_id := str(record.get("request_id", ""))
	if request_id.is_empty():
		return ""
	var error := str(record.get("error", ""))
	if error == Brain.SESSION_REQUEST_LIMIT_CODE:
		if str(record.get("session_limit_recovery_spent", "")) == request_id or str(_local_limit_failures.get(id, "")) == request_id:
			return ""
		return "session_request_limit"
	if error != "invalid_decision" or str(record.get("error_detail", "")) != REASON_TOO_LONG_DETAIL:
		# A missing or malformed decision and an over-long speech keep their review
		# boundary exactly as before.
		return ""
	# Structural metadata alone is never enough. This class is admitted only when
	# the archived receipt is a reply the world actually received, carrying the
	# structured decision whose reason is the over-long one. A missing, failed or
	# otherwise unrelated receipt stays held.
	if not _received_overlong_reason(record):
		return ""
	if str(record.get("length_recovery_spent", "")) == request_id or str(_local_length_failures.get(id, "")) == request_id:
		return ""
	return REASON_TOO_LONG_DETAIL

func _received_overlong_reason(record: Dictionary) -> bool:
	var receipt: Variant = record.get("accepted_reply", null)
	if not receipt is Dictionary or not bool(receipt.get("ok", false)):
		return false
	var decision: Variant = receipt.get("decision")
	if not decision is Dictionary or not decision.get("reason") is String:
		return false
	return decision.reason.length() > DECISION_TEXT_LIMIT

func _own_seq(id: String) -> int:
	var seq := 0
	for event in town._state.life.events:
		if id in event.get("recipient_ids", []):
			seq = maxi(seq, int(event.seq))
	return seq

func _requires_review(record: Dictionary, id: String = "") -> bool:
	if record.get("status", "") in ["pending", "disconnected"]:
		return true
	if record.get("status", "") == "provider_error":
		return not _cold_recoverable(id, record)
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

func admission_closed() -> bool:
	## Whether this episode admits NEW resident decisions. A closed episode still
	## owns every coroutine that had already started.
	return _admission_closed

func close_admission(reason: String) -> bool:
	## Close admission to NEW resident decisions exactly once. Only the call that
	## really cut the episode off returns true, so a host reports the true cutoff.
	if _admission_closed:
		return false
	_admission_closed = true
	admission_closed_reason = reason
	shutdown_wait_seconds = 0.0
	shutdown_wait_timed_out = false
	return true

func in_flight_requests() -> Array:
	var pending: Array = []
	for id in inflight.keys():
		var entry: Dictionary = inflight[id]
		pending.append({"actor_id": id, "request_id": str(entry.get("request_id", "")), "epoch": int(entry.get("epoch", 0))})
	pending.sort_custom(func(left, right): return str(left.actor_id) < str(right.actor_id))
	return pending

func shutdown_readiness(delta: float) -> Dictionary:
	## One bounded step of the episode's shutdown wait, after admission closed.
	## `ready` is the host's permission to persist and exit: true when nothing is
	## in flight, or when the bound expired and the still-owed reply must be
	## reported instead of waited for forever.
	if not _admission_closed:
		return {"ready": false, "reason": "", "waited_seconds": 0.0, "timed_out": false,
			"in_flight": inflight.size(), "unresolved": []}
	if busy:
		shutdown_wait_seconds += maxf(delta, 0.0)
		shutdown_wait_timed_out = shutdown_wait_seconds >= shutdown_wait_limit
	return {"ready": not busy or shutdown_wait_timed_out, "reason": admission_closed_reason,
		"waited_seconds": shutdown_wait_seconds, "timed_out": shutdown_wait_timed_out,
		"in_flight": inflight.size(), "unresolved": in_flight_requests() if busy else []}

func shutdown_evidence() -> Dictionary:
	## The host's own stopping facts. `resolved` is true only when the episode ended
	## with every already-started reply applied by its own coroutine; a distinct
	## capture reason and a nonzero engine exit keep an unresolved one honest.
	return {"admission_closed": _admission_closed, "admission_closed_reason": admission_closed_reason,
		"wait_limit_seconds": shutdown_wait_limit,
		"waited_seconds": roundf(shutdown_wait_seconds * 1000.0) / 1000.0,
		"timed_out": shutdown_wait_timed_out,
		"resolved": _admission_closed and not busy and not shutdown_wait_timed_out,
		"in_flight": in_flight_requests()}

func ready_resident() -> String:
	# A closed episode admits no NEW resident decision, whatever the clock says.
	if _admission_closed:
		return ""
	if inflight.size() >= max_parallel:
		return ""
	var residents: Array = town.active_ids()
	for offset in residents.size():
		var id: String = residents[(_next_resident_index + offset) % residents.size()]
		var record := _record(id)
		if not brains.has(id) or inflight.has(id) or _requires_review(record, id) or _replan_cooling(record):
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
	if _admission_closed:
		# Already-started coroutines keep their own request and settle it themselves;
		# only a decision that has not begun is refused here.
		return {"ok": false, "code": "admission_closed", "actor_id": requested_id}
	var id := ready_resident() if requested_id.is_empty() else requested_id
	if id.is_empty():
		return {"ok": true, "code": "no_due_turn"}
	var previous := _record(id)
	if not brains.has(id) or inflight.has(id) or inflight.size() >= max_parallel:
		return {"ok": false, "code": "controller_unavailable", "actor_id": id}
	if _requires_review(previous, id):
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
	# Model-facing decision contract for THIS request: reply shape, required field
	# types, the provided aliases and the exact text bounds. Disclosure only - the
	# authoritative check in apply_reply is unchanged, still fail-closed, and never
	# truncates text, invents a choice or relaxes the bound.
	var request_rules: Dictionary = view.get("known_rules", {}).duplicate(true)
	request_rules["decision_format"] = {
		"reply": "one JSON object following this field contract",
		"action": "string naming exactly one id from available_actions",
		"reason": "string, required, at most %d characters" % DECISION_TEXT_LIMIT,
		"speech": "string, optional, only for actions whose action_details entry has speech_allowed true, at most %d characters" % DECISION_TEXT_LIMIT,
		"need": "optional object with capability_id and reason, only when no available action meets the need",
	}
	view["known_rules"] = request_rules
	# Context is bounded; canonical full history remains in the world save.
	view.experiences = view.get("experiences", []).slice(-16)
	var seen := _own_seq(id)
	var recovery_class := _cold_recovery_class(id, previous)
	var recovering := not recovery_class.is_empty()
	var migrated_previous := _archive_legacy_previous(id, previous)
	if not migrated_previous.ok:
		return migrated_previous
	var reviews: Array = previous.get("reviews", []).duplicate(true)
	if recovering:
		# Keep the exact prior failed receipt, its structural detail, its request id
		# and its epoch as world evidence before the recovery replaces the working
		# record. If this recovery turn fails the same way, its own newer receipt is
		# marked denied durably in that class's own spent channel, so a restart
		# cannot buy another paid retry for it.
		reviews.append({"status": previous.get("status", ""), "error": previous.get("error", ""),
			"error_detail": previous.get("error_detail", ""),
			"request_id": previous.get("request_id", ""), "epoch": epoch, "reason": "cold_restored_local_recovery"})
	var prepared: Dictionary = town.transaction(save_path, func():
		if not town._state.godot.has("resident_turns"):
			town._state.godot.resident_turns = {}
		town._state.godot.resident_turns[id] = {"status": "pending", "seen_seq": seen, "history": previous.get("history", []).duplicate(true),
			"controller_epoch": epoch, "controller_id": previous.get("controller_id", "local:gateway"), "request_number": number, "request_id": request_id,
			"choice_protocol": 2, "offered_actions": aliases.duplicate(true), "speech_actions": speech_actions.duplicate(), "reviews": reviews,
			"session_limit_recovery_spent": str(previous.get("session_limit_recovery_spent", "")),
			"length_recovery_spent": str(previous.get("length_recovery_spent", "")),
			"session_limit_recovery_attempt": recovery_class == "session_request_limit",
			"reason_recovery_attempt": recovery_class == REASON_TOO_LONG_DETAIL}
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

func _reply_archive_entry(id: String, request_id: String, reply: Dictionary, application_status: String,
		application_code: String, effect: Dictionary = {}, speech_delivery: Dictionary = {}) -> Dictionary:
	var decision: Variant = reply.get("decision", {})
	if not decision is Dictionary:
		decision = {}
	return {"archive_id": request_id, "world_id": town._state.world_id, "resident_id": id,
		"request_id": request_id, "provider_id": str(reply.get("provider_id", reply.get("provenance", ""))),
		"model_returned": bool(reply.get("model_returned", false)),
		"assistant_text_parts": reply.get("assistant_text_parts", []).duplicate(true) if reply.get("assistant_text_parts", []) is Array else [],
		"assistant_text": str(reply.get("assistant_text", "")), "original_reply": reply.duplicate(true),
		"reason": str(decision.get("reason", "")), "speech": str(decision.get("speech", "")),
		"delivered_text": str(speech_delivery.get("text", "")),
		"application": {"status": application_status, "code": application_code,
			"effect": effect.duplicate(true), "speech_delivery": speech_delivery.duplicate(true)}}

func _archive_reply(id: String, request_id: String, reply: Dictionary, application_status: String,
		application_code: String, effect: Dictionary = {}, speech_delivery: Dictionary = {}) -> Dictionary:
	return town.transaction(save_path, func():
		return _record_archive_entry(_reply_archive_entry(id, request_id, reply, application_status,
			application_code, effect, speech_delivery)))

func _archive_legacy_previous(id: String, previous: Dictionary) -> Dictionary:
	var old_reply: Variant = previous.get("accepted_reply", null)
	var old_request := str(previous.get("request_id", ""))
	if not old_reply is Dictionary or old_request.is_empty():
		return {"ok": true, "code": "no_legacy_reply"}
	# A full archive entry already owns this request.  The compatibility migration runs before
	# replacing `previous`, so re-reading the same accepted reply on every next step must not
	# manufacture a legacy_incomplete replay beside the complete record.
	var existing_archive: Variant = town._state.godot.get("resident_archive", null)
	if existing_archive is Dictionary and existing_archive.get("entries", null) is Dictionary \
			and existing_archive.entries.has(old_request):
		return {"ok": true, "duplicate": true, "code": "resident_archive_already_present",
			"archive_id": old_request}
	var old_effect: Variant = previous.get("result", {})
	var effect: Dictionary = old_effect if old_effect is Dictionary else {}
	var entry := _reply_archive_entry(id, old_request, old_reply,
		str(previous.get("status", "legacy")), str(effect.get("code", "legacy")), effect,
		{"attempted": false, "delivered": false, "code": "legacy_incomplete"})
	entry.source = "legacy_resident_turn"
	entry.complete = false
	entry.incomplete_fields = ["provider_id", "assistant_text", "speech_delivery"]
	return town.transaction(save_path, func(): return _record_archive_entry(entry))

func _record_archive_entry(entry: Dictionary) -> Dictionary:
	# Lightweight TownLife fixtures and older host adapters do not own the archive method.
	# Preserve their established turn semantics while the full TownRuntime opts into archiving.
	if not town.has_method("record_resident_reply"):
		return {"ok": true, "code": "resident_archive_unsupported_runtime"}
	return town.record_resident_reply(entry)

func _speech_delivery(id: String, request_id: String, speech: String, effect: Dictionary) -> Dictionary:
	if not effect.get("ok", false):
		return {"attempted": not speech.is_empty(), "delivered": false, "code": effect.get("code", "speech_rejected")}
	for event in town._state.life.get("events", []):
		if event is Dictionary and event.get("operation_id", "") == request_id and event.get("actor_id", "") == id and event.get("text", "") == speech:
			return {"attempted": true, "delivered": true, "code": "speech_delivered",
				"text": str(event.get("text", "")),
				"event_id": event.get("event_id", ""), "event_seq": event.get("seq", 0),
				"recipient_ids": event.get("recipient_ids", []).duplicate() if event.get("recipient_ids", []) is Array else []}
	# Social/visitor actions can deliver their own canonical text when the model omitted
	# optional speech. That actual event text is the dialogue archive, never a guessed thought.
	for event in town._state.life.get("events", []):
		if event is Dictionary and event.get("operation_id", "") == request_id and event.get("actor_id", "") == id and not str(event.get("text", "")).is_empty():
			return {"attempted": false, "delivered": true, "code": "speech_delivered",
				"text": str(event.get("text", "")),
				"event_id": event.get("event_id", ""), "event_seq": event.get("seq", 0),
				"recipient_ids": event.get("recipient_ids", []).duplicate() if event.get("recipient_ids", []) is Array else []}
	return {"attempted": false, "delivered": false, "code": "no_dialogue"}

func _recovery_refusal(id: String, current: Dictionary, request_id: String, reply: Dictionary,
		recovery: Dictionary) -> Dictionary:
	## Exact bindings for one already-settled paid reply. This reads state only: every
	## refusal returns before any transaction, so a rejected receipt changes nothing.
	var refuse: Callable = func(code: String) -> Dictionary:
		return {"ok": false, "duplicate": false, "code": code, "actor_id": id}
	if save_path.is_empty():
		return refuse.call("recovery_save_path_required")
	if str(current.get("status", "")) != "provider_error":
		return refuse.call("recovery_not_provider_error")
	if not RECOVERABLE_PROVIDER_ERRORS.has(str(current.get("error", ""))):
		return refuse.call("recovery_error_not_recoverable")
	var failed_value: Variant = current.get("accepted_reply", null)
	if not failed_value is Dictionary or bool(failed_value.get("ok", true)):
		return refuse.call("recovery_no_failed_reply")
	var failed: Dictionary = failed_value
	if str(recovery.get("world_id", "")) != str(town._state.world_id):
		return refuse.call("recovery_world_mismatch")
	if str(recovery.get("resident_id", "")) != id:
		return refuse.call("recovery_resident_mismatch")
	## The receipt's request and the resident's recorded request must both be this request.
	## Checked here, before any guard that could archive a late reply.
	if str(recovery.get("request_id", "")) != request_id or str(current.get("request_id", "")) != request_id:
		return refuse.call("recovery_request_mismatch")
	if int(recovery.get("controller_epoch", -1)) != int(current.get("controller_epoch", -2)):
		return refuse.call("recovery_epoch_mismatch")
	var operation := str(recovery.get("provider_operation_id", ""))
	if operation.is_empty() or str(current.get("provider_command_id", "")) != operation:
		return refuse.call("recovery_operation_mismatch")
	if str(reply.get("command_id", "")) != operation:
		return refuse.call("recovery_reply_operation_mismatch")
	if failed != recovery.get("original_failed_reply", null):
		return refuse.call("recovery_failed_reply_mismatch")
	var archive_refusal := _failure_archive_refusal(id, request_id, failed)
	if not archive_refusal.is_empty():
		return refuse.call(archive_refusal)
	if not _save_source_matches(str(recovery.get("source_sha256", ""))):
		return refuse.call("recovery_source_hash_mismatch")
	if inflight.has(id) or not town.pending_job(id).is_empty():
		return refuse.call("resident_working")
	return {}

func _failure_archive_refusal(id: String, request_id: String, failed: Dictionary) -> String:
	## The original provider_error archive entry must still be the authoritative record of
	## this request: its own failed reply intact, no reply recorded beside it. Read only.
	var archive: Variant = town._state.godot.get("resident_archive", {})
	if not archive is Dictionary or str(archive.get("world_id", "")) != str(town._state.world_id):
		return "recovery_archive_missing"
	var entries: Variant = archive.get("entries", null)
	if not entries is Dictionary or not entries.has(request_id):
		return "recovery_archive_missing"
	var entry: Variant = entries[request_id]
	if not entry is Dictionary:
		return "recovery_archive_missing"
	if str(entry.get("request_id", "")) != request_id or str(entry.get("resident_id", "")) != id \
			or str(entry.get("world_id", "")) != str(town._state.world_id):
		return "recovery_archive_identity_mismatch"
	if entry.get("original_reply", null) != failed:
		return "recovery_archive_reply_mismatch"
	var application: Variant = entry.get("application", {})
	if not application is Dictionary or str(application.get("status", "")) != "provider_error":
		return "recovery_archive_not_provider_error"
	var replays_value: Variant = entry.get("replays", [])
	if not replays_value is Array:
		return "recovery_archive_replays_invalid"
	var replays: Array = replays_value
	if not replays.is_empty():
		return "recovery_previously_recorded_reply"
	return ""

func _save_source_matches(expected_sha256: String) -> bool:
	## The receipt is bound to the exact source bytes it was extracted from. Re-read here
	## under the caller's writer lock, so a newer save can never be reconciled against an
	## older receipt.
	if expected_sha256.is_empty() or save_path.is_empty():
		return false
	var actual := FileAccess.get_sha256(save_path)
	return not actual.is_empty() and actual.to_lower() == expected_sha256.to_lower()

func apply_reply(id: String, epoch: int, request_id: String, reply: Dictionary, recovery: Dictionary = {}) -> Dictionary:
	## `recovery` is empty for every ordinary turn, so the normal path below is unchanged.
	## When it carries a settled-reply receipt, its exact bindings are enforced BEFORE any
	## existing guard, so a refused receipt can never archive, mutate or acknowledge anything.
	## A fully validated recovery then enters the one existing transaction below, where the
	## review metadata, the effect and the archive entry are written together. No controller
	## is reset, no epoch changes and no decision is produced here.
	var current := _record(id)
	var recovering := false
	if not recovery.is_empty():
		var refused := _recovery_refusal(id, current, request_id, reply, recovery)
		if not refused.is_empty():
			return refused
		recovering = true
	if int(current.get("controller_epoch", -1)) != epoch or current.get("request_id", "") != request_id:
		var archived_stale := _archive_reply(id, request_id, reply, "stale_controller_reply", "stale_controller_reply")
		return {"ok": false, "code": "stale_controller_reply", "actor_id": id, "archive": archived_stale}
	if current.get("status") != "pending" and not recovering:
		var duplicate: bool = current.get("accepted_reply", {}) == reply
		if duplicate:
			return {"ok": true, "duplicate": true, "code": "duplicate", "actor_id": id}
		var archived_conflict := _archive_reply(id, request_id, reply, "reply_conflict", "reply_conflict")
		return {"ok": false, "duplicate": false, "code": "reply_conflict", "actor_id": id, "archive": archived_conflict}
	var aliases: Dictionary = current.offered_actions
	var applied: Dictionary = town.transaction(save_path, func():
		var record: Dictionary = town._state.godot.resident_turns[id]
		if recovering:
			# Review metadata, the recovered effect and its archive entry share this one
			# transaction: the resident never passes through a persisted intermediate state.
			record.reviews.append({"status": str(current.get("status", "")), "error": str(current.get("error", "")),
				"error_detail": str(current.get("error_detail", "")), "request_id": request_id, "epoch": epoch,
				"reason": "host_settled_reply_recovery",
				"provider_operation_id": str(recovery.get("provider_operation_id", "")),
				"source_sha256": str(recovery.get("source_sha256", "")),
				"ledger_response_sha256": str(recovery.get("ledger_response_sha256", ""))})
		record.accepted_reply = reply.duplicate(true)
		record.command_id = request_id
		record.provider_command_id = reply.get("command_id", "")
		record.provenance = reply.get("provenance", "")
		# Each recovery attempt is a property of this one request, in its own class:
		# it is consumed here whatever the outcome, and re-decided at the next
		# admission. The reason class never touches the request-limit allowance.
		var recovery_attempt := bool(record.get("session_limit_recovery_attempt", false))
		var reason_recovery_attempt := bool(record.get("reason_recovery_attempt", false))
		record.session_limit_recovery_attempt = false
		record.reason_recovery_attempt = false
		if not reply.get("ok", false):
			record.status = "provider_error"
			record.error = reply.get("code", "unknown_provider_error")
			if record.error == Brain.SESSION_REQUEST_LIMIT_CODE:
				if recovery_attempt:
					# The recovery's own turn hit the cap again. That newer receipt
					# must stay denied, or every cold restart would buy one more paid
					# retry instead of holding the resident.
					record.session_limit_recovery_spent = request_id
				else:
					# Created here: the cause is still in force in this process, so this
					# failure is held rather than treated as a cold-restored one.
					_local_limit_failures[id] = request_id
			var archived_provider: Dictionary = _record_archive_entry(_reply_archive_entry(id, request_id, reply,
				"provider_error", str(record.error), {}, {"attempted": false, "delivered": false, "code": "no_world_action"}))
			if not archived_provider.ok:
				return archived_provider
			return {"ok": true, "code": "provider_error"}
		var decision = reply.get("decision")
		if not decision is Dictionary or not decision.get("action") is String or not decision.get("reason") is String:
			record.status = "provider_error"
			record.error = "invalid_decision"
			var archived_invalid: Dictionary = _record_archive_entry(_reply_archive_entry(id, request_id, reply,
				"provider_error", "invalid_decision", {}, {"attempted": false, "delivered": false, "code": "no_world_action"}))
			if not archived_invalid.ok:
				return archived_invalid
			return {"ok": true, "code": "provider_error"}
		if decision.reason.length() > DECISION_TEXT_LIMIT:
			record.status = "provider_error"
			record.error = "invalid_decision"
			record.error_detail = REASON_TOO_LONG_DETAIL
			# The unchanged 512 contract still refuses this reply. The one fresh
			# cold-restored turn is consumed here whatever comes of it: a rejection
			# created in this process is held as local, and a recovery refused the
			# same way is recorded against its own newer request, so no later cold
			# start can buy another paid turn for the same held receipt. The
			# request-limit class keeps its own separate allowance.
			if reason_recovery_attempt:
				record.length_recovery_spent = request_id
			else:
				_local_length_failures[id] = request_id
			var archived_long_reason: Dictionary = _record_archive_entry(_reply_archive_entry(id, request_id, reply,
				"provider_error", "reason_too_long", {}, {"attempted": false, "delivered": false, "code": "no_world_action"}))
			if not archived_long_reason.ok:
				return archived_long_reason
			return {"ok": true, "code": "provider_error"}
		if decision.has("speech") and not decision.speech is String:
			record.status = "provider_error"
			record.error = "invalid_decision"
			var archived_invalid_speech: Dictionary = _record_archive_entry(_reply_archive_entry(id, request_id, reply,
				"provider_error", "invalid_decision", {}, {"attempted": false, "delivered": false, "code": "no_world_action"}))
			if not archived_invalid_speech.ok:
				return archived_invalid_speech
			return {"ok": true, "code": "provider_error"}
		if decision.has("speech") and decision.speech.length() > DECISION_TEXT_LIMIT:
			record.status = "provider_error"
			record.error = "invalid_decision"
			record.error_detail = "speech_too_long"
			var archived_long_speech: Dictionary = _record_archive_entry(_reply_archive_entry(id, request_id, reply,
				"provider_error", "speech_too_long", {}, {"attempted": false, "delivered": false, "code": "no_world_action"}))
			if not archived_long_speech.ok:
				return archived_long_speech
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
		var delivered_speech: Dictionary = speech_delivery if not speech_delivery.is_empty() else _speech_delivery(id, request_id, str(decision.get("speech", "")), effect)
		var archived_settled: Dictionary = _record_archive_entry(_reply_archive_entry(id, request_id, reply,
			record.status, str(effect.get("code", record.status)), effect, delivered_speech))
		if not archived_settled.ok:
			return archived_settled
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
	# The public baking route keeps its own journal, and it sits between the material and place
	# journals in the fixed order (trade, life, materials, baking, places), first match only. The
	# world rejects a bake command id that is already live in any of those journals, so a bake
	# receipt can never be shadowed by - or shadow - another module's command.
	var baking_commands: Dictionary = town._state.godot.get("baking", {}).get("commands", {})
	# Voluntary place trips and place-bound rest keep their own journal; without it an accepted
	# travel choice would still look like "no authoritative execution receipt" after arrival.
	var place_commands: Dictionary = town._state.godot.get("places", {}).get("commands", {})
	for item in history:
		if not item is Dictionary:
			continue
		var command_id := str(item.get("command_id", ""))
		var command: Dictionary = trade_commands.get(command_id, life_commands.get(command_id,
			material_commands.get(command_id, baking_commands.get(command_id, place_commands.get(command_id, {})))))
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
