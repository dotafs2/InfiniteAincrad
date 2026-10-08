extends SceneTree
## Food feedback must originate at real physical contacts and remain bounded.
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false;hole.active=false
	game.player.position=Vector3(71,0,36)
	var city:Node3D=game.city;var drops:Array[Node3D]=[]
	for i in 3:
		var body:Node3D=city.spawn_rain(["cookie","egg","cake"][i],Vector2(71,42+i*6),8)
		if i==2:body.set_meta("tower_id",0)
		drops.append(body)
	for i in 5:await physics_frame
	check(city.food_impact_events.is_empty(),"Airborne food does not emit fake impact feedback")
	var peak:=0
	for i in 300:
		await physics_frame;peak=maxi(peak,city.impacts.size())
	var styles:Dictionary={}
	for event in city.food_impact_events:
		styles[event.style]=true
		check(absf(event.at.x-71)<1.5 and event.at.y>=-.05 and event.at.y<.25,"Feedback lies at actual ground contact, not the body center")
	check(styles.size()==3,"Crisp food, soft food and structural tiers produce distinct contact feedback")
	check(city.impact_sounds.size()==3,"Three food impact sound envelopes are cached")
	var sounds:Dictionary={}
	for sound in city.impact_sounds.values():
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(sound.data);sounds[hash.finish().hex_encode()]=true
	check(sounds.size()==3,"Different food styles have different synthesized waveforms")
	for i in 30:city.spawn_rain("cookie",Vector2(65+(i%5)*2.3,29+(i/5)*2.3),3)
	for i in 240:
		await physics_frame;peak=maxi(peak,city.impacts.size())
		check(city.impacts.size()<=city.IMPACT_LIMIT and city.impact_queue.size()<=city.IMPACT_LIMIT,"Actual simultaneous contacts obey the burst budget")
	check(city.crumb_batch.visible_instance_count<=72 and city.glaze_batch.visible_instance_count<=12,"Contact feedback uses two bounded shared draw batches")
	for i in 180:await physics_frame
	check(city.impacts.is_empty() and city.crumb_batch.visible_instance_count==0 and city.glaze_batch.visible_instance_count==0,"All presentation fragments expire without leaving world obstacles")
	print("FOOD_IMPACT_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"styles":styles.keys(),"peak_bursts":peak,"events":city.food_impact_events.size(),"scope":"Physics/contact and waveform evidence, not audio audition or rendered capture"}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
