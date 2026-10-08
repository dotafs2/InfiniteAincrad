extends SceneTree
## Independent receipt and goal integration review. Calling finish_swallow here
## isolates receipt accounting; full physical falls are covered separately.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func receipt(body:Node3D,hole:Node3D)->void:
	body.claimed_by=hole
	body.finish_swallow()
func tick()->void:
	game.scan=999.0
	game._physics_process(.01)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.active=false;h.set_physics_process(false)
	# Receipt accounting requires living owners. Movement remains disabled;
	# the rival stays far away so manual goal ticks cannot start a combat event.
	game.player.active=true
	game.holes[1].active=true;game.holes[1].position=Vector3(-65,0,-65)
	game.reset_rival_state()
	check(game.player.active and game.active_rival_owner(game.player)==game.player,"Player receipt fixture has a living authoritative owner")
	check(game.holes[1].active and game.active_rival_owner(game.holes[1])==game.holes[1],"Enemy receipt fixture has a living authoritative owner")
	game.player.radius=8.0
	var city=game.city
	check(game.ui.font.get_string_size("CITY 12/12 · LANDMARK 1/1 · HEAP 1/1",HORIZONTAL_ALIGNMENT_LEFT,-1,17).x<=476,"Actual maximum goal receipt text fits the food HUD panel")
	check(game.ui.font.get_string_size("Eat 12 buildings, a landmark and a heap!",HORIZONTAL_ALIGNMENT_LEFT,-1,19).x<=500,"New city-objective tutorial fits the portrait viewport")
	var ordinary:Array=[];var landmarks:Array=[];var heaps:Array=[];var starters:Array=[]
	for t in city.towers:
		if t.role=="landmark":landmarks.append(t)
		else:ordinary.append(t)
	for p in city.piles:
		if p.starter:starters.append(p)
		else:heaps.append(p)
	check(ordinary.size()>=11 and not landmarks.is_empty() and not heaps.is_empty(),"Scene contains enough independently edible objective structures")
	check(not game.food_city_goal_complete() and not game.food_goal_complete(),"Fresh food round has incomplete physical city goals")
	var guide:Node3D=city.objective_target(game.player)
	check(is_instance_valid(guide) and guide.can_fit(game.player) and not guide.consumed,"Initial guide returns an actual fitting uneaten objective part")
	guide.claimed_by=game.holes[1]
	check(city.objective_target(game.player)!=guide,"Guide excludes a rival-owned part")
	guide.claimed_by=null
	game.food_guide_clock=0;game._process(.01)
	check(is_instance_valid(game.food_guide) and is_equal_approx(game.food_guide_clock,1.0),"Game samples the city guide at one-second cadence")
	var same_guide=game.food_guide;game._process(.40)
	check(game.food_guide==same_guide and absf(game.food_guide_clock-.60)<.00001,"Intermediate frames retain the guide instead of rescanning")
	game._process(.61)
	check(is_equal_approx(game.food_guide_clock,1.0),"Guide rescans when its one-second interval expires")
	var first:Dictionary=ordinary[0]
	var limit:=ceili(first.tiers.size()*.6)
	var rival_piece:Node3D=first.tiers[-1]
	receipt(rival_piece,game.holes[1])
	check(city.collection_progress.buildings==0 and not city.collected_food.has(rival_piece.get_instance_id()),"Rival collection cannot advance or occupy player receipt ledger")
	for i in limit-1:receipt(first.tiers[i],game.player)
	check(city.collection_progress.buildings==0,"Partial building below sixty percent is not a completed city goal")
	var before_score:int=game.player.score;var before_count:int=game.eaten
	first.tiers[0].finish_swallow()
	city.record_collection(first.tiers[0],game.player)
	check(game.player.score==before_score and game.eaten==before_count and city.building_collections[first.tiers[0].get_meta("tower_id")]==limit-1,"Repeated physical finish and repeated city receipt cannot duplicate score or progress")
	receipt(first.tiers[limit-1],game.player)
	check(city.collection_progress.buildings==1,"Crossing the sixty-percent threshold increments the building count once")
	for i in range(limit,first.tiers.size()-1):receipt(first.tiers[i],game.player)
	check(city.collection_progress.buildings==1,"Later receipts from the same building do not increment it again")
	for index in range(1,11):
		var tower:Dictionary=ordinary[index]
		for i in ceili(tower.tiers.size()*.6):receipt(tower.tiers[i],game.player)
	check(city.collection_progress.buildings==11 and city.collection_progress.landmarks==0,"Eleven ordinary structures do not substitute for the landmark objective")
	for piece in starters[0].pieces:receipt(piece,game.player)
	check(city.collection_progress.heaps==0,"Eating an entire starter pile does not fake the large-heap goal")
	var heap:Dictionary=heaps[0];limit=ceili(heap.pieces.size()*.6)
	for i in limit-1:receipt(heap.pieces[i],game.player)
	check(city.collection_progress.heaps==0,"Large heap requires sixty percent actual player receipts")
	receipt(heap.pieces[limit-1],game.player)
	check(city.collection_progress.heaps==1,"Large heap advances on its threshold receipt")
	city.record_collection(heap.pieces[limit-1],game.player)
	check(city.collection_progress.heaps==1,"Repeated heap receipt stays deduplicated")
	var landmark:Dictionary=landmarks[0];limit=ceili(landmark.tiers.size()*.6)
	for i in limit-1:receipt(landmark.tiers[i],game.player)
	check(city.collection_progress.buildings==11 and city.collection_progress.landmarks==0,"Partially collapsed landmark has not been counted as eaten")
	receipt(landmark.tiers[limit-1],game.player)
	check(city.collection_progress.buildings==12 and city.collection_progress.landmarks==1 and game.food_city_goal_complete(),"Landmark completion satisfies both the twelfth building and distinct landmark goal")
	check(city.objective_target(game.player)==null,"Guide stops requesting city objects after all city objectives are met")
	game.food_guide_clock=0;game._process(.01)
	check(game.food_guide==null,"HUD guide clears on the next scheduled update once goals complete")
	game.food_collected={"egg":10,"donut":4,"cake":1}
	check(game.ui.food_order_counts()==[10,4,1],"Displayed food-order receipt counts agree with goal gates")
	game.player.score=499;tick()
	check(game.phase=="playing","Complete food and city goals cannot end the timed run below the old milestone")
	game.player.score=500
	for key in ["buildings","landmarks","heaps"]:
		var value:int=city.collection_progress[key];city.collection_progress[key]=value-1;tick()
		check(game.phase=="playing","Crossing the old score milestone cannot finish the timer with missing "+key)
		city.collection_progress[key]=value
	for key in ["egg","donut","cake"]:
		var value:int=game.food_collected[key];game.food_collected[key]=value-1;tick()
		check(game.phase=="playing","Crossing the old score milestone cannot finish the timer with missing food "+key)
		game.food_collected[key]=value
	tick()
	check(game.phase=="playing" and game.stage==1 and game.round_coins==0,"All score and optional food objectives leave the timed run active")
	game.remaining=.005;tick()
	check(game.phase=="complete" and game.stage==2 and game.round_coins==50 and game.round_score_coins==50 and game.round_win_coins==0,"Timer expiry settles once through the real game tick")
	before_score=game.player.score;var final_progress:Dictionary=city.collection_progress.duplicate(true)
	receipt(ordinary[11].tiers[0],game.player)
	check(game.player.score==before_score and city.collection_progress==final_progress,"Late result-screen physical receipts cannot alter settled score or city goals")
	game.back_home();game.start_level()
	check(game.food_collected.is_empty() and game.food_city_progress()=={"buildings":0,"landmarks":0,"heaps":0} and game.food_guide==null,"Fresh round resets receipts, goals and the cached guide")
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"scope":"Independent actual receipt path and gate/guide review; physical playability is a separate test"}
	print("FOOD_GOALS_REVIEW "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
