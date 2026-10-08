extends "res://tests/growth_rivals_review.gd"
## Reuse the accepted rival-chain review; add inactive-without-successor cases.
var accepted_receipts:Array=[]
func uneaten()->Node3D:
	return game.city.foods.filter(func(body):return is_instance_valid(body) and not body.consumed and not body.get_meta("structural_shell",false))[0]
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.item_collected.connect(func(item:Node3D,hole:Node3D):accepted_receipts.append({"item":item.get_instance_id(),"owner":hole.get_instance_id()}))
	for map_name in ["city","food"]:
		game.selected_map=map_name;game.start_level();game.begin_play()
		game.city.set_process(false)
		if map_name=="food":game.city.rain_enabled=false
		clean()
		var player:=actor(0,1.2,Vector3.ZERO,10)
		var rival:=actor(1,.85,Vector3(65,0,65))
		var body:=uneaten();var points:int=body.points;var before:int=player.score;var eaten:int=game.eaten
		var receipt_count:=accepted_receipts.size();body.claimed_by=player;body.finish_swallow()
		check(player.active and player.score==before+points and game.eaten==eaten+1,map_name+": a legitimate active player's actual completion credits score and count")
		check(accepted_receipts.size()==receipt_count+1 and accepted_receipts.back().owner==player.get_instance_id(),map_name+": active completion emits a receipt attributed to the player")
		body=uneaten();points=body.points;before=player.score;eaten=game.eaten;receipt_count=accepted_receipts.size()
		var rival_before:int=rival.score;var rival_count:int=rival.collected
		body.claimed_by=rival;body.finish_swallow()
		check(rival.active and rival.collected==rival_count+1 and rival.score==rival_before+int(points*7/10),map_name+": active rival completion is accepted with actual fractional-growth policy")
		check(player.score==before and game.eaten==eaten+1 and accepted_receipts.size()==receipt_count+1 and accepted_receipts.back().owner==rival.get_instance_id(),map_name+": accepted rival receipt neither disappears nor credits the player")
		if map_name=="food":check(not game.city.collected_food.has(body.get_instance_id()),"Food: an accepted active-rival receipt does not consume the player's objective ledger")
		rival.active=false
		check(game.active_rival_owner(rival)==null,map_name+": inactive owner without a successor resolves to no scoring owner")
		body=uneaten();before=player.score;rival_before=rival.score;eaten=game.eaten;receipt_count=accepted_receipts.size()
		body.claimed_by=rival;body.finish_swallow()
		check(player.score==before and rival.score==rival_before and game.eaten==eaten,map_name+": inactive orphan completion cannot manufacture score or count")
		check(accepted_receipts.size()==receipt_count,map_name+": inactive orphan completion emits no accepted collection receipt")
		if map_name=="food":check(not game.city.collected_food.has(body.get_instance_id()),"Food: inactive orphan completion cannot advance player city objectives")
		# This inherited function is the exact existing, gate-accepted review of
		# two retirements, ownership transfer, real finish idempotency, late owner
		# resolution, and result-screen score rejection. No assertions are copied
		# or relaxed for this fixture correction.
		ownership_chain()
		body=uneaten();before=player.score;eaten=game.eaten;receipt_count=accepted_receipts.size()
		body.claimed_by=player;body.finish_swallow()
		check(game.phase=="complete" and player.score==before and game.eaten==eaten and accepted_receipts.size()==receipt_count,map_name+": actual result-screen completion cannot change score, count or accepted receipts")
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"scope":"Controlled actual completion and ownership accounting on both maps, reusing the existing growth/rivals ownership-chain review. Physical fall geometry is separately covered; no save, browser or performance claim."}
	print("OWNER_RECEIPT_REVIEW "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
