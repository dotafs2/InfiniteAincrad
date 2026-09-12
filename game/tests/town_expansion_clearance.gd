extends SceneTree
## Offline clearance survey: samples a grid around the market and reports, per point,
## the ground height and whether a 1.1 m sphere is free of static/body geometry.
## Used to place the expansion on measured free space. No model calls, disposable save.
const TownScene := preload("res://scenes/town_street.tscn")

var _scene: Node = null
var _frames := 0
var _out := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_scene = TownScene.instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var space: PhysicsDirectSpaceState3D = (_scene as Node3D).get_world_3d().direct_space_state
	var rows: Array = []
	for x in range(-40, 42, 4):
		for z in range(-90, 62, 4):
			var probe := Vector3(x, 1.0, z)
			var down := PhysicsRayQueryParameters3D.create(Vector3(x, 30.0, z), Vector3(x, -2.0, z))
			down.collide_with_areas = false
			var hit: Dictionary = space.intersect_ray(down)
			var ground_y: float = float(hit.position.y) if hit else 0.0
			var sphere := SphereShape3D.new()
			sphere.radius = 0.6
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis(), Vector3(x, ground_y + 1.2, z))
			query.collision_mask = 0xFFFFFFFF
			query.collide_with_areas = false
			var hits: Array = space.intersect_shape(query, 1)
			var blocked: bool = not hits.is_empty()
			rows.append({"x": x, "z": z, "ground_y": (hit.position.y if hit else null),
				"free": (not blocked) and (hit != null), "ground": (hit != null)})
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
		var handle := FileAccess.open(_out, FileAccess.WRITE)
		handle.store_string(JSON.stringify({"grid_step": 4, "sphere_radius": 0.6, "rows": rows,
			"corridor": _corridor(space)}))
		handle.close()
	var free := rows.filter(func(r): return r["free"]).size()
	print(JSON.stringify({"points": rows.size(), "free": free,
		"free_x_range": [rows.filter(func(r): return r["free"]).map(func(r): return r["x"]).min(),
			rows.filter(func(r): return r["free"]).map(func(r): return r["x"]).max()],
		"free_z_range": [rows.filter(func(r): return r["free"]).map(func(r): return r["z"]).min(),
			rows.filter(func(r): return r["free"]).map(func(r): return r["z"]).max()]}))
	quit(0)
	return true

func _corridor(space: PhysicsDirectSpaceState3D) -> Array:
	## Along-street samples at body height: is there a walkable gap between market and the
	## open land south of it, and where does the market's solid edge sit?
	var samples: Array = []
	for x in [-8, -4, 0, 4, 8, 12]:
		for z in range(8, 76, 4):
			var down := PhysicsRayQueryParameters3D.create(Vector3(x, 30.0, z), Vector3(x, -2.0, z))
			var hit: Dictionary = space.intersect_ray(down)
			var ground_y: float = float(hit.position.y) if hit else 0.0
			var sphere := SphereShape3D.new()
			sphere.radius = 0.6
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis(), Vector3(x, ground_y + 1.2, z))
			query.collision_mask = 0xFFFFFFFF
			var hits: Array = space.intersect_shape(query, 1)
			samples.append({"x": x, "z": z, "ground": (hit != null), "free": hits.is_empty()})
	return samples
