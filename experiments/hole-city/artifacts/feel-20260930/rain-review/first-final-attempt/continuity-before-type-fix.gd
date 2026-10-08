extends SceneTree
## Sustained visible rain, real supported rest and invisible-only retirement.
var checks:=0
var failures:Array[String]=[]
var sessions:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
var observed_city:Node3D
var admission_before:Dictionary={}
var admission_valid:=true
var admission_count:=0
func valid_admission(airborne:int,retained:int,spawned:int,reported_airborne:int)->bool:
	return reported_airborne==airborne and spawned>=0 and spawned<=mini(6,mini(maxi(0,24-airborne),maxi(0,640-retained)))
func admission_started(snapshot:Dictionary)->void:
	var ids:Dictionary={};var actual_airborne:=0
	for body in observed_city.rain_bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion():continue
		ids[body.get_instance_id()]=true
		if not body.rain_landed:actual_airborne+=1
	admission_before={"ids":ids,"airborne":actual_airborne,"retained":ids.size(),"serial":observed_city.rain_serial,"event":snapshot.event,"requested":snapshot.requested}
	admission_valid=admission_valid and int(snapshot.airborne_before)==actual_airborne and int(snapshot.retained_before)==ids.size() and int(snapshot.serial_before)==observed_city.rain_serial
func admission_finished(snapshot:Dictionary)->void:
	if admission_before.is_empty():admission_valid=false;return
	var ids:Dictionary={};var new_count:=0
	for body in observed_city.rain_bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion():continue
		var id:=body.get_instance_id();ids[id]=true
		if not admission_before.ids.has(id):new_count+=1
	admission_valid=admission_valid and admission_before.ids.keys().all(func(id):return ids.has(id))
	admission_valid=admission_valid and valid_admission(admission_before.airborne,admission_before.retained,new_count,int(snapshot.airborne_before))
	admission_valid=admission_valid and new_count==int(snapshot.spawned) and observed_city.rain_serial-admission_before.serial==new_count and int(snapshot.serial_after)==observed_city.rain_serial
	admission_valid=admission_valid and snapshot.event==admission_before.event and new_count<=int(admission_before.requested)
	admission_count+=1;admission_before.clear()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	for traveling in [false,true]:
		game.selected_map="food";game.start_level();game.begin_play()
		game.set_physics_process(false);game.city.set_process(false)
		for h in game.holes:h.enabled=false;h.active=h==game.player
		var city:Node3D=game.city;var samples:Array[Dictionary]=[]
		observed_city=city;admission_valid=true;admission_count=0;admission_before.clear()
		city.rain_admission_started.connect(admission_started)
		city.rain_admission_finished.connect(admission_finished)
		var prior:=0;var max_airborne:=0;var nearest_spawn:=0.0
		for tick in (14400 if not traveling else 7200):
			if traveling:
				var angle:=tick*.0009
				game.player.position=Vector3(cos(angle)*42,0,sin(angle)*42)
				game.update_camera(1.0,true)
			var old_serial:int=city.rain_serial
			await physics_frame
			if city.rain_serial>old_serial:
				for body in city.rain_bodies:
					if is_instance_valid(body) and body.rain_age<.05:
						nearest_spawn=maxf(nearest_spawn,Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length())
			var airborne:int=city.rain_bodies.filter(func(b):return is_instance_valid(b) and not b.rain_landed).size()
			max_airborne=maxi(max_airborne,airborne)
			if (tick+1)%1800==0:
				var landed:int=city.rain_bodies.filter(func(b):return is_instance_valid(b) and b.rain_landed).size()
				samples.append({"seconds":float(tick+1)/60,"spawned":city.rain_serial,"landed":landed,"alive":city.rain_bodies.size()})
				check(city.rain_serial>prior+20,"New visible rain continues in each 30-second window: %s at %d"%[traveling,tick+1])
				check(city.rain_bodies.size()<=city.RAIN_LIMIT,"Retained food remains bounded")
				prior=city.rain_serial
		var batched:int=city.rain_bodies.filter(func(b):return is_instance_valid(b) and b.batch!=null).size()
		check(batched>20,"Settled rain shares batched draws instead of one draw per retained food")
		# Previously landed food can legitimately wake or lose support between
		# waves. Preserve that global maximum as evidence; the spawn contract is
		# a per-wave admission cap measured synchronously from actual body IDs.
		check(admission_valid and admission_before.is_empty() and admission_count>0,"Every new wave obeys actual 24-body admission capacity without deleting previous bodies")
		check(nearest_spawn<=16.1,"Continued waves spawn near the player, not in hidden test-only districts")
		check(city.rain_retirements.all(func(r):return not r.visible and r.landed and r.distance>=city.RAIN_RETIRE_DISTANCE and r.age>=12),"Retirement only affects distant hidden settled food")
		if traveling:check(not city.rain_retirements.is_empty(),"Traveling replenishes its bounded pool by retiring distant landed food")
		sessions.append({"traveling":traveling,"samples":samples,"admission_checks":admission_count,"max_airborne":max_airborne,"retirements":city.rain_retirements.size(),"farthest_new_spawn":nearest_spawn,"batched":batched,"batch_draws":city.rain_batches.size()})
	check(valid_admission(20,639,1,20),"Independent admission oracle permits the final retained slot")
	check(not valid_admission(24,30,1,24),"A full airborne admission pool rejects even one extra spawn")
	check(not valid_admission(23,30,2,23),"One spawn beyond the remaining airborne capacity is rejected")
	check(not valid_admission(24,30,1,23),"Misreporting an airborne body as landed cannot admit an extra spawn")
	check(not valid_admission(20,639,2,20),"Retained-food capacity independently rejects one extra spawn")
	print("FOOD_RAIN_CONTINUITY_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"sessions":sessions}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
