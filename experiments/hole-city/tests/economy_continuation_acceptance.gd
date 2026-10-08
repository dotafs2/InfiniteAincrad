extends SceneTree
## Real same-world continuation and durable mixed-currency reward receipts.
const Game=preload("res://fidelity/game.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var paths:Array[String]=[]
var base:="/tmp/hole-economy-continuation-%d"%OS.get_process_id()

class Video extends RefCounted:
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	var requests:Array[String]=[]
	var ready:=true
	var accepted:=true
	func sink_city_rewarded_protocol_version()->int:return 1
	func initialize()->void:pass
	func rewarded_available()->bool:return ready
	func show_rewarded(id:String)->bool:requests.append(id);return accepted

class FaultySaveGame:
	extends "res://fidelity/game.gd"
	var save_calls:=0
	var fail_on_save:=0
	func save_player_progress()->bool:
		save_calls+=1
		if save_calls==fail_on_save:return false
		return super.save_player_progress()

class Acknowledgments extends Node:
	var ids:Array[String]=[]
	func acknowledge(id:String)->bool:ids.append(id);return true
	func active_request_id()->String:return ""

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func path(label:String)->String:
	var value:=base+"-"+label+".cfg"
	for suffix in ["",".tmp",".pre-coins.cfg"]:paths.append(value+suffix)
	return value
func restored(value:String)->Node3D:
	var state:=Game.new();state.test_progress_path=value
	check(state.load_player_progress(),"Isolated saved economy restores")
	return state
func quiet_world()->void:
	game.city.process_mode=Node.PROCESS_MODE_DISABLED
	if game.selected_map=="food":game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false
func open_round(map_id:="city",score:=800)->void:
	game.selected_map=map_id;game.start_level();game.begin_play();quiet_world();game.player.score=score
func end_round()->void:
	game.remaining=.01;game._physics_process(.02)

func completion_funds_actual_draw()->void:
	game.coins=0
	var owned:int=game.owned_skin_ids.size()
	open_round("city",1000)
	check(game.coins==0 and game.round_receipt.is_empty(),"Mid-round score is a preview and does not pay coins early")
	end_round()
	check(game.round_coins==100 and game.coins==100 and game.round_score_coins==100 and game.round_win_coins==0,"1000 points earn exactly one 100-coin draw")
	var loaded:=restored(game.test_progress_path)
	check(loaded.coins==100,"Played completion balance survives restart before any draw")
	loaded.free()
	game.gems=10
	check(game.request_round_coin_boost_gems().ok and game.coins==150 and game.round_coins==150,"A 100-coin score reward can be boosted to 150 exactly once")
	game.back_home();game.last_unlock_msec=-1000
	var receipt:Dictionary=game.unlock_random_skin("collection")
	check(receipt.ok and receipt.price==100 and game.coins==50 and game.owned_skin_ids.size()==owned+1,"Actual earned wallet buys one new skin at the fixed100-coin price")
	loaded=restored(game.test_progress_path)
	check(loaded.coins==50 and loaded.owned_skin_ids==game.owned_skin_ids and loaded.draw_pity==game.draw_pity,"Earned reward, draw deduction, entitlement and guarantees survive restart together")
	loaded.free()
	check(game.skin_unlock_price("collection")==100,"A completed draw cannot increase the next collection price")
	open_round("city",800)
	var wallet:int=game.coins
	game.finish("eaten")
	check(game.round_coins==80 and game.round_win_coins==0 and game.coins==wallet+80,"A terminal defeat retains its earned points without any finish bonus")
	game.back_home()

func timing_and_debit()->void:
	var starter:=Game.new()
	check(starter.coins==50 and starter.gems==10,"Fresh wallet starts with 50 coins and 10 diamonds")
	starter.free()
	for map_id in ["city","food","toys"]:
		open_round(map_id)
		game.gems=10
		var duration:=60.0 if map_id=="food" else 90.0
		check(game.remaining==duration and game.round_duration()==duration,map_id+": map duration is exact")
		var wallet:int=game.coins;var stages:int=game.stage;var completed:int=game.completed_runs
		end_round()
		check(game.round_score_coins==80 and game.round_win_coins==0 and game.coins==wallet+80,map_id+": 800 earned points pay 80 coins")
		var original_world:Node3D=game.world;var receipt_id:String=game.round_receipt.id
		var serial:int=game.round_serial;var before_gems:int=game.gems
		game.eaten=123;game.kills=4
		check(game.can_extend_round() and game.request_round_extension_gems().ok,map_id+": timed result offers one paid continuation")
		check(game.world==original_world and game.phase=="playing" and game.remaining==30 and game.player.score==800 and game.eaten==123 and game.kills==4,map_id+": continuation preserves world, score, consumption and kills")
		check(game.gems==before_gems-2 and game.extension_used and game.round_receipt.id==receipt_id,map_id+": two diamonds and original receipt commit together")
		game.player.score=1700;end_round()
		check(game.round_coins==170 and game.coins==wallet+170 and game.round_serial==serial,map_id+": extra score adds only its new 90 coins to the original receipt")
		check(game.stage==stages+1 and game.completed_runs==completed+1,map_id+": continuation cannot advance completion or stage twice")
		check(not game.can_extend_round() and not game.request_round_extension_gems().ok and not game.request_round_extension_video().ok,map_id+": second continuation is rejected")
		wallet=game.coins;game.finish("complete")
		check(game.coins==wallet,map_id+": repeated settlement is inert")
		game.gems=10
	open_round("city",90000);end_round()
	check(game.round_coins==9000 and game.round_score_coins==9000,"Large earned scores retain the same uncapped conversion")
	open_round("city",0)
	var stages:int=game.stage;var completed:int=game.completed_runs
	end_round()
	check(game.round_coins==0 and game.stage==stages,"An empty run earns no free coins or stage")
	check(game.request_round_extension_gems().ok,"An empty timed world can still use its one continuation")
	game.player.score=250;end_round()
	check(game.round_coins==25 and game.stage==stages+1 and game.completed_runs==completed+1,"First real score in continuation receives only its 25 earned coins")
	open_round();end_round()
	game.gems=10
	var saved_path:String=game.test_progress_path;var wallet:int=game.coins;var receipt:Dictionary=game.round_receipt.duplicate(true)
	game.test_progress_path=base+"-missing/charge.cfg"
	check(not game.request_round_extension_gems().ok and game.gems==10 and game.coins==wallet and game.phase=="complete" and game.round_receipt==receipt,"Failed continuation save spends no diamonds and does not resume")
	game.test_progress_path=saved_path

func coin_boost_and_continuation(video:Video)->void:
	open_round("city",800);end_round()
	game.gems=20
	var wallet:int=game.coins;var before_gems:int=game.gems
	var stage:int=game.stage;var runs:int=game.completed_runs;var serial:int=game.round_serial
	var world:Node3D=game.world;var receipt_id:String=game.round_receipt.id
	check(game.round_coins==80 and game.round_coin_boost_bonus()==40 and game.can_boost_round_coins(),"Base 80 exposes its exact 40-coin 1.5x offer")
	check(game.request_round_coin_boost_gems().ok and game.coins==wallet+40 and game.gems==before_gems-2,"Two diamonds commit exactly 40 bonus coins")
	check(game.round_receipt.base_coins==80 and game.round_receipt.coin_boost_bonus==40 and game.round_coins==120 and game.round_receipt.final_coins==120,"Multiplier keeps its score-derived base and displays 120 coins")
	check(not game.can_boost_round_coins() and not game.request_round_coin_boost_gems().ok and not game.request_round_coin_boost_video().ok and not game.request_round_double().ok,"A boosted receipt cannot buy, watch or legacy-double its multiplier again")
	check(game.can_extend_round() and game.request_round_extension_gems().ok,"One multiplier and one continuation remain independent choices")
	check(game.world==world and game.round_receipt.id==receipt_id and game.coins==wallet+40,"Continuation cannot reset a boosted world or replay its existing payment")
	game.player.score=1700;end_round()
	check(game.round_receipt.base_coins==170 and game.round_receipt.coin_boost_bonus==85 and game.round_coins==255 and game.coins==wallet+175,"Extended points add only the new base and multiplier difference")
	check(game.stage==stage and game.completed_runs==runs and game.round_serial==serial and game.round_win_coins==0,"Boosted continuation never repeats completion, stage, receipt or finish bonus")
	wallet=game.coins;game.finish("complete")
	check(game.coins==wallet and not game.can_boost_round_coins() and not game.can_extend_round(),"Repeated final settlement cannot repeat either once-per-round choice")
	open_round("food",800);end_round();game.gems=20
	wallet=game.coins
	check(game.request_round_extension_gems().ok,"Continuation-before-multiplier order also starts the same run")
	game.player.score=1700;end_round()
	check(game.request_round_coin_boost_gems().ok and game.round_coins==255 and game.coins==wallet+175 and game.gems==16,"Either choice order produces the same 255 coins and spends 4 diamonds")
	open_round("city",90000);end_round();game.gems=10
	wallet=game.coins
	check(game.request_round_coin_boost_gems().ok and game.round_receipt.base_coins==9000 and game.round_coins==13500 and game.coins==wallet+4500,"A high-score multiplier keeps the same 1.5x ratio")
	open_round("city",0);end_round();wallet=game.coins
	check(not game.can_boost_round_coins() and not game.request_round_coin_boost_gems().ok and game.coins==wallet,"An empty run cannot manufacture a multiplier or spend diamonds")
	open_round("city",800);end_round();game.gems=10
	var saved_path:String=game.test_progress_path;var before:Dictionary=game.round_receipt.duplicate(true)
	wallet=game.coins;game.test_progress_path=base+"-missing/coin-boost.cfg"
	check(not game.request_round_coin_boost_gems().ok and game.coins==wallet and game.gems==10 and game.round_receipt==before and game.round_coins==80,"Failed paid multiplier save rolls back both currencies, receipt and displayed total")
	game.test_progress_path=saved_path
	check(game.request_round_coin_boost_video().ok and game.reward_video_pending(),"Multiplier video binds the actual accepted round before SDK dispatch")
	var request:String=video.requests[-1]
	check(not game.request_round_coin_boost_gems().ok and not game.request_round_extension_gems().ok,"Visible multiplier ad blocks duplicate currency spending")
	video.rewarded_earned.emit(request)
	check(game.coins==wallet and not game.round_receipt.get("coin_boosted",false) and game.reward_video_pending(),"Earned multiplier waits for actual dismissal before granting coins")
	video.rewarded_closed.emit(request)
	check(game.coins==wallet+40 and game.round_coins==120 and game.gems==10 and not game.reward_video_pending(),"Dismissed genuinely earned multiplier grants 40 coins without spending diamonds")
	video.rewarded_earned.emit(request);video.rewarded_closed.emit(request);game.credit_round_double(request)
	check(game.coins==wallet+40,"Duplicate multiplier earned/closed callbacks cannot pay again")
	open_round("city",800);end_round();game.gems=10
	wallet=game.coins;check(game.request_round_coin_boost_video().ok,"Close-before-earned multiplier opens an actual request")
	request=video.requests[-1];video.rewarded_closed.emit(request)
	check(game.coins==wallet and not game.round_receipt.get("coin_boosted",false),"A closed but unearned multiplier does not grant coins")
	check(not game.request_round_double().ok,"A pending late1.5x callback cannot acquire a conflicting legacy2x offer")
	check(game.request_round_extension_gems().ok,"Late multiplier callback may coexist with a legitimate already-started continuation")
	game.player.score=1700;video.rewarded_earned.emit(request)
	check(game.phase=="playing" and game.coins==wallet+40 and game.round_coins==120,"Late earned callback boosts only the settled base while the same world continues")
	end_round()
	check(game.round_coins==255 and game.coins==wallet+175,"Later settlement tops up only the new score and earned multiplier")
	open_round("city",800);end_round();check(game.request_round_coin_boost_video().ok,"Historical multiplier opens a genuinely accepted binding")
	request=video.requests[-1];receipt_id=game.round_receipt.id;video.rewarded_closed.emit(request)
	for index in 40:
		var historical:="unwatched-history-%d"%index
		game.reward_receipts[historical]={"id":historical,"map":"city","base_coins":0,"settled":true}
	open_round("food",1700);end_round();wallet=game.coins
	var current_receipt:String=game.round_receipt.id;world=game.world
	check(game.reward_receipts.has(receipt_id) and game.rewarded_requests.has(request),"History trimming retains valid close-before-earned multiplier binding")
	video.rewarded_earned.emit(request)
	check(game.coins==wallet+40 and game.round_receipt.id==current_receipt and game.round_coins==170 and game.world==world and game.phase=="complete","Late old multiplier pays its old base only, without mutating or reviving the current world")
	game.back_home()

func coin_boost_restart_failure()->void:
	var owner:=FaultySaveGame.new();owner.test_progress_path=path("coin-boost-second-commit")
	owner.coins=63;owner.round_coins=13;owner.phase="complete"
	owner.round_receipt={"id":"boost-crash-round","map":"city","base_coins":13,"settled":true,"doubled":false}
	owner.reward_receipts["boost-crash-round"]=owner.round_receipt.duplicate(true)
	owner.rewarded_requests["accepted-coin-boost"]={"purpose":"coin_boost","round":"boost-crash-round","status":"loading","closed":true,"authenticated":false}
	owner.fail_on_save=2;owner.credit_round_double("accepted-coin-boost")
	check(owner.save_calls==2 and owner.coins==63 and owner.gems==10 and not owner.round_receipt.get("coin_boosted",false) and owner.round_coins==13,"Second multiplier commit failure preserves coins, diamonds and original receipt after durable earned marker")
	var cfg:=ConfigFile.new();check(cfg.load(owner.test_progress_path)==OK,"Persisted multiplier failure fixture loads")
	check(cfg.get_value("rewards","video_requests",{})["accepted-coin-boost"].status=="reward_due" and cfg.get_value("progress","coins",0)==63,"On-disk marker survives without an uncommitted coin grant")
	var saved_path:String=owner.test_progress_path;owner.free()
	var loaded:=restored(saved_path);loaded.retry_verified_rewards();loaded.retry_verified_rewards()
	check(loaded.coins==69 and loaded.gems==10 and loaded.reward_receipts["boost-crash-round"].coin_boosted and loaded.reward_receipts["boost-crash-round"].coin_boost_bonus==6,"Restart settles authenticated1.5x work exactly once into the old receipt")
	check(loaded.phase=="title" and loaded.round_receipt.is_empty(),"Restarted multiplier never revives its finished world")
	loaded.free()

func video_continuation(video:Video)->void:
	open_round();end_round()
	var original_world:Node3D=game.world;var wallet:int=game.coins;var before_gems:int=game.gems
	check(game.request_round_extension_video().ok and game.reward_video_pending(),"Extension request persists before accepted video opens")
	var request:String=video.requests[-1]
	check(not game.request_round_extension_gems().ok and not game.request_round_extension_video().ok,"Pending video blocks duplicate spending and duplicate videos")
	video.rewarded_earned.emit(request)
	check(game.phase=="complete" and game.remaining==0 and game.reward_video_pending(),"Earned-before-close keeps the timer stopped behind the ad")
	var cfg:=ConfigFile.new();cfg.load(game.test_progress_path)
	check(cfg.get_value("rewards","video_requests",{})[request].status=="reward_due","Authenticated earned work is durable before continuation")
	video.rewarded_closed.emit(request)
	check(game.phase=="playing" and game.remaining==30 and game.world==original_world and game.gems==before_gems and game.coins==wallet,"Actual close resumes the same world for 30 seconds without wallet charges")
	video.rewarded_earned.emit(request);video.rewarded_closed.emit(request);game.credit_round_double(request)
	check(game.remaining==30 and game.gems==before_gems,"Duplicate earned/closed callbacks cannot repeat continuation")
	end_round();open_round();end_round()
	check(game.request_round_extension_video().ok,"Another actual round has its own continuation offer")
	request=video.requests[-1];video.rewarded_closed.emit(request)
	check(game.phase=="complete" and not game.extension_used,"Closing alone never resumes a round")
	video.rewarded_earned.emit(request)
	check(game.phase=="playing" and game.remaining==30,"Close-before-earned callback order also resumes exactly once")
	end_round();open_round();end_round()
	check(game.request_round_extension_video().ok,"An old persisted extension offer can still resolve through the real callback path")
	request=video.requests[-1]
	# Older requests lack the explicit fallback field; keep their promised5.
	game.rewarded_requests[request].erase("extension_fallback_gems")
	check(game.save_player_progress(),"Legacy five-diamond offer snapshot persists without a new-price field")
	video.rewarded_closed.emit(request);before_gems=game.gems
	game.back_home();video.rewarded_earned.emit(request)
	check(game.gems==before_gems+5 and game.phase=="title","An unfinished legacy extension still grants its original five-diamond fallback")
	video.rewarded_earned.emit(request)
	check(game.gems==before_gems+5,"Legacy extension fallback remains duplicate-safe after the price correction")
	open_round();end_round()
	check(game.request_round_extension_video().ok,"Late-reward scenario opens an actual request")
	request=video.requests[-1];video.rewarded_closed.emit(request)
	before_gems=game.gems
	game.back_home();video.rewarded_earned.emit(request)
	check(game.phase=="title" and game.gems==before_gems+2,"An earned abandoned-world continuation uses its durable two-diamond fallback instead of reviving a lost world")
	video.rewarded_earned.emit(request);game.credit_round_double(request)
	check(game.gems==before_gems+2,"Abandoned-world fallback is also exactly once")
	open_round();end_round();check(game.request_round_extension_video().ok,"Restart recovery opens an actual continuation request")
	request=video.requests[-1];before_gems=game.gems;video.rewarded_earned.emit(request)
	var loaded:=restored(game.test_progress_path)
	loaded.retry_verified_rewards()
	check(loaded.phase=="title" and loaded.gems==before_gems+2 and loaded.rewarded_requests[request].status=="earned","Restart honors the persisted two-diamond extension offer")
	loaded.retry_verified_rewards()
	check(loaded.gems==before_gems+2,"Restart fallback cannot replay twice")
	loaded.free()
	# Simulate replacement of the old process before any further callbacks.
	game.rewarded_requests[request].status="earned";game.verified_rewards_waiting.erase(request)
	video.rewarded_closed.emit(request);game.back_home()
	# A persisted pre-update ten-diamond offer keeps its original entitlement.
	open_round();end_round();check(game.request_round_extension_video().ok,"Legacy ten-diamond snapshot opens a real continuation request")
	request=video.requests[-1];before_gems=game.gems
	game.rewarded_requests[request].extension_fallback_gems=10
	check(game.save_player_progress(),"Pre-update ten-diamond promise persists independently of the new price")
	video.rewarded_earned.emit(request)
	loaded=restored(game.test_progress_path);loaded.retry_verified_rewards();loaded.retry_verified_rewards()
	check(loaded.gems==before_gems+10 and loaded.rewarded_requests[request].status=="earned","Old ten-diamond promised fallback survives the price change exactly once")
	loaded.free();game.rewarded_requests[request].status="earned";game.verified_rewards_waiting.erase(request)
	video.rewarded_closed.emit(request);game.back_home()

func diamond_videos(video:Video)->void:
	game.back_home();game.diamond_video_ready_at=0
	var before_gems:int=game.gems;var requests:int=video.requests.size()
	check(game.request_diamond_video().ok and video.requests.size()==requests+1,"Home diamond offer opens an actual accepted SDK request")
	var request:String=video.requests[-1]
	check(not game.claim_shop_gift().ok,"Legacy gift entry cannot grant free or duplicate diamonds")
	video.rewarded_closed.emit(request)
	check(game.gems==before_gems and game.diamond_video_cooldown_remaining()==0,"Closing without earned completion grants nothing and starts no cooldown")
	video.rewarded_earned.emit(request)
	check(game.gems==before_gems+3 and game.diamond_video_cooldown_remaining()>119,"Earned video commits three diamonds and starts 120-second cooldown")
	var loaded:=restored(game.test_progress_path)
	check(loaded.gems==game.gems and loaded.diamond_video_cooldown_remaining()>119 and not loaded.request_diamond_video().ok,"Diamond balance and cooldown survive restart")
	loaded.free()
	video.rewarded_earned.emit(request);game.credit_round_double(request)
	check(game.gems==before_gems+3 and not game.request_diamond_video().ok,"Duplicate completion and cooldown taps cannot grant additional diamonds")
	game.diamond_video_ready_at=0
	check(game.claim_shop_gift().ok,"Legacy gift now routes to the genuine rewarded-video offer")
	request=video.requests[-1];before_gems=game.gems
	var saved_path:String=game.test_progress_path;game.test_progress_path=base+"-missing/reward.cfg"
	video.rewarded_earned.emit(request)
	check(game.gems==before_gems and game.diamond_video_ready_at==0 and game.verified_rewards_waiting.has(request),"Failed earned-marker save changes neither diamonds nor cooldown")
	video.rewarded_closed.emit(request);game.test_progress_path=saved_path
	check(game.save_player_progress(),"Verified pending reward can be stored after disk recovery")
	loaded=restored(saved_path);loaded.retry_verified_rewards()
	check(loaded.gems==before_gems+3 and loaded.rewarded_requests[request].status=="earned" and loaded.diamond_video_cooldown_remaining()>119,"Persisted earned marker settles once after restart and storage recovery")
	loaded.retry_verified_rewards();check(loaded.gems==before_gems+3,"Recovered diamond reward remains idempotent")
	loaded.free()
	game.rewarded_requests[request].status="earned";game.verified_rewards_waiting.erase(request)
	video.ready=false;game.diamond_video_ready_at=0
	check(not game.request_diamond_video().ok and game.gems==before_gems,"Unavailable ad provider never simulates a diamond grant")
	video.ready=true;video.accepted=false
	check(not game.request_diamond_video().ok,"Rejected SDK invocation is unavailable")
	request=video.requests[-1];video.rewarded_earned.emit(request)
	check(game.gems==before_gems,"A callback from a rejected ad invocation cannot reward")
	video.accepted=true

func diamond_ledger_bound()->void:
	var owner:=Game.new();owner.test_progress_path=path("bounded-video-ledger")
	owner.ads=Ads.new();owner.add_child(owner.ads)
	var video:=Video.new();check(owner.ads.bind_test_native(video),"Ledger fixture binds the actual isolated reward protocol")
	owner.ads.rewarded_completed.connect(owner.credit_round_double);owner.ads.rewarded_closed.connect(owner.reward_video_closed);owner.ads.rewarded_failed.connect(owner.reward_video_failed);owner.ads.initialize()
	for index in 45:
		owner.diamond_video_ready_at=0
		if not owner.request_diamond_video().ok:
			check(false,"Sequential completed video request accepted");break
		var request:String=video.requests[-1]
		video.rewarded_earned.emit(request);video.rewarded_closed.emit(request)
	check(owner.round_receipt.is_empty() and owner.gems==145 and owner.rewarded_requests.size()==32,"Forty-five real earned standalone videos retain only32terminalbindings before any round exists")
	var before_gems:int=owner.gems
	owner.credit_round_double(video.requests[0]);video.rewarded_earned.emit(video.requests[0])
	check(owner.gems==before_gems and not owner.rewarded_requests.has(video.requests[0]),"An aged-out completed callback cannot recreate its missing reward binding")
	for status in ["loading","reward_due","earned","closed"]:
		owner.rewarded_requests["protected-"+status]={"purpose":"diamonds","round":"","status":status,"closed":status=="closed","authenticated":status=="reward_due"}
	owner.verified_rewards_waiting.append("protected-reward_due")
	owner.reward_receipts["legacy-round"]={"id":"legacy-round","map":"city","base_coins":5,"settled":true}
	for purpose in ["double","extension"]:
		owner.rewarded_requests["legacy-"+purpose]={"purpose":purpose,"round":"legacy-round","status":"earned","closed":true}
	owner.rewarded_requests["next-failed"]={"purpose":"diamonds","round":"","status":"loading","closed":false}
	owner.reward_video_failed("next-failed","Controlled SDK failure")
	check(owner.rewarded_requests.size()==38,"Only terminal diamond entries count toward32cap; protected and legacy bindings survive")
	for status in ["loading","reward_due","earned","closed"]:
		check(owner.rewarded_requests.has("protected-"+status),"Ledger pruning retains protected "+status+" callback binding")
	check(owner.verified_rewards_waiting.has("protected-reward_due") and owner.rewarded_requests.has("legacy-double") and owner.rewarded_requests.has("legacy-extension"),"Pruning preserves authenticated work and all old round purposes")
	var cfg:=ConfigFile.new();cfg.load(owner.test_progress_path)
	var saved_requests:Dictionary=cfg.get_value("rewards","video_requests",{}).duplicate(true)
	for index in 45:saved_requests["old-terminal-%d"%index]={"purpose":"diamonds","round":"","status":"failed","closed":true}
	cfg.set_value("rewards","video_requests",saved_requests)
	check(cfg.save(owner.test_progress_path)==OK,"Oversized historical standalone ledger fixture writes")
	var loaded:=restored(owner.test_progress_path)
	var terminal:=0
	for request in loaded.rewarded_requests.values():
		if request.get("purpose","")=="diamonds" and (request.get("status","")=="failed" or (request.get("status","")=="earned" and request.get("closed",false))):terminal+=1
	check(terminal==32 and loaded.progress_dirty,"Loading also bounds terminal historical entries and schedules durable cleanup")
	check(loaded.rewarded_requests.has("protected-reward_due") and loaded.verified_rewards_waiting.has("protected-reward_due") and loaded.rewarded_requests.has("protected-closed") and loaded.rewarded_requests.has("protected-loading"),"Restart pruning preserves earned work and possible late earned callbacks")
	check(loaded.rewarded_requests.has("legacy-double") and loaded.rewarded_requests.has("legacy-extension") and loaded.gems==before_gems,"Restart pruning never removes legacy round bindings or changes wallet balance")
	loaded.free();owner.free()

func legacy_and_purchases()->void:
	var old_path:=path("legacy");var cfg:=ConfigFile.new()
	cfg.set_value("progress","skin_schema",3);cfg.set_value("progress","coins",12345);cfg.set_value("progress","gems",777)
	cfg.set_value("progress","owned_skin_ids",["tide","core_shell"]);cfg.set_value("progress","selected_skin_id","tide")
	cfg.set_value("progress","shop_gift_claimed_stage",99);cfg.set_value("custom","keep_me","untouched")
	cfg.set_value("rewards","purchases",{"legacy-transaction":"sink_city.coins_320"})
	check(cfg.save(old_path)==OK,"Legacy wallet fixture writes")
	var owner:=restored(old_path)
	check(owner.coins==12345 and owner.gems==777 and owner.shop_gift_claimed_stage==99 and owner.selected_skin_id=="tide" and owner.skin_unlocked("core_shell"),"Economy migration preserves existing currencies, claim marker, skins and purchases")
	check(not owner.claim_shop_gift().ok and owner.gems==777,"Absent SDK never reintroduces the removed free stage gift")
	owner.credit_verified_purchase("new-diamond-transaction","sink_city.diamonds_60")
	check(owner.gems==837 and owner.coins==12345,"Verified diamond product credits its diamond currency only")
	owner.credit_verified_purchase("new-diamond-transaction","sink_city.diamonds_60")
	check(owner.gems==837,"Duplicate diamond StoreKit transaction cannot grant twice")
	var acknowledgments:=Acknowledgments.new();owner.commerce=acknowledgments;owner.add_child(acknowledgments)
	owner.credit_verified_purchase("legacy-transaction","sink_city.diamonds_1800")
	check(owner.coins==12345 and owner.gems==837 and acknowledgments.ids.is_empty(),"Conflicting cross-process product binding cannot be credited or acknowledged")
	owner.credit_verified_purchase("legacy-transaction","sink_city.coins_320")
	check(owner.coins==12345 and acknowledgments.ids==["legacy-transaction"],"Already redeemed matching legacy transaction stays credited once and can be acknowledged")
	owner.credit_verified_purchase("new-legacy-coin-transaction","sink_city.coins_320")
	check(owner.coins==12665 and owner.gems==837,"Unfinished genuine legacy coin product still credits its original coin amount")
	check(owner.save_player_progress(),"Mixed wallet preserves unrelated saved settings")
	cfg=ConfigFile.new();cfg.load(old_path)
	check(cfg.get_value("custom","keep_me")=="untouched","Atomic saving retains unknown legacy settings")
	owner.gems=1000;owner.coins=0;owner.last_shop_msec=-1000
	check(owner.buy_coin_pack(0).ok and owner.gems==900 and owner.coins==2000,"First exchange spends100diamonds for2000coins")
	owner.last_shop_msec=-1000
	check(owner.buy_coin_pack(1).ok and owner.gems==650 and owner.coins==7000,"Second exchange spends250diamonds for5000coins")
	owner.gems=1000;owner.last_shop_msec=-1000
	check(owner.buy_coin_pack(2).ok and owner.gems==0 and owner.coins==27000,"Third exchange spends1000diamonds for20000coins")
	owner.test_progress_path=base+"-missing/purchase.cfg"
	var prior_ack_count:=acknowledgments.ids.size()
	owner.credit_verified_purchase("failed-diamond-transaction","sink_city.diamonds_360")
	check(owner.gems==0 and not owner.redeemed_transactions.has("failed-diamond-transaction") and acknowledgments.ids.size()==prior_ack_count,"Failed purchase save rolls back diamonds and leaves verified store transaction unacknowledged")
	owner.free()

func entry_pack_funds_twenty_draws()->void:
	var owner:=FaultySaveGame.new();owner.test_progress_path=path("entry-pack")
	var acknowledgments:=Acknowledgments.new();owner.commerce=acknowledgments;owner.add_child(acknowledgments)
	owner.coins=0;owner.gems=0;owner.fail_on_save=1
	owner.credit_verified_purchase("entry-100-transaction","sink_city.diamonds_100")
	check(owner.coins==0 and owner.gems==0 and not owner.redeemed_transactions.has("entry-100-transaction") and acknowledgments.ids.is_empty(),"A failed100-diamond wallet write neither grants nor acknowledges the new product")
	owner.fail_on_save=0
	owner.credit_verified_purchase("entry-100-transaction","sink_city.diamonds_100")
	owner.credit_verified_purchase("entry-100-transaction","sink_city.diamonds_100")
	check(owner.gems==100 and owner.coins==0 and owner.redeemed_transactions["entry-100-transaction"]=="sink_city.diamonds_100","Verified entry-product redelivery credits exactly100diamonds once after storage recovers")
	owner.last_shop_msec=-1000
	check(owner.buy_coin_pack(0).ok and owner.coins==2000 and owner.gems==0,"One real100-diamond exchange turns the entry pack into exactly2000coins")
	var owned:int=owner.owned_skin_ids.size()
	for index in 20:
		owner.last_unlock_msec=-1000
		var draw:Dictionary=owner.unlock_random_skin("collection")
		check(draw.ok and draw.price==100 and owner.owned_skin_ids.size()==owned+index+1,"The entry pack funds actual unique skin draw "+str(index+1))
	owner.last_unlock_msec=-1000
	var shortage:Dictionary=owner.unlock_random_skin("collection")
	check(owner.coins==0 and not shortage.ok and shortage.get("missing_coins")==100,"Exactly twenty draws exhaust the entry pack; a twenty-first draw is unaffordable")
	var loaded:=restored(owner.test_progress_path)
	check(loaded.coins==0 and loaded.gems==0 and loaded.owned_skin_ids==owner.owned_skin_ids and loaded.redeemed_transactions==owner.redeemed_transactions,"Entry credit, one exchange and twenty draw entitlements survive cold restart together")
	loaded.free();owner.free()

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.test_progress_path=path("main")
	game.ads.free();game.ads=Ads.new();game.add_child(game.ads)
	var video:=Video.new();check(game.ads.bind_test_native(video),"Explicit isolated test binds protocol-valid video provider")
	game.ads.rewarded_completed.connect(game.credit_round_double);game.ads.rewarded_closed.connect(game.reward_video_closed);game.ads.rewarded_failed.connect(game.reward_video_failed);game.ads.initialize()
	completion_funds_actual_draw();timing_and_debit();coin_boost_and_continuation(video);coin_boost_restart_failure();video_continuation(video);diamond_videos(video);diamond_ledger_bound();legacy_and_purchases();entry_pack_funds_twenty_draws()
	game.free();await process_frame
	for value in paths:
		if FileAccess.file_exists(value):DirAccess.remove_absolute(value)
	var result:={"checks":checks,"failures":failures}
	print("ECONOMY_CONTINUATION_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
