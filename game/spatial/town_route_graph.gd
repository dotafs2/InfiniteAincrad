class_name TownRouteGraph
extends RefCounted
## Global route graph for the MVP world snapshot.
##
## Regions are abstract walkable areas. Connectors are explicit graph edges for
## doors, ladders, elevators, and other one-step transitions. The graph does
## not validate geometry; authoring and offline acceptance tests own that work.

var regions: Dictionary = {}
var connectors: Dictionary = {}
var revision: int = 0


func clear() -> void:
	regions.clear()
	connectors.clear()
	revision += 1


func add_region(region_id: String, world_position: Vector3 = Vector3.ZERO) -> bool:
	if region_id.is_empty():
		return false
	regions[region_id] = {
		"id": region_id,
		"position": world_position,
	}
	revision += 1
	return true


func add_connector(
	connector_id: String,
	from_region: String,
	to_region: String,
	start_position: Vector3,
	end_position: Vector3,
	kind: String = "generic",
	action: String = "none",
	cost: float = 1.0,
	 bidirectional: bool = true,
	connector_object: Object = null
) -> bool:
	if connector_id.is_empty() or from_region.is_empty() or to_region.is_empty():
		return false
	if not regions.has(from_region) or not regions.has(to_region):
		return false
	if not is_finite(cost) or cost < 0.0:
		return false
	# Deliberately do not validate endpoint placement. The MVP treats every
	# connector as an authored straight-line graph edge.
	connectors[connector_id] = {
		"id": connector_id,
		"from_region": from_region,
		"to_region": to_region,
		"start_position": start_position,
		"end_position": end_position,
		"kind": kind,
		"action": action,
		"cost": cost,
		"bidirectional": bidirectional,
		"object": connector_object,
	}
	revision += 1
	return true


func remove_connector(connector_id: String) -> bool:
	if not connectors.has(connector_id):
		return false
	connectors.erase(connector_id)
	revision += 1
	return true


func find_route(start_region: String, target_region: String) -> Dictionary:
	if not regions.has(start_region) or not regions.has(target_region):
		return _failure("unknown_region")
	if start_region == target_region:
		return {
			"ok": true,
			"start_region": start_region,
			"target_region": target_region,
			"regions": [start_region],
			"connectors": [],
			"cost": 0.0,
			"revision": revision,
		}

	# Dijkstra is intentionally small and deterministic for the MVP. The route
	# graph is expected to contain authored regions and connectors, not millions
	# of per-voxel nodes.
	var frontier: Array[String] = [start_region]
	var distance: Dictionary = {start_region: 0.0}
	var parent: Dictionary = {}
	while not frontier.is_empty():
		var current := _pop_lowest(frontier, distance)
		if current == target_region:
			break
		for edge in _outgoing(current):
			var next_region: String = edge["to_region"]
			var next_distance: float = float(distance[current]) + float(edge["cost"])
			if not distance.has(next_region) or next_distance < float(distance[next_region]):
				distance[next_region] = next_distance
				parent[next_region] = {
					"from_region": current,
					"connector": edge,
				}
				if not frontier.has(next_region):
					frontier.append(next_region)

	if not distance.has(target_region):
		return _failure("unreachable")

	var region_path: Array[String] = []
	var connector_path: Array[Dictionary] = []
	var cursor := target_region
	while cursor != start_region:
		region_path.push_front(cursor)
		var step: Dictionary = parent[cursor]
		connector_path.push_front(step["connector"])
		cursor = String(step["from_region"])
	region_path.push_front(start_region)
	return {
		"ok": true,
		"start_region": start_region,
		"target_region": target_region,
		"regions": region_path,
		"connectors": connector_path,
		"cost": float(distance[target_region]),
		"revision": revision,
	}


func route_stays_on_graph(route: Dictionary) -> bool:
	if not bool(route.get("ok", false)):
		return false
	var region_path: Array = route.get("regions", [])
	var connector_path: Array = route.get("connectors", [])
	if region_path.is_empty() or connector_path.size() + 1 != region_path.size():
		return false
	for index in connector_path.size():
		var edge: Dictionary = connector_path[index]
		if not connectors.has(String(edge.get("id", ""))):
			return false
		if String(edge.get("from_region", "")) != String(region_path[index]):
			return false
		if String(edge.get("to_region", "")) != String(region_path[index + 1]):
			return false
	return String(region_path[0]) == String(route.get("start_region", "")) and \
		String(region_path[region_path.size() - 1]) == String(route.get("target_region", ""))


func _outgoing(region_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in connectors.values():
		var edge: Dictionary = raw
		if String(edge["from_region"]) == region_id:
			result.append(edge.duplicate())
		elif bool(edge["bidirectional"]) and String(edge["to_region"]) == region_id:
			var reverse := edge.duplicate()
			reverse["from_region"] = edge["to_region"]
			reverse["to_region"] = edge["from_region"]
			var start: Vector3 = edge["start_position"]
			reverse["start_position"] = edge["end_position"]
			reverse["end_position"] = start
			reverse["reverse"] = true
			result.append(reverse)
	return result


func _pop_lowest(frontier: Array[String], distance: Dictionary) -> String:
	var best_index := 0
	for index in range(1, frontier.size()):
		if float(distance[frontier[index]]) < float(distance[frontier[best_index]]):
			best_index = index
	return frontier.pop_at(best_index)


func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"regions": [],
		"connectors": [],
		"revision": revision,
	}
