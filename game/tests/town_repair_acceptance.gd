extends "res://tests/town_life_acceptance.gd"

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--write-fixture="):
			var output := arg.trim_prefix("--write-fixture=")
			var visual := fixture()
			visual.godot.homes = {
				"fixture:a": [0, 0.22, 7], "fixture:b": [4, 0.22, 7], "fixture:c": [-3, 0.22, 2]}
			visual.godot.positions = visual.godot.homes.duplicate(true)
			visual.godot.berry_position = [4, 0.22, 1]
			var fixture_file := FileAccess.open(output, FileAccess.WRITE)
			if fixture_file == null:
				push_error("cannot write visual repair fixture")
				quit(1)
				return
			fixture_file.store_string(JSON.stringify(visual, "", true, true))
			fixture_file.close()
			print(JSON.stringify({"suite": "town_repair_fixture_writer", "path": output, "paid_calls": 0}))
			quit(0)
			return
	var path := "user://town-repair-%d.json" % Time.get_ticks_usec()
	var data := fixture()
	data.godot.homes["fixture:a"] = [0, 0, 0]
	data.godot.homes["fixture:b"] = [4, 0, 0]
	data.godot.homes["fixture:c"] = [-4, 0, 0]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", true, true))
	file.close()
	var town := Town.new()
	check(town.load_from(path).ok, "repair fixture loads")
	check(town.resident_view("fixture:a").work.items.size() == 1, "owner sees own damaged axe")
	check(town.resident_view("fixture:b").work.items.is_empty(), "worker cannot see owner's private item before contract")
	check(town.resident_view("fixture:c").experiences.is_empty(), "nonparticipant starts without repair knowledge")
	var candidate := town.repair_candidate("edge")
	check(candidate == {"owner_id": "fixture:a", "worker_id": "fixture:b", "item_id": "fixture:axe", "part": "edge", "price_col": 2}, "damaged edge and registered skill produce one candidate")
	var untouched := town.snapshot()
	check(not town.propose_repair("fixture:a", "fixture:axe", "fixture:b", "edge", 3, "bad-price").ok and town.snapshot() == untouched, "unsupported price is rejected atomically")
	var proposed := town.transaction(path, func(): return town.propose_repair("fixture:a", "fixture:axe", "fixture:b", "edge", 2, "edge-propose"))
	check(proposed.ok and proposed.contract_id == "godot_repair:edge-propose", "owner proposes an edge repair")
	var after_proposal := town.snapshot()
	check(town.propose_repair("fixture:a", "fixture:axe", "fixture:b", "edge", 2, "edge-propose").duplicate and town.snapshot() == after_proposal, "proposal retry creates no contract or event")
	check(not town.propose_repair("fixture:a", "fixture:axe", "fixture:b", "edge", 5, "edge-propose").ok, "same command cannot change price")
	check(town.resident_view("fixture:b").work.contracts.size() == 1, "worker receives only the attributed contract")
	var before_remote_accept := town.snapshot()
	check(town.respond_repair("fixture:b", proposed.contract_id, "accept", "edge-accept").code == "worker_not_at_station" and town.snapshot() == before_remote_accept, "acceptance requires worker at the registered station")
	town.host_move("fixture:b", Vector3(4, 0, 0))
	var initial_money := _money_total(town)
	var accepted := town.transaction(path, func(): return town.respond_repair("fixture:b", proposed.contract_id, "accept", "edge-accept"))
	check(accepted.ok, "skilled worker with iron accepts")
	check(town.resident("fixture:a").coins_col == 8 and town.work_account("fixture:a").reserved_col == 2, "acceptance reserves exactly two Col")
	check(_money_total(town) == initial_money, "reservation conserves money")
	var before_remote_delivery := town.snapshot()
	check(town.deliver_repair("fixture:a", proposed.contract_id, "edge-deliver").code == "repair_delivery_out_of_range" and town.snapshot() == before_remote_delivery, "delivery cannot teleport the axe")
	town.host_move("fixture:a", Vector3(4, 0, 0))
	check(town.transaction(path, func(): return town.deliver_repair("fixture:a", proposed.contract_id, "edge-deliver")).ok, "co-located owner delivers the axe")
	check(_item(town, "fixture:axe").custodian_id == "fixture:b", "delivery transfers custody, not ownership")
	check(town.transaction(path, func(): return town.start_repair_work("fixture:b", proposed.contract_id, "edge-work")).ok, "worker starts timed repair")
	check(town.transaction(path, func(): return town.advance(30)).ok and _item(town, "fixture:axe").edge == 20, "half duration changes no tool condition or material")
	var mid_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := Town.new()
	check(restored.load_from(path).ok, "pending repair cold-loads")
	check(FileAccess.get_file_as_bytes(path) == mid_bytes and restored.pending_job("fixture:b").elapsed == 30, "cold load neither advances nor rewrites timed work")
	var completed := restored.transaction(path, func(): return restored.advance(30))
	check(completed.ok and completed.completed.size() == 1 and completed.completed[0].code == "repair_completed", "second half completes exactly one repair")
	check(_item(restored, "fixture:axe").edge == 100 and restored.work_account("fixture:b").iron == 0, "repair consumes one iron and restores edge to 100")
	check(restored.active_repair_for("fixture:a").status == "completed", "completed work remains open until collection")
	var collected := restored.transaction(path, func(): return restored.collect_repair("fixture:a", proposed.contract_id, "edge-collect"))
	check(collected.ok and _item(restored, "fixture:axe").custodian_id == "fixture:a", "owner collects repaired axe")
	check(restored.resident("fixture:b").coins_col == 12 and restored.work_account("fixture:a").reserved_col == 0 and _money_total(restored) == initial_money, "collection pays worker once and conserves Col")
	var final_state := restored.snapshot()
	check(restored.collect_repair("fixture:a", proposed.contract_id, "edge-collect").get("duplicate", false) and restored.snapshot() == final_state, "collection retry cannot pay twice")
	check(restored.resident_view("fixture:c").experiences.is_empty(), "nonparticipant learns no private repair history")
	var final_bytes := FileAccess.get_file_as_bytes(path)
	var cold := Town.new()
	check(cold.load_from(path).ok and FileAccess.get_file_as_bytes(path) == final_bytes, "collected repair cold-restores without rewriting")
	check(cold.repair_contracts()[0].status == "collected" and cold.repair_contracts()[0].reserved_col == 0, "terminal contract and settlement persist")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_repair", "checks": checks, "failures": failures,
		"paid_calls": 0, "provenance": "local_rule_policy_fixture"}))
	quit(0 if failures == 0 else 1)

func _item(town: RefCounted, item_id: String) -> Dictionary:
	for value in town.snapshot().life.items:
		if value.id == item_id:
			return value
	return {}

func _money_total(town: RefCounted) -> int:
	var total := 0
	for person in town.snapshot().residents:
		total += int(person.coins_col)
	for value in town.snapshot().life.accounts:
		total += int(value.reserved_col)
	return total
