extends RefCounted
## Six original, closed-surface collectibles. No textures, particles or physics.
## Profiles describe real rounded volume; normals follow that volume so existing
## preview/world lights provide highlights instead of painted bright stripes.
const IDS:Array[String]=["pizza_party","frosted_cake","fox_den","bunny_burrow","rocket_port","dragon_roost"]

static func finish(color:Color,roughness:=.34,metallic:=0.0)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color;mat.roughness=roughness;mat.metallic=metallic
	mat.metallic_specular=.55
	mat.clearcoat_enabled=true;mat.clearcoat=.22;mat.clearcoat_roughness=.3
	return mat

static func triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,na:Vector3,nb:Vector3,nc:Vector3)->void:
	if (b-a).cross(c-a).length_squared()<1e-14:return
	var points:Array[Vector3]=[a,b,c];var normals:Array[Vector3]=[na,nb,nc]
	if (b-a).cross(c-a).dot(na+nb+nc)>0:
		points=[a,c,b];normals=[na,nc,nb]
	for i in 3:
		st.set_normal(normals[i].normalized());st.set_uv(Vector2(points[i].x,points[i].y));st.add_vertex(points[i])

static func lathe(profile:Array[Vector2],segments:=32,scallop:=0.0)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for j in profile.size():
			var p:Array[Vector3]=[];var n:Array[Vector3]=[]
			for ij in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,(j+1)%profile.size()),Vector2i(i,(j+1)%profile.size())]:
				var q:Vector2=profile[ij.y];var angle:=TAU*float(ij.x%segments)/segments
				var prev:Vector2=profile[(ij.y-1+profile.size())%profile.size()]
				var next:Vector2=profile[(ij.y+1)%profile.size()]
				var tangent:Vector2=(q-prev).normalized()+(next-q).normalized()
				var normal:=Vector2(tangent.y,-tangent.x).normalized()
				var wave:float=scallop*sin(angle*8.0)
				p.append(Vector3(sin(angle)*q.x,q.y+wave,cos(angle)*q.x))
				var slope:float=-normal.y*scallop*8.0*cos(angle*8.0)/maxf(.001,q.x)
				n.append(Vector3(sin(angle)*normal.x+cos(angle)*slope,normal.y,cos(angle)*normal.x-sin(angle)*slope).normalized())
			triangle(st,p[0],p[1],p[2],n[0],n[1],n[2]);triangle(st,p[0],p[2],p[3],n[0],n[2],n[3])
	return st.commit()

static func cushion_mesh()->ArrayMesh:
	# Closed ellipsoid profile, not an orbiting sphere emitter.
	return lathe([Vector2(0,-1),Vector2(.59,-.81),Vector2(.95,-.31),Vector2(.95,.31),Vector2(.59,.81),Vector2(0,1)],12)

static func bevel(points:Array[Vector2],depth:float)->ArrayMesh:
	# Convex/concave authored outlines, with an inset cap and a bevel shoulder.
	points=points.duplicate()
	var area:=0.0
	for i in points.size():area+=points[i].cross(points[(i+1)%points.size()])
	if area<0:points.reverse()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center:=Vector2.ZERO
	for p in points:center+=p
	center/=points.size()
	var inset:=PackedVector2Array()
	for p in points:inset.append(center+(p-center)*.80)
	var cap:=Geometry2D.triangulate_polygon(inset)
	for sign in [-1.0,1.0]:
		for i in range(0,cap.size(),3):
			var a:Vector2=inset[cap[i]];var b:Vector2=inset[cap[i+1]];var c:Vector2=inset[cap[i+2]]
			var n:=Vector3(0,0,sign)
			triangle(st,Vector3(a.x,a.y,sign*depth*.5),Vector3(b.x,b.y,sign*depth*.5),Vector3(c.x,c.y,sign*depth*.5),n,n,n)
	var zlevels:Array[float]=[-depth*.5,-depth*.27,depth*.27,depth*.5]
	for row in 3:
		for i in points.size():
			var vertices:Array[Vector3]=[];var normals:Array[Vector3]=[]
			for ij in [Vector2i(i,row),Vector2i((i+1)%points.size(),row),Vector2i((i+1)%points.size(),row+1),Vector2i(i,row+1)]:
				var q:Vector2=inset[ij.x] if ij.y in [0,3] else points[ij.x]
				var tangent:Vector2=(points[(ij.x+1)%points.size()]-points[(ij.x-1+points.size())%points.size()]).normalized()
				var side:=Vector3(tangent.y,-tangent.x,0)
				var normal:Vector3=side+Vector3(0,0,[-1.0,-.35,.35,1.0][ij.y])
				vertices.append(Vector3(q.x,q.y,zlevels[ij.y]));normals.append(normal.normalized())
			triangle(st,vertices[0],vertices[1],vertices[2],normals[0],normals[1],normals[2]);triangle(st,vertices[0],vertices[2],vertices[3],normals[0],normals[2],normals[3])
	return st.commit()

static func piece(s:Node3D,name:String,mesh:Mesh,at:Vector3,mat:Material,scale:=Vector3.ONE,rotation:=Vector3.ZERO)->MeshInstance3D:
	var part:MeshInstance3D=s.mesh_part(s.ornaments,mesh,at,mat)
	part.name=name;part.scale=scale;part.rotation=rotation
	part.set_meta("sculpted",true)
	return part

static func rim(s:Node3D,name:String,mat:Material,height:=.22,outer:=1.22)->void:
	piece(s,name,lathe([Vector2(.97,.06),Vector2(outer-.05,.035),Vector2(outer,.09),Vector2(outer,height-.04),Vector2(outer-.05,height),Vector2(1.03,height+.018),Vector2(.965,height-.04),Vector2(.95,.10)]),Vector3.ZERO,mat)

static func build(s:Node3D)->void:
	var base:=finish(s.tint);var bright:=finish(s.accent,.25)
	var cream:=finish(Color("fff4dd"),.39);var dark:=finish(Color("292f47"),.28)
	var pink:=finish(Color("ff8fb5"),.34);var green:=finish(Color("4daf62"),.45)
	var soft:=cushion_mesh()
	s.set_meta("polish_revision",1)
	match s.model_id:
		"pizza_party":
			rim(s,"ToastedCrust",finish(Color("d98136"),.46),.235,1.26)
			piece(s,"MeltedCheese",lathe([Vector2(.98,.17),Vector2(1.20,.18),Vector2(1.23,.23),Vector2(1.18,.29),Vector2(1.01,.28),Vector2(.97,.23)],32,.008),Vector3.ZERO,base)
			for i in 5:
				var a:=float(i)*TAU/5+.24
				piece(s,"Pepperoni%d"%i,soft,Vector3(sin(a)*1.10,.30,cos(a)*1.10),bright,Vector3(.13,.025,.14))
			var leaf:=bevel([Vector2(-.12,0),Vector2(-.08,-.15),Vector2(.04,-.20),Vector2(.12,-.02),Vector2(.06,.15),Vector2(-.04,.16)],.05)
			for i in 3:
				var a:=float(i)*TAU/3+.8
				piece(s,"Basil%d"%i,leaf,Vector3(sin(a)*1.11,.32,cos(a)*1.11),green,Vector3.ONE,Vector3(PI/2,a,0))
		"frosted_cake":
			rim(s,"BakedSponge",finish(Color("e8b876"),.48),.36,1.22)
			piece(s,"BerryFilling",lathe([Vector2(.97,.15),Vector2(1.225,.15),Vector2(1.23,.20),Vector2(.97,.20)]),Vector3.ZERO,finish(Color("c44975"),.4))
			piece(s,"ScallopedIcing",lathe([Vector2(.965,.30),Vector2(1.24,.30),Vector2(1.255,.39),Vector2(1.19,.45),Vector2(1.025,.45),Vector2(.96,.39)],32,.027),Vector3.ZERO,bright)
			for i in 3:
				var a:=float(i)*TAU/3+PI
				piece(s,"Strawberry%d"%i,soft,Vector3(sin(a)*1.10,.53,cos(a)*1.10),base,Vector3(.145,.18,.14),Vector3(0,0,.16))
				var leaf:=bevel([Vector2(-.14,0),Vector2(-.04,-.06),Vector2(.04,-.12),Vector2(.065,-.02),Vector2(.14,.06),Vector2(.015,.055),Vector2(-.08,.12)],.04)
				piece(s,"BerryLeaf%d"%i,leaf,Vector3(sin(a)*1.1,.70,cos(a)*1.1),green,Vector3(.85,1,.85),Vector3(PI/2,a,0))
		"fox_den":
			rim(s,"FoxMask",base,.28,1.22)
			var ear:=bevel([Vector2(-.22,0),Vector2(-.20,.21),Vector2(-.10,.63),Vector2(.02,.71),Vector2(.14,.49),Vector2(.21,.14),Vector2(.19,0)],.23)
			for sign in [-1.0,1.0]:
				piece(s,"FoxEar"+("Left" if sign<0 else "Right"),ear,Vector3(sign*.71,.20,-.91),base,Vector3.ONE,Vector3(0,sign*.22,-sign*.19))
				piece(s,"EarInset"+("Left" if sign<0 else "Right"),ear,Vector3(sign*.71,.26,-.78),dark,Vector3(.53,.64,.28),Vector3(0,sign*.22,-sign*.19))
				piece(s,"Cheek"+("Left" if sign<0 else "Right"),soft,Vector3(sign*.52,.22,.94),cream,Vector3(.30,.105,.19),Vector3(0,sign*.4,0))
				piece(s,"Eye"+("Left" if sign<0 else "Right"),soft,Vector3(sign*.43,.37,.99),dark,Vector3(.047,.064,.033),Vector3(-.65,0,-sign*.12))
			piece(s,"FoxNose",bevel([Vector2(-.105,.05),Vector2(-.055,-.065),Vector2(.055,-.065),Vector2(.105,.05)],.08),Vector3(0,.25,1.125),dark,Vector3.ONE,Vector3(-.65,0,0))
		"bunny_burrow":
			rim(s,"PorcelainBunny",base,.29,1.20)
			var ear:=bevel([Vector2(-.17,0),Vector2(-.20,.46),Vector2(-.16,.79),Vector2(-.07,.91),Vector2(.07,.91),Vector2(.15,.78),Vector2(.16,.45),Vector2(.13,0)],.20)
			for sign in [-1.0,1.0]:
				var lean:= -.16 if sign<0 else .27
				var height:=.91 if sign<0 else .77
				piece(s,"RabbitEar"+("Left" if sign<0 else "Right"),ear,Vector3(sign*.61,.18,-1.0),base,Vector3(1,height,1),Vector3(0,0,lean))
				piece(s,"PinkEar"+("Left" if sign<0 else "Right"),ear,Vector3(sign*.61,.24,-.887),pink,Vector3(.49,height*.76,.25),Vector3(0,0,lean))
				piece(s,"BunnyCheek"+("Left" if sign<0 else "Right"),soft,Vector3(sign*.49,.26,1.01),bright,Vector3(.19,.065,.09))
				piece(s,"BunnyEye"+("Left" if sign<0 else "Right"),soft,Vector3(sign*.35,.38,1.02),dark,Vector3(.041,.064,.033),Vector3(-.6,0,0))
			piece(s,"BunnyNose",soft,Vector3(0,.26,1.12),pink,Vector3(.075,.043,.04))
		"rocket_port":
			rim(s,"LaunchDock",finish(Color("4b6c94"),.31,.18),.20,1.22)
			var body:=lathe([Vector2(0,-.36),Vector2(.14,-.36),Vector2(.205,-.27),Vector2(.215,.21),Vector2(.18,.37),Vector2(.10,.49),Vector2(0,.54)],20)
			piece(s,"RoundedRocket",body,Vector3(0,.60,-1.06),base,Vector3(1,.82,1))
			var fin:=bevel([Vector2(0,0),Vector2(.26,-.08),Vector2(.29,.02),Vector2(.14,.27),Vector2(0,.38)],.14)
			for sign in [-1.0,1.0]:
				piece(s,"SweptFin"+("Left" if sign<0 else "Right"),fin,Vector3(sign*.14,.21,-1.07),bright,Vector3.ONE,Vector3(0,0 if sign>0 else PI,0))
			piece(s,"PortholeRim",soft,Vector3(0,.67,-.855),bright,Vector3(.133,.143,.065))
			piece(s,"PortholeGlass",soft,Vector3(0,.67,-.806),finish(Color("37c8df"),.17,.12),Vector3(.092,.10,.025))
			piece(s,"EngineNozzle",lathe([Vector2(.065,0),Vector2(.16,0),Vector2(.18,.08),Vector2(.08,.12)],16),Vector3(0,.20,-1.06),dark)
			for i in 3:
				var a:=float(i)*TAU/3+.8
				piece(s,"DockBolt%d"%i,soft,Vector3(sin(a)*1.10,.225,cos(a)*1.10),bright,Vector3(.085,.045,.085))
		"dragon_roost":
			rim(s,"DragonCoil",base,.26,1.21)
			var wing:=bevel([Vector2(0,0),Vector2(-.07,.28),Vector2(.08,.66),Vector2(.21,.76),Vector2(.39,.64),Vector2(.65,.36),Vector2(.58,.24),Vector2(.41,.29),Vector2(.34,.12),Vector2(.18,.18)],.18)
			for sign in [-1.0,1.0]:
				piece(s,"DragonWing"+("Left" if sign<0 else "Right"),wing,Vector3(sign*.63,.15,-.83),base,Vector3(.95,1,1),Vector3(0,0 if sign>0 else PI,0))
				piece(s,"WingMembrane"+("Left" if sign<0 else "Right"),wing,Vector3(sign*.665,.23,-.724),bright,Vector3(.65,.65,.20),Vector3(0,0 if sign>0 else PI,0))
				var horn:=lathe([Vector2(0,0),Vector2(.085,0),Vector2(.075,.14),Vector2(.045,.26),Vector2(0,.36)],12)
				piece(s,"IvoryHorn"+("Left" if sign<0 else "Right"),horn,Vector3(sign*.39,.22,-1.05),cream,Vector3.ONE,Vector3(-.20,0,sign*.14))
				piece(s,"DragonEye"+("Left" if sign<0 else "Right"),soft,Vector3(sign*.40,.34,1.01),bright,Vector3(.09,.05,.045))
				piece(s,"SlitPupil"+("Left" if sign<0 else "Right"),soft,Vector3(sign*.40,.36,1.045),dark,Vector3(.016,.036,.018))
