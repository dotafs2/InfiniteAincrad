extends RefCounted
## Original food, animal and object silhouettes. All parts remain outside the
## swallowing disk; they never add collision shapes or affect admission.
static func part(s:Node3D,mesh:Mesh,at:Vector3,mat:Material)->MeshInstance3D:
	return s.mesh_part(s.ornaments,mesh,at,mat)
static func box(s:Node3D,at:Vector3,size:Vector3,mat:Material,angle:=0.0)->MeshInstance3D:
	var m:=BoxMesh.new();m.size=size
	var p:=part(s,m,at,mat);p.rotation.y=angle;return p
static func cone(s:Node3D,at:Vector3,radius:float,height:float,mat:Material,top:=0.0)->MeshInstance3D:
	var m:=CylinderMesh.new();m.bottom_radius=radius;m.top_radius=top;m.height=height;m.radial_segments=12
	return part(s,m,at,mat)
static func pill(s:Node3D,at:Vector3,radius:float,height:float,mat:Material)->MeshInstance3D:
	var m:=CapsuleMesh.new();m.radius=radius;m.height=maxf(height,radius*2.0);m.radial_segments=12;m.rings=3
	return part(s,m,at,mat)
static func ring(s:Node3D,at:Vector3,inner:float,outer:float,mat:Material)->MeshInstance3D:
	var m:=TorusMesh.new();m.inner_radius=inner;m.outer_radius=outer;m.rings=32;m.ring_segments=6
	var p:=part(s,m,at,mat);p.scale.y=.6;return p
static func poly(s:Node3D,at:Vector3,points:PackedVector2Array,depth:float,mat:Material)->MeshInstance3D:
	# Extruded upright polygon with a flat front and back and actual side walls.
	# Normalize the perimeter before deriving outward side normals. Godot's
	# front faces are clockwise, unlike Geometry2D's cap triangulation.
	if Geometry2D.is_polygon_clockwise(points):points.reverse()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles:=Geometry2D.triangulate_polygon(points)
	for side in [-1.0,1.0]:
		for i in range(0,triangles.size(),3):
			for j in [2,1,0] if side>0 else [0,1,2]:
				var v:=points[triangles[i+j]]
				st.set_uv(v+Vector2.ONE*.5)
				st.set_normal(Vector3(0,0,side));st.add_vertex(Vector3(v.x,v.y,side*depth*.5))
	for i in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()]
		var normal:=Vector3(b.y-a.y,a.x-b.x,0).normalized()
		for v in [Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(a.x,a.y,-depth*.5),Vector3(a.x,a.y,depth*.5),Vector3(b.x,b.y,depth*.5)]:
			st.set_uv(Vector2(v.x,v.y)+Vector2.ONE*.5)
			st.set_normal(normal);st.add_vertex(v)
	return part(s,st.commit(),at,mat)
static func wedge(s:Node3D,angle:float,inner:float,outer:float,height:float,width:float,mat:Material)->MeshInstance3D:
	var points:=PackedVector2Array()
	for i in 5:
		var a:=angle-width*.5+width*float(i)/4.0
		points.append(Vector2(sin(a),cos(a))*outer)
	for i in range(4,-1,-1):
		var a:=angle-width*.5+width*float(i)/4.0
		points.append(Vector2(sin(a),cos(a))*inner)
	var p:=poly(s,Vector3(0,height,0),points,.08,mat)
	p.rotation.x=PI*.5;return p
static func star(s:Node3D,at:Vector3,radius:float,mat:Material)->MeshInstance3D:
	var points:=PackedVector2Array()
	for i in 10:
		var a:=float(i)*TAU/10.0+PI*.5
		points.append(Vector2(cos(a),sin(a))*radius*(1.0 if i%2==0 else .45))
	return poly(s,at,points,.1,mat)
static func eyes(s:Node3D,width:float,z:float,y:float,white:Material,dark:Material)->void:
	for sign in [-1,1]:
		cone(s,Vector3(sign*width,y,z),.15,.09,white,.15)
		cone(s,Vector3(sign*width,y+.052,z+.018),.068,.022,dark,.068)
static func build(s:Node3D)->void:
	var base:Material=s.flat_material(s.tint)
	var bright:Material=s.flat_material(s.accent)
	var cream:Material=s.flat_material(Color("fff4db"))
	var dark:Material=s.flat_material(Color("302841"))
	var green:Material=s.flat_material(Color("53c96d"))
	var red:Material=s.flat_material(Color("f24b61"))
	match s.model_id:
		"sunny_side":
			for i in 5:
				var a:=float(i)*TAU/5.0
				var p:=pill(s,Vector3(sin(a)*1.1,.1,cos(a)*1.1),.24,.53,cream);p.rotation.x=PI*.5;p.rotation.y=a
			cone(s,Vector3(0,.23,-1.12),.29,.26,bright,.18)
		"sugar_glaze":
			ring(s,Vector3(0,.14,0),.96,1.32,base)
			for i in 6:
				var a:=float(i)*TAU/6.0
				box(s,Vector3(sin(a)*1.17,.26,cos(a)*1.17),Vector3(.19,.05,.055),bright if i%2==0 else cream,a+.6)
		"berry_crown":
			for i in 5:
				var a:=float(i)*TAU/5.0
				cone(s,Vector3(sin(a)*1.12,.20,cos(a)*1.12),.20,.34,base,.08)
			for i in 5:
				var p:=poly(s,Vector3(0,.23,-1.10),PackedVector2Array([Vector2(-.10,0),Vector2(0,.49),Vector2(.11,0)]),.07,green)
				p.rotation.z=(i-2)*.5
		"citrus_slice":
			ring(s,Vector3(0,.10,0),1.22,1.30,cream)
			for i in 8:wedge(s,float(i)*TAU/8.0,.99,1.26,.16,.64,bright if i%2==0 else base)
		"melon_munch":
			ring(s,Vector3(0,.12,0),1.2,1.34,bright)
			for i in 4:
				var a:=float(i)*TAU/4.0
				wedge(s,a,.99,1.24,.17,1.31,base)
				cone(s,Vector3(sin(a)*1.11,.23,cos(a)*1.11),.06,.025,dark,.025)
		"pretzel_twist":
			for i in 3:
				var a:=float(i)*TAU/3.0
				var p:=ring(s,Vector3(sin(a)*1.14,.19,cos(a)*1.14),.14,.29,base);p.scale=Vector3(1,.7,1.2);p.rotation.y=a
				box(s,Vector3(sin(a+.3)*1.06,.19,cos(a+.3)*1.06),Vector3(.085,.065,.09),cream,a)
		"popcorn_pot":
			for i in 6:
				var a:=float(i)*TAU/6.0
				box(s,Vector3(sin(a)*1.13,.20,cos(a)*1.13),Vector3(.24,.31,.16),cream if i%2==0 else base,a)
			for i in 5:
				var a:=float(i)*TAU/5.0
				var p:=pill(s,Vector3(sin(a)*1.13,.40,cos(a)*1.13),.15,.32,bright);p.rotation.z=.6
		"pizza_party":
			ring(s,Vector3(0,.09,0),1.23,1.34,base)
			for i in 6:
				var a:=float(i)*TAU/6.0
				wedge(s,a,.97,1.27,.16,.92,bright)
				cone(s,Vector3(sin(a)*1.14,.22,cos(a)*1.14),.105,.022,red,.105)
		"cookie_bite":
			for i in 7:
				var a:=float(i)*TAU/7.0
				cone(s,Vector3(sin(a)*1.11,.13,cos(a)*1.11),.22,.16,base,.19)
			for i in 4:
				var a:=float(i)*TAU/4.0+.2
				box(s,Vector3(sin(a)*1.12,.24,cos(a)*1.12),Vector3(.14,.07,.10),bright,a+.4)
		"waffle_stack":
			for i in 4:
				var a:=float(i)*PI*.5
				box(s,Vector3(sin(a)*1.10,.14,cos(a)*1.10),Vector3(2.2,.20,.24),base,a)
				for j in 2:box(s,Vector3(sin(a)*1.10+cos(a)*(.38 if j==0 else -.38),.27,cos(a)*1.10-sin(a)*(.38 if j==0 else -.38)),Vector3(.085,.06,.28),bright,a)
		"pancake_stack":
			for i in 3:ring(s,Vector3(0,.10+i*.12,0),.99,1.26-i*.025,base if i%2==0 else bright)
			box(s,Vector3(0,.48,-1.12),Vector3(.31,.10,.21),cream,.18)
		"bacon_curl":
			for i in 4:
				var a:=float(i)*TAU/4.0
				var points:=PackedVector2Array([Vector2(-.40,0),Vector2(-.25,.15),Vector2(0,.08),Vector2(.20,.24),Vector2(.42,.11),Vector2(.42,.28),Vector2(.20,.41),Vector2(0,.25),Vector2(-.25,.32),Vector2(-.40,.17)])
				var p:=poly(s,Vector3(sin(a)*1.12,.12,cos(a)*1.12),points,.13,base);p.rotation.y=a
				var stripe:=poly(s,p.position+Vector3(0,.08,0),points,.145,bright);stripe.scale.y=.22;stripe.rotation.y=a
		"cocoa_square":
			for i in 4:
				var a:=float(i)*PI*.5
				box(s,Vector3(sin(a)*1.06,.12,cos(a)*1.06),Vector3(2.1,.23,.19),base,a)
				box(s,Vector3(sin(a+PI*.25)*1.49,.30,cos(a+PI*.25)*1.49),Vector3(.30,.15,.30),bright,0)
		"frosted_cake":
			ring(s,Vector3(0,.14,0),.98,1.25,base)
			ring(s,Vector3(0,.32,0),1.0,1.20,cream)
			for i in 3:
				var a:=float(i)*TAU/3.0
				cone(s,Vector3(sin(a)*1.12,.48,cos(a)*1.12),.055,.34,bright,.055)
				cone(s,Vector3(sin(a)*1.12,.71,cos(a)*1.12),.065,.14,red)
		"pineapple_top":
			for i in 6:
				var a:=float(i)*TAU/6.0
				var p:=box(s,Vector3(sin(a)*1.13,.20,cos(a)*1.13),Vector3(.25,.25,.13),base,a);p.rotation.z=PI*.25
			for i in 5:
				var p:=poly(s,Vector3(0,.29,-1.07),PackedVector2Array([Vector2(-.085,0),Vector2(0,.60-absf(i-2)*.06),Vector2(.085,0)]),.065,bright);p.rotation.z=(i-2)*.4
		"crab_cove":
			for sign in [-1,1]:
				for i in 3:box(s,Vector3(sign*1.21,.08,(i-1)*.48),Vector3(.34,.10,.095),base,sign*(i-1)*.30)
				var p:=poly(s,Vector3(sign*.83,.10,-.95),PackedVector2Array([Vector2(-.25,0),Vector2(-.27,.39),Vector2(-.10,.54),Vector2(-.04,.31),Vector2(.10,.50),Vector2(.24,.33),Vector2(.20,0)]),.19,base);p.rotation.y=sign*.25
			eyes(s,.32,-1.12,.25,cream,dark)
		"fox_den":
			for sign in [-1,1]:
				poly(s,Vector3(sign*.65,.17,-1.0),PackedVector2Array([Vector2(-.24,0),Vector2(0,.65),Vector2(.24,0)]),.25,base)
				poly(s,Vector3(sign*.86,.12,-.65),PackedVector2Array([Vector2(-.24,0),Vector2(0,.25),Vector2(.24,0)]),.22,cream)
			eyes(s,.30,-1.12,.20,cream,dark)
			cone(s,Vector3(0,.23,-1.14),.105,.13,dark)
		"bunny_burrow":
			for sign in [-1,1]:
				pill(s,Vector3(sign*.46,.53,-1.04),.14,.91,base)
				var p:=pill(s,Vector3(sign*.46,.57,-.905),.065,.60,bright);p.scale.z=.35
			eyes(s,.29,-1.12,.19,cream,dark)
			box(s,Vector3(0,.24,-1.18),Vector3(.14,.10,.10),bright,.7)
		"frog_pond":
			eyes(s,.65,-.94,.31,bright,dark)
			for sign in [-1,1]:
				var p:=poly(s,Vector3(sign*1.18,.10,.34),PackedVector2Array([Vector2(-.19,0),Vector2(-.15,.22),Vector2(-.04,.10),Vector2(.06,.28),Vector2(.14,.08),Vector2(.24,.18),Vector2(.23,0)]),.25,base);p.rotation.x=PI*.5;p.rotation.y=sign*.3
		"owl_hollow":
			eyes(s,.48,-1.03,.27,bright,dark)
			for sign in [-1,1]:poly(s,Vector3(sign*.72,.23,-.96),PackedVector2Array([Vector2(-.19,0),Vector2(sign*.16,.44),Vector2(.19,0)]),.18,base)
			var beak:=poly(s,Vector3(0,.13,-1.12),PackedVector2Array([Vector2(-.15,.23),Vector2(0,0),Vector2(.15,.23)]),.20,bright);beak.rotation.x=-.3
		"turtle_shell":
			for i in 6:
				var a:=float(i)*TAU/6.0
				cone(s,Vector3(sin(a)*1.12,.20,cos(a)*1.12),.20,.19,bright,.15)
			for sign in [-1,1]:
				for z in [-.65,.65]:
					var p:=pill(s,Vector3(sign*1.08,.11,z),.12,.39,base);p.rotation.z=PI*.5;p.rotation.y=sign*z
			var head:=pill(s,Vector3(0,.18,-1.29),.18,.36,base);head.rotation.x=PI*.5
		"snail_trail":
			var shell:=ring(s,Vector3(0,.39,-1.08),.15,.39,base);shell.rotation.x=PI*.5
			var center:=ring(s,Vector3(0,.39,-.99),.035,.16,bright);center.rotation.x=PI*.5
			for sign in [-1,1]:
				var stalk:=box(s,Vector3(sign*.58,.30,-1.0),Vector3(.06,.44,.06),bright);stalk.rotation.z=sign*.24
				cone(s,Vector3(sign*.63,.55,-1.0),.10,.08,cream,.10)
				cone(s,Vector3(sign*.63,.60,-1.0),.045,.02,dark,.045)
		"clockwork_key":
			box(s,Vector3(0,.42,-1.08),Vector3(.13,.63,.13),base)
			var handle:=ring(s,Vector3(0,.83,-1.08),.12,.24,bright);handle.rotation.x=PI*.5
			for i in 3:box(s,Vector3(.12,.28+i*.13,-1.08),Vector3(.20,.065,.12),bright)
			for i in 4:
				var a:=float(i)*TAU/4.0+.4
				cone(s,Vector3(sin(a)*1.11,.16,cos(a)*1.11),.055,.045,dark,.055)
		"royal_gate":
			ring(s,Vector3(0,.22,0),1.01,1.19,base)
			for i in 5:
				var a:=float(i)*TAU/5.0
				cone(s,Vector3(sin(a)*1.10,.44,cos(a)*1.10),.17,.49,base)
				cone(s,Vector3(sin(a)*1.10,.72,cos(a)*1.10),.073,.11,bright,.04)
		"satellite_dish":
			for sign in [-1,1]:
				var panel:=box(s,Vector3(sign*1.13,.25,0),Vector3(.39,.09,1.14),bright);panel.rotation.z=sign*.2
				for z in [-.35,.35]:box(s,Vector3(sign*1.13,.31,z),Vector3(.42,.025,.045),cream)
			box(s,Vector3(0,.34,-1.05),Vector3(.10,.53,.10),base)
			var dish:=cone(s,Vector3(0,.64,-1.06),.29,.15,base,.12);dish.rotation.x=-.6
			var antenna:=box(s,Vector3(0,.80,-.99),Vector3(.045,.25,.045),bright);antenna.rotation.x=-.6
		"carnival_tent":
			for i in 8:
				var a:=float(i)*TAU/8.0
				var p:=poly(s,Vector3(sin(a)*1.10,.13,cos(a)*1.10),PackedVector2Array([Vector2(-.33,0),Vector2(0,.52),Vector2(.33,0)]),.11,base if i%2==0 else bright);p.rotation.y=a
			box(s,Vector3(0,.71,-1.12),Vector3(.04,.50,.04),cream)
			poly(s,Vector3(.04,.83,-1.12),PackedVector2Array([Vector2(0,-.10),Vector2(.28,0),Vector2(0,.13)]),.04,base)
		"rocket_port":
			cone(s,Vector3(0,.51,-1.05),.18,.57,base,.18)
			cone(s,Vector3(0,.93,-1.05),.18,.29,bright)
			for sign in [-1,1]:poly(s,Vector3(sign*.17,.27,-1.04),PackedVector2Array([Vector2(0,0),Vector2(sign*.28,-.08),Vector2(0,.32)]),.13,bright)
			cone(s,Vector3(0,.14,-1.05),.07,.18,bright,.16)
			var window:=cone(s,Vector3(0,.63,-.866),.085,.04,dark,.085);window.rotation.x=PI*.5
		"rainbow_bridge":
			for j in 3:
				var points:=PackedVector2Array()
				var radius:=.68-j*.16
				for i in 17:
					var a:=float(i)*PI/16.0
					points.append(Vector2(cos(a)*radius,sin(a)*radius))
				for i in range(16,-1,-1):
					var a:=float(i)*PI/16.0
					points.append(Vector2(cos(a)*(radius-.11),sin(a)*(radius-.11)))
				poly(s,Vector3(0,.21,-1.02),points,.1,[base,cream,bright][j])
			for sign in [-1,1]:pill(s,Vector3(sign*.68,.17,-1.02),.16,.34,cream)
		"storm_cloud":
			for i in 5:
				var cloud:=pill(s,Vector3((i-2)*.25,.54+sin(i)*.06,-1.03),.18,.39,base);cloud.rotation.z=PI*.5
			poly(s,Vector3(.15,.05,-.96),PackedVector2Array([Vector2(-.11,.62),Vector2(-.30,.27),Vector2(-.05,.29),Vector2(-.14,0),Vector2(.24,.39),Vector2(.02,.37),Vector2(.12,.62)]),.11,bright)
		"dragon_roost":
			for sign in [-1,1]:
				var points:=PackedVector2Array([Vector2(0,0),Vector2(sign*.43,.68),Vector2(sign*.75,.46),Vector2(sign*.55,.34),Vector2(sign*.66,.18),Vector2(sign*.36,.15),Vector2(sign*.26,0)])
				poly(s,Vector3(sign*.65,.12,-.79),points,.12,base)
				cone(s,Vector3(sign*.41,.50,-1.05),.09,.47,bright)
				cone(s,Vector3(sign*.25,.19,1.03),.02,.22,cream,.10)
		"jelly_veil":
			ring(s,Vector3(0,.34,0),.99,1.28,base)
			for i in 6:
				var a:=float(i)*TAU/6.0
				var points:=PackedVector2Array([Vector2(-.09,0),Vector2(-.16,.18),Vector2(-.04,.36),Vector2(-.11,.57),Vector2(.05,.57),Vector2(.11,.36),Vector2(-.01,.18),Vector2(.06,0)])
				var tentacle:=poly(s,Vector3(sin(a)*1.13,.08,cos(a)*1.13),points,.07,bright);tentacle.rotation.y=a;s.parts.append(tentacle)
		"moon_dream":
			poly(s,Vector3(0,.12,-1.05),PackedVector2Array([Vector2(.18,.72),Vector2(-.10,.67),Vector2(-.29,.48),Vector2(-.30,.24),Vector2(-.15,.05),Vector2(.08,0),Vector2(.29,.12),Vector2(.08,.14),Vector2(-.03,.28),Vector2(-.02,.46),Vector2(.08,.61)]),.14,bright)
			for i in 3:star(s,Vector3((i-1)*.53,.34 if i==1 else .50,-1.02 if i==1 else -.91),.13 if i==1 else .19,base)
		"coral_reef":
			for i in 4:
				var a:=float(i)*TAU/4.0
				var points:=PackedVector2Array([Vector2(-.07,0),Vector2(-.08,.24),Vector2(-.28,.36),Vector2(-.31,.54),Vector2(-.20,.53),Vector2(-.18,.39),Vector2(-.06,.34),Vector2(-.06,.67),Vector2(.06,.67),Vector2(.06,.39),Vector2(.20,.47),Vector2(.23,.62),Vector2(.33,.59),Vector2(.29,.39),Vector2(.07,.25),Vector2(.07,0)])
				var p:=poly(s,Vector3(sin(a)*1.10,.13,cos(a)*1.10),points,.12,base if i%2==0 else bright);p.rotation.y=a
		"music_stage":
			for sign in [-1,1]:
				box(s,Vector3(sign*1.09,.35,0),Vector3(.29,.60,.37),base)
				for y in [.23,.48]:
					var speaker:=cone(s,Vector3(sign*1.09,y,.20),.105,.026,dark,.105);speaker.rotation.x=PI*.5
				box(s,Vector3(sign*.44,.56,-1.03),Vector3(.06,.52,.055),bright)
				var note:=cone(s,Vector3(sign*.37,.28,-1.03),.13,.07,bright,.13);note.rotation.x=PI*.5;note.scale.x=1.25
			box(s,Vector3(0,.80,-1.03),Vector3(.94,.08,.055),bright)
