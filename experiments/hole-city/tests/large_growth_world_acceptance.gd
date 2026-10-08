extends SceneTree
## Independent integration checks: real score awards, portrait camera and cut ground.
var checks:=0
var failures:Array[String]=[]
var measurements:Array[Dictionary]=[]
var game:Node3D

func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(count:int)->void:
	for i in count:await physics_frame
func ground_at(at:Vector2)->bool:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,.06,at.y),Vector3(at.x,-.08,at.y),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.rid==game.ground.body.get_rid()

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level()
		game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for h in game.holes:
			h.enabled=false
			if h!=game.player:h.retire()
		var previous_radius:=0.0
		var previous_level:=0
		for total_score in [1250,1600,5000,50000,1000000000]:
			game.player.award(total_score-game.player.score)
			var radius:float=game.player.radius
			check(is_finite(radius) and radius>=previous_radius,map_id+": physical size remains finite and monotonic at score %d"%total_score)
			check(game.player.level>previous_level,map_id+": real awards advance beyond the previous level at score %d"%total_score)
			if total_score>1250:check(radius>14.0 and game.player.level>12,map_id+": growth continues beyond level twelve")
			previous_radius=radius;previous_level=game.player.level
			for at in [Vector3.ZERO,Vector3(96,0,0),Vector3(96,0,96)]:
				game.player.position=at;game.player._sync_shape()
				game.update_camera(1.0,true)
				game.ground.sync()
				await frames(2)
				var tag:="%s score %d at %s"%[map_id,total_score,at]
				check(not ground_at(Vector2(at.x,at.z)),tag+": mouth center is physically open")
				check(not ground_at(Vector2(at.x-radius*.5,at.z)),tag+": enlarged inner mouth is physically open")
				var outside:=Vector2(at.x-radius-1.0,at.z)
				check(outside.x>=-100.0 and ground_at(outside),tag+": ground beyond the rim remains solid")
				check(game.ground.collider.get_faces().size()>0 and game.ground.collider.get_faces().size()<12000,tag+": large mouth produces bounded nonempty collision geometry")
				var visible:=true
				for i in 16:
					var theta:=TAU*float(i)/16.0
					var rim:Vector3=at+Vector3(cos(theta),0,sin(theta))*radius
					if not game.camera.is_position_in_frustum(rim):visible=false
				check(visible,tag+": enlarged mouth fits the portrait camera frustum")
				check(game.camera.position.distance_to(at)+radius<game.camera.far,tag+": far clip contains the enlarged mouth")
			for screen_size in [Vector2i(390,844),Vector2i(844,390)]:
				root.size=screen_size;await frames(2)
				game.update_camera(1.0,true)
				var fits:=true
				for i in 24:
					var theta:=TAU*float(i)/24.0
					if not game.camera.is_position_in_frustum(game.player.position+Vector3(cos(theta),0,sin(theta))*radius):fits=false
				check(fits,map_id+": large mouth fits phone viewport %s at score %d"%[screen_size,total_score])
			root.size=Vector2i(540,960);await frames(2)
			measurements.append({"map":map_id,"score":total_score,"level":game.player.level,"radius":radius,"camera_far":game.camera.far})
		game.player.position=Vector3.ZERO;game.ground.sync();await frames(2)
		check(ground_at(Vector2(96,96)),map_id+": moving the giant mouth restores its old corner")
		# Stress the union independently of ordinary round score availability.
		# Eight near-limit mouths cover the old center; the expanded outer edge stays solid.
		var index:=0
		for h in game.holes:
			h.active=true;h.enabled=false;h.radius=47.99
			h.position=Vector3(-40 if index<4 else 40,0,-60+40*(index%4));index+=1
		game.ground.sync();await frames(2)
		for x in [-79.0,0.0,79.0]:
			for z in [-79.0,0.0,79.0]:check(not ground_at(Vector2(x,z)),map_id+": overlapping large mouths clear covered ground at %s"%Vector2(x,z))
		for at in [Vector2(-99,-99),Vector2(99,99),Vector2(-99,99),Vector2(99,-99)]:
			check(ground_at(at),map_id+": uncovered new outer corner retains ground")
		for h in game.holes:h.active=h==game.player
		game.player.radius=.85;game.player.position=Vector3.ZERO;game.ground.sync();await frames(2)
		check(ground_at(Vector2(96,96)) and not ground_at(Vector2.ZERO),map_id+": ground recovers after the large union closes")
	game.free();await process_frame
	var report:={"checks":checks,"failures":failures,"measurements":measurements}
	print("LARGE_GROWTH_WORLD_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
