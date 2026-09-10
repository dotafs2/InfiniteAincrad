extends SceneTree

const Kernel = preload("res://core/world_kernel.gd")

var _failures: Array[String] = []
var _evidence: Array[Dictionary] = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := "full"
	var save_path := ""
	for arg in args:
		if str(arg).begins_with("--phase="):
			phase = str(arg).substr(8)
		elif str(arg).begins_with("--save-path="):
			save_path = str(arg).substr(12)
	if phase == "cold-write":
		_run_cold_write(save_path)
	elif phase == "cold-read":
		_run_cold_read(save_path)
	else:
		_run_full(save_path)
	var output := {"ok": _failures.is_empty(), "phase": phase, "evidence": _evidence}
	if not _failures.is_empty():
		output["failures"] = _failures
	print(JSON.stringify(output))
	quit(0 if _failures.is_empty() else 1)

func _run_full(requested_save_path: String) -> void:
	var kernel := Kernel.new()
	_check(kernel.create_fixture().ok, "fixture can be created")
	var initial := kernel.snapshot()
	var view := kernel.resident_view()
	_check(view.keys().size() == 8, "resident view has only eight permitted resident sections")
	for forbidden in ["world", "plugins", "receipts", "command_payloads", "gm_budget"]:
		_check(not view.has(forbidden), "resident view excludes " + forbidden)
	_check(view.identity.id == "fixture:luna", "fixture identity is Luna")
	var waiting := kernel.resident_step()
	_check(waiting.ok and waiting.code == "resident_need_recorded" and waiting.provenance == "local_rule_policy", "resident waits and records need when water is inaccessible")
	var first_request := kernel.resident_decision_request()
	_check(first_request.ok and first_request.resident_view.available_actions.has("wait"), "resident decision request exposes only resident view")
	_check(first_request.resident_view.needs.has("capability_request"), "resident view exposes persistent need slot")
	_check(first_request.resident_view.needs.capability_request.status == "open", "observed obstacle records a persistent need")
	var unauthorized_decision := kernel.submit_resident_decision({"action": "gm_install", "gm": true}, "model-overreach-1")
	_check(not unauthorized_decision.ok and unauthorized_decision.code == "decision_fields_invalid", "model decision cannot call GM or add fields")
	var manifest_result := kernel.load_builtin_manifest()
	_check(manifest_result.ok and manifest_result.capability_id == "well_bucket", "built-in capability manifest validates")
	var manifest := _read_manifest()
	var no_need_kernel := Kernel.new()
	no_need_kernel.create_fixture()
	var no_need_before := JSON.stringify(no_need_kernel.snapshot())
	var no_need_install := no_need_kernel.gm_install(manifest, "no-need-install")
	_check(not no_need_install.ok and no_need_install.code == "gm_approval_required" and JSON.stringify(no_need_kernel.snapshot()) == no_need_before, "installation without approved need has no effect")
	var before_invalid := JSON.stringify(kernel.snapshot())
	var injected := manifest.duplicate(true)
	injected["code"] = "load('arbitrary.gd')"
	var invalid := kernel.validate_manifest(injected)
	_check(not invalid.ok and JSON.stringify(kernel.snapshot()) == before_invalid, "unknown or injected manifest field has no effect")
	var changed_nested := manifest.duplicate(true)
	changed_nested.actions[0].amount = 2
	_check(not kernel.validate_manifest(changed_nested).ok and JSON.stringify(kernel.snapshot()) == before_invalid, "changed action semantics have no effect")
	_check(not kernel.resident_command({"command_id": "impersonate", "action": "gm_install", "role": "gm"}).ok, "resident cannot impersonate GM")
	_check(not kernel.resident_command({"command_id": "impersonate-2", "resident_id": "gm", "action": "draw_water"}).ok, "resident identity is fixed")
	var review := kernel.gm_review_need("need-review-1", "approve", "well_bucket", "The resident has a persistent water-access need and this package is the smallest reviewed fix.")
	_check(review.ok and review.code == "gm_need_approved", "GM approves a persisted need with reason and capability gap")
	var installed := kernel.gm_install(manifest, "install-well-1", "need-review-1")
	_check(installed.ok and installed.code == "capability_installed", "GM installs validated capability")
	var after_install := kernel.snapshot()
	_check(after_install.world.gm_resources.rope == 0 and after_install.world.gm_resources.bucket == 0, "installation consumes exactly fixed GM materials")
	var duplicate_install := kernel.gm_install(manifest, "install-well-1", "need-review-1")
	_check(duplicate_install.ok and duplicate_install.duplicate and JSON.stringify(kernel.snapshot()) == JSON.stringify(after_install), "duplicate installation does not consume again")
	var different_payload := manifest.duplicate(true)
	different_payload.provenance = "tampered"
	var mismatch := kernel.gm_install(different_payload, "install-well-1")
	_check(not mismatch.ok and mismatch.code == "command_id_payload_mismatch" and JSON.stringify(kernel.snapshot()) == JSON.stringify(after_install), "same command ID with different payload is rejected")

	var draw := kernel.resident_step()
	_check(draw.ok and draw.code == "water_drawn" and draw.provenance == "local_rule_policy", "resident discovers and performs draw_water")
	var after_draw := kernel.snapshot()
	_check(after_draw.world.well_water == 0 and after_draw.residents["fixture:luna"].inventory.water == 1, "water moves from well to resident exactly once")
	_check(kernel.resident_view().available_actions == ["wait", "drink_water"], "empty well is not offered as a usable action to the model holding water")
	var drink := kernel.resident_step()
	_check(drink.ok and drink.code == "water_consumed", "resident drinks held water")
	var after_drink := kernel.snapshot()
	_check(after_drink.residents["fixture:luna"].inventory.water == 0 and after_drink.residents["fixture:luna"].consumed.water == 1 and after_drink.residents["fixture:luna"].needs.thirst == 20, "drinking conserves inventory and changes need/history")
	var dry_kernel := Kernel.new()
	dry_kernel.create_fixture()
	_check(dry_kernel.resident_step().ok, "dry-well resident records need")
	_check(dry_kernel.gm_review_need("dry-review", "approve", "well_bucket", "Approved for the persisted water-access need.").ok, "dry-well GM approves persisted need")
	_check(dry_kernel.gm_install(manifest, "dry-install", "dry-review").ok, "dry-well fixture installs capability")
	_check(dry_kernel.resident_command({"command_id": "dry-draw-1", "action": "draw_water"}).ok, "dry-well fixture consumes only available well water")
	var dry := dry_kernel.resident_command({"command_id": "dry-draw-2", "action": "draw_water"})
	_check(not dry.ok and dry.code == "well_empty", "resident does not draw from an empty well")
	var disable := kernel.gm_disable("disable-well-1")
	_check(disable.ok and disable.code == "capability_disabled", "GM can disable installed capability")
	_check(not kernel.resident_view().available_actions.has("draw_water"), "disabled bucket is absent from model action choices")
	var post_disable_draw := kernel.resident_command({"command_id": "draw-after-disable", "action": "draw_water"})
	_check(not post_disable_draw.ok and post_disable_draw.code == "capability_unavailable", "disabled capability cannot execute")
	var disable_retry := kernel.gm_disable("disable-well-1")
	_check(disable_retry.ok and disable_retry.duplicate, "retry of completed disable returns receipt")
	var reenabled := kernel.gm_install(manifest, "reenable-well-1", "need-review-1")
	_check(reenabled.ok and reenabled.code == "capability_reenabled", "re-enabling keeps installed capability without charging again")
	_check(kernel.snapshot().world.gm_resources.rope == 0 and kernel.snapshot().world.gm_resources.bucket == 0, "re-enable does not consume installation materials twice")
	var invalid_quantity_path := _temp_path("core-acceptance-invalid-quantity.json")
	var invalid_quantity := kernel.snapshot()
	invalid_quantity.world.well_water = -1
	var invalid_quantity_file := FileAccess.open(invalid_quantity_path, FileAccess.WRITE)
	invalid_quantity_file.store_string(JSON.stringify(invalid_quantity))
	invalid_quantity_file.close()
	var preserved_before_invalid_load := kernel.snapshot()
	var invalid_quantity_result := kernel.load_from(invalid_quantity_path)
	_check(not invalid_quantity_result.ok and invalid_quantity_result.code == "save_world_invalid" and kernel.snapshot() == preserved_before_invalid_load, "illegal quantity is rejected without changing loaded state")
	var atomic_path := _temp_path("core-acceptance-atomic.json")
	var atomic_initial := kernel.save_to(atomic_path)
	var atomic_before := FileAccess.get_file_as_string(atomic_path)
	DirAccess.make_dir_absolute(atomic_path + ".tmp")
	var interrupted_write := kernel.save_to(atomic_path)
	_check(atomic_initial.ok and not interrupted_write.ok and FileAccess.get_file_as_string(atomic_path) == atomic_before, "failed replacement keeps previous valid save")
	if DirAccess.dir_exists_absolute(atomic_path + ".tmp"):
		DirAccess.remove_absolute(atomic_path + ".tmp")
	_cleanup_file(atomic_path)
	var saved_path := requested_save_path if not requested_save_path.is_empty() else _temp_path("core-acceptance-save.json")
	var save := kernel.save_to(saved_path)
	_check(save.ok, "save succeeds")
	var recovered := Kernel.new()
	var load := recovered.load_from(saved_path)
	var recovered_state := recovered.snapshot()
	var source_state := kernel.snapshot()
	_check(load.ok and recovered_state.world_id == source_state.world_id and recovered_state.turn == source_state.turn and recovered_state.world.well_water == source_state.world.well_water and recovered_state.residents["fixture:luna"].identity == source_state.residents["fixture:luna"].identity and recovered_state.residents["fixture:luna"].experiences.size() == source_state.residents["fixture:luna"].experiences.size() and recovered_state.events.size() == source_state.events.size() and recovered_state.receipts.size() == source_state.receipts.size(), "cold in-process recovery preserves full state")
	var receipt_retry := recovered.gm_disable("disable-well-1")
	_check(receipt_retry.ok and receipt_retry.duplicate and recovered.snapshot().plugins.well_bucket.status == "enabled", "old disable receipt remains idempotent after reload without undoing re-enable")
	var lock_a := Kernel.new()
	var lock_b := Kernel.new()
	var lock_one := lock_a.acquire_writer(saved_path)
	var lock_two := lock_b.acquire_writer(saved_path)
	_check(lock_one.ok and not lock_two.ok and lock_two.code == "writer_lock_busy", "second writer is blocked")
	_check(lock_a.release_writer(saved_path).ok and lock_b.acquire_writer(saved_path).ok, "writer lock releases for next writer")
	_check(lock_b.release_writer(saved_path).ok, "second writer releases lock")
	var corrupt_path := _temp_path("core-acceptance-corrupt.json")
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{broken")
	corrupt_file.close()
	var corrupt_target := Kernel.new()
	var corrupt_result := corrupt_target.load_from(corrupt_path)
	_check(not corrupt_result.ok and corrupt_result.code == "save_json_invalid" and corrupt_target.snapshot().is_empty(), "corrupt save is rejected without reset")
	var unsupported_path := _temp_path("core-acceptance-unsupported.json")
	var unsupported_file := FileAccess.open(unsupported_path, FileAccess.WRITE)
	unsupported_file.store_string(JSON.stringify({"state_version": 999, "world_id": "fixture:well-street", "fixture": true}))
	unsupported_file.close()
	var unsupported_target := Kernel.new()
	var unsupported_result := unsupported_target.load_from(unsupported_path)
	_check(not unsupported_result.ok and unsupported_result.code == "save_version_unsupported" and unsupported_target.snapshot().is_empty(), "unsupported save version is rejected without reset")
	_evidence.append({"test": "full", "world_id": recovered.snapshot().world_id, "resident_id": recovered.snapshot().residents["fixture:luna"].identity.id, "events": recovered.snapshot().events.size(), "receipt_count": recovered.snapshot().receipts.size(), "resource": {"well_water": recovered.snapshot().world.well_water, "resident_water": recovered.snapshot().residents["fixture:luna"].inventory.water, "consumed_water": recovered.snapshot().residents["fixture:luna"].consumed.water}})
	_cleanup_file(saved_path)
	_cleanup_file(corrupt_path)
	_cleanup_file(unsupported_path)
	_cleanup_file(invalid_quantity_path)

func _run_cold_write(save_path: String) -> void:
	_check(not save_path.is_empty(), "cold-write requires --save-path")
	if not _failures.is_empty():
		return
	var kernel := Kernel.new()
	kernel.create_fixture()
	var manifest := _read_manifest()
	_check(kernel.resident_step().ok, "cold-write records resident need")
	_check(kernel.gm_review_need("cold-review", "approve", "well_bucket", "Approved for the persisted fixture need.").ok, "cold-write records GM approval")
	_check(kernel.gm_install(manifest, "cold-install", "cold-review").ok, "cold-write installs capability")
	_check(kernel.resident_step().ok, "cold-write performs resident draw")
	var saved := kernel.save_to(save_path)
	_check(saved.ok, "cold-write saves")
	_evidence.append({"test": "cold-write", "path": save_path, "snapshot": kernel.snapshot()})

func _run_cold_read(save_path: String) -> void:
	_check(not save_path.is_empty(), "cold-read requires --save-path")
	if not _failures.is_empty():
		return
	var kernel := Kernel.new()
	var loaded := kernel.load_from(save_path)
	_check(loaded.ok, "cold-read loads prior state")
	if loaded.ok:
		var state := kernel.snapshot()
		_check(state.world_id == "fixture:well-street" and state.residents["fixture:luna"].inventory.water == 1, "cold-read preserves resident item and world identity")
		_check(state.plugins.well_bucket.status == "enabled" and state.receipts.has("cold-install"), "cold-read preserves plugin and receipt")
		_evidence.append({"test": "cold-read", "world_id": state.world_id, "resident": state.residents["fixture:luna"].identity, "plugin_status": state.plugins.well_bucket.status, "receipt_ids": state.receipts.keys()})

func _read_manifest() -> Dictionary:
	var file := FileAccess.open("res://capabilities/well_bucket.v1.json", FileAccess.READ)
	return JSON.parse_string(file.get_as_text())

func _temp_path(filename: String) -> String:
	return ProjectSettings.globalize_path("user://" + filename)

func _cleanup_file(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if not path.is_empty() and DirAccess.dir_exists_absolute(path + ".writer-lock"):
		DirAccess.remove_absolute(path + ".writer-lock")

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	_failures.append(label)
