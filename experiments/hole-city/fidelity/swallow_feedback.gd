extends Node
## A short, soft gulp and a light touch, only for the human player's receipts.
signal feedback_triggered(details:Dictionary)
var sound:AudioStreamPlayer
var haptics_enabled:=true
var haptic_driver:Callable
var last_msec:=-1000
var cache:Dictionary={}

func trigger(points:int,rival:=false)->bool:
	var now:=Time.get_ticks_msec()
	# Falling piles cannot turn many receipts into continuous vibration/noise.
	if not rival and now-last_msec<90:return false
	last_msec=now
	var tier:=3 if rival else 0 if points<4 else 1 if points<20 else 2
	if not cache.has(tier):cache[tier]=make_gulp(tier)
	if is_instance_valid(sound) and DisplayServer.get_name()!="headless":
		sound.stream=cache[tier];sound.play()
	var duration:=65 if rival else 28 if tier==0 else 35
	var amplitude:=.80 if rival else .18 if tier==0 else .24
	if haptics_enabled:
		if haptic_driver.is_valid():haptic_driver.call(duration,amplitude)
		elif Engine.has_singleton("HoleFeastFeedback"):
			Engine.get_singleton("HoleFeastFeedback").play_swallow_haptic(amplitude)
		elif OS.has_feature("mobile"):Input.vibrate_handheld(duration,amplitude)
	feedback_triggered.emit({"rival":rival,"tier":tier,"duration_ms":duration,
		"amplitude":amplitude,"haptics_enabled":haptics_enabled})
	return true

func make_gulp(tier:int)->AudioStreamWAV:
	var rate:=22050
	var seconds:float=[.09,.11,.14,.16][tier]
	var count:=int(rate*seconds)
	var start_hz:float=[390.0,330.0,270.0,320.0][tier]
	var bytes:=PackedByteArray();bytes.resize(count*2)
	var phase:=0.0
	for i in count:
		var t:=float(i)/count
		phase+=TAU*lerpf(start_hz,start_hz*.50,t)/rate
		var envelope:=minf(1.0,float(i)/110.0)*pow(1.0-t,2.5)
		var wave:float=sin(phase)+.16*sin(phase*2.0)
		bytes.encode_s16(i*2,int(wave*envelope*9500.0))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=rate;wav.data=bytes
	return wav
