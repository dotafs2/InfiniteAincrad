extends SceneTree
## Zero-provider continuation of existing jobs in a disposable checkpoint copy.
## --town-restore disables legacy decisions; scripted_trade prevents idle choices.
const Scene = preload("res://scenes/town_street.tscn")
var scene: Node
var output := ""
var save := ""
var seconds := 75.0
var age := 0.0
var frames := 0
var samples: Array = []
var initial: Dictionary = {}
var ready_to_run := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="): save = arg.trim_prefix("--town-save=")
		if arg.begins_with("--probe-output="): output = arg.trim_prefix("--probe-output=")
		if arg.begins_with("--probe-seconds="): seconds = clampf(float(arg.trim_prefix("--probe-seconds=")), 5.0, 90.0)
	var allowed := ProjectSettings.globalize_path("res://../tmp/material-checkpoint-probe/").simplify_path() + "/"
	if not save.simplify_path().begins_with(allowed) or not output.simplify_path().begins_with(allowed) or save.simplify_path() == output.simplify_path() or FileAccess.file_exists(output) or not OS.get_cmdline_user_args().has("--town-restore") or OS.get_cmdline_user_args().has("--town-gateway"):
		push_error("Requires disposable tmp/material-checkpoint-probe paths and --town-restore; gateway forbidden")
		quit(2)
		return
	start.call_deferred()

func start() -> void:
	scene = Scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.model_turns != null or scene.town.pending_job("shared:carpenter").get("action") != "recover_material":
		quit(2)
		return
	initial = scene.town.snapshot().duplicate(true)
	scene.scripted_trade = true
	scene.paused = false
	ready_to_run = true

func _physics_process(delta: float) -> bool:
	if not ready_to_run: return false
	age += delta
	frames += 1
	if frames % 60 == 0:
		var body: CharacterBody3D = scene.bodies["shared:carpenter"]
		var target: Vector3 = scene.town.destination("shared:carpenter", "recover_material")
		var hits: Array = []
		for i in body.get_slide_collision_count():
			var collider = body.get_slide_collision(i).get_collider()
			hits.append(str(collider.get_path()) if collider is Node else str(collider))
		samples.append({"seconds": age, "position": [body.position.x, body.position.y, body.position.z], "distance": body.position.distance_to(target), "job": scene.town.pending_job("shared:carpenter").duplicate(true), "colliders": hits, "nav": scene.town_navigation.routes.get("shared:carpenter", {}).duplicate(true), "point_route": scene.place_steering._point_routes.get("shared:carpenter", {}).duplicate(true)})
	if age >= seconds or scene.town.pending_job("shared:carpenter").is_empty() or scene.paused:
		ready_to_run = false
		scene.paused = true
		finish.call_deferred()
	return false

func finish() -> void:
	var final: Dictionary = scene.town.snapshot()
	var command: String = initial.godot.materials.jobs["shared:carpenter"].command_id
	var receipt: Dictionary = final.godot.materials.commands[command].get("result", {})
	var checks := {
		"original_command_completed": receipt.get("command_id") == command and receipt.get("code") == "material_depleted",
		"job_closed": scene.town.pending_job("shared:carpenter").is_empty(),
		"finite_sources_unchanged": final.godot.materials.sources == initial.godot.materials.sources,
		"material_accounts_unchanged": final.life.accounts == initial.life.accounts,
		"no_model_controller": scene.model_turns == null,
		"history_prefix_retained": final.life.events.slice(0, initial.life.events.size()) == initial.life.events,
		"material_command_count_unchanged": final.godot.materials.commands.size() == initial.godot.materials.commands.size(),
	}
	var result := {"mode": "checkpoint_copy_physics_only", "paid_calls": 0, "seconds": age, "initial_seq": initial.life.seq, "final_seq": final.life.seq, "initial_job": initial.godot.materials.jobs["shared:carpenter"], "final_job": scene.town.pending_job("shared:carpenter"), "receipt": receipt, "samples": samples, "latest": scene.latest, "initial_sources": initial.godot.materials.sources, "final_sources": final.godot.materials.sources, "initial_accounts": initial.life.accounts, "final_accounts": final.life.accounts}
	result.checks = checks
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print(JSON.stringify({"seconds": age, "receipt": receipt, "final_job": result.final_job, "samples": samples.size(), "latest": scene.latest}))
	scene.town.release_writer(save)
	scene.queue_free()
	await process_frame
	quit(0 if checks.values().all(func(value): return value == true) else 1)
