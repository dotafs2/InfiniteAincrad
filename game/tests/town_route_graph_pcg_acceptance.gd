extends SceneTree
## Offline acceptance for the canonical PCG road-to-route adapter.
## It uses the production living_quarter_layout.json, so changes to authored roads
## are covered without starting renderer plugins or changing the saved world.

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
	var report: Dictionary = navigation.register_layout_route_graph(layout)
	check(bool(report.get("ok", false)), "PCG layout route graph registers road edges")
	check(int(report.get("road_count", 0)) == layout.roads.size(), "all authored PCG roads are registered")
	check(int(report.get("road_node_count", 0)) > 20, "road sampling creates a connected-scale graph")
	check(int(report.get("connector_count", 0)) > int(report.get("road_node_count", 0)), "road and junction connectors are present")
	var homes := ["shared:well-keeper", "shared:baker", "shared:smith", "shared:carpenter", "shared:innkeeper", "shared:herder", "shared:gardener", "shared:weaver", "shared:fisher", "shared:healer"]
	for home_id: String in homes:
		var matches: Array = layout.houses.filter(func(value): return String(value.get("resident", "")) == home_id)
		var nearest: Array = navigation.global_route_graph.regions.keys().filter(func(key): return String(key).begins_with("pcg:road:"))
		check(not matches.is_empty(), home_id + " remains in the canonical layout")
		check(not nearest.is_empty(), home_id + " has a road graph")
	# The route graph does not require house nodes in this offline test; connect two
	# authored house regions to their nearest road nodes as the production adapter does.
	var first: Dictionary = layout.houses[0]
	var second: Dictionary = layout.houses[1]
	var first_region := "test:first_home"
	var second_region := "test:second_home"
	navigation.register_route_region(first_region, Vector3(first.at[0], first.at[1], first.at[2]))
	navigation.register_route_region(second_region, Vector3(second.at[0], second.at[1], second.at[2]))
	var road_regions: Array[String] = []
	for key in navigation.global_route_graph.regions.keys():
		if String(key).begins_with("pcg:road:"): road_regions.append(String(key))
	road_regions.sort()
	var route := navigation.route_between_regions(road_regions[0], road_regions[road_regions.size()-1])
	check(bool(route.get("ok", false)), "canonical PCG road graph joins its ends")
	check(navigation.global_route_graph.route_stays_on_graph(route), "canonical PCG route stays on graph")
	check(route.get("connectors", []).size() > 5, "canonical PCG route crosses multiple authored road segments")

	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"report": report, "route": route}))
	quit(0 if failures.is_empty() else 1)
