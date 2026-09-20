extends SceneTree
## Offline MVP acceptance: route A to B must stay on the graph, trigger a door,
## cross a ladder, and finish at target B. No collision or placement checks are
## part of this contract.

const RouteGraph = preload("res://spatial/town_route_graph.gd")
const RouteConnector = preload("res://spatial/town_route_connector.gd")
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
	var graph = RouteGraph.new()
	graph.add_region("street", Vector3(0.0, 0.0, 0.0))
	graph.add_region("room_1f", Vector3(4.0, 0.0, 0.0))
	graph.add_region("room_2f", Vector3(4.0, 3.0, 0.0))
	graph.add_region("target_room", Vector3(8.0, 3.0, 0.0))

	var door = RouteConnector.new()
	door.connector_id = "door_01"
	door.connector_kind = "door"
	door.action_name = "open_door"
	door.start_position = Vector3(1.0, 0.0, 0.0)
	door.end_position = Vector3(2.0, 0.0, 0.0)
	var ladder = RouteConnector.new()
	ladder.connector_id = "ladder_01"
	ladder.connector_kind = "ladder"
	ladder.action_name = "climb"
	ladder.start_position = Vector3(4.0, 0.0, 0.0)
	ladder.end_position = Vector3(4.0, 3.0, 0.0)
	root.add_child(door)
	root.add_child(ladder)

	check(graph.add_connector("door_01", "street", "room_1f", door.route_start_position(), door.route_end_position(), "door", "open_door", 1.0, true, door), "door registers")
	check(graph.add_connector("ladder_01", "room_1f", "room_2f", ladder.route_start_position(), ladder.route_end_position(), "ladder", "climb", 1.0, true, ladder), "ladder registers")
	check(graph.add_connector("upper_door", "room_2f", "target_room", Vector3(5.0, 3.0, 0.0), Vector3(7.0, 3.0, 0.0), "door", "open_door"), "upper door registers")

	var route: Dictionary = graph.find_route("street", "target_room")
	route["target_position"] = Vector3(8.0, 3.0, 0.0)
	check(bool(route.get("ok", false)), "A to B route exists")
	check(graph.route_stays_on_graph(route), "every route step belongs to the graph")
	check(route.get("regions", []) == ["street", "room_1f", "room_2f", "target_room"], "route crosses door, ladder, and upper door in order")
	check(route.get("connectors", []).size() == 3, "route has exactly three connectors")

	var actor := Node3D.new()
	actor.set_meta("route_actor_id", "resident_A")
	root.add_child(actor)
	actor.global_position = Vector3.ZERO
	var execution: Dictionary = RouteExecutor.new().execute(route, actor, "resident_B")
	check(bool(execution.get("ok", false)), "route executes")
	check(String(execution.get("target_id", "")) == "resident_B", "execution preserves target identity B")
	check(actor.global_position.distance_to(Vector3(8.0, 3.0, 0.0)) < 0.01, "execution finishes at target B position")

	var reverse: Dictionary = graph.find_route("target_room", "street")
	check(bool(reverse.get("ok", false)), "bidirectional connectors support reverse route")
	check(graph.route_stays_on_graph(reverse), "reverse route stays on the graph")
	check(reverse.get("regions", []) == ["target_room", "room_2f", "room_1f", "street"], "reverse route returns through the same connectors")

	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"route": route, "reverse": reverse, "target_id": execution.get("target_id", "")}))
	quit(0 if failures.is_empty() else 1)
