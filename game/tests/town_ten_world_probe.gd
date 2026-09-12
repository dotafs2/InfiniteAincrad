extends SceneTree
## TEN-RESIDENT NEW-WORLD seed acceptance probe.
##
## Offline SceneTree diagnostic. It uses explicit offline test choices through the
## existing runtime actions (provenance "local_rule_policy"), makes NO model call,
## starts no gateway and performs no paid run. It never writes the given seed file:
## the seed is copied into this probe's own work path under the ten-world
## validation root first, and every check reads the copy.
##
## Scope: ten distinct residents of an explicitly NEW world seed load with their
## declared GENESIS positions, needs, holdings and roles; the plaza positions are
## spaced within declared numeric bounds; two different state consequences happen
## through the normal actions; an unfinished job, the history, the identities and
## the holdings survive a save and a second Runtime load in the SAME process.
## Separate-process continuation is checked by ten_world_continuation_probe.gd.

const Runtime := preload("res://core/town_runtime.gd")
const ALLOWED_ROOT_REL := "../tmp/chain-20260912/ten-world-validation"
const SPRINT_ROOT_REL := "../tmp/gpt6-sprint/ten-world"
const MIN_SPACING := 1.0
const PLAZA_BOUNDS := {"x": [-6.0, 6.0], "y": [0.0, 1.0], "z": [2.0, 10.0]}
const EXPECTED_RESIDENTS := 10

var _seed_path := ""
var _out_path := ""
var _work_save := ""
var _failures: Array = []
var _checks := 0
var _evidence: Dictionary = {}

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

func _finish(code: int) -> void:
	var payload := {"scenario": "ten-world-seed", "checks": _checks,
		"evidence_kind": "state_and_writer_lock_only",
		"scene_evidence": ("resident bodies, engine penetration and real-time life "
			+ "consequences are checked by the separate town-street run"),
		"failure_count": _failures.size(), "failures": _failures, "evidence": _evidence}
	if not _out_path.is_empty():
		DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
		var handle := FileAccess.open(_out_path, FileAccess.WRITE)
		if handle:
			handle.store_string(JSON.stringify(payload))
			handle.close()
		else:
			push_error("Cannot write state evidence")
			code = 2
	print(JSON.stringify(payload))
	quit(code)

func _allowed(path: String) -> bool:
	if not path.is_absolute_path():
		return false
	var normalized := path.replace("\\", "/").simplify_path().to_lower()
	for relative in [ALLOWED_ROOT_REL, SPRINT_ROOT_REL]:
		var allowed := ProjectSettings.globalize_path("res://").path_join(relative).simplify_path().replace("\\", "/").to_lower()
		if normalized.begins_with(allowed + "/"):
			return true
	return false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ten-save="):
			_seed_path = arg.trim_prefix("--ten-save=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
	if _seed_path.is_empty() or _out_path.is_empty():
		push_error("usage: -- --ten-save=<seed.json> --out=<result.json>")
		quit(2)
		return
	var allowed_root := ProjectSettings.globalize_path("res://").path_join(ALLOWED_ROOT_REL) \
		.simplify_path().replace("\\", "/")
	if not _allowed(_seed_path) or not _allowed(_out_path) or _seed_path == _out_path:
		push_error("Use distinct absolute seed/output paths under a ten-world validation root")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(allowed_root.path_join("probe-run"))
	# A disposable offline copy with a fresh work path per run: no writer lock can
	# outlive its process, and no lock is ever deleted or bypassed by this probe.
	var stamp := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_work_save = allowed_root.path_join("probe-run/ten-world-state-%s.json" % stamp)
	if FileAccess.file_exists(_work_save) or FileAccess.file_exists(_work_save + ".writer-lock") \
			or DirAccess.dir_exists_absolute(_work_save + ".writer-lock"):
		push_error("Refusing an existing probe work path")
		quit(2)
		return
	_check(not FileAccess.file_exists(_work_save + ".writer-lock") and not DirAccess.dir_exists_absolute(_work_save + ".writer-lock"),
		"the probe work path starts with no writer lock")
	var seed_text := FileAccess.get_file_as_string(_seed_path)
	var copy := FileAccess.open(_work_save, FileAccess.WRITE)
	if copy == null or seed_text.is_empty():
		push_error("Cannot read seed or create disposable work copy")
		quit(2)
		return
	copy.store_string(seed_text)
	copy.close()

	var runtime: RefCounted = Runtime.new()
	var loaded: Dictionary = runtime.load_from(_work_save)
	_check(loaded.get("ok", false), "new world seed loads through the existing runtime")
	if not loaded.get("ok", false):
		_finish(1)
		return
	var ids: Array = runtime.active_ids()
	_check(ids.size() == EXPECTED_RESIDENTS, "street runtime exposes ten active residents")
	if ids.size() != EXPECTED_RESIDENTS:
		_finish(1)
		return
	_check(__positions_are_valid(runtime, ids), "ten declared positions are finite, distinct, " +
		"non-overlapping and inside the plaza")
	_check(__identities_are_distinct(runtime, ids), "ten stable ids, names and roles are distinct")
	_check(__genesis_metadata(runtime), "seed declares an explicit NEW world origin, not a migration")

	var before: Dictionary = __snapshot(runtime, ids)
	var rest_id: String = ids[0]
	var eat_id: String = ids[1]
	var pending_id: String = ids[2]
	_check(runtime.start_action(rest_id, "rest", "probe:ten:rest:1").get("ok", false),
		"offline test choice starts an available rest action")
	_check(runtime.start_action(eat_id, "eat_ration", "probe:ten:eat:1").get("ok", false),
		"offline test choice starts an available meal action")
	var rest_step: Dictionary = runtime.advance(60.0)
	_check(rest_step.get("completed", []).size() == 2, "both chosen actions complete offline")
	_check(runtime.account(rest_id).energy >= float(before[rest_id]["energy"]) + 30.0,
		"state consequence type 1: the resting resident recovers energy")
	_check(runtime.account(eat_id).food == 0 and runtime.resident(eat_id).needs.hunger >= 95.0,
		"state consequence type 2: the eating resident consumes a ration and is fed")
	_check(runtime.resident(rest_id).needs.get("hunger", -1) == before[rest_id]["hunger"],
		"the first 60 seconds do not yet reach the 120-second need tick")

	# An unfinished job is a commitment: it must survive the closed world.
	_check(runtime.start_action(pending_id, "rest", "probe:ten:rest:pending").get("ok", false),
		"offline test choice opens an unfinished rest job")
	_check(runtime.pending_job(pending_id).get("action", "") == "rest",
		"the unfinished job is visible as a pending time commitment")
	_check(runtime.transaction(_work_save, func(): return {"ok": true}).get("ok", false),
		"the world saves through the normal writer-locked transaction")

	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_work_save))
	_check(on_disk.get("life", {}).get("seq", -1) == 2,
		"two completed offline actions are in the saved world history")
	var saved_accounts: Dictionary = {}
	for account in on_disk.get("survival", {}).get("accounts", []):
		saved_accounts[account.get("resident_id", "")] = account
	_check(saved_accounts.size() == EXPECTED_RESIDENTS and
		float(saved_accounts.get(rest_id, {}).get("energy", 0.0)) >=
			float(before[rest_id]["energy"]) + 30.0,
		"saved holdings keep the state consequence")
	_check(runtime.release_writer(_work_save).get("ok", false),
		"pausing the world releases its single writer, as a closed world must")

	var resumed: RefCounted = Runtime.new()
	var reopened: Dictionary = resumed.load_from(_work_save)
	_check(reopened.get("ok", false), "a second Runtime in this process loads the saved world")
	var resumed_ids: Array = resumed.active_ids()
	_check(resumed_ids == ids, "all ten identities survive the second Runtime load")
	_check(__reopen_retention(resumed, on_disk, before, rest_id, eat_id),
		"holdings, needs and roles are unchanged by the second Runtime load")
	_check(resumed.pending_job(pending_id).get("action", "") == "rest",
		"the unfinished commitment is still pending after the reopen")
	var reopened_pending: String = resumed.pending_job(pending_id).get("action", "")
	var resumed_step: Dictionary = resumed.advance(60.0)
	_check(resumed_step.get("completed", []).size() == 1,
		"the surviving commitment finishes after the reopen")
	_check(resumed.account(pending_id).energy >= float(before[pending_id]["energy"]) + 30.0,
		"the reopened work produces the expected state consequence")
	_check(resumed.resident(rest_id).needs.hunger < float(before[rest_id]["hunger"]),
		"the full 120 seconds apply the world's ordinary need tick")
	_check(resumed.transaction(_work_save, func(): return {"ok": true}).get("ok", false),
		"the reopened world saves again without losing history")
	_check(resumed.release_writer(_work_save).get("ok", false),
		"the reopened world releases its writer again")
	var final_state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_work_save))
	_check(final_state.get("life", {}).get("seq", -1) == 3,
		"the reopened history continues instead of restarting")
	_check(FileAccess.get_file_as_string(_seed_path) == seed_text, "the supplied seed remains byte exact")

	var resident_rows: Array = []
	for id in ids:
		var point: Vector3 = runtime.position_of(id)
		resident_rows.append({"stable_id": id, "name": runtime.resident(id).name,
			"role": runtime.resident(id).role, "position": [point.x, point.y, point.z],
			"coins_col": runtime.resident(id).coins_col, "food": runtime.account(id).food,
			"energy": runtime.account(id).energy,
			"hunger": runtime.resident(id).needs.hunger})
	var consequence_rows: Array = []
	consequence_rows.append({"type": "energy_recovery", "resident": rest_id,
		"energy_before": before[rest_id]["energy"],
		"energy_after": runtime.account(rest_id).energy})
	consequence_rows.append({"type": "ration_consumed_and_fed", "resident": eat_id,
		"food_before": before[eat_id]["food"], "food_after": runtime.account(eat_id).food,
		"hunger_before": before[eat_id]["hunger"],
		"hunger_after": runtime.resident(eat_id).needs.hunger})
	_evidence = {"world_id": on_disk.get("world_id", ""), "origin": on_disk.get("origin", {}),
		"seed": on_disk.get("seed", {}), "residents": resident_rows,
		"consequences": consequence_rows,
		"commitment_after_reopen": reopened_pending,
		"restore_scope": "second Runtime in the same engine process", "work_save": _work_save,
		"life_seq": final_state.get("life", {}).get("seq", -1), "model_calls": 0,
		"provenance": "explicit offline test choices; no model call, no paid run, no gateway"}
	_finish(0 if _failures.is_empty() else 1)

func __snapshot(runtime: RefCounted, ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for id in ids:
		result[id] = {"energy": runtime.account(id).energy, "food": runtime.account(id).food,
			"hunger": runtime.resident(id).needs.hunger, "name": runtime.resident(id).name,
			"role": runtime.resident(id).role, "coins_col": runtime.resident(id).coins_col,
			"position": runtime.position_of(id)}
	return result

func __positions_are_valid(runtime: RefCounted, ids: Array) -> bool:
	for id in ids:
		var point: Vector3 = runtime.position_of(id)
		if not point.is_finite():
			return false
		if point.x < PLAZA_BOUNDS.x[0] or point.x > PLAZA_BOUNDS.x[1] or \
				point.y < PLAZA_BOUNDS.y[0] or point.y > PLAZA_BOUNDS.y[1] or \
				point.z < PLAZA_BOUNDS.z[0] or point.z > PLAZA_BOUNDS.z[1]:
			return false
	for index in ids.size():
		for other in range(index + 1, ids.size()):
			if runtime.position_of(ids[index]).distance_to(runtime.position_of(ids[other])) < MIN_SPACING:
				return false
	return true

func __identities_are_distinct(runtime: RefCounted, ids: Array) -> bool:
	var names: Array = []
	var roles: Array = []
	for id in ids:
		var person: Dictionary = runtime.resident(id)
		if str(person.get("name", "")).is_empty() or str(person.get("role", "")).is_empty():
			return false
		if names.has(person.name) or roles.has(person.role):
			return false
		names.append(person.name)
		roles.append(person.role)
	return true

func __genesis_metadata(runtime: RefCounted) -> bool:
	var world: Dictionary = runtime.snapshot()
	var origin: Dictionary = world.get("origin", {})
	return origin.get("kind", "") == "new_world_seed" and origin.get("genesis", false) == true \
		and origin.get("migrated_from", "missing") == null \
		and world.get("godot", {}).get("new_world_seed", false) == true

func __reopen_retention(resumed: RefCounted, on_disk: Dictionary, before: Dictionary,
		rest_id: String, eat_id: String) -> bool:
	var saved_residents: Dictionary = {}
	for person in on_disk.get("residents", []):
		saved_residents[person.get("stable_id", "")] = person
	for id in before.keys():
		var person: Dictionary = resumed.resident(id)
		var saved: Dictionary = saved_residents.get(id, {})
		if person.get("name", "") != before[id]["name"] or person.get("role", "") != before[id]["role"]:
			return false
		if int(person.get("coins_col", -1)) != int(before[id]["coins_col"]):
			return false
		if saved.is_empty():
			return false
	if resumed.account(rest_id).energy < float(before[rest_id]["energy"]) + 30.0:
		return false
	if resumed.account(eat_id).food != 0 or resumed.resident(eat_id).needs.hunger < 95.0:
		return false
	return resumed.position_of(rest_id).is_equal_approx(before[rest_id]["position"])
