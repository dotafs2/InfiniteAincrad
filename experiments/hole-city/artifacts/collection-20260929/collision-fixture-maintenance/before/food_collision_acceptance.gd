extends SceneTree
## Rounded-food collider geometry, actual contacts and independent swallowing.
const ROUND_KINDS:=["egg","cake","donut","burger","cookie","berry","pancake","pizza"]
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var game:Node3D
var receipts:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
	for i in n:await physics_frame
func collision(body:Node3D)->Shape3D:
	for child in body.get_children():
		if child is CollisionShape3D:return child.shape
	return null
func low_point(body:Node3D)->float:
	var low:=INF
	for p in collision(body).points:low=minf(low,(body.global_transform*p).y)
	return low
func collected(body:Node3D,hole:Node3D)->void:
	var id:=body.get_instance_id()
	receipts[id]={"count":int(receipts.get(id,{}).get("count",0))+1,"player":hole==game.player,"top":body.position.y+body.vertical_extent(),"points":body.points}
func inventory()->void:
	var rounded:=0;var boxes:=0;var native:=0;var bad_geometry:=0;var bad_admission:=0;var bad_material:=0;var bad_box:=0
	var resources:Dictionary={}
	for body in game.city.foods:
		if not body.has_meta("food_kind"):continue
		var shape:Shape3D=collision(body)
		if shape is CylinderShape3D:native+=1
		var kind:String=body.get_meta("food_kind")
		var key:String=body.get_meta("food_mesh_key")
		var expected_round:bool=kind not in ["bacon","sushi"] and not key.begins_with("cake_tower") and not key.begins_with("pancake_tower") and key!="cake_shop"
		var extent:Vector3=body.food_visual.mesh.get_aabb().size*body.food_visual.scale
		if expected_round:
			rounded+=1
			if not shape is ConvexPolygonShape3D:bad_geometry+=1;continue
			resources[shape.get_instance_id()]=true
			var radius:float=maxf(extent.x,extent.z)*.5
			if shape.points.size()!=32:bad_geometry+=1
			for p in shape.points:
				if not p.is_finite() or absf(Vector2(p.x,p.z).length()-radius)>.00003 or absf(absf(p.y)-extent.y*.5)>.00003:bad_geometry+=1
			if absf(body.footprint-radius)>.00003 or not body.half_size.is_equal_approx(extent*.5):bad_admission+=1
			if shape!=game.city.round_food_shape(radius,extent.y):bad_geometry+=1
		else:
			boxes+=1
			if not shape is BoxShape3D or not shape.size.is_equal_approx(extent):bad_box+=1
		if body.food_visual.material_override!=game.city.food_material:bad_material+=1
	check(rounded>1000 and boxes>100,"Inventory exercises the actual dense food city, including round foods and rectangular buildings")
	check(native==0,"No actual food collider takes the native cylinder circle-contact path")
	check(bad_geometry==0,"Every round food has a shared 16-sided prism at the original height and outer radius")
	check(bad_admission==0,"Circular admission footprint and original half-size bounds are unchanged")
	check(bad_box==0,"Bacon, sushi and rectangular building floors retain their original box collision")
	check(bad_material==0,"Food visuals retain the original shared shader material")
	check(resources.size()==game.city.round_collision_cache.size() and rounded>resources.size()*2,"Equal dimensions share collider resources instead of allocating per body")
	metrics["inventory"]={"rounded_food_bodies":rounded,"rectangular_food_bodies":boxes,"native_cylinders":native,"shared_round_resources":resources.size()}
func circular_support()->void:
	for kind in ROUND_KINDS:
		var body:Node3D=game.city.food(kind,Vector2(72,70),.7,2)
		body.position.y=3.0;body.collision_layer=8;body.collision_mask=0
		await frames(2)
		var hits:=0;var false_box:=0;var max_inset:=0.0;var outer_ratio:=0.0
		for i in 64:
			var angle:=TAU*float(i)/64
			var direction:=Vector3(cos(angle),0,sin(angle))
			var q:=PhysicsRayQueryParameters3D.create(body.position+direction*body.footprint*1.2,body.position,8)
			var hit:=game.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty() and hit.rid==body.get_rid():
				hits+=1
				var distance:float=hit.position.distance_to(body.position)
				outer_ratio=maxf(outer_ratio,distance/body.footprint)
				max_inset=maxf(max_inset,1.0-distance/body.footprint)
				if distance>body.footprint*1.001:false_box+=1
		check(hits==64,kind+": actual physics rays see a continuous round footprint in all sampled directions")
		metrics.get_or_add("support_rays",[]).append({"kind":kind,"hits":hits,"outward_overshoot_count":false_box,"maximum_outer_ratio":outer_ratio,"maximum_inset":max_inset})
		# Convex plane/ray intersection adds about 0.1 mm of engine tolerance
		# to the 1.922% authored inset; measure the actual support within 2%.
		check(false_box==0 and max_inset<.02,kind+": actual radial support stays within two percent without box corners")
		var shared:Shape3D=collision(body)
		check(shared==game.city.round_food_shape(body.footprint,body.height),kind+": repeated equal-dimension requests reuse the immutable collider")
		game.player.radius=body.footprint*1.08-.00001
		check(not body.can_fit(game.player),kind+": former just-too-small admission boundary is preserved")
		game.player.radius=body.footprint*1.08+.00001
		check(body.can_fit(game.player),kind+": former sufficiently-large admission boundary is preserved")
		body.free()
func contacts_and_swallow()->void:
	var ordinary:Array[Node3D]=[];var rain:Array[Node3D]=[]
	var kinds:Array=[]
	for i in ROUND_KINDS.size():
		var kind:String=ROUND_KINDS[i]
		var body:Node3D=game.city.food(kind,Vector2(70,-60+i*16),.55,2)
		body.position.y=3.5;body.rotation=Vector3(deg_to_rad([0,3,25,87][i%4]),.13*i,.09)
		body.lose_support(null);ordinary.append(body);kinds.append(kind)
		var drop:Node3D=game.city.spawn_rain(kind,Vector2(74,-60+i*16),5.0)
		drop.rotation=Vector3(deg_to_rad([2,40,80,15][i%4]),.19*i,.05)
		rain.append(drop)
	var max_speed:=0.0
	for tick in 360:
		await physics_frame
		for body in ordinary:max_speed=maxf(max_speed,body.linear_velocity.length())
	check(max_speed>2.0,"Released food undergoes actual gravity motion before contact")
	var resting:Array=[]
	for i in ordinary.size():
		var body:Node3D=ordinary[i]
		var bottom:=low_point(body)
		resting.append({"kind":ROUND_KINDS[i],"at":str(body.position),"velocity":str(body.linear_velocity),"angular_velocity":str(body.angular_velocity),"lowest_contact":bottom})
		check(body.position.is_finite() and bottom>-.08 and bottom<.16,ROUND_KINDS[i]+": tilted ordinary food settles on actual ground without tunnelling or hovering")
		check(body.linear_velocity.length()<.3,ROUND_KINDS[i]+": ordinary contact motion decays below the original six-second speed guard")
		check(rain[i].rain_landed and rain[i].position.is_finite() and rain[i].linear_velocity.length()<.5,ROUND_KINDS[i]+": actual rain food lands with its support state intact")
	game.player.score=0;game.player.level=1;game.player.award(60)
	game.player.active=true
	for i in ordinary.size():
		var body:Node3D=ordinary[i]
		var id:=body.get_instance_id()
		var target:Vector3=body.interaction_position()
		game.player.position=Vector3(target.x,0,target.z)
		game.scan_food()
		for tick in 150:
			await physics_frame
			if tick%6==0:game.scan_food()
			if receipts.has(id):break
		check(receipts.has(id) and receipts[id].count==1 and receipts[id].player,ROUND_KINDS[i]+": independently released food still falls through and awards exactly once")
		if receipts.has(id):check(receipts[id].top< -3.5,ROUND_KINDS[i]+": collection still waits for complete physical descent")
		check(is_instance_valid(rain[i]) and not rain[i].consumed,ROUND_KINDS[i]+": neighbouring food remains independent while this piece is swallowed")
	metrics["contacts"]={"ordinary_bodies":ordinary.size(),"rain_bodies":rain.size(),"maximum_drop_speed":max_speed,"target_receipts":ordinary.size(),"after_six_seconds":resting}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false;hole.active=false
	game.item_collected.connect(collected)
	inventory();await circular_support();await contacts_and_swallow()
	var report:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual food scene collider inventory, physics-space support rays, tilted ordinary/rain contacts and independent gravity collection. No visual or performance certification."}
	print("FOOD_COLLISION_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
