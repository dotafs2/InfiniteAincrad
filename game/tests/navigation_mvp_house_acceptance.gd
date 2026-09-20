extends SceneTree
## Scene-level acceptance for the visual MVP house fixture.

const HouseScene = preload("res://scenes/navigation_mvp_house.tscn")
const RouteExecutor = preload("res://spatial/town_route_executor.gd")

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
	var house := HouseScene.instantiate()
	root.add_child(house)
	await process_frame
	check(house.route_graph != null, "visual fixture owns a route graph")
	check(house.connectors.size() == 3, "visual fixture registers door, ladder and upper door")
	var route: Dictionary = house.route_graph.find_route("street", "target_room")
	check(bool(route.get("ok", false)), "visual fixture exposes an A to B route")
	check(house.route_graph.route_stays_on_graph(route), "visual fixture route stays on graph")
	check(route.get("regions", []) == ["street", "room_1f", "room_2f", "target_room"], "visual fixture route reaches the upper target room")
	var actor := Node3D.new()
	actor.set_meta("route_actor_id", "resident_A")
	root.add_child(actor)
	route["target_position"] = Vector3(6.5, 3.85, 0.0)
	var result: Dictionary = RouteExecutor.new().execute(route, actor, "resident_B")
	check(bool(result.get("ok", false)), "visual fixture route executes")
	check(String(result.get("target_id", "")) == "resident_B", "visual fixture keeps target identity")
	check(actor.global_position.distance_to(route["target_position"]) < 0.01, "visual fixture execution reaches target B")
	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"connector_count": 3, "route": route}))
	house.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
