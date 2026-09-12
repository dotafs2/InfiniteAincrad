extends SceneTree
## Offline acceptance for H36 journey-stall evidence in the REAL playable scene.
##
## What it proves with actual Godot bodies:
##  - an ACTIVE social approach that a real solid obstacle stops produces one world-scoped
##    movement_blocked issue with `journey=approach`, sourced from the host physics position;
##  - the same continuous journey keeps ONE episode identity while it continues (no duplicates and
##    no claim churn), and that episode disappears from the export once the journey resolves;
##  - an unobstructed control resident walking the same kind of journey never creates an episode;
##  - an active public-place trip that a real wall stops produces `journey=place_travel` evidence
##    with the route remainder, and closes when the world itself ends the trip as blocked;
##  - the exported evidence carries physical facts and explicit limits only: no private reason
##    text, no other resident's data, no claim that this is a defect.
##
## Disposable fixture, default Forward+, scripted choices (labelled), real collision and motion.
## The test clock is accelerated (Engine.time_scale) and the run is labelled as such.
const TownScene := preload("res://scenes/town_street.tscn")
const Catalog := preload("res://spatial/town_places.gd")

const MOVER := "fixture:mover"
const BLOCKER_TARGET := "fixture:counterparty"
const CONTROL := "fixture:control"
const TRAVELLER := "fixture:traveller"
const PRIVATE_SENTINEL := "private-reason-must-never-be-exported"

var _scene: Node = null
var _work := ""
var _save := ""
var _game := 0.0
var _frames := 0
var _phase := "boot"
var _checks := 0
var _failures: Array = []
var _notes: Dictionary = {}
var _obstacle: StaticBody3D = null
var _wall: StaticBody3D = null
var _approach_command := ""
var _control_command := ""
var _travel_command := ""
var _opened_episode := ""
var _episode_polls := 0
var _phase_start := 0.0
var _closed_observed := false

func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		print("FAIL ", label)

func _args() -> Dictionary:
	var result: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			result[parts[0]] = parts[1] if parts.size() > 1 else true
	return result

func fixture() -> Dictionary:
	var roster := [
		[MOVER, [2.0, 0.22, 8.0]],
		[BLOCKER_TARGET, [0.0, 0.22, 18.0]],
		[CONTROL, [5.0, 0.22, 8.0]],
		[TRAVELLER, [0.0, 0.10, 44.0]],
	]
	var world := {"schema_version": 2, "world_id": "fixture:town-journey-stall", "fixture": true,
		"elapsed_seconds": 0, "residents": [],
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 6, "capacity": 6, "initial_stock": 6, "produced_total": 0,
			"harvested_total": 0, "growth_remainder_seconds": 0},
		"life": {"seq": 0, "events": [], "contracts": [], "applied": [], "relations": [],
			"inboxes": [], "items": [], "skills": [], "accounts": []},
		"godot": {"schema_version": 1, "mode": "migration_validation", "source_life_seq": 0,
			"source_sha256": "fixture-town-journey-stall", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0.22, 1]}}
	for entry in roster:
		var stable_id: String = entry[0]
		world.residents.append({"stable_id": stable_id, "name": stable_id + " (offline fixture)",
			"role": "fixture", "story": "explicit offline fixture identity",
			"personality": PRIVATE_SENTINEL, "coins_col": 5,
			"needs": {"hunger": 60.0}, "runtime": {"fixture_only": true}})
		world.survival.accounts.append({"resident_id": stable_id, "food": 1, "energy": 60.0})
		world.life.accounts.append({"resident_id": stable_id, "wood": 1, "iron": 0, "kindling": 0, "reserved_col": 0})
		world.godot.positions[stable_id] = entry[1].duplicate()
		world.godot.homes[stable_id] = entry[1].duplicate()
		world.godot.observations[stable_id] = []
	return world

func _initialize() -> void:
	var args := _args()
	_work = str(args.get("work", ""))
	_save = str(args.get("save", ""))
	if _work.is_empty() or _save.is_empty():
		push_error("journey stall acceptance requires --work= and --save=")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_work)
	DirAccess.make_dir_recursive_absolute(_save.get_base_dir())
	var file := FileAccess.open(_save, FileAccess.WRITE)
	if file == null:
		push_error("fixture save is not writable: " + _save)
		quit(2)
		return
	file.store_string(JSON.stringify(fixture(), "", true, true))
	file.close()
	Engine.time_scale = 6.0
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = false
	_scene.scripted_trade = true
	_notes = {}

func town():
	return _scene.town

func events_of(event_type: String) -> Array:
	var result: Array = []
	for event in _scene.town._state.life.events:
		if event is Dictionary and event.get("type", "") == event_type:
			result.append(event)
	return result

func receipts(command_id: String, event_type: String) -> int:
	var total := 0
	for event in events_of(event_type):
		if str(event.get("operation_id", "")) == command_id:
			total += 1
	return total

func _issues() -> Array:
	var snapshot: Dictionary = town().background_gm_snapshot()
	var result: Array = []
	for entry in snapshot.get("evidence", []):
		if entry is Dictionary and entry.get("evidence_kind") == "movement_blocked":
			result.append(entry)
	return result

func _issues_for(resident_id: String) -> Array:
	var result: Array = []
	for entry in _issues():
		if str(entry.get("resident_id", "")) == resident_id:
			result.append(entry)
	return result

func _reported_records_for(resident_id: String) -> Array:
	## Every episode the world ever reported for this resident, open or already closed.
	var result: Array = []
	for record in town()._journey_stall_records():
		if str(record.get("resident_id", "")) == resident_id and bool(record.get("reported", false)):
			result.append(record)
	return result

func _physics_process(delta: float) -> bool:
	_frames += 1
	_game += delta
	if _frames < 6:
		return false
	if _game > 300.0 and _phase != "done":
		check(false, "the bounded journey-stall acceptance exceeded its time budget")
		_finish()
		return true
	match _phase:
		"boot":
			_begin_approach()
		"approach_stall":
			_approach_stall_step()
		"control":
			_control_step()
		"wait_update":
			_wait_update_step()
		"progress_then_stall":
			_progress_then_stall_step()
		"resolve":
			_resolve_step()
		"travel_stall":
			_travel_stall_step()
		"travel_close":
			_travel_close_step()
		"done":
			return true
	return false

func _option(id: String, prefix: String) -> Dictionary:
	for candidate in town().trade_options(id):
		if str(candidate.get("id", "")).begins_with(prefix):
			return candidate
	return {}

func _begin_approach() -> void:
	## Real solid obstruction between the mover and its counterparty: a test-owned box, not a
	## resident, so no resident is moved or teleported by this test.
	_obstacle = StaticBody3D.new()
	_obstacle.name = "FixtureJourneyObstacle"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 3.0, 0.6)
	shape.shape = box
	shape.position = Vector3(1.0, 1.5, 12.0)
	_obstacle.add_child(shape)
	(_scene as Node3D).add_child(_obstacle)
	var option := _option(MOVER, "approach:" + BLOCKER_TARGET)
	check(not option.is_empty(), "the mover is offered a real approach to its counterparty")
	if option.is_empty():
		_finish()
		return
	_approach_command = "fixture-journey:approach:1"
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(MOVER, str(option.id), _approach_command, "opengameagent_fixture"))
	check(started.ok and started.get("pending", false), "the approach journey starts: " + str(started.get("code", "")))
	_phase = "approach_stall"
	_phase_start = _game

func _approach_stall_step() -> void:
	var entries := _issues_for(MOVER)
	if entries.size() == 1:
		var entry: Dictionary = entries[0]
		if _opened_episode.is_empty():
			_opened_episode = str(entry.get("issue_id", ""))
			var facts: Dictionary = entry.get("physical_facts", {})
			_notes.approach_issue = entry.duplicate(true)
			check(str(entry.get("journey", "")) == "approach", "the issue names the approach journey")
			check(not _opened_episode.is_empty(), "the issue carries a stable episode identity")
			check(float(facts.get("no_progress_seconds", 0.0)) >= 8.0,
				"no-progress time is measured, not assumed (%.1f s)" % float(facts.get("no_progress_seconds", 0.0)))
			check(float(facts.get("remaining_distance", 0.0)) > float(facts.get("arrival_radius", 0.0)),
				"the resident is still genuinely short of its meeting point")
			check(str(facts.get("observation_source", "")) == "host_physics_frame_position",
				"the evidence is sourced from the host physics frame")
			var json := JSON.stringify(entry)
			check(not json.contains(PRIVATE_SENTINEL), "no private reason text reaches the export")
			check(not (entry.get("discriminators", {}) as Dictionary).has("defect_confirmed"),
				"the export does not decide that this is a defect")
			check(str((entry.get("discriminators", {}) as Dictionary).get("note", "")).contains("not distinguishable"),
				"the export keeps the explicit limitation wording")
			_phase = "control"
		return
	if _game - _phase_start > 60.0:
		check(false, "no approach stall issue appeared within 60 s of real obstruction (paused=%s status=%s elapsed=%.1f)"
			% [str(_scene.paused), str(_scene.latest), town()._state.godot.elapsed_seconds])
		_finish()

func _control_step() -> void:
	## Unobstructed control: same kind of journey, clear path, must never create an issue.
	if _control_command.is_empty():
		var option := _option(CONTROL, "approach:" + BLOCKER_TARGET)
		check(not option.is_empty(), "the control resident is offered the same approach")
		if option.is_empty():
			_finish()
			return
		_control_command = "fixture-journey:control:1"
		var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(CONTROL, str(option.id), _control_command, "opengameagent_fixture"))
		check(started.ok, "the control journey starts: " + str(started.get("code", "")))
		return
	if receipts(_control_command, "resident_moved") == 1:
		check(_issues_for(CONTROL).is_empty(), "an unobstructed journey never creates a stall issue")
		_phase = "wait_update"
		_phase_start = _game
		return
	if _game - _phase_start > 90.0:
		check(false, "the control resident did not arrive; the fixture control is invalid")
		_finish()

func _wait_update_step() -> void:
	## The same continuing journey must keep one identity while the world keeps exporting it.
	var entries := _issues_for(MOVER)
	check(entries.size() == 1, "the continuing journey exports exactly one issue, never duplicates")
	if entries.size() == 1:
		check(str(entries[0].get("issue_id", "")) == _opened_episode,
			"the continuing journey keeps the same episode identity (update, not resubmission)")
		_episode_polls += 1
		_notes.update_polls = _episode_polls
		if _episode_polls >= 3:
			check(_reported_records_for(MOVER).size() == 1, "the mover has exactly one reported stall episode")
			check(_reported_records_for(CONTROL).is_empty(),
				"the unobstructed control never reports a stall episode even if it briefly slows")
			## Stall -> real progress -> stall, all inside the SAME live command: replace the first
			## obstruction with a second one further along the mover's route.
			_swap_obstacles()
			_phase = "progress_then_stall"
			_phase_start = _game
			return
	if _game - _phase_start > 60.0:
		check(false, "the open episode could not be polled three times while the journey continued")
		_finish()

func _remove_obstacle() -> void:
	if _obstacle != null and is_instance_valid(_obstacle):
		_obstacle.queue_free()
	_obstacle = null

func _swap_obstacles() -> void:
	## Remove the first real obstruction and place a second one 3 m further along the route, so the
	## mover genuinely advances (measurable progress) and then meets a new physical obstacle before
	## its command ends.
	_remove_obstacle()
	_obstacle = StaticBody3D.new()
	_obstacle.name = "FixtureJourneyObstacle2"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 3.0, 0.6)
	shape.shape = box
	shape.position = Vector3(0.9, 1.5, 15.0)
	_obstacle.add_child(shape)
	(_scene as Node3D).add_child(_obstacle)

func _progress_then_stall_step() -> void:
	## Two honest sub-stages of one live command: real progress (issue hidden), then a second real
	## obstruction (same issue id visible again).
	var entries := _issues_for(MOVER)
	var records := _reported_records_for(MOVER)
	if records.is_empty():
		_finish()
		return
	var record: Dictionary = records[0]
	if _stage == "await_progress":
		if not _single_record_checked:
			_single_record_checked = true
			check(records.size() == 1, "one reported record exists for the whole live command")
		if not _progress_evidence.has("position_at_first_stall"):
			var observed: Array = record.get("observed_position", [])
			if observed.size() == 3:
				_progress_evidence = {"position_at_first_stall": observed.duplicate(),
					"best_progress_before": float(record.get("best_progress", -1.0))}
		if entries.is_empty() and str(record.get("status", "")) == "closed":
			## The mover really advanced, so the export no longer claims a stall: honest visibility.
			_progress_evidence["hidden_while_progressing"] = true
			_progress_evidence["close_reason"] = str(record.get("close_reason", ""))
			_progress_evidence["best_progress_after"] = float(record.get("best_progress", -1.0))
			check(str(record.get("close_reason", "")) == "progress_resumed",
				"the first stall closed because real progress resumed")
			check(float(record.get("best_progress", 1e9)) <= float(_progress_evidence.get("best_progress_before", 0.0)) - 0.05,
				"the progress is measurable, not just a counter reset")
			_notes.progress_mid_journey = _progress_evidence.duplicate(true)
			_stage = "await_restall"
		elif _game - _phase_start > 90.0:
			check(false, "the mover did not make measurable progress after the first obstruction was removed")
			_finish()
		return
	if entries.size() == 1:
		var entry: Dictionary = entries[0]
		var facts: Dictionary = entry.get("physical_facts", {})
		_notes.second_stall_issue = entry.duplicate(true)
		check(str(entry.get("issue_id", "")) == _opened_episode,
			"the second stall of the same live command reuses the same issue identity: " + str(entry.get("issue_id", "")))
		check(float(facts.get("no_progress_seconds", 0.0)) >= 8.0,
			"the second stall measures fresh no-progress time (%.1f s)" % float(facts.get("no_progress_seconds", 0.0)))
		check(float(facts.get("progress_epsilon", -1.0)) == 0.05,
			"the exported progress threshold is the detector's real 0.05, not a silent zero")
		check(_moved_between_stalls(facts.get("observed_position", [])),
			"the second stall reports the genuinely advanced position")
		check(_reported_records_for(MOVER).size() == 1,
			"no duplicate reported history entry was created for the same command")
		_dump_mid_snapshot()
		_remove_obstacle()
		_phase = "resolve"
		_phase_start = _game
		return
	if _game - _phase_start > 90.0:
		check(false, "the same command did not stall a second time behind the second obstruction")
		_finish()

var _stage := "await_progress"
var _progress_evidence: Dictionary = {}
var _single_record_checked := false

func _dump_mid_snapshot() -> void:
	## A real NON-EMPTY producer snapshot, written while the journey issue is genuinely open, for
	## the independent consumer check against gm_runner's loading/preparation code.
	var args := _args()
	var out := str(args.get("out", ""))
	if out.is_empty():
		return
	var path := out.get_base_dir().path_join("gm-snapshot-mid.json")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "the mid-run producer snapshot could not be written")
		return
	file.store_string(JSON.stringify(town().background_gm_snapshot(), "", true, true))
	file.close()
	_notes.mid_snapshot = path

func _moved_between_stalls(second_position: Array) -> bool:
	var first: Array = _progress_evidence.get("position_at_first_stall", [])
	if first.size() != 3:
		return false
	return Vector2(float(second_position[0]) - float(first[0]), float(second_position[2]) - float(first[2])).length() > 1.0

func _resolve_step() -> void:
	if receipts(_approach_command, "resident_moved") == 1:
		check(_issues_for(MOVER).is_empty(), "the resolved journey is no longer exported as an open issue")
		var record: Dictionary = _reported_records_for(MOVER)[0]
		_notes.approach_closed = {"status": record.get("status"), "reason": record.get("close_reason", "")}
		check(str(record.get("status", "")) == "closed", "the resolved episode is closed, not left open")
		check(str(record.get("close_reason", "")) in ["progress_resumed", "journey_released"],
			"the closed episode keeps one explicit close reason: " + str(record.get("close_reason", "")))
		check(receipts(_approach_command, "resident_moved") == 1, "the approach resolved with exactly one receipt")
		_begin_travel()
		return
	if _game - _phase_start > 90.0:
		check(false, "the mover did not arrive after the obstruction was removed")
		_finish()

func _begin_travel() -> void:
	## Public-place trip blocked by a real wall across the paved street: the same evidence channel
	## must carry the journey=place_travel variant, and the world's own blocked close must end it.
	_wall = StaticBody3D.new()
	_wall.name = "FixtureTravelWall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 3.0, 0.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 48.0)
	_wall.add_child(shape)
	(_scene as Node3D).add_child(_wall)
	## The traveller learns the place the honest way: reading the notice in range with line of sight.
	town().transaction(_save, func(): return town().observe_public_places(TRAVELLER, true, []))
	var option := {}
	for candidate in town().trade_options(TRAVELLER):
		if str(candidate.get("id", "")) == "place:travel:planted_commons":
			option = candidate
			break
	check(not option.is_empty(), "the traveller knows the planted commons")
	if option.is_empty():
		_finish()
		return
	_travel_command = "fixture-journey:travel:1"
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(TRAVELLER, str(option.id), _travel_command, "opengameagent_fixture"))
	check(started.ok and started.get("pending", false), "the public trip starts: " + str(started.get("code", "")))
	_phase = "travel_stall"
	_phase_start = _game

func _travel_stall_step() -> void:
	var entries := _issues_for(TRAVELLER)
	if entries.size() == 1 and not _closed_observed:
		var entry: Dictionary = entries[0]
		var facts: Dictionary = entry.get("physical_facts", {})
		_notes.travel_issue = entry.duplicate(true)
		check(str(entry.get("journey", "")) == "place_travel", "the issue names the public-place journey")
		check(str(entry.get("place_id", "")) == "planted_commons", "the issue names the public destination")
		check(float(facts.get("remaining_route_m", -1.0)) > 0.0,
			"the physical facts carry the remaining verified route (%.1f m)" % float(facts.get("remaining_route_m", -1.0)))
		check(str(facts.get("progress_measure", "")).contains("route_remaining"),
			"the progress measure is stated so an oscillation cannot look like progress")
		_phase = "travel_close"
		_phase_start = _game
		return
	if _game - _phase_start > 60.0:
		check(false, "no public-trip stall issue appeared behind the real wall")
		_finish()

func _travel_close_step() -> void:
	if receipts(_travel_command, "travel_blocked") == 1:
		_closed_observed = true
		check(_issues_for(TRAVELLER).is_empty(), "a world-closed trip is no longer exported as an open issue")
		check(receipts(_travel_command, "place_visited") == 0, "the blocked trip produced no arrival receipt")
		var travel_record: Dictionary = {}
		for record in town()._journey_stall_records():
			if str(record.get("resident_id", "")) == TRAVELLER:
				travel_record = record
		_notes.travel_closed = {"status": travel_record.get("status"), "reason": travel_record.get("close_reason", "")}
		check(str(travel_record.get("status", "")) == "closed", "the blocked journey's episode is closed")
		check(receipts(_travel_command, "travel_blocked") == 1, "the blocked trip closed exactly once")
		_verify_export_boundaries()
		_finish()
		return
	if _game - _phase_start > 120.0:
		check(false, "the blocked public trip did not close within its bounded window (paused=%s status=%s job=%s)"
			% [str(_scene.paused), str(_scene.latest), str(town().pending_job(TRAVELLER))])
		_finish()

func _verify_export_boundaries() -> void:
	var snapshot: Dictionary = town().background_gm_snapshot()
	var boundaries: Dictionary = snapshot.get("boundaries", {})
	_notes.export_boundaries = boundaries
	check(boundaries.get("contains_private_reply_reason", true) == false, "the export declares no private reply reasons")
	check(boundaries.get("contains_other_resident_memories", true) == false, "the export declares no other resident's memories")
	check(boundaries.get("consumed_by_npc_model", true) == false, "the export is not consumed by any NPC model")
	var json := JSON.stringify(snapshot)
	check(not json.contains(PRIVATE_SENTINEL), "the whole snapshot carries no private fixture reason text")
	## Both journeys are resolved/closed by now, so the export must be empty of open issues again:
	## the evidence channel reports current physical stalls, not a permanent accusation.
	check(int(snapshot.get("counts", {}).get("issues", -1)) == 0,
		"closed journeys leave no open issue in the export")
	_notes.final_issue_count = snapshot.get("counts", {}).get("issues", -1)
	_notes.final_snapshot_evidence = snapshot.get("evidence", [])

func _finish() -> void:
	_phase = "done"
	var evidence := {"suite": "town_journey_stall", "checks": _checks, "failures": _failures,
		"failure_count": _failures.size(), "time_scale": Engine.time_scale as float,
		"notes": _notes, "model_calls": 0, "paid_calls": 0}
	var args := _args()
	var out := str(args.get("out", ""))
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(evidence, "", true, true))
			file.close()
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)
