extends SceneTree

## Offline acceptance for the minimum settled-reply reconciliation.
##
## A fixture world holds one resident whose paid turn failed (a provider_error receipt with its
## authoritative archive entry) and whose reply has since been settled at the fee ledger. The
## real Baking runtime and the real offline CLI (`Recon.Reconciliation.run`) are used:
## the recovered decision must apply exactly once through the world's own action validation,
## the original failure must stay authoritative beside exactly one recovered replay, and every
## rejection (pending status, pending job, stale request, mismatched operation, missing archive,
## changed source bytes, relabelled provenance, edited model text, save failure) must happen
## without one saved byte changing. No provider, no ledger, no network and no real world is
## touched. These fixtures are not autonomous resident evidence.
const Town := preload("res://core/town_baking.gd")
const Turns := preload("res://agents/town_turns.gd")
const Recon := preload("res://tools/reconcile_settled_town_reply_cli.gd")
const ValidFixture := preload("res://tests/town_life_acceptance.gd")

const OPERATION := "dc45d0a2-986a-4bd9-a03b-59b387dd9595"
const OTHER_OPERATION := "6f000000-0000-0000-0000-000000000000"
const RESIDENT := "fixture:a"
const REQUEST := "turn:fixture:a:0:1"
const STALE_REQUEST := "turn:fixture:a:0:0"
const EPOCH := 0
const PROVIDER := "opengameagent_fixture"
const DECISION_TEXT := "{\"action\":\"a0\",\"reason\":\"fixture recovery choice 复原\"}"
const WAIT_OPTION := "wait"
const ARCHIVE_PROVIDER_ERROR := "provider_error"

var checks := 0
var failures := 0
var artifacts: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func scratch_directory() -> String:
	## A candidate-local writable scratch path: an explicit override first, then the ignored
	## tmp/ directory of this checkout, then Godot's own user directory.
	var candidates: Array[String] = []
	var configured := OS.get_environment("AINCRAD_RECONCILE_TMP")
	if not configured.is_empty():
		candidates.append(configured)
	candidates.append(ProjectSettings.globalize_path("res://tmp/reconcile"))
	candidates.append(ProjectSettings.globalize_path("user://reconcile"))
	for candidate in candidates:
		DirAccess.make_dir_recursive_absolute(candidate)
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""

func scratch_path(directory: String, label: String) -> String:
	var path := directory.path_join("%s-%d-%d.json" % [label, OS.get_process_id(), artifacts.size()])
	artifacts.append(path)
	return path

func write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", true, true))
	file.close()
	return true

func utf8_sha256(text: String) -> String:
	## Computed here, independently of the CLI, so a non-ASCII decision text still has to
	## match the hash the CLI derives from the same bytes.
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode().to_lower()

func failed_reply() -> Dictionary:
	return {"ok": false, "code": "brain_run_failed", "command_id": OPERATION, "model_returned": false,
		"assistant_text_parts": [], "assistant_text": "", "provider_id": PROVIDER,
		"runtime": "OpenGameAgent", "fixture": true, "provenance": PROVIDER}

func fixture_world(variant: String) -> Dictionary:
	var source := ValidFixture.new()
	var seed: Dictionary = source.fixture()
	source.free()
	seed.residents = [seed.residents[0]]
	seed.survival.accounts = [seed.survival.accounts[0]]
	seed.life.accounts = [seed.life.accounts[0]]
	for key in ["positions", "homes", "observations"]:
		for id in ["fixture:b", "fixture:c"]:
			seed.godot[key].erase(id)
	seed.life.events = [{"seq": 1, "type": "old_history", "actor_id": RESIDENT,
		"recipient_ids": [RESIDENT], "operation_id": "old-event"}]
	seed.life.seq = 1
	var failed: Dictionary = failed_reply()
	var record := {"status": "provider_error", "seen_seq": 1, "history": [], "reviews": [],
		"controller_epoch": EPOCH, "controller_id": "local:gateway", "request_number": 1,
		"request_id": REQUEST, "offered_actions": {"a0": WAIT_OPTION}, "speech_actions": [],
		"provider_command_id": OPERATION, "error": "brain_run_failed", "accepted_reply": failed}
	seed.godot.resident_turns = {RESIDENT: record}
	seed.godot.resident_archive = {"schema_version": 1, "world_id": seed.world_id, "order": [REQUEST],
		"entries": {REQUEST: {"archive_id": REQUEST, "world_id": seed.world_id, "resident_id": RESIDENT,
			"request_id": REQUEST, "provider_id": PROVIDER, "model_returned": false, "assistant_text_parts": [],
			"assistant_text": "", "original_reply": failed,
			"application": {"status": ARCHIVE_PROVIDER_ERROR, "code": "brain_run_failed", "effect": {},
				"speech_delivery": {"attempted": false, "delivered": false, "code": "no_world_action"}}}}}
	if variant == "pending":
		record.status = "pending"
	elif variant == "pending_job":
		# A real, loadable pending physical job: the job and its command must agree.
		seed.godot.pending = {RESIDENT: {"action": "rest", "command_id": "pending-job", "elapsed": 0.0,
			"provenance": PROVIDER}}
		seed.godot.commands = {"pending-job": {"payload": {"actor_id": RESIDENT, "action": "rest",
			"provenance": PROVIDER}, "status": "pending"}}
	elif variant == "stale_request":
		record.request_id = STALE_REQUEST
	elif variant == "wrong_operation":
		record.provider_command_id = OTHER_OPERATION
	elif variant == "stale_epoch":
		record.controller_epoch = EPOCH + 1
	elif variant == "no_archive":
		seed.godot.resident_archive = {"schema_version": 1, "world_id": seed.world_id, "order": [], "entries": {}}
	return seed

func receipt_for(seed: Dictionary, source_sha: String, changes: Dictionary = {}) -> Dictionary:
	var failed: Dictionary = seed.godot.resident_turns[RESIDENT].accepted_reply
	var text := str(changes.get("assistant_text", DECISION_TEXT))
	return {"schema_version": 1, "kind": "settled_town_reply_receipt",
		"source": {"world_id": str(changes.get("world_id", seed.world_id)),
			"source_sha256": str(changes.get("source_sha256", source_sha)),
			"resident_id": RESIDENT, "request_id": str(changes.get("request_id", REQUEST)),
			"controller_epoch": EPOCH, "provider_operation_id": str(changes.get("operation", OPERATION)),
			"provider_id": str(changes.get("provider_id", PROVIDER))},
		"failure": {"controller_status": "provider_error", "error": "brain_run_failed", "error_detail": "",
			"original_failed_reply": failed},
		"archive": {"archive_id": REQUEST, "application_status": ARCHIVE_PROVIDER_ERROR,
			"application_code": "brain_run_failed", "replays": 0},
		"ledger": {"ledger_id": "fixture-ledger", "policy_sha256": "fixture-policy", "state": "settled",
			"payload_sha256": "fixture-payload", "response_sha256": "fixture-response", "charge_nano": 736000,
			"prompt_tokens": 80, "output_tokens": 12, "cached_tokens": 20, "maximum": 512,
			"reserve_nano": 1000000},
		"reply": {"command_id": str(changes.get("operation", OPERATION)), "assistant_text": text,
			"assistant_text_sha256": utf8_sha256(text)}}

func recovered_reply(provenance: String) -> Dictionary:
	return {"ok": true, "decision": JSON.parse_string(DECISION_TEXT), "assistant_text_parts": [DECISION_TEXT],
		"assistant_text": DECISION_TEXT, "model_returned": true, "provider_id": provenance,
		"runtime": "OpenGameAgent", "fixture": provenance != "opengameagent_live",
		"command_id": OPERATION, "provenance": provenance}

func load_town(path: String) -> RefCounted:
	var town := Town.new()
	var loaded: Dictionary = town.load_from(path)
	if not loaded.ok:
		return null
	return town

func record_of(town: RefCounted) -> Dictionary:
	var turns: Dictionary = town._state.godot.get("resident_turns", {})
	return turns.get(RESIDENT, {})

func archive_entry_of(town: RefCounted) -> Dictionary:
	var archive: Dictionary = town._state.godot.get("resident_archive", {})
	var entries: Dictionary = archive.get("entries", {})
	return entries.get(REQUEST, {})

func core_snapshot(town: RefCounted) -> Dictionary:
	var state: Dictionary = town.snapshot()
	return {"residents": state.residents, "accounts": state.life.accounts, "survival": state.survival,
		"foraging": state.foraging, "events": state.life.events}

func finish() -> void:
	for path in artifacts:
		for suffix in ["", ".tmp", ".replace-pending", ".bak", ".lock"]:
			var candidate: String = path + str(suffix)
			if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
				DirAccess.remove_absolute(candidate)
	print(JSON.stringify({"suite": "town_settled_reply", "checks": checks, "failures": failures,
		"paid_calls": 0, "provider_calls": 0, "ledger_rows_created": 0, "kind": "offline_fixture"}))
	quit(0 if failures == 0 else 1)

func run() -> void:
	var directory := scratch_directory()
	check(not directory.is_empty(), "a candidate-local writable scratch directory exists")
	if directory.is_empty():
		finish()
		return
	var save_path := scratch_path(directory, "town-settled-reply")
	var receipt_path := scratch_path(directory, "receipt")

	# --- the settled reply applies exactly once ---------------------------------------------
	var seed := fixture_world("ok")
	check(write_json(save_path, seed), "the fixture save is written")
	var before_core := core_snapshot(load_town(save_path))
	check(write_json(receipt_path, receipt_for(seed, FileAccess.get_sha256(save_path))),
		"the private receipt envelope is written")
	var applied: Dictionary = Recon.Reconciliation.run(save_path, receipt_path)
	check(applied.get("ok", false) and str(applied.get("code", "")) == "settled",
		"the settled reply applies once: " + str(applied.get("code", "")))
	check(str(applied.get("provider_operation_id", "")) == OPERATION, "the applied reply keeps its paid operation id")
	check(str(applied.get("ledger_response_sha256", "")) == "fixture-response", "the applied reply carries its ledger response hash")

	var town := load_town(save_path)
	check(town != null, "the reconciled save reloads cold")
	var record := record_of(town)
	check(str(record.get("status", "")) == "settled", "the held turn settles instead of staying in provider_error")
	check(str(record.get("request_id", "")) == REQUEST and int(record.get("controller_epoch", -1)) == EPOCH,
		"the request id and controller epoch are unchanged")
	check(str(record.get("provider_command_id", "")) == OPERATION, "the paid operation id is unchanged")
	check(str(record.get("controller_id", "")) == "local:gateway", "no controller was reset")
	var accepted: Dictionary = record.get("accepted_reply", {})
	check(accepted.get("ok", false) == true, "the recovered reply is the accepted reply")
	check(str(accepted.get("assistant_text", "")) == DECISION_TEXT, "the recovered model text is preserved byte for byte")
	check(str(accepted.get("provenance", "")) == PROVIDER, "the proven original provenance is carried")
	var history: Array = record.get("history", [])
	check(history.size() == 1, "exactly one decision enters history")
	check(str(history[0].get("status", "")) == "settled" and str(history[0].get("command_id", "")) == REQUEST,
		"the history entry names this request and its settled status")
	var effect: Dictionary = record.get("result", {})
	check(effect.get("ok", false) == true and str(effect.get("code", "")) == WAIT_OPTION,
		"the recovered effect is the resident's own wait choice: " + str(effect.get("code", "")))
	var reviews: Array = record.get("reviews", [])
	check(reviews.size() == 1 and str(reviews[0].get("reason", "")) == "host_settled_reply_recovery",
		"the review metadata is recorded with the recovery")
	check(str(reviews[0].get("error", "")) == "brain_run_failed"
			and str(reviews[0].get("provider_operation_id", "")) == OPERATION,
		"the review keeps the original failure and its operation")
	var entry := archive_entry_of(town)
	var application: Dictionary = entry.get("application", {})
	check(str(application.get("status", "")) == ARCHIVE_PROVIDER_ERROR,
		"the original provider_error archive stays authoritative")
	var original: Dictionary = entry.get("original_reply", {})
	check(str(original.get("code", "")) == "brain_run_failed" and str(original.get("assistant_text", "")) == "",
		"the original failure text is preserved as private evidence")
	var replays: Array = entry.get("replays", [])
	check(replays.size() == 1, "exactly one recovered replay is recorded beside it")
	check(str(replays[0].get("application", {}).get("status", "")) == "settled",
		"the recovered replay records the settled application")
	check(core_snapshot(town) == before_core,
		"an ordinary wait changes no resident, account, survival, foraging or event fact")

	# --- a repeated receipt never applies twice --------------------------------------------
	var settled_bytes := FileAccess.get_file_as_bytes(save_path)
	var repeated: Dictionary = Recon.Reconciliation.run(save_path, receipt_path)
	check(not repeated.get("ok", true) and str(repeated.get("code", "")) == "source_hash_changed_since_receipt",
		"a repeated receipt is refused, never applied twice: " + str(repeated.get("code", "")))
	check(FileAccess.get_file_as_bytes(save_path) == settled_bytes, "the refused repeat changes no save byte")
	# Even with the newer save hash the applied turn cannot be applied a second time.
	var replay_turns := Turns.new()
	replay_turns.town = load_town(save_path)
	replay_turns.save_path = save_path
	var fresh_recovery := {"world_id": seed.world_id, "resident_id": RESIDENT, "request_id": REQUEST,
		"controller_epoch": EPOCH, "provider_operation_id": OPERATION,
		"source_sha256": FileAccess.get_sha256(save_path), "ledger_response_sha256": "fixture-response",
		"original_failed_reply": seed.godot.resident_turns[RESIDENT].accepted_reply}
	var refused_replay: Dictionary = replay_turns.apply_reply(RESIDENT, EPOCH, REQUEST,
		recovered_reply(PROVIDER), fresh_recovery)
	replay_turns.free()
	check(not refused_replay.get("ok", true) and str(refused_replay.get("code", "")) == "recovery_not_provider_error",
		"an already applied turn is refused even with a fresh source hash: " + str(refused_replay.get("code", "")))
	check(FileAccess.get_file_as_bytes(save_path) == settled_bytes, "the second refusal changes no save byte")
	var settled_town := load_town(save_path)
	var settled_record := record_of(settled_town)
	var settled_history: Array = settled_record.get("history", [])
	var settled_replays: Array = archive_entry_of(settled_town).get("replays", [])
	check(settled_history.size() == 1 and settled_replays.size() == 1,
		"the refused repeat adds no second decision and no second replay")

	# --- every binding refusal happens without a saved byte changing ------------------------
	var refusals := [["pending", "recovery_not_provider_error"], ["pending_job", "resident_working"],
		["stale_request", "recovery_request_mismatch"], ["stale_epoch", "recovery_epoch_mismatch"],
		["wrong_operation", "recovery_operation_mismatch"], ["no_archive", "recovery_archive_missing"]]
	for pair in refusals:
		var variant: String = pair[0]
		var path := scratch_path(directory, "town-" + variant)
		var case_seed := fixture_world(variant)
		check(write_json(path, case_seed), "the " + variant + " fixture is written")
		var reference_town := load_town(path)
		check(reference_town != null, "the " + variant + " fixture loads")
		var reference_record := record_of(reference_town).duplicate(true)
		var reference_entry := archive_entry_of(reference_town).duplicate(true)
		var bytes := FileAccess.get_file_as_bytes(path)
		check(write_json(receipt_path, receipt_for(case_seed, FileAccess.get_sha256(path))),
			"the " + variant + " receipt is written")
		var refused: Dictionary = Recon.Reconciliation.run(path, receipt_path)
		check(not refused.get("ok", true) and str(refused.get("code", "")) == pair[1],
			"refuses " + variant + " with " + pair[1] + " (got " + str(refused.get("code", "")) + ")")
		check(FileAccess.get_file_as_bytes(path) == bytes, "refusal " + variant + " changes no save byte")
		var held := load_town(path)
		check(record_of(held) == reference_record,
			"refusal " + variant + " leaves the resident record untouched")
		check(archive_entry_of(held) == reference_entry,
			"refusal " + variant + " leaves the failure archive untouched")

	# --- envelope-level refusals -----------------------------------------------------------
	var envelope_cases := [
		["source", {"source_sha256": "00".repeat(32)}, "source_hash_changed_since_receipt"],
		["world", {"world_id": "fixture:other-world"}, "recovery_world_mismatch"],
		["provenance", {"provider_id": "opengameagent_live"}, "recovery_provenance_changed"],
		["text", {"assistant_text": DECISION_TEXT + " "}, "recovery_reply_text_mismatch"],
		["operation", {"operation": OTHER_OPERATION}, "recovery_operation_mismatch"],
	]
	for case in envelope_cases:
		var label: String = case[0]
		var changes: Dictionary = case[1]
		var path := scratch_path(directory, "envelope-" + label)
		var case_seed := fixture_world("ok")
		check(write_json(path, case_seed), "the " + label + " envelope fixture is written")
		var receipt := receipt_for(case_seed, FileAccess.get_sha256(path), changes)
		if label == "text":
			# The model text was edited after extraction: the envelope keeps the hash of the
			# audited bytes, so the CLI must refuse the edited text.
			receipt.reply.assistant_text_sha256 = utf8_sha256(DECISION_TEXT)
		check(write_json(receipt_path, receipt), "the " + label + " envelope is written")
		var bytes := FileAccess.get_file_as_bytes(path)
		var reference_town := load_town(path)
		var reference_record := record_of(reference_town).duplicate(true)
		var refused: Dictionary = Recon.Reconciliation.run(path, receipt_path)
		var expected: String = case[2]
		check(not refused.get("ok", true) and str(refused.get("code", "")) == expected,
			"refuses " + label + " with " + expected + " (got " + str(refused.get("code", "")) + ")")
		check(FileAccess.get_file_as_bytes(path) == bytes, "refusal " + label + " changes no save byte")
		check(record_of(load_town(path)) == reference_record, "refusal " + label + " leaves the record untouched")

	# --- an injected save failure rolls the review metadata and effect back together ---------
	var fail_path := scratch_path(directory, "town-save-failure")
	var fail_seed := fixture_world("ok")
	check(write_json(fail_path, fail_seed), "the save-failure fixture is written")
	var fail_receipt := scratch_path(directory, "receipt-save-failure")
	check(write_json(fail_receipt, receipt_for(fail_seed, FileAccess.get_sha256(fail_path))),
		"the save-failure receipt is written")
	var fail_bytes := FileAccess.get_file_as_bytes(fail_path)
	var blocker := fail_path + ".tmp"
	check(DirAccess.make_dir_absolute(blocker) == OK, "the save target is made unwritable")
	var failed_run: Dictionary = Recon.Reconciliation.run(fail_path, fail_receipt)
	check(not failed_run.get("ok", true), "an unwritable save fails the reconciliation")
	check(str(failed_run.get("code", "")).begins_with("save_"),
		"the failure names the save step: " + str(failed_run.get("code", "")))
	check(FileAccess.get_file_as_bytes(fail_path) == fail_bytes, "the failed save leaves the original bytes intact")
	var rolled_back := load_town(fail_path)
	var rolled_record := record_of(rolled_back)
	check(str(rolled_record.get("status", "")) == "provider_error",
		"the rolled-back record is still the provider_error receipt")
	check(rolled_record.get("reviews", []).is_empty(), "the review metadata rolled back with the effect")
	check(archive_entry_of(rolled_back).get("replays", []).is_empty(), "the archive replay rolled back with the effect")
	DirAccess.remove_absolute(blocker)

	# --- the helper's own source check and the unchanged ordinary behaviour ----------------
	var direct_path := scratch_path(directory, "town-direct")
	var direct_seed := fixture_world("ok")
	check(write_json(direct_path, direct_seed), "the direct-binding fixture is written")
	var direct_bytes := FileAccess.get_file_as_bytes(direct_path)
	var direct_turns := Turns.new()
	direct_turns.town = load_town(direct_path)
	direct_turns.save_path = direct_path
	check(direct_turns.town != null, "the direct-binding fixture loads")
	var wrong_source := {"world_id": direct_seed.world_id, "resident_id": RESIDENT, "request_id": REQUEST,
		"controller_epoch": EPOCH, "provider_operation_id": OPERATION, "source_sha256": "00".repeat(32),
		"ledger_response_sha256": "", "original_failed_reply": direct_seed.godot.resident_turns[RESIDENT].accepted_reply}
	var refused_direct: Dictionary = direct_turns.apply_reply(RESIDENT, EPOCH, REQUEST,
		recovered_reply(PROVIDER), wrong_source)
	direct_turns.free()
	check(not refused_direct.get("ok", true) and str(refused_direct.get("code", "")) == "recovery_source_hash_mismatch",
		"the helper's own source check refuses independently: " + str(refused_direct.get("code", "")))
	check(FileAccess.get_file_as_bytes(direct_path) == direct_bytes,
		"the helper's source refusal writes nothing")
	var normal_turns := Turns.new()
	normal_turns.town = load_town(direct_path)
	normal_turns.save_path = direct_path
	var conflicted: Dictionary = normal_turns.apply_reply(RESIDENT, EPOCH, REQUEST, recovered_reply(PROVIDER))
	normal_turns.free()
	check(str(conflicted.get("code", "")) == "reply_conflict",
		"an ordinary late reply keeps its existing reply_conflict behaviour")

	finish()
