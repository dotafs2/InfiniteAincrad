extends SceneTree

const Kernel = preload("res://core/world_kernel.gd")

var _failures: Array[String] = []
var _evidence: Array[Dictionary] = []

func _init() -> void:
	_run_acceptance()
	var output := {"ok": _failures.is_empty(), "fixture": true, "real_paid_calls": 0, "provenance_enum_test_only": true, "evidence": _evidence}
	if not _failures.is_empty():
		output["failures"] = _failures
	print(JSON.stringify(output))
	quit(0 if _failures.is_empty() else 1)

func _run_acceptance() -> void:
	var kernel := Kernel.new()
	kernel.create_fixture()
	var initial := JSON.stringify(kernel.snapshot())

	var bad_need := kernel.submit_resident_decision({
		"action": "wait",
		"need": {"capability_id": "well_bucket", "reason": 42}
	}, "bad-need-1", "opengameagent_fixture")
	_check(not bad_need.ok and bad_need.code == "decision_need_invalid" and JSON.stringify(kernel.snapshot()) == initial, "invalid need changes neither state nor turn")

	var unknown_field := kernel.submit_resident_decision({"action": "wait", "unexpected": true}, "unknown-field-1", "opengameagent_fixture")
	_check(not unknown_field.ok and unknown_field.code == "decision_fields_invalid" and JSON.stringify(kernel.snapshot()) == initial, "unknown decision fields are rejected atomically")

	var long_reason := "x".repeat(513)
	var invalid_reason := kernel.submit_resident_decision({"action": "wait", "reason": long_reason}, "long-reason-1", "opengameagent_fixture")
	_check(not invalid_reason.ok and invalid_reason.code == "decision_reason_invalid" and JSON.stringify(kernel.snapshot()) == initial, "oversized reason is rejected atomically")

	var forged_source := kernel.submit_resident_decision({"action": "wait", "provenance": "opengameagent_live"}, "forged-source-1", "opengameagent_fixture")
	_check(not forged_source.ok and forged_source.code == "decision_fields_invalid" and JSON.stringify(kernel.snapshot()) == initial, "model cannot inject provenance through decision payload")

	var waiting := kernel.submit_resident_decision({
		"action": "wait",
		"reason": "I need a safe way to draw water.",
		"need": {"capability_id": "well_bucket", "reason": "I am thirsty and cannot safely draw from the well."}
	}, "agent-need-1", "opengameagent_fixture")
	_check(waiting.ok and waiting.provenance == "opengameagent_fixture", "trusted caller provenance is accepted and returned")
	_check(kernel.gm_review_need("agent-review-1", "approve", "well_bucket", "The fixture capability is approved.").ok, "approved need can be reviewed")
	var manifest_file := FileAccess.open("res://capabilities/well_bucket.v1.json", FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	_check(kernel.gm_install(manifest, "agent-install-1", "agent-review-1").ok, "approved capability can be installed")

	var draw := kernel.submit_resident_decision({"action": "draw_water", "reason": "I can draw one bucket."}, "agent-draw-1", "opengameagent_live")
	_check(draw.ok and draw.code == "water_drawn" and draw.provenance == "opengameagent_live", "live decision records caller provenance")
	var draw_state := kernel.snapshot()
	var draw_payload: Dictionary = JSON.parse_string(draw_state.command_payloads["agent-draw-1"])
	_check(draw_payload.provenance == "opengameagent_live" and draw_state.residents["fixture:luna"].actions[-1].provenance == "opengameagent_live", "decision provenance persists in payload and history")
	var draw_mismatch_before := JSON.stringify(kernel.snapshot())
	var draw_mismatch := kernel.submit_resident_decision({"action": "draw_water", "reason": "A different payload."}, "agent-draw-1", "opengameagent_live")
	_check(not draw_mismatch.ok and draw_mismatch.code == "command_id_payload_mismatch" and JSON.stringify(kernel.snapshot()) == draw_mismatch_before, "same command ID with a different payload is rejected")

	var empty_before := JSON.stringify(kernel.snapshot())
	var empty_draw := kernel.submit_resident_decision({"action": "draw_water"}, "agent-empty-draw-1", "opengameagent_live")
	_check(not empty_draw.ok and empty_draw.code == "well_empty" and JSON.stringify(kernel.snapshot()) == empty_before, "unavailable well does not advance turn or mutate state")

	var drink := kernel.submit_resident_decision({"action": "drink_water", "reason": "I will drink the water."}, "agent-drink-1", "opengameagent_live")
	_check(drink.ok and drink.code == "water_consumed", "resident can consume the drawn water")
	var after_drink := JSON.stringify(kernel.snapshot())
	var drink_retry := kernel.submit_resident_decision({"action": "drink_water", "reason": "I will drink the water."}, "agent-drink-1", "opengameagent_live")
	_check(drink_retry.ok and drink_retry.duplicate and drink_retry.code == drink.code and JSON.stringify(kernel.snapshot()) == after_drink, "completed drink retry returns its receipt without consuming again")

	var disable := kernel.gm_disable("agent-disable-1")
	_check(disable.ok and disable.code == "capability_disabled", "capability can be disabled")
	var disabled_before := JSON.stringify(kernel.snapshot())
	var disabled_draw := kernel.submit_resident_decision({"action": "draw_water"}, "agent-disabled-draw-1", "opengameagent_live")
	_check(not disabled_draw.ok and disabled_draw.code == "capability_unavailable" and JSON.stringify(kernel.snapshot()) == disabled_before, "disabled capability rejects draw without changing turn or state")

	_evidence.append({"test": "decision_boundary_acceptance", "turn": kernel.snapshot().turn, "receipt_count": kernel.snapshot().receipts.size(), "provenance": draw.provenance})

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
