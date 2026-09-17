extends "res://tests/town_baking_route_acceptance.gd"
## Physics acceptance for the public oven's own collision (spatial/town_baking_points.gd).
## Command:
## python -X utf8 tools/run_godot.py --godot <godot> --name baking-physics --timeout 45 \
##   --out <candidate tmp dir> -- --headless --script res://tests/town_baking_physics_acceptance.gd
##
## Scope: a standalone, bounded physics fixture. It runs the real BakingPoints projection and the
## real line-of-sight component over primitives, plus one fixture-backed real town core, and it
## moves real resident-shaped CharacterBody3D capsules through them. It never loads the town
## street, its art, or the 16-house site, so it says NOTHING about the real town placement, the
## real navigation mesh bake, or real resident routes. Those stay unverified here.
##
## Three honest measurements of the original gap:
##  1. counterexample: the pre-fix source drew the oven as meshes only, and the very same capsule
##     walk that the fixed component stops passes straight through that mesh-only oven;
##  2. with the real component the capsule is physically stopped and never overlaps the body,
##     while the authoritative working apron (BAKING_WORK_OFFSET, arrival radius 0.45) is still
##     legally reachable by a real walking capsule;
##  3. the line-of-sight target above the body stays observable from that apron, is blocked by a
##     real occluding wall, and the real core grants knowledge only for the unblocked verdict.

const BakingVisuals = preload("res://spatial/town_baking_points.gd")
const BakeSight = preload("res://spatial/town_material_visibility.gd")
const CoreBakingTown = preload("res://core/town_baking.gd")
## Only the physics-callback scheduling shim is reused from the material sight suite.
const SightAcceptance = preload("res://tests/town_material_visibility_acceptance.gd")

const CAPSULE_RADIUS := 0.25
const CAPSULE_HEIGHT := 1.5
const WALK_SPEED := 1.35
const EYE_HEIGHT := 1.55
const OVEN_AT := Vector3(0.0, 0.0, 0.0)
const POINT_ID := "fixture:physics-oven"
const BACK_START := Vector3(0.0, 0.0, -0.7)
const BACK_FRAMES := 20
const SIDE_START := Vector3(0.85, 0.0, 0.0)
const SIDE_FRAMES := 12
const APPROACH_START := Vector3(0.6, 0.0, 1.5)
const APPROACH_FRAMES := 40
const OVERLAP_TOLERANCE := 0.02

class FakeWorld:
	# The minimal world the projection needs: the very read-only call the real town core answers.
	var entries: Array = []
	func baking_points() -> Array:
		return entries

class WalkingCapsule extends CharacterBody3D:
	# A real moving resident-shaped body: the same capsule the street residents carry.
	var heading := Vector3.ZERO
	var seek := Vector3.INF
	var frames := 0
	var closest_seek := INF
	func _physics_process(_delta: float) -> void:
		var direction := heading
		if seek.is_finite():
			direction = seek - global_position
			direction.y = 0.0
		velocity = direction.normalized() * WALK_SPEED if direction.length() > 0.08 else Vector3.ZERO
		move_and_slide()
		frames += 1
		if seek.is_finite():
			closest_seek = minf(closest_seek, global_position.distance_to(seek))

var _runner = null
var _sight = null
var _los_body: CharacterBody3D = null
var _los_visuals: Node3D = null
var _wall: StaticBody3D = null

func _fixture_path() -> String:
	# The same user:// location every other suite uses, with a project-local scratch fallback for
	# an environment that cannot write user:// at all. Which one was used is reported in evidence.
	for prefix in ["user://", "res://tmp/"]:
		var candidate: String = prefix + "fictional-town-baking-physics-%d.json" % Time.get_ticks_usec()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(candidate.get_base_dir()))
		var probe := FileAccess.open(candidate, FileAccess.WRITE)
		if probe == null:
			continue
		probe.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		return candidate
	return ""

func _capsule(at: Vector3) -> WalkingCapsule:
	var body := WalkingCapsule.new()
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	collider.shape = shape
	collider.position = Vector3(0, CAPSULE_HEIGHT * 0.5, 0)
	body.add_child(collider)
	body.position = at
	root.add_child(body)
	return body

func _occluding_wall(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collider := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	collider.shape = volume
	body.add_child(collider)
	body.position = at
	root.add_child(body)
	return body

func _legacy_oven_display(at: Vector3) -> Node3D:
	# Exactly what the pre-fix component drew: an oven mesh, a mouth mesh and a label, with no
	# physics body anywhere under them. This is the counterexample, not a second implementation.
	var display := Node3D.new()
	display.position = at
	root.add_child(display)
	var oven := MeshInstance3D.new()
	var oven_mesh := BoxMesh.new()
	oven_mesh.size = Vector3(1.0, 1.0, 0.76)
	oven.mesh = oven_mesh
	oven.position = Vector3(0.0, 0.5, 0.0)
	display.add_child(oven)
	var mouth := MeshInstance3D.new()
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.5, 0.34, 0.06)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0.0, 0.42, 0.40)
	display.add_child(mouth)
	var label := Label3D.new()
	label.text = "legacy"
	label.position = Vector3(0, 1.30, 0)
	display.add_child(label)
	return display

func _oven_box(visuals: Node3D, point_id: String) -> Dictionary:
	# Reads the collider the component actually installed, never an assumed dimension.
	var entry: Dictionary = visuals.points.get(point_id, {})
	var display: Variant = entry.get("display")
	if not is_instance_valid(display) or not display is Node3D:
		return {}
	for node in (display as Node3D).find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D:
			continue
		var collider := body.get_child(0) as CollisionShape3D
		if not collider.shape is BoxShape3D:
			continue
		var volume := collider.shape as BoxShape3D
		return {"size": volume.size, "center": collider.global_position,
			"layer": body.collision_layer, "name": str(body.name)}
	return {}

func _xz_clearance(point: Vector3, box: Dictionary) -> float:
	# Walking-plane distance from a capsule centre to the oven body footprint. The capsule is a
	# full-radius cylinder across the body's whole height, so this distance is exactly the overlap
	# test: below CAPSULE_RADIUS the two solids really intersect.
	var center: Vector3 = box.get("center", Vector3.ZERO)
	var size: Vector3 = box.get("size", Vector3.ZERO)
	var nearest := Vector2(clampf(point.x, center.x - size.x * 0.5, center.x + size.x * 0.5),
		clampf(point.z, center.z - size.z * 0.5, center.z + size.z * 0.5))
	return Vector2(point.x, point.z).distance_to(nearest)

func _walk(body: WalkingCapsule, frames: int, box: Dictionary) -> Dictionary:
	# Drives the real body for bounded physics frames and measures the path it actually took.
	var min_clearance := INF
	var penetrated := false
	for _i in frames:
		await physics_frame
		var clearance := _xz_clearance(body.global_position, box)
		min_clearance = minf(min_clearance, clearance)
		penetrated = penetrated or clearance <= 0.0
	return {"min_clearance": min_clearance, "penetrated": penetrated, "end": body.global_position}

func _run_in_physics(callable: Callable) -> Variant:
	_runner.schedule(callable)
	var guard := 0
	while not _runner.done and guard < 240:
		await physics_frame
		await process_frame
		guard += 1
	if not _runner.done:
		check(false, "physics runner did not complete within bounded frames")
		return null
	return _runner.result

func _perception(resident: String, point_id: String) -> Dictionary:
	var report: Variant = await _run_in_physics(func(): return _perception_now(resident, point_id))
	return report if report is Dictionary else {}

func _perception_now(resident: String, point_id: String) -> Dictionary:
	# One physics instant: the same straight segment the Sight component uses, queried here
	# directly so the reported occluder and the component verdict come from one single sample.
	var target: Vector3 = _los_visuals.observation_target(point_id)
	var eye: Vector3 = _los_body.global_position + Vector3(0, EYE_HEIGHT, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, target, 0xFFFFFFFF, [_los_body.get_rid()])
	query.hit_from_inside = true
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = _los_body.get_world_3d().direct_space_state.intersect_ray(query)
	return {"blocked": not hit.is_empty(), "occluder": hit.get("collider"), "eye": eye,
		"target": target, "observed": _sight.can_observe(resident, point_id)}

func _tick(town, path: String, delta: float) -> Dictionary:
	var verdict: Variant = await _run_in_physics(func(): return town.transaction(path, func(): return town.advance(delta)))
	return verdict if verdict is Dictionary else {}

func _json_codec_available() -> bool:
	# The real core decodes and encodes saves through a C# codec (core/TownJsonCodec.cs). In a
	# checkout where that assembly is not built the core cannot load at all, so the core-backed
	# section reports an environment limitation instead of pretending that it ran.
	var probe = CoreBakingTown.new()
	var decoded: Variant = probe._parse_json_text("{\"fixture\": 1}")
	probe.free()
	return decoded is Dictionary

func _wait_physics(count: int) -> void:
	for _i in count:
		await physics_frame

func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()

func run() -> void:
	var started := Time.get_ticks_msec()
	var path := _fixture_path()
	check(not path.is_empty(), "this environment offers a writable fixture path")
	if path.is_empty():
		print(JSON.stringify({"suite": "town_baking_physics", "checks": checks, "failures": failures + 1,
			"paid_calls": 0, "physics_fixture": true, "success": false,
			"environment_failure": "no writable fixture path (user:// and res://tmp both failed)"}))
		quit(1)
		return
	var town = null
	var legacy_end := Vector3.ZERO
	var blocked_end := Vector3.ZERO
	var side_end := Vector3.ZERO
	var apron_min_clearance := -1.0
	var apron_closest := INF
	var apron_arrival := -1.0
	var apron_observed := false
	var wall_occluder: Object = null
	var wall_is_occluder := false
	var wall_observed := -1
	var core_blocked_knowledge := -1
	var core_clear_knowledge := -1

	_runner = SightAcceptance.PhysicsRunner.new()
	root.add_child(_runner)
	var legacy_box: Dictionary = {"size": Vector3(1.0, 1.0, 0.76), "center": Vector3(0.0, 0.5, 0.0)}
	var rate_started := Time.get_ticks_msec()
	await _wait_physics(10)
	print(JSON.stringify({"suite": "town_baking_physics_rate", "physics_ms_per_frame":
		float(Time.get_ticks_msec() - rate_started) / 10.0}))
	var walking_started := Time.get_ticks_msec()

	# 1. Counterexample: the pre-fix source had meshes only, and the same walk crosses the oven.
	var legacy := _legacy_oven_display(OVEN_AT)
	check(legacy.find_children("*", "StaticBody3D", true, false).is_empty(),
		"counterexample: the mesh-only oven of the old source carries no collision at all")
	var legacy_body := _capsule(BACK_START)
	legacy_body.heading = Vector3(0, 0, 1)
	var legacy_walk := await _walk(legacy_body, BACK_FRAMES, legacy_box)
	legacy_end = legacy_walk.end
	check(bool(legacy_walk.penetrated),
		"counterexample: the same walking capsule passes through the mesh-only oven")
	check(legacy_end.z > -0.38,
		"counterexample: the capsule ends inside the oven footprint the old source only drew")
	_free_nodes([legacy_body, legacy])
	await _wait_physics(2)

	# 2. The real component, over a minimal fake world.
	var fake := FakeWorld.new()
	fake.entries = [{"id": POINT_ID, "label": "Public oven", "position": [0, 0, 0],
		"flour_remaining": 4, "access": "public"}]
	_los_visuals = BakingVisuals.new()
	root.add_child(_los_visuals)
	_los_visuals.configure(fake)
	check(_los_visuals.get_child_count() == 1, "one public oven display exists")
	var installed := _oven_box(_los_visuals, POINT_ID)
	check(not installed.is_empty(), "the display installs one real box collider")
	check(str(installed.get("name", "")) == "OvenCollision", "the oven solid is named for evidence")
	check((installed.get("size", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(1.0, 1.0, 0.76)),
		"the solid matches the drawn oven body 1x1x0.76")
	check((installed.get("center", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0.0, 0.5, 0.0)),
		"the solid sits on the drawn oven body centre")
	check((int(installed.get("layer", 0)) & 1) != 0,
		"the solid is on the layer resident capsules scan and the navigation bake parses")
	var body_top: float = (installed.get("center", Vector3.ZERO) as Vector3).y + (installed.get("size", Vector3.ZERO) as Vector3).y * 0.5
	var target: Vector3 = _los_visuals.observation_target(POINT_ID)
	check(target.is_finite(), "the oven line-of-sight target is real and finite")
	check(target.y > body_top,
		"the line-of-sight target sits above the body top, so the new solid cannot self-block it")
	check(is_equal_approx(target.x, OVEN_AT.x) and is_equal_approx(target.z, OVEN_AT.z),
		"the line-of-sight target is still the oven's own mouth point")

	# 3. The authoritative apron, straight from the real baking rules.
	var work_offset: Vector3 = CoreBakingTown.BAKING_WORK_OFFSET
	var arrival_radius: float = CoreBakingTown.BAKING_ARRIVAL_RADIUS
	var work_target: Vector3 = OVEN_AT + work_offset
	check(work_offset.is_equal_approx(Vector3(0.0, 0.0, 0.85)) and is_equal_approx(arrival_radius, 0.45),
		"the authoritative work target and arrival radius are unchanged")
	check(_xz_clearance(work_target, installed) >= CAPSULE_RADIUS,
		"a resident capsule standing on the work target does not touch the oven solid")

	# 4. The same walk that crossed the legacy oven cannot cross the real one.
	var blocked_body := _capsule(BACK_START)
	blocked_body.heading = Vector3(0, 0, 1)
	var blocked_walk := await _walk(blocked_body, BACK_FRAMES, installed)
	blocked_end = blocked_walk.end
	check(not bool(blocked_walk.penetrated), "the capsule never enters the real oven footprint from behind")
	check(float(blocked_walk.min_clearance) >= CAPSULE_RADIUS - OVERLAP_TOLERANCE,
		"the capsule never overlaps the real oven body from behind")
	check(blocked_end.z < -0.38, "the capsule stays outside the oven body's own back face")
	check(blocked_end.z > BACK_START.z + 0.03, "the capsule really walked against the oven")
	_free_nodes([blocked_body])
	await _wait_physics(2)
	var side_body := _capsule(SIDE_START)
	side_body.heading = Vector3(-1, 0, 0)
	var side_walk := await _walk(side_body, SIDE_FRAMES, installed)
	side_end = side_walk.end
	check(not bool(side_walk.penetrated), "the capsule never enters the real oven footprint from the side")
	check(float(side_walk.min_clearance) >= CAPSULE_RADIUS - OVERLAP_TOLERANCE,
		"the capsule never overlaps the real oven body from the side")
	check(side_end.x > 0.70 and side_end.x < 0.90, "the capsule stops against the oven's own side face")
	check(side_end.x < SIDE_START.x - 0.03, "the side capsule really moved before it stopped")
	_free_nodes([side_body])
	await _wait_physics(2)

	# 5. The legal work approach stays walkable: a real capsule really arrives on the apron.
	var worker_body := _capsule(APPROACH_START)
	worker_body.seek = work_target
	var approach_walk := await _walk(worker_body, APPROACH_FRAMES, installed)
	apron_min_clearance = float(approach_walk.min_clearance)
	apron_closest = worker_body.closest_seek
	apron_arrival = worker_body.global_position.distance_to(work_target)
	check(not bool(approach_walk.penetrated), "the legal approach never enters the oven body")
	check(apron_min_clearance >= CAPSULE_RADIUS - OVERLAP_TOLERANCE,
		"the legal approach never overlaps the new oven solid")
	check(apron_closest <= arrival_radius,
		"a real capsule reaches inside the authoritative arrival radius of the work target")
	check(apron_arrival <= arrival_radius,
		"the capsule ends the approach standing on the work target")
	var walking_seconds := float(Time.get_ticks_msec() - walking_started) / 1000.0

	# Park the walking body on the apron before sensing, so every sight sample stands still.
	worker_body.seek = Vector3.INF
	worker_body.heading = Vector3.ZERO
	worker_body.velocity = Vector3.ZERO
	await _wait_physics(1)

	# 6. Line of sight from that same apron, against a real occluding wall.
	var resident := "fictional:worker"
	_los_body = worker_body
	_sight = BakeSight.new()
	root.add_child(_sight)
	_sight.configure(fake, {resident: worker_body}, _los_visuals)
	for stand in [work_target, work_target + Vector3(0.55, 0, 0.30),
			work_target + Vector3(-0.60, 0, 0.15), OVEN_AT + Vector3(0.0, 0.0, 1.60)]:
		var spot: Vector3 = stand
		check(_xz_clearance(spot, installed) >= CAPSULE_RADIUS,
			"legal apron spot %s stands clear of the oven solid" % str(spot))
		worker_body.position = spot
		var clear_report := await _perception(resident, POINT_ID)
		check(not bool(clear_report.get("blocked", true)),
			"the apron at %s has a clear segment to the oven target" % str(spot))
		check(bool(clear_report.get("observed", false)),
			"the component observes the oven target from the apron at %s" % str(spot))
	apron_observed = true
	worker_body.position = work_target
	_wall = _occluding_wall(Vector3(1.6, 1.2, 0.06), Vector3(0.0, 1.35, 0.50))
	await _wait_physics(2)
	var blocked_report := await _perception(resident, POINT_ID)
	wall_occluder = blocked_report.get("occluder")
	wall_is_occluder = wall_occluder == _wall
	check(bool(blocked_report.get("blocked", false)),
		"a real wall between the apron eye and the oven target blocks the segment")
	check(wall_is_occluder, "the measured occluder is the wall itself, not the new oven solid")
	check(not bool(blocked_report.get("observed", true)),
		"the component does not see the oven through the real wall")
	wall_observed = 0 if not bool(blocked_report.get("observed", true)) else 1
	_free_nodes([_wall])
	_wall = null
	await _wait_physics(2)
	var reopened_report := await _perception(resident, POINT_ID)
	check(not bool(reopened_report.get("blocked", true)) and bool(reopened_report.get("observed", false)),
		"removing the wall restores the same clear observation")

	# 7. The real core still grants knowledge only for the unblocked physical verdict, and the
	#    authoritative flour, food and baking rules are untouched by the new solid.
	_free_nodes([_los_visuals])
	await _wait_physics(2)
	_write_fixture(path, baking_fixture())
	check(FileAccess.file_exists(path), "the fixture file really exists on disk")
	town = CoreBakingTown.new()
	check(town.load_from(path).ok, "fictional baking fixture loads")
	var spec := {"id": POINT_ID, "label": "Public oven", "initial_flour": 1, "position": [0, 0, 0], "access": "public"}
	check(town.transaction(path, func(): return town.install_baking_route(spec, 1, "development_gm:physics-oven")).ok,
		"reviewed finite oven installs")
	var core_visuals := BakingVisuals.new()
	root.add_child(core_visuals)
	core_visuals.configure(town)
	_los_visuals = core_visuals
	check(core_visuals.get_child_count() == 1, "the real core point has one oven display")
	var core_box := _oven_box(core_visuals, POINT_ID)
	check((core_box.get("size", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(1.0, 1.0, 0.76))
		and (core_box.get("center", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0.0, 0.5, 0.0)),
		"the real core-backed oven display carries the same solid body")
	var baker := "fictional:forge"
	var witness := "fictional:ember"
	town.host_move(witness, Vector3(8, 0, 8))
	town.host_move("fictional:birch", Vector3(-9, 0, 6))
	town.host_move(baker, work_target)
	worker_body.position = work_target
	_sight.configure(town, {baker: worker_body}, core_visuals)
	town.require_baking_visibility(Callable(_sight, "can_observe"))
	_wall = _occluding_wall(Vector3(1.6, 1.2, 0.06), Vector3(0.0, 1.35, 0.50))
	await _wait_physics(2)
	var blocked_before: Dictionary = town.snapshot()
	check((await _tick(town, path, 0.0)).ok, "advance(0) with the wall present succeeds")
	var blocked_after: Dictionary = town.snapshot()
	check(blocked_after.life.events == blocked_before.life.events,
		"a blocked apron emits no baking observation event")
	check(int(blocked_after.godot.baking.points[POINT_ID].flour_remaining) == 1,
		"a blocked apron leaves the public flour unchanged")
	core_blocked_knowledge = town.resident_view(baker).baking_points.size()
	check(core_blocked_knowledge == 0,
		"a real wall between the apron and the oven grants the resident no baking knowledge")
	_free_nodes([_wall])
	_wall = null
	await _wait_physics(2)
	check((await _tick(town, path, 0.0)).ok, "advance(0) after removing the wall succeeds")
	var knowledge: Array = town.resident_view(baker).baking_points
	core_clear_knowledge = knowledge.size()
	check(knowledge.size() == 1 and int(knowledge[0].last_observed_flour) == 1,
		"the same apron now personally observes the real public flour")
	check(str(knowledge[0].knowledge_source) == "personal_line_of_sight_observation",
		"the knowledge is attributed to the resident's own line of sight")
	check(town.resident_view(witness).baking_points.is_empty(),
		"a distant resident inside the same fixture gains nothing")
	var observations: Array = town.snapshot().life.events.filter(func(event): return event.get("type") == "baking_point_observed")
	check(observations.size() == 1 and observations[0].recipient_ids == [baker],
		"exactly one, personal, baking observation exists")
	var option := "baking:bake:" + POINT_ID
	check(town.trade_options(baker).any(func(entry): return entry.get("id") == option),
		"the observation creates the ordinary baking option")
	check(town.transaction(path, func(): return town.submit_trade(baker, option, "fixture:physics-bake", "opengameagent_fixture")).ok,
		"the resident voluntarily starts the bake")
	var station: Vector3 = town.destination(baker, "bake_bread")
	check(station.is_equal_approx(work_target),
		"the bake destination is still the apron in front of the mouth")
	town.host_move(baker, station)
	worker_body.position = station
	check((await _tick(town, path, 60.0)).ok, "the elapsed bake completes")
	var baked: Dictionary = town.snapshot()
	var terminal: Dictionary = baked.godot.baking.commands.get("fixture:physics-bake", {}).get("result", {})
	check(str(terminal.get("code", "")) == "bread_baked" and int(terminal.get("quantity", 0)) == 1,
		"the terminal receipt is one real loaf")
	check(int(baked.godot.baking.points[POINT_ID].flour_remaining) == 0
		and int(baked.godot.baking.ledgers[POINT_ID][baker].held) == 1,
		"remaining flour becomes exactly one held loaf")
	check(int(town.account(baker).food) == 2, "the real eatable food account receives the loaf")
	check(int(baked.godot.baking.points[POINT_ID].flour_remaining)
		+ int(baked.godot.baking.ledgers[POINT_ID][baker].held)
		+ int(baked.godot.baking.ledgers[POINT_ID][baker].eaten) == 1,
		"flour conservation holds across remaining, held and eaten")
	check(town._validate_state(baked).ok, "the authoritative baking state still validates")

	# 8. Cleanup and honest evidence.
	_free_nodes([_wall, worker_body, core_visuals, _los_visuals, _sight, _runner])
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var payload := {"suite": "town_baking_physics", "checks": checks, "failures": failures,
		"paid_calls": 0, "physics_fixture": true,
		"fixture_location": "user://" if path.begins_with("user://") else "res://tmp",
		"walking_seconds": walking_seconds, "total_seconds": float(Time.get_ticks_msec() - started) / 1000.0,
		"legacy_mesh_only_walkthrough": legacy_end.z > -0.38 and bool(legacy_walk.penetrated),
		"legacy_end_z": legacy_end.z, "blocked_end_z": blocked_end.z, "side_end_x": side_end.x,
		"apron_min_clearance_m": apron_min_clearance,
		"apron_closest_to_work_target_m": apron_closest, "apron_arrival_m": apron_arrival,
		"apron_observed_from_work_target": apron_observed,
		"wall_was_the_occluder": wall_is_occluder,
		"wall_blocked_observation": wall_observed == 0,
		"core_knowledge_while_blocked": core_blocked_knowledge,
		"core_knowledge_when_clear": core_clear_knowledge,
		"scope": "standalone physics fixture over primitives with the real BakingPoints projection, the real sight component and one fixture-backed real core; the real 16-house town placement, its art and its navigation mesh bake are NOT measured here"}
	var success: bool = failures == 0
	success = success and bool(payload.legacy_mesh_only_walkthrough)
	success = success and wall_is_occluder and bool(payload.wall_blocked_observation)
	success = success and int(payload.core_knowledge_while_blocked) == 0
	success = success and int(payload.core_knowledge_when_clear) == 1
	payload["success"] = success
	print(JSON.stringify(payload))
	quit(0 if success else 1)
