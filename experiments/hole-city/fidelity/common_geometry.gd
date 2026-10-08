extends RefCounted
## Twenty authored Common silhouettes. Each cached mesh has a small fixed set of
## material surfaces. All coordinates are cosmetic and leave the gameplay opening
## clear; construction never creates physics objects or per-frame geometry.
const Sculpt = preload("res://fidelity/skin_sculpt.gd")
const Surface = preload("res://fidelity/common_surface.gdshader")
const IDS:Array[String] = ["cookie_bite", "citrus_slice", "melon_munch", "pancake_stack", "bacon_curl", "cocoa_square", "paper_boat", "toy_tire", "leaf_cup", "wooden_tub", "rope_coil", "clay_pot", "shell_cup", "woven_nest", "paint_tin", "denim_pocket", "catchers_mitt", "enamel_basin", "acorn_cup", "knit_cap"]
static var _cache:Dictionary = {}

static func build(s:Node3D, parent:Node3D)->Dictionary:
	var id:String = str(s.get("model_id")) if s.get("model_id") != null else str(s.skin_id)
	if not _cache.has(id): _cache[id] = _make(id)
	var recipe:Dictionary = _cache[id]
	var root := Node3D.new()
	root.name = "CommonSculpt"
	parent.add_child(root)
	var model := MeshInstance3D.new()
	model.name = "CommonModel_" + id
	model.mesh = recipe.mesh
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.extra_cull_margin = .1
	model.set_meta("opening_radius", .985)
	model.set_meta("sculpted", true)
	model.set_meta("common_geometry_revision", 1)
	model.set_meta("authored_features", recipe.features)
	root.add_child(model)
	root.set_meta("common_skin_id", id)
	root.set_meta("cached_geometry", true)
	return {"main_ring": model, "animated_root": root, "theme": {"id": id, "features": recipe.features, "surface_count": model.mesh.get_surface_count(), "opening_radius": .985}}

static func _material(hex:String, rough:=.48, pattern:=0, grain:=.08, metal:=0.0)->ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Surface
	mat.set_shader_parameter("base_color", Color(hex))
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("grain", grain)
	mat.set_shader_parameter("metallic", metal)
	return mat

static func _bucket(materials:Array)->Dictionary:
	var surfaces:Array[SurfaceTool] = []
	for mat in materials:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		surfaces.append(st)
	return {"surfaces": surfaces, "used": {}, "features": PackedStringArray()}

static func _add(b:Dictionary, slot:int, mesh:Mesh, at:=Vector3.ZERO, scale:=Vector3.ONE, rot:=Vector3.ZERO)->void:
	var basis := Basis.from_euler(rot).scaled(scale)
	var st:SurfaceTool = b.surfaces[slot]
	st.append_from(mesh, 0, Transform3D(basis, at))
	b.used[slot] = true

static func _feature(b:Dictionary, label:String)->void:
	b.features.append(label)

static func _finish(b:Dictionary)->Dictionary:
	var mesh := ArrayMesh.new()
	for i in b.surfaces.size():
		if not b.used.has(i): continue
		var st:SurfaceTool = b.surfaces[i]
		st.index()
		st.commit(mesh)
	return {"mesh": mesh, "features": b.features}

static func _at(angle:float, radius:float, y:float)->Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)

static func _profile_point(q:Vector2, angle:float, options:Dictionary)->Vector3:
	# Ground the inner wall directly on the circular gameplay opening. Raised
	# outer bevels, polygon corners and wave crests must never expose the street.
	if options.get("floor",false) and is_equal_approx(q.y,.005):
		return _at(angle,1.009,.005)
	var radius := q.x
	var y := q.y
	var freq:float = options.get("frequency", 7.0)
	var phase:float = options.get("phase", 0.0)
	var edge := clampf((radius - 1.0) / .35, 0.0, 1.0)
	radius += float(options.get("radial_wave", 0.0)) * sin(angle * freq + phase) * edge
	var notch:float = options.get("notch", 0.0)
	if notch > 0.0:
		var distance := absf(wrapf(angle - .9, -PI, PI))
		var bite := maxf(0.0, 1.0 - distance / .31)
		radius -= notch * pow(bite, .65) * edge
	y += float(options.get("wave", 0.0)) * (1.0 + sin(angle * freq + phase))
	y += float(options.get("back_lift", 0.0)) * (1.0 - cos(angle)) * .5
	var oval:Vector2 = options.get("oval", Vector2.ONE)
	var polygon:int = options.get("polygon",0)
	if polygon > 2:
		var step := TAU/float(polygon)
		var side_angle := wrapf(angle-float(options.get("start",0.0)),0.0,step)-step*.5
		radius *= cos(step*.5)/cos(side_angle)
	return Vector3(sin(angle) * radius * oval.x, y, cos(angle) * radius * oval.y)

static func _ring(profile:Array[Vector2], segments:=64, options:Dictionary={})->ArrayMesh:
	if options.get("floor",false):
		profile = profile.duplicate()
		profile[0] = Vector2(1.009,.005)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start:float = options.get("start", 0.0)
	var length:float = options.get("length", TAU)
	for i in segments:
		for j in profile.size():
			var points:Array[Vector3] = []
			var normals:Array[Vector3] = []
			for ij in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,(j+1)%profile.size()), Vector2i(i,(j+1)%profile.size())]:
				var angle := start + length * float(ij.x) / segments
				var q:Vector2 = profile[ij.y]
				var prev:Vector2 = profile[(ij.y-1+profile.size())%profile.size()]
				var next:Vector2 = profile[(ij.y+1)%profile.size()]
				var tangent:Vector2 = (q-prev).normalized() + (next-q).normalized()
				var normal := Vector2(tangent.y, -tangent.x).normalized()
				var circum := (_profile_point(q,angle+.001,options) - _profile_point(q,angle-.001,options)).normalized()
				var radial := Vector3(sin(angle),0,cos(angle))
				var n := radial * normal.x + Vector3.UP * normal.y
				n = (n - circum * n.dot(circum)).normalized()
				points.append(_profile_point(q,angle,options))
				normals.append(n)
			Sculpt.triangle(st,points[0],points[1],points[2],normals[0],normals[1],normals[2])
			Sculpt.triangle(st,points[0],points[2],points[3],normals[0],normals[2],normals[3])
	if length < TAU - .001:
		var indices := Geometry2D.triangulate_polygon(PackedVector2Array(profile))
		for endpoint in [0,1]:
			var angle:float = start + length * endpoint
			var n := Vector3(cos(angle),0,-sin(angle)) * (-1.0 if endpoint == 0 else 1.0)
			for i in range(0,indices.size(),3):
				Sculpt.triangle(st,_profile_point(profile[indices[i]],angle,options),_profile_point(profile[indices[i+1]],angle,options),_profile_point(profile[indices[i+2]],angle,options),n,n,n)
	return st.commit()

static func _rounded(inner:float, outer:float, bottom:float, top:float, bevel:=.035)->Array[Vector2]:
	var e := minf(bevel, minf((outer-inner)*.25, (top-bottom)*.3))
	return [Vector2(inner,bottom+e),Vector2(inner+e,bottom),Vector2(outer-e,bottom),Vector2(outer,bottom+e),Vector2(outer,top-e),Vector2(outer-e,top),Vector2(inner+e,top),Vector2(inner,top-e)]

static func _arc(b:Dictionary, slot:int, inner:float, outer:float, bottom:float, top:float, start:float, length:float, options:Dictionary={})->void:
	options = options.duplicate()
	options.start = start
	options.length = length
	_add(b,slot,_ring(_rounded(inner,outer,bottom,top), maxi(5, int(ceil(length*12))),options))

static func _tube(path:Array[Vector3], radius:float, sides:=7, closed:=false)->ArrayMesh:
	if not closed and path[0].distance_to(path[-1]) < .0001:
		path = path.duplicate()
		path.remove_at(path.size()-1)
		closed = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := path.size() if closed else path.size()-1
	for i in steps:
		var points:Array[Vector3] = []
		var normals:Array[Vector3] = []
		for j in sides:
			points.clear(); normals.clear()
			for ij in [Vector2i(i,j),Vector2i((i+1)%path.size(),j),Vector2i((i+1)%path.size(),j+1),Vector2i(i,j+1)]:
				var k:int = ij.x
				var before:int = (k-1+path.size())%path.size() if closed else maxi(0,k-1)
				var after:int = (k+1)%path.size() if closed else mini(path.size()-1,k+1)
				var direction:Vector3 = (path[after]-path[before]).normalized()
				var cross_axis := Vector3.UP if absf(direction.y) < .95 else Vector3.RIGHT
				var axis := direction.cross(cross_axis).normalized()
				var second := direction.cross(axis).normalized()
				var angle := TAU * float(ij.y) / sides
				var n := axis*cos(angle)+second*sin(angle)
				points.append(path[k]+n*radius); normals.append(n)
			Sculpt.triangle(st,points[0],points[1],points[2],normals[0],normals[1],normals[2])
			Sculpt.triangle(st,points[0],points[2],points[3],normals[0],normals[2],normals[3])
	if not closed:
		for k in [0,path.size()-1]:
			# Use the side wall's forward frame at both ends. Reversing the frame
			# at the start reflects odd-sided rings into a different vertex set,
			# leaving real sliver holes between their wall and cap.
			var forward:Vector3 = (path[1]-path[0]).normalized() if k == 0 else (path[k]-path[k-1]).normalized()
			var direction := -forward if k == 0 else forward
			var cross_axis := Vector3.UP if absf(forward.y) < .95 else Vector3.RIGHT
			var axis := forward.cross(cross_axis).normalized()
			var second := forward.cross(axis).normalized()
			for j in sides:
				var a := TAU*float(j)/sides
				var c := TAU*float(j+1)/sides
				Sculpt.triangle(st,path[k],path[k]+(axis*cos(a)+second*sin(a))*radius,path[k]+(axis*cos(c)+second*sin(c))*radius,direction,direction,direction)
	return st.commit()

static func _path_arc(radius:float, y:float, start:=0.0, length:=TAU, count:=48)->Array[Vector3]:
	var path:Array[Vector3] = []
	for i in count+1: path.append(_at(start+length*float(i)/count,radius,y))
	return path

static func _soft(b:Dictionary, slot:int, at:Vector3, size:Vector3, rotation:=Vector3.ZERO)->void:
	_add(b,slot,Sculpt.cushion_mesh(),at,size,rotation)

static func _patch(b:Dictionary, slot:int, points:Array[Vector2], depth:float, at:Vector3, rot:=Vector3.ZERO)->void:
	_add(b,slot,Sculpt.bevel(points,depth),at,Vector3.ONE,Vector3(PI/2,0,0)+rot)

static func _make(id:String)->Dictionary:
	match id:
		"cookie_bite": return _cookie()
		"citrus_slice": return _citrus()
		"melon_munch": return _melon()
		"pancake_stack": return _pancake()
		"bacon_curl": return _bacon()
		"cocoa_square": return _slate()
		"paper_boat": return _boat()
		"toy_tire": return _tire()
		"leaf_cup": return _leaf()
		"wooden_tub": return _tub()
		"rope_coil": return _rope()
		"clay_pot": return _pot()
		"shell_cup": return _shell()
		"woven_nest": return _nest()
		"paint_tin": return _tin()
		"denim_pocket": return _denim()
		"catchers_mitt": return _mitt()
		"enamel_basin": return _basin()
		"acorn_cup": return _acorn()
		"knit_cap": return _knit()
	assert(false,"Unknown Common skin: "+id)
	return {}

static func _cookie()->Dictionary:
	var b := _bucket([_material("cb813b",.53,1,.20),_material("e5b465",.66,1,.22),_material("633b2d",.31,1,.12),_material("f2d19a",.72,1,.14)])
	var options := {"notch": .30, "radial_wave": .014, "frequency": 9.0, "floor":true}
	_add(b,0,_ring(_rounded(1.01,1.41,.045,.33,.06),72,options))
	options.floor = false
	_add(b,1,_ring(_rounded(1.045,1.406,.105,.255,.025),72,options))
	for i in 7:
		var angle := float(i)*TAU/7.0+.30
		if absf(wrapf(angle-.9,-PI,PI)) < .45: continue
		var points:Array[Vector2] = [Vector2(-.11,-.10),Vector2(.075,-.12),Vector2(.13,-.035),Vector2(.09,.09),Vector2(-.085,.12),Vector2(-.14,.01)]
		_patch(b,2,points,.115,_at(angle,1.225,.35),Vector3(.08,angle+.2,.10))
	for i in 8:
		var angle := float(i)*2.39996
		if absf(wrapf(angle-.9,-PI,PI)) < .4: continue
		_soft(b,3,_at(angle,1.10+float(i%3)*.105,.329),Vector3(.025,.018,.035))
	_feature(b,"Thick baked biscuit with a large carved bite notch")
	_feature(b,"Embedded beveled chocolate chunks and broad crumb layer")
	return _finish(b)

static func _citrus()->Dictionary:
	var b := _bucket([_material("df6d09",.48,1,.16),_material("e5d4a2",.57,1,.06),_material("e78a0e",.40,1,.10),_material("f2ae22",.42,1,.08),_material("496c24",.56,0,.1)])
	_add(b,0,_ring(_rounded(1.06,1.41,.04,.31,.055),48,{"radial_wave":.014,"frequency":10.0}))
	_add(b,1,_ring(_rounded(1.009,1.365,.08,.34,.035),32,{"floor":true}))
	for i in 10:
		var a := float(i)*TAU/10.0+.028
		_arc(b,2+i%2,1.035,1.317,.305,.366,a,TAU/10.0-.056)
		for j in 2:
			var angle := a+.12+float(j)*.20
			_add(b,3,_tube([_at(angle,1.085,.370),_at(angle+.025,1.20,.384),_at(angle+.018,1.28,.368)],.013,5))
	_add(b,4,_tube([Vector3(-.71,.30,-1.02),Vector3(-.75,.40,-1.09),Vector3(-.74,.50,-1.11)],.056,8))
	_patch(b,4,[Vector2(-.18,0),Vector2(-.03,-.09),Vector2(.19,.025),Vector2(.045,.10)],.035,Vector3(-.96,.37,-.87),Vector3(0,.4,0))
	_feature(b,"Ten separated flesh wedges with thick cream pith and rounded peel")
	_feature(b,"Low stem and one folded leaf")
	return _finish(b)

static func _melon()->Dictionary:
	var b := _bucket([_material("3d9754",.38,6,.31),_material("b7d674",.48,1,.1),_material("f7ebbf",.45,1,.05),_material("f85360",.30,1,.12),_material("30242f",.22,0,.05)])
	_add(b,0,_ring(_rounded(1.16,1.42,.045,.285,.06),40,{"radial_wave":.018,"frequency":8.0}))
	_add(b,1,_ring(_rounded(1.14,1.36,.11,.315,.035),40))
	_add(b,2,_ring(_rounded(1.12,1.305,.15,.330,.03),40))
	_add(b,3,_ring(_rounded(1.009,1.256,.04,.348,.035),48,{"floor":true}))
	for i in 7:
		var angle := float(i)*TAU/7+.13
		_patch(b,4,[Vector2(0,-.102),Vector2(.043,-.038),Vector2(.048,.035),Vector2(.02,.065),Vector2(-.029,.057),Vector2(-.049,.01),Vector2(-.03,-.053)],.045,_at(angle,1.13,.368),Vector3(0,angle,0))
	_feature(b,"Layered green rind, pale pith, red cut flesh and seven raised black seeds")
	return _finish(b)

static func _pancake()->Dictionary:
	var b := _bucket([_material("e9b565",.62,1,.19),_material("c78332",.46,1,.30),_material("b45b16",.18,0,.1),_material("ffe489",.24,0,.04)])
	for i in 3:
		var y := .045+float(i)*.125
		var outer := 1.38-float(i)*.013
		var opts := {"radial_wave":.018,"frequency":7.0,"phase":float(i)*.7,"floor":i==0}
		var offset := Vector3(.013 if i==1 else -.01,0,.01 if i==2 else 0)
		if i==0: offset = Vector3.ZERO
		_add(b,0,_ring(_rounded(1.035,outer,y,y+.12,.04),40,opts),offset)
		# The toasted cap is a shallow broad surface, not another deep pancake.
		opts.floor = false
		_add(b,1,_ring([Vector2(1.055,y+.099),Vector2(outer-.055,y+.099),Vector2(outer-.045,y+.122),Vector2(1.062,y+.127)],32,opts),offset)
	for a in [.15,3.30]:
		_patch(b,2,[Vector2(-.13,-.10),Vector2(-.02,-.14),Vector2(.11,-.12),Vector2(.145,-.025),Vector2(.085,.075),Vector2(.025,.16),Vector2(-.065,.12),Vector2(-.12,.02)],.006,_at(a,1.23,.421),Vector3(0,a,0))
	for a in [.15,3.30,4.1]:
		_add(b,2,_tube([_at(a,1.29,.406),_at(a,1.36,.387),_at(a,1.385,.30),_at(a,1.387,.19)],.025,8))
	_patch(b,3,[Vector2(-.145,-.12),Vector2(.14,-.12),Vector2(.15,.11),Vector2(-.14,.12)],.12,_at(.43,1.22,.498),Vector3(0,.3,0))
	_feature(b,"Three offset rounded pancakes with toasted tops")
	_feature(b,"One butter slab, maple pools and three solid syrup drips")
	return _finish(b)

static func _bacon()->Dictionary:
	var b := _bucket([_material("b95741",.33,1,.20),_material("f5c999",.32,1,.10),_material("8d3e27",.41,1,.15),_material("dc795b",.29,1,.1)])
	var opts := {"wave":.079,"radial_wave":.025,"frequency":8.0,"floor":true}
	_add(b,0,_ring(_rounded(1.035,1.40,.045,.11,.025),48,opts))
	opts.floor = false
	_add(b,1,_ring([Vector2(1.08,.106),Vector2(1.155,.106),Vector2(1.151,.123),Vector2(1.084,.123)],56,opts))
	_add(b,1,_ring([Vector2(1.268,.106),Vector2(1.332,.106),Vector2(1.328,.129),Vector2(1.272,.129)],56,opts))
	_add(b,3,_ring([Vector2(1.179,.109),Vector2(1.238,.109),Vector2(1.234,.133),Vector2(1.183,.133)],56,opts))
	for r in [1.036,1.40]:
		var path:Array[Vector3] = []
		for i in 49:
			var a := TAU*float(i)/48
			path.append(_profile_point(Vector2(r,.099),a,opts))
		_add(b,2,_tube(path,.021,5))
	_feature(b,"One continuous irregular curled strip with raised fat bands and crisp edges")
	return _finish(b)

static func _slate()->Dictionary:
	var b := _bucket([_material("667486",.60,3,.12),_material("7c8792",.60,3,.12),_material("525f70",.62,3,.12),_material("b7c0c4",.66,0,.04)])
	var angles:Array[float] = [0.0,.83,1.76,2.50,3.46,4.34,5.29,TAU]
	for i in 7:
		var a:float = angles[i]+.018
		var span:float = angles[i+1]-angles[i]-.036
		var top := .30+float(i%3)*.018
		_arc(b,i%3,1.015,1.385+float(i%2)*.022,.045,top,a,span,{"floor":true})
		var p:Array[Vector3] = [_at(a+.14,1.36,top+.002),_at(a+.21,1.24,top+.002),_at(a+.26,1.13,top+.002)]
		_add(b,3,_tube(p,.005,4))
	_feature(b,"Seven individual beveled slate slabs with asymmetric joins and mineral veins")
	return _finish(b)

static func _boat()->Dictionary:
	var b := _bucket([_material("f2e8cf",.76,1,.08),_material("28435e",.67,1,.07),_material("d9cdb3",.78,0,.03)])
	# The octagonal side folds remain outside the circular gameplay opening.
	_add(b,0,_ring(_rounded(1.095,1.36,.05,.33,.025),48,{"polygon":8,"floor":true}))
	_add(b,1,_ring(_rounded(1.345,1.365,.135,.215,.007),8))
	for sign in [-1.0,1.0]:
		var z:float = 1.0*sign
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tip := Vector3(0,.69,1.62*z)
		var left := Vector3(-.47,.31,1.12*z)
		var right := Vector3(.47,.31,1.12*z)
		var front := Vector3(0,.055,1.60*z)
		var center := (left+right+tip+front)*.25
		for triangle in [[left,tip,front],[front,tip,right],[left,right,tip],[left,front,right]]:
			var a:Vector3 = triangle[0]
			var c:Vector3 = triangle[1]
			var d:Vector3 = triangle[2]
			var normal := (c-a).cross(d-a).normalized()
			if normal.dot((a+c+d)/3.0-center)<0.0: normal = -normal
			Sculpt.triangle(st,a,c,d,normal,normal,normal)
		_add(b,0,st.commit())
		_add(b,2,_tube([left,tip,right],.014,5))
		_add(b,2,_tube([front,tip],.014,5))
		for side in [-1.0,1.0]:
			_add(b,1,_tube([Vector3(side*.39,.18,1.22*z),Vector3(side*.20,.23,1.43*z),Vector3(0,.25,1.605*z)],.022,5))
	_feature(b,"Folded eight-panel paper hull with high pointed bow and stern")
	_feature(b,"Navy printed side stripe and raised fold seams")
	return _finish(b)

static func _tire()->Dictionary:
	var b := _bucket([_material("30333b",.68,1,.09),_material("494d54",.61,1,.08),_material("eee6cb",.63,0,.04)])
	_add(b,0,_ring([Vector2(1.011,.11),Vector2(1.05,.047),Vector2(1.28,.045),Vector2(1.39,.12),Vector2(1.405,.24),Vector2(1.35,.345),Vector2(1.23,.38),Vector2(1.08,.362),Vector2(1.015,.29)],48,{"floor":true}))
	_add(b,2,_ring(_rounded(1.075,1.255,.356,.381,.012),40))
	for i in 24:
		var a := TAU*float(i)/24+.027
		_add(b,1,_ring([Vector2(1.285,.16),Vector2(1.427,.135),Vector2(1.449,.16),Vector2(1.449,.315),Vector2(1.427,.34),Vector2(1.285,.315)],5,{"start":a,"length":.205,"wave":.006,"frequency":1.0,"phase":float(i)}))
	_feature(b,"Thick rubber carcass, cream sidewall and twenty-four deep tread blocks")
	return _finish(b)

static func _leaf()->Dictionary:
	var b := _bucket([_material("68a440",.46,1,.08),_material("94bc49",.44,1,.08),_material("d8df70",.50,0,.04)])
	var opts := {"radial_wave":.050,"frequency":3.0,"wave":.020,"back_lift":.09,"floor":true}
	var profile:Array[Vector2] = [Vector2(1.02,.065),Vector2(1.23,.047),Vector2(1.38,.13),Vector2(1.39,.25),Vector2(1.33,.38),Vector2(1.23,.40),Vector2(1.27,.32),Vector2(1.32,.245),Vector2(1.23,.19),Vector2(1.02,.16)]
	_add(b,0,_ring(profile,80,opts))
	opts.floor = false
	var main_vein:Array[Vector3] = []
	for i in 65:
		var a := TAU*float(i)/64
		main_vein.append(_profile_point(Vector2(1.165,.204),a,opts))
	_add(b,2,_tube(main_vein,.020,6))
	for i in 12:
		var a := float(i)*TAU/12+.15
		var branch:Array[Vector3] = [_profile_point(Vector2(1.175,.21),a,opts),_profile_point(Vector2(1.28,.235),a+.13,opts),_profile_point(Vector2(1.345,.322),a+.24,opts),_profile_point(Vector2(1.287,.400),a+.30,opts)]
		_add(b,2,_tube(branch,.012,5))
	var stem:Array[Vector3] = [Vector3(.60,.20,-1.01),Vector3(.73,.29,-1.11),Vector3(.78,.44,-1.20),Vector3(.76,.585,-1.22)]
	_add(b,1,_tube(stem,.062,8))
	_patch(b,0,[Vector2(-.22,-.15),Vector2(-.08,-.24),Vector2(.14,-.15),Vector2(.20,-.01),Vector2(.07,.28),Vector2(-.07,.20),Vector2(-.21,.04)],.06,_at(.72,1.35,.36),Vector3(.22,.72,0))
	_add(b,2,_tube([_at(.72,1.17,.40),_at(.72,1.34,.414),_at(.72,1.56,.32)],.019,6))
	_feature(b,"Single asymmetric curled leaf with broad raised veins and an upright stem")
	return _finish(b)

static func _tub()->Dictionary:
	var b := _bucket([_material("bb803d",.65,2,.20),_material("d49b50",.61,2,.20),_material("664832",.60,7,.10,.15),_material("957455",.52,7,.08,.2)])
	for i in 16:
		var a := TAU*float(i)/16+.01
		var top := .45 + .028*sin(float(i)*2.4)
		_arc(b,i%2,1.025,1.325,.044,top,a,TAU/16-.02,{"floor":true})
	var rivet := Sculpt.lathe([Vector2(0,-1),Vector2(.59,-.81),Vector2(.95,-.31),Vector2(.95,.31),Vector2(.59,.81),Vector2(0,1)],8)
	for y in [.112,.303]:
		_add(b,2,_ring(_rounded(1.321,1.36,y,y+.070,.012),32))
		for i in 6:
			var a := float(i)*TAU/6+.19
			_add(b,3,rivet,_at(a,1.364,y+.035),Vector3(.027,.027,.014),Vector3(0,a,0))
	_feature(b,"Sixteen upright honey-wood staves with uneven tops")
	_feature(b,"Two dark metal bands and twelve rivets")
	return _finish(b)

static func _rope()->Dictionary:
	var b := _bucket([_material("c39b67",.82,4,.16),_material("dec092",.81,4,.15),_material("a0784c",.80,4,.15)])
	_add(b,2,_ring([Vector2(1.009,.005),Vector2(1.20,.035),Vector2(1.22,.32),Vector2(1.11,.37)],36,{"floor":true}))
	# Six large helical strands make the two coils; textile grain is shaded.
	for layer in 2:
		for strand in 3:
			var path:Array[Vector3] = []
			for i in 41:
				var a := TAU*float(i)/40
				var twist := a*8.0+TAU*float(strand)/3.0+float(layer)*.6
				path.append(_at(a,1.205+.070*cos(twist),.180+float(layer)*.185+.065*sin(twist)))
			_add(b,strand%2,_tube(path,.086,5))
	for strand in 2:
		var knot:Array[Vector3] = []
		for i in 13:
			var a := TAU*float(i)/12
			knot.append(Vector3(.15*cos(a)+float(strand)*.07-.03,.29+.155*sin(a),1.30+.065*sin(a*2.0+float(strand))))
		_add(b,strand,_tube(knot,.067,5))
	_add(b,1,_tube([Vector3(-.03,.20,1.31),Vector3(-.20,.15,1.44),Vector3(-.34,.14,1.59)],.080,8))
	_add(b,2,_tube([Vector3(.18,.22,1.32),Vector3(.29,.16,1.41),Vector3(.42,.12,1.43)],.060,7))
	_feature(b,"Two thick three-strand twisted rope coils with a front knot and loose ends")
	return _finish(b)

static func _pot()->Dictionary:
	var b := _bucket([_material("bb674b",.72,1,.16),_material("e5c397",.54,1,.12),_material("dca479",.73,1,.11)])
	_add(b,0,_ring([Vector2(1.025,.065),Vector2(1.23,.046),Vector2(1.365,.115),Vector2(1.397,.24),Vector2(1.33,.365),Vector2(1.25,.405),Vector2(1.12,.405),Vector2(1.035,.36)],56,{"floor":true}))
	_add(b,1,_ring([Vector2(1.018,.348),Vector2(1.065,.32),Vector2(1.245,.353),Vector2(1.295,.403),Vector2(1.27,.454),Vector2(1.21,.477),Vector2(1.05,.46),Vector2(1.009,.418)],64,{"wave":.013,"frequency":3.0}))
	_add(b,2,_ring(_rounded(1.386,1.401,.216,.237,.006),48,{"wave":.018,"frequency":6.0}))
	for sign in [-1.0,1.0]:
		var handle:Array[Vector3] = []
		for i in 17:
			var a := -PI*.5+PI*float(i)/16
			handle.append(Vector3(sign*(1.30+.26*cos(a)),.31+.14*sin(a),0))
		_add(b,0,_tube(handle,.064,8))
	_feature(b,"Bulging terracotta body, asymmetric rolled sand lip and two open ear handles")
	return _finish(b)

static func _shell()->Dictionary:
	var b := _bucket([_material("e8a592",.36,1,.10),_material("f6d7b9",.30,1,.06),_material("ca8275",.44,1,.08)])
	var opts := {"radial_wave":.033,"frequency":13.0,"back_lift":.12,"floor":true}
	_add(b,0,_ring([Vector2(1.015,.055),Vector2(1.26,.05),Vector2(1.40,.115),Vector2(1.42,.18),Vector2(1.36,.245),Vector2(1.21,.29),Vector2(1.05,.255),Vector2(1.013,.19)],78,opts))
	opts.floor = false
	for i in 13:
		var a := float(i)*TAU/13+PI/26
		var rib:Array[Vector3] = []
		for q in [Vector2(1.027,.23),Vector2(1.10,.269),Vector2(1.22,.298),Vector2(1.33,.264),Vector2(1.414,.183)]:
			rib.append(_profile_point(q,a,opts))
		_add(b,1,_tube(rib,.027,7))
	_add(b,2,_ring(_rounded(1.018,1.044,.185,.23,.011),64,opts))
	_feature(b,"Broad scalloped shell lip with thirteen raised radial ivory ribs")
	return _finish(b)

static func _nest()->Dictionary:
	var b := _bucket([_material("614026",.87,2,.13),_material("865a30",.86,2,.13),_material("c99546",.85,4,.13),_material("a97b39",.85,4,.13)])
	_add(b,3,_ring([Vector2(1.009,.005),Vector2(1.22,.025),Vector2(1.27,.19),Vector2(1.17,.27),Vector2(1.045,.23)],32,{"floor":true}))
	for layer in 3:
		for i in 11:
			var a := float(i)*TAU/11+float(layer)*.22
			var y := .092+float(layer)*.093
			var alternate := 1.0 if (i+layer)%2==0 else -1.0
			var twig:Array[Vector3] = [_at(a-.28,1.27-alternate*.10,y),_at(a,1.31,y+.039),_at(a+.29,1.27+alternate*.10,y+.014)]
			_add(b,(i+layer)%2,_tube(twig,.055 if layer<2 else .047,6))
	for i in 12:
		var a := float(i)*TAU/12
		for strand in 2:
			var offset := float(strand)*.028
			_add(b,2+strand,_tube([_at(a-.23,1.08+offset,.254),_at(a+.03,1.24+offset,.347),_at(a+.24,1.37+offset,.29)],.029 if strand==0 else .023,5))
	_feature(b,"Three crossed layers of chunky twigs with a soft straw-lined inner lip")
	return _finish(b)

static func _tin()->Dictionary:
	var b := _bucket([_material("369eaa",.27,7,.08,.25),_material("bec8c9",.30,7,.1,.66),_material("f0e6ce",.71,1,.04),_material("217383",.30,0,.04),_material("48545c",.43,7,.06,.5)])
	_add(b,0,_ring(_rounded(1.025,1.285,.05,.43,.025),48,{"floor":true}))
	_add(b,1,_ring(_rounded(1.010,1.31,.405,.457,.021),48))
	_add(b,1,_ring(_rounded(1.265,1.31,.048,.099,.018),48))
	_add(b,2,Sculpt.bevel([Vector2(-.38,-.09),Vector2(.36,-.09),Vector2(.39,.075),Vector2(-.36,.10)],.018),Vector3(0,.259,1.284))
	for i in 3:
		var a := -.24+float(i)*.19
		var y := .25-float(i%2)*.11
		_add(b,3,_tube([_at(a,1.24,.455),_at(a,1.312,.426),_at(a,1.308,y)],.024+float(i%2)*.006,7))
	var handle:Array[Vector3] = []
	for i in 33:
		var a := PI*.47+PI*1.06*float(i)/32
		handle.append(_at(a,1.34+.03*sin(float(i)/32*PI),.28+.28*sin(float(i)/32*PI)))
	_add(b,4,_tube(handle,.025,7))
	for sign in [-1.0,1.0]:
		_soft(b,1,Vector3(sign*1.293,.279,0),Vector3(.031,.05,.05))
	_feature(b,"Turquoise metal tin with rolled lips, cream label and solid dried paint drips")
	_feature(b,"Bent low metal handle follows the outside back of the opening")
	return _finish(b)

static func _denim()->Dictionary:
	var b := _bucket([_material("315979",.90,4,.15),_material("193750",.91,4,.14),_material("cfb58c",.87,4,.08),_material("688395",.86,4,.1)])
	# A pentagonal padded pocket, with the inner edge circumscribed around r=1.
	_add(b,0,_ring(_rounded(1.245,1.50,.035,.315,.065),50,{"start":PI,"polygon":5,"floor":true}))
	_add(b,1,_ring(_rounded(1.238,1.31,.225,.321,.029),50,{"start":PI,"polygon":5}))
	var seam:Array[Vector3] = []
	for i in 6: seam.append(_at(PI+TAU*float(i)/5,1.426,.326))
	_add(b,2,_tube(seam,.011,5))
	for i in 5:
		var a := PI+TAU*float(i)/5
		var from := _at(a,1.431,.330)
		var to := _at(a+TAU/5,1.431,.330)
		for j in 5:
			var p:Vector3 = from.lerp(to,(float(j)+.25)/5)
			var q:Vector3 = from.lerp(to,(float(j)+.63)/5)
			_add(b,2,_tube([p,q],.009,4))
	var flap_angle := PI+PI/5.0
	_patch(b,1,[Vector2(-.33,-.07),Vector2(.33,-.07),Vector2(.34,.075),Vector2(-.34,.075)],.10,_at(flap_angle,1.14,.328),Vector3(0,flap_angle,0))
	for corner in [1,4]:
		var a:float = PI+TAU*float(corner)/5
		for i in 3:
			_add(b,3,_tube([_at(a+float(i)*.015,1.48,.20),_at(a+float(i)*.022,1.57,.17+float(i)*.012)],.009,4))
	_feature(b,"Raised pentagonal denim pocket with folded mouth and double cream stitching")
	_feature(b,"Two restrained frayed corners")
	return _finish(b)

static func _mitt()->Dictionary:
	var b := _bucket([_material("82421f",.64,1,.13),_material("a65d2d",.60,1,.12),_material("45271c",.78,1,.1),_material("cdb186",.81,4,.08)])
	_add(b,0,_ring([Vector2(1.009,.005),Vector2(1.27,.026),Vector2(1.39,.11),Vector2(1.36,.245),Vector2(1.24,.293),Vector2(1.02,.245)],48,{"floor":true}))
	_arc(b,0,1.035,1.465,.145,.353,2.42,1.46)
	var finger_outline:Array[Vector2] = [Vector2(-.17,-.23),Vector2(-.12,-.32),Vector2(.12,-.32),Vector2(.17,-.23),Vector2(.17,.22),Vector2(.11,.29),Vector2(-.11,.29),Vector2(-.17,.22)]
	for i in 3:
		var a := 2.72+float(i)*.42
		_patch(b,1,finger_outline,.20,_at(a,1.32,.35),Vector3(0,a,0))
		var outline:Array[Vector3] = []
		for point in finger_outline:
			var p := Vector3(point.x*.80,.455,point.y*.80)
			outline.append(_at(a,1.32,0)+Basis(Vector3.UP,a)*p)
		_add(b,2,_tube(outline,.010,5,true))
	# One visibly lateral thumb with a low attached leather web.
	_patch(b,1,[Vector2(-.32,-.15),Vector2(-.18,-.21),Vector2(.25,-.19),Vector2(.38,-.08),Vector2(.36,.08),Vector2(.20,.20),Vector2(-.19,.19),Vector2(-.34,.07)],.22,_at(4.44,1.28,.295),Vector3(0,4.44,0))
	_arc(b,0,1.03,1.41,.12,.255,3.73,.83)
	for i in 9:
		var a := -.70+float(i)*.32
		_add(b,3,_tube([_at(a,1.12,.278),_at(a,1.26,.318),_at(a,1.395,.22)],.024,6))
	for i in 2:
		var a := 2.93+float(i)*.42
		_add(b,3,_tube([_at(a-.12,1.32,.430),_at(a,1.34,.465),_at(a+.12,1.32,.430)],.023,6))
	_feature(b,"Three rounded leather finger pads and a distinct broad thumb around the pocket")
	_feature(b,"Dark inset seams and thick cream laces")
	return _finish(b)

static func _basin()->Dictionary:
	var b := _bucket([_material("f1ecdc",.22,0,.035),_material("285693",.20,0,.045),_material("adbcc2",.37,7,.06,.12)])
	var opts := {"oval":Vector2(1.105,1.0),"floor":true}
	_add(b,2,_ring([Vector2(1.015,.053),Vector2(1.18,.044),Vector2(1.35,.12),Vector2(1.345,.173),Vector2(1.15,.104),Vector2(1.015,.103)],64,opts))
	opts.floor = false
	_add(b,0,_ring([Vector2(1.009,.082),Vector2(1.04,.062),Vector2(1.20,.074),Vector2(1.354,.169),Vector2(1.367,.218),Vector2(1.305,.238),Vector2(1.19,.18),Vector2(1.012,.112)],64,opts))
	_add(b,1,_ring([Vector2(1.31,.205),Vector2(1.36,.183),Vector2(1.393,.209),Vector2(1.391,.248),Vector2(1.35,.263),Vector2(1.315,.246)],64,opts))
	_feature(b,"Wide shallow oval enamel basin with a rolled cobalt lip and cool metal underside")
	return _finish(b)

static func _acorn()->Dictionary:
	var b := _bucket([_material("71502f",.79,1,.15),_material("956d39",.76,1,.16),_material("c78b40",.59,2,.1),_material("624224",.84,2,.13)])
	_add(b,0,_ring([Vector2(1.08,.05),Vector2(1.22,.04),Vector2(1.34,.13),Vector2(1.35,.23),Vector2(1.26,.32),Vector2(1.09,.34)],32))
	_add(b,2,_ring(_rounded(1.009,1.135,.035,.397,.03),40,{"floor":true}))
	var scale_mesh := Sculpt.bevel([Vector2(-.29,-.11),Vector2(.29,-.11),Vector2(.30,.015),Vector2(.18,.13),Vector2(0,.19),Vector2(-.18,.13),Vector2(-.30,.015)],.072)
	for row in 2:
		for i in 14:
			var a := TAU*(float(i)+float(row)*.5)/14
			var radius := 1.32-float(row)*.085
			var y := .20+float(row)*.142
			_add(b,(i+row)%2,scale_mesh,_at(a,radius,y),Vector3.ONE,Vector3(PI/2+.52,a,0))
	_add(b,3,_tube([Vector3(.0,.28,-1.27),Vector3(.02,.37,-1.42),Vector3(.045,.45,-1.55)],.066,8))
	_feature(b,"Broad overlapping olive-brown cap scales with honey interior and a short woody stem")
	return _finish(b)

static func _knit()->Dictionary:
	var b := _bucket([_material("b45f58",.94,4,.16),_material("cfb991",.93,4,.15),_material("bb6960",.95,4,.16),_material("c77668",.94,4,.16)])
	_add(b,0,_ring([Vector2(1.03,.12),Vector2(1.24,.12),Vector2(1.335,.28),Vector2(1.335,.39),Vector2(1.26,.465),Vector2(1.12,.455),Vector2(1.02,.32)],40))
	_add(b,1,_ring(_rounded(1.009,1.405,.025,.267,.065),40,{"floor":true}))
	# Follow the actual knit body's profile, not an arch above it. Both strands
	# sit just above the fabric; only their two endpoints tuck into the lining.
	var cable_profile:Array[Vector2] = [Vector2(1.035,.321),Vector2(1.07,.396),Vector2(1.10,.436),Vector2(1.14,.464),Vector2(1.18,.467),Vector2(1.22,.470),Vector2(1.26,.473),Vector2(1.30,.433),Vector2(1.342,.398),Vector2(1.344,.313),Vector2(1.345,.237)]
	for i in 4:
		var a := TAU*float(i)/4+.25
		for cross_side in [-1.0,1.0]:
			var cable:Array[Vector3] = []
			for j in 11:
				var t := float(j)/10.0
				var angle:float = a+cross_side*.12*cos(PI*t)
				var radius:float = cable_profile[j].x
				var y:float = cable_profile[j].y+cross_side*.004*sin(PI*t)
				cable.append(_at(angle,radius,y))
			_add(b,2,_tube(cable,.033,6))
	for i in 16:
		var a := TAU*float(i)/16
		_add(b,1,_tube([_at(a,1.379,.073),_at(a,1.431,.156),_at(a,1.38,.232)],.018,5))
	_soft(b,3,Vector3(1.415,.373,.18),Vector3(.19,.18,.19))
	var tuft := Sculpt.lathe([Vector2(0,-1),Vector2(.59,-.81),Vector2(.95,-.31),Vector2(.95,.31),Vector2(.59,.81),Vector2(0,1)],8)
	for i in 7:
		var a := float(i)*TAU/7
		_add(b,0,tuft,Vector3(1.415+sin(a)*.145,.38+.075*sin(a*2),.18+cos(a)*.145),Vector3(.073,.08,.073))
	_feature(b,"Dusty-coral knitted cap with a folded oatmeal cuff and broad cable stitches")
	_feature(b,"One small soft side pompom")
	return _finish(b)
