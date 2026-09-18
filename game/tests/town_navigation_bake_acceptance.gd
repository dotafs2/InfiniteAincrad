extends SceneTree
## Compare the new helper to the previous implicit radius rounding, on real colliders.
## The reference bakes intentionally emit the old radius warning; normal scene runs must not.

const Navigation = preload("res://spatial/town_navigation.gd")
var checks := 0
var failures: Array = []
var results: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func collider(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.position = at

func run() -> void:
	for cell in [0.10, 0.15]:
		var world := Node3D.new()
		root.add_child(world)
		collider(world, Vector3(20, 0.4, 20), Vector3(0, -0.2, 0))
		collider(world, Vector3(2, 2, 6), Vector3(0, 1, 0))
		var navigation = Navigation.new()
		navigation.bake_cell_size = cell
		world.add_child(navigation)
		navigation.build()
		await process_frame
		# Settle map changes between cases (different cell sizes on the same World3D).
		for _frame in 3:
			await physics_frame
		var actual: NavigationMesh = navigation.navigation_mesh
		check(navigation.enabled, "bake ready from sibling static colliders at cell %s" % cell)
		var reference: NavigationMesh = actual.duplicate()
		reference.clear()
		reference.agent_radius = 0.25
		var geometry := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(reference, geometry, world)
		print("REFERENCE_RADIUS_WARNING_EXPECTED cell=%s" % cell)
		NavigationServer3D.bake_from_source_geometry_data(reference, geometry)
		check(actual.get_vertices() == reference.get_vertices(), "unchanged walkable vertices at cell %s" % cell)
		var polygons_equal := actual.get_polygon_count() == reference.get_polygon_count()
		if polygons_equal:
			for i in actual.get_polygon_count():
				polygons_equal = polygons_equal and actual.get_polygon(i) == reference.get_polygon(i)
		check(polygons_equal, "unchanged walkable polygons at cell %s" % cell)
		# Frame counts alone do not establish completion of the server's async map
		# iteration after the previous case was removed. Synchronize before querying.
		NavigationServer3D.map_force_update(navigation.region.get_navigation_map())
		var path := NavigationServer3D.map_get_path(navigation.region.get_navigation_map(),
			Vector3(-5, 0.01, 0), Vector3(5, 0.01, 0), true)
		check(path.size() > 2, "route detours around sibling wall at cell %s" % cell)
		if not path.is_empty():
			check(path[path.size() - 1].distance_to(Vector3(5, 0.01, 0)) < 0.1,
				"route reaches target beyond wall at cell %s" % cell)
		results.append({"cell_size": cell, "explicit_radius": actual.agent_radius,
			"vertices": actual.get_vertices().size(), "polygons": actual.get_polygon_count(),
			"vertices_equal": actual.get_vertices() == reference.get_vertices(),
			"polygons_equal": polygons_equal, "path_points": path.size()})
		world.queue_free()
		await process_frame
		await physics_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "results": results,
		"reference_radius_warnings_expected": 2, "model_calls": 0}))
	quit(0 if failures.is_empty() else 1)
