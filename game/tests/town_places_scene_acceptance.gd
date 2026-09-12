extends SceneTree
## Offline scene acceptance for the public-place capability in the REAL playable town scene.
##
## Disposable ten-resident fixture, disposable working directory, default Forward+, no model call,
## no gateway, no maintained world. World-level rules (attribution, rejection, validation, trip
## persistence) are covered by town_places_rules_acceptance.gd; this file proves the physical part:
##  - the public notice exists in the street and is read only inside read range with a real clear
##    line of sight: a test-owned barrier installed BEFORE first perception blocks one resident,
##    and the same resident learns after the barrier is removed;
##  - residents chosen by index 0/4/8 - formerly all mapped to one modulo offset - walk to three
##    DIFFERENT measured-clear points at the same place and all three really arrive;
##  - every journey uses the resident's own CharacterBody3D at the original 1.35 m/s, measured;
##  - a wall across the paved street closes the trip honestly (travel_blocked, no arrival);
##  - a mid-walk copy of the real save resumes the same trip in a fresh scene and completes it
##    exactly once.
##
## The test clock is accelerated (Engine.time_scale) so this bounded run covers several minutes of
## GAME time; walk speed, collisions and distances are unchanged in game units. The same capability
## also has a smaller UNSCALED run (town_places_unscaled_acceptance.gd).
## No travelling body is ever teleported: only fixture start positions are set.
const TownScene := preload("res://scenes/town_street.tscn")
const Catalog := preload("res://spatial/town_places.gd")
const Town := preload("res://core/town_places.gd")

const IDS := ["fixture:innkeeper", "fixture:smith", "fixture:carpenter", "fixture:baker", "fixture:fisher",
	"fixture:well-keeper", "fixture:gardener", "fixture:weaver", "fixture:herder", "fixture:healer"]
## Measured clear standing positions on the market floor (town_places_site_probe.gd), not guessed:
## every one of the first nine is on floor 0.22 with no prop in its own volume.
const STARTS := [[2.0, 0.22, 8.0], [0.0, 0.22, 6.0], [5.0, 0.22, 6.0], [0.0, 0.10, 44.0], [2.0, 0.22, 13.0],
	[-2.0, 0.22, 6.0], [3.0, 0.22, 9.0], [0.0, 0.22, 14.0], [4.0, 0.22, 15.0], [0.0, 0.22, -20.0]]
const READER := 0
const SIGHT_ONLY := 2
const COMMONS_BY_SIGHT := 3
const BLOCKED_BY_WALL := 5
const FAR_RESIDENT := 9
const SAME_PLACE := [0, 4, 8]
const WALK_SPEED := 1.35

var _scene: Node = null
var _work := ""
var _save := ""
var _frames := 0
var _game := 0.0
var _phase := "boot"
var _checks := 0
var _failures: Array = []
var _deadline := 0.0
var _queue: Array = []
var _active: Array = []
var _wall: StaticBody3D = null
var _records: Array = []
var _mid_copy := ""
var _notes: Dictionary = {}
var _cold_command := ""
var _cold_start_pos := Vector3.ZERO
var _cold_start_game := 0.0
var _cold_deadline := 0.0
var _arrivals_before_cold := 0
var _blocked_command := ""
var _rest_started := 0.0
var _rest_energy_before := 0.0
var _rest_events_before := 0
var _spec_checked := true

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
	var world := {"schema_version": 2, "world_id": "fixture:town-places-scene", "fixture": true,
		"elapsed_seconds": 0, "residents": [],
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 6, "capacity": 6, "initial_stock": 6, "produced_total": 0,
			"harvested_total": 0, "growth_remainder_seconds": 0},
		"life": {"seq": 0, "events": [], "contracts": [], "applied": [], "relations": [],
			"inboxes": [], "items": [], "skills": [], "accounts": []},
		"godot": {"schema_version": 1, "mode": "migration_validation", "source_life_seq": 0,
			"source_sha256": "fixture-town-places-scene", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0.22, 1]}}
	for index in IDS.size():
		var stable_id: String = IDS[index]
		world.residents.append({"stable_id": stable_id, "name": stable_id + " (offline fixture)",
			"role": "fixture", "story": "explicit offline fixture identity",
			"personality": "explicit offline fixture", "coins_col": 5,
			"needs": {"hunger": 60.0}, "runtime": {"fixture_only": true}})
		world.survival.accounts.append({"resident_id": stable_id, "food": 1, "energy": 60.0})
		world.life.accounts.append({"resident_id": stable_id, "wood": 1, "iron": 0, "kindling": 0, "reserved_col": 0})
		world.godot.positions[stable_id] = STARTS[index].duplicate()
		world.godot.homes[stable_id] = STARTS[index].duplicate()
		world.godot.observations[stable_id] = []
	return world

func _initialize() -> void:
	var args := _args()
	_work = str(args.get("work", ""))
	_save = str(args.get("save", ""))
	if _work.is_empty() or _save.is_empty():
		push_error("scene acceptance requires --work= and --save=")
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
	_notes = {"specs": []}
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = true
	## Offline scripted fixture: disables the local rule-based auto-choices so every action in this
	## test is the one the test itself submits.
	_scene.scripted_trade = true

func town() -> Town:
	return _scene.town

func events_of(event_type: String) -> Array:
	var result: Array = []
	for event in _scene.town._state.life.events:
		if event is Dictionary and event.get("type", "") == event_type:
			result.append(event)
	return result

func known(index: int) -> Array:
	return _scene.town.known_place_ids(IDS[index])

func closure_count(command_id: String, event_type: String) -> int:
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
	if _game > 3000.0 and _phase != "done":
		check(false, "the bounded scene run exceeded its global game-time budget")
		_finish()
		return true
	match _phase:
		"boot":
			_boot_checks()
			_build_occluder()
			_deadline = _game + 2.0
			_phase = "paused_window"
		"paused_window":
			if _game >= _deadline:
				check(events_of("place_learned").is_empty(), "a paused world learns nothing")
				_scene.paused = false
				_deadline = _game + 6.0
				_phase = "perception"
		"perception":
			if _game >= _deadline:
				_perception_checks()
				_remove_occluder()
				_deadline = _game + 6.0
				_phase = "occlusion_clear"
		"occlusion_clear":
			if _game >= _deadline:
				check(not known(BLOCKED_BY_WALL).is_empty(), "after the barrier is gone the same resident reads the notice")
				_enqueue_journeys()
		"journey":
			_journey_step()
		"rest":
			_rest_step()
		"cold_walk":
			_cold_walk()
		"cold_suspend":
			_cold_suspend()
		"cold_resume":
			_cold_resume_step()
		"blocked_wait":
			_blocked_step()
		"done":
			return true
	return false

func _boot_checks() -> void:
	var notice := _scene.get_node_or_null("TownPlaceNotice")
	check(notice != null, "the public notice is installed in the playable town scene")
	if notice == null:
		_finish()
		return
	var evidence: Dictionary = notice.evidence()
	_notes.notice = {"id": evidence.get("notice_id", ""), "position": evidence.get("position", []),
		"read_range_m": evidence.get("read_range_m", 0.0), "placed": evidence.get("placed", false),
		"collision": evidence.get("collision", false), "load_failure": evidence.get("load_failure", "")}
	check(bool(evidence.get("placed", false)) and str(evidence.get("load_failure", "")).is_empty(),
		"the notice prop loaded from existing art")
	check(bool(evidence.get("collision", false)), "the notice is a real solid prop, not a marker")
	## Cause-specific check of the notice position: which bodies actually occupy it, and on which
	## floor does it stand? A future foreign collider must show up here by name.
	var space: PhysicsDirectSpaceState3D = (_scene as Node3D).get_world_3d().direct_space_state
	var notice_point: Vector3 = notice.notice_point()
	var notice_rid: RID = notice.solid.get_rid() if notice.solid != null else RID()
	var probe := PhysicsShapeQueryParameters3D.new()
	var probe_shape := CylinderShape3D.new()
	probe_shape.radius = 0.10
	probe_shape.height = 0.4
	probe.shape = probe_shape
	probe.transform = Transform3D(Basis(), notice_point - Vector3(0, 0.9, 0))
	probe.collision_mask = 0xFFFFFFFF
	var occupiers: Array = []
	for hit in space.intersect_shape(probe, 8):
		var node := hit.get("collider") as Node
		var entry := {"name": node.name if node != null else "?", "own_notice": hit.get("collider") == notice.solid}
		occupiers.append(entry)
	_notes.notice_occupiers = occupiers
	var foreign := 0
	for entry in occupiers:
		if not entry.own_notice:
			foreign += 1
	check(occupiers.size() >= 1 and foreign == 0,
		"only the notice itself occupies its own position (occupiers=%s)" % str(occupiers))
	var floor := PhysicsRayQueryParameters3D.create(Vector3(notice_point.x - 1.2, 20.0, notice_point.z),
		Vector3(notice_point.x - 1.2, -2.0, notice_point.z))
	var floor_hit: Dictionary = space.intersect_ray(floor)
	var floor_y: float = floor_hit.position.y if not floor_hit.is_empty() else -99.0
	_notes.notice_floor_y = snappedf(floor_y, 0.001)
	check(absf(floor_y - float(Catalog.NOTICE["position"][1])) < 0.10,
		"the notice stands on the measured market floor (%.3f)" % floor_y)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	var standing := PhysicsShapeQueryParameters3D.new()
	standing.shape = capsule
	standing.transform = Transform3D(Basis(), notice_point + Vector3(0, 0.60, 0))
	standing.collision_mask = 0xFFFFFFFF
	var blockers: Array = []
	for hit in space.intersect_shape(standing, 8):
		var node := hit.get("collider") as Node
		blockers.append(node.name if node != null else "?")
	_notes.notice_blockers = blockers
	check(not (blockers as Array).has("PublicNoticeCollision") or blockers.size() <= 1,
		"a body can stand at the notice without another resident's collider in the way")

func _build_occluder() -> void:
	## A test-owned barrier south of the notice, installed BEFORE the first perception pass. It is
	## removed again and is not part of the game: it proves the sensing is a real line-of-sight query.
	_wall = StaticBody3D.new()
	_wall.name = "FixtureOccludingWall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.5, 3.0, 0.4)
	shape.shape = box
	shape.position = Vector3(-2.25, 1.5, 7.5)
	_wall.add_child(shape)
	(_scene as Node3D).add_child(_wall)

func _remove_occluder() -> void:
	if _wall != null and is_instance_valid(_wall):
		_wall.queue_free()
	_wall = null

func _perception_checks() -> void:
	_notes.known_after_perception = {}
	for index in IDS.size():
		_notes.known_after_perception[IDS[index]] = known(index)
	check(known(READER).size() == Catalog.place_ids().size(), "the resident at the notice learned every public place")
	check(known(COMMONS_BY_SIGHT) == ["planted_commons"],
		"direct sight taught only the place actually seen: " + str(known(COMMONS_BY_SIGHT)))
	check(_scene.town.place_knowledge(IDS[COMMONS_BY_SIGHT]).get("planted_commons", {}).get("source", "") == "direct_sight",
		"direct-sight knowledge keeps its own source")
	check(known(SIGHT_ONLY) == ["market_plaza"],
		"beyond the notice read range a resident learns only what it can see: " + str(known(SIGHT_ONLY)))
	check(known(BLOCKED_BY_WALL).is_empty(), "the resident behind the barrier learned nothing")
	check(known(FAR_RESIDENT).is_empty(), "the far resident learned nothing")

func _enqueue_journeys() -> void:
	_queue = [
		{"indexes": [0], "place": "west_forecourt", "label": "market to the west forecourt"},
		{"indexes": [0], "place": "market_plaza", "label": "west forecourt back to the old market plaza"},
		{"indexes": SAME_PLACE, "place": "planted_commons", "label": "three residents to the planted commons"},
		{"indexes": [4, 8], "place": "market_plaza", "label": "commons back to the old market plaza"},
		{"indexes": [0], "place": "caravan_rest", "label": "market to the caravan rest (long leg past the commons)"},
		{"indexes": [0], "place": "market_plaza", "label": "caravan rest back to the old market plaza"},
	]
	_start_next_journey()

func _start_next_journey() -> void:
	if _queue.is_empty():
		_start_rest()
		return
	var spec: Dictionary = _queue.pop_front()
	_active = []
	_spec_checked = false
	for index in spec.indexes:
		var id: String = IDS[index]
		var place_id: String = spec.place
		var option := {}
		for candidate in town().trade_options(id):
			if candidate.get("id") == "place:travel:" + place_id:
				option = candidate
				break
		if option.is_empty():
			check(false, "%s offers travel to %s (resident %d)" % [id, place_id, index])
			continue
		var command := "fixture-places:travel:%d:%s:%d" % [index, place_id, _frames]
		var start_position := town().position_of(id)
		var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(id, str(option.id), command, "opengameagent_fixture"))
		if not started.ok:
			check(false, "journey starts for %s to %s: %s" % [id, place_id, str(started.get("code", ""))])
			continue
		_active.append({"index": index, "id": id, "place": place_id, "command": command, "label": spec.label,
			"start_game": _game, "start_pos": start_position,
			"expected": Catalog.road_length(place_id, start_position, index),
			"target": town().place_point(place_id, id), "recorded": false, "max_speed": 0.0})
	if _active.is_empty():
		_start_next_journey()
		return
	_deadline = _game + _longest_expected() / WALK_SPEED * 3.0 + 90.0
	_phase = "journey"

func _longest_expected() -> float:
	var longest := 10.0
	for journey in _active:
		longest = maxf(longest, float(journey.expected))
	return longest

func _journey_step() -> void:
	var arrived := true
	for journey in _active:
		if journey.recorded:
			continue
		var body: CharacterBody3D = _scene.bodies.get(journey.id)
		if is_instance_valid(body):
			journey.max_speed = maxf(float(journey.max_speed), Vector2(body.velocity.x, body.velocity.z).length())
		if closure_count(str(journey.command), "place_visited") == 0:
			arrived = false
			continue
		## Recorded once, on the first observed receipt, so no per-frame assertion inflation.
		journey.recorded = true
		var end_pos := town().position_of(str(journey.id))
		var distance := Vector2(end_pos.x - journey.start_pos.x, end_pos.z - journey.start_pos.z).length()
		var duration: float = _game - float(journey.start_game)
		_records.append({"label": journey.label, "id": journey.id, "place": journey.place,
			"distance_m": snappedf(distance, 0.01), "game_seconds": snappedf(duration, 0.01),
			"measured_speed_mps": snappedf(distance / maxf(duration, 0.001), 0.001),
			"max_horizontal_speed_mps": snappedf(float(journey.max_speed), 0.001),
			"graph_length_m": snappedf(float(journey.expected), 0.01),
			"arrival_distance_m": snappedf(end_pos.distance_to(journey.target), 0.02)})
		check(closure_count(str(journey.command), "place_visited") == 1, "exactly one arrival receipt: " + str(journey.label))
		check(distance > float(journey.expected) * 0.6, "the body really walked (%.1f m of %.1f m): %s" % [distance, journey.expected, journey.label])
		check(absf(float(journey.max_speed) - WALK_SPEED) < 0.02, "original NPC velocity 1.35 m/s used (%.3f)" % float(journey.max_speed))
		check(end_pos.distance_to(journey.target) <= 1.2, "arrived at its own point (%.2f m): %s" % [end_pos.distance_to(journey.target), journey.label])
		check(town().pending_job(str(journey.id)).is_empty(), "the trip is closed after arrival: " + str(journey.id))
	var all_recorded := true
	for journey in _active:
		if not journey.recorded:
			all_recorded = false
	if all_recorded and not _spec_checked:
		## Once per journey spec: the same-place case must use separated, stable indexed points.
		_spec_checked = true
		_notes.specs.append({"label": _records[-1].label if not _records.is_empty() else "",
			"targets": _active.map(func(journey): return [journey.id, journey.place, journey.target]),
			"indexes": _active.map(func(journey): return journey.index)})
		if _active.size() > 1:
			var targets: Array = []
			for journey in _active:
				targets.append(journey.target)
			var distinct := true
			for left in targets.size():
				for right in range(left + 1, targets.size()):
					if targets[left].distance_to(targets[right]) < 1.0:
						distinct = false
			check(distinct, "same-place residents use separated points: " + str(targets))
			var slots_ok := true
			for journey in _active:
				if Catalog.slot_point(str(journey.place), int(journey.index)).distance_to(journey.target) > 0.05:
					slots_ok = false
			check(slots_ok, "each resident's target is its own stable indexed point")
	if all_recorded and _spec_checked:
		_notes.journeys = _records
		_start_next_journey()
	elif _game > _deadline:
		check(false, "a journey did not arrive within the derived deadline: " + str(_active))
		_notes.journeys = _records
		_start_next_journey()

func _start_rest() -> void:
	## Rest at a public place uses the world's own rest rule. The resident really stands on its own
	## arrival point, which the travel above produced; nothing is teleported and no energy is edited.
	var index := 4
	var id: String = IDS[index]
	var option := {}
	for candidate in town().trade_options(id):
		if candidate.get("id") == "place:rest:market_plaza":
			option = candidate
			break
	check(not option.is_empty(), "the arrived resident is offered rest at the place it stands on")
	_rest_started = _game
	_rest_events_before = events_of("rest").size()
	_rest_sample = _energy_sample(index)
	if option.is_empty():
		_begin_cold()
		return
	var command := "fixture-places:rest:1"
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(id, str(option.id), command, "opengameagent_fixture"))
	check(started.ok and started.get("pending", false), "rest at the place starts: " + str(started.get("code", "")))
	if not started.ok:
		_begin_cold()
		return
	_phase = "rest"

var _rest_sample: Dictionary = {}

func _energy_sample(index: int) -> Dictionary:
	return {"energy": float(town().account(IDS[index]).energy),
		"remainder": float(town()._state.survival.tick_remainder_seconds),
		"elapsed": float(town()._state.godot.elapsed_seconds)}

func _rest_step() -> void:
	var index := 4
	if events_of("rest").size() == _rest_events_before:
		_rest_sample = _energy_sample(index)
		if _game - _rest_started > 120.0:
			check(false, "rest did not complete within its own 60 s rule")
			_begin_cold()
		return
	check(events_of("rest").size() == _rest_events_before + 1, "exactly one rest receipt at the place")
	var after := _energy_sample(index)
	var elapsed: float = float(after.elapsed) - float(_rest_sample.elapsed)
	var ticks: int = floori((float(_rest_sample.remainder) + elapsed) / 120.0)
	var expected := minf(100.0, float(_rest_sample.energy) - float(ticks) + 35.0)
	_notes.rest = {"before": _rest_sample, "after": after, "survival_ticks": ticks, "expected": expected}
	check(absf(float(after.energy) - expected) < 0.001,
		"rest grants the existing +35 with the world's own survival ticks accounted (%.1f -> %.1f, ticks %d)" % [float(_rest_sample.energy), float(after.energy), ticks])
	check(town().pending_job(IDS[index]).is_empty(), "the place rest closes and leaves no pending job")
	var mirror: Dictionary = town()._state.godot.get("places", {}).get("commands", {}).get("fixture-places:rest:1", {})
	check(str(mirror.get("status", "")) == "completed", "the place rest option mirror settles with the life command: " + str(mirror.get("status", "")))
	_begin_cold()

func _begin_cold() -> void:
	## One more trip, really walked, then a byte copy of the saved world is resumed in a fresh
	## scene instance: the same command must continue and produce exactly one arrival receipt.
	var index := 0
	var id: String = IDS[index]
	var option := {}
	for candidate in town().trade_options(id):
		if candidate.get("id") == "place:travel:west_forecourt":
			option = candidate
			break
	check(not option.is_empty(), "the cold-resume resident knows the west forecourt")
	if option.is_empty():
		_blocked_start()
		return
	_cold_command = "fixture-places:cold:1"
	_cold_start_pos = town().position_of(id)
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(id, str(option.id), _cold_command, "opengameagent_fixture"))
	check(started.ok, "the cold-resume trip starts: " + str(started.get("code", "")))
	if not started.ok:
		_blocked_start()
		return
	_arrivals_before_cold = events_of("place_visited").size()
	_cold_start_game = _game
	_cold_deadline = _game + float(Catalog.road_length("west_forecourt", _cold_start_pos, index)) / WALK_SPEED * 3.0 + 90.0
	_phase = "cold_walk"

func _cold_walk() -> void:
	if _game - _cold_start_game < 12.0:
		return
	var moved := Vector2(town().position_of(IDS[0]).x - _cold_start_pos.x, town().position_of(IDS[0]).z - _cold_start_pos.z).length()
	check(moved > 2.0, "the cold-resume trip really walked before the copy (%.2f m)" % moved)
	check(closure_count(_cold_command, "place_visited") == 0, "no arrival receipt exists when the copy is taken")
	check(closure_count(_cold_command, "travel_blocked") == 0, "no blocked closure exists when the copy is taken")
	_mid_copy = _work.path_join("mid-walk.json")
	DirAccess.copy_absolute(_save, _mid_copy)
	var copied := Town.new()
	var copied_ok: Dictionary = copied.load_from(_mid_copy)
	var copied_job: Dictionary = copied.pending_job(IDS[0]) if copied_ok.ok else {}
	_notes.cold_copy = {"loaded": copied_ok.ok, "pending_place": copied_job.get("place_id", ""),
		"command": copied_job.get("command_id", ""), "target": copied_job.get("target_position", [])}
	check(copied_ok.ok and str(copied_job.get("command_id", "")) == _cold_command,
		"the byte copy holds the same pending trip: " + str(_notes.cold_copy))
	_scene.paused = true
	_scene.queue_free()
	_phase = "cold_suspend"

func _cold_suspend() -> void:
	if FileAccess.file_exists(_save + ".writer-lock"):
		check(false, "the first scene still holds the writer lock after being freed")
		_blocked_start()
		return
	## The fresh scene reads its save path from the command line, so the copy is installed at that
	## exact path: the resumed scene owns the copied bytes and every later write goes to one file.
	## The copy itself stays as an untouched artifact beside the run.
	DirAccess.copy_absolute(_mid_copy, _save)
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = false
	_scene.scripted_trade = true
	_phase = "cold_resume"

func _cold_resume_step() -> void:
	if closure_count(_cold_command, "place_visited") == 1:
		var target := Catalog.slot_point("west_forecourt", 0)
		check(town().pending_job(IDS[0]).is_empty(), "the resumed trip closes after its single arrival")
		check(town().position_of(IDS[0]).distance_to(target) <= 1.2, "the resumed trip physically reached its own arrival point")
		_notes.cold_resume = {"arrivals": closure_count(_cold_command, "place_visited"),
			"position": town().position_of(IDS[0]), "target": target}
		_blocked_start()
		return
	if _game > _cold_deadline:
		_notes.cold_resume = {"timeout": true, "position": town().position_of(IDS[0]),
			"pending": town().pending_job(IDS[0]), "reported": town().place_travel_blocked(IDS[0])}
		check(false, "the resumed trip did not arrive within its deadline")
		_blocked_start()

func _blocked_start() -> void:
	## A wall across the paved main street. The last trip must close honestly: no arrival, no
	## resource, and the resident keeps its identity and history.
	var wall := StaticBody3D.new()
	wall.name = "FixtureBlockingWall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 3.0, 0.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 45.0)
	wall.add_child(shape)
	(_scene as Node3D).add_child(wall)
	_wall = wall
	var index := 6
	var id: String = IDS[index]
	var option := {}
	for candidate in town().trade_options(id):
		if candidate.get("id") == "place:travel:planted_commons":
			option = candidate
			break
	check(not option.is_empty(), "the blocked-journey resident knows the commons")
	if option.is_empty():
		_finish()
		return
	_blocked_command = "fixture-places:blocked:1"
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(id, str(option.id), _blocked_command, "opengameagent_fixture"))
	check(started.ok, "the blocked journey starts: " + str(started.get("code", "")))
	if not started.ok:
		_finish()
		return
	_deadline = _game + float(Catalog.road_length("planted_commons", town().position_of(id), index)) / WALK_SPEED * 2.0 + 150.0
	_phase = "blocked_wait"

func _blocked_step() -> void:
	if closure_count(_blocked_command, "travel_blocked") == 1:
		check(closure_count(_blocked_command, "place_visited") == 0, "the blocked trip produced no arrival receipt")
		var command: Dictionary = town()._state.godot.get("places", {}).get("commands", {}).get(_blocked_command, {})
		check(str(command.get("status", "")) == "rejected" and str(command.get("result", {}).get("code", "")) == "travel_blocked",
			"the blocked trip command is honestly rejected: " + str(command.get("result", {})))
		check(town().pending_job(IDS[6]).is_empty(), "the blocked trip leaves no dangling job")
		check(town().position_of(IDS[6]).z < 44.6, "the blocked body never passed the wall (z=%.2f)" % town().position_of(IDS[6]).z)
		var remaining := Catalog.road_length("planted_commons", town().position_of(IDS[6]), 6)
		_notes.blocked = {"arrivals": closure_count(_blocked_command, "place_visited"),
			"position": town().position_of(IDS[6]), "remaining_route_m": snappedf(remaining, 0.01)}
		check(remaining > 3.0, "the blocked resident is still honestly short of its destination (%.2f m)" % remaining)
		_finish()
		return
	if _game > _deadline:
		var job := town().pending_job(IDS[6])
		_notes.blocked = {"timeout": true, "position": town().position_of(IDS[6]), "pending": job,
			"reported": town().place_travel_blocked(IDS[6])}
		check(false, "the blocked trip did not close within its deadline; z=%.2f" % town().position_of(IDS[6]).z)
		_finish()

func _finish() -> void:
	_phase = "done"
	var evidence := {"suite": "town_places_scene", "checks": _checks, "failures": _failures,
		"failure_count": _failures.size(), "world_id": "fixture:town-places-scene",
		"fixture_save": _save, "work_dir": _work, "time_scale": Engine.time_scale,
		"walk_speed_mps": WALK_SPEED, "journeys": _records, "places": Catalog.place_ids(),
		"notice": str(Catalog.NOTICE["id"]), "notes": _notes, "model_calls": 0, "paid_calls": 0}
	var args := _args()
	var out := str(args.get("out", ""))
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(evidence, "", true, true))
			file.close()
	print(JSON.stringify({"checks": _checks, "failures": _failures, "journeys": _records.size()}))
	quit(0 if _failures.is_empty() else 1)
