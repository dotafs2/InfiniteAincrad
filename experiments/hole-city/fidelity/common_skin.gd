extends Node3D
## Authored Common geometry and bounded cosmetic feedback. No physics or rewards.
const Geometry=preload("res://fidelity/common_geometry.gd")
const Sculpt=preload("res://fidelity/skin_sculpt.gd")
const IDS=Geometry.IDS
const POOL_CAPACITY:=8
var skin_id:=""
var model_id:=""
var fx_profile:=""
var animated_root:Node3D
var particles:MultiMeshInstance3D
var active_count:=0
var rival_active:=false
var event_age:=0.0
var event_lifetime:=0.0
var item_events:=0
var rival_events:=0
var pulse_age:=1.0
var pulse_strength:=0.0
var color_a:=Color.WHITE
var color_b:=Color.WHITE
var _seed:=0

func build(s:Node3D)->void:
	skin_id=str(s.skin_id)
	model_id=str(s.get("model_id")) if s.get("model_id") != null else skin_id
	name="CommonSkin_"+skin_id
	var old_ring:MeshInstance3D=s.main_ring
	var geometry:Dictionary=Geometry.build(s,self)
	s.main_ring=geometry.main_ring
	animated_root=geometry.animated_root
	if is_instance_valid(old_ring):old_ring.free()
	fx_profile=profile_for(model_id)
	color_a=Color(s.tint);color_b=Color(s.accent)
	# Explicit material colors keep the burst recognizable even on a white street.
	match model_id:
		"cookie_bite":color_a=Color("d7a264");color_b=Color("613a28")
		"melon_munch":color_a=Color("302329");color_b=Color("e75665")
		"paper_boat":color_a=Color("f1eadd");color_b=Color("486383")
		"cocoa_square":color_a=Color("78879b");color_b=Color("cbd4de")
		"denim_pocket":color_a=Color("eee3c8");color_b=Color("466889")
		"paint_tin":color_a=Color("319c9d");color_b=Color("92dbd5")
		"enamel_basin":color_a=Color("649ade");color_b=Color("cee9ff")
	if int(s.get("variant_index"))>0:
		color_a=Color(s.tint);color_b=Color(s.accent)
	particles=MultiMeshInstance3D.new();particles.name="CommonBurstPool"
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.extra_cull_margin=.3
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true;batch.mesh=particle_mesh(fx_profile);batch.instance_count=POOL_CAPACITY
	batch.visible_instance_count=0
	particles.multimesh=batch
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.roughness=.38 if fx_profile=="juice" else .65
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	particles.material_override=mat
	add_child(particles);particles.visible=false
	set_meta("pool_capacity",POOL_CAPACITY)
	set_meta("feedback_profile",fx_profile)
	set_meta("cosmetic_only",true)
	set_process(false)

static func profile_for(id:String)->String:
	if id in ["citrus_slice","pancake_stack","paint_tin","enamel_basin"]:return "juice"
	if id=="melon_munch":return "seeds"
	if id in ["leaf_cup","shell_cup","acorn_cup"]:return "flakes"
	if id in ["paper_boat","woven_nest"]:return "flutter"
	if id in ["rope_coil","denim_pocket","knit_cap"]:return "fibers"
	if id in ["clay_pot","catchers_mitt"]:return "dust"
	return "crumbs"

static func particle_mesh(profile:String)->Mesh:
	match profile:
		"juice","seeds","dust":
			var drop:=SphereMesh.new();drop.radius=.45;drop.height=1.15 if profile!="dust" else .9
			drop.radial_segments=8;drop.rings=4
			return drop
		"flakes","flutter":
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var a:=Vector3(0,0,-.65);var b:=Vector3(-.42,0,0)
			var c:=Vector3(0,.16,.55);var d:=Vector3(.42,0,0)
			Sculpt.triangle(st,a,b,c,Vector3.UP,Vector3.UP,Vector3.UP)
			Sculpt.triangle(st,a,c,d,Vector3.UP,Vector3.UP,Vector3.UP)
			return st.commit()
		"fibers":
			# Short yarn flecks are only a few screen pixels; a six-face sliver
			# preserves the silhouette without spending a capsule per pool slot.
			var fiber:=BoxMesh.new();fiber.size=Vector3(.18,1.2,.18)
			return fiber
		_:
			var chip:=BoxMesh.new();chip.size=Vector3(.8,.5,.65)
			return chip

func absorb(is_rival:bool, _source_color:=Color.WHITE)->void:
	if is_rival:rival_events+=1
	else:item_events+=1
	# Dense item collection never erases an ongoing visible rival celebration.
	if rival_active and not is_rival:return
	rival_active=is_rival
	event_age=0.0;event_lifetime=.72 if is_rival else .25
	active_count=POOL_CAPACITY if is_rival else 2
	pulse_age=0.0;pulse_strength=1.0 if is_rival else .22
	_seed=(_seed+1)%31
	particles.multimesh.visible_instance_count=active_count
	particles.visible=true
	for i in active_count:
		particles.multimesh.set_instance_color(i,color_a if i%3!=1 else color_b)
	update_particles()

func advance(delta:float)->void:
	var step:=maxf(0.0,delta)
	pulse_age+=step
	if is_instance_valid(animated_root):
		var t:=clampf(pulse_age/.40,0.0,1.0)
		var bounce:=sin(t*TAU)*pow(1.0-t,1.5)*pulse_strength
		# Only expand XZ, so the model never intrudes into the gameplay opening.
		animated_root.scale=Vector3(1.0+absf(bounce)*.024,1.0-bounce*.16,1.0+absf(bounce)*.024)
		animated_root.position.y=maxf(0.0,-bounce)*.025
	if active_count==0:return
	event_age+=step
	if event_age>=event_lifetime:
		active_count=0;rival_active=false
		particles.multimesh.visible_instance_count=0;particles.visible=false
		return
	update_particles()

func update_particles()->void:
	var u:=clampf(event_age/maxf(.001,event_lifetime),0.0,1.0)
	var fade:=1.0-smoothstep(.55,1.0,u)
	var strength:=1.0 if rival_active else .40
	for i in active_count:
		var angle:=float(i)*TAU/float(active_count)+float(_seed)*.13
		# Sideward trajectories spread outside the rim instead of behind the label.
		var twist:=sin(u*PI)*.60 if fx_profile in ["flakes","flutter","fibers"] else 0.0
		var radius:=1.28+(u*(1.00+float(i%3)*.10))*strength
		var y:=.16+sin(u*PI)*(.30+float(i%3)*.045)*strength
		if fx_profile=="juice":
			radius=1.28+u*1.22*strength
			y=.15+sin(u*PI)*.36*strength
		elif fx_profile=="dust":
			y=.14+sin(u*PI)*.16*strength
		elif fx_profile=="crumbs":
			y+=absf(sin(u*TAU))*.075*strength
		var size:float=(.19+float(i%3)*.025)*strength*fade
		var shape:=Vector3.ONE
		if fx_profile=="seeds":shape=Vector3(.62,1.25,.48)
		if fx_profile=="juice":shape=Vector3(.65,1.15,.65)
		if fx_profile=="dust":shape=Vector3(1.2,.55,1.2)
		var turn:=Vector3(.5+u*3.0,angle+twist,float(i)*.8+u*2.5)
		var pose:=Transform3D(Basis.from_euler(turn).scaled(shape*size),Vector3(sin(angle+twist)*radius,y,cos(angle+twist)*radius))
		particles.multimesh.set_instance_transform(i,pose)
