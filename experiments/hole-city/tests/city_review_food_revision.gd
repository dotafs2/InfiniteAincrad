extends SceneTree
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func review_source_hash(path:String)->Variant:
	# Exported packages can contain compiled scripts without original source text.
	if not FileAccess.file_exists(path):return null
	var digest:=FileAccess.get_sha256(path)
	return null if digest.is_empty() else digest
func write_optional_report(result:Dictionary)->bool:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():return true
	if not output.is_absolute_path() or "://" in output:
		push_error("Review report requires an absolute filesystem path: "+output)
		return false
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		push_error("Could not write review report: %s (error %d)"%[output,FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(result,"\t")+"\n");file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:
		push_error("Could not finish review report: %s (error %d)"%[output,error])
		return false
	return true
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.active=false
	var city:Node3D=game.city
	game.player.position=Vector3(75,0,75)
	var initial:Array=[]
	for t in city.moving_vehicles:initial.append({"progress":t.progress,"pose":t.body.transform})
	var runs:Array=[]
	for hz in [30,60,120]:
		city.intersection_owners.clear()
		for i in initial.size():city.moving_vehicles[i].progress=initial[i].progress;city.moving_vehicles[i].body.transform=initial[i].pose
		var jumps:=0;var overlaps:=0;var offroad:=0;var visits:={};var distances:Array[float]=[]
		for i in initial.size():distances.append(0.0)
		for tick in hz*180:
			var before:Array[Vector3]=[]
			for t in city.moving_vehicles:before.append(t.body.position)
			city.update_traffic(1.0/hz)
			for i in city.moving_vehicles.size():
				var t:Dictionary=city.moving_vehicles[i]
				var step:float=t.body.position.distance_to(before[i]);distances[i]+=step
				if step>t.speed/hz+.0005:jumps+=1
				for j in range(i+1,city.moving_vehicles.size()):
					if city.vehicles_overlap(t.body,city.moving_vehicles[j].body):overlaps+=1
				if tick%(hz/10)!=0:continue
				var at:=Vector2(t.body.position.x,t.body.position.z)
				for road in city.urban_plan.roads:
					if road["class"]=="high_street" and city.Neighborhoods.closest(at,road).distance_to(at)<1.7:visits[road.name]=true
				var forward:=Vector2(t.body.basis.z.x,t.body.basis.z.z)
				var side:=Vector2(forward.y,-forward.x)
				for sx in [-1,1]:
					for sz in [-1,1]:
						if not city.Neighborhoods.on_road(at+side*t.body.half_size.x*sx+forward*t.body.half_size.z*sz):offroad+=1
		check(jumps==0 and overlaps==0 and offroad==0,"%d Hz branch traffic: no teleport, overlap or off-road footprint"%hz)
		check(visits.size()==5 and distances.all(func(d):return d>200),"%d Hz branch traffic: every branch is used and every car keeps moving"%hz)
		runs.append({"hz":hz,"jumps":jumps,"overlaps":overlaps,"offroad_corners":offroad,"branches":visits.keys(),"distance_m":distances})
	metrics["traffic"]=runs
	# Swallowed/deleted junction owner cannot strand surviving traffic.
	var owner:RigidBody3D=city.moving_vehicles[0].body
	var junction:Vector2=city.delivery_junctions[0]
	owner.position.x=junction.x;owner.position.z=junction.y
	city.intersection_owners[junction]=owner
	owner.free()
	for i in 120:city.update_traffic(1.0/60.0)
	check(city.intersection_owners.values().all(func(v):return is_instance_valid(v)),"Freed delivery owner is removed from junction reservations")
	# A tilted structural tier uses real non-rain contact feedback in world space.
	game.player.position=Vector3(70,0,35);city.food_impact_events.clear()
	var body:Node3D=city.food("cake",Vector2(70,43),.7,4,true)
	body.set_meta("tower_id",0)
	body.position.y=5;body.rotation=Vector3(.27,.45,.22);body.collapse_started=true
	body.max_contacts_reported=4;body.freeze=false;body.collision_layer=2;body.collision_mask=3;body.set_physics_process(true)
	for i in 240:await physics_frame
	check(not city.food_impact_events.is_empty(),"Tilted structural food emits feedback on real ground contact")
	check(city.food_impact_events.all(func(e):return absf(e.at.x-70)<2 and absf(e.at.z-43)<2 and e.at.y<.5 and e.at.y>=.015 and e.style=="thud"),"Tilted structural contacts place thud feedback above the ground surface")
	var before:int=city.impact_queue.size()
	city.queue_food_impact(body,Vector3(70,-1,43),6);city.queue_food_impact(body,Vector3(70,0,43),.2);city.queue_food_impact(body,Vector3(-70,0,-70),6)
	check(city.impact_queue.size()==before,"Below-world, slow and distant feedback is rejected")
	for i in 120:await physics_frame
	check(city.impacts.is_empty(),"Structural contact effects expire after settling")
	metrics["structural_contacts"]=city.food_impact_events
	var hashes:={}
	for path in ["fidelity/food_city.gd","fidelity/food_body.gd","fidelity/food_neighborhoods.gd","fidelity/food_shapes.gd"]:hashes[path]=review_source_hash("res://"+path)
	var result:={"checks":checks,"failures":failures,"source_hashes":hashes,"metrics":metrics}
	game.free();await process_frame
	result["source_hash_note"]="Null means source text is unavailable in this runtime; package identity is recorded by the release gate."
	var report_ok:=write_optional_report(result)
	print("CITY_REVIEW_FOOD_REVISION "+JSON.stringify(result))
	quit(0 if failures.is_empty() and report_ok else 1)
