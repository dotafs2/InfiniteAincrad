extends SceneTree
## Actual frontage, rendered-route agreement, clearance and pedestrian movement.
const Urban=preload("res://fidelity/food_neighborhoods.gd")
const Layout=preload("res://fidelity/street_layout.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false
	var city:Node3D=game.city;var plan:=Urban.plan()
	var heights:Array[float]=[];var rotated:=0;var shops:=0;var landmarks:=0
	for i in city.towers.size():
		var t:Dictionary=city.towers[i];var plot:Dictionary=plan.plots[i]
		heights.append(t.height)
		if absf(sin(t.yaw*2))>.25:rotated+=1
		if t.role=="shop":shops+=1
		if t.role=="landmark":landmarks+=1
		var toward:Vector2=(Urban.closest(t.at,plan.routes[int(plot.route)])-t.at).normalized()
		var facing:=Vector2(t.base.basis.z.x,t.base.basis.z.z)
		check(facing.dot(toward)>.99,"Frontage faces its actual local walking street: %d"%i)
	check(rotated>city.towers.size()*.65,"Most frontage follows curved streets rather than global axes")
	check(shops>=20 and landmarks>=8 and heights.max()/heights.min()>3.0,"Shops, housing and landmarks form a varied skyline")
	var texture:Texture2D=game.ground.surface.get_shader_parameter("food_city_atlas")
	check(texture!=null and texture.resource_path==Urban.ATLAS_PATH,"Running ground uses the authored street atlas")
	var atlas:Image=texture.get_image()
	if atlas.is_compressed():atlas.decompress()
	for route in plan.routes:
		var first:Vector2=(Urban.point(route.points[1])-Urban.point(route.points[0])).normalized()
		var turns:=false;var painted:=true
		for i in range(1,route.points.size()-1,3):
			var a:=Urban.point(route.points[i]);var b:=Urban.point(route.points[i+1])
			if absf(first.cross((b-a).normalized()))>.3:turns=true
			var uv:Vector2=(a+Vector2.ONE*80)/160
			var c:=atlas.get_pixel(clampi(int(uv.x*atlas.get_width()),0,atlas.get_width()-1),clampi(int(uv.y*atlas.get_height()),0,atlas.get_height()-1))
			if c.r<.8 or c.g<.45 or c.b>.88:painted=false
		check(turns or (absf(first.x)>.1 and absf(first.y)>.1),"Street has a curved or diagonal alignment: "+route.name)
		check(painted,"Walk constraint matches the displayed pavement: "+route.name)
	# The street skeleton must be a connected branching graph, not four grid axes.
	var reached:={0.0:true};var degree:={};var grid_trunks:=0
	var road_length:=0.0;var angled_length:=0.0
	for edge in plan.roads:
		var a:=Urban.point(plan.nodes[int(edge.from)].at)
		var b:=Urban.point(plan.nodes[int(edge.to)].at)
		check(a.distance_to(Urban.point(edge.points[0]))<.001 and b.distance_to(Urban.point(edge.points[-1]))<.001,"Road joins its actual graph nodes: "+edge.name)
		degree[edge.from]=int(degree.get(edge.from,0))+1;degree[edge.to]=int(degree.get(edge.to,0))+1
		for j in edge.path.size()-1:
			var segment:Vector2=edge.path[j+1]-edge.path[j]
			road_length+=segment.length()
			if absf(2*segment.x*segment.y/segment.length_squared())>.25:angled_length+=segment.length()
		if a.distance_to(b)>90 and (absf(a.x-b.x)<.1 or absf(a.y-b.y)<.1):grid_trunks+=1
	for pass_index in plan.nodes.size():
		for edge in plan.roads:
			if reached.has(edge.from) or reached.has(edge.to):reached[edge.from]=true;reached[edge.to]=true
	check(reached.size()==plan.nodes.size() and degree.values().filter(func(n):return n>=3).size()>=6,"All primary streets connect through six or more real branching junctions")
	check(angled_length/road_length>.70,"Most primary-road length curves or cuts diagonally instead of retaining orthogonal blocks")
	check(grid_trunks==0,"No full-width Cartesian trunks remain in the food map")
	var unsafe_walks:=[]
	for route in plan.routes:
		for p in route.path:
			if Urban.on_road(p,float(route.half_width)+.2):unsafe_walks.append(route.name);break
	check(unsafe_walks.is_empty(),"Every pedestrian corridor clears vehicle lanes: "+str(unsafe_walks))
	var road_obstacles:=[]
	for plot in plan.plots+plan.heaps:
		if Urban.on_road(Urban.point(plot.at),float(plot.radius)):road_obstacles.append(plot.at)
	check(road_obstacles.is_empty(),"Actual building and heap envelopes leave the new carriageways clear")
	# Check the whole vehicle footprint against the painted road, including curves.
	var off_road:=0;var unpainted:=0
	var half:Vector3=city.moving_vehicles[0].body.half_size
	for meter in range(0,int(plan.traffic.lane_length),2):
		var pose:=Urban.lane_sample(float(meter));var f:Vector2=pose.forward;var side:=Vector2(f.y,-f.x)
		for sx in [-1,1]:
			for sz in [-1,1]:
				var corner:Vector2=pose.at+side*half.x*sx+f*half.z*sz
				if not Urban.on_road(corner):off_road+=1
				var uv:Vector2=(corner+Vector2.ONE*80)/160
				var color:=atlas.get_pixel(int(uv.x*atlas.get_width()),int(uv.y*atlas.get_height()))
				if color.r<.9 or color.g<.45 or color.b>.9:unpainted+=1
	check(off_road==0 and unpainted==0,"Full sushi-car envelopes follow the rendered curved boulevard: off-road=%d, unpainted=%d"%[off_road,unpainted])
	game.player.position=Vector3(75,0,75)
	var traveled:=0.0;var wraps:=0;var jumps:=0;var collisions:=0
	for tick in 3200:
		var previous:Array=[]
		for t in city.moving_vehicles:previous.append({"at":t.body.position,"progress":t.progress})
		city.update_traffic(.1)
		for i in city.moving_vehicles.size():
			var t:Dictionary=city.moving_vehicles[i]
			var step:float=t.body.position.distance_to(previous[i].at)
			traveled+=step
			if step>float(t.speed)*.1+.002:jumps+=1
			if t.progress<previous[i].progress:wraps+=1
			for j in range(i+1,city.moving_vehicles.size()):
				if city.vehicles_overlap(t.body,city.moving_vehicles[j].body):collisions+=1
	check(wraps>=8 and traveled>5000 and jumps==0,"Cars complete continuous laps without old edge-wrap teleports")
	check(collisions==0,"Curved-lane convoys keep their physical envelopes separated")
	# Full plot footprints clear every pedestrian route, not just the main roads.
	var blocked_plots:=[]
	for plot in plan.plots+plan.heaps:
		var p:=Urban.point(plot.at)
		for route in plan.routes:
			if Urban.closest(p,route).distance_to(p)<float(plot.radius)+float(route.half_width)-.01:
				blocked_plots.append({"at":plot.at,"route":route.name})
	check(blocked_plots.is_empty(),"Buildings and rotated heap envelopes leave walking streets open: "+str(blocked_plots))
	# Exercise a minute of normal/panic motion without allowing the mouth to eat actors.
	game.player.radius=.05
	var unsafe:=0
	for tick in 600:
		game.elapsed=tick*.1
		if tick%80==0:
			var c:Dictionary=city.citizens[(tick/80)%city.citizens.size()]
			game.player.position=c.body.position+Vector3(1.6,0,0)
		city._process(.1)
		for c in city.citizens:
			if not city.pedestrian_contains(c,Vector2(c.body.position.x,c.body.position.z)):unsafe+=1
	check(unsafe==0,"All citizens stay on their curved pedestrian lanes")
	# Consuming a car must not abort updates for the remaining convoy.
	city.set_process(false)
	for hole in game.holes:hole.active=hole==game.player
	var eaten:Node3D=city.moving_vehicles[0].body
	game.player.level=4;game.player.score=game.player.LEVEL_STARTS[3]
	game.player.radius=game.player.RADII[3];game.player.position=Vector3(eaten.position.x,0,eaten.position.z);game.player._sync_shape()
	for frame in 3:await physics_frame
	check(eaten.begin_swallow(game.player),"A moving sushi car enters a real physical fall")
	for frame in 240:
		await physics_frame
		if not is_instance_valid(eaten):break
	check(not is_instance_valid(eaten),"A swallowed sushi vehicle is physically collected and removed")
	game.player.position=Vector3(75,0,75)
	var before:float=city.moving_vehicles[1].progress
	city.update_traffic(.1)
	check(city.moving_vehicles[1].progress!=before,"Remaining cars keep moving after a previous route node is freed")
	var result:={"checks":checks,"failures":failures,"buildings":city.towers.size(),"angled_frontages":rotated,"shops":shops,"landmarks":landmarks,"height_range":[heights.min(),heights.max()],"walking_routes":plan.routes.size(),"blocked_plots":blocked_plots,"road_edges":plan.roads.size(),"angled_road_fraction":angled_length/road_length,"junctions":degree.values().filter(func(n):return n>=3).size(),"vehicle_laps":wraps,"vehicle_distance":traveled}
	print("FOOD_NEIGHBORHOODS_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
