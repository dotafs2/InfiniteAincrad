extends Node3D
## A visual-only snack district. Shared game meshes keep the miniature's food
## colors and ingredient gloss consistent without a live city or physics world.
const FoodCity=preload("res://fidelity/food_city.gd")
const Surface=preload("res://fidelity/food_surface.gd")
const Glaze=preload("res://fidelity/food_glaze.gdshader")
const ROTATION_SPEED:=0.10
const SURFACE_Y:=.125
static var food_meshes:Dictionary={}
static var surface_meshes:Dictionary={}
static var glaze_material:ShaderMaterial
var preview:Node3D
var food_piece_count:=0
var layer_counts:Dictionary={}

func build_preview()->void:
	if is_instance_valid(preview):preview.free()
	preview=Node3D.new();preview.name="SnackDistrict";add_child(preview)
	food_piece_count=0;layer_counts={"foreground":0,"midground":0,"background":0}
	if glaze_material==null:
		glaze_material=ShaderMaterial.new();glaze_material.shader=Glaze
		glaze_material.set_shader_parameter("reveal_use_instance",false)
		glaze_material.set_shader_parameter("reveal_occluder",0.0)
	# mesh_for combines primitives using their global transforms, so its short-
	# lived builder must be inside the tree. Never call build(), food() or towers.
	var builder:=FoodCity.new();builder.name="TemporaryMeshBuilder"
	add_child(builder);builder.set_process(false);builder.set_physics_process(false)
	builder.rain_enabled=false
	base_and_streets()
	background(builder)
	midground(builder)
	foreground(builder)
	builder.free()

func _process(delta:float)->void:
	if is_instance_valid(preview):preview.rotation.y+=delta*ROTATION_SPEED

func food(builder:Node3D,kind:String,at:Vector2,bottom:float,size:float,angles:Vector3,layer:String,cluster:String,tower:=false,flavor:=0,tier:=0)->MeshInstance3D:
	var key:String=builder.mesh_key(kind,tower,flavor)
	if not food_meshes.has(key):food_meshes[key]=builder.mesh_for(kind,tower,flavor)
	var visual:=MeshInstance3D.new();visual.mesh=food_meshes[key]
	visual.material_override=glaze_material
	visual.name="%s_%s_%02d"%[cluster,kind,food_piece_count]
	visual.set_meta("food_kind",kind);visual.set_meta("preview_layer",layer)
	visual.set_meta("cluster",cluster);visual.set_meta("tier",tier)
	visual.set_meta("source_mesh_key",key)
	visual.transform=Transform3D(Basis.from_euler(angles).scaled(Vector3.ONE*size),Vector3(at.x,0,at.y))
	# Contact uses the transformed mesh bounds, including small authored tilts.
	var bounds:AABB=visual.transform*visual.mesh.get_aabb()
	visual.position.y=bottom-bounds.position.y
	preview.add_child(visual)
	food_piece_count+=1;layer_counts[layer]=int(layer_counts[layer])+1
	return visual

func top(visual:MeshInstance3D)->float:
	var bounds:AABB=visual.transform*visual.mesh.get_aabb()
	return bounds.end.y

func stack(builder:Node3D,kind:String,at:Vector2,sizes:Array,layer:String,cluster:String,tower:bool,flavor:int,tilt:float)->float:
	var bottom:=SURFACE_Y
	for tier in sizes.size():
		var offset:=Vector2.ZERO if tier==0 else Vector2(sin(tier*1.7)*.14,cos(tier*1.3)*.10)
		var angles:=Vector3(sin(tier*1.3)*tilt,-.12+tier*.13,cos(tier*1.6)*tilt)
		var piece:=food(builder,kind,at+offset,bottom,float(sizes[tier]),angles,layer,cluster,tower,flavor,tier)
		bottom=top(piece)-.035
	return bottom

func background(builder:Node3D)->void:
	# Three different rooflines, with a tapered pink landmark between lower
	# wafer apartments and a turquoise layer-cake side street.
	var height:=stack(builder,"cake",Vector2(-1.25,-3.3),[1.22,1.19,1.13,1.06,.98,.90,.81],"background","RoseCake",true,0,.018)
	var crown:=food(builder,"cake",Vector2(-1.20,-3.25),height,.64,Vector3(0,.24,0),"background","RoseCakeCrown",false,0,7)
	food(builder,"berry",Vector2(-1.17,-3.21),(crown.transform*Vector3(0,1.61,0)).y-.015,.28,Vector3(0,.1,.03),"background","RoseCakeCrown",false,0,8)
	height=stack(builder,"cake",Vector2(3.25,-3.0),[1.12,1.04,.96,.87],"background","BlueCake",true,1,.027)
	crown=food(builder,"cake",Vector2(3.35,-2.99),height,.62,Vector3(0,-.3,.025),"background","BlueCakeCrown",false,1,4)
	food(builder,"berry",Vector2(3.44,-2.98),(crown.transform*Vector3(0,1.61,0)).y-.015,.25,Vector3.ZERO,"background","BlueCakeCrown",false,0,5)
	height=stack(builder,"pancake",Vector2(-4.65,-2.65),[1.02,.95,.86],"background","WaferApartments",true,0,.035)
	crown=food(builder,"cookie",Vector2(-4.58,-2.64),height,.81,Vector3(.03,-.25,-.04),"background","WaferRoof",false,2,3)
	food(builder,"berry",Vector2(-4.52,-2.58),(crown.transform*Vector3(.07,.37,.06)).y-.015,.32,Vector3.ZERO,"background","WaferRoof",false,0,4)

func midground(builder:Node3D)->void:
	# Individual meals step sideways and turn slightly as they rise, so the
	# district reads as piled food instead of identical vertical extrusions.
	stack(builder,"pancake",Vector2(-4.05,-.20),[.79,.74,.69,.63,.56],"midground","BreakfastStack",false,0,.065)
	stack(builder,"burger",Vector2(-.05,-.05),[1.0,.89,.78],"midground","BurgerStack",false,0,.055)
	stack(builder,"donut",Vector2(4.30,-.05),[1.03,.94,.85,.75],"midground","DonutStack",false,2,.080)
	var shop:=food(builder,"cake",Vector2(2.05,-1.0),SURFACE_Y,.64,Vector3(0,-.18,0),"midground","CandyShop",true,4)
	food(builder,"cookie",Vector2(2.09,-1.03),top(shop)-.025,.49,Vector3(.04,.4,-.04),"midground","CandyShop",false,1,1)

func foreground(builder:Node3D)->void:
	var center:=Vector2(-.15,4.05)
	var cookie_supports:Array[MeshInstance3D]=[]
	var cookie_at:=[Vector2(-.8,-.18),Vector2(.05,-.43),Vector2(.85,-.15),Vector2(-.5,.5),Vector2(.5,.65)]
	for index in cookie_at.size():
		cookie_supports.append(food(builder,"cookie",center+cookie_at[index],SURFACE_Y,.49,Vector3(.02*index,index*.43,.035*float(index%2)),"foreground","CookieHeap",false,index%2))
	for index in 2:
		cookie_supports.append(food(builder,"cookie",center+Vector2(-.26+index*.54,.14),top(cookie_supports[3+index])-.025,.47,Vector3(-.08+index*.10,.4+index*.63,.07-index*.11),"foreground","CookieHeap",false,0,1))
	for index in [0,4,6]:
		var support:=cookie_supports[index]
		var at:=Vector2(support.position.x+.03,support.position.z+.02)
		var bottom:float=(support.transform*Vector3(.03,.33,.02)).y-.012
		food(builder,"berry",at,bottom,.28,Vector3(0,.4,.045),"foreground","CookieHeap",false,0,2)
	food(builder,"egg",Vector2(-5.2,3.9),SURFACE_Y,.67,Vector3(.025,.3,0),"foreground","BreakfastScatter")
	food(builder,"bacon",Vector2(-4.25,3.50),SURFACE_Y,.52,Vector3(0,.6,.035),"foreground","BreakfastScatter")
	food(builder,"bacon",Vector2(-4.00,4.55),SURFACE_Y,.48,Vector3(.035,-.6,.045),"foreground","BreakfastScatter")
	var breakfast:=food(builder,"pancake",Vector2(-4.65,4.6),SURFACE_Y,.51,Vector3(0,.2,.03),"foreground","BreakfastScatter")
	breakfast=food(builder,"pancake",Vector2(-4.53,4.60),top(breakfast)-.03,.43,Vector3(-.04,-.3,-.025),"foreground","BreakfastScatter",false,0,1)
	food(builder,"berry",Vector2(-4.48,4.61),top(breakfast)-.02,.24,Vector3.ZERO,"foreground","BreakfastScatter",false,0,2)
	food(builder,"pizza",Vector2(4.55,4.55),SURFACE_Y,.79,Vector3(.035,.1,-.025),"foreground","PicnicScatter")
	food(builder,"sushi",Vector2(3.55,3.60),SURFACE_Y,.43,Vector3(0,-.23,0),"foreground","PicnicScatter")
	food(builder,"sushi",Vector2(5.45,3.65),SURFACE_Y,.42,Vector3(0,.31,0),"foreground","PicnicScatter")
	food(builder,"cookie",Vector2(3.75,4.95),SURFACE_Y,.43,Vector3(.035,.3,.045),"foreground","PicnicScatter",false,0)
	food(builder,"cookie",Vector2(5.17,4.77),.48,.40,Vector3(-.08,-.3,.12),"foreground","PicnicScatter",false,3,1)
	food(builder,"donut",Vector2(5.73,4.98),SURFACE_Y,.37,Vector3(.09,.3,.06),"foreground","PicnicScatter",false,0)
	food(builder,"berry",Vector2(3.1,4.5),SURFACE_Y,.30,Vector3.ZERO,"foreground","PicnicScatter")
	food(builder,"berry",Vector2(5.85,4.18),SURFACE_Y,.29,Vector3.ZERO,"foreground","PicnicScatter")
	var loose:=[
		["berry",Vector2(-6.08,1.0),.39,0],["donut",Vector2(-6.0,-.7),.43,1],
		["cookie",Vector2(6.05,-.8),.47,0],["berry",Vector2(6.08,.60),.36,0],
		["cookie",Vector2(-2.6,3.55),.4,3],["egg",Vector2(2.45,3.40),.37,0],
		["bacon",Vector2(-2.42,-1.03),.34,0],["berry",Vector2(1.55,-4.73),.34,0],
		["cookie",Vector2(-5.95,-4.45),.42,1],["sushi",Vector2(5.79,-4.40),.37,0]]
	for index in loose.size():
		var item:Array=loose[index]
		food(builder,item[0],item[1],SURFACE_Y,item[2],Vector3(.025,index*.61,-.025),"foreground","StreetSnacks",false,item[3])

func surface(size:Vector3,tint:Color,at:Vector3,angle:=0.0)->MeshInstance3D:
	var key:="%s/%s"%[size,tint]
	if not surface_meshes.has(key):
		var source:=Surface.rounded_box(size)
		var arrays:Array=source.surface_get_arrays(0)
		var colors:=PackedColorArray();var encoded:=tint;encoded.a=Surface.roughness(tint)
		colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(encoded);arrays[Mesh.ARRAY_COLOR]=colors
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		surface_meshes[key]=mesh
	var visual:=MeshInstance3D.new();visual.mesh=surface_meshes[key];visual.material_override=glaze_material
	preview.add_child(visual);visual.position=at;visual.rotation.y=angle
	return visual

func base_and_streets()->void:
	# The district sits on a biscuit-and-cream slice. A bent chocolate avenue
	# separates low foreground meals from the stacked neighborhood behind it.
	surface(Vector3(13.7,.62,11.7),Color("cf802d"),Vector3(0,-.48,0)).name="BiscuitBase"
	surface(Vector3(13.85,.18,11.85),Color("fff3ce"),Vector3(0,-.14,0)).name="CreamFilling"
	surface(Vector3(14.0,.20,12.0),Color("ffc24d"),Vector3(0,.02,0)).name="BiscuitTop"
	street(Vector2(-6.35,1.90),Vector2(.15,2.42),1.22,5)
	street(Vector2(.15,2.42),Vector2(6.28,1.78),1.22,5)
	street(Vector2(.15,2.42),Vector2(.82,-1.67),.96,3)

func street(from:Vector2,to:Vector2,width:float,dashes:int)->void:
	var direction:=to-from;var center:=(from+to)*.5
	var angle:=-atan2(direction.y,direction.x)
	var road:=surface(Vector3(direction.length()+.12,.055,width),Color("78311b"),Vector3(center.x,.143,center.y),angle)
	road.name="ChocolateStreet";road.set_meta("preview_road",true)
	for index in dashes:
		var at:=from.lerp(to,(float(index)+.5)/float(dashes))
		var dash:=surface(Vector3(.35,.018,.075),Color("fff3ce"),Vector3(at.x,.180,at.y),angle)
		dash.name="CreamLaneMark"
