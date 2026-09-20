extends SceneTree
## Full-map acceptance for the current graph-only NPC navigation contract.
##
## The fixture deliberately ignores physics, collision, clearance and visual
## geometry. It uses the same canonical PCG layout as the production adapter,
## then drives one disposable NPC through every ordered pair of registered
## regions. This proves graph connectivity and connector execution before the
## production resident loop opts into the route graph.

const Navigation = preload("res://spatial/town_navigation.gd")
const Executor = preload("res://spatial/town_route_executor.gd")

var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func _region_ids(graph) -> Array[String]:
	var result: Array[String] = []
	for raw_id in graph.regions.keys():
		result.append(String(raw_id))
	result.sort()
	return result


func run() -> void:
	var navigation = Navigation.new()
	root.add_child(navigation)
	var layout_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://spatial/living_quarter_layout.json"))
	check(layout_variant is Dictionary, "canonical PCG layout parses as a dictionary")
	if not layout_variant is Dictionary:
		_print_and_quit()
		return
	var report: Dictionary = navigation.register_layout_route_graph(layout_variant)
	var graph = navigation.global_route_graph
	var region_ids := _region_ids(graph)
	check(bool(report.get("ok", false)), "canonical PCG route graph registers")
	check(region_ids.size() == int(report.get("region_count", -1)), "report region count matches graph")
	check(region_ids.size() > 100, "full-map fixture sees the authored road-scale graph")
	check(int(report.get("connector_count", 0)) >= region_ids.size() - 1, "graph has enough connectors for one connected map")

	var npc := CharacterBody3D.new()
	npc.name = "FullMapTestNpc"
	npc.set_meta("route_actor_id", "full_map_test_npc")
	root.add_child(npc)
	var executor = Executor.new()
	# A full all-pairs Dijkstra run is unnecessarily quadratic for this contract.
	# Instead, exercise both directions between one root and every region (which
	# proves the graph is strongly connected) and execute every authored connector
	# directly in both directions. This covers every PCG region and edge while
	# keeping the acceptance test fast enough for every local map change.
	var root_id: String = region_ids[0] if not region_ids.is_empty() else ""
	var successful_routes := 0
	var failed_routes := 0
	var max_connectors := 0
	var first_failure := ""
	var expected_routes := maxi(0, region_ids.size() - 1) * 2
	for target_id in region_ids:
		if target_id == root_id: continue
		for pair in [[root_id, target_id], [target_id, root_id]]:
			var start_id: String = pair[0]
			var destination_id: String = pair[1]
			var route: Dictionary = graph.find_route(start_id, destination_id)
			if not bool(route.get("ok", false)):
				failed_routes += 1
				if first_failure.is_empty(): first_failure = "%s -> %s: route unavailable" % [start_id, destination_id]
				continue
			check(graph.route_stays_on_graph(route), "route stays on graph: %s -> %s" % [start_id, destination_id])
			check(String(route.get("start_region", "")) == start_id, "route preserves start region: %s -> %s" % [start_id, destination_id])
			check(String(route.get("target_region", "")) == destination_id, "route preserves target region: %s -> %s" % [start_id, destination_id])
			var target_position: Vector3 = graph.regions[destination_id]["position"]
			route["target_position"] = target_position
			npc.global_position = graph.regions[start_id]["position"]
			var execution: Dictionary = executor.execute(route, npc, "full_map_test_npc")
			check(bool(execution.get("ok", false)), "route executes: %s -> %s" % [start_id, destination_id])
			check(String(execution.get("target_region", "")) == destination_id, "execution preserves target ID: %s -> %s" % [start_id, destination_id])
			check(npc.global_position.distance_to(target_position) < 0.001, "NPC reaches graph target: %s -> %s" % [start_id, destination_id])
			var connector_results: Array = execution.get("connector_results", [])
			var connector_path: Array = route.get("connectors", [])
			check(connector_results.size() == connector_path.size(), "connector count is preserved: %s -> %s" % [start_id, destination_id])
			for index in mini(connector_results.size(), connector_path.size()):
				check(String(connector_results[index].get("connector_id", "")) == String(connector_path[index].get("id", "")),
					"connector order is preserved: %s -> %s step %d" % [start_id, destination_id, index])
			successful_routes += 1
			max_connectors = maxi(max_connectors, connector_path.size())
	# Directly execute every authored edge so no PCG connector is untested.
	for raw_edge in graph.connectors.values():
		var edge: Dictionary = raw_edge
		for reverse in [false, true] if bool(edge.get("bidirectional", false)) else [false]:
			var traversed := edge.duplicate(true)
			var start_id := String(edge.get("from_region", ""))
			var destination_id := String(edge.get("to_region", ""))
			if reverse:
				start_id = String(edge.get("to_region", ""))
				destination_id = String(edge.get("from_region", ""))
				traversed["from_region"] = start_id
				traversed["to_region"] = destination_id
				traversed["start_position"] = edge.get("end_position", Vector3.ZERO)
				traversed["end_position"] = edge.get("start_position", Vector3.ZERO)
				traversed["reverse"] = true
			var direct_route := {"ok": true, "start_region": start_id, "target_region": destination_id,
				"regions": [start_id, destination_id], "connectors": [traversed], "cost": edge.get("cost", 0.0),
				"revision": graph.revision, "target_position": graph.regions[destination_id]["position"]}
			check(graph.route_stays_on_graph(direct_route), "authored connector stays on graph: %s" % edge.get("id", ""))
			npc.global_position = graph.regions[start_id]["position"]
			var direct_result: Dictionary = executor.execute(direct_route, npc, "full_map_test_npc")
			check(bool(direct_result.get("ok", false)), "authored connector executes: %s" % edge.get("id", ""))
			check(npc.global_position.distance_to(graph.regions[destination_id]["position"]) < 0.001,
				"authored connector reaches its target: %s" % edge.get("id", ""))
			successful_routes += 1
			expected_routes += 1

	check(failed_routes == 0, "every region is reachable in both directions: %s" % first_failure)
	check(successful_routes == expected_routes, "all representative routes and authored connectors execute (%d/%d)" % [successful_routes, expected_routes])
	_print_and_quit({
		"report": report,
		"region_count": region_ids.size(),
		"expected_routes": expected_routes,
		"successful_routes": successful_routes,
		"failed_routes": failed_routes,
		"max_connector_hops": max_connectors,
	})


func _print_and_quit(extra: Dictionary = {}) -> void:
	var payload := {"ok": failures.is_empty(), "checks": checks, "failures": failures}
	for key in extra: payload[key] = extra[key]
	print(JSON.stringify(payload))
	quit(0 if failures.is_empty() else 1)
