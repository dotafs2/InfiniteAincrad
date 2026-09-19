extends SceneTree
## Pure physics regression for the bounded-only final approach used after A*.

const SocialSteering = preload("res://spatial/town_social_steering.gd")
const TARGET := Vector3(0.85, 0.22, 7.5)
const START := Vector3(2.0002768, 0.22, 7.5)
const BLOCKER := Vector3(1.5, 0.22, 7.5)
const ARRIVAL := 0.45

var checks := 0
var failures: Array[String] = []
var cases: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for spec in [
			{"name": "bounded_detour", "blocker": true, "occupied": false, "legacy": false},
			{"name": "bounded_occupied", "blocker": false, "occupied": true, "legacy": false},
			{"name": "legacy_occupied", "blocker": false, "occupied": true, "legacy": true}]:
		var probe := Probe.new()
		probe.blocker = bool(spec.blocker)
		probe.occupied = bool(spec.occupied)
		probe.legacy = bool(spec.legacy)
		root.add_child(probe)
		await probe.done
		cases[spec.name] = {"distance": probe.distance, "travel": probe.travel,
			"max_step": probe.max_step, "min_clearance": probe.min_clearance}
		probe.queue_free()
		await process_frame
	check(float(cases.bounded_detour.distance) <= ARRIVAL,
		"bounded-only steering reaches the unchanged target around a real capsule")
	check(float(cases.bounded_detour.travel) > 1.0 and float(cases.bounded_detour.max_step) < 0.1,
		"the detour is physical movement at the established step size")
	check(float(cases.bounded_detour.min_clearance) > -0.02,
		"the bounded detour does not penetrate the blocking body")
	check(float(cases.bounded_occupied.travel) < 0.001 and float(cases.bounded_occupied.distance) > ARRIVAL,
		"bounded-only steering returns zero when the unchanged target is physically occupied")
	check(float(cases.legacy_occupied.travel) > 0.40 and float(cases.legacy_occupied.distance) > ARRIVAL,
		"the established standalone social fallback still walks to contact without claiming arrival")
	print(JSON.stringify({"suite": "town_social_near_target_steering", "checks": checks,
		"failures": failures, "cases": cases, "paid_calls": 0}))
	quit(0 if failures.is_empty() else 1)

class Probe extends Node3D:
	signal done
	var blocker := false
	var occupied := false
	var legacy := false
	var mover: CharacterBody3D
	var steering := SocialSteering.new()
	var frames := 0
	var distance := INF
	var travel := 0.0
	var max_step := 0.0
	var min_clearance := INF
	var last := Vector3.ZERO

	func _ready() -> void:
		var ground := StaticBody3D.new()
		var ground_collider := CollisionShape3D.new()
		var ground_box := BoxShape3D.new()
		ground_box.size = Vector3(20.0, 0.2, 20.0)
		ground_collider.shape = ground_box
		ground_collider.position = Vector3(0.0, -0.12, 7.5)
		ground.add_child(ground_collider)
		add_child(ground)
		if blocker: _capsule(BLOCKER)
		if occupied: _capsule(TARGET)
		mover = CharacterBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.5
		collider.shape = shape
		collider.position.y = 0.75
		mover.add_child(collider)
		add_child(mover)
		mover.position = START
		last = mover.position

	func _capsule(at: Vector3) -> void:
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

	func _physics_process(delta: float) -> void:
		var direction: Vector3 = steering.direction_for("mover", "approach", mover, TARGET) if legacy \
			else steering.bounded_direction_for("mover", "approach", mover, TARGET)
		mover.velocity.x = direction.x * 1.35
		mover.velocity.z = direction.z * 1.35
		mover.velocity.y = -0.2 if mover.is_on_floor() else mover.velocity.y - 18.0 * delta
		mover.move_and_slide()
		frames += 1
		var step := mover.position - last
		step.y = 0.0
		travel += step.length()
		max_step = maxf(max_step, step.length())
		last = mover.position
		distance = _flat_distance(mover.position, TARGET)
		if blocker: min_clearance = minf(min_clearance, _flat_distance(mover.position, BLOCKER) - 0.5)
		if occupied: min_clearance = minf(min_clearance, _flat_distance(mover.position, TARGET) - 0.5)
		if frames >= 180 or (not legacy and distance <= 0.30):
			done.emit()
			set_physics_process(false)

	func _flat_distance(first: Vector3, second: Vector3) -> float:
		var offset := first - second
		offset.y = 0.0
		return offset.length()
