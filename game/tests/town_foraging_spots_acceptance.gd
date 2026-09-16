extends "res://tests/town_life_acceptance.gd"
## Rule/persistence fixture only. Physical walkability belongs to scene acceptance.

func spots_for(town) -> Dictionary:
	return ring_spots(town.berry_center())

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
	declared_genesis_cases(path)
	reviewed_migration_cases(path)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--real-genesis="):
			real_genesis_case(argument.trim_prefix("--real-genesis="))
	town.release_writer(path)
	remove_world_files(path)
	print(JSON.stringify({"suite": "town_foraging_spots", "checks": checks, "failures": failures,
		"paid_calls": 0, "physical_reachability_tested": false}))
	quit(0 if failures == 0 else 1)

const LAYOUT_ID := "first-floor-market-quarter-v1"
const LAYOUT_SHA256 := "be6659494b9812df0ee41fd27db0ba652dcf32a97a44ac004e497b99d03445de"
const GENESIS_COMMAND := "development_gm:foraging-layout:v1"

func ring_spots(center: Vector3) -> Dictionary:
	return {"fixture:a": [center.x - 1.0, center.y, center.z],
		"fixture:b": [center.x + 1.0, center.y, center.z],
		"fixture:c": [center.x, center.y, center.z + 1.0]}

func shifted_spots(spots: Dictionary, shift: Vector3) -> Dictionary:
	var moved: Dictionary = {}
	for id in spots:
		moved[id] = [spots[id][0] + shift.x, spots[id][1] + shift.y, spots[id][2] + shift.z]
	return moved

func real_genesis_case(source: String) -> void:
	# Exercise the exact generated ten-resident save without ever opening it for writing.
	var source_bytes := FileAccess.get_file_as_bytes(source)
	var path := "user://foraging-real-genesis-%d.json" % Time.get_ticks_usec()
	var copy := FileAccess.open(path, FileAccess.WRITE)
	copy.store_buffer(source_bytes)
	copy.close()
	var town := Town.new()
	check(town.load_from(path).ok, "the real new-map genesis loads from an isolated copy")
	var center := town.berry_center()
	var identities: Array = town.active_ids()
	var spots: Dictionary = {}
	for index in identities.size():
		var angle := TAU * float(index) / float(identities.size())
		spots[identities[index]] = [center.x + cos(angle) * 1.5, center.y, center.z + sin(angle) * 1.5]
	check(identities.size() == 10, "the real genesis keeps its ten stable resident identities")
	check(town.transaction(path, func(): return town.configure_foraging_work_spots(spots, "development_gm:real-genesis-diagnostic")).ok, "the real layout_sha256 genesis accepts reviewed work spots")
	var installed := town.snapshot()
	check(town.release_writer(path).ok, "release the isolated real-genesis copy before cold load")
	var cold := Town.new()
	check(cold.load_from(path).ok and cold._serialize_state() == town._serialize_state(), "the configured real genesis survives an exact cold load")
	check(cold.snapshot().world_id == installed.world_id and cold.active_ids() == identities, "the real-genesis diagnostic preserves world and resident identity")
	check(FileAccess.get_file_as_bytes(source) == source_bytes, "the source genesis stays byte-identical")
	remove_world_files(path)

func reviewed_install(command: String, spots: Dictionary, center: Array, seq: int) -> Dictionary:
	return {"type": "foraging_work_spots_installed", "actor_id": "development_gm", "recipient_ids": [],
		"operation_id": command, "source": "development_gm_review", "positions": spots.duplicate(true),
		"berry_center": center.duplicate(), "seq": seq, "event_id": "life_event_%d" % seq}

func remove_world_files(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".replace-pending", ".writer-lock"]:
		var target := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
			DirAccess.remove_absolute(target)

func rejects(town, state: Dictionary, label: String) -> void:
	# Adding the preview flag must never turn a rejected world into an accepted one.
	var flagged: Dictionary = state.duplicate(true)
	flagged.godot.spatial_layout.preview_genesis = true
	check(not town._validate_state(state).ok, label)
	check(not town._validate_state(flagged).ok, label + " (also with preview_genesis)")

func _corrupt_transform(state: Dictionary) -> void:
	# One spot drifts off the uniform relocation while the persisted layout follows it.
	state.godot.foraging_work_spots.positions["fixture:a"][0] += 0.05
	state.godot.spatial_layout.foraging_after.positions["fixture:a"][0] += 0.05

func _corrupt_drop_spot(state: Dictionary) -> void:
	state.godot.foraging_work_spots.positions.erase("fixture:c")
	state.godot.spatial_layout.foraging_after.positions.erase("fixture:c")

func declared_genesis_cases(base: String) -> void:
	# A fresh new-map world declares its physical layout and keeps no relocation bridge:
	# nothing was relocated, so the reviewed evidence is the current ring itself.
	var path := base + ".genesis.json"
	var spots := ring_spots(Vector3(4, 0, 0))
	var declared_world: Dictionary = fixture()
	declared_world.fixture = false
	declared_world.origin = {"kind": "new_world_seed", "genesis": true, "migrated_from": null,
		"fixture": "unchanged declared genesis"}
	declared_world.godot.new_world_seed = true
	declared_world.godot.source_life_seq = 0
	declared_world.godot.spatial_layout = {"id": LAYOUT_ID, "doors": {}, "windows": {},
		"preview_genesis": true, "layout_sha256": LAYOUT_SHA256}
	write_fixture(path, declared_world)
	var town := Town.new()
	check(town.load_from(path).ok, "declared fresh genesis loads without a migration bridge")
	var declared: Dictionary = town.snapshot()
	check(declared.godot.spatial_layout.preview_genesis == true, "genesis declaration stays an explicit boolean fact")
	var spatial_keys: Array = declared.godot.spatial_layout.keys()
	spatial_keys.sort()
	check(spatial_keys == ["doors", "id", "layout_sha256", "preview_genesis", "windows"], "genesis fixture carries the real preview spatial key shape")
	check(not declared.godot.has("foraging_work_spots"), "fresh genesis starts without reviewed work spots")
	check(town.transaction(path, func(): return town.configure_foraging_work_spots(spots, GENESIS_COMMAND)).ok, "reviewed work spots install into a declared fresh genesis")
	var installed: Dictionary = town.snapshot()
	for key in ["world_id", "origin", "residents", "survival", "foraging", "elapsed_seconds"]:
		check(installed[key] == declared[key], "genesis installation preserves " + key)
	check(installed.life.items == declared.life.items and installed.life.accounts == declared.life.accounts and installed.life.contracts == declared.life.contracts, "genesis installation preserves money, items and contracts")
	check(installed.life.seq == declared.life.seq + 1 and installed.life.events.slice(0, declared.life.events.size()) == declared.life.events, "genesis installation appends exactly one event to unchanged history")
	check(installed.godot.berry_position == declared.godot.berry_position and town.berry_center() == Vector3(4, 0, 0), "genesis installation keeps the public berry center")
	check(town.active_ids() == ["fixture:a", "fixture:b", "fixture:c"], "genesis installation preserves the identity roster")
	for id in town.active_ids():
		check(town.destination(id, "harvest_ration") == town._vector(spots[id]), "genesis harvest uses the reviewed spot: " + id)
	check(town._validate_state(installed).code == "town_state_valid", "the installed declared genesis reports the expected validation code")
	var bytes := FileAccess.get_file_as_bytes(path)
	check(town.release_writer(path).ok, "release the genesis writer before cold load")
	var cold := Town.new()
	check(cold.load_from(path).ok, "cold load accepts reviewed spots in a declared fresh genesis")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold genesis load leaves the saved bytes untouched")
	check(cold._serialize_state() == town._serialize_state(), "cold genesis load preserves identity, history and balance exactly")
	check(cold.snapshot().life.seq == installed.life.seq and cold.snapshot().residents.size() == installed.residents.size(), "cold genesis load keeps roster size and history length")
	check(cold.configure_foraging_work_spots(spots, GENESIS_COMMAND).get("duplicate", false), "cold genesis replay keeps the original reviewed layout")
	check(cold.transaction(path, func(): return cold.start_action("fixture:a", "harvest_ration", "genesis:harvest", "opengameagent_fixture")).ok, "genesis resident starts a reviewed harvest")
	cold.host_move("fixture:a", cold.destination("fixture:a", "harvest_ration"))
	check(cold.transaction(path, func(): return cold.advance(20)).ok, "genesis harvest completes at the reviewed spot")
	check(cold.snapshot().foraging.stock == 0 and cold.account("fixture:a").food == 2 and cold.snapshot().foraging.harvested_total == 1, "declared genesis conserves exactly one finite berry")
	var final: Dictionary = cold.snapshot()
	for fault in ["position", "berry_center", "operation", "actor", "missing_event", "duplicate_event"]:
		var corrupted: Dictionary = final.duplicate(true)
		match fault:
			"position": corrupted.life.events[0].positions["fixture:a"][0] += 1.0
			"berry_center": corrupted.life.events[0].berry_center[0] += 1.0
			"operation": corrupted.life.events[0].operation_id = "development_gm:forged-genesis-layout"
			"actor": corrupted.life.events[0].actor_id = "fixture:a"
			"missing_event": corrupted.life.events[0].type = "work"
			"duplicate_event":
				var extra: Dictionary = corrupted.life.events[0].duplicate(true)
				extra.seq = corrupted.life.seq + 1
				corrupted.life.events.append(extra)
				corrupted.life.seq += 1
		check(not cold._validate_state(corrupted).ok, "declared genesis still rejects rewritten installation evidence: " + fault)
	var bridged: Dictionary = final.duplicate(true)
	bridged.godot.spatial_layout.foraging_before = final.godot.foraging_work_spots.positions.duplicate(true)
	check(not cold._validate_state(bridged).ok, "a genesis record carrying a relocation bridge must satisfy the migration check")
	var claimed: Dictionary = final.duplicate(true)
	claimed.godot.spatial_layout.source_sha256 = "claimed-relocation"
	check(not cold._validate_state(claimed).ok, "a genesis record claiming relocation provenance must satisfy the migration check")
	var relocated: Dictionary = final.duplicate(true)
	relocated.godot.spatial_layout.migration = []
	check(not cold._validate_state(relocated).ok, "a genesis record claiming a relocation list must satisfy the migration check")
	for stand_in in [1, 0, "true", "preview_genesis", null]:
		var weakened: Dictionary = final.duplicate(true)
		weakened.godot.spatial_layout.preview_genesis = stand_in
		check(not cold._validate_state(weakened).ok, "a non-boolean genesis flag cannot select the genesis path: " + str(stand_in))
	var unflagged: Dictionary = final.duplicate(true)
	unflagged.godot.spatial_layout.erase("preview_genesis")
	check(not cold._validate_state(unflagged).ok, "a bridge-less layout record with no genesis declaration is still rejected")
	for layout_hash in ["", "0".repeat(64), null]:
		var wrong_layout: Dictionary = final.duplicate(true)
		wrong_layout.godot.spatial_layout.layout_sha256 = layout_hash
		check(not cold._validate_state(wrong_layout).ok, "a fresh declaration must bind the reviewed layout bytes: " + str(layout_hash))
	var foreign: Dictionary = final.duplicate(true)
	foreign.godot.spatial_layout.id = "unreviewed-map-v2"
	check(cold._validate_state(foreign).code == "unsupported_spatial_layout", "an unknown layout id is still rejected in a declared genesis")
	var unbridged: Dictionary = final.duplicate(true)
	unbridged.godot.erase("spatial_layout")
	check(cold._validate_state(unbridged).code == "town_state_valid", "a world without a spatial record keeps the original unbridged rule")
	check(cold.release_writer(path).ok, "release the genesis writer")
	remove_world_files(path)

func reviewed_migration_cases(base: String) -> void:
	# A reviewed relocation keeps its exact before/after record and its original installation
	# evidence; the transform, position and evidence rules stay enforced either way.
	var path := base + ".migration.json"
	var command := "development_gm:relocated-foraging-layout:v1"
	var before_center := [4.0, 0.0, 0.0]
	var before_spots := ring_spots(Vector3(4, 0, 0))
	var shift := Vector3(-2.5, 0.5, 3.0)
	var after_center := [1.5, 0.5, 3.0]
	var after_spots := shifted_spots(before_spots, shift)
	var migrated: Dictionary = fixture()
	migrated.origin = {"fixture": "reviewed relocation of a legacy world"}
	migrated.godot.berry_position = after_center.duplicate()
	migrated.godot.foraging_work_spots = {"schema_version": 1, "positions": after_spots.duplicate(true), "command_id": command}
	migrated.godot.spatial_layout = {"id": LAYOUT_ID, "source_sha256": "fixture-source-sha256", "layout_sha256": "fixture-layout-sha256",
		"foraging_before": {"positions": before_spots.duplicate(true), "center": before_center.duplicate()},
		"foraging_after": {"positions": after_spots.duplicate(true), "center": after_center.duplicate()},
		"permission": "fixture: user reviewed the relocation", "doors": {}, "windows": {}, "migration": []}
	migrated.life.events.append(reviewed_install(command, before_spots, before_center, 1))
	migrated.life.seq = 1
	write_fixture(path, migrated)
	var town := Town.new()
	check(town.load_from(path).ok, "an exact reviewed migration still loads")
	check(town._validate_state(town.snapshot()).code == "town_state_valid", "the reviewed migration reports the expected validation code")
	check(town.berry_center() == Vector3(1.5, 0.5, 3.0), "the migrated world uses the relocated public berry center")
	check(town.destination("fixture:a", "harvest_ration") == town._vector(after_spots["fixture:a"]), "the migrated world assigns the relocated reviewed spot")
	check(town.transaction(path, func(): return town.advance(120)).ok, "the reviewed migration keeps running and saves")
	var advanced: Dictionary = town.snapshot()
	var bytes := FileAccess.get_file_as_bytes(path)
	check(town.release_writer(path).ok, "release the migration writer before cold load")
	var cold := Town.new()
	check(cold.load_from(path).ok, "cold load validates the reviewed migration and its later step")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold migration load leaves the saved bytes untouched")
	check(cold._serialize_state() == town._serialize_state(), "cold migration load preserves identity, history and balance")
	check(cold.destination("fixture:a", "harvest_ration") == town._vector(after_spots["fixture:a"]), "cold migration load keeps the relocated reviewed spot")
	check(cold.configure_foraging_work_spots(after_spots, command).get("duplicate", false), "cold migration replay keeps the relocated layout")
	var valid: Dictionary = advanced.duplicate(true)
	check(cold._validate_state(valid).code == "town_state_valid", "the saved migration state is valid before tampering")
	var corruptions := {
		"rewritten relocated spot": func(state): state.godot.spatial_layout.foraging_after.positions["fixture:a"][0] += 1.0,
		"rewritten historical spot": func(state): state.godot.spatial_layout.foraging_before.positions["fixture:a"][0] += 0.03,
		"rewritten relocated center": func(state): state.godot.spatial_layout.foraging_after.center[0] += 0.5,
		"rewritten historical center": func(state): state.godot.spatial_layout.foraging_before.center[0] += 0.5,
		"stale public center": func(state): state.godot.berry_position[0] += 0.5,
		"missing relocated record": func(state): state.godot.spatial_layout.erase("foraging_after"),
		"missing historical record": func(state): state.godot.spatial_layout.erase("foraging_before"),
		"rewritten installation evidence": func(state): state.life.events[0].positions["fixture:a"][0] += 0.5,
		"layout drifting from the record": func(state): state.godot.foraging_work_spots.positions["fixture:a"][0] += 0.5,
		"non-uniform transform": Callable(self, "_corrupt_transform"),
		"dropped reviewed spot": Callable(self, "_corrupt_drop_spot"),
		"unknown layout id": func(state): state.godot.spatial_layout.id = "unreviewed-map-v2",
	}
	for label in corruptions:
		var corrupted: Dictionary = valid.duplicate(true)
		corruptions[label].call(corrupted)
		rejects(cold, corrupted, "reviewed migration still rejects " + label)
	var incomplete: Dictionary = valid.duplicate(true)
	incomplete.godot.spatial_layout.erase("foraging_after")
	check(cold._validate_state(incomplete).code == "invalid_spatial_foraging_record", "an incomplete migration record still reports the migration failure")
	var drifted: Dictionary = valid.duplicate(true)
	_corrupt_transform(drifted)
	check(cold._validate_state(drifted).code == "invalid_spatial_foraging_transform", "the before/after transform rule still reports its own failure")
	var foreign: Dictionary = valid.duplicate(true)
	foreign.godot.spatial_layout.id = "unreviewed-map-v2"
	check(cold._validate_state(foreign).code == "unsupported_spatial_layout", "the unknown layout rule still reports its own failure")
	var out_of_ring: Dictionary = valid.duplicate(true)
	out_of_ring.godot.foraging_work_spots.positions["fixture:a"][1] += 0.6
	check(cold._validate_state(out_of_ring).code == "invalid_foraging_work_spots", "an out-of-ring reviewed spot is still rejected as an invalid position")
	var relabelled: Dictionary = valid.duplicate(true)
	relabelled.godot.spatial_layout = {"id": LAYOUT_ID, "doors": {}, "windows": {},
		"preview_genesis": true, "layout_sha256": LAYOUT_SHA256}
	# Make the installation evidence internally consistent with the current ring. Rejection must
	# come from missing new-world provenance, not merely from leaving stale migration coordinates.
	relabelled.life.events[0].positions = after_spots.duplicate(true)
	relabelled.life.events[0].berry_center = after_center.duplicate()
	check(not cold._validate_state(relabelled).ok, "a migration with rewritten evidence cannot relabel itself as a fresh genesis")
	remove_world_files(path)
