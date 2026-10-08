extends Node3D
## An original edible royal court. Scripted standing toys yield to physics once.
const Routes=preload("res://fidelity/toy_actor_routes.gd")
const Neighborhoods=preload("res://fidelity/toy_neighborhoods.gd")
const Guards=preload("res://fidelity/toy_guard_shapes.gd")
const MAX_EVENTS:=256
const LIVING_ROLES:Array[String]=["guard","guard","guard","guard","sentry","captain","knight","king","queen","princess","steward","courier","page","herald","courtier","courtier","jester","drummer","toymaker","balloon_vendor"]
const MILITARY:=["guard","captain","knight"]
const ROYALS:=["king","queen","princess","steward"]
const TRANSPORT:=["courier","page","herald"]
const FESTIVAL:=["jester","drummer"]
const RECIPES:Array[Dictionary]=[
	{"id":"crown_spinner","base":"toy_block","top":"bubble_turret","motion":"spin"},
	{"id":"royal_mailbox","base":"toy_block","top":"toy_ball","motion":"bob"},
	{"id":"ribbon_organ","base":"toy_arch","top":"toy_train","motion":"slide"},
	{"id":"parade_mascot","base":"toy_car","top":"toy_duck","motion":"bob"},
	{"id":"candy_drum","base":"toy_block","top":"toy_ball","motion":"spin"},
	{"id":"royal_chime","base":"toy_arch","top":"toy_ball","motion":"sway"},
	{"id":"guard_bell","base":"block_tower","top":"toy_ball","motion":"spin"},
	{"id":"bubble_fountain","base":"bubble_turret","top":"toy_ball","motion":"bob"},
	{"id":"moon_clock","base":"toy_block","top":"toy_arch","motion":"sway"},
	{"id":"star_wheel","base":"toy_arch","top":"toy_block","motion":"spin"}
]
var city:Node3D
var game:Node
var actors:Array[Dictionary]=[]
var living:Array[Dictionary]=[]
var ambient:Array[Dictionary]=[]
var beacons:Array[Dictionary]=[]
var installations:Array[Dictionary]=[]
var parade:Array[Dictionary]=[]
var activity_receipts:Array[Dictionary]=[]
var gate_beacon_receipts:Array[Dictionary]=[]
var group_alarm_until:Array[float]=[0.0,0.0,0.0,0.0]
var group_alarm_at:Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var guard_cycles:Array[int]=[-1,-1,-1,-1]
var separation_passes:=0
var released_count:=0
var _reserved:Array[Rect2]=[]

func _event(kind:String,row:Dictionary,extra:Dictionary={})->void:
	var record:={"elapsed":float(game.elapsed),"event":kind,"id":str(row.get("id","court")),"role":str(row.get("role","court")),"state":str(row.get("state",""))}
	record.merge(extra,true);activity_receipts.append(record)
	if activity_receipts.size()>MAX_EVENTS:activity_receipts.pop_front()

func _state(row:Dictionary,next:String)->void:
	if row.state==next:return
	row.state=next;_event("state_changed",row)

func _spec(kind:String,at:Vector2,size:Vector3,palette:int,points:int,airborne:=false)->Dictionary:
	return {"kind":kind,"at":at,"size":size,"tier":1 if points<=2 else 2,"points":points,"palette":palette,"neighborhood":"royal_court","yaw":0.0,"tower_id":"","tower_level":0,"bottom":.04,"landmark":false,"court_actor":true,"airborne":airborne}

func _row(body:Node3D,id:String,role:String,group:String,route:int,progress:float,index:int)->Dictionary:
	var result:={"id":id,"role":role,"group":group,"body":body,"visual":body.get_node("ToyVisual"),"route":route,"route_progress":progress,"formation":route%4,"formation_rank":index%8,"speed":.72+float(index%5)*.075,"phase":float(index)*.71,"rest_cycle":12.0+float(index%5)*1.9,"rest_window":1.7+float(index%3)*.6,"rest_offset":float(index%11),"state":"idle","alarm_target":Vector2.ZERO,"alert_until":0.0,"released":false,"previous_at":Vector2(body.position.x,body.position.z),"origin":body.position,"route_direction":1,"parts":[body],"part_origins":[body.position],"last_delivery_station":-1,"delivery_rest_until":0.0}
	body.set_meta("court_id",id);body.set_meta("court_role",role);body.set_meta("court_group",group)
	actors.append(result)
	return result

func _guard(role:String,at:Vector2,size:Vector3,palette:int,points:int,index:int)->Node3D:
	assert(role in Guards.KINDS,"A court role must have its own authored model")
	var body:Node3D=city.spawn_court_body(_spec(role,at,size,palette,points,role=="royal_drone"),Guards.mesh_for(role,palette),Guards.collision_parts_for(role))
	body.set_meta("resident",role!="royal_drone")
	return body

func _installation_site(preferred:Vector2)->Vector2:
	for ring in 9:
		for index in maxi(1,ring*8):
			var angle:float=TAU*float(index)/maxi(1,ring*8)
			var at:Vector2=preferred+Vector2.from_angle(angle)*float(ring)*.6
			var bounds:=Rect2(at-Vector2(.62,.62),Vector2(1.24,1.24))
			if not Neighborhoods.clear_of_roads(bounds.grow(.08)):continue
			var clear:=true
			for existing in _reserved:
				if bounds.grow(.06).intersects(existing,true):clear=false;break
			if clear:_reserved.append(bounds);return at
	return Vector2(INF,INF)

func _place_gate_beacon(body:Node3D,group:int)->Vector2:
	var district:Dictionary=Neighborhoods.districts()[group]
	var wanted:Vector2=district.center+Vector2(10,8)
	var palace:Node3D
	for candidate in city.static_foods():
		if candidate.get_meta("toy_kind","")!="toy_castle" or candidate.get_meta("neighborhood","")!=district.id:continue
		if Vector2(candidate.position.x,candidate.position.z).distance_to(wanted)<.01:palace=candidate;break
	assert(is_instance_valid(palace),"A gate beacon must belong to its actual lower palace")
	var palace_at:=Vector2(palace.position.x,palace.position.z)
	var forward:=Vector2(sin(palace.rotation.y),cos(palace.rotation.y))
	# The full rotating beacon's measured radial envelope clears the original
	# facade, while the ordinary level-five mouth can reach the palace's foot.
	var offset:float=palace.half_size.z+body.footprint+.12
	var at:Vector2=palace_at+forward*offset
	assert(offset<3.5*.9,"The gate approach must remain inside earned level-five admission")
	var radius:float=body.footprint
	var bounds:=Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2)
	assert(Neighborhoods.clear_of_roads(bounds.grow(.04)),"A palace beacon cannot narrow an open road")
	var nearest_other_clearance:=INF
	for other in city.static_foods():
		if other==palace:continue
		var other_at:=Vector2(other.position.x,other.position.z)
		nearest_other_clearance=minf(nearest_other_clearance,at.distance_to(other_at)-radius-other.footprint)
	assert(nearest_other_clearance>.04,"A gate beacon must clear every other actual toy envelope")
	var nearest_route_distance:=INF
	for route in Routes.PATHS.size():nearest_route_distance=minf(nearest_route_distance,sqrt(float(Routes.closest(at,route).distance)))
	assert(nearest_route_distance>Routes.HALF_WIDTH+radius,"A gate beacon must clear marching and civilian corridors")
	body.position.x=at.x;body.position.z=at.y;body.spawn_position=body.position
	body.set_meta("gate_palace_id",str(palace.name));body.set_meta("gate_front_clearance",.12)
	# Later two-owner installations use the same real clearance reservation.
	_reserved.append(bounds.grow(.12))
	gate_beacon_receipts.append({"beacon":str(body.name),"palace":str(palace.name),"district":str(district.id),"at":at,"palace_at":palace_at,"front_offset":offset,"beacon_radius":radius,"facade_half_depth":palace.half_size.z,"front_clearance":offset-radius-palace.half_size.z,"palace_required_radius":palace.footprint*1.08,"palace_minimum_level":int(palace.get_meta("minimum_level")),"nearest_other_toy_clearance":nearest_other_clearance,"nearest_actor_route_distance":nearest_route_distance})
	return at

func build(owner_city:Node3D,owner_game:Node)->void:
	city=owner_city;game=owner_game
	for body in city.static_foods():_reserved.append(Neighborhoods.bounds_for(Vector2(body.position.x,body.position.z),body.half_size*2,body.rotation.y))
	# Sixteen distinct living silhouettes inhabit each palette's palace loop.
	# Four marching guards plus the captain and knight form a real six-toy unit.
	for group in 4:
		var palette:int=[1,0,4,3][group]
		var station:Vector2=Routes.guard_station(group)
		var military_rank:=0
		for index in LIVING_ROLES.size():
			var role:String=LIVING_ROLES[index]
			var progress:float=Routes.length(group)*(float(index)+.4)/LIVING_ROLES.size()
			var pose:Dictionary=Routes.sample(progress,group)
			var at:Vector2=pose.at
			var formation_rank:=index%8
			if role in MILITARY:
				formation_rank=military_rank;military_rank+=1
				progress=Routes.length(group)*.22-float(formation_rank/2)*1.05
				pose=Routes.sample(progress,group)
				var side:=Vector2(-pose.forward.y,pose.forward.x)
				at=pose.at+side*(.55 if formation_rank%2==0 else -.55)
			elif role=="sentry":at=station+Vector2(-5,1.3)
			elif role in ROYALS:at=station+Vector2((index-8.5)*1.8,-1.15)
			elif role in FESTIVAL:at=station+Vector2(6+float(index%2)*2,1.1)
			var size:=Vector3(.76,1.65,.68) if role in MILITARY else Vector3(.9,1.85,.74) if role in ROYALS else Vector3(.74,1.65,.66)
			var body:=_guard(role,at,size,palette,4 if role in ROYALS else 2 if role in TRANSPORT else 3,group*20+index)
			var row:=_row(body,"court_%02d_%s"%[group*20+index,role],role,"living",group,progress,index)
			row.formation_rank=formation_rank;living.append(row)
	# Four different real ambient roles share an original royal-drone silhouette.
	for index in 48:
		var route:=index%6
		var progress:float=Routes.length(route)*(float(index/6)+.35)/8.0
		var pose:Dictionary=Routes.sample(progress,route)
		var body:=_guard("royal_drone",pose.at,Vector3(.62,.72,.62),index%5,2,index)
		body.position.y+=.45+float(index%3)*.25
		var row:=_row(body,"royal_drone_%02d"%index,["parcel_drone","royal_lantern","bubble_scout","court_clockwork"][index%4],"ambient",route,progress,index)
		ambient.append(row)
	for index in 8:
		var at:Vector2=Routes.guard_station(index%4)+Vector2(-7 if index<4 else 7,1.7)
		var body:Node3D=city.spawn_court_body(_spec("bubble_turret",at,Vector3(.62,1.5,.58),index%5,2))
		if index>=4:at=_place_gate_beacon(body,index%4)
		beacons.append(_row(body,"palace_beacon_%02d"%index,"palace_beacon","beacons",index%4,float(Routes.closest(at,index%4).progress),index))
	# One hundred actual two-owner court assemblies, ten distinct recipes.
	for index in 100:
		var group:=index%4;var district:Dictionary=Neighborhoods.districts()[group]
		var sequence:int=index/4
		var preferred:Vector2=district.center+Vector2(-12.8+float(sequence%5)*6.4,-11.5+float(sequence/5)*5.5)
		var at:=_installation_site(preferred)
		assert(at.is_finite(),"A court installation could not find a physically clear parcel")
		var recipe:Dictionary=RECIPES[index%RECIPES.size()]
		var base:Node3D=city.spawn_court_body(_spec(recipe.base,at,Vector3(.9,.68,.85),int(district.palette),2))
		var top_spec:=_spec(recipe.top,at,Vector3(.60,.65,.58),(int(district.palette)+2)%5,1)
		top_spec.tower_id="court_installation_%03d"%index;top_spec.tower_level=1
		var top:Node3D=city.spawn_court_body(top_spec)
		base.set_meta("tower_id",top_spec.tower_id)
		city.bind_toy_support(base,top)
		var row:=_row(base,"court_installation_%03d"%index,str(recipe.id),"installations",group,0.0,index)
		row.parts=[base,top];row.part_origins=[base.position,top.position];row.motion=recipe.motion
		top.set_meta("court_id",row.id);top.set_meta("court_role",row.role);top.set_meta("court_group","installations")
		installations.append(row)
	for index in 8:
		var route:=index%4;var progress:float=Routes.length(route)*(float(index/4)+.2)/2.0
		var pose:Dictionary=Routes.sample(progress,route)
		var side:=Vector2(-pose.forward.y,pose.forward.x)
		var body:Node3D=city.spawn_court_body(_spec("toy_car",pose.at+side*1.1,Vector3(1.25,.82,1.12),index%5,4))
		var row:=_row(body,"parade_carriage_%02d"%index,"parade_carriage","parade",route,progress,index)
		row.speed=1.45+float(index%3)*.12;parade.append(row)

func _released(row:Dictionary)->bool:
	if not is_instance_valid(row.body):
		if not row.released:row.released=true;released_count+=1;_state(row,"physics_released");_event("released",row)
		return true
	var body:Node3D=row.body
	if not body.freeze or is_instance_valid(body.claimed_by) or body.consumed:
		if not row.released:row.released=true;released_count+=1;_state(row,"physics_released");_event("released",row)
		return true
	return bool(row.released)

func _over_opening(body:Node3D)->bool:
	for hole in game.holes:
		if not is_instance_valid(hole) or not hole.active or not body.can_fit(hole):continue
		var at:Vector3=body.interaction_position()
		if Vector2(at.x-hole.position.x,at.z-hole.position.z).length()<hole.radius*.9:
			body.begin_swallow(hole);return true
	return false

func _face(body:Node3D,velocity:Vector2,delta:float)->void:
	if velocity.length_squared()<.0001:return
	var desired:=atan2(velocity.x,velocity.y)
	var blended:=lerp_angle(body.rotation.y,desired,1.0-exp(-delta*12.0))
	body.rotation.y=desired+clampf(angle_difference(desired,blended),-PI/12.0,PI/12.0)

func _walk(row:Dictionary,destination:Vector2,speed:float,delta:float)->void:
	var body:Node3D=row.body;var before:=Vector2(body.position.x,body.position.z)
	var next:Vector2=Routes.constrain(before+(destination-before).limit_length(delta*speed),int(row.route),Routes.HALF_WIDTH-minf(.7,body.footprint))
	body.position.x=next.x;body.position.z=next.y
	_face(body,(next-before)/maxf(.0001,delta),delta)
	row.previous_at=before

func _route_toward(row:Dictionary,destination:Vector2)->Vector2:
	var at:=Vector2(row.body.position.x,row.body.position.z)
	if at.distance_to(destination)<1.0:return destination
	var route:int=row.route
	var current:float=Routes.closest(at,route).progress
	var target:float=Routes.closest(destination,route).progress
	var forward:float=fposmod(target-current,Routes.length(route))
	var direction:=1.0 if forward<=Routes.length(route)*.5 else -1.0
	var distance:float=forward if direction>0 else Routes.length(route)-forward
	return Routes.sample(current+direction*minf(.8,distance),route).at

func _nearest_jester(row:Dictionary)->Dictionary:
	var best:=14.0*14.0;var result:Dictionary={}
	for other in living:
		if other.role!="jester" or other.formation!=row.formation or other.released or not is_instance_valid(other.body):continue
		var distance:float=row.body.position.distance_squared_to(other.body.position)
		if distance<best:best=distance;result=other
	return result

func _guard_near_jester(row:Dictionary)->bool:
	for other in living:
		if not other.role in MILITARY or other.state!="pursuit" or other.released or not is_instance_valid(other.body):continue
		if row.body.position.distance_squared_to(other.body.position)<3.6*3.6:return true
	return false

func _update_living(row:Dictionary,delta:float)->void:
	var body:Node3D=row.body;var group:int=row.formation
	var at:=Vector2(body.position.x,body.position.z)
	var player_at:=Vector2(game.player.position.x,game.player.position.z)
	var threat:bool=at.distance_to(player_at)<game.player.radius+4.1
	var time:float=game.elapsed+row.phase
	row.alarm_target=group_alarm_at[group];row.alert_until=group_alarm_until[group]
	if threat:
		if group_alarm_until[group]<game.elapsed+2.0:
			group_alarm_until[group]=game.elapsed+5.0;group_alarm_at[group]=player_at
			_event("alarm",row,{"at":player_at})
		row.alarm_target=group_alarm_at[group];row.alert_until=group_alarm_until[group]
	var resting:bool=fposmod(time+row.rest_offset,float(row.rest_cycle))>float(row.rest_cycle)-float(row.rest_window)
	var pose:Dictionary=Routes.sample(float(row.route_progress)+.8,int(row.route))
	var destination:Vector2=pose.at
	var speed:float=row.speed
	if threat:
		_state(row,"alarm" if row.role=="sentry" else "flee")
		var away:=at-player_at
		if away.length_squared()<.001:away=Vector2.from_angle(row.phase)
		destination=Routes.constrain(at+away.normalized()*4.5,int(row.route));speed=2.35
	elif row.role=="sentry":
		_state(row,"sentry");destination=Vector2(row.origin.x,row.origin.z);speed=.5
	elif row.role in ROYALS:
		_state(row,"royal_idle");destination=Vector2(row.origin.x,row.origin.z);speed=.6
		body.rotation.y=sin(time*.38)*.24
	elif resting:
		_state(row,"rest");destination=at
	elif row.role in MILITARY:
		var jester:Dictionary=_nearest_jester(row)
		if group_alarm_until[group]>game.elapsed:
			_state(row,"guard_alarm_patrol");destination=_route_toward(row,group_alarm_at[group]);speed=1.5
		elif not jester.is_empty() and fposmod(game.elapsed+row.phase,24.0)>17.0:
			_state(row,"pursuit");destination=_route_toward(row,Vector2(jester.body.position.x,jester.body.position.z));speed=1.7
		else:
			if int(floor(game.elapsed/18.0))%2==1:
				var station:Vector2=Routes.guard_station(group)+Vector2(.55 if int(row.formation_rank)%2==0 else -.55,-float(int(row.formation_rank)/2)*1.05)
				_state(row,"guard_post" if at.distance_to(station)<.35 else "guard_change")
				destination=_route_toward(row,station);speed=2.0
			else:
				_state(row,"march")
				var leader_progress:float=Routes.length(int(row.route))*.22+game.elapsed*.9
				var formation_pose:Dictionary=Routes.sample(leader_progress-float(int(row.formation_rank)/2)*1.05,int(row.route))
				var side:=Vector2(-formation_pose.forward.y,formation_pose.forward.x)
				destination=formation_pose.at+side*(.55 if int(row.formation_rank)%2==0 else -.55)
				speed=1.2
	elif row.role in TRANSPORT:
		speed=1.6
		var points:Array=Routes.PATHS[int(row.route)]
		var delivered_station:=-1
		for index in points.size():
			if at.distance_to(points[index])<.55 and int(row.last_delivery_station)!=index:
				row.last_delivery_station=index;row.delivery_rest_until=game.elapsed+1.2
				delivered_station=index
		var dropoff:bool=float(row.delivery_rest_until)>game.elapsed
		_state(row,"courier_dropoff" if dropoff else "courier_delivery")
		if delivered_station>=0:_event("delivery",row,{"station":delivered_station,"at":at})
		if dropoff:destination=at
	elif row.role in FESTIVAL:
		var king_at:Vector2=Routes.guard_station(group)
		if row.role=="jester" and _guard_near_jester(row):
			_state(row,"guard_evade");speed=2.2
		elif at.distance_to(king_at)<6 and fposmod(time,15.0)>8:
			_state(row,"jester_perform" if row.role=="jester" else "drummer_perform");destination=at;body.rotation.y+=delta*(1.2+sin(time*3.0)*.3)
		else:_state(row,"mischief");speed=1.05
	elif row.role in ["toymaker","balloon_vendor"]:
		_state(row,"craft_display" if fposmod(time,18.0)>9 else "market_walk")
		if row.state=="craft_display":destination=at;body.rotation.y=sin(time*.45)*.4
	else:_state(row,"courtyard_walk")
	_walk(row,destination,speed,delta)
	row.route_progress=float(Routes.closest(Vector2(body.position.x,body.position.z),int(row.route)).progress)
	# Idle breathing and marching use whole molded toy bodies, keeping meshes
	# and collider ownership synchronized; they never modify a falling actor.
	body.position.y=float(row.origin.y)+(.018*sin(time*1.7) if destination.distance_to(at)<.03 else .024*absf(sin(time*6.0)))

func _separate_living()->void:
	var active:Array[Dictionary]=[];var grid:Dictionary={};var pairs:Array[Vector2i]=[]
	for row in living:
		if row.released or not is_instance_valid(row.body) or not row.body.freeze:continue
		var at:=Vector2(row.body.position.x,row.body.position.z)
		var cell:=Vector2i(floori(at.x/1.8),floori(at.y/1.8));var index:=active.size()
		for x in range(cell.x-1,cell.x+2):
			for z in range(cell.y-1,cell.y+2):
				for other in grid.get(Vector2i(x,z),[]):pairs.append(Vector2i(int(other),index))
		active.append(row)
		if not grid.has(cell):grid[cell]=[]
		grid[cell].append(index)
	for _pass in 5:
		var deepest:=0.0
		for pair in pairs:
			var a:Dictionary=active[pair.x];var b:Dictionary=active[pair.y]
			var pa:=Vector2(a.body.position.x,a.body.position.z);var pb:=Vector2(b.body.position.x,b.body.position.z)
			var distance:float=pa.distance_to(pb);var required:float=a.body.footprint+b.body.footprint+.04
			if distance>=required:continue
			var direction:Vector2=(pa-pb)/distance if distance>.00001 else Vector2.from_angle(float(pair.x*17+pair.y*31)*.61)
			var correction:Vector2=direction*(required-distance)*.5
			var next_a:Vector2=Routes.constrain(pa+correction,int(a.route),Routes.HALF_WIDTH-minf(.7,a.body.footprint))
			var next_b:Vector2=Routes.constrain(pb-correction,int(b.route),Routes.HALF_WIDTH-minf(.7,b.body.footprint))
			a.body.position.x=next_a.x;a.body.position.z=next_a.y;b.body.position.x=next_b.x;b.body.position.z=next_b.y
			deepest=maxf(deepest,required-distance)
		if deepest<.0001:break
	separation_passes+=1

func _update_other(row:Dictionary,delta:float)->void:
	var body:Node3D=row.body;var time:float=game.elapsed+row.phase
	if row.group=="installations":
		_state(row,"installation_"+str(row.motion))
		if not is_instance_valid(row.parts[1]):return
		var top:Node3D=row.parts[1]
		if not top.freeze or is_instance_valid(top.claimed_by):return
		if row.motion=="spin":top.rotation.y+=delta*.75
		elif row.motion=="sway":top.rotation.y=sin(time*.8)*.20
		elif row.motion=="slide":top.position.x=float(row.part_origins[1].x)+sin(time*.9)*.07
		elif row.motion=="bob":top.position.y=float(row.part_origins[1].y)+absf(sin(time*1.3))*.04
		return
	if row.group=="beacons":
		_state(row,"beacon_alarm" if group_alarm_until[int(row.formation)]>game.elapsed else "beacon_idle")
		body.rotation.y+=delta*(1.2 if row.state=="beacon_alarm" else .22)
		return
	if row.group=="parade":
		var blocked:bool=Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length()<game.player.radius+2
		if not blocked:
			for other in parade:
				if other==row or other.released or not is_instance_valid(other.body):continue
				if body.position.distance_to(other.body.position)<body.footprint+other.body.footprint+.35:blocked=true;break
		_state(row,"parade_yield" if blocked else "parade")
		if blocked:return
		row.route_progress=fposmod(float(row.route_progress)+float(row.speed)*delta,Routes.length(int(row.route)))
		var pose:Dictionary=Routes.sample(float(row.route_progress),int(row.route))
		var side:=Vector2(-pose.forward.y,pose.forward.x)
		_walk(row,pose.at+side*1.1,float(row.speed),delta)
		return
	var pose:Dictionary=Routes.sample(float(row.route_progress)+.8,int(row.route))
	if row.role=="parcel_drone":
		_state(row,"parcel_flight");_walk(row,pose.at,1.2,delta)
	elif row.role=="bubble_scout":
		_state(row,"scout_patrol");_walk(row,pose.at,.8,delta)
	elif row.role=="court_clockwork":
		_state(row,"clockwork_walk");_walk(row,pose.at,.5,delta)
	else:_state(row,"lantern_hover");body.rotation.y+=delta*.4
	row.route_progress=float(Routes.closest(Vector2(body.position.x,body.position.z),int(row.route)).progress)
	body.position.y=float(row.origin.y)+sin(time*1.6)*.10

func update(delta:float)->void:
	if not is_instance_valid(game) or game.phase!="playing" or get_tree().paused or not is_instance_valid(game.player):return
	for group in 4:
		var cycle:=int(floor(game.elapsed/18.0))
		if guard_cycles[group]!=cycle:
			guard_cycles[group]=cycle
			_event("guard_change",{"id":"palace_%d"%group,"role":"guard_formation","state":"changing"},{"cycle":cycle})
	for row in actors:
		if _released(row):continue
		if _over_opening(row.body):_released(row);continue
		if row.group=="living":_update_living(row,delta)
		else:_update_other(row,delta)
	_separate_living()
	for row in living:
		if row.released or not is_instance_valid(row.body) or not row.body.freeze:continue
		var at:=Vector2(row.body.position.x,row.body.position.z)
		_face(row.body,(at-Vector2(row.previous_at))/maxf(delta,.0001),delta)

func _process(delta:float)->void:update(delta)

func snapshot_states()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for row in actors:
		var valid:=is_instance_valid(row.body)
		result.append({"id":row.id,"role":row.role,"group":row.group,"state":row.state,"route":row.route,"formation":row.formation,"released":row.released,"at":row.body.position if valid else Vector3.ZERO,"frozen":row.body.freeze if valid else false,"claimed":is_instance_valid(row.body.claimed_by) if valid else false,"alarm_until":row.alert_until})
	return result

func population_summary()->Dictionary:
	var roles:Dictionary={}
	for row in living:roles[row.role]=int(roles.get(row.role,0))+1
	var alive:=0
	for row in actors:
		if is_instance_valid(row.body) and not row.body.consumed:alive+=1
	return {"assemblies":actors.size(),"world_actors":actors.size()-parade.size(),"living":living.size(),"ambient":ambient.size(),"beacons":beacons.size(),"gate_beacons":gate_beacon_receipts.duplicate(true),"installations":installations.size(),"parade":parade.size(),"living_roles":roles,"distinct_recipes":RECIPES.size(),"active_assemblies":alive,"released":released_count,"separation_passes":separation_passes,"activity_receipts":activity_receipts.size(),"source_city_benchmark":{"world_actors":217,"living":64,"ambient":48,"beacons":5,"installations":100,"traffic":8},"routes":Routes.metadata()}
