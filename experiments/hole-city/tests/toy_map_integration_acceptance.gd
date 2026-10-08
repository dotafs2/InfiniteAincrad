extends SceneTree
## Cold launch, real Home controls, isolated legacy saves and same-world time.
## The video provider is an explicit local protocol fixture, never a live SDK.
const Game=preload("res://fidelity/game.gd")
const ToyCity=preload("res://fidelity/toy_city.gd")
const Growth=preload("res://fidelity/hole.gd")
const Catalog=preload("res://fidelity/map_catalog.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
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
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var paths:Array[String]=[]
var base:="/tmp/hole-toy-map-integration-%d"%OS.get_process_id()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for _index in count:await process_frame
func path(label:String)->String:
	var value:=base+"-"+label+".cfg"
	for suffix in ["",".tmp",".pre-coins.cfg"]:paths.append(value+suffix)
	return value
func target(id:String)->Button:
	for button in game.ui.buttons:
		if button.name==id or button.text==id:return button
	return null
func click(id:String)->void:
	var button:=target(id)
	check(button!=null,"Actual Home exposes "+id)
	if button==null:return
	var at:Vector2=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true);await frames()
func playback_id()->int:
	return game.audio.music.get_stream_playback().get_instance_id() if game.audio.music.has_stream_playback() else 0
func descendants(owner:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in owner.get_children():
		result.append(child);result.append_array(descendants(child))
	return result

func inspect_home_audio()->void:
	var available:Array[String]=[]
	for definition in Catalog.DEFS:
		if definition.available:available.append(definition.id)
	check(available==["city","food","toys","frost"] and game.MAPS.keys()==available,"Four available maps retain city/food/toys IDs and add Frostlight in order")
	check(game.selected_map=="toys" and game.ui.map_carousel.current_id()=="toys" and game.ui.map_carousel.photos.size()==4 and not is_instance_valid(game.world) and game.holes.is_empty(),"Cold Toy selection focuses its static screenshot without constructing a playable world")
	check(not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Cold Home keeps the old map viewport disabled")
	check(game.audio.current_map=="toys" and game.audio.music.stream is AudioStreamOggVorbis and game.audio.music.stream.get_length()>25 and game.audio.music.stream.loop,"Cold toy launch assigns the actual encoded looping music instead of a missing map key")
	var controls:Array[Button]=[]
	for id in ["home-play","map-previous","map-next"]:
		var button:=target(id)
		check(button!=null and not button.disabled,"Actual Home has an enabled "+id+" control at the middle Toy card")
		if button==null:continue
		controls.append(button)
		check(minf(button.size.x,button.size.y)*375.0/540.0>=44 and root.get_visible_rect().encloses(button.get_global_rect()),id+": target fits the portrait viewport and reaches44phone points")
	check(controls.size()==3 and not controls[0].get_rect().intersects(controls[1].get_rect()) and not controls[1].get_rect().intersects(controls[2].get_rect()) and not controls[0].get_rect().intersects(controls[2].get_rect()),"PLAY and the two real arrow hit regions remain distinct")
	var coins:int=game.coins;var gems:int=game.gems
	var stream:int=game.audio.music.stream.get_instance_id()
	await click("map-previous")
	check(game.selected_map=="food" and game.ui.map_carousel.current_id()=="food" and game.audio.current_map=="food","Actual previous-arrow release selects Snack Garden")
	await click("map-previous")
	check(game.selected_map=="city" and game.audio.current_map=="city" and target("map-previous").disabled,"Actual previous-arrow release selects City and disables the lower boundary")
	await click("map-next")
	check(game.selected_map=="food" and game.audio.current_map=="food","Actual next-arrow release advances from City to Food")
	await click("map-next")
	check(game.selected_map=="toys" and game.ui.map_carousel.current_id()=="toys" and game.audio.current_map=="toys","The next arrow reaches Toy Town's real screenshot and audio route")
	var decoder:int=playback_id()
	check(decoder!=0 and game.audio.unlocked and game.audio.music.playing,"Actual GUI releases unlock one real stream playback object")
	print("TOY_MAP_AUDIO_DIAGNOSTIC "+JSON.stringify({"phase":"before_seek","stream":game.audio.music.stream.get_instance_id(),"decoder":decoder,"position":game.audio.music.get_playback_position(),"playing":game.audio.music.playing,"paused":game.audio.music.stream_paused,"bookmark":game.audio.bookmark}))
	game.audio.music.seek(2.5);await frames(6)
	print("TOY_MAP_AUDIO_DIAGNOSTIC "+JSON.stringify({"phase":"after_seek","stream":game.audio.music.stream.get_instance_id(),"decoder":playback_id(),"position":game.audio.music.get_playback_position(),"playing":game.audio.music.playing,"paused":game.audio.music.stream_paused,"bookmark":game.audio.bookmark}))
	decoder=playback_id()
	check(decoder!=0 and game.audio.music.get_playback_position()>=2.4,"The actual settled seek establishes a live decoder and nonzero bookmark before map-preservation checks")
	var photo_owners:Array[WeakRef]=[]
	for photo in game.ui.map_carousel.photos:photo_owners.append(weakref(photo))
	for expected in ["frost","toys","food","city"]:
		await click("map-next" if expected=="frost" else "map-previous")
		check(game.selected_map==expected and game.audio.current_map==expected,"Arrow navigation reaches "+expected+" through the available-map order")
		check(photo_owners.all(func(owner):return owner.get_ref()!=null) and game.ui.map_carousel.find_children("*","SubViewport",true,false).is_empty() and not descendants(game.ui.map_carousel).any(func(node):return node is CollisionObject3D or node is CollisionShape3D),expected+": the same four static screenshot owners persist without viewport or physics allocations")
		print("TOY_MAP_AUDIO_DIAGNOSTIC "+JSON.stringify({"phase":"arrow","map":expected,"expected_stream":stream,"actual_stream":game.audio.music.stream.get_instance_id(),"after_seek_decoder":decoder,"actual_decoder":playback_id(),"position":game.audio.music.get_playback_position(),"playing":game.audio.music.playing,"paused":game.audio.music.stream_paused,"bookmark":game.audio.bookmark}))
		check(game.audio.music.stream.get_instance_id()==stream and playback_id()==decoder and game.audio.music.get_playback_position()>=2.4,expected+": screenshot navigation preserves the same music stream, decoder and playback position")
	check(game.coins==coins and game.gems==gems and game.holes.is_empty() and not is_instance_valid(game.world),"Preview navigation cannot mutate the wallet or instantiate a full world")
	await click("holes-nav")
	check(not game.ui.map_carousel.visible and not game.ui.map_carousel.is_processing() and not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Opening the collection hides and stops map-card animation while the live viewport remains disabled")
	await click("holes-home")
	check(game.ui.map_carousel.visible and game.ui.map_carousel.is_processing() and not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Returning Home resumes only the screenshot row, never live map rendering")
	game.select_map("animals");game.select_map("not-a-map")
	check(game.selected_map=="city","Future and unknown map IDs cannot replace the active selection")
	metrics.home={"available_maps":available,"cards":game.ui.map_carousel.photos.size(),"stream_preserved":game.audio.music.stream.get_instance_id()==stream,"scope":"Real screenshot resources and engine stream ownership only; no audible speaker or browser autoplay claim"}

func inspect_saved_compatibility()->void:
	for old_map in ["city","food"]:
		var saved_path:=path("legacy-"+old_map);var cfg:=ConfigFile.new()
		cfg.set_value("progress","skin_schema",3);cfg.set_value("progress","map",old_map)
		cfg.set_value("progress","coins",243);cfg.set_value("progress","gems",17)
		cfg.set_value("progress","stage",8);cfg.set_value("progress","completed_runs",7)
		cfg.set_value("progress","best_scores",{"city":720,"food":830})
		cfg.set_value("progress","owned_skin_ids",["tide","core_shell"]);cfg.set_value("progress","selected_skin_id","core_shell")
		cfg.set_value("audio","music_enabled",false);cfg.set_value("audio","haptics_enabled",false)
		cfg.set_value("rewards","rounds",{"old-city":{"id":"old-city","map":"city","base_coins":12,"settled":true},"old-food":{"id":"old-food","map":"food","base_coins":14,"settled":true}})
		cfg.set_value("rewards","purchases",{"old-coin-transaction":"sink_city.coins_320","old-diamond-transaction":"sink_city.diamonds_60"})
		cfg.set_value("custom","keep_me","untouched")
		check(cfg.save(saved_path)==OK,old_map+": isolated pre-toy save fixture writes")
		var owner:=Game.new();owner.test_progress_path=saved_path
		check(owner.load_player_progress(),old_map+": existing progress loads without a real-save read")
		check(owner.selected_map==old_map and owner.coins==243 and owner.gems==17 and owner.stage==8 and owner.completed_runs==7,old_map+": adding a map preserves the existing selected map, wallet and completed progress")
		check(owner.best_scores.city==720 and owner.best_scores.food==830 and owner.best_scores.toys==0,old_map+": legacy best scores survive and the new map starts at zero")
		check(owner.selected_skin_id=="core_shell" and owner.skin_unlocked("core_shell") and not owner.music_enabled and not owner.haptics_enabled,old_map+": owned skins, equipped skin and preferences remain intact")
		check(owner.reward_receipts.has("old-city") and owner.reward_receipts.has("old-food") and owner.redeemed_transactions.size()==2,old_map+": legacy round and mixed-currency purchase receipts remain bound")
		# This step models a newly earned Toy entitlement before testing storage;
		# a current-schema selected thumbnail alone cannot unlock another map.
		owner.unlocked_map_ids=["city","food","toys"]
		owner.selected_map="toys";owner.best_scores.toys=950
		check(owner.save_player_progress(),old_map+": new map selection commits in the same isolated save")
		owner.free();owner=Game.new();owner.test_progress_path=saved_path
		check(owner.load_player_progress() and owner.selected_map=="toys" and owner.best_scores.toys==950 and owner.best_scores.city==720 and owner.best_scores.food==830,old_map+": toy selection and independent best score survive restart without overwriting old scores")
		check(owner.coins==243 and owner.gems==17 and owner.redeemed_transactions.size()==2 and owner.reward_receipts.size()==2,old_map+": saving the new map never replays or deletes old rewards")
		cfg=ConfigFile.new();cfg.load(saved_path)
		check(cfg.get_value("custom","keep_me","")=="untouched",old_map+": atomic saving preserves unrelated legacy sections")
		owner.free()
	for unavailable in ["animals","not-a-map"]:
		var saved_path:=path("unavailable-"+unavailable);var cfg:=ConfigFile.new()
		cfg.set_value("progress","skin_schema",3);cfg.set_value("progress","map",unavailable)
		cfg.set_value("progress","coins",243);cfg.set_value("progress","gems",17)
		check(cfg.save(saved_path)==OK,unavailable+": isolated invalid-selection fixture writes")
		var owner:=Game.new();owner.test_progress_path=saved_path
		check(owner.load_player_progress() and owner.selected_map=="city" and owner.coins==243 and owner.gems==17,unavailable+": unknown or locked saved map falls back safely without resetting money")
		owner.free()

func quiet_world()->void:
	game.set_process(false);game.set_physics_process(false)
	game.city.process_mode=Node.PROCESS_MODE_DISABLED
	for hole in game.holes:
		hole.enabled=false;hole.set_process(false);hole.set_physics_process(false)
		if hole!=game.player:hole.active=false
func fixture_score(score:int)->void:
	game.player.score=score;game.player.level=Growth.level_for_score(score)
	game.player.radius=Growth.radius_for_level(game.player.level);game.player._sync_shape()
func toy_round(score:int)->void:
	game.selected_map="toys";game.start_level();game.begin_play();quiet_world();fixture_score(score)
func expire(seconds:float)->void:game._physics_process(seconds)

func inspect_duration_continuation()->void:
	check(game.map_round_seconds("city")==90.0 and game.map_round_seconds("food")==60.0 and game.map_round_seconds("toys")==90.0 and game.map_round_seconds("frost")==90.0,"Toy timing adds 90 seconds while retaining original city and food durations")
	toy_round(800);game.gems=10
	check(game.city is ToyCity and game.train_controller==null and game.train_tracks==null and game.holes.size()==8,"PLAY builds Toy Town plus seven rivals without attaching the old city tram")
	check(game.remaining==90.0 and game.round_duration()==90.0 and not game.ui.hero.visible,"Toy play starts at exactly 90 seconds with its menu preview suspended")
	var original_world:Node3D=game.world;var original_city:Node3D=game.city
	var wallet:int=game.coins;var stage:int=game.stage;var runs:int=game.completed_runs
	expire(89.75)
	check(game.phase=="playing" and is_equal_approx(game.remaining,.25),"Controlled timer fixture retains the final quarter second of the 90-second round")
	expire(.26)
	check(game.phase=="complete" and game.remaining==0 and game.round_coins==80 and game.coins==wallet+80,"800-point timeout settles 80 coins")
	check(game.round_receipt.map=="toys" and game.best_scores.toys>=800 and game.stage==stage+1 and game.completed_runs==runs+1,"Toy completion records its map ID, independent score and one completion")
	var receipt:String=game.round_receipt.id;var serial:int=game.round_serial
	game.eaten=23;game.kills=2
	check(game.request_round_extension_gems().ok,"The timed toy result accepts the two-diamond continuation")
	check(game.world==original_world and game.city==original_city and game.phase=="playing" and game.remaining==30.0 and game.player.score==800 and game.eaten==23 and game.kills==2,"Continuation preserves the same world and score for exactly 30 more seconds")
	check(game.gems==8 and game.extension_used and game.round_receipt.id==receipt,"The diamond debit and one continuation stay bound to the original receipt")
	fixture_score(1700);expire(30.01)
	check(game.coins==wallet+170 and game.round_coins==170 and game.round_serial==serial and game.stage==stage+1 and game.completed_runs==runs+1,"Continuation credits only its 90 new coins without duplicating stage or round")
	check(not game.can_extend_round() and not game.request_round_extension_gems().ok and not game.request_round_extension_video().ok,"A toy round cannot buy or watch a second continuation")
	var final_wallet:int=game.coins;game.finish("complete")
	check(game.coins==final_wallet,"Repeated completion cannot pay the toy round again")
	metrics.timing={"base_seconds":90,"extension_seconds":30,"scope":"Explicit timer/score fixture, separate from normal real-time play"}

func inspect_local_video()->void:
	game.ads.free();game.ads=Ads.new();game.add_child(game.ads)
	var video:=Video.new()
	check(game.ads.bind_test_native(video),"An explicit test flag binds only the local protocol video fixture")
	game.ads.rewarded_completed.connect(game.credit_round_double)
	game.ads.rewarded_closed.connect(game.reward_video_closed)
	game.ads.rewarded_failed.connect(game.reward_video_failed);game.ads.initialize()
	toy_round(200);expire(90.01)
	var original_world:Node3D=game.world;var wallet:int=game.coins;var gems:int=game.gems
	check(game.request_round_extension_video().ok and game.reward_video_pending(),"A completed toy round persists an accepted local video request")
	var request:String=video.requests[-1]
	video.rewarded_earned.emit(request)
	check(game.phase=="complete" and game.remaining==0 and game.reward_video_pending() and game.coins==wallet and game.gems==gems,"Earned-before-close keeps the toy world stopped behind the video without a fake wallet grant")
	video.rewarded_closed.emit(request)
	check(game.phase=="playing" and game.remaining==30 and game.world==original_world and game.coins==wallet and game.gems==gems,"An actual earned-plus-close fixture resumes the same toy world without spending currency")
	video.rewarded_earned.emit(request);video.rewarded_closed.emit(request)
	check(game.remaining==30 and game.coins==wallet and game.gems==gems,"Duplicate toy video callbacks cannot grant another extension or currency")
	expire(30.01);toy_round(200);expire(90.01)
	check(game.request_round_extension_video().ok,"A separate toy run opens its own bound local request")
	request=video.requests[-1];video.rewarded_closed.emit(request)
	check(game.phase=="complete" and game.remaining==0 and not game.extension_used,"Closing an unearned video cannot add any toy play time")
	metrics.video={"requests":video.requests.size(),"provider":"Local controlled protocol fixture; no SDK traffic or ad-duration claim"}

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	game=Game.new();game.selected_map="toys";game.test_progress_path=path("main")
	root.add_child(game);game.set_process(false);game.set_physics_process(false);await frames(4)
	await inspect_home_audio();inspect_saved_compatibility()
	inspect_duration_continuation();inspect_local_video()
	# The headless scene ends faster than the separate streamed-audio mixer.
	# Drain only this fixture-owned player, as in the existing music reviews.
	game.audio.music.stop();OS.delay_msec(150)
	game.free();await process_frame
	for value in paths:
		if FileAccess.file_exists(value):DirAccess.remove_absolute(value)
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Cold launch and actual pointer controls, isolated saves, explicit same-world timing/video fixtures; no live ads, purchases, phone or ordinary gameplay pacing claim"}
	print("TOY_MAP_INTEGRATION_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
