extends SceneTree
## Offline acceptance for the original Town of Beginnings quarter study.

const QUARTER := preload("res://spatial/sao_town_quarter.gd")
const LAYOUT_PATH := "res://spatial/sao_town_quarter_layout.json"

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
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	check(layout.get("id", "") == "sao-town-of-beginnings-quarter-v1", "authored SAO reference layout loads")
	check(layout.get("roads", []).size() == 8, "quarter has eight radial/cross streets")
	check(layout.get("landmarks", []).size() == 7, "quarter has seven readable landmarks")
	var quarter := QUARTER.new()
	root.add_child(quarter)
	await process_frame
	check(quarter.built, "procedural quarter builds once")
	check(is_instance_valid(quarter.collision_body), "quarter owns a collision body")
	check(quarter.landmark_nodes.has("teleport_plaza"), "teleport plaza is addressable")
	check(quarter.landmark_nodes.has("black_iron_palace"), "palace landmark is addressable")
	check(quarter.landmark_nodes.has("central_market"), "market landmark is addressable")
	check(quarter.landmark_nodes.has("church"), "church landmark is addressable")
	check(quarter.landmark_nodes.has("smithy"), "smithy landmark is addressable")
	check(quarter.get_node_or_null("TownLandmarks") != null, "landmark group exists")
	check(quarter.get_node_or_null("RadialRoads") != null, "road group exists")
	check(quarter.get_node_or_null("FortifiedTownEdge") != null, "fortified edge exists")
	check(quarter.get_node_or_null("QuarterCamera") != null, "overview camera exists")
	var route_count := 0
	for road in layout.get("roads", []):
		var start := Vector2(float(road["from"][0]), float(road["from"][1]))
		var end := Vector2(float(road["to"][0]), float(road["to"][1]))
		check(start.distance_to(end) > 1.0, "road %s has useful length" % road["id"])
		route_count += 1
	check(route_count == 8, "all authored routes are checked")
	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"roads": layout.get("roads", []).size(), "landmarks": layout.get("landmarks", []).size()}))
	quit(0 if failures.is_empty() else 1)
