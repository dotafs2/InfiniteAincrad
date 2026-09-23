extends "res://tests/town_life_acceptance.gd"

const TownActions = preload("res://core/town_actions.gd")
const TownTurns = preload("res://agents/town_turns.gd")

func run() -> void:
	var path := "user://town-need-transition-wake-%d.json" % Time.get_ticks_usec()
	var world: Dictionary = fixture()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(world, "", true, true))
	file.close()
	var town := TownActions.new()
	check(town.load_from(path).ok, "small disposable town fixture loads through the production action host")
	var actor := "fixture:a"
	for resident in town._state.residents:
		if resident.stable_id == actor:
			resident.needs.hunger = 81.0 # Legacy field is fullness/satiety.
	for account in town._state.survival.accounts:
		if account.resident_id == actor:
			account.food = 1
			account.energy = 100

	var turns := TownTurns.new()
	turns.town = town
	turns.brains[actor] = true # ready_resident checks availability; no brain is called.
	var options_before: Array = town.action_options(actor)
	var offered_before: Dictionary = _offered_actions(options_before)
	check(not _has_action(options_before, "eat_ration"),
		"fullness 81 does not yet offer the eat action")
	check(_has_action(options_before, "harvest_ration"),
		"the resident already has food-gathering as a voluntary option")
	var next_due := float(town._state.godot.elapsed_seconds) + 3600.0
	town._state.godot.resident_turns = {
		actor: {"status": "settled", "seen_seq": turns._own_seq(actor), "next_due": next_due,
			"offered_actions": offered_before, "history": []}
	}
	check(turns.ready_resident().is_empty(),
		"the resident is initially inside the cooldown and has no new evidence")

	var before_food := int(town.account(actor).food)
	var advanced: Dictionary = town.advance(120.0)
	check(advanced.ok, "normal world advancement succeeds")
	check(town.resident(actor).needs.hunger == 80.0,
		"one survival tick moves legacy fullness from 81 to 80")
	var options_after: Array = town.action_options(actor)
	check(_has_action(options_after, "eat_ration"),
		"the same ordinary action menu now offers eating at fullness 80")
	check(town.account(actor).food == before_food and town.pending_job(actor).is_empty(),
		"the scheduler does not eat, consume food or start work automatically")
	var actual_due := turns.ready_resident()
	var expected_due := actor if not _has_action(options_before, "eat_ration") and _has_action(options_after, "eat_ration") else ""
	var current_gap_reproduced := actual_due.is_empty() and expected_due == actor
	check(expected_due == actor,
		"the fixture creates a newly offered eat choice that should invite one fresh decision")
	check(actual_due == expected_due,
		"newly offered ration choice invites exactly one decision: expected %s, got %s" % [expected_due, actual_due])

	# Model an ordinary acknowledgement of the new menu: an already offered eat action
	# must not create a second transition wake, and the host still leaves the choice voluntary.
	var acknowledged: Dictionary = town._state.godot.resident_turns[actor]
	acknowledged.offered_actions = _offered_actions(options_after)
	acknowledged.seen_seq = turns._own_seq(actor)
	acknowledged.next_due = next_due
	check(turns.ready_resident().is_empty(),
		"a menu that already includes eat does not create a duplicate wake")
	acknowledged.offered_actions = {"broken": 7}
	check(turns.ready_resident().is_empty(),
		"a malformed historical menu cannot prove a new offer")
	acknowledged.offered_actions = _offered_actions(options_before)
	turns._admission_closed = true
	check(turns.ready_resident().is_empty(), "closed admission still blocks the new-offer wake")
	turns._admission_closed = false
	turns.inflight[actor] = "fixture-request"
	check(turns.ready_resident().is_empty(), "in-flight turn still blocks duplicate admission")
	turns.inflight.erase(actor)
	acknowledged.status = "pending"
	check(turns.ready_resident().is_empty(), "pending status still requires review")
	acknowledged.status = "settled"
	check(town.account(actor).food == before_food and town.resident(actor).needs.hunger == 80.0,
		"acknowledging the missed offer leaves all survival resources unchanged")

	print(JSON.stringify({"suite": "town_need_transition_wake_acceptance", "checks": checks,
		"failures": failures, "actor_id": actor, "fullness_before": 81.0, "fullness_after": 80.0,
		"newly_offered_action": "eat_ration", "expected_due": expected_due,
		"actual_due": actual_due, "current_gap_reproduced": current_gap_reproduced,
		"food_before": before_food, "food_after": town.account(actor).food,
		"automatic_action": false, "paid_calls": 0,
		"status": "need_transition_wake_passed" if failures == 0 else "scheduler_gap_or_regression"}))
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	turns.free()
	quit(0 if failures == 0 else 1)

func _has_action(options: Array, action_id: String) -> bool:
	for option in options:
		if option is Dictionary and option.get("action", "") == action_id:
			return true
	return false

func _offered_actions(options: Array) -> Dictionary:
	var result := {}
	for index in options.size():
		var option: Dictionary = options[index]
		result["a%d" % index] = option.get("id", "")
	return result
