extends SceneTree
## Independent real-world bounds/road/placement review. No timing or image claim.
const Bounds=preload("res://fidelity/world_bounds.gd")
const Layout=preload("res://fidelity/street_layout.gd")
const Urban=preload("res://fidelity/food_neighborhoods.gd")
## Sparse preserved pre-expansion plan coordinates; full byte-equivalence is separately retained in the independent report.
const TRAFFIC_BASELINE:=[[0, 0, -51.0, 51.0], [0, 23, -59.141673900462976, 9.73093894675926], [0, 46, -44.829861111111114, -27.479456018518523], [0, 69, -18.9169921875, -48.5322265625], [0, 92, 14.432870370370372, -52.442129629629626], [0, 115, 44.49768518518518, -34.18326822916667], [0, 138, 56.5234375, 0.21875], [0, 161, 44.88125723379629, 37.9945384837963], [0, 184, 18.59259259259259, 58.11111111111111], [0, 207, -12.2783203125, 55.41015625], [0, 230, -41.35011574074074, 54.0396412037037], [1, 0, -59.0, 8.0], [1, 23, -36.738800239273644, 10.733406055707405], [1, 46, -15.199963181390821, 2.9230627620733927], [1, 69, 6.29817872094016, -5.247626564041436], [1, 92, 25.76319678460186, -16.64830278783852], [1, 115, 46.02954260659092, -27.0835998031013], [1, 138, 56.5517578125, 1.8909143518518503], [1, 161, 43.9296875, 39.4609375], [1, 184, 27.76820386125578, 34.68590058349554], [1, 207, 27.519935009738358, 12.697185625822016], [1, 230, 22.55335406410927, -9.314555954303604], [1, 253, 4.446639842708593, -4.491604169705379], [1, 276, -17.06665439379694, 3.641020920691131], [1, 299, -23.93324822307847, -16.93930410570337], [1, 322, -18.51664173347734, -39.25842507626455], [1, 345, -28.986725983796298, -43.1349464699074], [1, 368, -51.732638888888886, -15.695891203703702]]
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func frames(count:int)->void:
	for frame in count:await physics_frame
func solid(at:Vector2)->bool:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,.05,at.y),Vector3(at.x,-.09,at.y),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.rid==game.ground.body.get_rid()
func covered(at:Vector2)->bool:
	for hole in game.holes:
		if not hole.active:continue
		var poly:=PackedVector2Array()
		for index in 32:poly.append(Vector2(hole.position.x,hole.position.z)+Vector2.from_angle(TAU*index/32.0)*hole.radius)
		if Geometry2D.is_point_in_polygon(at,poly):return true
	return false
func point(row:Array)->Vector2:return Vector2(float(row[0]),float(row[1]))
func road_distance(at:Vector2,road:Dictionary)->float:
	var closest:=INF
	for i in road.points.size()-1:
		closest=minf(closest,Geometry2D.get_closest_point_to_segment(at,point(road.points[i]),point(road.points[i+1])).distance_to(at))
	return closest
func inspect_bodies(map_id:String)->void:
	var outside:=[];var outer:Array[Node3D]=[];var quadrants:={};var scaled:=[];var awake:=0
	var maximum_scale_error:=0.0
	for body in game.city.foods:
		if not is_instance_valid(body):continue
		# Decomposing an oblique rotation can differ from unit scale by one
		# float32 ULP. Keep all bodies, including trains, within a fixed 1e-6.
		var scale_error:float=body.scale.distance_to(Vector3.ONE)
		maximum_scale_error=maxf(maximum_scale_error,scale_error)
		if scale_error>0.000001:scaled.append(str(body.name))
		var h:Vector3=body.half_size;var bad:=false
		for sx in [-1,1]:
			for sy in [-1,1]:
				for sz in [-1,1]:
					var at:Vector3=body.global_transform*Vector3(h.x*sx,h.y*sy,h.z*sz)
					if maxf(absf(at.x),absf(at.z))>Bounds.HALF+.02:bad=true
		if bad:outside.append(str(body.name))
		if maxf(absf(body.position.x),absf(body.position.z))>80:
			outer.append(body);quadrants[Vector2i(-1 if body.position.x<0 else 1,-1 if body.position.z<0 else 1)]=true
			if not body.freeze:awake+=1
	check(outside.is_empty(),map_id+": every edible body's complete rotated bounds remains on the enlarged terrain: "+str(outside))
	check(scaled.is_empty() and game.city.scale==Vector3.ONE,map_id+": added area does not rescale existing food or map geometry")
	check(outer.size()>100 and quadrants.size()==4,map_id+": genuinely new edible coordinates populate every outer quadrant")
	check(awake==0,map_id+": outer static food adds no continuously awake rigid bodies at startup")
	var query_found:=0
	for body in outer:
		if body.freeze and body.footprint<.8 and not body.has_meta("tower_id") and not body.has_meta("pile_id"):
			if game.city.query_foods(body.global_position,1.0).has(body):query_found+=1
	check(query_found>=20,map_id+": new loose foods participate in the actual spatial collection query")
	metrics[map_id]={"all_edibles":game.city.foods.size(),"outer_edibles":outer.size(),"queryable_small_food":query_found,"outside":outside,"maximum_scale_error":maximum_scale_error,"scale_tolerance":0.000001}
func ground_samples(map_id:String)->void:
	check(game.WORLD_LIMIT==96.0 and game.ground.HALF==100.0,map_id+": player and cut terrain use the real expanded coordinates")
	check(game.ground.surface.get_shader_parameter("world_half")==100.0,map_id+": material receives the shared enlarged atlas domain")
	var extrema:=Vector2(INF,-INF)
	for vertex in game.ground.collider.get_faces():extrema=Vector2(minf(extrema.x,minf(vertex.x,vertex.z)),maxf(extrema.y,maxf(vertex.x,vertex.z)))
	check(extrema==Vector2(-100,100),map_id+": actual collision triangles extend exactly to both new world edges")
	for side in [-1,1]:
		for along in [-99.37,-84.31,-60.13,-.27,45.71,84.23,99.17]:
			check(solid(Vector2(side*99.4,along)) and solid(Vector2(along,side*99.4)),map_id+": new outer strips have real ground")
			check(not solid(Vector2(side*100.6,along)) and not solid(Vector2(along,side*100.6)),map_id+": no phantom ground beyond the new edge")
func city_streets()->void:
	check(game.city.citizens.size()==64 and game.city.moving_vehicles.size()==8,"City actor and vehicle workloads remain unchanged")
	check(game.city.building_visuals.size()==72,"All original and 24 added houses are real building bodies")
	check(game.ground.surface.get_shader_parameter("city_outer_road")==84.0 and game.ground.surface.get_shader_parameter("city_outer_half_width")==3.2,"City road classification and painted road use identical explicit ring uniforms")
	var continuity:=true
	for side in [-1,1]:
		for step in 169:
			var along:float=-84+step
			if not Layout.on_road(Vector2(side*84,along)) or not Layout.on_road(Vector2(along,side*84)):continuity=false
	check(continuity,"The full outer avenue, including four corners, is a continuous road")
	for x in [-27.0,29.0]:
		for z in [-84.0,84.0]:check(Layout.on_road(Vector2(x,z-.1)) and Layout.on_road(Vector2(x,z+.1)),"Original vertical avenue joins new ring without a gap")
	for z in [-30.0,-2.0]:
		for x in [-84.0,84.0]:check(Layout.on_road(Vector2(x-.1,z)) and Layout.on_road(Vector2(x+.1,z)),"Original horizontal avenue joins new ring without a gap")
	var invalid:=0
	for route in 2:
		for sample in 256:
			var pose:Dictionary=Layout.traffic_sample(Layout.traffic_length(route)*float(sample)/256,route)
			if absf(pose.at.x)>31 or absf(pose.at.y)>32 or not Layout.on_road(pose.at):invalid+=1
		var a:Dictionary=Layout.traffic_sample(-.001,route);var b:Dictionary=Layout.traffic_sample(.001,route)
		check(a.at.distance_to(b.at)<.0021 and a.forward.dot(b.forward)>.999,"Original city traffic loop retains continuous seam and direction")
	check(invalid==0,"Original traffic stays in its unchanged inner-avenue coordinates")
func food_streets()->void:
	var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Urban.PLAN_PATH))
	check(plan.nodes.size()==20 and plan.roads.size()==27,"Food scene loads the expanded plan rather than a larger empty floor")
	var adjacency:={};var reached:={};var stack:Array=[0]
	for edge in plan.roads:
		for pair in [[int(edge.from),int(edge.to)],[int(edge.to),int(edge.from)]]:
			if not adjacency.has(pair[0]):adjacency[pair[0]]=[]
			adjacency[pair[0]].append(pair[1])
	while not stack.is_empty():
		var current:int=stack.pop_back()
		if reached.has(current):continue
		reached[current]=true
		stack.append_array(adjacency.get(current,[]))
	check(reached.size()==20,"Independent graph traversal reaches every new outer food junction")
	var atlas:Image=(game.ground.surface.get_shader_parameter("food_city_atlas") as Texture2D).get_image()
	if atlas.is_compressed():atlas.decompress()
	check(atlas.get_width()==2048 and atlas.get_height()==2048 and atlas.has_mipmaps(),"Actual imported atlas keeps bounded resolution and mip filtering")
	var appended:=0
	for road in plan.roads:
		if not road.get("extension",false):continue
		appended+=1
		check(point(road.points[0]).distance_to(point(plan.nodes[int(road.from)].at))<.001 and point(road.points[-1]).distance_to(point(plan.nodes[int(road.to)].at))<.001,"New road endpoints coincide with actual junction nodes: "+road.name)
		var painted:=true;var bounded:=true
		for i in range(1,road.points.size()-1):
			var p:=point(road.points[i]);var uv:=(p+Vector2.ONE*100)/200.0
			var color:=atlas.get_pixel(clampi(int(uv.x*2048),0,2047),clampi(int(uv.y*2048),0,2047))
			if color.r<.9 or color.g<.45 or color.b>.9:painted=false
			if maxf(absf(p.x),absf(p.y))+float(road.half_width)>100:bounded=false
		check(painted and bounded,"Added road is painted across the actual enlarged atlas and remains inside terrain: "+road.name)
	check(appended==12,"Eight outer sections and four connectors are actual new road geometry")
	var conflicts:=[]
	for plot in plan.plots+plan.heaps:
		for road in plan.roads:
			if road_distance(point(plot.at),road)<float(plot.radius)+float(road.half_width)-.01:conflicts.append(plot.at);break
	check(conflicts.is_empty(),"Independent segment-distance oracle finds no building or heap blocking a carriageway")
	check(game.city.citizens.size()==48 and game.city.moving_vehicles.size()==8,"Food population and traffic fleet remain bounded at original counts")
	check(plan.traffic_routes.size()==2,"Both existing food traffic loops remain")
	for row in TRAFFIC_BASELINE:
		var actual:Vector2=point(plan.traffic_routes[row[0]].points[row[1]])
		check(actual.distance_to(Vector2(row[2],row[3]))<.0001,"Original traffic path coordinate remains unchanged at "+str(row.slice(0,2)))
func edge_mouths(map_id:String)->void:
	for i in game.holes.size():
		var hole:Node3D=game.holes[i];hole.enabled=false;hole.active=i<4;hole.radius=4.2
		if i<4:hole.position=Vector3(95 if i<2 else -95,0,95 if i%2==0 else -95)
	game.ground.sync();await frames(2)
	for sx in [-1,1]:
		for sz in [-1,1]:
			for x in [91.17,94.29,97.33,99.43]:
				for z in [91.21,94.27,97.37,99.47]:
					var at:=Vector2(sx*x,sz*z)
					check(solid(at)!=covered(at),map_id+": expanded edge collision matches independent actual mouth polygons")
	for hole in game.holes:hole.active=false
	game.ground.sync();await frames(2)
	check(solid(Vector2(95,95)) and solid(Vector2(-95,-95)),map_id+": moving or retiring edge holes restores actual ground")
func movement_limit(map_id:String)->void:
	game.player.active=true;game.player.enabled=true;game.player.radius=.85;game.player.set_physics_process(true)
	for side in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
		game.player.position=Vector3(side.x*95.98,0,side.y*95.98);game.player.test_direction=side
		await frames(12)
		var at:=Vector2(game.player.position.x,game.player.position.z)
		check(is_equal_approx(at.dot(side),96.0),map_id+": real player movement reaches and clamps at the new limit "+str(side))
	game.player.enabled=false;game.player.active=false;game.player.test_direction=Vector2.ZERO;game.player.set_physics_process(false)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level();game.begin_play();game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
		game.ground.sync();await frames(2)
		inspect_bodies(map_id);ground_samples(map_id)
		if map_id=="city":city_streets()
		else:food_streets()
		await edge_mouths(map_id);await movement_limit(map_id)
	game.free();await process_frame
	print("WORLD_EXPANSION_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent real geometry, movement, physics rays, food atlas and original traffic; no GPU image or frame-rate claim."}))
	quit(0 if failures.is_empty() else 1)
