extends "res://tests/town_trade_acceptance.gd"

const BakingTown = preload("res://core/town_baking.gd")
const PlainRuntime = preload("res://core/town_runtime.gd")
const TownTurns = preload("res://agents/town_turns.gd")

func baking_fixture() -> Dictionary:
	var world := trade_fixture()
	world.life.seq = 1
	world.life.events = [{"seq": 1, "event_id": "life_event_1", "type": "ask_help",
		"actor_id": "fictional:forge", "subject_id": "fictional:forge",
		"recipient_ids": ["fictional:forge"], "text": "I need a public oven.",
		"operation_id": "fixture:baking-need", "request_id": "godot_help:fixture:baking-need",
		"source": "opengameagent_fixture"}]
	return world

func _write_baking_fixture(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(baking_fixture(), "", true, true))
	file.close()

func _foreign_command(town, journal_name: String, command_id: String, actor_id: String) -> void:
	if journal_name == "life":
		town._state.godot.commands[command_id] = {"payload": {"actor_id": actor_id}, "status": "pending"}
		return
	if not town._state.godot.get(journal_name, null) is Dictionary:
		town._state.godot[journal_name] = {}
	if not town._state.godot[journal_name].get("commands", null) is Dictionary:
		town._state.godot[journal_name].commands = {}
	town._state.godot[journal_name].commands[command_id] = {"payload": {"actor_id": actor_id}, "status": "pending"}

func run() -> void:
	var path := "user://fictional-town-baking-%d.json" % Time.get_ticks_usec()
	_write_baking_fixture(path)
	var town := BakingTown.new()
	check(town.load_from(path).ok, "baking fixture loads")
	var baker := "fictional:forge"
	var witness := "fictional:birch"
	var point := {"id": "fixture:public-oven", "label": "Public oven", "initial_flour": 1,
		"position": [4, 0, 4], "access": "public"}
	var second_point := {"id": "fixture:second-oven", "label": "Second public oven", "initial_flour": 1,
		"position": [6, 0, 4], "access": "public"}
	var before := town.snapshot()
	check(not town.transaction(path, func(): return town.install_baking_route(point, 1, "npc:install")).ok,
		"resident cannot install a public route")
	check(town.snapshot() == before, "rejected install leaves the save unchanged")
	check(town.transaction(path, func(): return town.install_baking_route(point, 1, "development_gm:fixture-oven")).ok,
		"reviewed finite oven installs")
	check(town.transaction(path, func(): return town.install_baking_route(second_point, 1, "development_gm:fixture-second-oven")).ok,
		"a second finite point installs without merging its stock")
	check(town.resident_view(baker).baking_points.is_empty(), "install does not broadcast knowledge")
	var installed_bytes := FileAccess.get_file_as_bytes(path)
	var plain := PlainRuntime.new()
	var plain_load: Dictionary = plain.load_from(path)
	check(not plain_load.ok and plain_load.get("code", "") == "baking_runtime_required",
		"an older base runtime fails closed on the baking namespace")
	check(FileAccess.get_file_as_bytes(path) == installed_bytes,
		"the rejected base-runtime load cannot rewrite the baking save")
	town.host_move(baker, Vector3(4, 0, 4))
	town.host_move(witness, Vector3(4, 0, 4))
	elapse(town, path, 0)
	check(town.resident_view(baker).baking_points.is_empty(),
		"an unbound visibility probe fails closed")
	town.require_baking_visibility(Callable())
	elapse(town, path, 0)
	check(town.resident_view(baker).baking_points.is_empty(),
		"an invalid visibility callback fails closed")
	town.require_baking_visibility(func(_id, _point_id): return false)
	elapse(town, path, 0)
	check(town.resident_view(baker).baking_points.is_empty(),
		"proximity without line of sight grants no baking knowledge")
	town.require_baking_visibility(func(id, _point_id): return id in [baker, witness])
	elapse(town, path, 0)
	var observed_view: Dictionary = town.resident_view(baker)
	check(observed_view.get("baking_points", []).size() == 2, "the baker personally observes visible ovens")
	check(town.resident_view("fictional:ember").baking_points.is_empty(),
		"a resident outside the reviewed LOS gains no baking knowledge")
	check(town.trade_options(baker).any(func(option): return option.get("id") == "baking:bake:fixture:public-oven"),
		"personal observation creates the baking option")
	var option := "baking:bake:fixture:public-oven"
	for journal_value in ["life", "trade", "materials", "places", "baking"]:
		var journal_name := str(journal_value)
		var collision: String = "fixture:foreign-" + journal_name
		var clean_before := town.snapshot()
		_foreign_command(town, journal_name, collision, witness)
		var collision_before := town.snapshot()
		var refused: Dictionary = town.submit_trade(baker, option, collision, "opengameagent_fixture")
		check(not refused.ok and refused.get("code", "") == "command_conflict",
			"a command id already live in %s is rejected" % journal_name)
		check(town.snapshot() == collision_before,
			"the %s command collision writes no baking state" % journal_name)
		town._state = clean_before
	var start_result: Dictionary = town.transaction(path, func(): return town.submit_trade(baker, option, "fixture:bake-1", "opengameagent_fixture"))
	check(start_result.ok, "resident voluntarily starts the bake")
	check(town.snapshot().godot.baking.points[point.id].flour_remaining == 0, "starting reserves one finite flour")
	check(town.pending_job(baker).get("action", "") == "bake_bread", "bake remains a physical pending journey")
	check(town.trade_options(witness).any(func(entry): return entry.get("id") == option)
		and town.resident_view(witness).baking_points.filter(func(entry): return entry.get("id") == point.id)[0].last_observed_flour == 1,
		"a stale personal observation offers only what that resident knows")
	var stale_before := town.snapshot()
	var stale_refused: Dictionary = town.submit_trade(witness, option, "fixture:stale-bake", "opengameagent_fixture")
	check(not stale_refused.ok and stale_refused.get("code", "") == "flour_unavailable",
		"the bake start rechecks real flour and honestly refuses stale knowledge")
	check(town.snapshot() == stale_before, "a stale flour refusal changes no resource or journal")
	var reverse_before := town.snapshot()
	var reverse_life: Dictionary = town.start_action(witness, "rest", "fixture:bake-1", "opengameagent_fixture")
	var reverse_trade: Dictionary = town.submit_trade(witness, "trade:unknown", "fixture:bake-1", "opengameagent_fixture")
	check(not reverse_life.ok and reverse_life.get("code", "") == "command_conflict"
		and not reverse_trade.ok and reverse_trade.get("code", "") == "command_conflict",
		"a baking command id cannot be reused through life or trade/material/place entry points")
	check(town.snapshot() == reverse_before, "reverse journal collisions leave the state unchanged")
	var station := town.destination(baker, "bake_bread")
	check(is_equal_approx(station.distance_to(Vector3(4, 0, 4)), 0.85),
		"the bake destination is the public apron in front of the oven, not its centre")
	town.host_move(baker, station)
	elapse(town, path, 60)
	var baked := town.snapshot()
	var terminal: Dictionary = baked.godot.baking.commands.get("fixture:bake-1", {}).get("result", {})
	check(terminal.get("code", "") == "bread_baked" and terminal.get("actor_id", "") == baker
		and terminal.get("command_id", "") == "fixture:bake-1"
		and terminal.get("capability_id", "") == "public_baking_route",
		"terminal receipt is a real loaf with exact adoption identity")
	var turns := TownTurns.new()
	turns.town = town
	var projected: Array = turns._feedback_history(baker, {"history": [{"action": "bake_bread",
		"command_id": "fixture:bake-1", "status": "settled"}]})
	var projected_result: Dictionary = projected[0].get("result", {}) if projected.size() == 1 else {}
	check(projected_result.get("actor_id", "") == baker
		and projected_result.get("command_id", "") == "fixture:bake-1"
		and projected_result.get("capability_id", "") == "public_baking_route",
		"resident feedback resolves the terminal baking journal with exact identity")
	turns.free()
	check(town._baking().ledgers[point.id][baker].held == 1, "the loaf belongs to the resident")
	check(town.account(baker).food == 2, "the real eatable food account receives the loaf")
	check(town.snapshot().godot.baking.points[point.id].flour_remaining == 0, "public flour never regenerates")
	var forged_total := baked.duplicate(true)
	forged_total.godot.baking.points[second_point.id].flour_remaining = 0
	forged_total.godot.baking.ledgers[second_point.id] = {baker: {"held": 1, "eaten": 0}}
	for account in forged_total.survival.accounts:
		if account.get("resident_id", "") == baker:
			account.food = 1
	check(town._validate_state(forged_total).get("code", "") == "baking_loaf_not_held",
		"held loaves across all points cannot exceed the resident's real food")
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := BakingTown.new()
	check(restored.load_from(path).ok, "cold restore loads the baking journal")
	check(FileAccess.get_file_as_bytes(path) == saved_bytes, "cold restore does not rewrite the save")
	check(restored._baking().ledgers[point.id][baker].held == 1, "cold restore keeps the held loaf")
	check(restored.transaction(path, func(): return restored.start_action(baker, "eat_ration", "fixture:eat-1", "opengameagent_fixture")).ok,
		"the baker can choose the ordinary eat action")
	restored.host_move(baker, restored.destination(baker, "eat_ration"))
	check(restored.transaction(path, func(): return restored.advance(30)).ok, "eating completes after elapsed time")
	check(restored.account(baker).food == 1 and restored._baking().ledgers[point.id][baker].held == 0 and restored._baking().ledgers[point.id][baker].eaten == 1,
		"the resident really eats the owned loaf")
	var final_state := restored.snapshot()
	check(final_state.godot.baking.points[point.id].flour_remaining + final_state.godot.baking.ledgers[point.id][baker].held + final_state.godot.baking.ledgers[point.id][baker].eaten == 1,
		"remaining plus held plus eaten flour is conserved")
	check(restored.transaction(path, func(): return restored.install_baking_route(point, 1, "development_gm:fixture-oven")).duplicate,
		"installation stays idempotent after cold restore")
	check(restored._validate_state(restored.snapshot()).ok, "baking state validates after the full loop")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_baking_route", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
