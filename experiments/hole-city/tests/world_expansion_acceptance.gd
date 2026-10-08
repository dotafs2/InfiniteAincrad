extends SceneTree
## Real expanded terrain, connected streets, edible content and unchanged scale.
const Bounds=preload("res://fidelity/world_bounds.gd")
const Layout=preload("res://fidelity/street_layout.gd")
const Urban=preload("res://fidelity/food_neighborhoods.gd")
var checks:=0
var failures:Array[String]=[]
var measurements:Dictionary={}
var game:Node3D

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for i in count:await physics_frame
func ground_at(at:Vector2)->bool:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,.06,at.y),Vector3(at.x,-.08,at.y),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.rid==game.ground.body.get_rid()
func raw_count()->int:
	var count:=0
	for body in game.city.foods:
		if is_instance_valid(body) and not body.consumed:count+=1
	return count
func report(result:Dictionary)->bool:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--report="):continue
		var path:=argument.trim_prefix("--report=")
		if not path.is_absolute_path() or "://" in path:return false
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file==null:return false
		file.store_string(JSON.stringify(result,"\t")+"\n");file.flush()
		var success:=file.get_error()==OK;file.close();return success
	return true
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	check(Bounds.HALF==100.0 and Bounds.PLAY_LIMIT==96.0,"Actual ground expands to 200 m with a 192 m playable width")
	check(pow(Bounds.HALF/80.0,2)>1.56 and pow(Bounds.PLAY_LIMIT/76.0,2)>1.59,"Ground and playable area increase by about 56 and 60 percent")
	check(Urban.atlas_uv(Vector2(-100,-100))==Vector2.ZERO and Urban.atlas_uv(Vector2(100,100))==Vector2.ONE,"Atlas coordinates span the complete enlarged ground")
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	check(game.WORLD_LIMIT==Bounds.PLAY_LIMIT,"Player movement uses the same expanded playable bounds")
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level();game.begin_play();game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for h in game.holes:h.enabled=false;h.active=false
		game.ground.sync();await frames(2)
		check(game.ground.HALF==Bounds.HALF and game.ground.surface.get_shader_parameter("world_half")==Bounds.HALF,map_id+": physical ground and shader atlas bounds agree")
		check(game.city.scale==Vector3.ONE and game.ground.scale==Vector3.ONE,map_id+": genuine additional world coordinates rather than enlarged node scale")
		for at in [Vector2(-99,-99),Vector2(-99,0),Vector2(99,0),Vector2(99,99),Vector2(0,99),Vector2(0,-99)]:
			check(ground_at(at),map_id+": new outer ground is physically solid at "+str(at))
		for at in [Vector2(101,0),Vector2(-101,0),Vector2(0,101),Vector2(0,-101)]:
			check(not ground_at(at),map_id+": collision ends at the actual new world edge at "+str(at))
		var outer:Array[Node3D]=[];var quadrants:={};var frozen:=0;var original_scales:=true
		for body in game.city.foods:
			if maxf(absf(body.position.x),absf(body.position.z))>80.0:
				outer.append(body);quadrants[Vector2i(1 if body.position.x>=0 else -1,1 if body.position.z>=0 else -1)]=true
				if body.freeze:frozen+=1
				if body.scale!=Vector3.ONE:original_scales=false
		check(outer.size()>=100 and quadrants.size()==4,map_id+": more than 100 edible bodies populate all four quadrants outside the old ground")
		check(frozen>=outer.size()-8 and original_scales,map_id+": outer food stays frozen at its original physical scale until release")
		if map_id=="city":
			check(game.city.outer_district_count==152 and game.city.outer_district_count<=200,"City adds only 152 objects within the 200-object budget")
			check(game.city.building_visuals.size()==72 and game.city.used_assets.size()==208,"Existing catalog remains intact with 24 additional buildings")
			var buildings:=0
			for record in game.city.building_visuals:
				if record.body.get_meta("outer_district",false):buildings+=1
			check(buildings==24,"Outer district contains actual building bodies, not distant decorative meshes")
			for x in [Layout.ROAD_X.x,Layout.ROAD_X.y]:
				for z in [-Layout.OUTER_ROAD,Layout.OUTER_ROAD]:
					check(Layout.on_road(Vector2(x,z)),"Outer ring joins an unchanged north-south avenue")
			for z in [Layout.ROAD_Z.x,Layout.ROAD_Z.y]:
				for x in [-Layout.OUTER_ROAD,Layout.OUTER_ROAD]:
					check(Layout.on_road(Vector2(x,z)),"Outer ring joins an unchanged east-west avenue")
			check(game.city.citizens.size()==64 and game.city.moving_vehicles.size()==8,"City preserves actor counts and existing traffic loops")
		else:
			var plan:=Urban.plan();var added:=0
			for i in range(136,game.city.towers.size()):added+=game.city.towers[i].tiers.size()
			for i in range(12,14):added+=game.city.piles[i].pieces.size()
			added+=120
			check(game.city.towers.size()==160 and game.city.piles.size()==17 and plan.snacks.size()==1080,"Food extension includes 24 real buildings, two heaps and 120 small foods")
			check(added>250 and added<=450,"Food extension stays within its conservative 450-body budget")
			var reached:={0.0:true}
			for pass_index in plan.nodes.size():
				for edge in plan.roads:
					if reached.has(edge.from) or reached.has(edge.to):reached[edge.from]=true;reached[edge.to]=true
			check(reached.size()==20 and plan.roads.size()==27,"All eight outer junctions and four connectors join the original street graph")
			check(plan.traffic_routes.size()==2 and game.city.moving_vehicles.size()==8 and game.city.citizens.size()==48,"Food keeps existing vehicle routes and bounded resident counts")
			check(game.city.batch_count>0,"New static food uses the existing shared batch path")
			measurements["food_additional_bodies"]=added
		var target:Node3D=null
		for body in outer:
			if body.footprint<.8 and body.freeze and body.category not in ["person","vehicle"] and not body.has_meta("tower_id") and not body.has_meta("pile_id"):target=body;break
		check(target!=null,map_id+": outer streets include small food that the player can actually collect")
		if target!=null:
			var at:=Vector2(target.position.x,target.position.z)
			game.player.active=true;game.player.award(30);game.player.position=Vector3(at.x,0,at.y);game.player._sync_shape()
			game.ground.sync();await frames(2)
			check(not ground_at(at),map_id+": the real hole cuts the new outer terrain")
			var score_before:int=game.player.score
			for tick in 240:
				if tick%6==0:game.scan_food()
				await physics_frame
				if not is_instance_valid(target):break
			check(not is_instance_valid(target) and game.player.score>score_before,map_id+": outer collectible physically falls and awards score")
			game.player.active=false;game.ground.sync();await frames(2)
			check(ground_at(at),map_id+": old outer hole restores collision when inactive")
		measurements[map_id]={"initial_outer_edibles":outer.size(),"outer_frozen":frozen,"quadrants":quadrants.size(),"remaining_food":raw_count()}
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"measurements":measurements,"scope":"Real expanded geometry and collection; no browser, rendered appearance or phone-frame-rate claim"}
	var saved:=report(result);print("WORLD_EXPANSION_ACCEPTANCE "+JSON.stringify(result));quit(0 if failures.is_empty() and saved else 1)
