extends "res://fidelity/art.gd"
## All 208 Blender assets participate in the playable city.
const Layout=preload("res://fidelity/street_layout.gd")
const Districts=preload("res://fidelity/city_districts.gd")
const MeshBatch=preload("res://fidelity/mesh_batch.gd")
const PlacementGrid=preload("res://fidelity/placement_grid.gd")
var actor_clock:=0.0
var food_queries:RefCounted
var indexed_count:=0
var shared_opaque:StandardMaterial3D
var static_batch_stats:Dictionary={}
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
var intersection_owners:Dictionary={}
var actor_district_colors: Dictionary = {}
var actor_layout_source: String = "local_recipe"
var layout_repairs:Array[Dictionary]=[]
var street_placement_repairs:Array[Dictionary]=[]
var city_districts:Array=[]
var outer_district_count:=0
const AMBIENT_KINDS:= ["CourierDrone","StreetBot","SkyMote","TransitBeacon"]
const BUILDING_TINTS:= [Color("d7775d"),Color("d0b36e"),Color("6f9fb0"),Color("a783b5"),Color("6fa77f"),Color("cf7c9a")]

func read_catalog() -> void:
	if not catalog.is_empty():return
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_kit/manifest.json"))
	catalog=data.assets
	for entry in catalog:
		if not by_kind.has(entry.kind):by_kind[entry.kind]=[]
		by_kind[entry.kind].append(entry)

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
	var body:=make_actor_edible(root,"signal_pylon",3)
	body.position.y=body.half_size.y+.04
	signal_nodes.append({"root":root,"body":body,"orb":orb,"ring":ring,"light":light,"phase":float(index)*1.7})

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
	var body:=make_actor_edible(root,"ambient_actor",2)
	if kind in ["StreetBot","TransitBeacon"]:body.position.y=body.half_size.y+.04
	ambient_actors.append({"root":root,"body":body,"origin":body.position,"phase":float(index)*.41,"kind":kind,"speed":.45+float(index%5)*.07})

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
	var spec:Dictionary=Layout.traffic_spec(index)
	spec["body"]=body
	moving_vehicles.append(spec)

func build_recipe_actor(entry:Dictionary, index:int) -> void:
	# Physics ownership is authored before batching. Separate luggage, food and
	# rack pieces must never inherit the frame's union box or footprint gate.
	var root:=Node3D.new()
	root.name="AuthoredActor_%03d_%s"%[index,entry.id]
	root.position=Vector3(float(entry.position[0]),0.0,float(entry.position[1]))
	root.set_meta("actor_type",entry.name)
	add_child(root)
	var groups:Dictionary={}
	var motions:Array[Dictionary]=[]
	for part in entry.parts:
		var object_id:String=part.get("object_id","frame")
		if not groups.has(object_id):
			var group:=Node3D.new()
			group.name=object_id
			root.add_child(group)
			groups[object_id]=group
		var parent:Node3D=groups[object_id]
		var size:=Vector3(part.size[0],part.size[1],part.size[2])
		var at:=Vector3(part.position[0],part.position[1],part.position[2])
		var tint:=actor_tint(entry.district,part.tone)
		var visual:MeshInstance3D
		if part.shape=="box":visual=box(parent,at,size,tint)
		elif part.shape=="cylinder":
			visual=cylinder(parent,at,size.x*.5,size.y,tint)
			visual.scale.z=size.z/size.x
		elif part.shape=="cone":
			visual=cylinder(parent,at,size.x*.5,size.y,tint,size.x*.12)
			visual.scale.z=size.z/size.x
		else:
			visual=sphere(parent,at,size.x*.5,tint,size.y/size.x)
			visual.scale.z=size.z/size.x
		# Recipes use full extents and degrees (also consumed by Houdini).
		visual.rotation_degrees=Vector3(part.rotation[0],part.rotation[1],part.rotation[2])
		var motion:String=part.motion
		if motion!="none":motions.append({"node":visual,"object_id":object_id,"motion":motion,"base":visual.rotation,"origin":visual.position,"phase":float(motions.size())*.43})
	var moving_parts:Array=[]
	for motion in motions:moving_parts.append(motion.node)
	var bodies:Dictionary={}
	var base_y:=INF
	for object_id in groups:
		var group:Node3D=groups[object_id]
		MeshBatch.combine(group,moving_parts)
		var body:=make_actor_edible(group,"authored_actor",int(entry.get("points",3)) if object_id=="frame" else 1)
		body.name="Recipe_%s_%s"%[entry.id,object_id]
		body.set_meta("recipe_id",entry.id)
		body.set_meta("object_id",object_id)
		body.set_meta("qa_origin",root.position)
		bodies[object_id]=body
		base_y=minf(base_y,body.position.y-body.half_size.y)
	# Move the assembly together; do not teleport every upper object to ground.
	var lift:float=.04-base_y if entry.id not in ["parcel_quadcopter","weather_balloon"] else 0.0
	for body in bodies.values():body.position.y+=lift
	for object in entry.get("objects",[]):
		if object.support!="" and bodies.has(object.support):
			bodies[object.support].carried_items.append(bodies[object.id])
	for motion in motions:motion["body"]=bodies[motion.object_id]
	recipe_actors.append({"root":root,"body":bodies.frame,"bodies":bodies,"definition":entry,"motions":motions,"phase":float(index)*.17,"speed":.45+float(index%7)*.06})

func make_actor_edible(visual:Node3D,category:String,points:int)->RigidBody3D:
	var bounds:=AABB()
	var first:=true
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var transform:Transform3D=visual.global_transform.affine_inverse()*mesh.global_transform
		var local:AABB=transform*mesh.get_aabb()
		bounds=local if first else bounds.merge(local)
		first=false
	var center:Vector3=visual.global_transform*bounds.get_center()
	var size:=bounds.size.max(Vector3.ONE*.1)
	var body:=_food(Vector2(center.x,center.z),size,category,points)
	body.position=center
	body.set_meta("scripted_actor",true)
	body.collision_layer=0
	visual.reparent(body,true)
	if category in ["signal_pylon","ambient_actor"]:
		# Beacons and robots also have empty space around their thin supports.
		# Their few primitive hulls are cheap and avoid a full-height solid box.
		for child in body.get_children():
			if child is CollisionShape3D:body.remove_child(child);child.queue_free()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var relative:Transform3D=body.global_transform.affine_inverse()*mesh.global_transform
			var hull_points:=PackedVector3Array()
			for surface in mesh.mesh.get_surface_count():
				var arrays:Array=mesh.mesh.surface_get_arrays(surface)
				for point in arrays[Mesh.ARRAY_VERTEX]:hull_points.append(relative*point)
			var shape:=ConvexPolygonShape3D.new();shape.points=hull_points;shape.margin=.002
			var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
			var mesh_bounds:AABB=relative*mesh.get_aabb()
			body.rim_samples.append(mesh_bounds.get_center())
			for axis in 3:
				for side in [-1,1]:
					var point:Vector3=mesh_bounds.get_center();point[axis]+=mesh_bounds.size[axis]*.5*side
					body.rim_samples.append(point)
	return body

func bind_building_contents()->void:
	for item in foods:
		if not item.get_meta("scripted_actor",false) or item.get_meta("resident",false):continue
		for entry in building_visuals:
			var local:Vector3=entry.body.to_local(item.global_position)
			if absf(local.x)<entry.half.x and absf(local.z)<entry.half.y and absf(local.y)<entry.body.height*.5:
				item.support_parent=entry.body
				entry.body.contents.append(item)
				break

func resolve_recipe_placement()->void:
	var grid:=PlacementGrid.new()
	reserve_walkways(grid)
	for body in foods:grid.put(body.get_instance_id(),traffic_bounds(body,.12))
	for actor in recipe_actors:
		var assembly:=AABB()
		var first:=true
		var excluded:Array=[]
		for body in actor.bodies.values():
			var bounds:AABB=body.global_transform*AABB(-body.half_size,body.half_size*2)
			assembly=bounds if first else assembly.merge(bounds)
			first=false
			excluded.append(body.get_instance_id())
		var center:Vector3=assembly.get_center()
		var half:=Vector2(assembly.size.x,assembly.size.z)*.5
		var origin:=Vector2(center.x,center.z)
		var destination:=origin
		var interior:=false
		for building in building_visuals:
			var local:Vector3=building.body.to_local(actor.body.position)
			if absf(local.x)<building.half.x-.1 and absf(local.z)<building.half.y-.1 and assembly.size.y<building.body.height:
				# Keep interior assemblies together and wholly behind their shell.
				var room:Rect2=traffic_bounds(building.body,-.15)
				if room.size.x>half.x*2 and room.size.y>half.y*2:
					destination=origin.clamp(room.position+half,room.end-half)
					interior=true
					break
		if not interior:
			var found:=false
			for ring in 25:
				for step in (1 if ring==0 else 24):
					var angle:=TAU*float(step)/24.0
					var candidate:=origin+Vector2(cos(angle),sin(angle))*float(ring)*.75
					var rect:=Rect2(candidate-half,half*2).grow(.14)
					if absf(candidate.x)+half.x>74 or absf(candidate.y)+half.y>74:continue
					if Layout.on_road(candidate,maxf(half.x,half.y)+.35):continue
					if not grid.clear_at(rect,excluded):continue
					destination=candidate;found=true;break
				if found:break
			if not found:push_error("No clear recipe placement: "+actor.definition.id)
		var shift:=Vector3(destination.x-origin.x,0,destination.y-origin.y)
		if shift.length_squared()>.0001:
			layout_repairs.append({"id":actor.definition.id,"from":[origin.x,origin.y],"to":[destination.x,destination.y],"interior":interior})
			actor.root.position+=shift
			for body in actor.bodies.values():
				body.position+=shift
				grid.put(body.get_instance_id(),traffic_bounds(body,.12))

func resolve_street_prop_placement()->void:
	# Imported furniture needs the same collision clearance as recipe actors.
	# Continuous fences/railings are intentionally joined; leave those rows.
	var grid:=PlacementGrid.new()
	reserve_walkways(grid)
	for body in foods:
		if body.category not in ["authored_actor","person","ambient_actor"]:
			grid.put(body.get_instance_id(),traffic_bounds(body,.10))
	for body in foods:
		if body.get_meta("catalog_group","") not in ["prop","plant"] and body.category not in ["signal_pylon","railing"]:continue
		if body.category=="fence" and not Layout.intersects_walk(traffic_bounds(body,.12)):continue
		var before:=Vector2(body.position.x,body.position.z)
		var rect:=traffic_bounds(body,.12)
		var excluded:Array=[body.get_instance_id()]
		if grid.clear_at(rect,excluded):continue
		var found:=false
		var placement_limit:float=Layout.WorldBounds.HALF-2.0 if body.get_meta("outer_district",false) else 74.0
		for ring in range(1,49):
			for step in 24:
				var delta:=Vector2(cos(TAU*step/24.0),sin(TAU*step/24.0))*ring*.5
				var candidate:=Rect2(rect.position+delta,rect.size)
				var center:Vector2=candidate.get_center()
				if absf(center.x)+rect.size.x*.5>placement_limit or absf(center.y)+rect.size.y*.5>placement_limit:continue
				if Layout.on_road(center,maxf(rect.size.x,rect.size.y)*.5):continue
				if not grid.clear_at(candidate,excluded):continue
				body.position.x+=delta.x;body.position.z+=delta.y
				grid.put(body.get_instance_id(),candidate)
				street_placement_repairs.append({"name":str(body.name),"from":str(before),"to":str(center)})
				found=true;break
			if found:break
		if not found:push_error("No clear street furniture placement: "+str(body.name))

func reserve_walkways(grid:RefCounted)->void:
	if city_districts.is_empty():return
	var index:=-1
	for rect in Layout.walk_clearance_rects():grid.put(index,rect);index-=1

func place(entry:Dictionary, at:Vector2, angle:float=0.0) -> RigidBody3D:
	var size_data:Array=entry.size
	var extent:=Vector3(size_data[0],size_data[1],size_data[2])
	var category:String=entry.group
	if category=="prop":category=entry.kind
	if category=="plant":category="tree"
	var points:int=35 if category=="building" else 7 if category=="vehicle" else 3 if category=="tree" else 1
	var body:=_food(at,extent,category,points)
	if entry.group=="prop":
		var collision_path:String="res://assets/prop_collisions/"+entry.id+".res"
		if ResourceLoader.exists(collision_path):
			var cache:Resource=load(collision_path)
			for child in body.get_children():
				if child is CollisionShape3D:body.remove_child(child);child.queue_free()
			for shape in cache.shapes:
				var collider:=CollisionShape3D.new()
				collider.shape=shape
				body.add_child(collider)
			body.set_meta("compound_collision",true)
			body.set_meta("collision_source_sha256",cache.source_sha256)
			body.rim_samples=cache.rim_samples
			if category in ["lamp","sign","traffic_light","bollard","mailbox"]:
				body.has_support_anchor=true
				body.support_anchor=cache.support_anchor
				# The mouth is aimed at the pole base, so an asymmetric arm's
				# extent must be measured from that same point, not its box center.
				body.footprint=maxf(body.footprint,cache.support_radius)
	if category=="person":
		# Route control owns living citizens; swallow release hands them to physics.
		# Held props belong to the silhouette, not to the pedestrian's footing.
		var capsule:=CapsuleShape3D.new()
		capsule.radius=.23
		capsule.height=extent.y
		for child in body.get_children():
			if child is CollisionShape3D:child.shape=capsule
		body.half_size=Vector3(.23,extent.y*.5,.23)
		body.footprint=.26
		body.set_meta("resident",true)
		body.set_meta("scripted_actor",true)
		body.freeze=true
		body.lock_rotation=true
		body.collision_layer=0
		body.collision_mask=0
	body.rotation.y=angle
	body.set_meta("asset_id",entry.id)
	body.set_meta("catalog_group",entry.group)
	used_assets[entry.id]=true
	if not models.has(entry.id):models[entry.id]=load(entry.path)
	var visual:Node3D=models[entry.id].instantiate()
	visual.name="Model"
	body.add_child(visual)
	visual.position=-Vector3(entry.center[0],entry.center[1],entry.center[2])
	if shared_opaque==null:
		shared_opaque=StandardMaterial3D.new()
		shared_opaque.vertex_color_use_as_albedo=true;shared_opaque.roughness=.78
	for mesh in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=shared_opaque
	if category=="building":
		# Explicit author opt-in: catalog houses only, never edible props or food.
		body.set_meta("dither_building",true)
		var mat:=ShaderMaterial.new()
		mat.shader=Palette
		var style:int=building_visuals.size()%BUILDING_TINTS.size()
		body.set_meta("fracture_tint",BUILDING_TINTS[style])
		mat.set_shader_parameter("building_tint",BUILDING_TINTS[style])
		mat.set_shader_parameter("tint_amount",.28)
		for mesh in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		building_dressing(body,extent,style)
		MeshBatch.combine(body,[],mat)
		body.fracture_material=mat
		var cache_path:String="res://assets/fractures/"+entry.id+".res"
		if not OS.get_cmdline_user_args().has("--bake-fractures") and ResourceLoader.exists(cache_path):body.fracture_cache=load(cache_path)
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

func build_outer_districts(buildings:Array)->void:
	var first:=foods.size()
	var compact:Array=buildings.filter(func(entry):return float(entry.size[0])<=5.5 and float(entry.size[2])<=7.2)
	var small_trees:Array=catalog.filter(func(entry):return entry.group=="plant" and maxf(float(entry.size[0]),float(entry.size[2]))<2.6)
	var parcels:=Districts.outer_parcels()
	for i in parcels.size():
		var parcel:Dictionary=parcels[i]
		var body:=place(compact[(i*5)%compact.size()],parcel.at,parcel.yaw)
		body.set_meta("city_district",parcel.district);body.set_meta("district_landmark",false)
		var forward:=Vector2(sin(parcel.yaw),cos(parcel.yaw))
		var side:=Vector2(forward.y,-forward.x)
		for j in 4:
			place(asset(["cone","bin","bollard","cone"][j],i+j),parcel.at+forward*4.5+side*(float(j)-1.5)*1.6,parcel.yaw)
		place(asset("bench",i),parcel.at+forward*4.5+side*5.0,parcel.yaw)
		if i%3==0 and not small_trees.is_empty():place(small_trees[i%small_trees.size()],parcel.at+side*5.0,parcel.yaw)
	for i in range(first,foods.size()):foods[i].set_meta("outer_district",true)
	outer_district_count=foods.size()-first

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
	city_districts=Districts.DISTRICTS.duplicate(true)
	var parcels:=Districts.parcels()
	for i in buildings.size():
		var parcel:Dictionary=parcels[i]
		var body:=place(buildings[i],parcel.at,parcel.yaw)
		body.set_meta("city_district",parcel.district);body.set_meta("district_landmark",parcel.landmark)
	for i in Layout.WALK_LOOPS.size():
		var area:Rect2=Layout.WALK_LOOPS[i]
		game.ground.surface.set_shader_parameter("city_walk_%d"%i,Vector4(area.position.x,area.position.y,area.size.x,area.size.y))
	for i in city_districts.size():
		var area:Rect2=city_districts[i].park
		game.ground.surface.set_shader_parameter("city_park_%d"%i,Vector4(area.position.x,area.position.y,area.size.x,area.size.y))
	game.ground.surface.set_shader_parameter("city_courtyard",Vector4(-7.0,52.0,14.0,5.5))
	var starting:=["school_bus","sedan","police","pickup","sedan","hatchback","taxi","delivery_van","sedan"]
	for i in starting.size():place(asset(starting[i],i%4),Vector2(-16.5+i*3.7,19),PI)
	var vehicles:Array=catalog.filter(func(e:Dictionary):return e.group=="vehicle")
	for i in vehicles.size():
		var row:int=i/8
		var at:=Vector2(-18.0+(i%8)*5.0,-36.0) if row==0 else Vector2(-18.0+(i%8)*5.0,-39.5) if row==1 else Vector2(-33 if row==2 else 35,[-44.0,-38.0,-18.0,-12.0,8.0,18.0,28.0,40.0][i%8])
		place(vehicles[i],at,PI/2 if row<2 else 0)
	# Two continuous avenue loops keep the streets alive. Cars slow near the
	# player and turn through the junctions without a world-position teleport.
	for i in 8:
		var spec:Dictionary=Layout.traffic_spec(i)
		var entry:Dictionary=vehicles[(i+5)%vehicles.size()]
		add_traffic(entry,spec.at,spec.angle,i)
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
		var z:float=[5.8,-9.0,39.0,-24.0][i/16]
		place(props[i],Vector2(x,z))
	var plants:Array=catalog.filter(func(e:Dictionary):return e.group=="plant")
	for i in plants.size():
		var at:=Vector2.ZERO
		if i<12:at=Vector2(18.7,19.5+i*1.5)
		elif i<24:at=Vector2(-7.5+float((i-12)%6)*3.0,-57.5+float((i-12)/6)*3.0)
		elif i<36:at=Vector2(-4.5+float((i-24)%4)*3.0,52.2+float((i-24)/4)*2.5)
		else:at=Vector2(-46.5+float((i-36)%4)*2.5,34.8+float((i-36)/4)*2.2)
		place(plants[i],at)
	var pylon_places:=[Vector2(-21,7),Vector2(2,27),Vector2(23,-12),Vector2(-12,-25),Vector2(35,30)]
	var pylon_colors:=[Color("41d9ff"),Color("c87cff"),Color("5df0b6"),Color("ffbd58"),Color("ff6db6")]
	for i in pylon_places.size():signal_pylon(pylon_places[i],pylon_colors[i],i)
	# Actors remain frozen during scripted motion and join physics on release.
	for i in 48:
		var actor_at:=Vector2(-34.0+float(i%12)*6.2,-34.0+float(i/12)*18.0+(i%2)*1.4)
		# Break the backdrop grid into loose clusters while keeping every actor
		# inside the authored street bounds.
		actor_at+=Vector2(rng.randf_range(-1.8,1.8),rng.randf_range(-1.35,1.35))
		if i%5==0:actor_at.x+=1.6
		ambient_actor(actor_at,i)
	for i in authored_actor_types.size():build_recipe_actor(authored_actor_types[i],i)
	var figures:Array=catalog.filter(func(e:Dictionary):return e.group=="person")
	# Residents circulate the painted block perimeters, including real corners.
	for i in 64:
		var sidewalk:int=i%Layout.WALK_LOOPS.size()
		var lane:int=i/Layout.WALK_LOOPS.size()
		var progress:float=Layout.walk_length(sidewalk)*(float(lane)+.3)/16.0
		var at:=Layout.walk_sample(progress,sidewalk)
		place(figures[i%16],at)
		var citizen_index:=citizens.size()-1
		var citizen:Dictionary=citizens[citizen_index]
		var citizen_body:RigidBody3D=citizen.body
		citizen_body.rotation.y=rng.randf_range(-PI,PI)
		citizen["sidewalk"]=sidewalk
		citizen["walk_loop"]=sidewalk;citizen["walk_progress"]=progress
		citizen["wander_radius"]=Vector2(1.2+float((i+lane)%3)*.5,.55+float((i*2+lane)%3)*.28)
		citizen["wander_speed"]=.26+float(i%5)*.045
		citizen["wander_phase"]=rng.randf_range(0,TAU)
		citizen["rest_cycle"]=10.0+float(i%5)*2.4
		citizen["rest_window"]=1.4+float((i+lane)%4)*.65
		citizen["rest_offset"]=rng.randf_range(0,12.0)
		citizens[citizen_index]=citizen
	# Narrow edible park railings retain the gradual early growth path.
	for side in [16.8,24.9]:
		var along:=18.0
		var cap_along:=0.0
		for i in 20:
			var entry:Dictionary=asset("fence",i)
			var width:float=entry.size[0]
			# Variants are 1.0–1.27 m wide. Fixed 1 m slots interlocked their
			# bars, letting frozen neighbors suspend an otherwise fitting panel.
			if along+width<=37.3:
				place(entry,Vector2(side,along+width*.5),PI/2)
				along+=width+.04
			else:
				var direction:=1.0 if side<20 else -1.0
				place(entry,Vector2(side+direction*(cap_along+width*.5+.06),37.3))
				cap_along+=width+.04
	subway(Vector2(0,-11.35));subway(Vector2(-43,35))
	for at in [Vector2(5,23),Vector2(13,31)]:
		var cover:=_food(at,Vector3(1.4,.16,2.3),"cover",2)
		box(cover,Vector3.ZERO,Vector3(1.4,.16,2.3),Color("41433d"))
	build_outer_districts(buildings)
	box(self,Vector3(0,-4.9,0),Vector3(Layout.WorldBounds.HALF*2.0+4.0,3,Layout.WorldBounds.HALF*2.0+4.0),Color("73644e"))
	box(self,Vector3(0,-6.7,0),Vector3(300,.2,300),Color("1e99f1"))
	resolve_street_prop_placement()
	resolve_recipe_placement()
	bind_building_contents()
	food_queries=preload("res://fidelity/food_query.gd").new()
	for item in foods:food_queries.register(item)
	indexed_count=foods.size()
	static_batch_stats=preload("res://fidelity/static_batch.gd").build(self)

func activate_food(body:Node3D)->void:
	if food_queries!=null:food_queries.activate(body)

func index_new_foods()->void:
	# Fractures and test/authored spawns append bodies after the initial build.
	while indexed_count<foods.size():
		var body=foods[indexed_count];indexed_count+=1
		if is_instance_valid(body):food_queries.register(body)

func query_foods(at:Vector3,reach:float)->Array[Node3D]:
	index_new_foods()
	return food_queries.query(at,reach)

func scan_candidates(holes:Array)->Array[Node3D]:
	index_new_foods()
	return food_queries.scan(holes)

func traffic_bounds(body:RigidBody3D,padding:=.1)->Rect2:
	var half:Vector3=body.half_size
	var extent:=Vector2(absf(body.basis.x.x)*half.x+absf(body.basis.z.x)*half.z,absf(body.basis.x.z)*half.x+absf(body.basis.z.z)*half.z)
	return Rect2(Vector2(body.position.x,body.position.z)-extent,extent*2).grow(padding)

func traffic_footprints_overlap(a:RigidBody3D,b:RigidBody3D,padding:=.1,proposed:Dictionary={})->bool:
	var at_a:Vector2=proposed.get("at",Vector2(a.position.x,a.position.z))
	var forward_a:Vector2=proposed.get("forward",Vector2(a.basis.z.x,a.basis.z.z))
	var at_b:=Vector2(b.position.x,b.position.z)
	var forward_b:=Vector2(b.basis.z.x,b.basis.z.z)
	var right_a:=Vector2(forward_a.y,-forward_a.x)
	var right_b:=Vector2(forward_b.y,-forward_b.x)
	for axis in [forward_a,right_a,forward_b,right_b]:
		var radius_a:float=absf(axis.dot(right_a))*(a.half_size.x+padding)+absf(axis.dot(forward_a))*(a.half_size.z+padding)
		var radius_b:float=absf(axis.dot(right_b))*(b.half_size.x+padding)+absf(axis.dot(forward_b))*(b.half_size.z+padding)
		if absf(axis.dot(at_a-at_b))>=radius_a+radius_b:return false
	return true

func update_intersections()->void:
	for x in [Layout.ROAD_X.x,Layout.ROAD_X.y]:
		for z in [Layout.ROAD_Z.x,Layout.ROAD_Z.y]:
			var center:=Vector2(x,z)
			var crossing:=Rect2(center-Vector2.ONE*Layout.HALF_WIDTH,Vector2.ONE*Layout.HALF_WIDTH*2)
			var owner=intersection_owners.get(center)
			if is_instance_valid(owner) and not is_instance_valid(owner.claimed_by) and traffic_bounds(owner,2.0).intersects(crossing):continue
			intersection_owners.erase(center)
			var nearest:=INF
			for t in moving_vehicles:
				if not is_instance_valid(t.body):continue
				var body:RigidBody3D=t.body
				if not is_instance_valid(body) or is_instance_valid(body.claimed_by):continue
				if not traffic_bounds(body,2.0).intersects(crossing):continue
				var distance:=Vector2(body.position.x,body.position.z).distance_squared_to(center)
				if distance<nearest:nearest=distance;intersection_owners[center]=body

func sidewalk_destination(citizen:Dictionary,at:Vector2)->Vector2:
	if citizen.has("walk_loop"):return Layout.walk_constrain(at,int(citizen.walk_loop))
	return Layout.sidewalk_point(at,int(citizen.sidewalk))

func pedestrian_contains(citizen:Dictionary,at:Vector2)->bool:
	if citizen.has("walk_loop"):
		return not Layout.on_road(at,.3) and at.distance_to(Layout.walk_closest(at,int(citizen.walk_loop)).at)<=Layout.WALK_HALF_WIDTH-.25
	return not Layout.on_road(at,.3) and Layout.SIDEWALKS[int(citizen.sidewalk)].has_point(at)

func face_pedestrian_velocity(body:Node3D,velocity:Vector2,delta:float)->void:
	# A speed threshold is independent of the rendered frame rate. Testing the
	# per-frame displacement formerly prevented every ordinary walker from
	# turning at 60 Hz and above. Keep at most a small visible turn lag.
	if velocity.length_squared()<.0001:return
	var desired:=atan2(velocity.x,velocity.y)
	var blended:=lerp_angle(body.rotation.y,desired,1.0-exp(-delta*10.0))
	body.rotation.y=desired+clampf(angle_difference(desired,blended),-PI/12.0,PI/12.0)

func separate_citizens()->void:
	# Scripted feet use lightweight planar separation while standing. Claimed
	# or falling people immediately leave this solver and remain owned by gravity.
	var standing:Array[Dictionary]=[]
	var grid:Dictionary={}
	var pairs:Array[Vector2i]=[]
	for citizen in citizens:
		if not is_instance_valid(citizen.body):continue
		var body:RigidBody3D=citizen.body
		if not body.freeze or is_instance_valid(body.claimed_by):continue
		var at:=Vector2(body.position.x,body.position.z)
		var cell:=Vector2i(floori(at.x),floori(at.y))
		var index:=standing.size()
		for x in range(cell.x-1,cell.x+2):
			for y in range(cell.y-1,cell.y+2):
				for other in grid.get(Vector2i(x,y),[]):pairs.append(Vector2i(other,index))
		standing.append(citizen)
		if not grid.has(cell):grid[cell]=[]
		grid[cell].append(index)
	for iteration in 24:
		var deepest:=0.0
		for pair in pairs:
			var a:Dictionary=standing[pair.x];var b:Dictionary=standing[pair.y]
			var pa:=Vector2(a.body.position.x,a.body.position.z)
			var pb:=Vector2(b.body.position.x,b.body.position.z)
			var gap:=pa-pb
			var distance:=gap.length()
			if distance>=.48:continue
			var direction:=gap/distance if distance>.00001 else Vector2.from_angle(float(pair.x*31+pair.y*17)*.71)
			var correction:=direction*(.4802-distance)*.5
			var safe_a:=sidewalk_destination(a,pa+correction)
			var safe_b:=sidewalk_destination(b,pb-correction)
			# If one is against the edge, the other takes the unapplied half.
			var moved_a:float=maxf(0.0,(safe_a-pa).dot(direction))
			var moved_b:float=maxf(0.0,(pb-safe_b).dot(direction))
			if moved_a<correction.length()*.9:safe_b=sidewalk_destination(b,pb-direction*(.4802-distance-moved_a))
			if moved_b<correction.length()*.9:safe_a=sidewalk_destination(a,pa+direction*(.4802-distance-moved_b))
			a.body.position.x=safe_a.x;a.body.position.z=safe_a.y
			b.body.position.x=safe_b.x;b.body.position.z=safe_b.y
			deepest=maxf(deepest,.48-distance)
		if deepest<.0001:break

func update_traffic(delta:float)->void:
	for traffic in moving_vehicles:
		var body=traffic.get("body")
		if not is_instance_valid(body) or not body.freeze or is_instance_valid(body.claimed_by) or game.phase!="playing":continue
		var gap:Vector2=Vector2(game.player.position.x-body.position.x,game.player.position.z-body.position.z)
		var blocked:bool=gap.length_squared()<pow(game.player.radius+3.0,2)
		var progress:float=traffic.progress+traffic.speed*delta
		var pose:=Layout.traffic_sample(progress,int(traffic.route))
		var forward:Vector2=pose.forward
		for other in moving_vehicles:
			if other.body==body or not is_instance_valid(other.body) or is_instance_valid(other.body.claimed_by):continue
			# World-axis boxes overlap spuriously when opposing cars turn. Test
			# the four actual oriented footprint axes to avoid a false deadlock.
			if traffic_footprints_overlap(body,other.body,.10,pose):blocked=true
		if blocked:continue
		traffic.progress=fposmod(progress,Layout.traffic_length(int(traffic.route)))
		body.position.x=pose.at.x;body.position.z=pose.at.y
		body.rotation.y=atan2(forward.x,forward.y)

func _process(delta:float) -> void:
	if is_instance_valid(preview):
		preview.rotation.y+=delta*.10
		return
	if not is_instance_valid(game):return
	var thief:Dictionary={}
	for c in citizens:
		if c.kind=="thief" and is_instance_valid(c.body):thief=c;break
	actor_clock+=delta
	var actor_tick:bool=actor_clock>=.10
	if actor_tick:actor_clock=0.0
	for citizen in citizens:
		if not is_instance_valid(citizen.body):continue
		var body:RigidBody3D=citizen.body
		var anim:AnimationPlayer=citizen.anim
		if not is_instance_valid(anim):continue
		if not body.freeze or game.phase!="playing":
			anim.pause()
			continue
		# A pedestrian already over an opening loses support before taking
		# another scripted fleeing step. The normal scan can run at a lower rate.
		for h in game.holes:
			if h.active and body.can_fit(h) and Vector2(body.position.x-h.position.x,body.position.z-h.position.z).length()<h.radius*.90:
				body.begin_swallow(h)
				break
		if not body.freeze:
			anim.pause()
			continue
		body.rotation.x=0.0
		body.rotation.z=0.0
		citizen["motion_from"]=Vector2(body.position.x,body.position.z)
		var origin:Vector3=citizen.origin
		var panic:bool=body.position.distance_to(game.player.position)<game.player.radius+4.0
		var police_chase:bool=citizen.kind=="police" and not thief.is_empty() and body.position.distance_to(thief.body.position)<14.0
		var thief_escape:bool=citizen.kind=="thief" and not thief.is_empty() and body.position.distance_to(game.player.position)>0.0 and body.position.distance_to(game.player.position)<6.0
		var time:float=game.elapsed+citizen.phase
		var rest_cycle:float=float(citizen.get("rest_cycle",12.0))
		var rest_window:float=float(citizen.get("rest_window",3.0))
		var rest_offset:float=float(citizen.get("rest_offset",0.0))
		var resting:bool=fmod(time+rest_offset,rest_cycle)>rest_cycle-rest_window and not panic
		citizen["motion_running"]=panic or police_chase or thief_escape
		citizen["motion_resting"]=resting
		if not resting:
			var wander_radius:Vector2=citizen.get("wander_radius",Vector2(1.1,.55))
			var wander_speed:float=float(citizen.get("wander_speed",.36))
			var wander_phase:float=float(citizen.get("wander_phase",citizen.phase))
			var wander:=Vector2(sin(time*wander_speed+wander_phase)*wander_radius.x,sin(time*wander_speed*.71+wander_phase*1.37)*wander_radius.y)
			var destination:Vector3=origin+Vector3(wander.x,0,wander.y)
			if citizen.has("walk_loop"):
				var route:int=citizen.walk_loop
				citizen.walk_progress=Layout.walk_closest(Vector2(body.position.x,body.position.z),route).progress
				var next:=Layout.walk_sample(float(citizen.walk_progress)+.7,route)
				destination=Vector3(next.x,body.position.y,next.y)
			if police_chase:destination=thief.body.position
			elif thief_escape:destination=origin+Vector3(-2.4 if body.position.x<game.player.position.x else 2.4,0,0)
			elif panic:destination=origin+Vector3(-1.65 if body.position.x<game.player.position.x else 1.65,0,0)
			var safe:Vector2=sidewalk_destination(citizen,Vector2(destination.x,destination.z))
			destination.x=safe.x;destination.z=safe.y
			var difference:Vector2=Vector2(destination.x-body.position.x,destination.z-body.position.z)
			var step:Vector2=difference.limit_length(delta*(2.1 if panic else .58))
			var next_step:=sidewalk_destination(citizen,Vector2(body.position.x,body.position.z)+step)
			body.position.x=next_step.x
			body.position.z=next_step.y
	if game.phase=="playing":separate_citizens()
	for citizen in citizens:
		if not is_instance_valid(citizen.body) or not is_instance_valid(citizen.anim):continue
		var body:RigidBody3D=citizen.body
		var anim:AnimationPlayer=citizen.anim
		if not body.freeze or game.phase!="playing" or not citizen.has("motion_from"):continue
		var velocity:Vector2=(Vector2(body.position.x,body.position.z)-Vector2(citizen.motion_from))/maxf(delta,.0001)
		var travel_speed:=velocity.length()
		var moved:=travel_speed>.01
		face_pedestrian_velocity(body,velocity,delta)
		# Traveling uses locomotion, while gestures belong to stationary beats.
		var clip:String=("Run" if citizen.motion_running else "Walk") if moved else "Idle" if citizen.motion_resting else citizen.special
		anim.speed_scale=clampf(travel_speed/(1.85 if clip=="Run" else .62),.4,1.4) if clip in ["Walk","Run"] else 1.0
		if citizen.clip!=clip or not anim.is_playing():anim.play(clip,.18)
		citizen.clip=clip

	update_traffic(delta)
	for node in signal_nodes:
		if not is_instance_valid(node.root) or not node.body.freeze or game.phase!="playing":continue
		var t:float=game.elapsed+node.phase
		node.body.rotation.y=t*.35
		node.orb.scale=Vector3.ONE*(1.0+sin(t*2.5)*.10)
		node.ring.rotation.y=-t*.9
		node.light.light_energy=.45+.25*(sin(t*2.0)+1.0)
	for actor in ambient_actors:
		if not is_instance_valid(actor.root) or not actor.body.freeze or game.phase!="playing":continue
		var t:float=game.elapsed+actor.phase
		var origin:Vector3=actor.origin
		var root:Node3D=actor.body
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
			root.position=origin
			root.rotation.y=t*.45
	for actor in recipe_actors:
		if not is_instance_valid(actor.root) or game.phase!="playing":continue
		var t:float=game.elapsed+actor.phase
		for motion in actor.motions:
			if not is_instance_valid(motion.body) or not motion.body.freeze:continue
			var node:MeshInstance3D=motion.node
			if not is_instance_valid(node):continue
			var base:Vector3=motion.base
			var wave:float=sin(t*actor.speed+motion.phase)
			if motion.motion=="spin_y":node.rotation=base+Vector3(0,t*actor.speed,0)
			elif motion.motion=="spin_x":node.rotation=base+Vector3(t*actor.speed,0,0)
			elif motion.motion=="spin_z":node.rotation=base+Vector3(0,0,t*actor.speed)
			elif motion.motion in ["bob","steam"]:node.position=motion.origin+Vector3(0,sin(t*1.6+motion.phase)*.06,0)
			elif motion.motion in ["sway","rock","pump"]:node.rotation=base+Vector3(0,0,wave*.12)
			elif motion.motion in ["slide","sweep"]:node.position=motion.origin+Vector3(wave*.18,0,0)
