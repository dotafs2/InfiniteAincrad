extends SceneTree
var checks:=0
var failures:Array[String]=[]
const Game=preload("res://fidelity/game.gd")
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var path:="/tmp/hole-store-qa-%d.cfg"%OS.get_process_id()
	var owner:=Game.new();owner.test_progress_path=path
	check(owner.coins==50 and owner.gems==10,"A fresh wallet starts with the modest starter allowance")
	check(not owner.claim_shop_gift().ok and owner.gems==10,"Opening the store cannot manufacture a free stage gift without an earned video")
	owner.gems=110
	check(owner.buy_coin_pack(0).ok and owner.gems==10 and owner.coins==2050,"The100-diamond exchange transfers exactly2000coins")
	check(not owner.buy_coin_pack(0).ok and owner.gems==10 and owner.coins==2050,"Insufficient diamonds and fast repeat input never charge")
	var fresh:=Game.new();fresh.test_progress_path=path
	check(fresh.load_player_progress() and fresh.coins==2050 and fresh.gems==10,"Cold restore retains both wallet currencies")
	check(not fresh.claim_shop_gift().ok and fresh.gems==10,"Restart does not invent a video reward")
	fresh.stage+=1
	check(not fresh.claim_shop_gift().ok and fresh.gems==10,"A completed stage does not bypass the rewarded SDK callback")
	for index in [1,2]:
		fresh.last_shop_msec=-1000;fresh.gems=1000
		var before:int=fresh.coins
		check(fresh.buy_coin_pack(index).ok,"Remaining advertised pack can be bought")
		check(fresh.coins==before+int(Game.COIN_PACKS[index].coins) and fresh.gems==1000-int(Game.COIN_PACKS[index].gems),"Each advertised coin/diamond amount is exact")
		check(not fresh.buy_coin_pack(index).ok,"Fast duplicate input is rejected")
	fresh.phase="playing";var before:int=fresh.coins
	check(not fresh.buy_coin_pack(0).ok and not fresh.claim_shop_gift().ok and fresh.coins==before,"Store actions are rejected during play")
	fresh.phase="title"
	check(not fresh.buy_coin_pack(-1).ok and not fresh.buy_coin_pack(99).ok,"Unknown offers cannot alter wallets")
	fresh.test_progress_path=path+"/missing/save.cfg";fresh.last_shop_msec=-1000;fresh.gems=100;fresh.stage=7
	before=fresh.coins
	check(not fresh.buy_coin_pack(0).ok and fresh.coins==before and fresh.gems==100,"Save failure restores both sides of a pack transaction")
	var claimed:int=fresh.shop_gift_claimed_stage
	check(not fresh.claim_shop_gift().ok and fresh.gems==100 and fresh.shop_gift_claimed_stage==claimed,"Save failure restores gift eligibility")
	owner.free();fresh.free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	var result:={"checks":checks,"failures":failures}
	print("STORE_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
