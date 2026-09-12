extends SceneTree
## No provider/config/world writes: a bounded capture must not prepare turn N+1.
const Street = preload("res://spatial/town_street.gd")
var checks := 0
var failures := 0

class Counter extends Node:
	var calls := 0
	var busy := false
	func step(_id: String) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return {"ok": true}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var street := Street.new()
	var turns := Counter.new()
	root.add_child(turns)
	street.model_turns = turns
	street.gateway_mode = true
	street.capture_dir = "fixture-only-no-write"
	street.validation_decision_limit = 1
	await street._run_model_turn("fixture:counter")
	check(turns.calls == 1 and street.validation_decisions_started == 1, "first decision runs once")
	await street._run_model_turn("fixture:counter")
	check(turns.calls == 1 and street.validation_decisions_started == 1, "cap prevents preparing next resident request")
	street.capture_dir = ""
	check(not street._validation_limit_reached(), "ordinary gameplay has no capture-only limit")
	street.capture_dir = "fixture-only-no-write"
	street.validation_decision_limit = -1
	check(not street._validation_limit_reached(), "default scene remains unlimited by validation cap")
	street.validation_decision_limit = 0
	check(street._validation_limit_reached(), "explicit zero means no validation decisions")
	check(not street._decision_limit_capture_ready(), "existing default does not enable cap-only capture")
	street.stop_on_decision_limit = true
	turns.busy = true
	check(not street._decision_limit_capture_ready(), "cap capture waits for the in-flight model result")
	turns.busy = false
	check(street._decision_limit_capture_ready(), "cap capture may pause once model result handling is finished")
	street.capture_started = true
	check(not street._decision_limit_capture_ready(), "cap capture is scheduled only once")
	street.capture_started = false
	street.validation_decisions_started = 0
	street.validation_decision_limit = 1
	check(not street._decision_limit_capture_ready(), "legitimate idle time does not trigger cap-only capture")
	street.restore_only = true
	street.validation_decisions_started = 1
	check(not street._decision_limit_capture_ready(), "cold restore never starts a cap-only continuation")
	street.free()
	turns.free()
	print(JSON.stringify({"suite": "town_validation_limit", "checks": checks, "failures": failures, "real_paid_calls": 0}))
	quit(0 if failures == 0 else 1)
