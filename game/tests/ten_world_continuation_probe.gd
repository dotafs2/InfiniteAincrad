extends SceneTree
## Run prepare, cold, resume, then cold in FOUR SEPARATE engine processes.
## State/serialization evidence only: explicit offline choices, no scene or models.
## Input must be a disposable copy. Each stage preserves prior evidence files.

const Runtime := preload("res://core/town_runtime.gd")
const ROOT_REL := "../tmp/gpt6-sprint/ten-world"
const PENDING_COMMAND := "probe:ten:cold:pending"
var _mode := ""
var _save := ""
var _out := ""
var _checkpoint := ""
var _checks := 0
var _failures: Array = []
var _runtime: RefCounted

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)

func _allowed(path: String) -> bool:
	var root_path := ProjectSettings.globalize_path("res://").path_join(ROOT_REL).simplify_path().replace("\\", "/").to_lower()
	return path.is_absolute_path() and path.replace("\\", "/").simplify_path().to_lower().begins_with(root_path + "/")

func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return a == b
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not _same(a[index], b[index]):
				return false
		return true
	return a == b

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--save="):
			_save = arg.trim_prefix("--save=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--checkpoint="):
			_checkpoint = arg.trim_prefix("--checkpoint=")
	if _mode not in ["prepare", "cold", "resume"] or not _allowed(_save) or not _allowed(_out) \
			or _save == _out or FileAccess.file_exists(_out) \
			or (_mode != "prepare" and (not _allowed(_checkpoint) or _checkpoint in [_save, _out])):
		push_error("Use prepare/cold/resume with distinct new evidence paths inside the ten-world sprint directory")
		quit(2)
		return
	var before_bytes := FileAccess.get_file_as_bytes(_save)
	var input: Variant = JSON.parse_string(before_bytes.get_string_from_utf8())
	if not input is Dictionary or input.get("origin", {}).get("kind") != "new_world_seed":
		push_error("Expected a disposable copy of an independent new world")
		quit(2)
		return
	_runtime = Runtime.new()
	var loaded: Dictionary = _runtime.load_from(_save)
	_check(loaded.get("ok", false), "existing runtime loads the same independent world")
	if not loaded.get("ok", false):
		_finish({})
		return
	var initial: Dictionary = _runtime.snapshot()
	var ids: Array = _runtime.active_ids()
	_check(ids.size() == 10, "all ten saved residents are active")
	_check(FileAccess.get_file_as_bytes(_save) == before_bytes, "loading does not write save bytes")
	_check(_same(initial.residents, input.residents), "all identity/background/need/wallet facts load unchanged")
	_check(_same(initial.life, input.life), "all items/contracts/skills/relations/history load unchanged")
	_check(_same(initial.survival, input.survival), "all food/energy accounts load unchanged")
	_check(_same(initial.origin, input.origin) and _same(initial.seed, input.seed), "original creation provenance remains unchanged")
	if ids.size() != 10:
		_finish({})
		return
	var pending_id: String = ids[2]
	var previous: Dictionary = {}
	if _mode != "prepare":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_checkpoint))
		if not parsed is Dictionary:
			push_error("Cannot read the prior stage's checkpoint")
			quit(2)
			return
		previous = parsed
		_check(previous.get("failure_count", -1) == 0, "prior stage completed successfully")
		_check(previous.get("process_id") != OS.get_process_id(), "this is a different engine process from the checkpoint writer")
		_check(FileAccess.get_sha256(_save) == previous.get("save_sha256"), "prior stage's exact save is continued")
		_check(_same(initial, previous.get("snapshot", {})), "full runtime snapshot survives process exit and reloading")
		_check(ids == previous.get("resident_ids"), "roster order and stable IDs survive process exit")
	if _mode == "prepare":
		_check(initial.life.seq == 0 and initial.godot.pending.is_empty(), "prepare requires untouched genesis on the disposable copy")
		if not _failures.is_empty():
			_finish({})
			return
		var result: Dictionary = _runtime.transaction(_save, func():
			var rest: Dictionary = _runtime.start_action(ids[0], "rest", "probe:ten:cold:rest")
			if not rest.ok:
				return rest
			var meal: Dictionary = _runtime.start_action(ids[1], "eat_ration", "probe:ten:cold:meal")
			if not meal.ok:
				return meal
			var advanced: Dictionary = _runtime.advance(60.0)
			if not advanced.ok:
				return advanced
			return _runtime.start_action(pending_id, "rest", PENDING_COMMAND))
		_check(result.get("ok", false), "normal writer-locked transaction records two offline consequences and unfinished rest")
		_check(_runtime.snapshot().life.seq == 2, "two completed actions enter persistent history")
		_check(_runtime.account(ids[0]).energy == 95 and _runtime.account(ids[1]).food == 0,
			"rest adds 35 energy and meal consumes one actual ration")
		_check(_runtime.pending_job(pending_id).get("command_id") == PENDING_COMMAND,
			"same-world checkpoint retains the original unfinished command")
	elif _mode == "resume":
		_check(initial.life.seq == 2 and _runtime.pending_job(pending_id).get("command_id") == PENDING_COMMAND,
			"resume starts from the original unfinished job after process exit")
		if not _failures.is_empty():
			_finish({})
			return
		var resumed: Dictionary = _runtime.transaction(_save, func(): return _runtime.advance(60.0))
		_check(resumed.get("ok", false) and resumed.get("completed", []).size() == 1,
			"continuing ordinary simulation completes exactly the surviving job")
		var final: Dictionary = _runtime.snapshot()
		_check(final.life.seq == 3 and final.life.events.size() == initial.life.events.size() + 1,
			"history extends by one event instead of resetting or replaying")
		_check(_same(final.life.events.slice(0, initial.life.events.size()), initial.life.events),
			"every prior event is preserved as the exact history prefix")
		_check(_runtime.pending_job(pending_id).is_empty() and _runtime.account(pending_id).energy == 94,
			"resumed rest applies once, including the ordinary 120-second need tick")
		for key in ["items", "contracts", "skills", "accounts", "relations", "inboxes"]:
			_check(_same(final.life[key], initial.life[key]), "%s remains conserved during continuation" % key)
		var replay: Dictionary = _runtime.start_action(pending_id, "rest", PENDING_COMMAND)
		_check(replay.get("ok", false) and _runtime.pending_job(pending_id).is_empty(),
			"replayed original command cannot create a second job")
		_check(_runtime.snapshot().life.seq == 3, "replay cannot mint a duplicate history event")
	else:
		_check(FileAccess.get_file_as_bytes(_save) == before_bytes, "cold verification preserves the exact saved bytes")
		_check(_runtime.pending_job(pending_id) == initial.godot.pending.get(pending_id, {}),
			"cold verification neither completes nor recreates the pending commitment")
	if _mode != "cold":
		_check(_runtime.release_writer(_save).get("ok", false), "stage releases its owned writer before exit")
	_finish({"input_sha256": previous.get("save_sha256", "genesis"), "pending_id": pending_id})

func _finish(extra: Dictionary) -> void:
	var snapshot: Dictionary = _runtime.snapshot() if _runtime != null else {}
	var payload := {"scenario": "ten-world-process-continuation", "mode": _mode,
		"checks": _checks, "failure_count": _failures.size(), "failures": _failures,
		"process_id": OS.get_process_id(), "save_sha256": FileAccess.get_sha256(_save),
		"resident_ids": _runtime.active_ids() if _runtime != null and not snapshot.is_empty() else [],
		"snapshot": snapshot, "extra": extra, "model_calls": 0,
		"evidence_kind": "separate_process_state_continuation", "provenance": "explicit offline actions; no physical scene, gateway or model"}
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var output := FileAccess.open(_out, FileAccess.WRITE)
	if output == null:
		push_error("Cannot create continuation evidence")
		quit(2)
		return
	output.store_string(JSON.stringify(payload, "  "))
	output.close()
	print(JSON.stringify({"mode": _mode, "checks": _checks, "failures": _failures,
		"process_id": OS.get_process_id(), "save_sha256": payload.save_sha256}))
	quit(0 if _failures.is_empty() else 1)
