extends SceneTree
## Controlled copied-world proof: physical notice, opaque obstruction, travel and recovery.
const Scene = preload("res://scenes/town_street.tscn")
const World = preload("res://core/town_actions.gd")
const READER := "shared:well-keeper"
const DISTANT := "shared:smith"
const SOURCE := "street:iron-salvage-20260918"
const COMMAND := "fixture:notice-collection"
var scene: Node
var path := ""
var output := ""
var phase := "boot"
var frames := 0
var age := 0.0
var checks := 0
var failures: Array = []
var wall: StaticBody3D
var last := Vector3.ZERO
var walked := 0.0
var max_step := 0.0
var max_speed := 0.0
var restored := false
var saved: Dictionary = {}
var initial: Dictionary = {}
var read_proof: Dictionary = {}
var arrived_observed := false

func _collector() -> String:
	return READER

func _prepare_read() -> void:
	pass

func _start_collection(world) -> Dictionary:
	return world.perform_action(path, _collector(), "material:recover:" + SOURCE, COMMAND, "opengameagent_fixture")

func _extra_evidence() -> Dictionary:
	return {}

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("FAIL " + text)

func _initialize() -> void:
	var source := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source = arg.trim_prefix("--source=")
		if arg.begins_with("--town-save="): path = arg.trim_prefix("--town-save=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if source.is_empty() or path.is_empty() or output.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(DirAccess.copy_absolute(source, path) == OK, "exact disposable copy created")
	Engine.time_scale = 4.0
	_open.call_deferred()

func _open() -> void:
	scene = Scene.instantiate()
	scene.scripted_trade = true
	scene.paused = true
	root.add_child(scene)
	scene.paused = phase != "swap"
	last = scene.town.position_of(_collector())
	if phase == "swap":
		check(_same(saved, scene.town.snapshot()), "cold scene retains every field before advancing")
		check(scene.town.pending_job(_collector()).command_id == COMMAND, "same collection command survives restart")
		check(scene.town._known_materials(_collector())[SOURCE].stock == null, "mid-walk restore preserves unknown stock")
		restored = true
		phase = "walk"

func _physics_process(delta: float) -> bool:
	if phase in ["done", "swap"] or not is_instance_valid(scene): return false
	age += delta
	frames += 1
	if frames < 6: return false
	var world = scene.town
	if phase == "boot":
		initial = world.snapshot()
		check(initial.life.seq == 148 and world._known_materials(READER).is_empty(), "paused seq148 acquired no resource knowledge on load")
		check(scene.material_notice.placed and scene.material_notice.solid != null, "notice is an actual visible colliding prop")
		check(world.position_of(READER).distance_to(world.material_notice_position()) < world.MATERIAL_NOTICE_RANGE, "reader naturally starts within sign range")
		check(world.position_of(READER).distance_to(world._vector(world.material_sources()[0].position)) > 40, "source remains remote at its original position")
		scene.material_notice.hide()
		check(not scene.material_notice.observe().ok and world.snapshot() == initial, "hidden prop grants no knowledge")
		scene.material_notice.show()
		var start: Vector3 = scene.bodies[READER].position + Vector3(0, 1.55, 0)
		var end: Vector3 = scene.material_notice.notice_point()
		wall = StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(.55, 2.5, .55)
		collider.shape = shape
		wall.add_child(collider)
		root.add_child(wall)
		wall.position = (start + end) / 2.0
		phase = "blocked"
		frames = 0
		return false
	if phase == "blocked":
		check(not scene.material_notice.visible_from(READER), "real opaque collider blocks notice ray")
		check(world.transaction(path, func(): return world.observe_material_notice(READER, scene.material_notice.visible_from(READER))).ok and world._known_materials(READER).is_empty(), "occluded reader gains nothing")
		wall.queue_free()
		_prepare_read()
		phase = "read"
		frames = 0
		return false
	if phase == "read":
		check(scene.material_notice.visible_from(READER), "removing test obstruction exposes the real sign")
		check(world.transaction(path, func(): return scene.material_notice.observe()).ok, "production notice perception commits")
		if world._known_materials(READER).is_empty():
			check(false, "reader did not learn posted location")
			_finish()
			return false
		read_proof = world.resident_view(READER).material_sources[0]
		check(read_proof.last_observed_stock == null, "notice records stock as unknown")
		check(world._known_materials(DISTANT).is_empty(), "distant smith receives no broadcast")
		check(world.snapshot().life.accounts == initial.life.accounts and world.material_sources()[0].stock == 3, "notice changes no material or inventory")
		var result: Dictionary = _start_collection(world)
		check(result.ok, "earned notice knowledge admits existing collection action")
		if not result.ok:
			_finish()
			return false
		scene.paused = false
		phase = "walk"
		return false
	if phase != "walk": return false
	var position: Vector3 = world.position_of(_collector())
	var step := Vector2(position.x - last.x, position.z - last.z).length()
	walked += step
	max_step = maxf(max_step, step)
	last = position
	var body: CharacterBody3D = scene.bodies[_collector()]
	max_speed = maxf(max_speed, Vector2(body.velocity.x, body.velocity.z).length())
	var known: Dictionary = world._known_materials(_collector())[SOURCE]
	if known.stock != null: arrived_observed = true
	var receipt: Dictionary = world.action_receipt(COMMAND)
	if receipt.status != "pending":
		check(receipt.status == "completed", "actual route and sorting complete")
		check(restored and arrived_observed, "trip resumed and later observed actual source")
		check(walked > 40 and max_step < .6 and max_speed <= 1.37, "ordinary physical walk without teleport or speed change")
		check(world.material_sources()[0].stock == 2 and world.material_sources()[0].recovered == 1 and world._trade_account(_collector()).iron == 1, "one conserved iron recovered after work")
		check(world.resident_view(_collector()).material_sources[0].knowledge_source == "personal_line_of_sight_observation", "arrival replaces route uncertainty with actual sight")
		check(world.save_to(path).ok, "physical outcome durably saved")
		var cold := World.new()
		check(cold.load_from(path).ok and _same(cold.snapshot(), world.snapshot()), "complete final state cold-restores")
		_finish()
		return false
	if not restored and walked > 5:
		scene.paused = true
		check(world.save_to(path).ok, "save actual mid-walk job")
		saved = world.snapshot()
		check(DirAccess.copy_absolute(path, output.get_base_dir().path_join("mid-walk.world.json")) == OK, "preserve mid-walk evidence")
		phase = "swap"
		scene.queue_free()
		_resume.call_deferred()
	if age > 500:
		check(false, "route exceeded bounded 500 world seconds")
		_finish()
	return false

func _resume() -> void:
	await process_frame
	await process_frame
	check(not FileAccess.file_exists(path + ".writer-lock"), "owned scene released writer lock")
	_open()

func _finish() -> void:
	phase = "done"
	scene.paused = true
	var result := {"suite": "town_material_notice_scene", "checks": checks, "failures": failures, "paid_calls": 0,
		"controlled_copy": true, "source_seq": 148, "final_seq": scene.town.snapshot().life.seq,
		"walked_metres": walked, "max_speed_mps": max_speed, "max_sample_step_m": max_step,
		"resumed": restored, "directly_observed": arrived_observed, "read_proof": read_proof,
		"receipt": scene.town.action_receipt(COMMAND), "notice": scene.material_notice.evidence()}
	result.merge(_extra_evidence(), true)
	var file := FileAccess.open(output, FileAccess.WRITE)
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
