extends SceneTree
## Non-author integration review. Isolated saves and native protocol fixtures;
## no advertisement SDK, payment, browser, player save, or real transaction.
const Game=preload("res://fidelity/game.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
const Commerce=preload("res://fidelity/commerce_bridge.gd")
const Catalog=preload("res://fidelity/skin_catalog.gd")
const SMALL:="sink_city.coins_320"
var checks:=0
var failures:Array[String]=[]
var game:Node3D
var files:Array[String]=[]
var ad:AdNative
var shop:StoreNative

class AdNative extends RefCounted:
 signal rewarded_earned(id:String)
 signal rewarded_closed(id:String)
 signal rewarded_failed(id:String,message:String)
 signal availability_changed
 var requests:Array[String]=[]
 var accepted:=true
 var synchronous:=false
 func sink_city_rewarded_protocol_version()->int:return 1
 func initialize()->void:pass
 func rewarded_available()->bool:return true
 func show_rewarded(id:String)->bool:
  requests.append(id)
  if synchronous:rewarded_closed.emit(id);rewarded_earned.emit(id)
  return accepted

class StoreNative extends RefCounted:
 signal products_received(products:Array)
 signal purchase_verified(tx:String,product:String,request:String)
 signal purchase_failed(request:String,message:String)
 signal purchase_pending(request:String)
 signal availability_changed
 var requests:Array=[]
 var ack:Array[String]=[]
 var ack_ok:=true
 var synchronous:=false
 var accepted:=true
 func sink_city_commerce_protocol_version()->int:return 1
 func initialize()->void:pass
 func purchases_available()->bool:return true
 func request_products(_ids:PackedStringArray)->void:products_received.emit([{"product_id":SMALL,"localized_price":"₩1,100"}])
 func purchase(product:String,request:String)->bool:
  requests.append([product,request])
  if synchronous:purchase_verified.emit("sync-"+request,product,request)
  return accepted
 func acknowledge(tx:String)->bool:ack.append(tx);return ack_ok

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:=2)->void:
 for _i in n:await process_frame
func path(label:String)->String:
 var p:="/tmp/hole-retention-review-%d-%s.cfg"%[OS.get_process_id(),label]
 files.append(p);return p
func target(id:String)->Button:
 for b in game.ui.buttons:
  if b.name==id or b.text==id:return b
 return null
func freeze_play()->void:
 game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
 if "rain_enabled" in game.city:game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.set_physics_process(false)
 game.scan=9999
func install_protocols()->void:
 game.ads.free();game.ads=Ads.new();game.add_child(game.ads);ad=AdNative.new()
 check(game.ads.bind_test_native(ad),"Independent typed ad fixture binds through the production boundary")
 game.ads.rewarded_completed.connect(game.credit_round_double)
 game.ads.rewarded_closed.connect(game.reward_video_closed)
 game.ads.rewarded_failed.connect(game.reward_video_failed)
 game.ads.availability_changed.connect(game.refresh_monetization_ui)
 game.ads.initialize()
 game.commerce.free();game.commerce=Commerce.new();game.add_child(game.commerce);shop=StoreNative.new()
 check(game.commerce.bind_test_native(shop),"Independent typed store fixture binds through the production boundary")
 game.commerce.verified_purchase.connect(game.credit_verified_purchase)
 game.commerce.purchase_failed.connect(game.purchase_failed)
 game.commerce.purchase_pending.connect(game.purchase_pending)
 game.commerce.products_changed.connect(game.refresh_monetization_ui)
 game.commerce.initialize()
func settle(score:int)->void:
 game.phase="playing";game.player.active=true;game.player.score=score;game.remaining=.001
 game._physics_process(.002)

func migrations()->void:
 # Every former entitlement, including original starter and equipped skills,
 # survives schema-2 migration independently of current rarity placement.
 for definition in Catalog.DEFS:
  var file:=path("schema2-"+str(definition.id));var cfg:=ConfigFile.new()
  cfg.set_value("progress","skin_schema",2)
  cfg.set_value("progress","owned_skin_ids",["core_shell",definition.id])
  cfg.set_value("progress","selected_skin_id",definition.id)
  cfg.set_value("progress","coins",173);cfg.set_value("progress","gems",41)
  cfg.set_value("audio","music_enabled",false);cfg.set_value("unrelated","proof",19)
  check(cfg.save(file)==OK,"Write process-owned legacy fixture "+str(definition.id))
  var owner:=Game.new();owner.test_progress_path=file
  check(owner.load_player_progress() and owner.skin_unlocked(str(definition.id)) and owner.skin_unlocked("core_shell"),"Retain former entitlement "+str(definition.id))
  check(owner.selected_skin_id==definition.id and owner.coins==173 and owner.gems==41 and not owner.music_enabled,"Retain old equipment and wallet "+str(definition.id))
  check(owner.save_player_progress(),"Commit schema-3 upgrade "+str(definition.id))
  var restored:=Game.new();restored.test_progress_path=file
  check(restored.load_player_progress() and restored.owned_skin_ids==owner.owned_skin_ids and restored.selected_skin_id==definition.id,"Schema-3 restart retains upgraded ownership "+str(definition.id))
  cfg.load(file);check(cfg.get_value("unrelated","proof")==19 and int(cfg.get_value("progress","skin_schema"))==3,"Schema upgrade preserves unrelated values "+str(definition.id))
  owner.free();restored.free()

func timed_runs()->void:
 for map_id in ["city","food"]:
  game.selected_map=map_id;game.start_level();game.begin_play();freeze_play()
  for h in game.holes:
   if h!=game.player:h.active=false
  var initial_wallet:int=game.coins;var initial_stage:int=game.stage
  for score in [499,500,501,10000]:
   game.player.score=score;game._physics_process(.1)
   check(game.phase=="playing" and game.round_receipt.is_empty() and game.coins==initial_wallet,"No automatic milestone settlement "+map_id+" "+str(score))
  if map_id=="food":
   game.food_collected={"egg":10,"donut":4,"cake":1};game.city.collection_progress={"buildings":12,"landmarks":1,"heaps":1}
   check(game.food_goal_complete(),"Food optional objectives are genuinely satisfied before timer test")
   game._physics_process(.1);check(game.phase=="playing","All food objectives cannot prematurely end the timed run")
  game.player.score=0;game.player.award(213)
  var saved_radius:float=game.player.radius
  var old:Node3D=game.player;var rival:Node3D=game.holes[1]
  rival.active=true;rival.radius=saved_radius*1.6;rival.position=old.position
  game.elapsed=20;game.remaining=220;game.reset_rival_state();game.scan_rivals()
  check(not old.active and game.phase=="playing" and game.player_respawn_time==2 and game.round_deaths==1,"Actual rival contact begins respawn, without result page: "+map_id)
  check(game.coins==initial_wallet and game.round_receipt.is_empty(),"Death does not settle or change wallet: "+map_id)
  game._physics_process(1.9)
  check(game.player==old and not game.player.active and is_equal_approx(game.remaining,218.1),"Countdown continues while waiting for automatic respawn: "+map_id)
  game._physics_process(.11)
  check(game.player!=old and game.player.active and game.player.score==213 and is_equal_approx(game.player.radius,saved_radius),"Respawn retains actual score and growth: "+map_id)
  check(game.holes.size()==8 and not game.holes.has(old) and is_equal_approx(game.player_protected_until-game.elapsed,8),"Respawn replaces one actor and grants eight seconds protection: "+map_id)
  game.player.enabled=false;game.player.set_physics_process(false)
  rival.position=game.player.position;game.reset_rival_state();game.scan_rivals()
  check(game.player.active and game.round_deaths==1 and not game.rival_size_allows(rival,game.player),"Overlapping larger rival cannot eat protected respawn: "+map_id)
  game.elapsed=game.player_protected_until-.001;game.reset_rival_state();game.scan_rivals()
  check(game.player.active,"Protection holds until exact expiry: "+map_id)
  game.elapsed=game.player_protected_until;game.reset_rival_state();game.scan_rivals()
  check(not game.player.active and game.round_deaths==2,"Protection expires without permanent invulnerability: "+map_id)
  game.remaining=.001;game._physics_process(.002)
  check(game.phase=="complete" and game.round_coins==41 and game.stage==initial_stage+1 and game.coins==initial_wallet+41,"Timer settles retained score once even during respawn: "+map_id)
  game.finish("complete");check(game.coins==initial_wallet+41,"Repeated finish cannot settle the timed run twice: "+map_id)
  await frames()

func monetary_callbacks()->void:
 check(not game.ads.validated_reward_available() and not game.commerce.purchase_available(SMALL),"No installed SDK means both native offers are unavailable")
 var before:int=game.coins
 check(not game.request_round_double().ok and game.coins==before,"Unavailable rewarded video cannot mint coins")
 game.ui.refresh();await frames()
 check(target("double-round-coins")!=null and target("double-round-coins").disabled,"Unavailable result video action is visibly disabled")
 game.back_home();game.ui.open_purchases();await frames()
 for i in 3:check(target("purchase-%d"%i)!=null and target("purchase-%d"%i).disabled,"No native SDK disables purchase product "+str(i))
 check(not game.request_coin_purchase(SMALL).ok and game.coins==before,"Unavailable coin purchase cannot debit or award")
 install_protocols()
 # Settlement uses 12 floored score coins + 20 finish coins = exactly 32.
 game.start_level();game.begin_play();freeze_play();settle(129)
 before=game.coins;var first_round:String=game.round_receipt.id
 check(game.round_coins==32 and game.request_round_double().ok,"A settled round binds a real opt-in request")
 var first_request:String=ad.requests.back()
 check(not game.request_round_double().ok and ad.requests.size()==1,"A loading round cannot create duplicate presentation")
 ad.rewarded_earned.emit("wrong-id");check(game.coins==before,"Unknown callback ID cannot affect wallet")
 ad.rewarded_closed.emit(first_request);check(game.coins==before,"Closing a video alone gives no reward")
 # Begin and settle another round before the valid late earned callback.
 game.start_level();game.begin_play();freeze_play();settle(999)
 var second_round:String=game.round_receipt.id;before=game.coins
 ad.rewarded_earned.emit(first_request)
 check(game.coins==before+32 and game.reward_receipts[first_round].doubled,"Late earned signal adds exact old base, not current wallet or new run")
 check(game.round_receipt.id==second_round and not game.round_receipt.doubled and game.round_coins==119,"Late old signal leaves new result receipt unchanged")
 ad.rewarded_earned.emit(first_request);check(game.coins==before+32,"Repeated native old reward stays deduplicated")
 var good_path:String=game.test_progress_path
 game.test_progress_path=good_path+"/blocked/save.cfg"
 before=game.coins;var requests:int=ad.requests.size()
 check(not game.request_round_double().ok and ad.requests.size()==requests and game.coins==before,"Request binding save failure never opens an external ad")
 game.test_progress_path=good_path
 check(game.request_round_double().ok,"Current round starts its own independent reward")
 var second_request:String=ad.requests.back()
 game.test_progress_path=good_path+"/blocked/save.cfg"
 ad.rewarded_earned.emit(second_request)
 check(game.coins==before and not game.reward_receipts[second_round].doubled and game.verified_rewards_waiting.has(second_request),"Reward write failure rolls back wallet and receipt while keeping authenticated retry")
 ad.rewarded_closed.emit(second_request)
 game.test_progress_path=good_path
 check(game.save_player_progress(),"Persist verified reward-due record after storage recovers")
 var restored:=Game.new();restored.test_progress_path=good_path
 check(restored.load_player_progress() and restored.verified_rewards_waiting.has(second_request),"Verified pending reward survives a cold restore")
 restored.retry_verified_rewards()
 check(restored.coins==before+119 and restored.reward_receipts[second_round].doubled and restored.verified_rewards_waiting.is_empty(),"Cold retry grants exactly the stored second-round base")
 restored.retry_verified_rewards();check(restored.coins==before+119,"Cold retry cannot duplicate reward")
 restored.free()
 game.retry_verified_rewards()
 check(game.coins==before+119 and game.round_receipt.doubled,"Live retry updates current result display receipt")
 game.back_home();await frames()
 # Native store: grant only a verified receipt, commit before acknowledge.
 check(game.request_coin_purchase(SMALL).ok,"Known available localized product opens store")
 var request:String=shop.requests.back()[1];before=game.coins
 shop.purchase_pending.emit(request)
 check(game.coins==before and game.purchase_request.is_empty(),"Parental approval pending never awards and releases presentation")
 check(game.request_coin_purchase(SMALL).ok,"A later same-product purchase can open while first awaits approval")
 var newer:String=shop.requests.back()[1]
 shop.purchase_verified.emit("verified-old",SMALL,request)
 check(game.coins==before+320 and game.purchase_request==newer and shop.ack==["verified-old"],"Late approval credits exact product and does not close newer presentation")
 shop.purchase_verified.emit("verified-old",SMALL,request)
 check(game.coins==before+320,"Duplicate verified transaction cannot duplicate wallet")
 game.test_progress_path=good_path+"/blocked/save.cfg";before=game.coins
 shop.purchase_verified.emit("save-retry",SMALL,newer)
 check(game.coins==before and not game.redeemed_transactions.has("save-retry") and not shop.ack.has("save-retry"),"Unwritable purchase rolls back and never acknowledges undurable coins")
 game.test_progress_path=good_path
 shop.ack_ok=false;shop.purchase_verified.emit("save-retry",SMALL,newer)
 check(game.coins==before+320 and game.redeemed_transactions.has("save-retry"),"Verified store receipt redelivery retries wallet commit")
 shop.ack_ok=true;shop.purchase_verified.emit("save-retry",SMALL,newer)
 check(game.coins==before+320 and shop.ack.count("save-retry")==2,"Acknowledgement retry does not grant coins again")
 restored=Game.new();restored.test_progress_path=good_path
 check(restored.load_player_progress() and restored.redeemed_transactions.has("save-retry") and restored.coins==game.coins,"Durable store transaction dedup survives process restart")
 before=restored.coins;restored.credit_verified_purchase("save-retry",SMALL)
 check(restored.coins==before,"Duplicate store transaction after restart remains harmless")
 restored.free()
 # A native call that rejects after synchronous callbacks cannot earn anything.
 before=game.coins;shop.synchronous=true;shop.accepted=false
 check(not game.request_coin_purchase(SMALL).ok and game.coins==before,"Rejected synchronous purchase cannot manufacture coins")
 shop.synchronous=false;shop.accepted=true
 game.start_level();game.begin_play();freeze_play();settle(111)
 before=game.coins;ad.accepted=false;ad.synchronous=true
 check(not game.request_round_double().ok and game.coins==before and not game.round_receipt.doubled,"Rejected synchronous video cannot manufacture coins")

func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 migrations()
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames()
 game.test_progress_path=path("live");game.set_process(false);game.set_physics_process(false)
 check(game.owned_skin_ids==["cocoa_square"] and game.selected_skin_id=="cocoa_square","A fresh player owns the simple gray starter only")
 await timed_runs()
 await monetary_callbacks()
 game.audio.music.stop();OS.delay_msec(120);await process_frame
 game.free();await frames()
 for file in files:
  for suffix in ["",".tmp",".pre-coins.cfg"]:
   if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
 var result:={"checks":checks,"failures":failures,"scope":"Real game timer/combat/respawn and production native bridges with test-only typed providers; all saves process-owned /tmp"}
 print("RETENTION_REVIEW "+JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 quit(0 if failures.is_empty() else 1)
