extends SceneTree
## Controlled physical continuation of a copied seq148 checkpoint; no model calls.
const Scene = preload("res://scenes/town_street.tscn")
const World = preload("res://core/town_actions.gd")
const ACTOR := "shared:carpenter"
const COMMAND := "fixture:self-repair-seq148"
var scene: Node
var path := ""
var out := ""
var phase := "boot"
var seconds := 0.0
var frames := 0
var checks := 0
var failures: Array = []
var last := Vector3.ZERO
var walked := 0.0
var max_step := 0.0
var max_speed := 0.0
var restored := false
var saved: Dictionary = {}
var source_seq := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL " + message)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="): path = arg.trim_prefix("--town-save=")
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if path.is_empty() or out.is_empty() or not FileAccess.file_exists(path):
		quit(2)
		return
	Engine.time_scale = 4.0
	_open.call_deferred()

func _open() -> void:
	scene = Scene.instantiate()
	scene.scripted_trade = true
	root.add_child(scene)
	scene.paused = false
	last = scene.town.position_of(ACTOR)
	if phase == "swap":
		check(_same(saved, scene.town.snapshot()), "fresh scene preserves every saved field before advancing")
		check(scene.town.pending_job(ACTOR).command_id == COMMAND, "original native job survives scene restart")
		restored = true
		phase = "running"

func _physics_process(delta: float) -> bool:
	if phase in ["done", "swap"] or not is_instance_valid(scene): return false
	frames += 1
	seconds += delta
	if frames < 6: return false
	if phase == "boot":
		source_seq = int(scene.town.snapshot().life.seq)
		check(source_seq == 148, "copied active lineage starts at seq148")
		var result: Dictionary = scene.town.perform_action(path, ACTOR, "ability:self_repair:seed:axe:handle", COMMAND, "opengameagent_fixture")
		check(result.ok, "actual carpenter prerequisites admit self repair in controlled copy")
		phase = "running"
		if not result.ok:
			_finish()
			return false
	var position: Vector3 = scene.town.position_of(ACTOR)
	var step := Vector2(position.x - last.x, position.z - last.z).length()
	walked += step
	max_step = maxf(max_step, step)
	last = position
	var body: CharacterBody3D = scene.bodies[ACTOR]
	max_speed = maxf(max_speed, Vector2(body.velocity.x, body.velocity.z).length())
	var receipt: Dictionary = scene.town.action_receipt(COMMAND)
	if receipt.status != "pending":
		check(receipt.status == "completed", "real physical trip and work completed: " + str(receipt.result.code))
		check(restored, "mid-journey cold scene restart occurred")
		check(walked > 10 and max_step < .6 and max_speed <= 1.37, "body walked actual metres at the established speed without teleporting")
		check(scene.town._item("seed:axe").handle == 100 and scene.town._item("seed:axe").edge == 20, "only owned handle repaired")
		check(scene.town._trade_account(ACTOR).wood == 0, "original single wood unit consumed")
		var terminals := 0
		for event in scene.town.snapshot().life.events:
			if event.get("operation_id") == COMMAND and event.type == "self_repair_completed": terminals += 1
		check(terminals == 1, "one completion across restart")
		check(scene.town.save_to(path).ok, "complete physical world saves")
		var cold := World.new()
		check(cold.load_from(path).ok and _same(cold.snapshot(), scene.town.snapshot()), "final full-state cold restore")
		_finish()
		return false
	if not restored and walked > 5:
		scene.paused = true
		check(scene.town.save_to(path).ok, "mid-walk save")
		saved = scene.town.snapshot()
		check(DirAccess.copy_absolute(path, out.get_base_dir().path_join("mid-walk.world.json")) == OK, "immutable mid-walk evidence copied")
		phase = "swap"
		scene.queue_free()
		_resume.call_deferred()
	if seconds > 360:
		check(false, "physical repair exceeded bounded 360 world seconds")
		_finish()
	return false

func _resume() -> void:
	await process_frame
	await process_frame
	check(not FileAccess.file_exists(path + ".writer-lock"), "owned scene released its writer lock")
	_open()

func _finish() -> void:
	phase = "done"
	scene.paused = true
	var result := {"suite": "town_self_repair_scene", "checks": checks, "failures": failures, "paid_calls": 0,
		"controlled_copy": true, "source_seq": source_seq, "final_seq": scene.town.snapshot().life.seq,
		"walked_metres": walked, "max_speed_mps": max_speed, "max_sample_step_m": max_step,
		"world_seconds": seconds, "resumed": restored, "receipt": scene.town.action_receipt(COMMAND)}
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ", true, true))
	file.close()
	print(JSON.stringify(result))
	scene.queue_free()
	_exit.call_deferred()

func _exit() -> void:
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same(a[i], b[i]): return false
		return true
	return a == b
