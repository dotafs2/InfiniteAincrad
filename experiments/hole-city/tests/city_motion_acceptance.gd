extends SceneTree
## Real city controller checks. No real save or foreground window is used.
var failures:Array[String]=[]
var checks:=0
var game:Node3D
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func heading_fixture()->void:
	var runs:Array=[]
	for hz in [30,60,120]:
		for c in game.city.citizens:c.body.position=c.origin;c.body.rotation.y=1.7
		var samples:=0;var bad:=0;var largest:=0.0
		for tick in hz*12:
			var before:Array[Vector3]=[]
			for c in game.city.citizens:before.append(c.body.position)
			game.elapsed=float(tick)/hz;game.city._process(1.0/hz)
			for i in game.city.citizens.size():
				var c:Dictionary=game.city.citizens[i]
				var velocity:Vector3=(c.body.position-before[i])*hz
				if velocity.length()<.02:continue
				var error:float=absf(angle_difference(c.body.rotation.y,atan2(velocity.x,velocity.z)))
				largest=maxf(largest,rad_to_deg(error));samples+=1
				if error>deg_to_rad(15.05):bad+=1
		check(samples>hz*100,"%d Hz: actual moving citizens provide heading samples"%hz)
		check(bad==0,"%d Hz: every moving citizen faces actual travel within 15 degrees"%hz)
		runs.append({"hz":hz,"samples":samples,"wrong_heading_samples":bad,"largest_error_degrees":largest})
	metrics["heading"]=runs
func crowd_fixture()->void:
	for c in game.city.citizens:c.body.position=c.origin
	var closest:=INF;var overlaps:=0;var escaped:=0
	for tick in 60*60:
		if tick%600==0:
			var target:Dictionary=game.city.citizens[(tick/600)*7]
			game.player.position=target.body.position+Vector3(1.8,0,0)
		game.elapsed=float(tick)/60;game.city._process(1.0/60.0)
		for i in game.city.citizens.size():
			var a:Dictionary=game.city.citizens[i]
			var at:=Vector2(a.body.position.x,a.body.position.z)
			if not game.city.pedestrian_contains(a,at):escaped+=1
			for j in range(i+1,game.city.citizens.size()):
				var b:Dictionary=game.city.citizens[j]
				var distance:float=at.distance_to(Vector2(b.body.position.x,b.body.position.z))
				closest=minf(closest,distance)
				if distance<.46:overlaps+=1
	check(overlaps==0,"60 Hz minute: wandering, pursuing and panicking citizens never overlap capsules")
	check(escaped==0,"60 Hz minute: separation preserves every sidewalk boundary")
	metrics["crowd"]={"seconds":60,"hz":60,"minimum_center_spacing_m":closest,"overlap_samples":overlaps,"off_sidewalk_samples":escaped}
	# An intentionally coincident spawn at the sidewalk edge exercises the
	# deterministic zero-distance direction and constrained neighbor correction.
	for i in 8:
		var c:Dictionary=game.city.citizens[i]
		c["sidewalk"]=0;c["walk_loop"]=0;c.body.position=Vector3(-21.4,c.body.position.y,4.25)
	game.city.separate_citizens()
	var dense_min:=INF
	for i in 8:
		for j in range(i+1,8):dense_min=minf(dense_min,game.city.citizens[i].body.position.distance_to(game.city.citizens[j].body.position))
	check(dense_min>=.46,"dense sidewalk-edge pocket resolves eight initially coincident residents")
	# A person over an opening must release before the crowd solver can move it.
	var falling:Dictionary=game.city.citizens[0]
	game.player.position=falling.body.position;game.player.position.y=0
	game.player.active=true;game.player.radius=2.0;game.player._sync_shape()
	var before:Vector3=falling.body.position
	game.city._process(1.0/60.0)
	check(not falling.body.freeze and falling.body.claimed_by==game.player,"crowd member over a hole transfers to gravity")
	check(Vector2(falling.body.position.x,falling.body.position.z).distance_to(Vector2(before.x,before.z))<.001,"released citizen receives no scripted separation displacement")
	metrics["dense_minimum_spacing_m"]=dense_min
func traffic_fixture()->void:
	for hole in game.holes:hole.active=false
	game.player.position=Vector3(70,0,70)
	var distances:Array[float]=[];var wraps:Array[int]=[]
	for i in game.city.moving_vehicles.size():
		var t:Dictionary=game.city.moving_vehicles[i]
		var spec:Dictionary=game.city.Layout.traffic_spec(i)
		t.progress=spec.progress;t.body.position.x=spec.at.x;t.body.position.z=spec.at.y;t.body.rotation.y=spec.angle
		distances.append(0.0);wraps.append(0)
	var jumps:=0;var wrong_heading:=0;var offroad:=0;var overlaps:=0;var maximum:=0.0
	for tick in 60*180:
		var before:Array[Vector3]=[];var old_progress:Array[float]=[]
		for t in game.city.moving_vehicles:before.append(t.body.position);old_progress.append(t.progress)
		game.city.update_traffic(1.0/60.0)
		for i in game.city.moving_vehicles.size():
			var t:Dictionary=game.city.moving_vehicles[i]
			var step:float=t.body.position.distance_to(before[i])
			distances[i]+=step;maximum=maxf(maximum,step)
			if step>float(t.speed)/60.0+.0002:jumps+=1
			if t.progress<old_progress[i]:wraps[i]+=1
			var pose:Dictionary=game.city.Layout.traffic_sample(t.progress,t.route)
			if t.body.basis.z.dot(Vector3(pose.forward.x,0,pose.forward.y))<.999:wrong_heading+=1
			if not game.city.Layout.on_road(Vector2(t.body.position.x,t.body.position.z)):offroad+=1
			for j in range(i+1,game.city.moving_vehicles.size()):
				if game.city.traffic_footprints_overlap(t.body,game.city.moving_vehicles[j].body,0):overlaps+=1
	check(jumps==0,"Three traffic minutes: no displacement exceeds speed * delta")
	check(wrong_heading==0 and offroad==0,"Continuous turns retain the rendered road and tangent heading")
	check(overlaps==0,"Opposing traffic loops remain free of physical footprint overlaps")
	for i in distances.size():check(distances[i]>200.0 and wraps[i]>=2,"Vehicle %d completes at least two continuous loops without deadlock"%i)
	metrics["traffic"]={"seconds":180,"hz":60,"maximum_frame_displacement_m":maximum,"jumps":jumps,"overlap_samples":overlaps,"offroad_samples":offroad,"wrong_heading_samples":wrong_heading,"distance_m":distances,"seam_crossings":wraps}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for hole in game.holes:hole.enabled=false;hole.active=false
	game.player.position=Vector3(70,0,70)
	heading_fixture()
	crowd_fixture()
	traffic_fixture()
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Headless controller evidence; no browser or device FPS claim"}
	print("CITY_MOTION_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
