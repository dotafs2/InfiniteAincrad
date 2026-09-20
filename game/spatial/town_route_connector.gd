class_name TownRouteConnector
extends Node3D
## Authored straight-line transition used by the MVP global route graph.
##
## The connector intentionally does not perform placement or collision checks.
## Its two local endpoint markers are data for the route executor only.

signal action_triggered(connector_id: String, action: String)
signal traversed(connector_id: String, actor_id: String)

@export var connector_id: String = ""
@export var connector_kind: String = "generic"
@export var action_name: String = "none"
@export var bidirectional: bool = true
@export var travel_cost: float = 1.0
@export var start_position: Vector3 = Vector3.ZERO
@export var end_position: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var actor_id_property: String = "route_actor_id"


func route_start_position() -> Vector3:
	return to_global(start_position) if is_inside_tree() else transform * start_position


func route_end_position() -> Vector3:
	return to_global(end_position) if is_inside_tree() else transform * end_position


func trigger_action() -> void:
	if action_name.is_empty() or action_name == "none":
		return
	action_triggered.emit(connector_id, action_name)
	# Door components already expose this semantic action. A connector can be
	# placed as their child without introducing a second door implementation.
	var owner := get_parent()
	while owner != null:
		if owner.has_method("set_door_open"):
			owner.call("set_door_open", true)
			break
		owner = owner.get_parent()


func execute(actor: Node3D, forward: bool = true) -> Dictionary:
	trigger_action()
	var destination := route_end_position() if forward else route_start_position()
	if is_instance_valid(actor):
		# MVP movement is intentionally forced. Physics, avoidance, and collision
		# validation belong to later runtime modes and offline authoring tests.
		actor.global_position = destination
	var actor_id := ""
	if is_instance_valid(actor) and actor.has_meta(actor_id_property):
		actor_id = String(actor.get_meta(actor_id_property))
	traversed.emit(connector_id, actor_id)
	return {
		"ok": true,
		"connector_id": connector_id,
		"action": action_name,
		"destination": destination,
		"actor_id": actor_id,
	}
