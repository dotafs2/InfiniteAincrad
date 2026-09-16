extends Node3D
## Art and physical geometry for the same saved world. No life decisions here.
const LAYOUT_PATH := "res://spatial/living_quarter_layout.json"
const House = preload("res://spatial/modular_house_component.gd")
const Interior = preload("res://spatial/living_quarter_interior.gd")
const ENV := "res://assets/floor1/environment_kit_20/"
var layout: Dictionary
var houses: Dictionary = {}
var entrances: Dictionary = {}
var materials: Dictionary = {}
var cached: Dictionary = {}

func build() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	for key in {"grass":"718957", "stone":"aaa28a", "wood":"796144", "roof":"aa6951", "cream":"e5cf9a", "red":"b5654f", "blue":"78969a"}:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color({"grass":"718957", "stone":"aaa28a", "wood":"796144", "roof":"aa6951", "cream":"e5cf9a", "red":"b5654f", "blue":"78969a"}[key])
		m.roughness = 0.92
		materials[key] = m
	_build_surface()
	for i in layout.houses.size():
		_build_house(layout.houses[i], i)
	for i in layout.infill.size():
		_build_house(layout.infill[i], i + 10)
	_dress_market()
	_landscape()
	for entry in layout.connections:
		var sign := Label3D.new()
		sign.text = entry.name
		sign.position = Vector3(entry.point[0], height_at(entry.point[0], entry.point[2]) + 3, entry.point[2])
		sign.font_size = 54
		sign.pixel_size = 0.015
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sign)

func height_at(x: float, z: float) -> float:
	# A broad settled valley; continuous surrounding slopes, not disconnected flat tiles.
	var edge := maxf(absf(x) - 53.0, 0.0)
	var height := pow(edge / 15.0, 1.35) * (2.0 + 0.55 * sin(z * 0.065))
	height += pow(maxf(z - 104.0, 0.0) / 17.0, 1.4) * 1.5
	for h in layout.houses + layout.infill:
		if h.at[1] <= 0: continue
		var distance := Vector2(x - h.at[0], z - h.at[2]).length()
		var factor := 1.0 - smoothstep(6.0, 12.0, distance)
		height = maxf(height, h.at[1] * factor)
	return height

func _road_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var v := b - a
	var t := clampf((point-a).dot(v) / maxf(v.length_squared(), 0.001), 0, 1)
	return point.distance_to(a + v * t)

func _paved(x: float, z: float) -> bool:
	var point := Vector2(x, z)
	for center in [Vector2(2.5,14.5), Vector2(-20.8,40), Vector2(0,53), Vector2(25.9,72.9)]:
		if point.distance_to(center) < (9.0 if center.y < 20 else 5.5): return true
	for road in layout.roads:
		for i in range(road.points.size()-1):
			var a: Array = road.points[i]
			var b: Array = road.points[i+1]
			if _road_distance(point, Vector2(a[0],a[1]), Vector2(b[0],b[1])) < road.width*0.5: return true
	# Aprons connect each real door to the nearest road, across the same terrain.
	for house in layout.houses + layout.infill:
		var at := Vector2(house.at[0], house.at[2])
		if point.distance_to(at) < 7: return true
		var nearest := Vector2.INF
		for road in layout.roads:
			for i in range(road.points.size()-1):
				var a := Vector2(road.points[i][0], road.points[i][1])
				var b := Vector2(road.points[i+1][0], road.points[i+1][1])
				var p := a + (b-a) * clampf((at-a).dot(b-a)/(b-a).length_squared(), 0, 1)
				if p.distance_to(at) < nearest.distance_to(at): nearest = p
		if _road_distance(point, at, nearest) < 1.7: return true
	return false

func _build_surface() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 land_world;
void vertex(){land_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=land_world.xz;
 float grain=fract(sin(dot(floor(p*5.0),vec2(12.9898,78.233)))*43758.5453);
 float row=mod(floor(p.y*2.0),2.0)*0.5;
 vec2 cell=fract(vec2(p.x*1.45+row,p.y*2.0));
 float seam=step(0.065,cell.x)*step(0.065,cell.y);
 vec3 stone=vec3(0.49,0.45,0.37)*(0.85+grain*0.2)*(0.78+seam*0.22);
 vec3 grass=vec3(0.30,0.40,0.20)*(0.90+grain*0.20+sin(p.x*0.23)*0.055);
 ALBEDO=mix(grass,stone,COLOR.r); ROUGHNESS=0.96;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Dictionary = {}
	var bounds: Array = layout.terrain_bounds
	for z in range(int(bounds[1]),int(bounds[3])+1,2):
		for x in range(int(bounds[0]),int(bounds[2])+1,2):
			vertices[Vector2i(x,z)] = [Vector3(x,height_at(x,z),z),Color(1,1,1) if _paved(x,z) else Color(0,0,0)]
	for z in range(int(bounds[1]),int(bounds[3]),2):
		for x in range(int(bounds[0]),int(bounds[2]),2):
			for key in [Vector2i(x,z),Vector2i(x+2,z),Vector2i(x,z+2),Vector2i(x+2,z),Vector2i(x+2,z+2),Vector2i(x,z+2)]:
				st.set_color(vertices[key][1])
				st.add_vertex(vertices[key][0])
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "ContinuousValleyTerrain"
	terrain.mesh = st.commit()
	terrain.material_override = mat
	add_child(terrain)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(shape)
	terrain.add_child(body)

func _build_house(entry: Dictionary, index: int) -> void:
	var house := House.new()
	house.name = "Home_%02d" % (index+1)
	house.variant_id = entry.variant
	house.position = Vector3(entry.at[0],entry.at[1],entry.at[2])
	house.rotation_degrees.y = entry.yaw
	add_child(house)
	if house.door_collision != null:
		# Dynamic doors physically block bodies, but are not baked as permanent walls.
		house.door_collision.collision_layer = 4
	var id: String = entry.get("resident", "infill:%02d" % index)
	houses[id] = house
	var door: Vector3 = house.to_global(house.door_opening_godot().centre)
	door.y = house.global_position.y
	entrances[id] = door
	if entry.has("resident"):
		var interior := Interior.new()
		interior.show_bakery_exterior_sign = false
		house.add_child(interior)

func _box(title: String, at: Vector3, size: Vector3, material: String, solid: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = materials[material]
	node.position = at
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		node.add_child(body)
	return node

func _asset(path: String, at: Vector3, height: float, yaw: float = 0) -> Node3D:
	if not cached.has(path): cached[path] = load(path)
	var packed := cached[path] as PackedScene
	if packed == null: return null
	var holder := Node3D.new()
	var node := packed.instantiate() as Node3D
	holder.add_child(node)
	add_child(holder)
	var low := Vector3.INF
	var high := -Vector3.INF
	for item: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if item.mesh == null: continue
		if String(item.name).begins_with("COL_"):
			item.visible = false
			continue
		var bounds := item.mesh.get_aabb()
		for i in 8:
			var p := item.global_transform * bounds.get_endpoint(i)
			low = low.min(p)
			high = high.max(p)
	if high.y <= low.y:
		holder.queue_free()
		return null
	var factor := height / (high.y-low.y)
	node.position = -Vector3((low.x+high.x)*.5,low.y,(low.z+high.z)*.5)
	holder.scale = Vector3.ONE * factor
	holder.position = at
	holder.rotation_degrees.y = yaw
	return holder

func _dress_market() -> void:
	# Paired street fronts, shade canopies and an overhead passage echo the confirmed market image.
	for side in [-1,1]:
		_box("PassagePier",Vector3(side*7.7,3.9,-45),Vector3(2,7.8,3),"stone")
	_box("UpperMarketPassage",Vector3(0,8,-45),Vector3(17.5,2.3,3.4),"cream")
	_box("PassageTileCap",Vector3(0,9.3,-45),Vector3(18.3,.35,4),"roof",false)
	for x in [-6,-3,0,3,6]:
		_box("PassageWindow",Vector3(x,8.1,-43.28),Vector3(.8,1.1,.08),"wood",false)
	for i in range(6):
		var x := -6.2 if i%2==0 else 6.2
		var z := -30.0 + floori(i/2.0)*12
		_box("MarketCounter",Vector3(x,.52,z),Vector3(1.4,1.04,3.5),"wood")
		_box("StripedCanopy",Vector3(x,2.7,z),Vector3(2.6,.12,4),"cream",false)
		for stripe in [-1,0,1]:
			_box("CanopyStripe",Vector3(x,2.78,z+stripe*1.2),Vector3(2.6,.025,.55),"red" if i%2==0 else "blue",false)
		for end in [-1,1]:
			_box("CanopyPost",Vector3(x,1.35,z+end*1.8),Vector3(.09,2.7,.09),"wood")
		_asset("res://assets/generated/travel_cargo_20260912/partitioned_ceramic_crate.glb",Vector3(x,1.05,z),.52)
	for z in [-36,-9,18]:
		for i in range(16):
			var x1 := -9.0 + i * 1.125
			var x2 := x1 + 1.125
			var a := Vector3(x1,5.53+pow(x1/7.2,2)*.6,z)
			var b := Vector3(x2,5.53+pow(x2/7.2,2)*.6,z)
			var rope := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = .018
			cylinder.bottom_radius = .018
			cylinder.height = a.distance_to(b)
			cylinder.radial_segments = 6
			rope.mesh = cylinder
			rope.material_override = materials.wood
			rope.position = (a+b)*.5
			rope.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
			add_child(rope)
		for i in range(13):
			var x := -7.2 + i*1.2
			var y := 5.3 + pow(x/7.2,2)*.6
			_box("FestivalRibbon",Vector3(x,y,z),Vector3(.50,.46,.015),"cream" if i%2==0 else "red",false)
	_asset("res://assets/floor1/plaza_fountain_20260916/F1_plaza_fountain.glb",Vector3(-5,0,18),2.2)
	_box("FountainCollision",Vector3(-5,.55,18),Vector3(2.5,1.1,2.5),"stone").visible=false
	_asset(ENV+"F1_stone_water_trough.glb",Vector3(-7.5,0,8.5),1.0)
	_box("TroughCollision",Vector3(-7.5,.4,8.5),Vector3(1.1,.8,2),"stone").visible=false
	_asset(ENV+"F1_canvas_rest_shelter.glb",Vector3(34,0,70),3.7,130)
	_box("RestBench",Vector3(34,.45,70),Vector3(3,.9,.55),"wood")
	for xz in [Vector2(-25,44),Vector2(-9,53),Vector2(21,75),Vector2(19,16)]:
		_asset(ENV+"F1_herb_planter.glb",Vector3(xz.x,height_at(xz.x,xz.y),xz.y),.65)

func _landscape() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9162026
	for i in range(46):
		var x := rng.randf_range(48,86) * (-1 if i%2==0 else 1)
		var z := rng.randf_range(-59,124)
		if _paved(x,z): continue
		_asset("res://assets/floor1/courtyard_oak_20260916/F1_oak_smart15k_forest_trial.glb",Vector3(x,height_at(x,z),z),rng.randf_range(8,14),rng.randf_range(0,360))
		# Tree trunks collide; leaves remain navigable under the canopy.
		_box("TreeTrunk",Vector3(x,height_at(x,z)+1.5,z),Vector3(.8,3,.8),"wood").visible=false
	for at in [Vector2(-8,46),Vector2(20,58),Vector2(-20,90),Vector2(29,-23),Vector2(-31,-10)]:
		_asset(ENV+"F1_orchard_apple.glb",Vector3(at.x,height_at(at.x,at.y),at.y),5.5)
		_box("OrchardTrunk",Vector3(at.x,height_at(at.x,at.y)+1,at.y),Vector3(.5,2,.5),"wood").visible=false
	for i in 35:
		var x := rng.randf_range(-78,78)
		var z := rng.randf_range(-66,125)
		if _paved(x,z): continue
		_asset(ENV+"F1_flowering_shrub.glb",Vector3(x,height_at(x,z),z),rng.randf_range(.6,1.1))
