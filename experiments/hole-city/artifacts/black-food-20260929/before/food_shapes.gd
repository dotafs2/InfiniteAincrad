extends RefCounted
## Original toy-like food meshes. Geometry is built once per kind and shared.
const KINDS:=["bacon","egg","cake","donut","burger","cookie","berry","sushi","pancake","pizza"]
const PINK:=Color("ff398c")
const FROSTINGS:=[Color("ff398c"),Color("49d6fa"),Color("9854ed"),Color("65df46")]
const GOLD:=Color("ffab12")
const CREAM:=Color("fff3ce")
const RED:=Color("f72f35")
const GREEN:=Color("6ddd17")
const BROWN:=Color("78311b")

static func build(c:Node3D,root:Node3D,kind:String,tower:=false,flavor:=0)->void:
	var icing:Color=FROSTINGS[posmod(flavor,FROSTINGS.size())]
	if tower and flavor>=4 and kind in ["cake","burger"]:
		shop_front(c,root,kind)
		return
	if tower and kind in ["cake","pancake"]:
		building_floor(c,root,kind,icing)
		return
	match kind:
		"bacon":
			for i in 9:
				var y:float=.12+sin(i*.95)*.055
				c.box(root,Vector3(0,y,(i-4)*.21),Vector3(.82,.15,.235),RED)
				for x in [-.23,.08]:c.box(root,Vector3(x+sin(i*.8)*.05,y+.081,(i-4)*.21),Vector3(.12,.025,.235),Color("ffcf93"))
		"egg":
			c.sphere(root,Vector3(0,.12,0),.87,CREAM,.14)
			c.sphere(root,Vector3(.48,.10,.16),.45,CREAM,.19)
			c.sphere(root,Vector3(-.48,.10,-.13),.42,CREAM,.18)
			c.sphere(root,Vector3(.08,.23,0),.40,Color("ffbf00"),.66)
			c.sphere(root,Vector3(-.04,.43,-.09),.12,Color("fff09a"),.25)
		"cake":
			for i in 3:
				c.cylinder(root,Vector3(0,.27+i*.48,0),.94,.44,Color("ffc045"))
				c.cylinder(root,Vector3(0,.48+i*.48,0),.96,.10,CREAM)
			c.cylinder(root,Vector3(0,1.52,0),1.0,.18,icing)
			for i in 10:
				var a:float=i*TAU/10
				c.sphere(root,Vector3(cos(a)*.91,1.40,sin(a)*.91),.14,icing,1.2)
			for i in 5:
				var a:float=i*TAU/5
				c.sphere(root,Vector3(cos(a)*.62,1.76,sin(a)*.62),.18,RED,1.05)
		"donut":
			for i in 2:
				var v:=MeshInstance3D.new();var ring:=TorusMesh.new()
				ring.inner_radius=.32;ring.outer_radius=1.0;ring.rings=24;ring.ring_segments=10
				v.mesh=ring;v.material_override=c.material(GOLD if i==0 else icing)
				root.add_child(v);v.position.y=.31+i*.12;v.scale.y=.7 if i==0 else .44
			for i in 12:
				var a:float=i*TAU/12
				var sprinkle:MeshInstance3D=c.box(root,Vector3(cos(a)*.69,.60,sin(a)*.69),Vector3(.17,.06,.07),[CREAM,Color("19dbe3"),Color("a340ff"),GOLD][i%4])
				sprinkle.rotation.y=a+.7
		"burger":
			c.sphere(root,Vector3(0,.22,0),.89,GOLD,.24)
			c.cylinder(root,Vector3(0,.49,0),.90,.24,BROWN)
			for i in 8:c.sphere(root,Vector3(cos(i*TAU/8)*.75,.67,sin(i*TAU/8)*.75),.24,GREEN,.35)
			c.cylinder(root,Vector3(0,.77,0),.88,.12,RED)
			var cheese:MeshInstance3D=c.box(root,Vector3(0,.87,0),Vector3(1.50,.08,1.50),Color("ffcf04"));cheese.rotation.y=.2
			c.sphere(root,Vector3(0,1.02,0),.91,Color("ffae21"),.41)
			for i in 8:c.sphere(root,Vector3(cos(i*2.4)*.54,1.34,sin(i*2.4)*.54),.055,CREAM,.35)
		"cookie":
			c.cylinder(root,Vector3(0,.18,0),.9,.30,Color("f7a32d"))
			if flavor>0:c.cylinder(root,Vector3(0,.345,0),.80,.05,icing)
			for i in 9:c.sphere(root,Vector3(cos(i*2.4)*(.35 if i%2==0 else .67),.35,sin(i*2.4)*(.35 if i%2==0 else .67)),.12,BROWN,.45)
		"berry":
			c.sphere(root,Vector3(0,.64,0),.70,RED,1.0)
			for i in 5:
				var leaf:MeshInstance3D=c.sphere(root,Vector3(cos(i*TAU/5)*.24,1.22,sin(i*TAU/5)*.24),.34,GREEN,.16)
				leaf.rotation.y=i*TAU/5
			for i in 10:c.sphere(root,Vector3(cos(i*2.4)*.66,.45+(i%3)*.22,sin(i*2.4)*.66),.045,Color("ffe258"),1.3)
		"sushi":
			c.box(root,Vector3(0,.30,0),Vector3(1.45,.49,1.76),CREAM)
			for x in [-.56,0,.56]:
				for z in [-.69,.69]:c.sphere(root,Vector3(x,.28,z),.25,CREAM,.94)
			c.box(root,Vector3(0,.61,0),Vector3(1.58,.22,1.86),Color("ff633e"))
			for z in [-.55,0,.55]:c.box(root,Vector3(0,.73,z),Vector3(1.56,.018,.045),Color("ffc67d"))
			c.box(root,Vector3(0,.43,0),Vector3(1.62,.80,.32),Color("214d26"))
		"pancake":
			for i in 3:
				c.cylinder(root,Vector3(0,.13+i*.25,0),.97,.23,GOLD)
				c.cylinder(root,Vector3(0,.23+i*.25,0),.92,.03,Color("ffd566"))
			c.sphere(root,Vector3(0,.77,0),.66,Color("c76b16"),.055)
			c.box(root,Vector3(.05,.85,0),Vector3(.36,.14,.31),Color("ffe73b"))
		"pizza":
			c.cylinder(root,Vector3(0,.14,0),1.0,.26,GOLD)
			c.cylinder(root,Vector3(0,.29,0),.89,.07,RED)
			c.cylinder(root,Vector3(0,.34,0),.82,.06,Color("ffd82a"))
			for i in 7:
				var a:float=i*2.4
				c.cylinder(root,Vector3(cos(a)*.54,.40,sin(a)*.54),.16,.045,Color("e33c1a"))
				c.sphere(root,Vector3(cos(a+.6)*.59,.42,sin(a+.6)*.59),.085,GREEN,.30)
	if tower:
		var y:float=.85 if kind=="burger" else .33
		for side in [-1,1]:
			for x in [-.40,.40]:
				c.box(root,Vector3(x,y,side*.89),Vector3(.23,.30,.08),BROWN)
				c.box(root,Vector3(x-.035,y+.035,side*.94),Vector3(.07,.12,.02),CREAM)

static func building_floor(c:Node3D,root:Node3D,kind:String,icing:Color)->void:
	# Square layer-cake apartments and wafer shops make legible street fronts.
	var wafer:bool=kind=="pancake"
	c.box(root,Vector3(0,.39,0),Vector3(1.90,.74,1.90),GOLD if wafer else Color("ffc24d"))
	for y in [.18,.51]:c.box(root,Vector3(0,y,0),Vector3(1.94,.08,1.94),CREAM)
	c.box(root,Vector3(0,.79,0),Vector3(2.04,.16,2.04),Color("ffdc58") if wafer else icing)
	for side in [-1,1]:
		for x in [-.57,0,.57]:
			c.box(root,Vector3(x,.39,side*.961),Vector3(.25,.31,.045),BROWN)
			c.box(root,Vector3(x-.035,.43,side*.991),Vector3(.08,.17,.025),Color("68deed"))
			c.box(root,Vector3(side*.961,.39,x),Vector3(.045,.31,.25),BROWN)
			c.box(root,Vector3(side*.991,.43,x-.035),Vector3(.025,.17,.08),Color("68deed"))
		if wafer:
			for x in [-.78,-.26,.26,.78]:c.box(root,Vector3(x,.68,side*.97),Vector3(.025,.13,.018),Color("c27326"))
		else:
			for i in 5:
				var x:float=-.78+i*.39
				c.sphere(root,Vector3(x,.71,side*.94),.11,icing,1.1+float(i%2)*.45)

static func shop_front(c:Node3D,root:Node3D,kind:String)->void:
	# A low storefront with a striped candy awning, broad display glass and door.
	# The whole counter is one food piece; stacked roof foods stay independent.
	var icing:Color=PINK if kind=="cake" else RED
	c.box(root,Vector3(0,.38,0),Vector3(1.90,.72,1.90),CREAM)
	c.box(root,Vector3(0,.10,0),Vector3(2.0,.14,2.0),GOLD)
	c.box(root,Vector3(0,.43,.97),Vector3(1.18,.41,.05),Color("35cfec"))
	c.box(root,Vector3(.72,.34,.97),Vector3(.30,.56,.05),BROWN)
	for x in [-.43,0,.43]:c.sphere(root,Vector3(x,.35,1.0),.13,icing,.75)
	c.box(root,Vector3(0,.83,.62),Vector3(2.04,.18,.76),icing)
	for x in [-.76,-.25,.25,.76]:c.box(root,Vector3(x,.931,.62),Vector3(.23,.025,.73),CREAM)
	c.box(root,Vector3(0,.93,-.29),Vector3(2.02,.10,1.04),GOLD)
