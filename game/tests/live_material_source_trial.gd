extends SceneTree
## Controlled acceptance on an exact disposable world copy. No model or gateway.
## The first walk is a harness-directed physical probe, not voluntary NPC adoption.
const World = preload("res://core/town_actions.gd")
const Street = preload("res://scenes/town_street.tscn")
var scene: Node
var args := {}
var spec := {}
var actor := "shared:well-keeper"
var checks := 0
var failures: Array = []
var phase := "boot"
var age := 0.0
var walked := 0.0
var max_step := 0.0
var last := Vector3.ZERO
var initial_iron := 0
var collected := 0
var started_work := 0.0
var labor_times: Array = []
var source_path := ""
var copy_path := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var parts := argument.trim_prefix("--").split("=", true, 1)
			if parts.size() == 2: args[parts[0]] = parts[1]
	source_path = str(args.get("source", ""))
	copy_path = str(args.get("town-save", ""))
	if source_path.is_empty() or copy_path.is_empty() or source_path.simplify_path() == copy_path.simplify_path() or FileAccess.file_exists(copy_path):
		push_error("Requires an existing source and a NEW distinct disposable --town-save copy")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(copy_path.get_base_dir())
	check(DirAccess.copy_absolute(source_path, copy_path) == OK, "copy exact existing world without reseeding")
	spec = JSON.parse_string(FileAccess.get_file_as_string(str(args["spec-file"])))
	var world := World.new()
	check(world.acquire_writer(copy_path).ok and world.load_from(copy_path).ok, "load and own disposable copy")
	var before: Dictionary = world.snapshot()
	check(world.transaction(copy_path, func(): return world.install_material_source(spec, int(args["source-seq"]), "development_gm:iron-physical-trial")).ok, "existing public need permits source installation")
	var after: Dictionary = world.snapshot()
	check(after.residents == before.residents and after.life.accounts == before.life.accounts and after.life.items == before.life.items and after.life.skills == before.life.skills, "installation grants no identity, inventory, Col or skill")
	check(after.life.events.slice(0, before.life.events.size()) == before.life.events, "full historical event prefix preserved")
	for id in world.active_ids():
		check(world.resident_view(id).material_sources.is_empty(), "installation does not inject knowledge into " + id)
	check(not world.transaction(copy_path, func(): return world.submit_trade(actor, "material:recover:" + spec.id, "trial:unknown-source", "opengameagent_fixture")).ok, "unknown source cannot be selected by guessing its id")
	initial_iron = world._trade_account(actor).iron
	world.release_writer(copy_path)
	Engine.time_scale = 3.0
	Engine.physics_ticks_per_second = 180
	start_scene.call_deferred()

func start_scene() -> void:
	scene = Street.instantiate()
	root.add_child(scene)
	scene.scripted_trade = true
	scene.paused = false
	last = scene.bodies[actor].position
	phase = "warmup"

func _physics_process(delta: float) -> bool:
	if phase == "done" or phase == "boot": return false
	age += delta
	if age > 440:
		check(false, "bounded physical trial completed within 440 game seconds")
		finish()
		return false
	if phase == "cold":
		if FileAccess.file_exists(copy_path + ".writer-lock"): return false
		var restored := World.new()
		check(restored.load_from(copy_path).ok, "production cold validation accepts final copy")
		check(restored.material_sources()[0].stock == 0 and restored._trade_account(actor).iron == initial_iron + spec.initial_stock, "cold restore preserves depletion and earned inventory")
		check(not restored.install_material_source(spec, int(args["source-seq"]), "development_gm:trial-refill").ok, "a new install command cannot refill the source")
		finish()
		return false
	var current: Vector3 = scene.bodies[actor].position
	var step := Vector2(current.x - last.x, current.z - last.z).length()
	walked += step
	max_step = maxf(max_step, step)
	last = current
	if phase == "warmup" and age > 2:
		check(scene.town_navigation != null and scene.town_navigation.enabled, "production navigation map ready")
		# Existing scene probe uses the same cached A*, RVO and move_and_slide.
		scene.probe_targets = {actor: Vector3(spec.position[0], spec.position[1], spec.position[2])}
		scene.probe_finished.clear()
		scene.probe_results.clear()
		scene.probe_leg = "controlled_source_trial"
		scene.probe_age = 0.0
		scene.probe_running = true
		phase = "walk"
	elif phase == "walk" and not scene.probe_running:
		check(scene.probe_results.size() == 1 and scene.probe_results[0].reached, "real body reaches exact GM source through fixed navigation")
		check(walked > 1.0 and max_step < 0.15, "walk covers real distance without teleporting")
		phase = "perceive"
	elif phase == "perceive":
		if scene.town.resident_view(actor).material_sources.is_empty(): return false
		var seen: Dictionary = scene.town.resident_view(actor).material_sources[0]
		check(seen.last_observed_stock == spec.initial_stock, "personal observation reports finite stock after physical approach")
		check(not JSON.stringify(scene.town.resident_view(actor)).contains("development_gm"), "personal view excludes developer installation metadata")
		begin_work()
	elif phase == "work" and scene.town.pending_job(actor).is_empty():
		var elapsed: float = scene.town.snapshot().godot.elapsed_seconds - started_work
		labor_times.append(elapsed)
		collected += 1
		check(elapsed >= 59.4, "each unit requires 60 seconds of physical work (one tick tolerance)")
		check(scene.town._trade_account(actor).iron == initial_iron + collected, "exactly one unit added to worker inventory")
		check(scene.town.material_sources()[0].stock == spec.initial_stock - collected, "each unit decrements finite source stock")
		if collected < spec.initial_stock:
			begin_work()
		else:
			check(not scene.town.perform_action(copy_path, actor, "material:recover:" + spec.id, "trial:depleted", "opengameagent_fixture").ok, "zero stock rejects additional recovery")
			check(scene.town.save_to(copy_path).ok, "save all labor receipts and depleted stock")
			scene.paused = true
			scene.queue_free()
			phase = "cold"
	return false

func begin_work() -> void:
	started_work = scene.town.snapshot().godot.elapsed_seconds
	var result: Dictionary = scene.town.perform_action(copy_path, actor, "material:recover:" + spec.id, "trial:recover:" + str(collected), "opengameagent_fixture")
	check(result.ok, "personally known source permits controlled recovery action")
	if not result.ok:
		finish()
		return
	phase = "work"

func finish() -> void:
	phase = "done"
	var result := {"suite": "live_material_source_copy_trial", "checks": checks, "failures": failures,
		"paid_calls": 0, "voluntary_adoption": false, "controlled_copy_trial": true,
		"world_source": source_path, "copy": copy_path, "time_scale": Engine.time_scale,
		"walked_metres": walked, "max_step_metres": max_step, "collected": collected,
		"labor_seconds": labor_times, "elapsed_game_seconds": age}
	var output := FileAccess.open(str(args["out"]), FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  ", true, true))
	output.close()
	print(JSON.stringify(result))
	if is_instance_valid(scene):
		scene.paused = true
		scene.queue_free()
	cleanup.call_deferred()

func cleanup() -> void:
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
