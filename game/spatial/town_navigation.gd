extends Node3D
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
var routes: Dictionary = {}
var safe_velocities: Dictionary = {}
var safe_velocity_ready: Dictionary = {}
var baking := false
var enabled := false
var bake_status := "not_started"

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
	navigation_mesh.agent_radius = BODY_RADIUS
	# The authored market/field join is a shallow ramp; a capsule must use it rather than step
	# across a vertical lip. Keep climb below the old lip while allowing the measured ramp.
	navigation_mesh.agent_max_climb = 0.04
	navigation_mesh.agent_max_slope = 35.0
	navigation_mesh.cell_size = 0.10
	navigation_mesh.cell_height = 0.01
	navigation_mesh.filter_baking_aabb = WALKABLE_AABB
	region.navigation_mesh = navigation_mesh
	add_child(region)
	var map := region.get_navigation_map()
	if map.is_valid():
		NavigationServer3D.map_set_cell_size(map, 0.10)
		NavigationServer3D.map_set_cell_height(map, 0.01)
	baking = true
	bake_status = "baking_static_colliders"
	# The region is a child of TownStreet; pass that scene root so the bake sees the market,
	# expansion, fallback floor, and their actual StaticBody3D collision shapes as siblings.
	NavigationServer3D.region_bake_navigation_mesh(navigation_mesh, get_parent())
	return {"ok": true, "code": bake_status, "aabb": WALKABLE_AABB}

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
	if agents.has(id) or not is_instance_valid(body):
		return
	var agent := NavigationAgent3D.new()
	agent.name = "NavigationAgent"
	agent.radius = BODY_RADIUS
	agent.height = BODY_HEIGHT
	agent.path_desired_distance = 0.22
	agent.target_desired_distance = 0.32
	agent.path_max_distance = 6.0
	agent.neighbor_distance = 1.5
	agent.max_neighbors = 8
	agent.avoidance_enabled = true
	agent.max_speed = WALK_SPEED
	agent.set_meta("resident_id", id)
	body.add_child(agent)
	agent.velocity_computed.connect(_on_velocity_computed.bind(id))
	agents[id] = agent
	routes.erase(id)

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
	return str(routes.get(id, {}).get("status", "inactive"))

func route_path(id: String) -> PackedVector3Array:
	var value: Variant = routes.get(id, {}).get("path", PackedVector3Array())
	return value if value is PackedVector3Array else PackedVector3Array()

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
	if not WALKABLE_AABB.has_point(target):
		return _mark_unreachable(id, route)
	var map := agent.get_navigation_map()
	if not map.is_valid():
		return _mark_unreachable(id, route)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, body.global_position, target, true)
	if path.is_empty():
		return _mark_unreachable(id, route)
	# A non-empty path may terminate at the closest reachable point when a target is
	# behind a collider. Treat that partial path as unreachable instead of steering
	# through the obstacle toward the requested point.
	if path[path.size() - 1].distance_to(target) > 0.45:
		return _mark_unreachable(id, route)
	route.status = "following"
	route.path = path
	routes[id] = route
	# The server path is authoritative for this physics frame. Agent path caches update on the
	# navigation tick, so selecting the first waypoint beyond the body's current position also
	# handles a legitimate body reposition (for example a restored pending job) without following
	# a stale previous command path.
	var next := target
	for waypoint in path:
		var candidate: Vector3 = waypoint
		if body.global_position.distance_to(candidate) > 0.42:
			next = candidate
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
