extends "res://fidelity/art.gd"
## All 208 Blender assets participate in the playable city.
const Palette = preload("res://fidelity/palette.gdshader")
var catalog: Array = []
var by_kind: Dictionary = {}
var models: Dictionary = {}
var used_assets: Dictionary = {}
var citizens: Array[Dictionary] = []
var building_visuals: Array[Dictionary] = []
var signal_nodes: Array[Dictionary] = []
var ambient_actors: Array[Dictionary] = []
var authored_actor_types: Array = []
var recipe_actors: Array[Dictionary] = []
var moving_vehicles: Array[Dictionary] = []
var actor_district_colors: Dictionary = {}
var actor_layout_source: String = "local_recipe"
const AMBIENT_KINDS:= ["CourierDrone","StreetBot","SkyMote","TransitBeacon"]
const BUILDING_TINTS:= [Color("d7775d"),Color("d0b36e"),Color("6f9fb0"),Color("a783b5"),Color("6fa77f"),Color("cf7c9a")]

func read_catalog() -> void:
	if not catalog.is_empty():return
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_kit/manifest.json"))
	catalog=data.assets
	for entry in catalog:
		if not by_kind.has(entry.kind):by_kind[entry.kind]=[]
		by_kind[entry.kind].append(entry)
		models[entry.id]=load(entry.path)

func asset(kind:String, variant:int=0) -> Dictionary:
	return by_kind[kind][variant%by_kind[kind].size()]

func signal_pylon(at:Vector2, tint:Color, index:int) -> void:
	var root:=Node3D.new()
	root.name="SignalPylon_%02d"%index
	add_child(root)
	root.position=Vector3(at.x,0,at.y)
	cylinder(root,Vector3(0,.35,0),.65,.18,Color("192c4c"))
	cylinder(root,Vector3(0,1.35,0),.12,2.1,Color("344b74"))
	var orb:=sphere(root,Vector3(0,2.55,0),.3,tint,1.0)
	var ring:=cylinder(root,Vector3(0,2.18,0),.56,.035,Color("3b73a8"))
	var orb_mat:StandardMaterial3D=material(tint).duplicate()
	orb_mat.emission_enabled=true
	orb_mat.emission=tint
	orb_mat.emission_energy_multiplier=3.0
	orb.material_override=orb_mat
	var light:=OmniLight3D.new()
	light.light_color=tint
	light.omni_range=5.0
	light.light_energy=.6
	light.position=Vector3(0,2.4,0)
	root.add_child(light)
	signal_nodes.append({"root":root,"orb":orb,"ring":ring,"light":light,"phase":float(index)*1.7})

func ambient_actor(at:Vector2, index:int) -> void:
	var root:=Node3D.new()
	var kind:String=AMBIENT_KINDS[index%AMBIENT_KINDS.size()]
	var tint:Color=[Color("4dd9ff"),Color("ff8a6b"),Color("b58cff"),Color("ffd166")][index%4]
	root.name="AmbientActor_%03d"%index
	root.position=Vector3(at.x,.24+float(index%3)*.08,at.y)
	add_child(root)
	if kind=="CourierDrone":
		cylinder(root,Vector3.ZERO,.24,.12,Color("202f55"))
		box(root,Vector3(0,.04,0),Vector3(.7,.05,.12),tint)
		box(root,Vector3(0,.04,0),Vector3(.12,.05,.7),tint)
		sphere(root,Vector3(0,.16,0),.12,tint,.7)
	elif kind=="StreetBot":
		box(root,Vector3(0,.38,0),Vector3(.38,.7,.3),Color("314052"))
		box(root,Vector3(0,.78,0),Vector3(.3,.22,.28),tint)
		cylinder(root,Vector3(-.16,.12,0),.08,.22,Color("263141"))
		cylinder(root,Vector3(.16,.12,0),.08,.22,Color("263141"))
	else:
		cylinder(root,Vector3(0,.18,0),.13,.36,Color("263756"))
		var orb:=sphere(root,Vector3(0,.46,0),.13,tint,1.0)
		var orb_mat:StandardMaterial3D=material(tint).duplicate()
		orb_mat.emission_enabled=true
		orb_mat.emission=tint
		orb_mat.emission_energy_multiplier=2.0
		orb.material_override=orb_mat
		if kind=="TransitBeacon":cylinder(root,Vector3(0,.68,0),.28,.025,tint)
	ambient_actors.append({"root":root,"origin":root.position,"phase":float(index)*.41,"kind":kind,"speed":.45+float(index%5)*.07})

func world_actor_count() -> int:
	return citizens.size()+ambient_actors.size()+signal_nodes.size()+recipe_actors.size()

func authored_actor_type_count() -> int:
	return authored_actor_types.size()

func actor_tint(district:String, tone:String) -> Color:
	var base:Color=actor_district_colors.get(district,Color("6edcff"))
	if tone=="accent":return base.lightened(.18)
	if tone=="light":return base.lightened(.48)
	if tone=="dark":return base.darkened(.48)
	if tone=="metal":return Color("52627a").lerp(base,.28)
	if tone=="wood":return Color("9e7658").lerp(base,.12)
	if tone=="brick":return Color("a8574c").lerp(base,.22)
	if tone=="leaf":return Color("61aa7b").lerp(base,.28)
	if tone=="stone":return Color("818895").lerp(base,.20)
	if tone=="bread":return Color("d79a57").lerp(base,.12)
	return base.darkened(.18)

func building_dressing(body:RigidBody3D, extent:Vector3, style:int) -> void:
	var accent:Color=BUILDING_TINTS[style%BUILDING_TINTS.size()]
	var trim:Color=accent.lightened(.28)
	var front:float=extent.z*.5+.06
	# Add a readable authored silhouette over each imported model. The styles
	# rotate between bands, balconies, fins and roof crowns.
	if style%3==0:
		for y in [-extent.y*.28,0.0,extent.y*.28]:
			box(body,Vector3(0,y,front),Vector3(extent.x*.86,.12,.09),trim)
		box(body,Vector3(-extent.x*.28,extent.y*.20,front+.08),Vector3(.13,extent.y*.56,.12),accent.darkened(.22))
	elif style%3==1:
		for y in [-extent.y*.16,extent.y*.12]:
			box(body,Vector3(0,y,front+.08),Vector3(extent.x*.72,.10,.14),Color("e8dbc0"))
		for y in [-extent.y*.22,extent.y*.08,extent.y*.38]:
			box(body,Vector3(extent.x*.28,y,front+.12),Vector3(extent.x*.32,.08,.30),accent)
	else:
		for x in [-extent.x*.32,extent.x*.32]:
			box(body,Vector3(x,0,front+.08),Vector3(.16,extent.y*.78,.13),trim)
		box(body,Vector3(0,extent.y*.40,front+.12),Vector3(extent.x*.58,.16,.34),accent.darkened(.18))
	box(body,Vector3(0,extent.y*.50+.16,0),Vector3(extent.x*.24,.18,extent.z*.24),accent)
	if style%2==0:cylinder(body,Vector3(0,extent.y*.50+.52,0),.045,.72,trim)

func add_traffic(entry:Dictionary, at:Vector2, angle:float, index:int) -> void:
	var body:=place(entry,at,angle)
	body.set_meta("traffic",true)
	moving_vehicles.append({"body":body,"axis":"x" if index%2==0 else "z","direction":1.0 if index%4<2 else -1.0,"speed":2.0+float(index%4)*.38,"min":-48.0,"max":48.0,"lane":at.y if index%2==0 else at.x,"phase":float(index)*1.7})

func build_recipe_actor(entry:Dictionary, index:int) -> void:
	var root:=Node3D.new()
	root.name="AuthoredActor_%03d_%s"%[index,entry.id]
	var at:Array=entry.position
	root.position=Vector3(float(at[0]),0.0,float(at[1]))
	root.set_meta("actor_type",entry.name)
	add_child(root)
	var motions:Array[Dictionary]=[]
	var parts:Array=entry.parts
	for part in parts:
		var size:Array=part.size
		var pos:Array=part.position
		var tint:=actor_tint(entry.district,part.tone)
		var visual:MeshInstance3D
		if part.shape=="box":
			visual=box(root,Vector3(pos[0],pos[1],pos[2]),Vector3(size[0],size[1],size[2]),tint)
		elif part.shape=="cylinder":
			visual=cylinder(root,Vector3(pos[0],pos[1],pos[2]),float(size[0]),float(size[1]),tint)
		elif part.shape=="cone":
			visual=cylinder(root,Vector3(pos[0],pos[1],pos[2]),float(size[0])*.5,float(size[1]),tint,float(size[0])*.12)
		else:
			visual=sphere(root,Vector3(pos[0],pos[1],pos[2]),float(size[0]),tint,float(size[1])/maxf(.01,float(size[0])))
		var rotation:Array=part.rotation
		visual.rotation=Vector3(rotation[0],rotation[1],rotation[2])
		var motion:String=part.motion
		if motion!="none":motions.append({"node":visual,"motion":motion,"base":visual.rotation,"phase":float(motions.size())*.43})
	recipe_actors.append({"root":root,"motions":motions,"phase":float(index)*.17,"speed":.45+float(index%7)*.06})

func place(entry:Dictionary, at:Vector2, angle:float=0.0) -> RigidBody3D:
	var size_data:Array=entry.size
	var extent:=Vector3(size_data[0],size_data[1],size_data[2])
	var category:String=entry.group
	if category=="prop":category=entry.kind
	if category=="plant":category="tree"
	var points:int=35 if category=="building" else 7 if category=="vehicle" else 3 if category=="tree" else 1
	var body:=_food(at,extent,category,points)
	if category=="person":
		# Residents are animated actors, not loose rigid bodies. Keep them out of
		# the swallow field so a passing hole cannot knock the city population over.
		body.set_meta("resident",true)
		body.freeze=true
		body.lock_rotation=true
		body.collision_layer=0
		body.collision_mask=0
	body.rotation.y=angle
	body.set_meta("asset_id",entry.id)
	used_assets[entry.id]=true
	var visual:Node3D=models[entry.id].instantiate()
	visual.name="Model"
	body.add_child(visual)
	visual.position=-Vector3(entry.center[0],entry.center[1],entry.center[2])
	var opaque:=StandardMaterial3D.new()
	opaque.vertex_color_use_as_albedo=true
	opaque.roughness=.78
	for mesh in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=opaque
	if category=="building":
		var mat:=ShaderMaterial.new()
		mat.shader=Palette
		var style:int=building_visuals.size()%BUILDING_TINTS.size()
		body.set_meta("fracture_tint",BUILDING_TINTS[style])
		mat.set_shader_parameter("building_tint",BUILDING_TINTS[style])
		mat.set_shader_parameter("tint_amount",.28)
		for mesh in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		building_dressing(body,extent,style)
		building_visuals.append({"body":body,"mat":mat,"half":Vector2(extent.x,extent.z)*.5,"style":style})
	if category=="person":
		var anim:AnimationPlayer=visual.find_child("AnimationPlayer",true,false)
		var special:String=entry.animations[3] if entry.animations.size()>3 else "Walk"
		if anim:
			for clip in anim.get_animation_list():
				if clip!="RESET":anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
			anim.play("Idle")
		citizens.append({"body":body,"anim":anim,"origin":body.position,"phase":rng.randf_range(0,TAU),"clip":"Idle","special":special,"kind":entry.kind})
	return body

func build(owner_game:Node) -> void:
	game=owner_game
	rng.seed=20260925
	read_catalog()
	var recipe_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_actors/recipes.json"))
	authored_actor_types=recipe_data.actors
	for district in recipe_data.districts:actor_district_colors[district.id]=Color(district.color)
	# The local Houdini HOM bridge owns spatial layout while the recipe JSON keeps
	# the deterministic actor definitions portable for headless and mobile runs.
	var layout_path:="res://assets/world_actors/houdini_layout.json"
	if FileAccess.file_exists(layout_path):
		var layout_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		var layout_actors:Array=layout_data.get("actors",[])
		for i in mini(authored_actor_types.size(),layout_actors.size()):
			var layout_entry:Dictionary=layout_actors[i]
			if layout_entry.has("position"):
				authored_actor_types[i]["position"]=layout_entry.position
		actor_layout_source="houdini_hom"
	var buildings:Array=catalog.filter(func(e:Dictionary):return e.group=="building")
	var b:=0
	for z in [1.0,-21.0]:
		for i in 9:
			place(buildings[b],Vector2(-21.6+i*5.5,z));b+=1
	for x in [-40.0,40.0]:
		for z in [-30.0,-15.0,0.0,16.0,31.0]:
			place(buildings[b],Vector2(x,z),PI/2);b+=1
	for z in [-44.0,44.0]:
		for i in 10:
			place(buildings[b],Vector2(-33.0+i*7.2,z));b+=1
	var starting:=["school_bus","sedan","police","pickup","sedan","hatchback","taxi","delivery_van","sedan"]
	for i in starting.size():place(asset(starting[i],i%4),Vector2(-16.5+i*3.7,11),PI)
	var vehicles:Array=catalog.filter(func(e:Dictionary):return e.group=="vehicle")
	for i in vehicles.size():
		var row:int=i/8
		var at:=Vector2(-18.0+(i%8)*5.0,-35.0) if row==0 else Vector2(-18.0+(i%8)*5.0,-8.0) if row==1 else Vector2(-27 if row==2 else 29,-36.0+(i%8)*10)
		place(vehicles[i],at,0 if row<2 else PI/2)
	# A small traffic loop keeps the streets alive while the parking rows remain
	# edible and static. Cars pause near the player and wrap at the city edge.
	for i in 8:
		var lane:float=[-35.0,-8.0,11.0,29.0][i%4]
		var at:=Vector2(-44.0 if i%2==0 else 44.0,lane) if i%2==0 else Vector2(lane,-44.0)
		var entry:Dictionary=vehicles[(i+5)%vehicles.size()]
		add_traffic(entry,at,0.0 if i%2==0 else PI/2,i)
	# Reference parking court: small food is reachable immediately at level one.
	for i in 22:
		place(asset("cone",i),Vector2(-18.5+i*1.8,16.2))
		place(asset("bin",i),Vector2(-18.5+i*1.8,36.8))
	for i in 28:
		var x:float=[-22.0,23.0,-32.0,34.0][i/7]
		var z:float=[-36.0,-25.0,-12.0,5.0,18.0,29.0,38.0][i%7]
		place(asset("lamp",i),Vector2(x,z))
		place(asset("bin",i),Vector2(x+.8,z+1.5))
	# Every street-furniture variant is a separate usable asset in a sidewalk row.
	var props:Array=catalog.filter(func(e:Dictionary):return e.group=="prop")
	for i in props.size():
		var x:float=-19.0+(i%16)*2.5
		var z:float=[5.8,-16.2,32.5,-28.0][i/16]
		place(props[i],Vector2(x,z))
	var plants:Array=catalog.filter(func(e:Dictionary):return e.group=="plant")
	for i in plants.size():
		var at:=Vector2(18.4+(i%3)*2.25,19+(i/3)*2.35) if i<24 else Vector2(-19+(i%12)*2.9,-39.5+(i/12-2)*2.3)
		place(plants[i],at)
	var pylon_places:=[Vector2(-27,7),Vector2(2,27),Vector2(28,-8),Vector2(-12,-30),Vector2(31,30)]
	var pylon_colors:=[Color("41d9ff"),Color("c87cff"),Color("5df0b6"),Color("ffbd58"),Color("ff6db6")]
	for i in pylon_places.size():signal_pylon(pylon_places[i],pylon_colors[i],i)
	# Lightweight non-physical actors add a living layer without making the
	# swallow simulation carry another 48 rigid bodies.
	for i in 48:
		var actor_at:=Vector2(-34.0+float(i%12)*6.2,-34.0+float(i/12)*18.0+(i%2)*1.4)
		# Break the backdrop grid into loose clusters while keeping every actor
		# inside the authored street bounds.
		actor_at+=Vector2(rng.randf_range(-1.8,1.8),rng.randf_range(-1.35,1.35))
		if i%5==0:actor_at.x+=1.6
		ambient_actor(actor_at,i)
	for i in authored_actor_types.size():build_recipe_actor(authored_actor_types[i],i)
	box(self,Vector3(20.8,.015,27.3),Vector3(7.3,.04,20),Color("85b82e"))
	box(self,Vector3(-2.8,.015,-38.2),Vector3(36,.04,5.4),Color("85b82e"))
	var figures:Array=catalog.filter(func(e:Dictionary):return e.group=="person")
	# People gather around several sidewalk pockets instead of spawning on one
	# mathematical row. Each pocket gets a small 2D wander radius below.
	var pedestrian_pockets:Array[Vector2]=[
		Vector2(-16.0,6.4),Vector2(-4.5,6.8),Vector2(7.0,6.2),Vector2(18.5,6.7),
		Vector2(-16.5,-15.8),Vector2(-5.0,-15.2),Vector2(7.5,-16.2),Vector2(19.0,-15.5),
		Vector2(-16.0,31.5),Vector2(-4.5,32.2),Vector2(7.0,31.3),Vector2(18.5,32.0),
		Vector2(-15.5,-28.0),Vector2(-3.5,-27.4),Vector2(8.5,-28.1),Vector2(20.0,-27.5)
	]
	for i in 64:
		var pocket:Vector2=pedestrian_pockets[i%pedestrian_pockets.size()]
		var lane:int=i/pedestrian_pockets.size()
		var at:=pocket+Vector2(rng.randf_range(-1.45,1.45),rng.randf_range(-1.05,1.05))
		at+=Vector2(float(lane%3)*.62,float((lane/2)%2)*.34)
		place(figures[i%16],at)
		var citizen_index:=citizens.size()-1
		var citizen:Dictionary=citizens[citizen_index]
		var citizen_body:RigidBody3D=citizen.body
		citizen_body.rotation.y=rng.randf_range(-PI,PI)
		citizen["wander_radius"]=Vector2(1.2+float((i+lane)%3)*.5,.55+float((i*2+lane)%3)*.28)
		citizen["wander_speed"]=.26+float(i%5)*.045
		citizen["wander_phase"]=rng.randf_range(0,TAU)
		citizen["rest_cycle"]=10.0+float(i%5)*2.4
		citizen["rest_window"]=1.4+float((i+lane)%4)*.65
		citizen["rest_offset"]=rng.randf_range(0,12.0)
		citizens[citizen_index]=citizen
	# Narrow edible park railings retain the gradual early growth path.
	for side in [16.8,24.9]:
		for i in 20:place(asset("fence",i),Vector2(side,18+i),PI/2)
	subway(Vector2(-18,-7.8));subway(Vector2(8,-34.7))
	for at in [Vector2(5,23),Vector2(13,31)]:
		var cover:=_food(at,Vector3(1.4,.16,2.3),"cover",2)
		box(cover,Vector3.ZERO,Vector3(1.4,.16,2.3),Color("41433d"))
	box(self,Vector3(0,-4.9,0),Vector3(103,3,103),Color("73644e"))
	box(self,Vector3(0,-6.7,0),Vector3(300,.2,300),Color("1e99f1"))

func _process(delta:float) -> void:
	if is_instance_valid(preview):
		preview.rotation.y+=delta*.10
		return
	if not is_instance_valid(game):return
	var thief:Dictionary={}
	for c in citizens:
		if c.kind=="thief" and is_instance_valid(c.body):thief=c;break
	for citizen in citizens:
		if not is_instance_valid(citizen.body):continue
		var body:RigidBody3D=citizen.body
		var anim:AnimationPlayer=citizen.anim
		if not is_instance_valid(anim):continue
		body.rotation.x=0.0
		body.rotation.z=0.0
		if is_instance_valid(body.claimed_by) or game.phase!="playing":
			anim.pause()
			continue
		var origin:Vector3=citizen.origin
		var panic:bool=body.position.distance_to(game.player.position)<game.player.radius+4.0
		var police_chase:bool=citizen.kind=="police" and not thief.is_empty() and body.position.distance_to(thief.body.position)<14.0
		var thief_escape:bool=citizen.kind=="thief" and not thief.is_empty() and body.position.distance_to(game.player.position)>0.0 and body.position.distance_to(game.player.position)<6.0
		var time:float=game.elapsed+citizen.phase
		var rest_cycle:float=float(citizen.get("rest_cycle",12.0))
		var rest_window:float=float(citizen.get("rest_window",3.0))
		var rest_offset:float=float(citizen.get("rest_offset",0.0))
		var resting:bool=fmod(time+rest_offset,rest_cycle)>rest_cycle-rest_window and not panic
		var clip:String="Idle" if resting else "Run" if panic else citizen.special
		if police_chase:clip="Chase"
		if thief_escape:clip="Sneak"
		if citizen.clip!=clip or not anim.is_playing():anim.play(clip,.18);citizen.clip=clip
		if not resting:
			var wander_radius:Vector2=citizen.get("wander_radius",Vector2(1.1,.55))
			var wander_speed:float=float(citizen.get("wander_speed",.36))
			var wander_phase:float=float(citizen.get("wander_phase",citizen.phase))
			var wander:=Vector2(sin(time*wander_speed+wander_phase)*wander_radius.x,sin(time*wander_speed*.71+wander_phase*1.37)*wander_radius.y)
			var destination:Vector3=origin+Vector3(wander.x,0,wander.y)
			if police_chase:destination=thief.body.position
			elif thief_escape:destination=origin+Vector3(-2.4 if body.position.x<game.player.position.x else 2.4,0,0)
			elif panic:destination=origin+Vector3(-1.65 if body.position.x<game.player.position.x else 1.65,0,0)
			var difference:Vector2=Vector2(destination.x-body.position.x,destination.z-body.position.z)
			var step:Vector2=difference.limit_length(delta*(2.1 if panic else .58))
			body.position.x+=step.x
			body.position.z+=step.y
			if step.length_squared()>.0001:body.rotation.y=lerp_angle(body.rotation.y,atan2(step.x,step.y),1-exp(-delta*10))
	for entry in building_visuals:
		if not is_instance_valid(entry.body):continue
		var offset:Vector3=game.player.position-entry.body.position
		var close:bool=absf(offset.x)<entry.half.x+2 and absf(offset.z)<entry.half.y+2
		# A collapsing facade stays solid; whole-building transparency can make
		# overlapping opaque roof details look like a vertical clipping plane.
		entry.mat.set_shader_parameter("visibility",.22 if close and not is_instance_valid(entry.body.claimed_by) else 1.0)
	for traffic in moving_vehicles:
		var body=traffic.get("body")
		if not is_instance_valid(body) or is_instance_valid(body.claimed_by):continue
		var gap:Vector2=Vector2(game.player.position.x-body.position.x,game.player.position.z-body.position.z)
		var blocked:bool=gap.length()<game.player.radius+3.0
		var step:float=0.0 if blocked else traffic.speed*traffic.direction*delta
		if traffic.axis=="x":
			body.position.x+=step
			if body.position.x>traffic.max:body.position.x=traffic.min
			elif body.position.x<traffic.min:body.position.x=traffic.max
			body.rotation.y=0.0 if traffic.direction>0 else PI
		else:
			body.position.z+=step
			if body.position.z>traffic.max:body.position.z=traffic.min
			elif body.position.z<traffic.min:body.position.z=traffic.max
			body.rotation.y=PI*.5 if traffic.direction>0 else -PI*.5
	for node in signal_nodes:
		if not is_instance_valid(node.root):continue
		var t:float=game.elapsed+node.phase
		node.root.rotation.y=t*.35
		node.orb.scale=Vector3.ONE*(1.0+sin(t*2.5)*.10)
		node.ring.rotation.y=-t*.9
		node.light.light_energy=.45+.25*(sin(t*2.0)+1.0)
	for actor in ambient_actors:
		if not is_instance_valid(actor.root):continue
		var t:float=game.elapsed+actor.phase
		var origin:Vector3=actor.origin
		var root:Node3D=actor.root
		if actor.kind=="CourierDrone":
			root.position=origin+Vector3(cos(t*actor.speed)*.8,sin(t*2.2)*.18,sin(t*actor.speed)*.8)
			root.rotation.y=t*1.7
		elif actor.kind=="StreetBot":
			root.position=origin+Vector3(sin(t*actor.speed)*1.1,0,0)
			root.rotation.y=PI/2 if cos(t*actor.speed)>0 else -PI/2
		elif actor.kind=="SkyMote":
			root.position=origin+Vector3(0,.35+sin(t*1.4)*.22,0)
			root.rotation.y=t*.8
		else:
			root.position=origin+Vector3(0,sin(t*.9)*.06,0)
			root.rotation.y=t*.45
	for actor in recipe_actors:
		if not is_instance_valid(actor.root):continue
		var t:float=game.elapsed+actor.phase
		for motion in actor.motions:
			var node:MeshInstance3D=motion.node
			if not is_instance_valid(node):continue
			var base:Vector3=motion.base
			var wave:float=sin(t*actor.speed+motion.phase)
			if motion.motion=="spin_y":node.rotation=base+Vector3(0,t*actor.speed,0)
			elif motion.motion.begins_with("spin_"):node.rotation=base+Vector3(0,t*actor.speed,0)
			elif motion.motion in ["bob","steam"]:node.position.y+=sin(t*1.6+motion.phase)*.06
			elif motion.motion in ["sway","rock","pump"]:node.rotation=base+Vector3(0,0,wave*.12)
			elif motion.motion in ["slide","sweep"]:node.position.x+=wave*.18
