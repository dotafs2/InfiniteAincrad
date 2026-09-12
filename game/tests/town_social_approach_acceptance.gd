extends SceneTree
## Offline acceptance for the reviewed innkeeper-to-smith approach stagnation.
##
## Part 1 is isolated geometry with real Godot physics bodies on a disposable
## fixture world: the reviewed positions (mover x=2.000277, blocking resident
## x=1.5, accepted meeting point x=0.85, all z=7.5) and two real 0.25 m capsules.
## A direct-offset control reproduces the observed stall without the new steering;
## the identical geometry must then finish through the real steering module. A
## third case stands a body exactly on the meeting point: the world's own 0.45 m
## arrival gate is inside the 0.5 m body contact distance, so that target is
## provably unreachable and must stay unfinished rather than be faked.
##
## Part 2 is world-level: the reviewed meeting point reproduces exactly through the
## world's own approach option, the capture pending breakdown counts a pending
## social job, and a cold reopen keeps the pending command without replaying it.
##
## The source observation is a real Kimi run; every number here is an explicitly
## labelled offline fixture and no model choice is claimed.

const Town = preload("res://core/town_trade.gd")
const TownStreet = preload("res://spatial/town_street.gd")
const SocialSteering = preload("res://spatial/town_social_steering.gd")

const MOVER := "fixture:innkeeper"
const BLOCKER := "fixture:carpenter"
const COUNTERPARTY := "fixture:smith"
const OCCUPANT := "fixture:occupant"
const MOVER_POSITION := [2.000276803970337, 0.22065602242946625, 7.5]
const BLOCKER_POSITION := [1.5, 0.2199999988079071, 7.5]
const GOAL_POSITION := [0.8500000238418579, 0.2199999988079071, 7.5]
const BODY_RADIUS := 0.25
const ARRIVAL_GATE := 0.45
const CONTROL_FRAMES := 180
const STEER_FRAMES := 480

var failures := 0
var checks := 0
var cases: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL ", label)

func fixture() -> Dictionary:
	var roster := [
		["fixture:innkeeper", "Innkeeper (offline fixture)", "innkeeper"],
		["fixture:smith", "Smith (offline fixture)", "smith"],
		["fixture:carpenter", "Carpenter (offline fixture)", "carpenter"],
		["fixture:baker", "Baker (offline fixture)", "baker"],
		["fixture:fisher", "Fisher (offline fixture)", "fisher"],
		["fixture:well-keeper", "Well keeper (offline fixture)", "well-keeper"],
	]
	# Genesis grid of the shared trial world seed: five columns, second row at z=5.5.
	var genesis := [[-3.0, 7.5], [-1.5, 7.5], [0.0, 7.5], [1.5, 7.5], [3.0, 7.5], [-3.0, 5.5]]
	var world := {"schema_version": 2, "world_id": "fixture:town-social-approach-rules",
		"fixture": true, "elapsed_seconds": 0, "residents": [],
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 6, "capacity": 6, "initial_stock": 6, "produced_total": 0,
			"harvested_total": 0, "growth_remainder_seconds": 0},
		"life": {"seq": 0, "events": [], "contracts": [], "applied": [], "relations": [],
			"inboxes": [], "items": [], "skills": [
				{"resident_id": "fixture:smith", "skill_id": "metal_repair"},
				{"resident_id": "fixture:carpenter", "skill_id": "wood_repair"}],
			"accounts": []},
		"godot": {"schema_version": 1, "mode": "migration_validation", "source_life_seq": 0,
			"source_sha256": "fixture-social-approach-rules", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0.2199999988079071, 1]}}
	for index in roster.size():
		var stable_id: String = roster[index][0]
		world.residents.append({"stable_id": stable_id, "name": roster[index][1],
			"role": roster[index][2], "story": "explicit offline fixture identity",
			"personality": "explicit offline fixture", "coins_col": 5 + index,
			"needs": {"hunger": 60.0}, "runtime": {"fixture_only": true}})
		world.survival.accounts.append({"resident_id": stable_id, "food": 1, "energy": 60.0})
		world.life.accounts.append({"resident_id": stable_id, "wood": 1, "iron": 0,
			"kindling": 0, "reserved_col": 0})
		world.godot.positions[stable_id] = [genesis[index][0], 0.2199999988079071, genesis[index][1]]
		world.godot.homes[stable_id] = world.godot.positions[stable_id].duplicate()
		world.godot.observations[stable_id] = []
	world.godot.positions[MOVER] = MOVER_POSITION.duplicate()
	world.godot.positions[BLOCKER] = BLOCKER_POSITION.duplicate()
	world.godot.positions[COUNTERPARTY] = [0.0, 0.2199999988079071, 7.5]
	world.life.items.append({"id": "fixture:axe", "kind": "axe", "owner_id": "fixture:carpenter",
		"custodian_id": "fixture:carpenter", "edge": 20, "handle": 20, "source": "explicit_offline_fixture"})
	return world

func _initialize() -> void:
	run.call_deferred()

func _work_dir() -> String:
	# The offline fixture is written inside the workspace, never into the engine's
	# user data directory and never into game/. A caller can point it elsewhere, but
	# the default stays inside this checkout so a standalone run needs no argument.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--social-work-dir="):
			var given := arg.trim_prefix("--social-work-dir=").strip_edges()
			if not given.is_empty():
				return given
	var game_dir := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var repo_root: String = game_dir.substr(0, game_dir.length() - 5) if game_dir.ends_with("/game") else game_dir
	return repo_root.path_join("tmp").path_join("gm09-tests").path_join("social-approach-acceptance")

func run() -> void:
	var folder := _work_dir()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("rules-%d.json" % Time.get_ticks_usec())
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "the accepted-workspace fixture path is writable: " + path)
	if file == null:
		_finish()
		return
	file.store_string(JSON.stringify(fixture(), "", true, true))
	file.close()
	var town := Town.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "offline social approach fixture loads: " + str(loaded.get("code", "")))
	if not loaded.ok:
		_finish()
		return
	check(town.active_ids().size() == 6, "six explicit offline fixture identities")
	# Part 2.1: the reviewed meeting point is the world's own approach target.
	var approach_option := {}
	for option in town.trade_options(MOVER):
		if option.get("action") == "approach" and str(option.get("counterparty", "")) == COUNTERPARTY:
			approach_option = option
			break
	check(not approach_option.is_empty(), "the world offers the mover an approach to the counterparty")
	var goal: Array = approach_option.get("target_position", [])
	check(goal.size() == 3 and _same_vector(goal, GOAL_POSITION),
		"the accepted meeting point reproduces the reviewed target exactly: " + str(goal))
	check(_same_vector(_flat(town.position_of(MOVER)), MOVER_POSITION), "the mover starts where the reviewed run left it")
	check(_same_vector(_flat(town.position_of(BLOCKER)), BLOCKER_POSITION), "the blocking resident stands where the reviewed run left it")
	var flat_gap := town.position_of(MOVER).distance_to(town.position_of(BLOCKER))
	check(absf(flat_gap - 0.5002768) < 0.0005, "the observed 0.500277 m gap equals the 0.5 m body contact distance: " + str(flat_gap))
	# Part 2.2: the accepted approach is real world state.
	var command := "fixture-social-approach:1"
	var started: Dictionary = town.transaction(path, func():
		return town.submit_trade(MOVER, str(approach_option.get("id")), command, "opengameagent_fixture"))
	check(started.ok, "the accepted approach starts through the world's own trade API: " + str(started.get("code", "")))
	var pending: Dictionary = town.pending_job(MOVER)
	check(pending.get("action") == "approach" and str(pending.get("command_id", "")) == command,
		"the pending social job is a real pending approach")
	# Part 2.3: the capture pending breakdown counts every journey source.
	var street = TownStreet.new()
	var idle_breakdown: Dictionary = street.pending_breakdown(_idle_snapshot(town))
	check(idle_breakdown.get("pending_count") == 0 and idle_breakdown.get("pending_trade_count") == 0,
		"an idle snapshot reports zero pending work")
	var social_breakdown: Dictionary = street.pending_breakdown(town.snapshot())
	check(social_breakdown.get("pending_trade_count") == 1 and social_breakdown.get("pending_life_count") == 0
		and social_breakdown.get("pending_count") == 1,
		"a pending social job is counted instead of being dropped: " + str(social_breakdown))
	var rested: Dictionary = town.transaction(path, func(): return town.start_action(BLOCKER, "rest", "fixture-rest:1"))
	check(rested.ok, "a second resident can start an unrelated life job: " + str(rested.get("code", "")))
	var mixed_breakdown: Dictionary = street.pending_breakdown(town.snapshot())
	check(mixed_breakdown.get("pending_life_count") == 1 and mixed_breakdown.get("pending_trade_count") == 1
		and mixed_breakdown.get("pending_count") == 2,
		"life and trade pending work are named separately and summed: " + str(mixed_breakdown))
	street.free()
	# Part 2.4: a cold reopen keeps the pending command, and the gate is still geometric.
	var before := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := Town.new()
	check(restored.load_from(path).ok, "cold reopen of the pending approach")
	check(FileAccess.get_file_as_bytes(path) == before, "cold reopen does not rewrite the save")
	check(str(restored.pending_job(MOVER).get("command_id", "")) == command,
		"cold reopen keeps the pending social command id")
	check(restored.snapshot().godot.trade.commands.get(command, {}).get("status") == "pending",
		"cold reopen keeps the pending command status")
	check(restored.resident(MOVER).coins_col == town.resident(MOVER).coins_col
		and restored.snapshot().life.items == town.snapshot().life.items,
		"cold reopen keeps money and items")
	var events_before: int = _command_events(restored.snapshot(), command)
	var advanced := true
	for step in 10:
		var elapsed: Dictionary = restored.transaction(path, func(): return restored.advance(120.0))
		advanced = advanced and elapsed.ok
	check(advanced, "world time advances on the restored save: the engine caps one step at 120 s, so ten steps run")
	check(restored.pending_job(MOVER).get("elapsed") == 0.0 and _command_events(restored.snapshot(), command) == events_before,
		"an unarrived approach accrues no work and no receipt over 1200 s")
	check(str(restored.pending_job(MOVER).get("command_id", "")) == command,
		"the unreached approach stays truthfully pending")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Part 1: real physics on the reviewed geometry.
	var world := Node3D.new()
	root.add_child(world)
	for spec in [{"name": "direct_control", "steering": false, "occupied": false, "frames": CONTROL_FRAMES},
			{"name": "steered_detour", "steering": true, "occupied": false, "frames": STEER_FRAMES},
			{"name": "occupied_target", "steering": true, "occupied": true, "frames": STEER_FRAMES, "blocked_lane": false}]:
		var lane: Node3D = LaneCase.new()
		lane.name = str(spec.name)
		lane.use_steering = bool(spec.steering)
		lane.occupied = bool(spec.occupied)
		lane.blocked_lane = bool(spec.get("blocked_lane", true))
		lane.max_frames = int(spec.frames)
		world.add_child(lane)
		await lane.done
		cases[str(spec.name)] = {
			"blocked_at_start": lane.blocked_at_start, "frames": lane.frames,
			"min_distance": lane.min_distance, "min_clearance": lane.min_clearance,
			"travel": lane.travel, "final_distance": lane.final_distance}
		# The await resumed inside the lane's own physics emission, so the emitter and
		# its parent must not be freed here: queue both and leave the tree afterwards.
		lane.queue_free()
	world.queue_free()
	check(bool(cases.direct_control.blocked_at_start),
		"the reviewed lane is really blocked for a straight approach: the cause is physical contact, not assumption")
	check(float(cases.direct_control.min_distance) > ARRIVAL_GATE,
		"a direct offset reproduces the observed stall outside the arrival gate: " + str(cases.direct_control.min_distance))
	check(float(cases.steered_detour.min_distance) <= ARRIVAL_GATE,
		"the same lane reaches the original target through the real steering: " + str(cases.steered_detour.min_distance))
	check(float(cases.steered_detour.travel) > float(cases.direct_control.travel) + 1.0,
		"the mover really travelled around the neighbour instead of through it")
	check(float(cases.steered_detour.min_clearance) > -0.02 and float(cases.occupied_target.min_clearance) > -0.02,
		"no collision penetration in either case")
	check(float(cases.occupied_target.min_distance) > ARRIVAL_GATE,
		"a body standing on the target keeps it unreachable: " + str(cases.occupied_target.min_distance))
	check(float(cases.occupied_target.travel) >= 0.40,
		"with no bounded route the mover still walks up to the obstruction instead of freezing: "
		+ str(cases.occupied_target.travel))
	check(float(cases.occupied_target.min_distance) <= BODY_RADIUS * 2.0 + 0.05,
		"the blocked mover really reaches physical contact distance: " + str(cases.occupied_target.min_distance))
	_finish.call_deferred()

func _idle_snapshot(town) -> Dictionary:
	var snap: Dictionary = town.snapshot()
	snap.godot.pending = {}
	snap.godot.trade = {"jobs": {}, "commands": {}}
	return snap

func _command_events(snap: Dictionary, command: String) -> int:
	var total := 0
	for event in snap.life.get("events", []):
		if str(event.get("operation_id", "")) == command:
			total += 1
	return total

func _same_vector(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for axis in 3:
		if not is_equal_approx(float(value[axis]), float(expected[axis])):
			return false
	return true

func _flat(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func _finish() -> void:
	var reported: Dictionary = {}
	for name in cases:
		var entry: Dictionary = cases[name]
		reported[name] = {"blocked_at_start": entry.blocked_at_start, "frames": entry.frames,
			"min_distance": entry.min_distance if is_finite(entry.min_distance) else -1.0,
			"min_clearance": entry.min_clearance if is_finite(entry.min_clearance) else -1.0,
			"travel": entry.travel,
			"final_distance": entry.final_distance if is_finite(entry.final_distance) else -1.0}
	print(JSON.stringify({"suite": "town_social_approach", "checks": checks, "failures": failures,
		"cases": reported, "work_dir": _work_dir(), "user_data_dir": OS.get_user_data_dir(),
		"paid_calls": 0, "provenance": "offline_fixture_real_bodies"}))
	quit(0 if failures == 0 else 1)


class LaneCase extends Node3D:
	## One disposable lane world: the reviewed positions and real capsule bodies.
	## The mover advances only through its own velocity and move_and_slide, so every
	## position is produced by the physics server.
	##
	## blocked_lane places the reviewed mid-lane resident at x=1.5 between the mover
	## and the goal. The occupied case omits it so the goal itself is the only
	## obstruction: that isolates the bounded search finding no route at all, which is
	## the fallback path that must still walk up to the obstruction.
	signal done

	var use_steering := false
	var occupied := false
	var blocked_lane := true
	var max_frames := 180
	var frames := 0
	var min_distance := INF
	var min_clearance := INF
	var travel := 0.0
	var final_distance := INF
	var blocked_at_start := false
	var mover: CharacterBody3D
	var steering: RefCounted
	var target := Vector3(0.8500000238418579, 0.2199999988079071, 7.5)
	var near := Vector3(1.5, 0.2199999988079071, 7.5)
	var last := Vector3.ZERO
	var settled := false

	func _ready() -> void:
		var ground := StaticBody3D.new()
		var ground_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(200.0, 0.2, 200.0)
		ground_shape.shape = box
		ground_shape.position.y = -0.12
		ground.add_child(ground_shape)
		add_child(ground)
		if blocked_lane:
			_capsule_body(near)
		if occupied:
			_capsule_body(target)
		mover = _mover(Vector3(2.000276803970337, 0.2199999988079071, 7.5))
		last = mover.position
		if use_steering:
			steering = SocialSteering.new()

	func _capsule_body(at: Vector3) -> void:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.5
		collider.shape = shape
		collider.position.y = 0.75
		body.add_child(collider)
		add_child(body)
		body.position = at

	func _mover(at: Vector3) -> CharacterBody3D:
		var body := CharacterBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.5
		collider.shape = shape
		collider.position.y = 0.75
		body.add_child(collider)
		add_child(body)
		body.position = at
		return body

	func _physics_process(delta: float) -> void:
		if settled:
			return
		var straight := target - mover.position
		straight.y = 0.0
		if frames == 0:
			blocked_at_start = mover.test_move(mover.global_transform, straight)
		var direction := Vector3.ZERO
		if use_steering:
			direction = steering.direction_for("lane-mover", "lane-command", mover, target)
		elif straight.length() > 0.30:
			direction = straight.normalized()
		mover.velocity.x = direction.x * 1.35
		mover.velocity.z = direction.z * 1.35
		mover.velocity.y = -0.2 if mover.is_on_floor() else mover.velocity.y - 18.0 * delta
		mover.move_and_slide()
		frames += 1
		var offset := mover.position - target
		offset.y = 0.0
		min_distance = minf(min_distance, offset.length())
		final_distance = offset.length()
		var step := mover.position - last
		step.y = 0.0
		travel += step.length()
		last = mover.position
		if blocked_lane:
			min_clearance = minf(min_clearance, _clearance(near))
		if occupied:
			min_clearance = minf(min_clearance, _clearance(target))
		if frames >= max_frames or (use_steering and offset.length() <= 0.30):
			settled = true
			done.emit()

	func _clearance(point: Vector3) -> float:
		var offset := mover.position - point
		offset.y = 0.0
		return offset.length() - 0.5
