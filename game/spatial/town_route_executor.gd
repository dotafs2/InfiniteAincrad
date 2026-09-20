class_name TownRouteExecutor
extends RefCounted
## Executes a planned route for the MVP. Ordinary region travel is represented
## by the authored graph; connector transitions perform the required action and
## force the actor to the connector exit.


func execute(route: Dictionary, actor: Node3D, target_id: String = "") -> Dictionary:
	if not bool(route.get("ok", false)):
		return {"ok": false, "code": "route_not_executable"}
	var connector_results: Array[Dictionary] = []
	for edge in route.get("connectors", []):
		var connector_object: Object = edge.get("object")
		var forward := not bool(edge.get("reverse", false))
		if is_instance_valid(connector_object) and connector_object.has_method("execute"):
			connector_results.append(connector_object.call("execute", actor, forward))
		elif is_instance_valid(actor):
			# The graph remains executable in offline fixtures that use plain edge
			# records instead of scene connector nodes.
			actor.global_position = edge["end_position"]
			connector_results.append({
				"ok": true,
				"connector_id": edge["id"],
				"action": edge.get("action", "none"),
				"destination": actor.global_position,
			})
		else:
			return {"ok": false, "code": "actor_missing"}
	if is_instance_valid(actor) and route.has("target_position"):
		actor.global_position = route["target_position"]
	return {
		"ok": true,
		"target_id": target_id,
		"target_region": route.get("target_region", ""),
		"connector_results": connector_results,
		"final_position": actor.global_position if is_instance_valid(actor) else Vector3.INF,
	}
