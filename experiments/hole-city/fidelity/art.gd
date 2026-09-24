extends "res://scripts/city.gd"
## All models below are authored from primitives and meshes, not extracted assets.
const Facade = preload("res://fidelity/facade.gdshader")
var fading: Array[Dictionary] = []
var people: Array[Node3D] = []
var preview: Node3D

func sphere(parent: Node3D, at: Vector3, radius: float, tint: Color, scale_y:=1.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius=radius
	m.height=radius*2.0
	m.radial_segments=10
	m.rings=5
	var v := MeshInstance3D.new()
	v.mesh=m
	v.material_override=material(tint)
	parent.add_child(v)
	v.position=at
	v.scale.y=scale_y
	return v

func roof(parent: Node3D, width: float, depth: float, y: float, tint: Color) -> void:
	var a:=Vector3(-width/2,y,-depth/2)
	var b:=Vector3(width/2,y,-depth/2)
	var c:=Vector3(width/2,y,depth/2)
	var d:=Vector3(-width/2,y,depth/2)
	var e:=Vector3(0,y+width*0.28,-depth/2)
	var f:=Vector3(0,y+width*0.28,depth/2)
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[a,e,b],[d,c,f],[a,d,f],[a,f,e],[e,f,c],[e,c,b]]:
		for vertex in tri:st.add_vertex(vertex)
	st.generate_normals()
	var v:=MeshInstance3D.new()
	v.mesh=st.commit()
	v.material_override=material(tint)
	parent.add_child(v)

func facade(parent: Node3D, size: Vector3, at: Vector3, tint: Color, tower:=false) -> ShaderMaterial:
	var v:=box(parent,at,size,tint)
	var mat:=ShaderMaterial.new()
	mat.shader=Facade
	mat.set_shader_parameter("wall_color",tint)
	mat.set_shader_parameter("floors",maxf(2,floorf(size.y/(0.35 if tower else 1.35))))
	mat.set_shader_parameter("columns",maxf(2,floorf(size.x/(0.16 if tower else 0.85))))
	mat.set_shader_parameter("glass_tower",tower)
	v.material_override=mat
	return mat

func build(owner_game: Node) -> void:
	game=owner_game
	rng.seed=20260925
	var wall_colors:=[Color("ac523b"),Color("ad9c82"),Color("798076"),Color("6f6560"),Color("c2b28e")]
	# The starting parking court, with a long row of mixed older city facades.
	for i in 9:
		city_house(Vector2(-20.0+i*5.1,1.0),Vector3(4.8,6.6+float(i%3)*1.8,7.0),wall_colors[i%5])
	for i in 9:
		city_house(Vector2(-20.0+i*5.1,-21.0),Vector3(4.8,7.2+float((i+1)%3)*1.7,7.8),wall_colors[(i+2)%5])
	for side in [-39.0,40.0]:
		for z in [-29.0,-15.0,0.0,16.0,31.0]:
			city_house(Vector2(side,z),Vector3(7.0,7.0+rng.randf()*5.0,8.0),wall_colors[rng.randi_range(0,4)])
	var cars:=[Color("b0211e"),Color("b52920"),Color("686f61"),Color("e5e2d6"),Color("255cba"),Color("d8ad40"),Color("deddd4"),Color("383e43")]
	var parking_colors:=[5,4,3,2,0,1,6,7,4]
	var parking_kinds:=[4,0,3,2,0,0,0,0,0]
	for i in 9:
		city_car(Vector2(-16.5+i*3.7,11.0),cars[parking_colors[i]],PI,parking_kinds[i])
		city_car(Vector2(-16.5+i*3.7,-35.5),cars[(i+4)%8],0.0,0)
	for x in [-27.0,29.0]:
		for z in [-38.0,-22.0,-11.0,8.0,25.0,39.0]:city_car(Vector2(x-1.6,z),cars[rng.randi_range(0,7)],0.0,0)
	for z in [-2.0,-30.0]:
		for x in [-16.0,-4.0,12.0,20.0]:city_car(Vector2(x,z+1.4),cars[rng.randi_range(0,7)],PI/2,0)
	# A small park to the right and a second square beyond the cross street.
	city_park(Vector2(21.5,24.0),Vector2(9.0,22.0))
	city_park(Vector2(4.0,-39.0),Vector2(22.0,8.0))
	for x in [-22.0,23.0,-32.0,34.0]:
		for z in [-36.0,-25.0,-12.0,5.0,18.0,33.0,42.0]:
			lamp(Vector2(x,z))
			bin_prop(Vector2(x+0.8,z+1.6))
			person(Vector2(x+1.0,z+3.0),randi()%4)
	for i in 22:
		var x:float=-20.0+i*2.0
		person(Vector2(x,5.5),i%4)
		cone(Vector2(x,37.0))
	for i in 14:
		cone(Vector2(-18.5+i*2.7,16.2))
		bin_prop(Vector2(-18.5+i*2.7,37.5))
	for at in [Vector2(5,23),Vector2(13,31)]:
		var cover:=_food(at,Vector3(1.4,0.16,2.3),"cover",2)
		box(cover,Vector3.ZERO,Vector3(1.4,0.16,2.3),Color("41433d"))
	subway(Vector2(-18.0,-7.8))
	subway(Vector2(8.0,-34.7))
	for z in [18.0,26.0]:
		var lid:=_food(Vector2(-3,z),Vector3(0.68,0.08,0.68),"manhole",1)
		cylinder(lid,Vector3.ZERO,0.34,0.07,Color("454847"))
	box(self,Vector3(0,-4.9,0),Vector3(103,3.0,103),Color("73644e"))
	box(self,Vector3(0,-6.7,0),Vector3(300,0.2,300),Color("1e99f1"))

func city_house(at: Vector2, size: Vector3, tint: Color) -> void:
	var body:=_food(at,Vector3(size.x+0.3,size.y+size.x*0.28,size.z+0.3),"building",35)
	var base_y:float=-body.height*0.5
	var mat:=facade(body,size,Vector3(0,base_y+size.y/2,0),tint)
	roof(body,size.x+0.4,size.z+0.4,base_y+size.y,Color("464b48"))
	box(body,Vector3(0,base_y+0.95,size.z/2+0.03),Vector3(0.9,1.9,0.10),Color("243431"))
	for y in [1.9,size.y-0.1]:box(body,Vector3(0,base_y+y,0),Vector3(size.x+0.24,0.18,size.z+0.24),tint.lightened(0.2))
	box(body,Vector3(-size.x*0.3,base_y+size.y+0.6,-size.z*0.2),Vector3(0.48,1.2,0.6),tint.darkened(0.3))
	fading.append({"body":body,"mat":mat,"half":Vector2(size.x,size.z)*0.5})

func city_car(at: Vector2, tint: Color, angle: float, kind: int) -> void:
	var size:=Vector3(1.65,1.18,3.5) if kind!=4 else Vector3(1.9,1.85,4.2)
	var body:=_food(at,size,"vehicle",7 if kind!=4 else 12)
	var low:float=-size.y/2
	body.rotation.y=angle
	if kind not in [2,4]:
		prism(body,PackedVector2Array([Vector2(-1.75,0.24),Vector2(-1.70,0.52),Vector2(-1.20,0.64),Vector2(1.0,0.65),Vector2(1.70,0.48),Vector2(1.75,0.24)]),size.x,low,tint)
	else:box(body,Vector3(0,low+0.42,0),Vector3(size.x,0.48,size.z),tint)
	if kind==2:
		box(body,Vector3(0,low+0.91,-0.55),Vector3(1.42,0.55,1.6),tint)
		box(body,Vector3(0,low+0.69,0.93),Vector3(1.4,0.09,1.48),Color("292d2a"))
	elif kind==4:
		var cabin_h:=0.52 if kind!=4 else 1.1
		box(body,Vector3(0,low+0.64+cabin_h/2,-0.03),Vector3(size.x*0.88,cabin_h,size.z*0.54),tint)
		for side in [-1,1]:
			box(body,Vector3(side*size.x*0.445,low+0.78+cabin_h/2,-0.08),Vector3(0.02,cabin_h*0.6,size.z*0.44),Color("26343a"))
		box(body,Vector3(0,low+0.78+cabin_h/2,-size.z*0.273),Vector3(size.x*0.77,cabin_h*0.6,0.028),Color("53777e"))
		box(body,Vector3(0,low+0.78+cabin_h/2,size.z*0.273),Vector3(size.x*0.77,cabin_h*0.6,0.028),Color("354e59"))
	else:
		prism(body,PackedVector2Array([Vector2(-0.95,0.64),Vector2(-0.44,1.10),Vector2(0.45,1.12),Vector2(1.06,0.65)]),1.40,low,tint)
		var glass:=Color("334b55")
		for side in [-1,1]:
			quad(body,[Vector3(side*0.706,low+0.73,-0.77),Vector3(side*0.706,low+1.04,-0.37),Vector3(side*0.706,low+1.06,0.39),Vector3(side*0.706,low+0.74,0.87)],glass)
			box(body,Vector3(side*0.714,low+0.91,0.07),Vector3(0.025,0.35,0.055),tint)
			box(body,Vector3(side*0.83,low+0.75,-0.6),Vector3(0.17,0.11,0.21),tint)
		quad(body,[Vector3(-0.63,low+0.71,-0.92),Vector3(0.63,low+0.71,-0.92),Vector3(0.61,low+1.075,-0.43),Vector3(-0.61,low+1.075,-0.43)],Color("50717b"))
		quad(body,[Vector3(-0.62,low+0.70,1.02),Vector3(0.62,low+0.70,1.02),Vector3(0.61,low+1.08,0.46),Vector3(-0.61,low+1.08,0.46)],glass)
	if kind==3:
		box(body,Vector3(0,low+1.25,0),Vector3(0.9,0.14,0.25),Color("293944"))
		box(body,Vector3(-0.27,low+1.34,0),Vector3(0.35,0.13,0.24),Color("2b7add"))
		box(body,Vector3(0.27,low+1.34,0),Vector3(0.35,0.13,0.24),Color("ed3c37"))
	for x in [-size.x/2,size.x/2]:
		for z in [-size.z*0.3,size.z*0.3]:
			var tire:=cylinder(body,Vector3(x,low+0.27,z),0.29,0.15,Color("171b1b"))
			tire.rotation.z=PI/2
			var hub:=cylinder(body,Vector3(x*1.04,low+0.27,z),0.17,0.17,Color("8e9695"))
			hub.rotation.z=PI/2
	for x in [-size.x*0.32,size.x*0.32]:
		box(body,Vector3(x,low+0.48,-size.z/2-0.02),Vector3(0.35,0.18,0.04),Color("ecebdc"))
		box(body,Vector3(x,low+0.48,size.z/2+0.02),Vector3(0.29,0.16,0.04),Color("9f1a18"))
	box(body,Vector3(0,low+0.32,-size.z/2-0.04),Vector3(size.x*0.9,0.10,0.06),Color("777e7a"))

func quad(parent:Node3D, vertices:Array, tint:Color) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,1,2,0,2,3]:st.add_vertex(vertices[i])
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=st.commit()
	var mat:=material(tint).duplicate()
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=mat
	parent.add_child(mesh)

func prism(parent:Node3D, outline:PackedVector2Array, width:float, y:float, tint:Color) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles:=Geometry2D.triangulate_polygon(outline)
	for side in [-1,1]:
		for index in triangles:
			var p:Vector2=outline[index]
			st.add_vertex(Vector3(side*width/2,p.y+y,p.x))
	for i in outline.size():
		var a:Vector2=outline[i]
		var b:Vector2=outline[(i+1)%outline.size()]
		for v in [Vector3(-width/2,a.y+y,a.x),Vector3(width/2,a.y+y,a.x),Vector3(width/2,b.y+y,b.x),Vector3(-width/2,a.y+y,a.x),Vector3(width/2,b.y+y,b.x),Vector3(-width/2,b.y+y,b.x)]:st.add_vertex(v)
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=st.commit()
	var mat:=material(tint).duplicate()
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=mat
	parent.add_child(mesh)

func cone(at: Vector2) -> void:
	var b:=_food(at,Vector3(0.37,0.62,0.37),"cone",1)
	box(b,Vector3(0,-0.26,0),Vector3(0.37,0.07,0.37),Color("c65121"))
	cylinder(b,Vector3(0,0.025,0),0.16,0.55,Color("eb781c"),0.02)
	cylinder(b,Vector3(0,0.015,0),0.10,0.14,Color("eee9d8"),0.07)

func bin_prop(at: Vector2) -> void:
	var b:=_food(at,Vector3(0.48,0.8,0.48),"bin",1)
	box(b,Vector3.ZERO,Vector3(0.48,0.77,0.48),Color("2d443b"))
	box(b,Vector3(0,0.4,0),Vector3(0.53,0.06,0.53),Color("26332d"))
	for i in [-0.14,0.0,0.14]:box(b,Vector3(i,0,0.245),Vector3(0.025,0.62,0.02),Color("192b23"))

func lamp(at: Vector2) -> void:
	var b:=_food(at,Vector3(0.75,3.4,0.4),"lamp",2)
	cylinder(b,Vector3(0,-0.1,0),0.048,3.15,Color("555850"))
	box(b,Vector3(0.22,1.48,0),Vector3(0.51,0.07,0.09),Color("585c57"))
	box(b,Vector3(0.39,1.40,0),Vector3(0.32,0.09,0.17),Color("e6e3ba"))

func person(at: Vector2, tone: int) -> void:
	var b:=_food(at,Vector3(0.39,1.38,0.39),"person",1)
	var shirts:=[Color("80392f"),Color("292c41"),Color("356c7d"),Color("af7755")]
	cylinder(b,Vector3(0,0.04,0),0.13,0.47,shirts[tone])
	sphere(b,Vector3(0,0.43,0),0.12,Color("d5a079"))
	for x in [-0.075,0.075]:
		box(b,Vector3(x,-0.39,0),Vector3(0.075,0.42,0.09),Color("262936"))
		box(b,Vector3(x*2.1,0.015,0),Vector3(0.06,0.42,0.07),shirts[tone])
	b.set_meta("origin",b.position)
	b.set_meta("walk",rng.randf_range(0,TAU))
	people.append(b)

func city_park(at: Vector2, extent: Vector2) -> void:
	box(self,Vector3(at.x,0.015,at.y),Vector3(extent.x,0.04,extent.y),Color("85b82e"))
	for x in [-extent.x/2,extent.x/2]:
		for i in int(extent.y/1.0):
			var z:float=-extent.y/2+i
			var f:=_food(at+Vector2(x,z),Vector3(0.11,0.8,1.0),"fence",1)
			box(f,Vector3.ZERO,Vector3(0.045,0.79,0.045),Color("233029"))
			for y in [-0.25,0.25]:box(f,Vector3(0,y,0.5),Vector3(0.04,0.045,1.0),Color("26362d"))
	for i in 7:
		var pos:=at+Vector2(rng.randf_range(-extent.x*0.35,extent.x*0.35),rng.randf_range(-extent.y*0.35,extent.y*0.35))
		var b:=_food(pos,Vector3(1.35,2.8,1.35),"tree",3)
		cylinder(b,Vector3(0,-0.56,0),0.09,1.45,Color("6d4b29"))
		sphere(b,Vector3(0,0.53,0),0.73,Color("598b27"),1.2)

func subway(at: Vector2) -> void:
	box(self,Vector3(at.x,0.035,at.y),Vector3(4,0.05,2.2),Color("1b2323"))
	for z in [-1.15,1.15]:
		for i in 9:
			var b:=_food(at+Vector2(-2.0+i*0.5,z),Vector3(0.14,0.75,0.14),"railing",1)
			cylinder(b,Vector3.ZERO,0.045,0.75,Color("656e68"))
			box(b,Vector3(0,0.34,0),Vector3(0.50,0.035,0.035),Color("b08b28"))
	for i in 5:box(self,Vector3(at.x-1.5+i*0.55,0.052,at.y),Vector3(0.5,0.035,2),Color("525b55").darkened(i*0.11))

func build_preview() -> void:
	preview=Node3D.new()
	add_child(preview)
	box(preview,Vector3(0,-0.5,0),Vector3(12,1,11),Color("835c31"))
	box(preview,Vector3(0,0,0),Vector3(12.2,0.28,11.2),Color("78ba37"))
	box(preview,Vector3(0,0.18,-0.4),Vector3(11.7,0.08,3.0),Color("666d6a"))
	box(preview,Vector3(-1.0,0.20,2.5),Vector3(2.2,0.06,5.7),Color("727673"))
	for x in [-4,-3,-2,-1,0,1,2,3,4]:box(preview,Vector3(x,0.25,-0.4),Vector3(0.55,0.03,0.055),Color("f1edde"))
	for i in 6:box(preview,Vector3(-1.85+i*0.33,0.26,1.02),Vector3(0.16,0.03,0.65),Color("e9e9dd"))
	var towers:=[Vector4(-4,3.0,-3.4,1.6),Vector4(-2.2,4.0,-3.8,1.35),Vector4(0,5.3,-3.6,1.6),Vector4(2.3,3.6,-3.5,1.5),Vector4(4.1,2.5,-3.2,1.7)]
	for t in towers:
		if t.x==0 or t.x>4.0:
			var tower:=cylinder(preview,Vector3(t.x,t.y+0.2,t.z),t.w*0.6,t.y*2,Color("a9c5d3"))
			var glass:=ShaderMaterial.new()
			glass.shader=Facade
			glass.set_shader_parameter("wall_color",Color("c4d9dd"))
			glass.set_shader_parameter("glass_tower",true)
			glass.set_shader_parameter("columns",30.0)
			glass.set_shader_parameter("floors",t.y*5)
			tower.material_override=glass
			cylinder(preview,Vector3(t.x,t.y*2+0.25,t.z),t.w*0.6+0.06,0.13,Color("e7ddd0"))
		else:
			facade(preview,Vector3(t.w,t.y*2,t.w*1.05),Vector3(t.x,t.y+0.2,t.z),Color("a9c5d3"),true)
			box(preview,Vector3(t.x,t.y*2+0.25,t.z),Vector3(t.w+0.13,0.13,t.w*1.05+0.13),Color("e7ddd0"))
	# Helipad and small original helicopter silhouette.
	cylinder(preview,Vector3(0,11.1,-3.6),1.18,0.20,Color("929f97"))
	cylinder(preview,Vector3(0,11.22,-3.6),0.89,0.05,Color("577561"))
	for x in [-0.3,0.3]:box(preview,Vector3(x,11.26,-3.6),Vector3(0.12,0.03,0.7),Color("e5e5d3"))
	box(preview,Vector3(0,11.26,-3.6),Vector3(0.6,0.03,0.12),Color("e5e5d3"))
	sphere(preview,Vector3(0,11.63,-3.6),0.38,Color("497866"),0.7)
	box(preview,Vector3(0,11.70,-3.0),Vector3(0.11,0.15,1.1),Color("4c7867"))
	box(preview,Vector3(0,12.04,-3.6),Vector3(2.2,0.035,0.085),Color("3d4841"))
	# Front garden, fountain and spherical trees reproduce the observed composition.
	box(preview,Vector3(2.35,0.24,3.0),Vector3(4.3,0.05,4.2),Color("c7c18c"))
	cylinder(preview,Vector3(2.35,0.31,3.0),0.98,0.17,Color("d8d5bd"))
	cylinder(preview,Vector3(2.35,0.42,3.0),0.78,0.09,Color("69d2e5"))
	cylinder(preview,Vector3(2.35,0.56,3.0),0.23,0.24,Color("d8dac6"))
	sphere(preview,Vector3(2.35,0.86,3.0),0.13,Color("d8dac6"))
	for x in [0.35,4.35,-4.7]:
		for z in [1.4,3.0,4.6]:
			cylinder(preview,Vector3(x,0.51,z),0.055,0.62,Color("806538"))
			sphere(preview,Vector3(x,1.03,z),0.38,Color("519f28"))
	for z in [1.4,4.5]:
		for x in [1.1,3.6]:box(preview,Vector3(x,0.4,z),Vector3(0.6,0.14,0.25),Color("71512e"))

func _process(delta: float) -> void:
	if is_instance_valid(preview):
		preview.rotation.y+=delta*0.10
		return
	if not is_instance_valid(game) or game.phase!="playing":return
	for b in people:
		if not is_instance_valid(b) or is_instance_valid(b.claimed_by):continue
		var origin:Vector3=b.get_meta("origin")
		var phase:float=b.get_meta("walk")+game.elapsed*0.36
		b.position=origin+Vector3(sin(phase)*1.1,0,0)
	for entry in fading:
		if not is_instance_valid(entry.body):continue
		var b:Node3D=entry.body
		var offset:Vector3=game.player.position-b.position
		var close:bool=absf(offset.x)<entry.half.x+2.0 and absf(offset.z)<entry.half.y+2.0
		entry.mat.set_shader_parameter("visibility",0.3 if close else 1.0)
