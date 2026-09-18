extends "res://tests/town_trade_acceptance.gd"

func run() -> void:
	var path := "user://town-basic-needs-rule-%d.json" % Time.get_ticks_usec()
	var world := trade_fixture()
	var id := "fictional:ember"
	for account_value in world.survival.accounts:
		if account_value.resident_id == id:
			account_value.food = 0
			account_value.energy = 0
	for person in world.residents:
		if person.stable_id == id:
			person.needs.hunger = 0
	_write_fixture(path, world)
	var town := TownTrade.new()
	check(town.load_from(path).ok, "zero-needs fixture loads")
	var options := town.trade_options(id)
	check(options.any(func(option): return option.get("action") == "rest")
		and options.any(func(option): return option.get("action") == "harvest_ration"),
		"zero energy and satiety do not remove the authoritative rest or harvest choices")
	var rule := str(town.resident_view(id).get("known_rules", {}).get("basic_needs", ""))
	check(rule.contains("satiety=0") and rule.contains("energy=0")
		and rule.contains("does not itself prevent movement") and rule.contains("available_actions")
		and rule.contains("does not guarantee") and rule.contains("stock"),
		"the personal view states the zero-needs, revalidation and no-stock-guarantee boundaries")
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_basic_needs_rule", "checks": checks,
		"failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
