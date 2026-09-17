extends "res://tests/town_trade_acceptance.gd"
## Bounded episode shutdown, headless and fixture-only. No provider, no paid call.
##
## The real host (`res://spatial/town_street.gd`) is instantiated and its own
## cutoff/admission/wait code is driven frame by frame; only the two effects that
## need art, the HUD and a real engine quit are replaced, exactly as the existing
## probes replace them. The real `res://agents/town_turns.gd` owns the requests.
##
## Covered: a delayed fixture reply crossing the cutoff is still applied and
## persisted exactly once; a never-returning fixture request ends the episode
## within its finite bound as an honest unresolved failure that preserves the
## pending record; an episode with nothing in flight stops promptly and a resident
## that becomes due on the boundary frame is never admitted.
##
## Every stage releases what it allocated before the next one starts, so the run
## exits with no fixture-owned object, CanvasItem or resource leak.

const Turns = preload("res://agents/town_turns.gd")

## Fixture decisions: one offered action, no world side effect.
class WaitTown extends "res://core/town_baking.gd":
	## Set at the very end of a scenario so unwinding the never-returning fixture
	## request cannot write: the fixture save was already deleted and the asserted
	## pending receipt must not be touched.
	var fixture_refuses_writes := false
	func transaction(path: String, operation: Callable) -> Dictionary:
		if fixture_refuses_writes:
			return {"ok": false, "code": "fixture_write_refused"}
		return super(path, operation)
	func trade_options(_id: String) -> Array:
		return [{"id": "wait", "label": "Wait", "action": "wait"}]
	func submit_trade(_id: String, option_id: String, _command_id: String, _provenance: String = "local_rule_policy", _speech: String = "") -> Dictionary:
		return {"ok": option_id == "wait", "code": "wait" if option_id == "wait" else "invalid_option"}

class DelayedBrain extends Node:
	var calls := 0
	var frames_until_reply := 1
	func propose(_view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		var waited := 0
		while waited < frames_until_reply:
			await get_tree().process_frame
			waited += 1
		return {"ok": true, "decision": {"action": "a0", "reason": "fixture shutdown decision"},
			"command_id": "fixture-shutdown-%d" % calls, "provenance": "opengameagent_fixture"}

class ShutdownScene extends "res://spatial/town_street.gd":
	var captures := 0
	var capture_reason := ""
	var capture_exit_code := -1
	var capture_status: Dictionary = {}
	var capture_owed: Array = []
	var capture_evidence: Dictionary = {}
	func _refresh() -> void:
		pass
	func _capture_town() -> void:
		captures += 1
		capture_reason = capture_shutdown_reason
		capture_exit_code = shutdown_exit_code
		capture_evidence = _shutdown_evidence()
		capture_owed = capture_evidence.resident_requests_owed
		for id in town.active_ids():
			capture_status[id] = str(town._state.godot.get("resident_turns", {}).get(id, {}).get("status", ""))
		paused = true

const EMBER := "fictional:ember"
const BIRCH := "fictional:birch"
const FRAME_SECONDS := 0.02

var _blocked := false

func _scratch_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shutdown-scratch="):
			return argument.trim_prefix("--shutdown-scratch=")
	return "user://town-shutdown"

func _fixture(name: String) -> String:
	var directory := _scratch_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory.path_join("shutdown-%s-%d.json" % [name, Time.get_ticks_usec()])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		# Environment failure, reported separately from any shutdown verdict.
		_blocked = true
		print(JSON.stringify({"suite": "town_shutdown", "status": "blocked",
			"reason": "fixture_save_unwritable", "path": path, "checks": checks, "failures": failures}))
		quit(1)
		return ""
	file.store_string(JSON.stringify(trade_fixture(), "", true, true))
	file.close()
	return path

func _stage(name: String, wait_limit: float) -> Dictionary:
	var path := _fixture(name)
	if _blocked:
		return {}
	var town := WaitTown.new()
	var loaded: Dictionary = town.load_from(path)
	check(loaded.ok, name + ": fixture world loads")
	if not loaded.ok:
		return {}
	var turns := Turns.new()
	turns.town = town
	turns.save_path = path
	turns.max_parallel = 1
	turns.shutdown_wait_limit = wait_limit
	var scene := ShutdownScene.new()
	scene.status = Label.new()
	scene.gateway_mode = true
	scene.paused = false # `_ready` does this for a capture run; this fixture skips `_ready`.
	scene.capture_dir = path.get_base_dir()
	scene.capture_seconds = 0.05
	scene.town = town
	scene.model_turns = turns
	root.add_child(turns)
	return {"path": path, "town": town, "turns": turns, "scene": scene}

func _attach_brain(stage: Dictionary, id: String, frames_until_reply: int) -> DelayedBrain:
	var brain := DelayedBrain.new()
	brain.frames_until_reply = frames_until_reply
	stage.turns.add_child(brain)
	stage.turns.brains[id] = brain
	return brain

func _release(stage: Dictionary) -> void:
	## Release exactly what this stage allocated: the in-tree turn module with its
	## controller brains, and the host scene with its orphan Label. The fixture save
	## is neither recreated nor rewritten here.
	if stage.is_empty():
		return
	var scene = stage.get("scene", null)
	var turns = stage.get("turns", null)
	stage.clear()
	if turns != null:
		if is_instance_valid(turns):
			var parent: Node = turns.get_parent()
			if parent != null:
				parent.remove_child(turns)
			turns.free()
	if scene != null and is_instance_valid(scene):
		var label = scene.status
		scene.status = null
		if label != null and is_instance_valid(label):
			label.free()
		scene.free()

func _drive(stage: Dictionary, limit: int) -> int:
	## Frame stepping only: the host's real `_process` decides every stop.
	var scene = stage.scene
	var used := 0
	while scene.captures == 0 and used < limit:
		scene._process(FRAME_SECONDS)
		used += 1
		if scene.captures == 0:
			await process_frame
	return used

func _append_notice(town, id: String) -> void:
	## One real incoming event, so this resident becomes due on the next admission
	## probe without touching the world clock.
	var life: Dictionary = town._state.life
	life.seq = int(life.seq) + 1
	life.events.append({"seq": life.seq, "event_id": "life_event_shutdown_%d" % life.seq, "type": "ask_help",
		"actor_id": id, "subject_id": id, "recipient_ids": [id], "text": "fixture notice",
		"operation_id": "fixture:shutdown-notice", "request_id": "godot_help:fixture:shutdown-notice",
		"source": "opengameagent_fixture"})

func _legacy_next_resident(turns) -> String:
	## Probe only: the pre-change admission rule transcribed from the discarded
	## ordering, i.e. the same resident `ready_resident()` would have returned with
	## admission still open. It is never the implementation under test.
	if turns.inflight.size() >= turns.max_parallel:
		return ""
	var residents: Array = turns.town.active_ids()
	for offset in residents.size():
		var id: String = residents[(turns._next_resident_index + offset) % residents.size()]
		var record: Dictionary = turns._record(id)
		if not turns.brains.has(id) or turns.inflight.has(id) or turns._requires_review(record, id) or turns._replan_cooling(record):
			continue
		if not turns.town.pending_job(id).is_empty() and turns.town.blocked_material_episode(id).is_empty():
			continue
		if record.is_empty() or turns._own_seq(id) > int(record.get("seen_seq", 0)) or turns.town._state.godot.elapsed_seconds >= float(record.get("next_due", INF)):
			return id
	return ""

func _legacy_capture_due(scene, elapsed: float, started: bool) -> bool:
	## Probe only: the discarded timeout trigger
	## `(capture_age > capture_timeout) and not capture_started and not (gateway_mode and busy)`
	## for the unpaused, non-repair case these fixtures use, evaluated on the elapsed
	## value a frame produced and the `capture_started` value that frame entered with.
	return elapsed > scene.capture_seconds and not started \
		and not (scene.gateway_mode and scene.model_turns.busy)

func _scenario_delayed_reply() -> Dictionary:
	var stage := _stage("delayed", 5.0)
	if stage.is_empty():
		return {}
	var town = stage.town
	var turns = stage.turns
	var scene = stage.scene
	var ember_brain := _attach_brain(stage, EMBER, 4)
	var birch_brain := _attach_brain(stage, BIRCH, 1)
	var used := await _drive(stage, 40)
	check(scene.captures == 1 and used < 40, "delayed reply: the episode stops once")
	check(turns.admission_closed() and turns.admission_closed_reason == "episode_duration_elapsed",
		"delayed reply: the duration cutoff closed admission")
	check(scene.capture_reason == "episode_duration_elapsed", "delayed reply: the episode is not reported as unresolved")
	check(scene.capture_exit_code == 0, "delayed reply: a fully applied stop exits cleanly")
	check(scene.capture_status.get(EMBER, "") == "settled", "delayed reply: the started reply is applied before capture")
	check(not turns.shutdown_wait_timed_out and turns.shutdown_wait_seconds > 0.0 and turns.shutdown_wait_seconds < turns.shutdown_wait_limit,
		"delayed reply: the host waited inside its finite bound")
	check(scene.capture_evidence.get("resolved", false) == true and scene.capture_evidence.get("in_flight", []).is_empty(),
		"delayed reply: shutdown evidence reports a resolved stop")
	check(scene.capture_owed.is_empty(), "delayed reply: nothing is left owed")
	var record: Dictionary = turns._record(EMBER)
	check(record.get("status", "") == "settled" and record.get("history", []).size() == 1,
		"delayed reply: the applied decision is recorded exactly once")
	check(record.get("request_id", "") == "turn:%s:0:1" % EMBER and ember_brain.calls == 1,
		"delayed reply: one durable request owns one applied reply")
	var archive: Dictionary = town._state.godot.get("resident_archive", {}).get("entries", {})
	check(archive.size() == 1 and str(archive.get(record.get("request_id", ""), {}).get("application", {}).get("status", "")) == "settled",
		"delayed reply: one authoritative archive entry records the real application")
	check(turns.ready_resident() == "", "delayed reply: a closed episode admits no next resident")
	check(_legacy_next_resident(turns) == BIRCH, "delayed reply: the discarded ordering would have started a new paid decision here")
	var refused: Dictionary = await turns.step(BIRCH)
	check(not refused.ok and refused.get("code", "") == "admission_closed" and birch_brain.calls == 0,
		"delayed reply: the next decision is refused without reaching a controller")
	check(scene.validation_decisions_started == 1, "delayed reply: only the pre-cutoff decision was spent")
	town.release_writer(stage.path)
	var cold := WaitTown.new()
	check(cold.load_from(stage.path).ok, "delayed reply: the shutdown save stays loadable")
	check(cold._state.godot.get("resident_turns", {}).get(EMBER, {}).get("status", "") == "settled",
		"delayed reply: the applied reply is durable")
	cold.release_writer(stage.path)
	cold = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))
	var summary := {"scenario": "delayed_reply", "frames": used, "waited_seconds": turns.shutdown_wait_seconds,
		"capture_reason": scene.capture_reason, "exit_code": scene.capture_exit_code}
	_release(stage)
	town = null
	return summary

func _scenario_unresolved_reply() -> Dictionary:
	var stage := _stage("unresolved", 0.1)
	if stage.is_empty():
		return {}
	var town = stage.town
	var turns = stage.turns
	var scene = stage.scene
	var ember_brain := _attach_brain(stage, EMBER, 1073741824)
	var used := await _drive(stage, 40)
	check(scene.captures == 1 and used < 40, "unresolved reply: the finite bound still ends the episode")
	check(scene.capture_reason == "episode_duration_elapsed_unresolved", "unresolved reply: the capture names the owed reply")
	check(scene.capture_exit_code == 3, "unresolved reply: the engine states an honest nonzero exit")
	check(turns.shutdown_wait_timed_out and turns.shutdown_wait_seconds >= turns.shutdown_wait_limit,
		"unresolved reply: the bound, not the provider, ended the wait")
	check(turns.busy and ember_brain.calls == 1, "unresolved reply: the started request is still owed")
	check(scene.capture_status.get(EMBER, "") == "pending", "unresolved reply: the record keeps its real pending status")
	check(scene.capture_owed.size() == 1 and str(scene.capture_owed[0].request_id) == "turn:%s:0:1" % EMBER,
		"unresolved reply: the owed request is named")
	check(scene.capture_evidence.get("resolved", false) == false and scene.capture_evidence.get("in_flight", []).size() == 1,
		"unresolved reply: evidence never claims a resolved stop")
	check(not _legacy_capture_due(scene, scene.capture_age, false),
		"unresolved reply: the discarded ordering could not have stopped here at all")
	town.release_writer(stage.path)
	var cold := WaitTown.new()
	check(cold.load_from(stage.path).ok, "unresolved reply: the save stays loadable")
	var cold_record: Dictionary = cold._state.godot.get("resident_turns", {}).get(EMBER, {})
	check(cold_record.get("status", "") == "pending" and cold_record.get("request_id", "") == "turn:%s:0:1" % EMBER,
		"unresolved reply: the owed request survives as one pending record")
	check(not cold_record.has("accepted_reply"), "unresolved reply: no reply is invented for it")
	check(cold._state.godot.get("resident_archive", {}).get("entries", {}).is_empty(),
		"unresolved reply: nothing is archived as settled")
	cold.release_writer(stage.path)
	cold = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))
	# Unwind the never-returning fixture request so no suspended coroutine outlives
	# the stage. From here the fixture world refuses every write, so the wrapper's
	# late reply can neither recreate the deleted fixture save nor change the pending
	# receipt asserted above.
	town.fixture_refuses_writes = true
	for brain in turns.brains.values():
		brain.frames_until_reply = 0
	await process_frame
	await process_frame
	var summary := {"scenario": "unresolved_reply", "frames": used, "waited_seconds": turns.shutdown_wait_seconds,
		"capture_reason": scene.capture_reason, "exit_code": scene.capture_exit_code}
	_release(stage)
	town = null
	return summary

func _scenario_boundary_frame() -> Dictionary:
	var stage := _stage("boundary", 5.0)
	if stage.is_empty():
		return {}
	var town = stage.town
	var turns = stage.turns
	var scene = stage.scene
	turns.brains.clear()
	town._state.godot.resident_turns = {}
	for id in town.active_ids():
		town._state.godot.resident_turns[id] = {"status": "settled", "seen_seq": 0, "next_due": 100000.0, "history": []}
	var ember_brain := _attach_brain(stage, EMBER, 1)
	scene._process(FRAME_SECONDS)
	await process_frame
	scene._process(FRAME_SECONDS)
	await process_frame
	check(scene.captures == 0 and not turns.admission_closed(), "boundary frame: the episode is still open before the duration")
	check(turns.ready_resident() == "", "boundary frame: no resident is due yet")
	_append_notice(town, EMBER)
	scene._process(FRAME_SECONDS)
	await process_frame
	check(scene.captures == 1, "boundary frame: an episode with nothing in flight stops on the boundary frame")
	check(turns.admission_closed() and turns.admission_closed_reason == "episode_duration_elapsed",
		"boundary frame: admission closes on the boundary frame")
	check(turns.ready_resident() == "", "boundary frame: the freshly due resident is not admitted")
	check(_legacy_next_resident(turns) == EMBER, "boundary frame: the discarded ordering would have chosen this resident")
	check(ember_brain.calls == 0 and scene.validation_decisions_started == 0,
		"boundary frame: no controller call and no decision spent")
	check(scene.capture_reason == "episode_duration_elapsed" and scene.capture_exit_code == 0,
		"boundary frame: a prompt empty stop stays a clean capture")
	check(turns.shutdown_wait_seconds == 0.0 and not turns.shutdown_wait_timed_out,
		"boundary frame: nothing in flight means no waiting")
	check(scene.capture_evidence.get("resolved", false) == true and scene.capture_owed.is_empty(),
		"boundary frame: shutdown evidence is truthful for an empty stop")
	check(_legacy_capture_due(scene, FRAME_SECONDS * 3.0, false),
		"boundary frame: the discarded empty-stop trigger agrees on the boundary frame")
	town.release_writer(stage.path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))
	var summary := {"scenario": "boundary_frame", "frames": 3, "capture_reason": scene.capture_reason,
		"exit_code": scene.capture_exit_code}
	_release(stage)
	town = null
	return summary

func run() -> void:
	var delayed := await _scenario_delayed_reply()
	if _blocked:
		return
	var unresolved := await _scenario_unresolved_reply()
	if _blocked:
		return
	var boundary := await _scenario_boundary_frame()
	print(JSON.stringify({"suite": "town_shutdown", "checks": checks, "failures": failures, "paid_calls": 0,
		"scenarios": [delayed, unresolved, boundary]}))
	quit(0 if failures == 0 else 1)
