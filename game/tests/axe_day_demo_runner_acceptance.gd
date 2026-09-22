extends SceneTree
const Runner = preload("res://demo/axe_day_demo_runner.gd")
class FailingRunner extends Runner:
	var calls := 0
	func _arrive(_town: RefCounted, _path: String, _id: String, _seconds: float) -> Dictionary:
		calls += 1
		return {"ok":false, "code":"fixture_injected_failure"}
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var runner := Runner.new()
	var success: Dictionary = await runner.run(root, "success")
	check(success.ok and success.scripted and success.source_unchanged and success.paid_calls == 0, "success demo is disposable scripted evidence")
	check(success.steps.any(func(s): return s.phase=="delivery" and s.custodian_id=="shared:smith") and success.steps.any(func(s): return s.phase=="collection" and s.custodian_id=="shared:carpenter"), "custody moves owner to smith and back")
	check(success.steps.any(func(s): return s.phase=="work_interrupted" and s.edge==20 and s.iron==1) and success.steps.any(func(s): return s.phase=="work_completed" and s.edge==100 and s.iron==0 and s.resumed), "cold reload interrupts work before actual repaired receipt")
	check(success.steps.any(func(s): return s.phase=="collection" and s.smith_col==12 and s.owner_col==8 and s.reserved_col==0), "collection settles once and conserves twenty Col")
	var refusal: Dictionary = await runner.run(root, "missing_iron_refusal")
	check(refusal.ok and refusal.steps.any(func(s): return s.phase=="refusal" and s.result_code=="option_unavailable") and refusal.steps[-1].edge==20 and not refusal.steps.any(func(s): return s.phase in ["delivery","work_completed","collection"]), "missing iron ends lawfully without success phases")
	var invalid: Dictionary = await runner.run(root, "unknown")
	check(not invalid.ok and invalid.failures == ["invalid_mode"] and invalid.steps.is_empty(), "invalid mode reports a bounded failure")
	var failing := FailingRunner.new()
	var injected: Dictionary = await failing.run(root, "success")
	check(not injected.ok and injected.failures.has("delivery_failed") and injected.source_unchanged and not injected.steps.any(func(s): return s.phase in ["work_completed","collection"]), "injected arrival failure aborts and cleans up before later success phases")
	print(JSON.stringify({"suite":"axe_day_demo_runner","checks":checks,"failures":failures,"paid_calls":0}))
	quit(0 if failures.is_empty() else 1)
