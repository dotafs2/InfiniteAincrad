extends RefCounted
## Own-property repair uses the existing skills, material costs and physical work time.
const Registry = preload("res://core/actions/capability_registry.gd")
const ID := "production.self_repair"
const PREFIX := "ability:self_repair:"
const START := "self_repair_started"
const DONE := "self_repair_completed"
const BLOCKED := "self_repair_blocked"
const UNAVAILABLE := "self_repair_unavailable"
const EVENTS := [START, DONE, BLOCKED, UNAVAILABLE]
const SECONDS := 60.0
const ARRIVAL := 0.45
const STALL_SECONDS := 90.0

func definitions() -> Array:
	return [Registry.spec(ID, "self_repair", "durable_job",
		["actor_body", "own_item_in_own_custody", "own_repair_skill", "uncommitted_repair_material", "own_workstation"],
		"forbidden", ["damaged_axe_part", "no_active_item_contract", "resources_rechecked_at_completion"],
		["physical_travel_then_60_seconds_work", "consume_one_matching_material", "restore_only_selected_part", "durable_personal_receipt"],
		"blocked_travel_closes_after_90_seconds_without_progress")]

func _eligible(world, id: String, item: Dictionary, part: String) -> bool:
	if item.get("kind") != "axe" or item.get("owner_id") != id or item.get("custodian_id") != id:
		return false
	if part not in ["edge", "handle"] or not world._part_damaged(item, part) or world._active_item_contract(str(item.id)):
		return false
	var rule: Dictionary = world._repair_part(part)
	return world._has_skill(id, rule.skill) and world._available_repair_material(id, rule.material) >= 1

func options(world, id: String) -> Array:
	var result: Array = []
	if world._busy(id): return result
	for item in world._legacy_array("items"):
		for part in ["edge", "handle"]:
			if not _eligible(world, id, item, part): continue
			var material: String = world._repair_part(part).material
			result.append({"id": PREFIX + str(item.id) + ":" + part, "action": "self_repair", "capability_id": ID,
				"label": "Repair my own axe %s: walk to my work point, work for 60 seconds and use 1 %s; no payment." % [part, material],
				"speech_allowed": false, "_item_id": item.id, "_part": part,
				"target_position": world._state.godot.homes[id].duplicate(), "duration_seconds": SECONDS})
	return result

func execute(world, id: String, option: Dictionary, command: String, provenance: String, _speech: String) -> Dictionary:
	var item: Dictionary = world._item(option._item_id)
	if world._busy(id) or not _eligible(world, id, item, option._part): return world._failure("option_unavailable")
	var target: Array = world._state.godot.homes[id].duplicate()
	var job := {"action": "self_repair", "actor_id": id, "item_id": item.id, "part": option._part,
		"material": world._repair_part(option._part).material, "command_id": command, "provenance": provenance,
		"target_position": target, "duration_seconds": SECONDS, "elapsed": 0.0,
		"best_remaining": world.position_of(id).distance_to(world._vector(target)), "no_progress_seconds": 0.0}
	var event: Dictionary = world.capability_event(START, id, [id], command, provenance,
		"I started a trip to repair my own axe %s. No repair or material consumption has happened yet." % option._part)
	event.merge({"item_id": item.id, "part": option._part, "material": job.material, "target_position": target.duplicate(), "initial_condition": item[option._part]})
	world._append_life_event(event)
	return {"ok": true, "code": START, "pending": true, "event_id": event.event_id, "job": job,
		"speech_delivery": {"attempted": false, "delivered": false, "code": "physical_work_not_speech"}}

func pending_job(world, id: String) -> Dictionary:
	for row in world.capability_store().get("commands", {}).values():
		if row.capability_id == ID and row.status == "pending" and row.payload.actor_id == id:
			return row.result.job.duplicate(true)
	return {}

func advance(world, delta: float) -> Array:
	var completed: Array = []
	if delta <= 0.0: return completed
	for row in world.capability_store().get("commands", {}).values():
		if row.capability_id != ID or row.status != "pending": continue
		var job: Dictionary = row.result.job
		var id: String = row.payload.actor_id
		var remaining: float = world.position_of(id).distance_to(world._vector(job.target_position))
		if remaining > ARRIVAL:
			if remaining <= float(job.best_remaining) - 0.05:
				job.best_remaining = remaining
				job.no_progress_seconds = 0.0
			else:
				job.no_progress_seconds = minf(STALL_SECONDS, float(job.no_progress_seconds) + delta)
			if job.no_progress_seconds >= STALL_SECONDS:
				completed.append(_finish(world, row, BLOCKED))
			continue
		job.best_remaining = remaining
		job.no_progress_seconds = 0.0
		job.elapsed = minf(SECONDS, float(job.elapsed) + delta)
		if job.elapsed >= SECONDS:
			var item: Dictionary = world._item(job.item_id)
			completed.append(_finish(world, row, DONE if _eligible(world, id, item, job.part) else UNAVAILABLE))
	return completed

func _finish(world, row: Dictionary, code: String) -> Dictionary:
	var job: Dictionary = row.result.job
	var id: String = row.payload.actor_id
	var success := code == DONE
	if success:
		world._trade_account(id)[job.material] -= 1
		world._item(job.item_id)[job.part] = 100
	var text := "I finished repairing my axe %s and used 1 %s." % [job.part, job.material] if success else (
		"I could not reach my work point. My repair ended unfinished; nothing was consumed." if code == BLOCKED else
		"My repair prerequisites changed. The job ended unfinished; nothing was consumed.")
	var event: Dictionary = world.capability_event(code, id, [id], job.command_id, job.provenance, text)
	event.merge({"item_id": job.item_id, "part": job.part, "material": job.material,
		"consumed": 1 if success else 0, "work_seconds": job.elapsed,
		"position": world._state.godot.positions[id].duplicate()})
	world._append_life_event(event)
	row.status = "completed" if success else "rejected"
	row.result.ok = success
	row.result.pending = false
	row.result.code = code
	row.result["terminal_seq"] = event.seq
	return {"ok": success, "code": code, "command_id": job.command_id, "actor_id": id, "event_id": event.event_id}

func validate_command(world, value: Dictionary, command: String, row: Dictionary, event: Dictionary) -> Dictionary:
	var result_keys := ["ok", "code", "pending", "event_id", "job", "speech_delivery"]
	if row.status != "pending": result_keys.append("terminal_seq")
	if not world._exact_keys(row.result, result_keys) or row.result.get("speech_delivery") != {"attempted": false, "delivered": false, "code": "physical_work_not_speech"}:
		return world._failure("invalid_self_repair_receipt")
	var job: Variant = row.result.get("job")
	if not job is Dictionary or not world._exact_keys(job, ["action", "actor_id", "item_id", "part", "material", "command_id", "provenance", "target_position", "duration_seconds", "elapsed", "best_remaining", "no_progress_seconds"]):
		return world._failure("invalid_self_repair_job")
	var id: String = row.payload.actor_id
	if job.action != "self_repair" or job.actor_id != id or job.command_id != command or job.provenance != row.payload.provenance or not job.item_id is String or job.part not in ["edge", "handle"]:
		return world._failure("invalid_self_repair_identity")
	if row.payload.option_id != PREFIX + job.item_id + ":" + job.part or row.payload.speech != "" or job.material != world._repair_part(job.part).material:
		return world._failure("invalid_self_repair_payload")
	if job.duration_seconds != SECONDS or not world._bounded(job.elapsed, SECONDS, false) or not world._bounded(job.best_remaining, 1000000, false) or not world._bounded(job.no_progress_seconds, STALL_SECONDS, false) or not world._valid_position(job.target_position):
		return world._failure("invalid_self_repair_progress")
	if job.elapsed > value.godot.elapsed_seconds - row.created_elapsed + 0.000001:
		return world._failure("self_repair_work_exceeds_world_time")
	if event.get("type") != START or event.get("recipient_ids") != [id] or event.get("item_id") != job.item_id or event.get("part") != job.part or event.get("material") != job.material or not world._valid_position(event.get("target_position")) or world._vector(event.target_position) != world._vector(job.target_position) or not world._bounded(event.get("initial_condition"), 99) or row.result.get("event_id") != event.event_id:
		return world._failure("invalid_self_repair_start")
	if row.status == "pending":
		if row.result.get("code") != START or row.result.get("pending") != true or row.result.has("terminal_seq") or job.elapsed >= SECONDS or job.no_progress_seconds >= STALL_SECONDS:
			return world._failure("invalid_self_repair_pending")
		if world._vector(job.target_position) != world._vector(value.godot.homes[id]): return world._failure("invalid_self_repair_worksite")
		return {"ok": true}
	var seq: Variant = row.result.get("terminal_seq")
	if not world._bounded(seq, value.life.seq) or seq <= row.event_seq or row.result.get("pending") != false:
		return world._failure("invalid_self_repair_terminal")
	var ended: Dictionary = value.life.events[int(seq) - 1]
	var code: String = str(row.result.get("code"))
	if code not in [DONE, BLOCKED, UNAVAILABLE] or ended.get("type") != code or ended.get("operation_id") != command or ended.get("actor_id") != id or ended.get("recipient_ids") != [id] or ended.get("provenance") != job.provenance or ended.get("item_id") != job.item_id or ended.get("part") != job.part or ended.get("material") != job.material or ended.get("work_seconds") != job.elapsed:
		return world._failure("self_repair_terminal_mismatch")
	if (row.status == "completed") != (code == DONE) or ended.get("consumed") != (1 if code == DONE else 0) or not world._valid_position(ended.get("position")):
		return world._failure("invalid_self_repair_outcome")
	var distance: float = world._vector(ended.position).distance_to(world._vector(job.target_position))
	if code == BLOCKED:
		if job.no_progress_seconds != STALL_SECONDS or distance <= ARRIVAL: return world._failure("invalid_self_repair_blocked")
	elif job.elapsed != SECONDS or distance > ARRIVAL:
		return world._failure("self_repair_completed_without_work")
	return {"ok": true}

func validate_state(world, value: Dictionary) -> Dictionary:
	var store: Dictionary = value.godot.capabilities
	var busy := {}
	for row in store.commands.values():
		if row.capability_id != ID or row.status != "pending": continue
		var id: String = row.payload.actor_id
		if busy.has(id) or value.godot.pending.has(id): return world._failure("self_repair_body_conflict")
		busy[id] = true
		for module in ["trade", "materials", "places", "baking"]:
			if value.godot.get(module, {}).get("jobs", {}).has(id): return world._failure("self_repair_body_conflict")
	for event in value.life.events:
		if event.get("type") not in EVENTS: continue
		var row: Dictionary = store.commands.get(event.get("operation_id"), {})
		var expected_seq: int = int(row.get("event_seq", -1)) if event.type == START else int(row.get("result", {}).get("terminal_seq", -1))
		if row.get("capability_id") != ID or expected_seq != event.seq: return world._failure("orphan_self_repair_event")
	return {"ok": true}
