extends SceneTree
## Scripted boundary fixture for the disposable adventure adapter. It exercises
## command authority and stale-route rejection; it is not a physics or adoption claim.

const ResidentTown = preload("res://core/adventure_resident_town.gd")
const TownActions = preload("res://core/town_actions.gd")
const Adventure = preload("res://core/adventure_state.gd")
const Bridge = preload("res://core/adventure_live_bridge.gd")

class FailingSaveTown:
	extends ResidentTown
	var fail_next_save := false

	func save_to(path: String) -> Dictionary:
		if fail_next_save:
			fail_next_save = false
			return {"ok": false, "code": "fixture_save_failed"}
		return super.save_to(path)

var checks := 0
var failures := 0

func _arg(prefix: String) -> String:
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with(prefix):
			return raw.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _receipt(resident_id: String) -> Dictionary:
	return {
		"ok": true,
		"route_kind": "collision_aware_town_route",
		"route_id": "scripted-boundary-gate-route",
		"resident_id": resident_id,
		"target": "wilderness_gate",
		"target_position": [0.0, 0.10, 53.0],
		"frames": 1005,
		"metres": 22.5680503845215,
		"fixture_origin": "scripted_boundary_fixture"
	}

func _offer_count(town, resident_id: String) -> int:
	var count := 0
	for option in town.action_options(resident_id):
		if option.get("id", "") == ResidentTown.ADVENTURE_OPTION:
			count += 1
	return count

func _fresh_path(source: String, suffix: String) -> String:
	var path := source + "." + suffix
	var copied := DirAccess.copy_absolute(source, path)
	check(copied == OK, "fixture creates isolated copy for " + suffix)
	return path

func _attach_at_gate(town, bridge, path: String, resident_id: String) -> void:
	check(town.load_from(path).get("ok", false), "isolated fixture town loads")
	check(town.attach_adventure(bridge).get("ok", false), "isolated fixture bridge attaches")
	town.host_move(resident_id, ResidentTown.GATE_TARGET)
	var marked: Dictionary = town.mark_physical_arrival(path, resident_id, _receipt(resident_id))
	check(marked.get("ok", false), "isolated fixture records its scripted gate setup")

func run() -> void:
	var town_path := _arg("--town-save=")
	check(not town_path.is_empty(), "boundary acceptance receives an explicit disposable town save path")
	if town_path.is_empty():
		quit(1)
		return

	var seed := TownActions.new()
	var seed_loaded: Dictionary = seed.load_from(town_path)
	check(seed_loaded.get("ok", false), "fixture town source loads")
	if not seed_loaded.get("ok", false):
		quit(1)
		return
	var rollback_seed := _fresh_path(town_path, "rollback-seed")
	var snapshot_probe := Adventure.new()
	var probe_state: Dictionary = snapshot_probe.create_from_town_snapshot(seed.snapshot())
	var integral_floor: Dictionary = probe_state.duplicate(true)
	integral_floor.floor = 1.0
	check(snapshot_probe.load_snapshot(integral_floor).get("ok", false),
		"snapshot loader accepts an integral JSON numeric floor")
	var fractional_floor: Dictionary = probe_state.duplicate(true)
	fractional_floor.floor = 1.5
	var probe_before: Dictionary = snapshot_probe.snapshot()
	check(not snapshot_probe.load_snapshot(fractional_floor).get("ok", false)
		and snapshot_probe.snapshot() == probe_before, "snapshot loader rejects fractional floor without replacing state")
	check(not snapshot_probe.load_snapshot("not-a-dictionary").get("ok", false),
		"snapshot loader cleanly rejects malformed non-object JSON")
	var bridge := Bridge.new()
	bridge.adventure = Adventure.new()
	bridge.adventure.create_from_town_snapshot(seed.snapshot())
	var town := ResidentTown.new()
	check(town.load_from(town_path).get("ok", false), "adapter loads and validates the town copy")
	check(town.attach_adventure(bridge).get("ok", false), "adapter attaches the sidecar")
	var actor := "shared:baker"
	var receipt := _receipt(actor)

	var wrong_actor := receipt.duplicate(true)
	wrong_actor.resident_id = "shared:carpenter"
	check(town.mark_physical_arrival(town_path, actor, wrong_actor).get("code") == "physical_route_actor_mismatch",
		"route receipt for another actor is rejected")
	var wrong_gate := receipt.duplicate(true)
	wrong_gate.target = "town_square"
	check(town.mark_physical_arrival(town_path, actor, wrong_gate).get("code") == "physical_route_target_mismatch",
		"route receipt for another named target is rejected")
	var wrong_target := receipt.duplicate(true)
	wrong_target.target_position = [20.0, 0.10, 53.0]
	check(town.mark_physical_arrival(town_path, actor, wrong_target).get("code") == "physical_route_target_untrusted",
		"route receipt for a different gate position is rejected")

	# This is explicit test setup, not a reported physics route. The persisted body
	# position is placed at the configured target so the receipt checks real state.
	town.host_move(actor, ResidentTown.GATE_TARGET)
	var marked: Dictionary = town.mark_physical_arrival(town_path, actor, receipt)
	check(marked.get("ok", false), "scripted boundary fixture records a matching gate position")
	check(town.position_of(actor).distance_to(ResidentTown.GATE_TARGET) <= ResidentTown.GATE_ARRIVAL_RADIUS,
		"arrival transaction preserves the current host body position")
	check(_offer_count(town, actor) == 1, "matching route and position expose one optional choice")

	town.host_move(actor, Vector3(2.0, 0.10, 53.0))
	check(_offer_count(town, actor) == 0, "moving away invalidates a stale arrival option")
	var stale: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		"fixture:stale-route", "opengameagent_fixture", "")
	check(not stale.get("ok", false) and stale.get("code") == "physical_arrival_required",
		"direct execution rejects a stale route even when the option is bypassed")

	town.host_move(actor, ResidentTown.GATE_TARGET)
	marked = town.mark_physical_arrival(town_path, actor, receipt)
	check(marked.get("ok", false), "resident can receive a fresh route receipt after returning to the gate")

	var invalid_actor: Dictionary = town.execute_action("shared:missing", ResidentTown.ADVENTURE_OPTION,
		"fixture:invalid-actor", "opengameagent_fixture", "")
	check(not invalid_actor.get("ok", false) and invalid_actor.get("code") == "invalid_actor_command_or_provenance",
		"direct execution validates actor identity")
	var invalid_command: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		"", "opengameagent_fixture", "")
	check(not invalid_command.get("ok", false) and invalid_command.get("code") == "invalid_actor_command_or_provenance",
		"direct execution validates command identifiers")
	var invalid_provenance: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		"fixture:invalid-provenance", "untrusted_source", "")
	check(not invalid_provenance.get("ok", false) and invalid_provenance.get("code") == "invalid_actor_command_or_provenance",
		"direct execution validates provenance")

	# A real host pending job is created through TownLife's ordinary action path.
	town.account(actor).energy = 50.0
	var pending := town.start_action(actor, "rest", "fixture:legacy-collision", "local_rule_policy")
	check(pending.get("ok", false), "fixture creates a pending job through the host action API")
	var collision: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		"fixture:legacy-collision", "opengameagent_fixture", "")
	check(not collision.get("ok", false) and collision.get("code") == "command_conflict",
		"adventure command cannot reuse a legacy job command")
	var pending_attempt: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		"fixture:pending-entry", "opengameagent_fixture", "")
	check(not pending_attempt.get("ok", false) and pending_attempt.get("code") == "resident_has_pending_job",
		"direct execution rechecks an active host job")
	town._state.godot.pending.erase(actor)
	town._state.godot.commands.erase("fixture:legacy-collision")

	var event_count_before: int = town._state.life.events.size()
	var sidecar_receipt_count_before: int = bridge.adventure.snapshot().receipts.size()
	var command := "fixture:adventure-boundary-entry"
	var result: Dictionary = town.transaction(town_path, func():
		return town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
			command, "opengameagent_fixture", ""))
	check(result.get("ok", false) and result.get("code") == "entered_wilderness",
		"valid optional action reaches the reducer once")
	check(_offer_count(town, actor) == 0, "completed entry removes the optional choice")
	check(town.adventure_resident_adopted(), "adoption reflects a recorded completed action")
	var event_count_after: int = town._state.life.events.size()
	var sidecar_receipt_count_after: int = bridge.adventure.snapshot().receipts.size()
	check(event_count_after == event_count_before + 1, "successful execution appends exactly one town event")
	check(sidecar_receipt_count_after == sidecar_receipt_count_before + 1,
		"successful execution adds exactly one sidecar receipt")
	var duplicate: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		command, "opengameagent_fixture", "")
	check(duplicate.get("ok", false) and duplicate.get("duplicate", false),
		"same command and payload returns the common-store duplicate")
	check(town._state.life.events.size() == event_count_after and bridge.adventure.snapshot().receipts.size() == sidecar_receipt_count_after,
		"retry adds no second town event or sidecar receipt")
	var conflicting_retry: Dictionary = town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
		command, "local_rule_policy", "")
	check(not conflicting_retry.get("ok", false) and conflicting_retry.get("code") == "command_conflict",
		"same command with changed provenance is rejected")
	check(town._state.life.events.size() == event_count_after,
		"conflicting retry does not append an event")
	check(town.release_writer(town_path).get("ok", false), "fixture releases its owned writer lock")
	var cold := ResidentTown.new()
	check(cold.load_from(town_path).get("ok", false), "common adventure receipt cold-restores through TownActions validation")
	check(cold.action_receipt(command).get("capability_id", "") == ResidentTown.ADVENTURE_CAPABILITY,
		"cold restore retains the dedupe receipt")
	check(cold.adventure_resident_adopted(), "cold restore retains the actual adoption record")
	check(cold.snapshot().godot.get("adventure_state", {}).get("residents", {}).get(actor, {}).get("zone") == "wilderness",
		"town save contains the committed adventure zone without a manifest")
	var stale_bridge := Bridge.new()
	stale_bridge.adventure = Adventure.new()
	stale_bridge.adventure.create_from_town_snapshot(cold.snapshot())
	var stale_town := ResidentTown.new()
	check(stale_town.load_from(town_path).get("ok", false), "stale-manifest fixture town loads")
	check(stale_town.attach_adventure(stale_bridge).get("ok", false), "embedded town snapshot overrides stale bridge state")
	check(stale_bridge.adventure.snapshot().residents[actor].zone == "wilderness",
		"cold attach restores committed zone even when optional manifest state is stale")

	# Failed operation: the reducer changes first, then the host rejects the operation.
	var op_path := _fresh_path(rollback_seed, "operation-rollback")
	var op_town := ResidentTown.new()
	var op_bridge := Bridge.new()
	_attach_at_gate(op_town, op_bridge, op_path, actor)
	var op_before: Dictionary = op_bridge.adventure.snapshot()
	var op_event_count: int = op_town.snapshot().life.events.size()
	var op_command := "fixture:operation-rollback"
	var op_failed: Dictionary = op_town.transaction(op_path, func():
		var applied: Dictionary = op_town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
			op_command, "opengameagent_fixture", "")
		if not applied.get("ok", false): return applied
		return {"ok": false, "code": "fixture_operation_failed"})
	check(not op_failed.get("ok", false), "explicit operation failure rejects the transaction")
	check(op_bridge.adventure.snapshot() == op_before, "failed operation restores the adventure reducer snapshot")
	check(op_town.snapshot().life.events.size() == op_event_count
		and op_town.action_receipt(op_command).is_empty(), "failed operation leaves no host event or dedupe receipt")
	check(op_town.release_writer(op_path).get("ok", false), "operation fixture releases rollback lock")
	var op_disk_cold := ResidentTown.new()
	check(op_disk_cold.load_from(op_path).get("ok", false)
		and op_disk_cold.action_receipt(op_command).is_empty(), "failed operation left no persisted host receipt")
	var op_disk_bridge := Bridge.new()
	check(op_disk_cold.attach_adventure(op_disk_bridge).get("ok", false)
		and op_disk_bridge.adventure.snapshot().residents[actor].zone == "town",
		"failed operation left no persisted adventure-zone change")
	var op_retry: Dictionary = op_town.transaction(op_path, func():
		return op_town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
			op_command, "opengameagent_fixture", ""))
	check(op_retry.get("ok", false) and op_bridge.adventure.snapshot().residents[actor].zone == "wilderness",
		"same operation retries successfully after full rollback")
	check(op_bridge.adventure.snapshot().receipts.size() == op_before.receipts.size() + 1,
		"operation retry commits exactly one sidecar receipt")
	check(op_town.release_writer(op_path).get("ok", false), "operation retry releases writer lock")

	# Failed save: state embeds into the host snapshot before save_to rejects it.
	var save_path := _fresh_path(rollback_seed, "save-rollback")
	var save_town := FailingSaveTown.new()
	var save_bridge := Bridge.new()
	_attach_at_gate(save_town, save_bridge, save_path, actor)
	var save_before: Dictionary = save_bridge.adventure.snapshot()
	var save_event_count: int = save_town.snapshot().life.events.size()
	var save_command := "fixture:save-rollback"
	save_town.fail_next_save = true
	var save_failed: Dictionary = save_town.transaction(save_path, func():
		return save_town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
			save_command, "opengameagent_fixture", ""))
	check(not save_failed.get("ok", false) and save_failed.get("code") == "fixture_save_failed",
		"injected host save failure rejects transaction")
	check(save_bridge.adventure.snapshot() == save_before, "save failure restores adventure reducer snapshot")
	check(save_town.snapshot().life.events.size() == save_event_count
		and save_town.action_receipt(save_command).is_empty(), "save failure leaves no host event or dedupe receipt")
	check(save_town.release_writer(save_path).get("ok", false), "save failure releases its writer lock")
	var save_disk_cold := ResidentTown.new()
	check(save_disk_cold.load_from(save_path).get("ok", false)
		and save_disk_cold.action_receipt(save_command).is_empty(), "failed save left no persisted host receipt")
	var save_disk_bridge := Bridge.new()
	check(save_disk_cold.attach_adventure(save_disk_bridge).get("ok", false)
		and save_disk_bridge.adventure.snapshot().residents[actor].zone == "town",
		"failed save left no persisted adventure-zone change")
	var save_retry: Dictionary = save_town.transaction(save_path, func():
		return save_town.execute_action(actor, ResidentTown.ADVENTURE_OPTION,
			save_command, "opengameagent_fixture", ""))
	check(save_retry.get("ok", false), "same command retries successfully after save failure")
	check(save_town.snapshot().godot.get("adventure_state", {}).get("residents", {}).get(actor, {}).get("zone") == "wilderness",
		"successful retry atomically persists the adventure state in town save")
	check(save_town.release_writer(save_path).get("ok", false), "save retry releases its writer lock")
	var save_cold := ResidentTown.new()
	var save_cold_bridge := Bridge.new()
	check(save_cold.load_from(save_path).get("ok", false), "save retry cold loads host snapshot")
	check(save_cold.attach_adventure(save_cold_bridge).get("ok", false), "missing manifest does not block cold hydration")
	check(save_cold_bridge.adventure.snapshot().residents[actor].zone == "wilderness",
		"host snapshot alone restores committed adventure zone")

	print(JSON.stringify({"suite": "adventure_resident_boundary_acceptance", "checks": checks,
		"failures": failures, "fixture_origin": "scripted_boundary_fixture",
		"resident_id": actor, "canonical_mutation_allowed": false,
		"physics_claim": false, "sidecar_atomic_with_town_save": true}))
	quit(0 if failures == 0 else 1)
