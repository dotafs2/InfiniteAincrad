extends SceneTree
## Independent audio state, resource, input and isolated-save acceptance.
## Dummy/headless playback state does not establish audible quality or Web
## browser autoplay compliance; those require separate real-device listening.
const Game=preload("res://fidelity/game.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
var owned_paths:Array[String]=[]
var base:="/tmp/hole-music-qa-%d"%OS.get_process_id()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=3)->void:
	for i in count:await process_frame
func fixture_path(label:String)->String:
	var path:=base+"-"+label+".cfg"
	for suffix in ["",".tmp",".pre-coins.cfg"]:owned_paths.append(path+suffix)
	return path
func ledger(owner:Node3D)->Dictionary:
	return {"coins":owner.coins,"gems":owner.gems,"stage":owner.stage,"owned":owner.owned_skin_ids.duplicate(),"equipped":owner.selected_skin_id,"skin_progress":owner.skin_progress,"map":owner.selected_map}
func descendants(node:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in node.get_children():result.append(child);result.append_array(descendants(child))
	return result
func bgm_players()->Array[Node]:
	return descendants(game).filter(func(node):return node is AudioStreamPlayer and node.bus=="Music")
func music_can_output()->bool:
	var player:AudioStreamPlayer=game.audio.music
	var bus:=AudioServer.get_bus_index("Music")
	return player.playing and not player.stream_paused and player.can_process() and bus>=0 and not AudioServer.is_bus_mute(bus)
func target(id:String)->Button:
	for button in game.ui.buttons:
		if button.name==id:return button
	return null
func click(id:String)->void:
	var button:=target(id)
	check(button!=null,"Actual audio input target exists: "+id)
	if button==null:return
	check(button.visible and not button.disabled and button.can_process(),"Audio target can receive current-state input: "+id)
	var at:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.position=at;event.global_position=at
		root.push_input(event,true);await frames()
func inspect_buttons(label:String)->void:
	for id in ["audio-music","audio-sfx"]:
		var button:=target(id)
		check(button!=null,label+": separate "+id+" control exists")
		if button==null:continue
		check(button.size.x>=44 and button.size.y>=44,label+": audio touch target is at least 44 design pixels")
		check(Rect2(Vector2.ZERO,Vector2(540,960)).encloses(button.get_global_rect()),label+": audio button fits the portrait viewport")
		var style:=button.get_theme_stylebox("normal")
		check(style is StyleBoxFlat and style.corner_radius_top_left>0,label+": audio control retains the rounded interface style")
	check(target("audio-music")==null or target("audio-sfx")==null or not target("audio-music").get_global_rect().intersects(target("audio-sfx").get_global_rect()),label+": the two audio hit regions do not overlap")
func freeze_world()->void:
	game.set_physics_process(false);game.world.process_mode=Node.PROCESS_MODE_DISABLED
	for node in descendants(game.world):
		if node is RigidBody3D:node.freeze=true
func resources()->void:
	var hashes:Array[String]=[];var tracks:Array=[]
	for map_id in ["city","food"]:
		game.select_map(map_id)
		var stream:AudioStream=game.audio.music.stream
		check(game.audio.current_map==map_id and stream is AudioStreamOggVorbis,map_id+": selecting the actual map installs a real Ogg Vorbis stream")
		if not stream is AudioStreamOggVorbis:continue
		check(stream.get_length()>25.0,map_id+": real encoded track exceeds twenty-five seconds")
		check(stream.loop and stream.loop_offset==0.0,map_id+": stream loops from the beginning")
		check(game.audio.music.playback_type==AudioServer.PLAYBACK_TYPE_STREAM,map_id+": music uses streaming playback")
		var packets=stream.packet_sequence.get("packet_data")
		check(packets is Array and not packets.is_empty(),map_id+": imported Ogg contains actual encoded audio packets")
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(packets))
		var digest:=hash.finish().hex_encode();hashes.append(digest)
		tracks.append({"map":map_id,"length_seconds":stream.get_length(),"encoded_packet_sha256":digest,"loop":stream.loop})
		check(not game.audio.unlocked and not game.audio.music.playing,map_id+": track selection cannot bypass the initial gesture gate")
	check(hashes.size()==2 and hashes[0]!=hashes[1],"Both maps contain different encoded music, not renamed copies")
	game.select_map("city")
	evidence["tracks"]=tracks
func gesture_and_home()->void:
	check(game.music_enabled and game.sfx_enabled,"Fresh audio preferences default independently to ON")
	check(not game.audio.unlocked and not music_can_output(),"Fresh ON preferences cannot start music without a gesture")
	game.audio.set_music_enabled(false);game.audio.set_music_enabled(true)
	game.audio.set_focused(false);game.audio.set_focused(true)
	await frames()
	check(not game.audio.unlocked and not music_can_output(),"Preference/focus restoration alone never unlocks autoplay")
	inspect_buttons("home")
	var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(12,450);touch.pressed=true
	root.push_input(touch,true);await frames()
	check(not game.audio.unlocked,"Touch press waits until release before deferred audio unlock")
	touch=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(12,450);touch.pressed=false
	root.push_input(touch,true);await frames(6)
	check(game.audio.unlocked and game.audio.music.playing and music_can_output(),"A real input release unlocks and starts the enabled music voice")
	var id:int=game.audio.music.get_instance_id()
	var stream:AudioStream=game.audio.music.stream
	var before_seek:AudioStreamPlayback=game.audio.music.get_stream_playback()
	game.audio.music.seek(3.0);await frames(6)
	var playback:AudioStreamPlayback=game.audio.music.get_stream_playback()
	evidence["seek_playback"]={"before":before_seek.get_instance_id(),"after":playback.get_instance_id(),"position":game.audio.music.get_playback_position(),"note":"Explicit seek may replace the decoder; the no-restart oracle is captured after this intentional operation."}
	check(game.audio.music.get_playback_position()>2.5,"Nonzero playback bookmark makes an unintended restart observable")
	for index in 5:
		game.ui.open_holes();await frames();game.ui.open_store();await frames();game.ui.close_menu();await frames()
		game.select_map("city");await frames()
		check(bgm_players().size()==1 and game.audio.music.get_instance_id()==id,"Menu cycle %d retains exactly one BGM voice"%index)
		check(game.audio.music.stream==stream and game.audio.music.get_stream_playback()==playback and game.audio.music.get_playback_position()>2.5,"Menu cycle %d and same-map selection preserve the existing playback"%index)
	await click("audio-music")
	check(not game.music_enabled and not music_can_output() and game.sfx_enabled,"Actual MUSIC control silences only music")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Music mute leaves the SFX bus enabled")
	await click("audio-sfx")
	check(not game.sfx_enabled and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Actual SFX control independently mutes collection and collision bus")
	await click("audio-music")
	check(game.music_enabled and music_can_output() and not game.sfx_enabled,"Music resumes while disabled SFX remains muted")
	await click("audio-sfx")
	check(game.sfx_enabled and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"SFX restores independently without changing music preference")
func round_and_focus()->void:
	var music:AudioStreamPlayer=game.audio.music
	var id:=music.get_instance_id()
	var stream:AudioStream=music.stream
	var playback:AudioStreamPlayback=music.get_stream_playback()
	game.start_level();freeze_world();await frames()
	check(game.phase=="intro" and music.stream==stream and music.get_stream_playback()==playback and music.get_playback_position()>2.5,"Starting the same map preserves the ongoing song and nonzero position")
	game.begin_play();await frames()
	check(music_can_output(),"Enabled music continues during actual gameplay phase")
	game.toggle_pause();await frames()
	check(paused and not music_can_output(),"Actual pause suspends background playback")
	inspect_buttons("pause")
	await click("audio-music")
	check(paused and not game.music_enabled and not music_can_output(),"Paused music button is actionable without unpausing the round")
	await click("audio-sfx")
	check(paused and not game.sfx_enabled and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Paused SFX button remains independently actionable")
	game.audio.set_focused(false)
	game.toggle_pause();await frames()
	check(not paused and not music_can_output(),"Unpausing cannot bypass disabled music or lost focus")
	game.toggle_music();await frames()
	check(game.music_enabled and not music_can_output(),"Enabling music cannot bypass lost focus")
	game.toggle_pause();game.audio.set_focused(true);await frames()
	check(paused and not music_can_output(),"Regaining focus cannot bypass an active pause")
	game.toggle_pause();await frames()
	check(music_can_output(),"Music resumes only after every suspension condition is cleared")
	check(not game.sfx_enabled and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Focus restoration never overrides an explicitly disabled SFX preference")
	game.toggle_sfx();game.audio.set_focused(false);await frames()
	check(not music_can_output() and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Background focus loss silences both music and enabled SFX")
	game.audio.set_focused(true);await frames()
	check(music_can_output() and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Foreground restoration restores each enabled audio channel")
	game.back_home();await frames()
	check(music.get_instance_id()==id and music.stream==stream and music.get_stream_playback()==playback and music.get_playback_position()>2.5,"Returning home preserves the same ongoing music instead of replaying its intro")
	game.select_map("food");await frames()
	check(game.audio.current_map=="food" and music.stream!=stream and music.get_instance_id()==id and bgm_players().size()==1,"Switching maps changes the song in the same sole player")
	var food_stream:AudioStream=music.stream
	music.seek(4.0);await frames(6)
	var food_playback:AudioStreamPlayback=music.get_stream_playback()
	game.start_level();freeze_world();await frames()
	check(music.stream==food_stream and music.get_stream_playback()==food_playback and music.get_playback_position()>3.5,"Food round entry also preserves its song and playback position")
	check(game.sound.bus=="SFX","Actual collection ping is routed to the SFX bus")
	game.city.ensure_impact_visuals()
	check(game.city.impact_audio.size()==3 and game.city.impact_audio.all(func(player):return player.bus=="SFX"),"All actual food-impact voices share the separately controlled SFX bus")
	check(bgm_players().size()==1,"Creating collision voices never creates another music voice")
	game.back_home();await frames()
	check(music.stream==food_stream and music.get_stream_playback()==food_playback,"Food return home leaves the existing playback intact")
	# Dummy's streamed mixer still runs on a real audio thread: cross the
	# encoded boundary using wall time rather than simulated fixed-fps delta.
	music.seek(music.stream.get_length()-0.03)
	OS.delay_msec(150)
	await frames(3)
	var loop_position:=music.get_playback_position()
	check(music.playing and loop_position>=0.0 and loop_position<1.0,"Actual streamed food track crosses its end and continues at the loop start")
	evidence["actual_loop"]={"map":"food","seek_seconds":music.stream.get_length()-0.03,"after_wall_wait_seconds":0.15,"position":loop_position,"playing":music.playing}
func stop_audio_before_free()->void:
	game.audio.music.stop()
	# The actual streaming audio thread needs wall time to retire its decoder.
	OS.delay_msec(120)
	await frames(3)
func cold_runtime_restore()->void:
	var path:String=game.test_progress_path
	await stop_audio_before_free()
	game.free();await frames()
	game=Game.new();game.test_progress_path=path
	check(game.load_player_progress(),"Cold runtime fixture loads its owned audio save before entering the tree")
	root.add_child(game);game.set_physics_process(false);await frames()
	check(not game.music_enabled and not game.sfx_enabled and game.audio.current_map==game.selected_map,"Cold game applies both disabled preferences and the saved map track")
	check(not game.audio.unlocked and not music_can_output() and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Cold game keeps audio disabled and starts a new gesture gate")
	check(bgm_players().size()==1,"Cold restart constructs exactly one replacement BGM player")
func persistence()->void:
	var live:=fixture_path("live")
	var cfg:=ConfigFile.new();cfg.set_value("future","retained","music-review")
	check(cfg.save(live)==OK,"Create an owned isolated progress fixture")
	game.test_progress_path=live
	game.coins=321;game.gems=67;game.stage=9;game.skin_progress=123
	game.owned_skin_ids.append(Game.SKIN_DEFS[1].id);game.selected_skin_id=Game.SKIN_DEFS[1].id
	var baseline:=ledger(game)
	for music_on in [true,false]:
		for sfx_on in [true,false]:
			if game.music_enabled!=music_on:game.toggle_music()
			if game.sfx_enabled!=sfx_on:game.toggle_sfx()
			check(game.save_player_progress(),"Independent music/SFX combination saves atomically")
			cfg=ConfigFile.new();check(cfg.load(live)==OK,"Saved audio fixture is valid ConfigFile data")
			check(cfg.get_value("audio","music_enabled")==music_on and cfg.get_value("audio","sfx_enabled")==sfx_on,"Both audio settings retain their separate boolean values")
			check(cfg.get_value("future","retained")=="music-review","Audio saves preserve unrelated future config sections")
			check(ledger(game)==baseline,"Audio setting changes preserve wallet, stage, skins and selected map")
			var restored:=Game.new();restored.test_progress_path=live
			check(restored.load_player_progress(),"Cold audio settings reload succeeds")
			check(restored.music_enabled==music_on and restored.sfx_enabled==sfx_on and ledger(restored)==baseline,"Cold reload restores independent audio preferences without an economy change")
			restored.free()
	var bytes_before:=FileAccess.get_file_as_bytes(live)
	var music_before:bool=game.music_enabled;var sfx_before:bool=game.sfx_enabled
	var bus_before:=AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
	game.test_progress_path=live+"/blocked.cfg"
	game.toggle_music();game.toggle_sfx()
	check(game.music_enabled==music_before and game.sfx_enabled==sfx_before,"Unwritable save path rolls back both audio preference mutations")
	check(not music_can_output() and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))==bus_before,"Failed save also restores the applied music and SFX state")
	check(FileAccess.get_file_as_bytes(live)==bytes_before and ledger(game)==baseline,"Failed audio transaction changes neither the valid save nor economy")
	game.test_progress_path=live
	var legacy:=fixture_path("legacy")
	cfg=ConfigFile.new();cfg.set_value("progress","skin_schema",2);cfg.set_value("progress","coins",243);cfg.set_value("progress","owned_skin_ids",["core_shell"])
	check(cfg.save(legacy)==OK,"Create an owned pre-audio progress fixture")
	var old:=Game.new();old.test_progress_path=legacy;old.music_enabled=false;old.sfx_enabled=false
	check(old.load_player_progress() and old.music_enabled and old.sfx_enabled and old.coins==243,"Missing audio keys default both controls on while preserving old progress")
	old.free()
	evidence["isolated_save"]={"combinations":4,"legacy_default":true,"failure_rollback":true,"scope":"Owned temporary files only; no real user progress file is opened."}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,960)
	game=Game.new();root.add_child(game);game.set_physics_process(false)
	await frames()
	check(game.progress_file().is_empty(),"Default --test mode has no path to the player's progress file")
	check(AudioServer.get_bus_index("Music")>=0 and AudioServer.get_bus_index("SFX")>=0 and AudioServer.get_bus_index("Music")!=AudioServer.get_bus_index("SFX"),"Distinct Music and SFX audio buses are configured")
	check(bgm_players().size()==1,"A new session constructs one BGM voice")
	resources()
	await gesture_and_home()
	await round_and_focus()
	persistence()
	await cold_runtime_restore()
	await stop_audio_before_free()
	game.free();await frames()
	for path in owned_paths:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	var report:={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Independent headless audio/resource/control/save acceptance. No browser autoplay, listening-quality or device-performance claim."}
	print("MUSIC_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:=arg.trim_prefix("--report=")
			if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):quit(2);return
			FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
