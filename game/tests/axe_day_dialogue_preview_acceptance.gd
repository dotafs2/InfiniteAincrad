extends SceneTree

const PREVIEW := preload("res://scenes/axe_day_dialogue_preview.tscn")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview := PREVIEW.instantiate()
	root.add_child(preview)
	for _i in range(120):
		await process_frame
		if not preview._running and not preview._result.is_empty():
			break
	_check(preview.get_node_or_null("Resident_Carpenter") != null, "carpenter resident is present")
	_check(preview.get_node_or_null("Resident_Smith") != null, "smith resident is present")
	_check(preview.get_node("Resident_Carpenter").get_meta("resident_id", "") == "shared:carpenter", "carpenter uses formal ID")
	_check(preview.get_node("Resident_Smith").get_meta("resident_id", "") == "shared:smith", "smith uses formal ID")
	_check(preview.get_node("Resident_Carpenter").equipped_item("right") == "axe", "damaged axe starts with carpenter")
	_check(preview.get_node("Resident_Smith").equipped_item("left") == "hammer", "smith hammer is in the other hand")
	_check(preview._result.get("scripted", false) == true, "runner failure remains scripted fixture state")
	_check(preview._result.get("source_unchanged", false) == true, "source unchanged flag is visible")
	_check(preview._result.get("paid_calls", -1) == 0, "paid call count is zero")
	_check(preview._result.get("ok", false) == true, "available runner returns an actual successful fixture result")
	_check(preview._result.get("steps", []).size() > 0, "runner supplies replay steps")
	var saw_smith := false
	var saw_collection := false
	for step in preview._steps:
		preview._apply_step(step)
		await process_frame
		var custodian := str(step.get("custodian_id", ""))
		var edge := int(step.get("edge", -1))
		if custodian == "shared:smith":
			saw_smith = true
			_check(preview.get_node("Resident_Smith").equipped_item("right") == "axe", "smith receives axe on supplied custody step")
			_check(preview.get_node("Resident_Carpenter").equipped_item("right") == "", "old carpenter custody clears on smith step")
		if custodian == "shared:carpenter" and edge >= 100:
			saw_collection = true
			_check(preview.get_node("Resident_Carpenter").equipped_item("right") == "axe", "carpenter receives repaired axe on supplied collection step")
	_check(saw_smith and saw_collection, "success replay includes smith custody and repaired collection")
	preview._start_mode("refusal")
	for _j in range(120):
		await process_frame
		if not preview._running and not preview._result.is_empty():
			break
	_check(preview._result.get("mode", "") == "missing_iron_refusal", "refusal key uses exact runner mode")
	var refusal_steps: Array = preview._result.get("steps", [])
	if not refusal_steps.is_empty():
		var last: Dictionary = refusal_steps[-1]
		_check(last.get("phase", "") == "refusal", "refusal report ends at refusal step")
		_check(last.get("custodian_id", "") == "shared:carpenter" and int(last.get("edge", -1)) < 100, "refusal leaves damaged axe with carpenter")
		preview._apply_step(last)
		await process_frame
		_check(preview.get_node("Resident_Carpenter").equipped_item("right") == "axe", "refusal keeps carpenter axe")
		_check(preview.get_node("Resident_Smith").equipped_item("right") == "", "refusal clears smith right hand")
	preview.queue_free()
	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "paid_calls": 0, "fixture_only": true}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
