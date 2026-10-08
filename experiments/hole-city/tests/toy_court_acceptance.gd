extends SceneTree
## Independent built-scene benchmark and real court controller/physics review.
## Simulated controller clocks are fixtures, not ordinary gameplay or phone FPS.
const Game=preload("res://fidelity/game.gd")
const Routes=preload("res://fidelity/toy_actor_routes.gd")
const Guards=preload("res://fidelity/toy_guard_shapes.gd")
const Growth=preload("res://fidelity/hole.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var baseline:Dictionary={}
var initial:Array[Dictionary]=[]
var receipts:Array[Dictionary]=[]
var active_id:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func descendants(owner:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in owner.get_children():result.append(child);result.append_array(descendants(child))
	return result
func counts(owner:Node)->Dictionary:
	var result:={"nodes":0,"bodies":0,"meshes":0,"colliders":0}
	for node in descendants(owner):
		result.nodes+=1
		if node is RigidBody3D:result.bodies+=1
		if node is MeshInstance3D or node is MultiMeshInstance3D:result.meshes+=1
		if node is CollisionShape3D:result.colliders+=1
	return result
func quiet()->void:
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	if is_instance_valid(game.city.get("court")):game.city.court.set_process(false)
	for hole in game.holes:
		hole.enabled=false;hole.active=false;hole.set_process(false);hole.set_physics_process(false)
	game.player.position=Vector3(93,0,93)
func family(row:Dictionary)->String:return Guards.behavior_group_for(str(row.role))
func one(family_id:String)->Dictionary:
	for row in game.city.court.living:
		if family(row)==family_id:return row
	return {}
func restore_court()->void:
	var court:Node3D=game.city.court
	for index in initial.size():
		var row:Dictionary=court.actors[index]
		row.clear();row.merge(initial[index].duplicate(true))
		for part_index in row.parts.size():
			var body:Node3D=row.parts[part_index]
			body.position=row.part_origins[part_index];body.rotation=Vector3.ZERO
			body.freeze=true;body.claimed_by=null;body.fall_credit=null
			body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
	var alarm_until:Array[float]=[0.0,0.0,0.0,0.0]
	var alarm_at:Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
	var guard_cycles:Array[int]=[-1,-1,-1,-1]
	court.group_alarm_until=alarm_until;court.group_alarm_at=alarm_at
	court.guard_cycles=guard_cycles;court.activity_receipts.clear();court.released_count=0
	game.elapsed=0;game.player.position=Vector3(93,0,93);game.player.active=false

func built_city_benchmark()->void:
	game=Game.new();game.selected_map="city";root.add_child(game)
	game.start_level();game.begin_play();quiet()
	var city:Node3D=game.city
	var kinds:Dictionary={};var query_members:=0
	for row in city.citizens:
		if is_instance_valid(row.body):
			kinds[row.kind]=true
			if city.query_foods(row.body.position,3).has(row.body):query_members+=1
	baseline={"assemblies":city.world_actor_count(),"living":city.citizens.size(),"living_appearance_role_kinds":kinds.keys(),"ambient":city.ambient_actors.size(),"beacons":city.signal_nodes.size(),"installations":city.recipe_actors.size(),"distinct_authored_recipes":city.authored_actor_type_count(),"traffic":city.moving_vehicles.size(),"edibles":city.foods.size(),"living_query_members":query_members,"scene":counts(city)}
	check(baseline.assemblies==baseline.living+baseline.ambient+baseline.beacons+baseline.installations,"Actual Sunny City actor assembly count matches its built runtime groups")
	check(baseline.living==64 and kinds.size()==16 and baseline.installations==100 and baseline.traffic==8,"The unchanged Sunny City scene supplies the real living/variant/recipe/traffic benchmark")
	check(query_members==baseline.living,"Every actual Sunny City resident remains present in the active spatial query")
	metrics.sunny_city=baseline
	game.free();await process_frame

func inspect_inventory()->void:
	var court:Node3D=game.city.court;var summary:Dictionary=court.population_summary()
	var assemblies:Array=court.actors
	check(summary.assemblies==assemblies.size() and summary.assemblies==court.living.size()+court.ambient.size()+court.beacons.size()+court.installations.size()+court.parade.size(),"Court complexity counts actual assemblies without double-counting installation parts")
	check(summary.world_actors==summary.assemblies-court.parade.size() and game.city.world_actor_count()==summary.world_actors,"Toy and Sunny City world actor counts both exclude their separately measured moving traffic")
	check(summary.world_actors>=baseline.assemblies and court.living.size()>=baseline.living,"The built court has no fewer comparable actual world actors or simultaneous living residents than Sunny City")
	check(court.ambient.size()>=baseline.ambient and court.beacons.size()>=baseline.beacons and court.installations.size()>=baseline.installations and court.parade.size()>=baseline.traffic,"Ambient actors, beacons, independent installations and parade routes meet their actual original-city population benchmarks")
	var roles:Dictionary={};var geometry:Dictionary={};var ids:Dictionary={};var body_ids:Dictionary={}
	var query_members:=0;var physics_owners:=0
	for row in assemblies:
		check(not ids.has(row.id) and is_instance_valid(row.body) and row.body.get_meta("court_actor",false) and row.body.get_meta("court_id","")==row.id,"Court assembly "+str(row.id)+" has one unique truthful runtime identity")
		ids[row.id]=true
		for part in row.parts:
			check(is_instance_valid(part) and game.city.foods.has(part) and not body_ids.has(part.get_instance_id()) and part.points>0,"Court assembly "+str(row.id)+" owns a separate real edible part")
			body_ids[part.get_instance_id()]=true;physics_owners+=1
		if game.city.query_foods(row.body.position,3).has(row.body):query_members+=1
		if row.group=="living":
			roles[row.role]=true
			var view:MeshInstance3D=row.visual
			var signature:Array=[]
			for surface in view.mesh.get_surface_count():
				var arrays:Array=view.mesh.surface_get_arrays(surface)
				signature.append([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX]])
			geometry[str(hash(signature))]=true
	check(roles.size()>=baseline.living_appearance_role_kinds.size() and geometry.size()>=16,"At least sixteen actual living court costumes have distinct modeled props/silhouettes instead of palette clones")
	check(query_members==assemblies.size(),"Every moving assembly body is registered in actual current-position food queries")
	check(physics_owners==court.living.size()+court.ambient.size()+court.beacons.size()+court.installations.size()*2+court.parade.size(),"One hundred two-part assemblies retain two independent physics owners each")
	check(court.RECIPES.size()>=10 and summary.distinct_recipes==court.RECIPES.size(),"Distinct court recipe count reports actual designs separately from repeated placements")
	check(game.city.catalog.is_empty() and game.train_controller==null and game.city.citizens.is_empty(),"Original court activity does not silently instantiate Sunny City's models, citizens or tram")
	metrics.court={"summary":summary,"living_costumes":roles.keys(),"distinct_living_geometry":geometry.size(),"query_members":query_members,"physics_owners":physics_owners,"scene":counts(game.city),"comparison_scope":"Built population and behavior review; sixteen City appearances and one hundred original City recipes remain separately reported"}
	for row in assemblies:initial.append(row.duplicate(true))

func natural_activity()->void:
	restore_court()
	var court:Node3D=game.city.court
	var traveled:Dictionary={};var states:Dictionary={};var events:Dictionary={}
	var part_changes:Dictionary={};var before_parts:Dictionary={}
	var delivery_events:Dictionary={};var invalid_deliveries:=0
	for row in court.installations:before_parts[row.id]=row.parts[1].transform
	for tick in 60*22:
		var before:Dictionary={}
		for row in court.living:before[row.id]=row.body.position
		game.elapsed=float(tick)/60.0;court.update(1.0/60.0)
		for row in court.living:
			var old_at:Vector3=before[row.id]
			traveled[row.id]=float(traveled.get(row.id,0))+Vector2(row.body.position.x,row.body.position.z).distance_to(Vector2(old_at.x,old_at.z))
			states[row.state]=int(states.get(row.state,0))+1
		for row in court.installations:
			if row.parts[1].transform!=before_parts[row.id]:part_changes[row.id]=true
		for event in court.activity_receipts:
			events[str(event.event)]=true
			if event.event=="delivery":
				var key:String=str(event.id)+"/"+str(event.elapsed)
				if delivery_events.has(key):continue
				delivery_events[key]=true
				var owner:Dictionary={}
				for row in court.living:
					if row.id==event.id:owner=row;break
				var valid:bool=not owner.is_empty() and family(owner)=="courier" and event.has("station") and event.has("at")
				if valid:
					var stops:Array=Routes.PATHS[int(owner.route)]
					valid=int(event.station)>=0 and int(event.station)<stops.size()
					if valid:valid=Vector2(event.at).distance_to(stops[int(event.station)])<.55
				if not valid:invalid_deliveries+=1
	var moving:=traveled.values().filter(func(distance):return float(distance)>.25).size()
	check(moving>=32,"Ordinary controller clocks move a substantial real court population instead of counting stationary duplicates")
	check(states.has("rest") and states.has("march") and states.has("guard_change") and states.has("courier_delivery") and states.has("royal_idle"),"Real natural updates produce rest, march, guard change, delivery and royal-idle behavior")
	check(events.has("guard_change") and events.has("delivery") and court.activity_receipts.size()<=256,"Real court events occur while the activity ledger remains bounded")
	check(delivery_events.size()>0 and invalid_deliveries==0,"Every actual delivery receipt identifies a transport role physically arriving at its real route corner")
	check(part_changes.size()==court.installations.size(),"Every independently edible installation has actual moving modeled parts")
	metrics.natural={"seconds":22,"hz":60,"moving_living":moving,"motion_measure":"Accumulated horizontal distance; idle vertical breathing excluded","states":states,"events":events.keys(),"moving_installations":part_changes.size(),"actual_corner_deliveries":delivery_events.size(),"invalid_deliveries":invalid_deliveries,"scope":"Simulated controller clock, not a real-time or FPS measurement"}

func heading_and_separation()->void:
	var court:Node3D=game.city.court
	var runs:Array[Dictionary]=[]
	for hz in [30,60,120]:
		restore_court()
		var samples:=0;var wrong:=0;var largest:=0.0;var overlaps:=0;var escaped:=0;var closest:=INF
		for tick in hz*3:
			var before:Dictionary={}
			for row in court.living:before[row.id]=row.body.position
			game.elapsed=float(tick)/hz;court.update(1.0/hz)
			for index in court.living.size():
				var row:Dictionary=court.living[index]
				var velocity:Vector3=(row.body.position-before[row.id])*hz
				if Vector2(velocity.x,velocity.z).length()>.02:
					var error:float=absf(angle_difference(row.body.rotation.y,atan2(velocity.x,velocity.z)))
					samples+=1;largest=maxf(largest,rad_to_deg(error))
					if error>deg_to_rad(15.05):wrong+=1
				var at:=Vector2(row.body.position.x,row.body.position.z)
				var center:Vector2=Routes.closest(at,int(row.route)).at
				if at.distance_to(center)>Routes.HALF_WIDTH-minf(.7,row.body.footprint)+.001:escaped+=1
				for other_index in range(index+1,court.living.size()):
					var other:Dictionary=court.living[other_index]
					var distance:float=at.distance_to(Vector2(other.body.position.x,other.body.position.z))
					var required:float=row.body.footprint+other.body.footprint
					closest=minf(closest,distance-required)
					if distance<required-.015:overlaps+=1
		check(samples>hz*20,"%d Hz: actual moving court bodies provide enough independent heading samples"%hz)
		check(wrong==0,"%d Hz: final actual court travel faces within Sunny City's 15-degree bound, including separation"%hz)
		check(overlaps==0 and escaped==0,"%d Hz: actual court footprints remain separated inside their authored route corridor"%hz)
		runs.append({"hz":hz,"samples":samples,"wrong_heading":wrong,"largest_error_degrees":largest,"overlap_samples":overlaps,"escaped_samples":escaped,"minimum_clearance":closest})
	metrics.heading=runs

@warning_ignore("integer_division")
func formation_fixtures()->void:
	restore_court()
	var court:Node3D=game.city.court
	var unit:Array[Dictionary]=[];var ranks:Dictionary={}
	for row in court.living:
		if family(row)=="guard" and int(row.formation)==0:
			row.rest_cycle=1000.0;row.rest_window=0.0
			unit.append(row);ranks[int(row.formation_rank)]=true
		else:
			# Isolate the marching unit from explicitly excluded controller participants.
			row.released=true
	check(unit.size()==6 and ranks.size()==6 and ranks.has(0) and ranks.has(5),"An actual palace unit has six independently modeled guards, captain and knight with unique marching ranks")
	if unit.size()!=6 or ranks.size()!=6:return
	unit.sort_custom(func(a,b):return int(a.formation_rank)<int(b.formation_rank))
	var origins:Dictionary={}
	for row in unit:origins[row.id]=Vector2(row.body.position.x,row.body.position.z)
	var largest_spacing_error:=0.0;var largest_column_error:=0.0;var samples:=0;var march_samples:=0
	for tick in 60*4:
		game.elapsed=float(tick)/60.0;court.update(1.0/60.0)
		if tick<60:continue
		var leader:Vector2=Vector2(unit[0].body.position.x,unit[0].body.position.z)
		var forward:Vector2=Routes.closest(leader,0).forward
		var side:=Vector2(-forward.y,forward.x)
		for row in unit:
			var rank:int=row.formation_rank
			var offset:Vector2=Vector2(row.body.position.x,row.body.position.z)-leader
			var expected_back:float=float(rank/2)*1.05
			var expected_side:float=-1.1 if rank%2==1 else 0.0
			largest_spacing_error=maxf(largest_spacing_error,absf(offset.dot(forward)+expected_back))
			largest_column_error=maxf(largest_column_error,absf(offset.dot(side)-expected_side))
			samples+=1
			if row.state=="march":march_samples+=1
	var moving:=0
	for row in unit:
		if Vector2(row.body.position.x,row.body.position.z).distance_to(origins[row.id])>2.5:moving+=1
	check(samples==6*60*3 and march_samples==samples and moving==6,"All six actual palace bodies march together for the sampled interval rather than displaying a formation label on static figures")
	check(largest_spacing_error<.22 and largest_column_error<.22,"Actual marching positions retain three separated ranks and two visible columns under real controller updates")
	metrics.formation={"members":unit.size(),"samples":samples,"moving":moving,"largest_rank_error":largest_spacing_error,"largest_column_error":largest_column_error,"scope":"Isolated real six-body marching controller; other residents excluded from this local formation fixture"}

func control_boundaries()->void:
	restore_court();var court:Node3D=game.city.court
	var before:Array[Transform3D]=[]
	for row in court.actors:before.append(row.body.transform)
	game.phase="result";court.update(.5)
	var same:=true
	for index in court.actors.size():same=same and court.actors[index].body.transform==before[index]
	check(same,"A finished round stops actual court motion instead of only disabling its visible state label")
	game.phase="playing";root.get_tree().paused=true;court.update(.5);root.get_tree().paused=false
	same=true
	for index in court.actors.size():same=same and court.actors[index].body.transform==before[index]
	check(same,"Application pause stops every actual court controller transform")
	var row:=one("courier");var body:Node3D=row.body;var view:MeshInstance3D=row.visual
	var pose:Transform3D=body.transform;var visual_pose:Transform3D=view.transform
	body.claimed_by=game.player;game.elapsed=2.0;court.update(.1)
	check(body.freeze and row.released and row.state=="physics_released" and body.transform==pose and view.transform==visual_pose,"An already claimed standing actor immediately yields all scripted transforms to its real owner")
	body.claimed_by=null
	for tick in 10:game.elapsed+=.1;court.update(.1)
	check(row.released and body.transform==pose and view.transform==visual_pose and court.activity_receipts.filter(func(event):return event.event=="released" and event.id==row.id).size()==1,"Clearing a previous reservation cannot restart the actor controller or duplicate its one-time handoff event")

func interaction_fixtures()->void:
	restore_court();var court:Node3D=game.city.court
	var guard:Dictionary=one("guard");var sentry:Dictionary=one("sentry");var jester:Dictionary=one("jester")
	check(not guard.is_empty() and not sentry.is_empty() and not jester.is_empty(),"Real guards, sentries and jesters supply independent interaction fixtures")
	if guard.is_empty() or sentry.is_empty() or jester.is_empty():return
	# Remove rest as a confounder in this explicitly positioned control fixture.
	guard.rest_cycle=1000.0;guard.rest_window=0.0
	var station:Vector2=Routes.guard_station(int(guard.formation))
	guard.body.position=Vector3(station.x+5,guard.origin.y,station.y)
	guard.route_progress=float(Routes.closest(Vector2(guard.body.position.x,guard.body.position.z),int(guard.route)).progress)
	var before:Vector2=Vector2(guard.body.position.x,guard.body.position.z)
	# Keep this station-return fixture outside the higher-priority pursuit window.
	game.elapsed=24.1;court.update(.1)
	var after:Vector2=Vector2(guard.body.position.x,guard.body.position.z)
	print("TOY_COURT_INTERACTION_DIAGNOSTIC "+JSON.stringify({"fixture":"station_return","elapsed":game.elapsed,"state":guard.state,"before":before,"after":after,"station":station,"distance_before":before.distance_to(station),"distance_after":after.distance_to(station)}))
	check(guard.state=="guard_change" and after.distance_to(station)<before.distance_to(station),"Guard change moves the actual guard toward its station instead of changing only a state label")
	restore_court();guard=one("guard");jester=one("jester")
	guard.rest_cycle=1000.0;guard.rest_window=0.0
	var at:=Routes.guard_station(int(guard.formation))
	guard.body.position=Vector3(at.x+4,guard.origin.y,at.y)
	jester.body.position=Vector3(at.x+7,jester.origin.y,at.y)
	game.elapsed=19.0-float(guard.phase)
	var distance:float=guard.body.position.distance_to(jester.body.position)
	court.update(.1)
	check(guard.state=="pursuit" and guard.body.position.distance_to(jester.body.position)<distance,"A nearby mischievous jester triggers real bounded guard pursuit")
	restore_court();sentry=one("sentry")
	var subject:=one("courtier")
	if subject.is_empty():subject=one("courier")
	check(not subject.is_empty(),"A real walking court resident supplies the threat fixture")
	if subject.is_empty():return
	at=Routes.guard_station(int(subject.formation))
	subject.body.position=Vector3(at.x,subject.origin.y,at.y)
	sentry.body.position=Vector3(at.x+1.7,sentry.origin.y,at.y)
	game.player.position=Vector3(at.x-3,0,at.y);game.player.radius=.85;game.player.active=false
	game.elapsed=5.0
	before=Vector2(subject.body.position.x,subject.body.position.z)
	var threat:=Vector2(game.player.position.x,game.player.position.z)
	court.update(.1)
	after=Vector2(subject.body.position.x,subject.body.position.z)
	check(subject.state=="flee" and after.distance_to(threat)>before.distance_to(threat),"A near mouth outside admission range makes an actual resident flee away")
	check(sentry.state=="alarm" and float(sentry.alert_until)>game.elapsed and not court.activity_receipts.filter(func(event):return event.event=="alarm").is_empty(),"A sentry raises a real timed group alarm near the same threat")
	check(court.beacons.any(func(row):return row.state=="beacon_alarm"),"The group alarm changes an actual beacon controller")
	metrics.interactions={"scope":"Explicit local positions and controller clocks; no reward, save or normal travel injected","guard_change":true,"pursuit":true,"flee":true,"alarm":true}

func on_collected(body:Node3D,hole:Node3D)->void:
	if body.get_instance_id()!=active_id:return
	receipts.append({"points":body.points,"top":body.global_position.y+body.vertical_extent(),"player":hole==game.player,"consumed":body.consumed})
func physical_handoff()->void:
	restore_court();var court:Node3D=game.city.court;var row:Dictionary=one("guard")
	if row.is_empty():return
	var body:Node3D=row.body;var view:MeshInstance3D=row.visual
	var mesh:Mesh=view.mesh;var pose:Transform3D=view.transform;var material:Material=view.material_override
	var point_value:int=body.points;active_id=body.get_instance_id()
	game.player.active=true;game.player.radius=Growth.RADII[0];game.player.score=0;game.player.level=1
	var at:Vector3=body.interaction_position();game.player.position=Vector3(at.x,0,at.z)
	game.player._sync_shape();game.ground.sync()
	check(body.can_fit(game.player) and game.city.scan_candidates(game.holes).has(body),"A real starter mouth can find and admit the actual moving guard")
	var before:Vector3=body.position;court.update(1.0/60.0)
	check(not body.freeze and body.claimed_by==game.player and row.released and row.state=="physics_released","Opening admission hands the original guard directly to rigid-body physics")
	check(Vector2(body.position.x,body.position.z).distance_to(Vector2(before.x,before.z))<.001 and game.player.score==0,"The admitted guard receives no extra scripted escape or premature score")
	var downward:=false;var no_script_motion:=true;var original:=true
	for tick in 240:
		if not is_instance_valid(body):break
		before=body.position;var local_before:Transform3D=view.transform
		game.elapsed+=1.0/60.0;court.update(1.0/60.0)
		no_script_motion=no_script_motion and body.position==before and view.transform==local_before
		original=original and view.mesh==mesh and view.transform==pose and view.material_override==material and body.points==point_value
		await physics_frame
		if is_instance_valid(body):downward=downward or body.linear_velocity.y<-.1
	check(no_script_motion and original,"Released court controllers preserve the actual mesh/material/pose and never reposition a falling guard")
	check(downward and not is_instance_valid(body),"The original guard obtains actual downward velocity and completes its fall")
	check(receipts.size()==1 and receipts[0].player and receipts[0].consumed and receipts[0].top<-3.5 and int(receipts[0].points)==point_value,"Only one actual whole-body collection callback grants the guard's unchanged points")
	check(court.activity_receipts.filter(func(event):return event.event=="released" and event.id==row.id).size()==1,"Repeated court ticks cannot emit duplicate release ownership events")
	metrics.handoff={"receipts":receipts,"downward_velocity_observed":downward,"no_script_motion":no_script_motion,"original_geometry":original}

func removed_upper_lifetime()->void:
	# Explicitly remove a test-owned upper part while keeping its real base.
	# This exercises stale runtime references, not a fabricated collection.
	var court:Node3D=game.city.court
	var row:Dictionary=court.installations[0]
	var base:Node3D=row.body;var upper:Node3D=row.parts[1]
	var view:MeshInstance3D=row.visual;var mesh:Mesh=view.mesh
	var pose:Transform3D=base.transform;var visual_pose:Transform3D=view.transform
	var wallet:=Vector2i(game.coins,game.gems);var score:int=game.player.score
	game.player.active=false
	check(is_instance_valid(upper) and upper.support_parent==base and base.freeze and not is_instance_valid(base.claimed_by),"The lifetime fixture begins with an actual independently owned supported upper toy and intact base")
	upper.free()
	check(not is_instance_valid(row.parts[1]),"The actual installation row retains the removed object reference that the controller must validate")
	for tick in 8:game.elapsed+=1.0/60.0;court.update(1.0/60.0)
	check(is_instance_valid(base) and base.freeze and not row.released and base.transform==pose and view.mesh==mesh and view.transform==visual_pose,"A removed upper part cannot crash or reposition the intact original installation base")
	check(Vector2i(game.coins,game.gems)==wallet and game.player.score==score,"An explicit removed-upper lifetime fixture fabricates no wallet or score reward")
	metrics.removed_upper={"recipe":row.role,"base_retained":is_instance_valid(base),"scope":"Explicit test-owned removal and actual controller updates; no physical-fall or reward claim"}

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	await built_city_benchmark()
	game=Game.new();game.selected_map="toys";root.add_child(game)
	game.start_level();game.begin_play();quiet()
	inspect_inventory();natural_activity();heading_and_separation();formation_fixtures();control_boundaries()
	print("TOY_COURT_CONTROLLER_DIAGNOSTIC "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	interaction_fixtures()
	game.item_collected.connect(on_collected);await physical_handoff()
	removed_upper_lifetime()
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual sequential City/Toy scenes, simulated real controllers and physical guard fall; no real saves, SDK traffic, GPU pixels, ordinary pacing or phone FPS claim"}
	print("TOY_COURT_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
