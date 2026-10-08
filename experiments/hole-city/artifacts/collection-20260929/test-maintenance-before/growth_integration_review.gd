extends SceneTree
## Independent integration review: real camera interpolation, mouth union and hints.
class HintBody:
	extends Node3D
	var consumed:=false
	var claimed_by:Node3D
	var support_parent:Node3D
	var footprint:=1.0
	func interaction_position()->Vector3:return global_position
	func can_fit(hole:Node3D)->bool:return not consumed and not is_instance_valid(claimed_by) and not is_instance_valid(support_parent) and footprint*1.08<=hole.radius
	func begin_swallow(hole:Node3D)->bool:claimed_by=hole;return true
class HintCity:
	extends Node3D
	var foods:Array[Node3D]=[]
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var game:Node3D

func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(count:int)->void:
	for i in count:await physics_frame

func mouth_visible()->bool:
	var size:Vector2=game.camera.get_viewport().get_visible_rect().size
	for point in 96:
		var angle:=TAU*float(point)/96.0
		var at:Vector3=game.player.position+Vector3(cos(angle),0,sin(angle))*game.player.radius
		var screen:Vector2=game.camera.unproject_position(at)
		if not game.camera.is_position_in_frustum(at) or screen.x<0 or screen.y<0 or screen.x>size.x or screen.y>size.y:return false
	return true

func camera_review()->void:
	var viewport:=SubViewport.new();viewport.world_3d=game.get_world_3d();root.add_child(viewport)
	game.camera.reparent(viewport)
	var cases:=0
	var observed_aspects:Array[float]=[]
	for size in [Vector2i(270,480),Vector2i(390,844),Vector2i(375,812),Vector2i(360,960),Vector2i(540,960),Vector2i(844,390),Vector2i(1920,1080)]:
		viewport.size=size;await process_frame
		check(game.camera.get_viewport().get_visible_rect().size==Vector2(size),"Camera uses the actual independent viewport dimensions "+str(size))
		observed_aspects.append(game.camera.get_viewport().get_visible_rect().size.aspect())
		for delta:float in [0.0,.001,1.0/120.0,1.0/60.0,.25]:
			for award:int in [1600,50000,1000000000]:
				game.player.score=0;game.player.level=1;game.player.radius=.85;game.player.position=Vector3(76,0,-76)
				game.update_camera(1.0,true)
				game.player.award(award)
				game.update_camera(delta,false)
				var tag:="%s delta=%s award=%d"%[size,delta,award]
				check(game.player.level>12 and game.player.radius>14.0,"Camera fixture crosses the original cap through a real award: "+tag)
				check(mouth_visible(),"Entire mouth is in frame on the first eased growth update: "+tag)
				check(game.camera.position.distance_to(game.player.position)+game.player.radius<game.camera.far,"Far clip covers the current eased offset and enlarged mouth: "+tag)
				var settled:=true
				for frame in 12:
					game.player.position+=Vector3(-.035,0,.04)
					game.update_camera(1.0/60.0,false)
					if not mouth_visible():settled=false
				check(settled,"Following motion stays visible throughout twelve additional easing steps: "+tag)
				cases+=1
	# A camera exactly at the newly assigned target needs the fallback direction.
	game.camera.position=game.player.position;game.update_camera(0.0,false)
	check(mouth_visible() and game.camera.position.is_finite(),"Zero-length offset uses a finite visible fallback before look_at")
	game.camera.reparent(game);viewport.free()
	metrics.camera_cases=cases;metrics.actual_camera_aspects=observed_aspects

func solid(at:Vector2)->bool:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,.05,at.y),Vector3(at.x,-.10,at.y),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.rid==game.ground.body.get_rid()

func covered(at:Vector2)->bool:
	for hole in game.holes:
		if not hole.active:continue
		var polygon:=PackedVector2Array()
		for corner in 32:
			var angle:=TAU*float(corner)/32.0
			polygon.append(Vector2(hole.position.x,hole.position.z)+Vector2(cos(angle),sin(angle))*hole.radius)
		if Geometry2D.is_point_in_polygon(at,polygon):return true
	return false

func ground_review()->void:
	var phases:=[8,4,1,0]
	for count in phases:
		for index in game.holes.size():
			var hole:Node3D=game.holes[index];hole.enabled=false;hole.active=index<count
			hole.radius=.85 if count==1 else 47.99
			hole.position=Vector3.ZERO if count==1 else Vector3(-40 if index<4 else 40,0,-60+40*(index%4))
		game.ground.sync();await frames(2)
		var open_samples:=0
		for ix in 17:
			for iz in 17:
				var at:=Vector2(-77.37+ix*9.53,-77.11+iz*9.51)
				var expected_open:=covered(at)
				if expected_open:open_samples+=1
				check(solid(at)!=expected_open,"Actual collision matches an independent polygon-union oracle with %d mouths at %s"%[count,at])
		if count==8:check(open_samples==289,"Eight near-limit mouths genuinely cover every sampled ground point")
		if count==0:check(open_samples==0 and solid(Vector2.ZERO),"Retiring the entire large union restores the original ground center")
		var faces:PackedVector3Array=game.ground.collider.get_faces()
		var finite:=true
		for vertex in faces:
			if not vertex.is_finite():finite=false
		check(finite and faces.size()<18000,"Union rebuild remains finite and bounded with %d active mouths"%count)
	metrics.ground_ray_samples=1156

func hint_review()->void:
	var old_city:Node3D=game.city
	var fixture:=HintCity.new();root.add_child(fixture);game.city=fixture
	var body:=HintBody.new();fixture.add_child(body);fixture.foods.append(body)
	for hole in game.holes:hole.active=hole==game.player
	game.player.position=Vector3.ZERO;game.player.radius=.85;game.player.level=1
	var boundaries:=[
		[1.199999,2],[1.2,2],[1.200001,3],
		[13.999999,12],[14.0,12],[14.000001,13],
		[15.88888,13],[15.88890,14],[24.88,20],[24.88001,21],
		[47.99,57795],[48.0,0],[60.0,0]]
	for boundary in boundaries:
		body.footprint=float(boundary[0])/1.08;body.claimed_by=null
		game.scan_food()
		var expected:="GROW TO LVL %d"%boundary[1] if int(boundary[1])>0 else "TOO LARGE"
		check(game.swallow_hint==expected,"Actual scan_food gives an attainable first-fitting level or truthful unreachable fallback at "+str(boundary[0]))
	body.footprint=.5;body.claimed_by=null;game.scan_food()
	check(body.claimed_by==game.player and game.swallow_hint.is_empty(),"Actual swallow admission clears stale growth hints")
	body.footprint=20.0;body.claimed_by=null;body.support_parent=fixture;game.scan_food()
	check(game.swallow_hint.is_empty(),"Supported upper objects do not produce standalone growth hints")
	body.support_parent=null;body.position=Vector3(10,0,0);game.scan_food()
	check(game.swallow_hint.is_empty(),"Distant objects cannot leave a misleading local growth prompt")
	game.city=old_city;fixture.free()

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.start_level()
	game.city.process_mode=Node.PROCESS_MODE_DISABLED
	for hole in game.holes:hole.enabled=false
	await camera_review();await ground_review();hint_review()
	game.free();await process_frame
	print("GROWTH_INTEGRATION_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent headless integration, no browser or device timing claim"}))
	quit(0 if failures.is_empty() else 1)
