extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play();game.city.set_process(false);game.set_physics_process(false)
	for h in game.holes:h.enabled=false;h.active=false
	game.player.position=Vector3(70,0,70)
	var city:Node3D=game.city;var layout=city.Layout
	check(city.building_visuals.size()==48 and city.used_assets.size()==208,"District composition retains all 48 buildings and all 208 original catalog assets")
	check(city.city_districts.size()>=3,"At least three authored named districts")
	var ids:Array=[];var reached:Array=[];var pending:Array=[city.city_districts[0].id]
	for district in city.city_districts:
		ids.append(district.id)
		var landmarks:int=city.building_visuals.filter(func(b):return b.body.get_meta("city_district","")==district.id and b.body.get_meta("district_landmark",false)).size()
		check(landmarks==1,"District has its own real landmark: "+district.id)
		check(district.park.size.x>=7 and district.park.size.y>=2,"District has an authored park: "+district.id)
	while not pending.is_empty():
		var id:String=pending.pop_front()
		if reached.has(id):continue
		reached.append(id)
		for district in city.city_districts:
			if district.id==id:pending.append_array(district.links)
	check(reached.size()==ids.size(),"All district entrances belong to one connected avenue network")
	var areas:={};var turned:=0;var clear:=true;var static_walk_blockers:Array=[]
	for route in layout.WALK_LOOPS.size():
		var area:Rect2=layout.WALK_LOOPS[route]
		areas[snappedf(area.get_area(),1.0)]=true
		var painted:Vector4=game.ground.surface.get_shader_parameter("city_walk_%d"%route)
		check(painted==Vector4(area.position.x,area.position.y,area.size.x,area.size.y),"Walk route %d uses identical rendered and movement geometry"%route)
		for sample in 100:
			var at:Vector2=layout.walk_sample(layout.walk_length(route)*sample/100.0,route)
			if layout.on_road(at,.3):clear=false
	check(areas.size()>=3 and clear,"Three block sizes have continuous sidewalk loops clear of traffic")
	for i in city.building_visuals.size():
		var body:RigidBody3D=city.building_visuals[i].body
		var parcel:Rect2=city.traffic_bounds(body,0)
		check(not layout.intersects_walk(parcel),"Building footprint clears painted walking loops: "+str(body.name))
		var onroad:=false
		for corner in [parcel.position,parcel.end,Vector2(parcel.position.x,parcel.end.y),Vector2(parcel.end.x,parcel.position.y)]:
			if layout.on_road(corner):onroad=true
		check(not onroad,"Building footprint clears avenues: "+str(body.name))
		for j in range(i+1,city.building_visuals.size()):
			check(not parcel.intersects(city.traffic_bounds(city.building_visuals[j].body,0)),"Distinct district parcels do not overlap: %d/%d"%[i,j])
	for body in city.foods:
		if body.get_meta("catalog_group","") not in ["prop","plant"] and body.category not in ["signal_pylon","railing"]:continue
		if layout.intersects_walk(city.traffic_bounds(body,0)):static_walk_blockers.append(str(body.name))
	check(static_walk_blockers.is_empty(),"Painted pedestrian routes clear furniture and planted obstacles")
	var before:Array[float]=[]
	for c in city.citizens:before.append(c.body.rotation.y)
	for tick in 60*60:
		game.elapsed=float(tick)/60.0;city._process(1.0/60.0)
	for i in city.citizens.size():
		if absf(angle_difference(before[i],city.citizens[i].body.rotation.y))>PI*.35:turned+=1
	check(turned>=20,"A minute of actual circulation includes multiple block corners")
	var result:={"checks":checks,"failures":failures,"districts":ids,"block_areas":areas.keys(),"turned_citizens":turned,"walk_blockers":static_walk_blockers,"catalog_sha256":FileAccess.get_sha256("res://fidelity/catalog_city.gd"),"layout_sha256":FileAccess.get_sha256("res://fidelity/street_layout.gd")}
	print("CITY_DISTRICTS_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
