extends "res://fidelity/art.gd"
## All 208 Blender assets participate in the playable city.
const Palette = preload("res://fidelity/palette.gdshader")
var catalog: Array = []
var by_kind: Dictionary = {}
var models: Dictionary = {}
var used_assets: Dictionary = {}
var citizens: Array[Dictionary] = []
var building_visuals: Array[Dictionary] = []

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

func place(entry:Dictionary, at:Vector2, angle:float=0.0) -> RigidBody3D:
	var size_data:Array=entry.size
	var extent:=Vector3(size_data[0],size_data[1],size_data[2])
	var category:String=entry.group
	if category=="prop":category=entry.kind
	if category=="plant":category="tree"
	var points:int=35 if category=="building" else 7 if category=="vehicle" else 3 if category=="tree" else 1
	var body:=_food(at,extent,category,points)
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
		for mesh in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		building_visuals.append({"body":body,"mat":mat,"half":Vector2(extent.x,extent.z)*.5})
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
	box(self,Vector3(20.8,.015,27.3),Vector3(7.3,.04,20),Color("85b82e"))
	box(self,Vector3(-2.8,.015,-38.2),Vector3(36,.04,5.4),Color("85b82e"))
	var figures:Array=catalog.filter(func(e:Dictionary):return e.group=="person")
	for i in 64:
		var at:=Vector2(-20+(i%16)*2.65,[7.8,-13.8,30.3,39.8][i/16])
		place(figures[i%16],at)
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
		if is_instance_valid(body.claimed_by) or game.phase!="playing":
			anim.pause()
			continue
		var origin:Vector3=citizen.origin
		var panic:bool=body.position.distance_to(game.player.position)<game.player.radius+4.0
		var police_chase:bool=citizen.kind=="police" and not thief.is_empty() and body.position.distance_to(thief.body.position)<14.0
		var thief_escape:bool=citizen.kind=="thief" and not thief.is_empty() and body.position.distance_to(game.player.position)>0.0 and body.position.distance_to(game.player.position)<6.0
		var time:float=game.elapsed+citizen.phase
		var resting:bool=fmod(time,12.0)>9.0 and not panic
		var clip:String="Idle" if resting else "Run" if panic else citizen.special
		if police_chase:clip="Chase"
		if thief_escape:clip="Sneak"
		if citizen.clip!=clip or not anim.is_playing():anim.play(clip,.18);citizen.clip=clip
		if not resting:
			var destination:float=origin.x+sin(time*.38)*1.15
			if police_chase:destination=thief.body.position.x
			elif thief_escape:destination=origin.x+(-2.4 if body.position.x<game.player.position.x else 2.4)
			elif panic:destination=origin.x+(-1.65 if body.position.x<game.player.position.x else 1.65)
			var step:float=clampf(destination-body.position.x,-delta*(2.1 if panic else .58),delta*(2.1 if panic else .58))
			body.position.x+=step
			if absf(step)>.0001:body.rotation.y=lerp_angle(body.rotation.y,PI/2 if step>0 else -PI/2,1-exp(-delta*10))
	for entry in building_visuals:
		if not is_instance_valid(entry.body):continue
		var offset:Vector3=game.player.position-entry.body.position
		var close:bool=absf(offset.x)<entry.half.x+2 and absf(offset.z)<entry.half.y+2
		entry.mat.set_shader_parameter("visibility",.22 if close else 1.0)
