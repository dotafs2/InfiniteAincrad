extends SceneTree
## Actual larger food footprints, safe clearances and low-level accessibility.
## The unchanged full food_city_density suite separately gates all 11 districts.
var checks:=0
var failures:Array[String]=[]
var mesh_radii:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func mesh_radius(mesh:Mesh)->float:
	if mesh_radii.has(mesh.get_instance_id()):return mesh_radii[mesh.get_instance_id()]
	var center:=mesh.get_aabb().get_center();var radius:=0.0
	for surface in mesh.get_surface_count():
		for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			radius=maxf(radius,Vector2(vertex.x-center.x,vertex.z-center.z).length())
	mesh_radii[mesh.get_instance_id()]=radius;return radius
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false)
	game.city.rain_enabled=false;game.city.set_process(false)
	for hole in game.holes:hole.enabled=false;hole.active=false
	var plan:Dictionary=game.city.Neighborhoods.plan()
	var envelopes:Array[Dictionary]=[]
	var max_height:=0.0;var min_size:=INF;var max_size:=0.0
	var tiny_by_district:={7:0,8:0,9:0,10:0}
	for i in range(136,160):
		var plot:Dictionary=plan.plots[i];var tower:Dictionary=game.city.towers[i]
		var origin:=Vector2(plot.at[0],plot.at[1]);var radius:=float(plot.placement_radius)
		var actual_radius:=0.0;var supported:=0
		for body in tower.tiers:
			var offset:=Vector2(body.position.x,body.position.z).distance_to(origin)
			actual_radius=maxf(actual_radius,offset+mesh_radius(body.food_visual.mesh)*body.food_visual.scale.x)
			max_height=maxf(max_height,body.position.y+body.half_size.y)
			if is_instance_valid(body.support_parent):supported+=1
		check(actual_radius<=radius+.001,"Actual independent tower geometry fits reserved envelope: "+str(i))
		check(tower.tiers.size()==int(plot.floors)+1 and supported==tower.tiers.size()-1,"Every enlarged tower retains its original independent tier/support count: "+str(i))
		check(tower.base.half_size.x*2.0>4.5 and tower.base.half_size.z*2.0>4.5,"New frontage is physically broader than the former tiny shop: "+str(i))
		min_size=minf(min_size,float(plot.size));max_size=maxf(max_size,float(plot.size))
		envelopes.append({"at":origin,"radius":radius,"id":"tower-"+str(i)})
	var loose:Array=game.city.foods.filter(func(body):return body.has_meta("food_kind") and not body.has_meta("tower_id") and not body.has_meta("pile_id") and not body.get_meta("traffic",false))
	check(loose.size()==plan.snacks.size(),"Plan loose foods correspond one-to-one to actual collision bodies")
	for i in range(960,1080):
		var record:Dictionary=plan.snacks[i];var body:Node3D=loose[i]
		var radius:float=mesh_radius(body.food_visual.mesh)*body.food_visual.scale.x
		check(radius<=float(record.placement_radius)+.001,"Food-plaza collision/mesh scale fits its reserved circle: "+str(i))
		check(body.freeze and not is_instance_valid(body.support_parent) and absf(body.position.y-body.half_size.y)<.05,"Each enlarged loose food is a separate ground-supported body: "+str(i))
		if record.frontage=="starter_food":
			tiny_by_district[int(record.district)]+=1
			check(body.can_fit(game.player),"Perimeter retains actual edible LVL1 food: "+str(i))
		envelopes.append({"at":Vector2(record.at[0],record.at[1]),"radius":float(record.placement_radius),"id":"food-"+str(i)})
	for envelope in envelopes:
		var clear:bool=not game.city.Neighborhoods.on_road(envelope.at,envelope.radius+.25)
		for route in plan.routes:
			if game.city.Neighborhoods.closest(envelope.at,route).distance_to(envelope.at)<envelope.radius+float(route.half_width)+.25:clear=false
		check(clear,"Full larger food footprint leaves real streets and sidewalks clear: "+envelope.id)
		check(maxf(absf(envelope.at.x),absf(envelope.at.y))+envelope.radius<=96.001,"Larger food stays inside reachable world bounds: "+envelope.id)
	var nonoverlap:=true
	for i in envelopes.size():
		for j in range(i+1,envelopes.size()):
			if envelopes[i].at.distance_to(envelopes[j].at)<envelopes[i].radius+envelopes[j].radius+.34:nonoverlap=false
	check(nonoverlap,"New building/plaza food envelopes do not interpenetrate each other")
	check(tiny_by_district.values()==[6,6,6,6],"All four perimeter districts retain six genuinely small starter foods")
	check(max_height<17.0,"Actual top of every enlarged building stays below 18 m rain spawn altitude")
	check(max_size/min_size>1.4,"Physical frontage sizes remain visibly varied")
	check(game.city.foods.size()==2922 and game.city.mesh_cache.size()<=40,"Denser footprint uses the same bounded body and shared-mesh budgets")
	var result:={"checks":checks,"failures":failures,"actual_maximum_new_building_height":max_height,"new_building_size_range":[min_size,max_size],"small_foods_per_district":tiny_by_district,"initial_objects":game.city.foods.size(),"mesh_cache_count":game.city.mesh_cache.size(),"scope":"Real geometry/support/clearance; no rendered appearance or phone-performance claim"}
	game.free();await process_frame
	print("PERIMETER_FRONTAGE_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
