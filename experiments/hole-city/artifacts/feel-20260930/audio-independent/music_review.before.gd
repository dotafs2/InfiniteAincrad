extends SceneTree
## Non-author review of actual UI event order, independent suspension causes,
## native stream ownership and bus routing. No audible/browser claim.
const Game=preload("res://fidelity/game.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
var saved_path:="/tmp/hole-music-independent-%d.cfg"%OS.get_process_id()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=2)->void:
	for i in n:await process_frame
func button(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id:return b
	return null
func mouse(at:Vector2,pressed:bool)->void:
	var move:=InputEventMouseMotion.new();move.position=at;move.global_position=at;root.push_input(move,true)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at
	event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)
func click(id:String)->void:
	var target:=button(id);check(target!=null,"Current UI has "+id)
	if target==null:return
	var at:=target.get_global_rect().get_center()
	mouse(at,true);await frames();mouse(at,false);await frames()
func playback_id()->int:
	return game.audio.music.get_stream_playback().get_instance_id() if game.audio.music.has_stream_playback() else 0
func music_eligible()->bool:
	return game.audio.music.playing and not game.audio.music.stream_paused and game.audio.music.can_process() and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
func validate_state(label:String)->void:
	var a:Node=game.audio
	var expected:bool=not a.music_enabled or not a.focused or a.app_suspended or paused
	check(a.music.stream_paused==expected,label+": music respects every suspension reason")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))==(not a.sfx_enabled or not a.focused or a.app_suspended),label+": effects respect independent preference and background reasons")
func phone_target(target:Button,screen:String)->void:
	var rect:=target.get_global_rect();var points:=rect.size*(375.0/540.0)
	check(minf(points.x,points.y)>=44.0,screen+": actual "+target.name+" touch target reaches 44 points at a 375-point phone width")
	var font:=target.get_theme_font("font");var font_size:=target.get_theme_font_size("font_size")
	if not evidence.has("phone_targets"):evidence["phone_targets"]=[]
	evidence.phone_targets.append({"screen":screen,"label":target.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"points_375":[points.x,points.y],"font_size":font_size,"glyph_width":font.get_string_size(target.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x})
func pause_geometry()->void:
	for id in ["audio-music","audio-sfx"]:
		var target:=button(id);phone_target(target,"pause")
		var font:=target.get_theme_font("font");var font_size:=target.get_theme_font_size("font_size")
		check(font.get_string_size(target.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+8<=target.get_global_rect().size.x,id+": actual pause ON/OFF glyph width fits with padding")
func home_geometry()->void:
	for enabled in [true,false]:
		game.music_enabled=enabled;game.sfx_enabled=enabled;game.ui.refresh();await frames()
		for id in ["audio-music","audio-sfx"]:
			var target:=button(id);var rect:=target.get_global_rect();phone_target(target,"home")
			check(not rect.intersects(Rect2(24,26,130,50)),id+": actual bounds do not cover the level badge")
			check(not rect.intersects(Rect2(394,26,122,50)),id+": actual bounds do not cover the wallet")
			var font:=target.get_theme_font("font");var font_size:=target.get_theme_font_size("font_size")
			check(font.get_string_size(target.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+8<=rect.size.x,id+": actual ON/OFF glyph width fits with padding")
			check(target.get_combined_minimum_size().x<=rect.size.x,id+": theme minimum size fits the actual button")
		check(not button("audio-music").get_global_rect().intersects(button("audio-sfx").get_global_rect()),"Actual home music and SFX hit regions do not overlap")
	game.music_enabled=true;game.sfx_enabled=true;game.ui.refresh();await frames()
func event_order()->void:
	check(not game.audio.started and not game.audio.unlocked and not music_eligible(),"Stored default ON does not autoplay before input")
	var at:=button("audio-music").get_global_rect().get_center()
	mouse(at,true);await frames(5)
	check(not game.audio.started and not game.audio.unlocked,"Holding first MUSIC ON-to-OFF press does not briefly start the track")
	mouse(at,false)
	check(not game.music_enabled and not game.audio.started,"Actual button callback switches music off before deferred unlock")
	await frames()
	check(game.audio.unlocked and not game.audio.started and not music_eligible(),"First mute release unlocks without starting a muted track")
	await click("audio-sfx")
	check(not game.sfx_enabled and not game.music_enabled,"Actual effects button changes only effects")
	await click("audio-music")
	check(game.music_enabled and not game.sfx_enabled and music_eligible(),"Actual music button starts only music after unlock")
	var first:=playback_id();check(first!=0,"Streaming playback is an actual engine playback object")
	await frames(7);game.audio.unlock_from_gesture();await frames()
	check(playback_id()==first,"Ordinary frames and repeated gesture do not create or restart another voice")
	await click("audio-music");await click("audio-music")
	check(playback_id()==first,"Mute/unmute preserves the existing stream playback")
	var stream_id:int=game.audio.music.stream.get_instance_id()
	game.select_map("city");await frames()
	check(game.audio.music.stream.get_instance_id()==stream_id and playback_id()==first,"Selecting the same map does not restart the track")
	game.select_map("food");await frames()
	check(game.audio.current_map=="food" and game.audio.music.stream.get_instance_id()!=stream_id and music_eligible(),"Actual map control switches to one new food stream")
	game.audio.set_map("unknown")
	check(game.audio.current_map=="food","Invalid map cannot destroy the current track")
	# A touch release is routed through the real viewport input stage. It may
	# reach a GUI control separately via the platform's emulated mouse event.
	game.audio.music.stop();game.audio.started=false;game.audio.unlocked=false
	var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(15,400);touch.pressed=true
	root.push_input(touch,true);await frames()
	check(not game.audio.unlocked,"Touch press waits for release before unlocking")
	touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
	check(game.audio.unlocked and music_eligible(),"Viewport touch release unlocks the current stream")
	game.audio.music.stop();game.audio.started=false;game.audio.unlocked=false
	var key:=InputEventKey.new();key.pressed=true;key.echo=true;key.keycode=KEY_A;root.push_input(key,true);await frames()
	check(not game.audio.unlocked,"Keyboard repeat cannot be the first unlock")
	key=key.duplicate();key.echo=false;root.push_input(key,true);await frames()
	check(not game.audio.unlocked,"Initial keyboard press waits for release, including keyboard GUI activation")
	key=key.duplicate();key.pressed=false;root.push_input(key,true);await frames()
	check(game.audio.unlocked and music_eligible(),"Keyboard release unlocks after GUI event dispatch")
	game.audio.music.stop();game.audio.started=false;game.audio.unlocked=false
	button("audio-music").grab_focus()
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true);await frames(5)
	check(button("audio-music").button_pressed and not game.audio.started and not game.audio.unlocked,"Holding focused MUSIC ON with SPACE does not briefly start music")
	key=key.duplicate();key.pressed=false;root.push_input(key,true)
	check(not game.music_enabled and not game.audio.started,"Keyboard GUI mute callback precedes deferred release unlock")
	await frames()
	check(game.audio.unlocked and not game.audio.started and not music_eligible(),"First keyboard mute completes silently without losing the gesture")
	game.toggle_music();await frames()
func suspension()->void:
	var a:Node=game.audio
	a.set_sfx_enabled(true);game.sfx_enabled=true
	a.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	a.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await frames()
	check(a.app_suspended and a.focused and not music_eligible(),"Focus-in cannot override an outstanding application suspension")
	validate_state("Suspended then focused")
	a.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	a.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	a.notification(Node.NOTIFICATION_APPLICATION_RESUMED);await frames()
	check(not a.focused and not a.app_suspended and not music_eligible(),"Application-resumed cannot override a separate focus loss")
	validate_state("Unfocused then resumed")
	for enabled in [false,true]:
		for focus in [false,true]:
			for suspended in [false,true]:
				for tree_paused in [false,true]:
					a.set_music_enabled(enabled);a.set_sfx_enabled(not enabled)
					a.set_focused(focus);a.set_app_suspended(suspended);paused=tree_paused
					await frames();validate_state("Independent state combination")
	paused=false;a.set_music_enabled(true);a.set_sfx_enabled(true);a.set_focused(true);a.set_app_suspended(false)
	game.music_enabled=true;game.sfx_enabled=true;await frames()
	check(music_eligible(),"Only clearing all suspension causes restores playback")
func route_and_lifecycle()->void:
	check(AudioServer.get_bus_count()==3,"Exactly Master, Music and SFX buses are loaded")
	for name in ["Music","SFX"]:
		var index:=AudioServer.get_bus_index(name)
		check(index>0 and AudioServer.get_bus_send(index)==&"Master",name+" sends to Master without bypassing its own mute")
	check(game.sound.bus==&"SFX","Actual collection sound is routed to SFX")
	check(game.audio.music.bus==&"Music" and game.audio.music.playback_type==AudioServer.PLAYBACK_TYPE_STREAM,"Background Ogg uses dedicated Music bus and explicit stream playback")
	check(game.audio.music.stream.loop and game.audio.music.stream.loop_offset==0.0,"Actual loaded Vorbis resource loops from the beginning")
	check(game.audio.TRACKS.city.resource_path!=game.audio.TRACKS.food.resource_path and absf(game.audio.TRACKS.city.get_length()-32)<.01 and game.audio.TRACKS.food.get_length()>34,"Both distinct imported Vorbis resources decode to expected duration")
	game.start_level();game.begin_play();game.set_physics_process(false)
	game.world.process_mode=Node.PROCESS_MODE_DISABLED
	for body in game.city.foods:
		if is_instance_valid(body):body.freeze=true
	game.city.ensure_impact_visuals()
	check(game.city.impact_audio.size()==3,"Actual food scene creates its three effects voices")
	for player in game.city.impact_audio:check(player.bus==&"SFX","Every real food collision voice is routed to SFX")
	var music_id:int=game.audio.music.get_instance_id()
	game.toggle_pause();await frames()
	check(not music_eligible() and button("audio-music")!=null and button("audio-sfx")!=null,"Pause stops music and exposes both functioning settings")
	pause_geometry()
	await click("audio-sfx");check(not game.sfx_enabled and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Actual pause effects control works while SceneTree is paused")
	await click("audio-music");check(not game.music_enabled and not music_eligible(),"Actual pause music control does not resume a paused track")
	pause_geometry()
	game.back_home();await frames(6)
	check(not paused and not music_eligible() and game.audio.music.get_instance_id()==music_id,"Returning home retains one player and respects music OFF")
	await click("audio-music");check(music_eligible(),"Music can resume normally from the returned home screen")
	var count:=0
	for node in game.find_children("*","AudioStreamPlayer",true,false):
		if node.bus==&"Music":count+=1
	check(count==1,"Map, pause and home transitions leave exactly one Music player")
func persistence()->void:
	game.test_progress_path=saved_path
	var config:=ConfigFile.new();config.set_value("future","keep",71);check(config.save(saved_path)==OK,"Create only an isolated reviewer preference fixture")
	game.coins=432;game.gems=123;game.stage=7
	game.music_enabled=false;game.sfx_enabled=true
	check(game.save_player_progress(),"Independent preferences save successfully")
	var loaded:=Game.new();loaded.test_progress_path=saved_path
	check(loaded.load_player_progress() and not loaded.music_enabled and loaded.sfx_enabled,"Cold loading preserves independent music OFF/effects ON values")
	check(loaded.coins==432 and loaded.gems==123 and loaded.stage==7,"Audio persistence preserves progression")
	loaded.free();config=ConfigFile.new();check(config.load(saved_path)==OK and config.get_value("future","keep")==71,"Audio save preserves unknown config sections")
	game.test_progress_path=""
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,960)
	game=Game.new();root.add_child(game);game.set_physics_process(false)
	await frames()
	await home_geometry();await event_order();await suspension();await route_and_lifecycle();persistence()
	paused=false
	# Fixed-FPS frames advance much faster than the independent audio mixer.
	# Explicitly end this test-owned loop and allow one bounded mixer drain
	# before destroying the scene and immediately terminating the engine.
	game.audio.music.stop()
	OS.delay_msec(100)
	game.free();await frames()
	for suffix in ["",".tmp",".pre-coins.cfg"]:
		if FileAccess.file_exists(saved_path+suffix):DirAccess.remove_absolute(saved_path+suffix)
	print("MUSIC_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual headless engine state and UI input dispatch; no audible/browser autoplay certification."}))
	quit(0 if failures.is_empty() else 1)
