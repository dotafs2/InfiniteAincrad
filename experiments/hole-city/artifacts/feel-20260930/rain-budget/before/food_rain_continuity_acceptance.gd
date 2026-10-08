extends SceneTree
## Sustained visible rain, real supported rest and invisible-only retirement.
var checks:=0
var failures:Array[String]=[]
var sessions:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	for traveling in [false,true]:
		game.selected_map="food";game.start_level();game.begin_play()
		game.set_physics_process(false);game.city.set_process(false)
		for h in game.holes:h.enabled=false;h.active=h==game.player
		var city:Node3D=game.city;var samples:Array[Dictionary]=[]
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
			if tick%60==0:
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
		check(max_airborne<=city.AIRBORNE_LIMIT,"Only actually airborne food uses the 24-body budget")
		check(nearest_spawn<=16.1,"Continued waves spawn near the player, not in hidden test-only districts")
		check(city.rain_retirements.all(func(r):return not r.visible and r.landed and r.distance>=city.RAIN_RETIRE_DISTANCE and r.age>=12),"Retirement only affects distant hidden settled food")
		if traveling:check(not city.rain_retirements.is_empty(),"Traveling replenishes its bounded pool by retiring distant landed food")
		sessions.append({"traveling":traveling,"samples":samples,"max_airborne":max_airborne,"retirements":city.rain_retirements.size(),"farthest_new_spawn":nearest_spawn,"batched":batched,"batch_draws":city.rain_batches.size()})
	print("FOOD_RAIN_CONTINUITY_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"sessions":sessions}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
