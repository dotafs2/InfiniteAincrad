extends SceneTree
## Non-author admission and real reawakening/support-loss regression.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var receipts:Dictionary={}
var events:Array[Dictionary]=[]
var captured:Dictionary={}
var observations_valid:=true
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
	for i in n:await physics_frame
func before(snapshot:Dictionary)->void:
	var ids:Dictionary={};var flying:=0
	for b in game.city.rain_bodies:
		if not is_instance_valid(b) or b.is_queued_for_deletion():continue
		ids[b.get_instance_id()]=true
		if not b.rain_landed:flying+=1
	captured={"ids":ids,"flying":flying,"serial":game.city.rain_serial,"event":snapshot.event}
	observations_valid=observations_valid and snapshot.airborne_before==flying and snapshot.retained_before==ids.size() and snapshot.serial_before==game.city.rain_serial
func after(snapshot:Dictionary)->void:
	var added:=0;var ids:Dictionary={}
	for b in game.city.rain_bodies:
		if not is_instance_valid(b) or b.is_queued_for_deletion():continue
		ids[b.get_instance_id()]=true
		if not captured.ids.has(b.get_instance_id()):added+=1
	var permitted:=mini(6,mini(maxi(0,24-int(captured.flying)),maxi(0,640-captured.ids.size())))
	observations_valid=observations_valid and added<=permitted and captured.ids.keys().all(func(id):return ids.has(id)) and snapshot.spawned==added and game.city.rain_serial-captured.serial==added and snapshot.event==captured.event
	events.append({"airborne_before":captured.flying,"retained_before":captured.ids.size(),"actual_added":added,"permitted":permitted})
func wave()->void:
	game.city.rain_enabled=true;game.city.rain_clock=0.0;game.city.update_rain(0.0);game.city.rain_enabled=false
func record(body:Node3D,owner:Node3D)->void:
	if owner==game.player:receipts[body.get_instance_id()]=int(receipts.get(body.get_instance_id(),0))+1
func free_site()->Vector2:
	var box:=BoxShape3D.new();box.size=Vector3(9,20,9)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.collision_mask=3;query.exclude=[game.ground.body.get_rid()]
	for x in [-91.0,91.0,-84.0,84.0]:
		for z in [-64.0,-40.0,-16.0,16.0,40.0,64.0]:
			query.transform=Transform3D(Basis.IDENTITY,Vector3(x,10.1,z))
			if game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return Vector2(x,z)
	return Vector2(INF,INF)
func snapshot(bodies:Array,label:String)->void:
	var rows:Array=[]
	for b in bodies:
		var bottom:=INF
		for child in b.get_children():
			if child is CollisionShape3D:
				if child.shape is ConvexPolygonShape3D:
					for point in child.shape.points:bottom=minf(bottom,(child.global_transform*point).y)
		var state:=PhysicsServer3D.body_get_direct_state(b.get_rid())
		var q:=PhysicsRayQueryParameters3D.create(b.position,b.position+Vector3.DOWN*8,3,[b.get_rid()])
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(q)
		rows.append({"name":b.name,"pos":str(b.position),"linear":str(b.linear_velocity),"angular":str(b.angular_velocity),"sleep":b.sleeping,"landed":b.rain_landed,"batch":b.batch!=null,"hull_bottom":bottom,"extent_bottom":b.position.y-b.vertical_extent(),"contacts":state.get_contact_count() if state!=null else -1,"support":str(hit.collider.name) if not hit.is_empty() else "none","support_y":hit.position.y if not hit.is_empty() else -999})
	print("SUPPORT_DIAG "+JSON.stringify({"label":label,"rows":rows}))
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
	game.city.set_process(false);game.city.set_physics_process(false);game.city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.active=false;h.set_physics_process(false)
	game.ground.sync();await frames(3)
	game.city.rain_admission_started.connect(before);game.city.rain_admission_finished.connect(after)
	game.item_collected.connect(record)
	var at:=free_site();check(at.is_finite(),"Support-loss fixture occupies a genuinely clear physical column")
	if not at.is_finite():game.free();await frames(2);quit(1);return
	game.player.position=Vector3(at.x,0,at.y)
	game.camera.position=Vector3(at.x,42,at.y+12);game.camera.look_at(Vector3(at.x,5,at.y),Vector3.UP)
	var platform:=StaticBody3D.new();platform.collision_layer=1;platform.collision_mask=3
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,.5,7);shape.shape=box;platform.add_child(shape)
	game.world.add_child(platform);platform.position=Vector3(at.x,6,at.y)
	await frames(2)
	var settled:Array[Node3D]=[];var original_meshes:Dictionary={}
	for i in 6:
		var location:=at+Vector2(-2.2+float(i%3)*2.2,-1.6+float(i/3)*3.2)
		var b:Node3D=game.city.spawn_rain("cookie",location,9.0)
		settled.append(b);original_meshes[b.get_instance_id()]=b.food_visual.mesh
		check(not b.rain_landed and not b.freeze and not b.sleeping,"New rain is truly falling, not mislabeled settled")
	await frames(420)
	game.city.batch_settled_rain()
	for b in settled:
		check(b.rain_landed and b.sleeping and b.batch!=null,"Real support contact settles and batches the visible cookie")
		check(absf(b.position.y-b.vertical_extent()-6.25)<.04,"Settled pose rests on actual elevated support")
		check(game.city.rain_visible(b.position) and not b.freeze,"Supported food is visible and asleep rather than artificially frozen")
	# Fill the production admission pool through four legitimate six-drop waves.
	for i in 4:wave()
	check(observations_valid and events.size()==4 and events.all(func(e):return e.actual_added==6),"Actual production waves admit exactly 24 new airborne foods around supported rain")
	var count_before:int=game.city.rain_serial;wave()
	check(game.city.rain_serial==count_before and events.back().actual_added==0,"A full real admission pool cannot spawn even one more body")
	# Physical relaunch of the old six proves an all-time 24 invariant is false.
	for b in settled:b.sleeping=false;b.linear_velocity=Vector3(0,4.5,0);b.angular_velocity=Vector3.ZERO
	await frames(4)
	var airborne:int=game.city.rain_bodies.filter(func(b):return is_instance_valid(b) and not b.rain_landed).size()
	check(airborne==30,"Already landed food may genuinely relaunch above the 24-new-drop admission cap")
	for b in settled:
		check(not b.rain_landed and not b.sleeping and not b.freeze and b.linear_velocity.y>0,"Relaunched cookie truthfully resumes upward physical flight")
		check(b.batch==null and b.food_visual.visible and b.food_visual.mesh==original_meshes[b.get_instance_id()],"Woken body exposes its same individual mesh at the current physical pose")
	var old_ids:Array=game.city.rain_bodies.map(func(b):return b.get_instance_id())
	count_before=game.city.rain_serial;wave()
	check(game.city.rain_serial==count_before and events.back().actual_added==0 and observations_valid,"Natural reactivation beyond 24 denies new arrivals without falsifying admission counts")
	check(game.city.rain_bodies.size()==old_ids.size() and game.city.rain_bodies.all(func(b):return old_ids.has(b.get_instance_id()) and not b.is_queued_for_deletion() and not b.freeze),"Quota denial never deletes or freezes existing visible/falling food")
	await frames(420)
	game.city.batch_settled_rain()
	for b in settled:check(b.rain_landed and b.batch!=null,"A real bounce can settle and join rendering batches again")
	# Removing real support must wake the collider and clear landed/batched state.
	var heights:Dictionary={}
	for b in settled:heights[b.get_instance_id()]=b.position.y
	snapshot(settled,"before removal");platform.free();await frames(30);snapshot(settled,"after .5s")
	for b in settled:
		check(not b.rain_landed and not b.freeze and b.position.y<heights[b.get_instance_id()]-.2,"Removing support produces real downward motion, not a sticky landed label")
		check(b.batch==null and b.food_visual.visible,"Support-loss fall renders the live body rather than its stale batch transform")
	await frames(360)
	snapshot(settled,"after 6.5s")
	var edible:Node3D
	for b in settled:
		check(is_instance_valid(b) and b.rain_landed and b.position.y-b.vertical_extent()<.08,"Previously elevated food remains present and lands on actual terrain")
		if edible==null:edible=b
	# A distant but camera-visible supported food cannot be culled for a quota.
	game.player.position=Vector3(-at.x,0,-at.y)
	for b in settled:b.rain_age=100
	game.city.retire_distant_rain()
	for b in settled:check(game.city.rain_visible(b.position) and not b.is_queued_for_deletion(),"Visible old settled food never expires to satisfy budget")
	game.player.active=true;game.player.radius=1.5;game.player.position=Vector3(edible.position.x,0,edible.position.z);game.player._sync_shape();game.ground.sync();await frames(3)
	var id:=edible.get_instance_id();var score:int=game.player.score
	game.scan_food()
	check(is_instance_valid(edible.claimed_by) and edible.claimed_by==game.player,"Reawakened and resettled rain remains eligible for ordinary mouth admission")
	for tick in 360:
		await physics_frame
		if not is_instance_valid(edible):break
	check(not is_instance_valid(edible) and int(receipts.get(id,0))==1 and game.player.score>score,"The same rain piece finally falls through the real hole and credits exactly once")
	var result:={"checks":checks,"failures":failures,"observed_admissions":events,"peak_after_deliberate_relaunch":airborne,"scope":"Independent real contacts, reawakening, support removal, normal collection and synchronous admission snapshots; no global physics cap, renderer or phone-FPS claim."}
	game.free();await frames(3)
	print("RAIN_ADMISSION_REVIEW "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
