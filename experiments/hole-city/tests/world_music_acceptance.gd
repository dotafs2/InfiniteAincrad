extends SceneTree
## Independent six-route and lifecycle review. Run with --audio-driver Dummy.
## All progression is memory-only; no real SDK, user save, or audible QA.
const Audio=preload("res://fidelity/audio.gd")
const Game=preload("res://fidelity/game.gd")
const ROUTES:Array[String]=["menu","city","food","toys","frost","case"]
const MAPS:Array[String]=["city","food","toys","frost"]
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
var audio:Node
var game:Node3D
var master_volume:=0.0

class ReviewAds:
	extends Node
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	var audio_controller:Node
	var muted_at_native_show:=false
	func sink_city_rewarded_protocol_version()->int:return 1
	func initialize()->void:pass
	func rewarded_available()->bool:return true
	func show_rewarded(_request_id:String)->bool:
		muted_at_native_show=audio_controller.music.stream_paused and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
		return true

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=3)->void:
	for _i in count:await process_frame
func settle()->void:
	# This timer uses engine time, including fixed-fps runners, and always
	# processes so independent tree-pause behavior can be reviewed safely.
	await create_timer(.75,true,false,true).timeout
	await frames()
func can_output(owner:Node)->bool:
	var voice:AudioStreamPlayer=owner.music
	return voice.playing and not voice.stream_paused and voice.can_process() and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
func music_voices(owner:Node)->Array[Node]:
	return owner.find_children("*","AudioStreamPlayer",true,false).filter(func(voice):return voice.bus==&"Music")
func route(owner:Node,id:String,label:String)->void:
	check(owner.current_track==id and owner.target_track==id,label+": current and requested music route are "+id)
	check(music_voices(owner).size()==1,label+": exactly one persistent Music voice exists")
func decoder_id(owner:Node)->int:
	return owner.music.get_stream_playback().get_instance_id() if owner.music.has_stream_playback() else 0
func native_boundary(stream:AudioStreamOggVorbis,id:String)->void:
	# Review the actual controller-installed stream in a separate bounded
	# memory decoder. No sample is sent to an output player or physical device.
	var decoder:AudioStreamPlayback=stream.instantiate_playback()
	decoder.start(stream.get_length()-.05)
	var samples:PackedVector2Array=decoder.mix_audio(1.0,int(AudioServer.get_mix_rate()*.4))
	var peak:=0.0;var energy:=0.0;var finite:=true
	for sample in samples:
		finite=finite and sample.is_finite()
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		energy+=sample.length_squared()
	check(samples.size()>1000 and finite and energy>.0001 and peak<.8,id+": native decoder returns actual finite, non-silent, unclipped samples across the boundary")
	check(decoder.get_loop_count()>=1,id+": actual native decoder crosses the encoded loop end")
	check(decoder.is_playing() and decoder.get_playback_position()<1.0,id+": native decoder continues into the next phrase start")
	if not evidence.has("map_boundary_decodes"):evidence["map_boundary_decodes"]=[]
	evidence.map_boundary_decodes.append({"map":id,"frames":samples.size(),"peak":peak,"energy":energy,"loops":decoder.get_loop_count(),"position":decoder.get_playback_position()})
	decoder.stop();check(not decoder.is_playing(),id+": bounded review decoder releases playback")

func resources()->void:
	check(Audio.TRACKS.size()==6,"Production registry contains exactly six music roles")
	var seen:Dictionary={}
	var total_bytes:=0
	var measurements:Array[Dictionary]=[]
	for id in ROUTES:
		check(Audio.TRACKS.has(id),"Production registry contains "+id)
		if not Audio.TRACKS.has(id):continue
		var stream:AudioStream=Audio.TRACKS[id]
		check(stream is AudioStreamOggVorbis,id+": actual imported resource is Ogg Vorbis")
		if not stream is AudioStreamOggVorbis:continue
		var length:=stream.get_length()
		check(length>= (4.25 if id=="case" else 20.0) and length<=180.0,id+": complete musical phrase has a bounded duration")
		var packets=stream.packet_sequence.get("packet_data")
		check(packets is Array and not packets.is_empty(),id+": actual import contains compressed audio packets")
		var bytes:=var_to_bytes(packets)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		var digest:=hash.finish().hex_encode()
		check(not seen.has(digest),id+": recording is distinct from every other role")
		seen[digest]=true;total_bytes+=bytes.size()
		check(bytes.size()<3*1024*1024,id+": encoded packet storage is below3MiB")
		measurements.append({"route":id,"duration":length,"packet_bytes":bytes.size(),"packet_sha256":digest})
	check(seen.size()==6,"All six real encoded recordings are unique")
	check(total_bytes<12*1024*1024,"Six compressed packet resources together remain below12MiB")
	evidence["tracks"]=measurements;evidence["total_packet_bytes"]=total_bytes

func controller_routes()->void:
	audio=Audio.new();root.add_child(audio);await frames()
	check(not audio.unlocked and not can_output(audio),"Initial saved-ON controller does not bypass desktop/Web gesture gate")
	check(audio.music.playback_type==AudioServer.PLAYBACK_TYPE_STREAM and audio.music.max_polyphony==1,"Actual persistent player streams one voice instead of full Web Audio sample decoding")
	var voice_id:int=audio.music.get_instance_id()
	route(audio,"menu","Initial controller")
	for id in MAPS:
		audio.set_map(id);await settle()
		route(audio,"menu",id+" selected before a user gesture")
		check(not can_output(audio),id+": map browsing cannot unlock audio")
	audio.unlock_from_gesture();await settle()
	check(can_output(audio),"Deliberate gesture admits enabled menu music")
	var menu_decoder:=decoder_id(audio)
	for id in MAPS:audio.set_map(id);audio.set_context("menu")
	await settle()
	check(decoder_id(audio)==menu_decoder,"Repeated menu requests and selected maps preserve the actual menu decoder")
	audio.set_map("invalid");audio.set_context("invalid");await settle()
	check(audio.current_map=="frost" and decoder_id(audio)==menu_decoder,"Unknown map/context leave the valid selection and decoder intact")
	for id in MAPS:
		audio.set_map(id);audio.set_context("gameplay");await settle()
		route(audio,id,"Actual controller world route")
		check(can_output(audio) and audio.music.stream.loop and audio.music.stream.loop_offset==0.0,id+": effective imported track plays and loops from zero")
		native_boundary(audio.music.stream,id)
		var playback:=decoder_id(audio)
		audio.set_map(id);audio.set_context("gameplay");await frames()
		check(decoder_id(audio)==playback,id+": repeated effective route does not restart its decoder")
	var outgoing_stream:AudioStream=audio.music.stream
	var outgoing_db:float=audio.music.volume_db
	audio.set_context("menu")
	check(audio.music.stream==outgoing_stream,"An audible route request retains the outgoing stream until its fade completes")
	await create_timer(.08,true,false,true).timeout
	check(audio.music.stream==outgoing_stream and audio.music.volume_db<outgoing_db-.2,"Outgoing music measurably fades before the stream is exchanged")
	await settle();route(audio,"menu","Completed fade transition")
	audio.set_context("menu");audio.set_map("city");audio.set_context("gameplay")
	await frames(2)
	audio.set_context("case");audio.set_map("food");audio.set_context("gameplay")
	audio.set_context("menu");audio.set_map("toys");audio.set_context("case")
	await settle()
	route(audio,"case","Rapid route changes")
	check(audio.music.get_instance_id()==voice_id,"All route changes reuse the original Music player")
	var normal_db:float=audio.music.volume_db
	audio.set_case_rolling(true);await settle()
	var rolling_db:float=audio.music.volume_db
	check(rolling_db<=normal_db-5.0,"Rolling ducks case music by at least5dB for event detail")
	audio.set_case_rolling(false);await settle()
	check(absf(audio.music.volume_db-normal_db)<.5,"Ending the roll restores the previous case music level")
	evidence["case_duck_db"]=rolling_db-normal_db
	# Observe a deliberate nonzero real mixer position before leaving the route.
	audio.music.seek(3.0);OS.delay_msec(70);await frames()
	check(audio.music.get_playback_position()>2.5,"Bookmark oracle uses actual nonzero streamed playback")
	audio.set_context("menu");await settle();audio.set_context("case");await settle()
	check(audio.music.get_playback_position()>2.5,"Returning to case restores its existing musical bookmark")
	audio.music.seek(audio.music.stream.get_length()-.03);OS.delay_msec(160);await frames()
	var loop_at:float=audio.music.get_playback_position()
	check(audio.music.playing and loop_at>=0.0 and loop_at<1.0,"Actual streaming decoder crosses the encoded loop boundary")
	evidence["actual_loop_position"]=loop_at

func suspension()->void:
	audio.set_focused(false);audio.set_context("menu");await settle()
	check(not can_output(audio) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Focus loss silences music/effects during a transition")
	audio.set_app_suspended(true);audio.set_focused(true);await settle()
	check(not can_output(audio),"Focus-in cannot bypass outstanding app suspension")
	paused=true;audio.set_app_suspended(false);await settle()
	check(not can_output(audio),"App resume cannot bypass tree pause")
	audio.set_music_enabled(false);paused=false;await settle()
	check(not can_output(audio),"Tree resume cannot bypass saved music OFF")
	audio.set_context("gameplay");audio.set_map("frost");await settle()
	check(not can_output(audio),"Changing the desired track while muted cannot create audible output")
	audio.set_music_enabled(true);await settle()
	route(audio,"frost","Full independent suspension recovery")
	check(can_output(audio),"Output resumes only after every music suspension cause clears")
	audio.set_sfx_enabled(false);audio.set_focused(false);audio.set_focused(true);await settle()
	check(can_output(audio) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Focus restoration preserves independent SFX OFF while music resumes")
	audio.set_sfx_enabled(true)
	audio.music.stop();OS.delay_msec(100);audio.free();await frames()

func game_routes()->void:
	game=Game.new();root.add_child(game);game.set_physics_process(false);await frames()
	check(game.test_mode and game.test_progress_path.is_empty(),"Integration uses test-mode memory-only progression")
	game.audio.unlock_from_gesture();await settle()
	game.ui.pick_map("frost");await settle()
	route(game.audio,"menu","Locked Frost preview")
	check(game.selected_map=="city","Locked preview does not alter authorized selected world")
	game.ui.play_focused_map();await settle()
	check(game.phase=="title","Locked preview cannot start a real round")
	route(game.audio,"menu","Rejected locked launch")
	game.unlocked_map_ids=game.available_map_ids()
	for id in MAPS:
		game.select_map(id);await settle();route(game.audio,"menu",id+" selected in HOME")
		game.start_level();game.world.process_mode=Node.PROCESS_MODE_DISABLED;await settle()
		check(game.phase=="intro" and game.world.get_meta("map_id")==id,id+": actual requested world was instantiated")
		route(game.audio,id,id+" actual round intro")
		game.begin_play();await settle();route(game.audio,id,id+" actual playing phase")
		game.finish("timeout");await settle();route(game.audio,id,id+" actual settled results")
		game.back_home();await settle();route(game.audio,"menu",id+" actual return HOME")
	var menu_playback:=decoder_id(game.audio)
	game.ui.open_holes();game.ui.open_store();game.ui.open_settings();game.ui.close_menu();await settle()
	check(decoder_id(game.audio)==menu_playback,"Ordinary UI pages retain the menu decoder")
	game.coins=1000
	game.ui.request_unlock();await settle();route(game.audio,"case","Case READY page")
	game.ui.open_rates();await settle();route(game.audio,"case","Odds opened from the case")
	game.ui.close_rates();await settle();route(game.audio,"case","Return from case odds")
	var case_ui:Control=game.ui.case_opening
	var normal_db:float=game.audio.music.volume_db
	case_ui.begin_open();await settle()
	check(case_ui.stage=="rolling" and game.coins==900,"Actual memory-only case commits one draw before its roll")
	check(game.audio.music.volume_db<=normal_db-5.0,"Actual case roll ducks its music route")
	case_ui.reveal();await settle()
	check(absf(game.audio.music.volume_db-normal_db)<.5,"Actual SKIP/reveal restores the music mix")
	case_ui.back();await settle();route(game.audio,"menu","Case BACK returns to collection music")
	game.ui.request_unlock();await settle();route(game.audio,"case","Restored result route")
	check(case_ui.stage=="result" and game.coins==900,"Reopening a pending case restores its prior award without another charge")
	check(not case_ui.sound.tick_voice.playing and not case_ui.sound.accent_voice.playing,"Restored receipt plays no opening, tick, or rarity cue")
	game.audio.set_music_enabled(false);case_ui.sound.play_reveal("rare");await frames()
	check(not can_output(game.audio) and case_ui.sound.accent_voice.playing,"MUSIC OFF suppresses the score while deliberate SFX still works")
	case_ui.sound.stop_all();game.audio.set_sfx_enabled(false);game.audio.set_music_enabled(true);await settle()
	case_ui.sound.play_open();await frames()
	check(can_output(game.audio) and not case_ui.sound.accent_voice.playing,"SFX OFF suppresses case events while the score still works")
	game.audio.set_sfx_enabled(true);case_ui.back();game.ui.open_store();await settle()

func ad_routes()->void:
	var provider:=ReviewAds.new();provider.audio_controller=game.audio;game.add_child(provider)
	check(game.ads.bind_test_native(provider),"Isolated typed fake provider binds without a real SDK")
	game.ads.initialize()
	var request:Dictionary=game.request_diamond_video()
	check(request.get("ok",false) and game.ads.reward_in_flight,"Actual game ad request enters presentation lifetime")
	check(provider.muted_at_native_show,"Music and effects are suspended before the native presentation call")
	await frames()
	check(not can_output(game.audio),"Active rewarded overlay suppresses menu music without OS focus events")
	var id:String=game.ads._active_id
	provider.rewarded_closed.emit("unrelated-review-id");await frames()
	check(not can_output(game.audio) and game.ads.reward_in_flight,"Unrelated native close cannot release another overlay's suspension")
	provider.rewarded_earned.emit(id);await frames()
	check(not can_output(game.audio) and game.ads.reward_in_flight,"Earned-before-close keeps the overlay audio suspension")
	game.audio.set_focused(false);provider.rewarded_closed.emit(id);await settle()
	check(not can_output(game.audio) and not game.ads.reward_in_flight,"Matching close cannot bypass outstanding focus loss")
	game.audio.set_focused(true);await settle()
	check(can_output(game.audio),"Matching close plus foreground recovery restores enabled menu music")
	game.diamond_video_ready_at=0.0
	request=game.request_diamond_video();await frames()
	check(request.get("ok",false) and not can_output(game.audio),"Second isolated presentation enters suspension normally")
	id=game.ads._active_id;provider.rewarded_failed.emit(id,"Intentional independent QA failure");await settle()
	check(not game.ads.reward_in_flight and can_output(game.audio),"Native failure clears only the matching presentation suspension")
	evidence["ad_scope"]="In-memory typed provider through actual Game/AdsBridge. No native SDK or physical ad interruption measurement."

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,960)
	master_volume=AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-80.0)
	resources();await controller_routes();await suspension();await game_routes();await ad_routes()
	paused=false
	game.audio.music.stop();game.ui.case_opening.sound.stop_all();OS.delay_msec(120)
	game.free();await frames();AudioServer.set_bus_volume_db(0,master_volume)
	var result:={"checks":checks,"failures":failures,"evidence":evidence,
		"scope":"Independent imported-stream, six-route, actual game/UI and fake-provider lifecycle review; memory-only progression, Dummy driver, no subjective listening or physical-phone certification."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n");file.flush();file.close()
	print("WORLD_MUSIC_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
