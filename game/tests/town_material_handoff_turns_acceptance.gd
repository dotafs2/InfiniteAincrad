extends "res://tests/town_capabilities_turns_acceptance.gd"
const Handoff = preload("res://core/actions/material_handoff_capability.gd")

func run() -> void:
	var stage := _new_stage("turn-material-handoff")
	var world = stage.world
	var option := Handoff.new().option_id("iron", B)
	var turns := _controller(stage, C, option)
	var outcome: Dictionary = await turns.step(C)
	check(outcome.ok and outcome.record.action == option and outcome.record.result.code == Handoff.EVENT,
		"resident controller dispatches the offered one-unit iron gift")
	var donor_view: Dictionary = turns.brains[C].received
	check(donor_view.life_account.iron == 1 and not JSON.stringify(donor_view).contains('"resident_id":"' + B + '","wood"'),
		"donor input contains own material account without recipient inventory")
	var request: String = outcome.record.request_id
	var archive: Dictionary = world._state.godot.resident_archive.entries[request]
	check(not archive.application.speech_delivery.delivered and archive.application.effect.quantity == 1
		and not archive.application.effect.has("recipient_balance"),
		"controller archives the physical effect without inventing speech or exposing recipient stock")
	check(world._trade_account(C).iron == 0 and world._trade_account(B).iron == 1,
		"controller execution moves the same conserved authoritative stock")
	turns.free()
	turns = _controller(stage, B, "wait")
	outcome = await turns.step(B)
	check(outcome.ok and turns.brains[B].received.life_account.iron == 1,
		"recipient learns its new stock only through its own later personal view")
	turns.free()
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_material_handoff_turns", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
