extends RefCounted
## Authoritative whitebox layout for a first-floor Starting City study.
##
## This is a spatial design layer only. It deliberately contains no resident state,
## model calls or save writes. The four neighbourhood roads are copied from the
## authored living_quarter_layout.json road polylines so a whitebox review and the
## current PCG/navigation adapter share the same centreline evidence.

const REVISION := "starting-city-whitebox-20260921-v1"
const REFERENCE_SCOPE := "First floor macro whitebox; inspired by the Town of Beginnings, not a canon map recreation."

const TERRAIN_BOUNDS := Rect2(-140.0, -130.0, 280.0, 310.0)
const CITY_BOUNDS := Rect2(-72.0, -105.0, 144.0, 108.0)
const CITY_WALL_Y := 1.2

const ZONES := [
	{"id": "city_core", "label": "CITY CORE / TOWN OF BEGINNINGS", "center": Vector2(0, -35), "size": Vector2(140, 115), "height": 0.0, "color": Color("#c9c0aa")},
	{"id": "central_plaza", "label": "CENTRAL PLAZA", "center": Vector2(0, -55), "size": Vector2(52, 38), "height": 0.18, "color": Color("#d9d4c8")},
	{"id": "south_gate", "label": "SOUTH GATE", "center": Vector2(0, -106), "size": Vector2(34, 22), "height": 0.05, "color": Color("#b8aa8e")},
	{"id": "outer_meadow", "label": "LATA PLAINS / OUTER MEADOW", "center": Vector2(-56, 82), "size": Vector2(105, 90), "height": -0.8, "color": Color("#9eb886")},
	{"id": "forest", "label": "HORUNKA FOREST", "center": Vector2(-106, 28), "size": Vector2(64, 122), "height": -0.35, "color": Color("#5f8066")},
	{"id": "wetland", "label": "LAKE / WETLAND", "center": Vector2(93, 46), "size": Vector2(72, 92), "height": -1.4, "color": Color("#6c9db0")},
	{"id": "ruins", "label": "EASTERN RUINS", "center": Vector2(94, -66), "size": Vector2(64, 62), "height": -0.1, "color": Color("#8d8174")},
	{"id": "labyrinth", "label": "NORTH LABYRINTH APPROACH", "center": Vector2(18, 139), "size": Vector2(145, 52), "height": 3.5, "color": Color("#777b84")},
]

## Existing neighbourhood roads. Coordinates match living_quarter_layout.json exactly.
const AUTHORED_ROADS := [
	{"id": "main_spine", "label": "MAIN NORTH-SOUTH ROAD", "width": 9.0, "points": [[0,-130],[0,-80],[0,-40],[0,-15],[1,14],[0,35],[-3,53],[0,66],[8,91],[2,116],[-8,138],[-9,180]]},
	{"id": "west_cross", "label": "WEST CROSS STREET", "width": 5.0, "points": [[0,39.5],[-13.5,40],[-20.8,40],[-26,48],[-24,63],[-23,77],[-15,88],[8,91]]},
	{"id": "east_cross", "label": "EAST CROSS STREET", "width": 5.0, "points": [[0,39.5],[23,41],[27,53],[22,66],[25.9,72.9],[30,77],[8,91]]},
	{"id": "east_connector", "label": "EAST OUTER CONNECTOR", "width": 4.0, "points": [[0,66],[13.5,66],[25.9,72.9],[47,79],[65,96],[92,114],[140,128]]},
]

## Macro roads are additional graph-connected approaches; they terminate at the same authored spine.
const MACRO_ROADS := [
	{"id": "gate_to_plaza", "label": "GATE TO PLAZA", "width": 10.0, "points": [[0,-118],[0,-96],[0,-72],[0,-55]]},
	{"id": "plaza_to_forest", "label": "FOREST ROAD", "width": 8.0, "points": [[-20,-55],[-48,-48],[-78,-28],[-100,18]]},
	{"id": "plaza_to_wetland", "label": "LAKESIDE ROAD", "width": 8.0, "points": [[25,-55],[48,-42],[70,-15],[83,30]]},
	{"id": "plaza_to_ruins", "label": "RUINS ROAD", "width": 7.0, "points": [[35,-60],[65,-69],[94,-66]]},
	{"id": "spine_to_labyrinth", "label": "LABYRINTH APPROACH", "width": 9.0, "points": [[0,66],[4,92],[12,117],[18,139]]},
]

## Every listed house is a whitebox cube. Resident houses are named; infill cubes keep the
## town scale legible before final art assets exist.
const HOUSES := [
	{"id":"shared:well-keeper", "label":"WELL KEEPER", "at":[-42,-53], "zone":"city_core"},
	{"id":"shared:baker", "label":"BAKER", "at":[-18,-38], "zone":"city_core"},
	{"id":"shared:smith", "label":"SMITH", "at":[22,-38], "zone":"city_core"},
	{"id":"shared:carpenter", "label":"CARPENTER", "at":[42,-52], "zone":"city_core"},
	{"id":"shared:innkeeper", "label":"INNKEEPER", "at":[-27,-78], "zone":"city_core"},
	{"id":"shared:herder", "label":"HERDER", "at":[43,16], "zone":"city_core"},
	{"id":"shared:gardener", "label":"GARDENER", "at":[-43,14], "zone":"city_core"},
	{"id":"shared:weaver", "label":"WEAVER", "at":[25,-11], "zone":"city_core"},
	{"id":"shared:fisher", "label":"FISHER", "at":[56,22], "zone":"city_core"},
	{"id":"shared:healer", "label":"HEALER", "at":[-24,31], "zone":"city_core"},
	{"id":"infill:market-nw", "label":"MARKET HOUSE", "at":[-50,-20], "zone":"city_core"},
	{"id":"infill:market-ne", "label":"MARKET HOUSE", "at":[50,-20], "zone":"city_core"},
	{"id":"infill:church", "label":"CHURCH / CARE", "at":[0,-20], "zone":"city_core"},
	{"id":"infill:plaza-west", "label":"PLAZA HOUSE", "at":[-55,-65], "zone":"city_core"},
	{"id":"infill:plaza-east", "label":"PLAZA HOUSE", "at":[55,-65], "zone":"city_core"},
	{"id":"infill:outer-west", "label":"OUTER HOUSE", "at":[-76,62], "zone":"outer_meadow"},
	{"id":"infill:outer-south", "label":"OUTER HOUSE", "at":[-34,101], "zone":"outer_meadow"},
	{"id":"infill:outer-east", "label":"OUTER HOUSE", "at":[38,99], "zone":"outer_meadow"},
]

static func all_roads() -> Array:
	var roads: Array = []
	roads.append_array(AUTHORED_ROADS)
	roads.append_array(MACRO_ROADS)
	return roads

static func vec2_points(raw: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for item in raw:
		points.append(Vector2(float(item[0]), float(item[1])))
	return points
