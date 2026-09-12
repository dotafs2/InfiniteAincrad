extends SceneTree
## Short physical junction test: one plain 0.25 m / 1.75 m NPC-style capsule crosses the old
## market floor edge into the new neighbourhood and back with ordinary move_and_slide at the
## original 1.35 m/s walk speed. No teleport, no step-up assist, no test-only motor. It also
## probes the floor height on both sides so a real step would be visible rather than inferred.
const TownScene := preload("res://scenes/town_street.tscn")

var _scene: Node = null
var _walker: CharacterBody3D = null
var _frames := 0
var _out := ""
var _leg := 0
var _results: Array = []
var _positions: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_scene = TownScene.instantiate()
	root.add_child(_scene)

func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_floor_probe()
		_walker = CharacterBody3D.new()
		_walker.name = "JunctionWalker"
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.25
		capsule.height = 1.75
		collider.shape = capsule
		collider.position.y = 0.875
		_walker.add_child(collider)
		_walker.position = Vector3(0.0, 0.95, 30.0)
		root.add_child(_walker)
		return false
	if _frames < 6:
		return false
	_drive()
	## Two ~13 m legs at the original 1.35 m/s need ~20 s; the cap stays short (30 s) on purpose.
	if _frames > 1800:
		_finish(["junction walk did not finish within 1800 frames"])
	return false

func _floor_probe() -> void:
	var space: PhysicsDirectSpaceState3D = (_scene as Node3D).get_world_3d().direct_space_state
	var samples: Array = []
	for z in [30, 32, 34, 35, 36, 37, 38, 40, 42, 44]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 20, z), Vector3(0, -2, z))
		var hit: Dictionary = space.intersect_ray(ray)
		samples.append({"z": z, "y": (hit.position.y if hit else null)})
	_results.append({"floor_profile": samples})

func _drive() -> void:
	## leg 0: 30 -> 44 (into the neighbourhood), leg 1: 44 -> 30 (back into the market).
	var target_z := 44.0 if _leg == 0 else 30.0
	var delta_z := target_z - _walker.position.z
	if absf(delta_z) < 0.8:
		_results.append({"leg": _leg, "reached_z": _walker.position.z,
			"position": [_walker.position.x, _walker.position.y, _walker.position.z]})
		_leg += 1
		if _leg > 1:
			_finish([])
		return
	_walker.velocity.z = signf(delta_z) * 1.35
	_walker.velocity.x = clampf(-_walker.position.x * 2.0, -0.6, 0.6)
	_walker.velocity.y = -1.0 if not _walker.is_on_floor() else 0.0
	_walker.move_and_slide()
	if _frames % 30 == 0 and _positions.size() < 60:
		_positions.append([_walker.position.z, _walker.position.y])

func _finish(failures: Array) -> void:
	var profile: Array = _results[0]["floor_profile"] if not _results.is_empty() else []
	var crossed: bool = _leg > 1
	var legs: Array = _results.filter(func(item): return item.has("leg"))
	if not crossed:
		failures.append("capsule did not cross the junction in both directions")
	var result := {"suite": "town_expansion_junction", "crossed_both_ways": crossed,
		"walk_speed_mps": 1.35, "capsule_radius_m": 0.25,
		"floor_profile": profile, "legs": legs, "trace": _positions,
		"failures": failures, "model_calls": 0}
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
		var handle := FileAccess.open(_out, FileAccess.WRITE)
		handle.store_string(JSON.stringify(result))
		handle.close()
	print(JSON.stringify({"crossed_both_ways": crossed, "failures": failures,
		"legs": legs}))
	quit(0 if failures.is_empty() else 1)
