extends "res://tests/town_life_acceptance.gd"

const Actions = preload("res://core/town_actions.gd")
const Turns = preload("res://agents/town_turns.gd")
const SOURCE := "res://../worlds/restart-20260918-01/checkpoints/seq000148-cdfe013685698028.world.json"
const ROWAN := "shared:carpenter"
const AXE := "seed:axe"
const REPAIR := "ability:self_repair:seed:axe:handle"

class WaitBrain extends Node:
	var turns: Node
	var actor := ""
	var calls := 0
	func propose(_view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		var alias := "not-offered"
		for key in turns._record(actor).get("offered_actions", {}):
			if turns._record(actor).offered_actions[key] == "wait":
				alias = key
		await get_tree().process_frame
		return {"ok": true, "decision": {"action": alias,
			"reason": "I choose to wait after seeing my current options."},
			"command_id": "fixture-self-repair-first-offer-wait",
			"provenance": "opengameagent_fixture"}

func _stage(label: String) -> Dictionary:
	var path := "user://self-repair-first-offer-%s-%d.json" % [label, Time.get_ticks_usec()]
	var copied := DirAccess.copy_absolute(SOURCE, path)
	check(copied == OK, label + ": immutable seq148 checkpoint copied to a disposable path")
	var world := Actions.new()
	check(world.load_from(path).ok, label + ": exact seq148-shaped world loads")
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = world
	turns.save_path = path
	var brain := WaitBrain.new()
	brain.turns = turns
	brain.actor = ROWAN
	turns.add_child(brain)
	turns.brains[ROWAN] = brain
	return {"world": world, "turns": turns, "path": path, "brain": brain}

func _close_stage(stage: Dictionary) -> void:
	stage.turns.free()
	stage.world.release_writer(stage.path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))

func _repair_options(world) -> Array:
	return world.action_options(ROWAN).filter(func(option):
		return option.get("capability_id", "") == Turns.FIRST_OFFER_WAKE_CAPABILITY)

func _restore_record(stage: Dictionary, record: Dictionary) -> void:
	stage.world._state.godot.resident_turns[ROWAN] = record.duplicate(true)

func run() -> void:
	var stage := _stage("wait-acknowledges")
	var world = stage.world
	var turns = stage.turns
	var old_record: Dictionary = turns._record(ROWAN).duplicate(true)
	check(old_record.status == "settled" and old_record.request_id == "turn:shared:carpenter:0:26",
		"fixture is Rowan's settled seq148 decision")
	check(float(old_record.next_due) > float(world._state.godot.elapsed_seconds)
		and not old_record.offered_actions.values().has(REPAIR),
		"seq148 keeps its future timer and its genuine pre-self-repair menu")
	check(_repair_options(world).any(func(option): return option.id == REPAIR),
		"Rowan now has a real eligible handle repair option")
	var before_ready: Dictionary = world.snapshot()
	check(turns.ready_resident() == ROWAN, "a settled Rowan gets one early first-offer turn")
	check(world.snapshot() == before_ready and turns._record(ROWAN).next_due == old_record.next_due,
		"checking the first offer changes neither the world nor next_due")
	var result: Dictionary = await turns.step()
	check(result.ok and result.record.action == "wait" and stage.brain.calls == 1,
		"Rowan may freely acknowledge the new menu by choosing wait")
	check(result.record.offered_actions.values().has(REPAIR),
		"the ordinary settled turn durably records the offered repair option")
	check(turns.ready_resident().is_empty(), "the acknowledged option cannot trigger a second early turn")
	check(world._trade_account(ROWAN).wood == 1 and world._item(AXE).handle == 20
		and world._state.life == before_ready.life,
		"choosing wait consumes no material, repairs nothing and invents no life event")
	world.release_writer(stage.path)
	var restored := Actions.new()
	check(restored.load_from(stage.path).ok, "the acknowledged menu cold-restores")
	stage.world = restored
	turns.town = restored
	check(turns.ready_resident().is_empty(), "cold restore preserves the one-time acknowledgement")
	_close_stage(stage)

	stage = _stage("invalid-old-menu")
	world = stage.world
	turns = stage.turns
	old_record = turns._record(ROWAN).duplicate(true)
	var invalid_menus: Array = [null, {}, [], {"a0": 7}, {7: "wait"}, {"a0": ""}]
	for invalid in invalid_menus:
		_restore_record(stage, old_record)
		if invalid == null:
			world._state.godot.resident_turns[ROWAN].erase("offered_actions")
		else:
			world._state.godot.resident_turns[ROWAN].offered_actions = invalid
		check(turns.ready_resident().is_empty(),
			"missing or malformed old menu fails closed: " + str(invalid))
	_close_stage(stage)

	stage = _stage("gates")
	world = stage.world
	turns = stage.turns
	old_record = turns._record(ROWAN).duplicate(true)
	_restore_record(stage, old_record)
	world._state.godot.resident_turns[ROWAN].status = "pending"
	check(turns.ready_resident().is_empty(), "a pending decision keeps its review gate")
	_restore_record(stage, old_record)
	world._state.godot.resident_turns[ROWAN].status = "rule_rejection"
	world._state.godot.resident_turns[ROWAN].result = {"code": "option_unavailable"}
	world._state.godot.resident_turns[ROWAN].replan_policy = "stale_option_v1"
	world._state.godot.resident_turns[ROWAN].replan_not_before = float(world._state.godot.elapsed_seconds) + 10.0
	check(turns.ready_resident().is_empty(), "a cooling stale-option rejection remains gated")
	_restore_record(stage, old_record)
	turns.close_admission("fixture_boundary")
	check(turns.ready_resident().is_empty(), "closed admission remains closed")
	_close_stage(stage)

	stage = _stage("busy")
	world = stage.world
	turns = stage.turns
	check(world.transaction(stage.path, func():
		return world.execute_action(ROWAN, REPAIR, "fixture:first-offer-busy", "opengameagent_fixture")).ok,
		"fixture starts the actually eligible repair job")
	check(not world.pending_job(ROWAN).is_empty() and turns.ready_resident().is_empty(),
		"an existing physical job keeps the resident unschedulable")
	_close_stage(stage)

	for condition in ["material", "skill", "damage"]:
		stage = _stage("no-" + condition)
		world = stage.world
		turns = stage.turns
		match condition:
			"material":
				world._trade_account(ROWAN).wood = 0
			"skill":
				world._state.life.skills = world._state.life.skills.filter(func(entry):
					return not (entry.get("resident_id") == ROWAN and entry.get("skill_id") == "wood_repair"))
			"damage":
				world._item(AXE).handle = 100
		check(_repair_options(world).is_empty(), condition + " prerequisite removes the current repair option")
		check(turns.ready_resident().is_empty(), condition + " absence cannot cause an early wake")
		_close_stage(stage)

	print(JSON.stringify({"suite": "town_self_repair_first_offer_wake", "checks": checks,
		"failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
