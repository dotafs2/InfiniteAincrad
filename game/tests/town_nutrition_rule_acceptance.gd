extends "res://tests/town_life_acceptance.gd"

const TownActions = preload("res://core/town_actions.gd")
const TownTurns = preload("res://agents/town_turns.gd")

class TestBrain extends Node:
	var calls := 0
	var received: Array = []

	func propose(view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		received.append(view.duplicate(true))
		var action_id := "wait"
		for detail in view.get("action_details", []):
			if detail is Dictionary and str(detail.get("label", "")).to_lower().contains("wait"):
				action_id = str(detail.get("id", "wait"))
				break
		await get_tree().process_frame
		return {"ok": true, "decision": {"action": action_id,
			"reason": "I will wait while keeping my current food and choices unchanged."},
			"command_id": "nutrition-wait-%d" % calls,
			"provenance": "opengameagent_fixture"}

class TownLifeOnly extends "res://core/town_life.gd":
	func trade_options(_id: String) -> Array:
		return [{"id": "wait", "label": "Wait", "action": "wait"}]

	func submit_trade(_id: String, option: String, _command: String,
			_provenance: String, _speech: String = "") -> Dictionary:
		return {"ok": option == "wait", "code": "wait" if option == "wait" else "invalid_option"}

func run() -> void:
	var path := "user://town-nutrition-rule-%d.json" % Time.get_ticks_usec()
	var source := fixture()
	for resident in source.residents:
		if resident.stable_id == "fixture:a":
			resident.needs.hunger = 80.0
			resident.runtime.private_memory = "private-nutrition-sentinel"
	for account in source.survival.accounts:
		if account.resident_id == "fixture:a": account.food = 1
		if account.resident_id == "fixture:b": account.food = 1
		if account.resident_id == "fixture:c": account.food = 0
	for resident in source.residents:
		if resident.stable_id in ["fixture:b", "fixture:c"]:
			resident.needs.hunger = 80.0
	_write_fixture(path, source)

	var town := TownActions.new()
	check(town.load_from(path).ok, "disposable nutrition fixture loads")
	var actor := "fixture:a"
	var options_before: Array = town.action_options(actor)
	var option_ids_before := _option_ids(options_before)
	var fullness_80_offered := town.available(actor).has("eat_ration")
	check(fullness_80_offered
		and _has_option(options_before, "life:eat_ration"),
		"the real TownLife threshold offers eating at fullness 80 with one ration")
	var brain := TestBrain.new()
	root.add_child(brain)
	var turns := TownTurns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	turns.brains[actor] = brain
	var food_before := int(town.account(actor).food)
	var fullness_before := float(town.resident(actor).needs.hunger)
	var seq_before := int(town._state.life.seq)
	var result: Dictionary = await turns.step(actor)
	check(result.get("ok", false) and result.get("code") == "settled",
		"the real TownTurns host sends and settles a voluntary wait choice")
	check(brain.received.size() == 1, "the prepared decision view is captured by one offline test brain")
	if not brain.received.is_empty():
		var view: Dictionary = brain.received[0]
		var rule := _nutrition_rule(view)
		check(not rule.is_empty(),
			"prepared resident request discloses the existing meal threshold, 30-second duration, +40 return and 100 cap")
		if not rule.is_empty():
			var lowered := rule.to_lower()
			check(lowered.contains("satiety") or lowered.contains("fullness"),
				"nutrition rule names the fullness measure")
			check(rule.contains("80") and rule.contains("40") and rule.contains("100")
				and rule.contains("30"),
				"nutrition rule retains the exact existing offer, return, cap and duration values")
			check((lowered.contains("ration") or lowered.contains("food"))
				and (lowered.contains("eat") or lowered.contains("meal")),
				"nutrition rule identifies the voluntary ration action")
			check(not lowered.contains("must eat") and not lowered.contains("should eat")
				and not lowered.contains("always eat") and not lowered.contains("must wait"),
				"nutrition information is descriptive and does not direct eating or waiting")
		check(view.needs.get("satiety", -1) == 80.0
			and view.inventory.get("food", -1) == 1,
			"the rule accompanies only this actor's fullness and food inventory")
		check(not JSON.stringify(view).contains("private-nutrition-sentinel")
			and not JSON.stringify(view).contains("private_memory"),
			"prepared request does not leak private runtime memory")
		var rules: Dictionary = view.get("known_rules", {})
		for existing_rule in ["basic_needs", "axe_use", "communication", "repair"]:
			check(rules.has(existing_rule), "nutrition disclosure preserves existing " + existing_rule + " rule")
		check(view.get("action_details", []).any(func(item):
			return item is Dictionary and str(item.get("label", "")).to_lower().contains("wait")),
			"the captured request retains the voluntary wait option")
	check(int(town.account(actor).food) == food_before
		and float(town.resident(actor).needs.hunger) == fullness_before
		and town.pending_job(actor).is_empty()
		and int(town._state.life.seq) == seq_before,
		"preparing and choosing wait consumes no ration, changes no fullness or starts no meal")
	var options_after: Array = town.action_options(actor)
	check(_option_ids(options_after) == option_ids_before,
		"the information-only request changes no authoritative action-menu choices")
	var start_a: Dictionary = town.transaction(path, func():
		return town.execute_action(actor, "life:eat_ration", "nutrition-meal-cap", "opengameagent_fixture"))
	check(start_a.get("ok", false), "fullness-80 meal starts through the production action host")
	var cap_food_before := int(town.account(actor).food)
	var cap_meal: Dictionary = town.transaction(path, func(): return town.advance(30.0))
	check(cap_meal.get("ok", false)
		and int(town.account(actor).food) == cap_food_before - 1
		and float(town.resident(actor).needs.hunger) == 100.0
		and town.pending_job(actor).is_empty(),
		"the real 30-second meal consumes one ration and caps fullness at 100")

	# Reopening a due ordinary turn must recreate, not append to, the nutrition rule.
	# Remove the offered ration before the next request so the deterministic test
	# brain cannot voluntarily select a meal while we are testing repeat disclosure.
	town.transaction(path, func():
		town.account(actor).food = 0
		return {"ok": true})
	var repeat_food_before := int(town.account(actor).food)
	if not town._state.godot.resident_turns.get(actor, {}).is_empty():
		town._state.godot.resident_turns[actor].next_due = 0.0
		result = await turns.step(actor)
		check(result.get("ok", false) and brain.received.size() == 2,
			"a second ordinary request remains valid")
		if brain.received.size() >= 2:
			var second_rule := _nutrition_rule(brain.received[1])
			check(not second_rule.is_empty() and second_rule == _nutrition_rule(brain.received[0]),
				"repeated requests contain one stable nutrition rule without duplicate accumulation")
	check(int(town.account(actor).food) == repeat_food_before
		and town.pending_job(actor).is_empty(),
		"repeated menu disclosure does not consume food or start a meal (food %d/%d, pending %s)" % [int(town.account(actor).food), food_before, JSON.stringify(town.pending_job(actor))])

	# Assert menu guards against the actual inherited TownLife.available implementation.
	var actor_b := "fixture:b"
	for resident in town._state.residents:
		if resident.stable_id == actor_b: resident.needs.hunger = 81.0
	var fullness_81_offered := town.available(actor_b).has("eat_ration")
	var at_81: Array = town.action_options(actor_b)
	check(not fullness_81_offered
		and not _has_option(at_81, "life:eat_ration"),
		"fullness 81 excludes the actual eat option")
	for resident in town._state.residents:
		if resident.stable_id == actor_b: resident.needs.hunger = 50.0
	check(town.available(actor_b).has("eat_ration")
		and _has_option(town.action_options(actor_b), "life:eat_ration"),
		"fullness 50 with one ration enables the real meal effect")
	var start_b: Dictionary = town.transaction(path, func():
		return town.execute_action(actor_b, "life:eat_ration", "nutrition-meal-plus-40", "opengameagent_fixture"))
	check(start_b.get("ok", false), "valid meal starts through the production action host")
	var before_b_food := int(town.account(actor_b).food)
	var before_b_fullness := float(town.resident(actor_b).needs.hunger)
	var advance_29: Dictionary = town.transaction(path, func(): return town.advance(29.0))
	check(advance_29.get("ok", false), "29 seconds of meal progress is accepted")
	check(int(town.account(actor_b).food) == before_b_food
		and float(town.resident(actor_b).needs.hunger) == before_b_fullness
		and not town.pending_job(actor_b).is_empty(),
		"29 seconds does not finish the meal or consume its ration")
	var advance_1: Dictionary = town.transaction(path, func(): return town.advance(1.0))
	check(advance_1.get("ok", false), "the 30-second meal duration completes")
	check(int(town.account(actor_b).food) == before_b_food - 1
		and float(town.resident(actor_b).needs.hunger) == 90.0
		and town.pending_job(actor_b).is_empty(),
		"completion consumes exactly one ration and adds the full 40 fullness")

	var actor_c := "fixture:c"
	var food_zero_offered := town.available(actor_c).has("eat_ration")
	check(town.account(actor_c).food == 0
		and not town.available(actor_c).has("eat_ration")
		and not _has_option(town.action_options(actor_c), "life:eat_ration"),
		"zero food excludes eating despite fullness 80")
	for resident in town._state.residents:
		if resident.stable_id == actor_c: resident.needs.hunger = 80.0
	var start_c: Dictionary = town.transaction(path, func():
		return town.execute_action(actor_c, "life:eat_ration", "nutrition-meal-no-food", "opengameagent_fixture"))
	check(not start_c.get("ok", false) and int(town.account(actor_c).food) == 0,
		"the real host rejects a meal with no food and moves no inventory")

	# On a base TownLife-compatible adapter view, known_rules is absent. The turn
	# projection must initialize/retain it safely rather than assuming TownTrade keys.
	var life_only_path := "user://town-nutrition-life-only-%d.json" % Time.get_ticks_usec()
	_write_fixture(life_only_path, fixture())
	var life_only := TownLifeOnly.new()
	check(life_only.load_from(life_only_path).ok, "base TownLife fixture loads")
	check(life_only.resident_view("fixture:a").get("known_rules", {}).is_empty(),
		"base TownLife view legitimately has no known_rules map")
	var generic_turns := TownTurns.new()
	root.add_child(generic_turns)
	generic_turns.town = life_only
	generic_turns.save_path = life_only_path
	var generic_brain := TestBrain.new()
	root.add_child(generic_brain)
	generic_turns.brains["fixture:a"] = generic_brain
	var generic_result: Dictionary = await generic_turns.step("fixture:a")
	check(generic_result.get("ok", false) and generic_brain.received.size() == 1,
		"a valid TownLife-only view without known_rules does not crash request preparation")
	if not generic_brain.received.is_empty():
		check(generic_brain.received[0].get("known_rules", {}).get("decision_format", {}).has("action"),
			"generic host still receives the prepared decision contract")

	town.release_writer(path)
	life_only.release_writer(life_only_path)
	var prepared_requests := brain.received.size()
	turns.free()
	brain.free()
	generic_turns.free()
	generic_brain.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(life_only_path))
	print(JSON.stringify({"suite": "town_nutrition_rule_acceptance", "checks": checks,
		"failures": failures, "prepared_requests": prepared_requests,
		"fullness_80_offered": fullness_80_offered,
		"fullness_81_offered": fullness_81_offered,
		"food_zero_offered": food_zero_offered,
		"automatic_consumption": false, "paid_calls": 0,
		"status": "failed" if failures > 0 else "nutrition_rule_acceptance_passed"}))
	quit(0 if failures == 0 else 1)

func _nutrition_rule(view: Dictionary) -> String:
	var rules: Variant = view.get("known_rules", {})
	var candidates: Array[String] = []
	if rules is Dictionary:
		for key in rules:
			var value: Variant = rules[key]
			if key == "nutrition" and value is Array:
				for item in value:
					if item is String: candidates.append(str(item))
			elif value is String:
				candidates.append(str(value))
	elif rules is Array:
		for item in rules:
			if item is String: candidates.append(str(item))
	var matches: Array[String] = []
	for candidate in candidates:
		var text := candidate.to_lower()
		if (text.contains("satiety") or text.contains("fullness")) \
				and text.contains("80") and text.contains("40") and text.contains("100") \
				and text.contains("30"):
			matches.append(candidate)
	return matches[0] if matches.size() == 1 else ""

func _has_option(options: Array, id: String) -> bool:
	for option in options:
		if option is Dictionary and str(option.get("id", "")) == id:
			return true
	return false

func _option_ids(options: Array) -> Array[String]:
	var result: Array[String] = []
	for option in options:
		if option is Dictionary:
			result.append(str(option.get("id", "")))
	return result

func _write_fixture(path: String, world: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(world, "", true, true))
	file.close()
