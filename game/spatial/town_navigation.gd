extends Node3D
const TownRouteGraph = preload("res://spatial/town_route_graph.gd")
const TownRouteConnector = preload("res://spatial/town_route_connector.gd")
## One world navigation map for the real town colliders.
##
## The region is baked once after market/expansion construction. Resident jobs keep their
## authoritative destination; this helper only supplies a collision-aware steering point and
## reports an unreachable target. No save state, command, destination, or completion gate is
## rewritten here.

const WALKABLE_AABB := AABB(Vector3(-34.0, -0.5, -80.0), Vector3(68.0, 4.0, 177.0))
const BODY_RADIUS := 0.25
const BODY_HEIGHT := 1.5
const WALK_SPEED := 1.35

var region: NavigationRegion3D
var navigation_mesh: NavigationMesh
var agents: Dictionary = {}
## Current loaded-world resident lookup. The MVP intentionally has no knowledge
## filtering: callers may resolve any registered resident ID.
var resident_directory: Dictionary = {}
var routes: Dictionary = {}
var safe_velocities: Dictionary = {}
var safe_velocity_ready: Dictionary = {}
var baking := false
var enabled := false
var bake_status := "not_started"
var walkable_bounds := WALKABLE_AABB
var bake_cell_size := 0.10
var bake_cell_height := 0.01
var bake_max_climb := 0.04
var dynamic_detours := false
## First-stage PCG routing mode. When enabled, the loaded-world graph owns the
## long route and the resident loop may ignore physics/collision resolution.
## It is opt-in so the older navmesh path remains available for legacy worlds.
var graph_only_routes := false
const GRAPH_WAYPOINT_RADIUS := 0.20
var crowd_detour_count := 0
var crowd_detour_attempts := 0
var door_portals: Array = []
var door_crossings := 0
var path_updates := 0
## Static world-snapshot route graph used by the MVP connector flow. The existing
## baked navmesh remains the local surface planner; this graph adds authored
## doors, ladders, and other straight-line transitions without changing current
## town movement until a caller opts into it.
var global_route_graph = TownRouteGraph.new()
var route_regions_by_resident: Dictionary = {}
## Stable semantic target -> graph region bindings. A moving resident or a public
## point may change its exact position, but its long route must not change merely
## because the nearest sampled road node changed at a boundary.
var route_regions_by_target: Dictionary = {}
var route_graph_build_report: Dictionary = {}
var graph_routes: Dictionary = {}


func register_route_region(region_id: String, world_position: Vector3 = Vector3.ZERO) -> bool:
	return global_route_graph.add_region(region_id, world_position)


func register_route_connector(
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
	return global_route_graph.add_connector(connector_id, from_region, to_region,
		start_position, end_position, kind, action, cost, bidirectional, connector_object)


func route_between_regions(from_region: String, to_region: String) -> Dictionary:
	return global_route_graph.find_route(from_region, to_region)


func route_region_for_resident(resident_id: String) -> String:
	return String(route_regions_by_resident.get(resident_id, ""))


func register_route_target(target_id: String, world_position: Vector3, region_id: String = "") -> String:
	## Bind a semantic target once. If the caller has no authored region, choose the
	## nearest graph sample now and keep that choice stable for the target's lifetime.
	if target_id.is_empty(): return ""
	if route_regions_by_target.has(target_id):
		return String(route_regions_by_target[target_id])
	var resolved := region_id if not region_id.is_empty() else _nearest_graph_region(world_position)
	if resolved.is_empty(): return ""
	route_regions_by_target[target_id] = resolved
	return resolved


func route_region_for_target(target_id: String, world_position: Vector3 = Vector3.INF) -> String:
	if target_id.is_empty(): return ""
	if route_regions_by_target.has(target_id):
		return String(route_regions_by_target[target_id])
	return register_route_target(target_id, world_position)


func route_between_residents(from_resident_id: String, to_resident_id: String) -> Dictionary:
	var from_region := route_region_for_resident(from_resident_id)
	var to_region := route_region_for_resident(to_resident_id)
	if from_region.is_empty() or to_region.is_empty():
		return {"ok": false, "code": "unknown_resident_route_region", "regions": [], "connectors": []}
	var route := route_between_regions(from_region, to_region)
	route["target_id"] = to_resident_id
	var target := target_position_for(to_resident_id)
	if target.is_finite(): route["target_position"] = target
	return route


func register_layout_route_graph(layout: Dictionary, quarter: Node3D = null, resident_houses: Dictionary = {}) -> Dictionary:
	## Build the static MVP graph from the same layout that drives PCG roads.
	## Road samples are abstract graph points; baked NavigationServer geometry remains
	## responsible for ordinary local movement. This method is called once per loaded world.
	global_route_graph.clear()
	route_regions_by_resident.clear()
	route_regions_by_target.clear()
	var road_nodes_by_key: Dictionary = {}
	var road_nodes: Array[Dictionary] = []
	var road_samples: Array[Array] = []
	var roads: Array = layout.get("roads", [])
	var region_count := 0
	var edge_count := 0
	for road_index in roads.size():
		var description: Dictionary = roads[road_index]
		var points: Array = description.get("points", [])
		var width := float(description.get("width", 4.0))
		var samples: Array[Dictionary] = []
		for point_index in range(maxi(0, points.size()-1)):
			var a := Vector2(float(points[point_index][0]), float(points[point_index][1]))
			var b := Vector2(float(points[point_index+1][0]), float(points[point_index+1][1]))
			var count := maxi(1, ceili(a.distance_to(b) / 4.0))
			for sample_index in count:
				var p := a.lerp(b, float(sample_index) / float(count))
				samples.append(_register_route_road_node(road_nodes_by_key, road_nodes, p, quarter, width, road_index))
		if not points.is_empty():
			var last: Array = points[points.size()-1]
			var last_point := Vector2(float(last[0]), float(last[1]))
			samples.append(_register_route_road_node(road_nodes_by_key, road_nodes, last_point, quarter, width, road_index))
		road_samples.append(samples)
		for sample_index in range(1, samples.size()):
			var previous: Dictionary = samples[sample_index-1]
			var current: Dictionary = samples[sample_index]
			if previous["id"] == current["id"]: continue
			if register_route_connector("pcg:road:%d:%d" % [road_index, sample_index-1], previous["id"], current["id"],
				previous["position"], current["position"], "road", "none", maxf(.1, previous["position"].distance_to(current["position"])), true):
				edge_count += 1
	# Join sampled points where the authored road widths overlap. This handles a
	# cross-street endpoint landing between two samples on the main road.
	for left_index in road_nodes.size():
		var left: Dictionary = road_nodes[left_index]
		for right_index in range(left_index+1, road_nodes.size()):
			var right: Dictionary = road_nodes[right_index]
			if left["road_index"] == right["road_index"]: continue
			var distance := Vector2(left["position"].x, left["position"].z).distance_to(Vector2(right["position"].x, right["position"].z))
			var threshold := clampf((float(left["width"]) + float(right["width"])) * .35, 1.25, 2.75)
			if distance > threshold: continue
			if register_route_connector("pcg:junction:%d:%d" % [left_index, right_index], left["id"], right["id"],
				left["position"], right["position"], "road_junction", "none", maxf(.1, distance), true):
				edge_count += 1
	# A resident house is a graph region reached through the nearest road point.
	# The connector is parented to the real house so its action can open that door.
	var houses: Array = layout.get("houses", [])
	for entry: Dictionary in houses:
		var resident_id := String(entry.get("resident", ""))
		if resident_id.is_empty(): continue
		var entrance := Vector3(float(entry["at"][0]), float(entry["at"][1]), float(entry["at"][2]))
		var house: Node3D = resident_houses.get(resident_id) as Node3D
		if resident_houses.has(resident_id) and is_instance_valid(house) and quarter != null:
			entrance = quarter.entrances.get(resident_id, entrance)
		var nearest := _nearest_route_node(road_nodes, entrance)
		if nearest.is_empty(): continue
		var home_region := "pcg:home:" + resident_id
		var home_position := entrance + Vector3.UP
		if is_instance_valid(house): home_position = house.global_position + Vector3.UP
		register_route_region(home_region, home_position)
		var connector_object: TownRouteConnector = null
		if is_instance_valid(house):
			connector_object = TownRouteConnector.new()
			connector_object.name = "RouteDoor_" + resident_id.replace(":", "_")
			connector_object.connector_id = "pcg:door:" + resident_id
			connector_object.connector_kind = "door"
			connector_object.action_name = "open_door"
			house.add_child(connector_object)
			connector_object.start_position = house.to_local(nearest["position"])
			connector_object.end_position = house.to_local(home_position)
		var door_start: Vector3 = nearest["position"]
		var door_end: Vector3 = home_position
		if is_instance_valid(connector_object):
			door_start = connector_object.route_start_position()
			door_end = connector_object.route_end_position()
		if register_route_connector("pcg:door:" + resident_id, nearest["id"], home_region, door_start, door_end,
			"door", "open_door", maxf(.1, door_start.distance_to(door_end)), true, connector_object):
			edge_count += 1
			route_regions_by_resident[resident_id] = home_region
			route_regions_by_target["home:" + resident_id] = home_region
	var report := {
		"ok": edge_count > 0 and region_count >= 0,
		"source": "living_quarter_layout.json",
		"road_count": roads.size(),
		"road_node_count": road_nodes.size(),
		"region_count": global_route_graph.regions.size(),
		"connector_count": global_route_graph.connectors.size(),
		"resident_region_count": route_regions_by_resident.size(),
		"target_region_count": route_regions_by_target.size(),
		"revision": global_route_graph.revision,
	}
	route_graph_build_report = report
	return report


func _register_route_road_node(nodes_by_key: Dictionary, nodes: Array[Dictionary], point: Vector2,
		quarter: Node3D, width: float, road_index: int) -> Dictionary:
	var key := "%d:%d" % [int(round(point.x * 2.0)), int(round(point.y * 2.0))]
	if nodes_by_key.has(key): return nodes_by_key[key]
	var position := Vector3(point.x, 0.0, point.y)
	if quarter != null and quarter.has_method("height_at"):
		position.y = float(quarter.call("height_at", point.x, point.y)) + .03
	var region_id := "pcg:road:" + key
	register_route_region(region_id, position)
	var node := {"id": region_id, "position": position, "road_index": road_index, "width": width}
	nodes_by_key[key] = node
	nodes.append(node)
	return node


func _nearest_route_node(nodes: Array[Dictionary], position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for node: Dictionary in nodes:
		var distance := Vector2(node["position"].x, node["position"].z).distance_to(Vector2(position.x, position.z))
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func build() -> Dictionary:
	if region != null:
		return {"ok": enabled, "code": bake_status}
	region = NavigationRegion3D.new()
	region.name = "TownNavigationRegion"
	navigation_mesh = NavigationMesh.new()
	# 4.7's root-node source mode walks the town street subtree; parsed geometry is restricted
	# to the StaticBody3D collision shapes below it.
	navigation_mesh.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN)
	navigation_mesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	navigation_mesh.set_collision_mask(1)
	navigation_mesh.agent_height = BODY_HEIGHT
	# Recast already rounds clearance up to whole horizontal voxels. Make that
	# existing effective radius explicit without changing bodies or voxel resolution.
	navigation_mesh.agent_radius = ceilf(BODY_RADIUS / bake_cell_size) * bake_cell_size
	# The authored market/field join is a shallow ramp; a capsule must use it rather than step
	# across a vertical lip. Keep climb below the old lip while allowing the measured ramp.
	navigation_mesh.agent_max_climb = bake_max_climb
	navigation_mesh.agent_max_slope = 35.0
	navigation_mesh.cell_size = bake_cell_size
	navigation_mesh.cell_height = bake_cell_height
	navigation_mesh.filter_baking_aabb = walkable_bounds
	region.navigation_mesh = navigation_mesh
	add_child(region)
	var map := region.get_navigation_map()
	if map.is_valid():
		NavigationServer3D.map_set_cell_size(map, bake_cell_size)
		NavigationServer3D.map_set_cell_height(map, bake_cell_height)
	baking = true
	bake_status = "baking_static_colliders"
	# The region is a child of TownStreet; pass that scene root so the bake sees the market,
	# expansion, fallback floor, and their actual StaticBody3D collision shapes as siblings.
	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation_mesh, source_geometry, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source_geometry)
	return {"ok": true, "code": bake_status, "aabb": walkable_bounds}

func _process(_delta: float) -> void:
	if not baking or region == null:
		return
	if region.is_baking():
		return
	baking = false
	var polygon_count := navigation_mesh.get_polygon_count()
	enabled = polygon_count > 0
	bake_status = "ready" if enabled else "empty_static_collider_bake"
	if enabled:
		NavigationServer3D.map_force_update(region.get_navigation_map())

func register_body(id: String, body: CharacterBody3D) -> void:
	if not is_instance_valid(body):
		return
	resident_directory[id] = body
	if agents.has(id):
		return
	var agent := NavigationAgent3D.new()
	agent.name = "NavigationAgent"
	agent.radius = BODY_RADIUS
	agent.height = BODY_HEIGHT
	agent.path_desired_distance = 0.22
	agent.target_desired_distance = 0.32
	agent.path_max_distance = 6.0
	agent.pathfinding_algorithm = NavigationPathQueryParameters3D.PATHFINDING_ALGORITHM_ASTAR
	agent.neighbor_distance = 1.5
	agent.max_neighbors = 8
	agent.avoidance_enabled = true
	agent.max_speed = WALK_SPEED
	agent.set_meta("resident_id", id)
	body.add_child(agent)
	agent.velocity_computed.connect(_on_velocity_computed.bind(id))
	agent.path_changed.connect(_on_path_changed)
	agents[id] = agent
	routes.erase(id)


func loaded_resident_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in resident_directory.keys():
		var body: CharacterBody3D = resident_directory[id]
		if is_instance_valid(body):
			ids.append(String(id))
	return ids


func target_position_for(resident_id: String) -> Vector3:
	var body: CharacterBody3D = resident_directory.get(resident_id)
	return body.global_position if is_instance_valid(body) else Vector3.INF

func _on_path_changed() -> void:
	path_updates += 1

func _on_velocity_computed(velocity: Vector3, id: String) -> void:
	safe_velocities[id] = velocity
	safe_velocity_ready[id] = true

func _mark_unreachable(id: String, route: Dictionary) -> Vector3:
	route.status = "unreachable"
	route.path = PackedVector3Array()
	routes[id] = route
	safe_velocities.erase(id)
	safe_velocity_ready.erase(id)
	var agent: NavigationAgent3D = agents.get(id)
	if is_instance_valid(agent):
		agent.set_velocity(Vector3.ZERO)
	return Vector3.ZERO

func clear_route(id: String) -> void:
	routes.erase(id)
	graph_routes.erase(id)
	safe_velocities.erase(id)
	safe_velocity_ready.erase(id)
	var agent: NavigationAgent3D = agents.get(id)
	if is_instance_valid(agent):
		var body := agent.get_parent() as CharacterBody3D
		if is_instance_valid(body):
			agent.target_position = body.global_position
		agent.set_velocity(Vector3.ZERO)

func is_unreachable(id: String) -> bool:
	return str(routes.get(id, {}).get("status", "")) == "unreachable"

func route_status(id: String) -> String:
	if graph_routes.has(id):
		return str(graph_routes[id].get("status", "inactive"))
	return str(routes.get(id, {}).get("status", "inactive"))

func route_path(id: String) -> PackedVector3Array:
	var value: Variant = routes.get(id, {}).get("path", PackedVector3Array())
	return value if value is PackedVector3Array else PackedVector3Array()


func graph_route_is_unreachable(id: String) -> bool:
	return str(graph_routes.get(id, {}).get("status", "")) == "unreachable"


func _nearest_graph_region(position: Vector3) -> String:
	var best_id := ""
	var best_distance := INF
	for raw_id in global_route_graph.regions.keys():
		var region_id := String(raw_id)
		var point: Vector3 = global_route_graph.regions[region_id].get("position", Vector3.INF)
		if not point.is_finite(): continue
		var distance := Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best_id = region_id
	return best_id


func graph_direction_for(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	return _graph_direction_for(id, command_id, body, target, "")


func graph_direction_for_target(id: String, command_id: String, body: CharacterBody3D,
		target_id: String, target: Vector3) -> Vector3:
	## Use a stable semantic target region while retaining the target's current exact
	## position for the final arrival leg.
	return _graph_direction_for(id, command_id, body, target, target_id)


func _graph_direction_for(id: String, command_id: String, body: CharacterBody3D,
		target: Vector3, target_id: String) -> Vector3:
	if not graph_only_routes or not is_instance_valid(body) or global_route_graph.regions.is_empty():
		return Vector3.ZERO
	var source_region := _nearest_graph_region(body.global_position)
	var target_region := route_region_for_target(target_id, target) if not target_id.is_empty() else _nearest_graph_region(target)
	if source_region.is_empty() or target_region.is_empty():
		graph_routes[id] = {"status": "unreachable", "command_id": command_id, "target": target}
		return Vector3.ZERO
	var route: Dictionary = graph_routes.get(id, {})
	# Keep the source region captured when this command starts. Re-selecting the
	# nearest node every physics tick makes two close PCG samples alternate as the
	# body crosses their midpoint, which reverses the route. The command/target
	# pair is the stable identity of this first-stage journey.
	var route_key := "%s|%s" % [command_id, target_region]
	if str(route.get("key", "")) != route_key:
		route = global_route_graph.find_route(source_region, target_region)
		route["key"] = route_key
		route["command_id"] = command_id
		route["target"] = target
		route["source_region"] = source_region
		route["target_region"] = target_region
		route["waypoint_index"] = 0
		if not bool(route.get("ok", false)):
			route["status"] = "unreachable"
			graph_routes[id] = route
			return Vector3.ZERO
	# A resident target may move within the same graph region. Keep the final
	# approach pointed at its current position without rebuilding the long route.
	route["target"] = target
	graph_routes[id] = route
	var region_path: Array = route.get("regions", [])
	var waypoint_index := int(route.get("waypoint_index", 0))
	while waypoint_index + 1 < region_path.size():
		var waypoint_region := String(region_path[waypoint_index + 1])
		var waypoint: Vector3 = global_route_graph.regions[waypoint_region].get("position", Vector3.INF)
		var waypoint_distance := Vector2(body.global_position.x, body.global_position.z).distance_to(
			Vector2(waypoint.x, waypoint.z))
		if waypoint_distance > GRAPH_WAYPOINT_RADIUS:
			break
		waypoint_index += 1
	route["waypoint_index"] = waypoint_index
	var final_leg := waypoint_index + 1 >= region_path.size()
	var next := target
	if waypoint_index + 1 < region_path.size():
		var next_region := String(region_path[waypoint_index + 1])
		next = global_route_graph.regions[next_region].get("position", target)
	var offset := next - body.global_position
	if not final_leg:
		offset.y = 0.0
	var arrival_radius := 0.45 if final_leg else 0.08
	if offset.length() <= arrival_radius:
		offset = target - body.global_position
		if not final_leg:
			offset.y = 0.0
	if offset.length() <= 0.08:
		route["status"] = "arrived"
	else:
		route["status"] = "following"
	graph_routes[id] = route
	return offset.normalized() if offset.length() > 0.0 else Vector3.ZERO

func direction_for(id: String, command_id: String, body: CharacterBody3D, target: Vector3) -> Vector3:
	var agent: NavigationAgent3D = agents.get(id)
	if not enabled or not is_instance_valid(agent) or not is_instance_valid(body):
		return Vector3.ZERO
	var route: Dictionary = routes.get(id, {})
	if route.get("command_id", "") != command_id or route.get("target", Vector3.INF).distance_to(target) > 0.02:
		route = {"command_id": command_id, "target": target, "status": "pending", "path": []}
		routes[id] = route
		safe_velocities.erase(id)
		safe_velocity_ready.erase(id)
		agent.set_velocity(Vector3.ZERO)
		agent.target_position = target
	if not walkable_bounds.has_point(target):
		return _mark_unreachable(id, route)
	var map := agent.get_navigation_map()
	if not map.is_valid():
		return _mark_unreachable(id, route)
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		route.status = "map_pending"
		routes[id] = route
		return Vector3.ZERO
	# Stock Godot A* owns the corridor cache and repaths when the map or target changes,
	# or the body leaves that corridor. A restored/repositioned body also invalidates it.
	var previous: Vector3 = route.get("last_position", body.global_position)
	if previous.distance_to(body.global_position) > maxf(0.5, WALK_SPEED * get_physics_process_delta_time() * 2.0):
		agent.target_position = target
		route.erase("doorway_points")
		route.erase("detour")
		safe_velocities.erase(id)
		safe_velocity_ready.erase(id)
	route.last_position = body.global_position
	var next: Vector3 = target
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if route.get("map_iteration", -1) != iteration:
		agent.target_position = target
		route.erase("doorway_points")
		route.map_iteration = iteration
	if not agent.is_navigation_finished():
		next = agent.get_next_path_position()
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.is_empty():
		return _mark_unreachable(id, route)
	# A non-empty path may terminate at the closest reachable point when a target is
	# behind a collider. Treat that partial path as unreachable instead of steering
	# through the obstacle toward the requested point.
	if path[path.size() - 1].distance_to(target) > 0.45:
		return _mark_unreachable(id, route)
	route.status = "following"
	route.path = path
	if not door_portals.is_empty():
		var remaining := PackedVector3Array([body.global_position])
		remaining.append_array(path.slice(agent.get_current_navigation_path_index()))
		path = _doorway_path(route,remaining,body.global_position)
	if dynamic_detours and not route.has("doorway_points"):
		var now := Time.get_ticks_msec()
		var distance := body.global_position.distance_to(target)
		if not route.has("progress_msec") or distance < float(route.get("progress_distance",INF)) - 0.15:
			route.progress_distance = distance
			route.progress_msec = now
		if route.has("detour") and body.global_position.distance_to(route.detour) < 0.45:
			route.erase("detour")
		if now - int(route.progress_msec) > 1100:
			crowd_detour_attempts += 1
			var detour := _crowd_detour(body, target, map)
			if detour.is_finite():
				route.detour = detour
				crowd_detour_count += 1
			route.progress_msec = now
		if route.has("detour"):
			var around: PackedVector3Array = NavigationServer3D.map_get_path(map, body.global_position, route.detour, true)
			if not around.is_empty() and around[around.size()-1].distance_to(route.detour) < 0.3:
				path = around
			else: route.erase("detour")
	routes[id] = route
	# Portal and optional crowd legs refine the same physical journey. Do not iterate the
	# complete cached corridor here: points behind the body would cause backtracking.
	if route.has("doorway_points"):
		next = route.doorway_points[0]
	elif route.has("detour"):
		for waypoint in path:
			if body.global_position.distance_to(waypoint) > 0.42:
				next = waypoint
				break
	var offset := next - body.global_position
	offset.y = 0.0
	if offset.length() <= 0.08:
		offset = target - body.global_position
		offset.y = 0.0
	if offset.length() <= 0.08:
		return Vector3.ZERO
	agent.set_velocity(offset.normalized() * WALK_SPEED)
	var desired := offset.normalized() * WALK_SPEED
	if not safe_velocity_ready.get(id, false):
		return Vector3.ZERO
	var safe: Vector3 = safe_velocities.get(id, Vector3.ZERO)
	safe.y = 0.0
	if safe.length() <= 0.05 or safe.dot(desired) <= 0.05:
		return Vector3.ZERO
	# TownStreet multiplies this direction by WALK_SPEED. Preserve the avoidance
	# solver's speed so a slowed RVO result is not silently normalized away.
	return safe / WALK_SPEED

func _doorway_path(route: Dictionary, path: PackedVector3Array, position: Vector3) -> PackedVector3Array:
	# A narrow opening needs a straight approach AND exit before turning alongside the
	# facade. Keep these short portal legs until traversed; an open door remains physical.
	if not route.has("doorway_points"):
		for portal in door_portals:
			var center: Vector3 = portal.center
			var normal: Vector3 = portal.normal
			if position.distance_to(center)>3.2: continue
			for i in range(1,path.size()):
				var a: Vector3 = path[i-1]
				var b: Vector3 = path[i]
				var da := (a-center).dot(normal)
				var db := (b-center).dot(normal)
				if da*db>=0 or absf(da-db)<.01: continue
				var crossing := a.lerp(b,da/(da-db))
				if Vector2(crossing.x-center.x,crossing.z-center.z).length()>.7: continue
				var direction := normal*(1.0 if db>da else -1.0)
				var waypoints: Array[Vector3] = []
				if (position-center).dot(direction)<-.2: waypoints.append(center-direction*.75)
				waypoints.append(center+direction*.95)
				route.doorway_points = waypoints
				route.erase("detour")
				door_crossings += 1
				break
			if route.has("doorway_points"): break
	if route.has("doorway_points"):
		var points: Array = route.doorway_points
		while not points.is_empty() and position.distance_to(points[0])<.20:
			points.pop_front()
		if points.is_empty(): route.erase("doorway_points")
		else: return PackedVector3Array([position,points[0]])
	return path

func _crowd_detour(body: CharacterBody3D, goal: Vector3, map: RID) -> Vector3:
	# RVO can stop at a ring of stationary neighbours. Search a short, physically clear
	# lateral leg on the existing navmesh; neither the job nor its actual endpoint changes.
	var neighbours: Array[Vector3] = []
	for other in agents.values():
		var peer := other.get_parent() as CharacterBody3D
		if peer != body and is_instance_valid(peer) and peer.global_position.distance_to(body.global_position) < 5.5:
			neighbours.append(peer.global_position)
	if neighbours.is_empty(): return Vector3.INF
	var best := Vector3.INF
	var best_cost := INF
	for radius in [2.0,3.1]:
		for i in 20:
			var trial: Vector3 = body.global_position + Vector3(cos(i*TAU/20),0,sin(i*TAU/20))*float(radius)
			var point := NavigationServer3D.map_get_closest_point(map,trial)
			if point.distance_to(trial) > 0.35: continue
			var path := NavigationServer3D.map_get_path(map,body.global_position,point,true)
			if path.is_empty() or path[path.size()-1].distance_to(point) > 0.3: continue
			var clear := true
			var length := 0.0
			for j in range(1,path.size()):
				length += path[j-1].distance_to(path[j])
				var a := Vector2(path[j-1].x,path[j-1].z)
				var b := Vector2(path[j].x,path[j].z)
				for neighbour in neighbours:
					var p := Vector2(neighbour.x,neighbour.z)
					var fraction := clampf((p-a).dot(b-a)/maxf((b-a).length_squared(),.0001),0,1)
					# An already crowded start must be allowed to move away; do not reject
					# every escape merely because its first point is inside the comfort margin.
					var start_gap := p.distance_to(Vector2(body.global_position.x,body.global_position.z))
					if p.distance_to(a+(b-a)*fraction)<minf(.68,start_gap-.015): clear=false
			var cost := point.distance_to(goal)+length*.25
			if clear and cost<best_cost:
				best=point
				best_cost=cost
	return best
