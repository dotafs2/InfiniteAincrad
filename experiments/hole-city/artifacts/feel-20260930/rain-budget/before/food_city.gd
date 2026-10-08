extends "res://fidelity/catalog_city.gd"
const WorldBounds=preload("res://fidelity/world_bounds.gd")
## A dense edible city: layered food buildings, snack streets and physical food rain.
const Batch=preload("res://fidelity/mesh_batch.gd")
const Shapes=preload("res://fidelity/food_shapes.gd")
const FoodBody=preload("res://fidelity/food_body.gd")
const Surface=preload("res://fidelity/food_surface.gd")
const Glaze=preload("res://fidelity/food_glaze.gdshader")
const Neighborhoods=preload("res://fidelity/food_neighborhoods.gd")
var urban_plan:Dictionary={}
var delivery_junctions:Array[Vector2]=[]
const RAIN_LIMIT:=640
const AIRBORNE_LIMIT:=24
const RAIN_RETIRE_DISTANCE:=34.0
var food_kind_counts:Dictionary={}
var mesh_cache:Dictionary={}
const ROUND_COLLISION_SIDES:=16
var round_collision_cache:Dictionary={}
var towers:Array[Dictionary]=[]
var collection_progress:Dictionary={"buildings":0,"landmarks":0,"heaps":0}
var collected_food:Dictionary={}
var building_collections:Dictionary={}
var pile_collections:Dictionary={}
var piles:Array[Dictionary]=[]
var districts:Array[PackedVector2Array]=[]
var occupied_plots:Array[Dictionary]=[]
var collapse_events:Array[Dictionary]=[]
var batch_cells:Dictionary={}
const BATCH_CELL:=24.0
var spatial_ready:=false
var rain_bodies:Array[Node3D]=[]
var rain_clock:=0.0
var rain_serial:=0
var rain_waves:=0
var rain_retirements:Array[Dictionary]=[]
var rain_batches:Dictionary={}
var rain_enabled:=true
var batch_count:=0
var rain_rng:=RandomNumberGenerator.new()
var food_material:ShaderMaterial
var food_batch_material:ShaderMaterial
const IMPACT_LIMIT:=12
var impact_queue:Array[Dictionary]=[]
var food_impact_events:Array[Dictionary]=[]
var impacts:Array[Dictionary]=[]
var crumb_batch:MultiMesh
var glaze_batch:MultiMesh
var impact_audio:Array[AudioStreamPlayer3D]=[]
var impact_sounds:Dictionary={}
var impact_sound_clock:=0.0
var impact_serial:=0

func _new_food()->RigidBody3D:return FoodBody.new()

func material(tint:Color)->StandardMaterial3D:
	var mat:=super.material(tint)
	mat.roughness=Surface.roughness(tint)
	return mat

func box(parent:Node3D,at:Vector3,size:Vector3,tint:Color)->MeshInstance3D:
	var visual:=super.box(parent,at,size,tint)
	# Window inlays and thin sprinkles stay cheap; edible masses get real bevels.
	if maxf(size.x,maxf(size.y,size.z))>=.65 and size.y>=.07 and size.x<5:
		visual.mesh=Surface.rounded_box(size)
	return visual

func cylinder(parent:Node3D,at:Vector3,radius:float,height:float,tint:Color,top:=-1.0)->MeshInstance3D:
	var visual:=super.cylinder(parent,at,radius,height,tint,top)
	if top<0 and radius>=.3:visual.mesh=Surface.rounded_disc(radius,height)
	else:visual.mesh.radial_segments=16
	return visual

func sphere(parent:Node3D,at:Vector3,radius:float,tint:Color,scale_y:=1.0)->MeshInstance3D:
	var visual:=super.sphere(parent,at,radius,tint,scale_y)
	visual.mesh.radial_segments=20 if radius>=.35 else 12 if radius>=.2 else 8
	visual.mesh.rings=8 if radius>=.35 else 5 if radius>=.2 else 3
	return visual

func build(owner_game:Node)->void:
	game=owner_game
	rng.seed=20260928;rain_rng.seed=202609281
	read_catalog()
	urban_plan=Neighborhoods.plan()
	var degrees:Dictionary={}
	for road in urban_plan.roads:
		degrees[road.from]=int(degrees.get(road.from,0))+1;degrees[road.to]=int(degrees.get(road.to,0))+1
	for key in degrees:
		if degrees[key]>=3:delivery_junctions.append(Neighborhoods.point(urban_plan.nodes[int(key)].at))
	for district in urban_plan.districts:
		var polygon:=PackedVector2Array()
		for p in district.polygon:polygon.append(Neighborhoods.point(p))
		districts.append(polygon)
	for i in urban_plan.plots.size():
		var plot:Dictionary=urban_plan.plots[i]
		build_tower(Neighborhoods.point(plot.at),i,plot)
	for i in urban_plan.heaps.size():
		var plot:Dictionary=urban_plan.heaps[i]
		build_pile(Neighborhoods.point(plot.at),i,5,.52,plot.yaw,float(plot.get("growth_base_footprint",0.0)))
	# Three small cascades beside the first mouth: the opening can topple them.
	for i in 3:build_pile([Vector2(-2.7,19.6),Vector2(4.0,22.7),Vector2(.4,27.0)][i],200+i,3,.37)
	for snack in urban_plan.snacks:
		var body:=food(Shapes.KINDS[int(snack.kind)],Neighborhoods.point(snack.at),snack.size,int(snack.get("points",1 if snack.size<.5 else 2)),false,int(snack.flavor))
		body.rotation.y=snack.yaw
	for i in 8:
		var route_id:int=i%2
		var progress:float=Neighborhoods.lane_length(route_id)*float(i/2)/4.0
		var pose:=Neighborhoods.lane_sample(progress,route_id)
		var body:=food("sushi",pose.at,.82,7)
		body.set_meta("traffic",true);body.rotation.y=atan2(pose.forward.x,pose.forward.y)
		moving_vehicles.append({"body":body,"progress":progress,"route_id":route_id,"speed":2.5+float(i%3)*.12})
	var figures:Array=catalog.filter(func(e:Dictionary):return e.group=="person")
	for i in 48:
		var region:int=i%4
		var route_index:int=(i*7)%urban_plan.routes.size()
		var route:Dictionary=urban_plan.routes[route_index]
		var sample:int=clampi(int(route.points.size()*(.24+float(i/12)*.16)),1,route.points.size()-2)
		var at:=Neighborhoods.point(route.points[sample])
		place(figures[5 if i%2==0 else 14],at)
		var c:Dictionary=citizens.back()
		c["sidewalk"]=region;c["walk_route"]=route_index;c["wander_radius"]=Vector2(1.8,1.3)
		c["rest_cycle"]=10.0+float(i%4);c["rest_window"]=2.0
	batch_static_food()
	food_queries=preload("res://fidelity/food_query.gd").new()
	spatial_ready=true
	for body in foods:register_food(body)
	box(self,Vector3(0,-4.9,0),Vector3(WorldBounds.HALF*2.0+4.0,3,WorldBounds.HALF*2.0+4.0),Color("edb36d"))
	box(self,Vector3(0,-6.7,0),Vector3(300,.2,300),Color("43c7de"))

func on_sidewalk(at:Vector2)->bool:
	for route in urban_plan.routes:
		if Neighborhoods.closest(at,route).distance_to(at)<route.half_width:return true
	return false

func sidewalk_destination(citizen:Dictionary,at:Vector2)->Vector2:
	if not citizen.has("walk_route"):return super.sidewalk_destination(citizen,at)
	return Neighborhoods.constrain(at,urban_plan.routes[int(citizen.walk_route)])

func pedestrian_contains(citizen:Dictionary,at:Vector2)->bool:
	if not citizen.has("walk_route"):return super.pedestrian_contains(citizen,at)
	var route:Dictionary=urban_plan.routes[int(citizen.walk_route)]
	return not Neighborhoods.on_road(at,.3) and Neighborhoods.closest(at,route).distance_to(at)<=route.half_width-.25

func delivery_overlap(at:Vector2,forward:Vector2,half:Vector3,other:RigidBody3D,padding:=0.0)->bool:
	# SAT on the real oriented vehicle footprints. Axis-aligned boxes falsely
	# blocked opposite diagonal lanes even when the sushi cars had ample space.
	var side:=Vector2(forward.y,-forward.x)
	var other_forward:=Vector2(other.basis.z.x,other.basis.z.z).normalized()
	var other_side:=Vector2(other_forward.y,-other_forward.x)
	var gap:=Vector2(other.position.x,other.position.z)-at
	for axis in [side,forward,other_side,other_forward]:
		var a:float=absf(axis.dot(side))*half.x+absf(axis.dot(forward))*half.z
		var b:float=absf(axis.dot(other_side))*other.half_size.x+absf(axis.dot(other_forward))*other.half_size.z
		if absf(gap.dot(axis))>=a+b+padding:return false
	return true

func vehicles_overlap(a:RigidBody3D,b:RigidBody3D,padding:=0.0)->bool:
	return delivery_overlap(Vector2(a.position.x,a.position.z),Vector2(a.basis.z.x,a.basis.z.z).normalized(),a.half_size,b,padding)

func reserve_delivery_junctions()->void:
	for center in delivery_junctions:
		var owner=intersection_owners.get(center)
		if is_instance_valid(owner) and owner.freeze and not is_instance_valid(owner.claimed_by):
			if Vector2(owner.position.x,owner.position.z).distance_to(center)<8.5:continue
		intersection_owners.erase(center)
		var nearest:=8.5
		for traffic in moving_vehicles:
			var body=traffic.body
			if not is_instance_valid(body) or not body.freeze or is_instance_valid(body.claimed_by):continue
			var distance:float=Vector2(body.position.x,body.position.z).distance_to(center)
			if distance<nearest:nearest=distance;intersection_owners[center]=body

func update_traffic(delta:float)->void:
	if game.phase!="playing":return
	reserve_delivery_junctions()
	for traffic in moving_vehicles:
		# A consumed body can outlive its node in this route record. Validate the
		# Variant before assigning to a typed Object, which rejects freed values.
		if not is_instance_valid(traffic.body):continue
		var body:RigidBody3D=traffic.body
		if not body.freeze or is_instance_valid(body.claimed_by):continue
		if Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length_squared()<pow(game.player.radius+3.0,2):continue
		var progress:float=traffic.progress+traffic.speed*delta
		var pose:=Neighborhoods.lane_sample(progress,int(traffic.get("route_id",0)))
		var forward:Vector2=pose.forward
		var half:Vector3=body.half_size
		var extent:=Vector2(absf(forward.y)*half.x+absf(forward.x)*half.z,absf(forward.x)*half.x+absf(forward.y)*half.z)
		var predicted:=Rect2(pose.at-extent,extent*2).grow(.18)
		var blocked:=false
		for center in intersection_owners:
			if intersection_owners[center]==body:continue
			var crossing:=Rect2(center-Vector2.ONE*5.0,Vector2.ONE*10.0)
			if predicted.intersects(crossing):blocked=true;break
		for other in moving_vehicles:
			if other.body==body or not is_instance_valid(other.body) or is_instance_valid(other.body.claimed_by):continue
			if delivery_overlap(pose.at,forward,half,other.body,.28):blocked=true;break
		if blocked:continue
		traffic.progress=fposmod(progress,Neighborhoods.lane_length(int(traffic.get("route_id",0))))
		body.position.x=pose.at.x;body.position.z=pose.at.y
		body.rotation.y=atan2(forward.x,forward.y)

func near_tower(at:Vector2,extra:float)->bool:
	for plot in occupied_plots:
		if absf(at.x-plot.at.x)<plot.radius+extra and absf(at.y-plot.at.y)<plot.radius+extra:return true
	return false

func support(child:RigidBody3D,parent:RigidBody3D,level:int)->void:
	child.support_parent=parent
	parent.supported_food.append(child)
	child.set_meta("stack_level",level)
	child.set_meta("stack_origin",child.position)

func build_tower(at:Vector2,index:int,spec:Dictionary={})->void:
	var family:String=spec.get("family","apartments")
	if family in ["wafer_gate","berry_water_tower"]:
		build_structural_landmark(at,index,spec);return
	var kind:String=spec.get("kind",["cake","burger","pancake","donut"][index%4])
	var size:float=spec.get("size",1.78+float(index%3)*.12)
	var flavor:int=int(spec.get("flavor",(index/4)%4))
	var count:int=int(spec.get("floors",(3+index%2) if kind=="burger" else (7+index%3) if kind=="donut" else (5+index%3)))
	var yaw:float=spec.get("yaw",0.0)
	if family=="wedding_cake":kind="cake";count=3
	elif family=="diner":kind="burger";count=2
	elif family=="cakery":kind="cake";count=2
	var base:RigidBody3D
	var previous:RigidBody3D
	var tiers:Array[Node3D]=[]
	var y:=.025
	var bound:=0.0
	for level in count:
		var step_size:=size*(1.0-level*.025)
		if family=="wedding_cake":step_size=size*(1.0-level*.26)
		# Small offsets make unsupported floors tip against their neighbours.
		var offset:=Vector2(sin(index*1.7+level*.8),cos(index+level*.9))*.11 if level>0 else Vector2.ZERO
		var shop_floor:bool=level==0 and family in ["cakery","diner"]
		var rounded:bool=family=="wedding_cake" or (family=="diner" and level>0)
		var body:=food(kind,at+offset.rotated(-yaw),step_size,8 if level>0 else 12,not rounded,4 if shop_floor else flavor)
		body.rotation.y=yaw
		body.position.y=y+body.height*.5
		y+=body.height+.012
		body.set_meta("food_building",true);body.set_meta("tower_id",towers.size())
		body.set_meta("structural_shell",true)
		body.set_meta("stack_level",level);body.set_meta("stack_origin",body.position)
		if level==0:base=body
		else:support(body,previous,level)
		previous=body;tiers.append(body)
		bound=maxf(bound,maxf(body.half_size.x,body.half_size.z)+offset.length())
	var topper:=food("berry" if index%2==0 else "donut",at,size*.36,3,false,flavor)
	topper.position.y=y+topper.height*.5+.015;support(topper,previous,count);tiers.append(topper)
	topper.rotation.y=yaw
	topper.set_meta("food_building",true);topper.set_meta("tower_id",towers.size())
	for body in tiers:
		body.set_meta("structure_height",y+topper.height)
		body.set_meta("structure_width",bound*2.0)
	towers.append({"at":at,"radius":bound,"base":base,"height":y+topper.height,"tiers":tiers,"kind":kind,"yaw":yaw,"role":spec.get("role","housing"),"family":family})
	occupied_plots.append({"at":at,"radius":bound})

func build_structural_landmark(at:Vector2,index:int,spec:Dictionary)->void:
	var size:float=spec.size;var yaw:float=spec.yaw
	var family:String=spec.family
	var tiers:Array[Node3D]=[];var heads:Array[Node3D]=[]
	var base:Node3D=null;var height:=0.0
	var columns:Array=[Vector2(-.72,0),Vector2(.72,0)] if family=="wafer_gate" else [Vector2(-.65,-.65),Vector2(.65,-.65),Vector2(-.65,.65),Vector2(.65,.65)]
	for corner in columns:
		var previous:Node3D=null;var y:=.025
		for level in 4:
			var body:=food("pancake",at+(corner*size).rotated(-yaw),size*.30,5,true,index%4)
			body.set_meta("structural_shell",true)
			body.rotation.y=yaw;body.position.y=y+body.height*.5;y+=body.height+.01
			if previous!=null:support(body,previous,level)
			elif base==null:base=body
			previous=body;tiers.append(body)
		heads.append(previous);height=maxf(height,y)
	if family=="wafer_gate":
		# Each short span is a separate wafer slab on its nearest column. Removing
		# one pillar releases its slabs; real contacts decide how the bridge tips.
		for i in 5:
			var body:=food("pancake",at+Vector2((i-2)*size*.36,0).rotated(-yaw),size*.32,8,true,index%4)
			body.set_meta("structural_shell",true)
			body.rotation.y=yaw;body.position.y=height+body.height*.5
			support(body,heads[0 if i<3 else 1],4);tiers.append(body)
		var crown:=food("donut",at,size*.38,5,false,index%4)
		crown.position.y=height+size*.29+crown.height*.5;support(crown,tiers[tiers.size()-3],5);tiers.append(crown)
		height=crown.position.y+crown.height*.5
	else:
		var tank:=food("berry",at,size*.9,20)
		tank.set_meta("structural_shell",true)
		tank.position.y=height+tank.height*.5;support(tank,heads[0],4);tiers.append(tank)
		height=tank.position.y+tank.height*.5
	for i in tiers.size():
		var body:Node3D=tiers[i]
		body.set_meta("food_building",true);body.set_meta("tower_id",towers.size())
		body.set_meta("stack_origin",body.position)
		body.set_meta("structure_height",height)
		body.set_meta("structure_width",size*2.9)
	towers.append({"at":at,"radius":size*1.45,"base":base,"height":height,"tiers":tiers,"kind":"pancake" if family=="wafer_gate" else "berry","yaw":yaw,"role":"landmark","family":family})
	occupied_plots.append({"at":at,"radius":size*1.45})

func build_pile(at:Vector2,index:int,width:int,size:float,yaw:=0.0,base_footprint:=0.0)->void:
	var pieces:Array[Node3D]=[]
	var previous:Array[Node3D]=[]
	var roots:Array[Node3D]=[]
	var y:=.025
	var step:=size*2.12
	var platter:Node3D=null
	if width==5 and base_footprint>0.0:
		# One existing center-bottom piece becomes a real broad cookie support.
		# All other pieces stay separate; this replaces rather than adds a body.
		platter=food("cookie",at,base_footprint/.9,10,false,index%4)
		platter.rotation.y=yaw;platter.set_meta("pile_id",piles.size())
		platter.set_meta("stack_level",0);platter.set_meta("stack_origin",platter.position)
		platter.set_meta("growth_platter",true)
		pieces.append(platter);roots.append(platter)
		y=platter.position.y+platter.half_size.y+.015
	for layer in width:
		var count:=width-layer
		var row:Array[Node3D]=[]
		var kind:String=["donut","cookie","pancake","donut","cake"][layer%5]
		var layer_height:=0.0
		for iz in count:
			for ix in count:
				if platter!=null and layer==0 and ix==2 and iz==2:
					row.append(platter)
					continue
				var pos:=at+Vector2(ix-(count-1)*.5,iz-(count-1)*.5)*step
				if width==3 and layer>0:
					var parent:Node3D=previous[iz*(count+1)+ix]
					pos=Vector2(parent.position.x,parent.position.z)+Vector2(.035,-.025)
				pos=at+(pos-at).rotated(-yaw)
				var body:=food(kind,pos,size,1 if width==3 else 2,false,(index+layer)%4)
				body.rotation.y=yaw
				body.position.y=y+body.height*.5;body.set_meta("pile_id",piles.size())
				body.set_meta("stack_level",layer);body.set_meta("stack_origin",body.position)
				if layer==0:
					if platter==null:roots.append(body)
					else:support(body,platter,1)
				else:
					var parent_index:=iz*(count+1)+ix
					# The missing center donut is the platter itself; the next
					# cookie instead rests on the adjacent intact bottom donut.
					if previous[parent_index]==platter:parent_index+=1
					support(body,previous[parent_index],layer+1 if platter!=null else layer)
				row.append(body);pieces.append(body);layer_height=maxf(layer_height,body.height)
		previous=row;y+=layer_height+.015
	# A tall central crown makes the larger piles visible from the next street.
	var top:RigidBody3D=previous[0]
	if width>=5:
		for level in 4:
			var body:=food("donut" if level%2==0 else "pancake",at,size*.94,2,false,(index+level)%4)
			body.position.y=y+body.height*.5;support(body,top,width+level)
			body.set_meta("pile_id",piles.size());pieces.append(body)
			top=body;y+=body.height+.015
	var bound:=maxf(width*step*.5,base_footprint)
	piles.append({"at":at,"radius":bound,"pieces":pieces,"roots":roots,"height":y,"starter":width==3,"growth_platter":platter})
	occupied_plots.append({"at":at,"radius":bound})

func record_collection(item:Node3D,hole:Node3D)->void:
	if hole!=game.player:return
	var id:=item.get_instance_id()
	if collected_food.has(id):return
	collected_food[id]=true
	if item.has_meta("tower_id"):
		var index:int=item.get_meta("tower_id")
		var before:int=building_collections.get(index,0)
		building_collections[index]=before+1
		var tower:Dictionary=towers[index]
		var threshold:int=ceili(tower.tiers.size()*.6)
		if before<threshold and before+1>=threshold:
			collection_progress.buildings+=1
			if tower.role=="landmark":collection_progress.landmarks+=1
	if item.has_meta("pile_id"):
		var index:int=item.get_meta("pile_id")
		var before:int=pile_collections.get(index,0)
		pile_collections[index]=before+1
		var pile:Dictionary=piles[index]
		var threshold:int=ceili(pile.pieces.size()*.6)
		if not pile.starter and before<threshold and before+1>=threshold:collection_progress.heaps+=1

func objective_target(hole:Node3D)->Node3D:
	var best:Node3D=null;var nearest:=INF
	# The large goals require receipts, not support-release telemetry. Keep
	# guiding toward remaining independently edible roots and fallen pieces.
	var need_landmark:bool=collection_progress.landmarks<int(game.FOOD_CITY_GOALS.landmarks)
	var need_heap:bool=collection_progress.heaps<int(game.FOOD_CITY_GOALS.heaps)
	var need_buildings:bool=collection_progress.buildings<int(game.FOOD_CITY_GOALS.buildings)
	for i in towers.size():
		var tower:Dictionary=towers[i]
		if not need_buildings and (not need_landmark or tower.role!="landmark"):continue
		if int(building_collections.get(i,0))>=ceili(tower.tiers.size()*.6):continue
		for body in tower.tiers:
			if not is_instance_valid(body) or body.consumed or not body.can_fit(hole):continue
			if is_instance_valid(body.claimed_by) and body.claimed_by!=hole:continue
			var distance:float=Vector2(body.position.x-hole.position.x,body.position.z-hole.position.z).length()
			if need_landmark and tower.role=="landmark":distance*=.65
			if distance<nearest:nearest=distance;best=body
	if need_heap:
		for i in piles.size():
			var pile:Dictionary=piles[i]
			if pile.starter or int(pile_collections.get(i,0))>=ceili(pile.pieces.size()*.6):continue
			for body in pile.pieces:
				if not is_instance_valid(body) or body.consumed or not body.can_fit(hole):continue
				if is_instance_valid(body.claimed_by) and body.claimed_by!=hole:continue
				var distance:float=Vector2(body.position.x-hole.position.x,body.position.z-hole.position.z).length()*.8
				if distance<nearest:nearest=distance;best=body
	return best

func record_collapse(body:Node3D)->void:
	if collapse_events.size()>=256:collapse_events.pop_front()
	collapse_events.append({"body":body.name,"level":body.get_meta("stack_level",0),"time":Time.get_ticks_msec(),"at":body.position})

func mesh_for(kind:String,tower:bool,flavor:=0)->ArrayMesh:
	var key:=mesh_key(kind,tower,flavor)
	if mesh_cache.has(key):return mesh_cache[key]
	var root:=Node3D.new();add_child(root)
	Shapes.build(self,root,kind,tower,flavor)
	Batch.combine(root,[],null,true)
	var node:MeshInstance3D=root.get_child(0)
	var mesh:ArrayMesh=node.mesh
	mesh_cache[key]=mesh;root.free()
	return mesh

func mesh_key(kind:String,tower:bool,flavor:int)->String:
	if tower and flavor>=4 and kind in ["cake","burger"]:return kind+"_shop"
	var colored:bool=kind in ["cake","donut","cookie"] or (tower and kind=="pancake")
	return kind+("_tower" if tower else "")+("_%d"%posmod(flavor,4) if colored else "")

func round_food_shape(radius:float,height:float)->ConvexPolygonShape3D:
	var key:=Vector2(radius,height)
	if round_collision_cache.has(key):return round_collision_cache[key]
	# Native cylinder edge/circle clipping can exceed its two-contact buffer
	# during thin or tilted food contacts. A shared regular convex prism takes
	# the polygon contact path while preserving height and outer radius. Its
	# Sixteen points per cap stay within the SAT support-face budget; a 32-point
	# cap is truncated by that path and produced persistent rocking in testing.
	# Radial inset is at most 1.922%, below the existing admission margin.
	var points:=PackedVector3Array()
	for y in [-height*.5,height*.5]:
		for i in ROUND_COLLISION_SIDES:
			var angle:=TAU*float(i)/ROUND_COLLISION_SIDES
			points.append(Vector3(cos(angle)*radius,y,sin(angle)*radius))
	var shape:=ConvexPolygonShape3D.new()
	shape.points=points
	round_collision_cache[key]=shape
	return shape

func food(kind:String,at:Vector2,size:float,points:int,tower:=false,flavor:=0)->RigidBody3D:
	var mesh:=mesh_for(kind,tower,flavor)
	var bounds:=mesh.get_aabb()
	var extent:=bounds.size*size
	var body:=_food(at,extent,"food_"+kind,points)
	body.set_meta("food_kind",kind);body.set_meta("food_mesh_key",mesh_key(kind,tower,flavor))
	# Ordinary snacks, rain and decorative crowns never opt into occlusion.
	body.set_meta("structural_shell",false)
	food_kind_counts[kind]=int(food_kind_counts.get(kind,0))+1
	if kind not in ["bacon","sushi"] and not (tower and kind in ["cake","pancake"]):
		var radius:=maxf(extent.x,extent.z)*.5
		var shape:=round_food_shape(radius,extent.y)
		for child in body.get_children():
			if child is CollisionShape3D:child.shape=shape
		body.footprint=radius
		body.terrain_sweep_points=shape.points
	body.half_size=extent*.5
	if food_material==null:
		food_material=ShaderMaterial.new()
		food_material.shader=Glaze
		food_material.set_shader_parameter("reveal_use_instance",false)
		food_material.set_shader_parameter("reveal_occluder",0.0)
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=food_material
	body.add_child(visual);visual.scale=Vector3.ONE*size;visual.position=-bounds.get_center()*size
	body.food_visual=visual
	if spatial_ready:register_food(body)
	return body

func batch_static_food()->void:
	# Food remains opaque both in a batch and after independent physical release.
	if food_batch_material==null:
		food_batch_material=food_material.duplicate()
		food_batch_material.set_shader_parameter("reveal_use_instance",false)
	var groups:Dictionary={}
	for body in foods:
		if not body.has_meta("food_kind") or body.get_meta("traffic",false):continue
		var cell:=Vector2i(floori(body.position.x/BATCH_CELL),floori(body.position.z/BATCH_CELL))
		var key:String=body.get_meta("food_mesh_key")+"@%d,%d"%[cell.x,cell.y]
		if not groups.has(key):groups[key]=[]
		groups[key].append(body)
	for key in groups:
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
		# Compatibility stores color/custom data together. Explicit white
		# prevents its initially zero color lane from blackening vertex colors.
		mm.use_colors=true
		mm.use_custom_data=true
		mm.mesh=groups[key][0].food_visual.mesh;mm.instance_count=groups[key].size();mm.visible_instance_count=groups[key].size()
		var view:=MultiMeshInstance3D.new();view.multimesh=mm;view.material_override=food_batch_material
		add_child(view);batch_count+=1;batch_cells[key]=groups[key].size()
		var members:Array[Node3D]=[];var bounds:=AABB()
		for i in groups[key].size():
			var body:Node3D=groups[key][i]
			var pose:Transform3D=body.transform*body.food_visual.transform
			mm.set_instance_transform(i,pose)
			mm.set_instance_color(i,Color.WHITE)
			mm.set_instance_custom_data(i,Color(0,0,0,0))
			var at:AABB=pose*mm.mesh.get_aabb();bounds=at if i==0 else bounds.merge(at)
			members.append(body)
			body.batch=mm;body.batch_index=i;body.batch_members=members;body.food_visual.visible=false
		mm.custom_aabb=bounds

func spawn_rain(kind:String,at:Vector2,altitude:=20.0)->RigidBody3D:
	var body:=food(kind,at,.48+float(rain_serial%3)*.12,2,false,rain_serial%4)
	body.is_rain=true;body.position.y=altitude;body.max_contacts_reported=4
	body.freeze=false;body.collision_layer=2;body.collision_mask=3
	body.gravity_scale=1.0;body.linear_damp=.25;body.angular_damp=1.5
	body.angular_velocity=Vector3(.20,.35,-.15)
	body.set_physics_process(true);rain_bodies.append(body);rain_serial+=1
	activate_food(body)
	return body

func batch_settled_rain()->void:
	for body in rain_bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.batch!=null:continue
		if not body.rain_landed or not body.sleeping or is_instance_valid(body.claimed_by):continue
		var cell:=Vector2i(floori(body.position.x/BATCH_CELL),floori(body.position.z/BATCH_CELL))
		var key:String=body.get_meta("food_mesh_key")+"@%d,%d"%[cell.x,cell.y]
		if not rain_batches.has(key):
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.use_colors=true
			mm.use_custom_data=true
			mm.mesh=body.food_visual.mesh;mm.instance_count=16;mm.visible_instance_count=0
			for i in mm.instance_count:
				mm.set_instance_color(i,Color.WHITE)
				mm.set_instance_custom_data(i,Color(0,0,0,0))
			var view:=MultiMeshInstance3D.new();view.multimesh=mm;view.material_override=food_material;add_child(view)
			var members:Array[Node3D]=[]
			rain_batches[key]={"mesh":mm,"members":members,"bounds":AABB()}
		var group:Dictionary=rain_batches[key];var mm:MultiMesh=group.mesh
		var index:int=group.members.size()
		if index==mm.instance_count:
			mm.instance_count*=2
			for i in mm.instance_count:
				mm.set_instance_color(i,Color.WHITE)
				mm.set_instance_custom_data(i,Color(0,0,0,0))
			for i in index:
				var member:Node3D=group.members[i]
				mm.set_instance_transform(i,member.transform*member.food_visual.transform)
		var pose:Transform3D=body.transform*body.food_visual.transform
		mm.set_instance_transform(index,pose);mm.set_instance_color(index,Color.WHITE);mm.set_instance_custom_data(index,Color(0,0,0,0));mm.visible_instance_count=index+1
		group.members.append(body)
		body.batch=mm;body.batch_index=index;body.batch_members=group.members;body.food_visual.visible=false
		var bounds:AABB=pose*mm.mesh.get_aabb()
		group.bounds=bounds if index==0 else group.bounds.merge(bounds);mm.custom_aabb=group.bounds

func rain_visible(at:Vector3,radius:=1.5)->bool:
	if not is_instance_valid(game.camera):return true
	# A sphere/plane test is conservative at frustum corners too. Sampling
	# only center/axis tips can miss a visible corner of a food near the edge.
	var interior:Vector3=game.camera.global_position-game.camera.global_basis.z*10.0
	for plane in game.camera.get_frustum():
		var side:=1.0 if plane.distance_to(interior)>0 else -1.0
		if plane.distance_to(at)*side < -radius:return false
	return true

func retire_distant_rain()->void:
	var player_at:=Vector2(game.player.position.x,game.player.position.z)
	for body in rain_bodies:
		if not is_instance_valid(body) or not body.rain_landed or body.rain_age<12.0:continue
		if is_instance_valid(body.claimed_by) or body.linear_velocity.length()>.8:continue
		var distance:float=Vector2(body.position.x,body.position.z).distance_to(player_at)
		if distance<RAIN_RETIRE_DISTANCE or rain_visible(body.global_position,maxf(body.half_size.length(),1.5)):continue
		if rain_retirements.size()>=128:rain_retirements.pop_front()
		rain_retirements.append({"at":body.global_position,"distance":distance,"visible":false,"landed":true,"age":body.rain_age})
		body.expose_visual();body.queue_free()

func rain_spawn_position()->Vector2:
	var origin:=Vector2(game.player.position.x,game.player.position.z)
	var a:=rain_rng.randf_range(0,TAU)
	var distance:=rain_rng.randf_range(3.5,16.0)
	# Rain follows the expanded playable perimeter too. Keep a physical margin
	# for the largest drop and its horizontal drift before landing.
	var safe_limit:=WorldBounds.PLAY_LIMIT-3.0
	return (origin+Vector2(cos(a),sin(a))*distance).clamp(Vector2.ONE*-safe_limit,Vector2.ONE*safe_limit)

func update_rain(delta:float)->void:
	if not rain_enabled or not is_instance_valid(game.player) or game.phase!="playing":return
	rain_clock-=delta
	if rain_clock>0:return
	rain_clock=2.4
	rain_bodies=rain_bodies.filter(func(b):return is_instance_valid(b) and not b.is_queued_for_deletion())
	retire_distant_rain()
	batch_settled_rain()
	rain_bodies=rain_bodies.filter(func(b):return is_instance_valid(b) and not b.is_queued_for_deletion())
	foods=foods.filter(func(b):return is_instance_valid(b) and not b.is_queued_for_deletion())
	var airborne:=0
	for body in rain_bodies:
		# Sleep is an engine optimization, not proof of support. Swept contact
		# tells us whether a food has landed even if its rigid body stays awake.
		if not body.rain_landed:airborne+=1
	var count:=mini(6,mini(RAIN_LIMIT-rain_bodies.size(),AIRBORNE_LIMIT-airborne))
	if count<=0:return
	for i in count:
		# The retained budget covers an entire four-minute idle round. Nearby
		# landed foods stay edible, while only distant hidden foods can retire.
		var at:=rain_spawn_position()
		spawn_rain(Shapes.KINDS[rain_serial%10],at,18.0+float(i%3)*2.0)
	rain_waves+=1
	if rain_waves==1 or rain_waves%8==0:
		game.notice="FOOD RAIN!";game.notice_time=1.8

func _physics_process(delta:float)->void:
	update_food_impacts(delta)
	update_rain(delta)

func queue_food_impact(body:Node3D,at:Vector3,speed:float)->void:
	if at.y<-.15 or speed<1.8 or impact_queue.size()>=IMPACT_LIMIT:return
	if not is_instance_valid(game.player) or at.distance_to(game.player.position)>34:return
	var kind:String=body.get_meta("food_kind","cookie")
	var style:String="thud" if body.has_meta("tower_id") else "crumb" if kind in ["cookie","pancake","bacon","pizza"] else "glaze"
	var tint:Color=Color("ffb42c") if style=="crumb" else Color("fff2c2") if kind in ["egg","sushi"] else Color("ff529e")
	# Contact solvers allow a small penetration slop. Keep a ground ripple on
	# the visible floor, while preserving raised contacts on roofs and stacks.
	var presentation_at:=Vector3(at.x,maxf(.025,at.y+.035),at.z)
	impact_queue.append({"at":presentation_at,"strength":clampf(speed/6,.45,1.4),"kind":kind,"style":style,"color":tint,"time":0.0,"serial":impact_serial})
	impact_serial+=1

func impact_wave(style:String)->AudioStreamWAV:
	var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=22050
	var length:=3308 if style!="thud" else 5513
	var data:=PackedByteArray();data.resize(length*2)
	var noise:=RandomNumberGenerator.new();noise.seed=937+style.hash()
	var low:=0.0
	for i in length:
		var t:=float(i)/22050;var fade:=pow(1.0-float(i)/length,3)
		low=lerpf(low,noise.randf_range(-1,1),.12)
		var value:float=low*.7+sin(t*TAU*(125 if style=="thud" else 370 if style=="glaze" else 710))*exp(-t*35)*.4
		data.encode_s16(i*2,int(clampf(value*fade,-1,1)*9000))
	wave.data=data;return wave

func ensure_impact_visuals()->void:
	if crumb_batch!=null:return
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var cube:=BoxMesh.new();cube.size=Vector3.ONE*.13
	var ring:=TorusMesh.new();ring.inner_radius=.87;ring.outer_radius=1.0;ring.rings=16;ring.ring_segments=4
	for i in 2:
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
		mm.mesh=cube if i==0 else ring;mm.instance_count=IMPACT_LIMIT*(6 if i==0 else 1);mm.visible_instance_count=0
		var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
		if i==0:crumb_batch=mm
		else:glaze_batch=mm
	for style in ["crumb","glaze","thud"]:impact_sounds[style]=impact_wave(style)
	for i in 3:
		var player:=AudioStreamPlayer3D.new();player.volume_db=-16;player.unit_size=18;player.max_distance=70
		player.bus="SFX"
		add_child(player);impact_audio.append(player)

func update_food_impacts(delta:float)->void:
	impact_sound_clock=maxf(0,impact_sound_clock-delta)
	if impact_queue.is_empty() and impacts.is_empty():return
	ensure_impact_visuals()
	for entry in impact_queue:
		if impacts.size()>=IMPACT_LIMIT:break
		impacts.append(entry)
		if food_impact_events.size()>=128:food_impact_events.pop_front()
		food_impact_events.append(entry.duplicate())
		if impact_sound_clock<=0:
			var player:AudioStreamPlayer3D=impact_audio[int(entry.serial)%impact_audio.size()]
			player.position=entry.at;player.stream=impact_sounds[entry.style];player.pitch_scale=.9+float(int(entry.serial)%5)*.06
			if DisplayServer.get_name()!="headless":player.play()
			impact_sound_clock=.08
	impact_queue.clear()
	var kept:Array[Dictionary]=[];var crumb_index:=0;var ring_index:=0
	for entry in impacts:
		entry.time+=delta
		var duration:=.8 if entry.style=="thud" else .55
		var progress:float=entry.time/duration
		if progress>=1:continue
		kept.append(entry)
		var color:Color=entry.color;color.a=1-progress
		for i in 6:
			var angle:float=i*TAU/6+float(entry.serial)*.37
			var radius:float=entry.time*(1.2 if entry.style=="thud" else .8)*entry.strength
			var rise:float=maxf(0.0,entry.time*(2.0-entry.time*5.0))
			var at:Vector3=entry.at+Vector3(cos(angle)*radius,rise,sin(angle)*radius)
			var scale:float=(1-progress*.75)*(1.4 if entry.style=="thud" else 1.0)
			crumb_batch.set_instance_transform(crumb_index,Transform3D(Basis.from_euler(Vector3(i,angle,entry.time*8)).scaled(Vector3.ONE*scale),at))
			crumb_batch.set_instance_color(crumb_index,color);crumb_index+=1
		var radius:float=(.16+progress*.65)*entry.strength
		glaze_batch.set_instance_transform(ring_index,Transform3D(Basis.IDENTITY.scaled(Vector3(radius,.12,radius)),entry.at))
		glaze_batch.set_instance_color(ring_index,color);ring_index+=1
	impacts=kept;crumb_batch.visible_instance_count=crumb_index;glaze_batch.visible_instance_count=ring_index
	var bounds:=AABB(game.player.position-Vector3(38,6,38),Vector3(76,42,76))
	crumb_batch.custom_aabb=bounds;glaze_batch.custom_aabb=bounds

func register_food(body:Node3D)->void:
	if spatial_ready:food_queries.register(body)

func query_foods(at:Vector3,reach:float)->Array[Node3D]:
	return food_queries.query(at,reach)

func scan_candidates(holes:Array)->Array[Node3D]:
	return food_queries.scan(holes)
