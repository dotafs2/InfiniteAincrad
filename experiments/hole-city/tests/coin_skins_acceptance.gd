extends SceneTree
## Acquisition, actual pointer input, migration, atomic persistence and settlement.
## All disk fixtures belong to this process in /tmp; the player save is untouched.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var paths:Array[String]=[]
var base:="/tmp/hole-city-coin-qa-%d"%OS.get_process_id()
const Game=preload("res://fidelity/game.gd")
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(count:=2)->void:
	for i in count:await process_frame
func target(id:String)->Button:
	for b in game.ui.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and (b.name==id or b.text==id):return b
	return null
func click(id:String)->void:
	var b:=target(id)
	check(b!=null,"Pointer target exists: "+id)
	if b==null:return
	var at:=b.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await frames()
func path(label:String)->String:
	var value:=base+"-"+label+".cfg"
	paths.append(value);paths.append(value+".tmp");paths.append(value+".pre-coins.cfg")
	return value
func restored(file:String)->Node3D:
	var result:=Game.new();result.test_progress_path=file
	check(result.load_player_progress(),"Progress file loads: "+file.get_file())
	return result
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	game.set_process(false)
	game.test_progress_path=path("live")
	check(game.coins==50 and game.owned_skin_ids==["cocoa_square"],"New player starts with 50 coins and one owned skin")
	game.note_skin_progress(420)
	check(not game.skin_unlocked("prism_vale"),"High scores do not bypass coin ownership")
	game.coins=100 # Isolated exact-price input fixture; starter allowance stays50.
	await click("holes-nav")
	check(target("unlock-random")!=null and game.skin_unlock_price("foundation")==100,"Unified collection retains the initial 100-coin action")
	await click("unlock-random")
	check(game.ui.menu_screen=="case" and game.ui.case_opening.stage=="ready","Collection action opens the ready case view")
	check(game.coins==100 and game.unlocked_skin_count("collection")==1 and game.pending_skin_case().is_empty(),"Navigating to the case never debits or grants a skin")
	await click("case-open")
	check(game.coins==0 and game.unlocked_skin_count("collection")==2,"Actual OPEN pointer buys exactly one new collection skin")
	var chosen:String=game.pending_skin_case().id
	var first_case:String=game.pending_skin_case().case_id
	check(game.selected_skin_id=="cocoa_square" and game.skin_unlocked(chosen),"New result is owned while the previous equipment remains selected")
	check(game.ui.case_opening.stage=="rolling" and game.ui.case_opening.receipt.id==chosen,"The visible rolling reel presents the committed reward")
	check(target("case-open")==null or target("case-open").disabled,"Rolling reveal has no second payable OPEN action")
	game.ui.case_opening.begin_open()
	check(game.coins==0 and game.pending_skin_case().case_id==first_case and game.unlocked_skin_count("collection")==2,"Rapid repeated opening cannot spend or grant twice")
	await click("case-skip")
	check(game.ui.case_opening.stage=="result" and game.ui.case_opening.receipt.id==chosen,"SKIP reveals the same already-paid result")
	await click("case-equip")
	check(game.selected_skin_id==chosen and game.coins==0,"Explicit result EQUIP selects the earned model without another charge")
	await click("case-continue")
	check(game.ui.case_opening.stage=="ready" and game.pending_skin_case().is_empty(),"CONTINUE acknowledges the result and exposes the next ready case")
	check(target("case-open").disabled,"Unaffordable OPEN is disabled before any new transaction")
	await click("case-open")
	check(game.coins==0 and game.unlocked_skin_count("collection")==2,"Insufficient funds leave ownership and balance unchanged")
	check(game.ui.case_opening.message=="Need 100 more coins","Case shortfall shows the fixed collection purchase deficit")
	var deficit:Dictionary=game.unlock_random_skin("collection")
	check(deficit.get("missing_coins")==100 and deficit.get("price")==100,"Unaffordable receipt contains exact current price and shortage")
	check(game.skin_unlock_price("collection")==100,"Unified collection keeps its disclosed price after an unlock")
	game.coins=500;game.last_unlock_msec=-1000;game.ui.refresh();await frames()
	await click("case-open")
	check(game.coins==400 and game.unlocked_skin_count("collection")==3,"Next unified purchase spends100coins and grants one unowned skin")
	var second_chosen:String=game.pending_skin_case().id
	check(second_chosen!=chosen and game.selected_skin_id==chosen,"A second case stays duplicate-free and does not silently replace equipment")
	var second_case:String=game.pending_skin_case().case_id
	await click("case-back")
	check(game.ui.menu_screen=="holes" and game.pending_skin_case().case_id==second_case,"Back to collection preserves the pending paid result")
	await click("unlock-random")
	check(game.ui.case_opening.stage=="result" and game.ui.case_opening.receipt.id==second_chosen and game.coins==400,"Reentry directly restores the same result without replay or another charge")
	await click("case-equip")
	chosen=second_chosen
	check(game.selected_skin_id==chosen and game.pending_skin_case().case_id==second_case,"Result EQUIP selects the new skin while presentation remains recoverable")
	await click("case-continue")
	await click("case-back")
	await click("holes-home")
	check(game.ui.menu_screen=="home" and game.selected_skin_id==chosen,"Collection HOME retains the purchased equipment")
	await click("PLAY")
	check(game.phase=="intro" and game.player.skin_id==chosen,"Home PLAY equips the purchased model in the actual round")
	game.begin_play();game.player.score=125
	game.finish("timeout")
	check(game.round_coins==12 and game.round_score_coins==12 and game.round_win_coins==0 and game.coins==412,"125 points award 12 coins")
	game.finish("timeout")
	check(game.coins==412,"Repeated finish does not pay twice")
	game.back_home();game.selected_map="food";game.start_level();game.begin_play()
	game.player.score=500;game.finish("complete")
	check(game.round_coins==50 and game.round_score_coins==50 and game.round_win_coins==0 and game.coins==462,"500 food points pay 50 score coins")
	var after_round:=restored(game.test_progress_path)
	check(after_round.coins==462 and after_round.selected_skin_id==chosen,"Round earnings and purchased equipment survive a cold restore")
	after_round.free()
	game.start_level();game.begin_play();game.player.score=0;game.finish("eaten")
	check(game.round_coins==0 and game.coins==462,"Empty defeats do not mint coins")
	game.start_level();game.begin_play();game.player.score=100;game.back_home()
	check(game.coins==462,"Leaving a round does not award a completion")
	check(not game.unlock_random_skin("unknown").ok and game.coins==462,"Unknown categories cannot spend coins")
	# Recheck shortage after a real settlement and a subsequent successful purchase.
	game.coins=0
	for group in ["foundation","resonance"]:
		deficit=game.unlock_random_skin(group)
		check(deficit.get("missing_coins")==game.skin_unlock_price(group) and deficit.message=="Need %d more coins"%game.skin_unlock_price(group),"Independent group price yields precise shortage: "+group)
	game.start_level();game.begin_play();game.player.score=1000;game.finish("timeout");game.back_home()
	check(game.coins==100 and game.round_score_coins==100 and game.round_win_coins==0,"1000 earned points fund exactly one draw")
	check(game.skin_unlock_price("foundation")==100 and game.coins==game.skin_unlock_price("foundation"),"Actual normal completion can afford the next draw after prior unlocks")
	game.last_unlock_msec=-1000
	check(game.unlock_random_skin("foundation").ok and game.coins==0,"Exact balance can buy the next skin")
	deficit=game.unlock_random_skin("foundation")
	check(deficit.get("price")==100 and deficit.get("missing_coins")==100,"Shortage keeps the fixed100-coin price after a successful unlock")
	game.ui.open_holes();game.ui.refresh();await frames()
	await click("unlock-random")
	check(game.coins==0 and game.ui.case_opening.stage=="ready","Reopening the case screen after another purchase remains free")
	check(target("case-open").disabled,"Updated wallet disables unaffordable OPEN")
	await click("case-open")
	check(game.ui.case_opening.message=="Need %d more coins"%game.skin_unlock_price("collection"),"Actual case UI reflects the updated post-purchase shortage")
	check(game.ui.font.get_string_size(game.ui.case_opening.message,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=378,"Exact case shortage notice fits portrait")
	await click("case-back")
	# Independent payout boundaries retain real settlement and durable balances;
	# whole coins follow the score with no floor, bonus or upper cap.
	for reward_case in [[0,0,0],[1,0,0],[9,0,0],[10,1,1],[19,1,1],[99,9,9],[100,10,10],[963,96,96],[999,99,99],[1000,100,100],[3099,309,309],[9100,910,910]]:
		game.start_level();game.begin_play();game.player.score=int(reward_case[0])
		var before_reward:int=game.coins
		game.finish("timeout")
		check(game.round_score_coins==int(reward_case[1]) and game.round_win_coins==0 and game.round_coins==int(reward_case[2]),"Actual settlement scales with %d points"%int(reward_case[0]))
		check(game.coins==before_reward+int(reward_case[2]),"Actual wallet receives exactly the earned reward at %d points"%int(reward_case[0]))
	game.back_home()

	# Purchase every remaining skin, cold-restore every transaction and ensure
	# the draw pool never returns a duplicate or crosses the selected category.
	var file:=path("owned")
	var owner:=Game.new();owner.test_progress_path=file
	owner.coins=owner.locked_skin_ids("collection").size()*100+500
	for group in ["foundation","resonance"]:
		var seen:=owner.owned_skin_ids.duplicate()
		while not owner.locked_skin_ids(group).is_empty():
			owner.last_unlock_msec=-1000 # Each iteration is a separate deliberate purchase.
			var before:int=owner.coins
			var cost:int=owner.skin_unlock_price(group)
			var receipt:Dictionary=owner.unlock_random_skin(group)
			check(receipt.ok,"Purchase succeeds in "+group)
			if not receipt.ok:break
			check(not seen.has(receipt.id),"Random unlock never grants an owned skin")
			seen.append(receipt.id)
			check(owner.skin_ids(group).has(receipt.id),"Random skin belongs to the active category")
			check(owner.coins==before-cost and receipt.price==cost,"Displayed price equals the exact deduction")
			var fresh:=restored(file)
			check(fresh.coins==owner.coins,"Cold restore retains the wallet after purchase")
			check(fresh.owned_skin_ids==owner.owned_skin_ids and fresh.selected_skin_id==receipt.id,"Cold restore retains ownership and selected skin together")
			fresh.free()
			var repeated:Dictionary=owner.unlock_random_skin(group)
			check(not repeated.ok and owner.coins==before-cost,"Rapid API retry cannot perform another transaction")
		var complete_coins:int=owner.coins
		check(not owner.unlock_random_skin(group).ok and owner.coins==complete_coins,"Completed collections never charge coins")
		check(owner.skin_unlock_price(group)==0,"Completed collection has no payable price")
	check(owner.owned_skin_ids.size()==200 and owner.coins==500,"Every catalog skin is acquired at100coins with500reserved for write-failure rollback")
	owner.phase="playing";owner.owned_skin_ids=["core_shell"]
	check(not owner.unlock_random_skin("foundation").ok,"Purchases cannot occur mid-round")
	owner.phase="title";owner.last_unlock_msec=-1000
	var before_failure:int=owner.coins
	owner.test_progress_path=base+"-missing/blocked.cfg"
	check(not owner.unlock_random_skin("foundation").ok,"Unwritable save rejects the purchase")
	check(owner.coins==before_failure and owner.owned_skin_ids==["core_shell"],"Failed write restores both coins and ownership")
	owner.free()
	# Legacy save migration must preserve unlocked forms, currencies, map,
	# selection and unrelated fields. Score progression after migration does
	# not silently grant locked forms again on the next restart.
	file=path("legacy")
	var cfg:=ConfigFile.new()
	for entry in [["coins",137],["gems",9],["stage",4],["skin_progress",240],["selected_skin_id","shard"],["map","food"]]:cfg.set_value("progress",entry[0],entry[1])
	# Genuine pre-world-gate play evidence preserves the selected Food map;
	# aggregate stage and a selected preview are intentionally insufficient.
	cfg.set_value("progress","best_scores",{"city":90,"food":240})
	cfg.set_value("unrelated","retain","sentinel")
	check(cfg.save(file)==OK,"Legacy fixture is written")
	var original:=FileAccess.get_sha256(file)
	owner=restored(file)
	check(owner.owned_skin_ids.size()==7 and owner.skin_unlocked("shard") and not owner.skin_unlocked("cinder"),"Migration retains every previously earned skin")
	check(owner.coins==137 and owner.gems==9 and owner.stage==4 and owner.selected_map=="food" and owner.selected_skin_id=="shard","Migration preserves wallet, map and equipment")
	check(owner.map_unlocked("food") and not owner.map_unlocked("toys") and owner.best_scores.food==240,"Legacy played-map evidence preserves access and its score without inventing later unlocks")
	check(FileAccess.get_sha256(file+".pre-coins.cfg")==original,"Original legacy save is retained byte-for-byte")
	owner.note_skin_progress(420);owner.save_player_progress();owner.free()
	owner=restored(file)
	check(owner.skin_progress==420 and not owner.skin_unlocked("prism_vale"),"Post-migration high scores cannot re-grant unowned skins")
	cfg.load(file)
	check(cfg.get_value("unrelated","retain")=="sentinel","Unrelated save sections survive updates")
	owner.free()
	# Invalid IDs and duplicates in a current-version save are not accepted.
	cfg.set_value("progress","owned_skin_ids",["tide","tide","missing_skin"])
	cfg.set_value("progress","selected_skin_id","missing_skin");cfg.save(file)
	owner=restored(file)
	check(owner.owned_skin_ids==["cocoa_square","tide"] and owner.selected_skin_id=="cocoa_square","Restore normalizes duplicate/unknown skin IDs and invalid equipment")
	owner.free()
	file=path("broken")
	var broken_file:=FileAccess.open(file,FileAccess.WRITE)
	check(broken_file!=null,"Corrupt-save fixture opens its process-owned file")
	if broken_file!=null:
		broken_file.store_string("[invalid")
		broken_file.flush()
		broken_file.close()
	check(FileAccess.get_file_as_string(file)=="[invalid","Corrupt-save fixture is flushed and readable before protection checks")
	owner=Game.new();owner.test_progress_path=file
	check(not owner.load_player_progress() and not owner.save_player_progress(),"Corrupt existing saves are not overwritten")
	check(FileAccess.get_file_as_string(file)=="[invalid","Invalid original data remains recoverable")
	owner.free()
	game.owned_skin_ids=game.skin_ids("foundation")+game.skin_ids("resonance");game.ui.open_holes();await frames()
	check(target("unlock-random").disabled,"Complete collection disables the purchase control")
	# Stop route updates before draining: a pending case-to-menu fade must not
	# create a new decoder during the teardown frame after music.stop().
	game.audio.set_process(false)
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.free();await frames()
	for owned_path in paths:
		if FileAccess.file_exists(owned_path):DirAccess.remove_absolute(owned_path)
	var result:={"checks":checks,"failures":failures,"save_scope":"isolated process-owned /tmp files","input":"actual viewport pointer routing"}
	print("COIN_SKINS_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
