extends SceneTree
## Independent retained menu recording and real Vorbis decoding review. Memory only;
## headless audio state is not browser autoplay or subjective listening.
const Audio=preload("res://fidelity/audio.gd")
const EXPECTED_SECONDS:=88.0
const EXPECTED_PACKET_SHA:="5d0053ae1d9ee3c8627fe9f6cfecd9f0126fc6c9eaae65ad47b01c7049f71fe0"
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
var controller:Node
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=3)->void:
	for i in count:await process_frame
func packet_hash(stream:AudioStreamOggVorbis)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(stream.packet_sequence.get("packet_data")))
	return hash.finish().hex_encode()
func decoder_review(stream:AudioStreamOggVorbis)->void:
	# This decoder has no AudioStreamPlayer or output bus. Its samples stay in
	# this bounded in-memory buffer rather than being sent to an audio device.
	var decoder:AudioStreamPlayback=stream.instantiate_playback()
	decoder.start(EXPECTED_SECONDS-.05)
	var output:PackedVector2Array=decoder.mix_audio(1.0,int(AudioServer.get_mix_rate()*.4))
	var finite:=true;var energy:=0.0;var peak:=0.0
	for sample in output:
		finite=finite and sample.is_finite()
		energy+=sample.length_squared()
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	check(output.size()>1000,"Native Vorbis decoder returns actual audio samples across the loop boundary")
	check(finite and energy>0.0001 and peak<1.0,"Actual decoded boundary contains finite non-silent unclipped stereo samples")
	check(decoder.get_loop_count()>=1,"Native decoder actually loops across the encoded end")
	check(decoder.is_playing() and decoder.get_playback_position()<1.0,"Actual looping decoder remains active near the beginning")
	evidence["native_boundary_decode"]={"frames":output.size(),"peak":peak,"energy":energy,"loops":decoder.get_loop_count(),"position":decoder.get_playback_position()}
	decoder.stop()
	check(not decoder.is_playing(),"Independent memory decoder stops without a persistent audio voice")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	controller=Audio.new();root.add_child(controller);await frames()
	var player:AudioStreamPlayer=controller.music
	var stream:AudioStreamOggVorbis=player.stream
	check(controller.TRACKS.city!=controller.TRACKS.food,"Distinct gameplay maps no longer share the menu recording")
	check(controller.TRACKS.menu.resource_path=="res://assets/audio/shop_theme_loop.ogg" and controller.current_track=="menu","Initial menu resource is the retained Shop Theme Ogg")
	check(absf(stream.get_length()-EXPECTED_SECONDS)<.001,"Imported normal Shop Theme retains its full 88-second composition")
	check(stream.loop and stream.loop_offset==0.0,"Runtime duplicate loops the complete recording from its beginning")
	check(player.playback_type==AudioServer.PLAYBACK_TYPE_STREAM and player.bus==&"Music","Menu music remains one streamed Music-bus voice")
	var encoded_sha:=packet_hash(stream)
	check(encoded_sha==EXPECTED_PACKET_SHA,"Actual imported audio packets match the independently pinned selected recording")
	evidence["encoded_packet_sha256"]=encoded_sha
	evidence["length_seconds"]=stream.get_length()
	for id in ["food","city","food"]:
		controller.set_map(id);await frames()
		check(controller.current_map==id,"Locked menu music still tracks the selected map: "+id)
		check(player.stream==stream and not controller.unlocked and not controller.started and not player.playing,"Locked map selection preserves one resource without autoplay: "+id)
	decoder_review(stream)
	controller.unlock_from_gesture();await frames()
	check(controller.started and player.playing,"An explicitly unlocked menu track starts through the existing controller")
	player.seek(7.0);await frames(6)
	var playback:AudioStreamPlayback=player.get_stream_playback()
	check(player.get_playback_position()>6.5,"A real nonzero decoder bookmark exposes accidental restarts")
	for i in 8:
		var id:="city" if i%2==0 else "food"
		controller.set_map(id);await frames()
		check(controller.current_map==id and player.stream==stream,"Changing maps preserves the same menu stream: %d"%i)
		check(player.get_stream_playback()==playback and player.get_playback_position()>6.5,"Changing maps preserves the actual decoder and nonzero playhead: %d"%i)
	for music_enabled in [false,true]:
		for focused in [false,true]:
			for suspended in [false,true]:
				controller.set_music_enabled(music_enabled);controller.set_focused(focused);controller.set_app_suspended(suspended)
				controller.set_map("food" if controller.current_map=="city" else "city");await frames()
				check(player.stream==stream and player.get_stream_playback()==playback,"Map changes under compound suspension never replace the stream or decoder")
				check(player.stream_paused==(not music_enabled or not focused or suspended),"Shared-track map changes preserve all independent suspension reasons")
	controller.set_music_enabled(true);controller.set_focused(true);controller.set_app_suspended(false)
	paused=true;controller.set_map("food" if controller.current_map=="city" else "city");await frames()
	check(player.stream_paused and player.get_stream_playback()==playback,"Map changes cannot bypass an active SceneTree pause")
	paused=false;await frames()
	check(not player.stream_paused and player.get_stream_playback()==playback and player.get_playback_position()>6.5,"Clearing all suspension reasons resumes the same ongoing recording")
	var last_map:String=controller.current_map;controller.set_map("invalid");await frames()
	check(controller.current_map==last_map and player.stream==stream and player.get_stream_playback()==playback,"Unknown map never replaces or restarts menu music")
	check(controller.find_children("*","AudioStreamPlayer",true,false).size()==1,"Repeated map and suspension transitions retain exactly one Music player")
	player.stop();OS.delay_msec(150);controller.free();await frames()
	print("SHOP_THEME_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Independent actual native decoder, resource identity and controller lifecycle; no speaker output, browser autoplay certification or subjective audition."}))
	quit(0 if failures.is_empty() else 1)
