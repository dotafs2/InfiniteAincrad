extends SceneTree
## Isolated actual-stream/voice lifecycle acceptance. No Game, saves or commerce.
## Run with the Dummy audio driver. Decoder measurements do not establish feel.
const CaseAudio=preload("res://fidelity/case_audio.gd")
const Audio=preload("res://fidelity/audio.gd")
const EXPECTED_SECONDS:={"open":4.25,"tick":.028,"common":.46,"uncommon":.60,"rare":.74,"epic":.90,"legendary":1.08,"prismatic":1.24}
const TIERS:Array[String]=["common","uncommon","rare","epic","legendary","prismatic"]
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
var helper:Node
var audio:Node
var saved_buses:Dictionary={}
var added_buses:Array[String]=[]

func _initialize()->void:run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func frames(count:=3)->void:
	for _i in count:await process_frame

func retain_bus(name:String)->int:
	var index:=AudioServer.get_bus_index(name)
	if index<0:
		AudioServer.add_bus()
		index=AudioServer.bus_count-1
		AudioServer.set_bus_name(index,name)
		added_buses.append(name)
	else:
		saved_buses[name]={"muted":AudioServer.is_bus_mute(index),"volume_db":AudioServer.get_bus_volume_db(index)}
	return index

func restore_buses()->void:
	for name in added_buses:
		var index:=AudioServer.get_bus_index(name)
		if index>=0:AudioServer.remove_bus(index)
	for name in saved_buses:
		var index:=AudioServer.get_bus_index(name)
		AudioServer.set_bus_mute(index,bool(saved_buses[name].muted))
		AudioServer.set_bus_volume_db(index,float(saved_buses[name].volume_db))

func voices()->Array[Node]:
	return helper.find_children("*","AudioStreamPlayer",true,false)

func quiet()->bool:
	return not helper.tick_voice.playing and not helper.accent_voice.playing

func emit_all()->void:
	helper.play_open();helper.play_tick();helper.play_reveal("prismatic")

func stream_review()->void:
	var streams:Dictionary={"open":CaseAudio.OPEN,"tick":CaseAudio.TICK}
	for tier in TIERS:streams[tier]=CaseAudio.REVEALS[tier]
	var seen:Dictionary={}
	var results:Array[Dictionary]=[]
	for label in streams:
		var stream:AudioStream=streams[label]
		check(stream is AudioStreamWAV,label+": actual imported WAV stream is available")
		if not stream is AudioStreamWAV:continue
		var wav:AudioStreamWAV=stream
		check(not wav.stereo and wav.mix_rate==32000,label+": actual imported audio is mono32kHz")
		check(absf(wav.get_length()-float(EXPECTED_SECONDS[label]))<.01,label+": actual length matches the bounded composed phrase")
		check(wav.loop_mode==AudioStreamWAV.LOOP_DISABLED,label+": revealing cannot leave a looping voice")
		check(not wav.data.is_empty(),label+": imported stream contains actual encoded data")
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(wav.data)
		var digest:=hash.finish().hex_encode()
		check(not seen.has(digest),label+": every cue contains distinct encoded audio")
		seen[digest]=true
		# Import compression may be QOA. Measure real decoded samples rather than
		# treating its byte buffer as16-bit PCM or mirroring generator constants.
		var decoder:AudioStreamPlayback=wav.instantiate_playback()
		decoder.start(0.0)
		var samples:PackedVector2Array=decoder.mix_audio(1.0,int(ceil((wav.get_length()+.05)*AudioServer.get_mix_rate())))
		var peak:=0.0
		var energy:=0.0
		var finite:=true
		var mono:=true
		for sample in samples:
			finite=finite and sample.is_finite()
			mono=mono and absf(sample.x-sample.y)<.000001
			peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
			energy+=sample.length_squared()
		check(samples.size()>200 and finite and energy>.001,label+": actual decoder produces finite audible-content samples")
		check(mono and peak>.01 and peak<.32,label+": decoded mono samples retain gentle unclipped headroom")
		decoder.stop()
		check(not decoder.is_playing(),label+": in-memory decoder releases playback")
		results.append({"cue":label,"duration":wav.get_length(),"mono":not wav.stereo,"mix_rate":wav.mix_rate,
			"import_format":wav.format,"encoded_sha256":digest,"decoded_frames":samples.size(),"decoded_peak":peak})
	check(seen.size()==8,"All eight real cue streams are distinct")
	evidence["streams"]=results

func playback_review()->void:
	check(quiet(),"Adding the helper starts no open, tick or reveal voice")
	check(voices().size()==2,"The actual helper owns exactly two AudioStreamPlayers")
	var voice_ids:Array[int]=[]
	for voice in voices():
		voice_ids.append(voice.get_instance_id())
		check(voice.bus==&"SFX" and voice.max_polyphony==1 and not voice.autoplay,"Actual voice uses SFX with one bounded playback and no autoplay")
	helper.play_open()
	check(helper.accent_voice.playing and helper.accent_voice.stream==CaseAudio.OPEN and not helper.tick_voice.playing,"Open starts only the real opening accent")
	check(helper.accent_voice.get_stream_playback()!=null,"Opening has a real AudioStreamPlayback instance")
	helper.play_tick()
	check(helper.tick_voice.playing and helper.accent_voice.playing,"A card tick can coexist with the opening using only two voices")
	# Stop the voice without resetting the helper's timestamp. A real immediate
	# repeat must remain silent, proving the limiter controls admission itself.
	var tick_at:int=helper.last_tick_msec
	helper.tick_voice.stop()
	helper.play_tick()
	check(not helper.tick_voice.playing and helper.last_tick_msec==tick_at,"Immediate repeat is rejected even after the tick voice was manually stopped")
	OS.delay_msec(45)
	helper.play_tick()
	check(helper.tick_voice.playing and helper.last_tick_msec>=tick_at+40,"A later actual tick is admitted after the40ms window")
	for tier in TIERS:
		helper.stop_all();helper.play_tick();helper.play_reveal(tier)
		check(helper.accent_voice.playing and helper.accent_voice.stream==CaseAudio.REVEALS[tier],"Actual reveal chooses the committed rarity stream: "+tier)
		check(not helper.tick_voice.playing,"Reveal retires the last card tick: "+tier)
		check(voices().size()==2,"Tier change does not allocate another player: "+tier)
	helper.stop_all();helper.play_reveal("unknown")
	check(quiet(),"Unknown rarity cannot start a cue from idle")
	helper.play_reveal("rare")
	var existing:AudioStreamPlayback=helper.accent_voice.get_stream_playback()
	helper.play_reveal("UNKNOWN")
	check(helper.accent_voice.playing and helper.accent_voice.get_stream_playback()==existing and helper.accent_voice.stream==CaseAudio.REVEALS.rare,"Unknown rarity cannot replace or restart an already valid cue")
	for index in 100:
		helper.play_open();helper.play_tick();helper.play_reveal(TIERS[index%TIERS.size()])
	check(voices().size()==2 and voices().all(func(voice):return voice_ids.has(voice.get_instance_id())),"One hundred complete event bursts retain the same two persistent voices")
	helper.stop_all()
	check(quiet(),"Explicit dismissal immediately stops both actual voices")
	evidence["voice_ids"]=voice_ids

func lifecycle_review()->void:
	var sfx:=AudioServer.get_bus_index("SFX")
	helper.play_open();helper.play_tick()
	audio.set_sfx_enabled(false)
	await frames()
	check(AudioServer.is_bus_mute(sfx) and quiet(),"Existing SFX preference mutes the bus and stops both ongoing case voices")
	emit_all();await frames()
	check(quiet(),"All three event APIs stay silent while SFX is off")
	audio.set_sfx_enabled(true);await frames()
	check(not AudioServer.is_bus_mute(sfx) and quiet(),"Turning SFX back on does not replay an interrupted cue")
	helper.play_open();helper.play_tick()
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	helper.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(quiet(),"Focus loss immediately stops the actual accent and tick")
	emit_all();check(quiet(),"New case events are suppressed while unfocused")
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	helper.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames()
	check(quiet(),"Focus restoration has no automatic cue playback")
	helper.play_reveal("legendary")
	check(helper.accent_voice.playing,"A new deliberate event works after focus recovery")
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	helper.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(quiet(),"Application suspension stops an active reveal")
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	helper.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	emit_all();check(quiet(),"Focus-in cannot bypass an outstanding application suspension")
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	helper.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	helper.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	emit_all();check(quiet(),"Resume cannot bypass outstanding focus loss")
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	helper.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames();check(quiet(),"Full lifecycle recovery never restarts a stopped reveal")
	helper.play_open()
	check(helper.accent_voice.playing,"Explicit interaction remains functional after pause and focus orderings")
	AudioServer.set_bus_mute(0,true);await frames()
	check(quiet(),"Master mute also retires a pending case tail")
	emit_all();check(quiet(),"A muted Master rejects new case voices")
	AudioServer.set_bus_mute(0,false);await frames()
	check(quiet(),"Restoring Master cannot resurrect a previous case event")
	helper.play_open();helper.play_tick()
	root.remove_child(helper)
	check(quiet(),"Removing the UI audio helper from the tree stops both voices")
	root.add_child(helper);await frames()
	check(quiet() and voices().size()==2,"Reattaching a preserved helper neither auto-plays nor duplicates its voices")

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var master:=retain_bus("Master")
	retain_bus("Music");retain_bus("SFX")
	# Dummy is preferred. This isolated process also suppresses physical output
	# without bus muting, since actual mute transitions are under test below.
	AudioServer.set_bus_volume_db(master,-80.0)
	AudioServer.set_bus_mute(master,false)
	audio=Audio.new();audio.music_enabled=false;audio.sfx_enabled=true
	root.add_child(audio)
	helper=CaseAudio.new();root.add_child(helper)
	await frames()
	stream_review()
	playback_review()
	await lifecycle_review()
	helper.stop_all();audio.music.stop()
	var tick_weak:WeakRef=weakref(helper.tick_voice)
	var accent_weak:WeakRef=weakref(helper.accent_voice)
	helper.free()
	check(tick_weak.get_ref()==null and accent_weak.get_ref()==null,"Freeing the helper releases both owned voice nodes")
	OS.delay_msec(100);audio.free();await frames()
	restore_buses()
	var result:={"checks":checks,"failures":failures,"evidence":evidence,
		"scope":"Actual imported WAV decoding and two-player lifecycle; memory only, no Game/save/commerce. Dummy audio state is not physical-device listening."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:=arg.trim_prefix("--report=")
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n");file.flush();file.close()
	print("SKIN_CASE_AUDIO_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
