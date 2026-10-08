extends SceneTree
## Independent actual-physics rain review; does not alter authored food tests.
var checks:=0
var failures:Array[String]=[]
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
	game.set_physics_process(false);game.city.set_process(false)
	for h in game.holes:h.enabled=false;h.active=false
	var city:Node3D=game.city
	var samples:Array[int]=[]
	for tick in 3900:
		await physics_frame
		if (tick+1)%1200==0:samples.append(city.rain_serial)
	check(samples.size()==3 and samples[0]>24 and samples[1]>samples[0]+30 and samples[2]>samples[1]+30,"Fresh waves continue at 20, 40 and 60 seconds after original 24-food ceiling")
	city.rain_enabled=false
	var landed:Array=city.rain_bodies.filter(func(b):return is_instance_valid(b) and b.rain_landed and b.batch!=null and b.position.y<1.5)
	check(landed.size()>20,"Actual landed rain enters shared batches")
	if landed.size()<2:game.free();quit(1);return
	var food:RigidBody3D=landed[0]
	var mm:MultiMesh=food.batch;var old_count:int=mm.visible_instance_count
	game.player.active=true;game.player.radius=2.5;game.player._sync_shape()
	game.player.position=Vector3(food.position.x,0,food.position.z)
	var score:int=game.player.score
	check(food.begin_swallow(game.player),"Landed batched food remains eligible for swallowing")
	check(food.batch==null and food.food_visual.visible and mm.visible_instance_count==old_count-1,"Swallowing wakes one current-pose visual and compacts its exact batch slot")
	for tick in 240:
		await physics_frame
		if not is_instance_valid(food):break
	check(not is_instance_valid(food) and game.player.score>score,"Woken landed food completes real gravity fall and awards points")
	var visible:RigidBody3D=landed.filter(func(b):return is_instance_valid(b) and b.rain_landed and not is_instance_valid(b.claimed_by))[0]
	game.player.active=false;game.player.position=Vector3(70,0,70)
	visible.rain_age=100
	game.camera.position=visible.position+Vector3(0,20,20);game.camera.look_at(visible.position,Vector3.UP)
	check(city.rain_visible(visible.position),"Retirement fixture really is inside the camera frustum")
	city.retire_distant_rain()
	check(not visible.is_queued_for_deletion(),"Distant on-screen landed food does not expire")
	game.camera.position=Vector3(70,30,70);game.camera.look_at(Vector3(70,0,60),Vector3.UP)
	check(not city.rain_visible(visible.position),"Retirement fixture is now outside the camera frustum")
	city.retire_distant_rain()
	check(visible.is_queued_for_deletion(),"Only distant hidden settled food can retire")
	var result:={"checks":checks,"failures":failures,"wave_samples":samples,"food_city_sha256":review_source_hash("res://fidelity/food_city.gd"),"food_body_sha256":review_source_hash("res://fidelity/food_body.gd")}
	game.free();await process_frame
	result["source_hash_note"]="Null means source text is unavailable in this runtime; package identity is recorded by the release gate."
	var report_ok:=write_optional_report(result)
	print("CITY_REVIEW_FOOD_RAIN "+JSON.stringify(result))
	quit(0 if failures.is_empty() and report_ok else 1)
