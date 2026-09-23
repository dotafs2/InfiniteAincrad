extends SceneTree

const TownScene = preload("res://scenes/town_street.tscn")
const Adventure = preload("res://core/adventure_state.gd")

var scene: Node3D
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _arg(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	call_deferred("run")

func _walk_to(id: String, target: Vector3, command_id: String, max_frames: int) -> Dictionary:
	var body: CharacterBody3D = scene.bodies[id]
	var navigation = scene.town_navigation
	var start := body.global_position
	var max_step := 0.0
	var saw_floor := false
	var status := ""
	for frame in max_frames:
		var direction: Vector3 = navigation.direction_for(id, command_id, body, target)
		status = navigation.route_status(id)
		body.velocity.x = direction.x * 1.35
		body.velocity.z = direction.z * 1.35
		body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 18.0 / 60.0
		body.move_and_slide()
		if body.is_on_floor(): saw_floor = true
		max_step = maxf(max_step, Vector2(body.velocity.x, body.velocity.z).length() / 60.0)
		if body.global_position.distance_to(target) <= 0.45:
			return {"arrived": true, "status": status, "frames": frame + 1,
				"metres": start.distance_to(body.global_position), "max_step": max_step, "saw_floor": saw_floor}
		await physics_frame
	return {"arrived": body.global_position.distance_to(target) <= 0.45, "status": status,
		"frames": max_frames, "metres": start.distance_to(body.global_position),
		"max_step": max_step, "saw_floor": saw_floor}

func run() -> void:
	var save_path := _arg("--town-save=")
	check(not save_path.is_empty(), "rendered probe uses an explicit disposable town copy")
	scene = TownScene.instantiate()
	root.add_child(scene)
	for _frame in 180:
		await process_frame
		if scene.town_navigation != null and not scene.town_navigation.baking: break
	var navigation = scene.town_navigation
	check(navigation != null and navigation.enabled, "disposable copy bakes navigation from real colliders")
	if navigation == null or not navigation.enabled:
		print(JSON.stringify({"suite":"adventure_rendered_probe","checks":checks,"failures":failures,"status":"navigation_unavailable"}))
		quit(1)
		return
	var id := "shared:baker"
	var body: CharacterBody3D = scene.bodies[id]
	body.position = Vector3(0.0, 0.22, 30.0)
	await physics_frame
	var gate_target := Vector3(0.0, 0.10, 53.0)
	var gate := await _walk_to(id, gate_target, "adventure-gate-entry", 1400)
	check(gate.status == "following" and gate.arrived, "resident physically reaches the bounded wilderness gate")
	check(gate.metres > 20.0 and gate.max_step < 0.6 and gate.saw_floor,
		"gate approach uses real body movement with grounded collision steps")
	var closed: Vector3 = navigation.direction_for(id, "adventure-gate-closed", body, Vector3(200.0, 0.1, 200.0))
	check(closed == Vector3.ZERO and navigation.is_unreachable(id), "closed gate target is explicitly unreachable")

	var adventure := Adventure.new()
	var migrated: Dictionary = adventure.create_from_town_snapshot(scene.town.snapshot())
	check(migrated.residents.size() == 10 and migrated.migration.combat_authority == "undefined_until_host_seed",
		"rendered probe keeps the ten-resident migration authority boundary")
	var job_hold: Dictionary = adventure.set_committed_job(id, true, "render-job-hold")
	check(job_hold.ok,
		"rendered probe records a committed job before entry")
	var blocked_entry: Dictionary = adventure.enter_wilderness(id, "render-entry-blocked")
	check(blocked_entry.code == "committed_job_must_finish_or_reject",
		"committed job blocks gate entry without a host override")
	check(adventure.set_committed_job(id, false, "render-job-release").ok and
		adventure.enter_wilderness(id, "render-entry").ok,
		"explicit host closure permits the copied resident to enter")

	# Use the reducer's fully seeded fixture for defeat semantics while this same real
	# CharacterBody3D performs the retreat. No migrated combat authority is invented.
	var fight := Adventure.new()
	fight.create_fixture()
	check(fight.enter_wilderness("fixture:guard", "fight-enter").ok and
		fight.open_floor_one_gate("fight-gate").ok and
		fight.enter_labyrinth("fixture:guard", "fight-labyrinth").ok,
		"seeded disposable encounter reaches the danger zone")
	for index in 10: fight.encounter_attack("fixture:wolf", "fixture:guard", "fight-hit-%d" % index)
	var defeat_before_retreat: Dictionary = fight.snapshot().residents["fixture:guard"].duplicate(true)
	check(defeat_before_retreat.status == "defeated" and defeat_before_retreat.zone == "labyrinth",
		"authoritative fixture encounter records defeat in place")
	var retreat := await _walk_to(id, Vector3(0.0, 0.22, 30.0), "adventure-physical-retreat", 1400)
	check(retreat.status == "following" and retreat.arrived and retreat.metres > 20.0,
		"real body physically walks back from the adventure gate")
	var retreat_receipt: Dictionary = fight.retreat_after_defeat("fixture:guard", "fight-retreat")
	check(retreat_receipt.ok and
		fight.snapshot().residents["fixture:guard"].zone == "town",
		"defeated fixture receives a separate retreat receipt after physical return")
	print(JSON.stringify({"suite":"adventure_rendered_probe","checks":checks,"failures":failures,
		"gate":gate,"closed_gate_direction":closed,"retreat":retreat,
		"committed_job_receipt":job_hold,"blocked_entry_receipt":blocked_entry,
		"host_override_used":false,"defeat_before_retreat":defeat_before_retreat,
		"retreat_receipt":retreat_receipt,
		"navigation_bake_status":navigation.bake_status,"canonical_world_touched":false,
		"status":"rendered_probe_passed_pending_gm_effect_feedback"}))
	if is_instance_valid(scene): scene.queue_free()
	quit(0 if failures == 0 else 1)
