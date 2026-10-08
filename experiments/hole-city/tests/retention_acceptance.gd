extends SceneTree
## Real timed rounds plus durable, receipt-bound cosmetic economy.
const Game=preload("res://fidelity/game.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
const Commerce=preload("res://fidelity/commerce_bridge.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const SMALL:="sink_city.coins_320"
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var paths:Array[String]=[]
var base:="/tmp/hole-city-retention-%d"%OS.get_process_id()

class Video extends RefCounted:
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	var requests:Array[String]=[]
	func sink_city_rewarded_protocol_version()->int:return 1
	func initialize()->void:pass
	func rewarded_available()->bool:return true
	func show_rewarded(id:String)->bool:requests.append(id);return true

class Store extends RefCounted:
	signal products_received(products:Array)
	signal purchase_verified(transaction_id:String,product_id:String,request_id:String)
	signal purchase_failed(request_id:String,message:String)
	signal purchase_pending(request_id:String)
	signal availability_changed
	var requests:Array=[]
	var acknowledgments:Array[String]=[]
	func sink_city_commerce_protocol_version()->int:return 1
	func initialize()->void:pass
	func purchases_available()->bool:return true
	func request_products(_ids:PackedStringArray)->void:products_received.emit([{"product_id":"sink_city.coins_320","localized_price":"TEST PRICE"}])
	func purchase(product:String,id:String)->bool:requests.append([product,id]);return true
	func acknowledge(id:String)->bool:acknowledgments.append(id);return true

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for i in count:await process_frame
func file(label:String)->String:
	var p:=base+"-"+label+".cfg";paths.append(p);paths.append(p+".tmp");paths.append(p+".pre-coins.cfg");return p
func restored(path:String)->Node3D:
	var state:=Game.new();state.test_progress_path=path
	check(state.load_player_progress(),"Isolated save restores")
	return state
func quiet_world()->void:
	game.city.process_mode=Node.PROCESS_MODE_DISABLED
	for h in game.holes:
		h.enabled=false
		if h!=game.player:h.retire()
	if game.selected_map=="food":game.city.rain_enabled=false

func round_tests()->void:
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level();game.begin_play();quiet_world()
		game.player.award(2700)
		if map_id=="food":
			game.food_collected={"egg":10,"donut":4,"cake":1}
			game.city.collection_progress={"buildings":40,"landmarks":3,"heaps":5}
		game._physics_process(.01)
		check(game.phase=="playing" and game.player.score>=2700,map_id+": high score and all food milestones never end the round")
		check(game.remaining>game.round_duration()-1 and game.remaining<=game.round_duration(),map_id+": starts with its configured full duration")
		var wallet:int=game.coins
		var score:int=game.player.score
		game.remaining=.01;game._physics_process(.02)
		check(game.phase=="complete" and game.remaining==0.0,map_id+": timer alone settles the run")
		check(game.round_coins==score/10 and game.round_score_coins==score/10 and game.coins==wallet+score/10,map_id+": completed round pays one coin per ten earned points")
		check(game.round_receipt.base_coins==game.round_coins and not game.round_receipt.doubled,map_id+": original round reward is immutable receipt basis")
		wallet=game.coins;game.finish("complete");game._physics_process(1)
		check(game.coins==wallet,map_id+": repeat finish never credits twice")
	game.start_level();game.begin_play();quiet_world()
	game.elapsed=12;game.player.award(30)
	var victim:Node3D=game.player
	var predator:Node3D=game.holes[1]
	predator.active=true;predator.radius=game.player.radius*1.6;predator.position=game.player.position
	game.reset_rival_state();game.scan_rivals()
	check(not victim.active and game.phase=="playing" and game.player_respawn_time==2,"Being eaten schedules a respawn without settling")
	var score:int=victim.score;var wallet:int=game.coins;var remaining:float=game.remaining
	game._physics_process(2.01)
	check(game.player!=victim and game.player.active and game.player.score==score,"Respawn replaces the swallowed player and retains earned score")
	check(game.coins==wallet and game.remaining<remaining and game.round_receipt.is_empty(),"Respawn consumes time without paying an early round")
	check(game.player_protected_until>game.elapsed and not game.rival_size_allows(predator,game.player),"Respawn grants renewed protection")
	await frames()
	check(not is_instance_valid(victim) and game.holes.size()==8,"Retired body is cleaned without accumulating holes")
	game.back_home();await frames()

func collection_tests()->void:
	var wallet:=Game.new();wallet.test_progress_path=file("collection");wallet.coins=1000
	check(wallet.owned_skin_ids==[Rarity.NEW_PLAYER_SKIN] and Rarity.for_skin(wallet.selected_skin_id)=="common","Fresh account receives the simple gray starter")
	wallet.draw_pity.foundation={"epic":4,"legendary":0,"prismatic":0}
	var offered:Dictionary=wallet.skin_draw_offer("foundation")
	check(offered.guarantee=="epic","Next draw discloses its due Epic guarantee")
	var result:Dictionary=wallet.unlock_random_skin("foundation")
	check(result.ok and Rarity.index_of(result.rarity)>=3 and wallet.draw_pity.foundation.epic==0,"A real paid draw honors the guarantee and resets it")
	var loaded:=restored(wallet.test_progress_path)
	check(loaded.coins==wallet.coins and loaded.owned_skin_ids==wallet.owned_skin_ids and loaded.draw_pity==wallet.draw_pity,"Ownership, debit and all pity counters commit together")
	loaded.free()
	var old_owned:Array=wallet.owned_skin_ids.duplicate();var old_pity:Dictionary=wallet.draw_pity.duplicate(true);var old_coins:int=wallet.coins
	wallet.test_progress_path=base+"-missing/save.cfg";wallet.last_unlock_msec=-1000
	result=wallet.unlock_random_skin("foundation")
	check(not result.ok and wallet.owned_skin_ids==old_owned and wallet.coins==old_coins and wallet.draw_pity==old_pity,"Failed atomic save rolls back draw, wallet and pity")
	wallet.free()
	for schema in [0,2,3]:
		var path:=file("migration-%d"%schema);var cfg:=ConfigFile.new()
		cfg.set_value("progress","skin_schema",schema);cfg.set_value("progress","skin_progress",420)
		cfg.set_value("progress","owned_skin_ids",["core_shell","tide","rainbow_bridge"])
		cfg.set_value("progress","selected_skin_id","tide");cfg.set_value("progress","coins",777)
		cfg.set_value("custom","keep_me","preserved");check(cfg.save(path)==OK,"Legacy fixture writes")
		loaded=restored(path)
		check(loaded.skin_unlocked("core_shell") and loaded.skin_unlocked("tide") and loaded.selected_skin_id=="tide","Existing advanced ownership and equipment survive schema %d"%schema)
		check(loaded.skin_unlocked("rainbow_bridge"),"Explicit rainbow entitlement survives every migration schema")
		check(loaded.skin_unlocked(Rarity.NEW_PLAYER_SKIN) and loaded.coins==777,"Migration grants simple starter without changing wallet")
		check(loaded.save_player_progress(),"Migrated state saves atomically")
		cfg=ConfigFile.new();cfg.load(path)
		check(cfg.get_value("custom","keep_me","")=="preserved" and cfg.get_value("progress","skin_schema",0)==3,"Migration preserves unrelated settings and advances schema")
		loaded.free()

func monetization_tests()->void:
	game.start_level();game.begin_play();quiet_world();game.player.score=1234;game.finish("complete")
	var base_coins:int=game.round_coins;var wallet:int=game.coins
	check(base_coins==123 and not game.request_round_double().ok and game.coins==wallet,"No real ad SDK means no simulated video or reward")
	check(not game.request_coin_purchase(SMALL).ok and game.coins==wallet,"No store SDK means no simulated purchase or balance grant")
	game.ads.free();game.ads=Ads.new();game.add_child(game.ads)
	var video:=Video.new();check(game.ads.bind_test_native(video),"Test injects versioned video provider explicitly")
	game.ads.rewarded_completed.connect(game.credit_round_double);game.ads.rewarded_closed.connect(game.reward_video_closed);game.ads.rewarded_failed.connect(game.reward_video_failed);game.ads.initialize()
	check(game.request_round_double().ok and game.reward_video_pending(),"Result action persists request before opening video")
	check(not game.request_round_double().ok and video.requests.size()==1,"Rapid taps cannot launch duplicate video requests")
	var request:String=video.requests[0]
	video.rewarded_closed.emit(request)
	check(game.coins==wallet and not game.reward_video_pending(),"Closing alone gives no reward and does not leave a stuck action")
	game.start_level();game.begin_play();quiet_world();game.player.score=9000
	video.rewarded_earned.emit(request)
	check(game.coins==wallet+base_coins and game.round_receipt.is_empty(),"Delayed earned callback doubles only the previous run, not wallet or new score")
	video.rewarded_earned.emit(request);game.credit_round_double(request)
	check(game.coins==wallet+base_coins,"Duplicate callback cannot pay twice")
	game.remaining=.01;game._physics_process(.02)
	wallet=game.coins;base_coins=game.round_coins
	check(game.request_round_double().ok,"A new round has its own reward opportunity")
	request=video.requests[-1]
	var path:String=game.test_progress_path;game.test_progress_path=base+"-missing/reward.cfg"
	video.rewarded_earned.emit(request)
	check(game.coins==wallet and not game.round_receipt.doubled and game.verified_rewards_waiting.has(request),"Disk failure does not display or commit a false reward")
	video.rewarded_closed.emit(request);game.test_progress_path=path;game.retry_verified_rewards()
	check(game.coins==wallet+base_coins and game.round_receipt.doubled and game.verified_rewards_waiting.is_empty(),"Verified reward retries after storage recovers")
	var loaded:=restored(path)
	check(loaded.coins==game.coins and loaded.reward_receipts[game.round_receipt.id].doubled,"Bonus and receipt survive restart together")
	loaded.free()
	game.back_home();await frames()
	game.commerce.free();game.commerce=Commerce.new();game.add_child(game.commerce)
	var store:=Store.new();check(game.commerce.bind_test_native(store),"Test injects versioned store provider explicitly")
	game.commerce.verified_purchase.connect(game.credit_verified_purchase);game.commerce.purchase_failed.connect(game.purchase_failed);game.commerce.purchase_pending.connect(game.purchase_pending);game.commerce.products_changed.connect(game.refresh_monetization_ui);game.commerce.initialize()
	wallet=game.coins
	check(game.request_coin_purchase(SMALL).ok,"Available native product opens a real request path")
	var order:String=game.purchase_request;store.purchase_pending.emit(order)
	check(game.coins==wallet and game.purchase_request.is_empty(),"Pending approval never grants coins")
	check(game.request_coin_purchase(SMALL).ok,"A second purchase can be presented after pending approval")
	var newer:String=game.purchase_request
	store.purchase_verified.emit("prior-approved",SMALL,order)
	check(game.coins==wallet+320 and game.purchase_request==newer,"Delayed approval grants once without closing newer same-product request")
	store.purchase_verified.emit("prior-approved",SMALL,order)
	check(game.coins==wallet+320,"Duplicate transaction never changes wallet twice")
	game.test_progress_path=base+"-missing/store.cfg"
	store.purchase_verified.emit("new-approved",SMALL,newer)
	check(game.coins==wallet+320 and not game.redeemed_transactions.has("new-approved") and not store.acknowledgments.has("new-approved"),"Failed wallet write neither spends nor acknowledges verified store receipt")
	game.test_progress_path=path;store.purchase_verified.emit("new-approved",SMALL,newer)
	check(game.coins==wallet+640 and store.acknowledgments.has("new-approved"),"Store redelivery credits and acknowledges after durable save")
	loaded=restored(path)
	check(loaded.redeemed_transactions.has("prior-approved") and loaded.redeemed_transactions.has("new-approved") and loaded.coins==game.coins,"Purchase dedup keys persist with the wallet")
	loaded.free()

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.test_progress_path=file("game")
	await frames(3)
	await round_tests();collection_tests();await monetization_tests()
	game.free();await frames()
	for path in paths:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("RETENTION_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"scope":"Timed gameplay, real persistence, protocol-injected callbacks; no actual ad/store SDK or browser claim"}))
	quit(0 if failures.is_empty() else 1)
