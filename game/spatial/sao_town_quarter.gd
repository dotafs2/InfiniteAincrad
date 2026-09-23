extends Node3D
## Reference-aligned review blockout. No gameplay or navigation integration.
const LAYOUT_PATH := "res://spatial/sao_town_quarter_layout.json"
const SCALE := 0.1
var built := false
var data: Dictionary
var materials: Dictionary = {}
var camera: Camera3D
var label_root: Node3D

func _ready() -> void:
	build()

func mat(key: String) -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(data.palette[key])
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = m
	return m

func point(p: Array, height: float = 0.0) -> Vector3:
	return Vector3((float(p[0])-627.0)*SCALE, height, (float(p[1])-627.0)*SCALE)

func polygon(id: String, pixels: Array, key: String, height: float, bottom: float = 0.0) -> MeshInstance3D:
	var xy := PackedVector2Array()
	for p: Array in pixels: xy.append(Vector2(float(p[0]), float(p[1])))
	var triangles := Geometry2D.triangulate_polygon(xy)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in triangles:
		st.add_vertex(point(pixels[i], height))
	if height > bottom:
		for i in pixels.size():
			var a := point(pixels[i], height)
			var b := point(pixels[(i+1)%pixels.size()], height)
			var c := Vector3(b.x, bottom, b.z)
			var d := Vector3(a.x, bottom, a.z)
			for v: Vector3 in [a,b,c,a,c,d]: st.add_vertex(v)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = st.commit()
	node.material_override = mat(key)
	node.set_meta("surface_category", key)
	add_child(node)
	return node

func disc(id: String, center: Array, radius: float, key: String, height: float, segments: int = 64) -> void:
	var pixels: Array = []
	for i in segments:
		var a := TAU*float(i)/float(segments)
		pixels.append([float(center[0])+cos(a)*radius,float(center[1])+sin(a)*radius])
	polygon(id,pixels,key,height)

func arc(id: String, center: Array, inner: float, outer: float, start: float, end: float, key: String, height: float) -> void:
	var pixels: Array = []
	var count := maxi(2,ceili(absf(end-start)/3.0))
	for i in count+1:
		var a := deg_to_rad(lerpf(start,end,float(i)/count))
		pixels.append([float(center[0])+cos(a)*outer,float(center[1])+sin(a)*outer])
	for i in range(count,-1,-1):
		var a := deg_to_rad(lerpf(start,end,float(i)/count))
		pixels.append([float(center[0])+cos(a)*inner,float(center[1])+sin(a)*inner])
	polygon(id,pixels,key,height)

func build() -> void:
	if built: return
	data = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	built = true
	disc("OuterGrass",[627,627],625,"garden",0.02,160)
	disc("TownPaving",[627,627],587,"paving",0.07,160)
	# Four perimeter arcs leave the gate gaps visible in the source plan.
	for r: Array in [[-163,-81],[-75,7],[13,25],[31,99],[105,193]]:
		arc("Wall",[627,627],596,616,float(r[0]),float(r[1]),"wall",1.5)
	for r: Array in [[-165,-79],[-77,8],[11,27],[29,101],[103,195]]:
		arc("WallWalk",[627,627],583,596,float(r[0]),float(r[1]),"wall",0.15)
	disc("PlazaBorder",[615,620],181,"wall",0.11,128)
	disc("Plaza",[615,620],160,"plaza",0.13,128)
	for r in [50.0,75.0,100.0,125.0,150.0]:
		arc("PlazaPavingRing",[615,620],r,r+0.7,0,359.9,"paving",0.145)
	arc("RedArcBorderA",[615,620],165,218,-135,-2,"wall",0.2)
	arc("RedArcBorderB",[615,620],165,185,42,178,"wall",0.2)
	arc("RedRoofA",[615,620],173,208,-134,-3,"red",1.0)
	arc("RedRoofB",[615,620],172,207,43,177,"red",1.0)
	for i in data.water.size(): polygon("Water_%02d"%i,data.water[i],"water",0.10)
	for i in data.gardens.size(): polygon("Garden_%02d"%i,data.gardens[i],"garden",0.14)
	for i in data.bridges.size(): polygon("Bridge_%02d"%i,data.bridges[i],"wall",0.24)
	for i in data.buildings.size():
		var b: Array = data.buildings[i]
		var pixels: Array = b[0]
		polygon("Building_%02d"%i,pixels,String(b[1]),1.7+float(i%3)*0.25)
		# Roof ridge lines preserve individual footprint legibility.
		if pixels.size()==4:
			var a: Vector3 = point(pixels[0],2.25)
			var c: Vector3 = point(pixels[2],2.25)
			var beam := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size=Vector3(0.06,0.04,a.distance_to(c))
			beam.mesh=mesh
			beam.material_override=mat("wall")
			beam.position=(a+c)*0.5
			add_child(beam)
			beam.look_at(c,Vector3.UP)
	polygon("DarkLandmarkBase",[[148,385],[298,420],[340,578],[260,602],[105,558]],"wall",0.30)
	polygon("DarkLandmarkWing",[[91,418],[122,417],[148,462],[110,538],[79,539]],"dark",2.0)
	for dome: Array in [[222,498,65],[291,438,22],[333,477,19],[322,522,30],[303,573,22],[253,586,24]]:
		disc("DomeBase",[dome[0],dome[1]],float(dome[2])+3.0,"dark",2.1)
		var sphere := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius=float(dome[2])*SCALE
		mesh.height=mesh.radius*1.1
		sphere.mesh=mesh
		sphere.position=point([dome[0],dome[1]],2.2)
		sphere.material_override=mat("dark")
		add_child(sphere)
	for f: Array in data.fountains:
		disc("FountainRim",[f[0],f[1]],float(f[2]),"wall",0.38)
		disc("FountainWater",[f[0],f[1]],float(f[2])-3.0,"water",0.40)
		disc("FountainCenter",[f[0],f[1]],4.5,"wall",0.65)
	for t: Array in data.trees:
		disc("TreeTrunk",[t[0],t[1]],2.5,"paving",1.4,8)
		disc("TreeCanopy",[t[0],t[1]],float(t[2]),"tree",2.1,10)
	for p: Array in data.pavilions: disc("RedPavilion",[p[0],p[1]],float(p[2]),"red",2.4,8)
	polygon("CenterMonument",[[590,576],[650,587],[660,600],[640,650],[577,630]],"monument",1.0)
	disc("CenterTower",[587,605],19,"monument",4.0)
	# Two pale canopies on the southern green.
	polygon("CanopyA",[[597,999],[629,1002],[628,1032],[600,1030]],"wall",1.7)
	polygon("CanopyB",[[638,998],[670,996],[674,1031],[642,1030]],"wall",1.7)
	environment_setup()
	add_labels()

func environment_setup() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#13181b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color.WHITE
	env.ambient_light_energy=0.65
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env_node.environment=env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-72,-30,0)
	sun.light_energy=0.65
	sun.shadow_enabled=true
	add_child(sun)
	camera=Camera3D.new()
	camera.name="QuarterCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=131.0
	camera.far=500
	add_child(camera)
	top_view()
	camera.current=true

func top_view() -> void:
	camera.position=Vector3(0,160,0)
	camera.rotation_degrees=Vector3(-90,0,0)
	camera.size=131.0

func oblique_view() -> void:
	camera.position=Vector3(90,130,130)
	camera.look_at(Vector3.ZERO,Vector3.UP)
	camera.size=162.0

func add_labels() -> void:
	label_root=Node3D.new()
	label_root.name="ReferenceMarkers"
	add_child(label_root)
	for entry: Array in data.labels:
		var label := Label3D.new()
		label.text=String(entry[0])
		label.font_size=42
		label.pixel_size=0.024
		label.outline_size=9
		label.modulate=Color.WHITE
		label.no_depth_test=true
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=point([entry[1],entry[2]],6.5)
		label_root.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_1: top_view()
		if event.keycode==KEY_2: oblique_view()
		if event.keycode==KEY_L: label_root.visible=not label_root.visible
