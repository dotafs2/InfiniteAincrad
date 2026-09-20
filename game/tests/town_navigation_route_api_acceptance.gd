extends SceneTree
## API bridge acceptance for the static loaded-world MVP.

const Navigation = preload("res://spatial/town_navigation.gd")
const RouteConnector = preload("res://spatial/town_route_connector.gd")

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
	var resident_a := CharacterBody3D.new()
	resident_a.name = "ResidentA"
	resident_a.position = Vector3(0.0, 0.0, 0.0)
	var resident_b := CharacterBody3D.new()
	resident_b.name = "ResidentB"
	resident_b.position = Vector3(8.0, 3.0, 0.0)
	root.add_child(resident_a)
	root.add_child(resident_b)
	navigation.register_body("resident_A", resident_a)
	navigation.register_body("resident_B", resident_b)
	check(navigation.loaded_resident_ids().size() == 2, "loaded resident directory contains both residents")
	check(navigation.target_position_for("resident_B").distance_to(resident_b.global_position) < 0.01, "resident B resolves by stable ID")
	check(navigation.target_position_for("missing").is_finite() == false, "missing resident resolves as unavailable")

	check(navigation.register_route_region("street", resident_a.global_position), "street region registers through town navigation")
	check(navigation.register_route_region("upper_room", resident_b.global_position), "upper room registers through town navigation")
	var ladder := RouteConnector.new()
	ladder.connector_id = "ladder_01"
	ladder.connector_kind = "ladder"
	ladder.action_name = "climb"
	ladder.start_position = Vector3(4.0, 0.0, 0.0)
	ladder.end_position = Vector3(4.0, 3.0, 0.0)
	root.add_child(ladder)
	check(navigation.register_route_connector("ladder_01", "street", "upper_room",
		ladder.route_start_position(), ladder.route_end_position(), "ladder", "climb", 1.0, true, ladder), "ladder registers through town navigation")
	var route := navigation.route_between_regions("street", "upper_room")
	check(bool(route.get("ok", false)), "town navigation returns the global route")
	check(navigation.global_route_graph.route_stays_on_graph(route), "town navigation route stays on registered graph")
	check(route.get("target_region", "") == "upper_room", "town navigation preserves target region")

	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"loaded_residents": navigation.loaded_resident_ids(), "route": route}))
	quit(0 if failures.is_empty() else 1)
