extends SceneTree
## Real dense-map support loss, sequential collapse, collision and collection QA.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var receipts:Dictionary={}
var coverage:Array[Dictionary]=[]
var collapse_results:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func receipt(item:Node3D,_hole:Node3D)->void:receipts[item.name]=int(receipts.get(item.name,0))+1
func frames(count:int,scan:=true)->void:
	for i in count:
		await physics_frame
		if scan and i%6==0:game.scan_food()
func move_hole(at:Vector2,level:int)->void:
	game.player.level=level;game.player.score=game.player.LEVEL_STARTS[level-1]
	game.player.radius=game.player.RADII[level-1];game.player.position=Vector3(at.x,0,at.y);game.player._sync_shape()
func run()->void:
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false)
	game.city.rain_enabled=false;game.item_collected.connect(receipt)
	for h in game.holes:h.enabled=false;h.active=h==game.player
	move_hole(Vector2(74,-74),1)
	await frames(4,false)
	var count:int=game.city.foods.size()
	check(count>=2000 and count<=3000,"Dense city retains a bounded 2,000–3,000 initial physical objects")
	check(game.city.towers.size()>=90 and game.city.piles.size()>=15,"High streets contain 90+ buildings and 15+ food heaps")
	check(game.city.mesh_cache.size()<=40,"Repeated colored food uses at most 40 shared meshes")
	# Measure occupied ground across each city block, rather than relying on object count.
	for polygon in game.city.districts:
		var region:=Rect2(polygon[0],Vector2.ZERO)
		for point in polygon:region=region.expand(point)
		var ground_food:=[]
		for body in game.city.foods:
			if not body.has_meta("food_kind") or is_instance_valid(body.support_parent):continue
			if region.grow(3).has_point(Vector2(body.position.x,body.position.z)):ground_food.append(body)
		var occupied:=0;var total:=0
		for x in range(ceili(region.position.x),floori(region.end.x)):
			for z in range(ceili(region.position.y),floori(region.end.y)):
				var at:=Vector2(x+.5,z+.5)
				if not Geometry2D.is_point_in_polygon(at,polygon):continue
				if game.city.Neighborhoods.on_road(at,1.5):continue
				total+=1
				for body in ground_food:
					if absf(x+.5-body.position.x)<body.half_size.x and absf(z+.5-body.position.z)<body.half_size.z:
						occupied+=1;break
		var ratio:=float(occupied)/maxi(1,total)
		coverage.append({"origin":[region.position.x,region.position.y],"occupied_ratio":ratio})
		check(ratio>=.12,"Every district has edible ground coverage, including map edges: "+str(region.position))
	# Every upper piece has its own body and a close, real parent below it.
	var upper_count:=0
	for body in game.city.foods:
		if not body.has_meta("food_kind") or not is_instance_valid(body.support_parent):continue
		upper_count+=1
		var parent:Node3D=body.support_parent
		var gap:float=body.position.y-body.half_size.y-(parent.position.y+parent.half_size.y)
		check(body!=parent and parent.supported_food.has(body) and gap>=-.002 and gap<.06,"Independent tier has one matching support: "+body.name)
	check(upper_count>=700,"Vertical density comes from independent pieces, not fused scenery")
	# Index answers must match the exhaustive world, including a whole-map query.
	for i in 48:
		var at:=Vector3(-74+float((i*31)%148),0,-74+float((i*47)%148))
		var reach:float=[.85,3.5,12.0,24.0,256.0][i%5]
		var expected:Array=[]
		for body in game.city.foods:
			if is_instance_valid(body) and not body.consumed and Vector2(body.position.x-at.x,body.position.z-at.z).length_squared()<=reach*reach:expected.append(body.get_instance_id())
		var actual:Array=[]
		for body in game.city.query_foods(at,reach):actual.append(body.get_instance_id())
		expected.sort();actual.sort()
		check(expected==actual,"Spatial query matches the complete physical world: %d"%i)
	for i in 12:
		move_hole(Vector2(-70+i*12,-61+(i%4)*38),1)
		var expected:Node3D;var best:=INF
		for body in game.city.foods:
			if body.can_fit(game.player):
				var d:float=body.interaction_position().distance_squared_to(game.player.position)
				if d<best:best=d;expected=body
		var actual:Node3D=game.nearest_food(game.player)
		check(actual==expected,"Nearest edible query agrees with a full map search: %d"%i)
	var starter:Dictionary=game.city.piles.filter(func(p):return p.starter)[0]
	var first:Node3D=starter.roots[0]
	var upper:Node3D=first.supported_food[0]
	var initial_y:float=upper.position.y
	move_hole(Vector2(first.position.x,first.position.z),1);await frames(3,false)
	var saved_batch:MultiMesh=first.batch
	var saved_count:int=saved_batch.visible_instance_count
	var saved_bounds:AABB=saved_batch.custom_aabb
	var score:int=game.player.score;game.scan_food()
	check(saved_batch.visible_instance_count<saved_count and saved_batch.custom_aabb==saved_bounds,"Released pieces leave the active draw range while preserving conservative spatial bounds")
	check(not first.freeze and upper.freeze and game.player.score==score,"Only the contacted base starts falling; collection is not awarded on release")
	await frames(12)
	check(not is_instance_valid(upper) or (not upper.freeze and upper.food_visual.visible and upper.position.y<initial_y-.02),"Loss of support wakes the next separate tier after the base")
	await frames(300)
	var starter_receipts:=0
	for piece in starter.pieces:
		if not is_instance_valid(piece):starter_receipts+=1
	check(starter_receipts>=2,"A normal starting hole produces a real multi-piece cascade")
	# Traverse a big pyramid and one tower of each shape, in the actual dense world.
	var cases:Array[Dictionary]=[]
	var big:Dictionary=game.city.piles.filter(func(p):return not p.starter)[0]
	cases.append({"name":"59-piece pyramid","at":big.at,"pieces":big.pieces})
	for kind in ["cake","burger","pancake","donut"]:
		var tower:Dictionary=game.city.towers.filter(func(t):return t.kind==kind)[0]
		cases.append({"name":kind+" building","at":tower.at,"pieces":tower.tiers})
	for trial in cases:
		var tracked:Array=[]
		var initial:=0
		for piece in trial.pieces:
			if is_instance_valid(piece):tracked.append({"id":piece.name,"node":weakref(piece)});initial+=1
		move_hole(trial.at,6);await frames(3,false);game.scan_food()
		var tilted:=false
		for tick in 600:
			await frames(1)
			for record in tracked:
				var item=record.node.get_ref()
				if is_instance_valid(item) and item.global_basis.y.dot(Vector3.UP)<.98:tilted=true
			if tracked.all(func(r):return receipts.has(r.id)):break
		var eaten:=tracked.filter(func(r):return receipts.get(r.id,0)==1).size()
		check(eaten==initial,"Every piece physically collected once: "+trial.name)
		check(tilted,"The stack tips, instead of translating as one fused object: "+trial.name)
		collapse_results.append({"case":trial.name,"pieces":initial,"collected_once":eaten,"tilted":tilted})
	# Negative control: a narrow edible support under a wider piece. Losing the
	# parent must release physics even though the child fails the current size gate.
	var at:=Vector2(-73,64)
	var base:Node3D=game.city.food("cookie",at,.38,1)
	var wide:Node3D=game.city.food("cake",at,1.15,5)
	wide.position.y=base.position.y+base.half_size.y+wide.half_size.y+.015
	game.city.support(wide,base,1)
	var wide_start:float=wide.position.y
	move_hole(at,1);await frames(3,false);game.scan_food();await frames(90)
	check(is_instance_valid(wide) and not wide.freeze and not is_instance_valid(wide.support_parent) and wide.position.y<wide_start-.05,"Oversized upper food loses its support and physically settles onto the rim within 1.5 seconds")
	if is_instance_valid(wide):
		var id:String=wide.name
		move_hole(Vector2(wide.position.x,wide.position.z),4);await frames(360)
		check(receipts.get(id,0)==1,"A collapsed oversize piece remains edible after growing")
	check(receipts.values().all(func(n):return n==1),"No double collection during cascades")
	var result:={"checks":checks,"failures":failures,"initial_objects":count,"buildings":game.city.towers.size(),"piles":game.city.piles.size(),"supported_pieces":upper_count,"district_coverage":coverage,"cascades":collapse_results,"starter_collections":starter_receipts}
	print("FOOD_CITY_DENSITY_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
