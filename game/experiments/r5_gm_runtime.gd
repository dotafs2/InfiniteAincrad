extends "res://core/town_places.gd"
## H86 capability runtime (resident request r5-resident-warm-food).
##
## ONE real preparation action that turns ONE held ration into ONE distinct HELD warm meal at
## the resident's own fixed work point, plus ONE separate action that eats that held item later.
##
## Boundaries held here:
##  - Only this file (plus its capability contract and its self-test) exists. No production
##    module is edited and no inherited rule is rewritten. Every new fact lives in its own
##    `godot.warm_food` namespace, so no base namespace that rejects unknown job types is asked
##    to hold one. `pending_job`, `destination`, `trade_options`, `submit_trade`, `available`,
##    `_busy` and `advance` are EXTENDED (super first), never replaced.
##  - Food accounting is preserved. Preparation CONSUMES one existing ration from the resident's
##    own survival account at completion and creates exactly one new held item; eating consumes
##    that item once. No food unit is created and no ingredient is invented.
##  - Real work and real movement. Both actions require the resident's collision-resolved body
##    inside WORK_POINT_RANGE of its own saved home/work point, and the work time only accrues
##    while the body is really there. This runtime never moves a body.
##  - Honest closure. A preparation whose body stops making progress toward its own work point
##    closes once as `warm_meal_blocked`, with no ration consumed, no item created and no
##    arrival receipt. A missing ration at completion is a rejection, never an invention.
##  - Durable identity. Meal ids come from a monotone serial in the save, every held item is
##    backed by exactly one attributed preparation event, and validation (run on load and on
##    every transaction) refuses a save where a prepared meal is neither held nor eaten exactly
##    once, where a pending command has no job, or where the freshness deadline was rewritten.
##
## Disclosed simplification: in this world a resident's fixed work point IS its saved home point
## (`home_point()`), the same point the world's own workstation rule uses. The requested "carry
## it home and eat it there" is therefore that one point: the item is HELD in the resident's own
## record (it is not eaten by preparing it), and the second action eats it there. The work
## duration, the satiety effect and the freshness window are this capability's own stated rule.

const WarmFoodKey := "warm_food"
const WARM_FOOD_SCHEMA_VERSION := 1
const WARM_COMMAND_ACTION := "warm_food_option"
const WARM_OPTION_PREFIX := "warm:"
const WARM_PREPARE_OPTION := "warm:prepare"
const WARM_EAT_OPTION_PREFIX := "warm:eat:"
const WARM_PREPARE_ACTION := "prepare_warm_meal"
const WARM_EAT_ACTION := "eat_warm_meal"
const WARM_ACTIONS := [WARM_PREPARE_ACTION, WARM_EAT_ACTION]
const MEAL_ID_PREFIX := "warm_meal_"
## Declared costs/durations of this capability (disclosed in the resident view).
const WARM_PREPARE_SECONDS := 60.0
const WARM_EAT_SECONDS := 20.0
const WARM_FRESH_SECONDS := 3600.0
const WARM_SATIETY_FRESH := 50.0
const WARM_SATIETY_COOLED := 25.0
## Same unit as the world's own eat_ration gate: eating near full would waste the item.
const WARM_EAT_MAX_HUNGER := 80.0
const WARM_HELD_LIMIT := 2
## The inherited workstation range (town_life.WORK_STATION_RANGE): the resident counts as being
## at its own work point within this distance, exactly like the world's own repair work rule.
const WARM_WORK_POINT_RANGE := 2.5
const WARM_PROGRESS_EPSILON := 0.05
const WARM_BLOCKED_SECONDS := 45.0
const WARM_BLOCKED_REASONS := ["work_point_unreachable", "ration_unavailable", "held_limit_reached", "meal_unavailable"]
const WARM_EVENT_PREPARED := "warm_meal_prepared"
const WARM_EVENT_EATEN := "warm_meal_eaten"
const WARM_EVENT_BLOCKED := "warm_meal_blocked"
const WARM_EVENT_TYPES := [WARM_EVENT_PREPARED, WARM_EVENT_EATEN, WARM_EVENT_BLOCKED]
const WARM_COMMAND_KEYS := ["payload", "status", "result"]
const WARM_PAYLOAD_KEYS := ["actor_id", "action", "option_id", "provenance"]
const WARM_JOB_KEYS := ["action", "command_id", "provenance", "elapsed", "duration_seconds",
	"target_position", "last_position", "no_progress_seconds", "best_remaining"]

func _warm_food() -> Dictionary:
	var value: Variant = _state.godot.get(WarmFoodKey, {})
	return value if value is Dictionary else {}

func _ensure_warm_food() -> Dictionary:
	if not _state.godot.get(WarmFoodKey, null) is Dictionary:
		_state.godot[WarmFoodKey] = {"schema_version": WARM_FOOD_SCHEMA_VERSION, "seq": 0,
			"commands": {}, "jobs": {}, "held": {}}
	var store: Dictionary = _state.godot[WarmFoodKey]
	if typeof(store.get("schema_version", null)) != TYPE_INT:
		store.schema_version = WARM_FOOD_SCHEMA_VERSION
	if typeof(store.get("seq", null)) != TYPE_INT:
		store.seq = 0
	for key in ["commands", "jobs", "held"]:
		if not store.get(key) is Dictionary:
			store[key] = {}
	return store

func _warm_commands() -> Dictionary:
	var value: Variant = _warm_food().get("commands", {})
	return value if value is Dictionary else {}

func _warm_jobs() -> Dictionary:
	var value: Variant = _warm_food().get("jobs", {})
	return value if value is Dictionary else {}

func _warm_held() -> Dictionary:
	var value: Variant = _warm_food().get("held", {})
	return value if value is Dictionary else {}

func _warm_job(id: String) -> Dictionary:
	var value: Variant = _warm_jobs().get(id, {})
	return value if value is Dictionary else {}

func _meal_serial(meal_id: String) -> int:
	if not meal_id.begins_with(MEAL_ID_PREFIX):
		return 0
	var tail := meal_id.trim_prefix(MEAL_ID_PREFIX)
	if not tail.is_valid_int():
		return 0
	return int(tail)

func _valid_meal_id(meal_id: String) -> bool:
	return _meal_serial(meal_id) > 0

func held_meals(id: String) -> Array:
	## The resident's own held warm meals, oldest first. Pure read; never creates the namespace.
	var result: Array = []
	for meal_id_value in _warm_held():
		var meal: Variant = _warm_held()[meal_id_value]
		if meal is Dictionary and str(meal.get("owner_id", "")) == id:
			result.append(meal.duplicate(true))
	result.sort_custom(func(first, second): return _meal_serial(str(first.meal_id)) < _meal_serial(str(second.meal_id)))
	return result

func _meal_report(meal: Dictionary, now: float) -> Dictionary:
	var prepared := float(meal.get("prepared_elapsed", 0.0))
	var fresh_until := float(meal.get("fresh_until_elapsed", 0.0))
	var fresh_left := maxf(0.0, fresh_until - now)
	return {"meal_id": str(meal.get("meal_id", "")), "prepared_elapsed": prepared,
		"prepare_command_id": str(meal.get("prepare_command_id", "")),
		"age_seconds": maxf(0.0, now - prepared), "fresh_until_elapsed": fresh_until,
		"fresh_remaining_seconds": fresh_left, "cooled": now > fresh_until,
		"satiety_if_eaten_now": WARM_SATIETY_COOLED if now > fresh_until else WARM_SATIETY_FRESH}

func _warm_option_label(meal: Dictionary, now: float) -> String:
	var report := _meal_report(meal, now)
	if bool(report.cooled):
		return "At your own workstation, spend %.0f seconds eating this prepared meal (now cold; restores about %.0f satiety and consumes the meal once)." % [WARM_EAT_SECONDS, WARM_SATIETY_COOLED]
	return "At your own workstation, spend %.0f seconds eating this warm meal (warm for about %.0f more minutes; restores about %.0f satiety and consumes the meal once)." % [WARM_EAT_SECONDS, float(report.fresh_remaining_seconds) / 60.0, WARM_SATIETY_FRESH]

## ---------------------------------------------------------------------------
## Option surface (model-facing choices, re-derived on submit)
## ---------------------------------------------------------------------------

func trade_options(id: String) -> Array:
	var result := super.trade_options(id)
	if id not in active_ids() or _busy(id):
		return result
	var foods: Dictionary = account(id)
	var held := held_meals(id)
	var now := float(_state.godot.elapsed_seconds)
	if int(foods.get("food", 0)) >= 1 and held.size() < WARM_HELD_LIMIT:
		_option(result, {"id": WARM_PREPARE_OPTION, "action": WARM_PREPARE_ACTION, "speech_allowed": false,
			"label": "Work at your own workstation for %.0f seconds to turn 1 ration into 1 warm meal (consumes 1 ration; carry the meal without eating it immediately; cools in about %.0f minutes)." % [WARM_PREPARE_SECONDS, WARM_FRESH_SECONDS / 60.0]})
	if float(resident(id).needs.get("hunger", 0.0)) <= WARM_EAT_MAX_HUNGER:
		for meal in held:
			_option(result, {"id": WARM_EAT_OPTION_PREFIX + str(meal.meal_id), "action": WARM_EAT_ACTION,
				"speech_allowed": false, "_meal_id": str(meal.meal_id),
				"label": _warm_option_label(meal, now)})
	return result

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if not option_id.begins_with(WARM_OPTION_PREFIX):
		# The inherited option surface is untouched; only a real cross-namespace command-id
		# collision is refused here, so one command can never name two different things.
		if _warm_commands().has(command_id):
			return _failure("command_conflict")
		return super.submit_trade(id, option_id, command_id, provenance, speech)
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if not speech.is_empty():
		return _failure("speech_not_supported_for_action")
	var payload := {"actor_id": id, "action": WARM_COMMAND_ACTION, "option_id": option_id, "provenance": provenance}
	var commands := _warm_commands()
	if commands.has(command_id):
		var prior: Dictionary = commands[command_id]
		var same: bool = prior.get("payload") == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if _state.godot.commands.has(command_id) \
			or _trade().get("commands", {}).has(command_id) \
			or _state.godot.get("places", {}).get("commands", {}).has(command_id) \
			or _state.godot.get("materials", {}).get("commands", {}).has(command_id):
		return _failure("command_conflict")
	# Read-only re-derivation: the option list is only a listing, this is the authoritative check.
	var option := {}
	for candidate in trade_options(id):
		if candidate.get("id") == option_id:
			option = candidate
			break
	if option.is_empty():
		return _failure("option_unavailable")
	if _busy(id):
		return _failure("option_unavailable")
	var action: String = str(option.get("action", ""))
	var target := home_point(id)
	if not WARM_ACTIONS.has(action) or not target.is_finite():
		return _failure("option_unavailable")
	var position_value := position_of(id)
	var store := _ensure_warm_food()
	var job := {"action": action, "command_id": command_id, "provenance": provenance, "elapsed": 0.0,
		"duration_seconds": WARM_PREPARE_SECONDS if action == WARM_PREPARE_ACTION else WARM_EAT_SECONDS,
		"target_position": [target.x, target.y, target.z],
		"last_position": [position_value.x, position_value.y, position_value.z],
		"no_progress_seconds": 0.0, "best_remaining": position_value.distance_to(target)}
	if action == WARM_EAT_ACTION:
		job["meal_id"] = str(option.get("_meal_id", ""))
	store.commands[command_id] = {"payload": payload, "status": "pending"}
	store.jobs[id] = job
	return {"ok": true, "code": "warm_food_preparing" if action == WARM_PREPARE_ACTION else "warm_food_eating",
		"pending": true, "command_id": command_id, "work_point": [target.x, target.y, target.z],
		"duration_seconds": float(job.duration_seconds),
		"at_work_point": position_value.distance_to(target) <= WARM_WORK_POINT_RANGE}

## ---------------------------------------------------------------------------
## Inherited integration points (super first, own fact appended)
## ---------------------------------------------------------------------------

func _busy(id: String) -> bool:
	return super._busy(id) or not _warm_job(id).is_empty()

func pending_job(id: String) -> Dictionary:
	var job := _warm_job(id)
	if not job.is_empty():
		return job.duplicate(true)
	return super.pending_job(id)

func destination(id: String, action: String) -> Vector3:
	var job := _warm_job(id)
	if not job.is_empty() and str(job.get("action", "")) == action and _valid_position(job.get("target_position", [])):
		return _vector(job.target_position)
	return super.destination(id, action)

func available(id: String) -> Array:
	## While the resident's own preparation/eating is running, the world's own basic actions are
	## not offered, exactly like the inherited rule for a pending basic action.
	if not _warm_job(id).is_empty():
		return ["wait"]
	return super.available(id)

func advance(delta: float) -> Dictionary:
	var result := super.advance(delta)
	if not result.ok:
		return result
	if _warm_jobs().is_empty():
		return result
	var store := _ensure_warm_food()
	var completed: Array = result.completed
	for id_value in store.jobs.keys().duplicate():
		var id := str(id_value)
		var job_value: Variant = store.jobs.get(id_value, {})
		if not job_value is Dictionary:
			continue
		var job: Dictionary = job_value
		if not WARM_ACTIONS.has(str(job.get("action", ""))):
			continue
		if not active_ids().has(id):
			# An identity that left the active set cannot keep a body-bound job alive. There is
			# no active recipient left for a personal event, so only the command is settled.
			completed.append(_abandon_warm_job(id, job))
			continue
		var target := _vector(job.get("target_position", [0, 0, 0]))
		var position_value := position_of(id)
		job.last_position = [position_value.x, position_value.y, position_value.z]
		var remaining := position_value.distance_to(target) if target.is_finite() else -1.0
		if remaining >= 0.0 and remaining <= WARM_WORK_POINT_RANGE:
			job.no_progress_seconds = 0.0
			job.best_remaining = remaining
			job.elapsed = float(job.get("elapsed", 0.0)) + delta
			if float(job.elapsed) >= float(job.get("duration_seconds", 0.0)):
				completed.append(_finish_warm_job(id, job))
			continue
		# Outside its own work point the resident has to really walk there: only measured
		# progress resets the stall clock, so a body against a wall closes honestly.
		if remaining >= 0.0 and remaining <= float(job.get("best_remaining", remaining)) - WARM_PROGRESS_EPSILON:
			job.best_remaining = remaining
			job.no_progress_seconds = 0.0
		else:
			job.no_progress_seconds = float(job.get("no_progress_seconds", 0.0)) + delta
		if float(job.no_progress_seconds) >= WARM_BLOCKED_SECONDS:
			completed.append(_close_warm_job(id, job, "warm_food_work_point_blocked", "work_point_unreachable",
				{"remaining_distance": remaining}))
	return result

## ---------------------------------------------------------------------------
## Completion and closure
## ---------------------------------------------------------------------------

func _finish_warm_job(id: String, job: Dictionary) -> Dictionary:
	var receipt := _complete_prepare(id, job) if str(job.get("action", "")) == WARM_PREPARE_ACTION else _complete_eat(id, job)
	var store := _ensure_warm_food()
	store.jobs.erase(id)
	var command_id := str(job.get("command_id", ""))
	var record: Variant = store.commands.get(command_id, {})
	if record is Dictionary and not (record as Dictionary).is_empty():
		(record as Dictionary).status = "completed" if bool(receipt.get("ok", false)) else "rejected"
		(record as Dictionary).result = receipt.duplicate(true)
	return receipt

func _close_warm_job(id: String, job: Dictionary, code: String, reason: String, fields: Dictionary) -> Dictionary:
	var receipt := {"ok": false, "code": code, "reason": reason, "actor_id": id,
		"command_id": str(job.get("command_id", ""))}
	for key in fields:
		receipt[key] = fields[key]
	var store := _ensure_warm_food()
	store.jobs.erase(id)
	var command_id := str(job.get("command_id", ""))
	var record: Variant = store.commands.get(command_id, {})
	if record is Dictionary and not (record as Dictionary).is_empty():
		(record as Dictionary).status = "rejected"
		(record as Dictionary).result = receipt.duplicate(true)
	_append_life_event({"type": WARM_EVENT_BLOCKED, "actor_id": id, "subject_id": id, "recipient_ids": [id],
		"operation_id": command_id, "source": str(job.get("provenance", "local_rule_policy")),
		"action": str(job.get("action", "")), "reason": reason,
		"remaining_distance": float(fields.get("remaining_distance", -1.0)),
		"no_progress_seconds": float(job.get("no_progress_seconds", 0.0)),
		"text": _warm_blocked_text(id, str(job.get("action", "")), reason)})
	return receipt

func _abandon_warm_job(id: String, job: Dictionary) -> Dictionary:
	var receipt := {"ok": false, "code": "warm_food_actor_inactive", "reason": "actor_inactive",
		"actor_id": id, "command_id": str(job.get("command_id", ""))}
	var store := _ensure_warm_food()
	store.jobs.erase(id)
	var command_id := str(job.get("command_id", ""))
	var record: Variant = store.commands.get(command_id, {})
	if record is Dictionary and not (record as Dictionary).is_empty():
		(record as Dictionary).status = "rejected"
		(record as Dictionary).result = receipt.duplicate(true)
	return receipt

func _warm_blocked_text(id: String, action: String, reason: String) -> String:
	if reason == "work_point_unreachable":
		return "I kept walking toward my workstation but made no progress, so this attempt at %s did not finish. I consumed no ration and received no warm meal." % ("preparing food" if action == WARM_PREPARE_ACTION else "Eating")
	if reason == "ration_unavailable":
		return "I reached my workstation, but I no longer had a ration. Preparation did not finish and produced no warm meal."
	if reason == "held_limit_reached":
		return "I am carrying the maximum number of warm meals. Preparation did not start and consumed no ration."
	if reason == "meal_unavailable":
		return "I no longer have the warm meal I meant to eat. Eating did not finish and restored no satiety."
	return "This warm-meal action did not finish."

func _complete_prepare(id: String, job: Dictionary) -> Dictionary:
	var foods: Dictionary = account(id)
	var held: Dictionary = _warm_held()
	var owned := held_meals(id)
	if int(foods.get("food", 0)) < 1:
		return _reject_warm_job(id, job, "warm_food_prepare_rejected", "ration_unavailable")
	if owned.size() >= WARM_HELD_LIMIT:
		return _reject_warm_job(id, job, "warm_food_prepare_rejected", "held_limit_reached")
	var now := float(_state.godot.elapsed_seconds)
	var store := _ensure_warm_food()
	store.seq = int(store.seq) + 1
	var meal_id := "%s%d" % [MEAL_ID_PREFIX, int(store.seq)]
	var fresh_until := now + WARM_FRESH_SECONDS
	foods.food = int(foods.get("food", 0)) - 1
	store.held[meal_id] = {"meal_id": meal_id, "owner_id": id, "prepared_elapsed": now,
		"fresh_until_elapsed": fresh_until, "prepare_command_id": str(job.get("command_id", ""))}
	var receipt := {"ok": true, "code": "warm_food_prepared", "actor_id": id, "command_id": str(job.get("command_id", "")),
		"meal_id": meal_id, "ration_consumed": 1, "rations_remaining": int(foods.food),
		"held_meals": owned.size() + 1, "prepared_elapsed": now, "fresh_until_elapsed": fresh_until,
		"work_seconds": WARM_PREPARE_SECONDS, "work_point": job.get("target_position", []).duplicate()}
	_append_life_event({"type": WARM_EVENT_PREPARED, "actor_id": id, "subject_id": id, "recipient_ids": [id],
		"operation_id": str(job.get("command_id", "")), "source": str(job.get("provenance", "local_rule_policy")),
		"meal_id": meal_id, "prepared_elapsed": now, "fresh_until_elapsed": fresh_until,
		"work_seconds": WARM_PREPARE_SECONDS, "work_point": job.get("target_position", []).duplicate(),
		"text": "I worked at my workstation for %.0f seconds to turn 1 ration into 1 warm meal. I carry it myself and have not eaten it; it should stay warm for about %.0f minutes." % [WARM_PREPARE_SECONDS, WARM_FRESH_SECONDS / 60.0]})
	return receipt

func _complete_eat(id: String, job: Dictionary) -> Dictionary:
	var meal_id := str(job.get("meal_id", ""))
	var held: Dictionary = _warm_held()
	var meal: Variant = held.get(meal_id, {})
	if not meal is Dictionary or str((meal as Dictionary).get("owner_id", "")) != id:
		return _reject_warm_job(id, job, "warm_food_eat_rejected", "meal_unavailable")
	var item: Dictionary = meal
	var now := float(_state.godot.elapsed_seconds)
	var cooled := now > float(item.get("fresh_until_elapsed", 0.0))
	var needs: Dictionary = resident(id).needs
	var before := float(needs.get("hunger", 0.0))
	var gain: float = WARM_SATIETY_COOLED if cooled else WARM_SATIETY_FRESH
	needs.hunger = minf(100.0, before + gain)
	var store := _ensure_warm_food()
	store.held.erase(meal_id)
	var receipt := {"ok": true, "code": "warm_food_eaten", "actor_id": id, "command_id": str(job.get("command_id", "")),
		"meal_id": meal_id, "prepare_command_id": str(item.get("prepare_command_id", "")), "cooled": cooled,
		"satiety_before": before, "satiety_after": float(needs.hunger),
		"satiety_gained": float(needs.hunger) - before, "held_meals": held_meals(id).size(),
		"prepared_elapsed": float(item.get("prepared_elapsed", 0.0)), "eaten_elapsed": now}
	_append_life_event({"type": WARM_EVENT_EATEN, "actor_id": id, "subject_id": id, "recipient_ids": [id],
		"operation_id": str(job.get("command_id", "")), "source": str(job.get("provenance", "local_rule_policy")),
		"meal_id": meal_id, "prepare_command_id": str(item.get("prepare_command_id", "")),
		"prepared_elapsed": float(item.get("prepared_elapsed", 0.0)), "eaten_elapsed": now, "cooled": cooled,
		"satiety_gained": float(needs.hunger) - before,
		"text": "I ate the prepared meal I was carrying%s. My satiety changed from %.0f to %.0f; I no longer carry that meal." % [" (now cold)" if cooled else "", before, float(needs.hunger)]})
	return receipt

func _reject_warm_job(id: String, job: Dictionary, code: String, reason: String) -> Dictionary:
	var store := _ensure_warm_food()
	store.jobs.erase(id)
	var receipt := {"ok": false, "code": code, "reason": reason, "actor_id": id, "command_id": str(job.get("command_id", ""))}
	var command_id := str(job.get("command_id", ""))
	var record: Variant = store.commands.get(command_id, {})
	if record is Dictionary and not (record as Dictionary).is_empty():
		(record as Dictionary).status = "rejected"
		(record as Dictionary).result = receipt.duplicate(true)
	_append_life_event({"type": WARM_EVENT_BLOCKED, "actor_id": id, "subject_id": id, "recipient_ids": [id],
		"operation_id": command_id, "source": str(job.get("provenance", "local_rule_policy")),
		"action": str(job.get("action", "")), "reason": reason, "remaining_distance": -1.0,
		"no_progress_seconds": float(job.get("no_progress_seconds", 0.0)),
		"text": _warm_blocked_text(id, str(job.get("action", "")), reason)})
	return receipt

## ---------------------------------------------------------------------------
## Personal view: actual held state, deadlines and stated rules only
## ---------------------------------------------------------------------------

func resident_view(id: String = "") -> Dictionary:
	var view := super.resident_view(id)
	if view.is_empty():
		return view
	var now := float(_state.godot.elapsed_seconds)
	var foods: Dictionary = account(id)
	var held := held_meals(id)
	var report: Array = []
	for meal in held:
		report.append(_meal_report(meal, now))
	var job := _warm_job(id)
	var work_point := home_point(id)
	view["warm_food"] = {"work_point": [work_point.x, work_point.y, work_point.z] if work_point.is_finite() else [],
		"work_point_range_m": WARM_WORK_POINT_RANGE, "rations_held": int(foods.get("food", 0)),
		"prepare_seconds": WARM_PREPARE_SECONDS, "eat_seconds": WARM_EAT_SECONDS,
		"fresh_seconds": WARM_FRESH_SECONDS, "satiety_fresh": WARM_SATIETY_FRESH,
		"satiety_cooled": WARM_SATIETY_COOLED, "held_limit": WARM_HELD_LIMIT,
		"held_meals": report,
		"abstraction": "Preparing and eating require you to be within %.1f meters of your own fixed home/workstation in the save. Preparation consumes 1 ration and creates 1 portable meal; only eating consumes that meal. Meals cool according to world time while the world runs." % WARM_WORK_POINT_RANGE}
	if not job.is_empty():
		var job_target := _vector(job.get("target_position", [0, 0, 0]))
		view["pending"] = {"action": str(job.get("action", "")), "command_id": str(job.get("command_id", "")),
			"provenance": str(job.get("provenance", "")), "elapsed": float(job.get("elapsed", 0.0)),
			"duration_seconds": float(job.get("duration_seconds", 0.0)),
			"remaining_seconds": maxf(0.0, float(job.get("duration_seconds", 0.0)) - float(job.get("elapsed", 0.0))),
			"target_position": job.get("target_position", []).duplicate(),
			"at_work_point": position_of(id).distance_to(job_target) <= WARM_WORK_POINT_RANGE,
			"meal_id": str(job.get("meal_id", "")),
			"note": "In progress: time counts only while you stand at your own workstation."}
	view["known_rules"]["warm_food"] = "Warm meals: work at your workstation for %.0f seconds to turn 1 ration into 1 warm meal (a new product, not eaten automatically). Carry at most %d meals. Later, spend %.0f seconds at your workstation eating one meal to restore about %.0f satiety (about %.0f if cold). Meals cool after %.0f minutes of world time." % [WARM_PREPARE_SECONDS, WARM_HELD_LIMIT, WARM_EAT_SECONDS, WARM_SATIETY_FRESH, WARM_SATIETY_COOLED, WARM_FRESH_SECONDS / 60.0]
	var unavailable: Array = view.get("unavailable_actions", [])
	if job.is_empty() and not _busy(id):
		if int(foods.get("food", 0)) < 1:
			unavailable.append({"action": WARM_PREPARE_ACTION, "rations_held": 0,
				"reason": "You have no ration. Preparation requires 1 ration first; forage or keep a ration."})
		if held.size() >= WARM_HELD_LIMIT:
			unavailable.append({"action": WARM_PREPARE_ACTION, "held_meals": held.size(),
				"reason": "You already carry %d warm meals. Eat one before preparing another." % held.size()})
		if held.size() > 0 and float(resident(id).needs.get("hunger", 0.0)) > WARM_EAT_MAX_HUNGER:
			unavailable.append({"action": WARM_EAT_ACTION, "held_meals": held.size(),
				"reason": "Your satiety is %.0f, nearly full. Eating now would waste food; keep the meal until you are hungrier." % float(resident(id).needs.get("hunger", 0.0))})
	view["unavailable_actions"] = unavailable
	return view

## ---------------------------------------------------------------------------
## Durable validation: load and every transaction must accept this state or fail closed
## ---------------------------------------------------------------------------

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok:
		return base
	if not value is Dictionary or not value.get("godot", null) is Dictionary:
		return _failure("invalid_warm_food_state")
	return _validate_warm_food(value)

func _validate_warm_food(value: Dictionary) -> Dictionary:
	var g: Dictionary = value.godot
	var raw: Variant = g.get(WarmFoodKey, {})
	var active: Array = g.positions.keys()
	if not raw is Dictionary:
		return _failure("invalid_warm_food_state")
	if raw.is_empty():
		for event_value in value.life.events:
			if event_value is Dictionary and WARM_EVENT_TYPES.has(str(event_value.get("type", ""))):
				return _failure("warm_food_state_missing")
		return {"ok": true, "code": "warm_food_absent"}
	var store: Dictionary = raw
	if not _exact_keys(store, ["schema_version", "seq", "commands", "jobs", "held"]) \
			or typeof(store.schema_version) != TYPE_INT or int(store.schema_version) != WARM_FOOD_SCHEMA_VERSION:
		return _failure("invalid_warm_food_state")
	if typeof(store.seq) != TYPE_INT or not _bounded(store.seq, 1000000000):
		return _failure("invalid_warm_food_sequence")
	for key in ["commands", "jobs", "held"]:
		if not store[key] is Dictionary:
			return _failure("invalid_warm_food_state")
	var commands: Dictionary = store.commands
	var jobs: Dictionary = store.jobs
	var held: Dictionary = store.held
	for command_key in commands:
		var command_id := str(command_key)
		var command_value: Variant = commands[command_key]
		if not _validate_decision_command_id(command_id).ok or not command_value is Dictionary:
			return _failure("invalid_warm_food_command")
		var record: Dictionary = command_value
		var status := str(record.get("status", ""))
		if not record.get("payload", null) is Dictionary:
			return _failure("invalid_warm_food_command")
		var payload: Dictionary = record.payload
		if not _exact_keys(payload, WARM_PAYLOAD_KEYS) or str(payload.action) != WARM_COMMAND_ACTION:
			return _failure("invalid_warm_food_command")
		var actor := str(payload.actor_id)
		if actor not in active or str(payload.provenance) not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_warm_food_command")
		var option_id := str(payload.option_id)
		if not option_id.begins_with(WARM_OPTION_PREFIX) \
				or (option_id != WARM_PREPARE_OPTION and not option_id.begins_with(WARM_EAT_OPTION_PREFIX)):
			return _failure("invalid_warm_food_command")
		if status == "pending":
			var job_value: Variant = jobs.get(actor, {})
			if not job_value is Dictionary or str((job_value as Dictionary).get("command_id", "")) != command_id:
				return _failure("orphan_warm_food_command")
			continue
		if status not in ["completed", "rejected"] or not record.get("result", null) is Dictionary:
			return _failure("invalid_warm_food_command")
		if not _exact_keys(record, WARM_COMMAND_KEYS):
			return _failure("invalid_warm_food_command")
		var result: Dictionary = record.result
		if not result.get("ok", null) is bool or not result.get("code", null) is String \
				or str(result.get("actor_id", "")) != actor or str(result.get("command_id", "")) != command_id:
			return _failure("invalid_warm_food_receipt")
	var prepared_events: Dictionary = {}
	var eaten_events: Dictionary = {}
	var max_serial := 0
	for event_value in value.life.events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_type := str(event.get("type", ""))
		if not WARM_EVENT_TYPES.has(event_type):
			continue
		var actor := str(event.get("actor_id", ""))
		if actor not in active or str(event.get("subject_id", "")) != actor or event.get("recipient_ids", []) != [actor]:
			return _failure("invalid_warm_food_event")
		var command_id := str(event.get("operation_id", ""))
		var command_value: Variant = commands.get(command_id, {})
		if not command_value is Dictionary or (command_value as Dictionary).is_empty():
			return _failure("invalid_warm_food_event_source")
		var source_command: Dictionary = command_value
		if str(source_command.payload.actor_id) != actor \
				or str(source_command.payload.provenance) != str(event.get("source", "")) \
				or str(source_command.get("status", "")) != ("rejected" if event_type == WARM_EVENT_BLOCKED else "completed"):
			return _failure("invalid_warm_food_event_source")
		if event_type == WARM_EVENT_BLOCKED:
			## A blocked or rejected attempt produces NO item, so it carries no meal id: it is a
			## personal observation about work that did not happen. Requiring an item here would make
			## an honest failure impossible to save, which is exactly what this event guards against.
			if str(event.get("meal_id", "")) != "" \
					or str(event.get("action", "")) not in WARM_ACTIONS \
					or str(event.get("reason", "")) not in WARM_BLOCKED_REASONS \
					or str(source_command.get("result", {}).get("reason", "")) != str(event.get("reason", "")):
				return _failure("invalid_warm_food_event")
			if not float_is_valid(event.get("no_progress_seconds")) or float(event.no_progress_seconds) < 0.0 \
					or not float_is_valid(event.get("remaining_distance")) or float(event.remaining_distance) < -1.0:
				return _failure("invalid_warm_food_event_clock")
			continue
		var meal_id := str(event.get("meal_id", ""))
		if not _valid_meal_id(meal_id):
			return _failure("invalid_warm_food_event_identity")
		max_serial = maxi(max_serial, _meal_serial(meal_id))
		if event_type == WARM_EVENT_PREPARED:
			if str(source_command.payload.option_id) != WARM_PREPARE_OPTION or str(event.get("action", WARM_PREPARE_ACTION)) not in [WARM_PREPARE_ACTION] \
					or not float_is_valid(event.get("work_seconds")) or absf(float(event.work_seconds) - WARM_PREPARE_SECONDS) > 0.001:
				return _failure("invalid_warm_food_event")
			if not float_is_valid(event.get("prepared_elapsed")) or float(event.prepared_elapsed) < 0.0 or float(event.prepared_elapsed) > float(g.elapsed_seconds) \
					or not float_is_valid(event.get("fresh_until_elapsed")) or absf(float(event.fresh_until_elapsed) - (float(event.prepared_elapsed) + WARM_FRESH_SECONDS)) > 0.001:
				return _failure("invalid_warm_food_event_clock")
			if not _valid_position(event.get("work_point")):
				return _failure("invalid_warm_food_event")
			prepared_events[meal_id] = int(prepared_events.get(meal_id, 0)) + 1
			continue
		if event_type == WARM_EVENT_EATEN:
			if str(source_command.payload.option_id) != WARM_EAT_OPTION_PREFIX + meal_id:
				return _failure("invalid_warm_food_event_source")
			var prepare_id := str(event.get("prepare_command_id", ""))
			var prepare_value: Variant = commands.get(prepare_id, {})
			if not prepare_value is Dictionary or (prepare_value as Dictionary).is_empty():
				return _failure("invalid_warm_food_event_source")
			var prepare_command: Dictionary = prepare_value
			if str(prepare_command.get("status", "")) != "completed" or str(prepare_command.payload.option_id) != WARM_PREPARE_OPTION \
					or str(prepare_command.payload.actor_id) != actor or str(prepare_command.get("result", {}).get("meal_id", "")) != meal_id:
				return _failure("invalid_warm_food_event_source")
			if not float_is_valid(event.get("eaten_elapsed")) or float(event.eaten_elapsed) < 0.0 or float(event.eaten_elapsed) > float(g.elapsed_seconds) \
					or not float_is_valid(event.get("prepared_elapsed")) or float(event.prepared_elapsed) > float(event.eaten_elapsed) \
					or typeof(event.get("cooled")) != TYPE_BOOL or not float_is_valid(event.get("satiety_gained")) or float(event.satiety_gained) < 0.0:
				return _failure("invalid_warm_food_event_clock")
			eaten_events[meal_id] = int(eaten_events.get(meal_id, 0)) + 1
			continue
		return _failure("invalid_warm_food_event")
	for job_key in jobs:
		var id := str(job_key)
		var job_value: Variant = jobs[job_key]
		if id not in active or not job_value is Dictionary:
			return _failure("invalid_warm_food_job")
		var job: Dictionary = job_value
		var action := str(job.get("action", ""))
		var keys: Array = WARM_JOB_KEYS.duplicate()
		if action == WARM_EAT_ACTION:
			keys.append("meal_id")
		if not WARM_ACTIONS.has(action) or not _exact_keys(job, keys):
			return _failure("invalid_warm_food_job")
		var command_id := str(job.get("command_id", ""))
		var command_value: Variant = commands.get(command_id, {})
		if not command_value is Dictionary or (command_value as Dictionary).is_empty() or str((command_value as Dictionary).get("status", "")) != "pending":
			return _failure("invalid_warm_food_job_command")
		var command: Dictionary = command_value
		var expected_option := WARM_PREPARE_OPTION if action == WARM_PREPARE_ACTION else WARM_EAT_OPTION_PREFIX + str(job.get("meal_id", ""))
		if str(command.payload.actor_id) != id or str(command.payload.option_id) != expected_option \
				or str(command.payload.provenance) != str(job.get("provenance", "")):
			return _failure("invalid_warm_food_job_command")
		if action == WARM_EAT_ACTION and not held.has(str(job.get("meal_id", ""))):
			return _failure("invalid_warm_food_job_item")
		if not float_is_valid(job.get("elapsed")) or float(job.elapsed) < 0.0 \
				or not float_is_valid(job.get("duration_seconds")) or float(job.duration_seconds) <= 0.0 \
				or float(job.elapsed) >= float(job.duration_seconds):
			return _failure("invalid_warm_food_job_clock")
		if not float_is_valid(job.get("no_progress_seconds")) or float(job.no_progress_seconds) < 0.0 \
				or not float_is_valid(job.get("best_remaining")) or float(job.best_remaining) < 0.0:
			return _failure("invalid_warm_food_job_clock")
		if not _valid_position(job.get("target_position")) or not _valid_position(job.get("last_position")):
			return _failure("invalid_warm_food_job_placement")
		if _vector(job.target_position).distance_to(_vector(g.homes.get(id, []))) > 0.05:
			return _failure("invalid_warm_food_job_placement")
		# One journey owns the resident: a warm-food job never coexists with another queue.
		if g.pending.has(id):
			return _failure("conflicting_warm_food_journey")
		for queue_name in ["trade", "places", "materials"]:
			var record: Variant = g.get(queue_name, {})
			var queue_jobs: Variant = record.get("jobs", {}) if record is Dictionary else {}
			if queue_jobs is Dictionary and queue_jobs.has(id):
				return _failure("conflicting_warm_food_journey")
	var owned_counts: Dictionary = {}
	for meal_key in held:
		var meal_id := str(meal_key)
		var meal_value: Variant = held[meal_key]
		if not _valid_meal_id(meal_id) or not meal_value is Dictionary:
			return _failure("invalid_warm_food_held_item")
		var meal: Dictionary = meal_value
		if not _exact_keys(meal, ["meal_id", "owner_id", "prepared_elapsed", "fresh_until_elapsed", "prepare_command_id"]):
			return _failure("invalid_warm_food_held_item")
		var owner := str(meal.owner_id)
		if str(meal.meal_id) != meal_id or owner not in active:
			return _failure("invalid_warm_food_held_item")
		if not float_is_valid(meal.prepared_elapsed) or float(meal.prepared_elapsed) < 0.0 or float(meal.prepared_elapsed) > float(g.elapsed_seconds) \
				or not float_is_valid(meal.fresh_until_elapsed) or absf(float(meal.fresh_until_elapsed) - (float(meal.prepared_elapsed) + WARM_FRESH_SECONDS)) > 0.001:
			return _failure("invalid_warm_food_held_clock")
		var prepare_id := str(meal.prepare_command_id)
		var prepare_value: Variant = commands.get(prepare_id, {})
		if not prepare_value is Dictionary or (prepare_value as Dictionary).is_empty():
			return _failure("invalid_warm_food_held_source")
		var prepare_command: Dictionary = prepare_value
		if str(prepare_command.get("status", "")) != "completed" or str(prepare_command.payload.option_id) != WARM_PREPARE_OPTION \
				or str(prepare_command.payload.actor_id) != owner \
				or str(prepare_command.get("result", {}).get("meal_id", "")) != meal_id \
				or str(prepare_command.get("result", {}).get("code", "")) != "warm_food_prepared" \
				or float(prepare_command.get("result", {}).get("fresh_until_elapsed", -1.0)) != float(meal.fresh_until_elapsed):
			return _failure("invalid_warm_food_held_source")
		owned_counts[owner] = int(owned_counts.get(owner, 0)) + 1
		if int(owned_counts[owner]) > WARM_HELD_LIMIT:
			return _failure("warm_food_held_capacity")
		max_serial = maxi(max_serial, _meal_serial(meal_id))
	for meal_id in prepared_events:
		var held_count := 1 if held.has(meal_id) else 0
		if int(prepared_events[meal_id]) != 1 or held_count + int(eaten_events.get(meal_id, 0)) != 1:
			return _failure("unbalanced_warm_food_meal")
	for meal_id in eaten_events:
		if int(eaten_events[meal_id]) != 1 or not prepared_events.has(meal_id):
			return _failure("unbalanced_warm_food_meal")
	for meal_key in held:
		if not prepared_events.has(str(meal_key)):
			return _failure("warm_food_meal_without_source")
	if max_serial > int(store.seq):
		return _failure("invalid_warm_food_sequence")
	return {"ok": true, "code": "warm_food_valid"}
