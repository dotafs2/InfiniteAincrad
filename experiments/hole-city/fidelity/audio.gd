extends Node
## A single streamed voice with explicit scene routing and bounded transitions.
## Selection previews do not start level music; every suspension gate is independent.
const TRACKS:={
	"menu":preload("res://assets/audio/shop_theme_loop.ogg"),
	"city":preload("res://assets/audio/worlds/city.ogg"),
	"food":preload("res://assets/audio/worlds/food.ogg"),
	"toys":preload("res://assets/audio/worlds/toys.ogg"),
	"frost":preload("res://assets/audio/worlds/frost.ogg"),
	"case":preload("res://assets/audio/worlds/case.ogg"),
}
const FADE_OUT_SECONDS:=0.20
const FADE_IN_SECONDS:=0.30
const TRANSITION_SECONDS:=0.50
const CASE_DUCK_DB:=-7.0
var music:AudioStreamPlayer
var current_map:="city"
var context:="menu"
var current_track:="menu"
var target_track:="menu"
var music_enabled:=true
var sfx_enabled:=true
var unlocked:=false
var focused:=true
var app_suspended:=false
var ad_active:=false
var started:=false
var bookmark:=0.0
var bookmarks:Dictionary={}
var case_rolling:=false
var _envelope:=1.0
var _duck:=1.0

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	unlocked=OS.get_name()=="iOS"
	music=AudioStreamPlayer.new()
	music.name="BackgroundMusic"
	music.bus="Music"
	music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	music.max_polyphony=1
	add_child(music)
	_assign_track(_desired_track())
	set_music_enabled(music_enabled)
	set_sfx_enabled(sfx_enabled)

func _desired_track()->String:
	return current_map if context=="gameplay" else context

func _remember()->void:
	if started and music.playing:bookmark=music.get_playback_position()
	bookmarks[current_track]=bookmark

func _assign_track(id:String)->void:
	if not is_instance_valid(music):return
	_remember()
	music.stop()
	started=false
	current_track=id
	var track:AudioStreamOggVorbis=TRACKS[id].duplicate()
	track.loop=true
	track.loop_offset=0.0
	music.stream=track
	bookmark=fposmod(float(bookmarks.get(id,0.0)),track.get_length())

func _request_track()->void:
	target_track=_desired_track()
	if not is_instance_valid(music):return
	# Changing a silent route cannot leak the stale track on later resume.
	if not unlocked or _suspended():
		if target_track!=current_track:_assign_track(target_track)
		_envelope=1.0
	_sync_playback()

func set_map(id:String)->void:
	if id not in ["city","food","toys","frost"] or id==current_map:return
	current_map=id
	_request_track()

func set_context(value:String)->void:
	if value not in ["menu","gameplay","case"] or value==context:return
	context=value
	_request_track()

func set_case_rolling(value:bool)->void:
	case_rolling=value

func set_ad_active(value:bool)->void:
	ad_active=value
	_sync_sfx()
	_sync_playback()

func unlock_from_gesture()->void:
	unlocked=true
	_sync_playback()

func set_music_enabled(enabled:bool)->void:
	music_enabled=enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),not enabled)
	_sync_playback()

func set_sfx_enabled(enabled:bool)->void:
	sfx_enabled=enabled
	_sync_sfx()

func set_focused(value:bool)->void:
	focused=value
	_sync_sfx()
	_sync_playback()

func set_app_suspended(value:bool)->void:
	app_suspended=value
	_sync_sfx()
	_sync_playback()

func _sync_sfx()->void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),not sfx_enabled or not focused or app_suspended or ad_active)

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:set_focused(false)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:set_focused(true)
	elif what==NOTIFICATION_APPLICATION_PAUSED:set_app_suspended(true)
	elif what==NOTIFICATION_APPLICATION_RESUMED:set_app_suspended(false)

func _input(event:InputEvent)->void:
	# GUI mute callbacks finish before this deferred first-gesture unlock.
	if event is InputEventScreenTouch and not event.pressed:unlock_from_gesture.call_deferred()
	elif event is InputEventMouseButton and not event.pressed:unlock_from_gesture.call_deferred()
	elif event is InputEventKey and not event.pressed and not event.echo:unlock_from_gesture.call_deferred()

func _suspended()->bool:
	return not music_enabled or not focused or app_suspended or ad_active or (is_inside_tree() and get_tree().paused)

func _process(delta:float)->void:
	if not is_instance_valid(music):return
	if music.playing and not music.stream_paused:bookmark=music.get_playback_position()
	if target_track!=current_track:
		if not unlocked or _suspended():
			_assign_track(target_track);_envelope=1.0
		else:
			_envelope=move_toward(_envelope,0.0,delta/FADE_OUT_SECONDS)
			if _envelope<=0.0:_assign_track(target_track)
	else:
		_envelope=move_toward(_envelope,1.0,delta/FADE_IN_SECONDS)
	var duck_target:float=db_to_linear(CASE_DUCK_DB) if context=="case" and case_rolling else 1.0
	_duck=move_toward(_duck,duck_target,delta/0.20)
	music.volume_db=linear_to_db(maxf(0.00001,_envelope*_duck))
	_sync_playback()

func _sync_playback()->void:
	if not is_instance_valid(music) or not is_inside_tree():return
	var suspended:=_suspended()
	# Commit silent pending routes before any preference/focus/gesture resume.
	if (suspended or not unlocked) and target_track!=current_track:
		_assign_track(target_track);_envelope=1.0
	var interrupted_native:=OS.get_name()=="iOS" and started and not music.playing
	if unlocked and not suspended and (not started or interrupted_native):
		music.play(bookmark)
		started=true
	music.stream_paused=suspended
