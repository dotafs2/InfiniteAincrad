extends SceneTree
## Focused UNSCALED (Engine.time_scale 1.0) real-physics regression for the reviewed
## terminal-route defect and the public-place semantics:
##  1. one long road journey (market -> caravan rest) finishes EXACTLY once at the true 1.35 m/s,
##     with no walk back to a road node behind the resident once the final point is close;
##  2. a mid-approach copy of the real save resumes in a fresh scene, keeps the same command and
##     target, walks only the short remaining distance and still produces exactly one receipt;
##  3. destination semantics stay split: a pending place TRIP never answers the fixed
##     home/work-station lookup that repair and workstation callers use, a pending place REST
##     answers only its own rest action at the public point, and that point is never a workstation.
## Disposable two-resident fixture, default Forward+, no model call, no gateway, no paid provider.
const TownScene := preload("res://scenes/town_street.tscn")
const Catalog := preload("res://spatial/town_places.gd")
const Town := preload("res://core/town_places.gd")

const READER := "fixture:innkeeper"
const NEIGHBOUR := "fixture:smith"
const WALK_SPEED := 1.35
const PLACE := "caravan_rest"
const COMMAND := "fixture-places:route:1"

var _scene: Node = null
var _work := ""
var _save := ""
var _world_save := ""
var _game := 0.0
var _frames := 0
var _phase := "boot"
var _checks := 0
var _failures: Array = []
var _notes: Dictionary = {}
var _start_game := 0.0
var _start_pos := Vector3.ZERO
var _max_speed := 0.0
var _walked := 0.0
var _last_pos := Vector3.ZERO
var _min_target_distance := INF
var _closest_approach_game := 0.0
var _backtrack_after_approach := 0.0
var _target := Vector3.INF
var _copied := ""
var _copy_game := 0.0
var _copy_distance := INF
var _resume_start := Vector3.ZERO
var _resume_walked := 0.0

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
	var roster := [[READER, [2.0, 0.22, 8.0]], [NEIGHBOUR, [0.0, 0.22, 6.0]]]
	var world := {"schema_version": 2, "world_id": "fixture:town-places-route", "fixture": true,
		"elapsed_seconds": 0, "residents": [],
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 6, "capacity": 6, "initial_stock": 6, "produced_total": 0,
			"harvested_total": 0, "growth_remainder_seconds": 0},
		"life": {"seq": 0, "events": [], "contracts": [], "applied": [], "relations": [],
			"inboxes": [], "items": [], "skills": [], "accounts": []},
		"godot": {"schema_version": 1, "mode": "migration_validation", "source_life_seq": 0,
			"source_sha256": "fixture-town-places-route", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0.22, 1]}}
	for entry in roster:
		var stable_id: String = entry[0]
		world.residents.append({"stable_id": stable_id, "name": stable_id + " (offline fixture)",
			"role": "fixture", "story": "explicit offline fixture identity",
			"personality": "explicit offline fixture", "coins_col": 5,
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
		push_error("route acceptance requires --work= and --save=")
		quit(2)
		return
	_world_save = _save
	DirAccess.make_dir_recursive_absolute(_work)
	DirAccess.make_dir_recursive_absolute(_save.get_base_dir())
	var file := FileAccess.open(_save, FileAccess.WRITE)
	if file == null:
		push_error("fixture save is not writable: " + _save)
		quit(2)
		return
	file.store_string(JSON.stringify(fixture(), "", true, true))
	file.close()
	Engine.time_scale = 1.0
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = false
	_scene.scripted_trade = true
	_notes = {}

func town() -> Town:
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

func _physics_process(delta: float) -> bool:
	_frames += 1
	_game += delta
	if _frames < 4:
		return false
	if _game > 600.0 and _phase != "done":
		check(false, "the bounded unscaled run exceeded its time budget")
		_finish()
		return true
	match _phase:
		"boot":
			_wait_for_notice()
		"walk":
			_walk_step(false)
		"swap":
			_swap()
		"resume":
			_walk_step(true)
		"semantics":
			_semantics()
		"done":
			return true
	return false

func _wait_for_notice() -> void:
	if _game < 2.0:
		return
	if town().known_place_ids(READER).size() != Catalog.place_ids().size():
		check(false, "the reader learned every public place in real time: " + str(town().known_place_ids(READER)))
		_finish()
		return
	var option := {}
	for candidate in town().trade_options(READER):
		if candidate.get("id") == "place:travel:" + PLACE:
			option = candidate
			break
	if option.is_empty():
		check(false, "the reader is offered the caravan rest")
		_finish()
		return
	_target = town().place_point(PLACE, READER)
	_start_pos = town().position_of(READER)
	_last_pos = _start_pos
	_start_game = _game
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(READER, str(option.id), COMMAND, "opengameagent_fixture"))
	check(started.ok, "the long trip starts: " + str(started.get("code", "")))
	check(_target.distance_to(Catalog.slot_point(PLACE, 0)) <= 0.05, "the trip target is the resident's own authored slot")
	_notes.route = {"graph_length_m": snappedf(Catalog.road_length(PLACE, _start_pos, 0), 0.01)}
	_phase = "walk"

func _walk_step(resumed: bool) -> void:
	var position := town().position_of(READER)
	var body: CharacterBody3D = _scene.bodies.get(READER)
	if is_instance_valid(body):
		_max_speed = maxf(_max_speed, Vector2(body.velocity.x, body.velocity.z).length())
	var moved := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length()
	if resumed:
		_resume_walked += moved
	else:
		_walked += moved
	_last_pos = position
	var distance := position.distance_to(_target)
	if distance < _min_target_distance:
		_min_target_distance = distance
		_closest_approach_game = _game
	elif _min_target_distance <= 2.5 and distance > _min_target_distance + 1.0:
		## After getting close to its own point, a resident must never walk away from it again:
		## the reviewed defect rebuilt the road behind the body and did exactly this.
		_backtrack_after_approach = maxf(_backtrack_after_approach, distance - _min_target_distance)
	if not resumed and receipts(COMMAND, "place_visited") == 0 and distance <= 4.0 and _copied.is_empty():
		_copy_mid_approach(position, distance)
	if receipts(COMMAND, "place_visited") == 1:
		_finish_walk(resumed)
		return
	if receipts(COMMAND, "travel_blocked") == 1:
		check(false, "the long trip was closed as blocked instead of arriving: " + str(town().place_travel_blocked(READER)))
		_finish()
		return
	if _game - _start_game > 240.0:
		check(false, "the trip did not arrive in real time: " + str(town().position_of(READER)))
		_finish()

func _copy_mid_approach(position: Vector3, distance: float) -> void:
	_copied = _work.path_join("mid-approach.json")
	DirAccess.copy_absolute(_save, _copied)
	_copy_game = _game
	_copy_distance = distance
	_notes.mid_approach = {"distance_m": snappedf(distance, 0.02), "walked_m": snappedf(_walked, 0.01),
		"graph_length_m": _notes.route.graph_length_m}
	var copied := Town.new()
	var loaded: Dictionary = copied.load_from(_copied)
	var job: Dictionary = copied.pending_job(READER) if loaded.ok else {}
	check(loaded.ok and str(job.get("command_id", "")) == COMMAND and str(job.get("place_id", "")) == PLACE,
		"the mid-approach bytes keep the same pending trip and target")
	var saved_target: Array = job.get("target_position", [0, 0, 0])
	var saved_point := Vector3(float(saved_target[0]), float(saved_target[1]), float(saved_target[2]))
	check(saved_point.distance_to(_target) <= 0.05,
		"the copied trip keeps the exact saved target")
	_scene.paused = true
	_scene.queue_free()
	_phase = "swap"

func _swap() -> void:
	## The fresh scene reads its save path from the command line, so the copied bytes are installed
	## at that exact path; the copy stays as an untouched artifact beside the run.
	if FileAccess.file_exists(_world_save + ".writer-lock"):
		return
	DirAccess.copy_absolute(_copied, _world_save)
	_save = _world_save
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = false
	_scene.scripted_trade = true
	_resume_start = _scene.town.position_of(READER)
	_target = _scene.town.place_point(PLACE, READER)
	check(_scene.town.pending_job(READER).get("place_id", "") == PLACE, "the resumed scene holds the same pending trip")
	_phase = "resume"

func _finish_walk(resumed: bool) -> void:
	var position := town().position_of(READER)
	var walked := _resume_walked if resumed else _walked
	var record := {"resumed": resumed, "walked_m": snappedf(walked, 0.01),
		"target_distance_m": snappedf(position.distance_to(_target), 0.02),
		"max_speed_mps": snappedf(_max_speed, 0.001),
		"receipts": receipts(COMMAND, "place_visited"),
		"backtrack_after_approach_m": snappedf(_backtrack_after_approach, 0.02)}
	if resumed:
		_notes.route.resumed = record
		check(_resume_walked <= 12.0, "the resumed walk covered only the remaining metres (%.2f m)" % _resume_walked)
		check(_resume_walked >= 0.5, "the resumed trip really walked the rest of the way (%.2f m)" % _resume_walked)
		check(receipts(COMMAND, "place_visited") == 1, "exactly one arrival receipt across the copy")
		check(receipts(COMMAND, "travel_blocked") == 0, "the resumed trip was not closed as blocked")
		check(town().pending_job(READER).is_empty(), "the trip is closed after its single arrival")
	else:
		_notes.route.direct = record
		check(receipts(COMMAND, "place_visited") == 1, "exactly one arrival receipt for the long trip")
		check(_backtrack_after_approach <= 1.0,
			"no walk back to a road node after the final approach (max back-off %.2f m)" % _backtrack_after_approach)
		check(absf(_max_speed - WALK_SPEED) < 0.02, "the mover used the original 1.35 m/s (%.3f)" % _max_speed)
		check(_walked <= float(_notes.route.graph_length_m) * 1.6,
			"the body did not wander far beyond the road route (walked %.1f m of %.1f m)" % [_walked, _notes.route.graph_length_m])
	_notes.route.record = record
	_semantics()

func _semantics() -> void:
	## The fixed home/work-station lookup must survive place travel, and a pending place rest must
	## point at its own public target without turning that square into a workstation.
	var home: Array = town()._state.godot.homes[READER]
	var home_point := Vector3(float(home[0]), float(home[1]), float(home[2]))
	var after_trip: Vector3 = town().destination(READER, "rest")
	var after_trip_workstation_at_public: float = town().position_of(READER).distance_to(Catalog.point_of(PLACE))
	_notes.destination = {"home": home, "rest_after_trip": after_trip,
		"public_distance_from_home_m": snappedf(home_point.distance_to(Catalog.point_of(PLACE)), 0.01)}
	check(after_trip.distance_to(home_point) <= 0.05,
		"after the trip the fixed home/work lookup is unchanged (got %s want %s)" % [str(after_trip), str(home_point)])
	check(after_trip_workstation_at_public > 1.0, "the public place is not the old home station (%0.2f m away)" % after_trip_workstation_at_public)
	## A place rest really pending: it owns destination(id, "rest") while it is pending.
	var option := {}
	for candidate in town().trade_options(READER):
		if candidate.get("id") == "place:rest:" + PLACE:
			option = candidate
			break
	if option.is_empty():
		check(false, "the arrived resident is offered rest at the place")
		_finish()
		return
	var rest_command := "fixture-places:route:rest"
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(READER, str(option.id), rest_command, "opengameagent_fixture"))
	check(started.ok and started.get("pending", false), "the place rest starts: " + str(started.get("code", "")))
	var public_point := Catalog.slot_point(PLACE, 0)
	var rest_target: Vector3 = town().destination(READER, "rest")
	var travel_target: Vector3 = town().destination(READER, "travel")
	var at_public := town()._at_worker_station(READER, READER)
	_notes.pending_rest = {"rest_target": rest_target, "public_point": public_point,
		"travel_lookup": travel_target, "is_workstation": at_public}
	check(rest_target.distance_to(public_point) <= 0.05,
		"a pending place rest waits at its own public point")
	check(rest_target.distance_to(home_point) > 1.0, "the pending rest target is not the old home station")
	check(not travel_target.is_finite() or travel_target.distance_to(rest_target) > 0.05,
		"the rest action does not answer the travel lookup from the public point")
	check(not at_public, "standing on the public square is not the old repair workstation")
	check(rest_target.distance_to(Catalog.point_of(PLACE)) <= 3.0, "the rest point is the measured public point of its own slot")
	_finish()

func _finish() -> void:
	_phase = "done"
	var evidence := {"suite": "town_places_route", "checks": _checks, "failures": _failures,
		"failure_count": _failures.size(), "time_scale": Engine.time_scale, "place": PLACE,
		"command": COMMAND, "walk_speed_mps": WALK_SPEED, "notes": _notes,
		"model_calls": 0, "paid_calls": 0}
	var args := _args()
	var out := str(args.get("out", ""))
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(evidence, "", true, true))
			file.close()
	print(JSON.stringify({"checks": _checks, "failures": _failures, "notes": _notes}))
	quit(0 if _failures.is_empty() else 1)
