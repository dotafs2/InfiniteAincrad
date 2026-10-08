extends RefCounted
## Additional original collection families. Mesh/material resources are cached by
## model family and palette; every instance owns its nodes and motion transforms.
const Common = preload("res://fidelity/common_geometry.gd")
const Sculpt = preload("res://fidelity/skin_sculpt.gd")
const IDS:Array[String] = ["plain_loop","button_wheel","pocket_arcade","sakura_pavilion","clockwork_orbit","phoenix_nest","crystal_crown","aurora_rift"]
static var _cache:Dictionary = {}

static func build(s:Node3D, parent:Node3D)->Dictionary:
	var family:String = str(s.get("model_id")) if s.get("model_id") != null else str(s.skin_id)
	if family.is_empty(): family = str(s.skin_id)
	var tint:Color = s.tint
	var accent:Color = s.accent
	var key := family+":"+tint.to_html()+":"+accent.to_html()
	if not _cache.has(key): _cache[key] = _make(family,tint,accent)
	var recipe:Dictionary = _cache[key]
	var root := Node3D.new()
	root.name = "CollectionSculpt_"+family
	parent.add_child(root)
	var model := _instance(root,recipe.mesh,"CollectionModel_"+family)
	model.set_meta("opening_radius",1.0)
	model.set_meta("authored_features",recipe.features)
	model.set_meta("collection_geometry_revision",2 if family == "phoenix_nest" else 1)
	var motions:Array[Dictionary] = []
	for extra in recipe.get("extras",[]):
		var pivot := Node3D.new()
		pivot.name = str(extra.name)
		root.add_child(pivot)
		pivot.position = extra.get("origin",Vector3.ZERO)
		_instance(pivot,extra.mesh,str(extra.name)+"Mesh")
		pivot.set_meta("motion_role",extra.role)
		motions.append({"node":pivot,"role":extra.role,"speed":float(extra.get("speed",.35)),"amplitude":float(extra.get("amplitude",.025)),"phase":float(extra.get("phase",0.0)),"base_position":pivot.position,"base_rotation":pivot.rotation,"base_scale":pivot.scale})
	root.set_meta("model_family",family)
	root.set_meta("cached_geometry",true)
	return {"main_ring":model,"animated_root":root,"motions":motions,"theme":{"id":family,"model_id":family,"features":recipe.features,"opening_radius":1.0}}

static func _instance(parent:Node3D, mesh:Mesh, label:String)->MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.extra_cull_margin = .12
	part.set_meta("sculpted",true)
	parent.add_child(part)
	return part

static func _mat(color:Color, rough:=.43, pattern:=0, grain:=.06, metal:=0.0)->ShaderMaterial:
	return Common._material(color.to_html(false),rough,pattern,grain,metal)

static func _p(a:float, r:float, y:float)->Vector3:
	return Common._at(a,r,y)

static func _tag(b:Dictionary, text:String)->void:
	Common._feature(b,text)

static func _ring(b:Dictionary, slot:int, inner:float, outer:float, low:float, high:float, segments:=40, floor:=false)->void:
	Common._add(b,slot,Common._ring(Common._rounded(inner,outer,low,high,.035),segments,{"floor":floor}))

static func _tile(b:Dictionary, slot:int, at:Vector3, size:Vector2, depth:float, angle:=0.0)->void:
	Common._patch(b,slot,[Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(size.x*.5,size.y*.5),Vector2(-size.x*.5,size.y*.5)],depth,at,Vector3(0,angle,0))

static func _panel(b:Dictionary, slot:int, at:Vector3, size:Vector2, depth:float, angle:=0.0)->void:
	var mesh := Sculpt.bevel([Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(size.x*.5,size.y*.5),Vector2(-size.x*.5,size.y*.5)],depth)
	Common._add(b,slot,mesh,at,Vector3.ONE,Vector3(0,angle,0))

static func _post(b:Dictionary, slot:int, at:Vector3, radius:float, height:float, segments:=10)->void:
	var mesh := Sculpt.lathe([Vector2(0,0),Vector2(radius*.82,0),Vector2(radius,.02),Vector2(radius,height-.02),Vector2(radius*.82,height),Vector2(0,height)],segments)
	Common._add(b,slot,mesh,at)

static func _gem(b:Dictionary, slot:int, at:Vector3, width:float, height:float, depth:float, angle:=0.0)->void:
	var mesh := Sculpt.bevel([Vector2(0,-height*.5),Vector2(width*.5,-height*.13),Vector2(width*.36,height*.18),Vector2(0,height*.5),Vector2(-width*.36,height*.18),Vector2(-width*.5,-height*.13)],depth)
	Common._add(b,slot,mesh,at,Vector3.ONE,Vector3(0,angle,0))

static func _finish(b:Dictionary, extras:Array[Dictionary]=[])->Dictionary:
	var result := Common._finish(b)
	result.extras = extras
	return result

static func _make(family:String, tint:Color, accent:Color)->Dictionary:
	match family:
		"plain_loop":return _plain(tint,accent)
		"button_wheel":return _button(tint,accent)
		"pocket_arcade":return _arcade(tint,accent)
		"sakura_pavilion":return _pavilion(tint,accent)
		"clockwork_orbit":return _clockwork(tint,accent)
		"phoenix_nest":return _phoenix(tint,accent)
		"crystal_crown":return _crown(tint,accent)
		"aurora_rift":return _aurora(tint,accent)
	assert(false,"Unknown collection model family: "+family)
	return {}

static func _plain(tint:Color, accent:Color)->Dictionary:
	var b := Common._bucket([_mat(tint,.31),_mat(accent,.27),_mat(Color("657080"),.39,7,.05,.35)])
	Common._add(b,0,Common._ring([Vector2(1.009,.005),Vector2(1.21,.025),Vector2(1.28,.08),Vector2(1.265,.15),Vector2(1.20,.19),Vector2(1.04,.18),Vector2(1.009,.12)],40,{"floor":true}))
	_ring(b,1,1.10,1.21,.182,.197,40)
	for i in 3:
		var a := TAU*float(i)/3+.25
		_tile(b,2,_p(a,1.24,.155),Vector2(.15,.075),.045,a)
	_tag(b,"Low rolled enamel loop with an inset color band and three metal clasps")
	return _finish(b)

static func _button(tint:Color, accent:Color)->Dictionary:
	var b := Common._bucket([_mat(tint,.42),_mat(accent,.64,4,.12),_mat(tint.darkened(.57),.59),_mat(Color("eee0c1"),.73,4,.06)])
	Common._add(b,0,Common._ring([Vector2(1.009,.005),Vector2(1.28,.03),Vector2(1.40,.10),Vector2(1.415,.20),Vector2(1.36,.30),Vector2(1.22,.338),Vector2(1.02,.28)],48,{"floor":true,"radial_wave":.013,"frequency":8.0}))
	_ring(b,1,1.03,1.10,.278,.300,40)
	for i in 4:
		var a := TAU*float(i)/4+.30
		var at := _p(a,1.235,.340)
		Common._add(b,2,Sculpt.lathe([Vector2(0,.0),Vector2(.084,0),Vector2(.090,.025),Vector2(.068,.050),Vector2(0,.05)],12),at)
		for side in [-1.0,1.0]:
			var from := at+Basis(Vector3.UP,a)*Vector3(-.12,.029,side*.055)
			var mid := at+Vector3(0,.065,0)
			var to := at+Basis(Vector3.UP,a)*Vector3(.12,.029,-side*.055)
			Common._add(b,3,Common._tube([from,mid,to],.018,6))
	_tag(b,"Sculpted sewing button with four recessed eyelets and crossed cream thread")
	return _finish(b)

static func _arcade(tint:Color, accent:Color)->Dictionary:
	var b := Common._bucket([_mat(tint,.36),_mat(accent,.28),_mat(Color("222a43"),.40),_mat(Color("d9e8ef"),.31,7,.03,.20),_mat(accent.lightened(.30),.27)])
	# The octagonal opening's flat sides are closer than its corner radius.
	Common._add(b,0,Common._ring(Common._rounded(1.09,1.44,.03,.24,.045),48,{"polygon":8,"floor":true}))
	_ring(b,2,1.02,1.11,.192,.247,40)
	var body := Sculpt.bevel([Vector2(-.41,0),Vector2(.41,0),Vector2(.43,.19),Vector2(.35,.75),Vector2(-.35,.75),Vector2(-.43,.19)],.22)
	Common._add(b,0,body,Vector3(0,.22,-1.30))
	_panel(b,3,Vector3(0,.701,-1.174),Vector2(.61,.39),.036)
	_panel(b,2,Vector3(0,.701,-1.148),Vector2(.52,.30),.018)
	_panel(b,1,Vector3(0,.958,-1.165),Vector2(.67,.092),.025)
	# Three abstract pixel ships on the actual cabinet screen.
	for x in [-.15,0.0,.15]:
		_panel(b,4,Vector3(x,.71,-1.13),Vector2(.07,.045),.008)
		_panel(b,4,Vector3(x,.67,-1.13),Vector2(.10,.025),.008)
	for side in [-1.0,1.0]:
		var a:float = side*.69
		_tile(b,2,_p(a,1.245,.260),Vector2(.32,.23),.065,a)
	var stick := _p(-.69,1.245,.295)
	_post(b,3,stick,.025,.19,8)
	Common._soft(b,1,stick+Vector3.UP*.225,Vector3(.081,.075,.081))
	for i in 3:
		var a := .54+float(i)*.14
		Common._soft(b,1 if i%2==0 else 4,_p(a,1.245,.315),Vector3(.041,.027,.041))
	for i in 6:
		var a := 1.06+float(i)*.62
		_tile(b,1,_p(a,1.34,.247),Vector2(.11,.047),.022,a)
	_tag(b,"Pocket arcade cabinet with framed pixel screen, marquee, joystick and three buttons")
	_tag(b,"Eight-sided control deck leaves the swallowing opening completely clear")
	return _finish(b)

static func _pavilion(tint:Color, accent:Color)->Dictionary:
	var b := Common._bucket([_mat(tint,.43),_mat(accent,.50),_mat(Color("845437"),.65,2,.11),_mat(Color("e9d9b6"),.60),_mat(accent.lightened(.30),.56)])
	_ring(b,2,1.02,1.40,.025,.175,40,true)
	_ring(b,3,1.04,1.31,.17,.195,40)
	for side in [-1.0,1.0]:
		_post(b,2,Vector3(side*.57,.18,-1.12),.055,.68,10)
		_post(b,2,Vector3(side*.76,.17,-.94),.047,.52,10)
	_panel(b,2,Vector3(0,.735,-1.235),Vector2(1.46,.075),.085)
	var roof_points:Array[Vector2] = [Vector2(-.83,.0),Vector2(-.62,.12),Vector2(0,.27),Vector2(.62,.12),Vector2(.83,0),Vector2(.55,.035),Vector2(0,.16),Vector2(-.55,.035)]
	Common._add(b,0,Sculpt.bevel(roof_points,.34),Vector3(0,.84,-1.25))
	Common._add(b,3,Sculpt.bevel(roof_points,.34),Vector3(0,.747,-1.25),Vector3(.82,.63,.90))
	for side in [-1.0,1.0]:
		var branch:Array[Vector3] = [Vector3(side*1.19,.17,-.10),Vector3(side*1.31,.35,-.23),Vector3(side*1.41,.57,-.26),Vector3(side*1.49,.72,-.38)]
		Common._add(b,2,Common._tube(branch,.028,6))
		Common._add(b,2,Common._tube([branch[1],Vector3(side*1.49,.40,-.03),Vector3(side*1.56,.48,.03)],.019,6))
		for bloom in [Vector3(side*1.48,.71,-.37),Vector3(side*1.55,.48,.03)]:
			for i in 5:
				var a := TAU*float(i)/5
				Common._soft(b,1 if i%2==0 else 4,bloom+Vector3(sin(a)*.063,cos(a)*.063,0),Vector3(.045,.05,.020))
			Common._soft(b,3,bloom+Vector3(0,0,.019),Vector3(.027,.027,.022))
	_tag(b,"Two swept pavilion eaves, four timber posts and a pale stepped platform")
	_tag(b,"Two branching sakura boughs carry four five-petal blossoms")
	return _finish(b)

static func _clockwork(tint:Color, accent:Color)->Dictionary:
	var mats:Array = [_mat(tint,.35,7,.06,.40),_mat(accent,.33),_mat(Color("b68a48"),.36,7,.05,.45),_mat(Color("26303d"),.54)]
	var b := Common._bucket(mats)
	_ring(b,0,1.009,1.43,.025,.25,40,true)
	_ring(b,1,1.035,1.325,.239,.28,40)
	for i in 20:
		var a := TAU*float(i)/20
		_tile(b,2,_p(a,1.438,.166),Vector2(.115,.095),.125,a)
	for i in 12:
		var a := TAU*float(i)/12
		_tile(b,3,_p(a,1.205,.290),Vector2(.035,.118 if i%3==0 else .067),.016,a)
	for i in 3:
		var a := TAU*float(i)/3+.46
		var at := _p(a,1.325,.342)
		Common._add(b,2,Sculpt.lathe([Vector2(.045,0),Vector2(.15,0),Vector2(.17,.055),Vector2(.055,.063)],16),at)
		for j in 6:
			var angle := TAU*float(j)/6
			_tile(b,2,at+_p(angle,.175,.033),Vector2(.067,.065),.058,angle)
	var moving := Common._bucket([mats[2]])
	var orbit:Array[Vector3] = []
	for i in 49:
		var a := TAU*float(i)/48
		orbit.append(_p(a,1.49,.58+.30*sin(a)))
	Common._add(moving,0,Common._tube(orbit,.021,6))
	for a in [.5,PI+.5]:
		_gem(moving,0,_p(a,1.49,.58+.30*sin(a)),.13,.20,.105,a)
	var extra := Common._finish(moving)
	_tag(b,"Clock dial, twenty gear teeth, twelve hour markers and three exposed cogs")
	_tag(b,"One inclined mechanical orbit carries two counterweights")
	return _finish(b,[{"name":"ClockworkOrbit","mesh":extra.mesh,"role":"orbit","speed":.32}])

static func _phoenix(tint:Color, accent:Color)->Dictionary:
	var mats:Array = [_mat(tint,.43,1,.05),_mat(accent,.31),_mat(Color("35222b"),.54)]
	var b := Common._bucket(mats)
	Common._add(b,0,Common._ring([Vector2(1.009,.005),Vector2(1.23,.025),Vector2(1.41,.13),Vector2(1.36,.29),Vector2(1.18,.33),Vector2(1.015,.23)],40,{"floor":true}))
	for i in 10:
		var a := TAU*float(i)/10
		var points:Array[Vector2] = [Vector2(-.095,-.13),Vector2(.045,-.15),Vector2(.11,-.02),Vector2(.03,.22),Vector2(-.07,.13)]
		Common._patch(b,1,points,.05,_p(a,1.255,.313),Vector3(.28,a,0))
	Common._soft(b,0,Vector3(0,.64,-1.28),Vector3(.14,.18,.12))
	Common._add(b,1,Sculpt.bevel([Vector2(-.09,.035),Vector2(.09,.035),Vector2(0,-.065)],.14),Vector3(0,.60,-1.125),Vector3.ONE,Vector3(.4,0,0))
	for side in [-1.0,1.0]:
		Common._soft(b,2,Vector3(side*.067,.692,-1.177),Vector3(.022,.022,.015))
		_gem(b,1,Vector3(side*.046,.91,-1.30),.075,.32,.065,side*.2)
	var extras:Array[Dictionary] = []
	var wing_outline:Array[Vector2] = [Vector2(0,0),Vector2(.08,.47),Vector2(.22,.91),Vector2(.34,.97),Vector2(.35,.55),Vector2(.56,.84),Vector2(.63,.82),Vector2(.52,.43),Vector2(.73,.59),Vector2(.76,.48),Vector2(.62,.18),Vector2(.35,.055)]
	for side in [-1.0,1.0]:
		var wings := Common._bucket([mats[0],mats[1]])
		var shoulder := Vector3(side*.53,.25,-1.075)
		var points:Array[Vector2] = []
		for p in wing_outline: points.append(Vector2(p.x*side,p.y))
		Common._add(wings,0,Sculpt.bevel(points,.11))
		for i in 3:
			var x:float = side*(.72+float(i)*.16)
			_gem(wings,1,Vector3(x,.65-float(i)*.09,-1.003)-shoulder,.08,.49-float(i)*.06,.025,side*.1)
		var wing := Common._finish(wings)
		extras.append({"name":"PhoenixLeftWing" if side < 0 else "PhoenixRightWing","mesh":wing.mesh,"origin":shoulder,"role":"sway","speed":1.35,"amplitude":.11,"phase":PI if side < 0 else 0.0})
	_tag(b,"Phoenix head, pointed crest and ten overlapping flame feathers around the nest")
	_tag(b,"Paired carved wings with three broad feather tips and bright inset shafts")
	return _finish(b,extras)

static func _crown(tint:Color, accent:Color)->Dictionary:
	var b := Common._bucket([_mat(tint.darkened(.40),.40),_mat(tint,.27),_mat(accent,.22),_mat(Color("e6edf6"),.28),_mat(Color("b18c47"),.36,7,.05,.45)])
	_ring(b,0,1.009,1.40,.025,.23,40,true)
	_ring(b,4,1.07,1.40,.175,.255,40)
	for i in 9:
		var a := TAU*float(i)/9
		var rear := (1.0-cos(a))*.5
		var height := .40+rear*.80
		_gem(b,1 if i%2==0 else 2,_p(a,1.255,.205+height*.5),.29,height,.18,a)
		_gem(b,3,_p(a,1.358,.283),.095,.135,.055,a)
	for i in 5:
		var a := TAU*(float(i)+.35)/5
		_gem(b,4,_p(a,1.405,.23),.095,.16,.065,a)
	_tag(b,"Nine faceted crown spires rise from low front jewels to a tall rear crystal fan")
	_tag(b,"Gold mounting band, pearl rivets and five pronged settings")
	return _finish(b)

static func _aurora_ribbon(start:float, phase:float)->ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers:Array[Vector3] = []
	var rings:Array = []
	var normals:Array = []
	var sections := 24
	for i in sections+1:
		var t := float(i)/sections
		var angle := start+t*1.56
		centers.append(_p(angle,1.31+.06*sin(t*TAU+phase),.22+sin(t*PI)*1.02))
	for i in sections+1:
		var t := float(i)/sections
		var angle := start+t*1.56
		var tangent := (centers[mini(sections,i+1)]-centers[maxi(0,i-1)]).normalized()
		var radial := Vector3(sin(angle),0,cos(angle))
		radial = (radial-tangent*radial.dot(tangent)).normalized()
		var across := tangent.cross(radial).normalized()
		var twist := .65*sin(t*TAU+phase)
		var axis := radial*cos(twist)+across*sin(twist)
		var second := -radial*sin(twist)+across*cos(twist)
		var vertices:Array[Vector3] = []
		var ns:Array[Vector3] = []
		for j in 8:
			var a := TAU*float(j)/8
			vertices.append(centers[i]+axis*cos(a)*.112+second*sin(a)*.028)
			ns.append((axis*cos(a)/.112+second*sin(a)/.028).normalized())
		rings.append(vertices);normals.append(ns)
	for i in sections:
		for j in 8:
			var k := (j+1)%8
			Sculpt.triangle(st,rings[i][j],rings[i+1][j],rings[i+1][k],normals[i][j],normals[i+1][j],normals[i+1][k])
			Sculpt.triangle(st,rings[i][j],rings[i+1][k],rings[i][k],normals[i][j],normals[i+1][k],normals[i][k])
	for i in [0,sections]:
		var n:Vector3 = (centers[0]-centers[1]).normalized() if i==0 else (centers[sections]-centers[sections-1]).normalized()
		for j in 8:Sculpt.triangle(st,centers[i],rings[i][j],rings[i][(j+1)%8],n,n,n)
	return st.commit()

static func _aurora(tint:Color, accent:Color)->Dictionary:
	var mats:Array = [_mat(tint.darkened(.68),.37),_mat(Color("cbd7e9"),.29,7,.03,.24),_mat(accent,.23),_mat(tint,.25)]
	var b := Common._bucket(mats)
	for i in 8:
		var a := TAU*float(i)/8+.013
		Common._arc(b,0,1.015,1.435,.025,.22+float(i%2)*.035,a,TAU/8-.026,{"floor":true})
		_gem(b,1,_p(a+.23,1.275,.267),.095,.15,.095,a)
	for i in 6:
		var a := TAU*float(i)/6+.10
		_gem(b,2,_p(a,1.465,.37+float(i%2)*.15),.15,.27,.09,a)
	var ribbons := Common._bucket([mats[3],mats[2]])
	for i in 3:
		Common._add(ribbons,i%2,_aurora_ribbon(TAU*float(i)/3+.2,float(i)*1.2))
	var extra := Common._finish(ribbons)
	_tag(b,"Eight split obsidian foundation pieces, silver inset points and six floating rift shards")
	_tag(b,"Three closed twisting aurora ribbons rise around the clear central opening")
	return _finish(b,[{"name":"AuroraRibbons","mesh":extra.mesh,"role":"sway","speed":.82,"amplitude":.015}])
