extends "res://tests/town_trade_acceptance.gd"
const Turns = preload("res://agents/town_turns.gd")

class ChoiceBrain extends Node:
	var turns
	var action := "wait"
	var calls := 0
	var before_reply: Callable
	var view: Dictionary
	func propose(observation: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		view = observation.duplicate(true)
		var aliases: Dictionary = turns._record(observation.identity.id).offered_actions
		var selected := "not-offered"
		for alias in aliases:
			if aliases[alias] == action:
				selected = alias
		if before_reply.is_valid():
			var hook := before_reply
			before_reply = Callable()
			hook.call()
		return {"ok": true, "command_id": "test-provider", "provenance": "opengameagent_fixture", "decision": {"action": selected, "reason": "explicit offline choice"}}

func run() -> void:
	var path := "user://social-trigger-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town := _load_trade(path)
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	turns.max_parallel = 1
	var owner := "fictional:ember"
	var wood := "fictional:birch"
	var first := ChoiceBrain.new()
	var second := ChoiceBrain.new()
	first.turns = turns; second.turns = turns
	check(turns.connect_controller(owner, first, "fixture:owner").ok, "owner controller attaches")
	check(turns.connect_controller(wood, second, "fixture:wood").ok, "recipient controller attaches")
	first.action = "ask-repair:" + wood + ":fictional:axe-edge:edge"
	check((await turns.step(owner)).ok, "specific request sent")
	check(turns.ready_resident() == wood, "own speech does not reschedule sender before recipient")
	check(not town.trade_options(owner).any(func(o): return o.id == first.action), "same unanswered specific request no longer offered")
	var command: String = turns._record(owner).request_id
	var decision: Dictionary = town._state.godot.commands[command].payload.decision
	var before: Dictionary = town.snapshot()
	check(town.communicate(owner, decision, command, "opengameagent_fixture").duplicate, "same command retains idempotent receipt")
	check(town.communicate(owner, decision, "another-request", "opengameagent_fixture").code == "help_request_pending", "new command cannot duplicate unanswered same need")
	check(town.snapshot() == before, "duplicate questions change no state")
	second.action = "reply:godot_help:" + command + ":unavailable"
	check((await turns.step(wood)).ok, "recipient can voluntarily refuse")
	check(turns.ready_resident() == owner, "other person's reply wakes sender")
	first.action = "wait"
	check((await turns.step(owner)).ok, "sender can decide after refusal")
	check(turns.ready_resident().is_empty(), "wait and own reply create no thought echo")
	check(town.trade_options(owner).any(func(o): return o.id == "ask-repair:" + wood + ":fictional:axe-edge:edge"), "resolved request is not a permanent ban")
	first.before_reply = func():
		var result: Dictionary = town.transaction(path, func(): return town.communicate(wood, {"action": "ask_help", "recipient_id": owner, "text": "New message while you were thinking"}, "concurrent-message", "opengameagent_fixture"))
		check(result.ok, "new incoming event arrives after view was frozen")
	check((await turns.step(owner)).ok, "old-view decision can settle")
	check(turns._record(owner).next_due == town._state.godot.elapsed_seconds, "incoming event during thinking is not swallowed by result acknowledgement")
	check((await turns.step(owner)).ok, "another observation can process the concurrent message")
	check(first.view.experiences.any(func(e): return e.get("operation_id") == "concurrent-message"), "next personal view contains concurrent message")
	town.release_writer(path)
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_social_trigger", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
