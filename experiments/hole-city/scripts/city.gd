extends Node3D
## Deterministic original city geometry; no proprietary map or model assets.
const Food = preload("res://scripts/swallowable.gd")
const Windows = preload("res://shaders/windows.gdshader")
var game: Node
var foods: Array[Node3D] = []
var materials := {}
var rng := RandomNumberGenerator.new()
var serial := 0

func build(owner_game: Node) -> void:
	game = owner_game
	rng.seed = 20260924
	var tones := [Color("edb778"), Color("e88677"), Color("82b4ba"), Color("e5cc95"), Color("a5b1ca"), Color("96c3b0")]
	for ix in 4:
		for iz in 4:
			var center := Vector2(-24 + ix * 16, -24 + iz * 16)
			if (ix == 1 and iz == 2) or (ix == 3 and iz == 0):
				_park(center)
				continue
			for dx in [-3.25, 3.25]:
				for dz in [-3.25, 3.25]:
					var downtown := iz < 2 and ix > 0 and ix < 3
					var wide := rng.randf_range(3.5, 4.8) if downtown else rng.randf_range(2.6, 3.6)
					var tall := rng.randf_range(9.0, 16.0) if downtown else rng.randf_range(3.0, 7.0)
					_building(center + Vector2(dx,dz), wide, tall, tones[rng.randi_range(0,tones.size()-1)], downtown)
	for street in [-32.0,-16.0,0.0,16.0,32.0]:
		for offset in [-29.0,-23.0,-13.0,-7.0,3.0,9.0,19.0,25.0]:
			_car(Vector2(street + 1.1, offset), false, tones[rng.randi_range(0,5)])
			_car(Vector2(offset, street - 1.1), true, tones[rng.randi_range(0,5)])
			_prop(Vector2(street + 3.1, offset + 1.5), 0)
			_prop(Vector2(offset + 1.5, street - 3.1), 1)
			if int(offset) % 3 != 0:
				_tree(Vector2(street-3.2,offset), false)
				_prop(Vector2(offset,street+3.2),2)
	for i in 12:
		_prop(Vector2(-2.7 + float(i % 2) * 5.4, 18.0 + floorf(float(i) / 2.0) * 2.2), 0)
	# Surrounding water and a pedestal make the map readable without fake boundaries.
	box(self,Vector3(0,-4.8,0),Vector3(84,3.0,84),Color("537e83"))
	box(self,Vector3(0,-6.5,0),Vector3(500,0.5,500),Color("71b5bf"))
	for x in [-39.0,39.0]:
		box(self,Vector3(x,0.08,0),Vector3(0.55,0.16,78.0),Color("e2d9ba"))
	for z in [-39.0,39.0]:
		box(self,Vector3(0,0.08,z),Vector3(78.0,0.16,0.55),Color("e2d9ba"))

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	materials[key] = mat
	return mat

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material(color)
	parent.add_child(visual)
	visual.position = at
	return visual

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 8
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material(color)
	parent.add_child(visual)
	visual.position = at
	return visual

func _food(at: Vector2, size: Vector3, category: String, points: int) -> RigidBody3D:
	var body := Food.new()
	body.game = game
	body.height = size.y
	body.footprint = Vector2(size.x,size.z).length() * 0.5
	body.category = category
	body.points = points
	serial += 1
	body.name = "%s_%03d" % [category, serial]
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = Vector3(at.x,size.y*0.5+0.04,at.y)
	foods.append(body)
	return body

func _building(at: Vector2, width: float, floors_height: float, tone: Color, tower: bool) -> void:
	var roof := 0.9 if tower else 0.65
	var total := floors_height + roof
	var body := _food(at,Vector3(width+0.3,total,width+0.3),"tower" if tower else "building",45 if tower else 20)
	var wall := box(body,Vector3(0,-roof*0.5,0),Vector3(width,floors_height,width),tone)
	var mat := ShaderMaterial.new()
	mat.shader = Windows
	mat.set_shader_parameter("wall_color",tone)
	mat.set_shader_parameter("floors",floorf(floors_height / 1.5))
	mat.set_shader_parameter("columns",3.0)
	wall.material_override = mat
	box(body,Vector3(0,total*0.5-roof*0.75,0),Vector3(width+0.24,0.25,width+0.24),Color("f2e4cd"))
	box(body,Vector3(0,total*0.5-roof*0.3,0),Vector3(width*0.55,roof*0.6,width*0.5),tone.darkened(0.25))
	box(body,Vector3(0,-total*0.5+0.6,width*0.5+0.025),Vector3(0.65,1.2,0.055),Color("28424e"))
	if not tower:
		box(body,Vector3(0,-total*0.5+1.5,width*0.5+0.11),Vector3(width*0.8,0.15,0.3),Color("f6cf79"))

func _car(at: Vector2, sideways: bool, tone: Color) -> void:
	var body := _food(at,Vector3(1.25,1.05,2.65),"car",6)
	box(body,Vector3(0,-0.12,0),Vector3(1.23,0.5,2.65),tone)
	box(body,Vector3(0,0.24,0.0),Vector3(1.02,0.45,1.4),tone.lightened(0.15))
	box(body,Vector3(0,0.24,-0.6),Vector3(0.96,0.34,0.055),Color("274551"))
	box(body,Vector3(0,0.24,0.61),Vector3(0.96,0.34,0.055),Color("274551"))
	for x in [-0.61,0.61]:
		for z in [-0.78,0.78]:
			var wheel := cylinder(body,Vector3(x,-0.3,z),0.24,0.13,Color("26313c"))
			wheel.rotation.z = PI * 0.5
	box(body,Vector3(0,-0.15,-1.34),Vector3(0.9,0.12,0.06),Color("f9e8a8"))
	if sideways: body.rotation.y = PI * 0.5

func _tree(at: Vector2, large: bool) -> void:
	var size := 1.55 if large else 1.05
	var h := 3.3 if large else 2.4
	var body := _food(at,Vector3(size,h,size),"tree",4 if large else 3)
	cylinder(body,Vector3(0,-h*0.24,0),0.11,h*0.5,Color("946f50"))
	cylinder(body,Vector3(0,h*0.18,0),size*0.5,h*0.6,Color("599e74") if large else Color("77b98b"),size*0.17)

func _prop(at: Vector2, style: int) -> void:
	if style == 0:
		var body := _food(at,Vector3(0.43,0.65,0.43),"cone",1)
		box(body,Vector3(0,-0.28,0),Vector3(0.43,0.08,0.43),Color("d77652"))
		cylinder(body,Vector3(0,0.04,0),0.19,0.55,Color("ef9b58"),0.035)
		cylinder(body,Vector3(0,0.03,0),0.12,0.12,Color("fff0d8"),0.09)
	elif style == 1:
		var body := _food(at,Vector3(0.56,0.85,0.56),"bin",2)
		box(body,Vector3.ZERO,Vector3(0.53,0.78,0.53),Color("44797a"))
		box(body,Vector3(0,0.4,0),Vector3(0.56,0.06,0.56),Color("284e59"))
	else:
		var body := _food(at,Vector3(0.48,0.8,0.48),"hydrant",2)
		cylinder(body,Vector3.ZERO,0.16,0.75,Color("e77361"))
		box(body,Vector3(0,0.12,0),Vector3(0.48,0.18,0.2),Color("e77361"))

func _park(center: Vector2) -> void:
	# The planter is edible too; no decorative slab can remain floating over a hole.
	var lawn := _food(center,Vector3(9.0,0.1,9.0),"garden",32)
	box(lawn,Vector3.ZERO,Vector3(9.0,0.1,9.0),Color("94c398"))
	for x in [-3.4,0.0,3.4]:
		for z in [-3.4,0.0,3.4]: _tree(center+Vector2(x,z),true)
	for x in [-5.5,5.5]:
		for z in [-3.0,3.0]:
			var bench := _food(center+Vector2(x,z),Vector3(1.5,0.75,0.6),"bench",3)
			box(bench,Vector3(0,0.0,0),Vector3(1.5,0.12,0.6),Color("b59065"))
			box(bench,Vector3(0,0.25,0.23),Vector3(1.5,0.3,0.08),Color("b59065"))
			for leg in [-0.5,0.5]:box(bench,Vector3(leg,-0.2,0),Vector3(0.12,0.4,0.4),Color("496769"))
