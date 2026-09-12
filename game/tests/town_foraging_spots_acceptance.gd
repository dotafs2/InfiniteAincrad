extends "res://tests/town_life_acceptance.gd"
## Rule/persistence fixture only. Physical walkability belongs to scene acceptance.

func spots_for(town) -> Dictionary:
	var center: Vector3 = town.berry_center()
	return {"fixture:a": [center.x - 1.0, center.y, center.z],
		"fixture:b": [center.x + 1.0, center.y, center.z],
		"fixture:c": [center.x, center.y, center.z + 1.0]}

func write_fixture(path: String, world: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(world, "", true, true))
	file.close()

func run() -> void:
	var path := "user://foraging-work-spots-%d.json" % Time.get_ticks_usec()
	var seed := fixture()
	seed.origin = {"fixture": "unchanged declared genesis"}
	write_fixture(path, seed)
	var town := Town.new()
	check(town.load_from(path).ok, "legacy fixture loads without layout migration")
	var center: Vector3 = town.berry_center()
	for id in town.active_ids():
		check(town.destination(id, "harvest_ration") == center, "legacy harvest target remains berry center: " + id)
	var spots := spots_for(town)
	var initial: Dictionary = town.snapshot()
	check(not town.transaction(path, func(): return town.configure_foraging_work_spots(spots, "npc:layout")).ok, "NPC command cannot install layout")
	for fault in ["missing", "unknown", "near", "far", "height", "nan", "shape"]:
		var bad := spots.duplicate(true)
		match fault:
			"missing": bad.erase("fixture:a")
			"unknown": bad["missing:resident"] = [center.x, center.y, center.z - 1.0]
			"near": bad["fixture:b"] = [center.x - 0.5, center.y, center.z]
			"far": bad["fixture:a"] = [center.x + 2.01, center.y, center.z]
			"height": bad["fixture:a"] = [center.x - 1.0, center.y + 0.51, center.z]
			"nan": bad["fixture:a"] = [NAN, center.y, center.z]
			"shape": bad["fixture:a"] = [center.x, center.y]
		check(not town.transaction(path, func(): return town.configure_foraging_work_spots(bad, "development_gm:bad-" + fault)).ok, "invalid layout rejected: " + fault)
	check(town.snapshot() == initial, "all rejected layouts preserve exact world facts")
	# Keep an existing command and ten seconds of accepted work across installation.
	check(town.transaction(path, func(): return town.start_action("fixture:a", "harvest_ration", "fixture:ongoing-harvest", "opengameagent_fixture")).ok, "legacy harvest begins")
	town.host_move("fixture:a", center)
	check(town.transaction(path, func(): return town.advance(10)).ok, "legacy job earns ten seconds only at actual legacy target")
	var before: Dictionary = town.snapshot()
	var command := "development_gm:reviewed-foraging-spots"
	check(town.transaction(path, func(): return town.configure_foraging_work_spots(spots, command)).ok, "reviewed distinct work spots install")
	var installed: Dictionary = town.snapshot()
	check(installed.godot.pending == before.godot.pending and installed.godot.commands == before.godot.commands, "installation preserves pending IDs, elapsed work and command history")
	for key in ["world_id", "origin", "residents", "survival", "foraging", "elapsed_seconds"]:
		check(installed[key] == before[key], "installation preserves " + key)
	check(installed.life.items == before.life.items and installed.life.accounts == before.life.accounts and installed.life.contracts == before.life.contracts, "installation preserves money, items and contracts")
	check(installed.godot.berry_position == before.godot.berry_position and town.berry_center() == center, "public berry center remains unchanged")
	check(installed.life.events.slice(0, before.life.events.size()) == before.life.events and installed.life.events.size() == before.life.events.size() + 1, "exactly one attributed event appends to unchanged history")
	check(installed.life.events[-1].recipient_ids == [] and not installed.life.events[-1].has("text"), "layout installation is not public speech")
	for id in town.active_ids():
		check(town.destination(id, "harvest_ration") == town._vector(spots[id]), "harvest uses assigned work spot: " + id)
		check(not JSON.stringify(town.resident_view(id)).contains("foraging_work_spots"), "personal view excludes host layout diagnostics: " + id)
	var snapshot_before_replay: Dictionary = town.snapshot()
	check(town.configure_foraging_work_spots(spots.duplicate(true), command).duplicate and town.snapshot() == snapshot_before_replay, "exact direct replay changes no in-memory state")
	check(not town.transaction(path, func(): return town.configure_foraging_work_spots(spots, "development_gm:replacement")).ok, "another command cannot replace layout")
	var changed := spots.duplicate(true)
	changed["fixture:a"][2] = center.z - 0.1
	check(not town.transaction(path, func(): return town.configure_foraging_work_spots(changed, command)).ok, "same command cannot reassign a work spot")
	check(town.transaction(path, func(): return town.advance(10)).ok, "old center alone no longer counts as assigned spot arrival")
	check(town.pending_job("fixture:a").elapsed == 10 and town.snapshot().foraging.stock == 1, "distance gate preserves old labor but grants no remote progress or food")
	town.host_move("fixture:a", town.destination("fixture:a", "harvest_ration"))
	for probe in [Callable(), func(_id): return false, func(_id): return "not a clearance verdict"]:
		town.require_foraging_access(probe)
		check(town.transaction(path, func(): return town.advance(2)).ok, "blocked or invalid required host probe keeps world running")
		check(town.pending_job("fixture:a").elapsed == 10 and town.snapshot().foraging.stock == 1, "even assigned-point arrival cannot work through denied host clearance")
	town.require_foraging_access(func(_id): return true)
	check(town.transaction(path, func(): return town.advance(5)).ok, "assigned arrival advances same job to fifteen seconds")
	var bytes := FileAccess.get_file_as_bytes(path)
	check(town.release_writer(path).ok, "release old writer before cold load")
	town = Town.new()
	check(town.load_from(path).ok, "cold load validates persisted layout and original pending job")
	check(FileAccess.get_file_as_bytes(path) == bytes and town.pending_job("fixture:a").elapsed == 15, "cold load preserves exact bytes and unfinished work")
	check(town.configure_foraging_work_spots(spots, command).duplicate, "cold exact replay keeps original layout")
	check(town.transaction(path, func(): return town.advance(4)).ok and town.snapshot().foraging.stock == 1, "nineteen seconds never consumes a berry")
	check(town.transaction(path, func(): return town.advance(1)).ok, "twentieth second completes unchanged finite work rule")
	check(town.snapshot().foraging.stock == 0 and town.snapshot().foraging.harvested_total == 1 and town.account("fixture:a").food == 2, "exactly one berry transfers to worker inventory")
	check(town.transaction(path, func(): return town.start_action("fixture:b", "harvest_ration", "fixture:last-berry-competitor", "opengameagent_fixture")).ok, "second resident may investigate stale source availability")
	town.host_move("fixture:b", town.destination("fixture:b", "harvest_ration"))
	check(town.transaction(path, func(): return town.advance(20)).ok, "competitor earns actual work time at separate spot")
	check(town.pending_job("fixture:b").is_empty() and town.snapshot().godot.commands["fixture:last-berry-competitor"].result.code == "resources_unavailable", "empty source rejects terminally without leaving a phantom pending job")
	check(town.account("fixture:b").food == 1 and town.snapshot().foraging.harvested_total == 1, "separate spots never multiply finite stock")
	var final_state: Dictionary = town.snapshot()
	check(town.start_action("fixture:a", "harvest_ration", "fixture:ongoing-harvest", "opengameagent_fixture").duplicate and town.snapshot() == final_state, "old completed command cannot harvest twice")
	for fault in ["layout", "position", "event", "recipient", "duplicate_event", "missing_layout"]:
		var corrupt := final_state.duplicate(true)
		match fault:
			"layout": corrupt.godot.foraging_work_spots = []
			"position": corrupt.godot.foraging_work_spots.positions["fixture:a"][0] -= 0.1
			"event": corrupt.life.events[0].operation_id = "development_gm:forged"
			"recipient": corrupt.life.events[0].recipient_ids = ["fixture:b"]
			"duplicate_event":
				var extra: Dictionary = corrupt.life.events[0].duplicate(true)
				extra.seq = corrupt.life.seq + 1
				corrupt.life.events.append(extra)
				corrupt.life.seq += 1
			"missing_layout": corrupt.godot.erase("foraging_work_spots")
		check(not town._validate_state(corrupt).ok, "tampered layout/evidence rejected: " + fault)
	# A later admission leaves all old assignments intact; no implicit new layout.
	var extended := final_state.duplicate(true)
	var newcomer: Dictionary = extended.residents[0].duplicate(true)
	newcomer.stable_id = "fixture:later"
	extended.residents.append(newcomer)
	var supplies: Dictionary = extended.survival.accounts[0].duplicate(true)
	supplies.resident_id = newcomer.stable_id
	extended.survival.accounts.append(supplies)
	extended.godot.positions[newcomer.stable_id] = [0, 0, 2]
	extended.godot.homes[newcomer.stable_id] = [0, 0, 2]
	extended.godot.observations[newcomer.stable_id] = []
	check(town._validate_state(extended).ok, "later active identity does not invalidate original persisted subset")
	var unassigned := Town.new()
	unassigned._state = extended
	check(unassigned.destination(newcomer.stable_id, "harvest_ration") == center, "unassigned later identity has explicit legacy center fallback")
	check(unassigned.configure_foraging_work_spots(spots, command).duplicate, "later admission does not break exact old layout replay")
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_foraging_spots", "checks": checks, "failures": failures,
		"paid_calls": 0, "physical_reachability_tested": false}))
	quit(0 if failures == 0 else 1)
