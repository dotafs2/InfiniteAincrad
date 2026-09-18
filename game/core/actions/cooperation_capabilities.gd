extends RefCounted
## A small composition of existing travel, with explicit invitation and consent.
const Registry = preload("res://core/actions/capability_registry.gd")
const Catalog = preload("res://spatial/town_places.gd")
const INVITATION_SECONDS := 300.0

func definitions() -> Array:
	var result: Array = []
	for verb in ["invite_visit", "accept_visit", "decline_visit", "cancel_invitation"]:
		result.append(Registry.spec("cooperation." + verb, "cooperation", "consent_protocol",
			["named_participants", "one_body_job_per_participant", "separate_destination_slots"], "optional",
			["current_participant_identity_and_consent", "personal_place_knowledge_before_travel", "both_bodies_available_at_acceptance"],
			["attributed_plan_protocol", "accepted_visit_composes_existing_travel_without_teleporting"], "invitation_can_be_declined_cancelled_or_expire"))
	return result

func options(world, id: String) -> Array:
	if world._busy(id): return []
	var result: Array = []
	var plans: Dictionary = world.capability_store().get("plans", {})
	for key in plans:
		var plan: Dictionary = plans[key]
		if plan.status != "invited" or id not in plan.participants: continue
		if world._state.godot.elapsed_seconds > plan.expires_at: continue
		var verb := "cancel_invitation" if id == plan.participants[0] else "decline_visit"
		result.append(_option(verb, key, "Cancel my invitation." if verb == "cancel_invitation" else "Decline this joint visit.", plan))
		if id == plan.participants[1] and _can_start(world, plan):
			result.append(_option("accept_visit", key, "Accept the invitation to %s; both consenting residents start walking to separate spots there." % Catalog.place(plan.place_id)["label"], plan))
	# At most one open invitation per resident: prevent a flood of commitments.
	if _has_open_plan(plans, id): return result
	for other in world.active_ids():
		if other == id or _has_open_plan(plans, other): continue
		if world.position_of(id).distance_to(world.position_of(other)) > world.HEARING_RANGE: continue
		for place_id in world.known_place_ids(id):
			# Only the proposer's knowledge enters the offered invitation. The receiver's
			# private place knowledge is checked later, on their own acceptance turn.
			result.append({"id": "ability:invite:" + other + ":" + place_id, "action": "invite_visit",
				"capability_id": "cooperation.invite_visit", "counterparty": other, "_place_id": place_id,
				"presentation": {"template": "Invite {0} to {1} (separate consent required).", "arguments": [world.resident_name(other), Catalog.place(place_id)["label"]]},
				"label": "Invite %s to %s (separate consent required)." % [world.resident_name(other), Catalog.place(place_id)["label"]], "speech_allowed": true})
	return result

func _option(verb: String, key: String, label: String, plan: Dictionary) -> Dictionary:
	return {"id": "ability:" + verb + ":" + key, "action": verb, "capability_id": "cooperation." + verb,
		"label": label, "speech_allowed": true, "_plan_id": key, "_place_id": plan.place_id}

func _has_open_plan(plans: Dictionary, id: String) -> bool:
	for plan in plans.values():
		if id in plan.participants and plan.status in ["invited", "running"]: return true
	return false

func _can_start(world, plan: Dictionary) -> bool:
	var a: String = plan.participants[0]
	var b: String = plan.participants[1]
	if world._busy(a) or world._busy(b): return false
	if world.position_of(a).distance_to(world.position_of(b)) > world.HEARING_RANGE: return false
	for member in plan.participants:
		if plan.place_id not in world.known_place_ids(member): return false
		if world.legacy_action_option(member, "place:travel:" + plan.place_id).is_empty(): return false
	return true

func execute(world, id: String, option: Dictionary, command: String, provenance: String, speech: String) -> Dictionary:
	var store: Dictionary = world.ensure_capability_store()
	var action: String = option.action
	var plan: Dictionary
	var key: String
	if action == "invite_visit":
		key = command
		plan = {"id": key, "participants": [id, option.counterparty], "place_id": option._place_id,
			"status": "invited", "expires_at": world._state.godot.elapsed_seconds + INVITATION_SECONDS,
			"children": [], "accepted_command": "", "created_seq": int(world._state.life.seq) + 1}
		store.plans[key] = plan
	else:
		key = option._plan_id
		plan = store.plans[key]
		if action == "accept_visit":
			if not _can_start(world, plan): return {"ok": false, "code": "option_unavailable"}
			# Outer action execution is atomic. A later child failure rolls all children
			# back, including reserved slots and command records; no partial departure.
			var steps: Array = []
			var children: Array = []
			for index in plan.participants.size():
				var member: String = plan.participants[index]
				var child_id := "joint:" + command.sha256_text().substr(0, 32) + ":" + str(index)
				var choice: String = "place:travel:" + plan.place_id
				steps.append({"actor_id": member, "option_id": choice, "command_id": child_id, "provenance": provenance, "speech": ""})
				children.append({"actor_id": member, "command_id": child_id, "option_id": choice})
			var batch: Dictionary = world.execute_atomic_actions(steps)
			if not batch.ok: return batch
			plan.children = children
			plan.status = "running"
			plan.accepted_command = command
		elif action == "decline_visit": plan.status = "declined"
		elif action == "cancel_invitation": plan.status = "cancelled"
	var text: String = speech if not speech.strip_edges().is_empty() else option.label
	var event: Dictionary = world.capability_event("joint_visit_" + action, id, plan.participants, command, provenance, text)
	event["plan_id"] = key
	event["place_id"] = plan.place_id
	world._append_life_event(event)
	return {"ok": true, "code": "joint_visit_" + action, "plan_id": key, "event_id": event.event_id,
		"pending": action == "accept_visit"}

func reconcile(world) -> void:
	var store: Dictionary = world.capability_store()
	for plan in store.get("plans", {}).values():
		if plan.status == "invited" and world._state.godot.elapsed_seconds > plan.expires_at:
			plan.status = "expired"
			_append_end(world, plan, "expired", plan.id, plan.participants[0])
		elif plan.status == "running":
			var pending := false
			var failed := false
			for child in plan.children:
				var receipt: Dictionary = world.action_receipt(child.command_id)
				pending = pending or receipt.get("status") == "pending"
				failed = failed or receipt.get("status") == "rejected" or receipt.is_empty()
			if pending: continue
			plan.status = "blocked" if failed else "completed"
			var command: Dictionary = store.commands[plan.accepted_command]
			command.status = "rejected" if failed else "completed"
			command.result = {"ok": not failed, "code": "joint_visit_" + plan.status, "plan_id": plan.id}
			_append_end(world, plan, plan.status, plan.accepted_command, plan.participants[1])

func _append_end(world, plan: Dictionary, status: String, command: String, actor: String) -> void:
	var provenance: String = world.capability_store().commands[command].payload.provenance
	var event: Dictionary = world.capability_event("joint_visit_" + status, actor, plan.participants, command, provenance,
		"Our joint visit is %s; this receipt does not claim anyone performed work there." % status)
	event["plan_id"] = plan.id
	event["place_id"] = plan.place_id
	event["system_receipt"] = true
	world._append_life_event(event)

func validate_command(world, value: Dictionary, command: String, row: Dictionary, event: Dictionary) -> Dictionary:
	var verb: String = row.capability_id.trim_prefix("cooperation.")
	var key: Variant = event.get("plan_id")
	var plans: Dictionary = value.godot.capabilities.plans
	if not key is String or not plans.has(key) or not plans[key] is Dictionary:
		return world._failure("orphan_cooperation_command")
	var plan: Dictionary = plans[key]
	if not plan.get("participants") is Array or plan.participants.size() != 2 or not plan.get("place_id") is String:
		return world._failure("invalid_plan_participants")
	var actor: Variant = plan.participants[0] if verb in ["invite_visit", "cancel_invitation"] else plan.participants[1]
	var option: String = "ability:" + verb + ":" + key
	if verb == "invite_visit": option = "ability:invite:" + str(plan.participants[1]) + ":" + plan.place_id
	if row.payload.actor_id != actor or row.payload.option_id != option or event.get("type") != "joint_visit_" + verb or event.get("recipient_ids") != plan.participants or event.get("place_id") != plan.place_id:
		return world._failure("invalid_plan_consent")
	if verb == "invite_visit" and command != key: return world._failure("invalid_plan_origin")
	if verb == "accept_visit":
		if plan.get("accepted_command") != command: return world._failure("invalid_plan_acceptance")
	elif row.status != "completed": return world._failure("invalid_plan_receipt")
	if not row.payload.speech.is_empty() and event.get("text") != row.payload.speech:
		return world._failure("capability_speech_mismatch")
	if row.result.get("plan_id") != key: return world._failure("invalid_plan_receipt")
	var expected_code: String = "joint_visit_" + verb
	if verb == "accept_visit" and row.status != "pending": expected_code = "joint_visit_" + str(plan.get("status"))
	if row.result.get("code") != expected_code: return world._failure("invalid_plan_receipt")
	return {"ok": true}

func validate_state(world, value: Dictionary) -> Dictionary:
	var store: Dictionary = value.godot.capabilities
	var open_members := {}
	# Check actual event order, including terminal receipts. A saved status alone
	# cannot assert that another resident consented or that a journey completed.
	var histories := {}
	for event in value.life.events:
		if not str(event.get("type", "")).begins_with("joint_visit_"): continue
		var key: Variant = event.get("plan_id")
		if not key is String or not store.plans.has(key): return world._failure("orphan_plan_event")
		if not histories.has(key): histories[key] = []
		histories[key].append(event)
	for key in store.plans:
		var plan: Variant = store.plans[key]
		if not key is String or not plan is Dictionary or not world._exact_keys(plan, ["id", "participants", "place_id", "status", "expires_at", "children", "accepted_command", "created_seq"]):
			return world._failure("invalid_shared_plan")
		if plan.id != key or not store.commands.has(key) or store.commands[key].capability_id != "cooperation.invite_visit": return world._failure("invalid_plan_origin")
		if not plan.accepted_command is String or not plan.status is String: return world._failure("invalid_plan_state")
		if not plan.participants is Array or plan.participants.size() != 2 or plan.participants[0] == plan.participants[1] or not plan.children is Array:
			return world._failure("invalid_plan_participants")
		for member in plan.participants:
			if not member is String or not value.godot.positions.has(member): return world._failure("invalid_plan_participants")
		if not plan.place_id is String or not Catalog.is_place_id(plan.place_id) or not world._valid_nonnegative(plan.expires_at) or plan.expires_at != store.commands[key].created_elapsed + INVITATION_SECONDS:
			return world._failure("invalid_plan_state")
		if not world._bounded(plan.created_seq, value.life.seq) or plan.created_seq != store.commands[key].event_seq or plan.created_seq < 1: return world._failure("invalid_plan_origin")
		var expected_status := ""
		var accepted := ""
		for event in histories.get(key, []):
			if event.get("recipient_ids") != plan.participants or event.get("place_id") != plan.place_id: return world._failure("invalid_plan_event")
			var verb: String = str(event.type).trim_prefix("joint_visit_")
			var op: String = str(event.get("operation_id", ""))
			if verb in ["invite_visit", "accept_visit", "decline_visit", "cancel_invitation"]:
				if not store.commands.has(op) or store.commands[op].event_seq != event.seq or store.commands[op].capability_id != "cooperation." + verb:
					return world._failure("unrecorded_plan_consent")
				if verb == "invite_visit":
					if expected_status != "" or op != key: return world._failure("invalid_plan_transition")
					expected_status = "invited"
				else:
					if expected_status != "invited" or store.commands[op].created_elapsed > plan.expires_at: return world._failure("invalid_plan_transition")
					if verb == "accept_visit":
						expected_status = "running"
						accepted = op
					else: expected_status = "declined" if verb == "decline_visit" else "cancelled"
			elif verb in ["expired", "completed", "blocked"]:
				var parent: String = key if verb == "expired" else accepted
				var actor: String = plan.participants[0] if verb == "expired" else plan.participants[1]
				if event.get("system_receipt") != true or op != parent or parent.is_empty() or event.get("actor_id") != actor or event.get("provenance") != store.commands[parent].payload.provenance:
					return world._failure("invalid_plan_terminal_receipt")
				if verb == "expired":
					if expected_status != "invited" or value.godot.elapsed_seconds <= plan.expires_at: return world._failure("premature_plan_expiry")
				elif expected_status != "running": return world._failure("invalid_plan_transition")
				expected_status = verb
			else: return world._failure("unknown_plan_event")
		if plan.status != expected_status or plan.accepted_command != accepted: return world._failure("unproven_plan_status")
		if plan.status in ["invited", "running"]:
			for member in plan.participants:
				if open_members.has(member): return world._failure("overlapping_shared_plans")
				open_members[member] = true
		if accepted.is_empty():
			if not plan.children.is_empty(): return world._failure("unaccepted_plan_has_work")
			continue
		if plan.children.size() != 2: return world._failure("invalid_plan_children")
		var pending := false
		var failed := false
		for index in 2:
			var child: Variant = plan.children[index]
			if not child is Dictionary or not world._exact_keys(child, ["actor_id", "option_id", "command_id"]) or child.actor_id != plan.participants[index] or child.option_id != "place:travel:" + plan.place_id:
				return world._failure("invalid_plan_child")
			var expected := "joint:" + accepted.sha256_text().substr(0, 32) + ":" + str(index)
			if child.command_id != expected: return world._failure("invalid_plan_child")
			var legacy: Dictionary = value.godot.get("places", {}).get("commands", {}).get(expected, {})
			if legacy.get("payload", {}).get("actor_id") != child.actor_id or legacy.get("payload", {}).get("option_id") != child.option_id or legacy.get("payload", {}).get("provenance") != store.commands[accepted].payload.provenance:
				return world._failure("invalid_plan_child")
			pending = pending or legacy.get("status") == "pending"
			failed = failed or legacy.get("status") == "rejected"
		var expected: String = "running" if pending else ("blocked" if failed else "completed")
		if plan.status != expected or store.commands[accepted].status != ("pending" if pending else ("rejected" if failed else "completed")):
			return world._failure("plan_child_outcome_mismatch")
	return {"ok": true}
