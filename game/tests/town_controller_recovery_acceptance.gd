extends SceneTree

const Town := preload("res://core/town_runtime.gd")
const Turns := preload("res://agents/town_turns.gd")
const Recovery := preload("res://tools/recover_town_controller.gd")
const ValidFixture := preload("res://tests/town_life_acceptance.gd")
var checks := 0
var failures := 0

class FailingBrain extends Node:
	var calls := 0
	func propose(_view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		return {"ok": false, "code": "saved_provider_error", "command_id": "provider-failure", "provenance": "fixture"}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func write_save(path: String, pending: bool = false) -> void:
	var source := ValidFixture.new()
	var seed: Dictionary = source.fixture()
	source.free()
	seed.residents = [seed.residents[0]]
	seed.residents[0].story = "stable story"
	seed.residents[0].coins_col = 17
	seed.residents[0].runtime.private_memory = "history"
	seed.survival.accounts = [seed.survival.accounts[0]]
	seed.survival.accounts[0].food = 2
	seed.survival.accounts[0].energy = 44
	for key in ["positions", "homes", "observations"]:
		for id in ["fixture:b", "fixture:c"]:
			seed.godot[key].erase(id)
	seed.life.accounts = [{"resident_id": "fixture:a", "wood": 2, "iron": 1, "kindling": 0, "reserved_col": 0}]
	seed.life.events = [{"seq": 1, "type": "old_history", "actor_id": "fixture:a", "recipient_ids": ["fixture:a"], "operation_id": "old-event"}]
	seed.life.seq = 1
	seed.godot.resident_turns = {"fixture:a": {"status": "pending" if pending else "ready", "seen_seq": 1, "history": [{"action": "old", "status": "settled"}],
		"controller_epoch": 2, "controller_id": "old:controller", "request_number": 0, "request_id": "old-request", "reviews": []}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(seed))
	file.close()

func core_snapshot(town: RefCounted) -> Dictionary:
	var state: Dictionary = town.snapshot()
	return {"residents": state.residents, "life": state.life, "survival": state.survival, "foraging": state.foraging}

func run() -> void:
	var path := "user://town-controller-recovery-%d.json" % Time.get_ticks_usec()
	write_save(path)
	var town := Town.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "fixture loads")
	if not loaded.ok:
		print(JSON.stringify({"suite": "town_controller_recovery", "checks": checks, "failures": failures, "load_error": loaded}))
		quit(1)
		return
	var turns := Turns.new()
	get_root().add_child(turns)
	turns.town = town
	turns.save_path = path
	var failing := FailingBrain.new()
	check(turns.connect_controller("fixture:a", failing, "fixture:failed").ok, "failed controller connects")
	var failed := await turns.step("fixture:a")
	check(failed.code == "provider_error" and failing.calls == 1, "provider error is saved without retry")
	var failed_record: Dictionary = turns._record("fixture:a").duplicate(true)
	var before_core := core_snapshot(town)
	var old_epoch := int(failed_record.controller_epoch)
	var old_request: String = failed_record.request_id
	var old_reply: Dictionary = failed_record.accepted_reply.duplicate(true)
	town.release_writer(path)
	turns.free()

	var recovered := await Recovery.recover(get_root(), path, "fixture:a", old_request)
	check(recovered.ok and not recovered.get("duplicate", false), "failed controller recovers")
	var after := Town.new()
	check(after.load_from(path).ok, "recovered save loads")
	var record: Dictionary = after._state.godot.resident_turns["fixture:a"]
	var expected_controller_id := "host:recovery:" + ("fixture:a|" + old_request).sha256_text()
	check(record.status == "ready" and record.controller_id == expected_controller_id, "durable host review controller identifier recorded")
	check(int(record.controller_epoch) == old_epoch + 1, "recovery bumps epoch once")
	check(record.reviews.back().error == failed_record.error and record.reviews.back().request_id == old_request, "original provider failure is archived")
	check(core_snapshot(after) == before_core, "identity history coins contracts and resources unchanged")
	var bytes := FileAccess.get_file_as_bytes(path)
	var duplicate_epoch := int(record.controller_epoch)
	var duplicate := await Recovery.recover(get_root(), path, "fixture:a", old_request)
	check(duplicate.ok and duplicate.duplicate, "duplicate recovery is idempotent")
	check(FileAccess.get_file_as_bytes(path) == bytes and duplicate_epoch == old_epoch + 1, "duplicate does not rewrite save or bump epoch")
	var cold := Town.new()
	check(cold.load_from(path).ok and cold._state.godot.resident_turns["fixture:a"].controller_epoch == old_epoch + 1, "independent cold restore keeps recovery epoch")
	var stale_turns := Turns.new()
	stale_turns.town = cold
	stale_turns.save_path = path
	var stale := stale_turns.apply_reply("fixture:a", old_epoch, old_request, old_reply)
	check(stale.code == "stale_controller_reply", "old reply is fenced")
	check(FileAccess.get_file_as_bytes(path) == bytes, "fenced old reply leaves save unchanged")
	var stale_request := await Recovery.recover(get_root(), path, "fixture:a", "old-request")
	check(not stale_request.ok and stale_request.code == "stale_request", "stale request rejected")
	var pending_path := "user://town-controller-recovery-pending-%d.json" % Time.get_ticks_usec()
	write_save(pending_path, true)
	var pending_town := Town.new()
	var pending_loaded := pending_town.load_from(pending_path)
	check(pending_loaded.ok, "pending fixture loads")
	if not pending_loaded.ok:
		print(JSON.stringify({"suite": "town_controller_recovery", "checks": checks, "failures": failures, "load_error": pending_loaded}))
		quit(1)
		return
	var pending := await Recovery.recover(get_root(), pending_path, "fixture:a", "old-request")
	check(not pending.ok and pending.code == "request_inflight", "pending request rejected")
	pending_town.release_writer(pending_path)
	after.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pending_path))
	stale_turns.free()
	await process_frame
	print(JSON.stringify({"suite": "town_controller_recovery", "checks": checks, "failures": failures, "paid_calls": 0, "provenance": "host_review_fixture"}))
	quit(0 if failures == 0 else 1)
