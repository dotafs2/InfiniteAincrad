extends RefCounted
## Explicit public-place catalog and road graph for the expanded town.
##
## Geometry only: no resident data, no saved state, no decisions. The world modules use it
## to build the voluntary travel options, the separated arrival points and the graph route;
## the scene uses it to install the public notice and to steer a travelling body.
##
## Every node below is a point of the ACCEPTED run9 physical route
## (tmp/town-expansion-20260912/run9/out/acceptance.json, 23 reached waypoints, 0 blocked
## samples) or of the accepted layout (game/spatial/town_expansion_layout.gd). The road graph
## keeps every leg on paving or on the walkable plate; the caravan leg follows
## (26,70) -> (26,66) -> (0,66) and never cuts diagonally across the z=78 house row.
## Nothing here grants knowledge, movement or rest by itself.

## Public notice: a wayfinding waystone at the old-market exit where residents actually
## stand. It describes only what is publicly visible (streets and public use), never skills,
## stock, interiors or another resident.
const NOTICE := {
	"id": "public_notice:market_exit",
	"label": "旧市场出口的公共路牌",
	"asset": "res://assets/generated/travel_cargo_20260912/carved_route_waystone.glb",
	## Measured site at the market/street exit: the floor is 0.22 m, no other collider occupies the
	## spot, and 142 of the 144 measured clear standing positions within 8 m can see it (the two
	## exceptions are a bakery fitting and the player). Measurement: the private diagnostic
	## tmp/town-places-20260912/probes/town_places_site_probe.gd, whose output is kept beside the
	## run; the scene acceptance re-checks the installed notice directly.
	"position": [-3.0, 0.22, 12.0],
	"yaw": 200.0,
	"point": [-3.0, 1.32, 12.0],
	"read_range_m": 8.0,
	"text": "路牌上写着：沿街向南可以走到西边的空地、街口的公共花园，再往东南是商队歇脚的空场；这些地方都可以走过去，也能站一会儿歇脚。牌子上没有写别的事。",
}
const DIRECT_SIGHT_RANGE := 20.0

## Road nodes of the verified graph, measured on the accepted layout.
const ROAD_NODES := {
	"plaza": [2.5, 0.22, 14.5],
	"market_edge": [0.0, 0.15, 30.0],
	"north_junction": [0.0, 0.10, 39.5],
	"west_street": [-13.5, 0.10, 40.0],
	"west_end": [-20.8, 0.10, 40.0],
	"commons_north": [0.0, 0.10, 46.5],
	"commons": [0.0, 0.10, 53.0],
	"commons_south": [0.0, 0.10, 60.0],
	"south_junction": [0.0, 0.10, 66.0],
	"sw_street": [-13.5, 0.10, 66.0],
	"sw_end": [-20.8, 0.10, 66.0],
	"se_street": [13.5, 0.10, 66.0],
	"se_arm_end": [25.5, 0.10, 69.0],
	"orchard_track": [0.0, 0.10, 86.8],
}

## Walkable connections. The graph is AUTHORED from the accepted layout and the accepted run9
## physical route, which walked these paved/plate legs at 1.35 m/s with a plain capsule and 0
## blocked samples. The current place acceptance tests walk only the market<->west,
## market<->commons and market<->caravan legs with a real body; the south-west arm and the
## orchard-track edge rest on that earlier run9 evidence instead of a new walk here. No diagonal
## shortcut across houses exists in this graph.
const ROAD_EDGES := [
	["plaza", "market_edge"],
	["market_edge", "north_junction"],
	["north_junction", "west_street"],
	["west_street", "west_end"],
	["north_junction", "commons_north"],
	["commons_north", "commons"],
	["commons", "commons_south"],
	["commons_south", "south_junction"],
	["south_junction", "sw_street"],
	["sw_street", "sw_end"],
	["south_junction", "se_street"],
	["se_street", "se_arm_end"],
	["south_junction", "orchard_track"],
]

## The ten measured-clear arrival/rest points around a place anchor, in metres (x, z), kept within
## 1.2 m of the place's own street depth so every point stays well inside the paved surface.
## Measured with the real 0.25 m resident capsule in the playable scene (private diagnostic
## tmp/town-places-20260912/probes/town_places_clearance_probe.gd, output and the per-target
## mapping kept beside the run): every point below is clear at every place, sits on that place's
## own floor, and its centre is at least 1.2 m from any other centre (0.7 m of clear
## surface between two 0.25 m capsules). No point sits on the street centreline, which keeps the
## through lane open in the measured cases; a standing resident can still narrow a corridor and
## simultaneous arrivals can still crowd, and such a trip closes honestly as travel_blocked rather
## than faking arrival. Ten points match the ten-person scope; index 0/4/8 - the formerly-colliding
## modulo case - are 2.4-5.4 m apart.
const PLACE_OFFSETS := [
	[-2.4, -1.2], [-1.2, -1.2],
	[1.2, -1.2], [2.4, 0.0],
	[2.4, -1.2], [-1.2, 1.2],
	[1.2, 1.2], [2.4, 1.2],
	[-2.4, 1.2], [-2.4, 0.0],
]
## Capacity of the authored public arrival points per place: the first ten residents by roster
## order own one point each. A resident beyond the authored set is not offered these public places
## at all rather than aliasing onto another resident's point.
const PLACE_CAPACITY := 10

## Four public places. "node" is the graph node they hang from.
const PLACES := [
	{
		"id": "market_plaza",
		"label": "旧市场广场",
		"public_use": "旧市场外面的公共铺石广场，沿街走过来站一会儿就行。",
		"point": [2.5, 0.22, 14.5],
		"node": "plaza",
	},
	{
		"id": "west_forecourt",
		"label": "西侧工匠前庭",
		"public_use": "西边街尾的一块公共空地，沿街走过去就能站下来。",
		"point": [-20.8, 0.10, 40.0],
		"node": "west_end",
	},
	{
		"id": "planted_commons",
		"label": "种植公共地",
		"public_use": "街口十字路边的公共绿地，可以走过去站一会儿。",
		"point": [0.0, 0.10, 53.0],
		"node": "commons",
	},
	{
		"id": "caravan_rest",
		"label": "商队休息区",
		"public_use": "东南边街尾的空场，商队在那里歇脚，路人也可以走过去站着。",
		"point": [25.9, 0.06, 72.9],
		"node": "se_arm_end",
	},
]

const ARRIVAL_RADIUS := 0.45
const LEG_REACH := 1.2

static func place_ids() -> Array:
	var ids: Array = []
	for place in PLACES:
		ids.append(str(place["id"]))
	return ids

static func place(place_id: String) -> Dictionary:
	for place in PLACES:
		if str(place["id"]) == place_id:
			return place
	return {}

static func is_place_id(place_id: String) -> bool:
	return not place(place_id).is_empty()

static func point_of(place_id: String) -> Vector3:
	var entry := place(place_id)
	if entry.is_empty():
		return Vector3.INF
	var p: Array = entry["point"]
	return Vector3(p[0], p[1], p[2])

static func offset_count(place_id: String) -> int:
	var entry := place(place_id)
	return 0 if entry.is_empty() else PLACE_OFFSETS.size()

static func slot_point(place_id: String, slot: int) -> Vector3:
	## Separated arrival/rest point for one resident slot. Falls back to the anchor.
	var entry := place(place_id)
	if entry.is_empty():
		return Vector3.INF
	if PLACE_OFFSETS.is_empty():
		return point_of(place_id)
	if slot < 0 or slot >= PLACE_OFFSETS.size():
		return Vector3.INF
	var offset: Array = PLACE_OFFSETS[slot]
	var p: Array = entry["point"]
	var x: float = float(p[0]) + float(offset[0])
	var z: float = float(p[2]) + float(offset[1])
	return Vector3(x, float(p[1]), z)

static func place_for_point(target: Vector3) -> String:
	## Reverse lookup used by the scene steering: which catalog point is this target?
	if not target.is_finite():
		return ""
	for place in PLACES:
		var place_id := str(place["id"])
		for slot in offset_count(place_id):
			if slot_point(place_id, slot).distance_to(target) <= 0.6:
				return place_id
		if point_of(place_id).distance_to(target) <= 0.6:
			return place_id
	return ""

static func nearest_node(point: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for name in ROAD_NODES:
		var node: Array = ROAD_NODES[name]
		var distance := Vector2(float(node[0]) - point.x, float(node[2]) - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = name
	return best

static func _adjacency() -> Dictionary:
	var graph: Dictionary = {}
	for name in ROAD_NODES:
		graph[name] = []
	for edge in ROAD_EDGES:
		graph[edge[0]].append(edge[1])
		graph[edge[1]].append(edge[0])
	return graph

static func route_nodes(place_id: String, from: Vector3) -> Array:
	## Breadth-first route over the verified graph from the node nearest to "from" to the
	## node the place hangs from. Returns node names including both ends; [] if unreachable.
	var entry := place(place_id)
	if entry.is_empty() or not from.is_finite():
		return []
	var start := nearest_node(from)
	var goal := str(entry["node"])
	var graph := _adjacency()
	if start.is_empty() or not graph.has(start) or not graph.has(goal):
		return []
	var queue: Array = [start]
	var came_from: Dictionary = {start: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == goal:
			break
		for neighbour in graph[current]:
			if came_from.has(neighbour):
				continue
			came_from[neighbour] = current
			queue.append(neighbour)
	if not came_from.has(goal):
		return []
	var reversed: Array = []
	var step := goal
	while step != "":
		reversed.append(step)
		step = str(came_from[step])
	reversed.reverse()
	return reversed

static func path_points(place_id: String, from: Vector3, slot: int) -> Array:
	## Full steering polyline: graph nodes from the resident's nearest node to the place's
	## node, then the resident's own separated arrival point.
	var points: Array = []
	for name in route_nodes(place_id, from):
		var node: Array = ROAD_NODES[name]
		points.append(Vector3(node[0], node[1], node[2]))
	var arrival := slot_point(place_id, slot)
	if arrival.is_finite():
		points.append(arrival)
	return points

static func notice_place_ids() -> Array:
	return place_ids()

static func road_length(place_id: String, from: Vector3, slot: int) -> float:
	var points := path_points(place_id, from, slot)
	var total := 0.0
	var previous := from
	for point_value in points:
		var point: Vector3 = point_value
		total += Vector2(point.x - previous.x, point.z - previous.z).length()
		previous = point
	return total
