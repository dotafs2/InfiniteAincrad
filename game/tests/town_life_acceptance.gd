extends SceneTree

const Town = preload("res://core/town_life.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func fixture() -> Dictionary:
	var world := {"schema_version": 2, "world_id": "fixture:town-rules", "elapsed_seconds": 0,
		"residents": [], "life": {"seq": 0, "events": []},
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 1, "capacity": 3, "initial_stock": 1, "produced_total": 0, "harvested_total": 0, "growth_remainder_seconds": 0},
		"godot": {"schema_version": 1, "mode": "migration_validation", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0, 0]}}
	for id in ["fixture:a", "fixture:b", "fixture:c"]:
		world.residents.append({"stable_id": id, "name": id, "role": "tester", "needs": {"hunger": 60}, "coins_col": 10, "runtime": {"private_memory": id, "historical_coordinate": -1551.6842461617832}})
		world.survival.accounts.append({"resident_id": id, "food": 1, "energy": 50})
		world.godot.positions[id] = [0, 0, 0]
		world.godot.homes[id] = [0, 0, 0]
		world.godot.observations[id] = []
	return world

func run() -> void:
	var path := "user://town-rules-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture(), "", true, true))
	file.close()
	var town := Town.new()
	check(town.load_from(path).ok, "valid fixture load")
	check(town.active_ids().size() == 3, "three explicit test identities")
	check(not JSON.stringify(town.resident_view("fixture:a")).contains("private_memory"), "legacy runtime excluded from model view")
	check(town.resident_view("missing").is_empty(), "unknown resident gets no view")
	check(not town.start_action("missing", "rest", "bad").ok, "unknown cannot act")
	check(not town.start_action("fixture:a", "create_food", "bad").ok, "arbitrary action rejected")
	check(town.start_action("fixture:a", "eat_ration", "eat-1").ok, "eat begins")
	check(town.account("fixture:a").food == 1, "food unchanged until duration complete")
	town.advance(15)
	check(town.save_to(path).ok, "mid-action save")
	var restored := Town.new()
	check(restored.load_from(path).ok, "mid-action cold load")
	# JSON has one number type: 15 and 15.0 normalize to the same encoded value.
	check(restored._serialize_state() == town._serialize_state(), "cold load preserves full numeric precision and makes no catch-up changes")
	check(restored.resident("fixture:a").runtime.historical_coordinate == -1551.6842461617832, "historical float round-trips exactly")
	restored.advance(15)
	check(restored.account("fixture:a").food == 0 and restored.resident("fixture:a").needs.hunger == 100, "one ration becomes satiety")
	var after := restored.snapshot()
	check(restored.start_action("fixture:a", "eat_ration", "eat-1").duplicate, "duplicate completion acknowledged")
	check(restored.snapshot() == after, "no repeated consumption")
	check(not restored.start_action("fixture:a", "rest", "eat-1").ok, "command content conflict")
	check(restored.start_action("fixture:a", "harvest_ration", "harvest-a").ok, "forage starts")
	restored.advance(20)
	check(restored.account("fixture:a").food == 0, "distant harvest has no effect")
	restored.host_move("fixture:a", Vector3(4, 0, 0))
	restored.host_move("fixture:b", Vector3(4, 0, 0))
	check(restored.start_action("fixture:b", "harvest_ration", "harvest-b").ok, "second worker competes for last berry")
	var result: Dictionary = restored.advance(20)
	check(result.completed.size() == 2, "both attempts resolved")
	check(restored.snapshot().foraging.stock == 0 and restored.snapshot().foraging.harvested_total == 1, "single berry consumed once")
	check(restored.account("fixture:a").food + restored.account("fixture:b").food == 2, "food conservation under competition")
	check(restored.resident_view("fixture:c").experiences.is_empty(), "nonparticipant does not learn private actions")
	check(restored.resident("fixture:a").coins_col == 10, "food actions never generate money")
	check(not restored.advance(INF).ok and not restored.advance(-1).ok, "invalid clock rejected")
	for unused in range(15):
		restored.advance(120)
	check(restored.snapshot().foraging.stock == 1 and restored.snapshot().foraging.produced_total == 1, "one berry per 1800 seconds")
	check(restored.account("fixture:c").energy == 35 and restored.resident("fixture:c").needs.hunger == 45, "survival drains on live time")
	var locked := Town.new()
	check(locked.acquire_writer(path).ok, "another writer owns save")
	var before := restored.snapshot()
	var blocked: Dictionary = restored.transaction(path, func(): return restored.start_action("fixture:c", "rest", "rest-c"))
	check(not blocked.ok and restored.snapshot() == before, "writer conflict cannot mutate")
	locked.release_writer(path)
	check(restored.transaction(path, func(): return restored.start_action("fixture:c", "rest", "rest-c")).ok, "transaction commits")
	restored.release_writer(path)
	var before_failed_save := restored.snapshot()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	var failed_save := restored.transaction(path, func(): return restored.start_action("fixture:b", "rest", "unsaved-rest"))
	check(not failed_save.ok and restored.snapshot() == before_failed_save, "failed file write rolls back started action and receipt")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	# Optional private full migration smoke; only emit counts, not personal history.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="):
			var source := Town.new()
			check(source.load_from(arg.trim_prefix("--town-save=")).ok, "complete private migration loads")
			check(source.snapshot().residents.size() == 13 and source.snapshot().life.seq == 37, "13 original identities and 37 events")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_life", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
