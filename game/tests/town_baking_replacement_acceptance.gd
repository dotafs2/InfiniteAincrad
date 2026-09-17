extends "res://tests/town_baking_route_acceptance.gd"
## Bounded acceptance for replacing one never-observed, never-used baking installation.

func run() -> void:
	var path := "user://fictional-town-baking-replacement-%d.json" % Time.get_ticks_usec()
	_write_baking_fixture(path)
	var town := BakingTown.new()
	check(town.load_from(path).ok, "replacement fixture loads")
	var old := {"id": "fixture:unused-oven-v1", "label": "Unused oven", "initial_flour": 4,
		"position": [4, 0, 4], "access": "public"}
	var replacement := {"id": "fixture:unused-oven-v2", "label": "Unused oven, reviewed site", "initial_flour": 4,
		"position": [4, 0, 5], "access": "public"}
	var old_command := "development_gm:unused-oven-v1"
	var replacement_command := "development_gm:unused-oven-v2"
	check(town.transaction(path, func(): return town.install_baking_route(old, 1, old_command)).ok,
		"reviewed old point installs")
	var installed := town.snapshot()
	check(not town.transaction(path, func(): return town.replace_unused_baking_route(old.id, replacement, 1, "npc:replace")).ok,
		"resident cannot replace infrastructure")
	check(town.snapshot() == installed, "rejected resident replacement changes nothing")
	var wrong_flour := replacement.duplicate(true)
	wrong_flour.initial_flour = 5
	check(town.replace_unused_baking_route(old.id, wrong_flour, 1, "development_gm:wrong-flour").get("code") == "baking_replacement_flour_changed",
		"replacement cannot add flour")
	check(town.snapshot() == installed, "wrong-flour replacement changes nothing")
	check(town.replace_unused_baking_route(old.id, replacement, 2, "development_gm:wrong-source").get("code") == "baking_replacement_source_changed",
		"replacement cannot change source need")
	check(town.snapshot() == installed, "wrong-source replacement changes nothing")
	var before_residents: Array = installed.residents.duplicate(true)
	var before_accounts: Array = installed.life.accounts.duplicate(true)
	var before_items: Array = installed.life.items.duplicate(true)
	var before_contracts: Array = installed.life.contracts.duplicate(true)
	var result: Dictionary = town.transaction(path, func(): return town.replace_unused_baking_route(
		old.id, replacement, 1, replacement_command))
	check(result.ok and result.code == "baking_route_replaced", "unused point is replaced atomically")
	var replaced := town.snapshot()
	check(not replaced.godot.baking.points.has(old.id) and replaced.godot.baking.points.has(replacement.id),
		"only the reviewed replacement remains active")
	check(replaced.godot.baking.installs.has(old_command) and replaced.godot.baking.installs.has(replacement_command),
		"both immutable install records remain")
	var old_install_event: bool = replaced.life.events.any(func(event): return event.get("type") == "baking_route_installed" and event.get("operation_id") == old_command and event.get("point_id") == old.id)
	check(old_install_event, "old install event remains unchanged")
	var superseded: Array = replaced.life.events.filter(func(event): return event.get("type") == "baking_route_superseded")
	check(superseded.size() == 1 and superseded[0].get("operation_id") == replacement_command
		and superseded[0].get("point_id") == old.id and superseded[0].get("replacement_point_id") == replacement.id,
		"one explicit supersession event links old and new points")
	check(int(replaced.godot.baking.points[replacement.id].flour_remaining) == 4
		and int(replaced.godot.baking.points[replacement.id].initial_flour) == 4,
		"replacement conserves the original four flour")
	check(replaced.residents == before_residents and replaced.life.accounts == before_accounts
		and replaced.life.items == before_items and replaced.life.contracts == before_contracts,
		"replacement changes no resident, money, item or contract")
	check(town._validate_state(replaced).ok, "replaced state validates")
	var duplicate_before := town.snapshot()
	var duplicate: Dictionary = town.transaction(path, func(): return town.replace_unused_baking_route(
		old.id, replacement, 1, replacement_command))
	check(duplicate.ok and duplicate.duplicate, "exact retry is idempotent")
	check(town.snapshot() == duplicate_before, "idempotent retry changes nothing")
	var conflict := replacement.duplicate(true)
	conflict.position = [4, 0, 6]
	check(town.replace_unused_baking_route(old.id, conflict, 1, replacement_command).get("code") == "command_conflict",
		"same command with different payload conflicts")
	var forged := installed.duplicate(true)
	forged.godot.baking.points.erase(old.id)
	check(town._validate_state(forged).get("code") == "baking_inactive_install_without_supersession",
		"inactive historical install requires supersession evidence")
	var used := {"id": "fixture:observed-oven", "label": "Observed oven", "initial_flour": 1,
		"position": [8, 0, 8], "access": "public"}
	check(town.transaction(path, func(): return town.install_baking_route(used, 1, "development_gm:observed-oven")).ok,
		"second point installs for used-point guard")
	town.host_move("fictional:forge", Vector3(8, 0, 8))
	town.require_baking_visibility(func(_id, _point_id): return true)
	elapse(town, path, 0)
	var used_replacement := {"id": "fixture:observed-oven-v2", "label": "Observed oven v2", "initial_flour": 1,
		"position": [8, 0, 9], "access": "public"}
	var used_before := town.snapshot()
	check(town.replace_unused_baking_route(used.id, used_replacement, 1, "development_gm:observed-oven-v2").get("code") == "baking_point_used",
		"personally observed point cannot be replaced")
	check(town.snapshot() == used_before, "used-point refusal changes nothing")
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := BakingTown.new()
	check(restored.load_from(path).ok, "cold restore loads replacement history")
	check(FileAccess.get_file_as_bytes(path) == saved_bytes, "cold restore does not rewrite replacement save")
	var restored_state := restored.snapshot()
	check(not restored_state.godot.baking.points.has(old.id)
		and restored_state.godot.baking.points.has(replacement.id)
		and int(restored_state.godot.baking.points[replacement.id].flour_remaining) == 4,
		"cold restore retains the active replacement and all four flour")
	var restored_old_install: bool = restored_state.life.events.any(func(event): return event.get("type") == "baking_route_installed" and event.get("operation_id") == old_command and event.get("point_id") == old.id)
	var restored_supersession: bool = restored_state.life.events.any(func(event): return event.get("type") == "baking_route_superseded" and event.get("operation_id") == replacement_command and event.get("point_id") == old.id and event.get("replacement_point_id") == replacement.id)
	check(restored_state.godot.baking.installs.has(old_command)
		and restored_state.godot.baking.installs.has(replacement_command)
		and restored_old_install and restored_supersession,
		"cold restore retains the original install fact and explicit supersession fact")
	check(restored._validate_state(restored_state).ok, "cold-restored replacement validates")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_baking_replacement", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
