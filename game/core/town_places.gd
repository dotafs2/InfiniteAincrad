extends "res://core/town_runtime.gd"
## Public places: personal knowledge earned from a real notice or direct sight, voluntary
## travel along the verified road graph, and rest at a place under the EXISTING rest rule.
##
## Boundaries held here:
##  - a resident only ever sees places it personally learned; nothing is injected into every
##    brain, and another resident's knowledge/private data never appears in the view;
##  - knowledge is derived from persisted, attributed events (`place_learned`) whose operation
##    id is a pure function of (source, resident, place), so a duplicate is impossible and a
##    world with no such event loads unchanged;
##  - travel and rest produce no resource, no stock and no production; a blocked trip closes
##    honestly as `travel_blocked` with no arrival receipt;
##  - the trip keeps its own command, target and progress so a cold restore resumes it without
##    a second arrival receipt.

const Catalog := preload("res://spatial/town_places.gd")

const PLACES_SCHEMA_VERSION := 1
const PLACE_PREFIX := "place:"
const TRAVEL_PREFIX := "place:travel:"
const REST_PREFIX := "place:rest:"
const LEARN_NOTICE := "public_notice"
const LEARN_SIGHT := "direct_sight"
const LEARN_SOURCES := [LEARN_NOTICE, LEARN_SIGHT]
const TRAVEL_BLOCKED_SECONDS := 45.0
## A trip closes as blocked only when the REAL route progress (distance still to walk along the
## verified road graph) stops improving by this much. A body oscillating against a wall cannot
## reset the timer, and a short away-from-goal road leg is not penalised either.
const TRAVEL_PROGRESS_STEP := 0.25
const PLACE_EVENT_TYPES := ["place_learned", "place_visited", "travel_blocked"]

## Journey-stall evidence (H36): world-scoped physical facts for an ACTIVE journey that stops
## making progress, exported to the existing background-GM projection. It is not a verdict: the
## record says only where the resident was, where it was going and how long it has not improved,
## and it stays the same episode while that journey continues, closing when the journey ends.
const JOURNEY_STALL_KEY_PREFIX := "journey_stall:"
const JOURNEY_STALL_NO_PROGRESS_SECONDS := 8.0
const JOURNEY_STALL_PROGRESS_EPSILON := 0.05
const JOURNEY_STALL_ARRIVAL_RADIUS := 0.45
const JOURNEY_STALL_CLOSED_LIMIT := 24
const JOURNEY_STALL_KINDS := ["approach", "place_travel"]

func _journey_stalls() -> Dictionary:
	var value: Variant = _state.godot.get("journey_stalls", {})
	return value if value is Dictionary else {}

func _ensure_journey_stalls() -> Dictionary:
	if not _state.godot.get("journey_stalls", null) is Dictionary:
		_state.godot.journey_stalls = {"schema_version": 1, "next": 0, "records": {}}
	var store: Dictionary = _state.godot.journey_stalls
	if not store.get("records") is Dictionary:
		store.records = {}
	return store

func _journey_stall_records() -> Array:
	var store := _journey_stalls()
	var records: Dictionary = store.get("records", {})
	var keys: Array = records.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var record: Variant = records[key]
		if record is Dictionary:
			result.append(record)
	return result

func _allocate_journey_stall_key() -> String:
	var store := _ensure_journey_stalls()
	var sequence: int = maxi(0, int(store.get("next", 0)))
	var records: Dictionary = store.records
	var key := ""
	while true:
		sequence += 1
		key = "%s%d" % [JOURNEY_STALL_KEY_PREFIX, sequence]
		if not records.has(key):
			break
	store.next = sequence
	return key

func _active_journey_stall(id: String, command_id: String) -> Dictionary:
	## The identity of one LIVE intent: the open episode, the silent watch, or — after a stall that
	## ended because the resident genuinely made progress — that very same record, so the SAME
	## command can never accumulate a second issue id. A record closed because its command ended is
	## never reused; a brand-new command gets a brand-new identity.
	var records: Dictionary = _journey_stalls().get("records", {})
	var keys: Array = records.keys()
	keys.sort()
	var watching: Dictionary = {}
	var resumable: Dictionary = {}
	for key in keys:
		var record: Variant = records[key]
		if not record is Dictionary or str(record.get("resident_id", "")) != id or str(record.get("command_id", "")) != command_id:
			continue
		if record.get("status") == "open":
			return {"key": str(key), "record": record}
		if record.get("status") == "watching":
			watching = {"key": str(key), "record": record}
			continue
		if str(record.get("close_reason", "")) == "progress_resumed":
			resumable = {"key": str(key), "record": record}
	if not watching.is_empty():
		return watching
	return resumable

func _journey_progress_scalar(kind: String, job: Dictionary, id: String, position_value: Vector3) -> float:
	## The physical progress measure, from the world's own save, never from a model or a guess:
	## how much road is still to walk to a public point, or how far the counterparty meeting point
	## still is. Both improve monotonically as the body genuinely advances.
	var target := _vector(job.get("target_position", [0, 0, 0]))
	if not target.is_finite() or not position_value.is_finite():
		return -1.0
	if kind == "place_travel":
		return _remaining_route(str(job.get("place_id", "")), job, position_value)
	return Vector2(target.x - position_value.x, target.z - position_value.z).length()

func observe_journey_stall(id: String, kind: String, position_value: Vector3, elapsed: float) -> Dictionary:
	## Called by the real scene every world step for a resident whose own choice left an approach
	## or a public-place trip pending. Identity is (resident, command): the same journey keeps one
	## episode while it continues, so a report cannot churn or duplicate.
	if not JOURNEY_STALL_KINDS.has(kind) or id not in active_ids():
		return _failure("invalid_journey_stall_call")
	if not position_value.is_finite() or not is_finite(elapsed) or elapsed <= 0.0:
		return _failure("invalid_journey_stall_call")
	var job: Dictionary = pending_job(id)
	if job.is_empty() or str(job.get("action", "")) != ("travel" if kind == "place_travel" else "approach"):
		return _failure("journey_stall_without_pending_job")
	var scalar := _journey_progress_scalar(kind, job, id, position_value)
	if scalar < 0.0:
		return _failure("invalid_journey_stall_progress")
	var command_id := str(job.get("command_id", ""))
	var active := _active_journey_stall(id, command_id)
	var record: Dictionary = active.get("record", {})
	var record_key := str(active.get("key", ""))
	if record.is_empty() or str(record.get("kind", "")) != kind:
		record_key = _allocate_journey_stall_key()
		record = {"episode_id": record_key, "resident_id": id, "command_id": command_id, "kind": kind,
			"place_id": str(job.get("place_id", "")), "target_position": job.get("target_position", []).duplicate(),
			"observed_position": [position_value.x, position_value.y, position_value.z],
			"best_progress": scalar, "no_progress_seconds": 0.0, "opened_elapsed": 0.0,
			"status": "watching", "reported": false, "close_reason": ""}
	elif record.get("status") == "closed":
		## The same live command stalled again after real progress: keep the identity, drop the old
		## close reason and measure this new stagnation from scratch. The earlier progress is not
		## denied and the earlier stalled period is not re-reported as a second issue.
		record.status = "watching"
		record.close_reason = ""
		record.no_progress_seconds = 0.0
		record.best_progress = scalar
	var best := float(record.get("best_progress", scalar))
	if scalar <= JOURNEY_STALL_ARRIVAL_RADIUS or scalar <= best - JOURNEY_STALL_PROGRESS_EPSILON:
		## Real progress (including slow progress and a necessary detour) or arrival: no stall time.
		record.best_progress = minf(best, scalar)
		record.no_progress_seconds = 0.0
		if record.get("status") == "open":
			_close_journey_stall(record, "progress_resumed")
	else:
		record.no_progress_seconds = float(record.get("no_progress_seconds", 0.0)) + elapsed
		if record.get("status") == "watching" and float(record.no_progress_seconds) >= JOURNEY_STALL_NO_PROGRESS_SECONDS:
			record.status = "open"
			record.reported = true
			record.opened_elapsed = float(_state.godot.elapsed_seconds)
			_append_life_event({"type": "journey_stall_noticed", "actor_id": id, "subject_id": id,
				"recipient_ids": [id], "operation_id": record.episode_id, "source": "host_physics_frame_position",
				"kind": kind, "text": "我一直在往那个方向走，但这段路没有前进；我还没有到达。"})
	record.observed_position = [position_value.x, position_value.y, position_value.z]
	var store := _ensure_journey_stalls()
	store.records[record_key] = record
	_prune_journey_stalls()
	return {"ok": true, "code": "journey_stall_" + str(record.get("status", ""))}

func _close_journey_stall(record: Dictionary, reason: String) -> void:
	record.status = "closed"
	record.close_reason = reason

func _close_journey_stalls_without_pending_job() -> void:
	## Closure driven by the world's own job bookkeeping: when the journey ends for ANY reason
	## (arrival, cancellation, replacement), its episode closes instead of staying open forever.
	var records: Dictionary = _journey_stalls().get("records", {})
	for key in records.keys():
		var record: Variant = records[key]
		if not record is Dictionary or record.get("status") == "closed":
			continue
		var id := str(record.get("resident_id", ""))
		var job: Dictionary = pending_job(id) if id in active_ids() else {}
		var still_pending := str(job.get("command_id", "")) == str(record.get("command_id", ""))
		if not still_pending:
			_close_journey_stall(record, "journey_released")

func _prune_journey_stalls() -> void:
	var store := _ensure_journey_stalls()
	var records: Dictionary = store.records
	var closed: Array = []
	for key in records.keys():
		var record: Variant = records[key]
		if record is Dictionary and record.get("status") == "closed":
			closed.append(str(key))
	closed.sort()
	while closed.size() > JOURNEY_STALL_CLOSED_LIMIT:
		records.erase(closed.pop_front())

func journey_stall_diagnostics() -> Array:
	## Read-only, world-scoped projection for the existing background-GM export. Same privacy
	## boundary as the material diagnostic: physical facts only, never a resident's private
	## reason, never another resident's data, and never a verdict about whether this is a defect.
	var result: Array = []
	for record in _journey_stall_records():
		if record.get("status") != "open" or not record.get("reported", false):
			continue
		var observed := _vector(record.get("observed_position", [0, 0, 0]))
		var target := _vector(record.get("target_position", [0, 0, 0]))
		var kind := str(record.get("kind", ""))
		result.append({"world_id": _state.world_id, "resident_id": str(record.get("resident_id", "")),
			"job_command_id": str(record.get("command_id", "")), "episode_id": str(record.get("episode_id", "")),
			"journey": kind, "kind": kind, "place_id": str(record.get("place_id", "")),
			"status": "open", "opened_elapsed": float(record.get("opened_elapsed", 0.0)),
			"no_progress_seconds": float(record.get("no_progress_seconds", 0.0)),
			"remaining_distance": observed.distance_to(target) if target.is_finite() else -1.0,
			"remaining_route_m": _remaining_route(str(record.get("place_id", "")), record, observed) if kind == "place_travel" else -1.0,
			"progress_evidence": {"observed_position": record.get("observed_position", []).duplicate(),
				"target_position": record.get("target_position", []).duplicate(),
				"arrival_radius": JOURNEY_STALL_ARRIVAL_RADIUS, "no_progress_seconds": float(record.get("no_progress_seconds", 0.0)),
				"progress_epsilon": JOURNEY_STALL_PROGRESS_EPSILON, "progress_measure": "route_remaining_m" if kind == "place_travel" else "remaining_meeting_distance_m",
				"observation_source": "host_physics_frame_position"}})
	return result

func _places() -> Dictionary:
	var value: Variant = _state.godot.get("places", {})
	return value if value is Dictionary else {}

func _ensure_places() -> Dictionary:
	if not _state.godot.get("places", null) is Dictionary:
		_state.godot.places = {"schema_version": PLACES_SCHEMA_VERSION, "commands": {}, "jobs": {}}
	var places: Dictionary = _state.godot.places
	if not places.get("commands") is Dictionary:
		places.commands = {}
	if not places.get("jobs") is Dictionary:
		places.jobs = {}
	return places

func public_place_ids() -> Array:
	return Catalog.place_ids()

func _place_slot(id: String, place_id: String) -> int:
	## Stable: a resident's own ordinal in the source roster is its public point, so ten residents
	## get ten distinct points and a saved target never depends on dictionary ordering. Beyond the
	## authored capacity the place is honestly NOT offered (-1): no modulo alias, no second-choice
	## allocator and never a point another resident already owns.
	var index: int = active_ids().find(id)
	if index < 0:
		return -1
	if index < Catalog.PLACE_CAPACITY:
		return index
	return -1

func place_point(place_id: String, id: String = "") -> Vector3:
	if not Catalog.is_place_id(place_id):
		return Vector3.INF
	if id.is_empty() or id not in active_ids():
		return Catalog.point_of(place_id)
	var slot := _place_slot(id, place_id)
	if slot < 0:
		return Vector3.INF
	return Catalog.slot_point(place_id, slot)

func place_knowledge(id: String) -> Dictionary:
	## Personal, attributed knowledge: place_id -> {source, source_id, event_id, seq}.
	var result: Dictionary = {}
	if id.is_empty():
		return result
	for event in _state.life.events:
		if not event is Dictionary or event.get("type", "") != "place_learned":
			continue
		if not event.get("recipient_ids", []).has(id) or str(event.get("actor_id", "")) != id:
			continue
		var place_id := str(event.get("place_id", ""))
		if not Catalog.is_place_id(place_id) or result.has(place_id):
			continue
		result[place_id] = {"source": str(event.get("source_kind", "")), "source_id": str(event.get("source_id", "")),
			"event_id": str(event.get("event_id", "")), "seq": int(event.get("seq", 0))}
	return result

func known_place_ids(id: String) -> Array:
	var ids: Array = place_knowledge(id).keys()
	ids.sort()
	return ids

func _learn_operation_id(source_kind: String, id: String, place_id: String) -> String:
	return "places:%s:%s:%s" % [source_kind, id, place_id]

func _learn_place(id: String, place_id: String, source_kind: String, source_id: String, source_position: Vector3) -> bool:
	## One idempotent, attributed transaction per (resident, place). A repeated perception
	## cannot add a second record: the operation id is fully derived from its inputs.
	if not Catalog.is_place_id(place_id) or id not in active_ids() or not LEARN_SOURCES.has(source_kind):
		return false
	if place_knowledge(id).has(place_id):
		# Already known, from whichever source actually taught it first: no second record,
		# no rewritten attribution and no state write at all.
		return false
	var operation_id := _learn_operation_id(source_kind, id, place_id)
	for event in _state.life.events:
		if event is Dictionary and str(event.get("operation_id", "")) == operation_id:
			return false
	_ensure_places()
	_append_life_event({"type": "place_learned", "actor_id": id, "subject_id": id, "recipient_ids": [id],
		"operation_id": operation_id, "source": "public_notice_or_sight", "source_kind": source_kind,
		"source_id": source_id, "place_id": place_id,
		"source_position": [source_position.x, source_position.y, source_position.z],
		"text": "我%s，知道%s是公共可以去的地方。" % ["读了出口的公共路牌" if source_kind == LEARN_NOTICE else "亲眼看到了那里", Catalog.place(place_id)["label"]]})
	return true

func observe_public_places(id: String, notice_visible: bool, visible_place_ids: Array) -> Dictionary:
	## Called by the real scene inside the world transaction, after it has answered the
	## physics line-of-sight questions. The world still re-checks its own authoritative
	## distance rules and every catalog id; it never trusts a caller-supplied place id.
	if id not in active_ids() or _places().has("_frozen"):
		return {"ok": false, "code": "invalid_observer"}
	var learned: Array = []
	var notice: Dictionary = Catalog.NOTICE
	var notice_point := Vector3(notice["position"][0], notice["position"][1], notice["position"][2])
	if notice_visible and position_of(id).distance_to(notice_point) <= float(notice["read_range_m"]):
		for place_id in Catalog.notice_place_ids():
			if _learn_place(id, str(place_id), LEARN_NOTICE, str(notice["id"]), notice_point):
				learned.append(str(place_id))
	for place_value in visible_place_ids:
		var place_id := str(place_value)
		if not Catalog.is_place_id(place_id):
			continue
		var anchor := Catalog.point_of(place_id)
		if position_of(id).distance_to(anchor) > Catalog.DIRECT_SIGHT_RANGE:
			continue
		if _learn_place(id, place_id, LEARN_SIGHT, place_id, anchor):
			learned.append(place_id)
	return {"ok": true, "code": "place_learned" if not learned.is_empty() else "no_new_place_knowledge",
		"actor_id": id, "learned": learned}

func place_travel_blocked(id: String) -> Dictionary:
	## Read-only projection of a still-pending trip that is not making progress.
	var job: Dictionary = _places().get("jobs", {}).get(id, {})
	if job.is_empty():
		return {}
	var target := _vector(job.get("target_position", [0, 0, 0]))
	var record := {"command_id": str(job.get("command_id", "")), "place_id": str(job.get("place_id", "")),
		"no_progress_seconds": float(job.get("no_progress_seconds", 0.0)),
		"remaining_distance": position_of(id).distance_to(target) if target.is_finite() else -1.0}
	return record if record.no_progress_seconds >= TRAVEL_BLOCKED_SECONDS else {}

func observe_place_travel(id: String, position_value: Vector3, delta: float) -> void:
	## Physical travel observation for place trips. The scene passes the collision-resolved body
	## position and the unpaused seconds of this batch; the world owns the verdict. Progress is
	## measured on the verified road graph, so a wall really closes the trip and oscillation
	## around it cannot. Forward progress is credited cumulatively in fixed milestones, so slow but
	## steady movement keeps the trip alive while a body rocking against a wall earns no credit.
	var job: Dictionary = _places().get("jobs", {}).get(id, {})
	if job.is_empty() or not position_value.is_finite() or not is_finite(delta) or delta <= 0.0:
		return
	var remaining := _remaining_route(str(job.get("place_id", "")), job, position_value)
	if remaining < 0.0:
		return
	var best := float(job.get("best_remaining", INF))
	var gain := 0.0
	if not is_finite(best):
		job.best_remaining = remaining
	else:
		gain = maxf(0.0, best - remaining)
		job.best_remaining = best - gain
	var credit := float(job.get("progress_credit", 0.0)) + gain
	while credit >= TRAVEL_PROGRESS_STEP:
		credit -= TRAVEL_PROGRESS_STEP
		job.no_progress_seconds = 0.0
	job.progress_credit = credit
	if gain <= 0.0:
		job.no_progress_seconds = float(job.get("no_progress_seconds", 0.0)) + delta
	job.last_position = [position_value.x, position_value.y, position_value.z]

func _remaining_route(place_id: String, job: Dictionary, position_value: Vector3) -> float:
	## Distance still to walk: from the body's nearest verified road node along the graph to the
	## job's own saved point. The saved target is authoritative, so this survives roster changes.
	if not Catalog.is_place_id(place_id):
		return -1.0
	var target := _vector(job.get("target_position", [0, 0, 0]))
	if not target.is_finite():
		return -1.0
	for slot in Catalog.offset_count(place_id):
		if Catalog.slot_point(place_id, slot).distance_to(target) <= 0.05:
			return Catalog.road_length(place_id, position_value, slot)
	return Catalog.road_length(place_id, position_value, 0)

func _close_place_job(id: String, job: Dictionary, ok: bool, code: String) -> Dictionary:
	var places := _ensure_places()
	var command_id := str(job.get("command_id", ""))
	var place_id := str(job.get("place_id", ""))
	var target := _vector(job.get("target_position", [0, 0, 0]))
	var receipt := {"ok": ok, "code": code, "actor_id": id, "command_id": command_id,
		"place_id": place_id, "target_position": job.get("target_position", []).duplicate()}
	if places.get("commands", {}).has(command_id):
		places.commands[command_id].status = "completed" if ok else "rejected"
		places.commands[command_id].result = receipt.duplicate(true)
	places.jobs.erase(id)
	if ok:
		_append_life_event({"type": "place_visited", "actor_id": id, "subject_id": id, "recipient_ids": [id],
			"operation_id": command_id, "source": str(job.get("provenance", "local_rule_policy")),
			"place_id": place_id, "target_position": job.get("target_position", []).duplicate(),
			"text": "我按自己知道的路走到了%s。" % Catalog.place(place_id)["label"]})
	else:
		_append_life_event({"type": "travel_blocked", "actor_id": id, "subject_id": id, "recipient_ids": [id],
			"operation_id": command_id, "source": str(job.get("provenance", "local_rule_policy")),
			"place_id": place_id, "no_progress_seconds": float(job.get("no_progress_seconds", 0.0)),
			"remaining_distance": position_of(id).distance_to(target) if target.is_finite() else -1.0,
			"text": "这次去%s的路走不通，我停了下来，没有到达。" % Catalog.place(place_id)["label"]})
	return receipt

func advance(delta: float) -> Dictionary:
	var result := super.advance(delta)
	if not result.ok:
		return result
	var places := _places()
	if places.is_empty():
		return result
	# Place-bound rest is executed by the world's own rest rule; its option journal is settled
	# here from that one authoritative command, exactly once, so no forever-pending mirror stays
	# behind while the resident's life continues.
	for command_id in places.get("commands", {}).keys():
		var record: Dictionary = places.commands[command_id]
		if str(record.get("status", "")) != "pending" or not record.has("place_id"):
			continue
		var base: Dictionary = _state.godot.commands.get(command_id, {})
		if base.is_empty() or str(base.get("status", "pending")) == "pending":
			continue
		record.status = str(base.status)
		record.result = base.get("result", {}).duplicate(true)
	for id in places.get("jobs", {}).keys().duplicate():
		var job: Dictionary = places.get("jobs", {}).get(id, {})
		if job.is_empty() or id not in active_ids():
			continue
		var target := _vector(job.get("target_position", [0, 0, 0]))
		if not target.is_finite():
			continue
		if position_of(id).distance_to(target) <= Catalog.ARRIVAL_RADIUS:
			result.completed.append(_close_place_job(id, job, true, "place_visited"))
		elif float(job.get("no_progress_seconds", 0.0)) >= TRAVEL_BLOCKED_SECONDS:
			# Bounded, honest failure: no arrival, no receipt of success, no teleport. The
			# resident keeps its identity/history and may choose again afterwards.
			result.completed.append(_close_place_job(id, job, false, "travel_blocked"))
	## After the world's own journey endings, a journey that is no longer pending takes its stall
	## episode with it in the SAME transaction, so no still-open episode can outlive its journey.
	if not _journey_stalls().is_empty():
		_close_journey_stalls_without_pending_job()
	return result

func _place_job(id: String) -> Dictionary:
	var job: Dictionary = _places().get("jobs", {}).get(id, {})
	return job

func _busy(id: String) -> bool:
	return super._busy(id) or not _place_job(id).is_empty()

func pending_job(id: String) -> Dictionary:
	var job := _place_job(id)
	if not job.is_empty():
		return job.duplicate(true)
	return super.pending_job(id)

func destination(id: String, action: String) -> Vector3:
	## Only the action that IS pending may be answered from a public point: a place trip answers
	## destination(id, "travel") and a place-bound rest answers destination(id, "rest"). Everything
	## else - the fixed home/work-station lookup used by repair and workstation callers - keeps the
	## original behaviour, so a public square never turns into a workshop or a residence.
	var public_target := _pending_public_point(id, action)
	if public_target.is_finite():
		return public_target
	return super.destination(id, action)

func _pending_public_point(id: String, action: String) -> Vector3:
	var job := _place_job(id)
	if not job.is_empty() and str(job.get("action", "")) == action and _valid_position(job.get("target_position")):
		return _vector(job.target_position)
	var pending: Dictionary = _state.godot.pending.get(id, {})
	if pending.is_empty() or not pending.has("place_id"):
		return Vector3.INF
	if str(pending.get("action", "")) != action or not _valid_position(pending.get("target_position")):
		return Vector3.INF
	return _vector(pending.target_position)

func trade_options(id: String) -> Array:
	var result := super.trade_options(id)
	if id not in active_ids() or _busy(id):
		return result
	var known := known_place_ids(id)
	for place_value in known:
		var place_id := str(place_value)
		var target := place_point(place_id, id)
		if not target.is_finite():
			# No free public point for this resident at this place right now: the place is honestly
			# not offered instead of sharing a point someone else already occupies.
			continue
		var entry: Dictionary = Catalog.place(place_id)
		if position_of(id).distance_to(target) <= Catalog.ARRIVAL_RADIUS:
			if _can_rest_here(id):
				_option(result, {"id": REST_PREFIX + place_id, "action": "rest",
					"label": "在%s休息60秒，恢复精力" % entry["label"],
					"speech_allowed": false, "_place_id": place_id,
					"target_position": [target.x, target.y, target.z]})
			continue
		_option(result, {"id": TRAVEL_PREFIX + place_id, "action": "travel",
			"label": "走到%s并停在那里（公共地点，沿街步行）" % entry["label"],
			"speech_allowed": false, "_place_id": place_id,
			"target_position": [target.x, target.y, target.z]})
	return result

func _can_rest_here(id: String) -> bool:
	return "rest" in available(id)

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if not option_id.begins_with(PLACE_PREFIX):
		var places := _places()
		if places.get("commands", {}).has(command_id):
			return _failure("command_conflict")
		return super.submit_trade(id, option_id, command_id, provenance, speech)
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if not speech.is_empty():
		return _failure("speech_not_supported_for_action")
	# Validation stays read-only: a rejected option must not create the namespace.
	var places := _places()
	var payload := {"actor_id": id, "action": "place_option", "option_id": option_id, "provenance": provenance}
	if places.get("commands", {}).has(command_id):
		var prior: Dictionary = places.commands[command_id]
		var same: bool = prior.get("payload") == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if _trade().get("commands", {}).has(command_id) or _state.godot.commands.has(command_id):
		return _failure("command_conflict")
	var option := {}
	for candidate in trade_options(id):
		if candidate.get("id") == option_id:
			option = candidate
			break
	if option.is_empty():
		return _failure("option_unavailable")
	var place_id := str(option.get("_place_id", ""))
	if not Catalog.is_place_id(place_id) or not known_place_ids(id).has(place_id):
		return _failure("place_not_known")
	var target: Array = option.get("target_position", [])
	if not _valid_position(target) or _vector(target).distance_to(place_point(place_id, id)) > 0.05:
		return _failure("invalid_place_target")
	if option.get("action") == "rest":
		return _start_place_rest(id, place_id, target, command_id, provenance, payload)
	if option.get("action") != "travel":
		return _failure("invalid_place_action")
	places = _ensure_places()
	var origin := position_of(id)
	var best_remaining := -1.0
	for slot in Catalog.offset_count(place_id):
		if Catalog.slot_point(place_id, slot).distance_to(_vector(target)) <= 0.05:
			best_remaining = Catalog.road_length(place_id, origin, slot)
			break
	if best_remaining < 0.0:
		return _failure("invalid_place_target")
	places.commands[command_id] = {"payload": payload, "status": "pending"}
	places.jobs[id] = {"action": "travel", "command_id": command_id, "place_id": place_id, "provenance": provenance,
		"elapsed": 0.0, "duration_seconds": 0.0, "target_position": target.duplicate(),
		"last_position": [origin.x, origin.y, origin.z], "no_progress_seconds": 0.0,
		"best_remaining": best_remaining, "progress_credit": 0.0}
	return {"ok": true, "code": "place_travel_started", "pending": true, "place_id": place_id}

func _start_place_rest(id: String, place_id: String, target: Array, command_id: String, provenance: String, payload: Dictionary) -> Dictionary:
	## Rest at a place reuses the world's own rest action, duration and energy rule; the only
	## addition is the target the resident must actually stand at.
	if not _can_rest_here(id):
		return _failure("rest_unavailable")
	if position_of(id).distance_to(_vector(target)) > Catalog.ARRIVAL_RADIUS:
		return _failure("not_at_place")
	var started := start_action(id, "rest", command_id, provenance, _vector(target))
	if not started.ok:
		return started
	var places := _ensure_places()
	places.commands[command_id] = {"payload": payload, "status": "pending", "place_id": place_id}
	var pending: Dictionary = _state.godot.pending[id]
	pending.place_id = place_id
	pending.target_position = target.duplicate()
	_state.godot.commands[command_id].payload.place_id = place_id
	return {"ok": true, "code": "place_rest_started", "pending": true, "place_id": place_id}

func resident_view(id: String = "") -> Dictionary:
	var view := super.resident_view(id)
	if view.is_empty():
		return view
	var knowledge := place_knowledge(id)
	var known: Array = []
	var ids: Array = knowledge.keys()
	ids.sort()
	for place_value in ids:
		var place_id := str(place_value)
		var entry: Dictionary = Catalog.place(place_id)
		known.append({"place_id": place_id, "label": entry.get("label", place_id),
			"public_use": entry.get("public_use", ""), "source": knowledge[place_id].get("source", ""),
			"source_id": knowledge[place_id].get("source_id", ""),
			"learned_event_id": knowledge[place_id].get("event_id", ""), "seq": knowledge[place_id].get("seq", 0)})
	view["known_places"] = known
	view["place_travel"] = {"arrival_radius_m": Catalog.ARRIVAL_RADIUS,
		"note": "只有你本人读过公共路牌或亲眼见过的地点才会出现在可选动作里；步行沿已修好的街道，公共地点不产出食物、材料或存货。"}
	var blocked := place_travel_blocked(id)
	if not blocked.is_empty():
		view["unavailable_actions"].append({"action": "travel", "place_id": blocked.place_id,
			"command_id": blocked.command_id, "reason": "这次出行已经%.1f秒没有前进，仍在等待真实到达；到达或确认走不通之前不会有到达回执。" % float(blocked.no_progress_seconds)})
	return view

func _validate_places(value: Dictionary) -> Dictionary:
	var g: Dictionary = value.godot
	var raw: Variant = g.get("places", {})
	if raw == {}:
		for event in value.life.events:
			if event is Dictionary and PLACE_EVENT_TYPES.has(str(event.get("type", ""))):
				return _failure("place_state_missing")
		return {"ok": true, "code": "places_absent"}
	if not raw is Dictionary or not raw.get("commands") is Dictionary or not raw.get("jobs") is Dictionary or typeof(raw.get("schema_version", null)) != TYPE_INT or raw.schema_version != PLACES_SCHEMA_VERSION:
		return _failure("invalid_places_state")
	var places: Dictionary = raw
	var active: Array = g.positions.keys()
	for command_id in places.commands:
		var command: Variant = places.commands[command_id]
		if not command_id is String or not _validate_decision_command_id(command_id).ok or not command is Dictionary:
			return _failure("invalid_place_command")
		var record: Dictionary = command
		var payload_value: Variant = record.get("payload")
		if not payload_value is Dictionary:
			return _failure("invalid_place_command")
		var payload: Dictionary = payload_value
		if not _exact_keys(payload, ["actor_id", "action", "option_id", "provenance"]) or payload.action != "place_option":
			return _failure("invalid_place_command")
		if payload.actor_id not in active or payload.provenance not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_place_command")
		if not payload.option_id is String or (not payload.option_id.begins_with(TRAVEL_PREFIX) and not payload.option_id.begins_with(REST_PREFIX)):
			return _failure("invalid_place_command")
		var option_place := str(record.get("place_id", "")) if record.has("place_id") else str(payload.option_id).trim_prefix(TRAVEL_PREFIX).trim_prefix(REST_PREFIX)
		if not Catalog.is_place_id(option_place):
			return _failure("invalid_place_command")
		if record.get("status") not in ["pending", "completed", "rejected"]:
			return _failure("invalid_place_command")
	for id in places.jobs:
		var job_value: Variant = places.jobs[id]
		if id not in active or not job_value is Dictionary:
			return _failure("invalid_place_job")
		var job: Dictionary = job_value
		var place_id := str(job.get("place_id", ""))
		if job.get("action") != "travel" or not Catalog.is_place_id(place_id) or job.get("provenance") not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_place_job")
		var target: Variant = job.get("target_position")
		if not _valid_position(target) or not _is_catalog_point(place_id, _vector(target)):
			return _failure("invalid_place_job_target")
		if not places.commands.has(job.get("command_id")) or places.commands[job.command_id].status != "pending":
			return _failure("invalid_place_job_command")
		if str(places.commands[job.command_id].payload.get("actor_id", "")) != id:
			return _failure("invalid_place_job_command_actor")
		if not float_is_valid(job.get("elapsed")) or float(job.get("elapsed")) < 0.0:
			return _failure("invalid_place_job_clock")
		if not float_is_valid(job.get("no_progress_seconds")) or float(job.get("no_progress_seconds")) < 0.0:
			return _failure("invalid_place_job_clock")
		if not float_is_valid(job.get("best_remaining")) or float(job.get("best_remaining")) < 0.0:
			return _failure("invalid_place_job_progress")
		if not float_is_valid(job.get("progress_credit")) or float(job.get("progress_credit")) < 0.0 or float(job.get("progress_credit")) >= TRAVEL_PROGRESS_STEP:
			return _failure("invalid_place_job_progress")
		if not _valid_position(job.get("last_position")):
			return _failure("invalid_place_job_progress")
		# One public point per resident and never an occupied one.
		for other in places.jobs:
			if other == id:
				continue
			var other_job: Variant = places.jobs[other]
			if other_job is Dictionary and str(other_job.get("place_id", "")) == place_id and _valid_position(other_job.get("target_position")) and _vector(other_job.target_position).distance_to(_vector(target)) <= 0.05:
				return _failure("duplicate_place_target")
		for other in active:
			var pending_value: Variant = g.pending.get(other, {})
			if not pending_value is Dictionary or other == id:
				continue
			var pending_other: Dictionary = pending_value
			if str(pending_other.get("place_id", "")) == place_id and _valid_position(pending_other.get("target_position")) and _vector(pending_other.target_position).distance_to(_vector(target)) <= 0.05:
				return _failure("duplicate_place_target")
		# A place trip owns the resident: no other journey queue may be active at the same time.
		var trade_record: Variant = g.get("trade", {})
		var material_record: Variant = g.get("materials", {})
		if g.pending.has(id) \
				or (trade_record is Dictionary and trade_record.get("jobs", {}) is Dictionary and trade_record.get("jobs", {}).has(id)) \
				or (material_record is Dictionary and material_record.get("jobs", {}) is Dictionary and material_record.get("jobs", {}).has(id)):
			return _failure("conflicting_resident_journey")
	for event in value.life.events:
		if not event is Dictionary or str(event.get("type", "")) != "place_learned":
			continue
		var actor := str(event.get("actor_id", ""))
		var place_id := str(event.get("place_id", ""))
		var source_kind := str(event.get("source_kind", ""))
		if not Catalog.is_place_id(place_id) or not LEARN_SOURCES.has(source_kind):
			return _failure("invalid_place_learned_event")
		if actor not in active or str(event.get("subject_id", "")) != actor or event.get("recipient_ids", []) != [actor]:
			return _failure("invalid_place_learned_event")
		if str(event.get("operation_id", "")) != _learn_operation_id(source_kind, actor, place_id):
			return _failure("invalid_place_learned_event")
		if source_kind == LEARN_NOTICE:
			if str(event.get("source_id", "")) != str(Catalog.NOTICE["id"]):
				return _failure("invalid_place_learned_event")
		elif str(event.get("source_id", "")) != place_id:
			return _failure("invalid_place_learned_event")
		if not _valid_position(event.get("source_position")):
			return _failure("invalid_place_learned_event")
		if typeof(event.get("text", null)) != TYPE_STRING or str(event.text).length() > 200:
			return _failure("invalid_place_learned_event")
	for event in value.life.events:
		if not event is Dictionary or not PLACE_EVENT_TYPES.has(str(event.get("type", ""))):
			continue
		if str(event.get("type", "")) in ["place_visited", "travel_blocked"]:
			if not Catalog.is_place_id(str(event.get("place_id", ""))) or event.get("recipient_ids", []) != [str(event.get("actor_id", ""))]:
				return _failure("invalid_place_travel_event")
	# A pending rest at a place must still point at that place's own catalog point.
	for id in g.pending:
		var pending: Dictionary = g.pending[id]
		if not pending.has("place_id"):
			continue
		var place_id := str(pending.place_id)
		if pending.get("action") != "rest" or not Catalog.is_place_id(place_id) or not _is_catalog_point(place_id, _vector(pending.get("target_position", []))):
			return _failure("invalid_place_rest")
		if not g.commands.has(pending.get("command_id")) or str(g.commands[pending.command_id].payload.get("place_id", "")) != place_id:
			return _failure("invalid_place_rest")
		if str(g.commands[pending.command_id].payload.get("actor_id", "")) != id:
			return _failure("invalid_place_rest_actor")
		# The option journal mirror and the authoritative life command settle together.
		var mirror: Variant = places.commands.get(pending.command_id, {})
		if mirror is Dictionary and not (mirror as Dictionary).is_empty():
			var mirror_status := str((mirror as Dictionary).get("status", ""))
			var base_status := str(g.commands[pending.command_id].get("status", ""))
			if mirror_status == "pending" and base_status != "pending":
				return _failure("unsettled_place_rest_mirror")
			if mirror_status != "pending" and mirror_status != base_status:
				return _failure("inconsistent_place_rest_mirror")
	var stall_valid := _validate_journey_stalls(value)
	if not stall_valid.ok:
		return stall_valid
	return {"ok": true, "code": "places_valid"}

func _validate_journey_stalls(value: Dictionary) -> Dictionary:
	## Journey-stall evidence is world-scoped physical evidence only. Every record must stay tied to
	## a real resident and to that resident's own command, and an OPEN episode must still match a
	## journey that is genuinely pending, so a stale entry cannot be exported as current.
	var g: Dictionary = value.godot
	var raw: Variant = g.get("journey_stalls", {})
	if raw == {}:
		return {"ok": true, "code": "journey_stalls_absent"}
	if not raw is Dictionary or not _exact_keys(raw, ["schema_version", "next", "records"]):
		return _failure("invalid_journey_stalls")
	var store: Dictionary = raw
	if typeof(store.schema_version) != TYPE_INT or store.schema_version != 1:
		return _failure("invalid_journey_stalls")
	if not _bounded(store.next, 1000000000) or not store.records is Dictionary:
		return _failure("invalid_journey_stalls")
	var active: Array = g.positions.keys()
	var closed := 0
	for key in store.records:
		var record_value: Variant = store.records[key]
		if not record_value is Dictionary:
			return _failure("invalid_journey_stall_record")
		var record: Dictionary = record_value
		if not _exact_keys(record, ["episode_id", "resident_id", "command_id", "kind", "place_id",
				"target_position", "observed_position", "best_progress", "no_progress_seconds",
				"opened_elapsed", "status", "reported", "close_reason"]):
			return _failure("invalid_journey_stall_record")
		if str(record.episode_id) != str(key) or not str(key).begins_with(JOURNEY_STALL_KEY_PREFIX):
			return _failure("invalid_journey_stall_identity")
		if record.resident_id not in active or not JOURNEY_STALL_KINDS.has(str(record.kind)):
			return _failure("invalid_journey_stall_identity")
		if not record.command_id is String or record.command_id.is_empty() or not _validate_decision_command_id(record.command_id).ok:
			return _failure("invalid_journey_stall_identity")
		if not typeof(record.reported) == TYPE_BOOL or str(record.status) not in ["watching", "open", "closed"]:
			return _failure("invalid_journey_stall_status")
		if not record.close_reason is String or record.close_reason.length() > 64:
			return _failure("invalid_journey_stall_status")
		if not _valid_position(record.target_position) or not _valid_position(record.observed_position):
			return _failure("invalid_journey_stall_position")
		if not float_is_valid(record.best_progress) or float(record.best_progress) < 0.0:
			return _failure("invalid_journey_stall_progress")
		if not float_is_valid(record.no_progress_seconds) or float(record.no_progress_seconds) < 0.0:
			return _failure("invalid_journey_stall_progress")
		if not float_is_valid(record.opened_elapsed) or float(record.opened_elapsed) < 0.0:
			return _failure("invalid_journey_stall_progress")
		if str(record.kind) == "place_travel" and not Catalog.is_place_id(str(record.place_id)):
			return _failure("invalid_journey_stall_identity")
		if str(record.status) == "closed":
			closed += 1
			if str(record.close_reason).is_empty():
				return _failure("invalid_journey_stall_status")
			continue
		if str(record.close_reason) != "":
			return _failure("invalid_journey_stall_status")
		## Crosslink: a live episode must still match that resident's own pending journey, whichever
		## store owns it (life pending, places travel, or trade approach).
		var job: Dictionary = {}
		var life_job: Variant = g.pending.get(record.resident_id, {})
		if life_job is Dictionary and not (life_job as Dictionary).is_empty():
			job = life_job
		else:
			var place_record: Variant = g.get("places", {})
			var place_jobs: Variant = place_record.get("jobs", {}) if place_record is Dictionary else {}
			var trade_record: Variant = g.get("trade", {})
			var trade_jobs: Variant = trade_record.get("jobs", {}) if trade_record is Dictionary else {}
			var place_job: Variant = place_jobs.get(record.resident_id, {}) if place_jobs is Dictionary else {}
			var trade_job: Variant = trade_jobs.get(record.resident_id, {}) if trade_jobs is Dictionary else {}
			## An absent store entry is `{}`, which is still a Dictionary: require a real job.
			if place_job is Dictionary and not (place_job as Dictionary).is_empty():
				job = place_job
			elif trade_job is Dictionary and not (trade_job as Dictionary).is_empty():
				job = trade_job
		if str(job.get("command_id", "")) != str(record.command_id):
			return _failure("stale_journey_stall_episode")
	if closed > JOURNEY_STALL_CLOSED_LIMIT:
		return _failure("invalid_journey_stalls")
	return {"ok": true, "code": "journey_stalls_valid"}

func _is_catalog_point(place_id: String, point: Vector3) -> bool:
	if not point.is_finite():
		return false
	for slot in Catalog.offset_count(place_id):
		if Catalog.slot_point(place_id, slot).distance_to(point) <= 0.05:
			return true
	return Catalog.point_of(place_id).distance_to(point) <= 0.05

func float_is_valid(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok:
		return base
	return _validate_places(value)
