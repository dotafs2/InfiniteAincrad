extends Node
## Two bounded, original cosmetic voices. State restoration never starts audio.
## The existing game audio controller owns SFX preference/focus bus muting.
const OPEN:AudioStream=preload("res://assets/audio/case_opening/open.wav")
const TICK:AudioStream=preload("res://assets/audio/case_opening/tick.wav")
const REVEALS:={
	"common":preload("res://assets/audio/case_opening/reveal_common.wav"),
	"uncommon":preload("res://assets/audio/case_opening/reveal_uncommon.wav"),
	"rare":preload("res://assets/audio/case_opening/reveal_rare.wav"),
	"epic":preload("res://assets/audio/case_opening/reveal_epic.wav"),
	"legendary":preload("res://assets/audio/case_opening/reveal_legendary.wav"),
	"prismatic":preload("res://assets/audio/case_opening/reveal_prismatic.wav"),
}
const TICK_INTERVAL_MS:=40
const ACCENT_VOLUME_DB:=-5.0
const TICK_VOLUME_DB:=-9.0
var tick_voice:AudioStreamPlayer
var accent_voice:AudioStreamPlayer
var last_tick_msec:=-TICK_INTERVAL_MS
var focused:=true
var app_suspended:=false

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	tick_voice=_voice("CaseCardTick",TICK_VOLUME_DB)
	tick_voice.stream=TICK
	accent_voice=_voice("CaseAccent",ACCENT_VOLUME_DB)

func _voice(voice_name:String,gain_db:float)->AudioStreamPlayer:
	var voice:=AudioStreamPlayer.new()
	voice.name=voice_name
	voice.bus="SFX"
	voice.volume_db=gain_db
	voice.max_polyphony=1
	voice.autoplay=false
	add_child(voice)
	return voice

func _can_play()->bool:
	if not is_inside_tree() or not focused or app_suspended:return false
	var bus:=AudioServer.get_bus_index("SFX")
	# Fail quiet if the game's bus layout has not been initialized yet.
	return bus>=0 and not AudioServer.is_bus_mute(bus) and not AudioServer.is_bus_mute(0)

func play_open()->void:
	stop_all()
	_play_accent(OPEN)

func play_tick()->void:
	if not _can_play() or not is_instance_valid(tick_voice):return
	var now:=Time.get_ticks_msec()
	if now-last_tick_msec<TICK_INTERVAL_MS:return
	last_tick_msec=now
	tick_voice.play()

func play_reveal(rarity:String)->void:
	# Unknown rarity must not accidentally sound like a high-value reward.
	if not REVEALS.has(rarity):return
	if is_instance_valid(tick_voice):tick_voice.stop()
	_play_accent(REVEALS[rarity])

func _play_accent(stream:AudioStream)->void:
	if not _can_play() or not is_instance_valid(accent_voice):return
	accent_voice.stop()
	accent_voice.stream=stream
	accent_voice.play()

func stop_all()->void:
	if is_instance_valid(tick_voice):tick_voice.stop()
	if is_instance_valid(accent_voice):accent_voice.stop()
	last_tick_msec=-TICK_INTERVAL_MS

func _process(_delta:float)->void:
	# Do not leave a tail waiting to become audible after an SFX/focus change.
	if not _can_play():stop_all()

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused=false;stop_all()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		focused=true
	elif what==NOTIFICATION_APPLICATION_PAUSED:
		app_suspended=true;stop_all()
	elif what==NOTIFICATION_APPLICATION_RESUMED:
		app_suspended=false

func _exit_tree()->void:
	stop_all()
