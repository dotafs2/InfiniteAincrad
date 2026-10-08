extends SceneTree
## Unified draw/save compatibility. Every file belongs to this test process.
const Game=preload("res://fidelity/game.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
var checks:=0
var failures:Array[String]=[]
var files:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func path(label:String)->String:
	var value:="/tmp/hole-unified-collection-%d-%s.cfg"%[OS.get_process_id(),label]
	files.append(value);files.append(value+".tmp")
	return value
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:=Game.new();game.test_progress_path=path("legacy")
	game.coins=10000;game.gems=123;game.stage=7;game.selected_map="food"
	# This current-schema snapshot belongs to an existing Food-map owner;
	# selecting a thumbnail alone no longer proves that entitlement.
	game.unlocked_map_ids=["city","food"]
	game.owned_skin_ids.append("music_stage");game.selected_skin_id="music_stage"
	game.draw_pity={"foundation":{"epic":4,"legendary":3,"prismatic":12},"resonance":{"epic":1,"legendary":9,"prismatic":18}}
	var legacy:=game.draw_pity.duplicate(true)
	check(game.save_player_progress(),"Existing split-pool progress fixture saves")
	var cold:=Game.new();cold.test_progress_path=game.test_progress_path
	check(cold.load_player_progress(),"Existing split-pool save loads without reset")
	check(cold.coins==10000 and cold.gems==123 and cold.stage==7 and cold.selected_map=="food","Wallet, stage and map survive unification")
	check(cold.map_unlocked("food") and not cold.map_unlocked("toys") and not cold.map_unlocked("frost"),"Existing Food access survives without granting unplayed later worlds")
	check(cold.selected_skin_id=="music_stage" and cold.skin_unlocked("music_stage"),"Former Special equipment and entitlement survive")
	check(cold.draw_pity==legacy and not cold.draw_pity.has("collection"),"Reading legacy progress preserves both original counters")
	var offer:Dictionary=cold.skin_draw_offer("collection")
	check(offer.counters=={"epic":4,"legendary":9,"prismatic":18},"Each unified tier inherits the stronger existing guarantee")
	check(offer.guarantee=="legendary","Inherited Legendary countdown controls the next actual offer")
	var eligible:Array[String]=[]
	var total:=0.0
	for entry in offer.entries:
		eligible.append_array(entry.ids);total+=float(entry.chance)
		check(entry.ids.all(func(id):return not cold.skin_unlocked(id)),"Unified disclosed pools exclude owned forms: "+entry.rarity)
		check(float(entry.chance)==0 if Rarity.index_of(entry.rarity)<4 else float(entry.chance)>0,"Inherited guarantee removes lower-tier probability: "+entry.rarity)
	check(absf(total-1)<.000001 and eligible.size()==198,"Unified odds normalize across every remaining form")
	check(cold.draw_pity==legacy,"Odds inspection never consumes or writes guarantee progress")
	check(not cold.unlock_random_skin("unknown").ok,"Unknown pools cannot spend coins")
	cold.last_unlock_msec=-1000
	var receipt:Dictionary=cold.unlock_random_skin("collection")
	check(receipt.ok and Rarity.index_of(receipt.rarity)>=4,"First unified purchase honors the inherited guarantee")
	check(cold.draw_pity.foundation==legacy.foundation and cold.draw_pity.resonance==legacy.resonance,"Unified purchases retain legacy counter records")
	var restored:=Game.new();restored.test_progress_path=cold.test_progress_path
	check(restored.load_player_progress() and restored.draw_pity==cold.draw_pity,"Shared counters survive cold restore without re-inheriting stale progress")
	restored.free();cold.free();game.free()
	game=Game.new();game.test_progress_path=path("complete");game.coins=30000
	var seen:Array[String]=game.owned_skin_ids.duplicate()
	check(game.skin_unlock_price("collection")==100,"One collection begins at the disclosed 100-coin price")
	for index in 199:
		game.last_unlock_msec=-1000
		var cost:=100
		var previous:int=game.coins
		check(game.skin_unlock_price("collection")==cost,"The price stays100coins before draw %d"%index)
		receipt=game.unlock_random_skin("collection")
		check(receipt.ok,"Unified draw succeeds %d"%index)
		if not receipt.ok:break
		check(not seen.has(receipt.id),"No duplicate entitlement %d"%index);seen.append(receipt.id)
		check(game.coins==previous-cost and receipt.price==cost,"Exact disclosed deduction %d"%index)
		check(game.selected_skin_id==receipt.id and game.skin_unlocked(receipt.id),"Award and equipment commit together %d"%index)
		restored=Game.new();restored.test_progress_path=game.test_progress_path
		check(restored.load_player_progress(),"Cold restore succeeds after unified purchase %d"%index)
		check(restored.coins==game.coins and restored.owned_skin_ids==game.owned_skin_ids and restored.draw_pity==game.draw_pity,"Wallet, all entitlements and shared guarantees persist atomically %d"%index)
		restored.free()
		var balance:int=game.coins
		check(not game.unlock_random_skin("collection").ok and game.coins==balance,"Rapid retry cannot charge or grant again %d"%index)
	check(seen.size()==200 and game.SKIN_DEFS.all(func(d):return seen.count(d.id)==1),"Both former groups are collectible exactly once in one pool")
	check(game.skin_unlock_price("collection")==0 and game.locked_skin_ids("collection").is_empty(),"Complete unified collection has no payable offer")
	game.free()
	# Ownership is stored by stable ID, not tier. Existing weather-skin owners
	# retain their equipment, wallet and unfinished guarantees after promotion.
	for equipped_id in ["tempest","rainfall"]:
		game=Game.new();game.test_progress_path=path("weather-"+equipped_id)
		game.owned_skin_ids.append_array(["tempest","rainfall"])
		game.selected_skin_id=equipped_id;game.coins=237;game.gems=19;game.stage=11
		game.selected_map="food"
		# Weather-skin ownership and already-earned Food access are separate
		# current-profile entitlements; neither implies all worlds are open.
		game.unlocked_map_ids=["city","food"]
		game.draw_pity.collection={"epic":4,"legendary":9,"prismatic":19}
		check(game.save_player_progress(),"Existing weather-skin ownership fixture saves: "+equipped_id)
		var before_load:=FileAccess.get_file_as_bytes(game.test_progress_path)
		restored=Game.new();restored.test_progress_path=game.test_progress_path
		check(restored.load_player_progress(),"Promoted weather-skin save cold-loads: "+equipped_id)
		check(restored.owned_skin_ids==game.owned_skin_ids and restored.selected_skin_id==equipped_id,"Stable weather IDs retain ownership and equipment without replacement: "+equipped_id)
		check(restored.coins==237 and restored.gems==19 and restored.stage==11 and restored.selected_map=="food","Promotion cannot charge, grant currency or reset progress: "+equipped_id)
		check(restored.unlocked_map_ids==["city","food"],"Skin promotion retains only previously earned map access: "+equipped_id)
		check(restored.draw_pity==game.draw_pity,"All unfinished guarantees survive promotion: "+equipped_id)
		offer=restored.skin_draw_offer("collection")
		check(offer.guarantee=="prismatic" and offer.entries.back().ids.size()==6 and not offer.entries.back().ids.has("tempest") and not offer.entries.back().ids.has("rainfall"),"Highest-tier guarantee excludes both already-owned weather skins: "+equipped_id)
		check(restored.skin_unlock_price("collection")==100,"Promotion retains the existing draw charge: "+equipped_id)
		check(FileAccess.get_file_as_bytes(game.test_progress_path)==before_load,"Cold-load and offer inspection do not rewrite the saved file: "+equipped_id)
		restored.free();game.free()
	# The six reworked Common forms keep their saved identities. A completed
	# previous 60-skin collection must not silently receive the 140 additions.
	for equipped_id in ["cookie_bite","citrus_slice","melon_munch","pancake_stack","bacon_curl","cocoa_square"]:
		game=Game.new();game.test_progress_path=path("common-"+equipped_id)
		for definition in game.SKIN_DEFS.slice(0,60):
			if not game.owned_skin_ids.has(definition.id):game.owned_skin_ids.append(definition.id)
		game.selected_skin_id=equipped_id;game.coins=237;game.gems=19;game.stage=11
		game.draw_pity.collection={"epic":4,"legendary":9,"prismatic":19}
		check(game.save_player_progress(),"Original Common ownership fixture saves: "+equipped_id)
		var before_load:=FileAccess.get_file_as_bytes(game.test_progress_path)
		restored=Game.new();restored.test_progress_path=game.test_progress_path
		check(restored.load_player_progress(),"Reworked Common selection cold-loads: "+equipped_id)
		check(restored.owned_skin_ids==game.owned_skin_ids and restored.selected_skin_id==equipped_id,"Reworked Common retains all sixty old entitlements and selection: "+equipped_id)
		check(restored.locked_skin_ids("collection").size()==140 and restored.locked_skin_ids("collection").all(func(id):return game.SKIN_DEFS.slice(60).any(func(d):return d.id==id)),"Only 140 actual new base/variant forms remain locked: "+equipped_id)
		check(restored.coins==237 and restored.gems==19 and restored.stage==11 and restored.draw_pity==game.draw_pity,"Common rework preserves wallet, progress and pending guarantees: "+equipped_id)
		check(restored.skin_unlock_price("collection")==100,"Common expansion keeps the existing draw price: "+equipped_id)
		check(FileAccess.get_file_as_bytes(game.test_progress_path)==before_load,"Common migration inspection never rewrites the save: "+equipped_id)
		restored.free();game.free()
	game=Game.new();game.coins=500;game.test_progress_path=path("missing")+"/unwritable.cfg"
	game.draw_pity.foundation={"epic":4,"legendary":9,"prismatic":19}
	legacy=game.draw_pity.duplicate(true)
	check(not game.unlock_random_skin("collection").ok,"Failed persistence rejects a unified draw")
	check(game.coins==500 and game.owned_skin_ids==[Rarity.NEW_PLAYER_SKIN] and game.draw_pity==legacy and not game.draw_pity.has("collection"),"Failed write rolls back coins, entitlement and inherited/shared counters")
	game.free()
	for file in files:
		if FileAccess.file_exists(file):DirAccess.remove_absolute(file)
	var result:={"checks":checks,"failures":failures,"scope":"Isolated legacy migration, all 199 unified purchases, exact charges, weather-skin promotion cold restores and write rollback"}
	print("SKIN_COLLECTION_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
