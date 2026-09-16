extends "res://experiments/pcg/native_quarter.gd"
## Authored activity clusters + native PCG for the surrounding landscape.
const DEMO_ASSETS := "res://assets/floor1/demo_prefabs/"
var dressing: Array = []
var prefab_cache: Dictionary = {}
var yard_zones := [
	[Vector2(25,-12),Vector2(12,12)], [Vector2(-43,30),Vector2(12,13)],
	[Vector2(-46,47),Vector2(13,12)], [Vector2(26,23),Vector2(12,11)],
	[Vector2(46,53),Vector2(13,13)], [Vector2(25,38),Vector2(11,8)],
	[Vector2(-30,95),Vector2(17,12)], [Vector2(38,-22),Vector2(16,23)],
	[Vector2(35,68),Vector2(12,10)], [Vector2(-39,-16),Vector2(17,14)]
]

func _paved(x: float, z: float) -> bool:
	if super._paved(x,z): return true
	for zone in yard_zones:
		if absf(x-zone[0].x)<zone[1].x*.5 and absf(z-zone[0].y)<zone[1].y*.5: return true
	# Make the space around each street stall read as a used market apron.
	return absf(x)<9.0 and z>-42 and z<5

func _box(title: String, at: Vector3, size: Vector3, material: String, solid: bool = true) -> MeshInstance3D:
	# Replace the old blockout stalls with the new separate Meshy model.
	var replaced := title in ["MarketCounter", "StripedCanopy", "CanopyStripe", "CanopyPost"]
	var node := super._box(title, at, size, material, solid and not replaced)
	if replaced: node.visible = false
	return node

func _dress_market() -> void:
	super._dress_market()
	for i in 6:
		var side := -1 if i%2 == 0 else 1
		var x := side*6.5
		var z := -30.0 + floori(i/2.0)*12
		_place("market-stall", Vector3(x,0,z), -side*90, "market")
		_place("produce-crate", Vector3(x+side*.5,0,z+2.25), i*13, "market")
		_place("market-barrel", Vector3(x-side*.3,0,z-2.2), i*24, "market")
		_place("fishing-basket" if i%2==0 else "cloth-bale", Vector3(x+side*.6,0,z-2.5), 15, "market")
	# Shop equipment lives beside its house; the actual door approach stays open.
	_cluster("smith",Vector3(-43,0,30),[
		["forge",-1.4,-2.4,90], ["anvil",1.5,-1.0,10], ["tool-rack",-3.6,1.2,90],
		["weapon_rack",1.6,2.6,90], ["market-barrel",-2.5,3.4,0], ["workbench",.8,-3.6,90]])
	_cluster("carpenter",Vector3(-46,0,47),[
		["workbench",0,-2,90], ["shaving-horse",2.2,1.2,110], ["pallets",-2.8,2,0],
		["fallen-log",-2,-3.4,30], ["market-barrel",3.1,-2.7,20], ["chest",-3.1,.2,90]])
	_cluster("baker",Vector3(25,0,-12),[
		["hearth",-3,-1,90], ["oven-rack",-3,1.1,90], ["flour-mill",-1.6,-2.7,0],
		["market-barrel",-1.2,2.8,0], ["market-barrel",-2.3,2.7,20], ["produce-crate",1.7,2.8,10]])
	_table_group(Vector3(26,0,-13), "bakery terrace", false)
	_table_group(Vector3(25,0,22), "inn terrace", true)
	_table_group(Vector3(28.4,0,26.2), "inn terrace", true)
	_place("market-barrel",Vector3(30,0,21),0,"inn terrace")
	_place("wooden-handcart",Vector3(29,0,18),-25,"inn terrace")
	_cluster("fisher",Vector3(46,0,53),[
		["fish-rack",0,-2,90], ["fishing-rods",-2.5,-2.3,10], ["net-frame",2.2,1.6,30],
		["fishing-basket",-1,1.8,0], ["fishing-basket",-2.0,1.9,15], ["rope",.3,.8,0],
		["water-cart",2.8,-2,15], ["market-barrel",-3.6,.4,0]])
	_cluster("textile",Vector3(25,0,37),[
		["dye-vat",0,-1,0], ["cloth-bale",2.1,-2,0], ["cloth-bale",2.3,-.7,15],
		["workbench",-1.4,-2.1,0], ["cargo-bundle",3.5,-1.9,0]])
	_cluster("pottery",Vector3(-30,0,95),[
		["pottery-kiln",-3,0,90], ["potters-wheel",0,0,20], ["workbench",2.6,-2,0],
		["market-barrel",-3,2.4,0], ["chest",2.8,1.5,0], ["wooden-handcart",0,3.4,90]])
	_cluster("cargo",Vector3(38,0,-22),[
		["covered-wagon",1,-4,25], ["wooden-handcart",-4,3,0], ["pallets",3,3,0],
		["cloth-bale",2,1,0], ["cargo-bundle",4,1,15], ["market-barrel",-2,-3,0],
		["market-barrel",-3.1,-3,0], ["produce-crate",-3,-1.5,0], ["market-barrel",4,4,0]])
	_table_group(Vector3(35,0,67), "rest area", false)
	_cluster("traveller rest",Vector3(-39,0,-16),[
		["tent",-3,-1,90], ["tent",2,-3,150], ["field-stool",0,1,0],
		["cargo-bundle",-2,2,0], ["market-barrel",3.5,2,0], ["wooden-handcart",3,4,15]])
	# Short boundary runs frame the yards, with open fronts and side gaps.
	for row in [[-47,39,90,5],[21,-6,0,3],[48,47,90,5],[31,-31,0,5],[-38,101,0,5],[22,29,0,3]]:
		for i in int(row[3]):
			var yaw := float(row[2])
			var step := Vector3(3.0,0,0).rotated(Vector3.UP,deg_to_rad(yaw))
			_place("fence",Vector3(row[0],0,row[1])+step*i,yaw,"yard boundary")
	for side in [-1,1]:
		for z in [-40,-24,-10,6,24]:
			var at := Vector3(side*5.25,0,z)
			_box("DemoLampPost",at+Vector3(0,1.35,0),Vector3(.13,2.7,.13),"wood")
			_box("DemoLampArm",at+Vector3(-side*.20,2.60,0),Vector3(.60,.10,.10),"wood",false)
			_place("lantern",at+Vector3(-side*.43,1.98,0),0,"street lights")
	for at in [Vector3(-5.8,0,-60),Vector3(52,0,84),Vector3(-14,0,112)]:
		_place("milestone",at,0,"route markers")
	pcg_report["dressing"] = dressing
	pcg_report["asset_catalog"] = "res://experiments/pcg/demo_catalog.json"

func _table_group(at: Vector3, zone: String, four_seats: bool) -> void:
	var table := _place("table",at,0,zone)
	var tabletop: float = table.get_meta("demo_size").y
	_place("meal",at+Vector3(-.35,tabletop+.015,0),0,zone)
	_place("jug",at+Vector3(.38,tabletop+.015,.1),0,zone)
	_place("cooking_pot" if not four_seats else "potion",at+Vector3(.1,tabletop+.015,-.2),0,zone)
	for side in [-1,1]:
		_place("chair",at+Vector3(0,0,side*1.02),0 if side<0 else 180,zone)
		if four_seats: _place("chair",at+Vector3(side*1.22,0,0),-side*90,zone)

func _cluster(zone: String, center: Vector3, members: Array) -> void:
	for item in members:
		_place(item[0],center+Vector3(item[1],0,item[2]),item[3],zone)

func _place(id: String, at: Vector3, yaw: float, zone: String) -> Node3D:
	if not prefab_cache.has(id): prefab_cache[id] = load(DEMO_ASSETS+id+".tscn")
	var node: Node3D = prefab_cache[id].instantiate()
	node.name = "Demo_"+id.replace("-","_")+str(dressing.size())
	node.position = Vector3(at.x,_map_height(at.x,at.z)+at.y,at.z)
	node.rotation_degrees.y = yaw
	add_child(node)
	dressing.append({"asset":id,"zone":zone,"position":[node.position.x,node.position.y,node.position.z],"yaw":yaw})
	return node

func _exclusions(scatter: ProtonScatter, margin: float) -> void:
	super._exclusions(scatter,margin)
	# Rounded join clearance closes the tiny gaps between straight road boxes.
	for road in layout.roads:
		for p in road.points:
			var exclusion := ProtonScatterShape.new()
			var sphere := ProtonScatterSphereShape.new()
			sphere.radius = road.width*.5+margin
			exclusion.shape = sphere
			exclusion.negative = true
			exclusion.position = Vector3(p[0],0,p[1])
			scatter.add_child(exclusion)
	for zone in yard_zones:
		_shape(scatter,Vector3(zone[0].x,0,zone[0].y),Vector3(zone[1].x+margin*2,100,zone[1].y+margin*2),true)
	# Keep all real door-to-road approaches free, including those crossing a verge.
	for home in layout.houses+layout.infill:
		var a := Vector2(home.at[0],home.at[2])
		var nearest := Vector2.INF
		for road in layout.roads:
			for i in range(road.points.size()-1):
				var p := Vector2(road.points[i][0],road.points[i][1])
				var q := Vector2(road.points[i+1][0],road.points[i+1][1])
				var b := p+(q-p)*clampf((a-p).dot(q-p)/(q-p).length_squared(),0,1)
				if b.distance_to(a)<nearest.distance_to(a): nearest=b
		var d := nearest-a
		_shape(scatter,Vector3((a.x+nearest.x)*.5,0,(a.y+nearest.y)*.5),Vector3(3.4+2*margin,100,d.length()+2*margin),true,atan2(d.x,d.y))

func _start_scatter() -> void:
	pcg_report.plugins.append_array(["EZ-Tree 0.2.0", "SimpleGrassTextured 2.1.0"])
	pcg_report["scope"] = "first demo living district; existing resident identities and historical state"
	for frame in 3: await get_tree().physics_frame
	asset_root = "res://assets/floor1/pcg_native/"
	_scatter("ez-oak",42,Vector3(-79,0,22),Vector3(64,1,188),4,true,61)
	_scatter("ez-small-oak",38,Vector3(78,0,31),Vector3(58,1,184),4,true,62)
	_scatter("ez-oak",28,Vector3(-2,0,132),Vector3(170,1,44),4,true,63)
	_scatter("ez-small-oak",8,Vector3(-40,0,-12),Vector3(28,1,90),4,true,64)
	_scatter("simple-grass",26000,Vector3(-58,0,27),Vector3(100,1,208),.85,false,65)
	_scatter("simple-grass",24000,Vector3(59,0,27),Vector3(100,1,208),.85,false,66)
	_scatter("simple-grass",9000,Vector3(0,0,122),Vector3(174,1,39),.85,false,67)
	_scatter("simple-grass",7000,Vector3(0,0,-63),Vector3(80,1,29),.85,false,68)
	asset_root = DEMO_ASSETS
	_scatter("boulder",16,Vector3(-97,0,30),Vector3(33,1,175),5,true,69)
	_scatter("boulder",12,Vector3(94,0,38),Vector3(28,1,160),5,true,70)
	_scatter("fallen-log",8,Vector3(0,0,136),Vector3(165,1,24),5,true,71)
	for scatter in scatter_nodes:
		scatter.full_rebuild()
		await scatter.build_completed
	pcg_report["grass_rendering"] = "SimpleGrassTextured original mesh, CC0 texture and wind, ProtonScatter MultiMesh"
	pcg_report["trees"] = "EZ-Tree native PBR bark and lit wind leaves, trunk colliders"
	pcg_report["scatter_rule"] = "seeded native modifiers, projected terrain, slope limits, roads/homes/door approaches/yards excluded"
	pcg_report["new_meshy_models"] = 4
	pcg_ready = scatter_complete == scatter_expected
	print("DEMO_PCG_READY groups=",scatter_complete," props=",dressing.size())
