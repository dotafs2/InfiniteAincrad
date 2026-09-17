extends "res://tests/town_trade_acceptance.gd"

func run() -> void:
	var path := "user://town-food-handoff-%d.json" % Time.get_ticks_usec()
	var world := trade_fixture()
	var donor := "fictional:ember"
	var recipient := "fictional:birch"
	var distant := "fictional:forge"
	for account_value in world.survival.accounts:
		if account_value.resident_id == donor:
			account_value.food = 1
		elif account_value.resident_id == recipient:
			account_value.food = 0
	world.godot.positions[donor] = [0, 0, 0]
	world.godot.positions[recipient] = [1.11, 0, 0]
	world.godot.positions[distant] = [2, 0, 0]
	_write_fixture(path, world)
	var town := TownTrade.new()
	check(town.load_from(path).ok, "food handoff fixture loads")
	var option_id := "food:give:" + recipient
	var option: Dictionary = {}
	for candidate in town.trade_options(donor):
		if candidate.get("id") == option_id:
			option = candidate
	check(not option.is_empty() and option.get("action") == "give_food"
		and str(option.get("label", "")).contains("普通口粮")
		and str(option.get("label", "")).contains("不是交易"),
		"a nearby resident receives one explicit voluntary ordinary-ration option")
	check(not town.trade_options(donor).any(func(candidate): return candidate.get("id") == "food:give:" + donor)
		and not town.trade_options(donor).any(func(candidate): return candidate.get("id") == "food:give:" + distant),
		"self and residents outside the 1.5 metre handoff reach are not offered")
	var before := town.snapshot()
	var total_before := int(town.account(donor).food) + int(town.account(recipient).food) + int(town.account(distant).food)
	var handed: Dictionary = town.transaction(path,
		func(): return town.submit_trade(donor, option_id, "fixture:food-handoff", "opengameagent_fixture"))
	check(handed.get("code", "") == "food_handed_over" and handed.get("quantity", 0) == 1,
		"the donor's own selected action hands over exactly one ration")
	var after := town.snapshot()
	var total_after := int(town.account(donor).food) + int(town.account(recipient).food) + int(town.account(distant).food)
	check(town.account(donor).food == 0 and town.account(recipient).food == 1 and total_after == total_before,
		"one real food unit moves and total food is conserved")
	check(after.residents == before.residents and after.life.accounts == before.life.accounts
		and after.life.items == before.life.items and after.life.contracts == before.life.contracts
		and after.godot.positions == before.godot.positions,
		"the gift changes no satiety, money, material, item, contract or position")
	var event: Dictionary = after.life.events[-1]
	check(event.type == "food_handed_over" and event.actor_id == donor and event.subject_id == recipient
		and event.recipient_ids == [donor, recipient] and event.quantity == 1
		and event.operation_id == "fixture:food-handoff",
		"both residents receive one truthful persisted handoff event")
	var settled := town.snapshot()
	check(town.submit_trade(donor, option_id, "fixture:food-handoff", "opengameagent_fixture").get("duplicate", false)
		and town.snapshot() == settled,
		"replaying the same command is idempotent after the donor spent the ration")
	town.release_writer(path)
	var restored := TownTrade.new()
	check(restored.load_from(path).ok and restored.account(donor).food == 0
		and restored.account(recipient).food == 1,
		"the conserved handoff survives a cold restore")

	var stale_path := path + ".stale.json"
	world = trade_fixture()
	for account_value in world.survival.accounts:
		if account_value.resident_id == donor:
			account_value.food = 1
		elif account_value.resident_id == recipient:
			account_value.food = 0
	world.godot.positions[donor] = [0, 0, 0]
	world.godot.positions[recipient] = [1.11, 0, 0]
	_write_fixture(stale_path, world)
	var stale := TownTrade.new()
	check(stale.load_from(stale_path).ok and stale.trade_options(donor).any(func(candidate): return candidate.get("id") == option_id),
		"stale fixture first offers the real handoff")
	stale.account(recipient).food = 2
	var stale_before := stale.snapshot()
	check(stale.submit_trade(donor, option_id, "fixture:stale-food", "opengameagent_fixture").get("code", "") == "option_unavailable"
		and stale.snapshot() == stale_before,
		"a newly full recipient makes the submitted option stale with no partial transfer")

	stale.account(recipient).food = 0
	stale._state.godot.baking = {"ledgers": {"fixture:oven": {donor: {"held": 1, "eaten": 0}}}}
	check(not stale.trade_options(donor).any(func(candidate): return candidate.get("id") == option_id),
		"a baked loaf is not relabelled or transferred as an ordinary ration")
	stale.release_writer(stale_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
	print(JSON.stringify({"suite": "town_food_handoff", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
