extends SceneTree
## Acceptance for the first formal resident integration: graph-only steering.
## Physics and collision are intentionally bypassed; this checks that the same
## PCG graph can drive a resident body to every authored home region.

const Navigation = preload("res://spatial/town_navigation.gd")

var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var navigation = Navigation.new()
	root.add_child(navigation)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spatial/living_quarter_layout.json"))
	navigation.register_layout_route_graph(layout)
	navigation.graph_only_routes = true
	var graph = navigation.global_route_graph
	var npc := CharacterBody3D.new()
	npc.name = "FormalGraphResident"
	root.add_child(npc)
	var root_id := ""
	for raw_id in graph.regions.keys():
		root_id = String(raw_id)
		break
	check(not root_id.is_empty(), "formal graph integration has a root region")
	npc.global_position = graph.regions[root_id]["position"]
	var home_ids: Array[String] = []
	for raw_id in graph.regions.keys():
		var id := String(raw_id)
		if id.begins_with("pcg:home:"): home_ids.append(id)
	home_ids.sort()
	check(home_ids.size() == 10, "formal graph integration sees ten resident homes")
	var reached := 0
	for home_id in home_ids:
		var target: Vector3 = graph.regions[home_id]["position"]
		var target_id := "home:" + home_id.trim_prefix("pcg:home:")
		npc.global_position = graph.regions[root_id]["position"]
		var command := "formal-route:" + home_id
		var arrived := false
		for step in 3000:
			if npc.global_position.distance_to(target) <= 0.45:
				arrived = true
				break
			var direction: Vector3 = navigation.graph_direction_for_target(
				"formal-resident", command, npc, target_id, target)
			if navigation.graph_route_is_unreachable("formal-resident"):
				break
			if direction.length() <= 0.0:
				arrived = npc.global_position.distance_to(target) <= 0.45
				if arrived: break
			else:
				# Use a bounded test step and clamp it to the current graph waypoint;
				# production frames use a smaller 1.35 m/s step and cannot overshoot
				# the 0.20 m waypoint tolerance.
				var move_target := target
				var saved_route: Dictionary = navigation.graph_routes.get("formal-resident", {})
				var path: Array = saved_route.get("regions", [])
				var waypoint_index := int(saved_route.get("waypoint_index", 0))
				if waypoint_index + 1 < path.size():
					move_target = graph.regions[String(path[waypoint_index + 1])]["position"]
				var distance := npc.global_position.distance_to(move_target)
				npc.position += direction * minf(0.10, distance)
		check(not navigation.graph_route_is_unreachable("formal-resident"), "formal route remains connected to %s" % home_id)
		check(arrived, "formal resident reaches %s" % home_id)
		check(navigation.route_region_for_target(target_id) == home_id,
			"stable target ID remains bound to %s" % home_id)
		if arrived: reached += 1
	check(reached == home_ids.size(), "formal resident reaches every authored home")
	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"home_count": home_ids.size(), "reached": reached, "graph_only_routes": navigation.graph_only_routes}))
	quit(0 if failures.is_empty() else 1)
