extends SceneTree

class Actor extends Node3D:
	func set_walking(_value: bool) -> void: pass
	func set_gesture(_value: String) -> void: pass

class Probe extends "res://spatial/street_trial.gd":
	func _ready() -> void: pass
	func _spawn_hanging_bucket() -> void: pass

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var p := Probe.new()
	p._resident = Actor.new()
	p.add_child(p._resident)
	root.add_child(p)
	var k: RefCounted = p._kernel
	k.create_fixture()
	k.submit_resident_decision({"action":"wait", "need":{"capability_id":"well_bucket", "reason":"Need water"}}, "need")
	k.gm_review_need("review", "approve", "well_bucket", "fixture")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://capabilities/well_bucket.v1.json"))
	k.gm_install(manifest, "install", "review")
	var checks := {"unanswered_install_is_not_wait": not p._is_installed_wait_state()}
	k.submit_resident_decision({"action":"wait", "reason":"Later"}, "defer", "opengameagent_live")
	checks["wait_independent_of_model_source"] = p._is_installed_wait_state()
	checks["receipt_from_saved_facts"] = p._last_wait_receipt() == k.snapshot().receipts.defer
	p._reconcile_loaded_world()
	checks["installed_wait_resumes_idle"] = p._waiting_after_decision
	k.submit_resident_decision({"action":"draw_water"}, "draw")
	k.submit_resident_decision({"action":"wait", "reason":"Rest first"}, "rest")
	p._waiting_after_decision = false
	p._reconcile_loaded_world()
	checks["carried_water_wait_resumes_idle"] = p._waiting_after_decision and p._resident.position == p.RESIDENT_SIDE
	k.create_fixture()
	k.submit_resident_decision({"action":"wait", "reason":"Looking around"}, "observe")
	p._waiting_after_decision = false
	p._reconcile_loaded_world()
	checks["wait_without_need_resumes_idle"] = p._waiting_after_decision and p._resident.position == p.WELL_APPROACH
	p.free()
	print(JSON.stringify({"suite":"street_resume_edges", "fixture":true, "paid_calls":0, "checks":checks}))
	quit(0 if not checks.values().has(false) else 1)
