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
	for b in game.ui.buttons:
		if b.name==id or b.text==id:return b
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
	check(game.coins==50 and game.owned_skin_ids==["core_shell"],"New player starts with 50 coins and one owned skin")
	game.note_skin_progress(420)
	check(not game.skin_unlocked("prism_vale"),"High scores do not bypass coin ownership")
	await click("holes-nav")
	check(target("unlock-random")!=null and game.skin_unlock_price("foundation")==50,"Classic collection has the initial 50-coin action")
	await click("unlock-random")
	check(game.coins==0 and game.unlocked_skin_count("foundation")==2,"Actual pointer buys exactly one new Classic skin")
	check(game.selected_skin_id!="core_shell" and game.skin_unlocked(game.selected_skin_id),"New skin is automatically selected")
	check(game.ui.preview_skin_id==game.selected_skin_id and game.ui.toast.contains("UNLOCKED"),"Purchase highlights the new card and announces it")
	check(target("unlock-random").disabled,"Reveal blocks queued repeat pointer taps")
	var chosen:String=game.selected_skin_id
	game.ui.request_unlock()
	check(game.coins==0 and game.selected_skin_id==chosen,"Rapid repeated UI action cannot spend twice")
	game.ui._process(1.1);await frames()
	await click("unlock-random")
	check(game.coins==0 and game.unlocked_skin_count("foundation")==2,"Insufficient funds leave ownership and balance unchanged")
	check(game.ui.toast=="Need 70 more coins","Insufficient toast shows exact next Classic purchase deficit")
	check(game.ui.COIN_EARNING_RULE=="Coins: score / 10 (round down) +20 for a win","Persistent earning rule states rounding and actual completion bonus")
	check(game.ui.font.get_string_size(game.ui.COIN_EARNING_RULE,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x<=400,"Earning rule fits the narrowest result panel")
	var deficit:Dictionary=game.unlock_random_skin("foundation")
	check(deficit.get("missing_coins")==70 and deficit.get("price")==70,"Unaffordable receipt contains exact current price and shortage")
	await click("holes-special-tab")
	check(game.skin_unlock_price("resonance")==50,"Special tab has its own coin pool")
	game.coins=500;game.last_unlock_msec=-1000;game.ui.refresh();await frames()
	await click("unlock-random")
	check(game.coins==450 and game.unlocked_skin_count("resonance")==1,"Special purchase spends coins and grants one Special skin")
	chosen=game.selected_skin_id
	await click("PLAY")
	check(game.phase=="intro" and game.player.skin_id==chosen,"Library PLAY equips the purchased model in the actual round")
	game.begin_play();game.player.score=125
	game.finish("timeout")
	check(game.round_coins==12 and game.coins==462,"City settlement pays one coin per ten actual points")
	game.finish("timeout")
	check(game.coins==462,"Repeated finish does not pay twice")
	game.back_home();game.selected_map="food";game.start_level();game.begin_play()
	game.player.score=500;game.finish("complete")
	check(game.round_coins==70 and game.coins==532,"Food completion pays score coins plus the 20-coin win bonus")
	var after_round:=restored(game.test_progress_path)
	check(after_round.coins==532 and after_round.selected_skin_id==chosen,"Round earnings and purchased equipment survive a cold restore")
	after_round.free()
	game.start_level();game.begin_play();game.player.score=0;game.finish("eaten")
	check(game.round_coins==0 and game.coins==532,"Empty defeats do not mint coins")
	game.start_level();game.begin_play();game.player.score=100;game.back_home()
	check(game.coins==532,"Leaving a round does not award a completion")
	check(not game.unlock_random_skin("unknown").ok and game.coins==532,"Unknown categories cannot spend coins")
	# Recheck shortage after a real settlement and a subsequent successful purchase.
	game.coins=0
	for group in ["foundation","resonance"]:
		deficit=game.unlock_random_skin(group)
		check(deficit.get("missing_coins")==70 and deficit.message=="Need 70 more coins","Independent group price yields precise shortage: "+group)
	game.start_level();game.begin_play();game.player.score=95;game.finish("timeout");game.back_home()
	check(game.coins==9,"Nonmultiple score settlement floors before updating shortage")
	deficit=game.unlock_random_skin("foundation")
	check(deficit.get("missing_coins")==61 and deficit.message=="Need 61 more coins","Exact shortage refreshes after actual round earnings")
	game.coins+=61 # Fund exactly this fixture's next deliberate purchase.
	game.last_unlock_msec=-1000
	check(game.unlock_random_skin("foundation").ok and game.coins==0,"Exact balance can buy the next skin")
	deficit=game.unlock_random_skin("foundation")
	check(deficit.get("price")==90 and deficit.get("missing_coins")==90,"Shortage uses increased next price after a successful unlock")
	game.ui.open_holes();game.ui.holes_tab="classic";game.ui.unlock_feedback_time=0;game.ui.refresh();await frames()
	await click("unlock-random")
	check(game.ui.toast=="Need 90 more coins","Actual UI reflects the updated post-purchase shortage")
	check(game.ui.font.get_string_size(game.ui.toast,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=378,"Exact shortage toast fits portrait")
	# Purchase every remaining skin, cold-restore every transaction and ensure
	# the draw pool never returns a duplicate or crosses the selected category.
	var file:=path("owned")
	var owner:=Game.new();owner.test_progress_path=file;owner.coins=10000
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
	cfg.set_value("unrelated","retain","sentinel")
	check(cfg.save(file)==OK,"Legacy fixture is written")
	var original:=FileAccess.get_sha256(file)
	owner=restored(file)
	check(owner.owned_skin_ids.size()==6 and owner.skin_unlocked("shard") and not owner.skin_unlocked("cinder"),"Migration retains every previously earned skin")
	check(owner.coins==137 and owner.gems==9 and owner.stage==4 and owner.selected_map=="food" and owner.selected_skin_id=="shard","Migration preserves wallet, map and equipment")
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
	check(owner.owned_skin_ids==["core_shell","tide"] and owner.selected_skin_id=="core_shell","Restore normalizes duplicate/unknown skin IDs and invalid equipment")
	owner.free()
	file=path("broken");FileAccess.open(file,FileAccess.WRITE).store_string("[invalid")
	owner=Game.new();owner.test_progress_path=file
	check(not owner.load_player_progress() and not owner.save_player_progress(),"Corrupt existing saves are not overwritten")
	check(FileAccess.get_file_as_string(file)=="[invalid","Invalid original data remains recoverable")
	owner.free()
	game.owned_skin_ids=game.skin_ids("foundation")+game.skin_ids("resonance");game.ui.open_holes();await frames()
	check(target("unlock-random").disabled,"Complete collection disables the purchase control")
	# Release the streamed music decoder on its audio thread before freeing the game.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.free();await frames()
	for owned_path in paths:
		if FileAccess.file_exists(owned_path):DirAccess.remove_absolute(owned_path)
	var result:={"checks":checks,"failures":failures,"save_scope":"isolated process-owned /tmp files","input":"actual viewport pointer routing"}
	print("COIN_SKINS_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
