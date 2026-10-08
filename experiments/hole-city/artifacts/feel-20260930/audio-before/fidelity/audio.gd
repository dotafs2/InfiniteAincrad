extends Node
## One streamed music voice for the whole session. Input unlock is separate
## from preferences: a stored ON setting must never bypass browser autoplay.
const TRACKS:={
	"city":preload("res://assets/audio/sunny_city_loop.ogg"),
	"food":preload("res://assets/audio/snack_garden_loop.ogg"),
}
var music:AudioStreamPlayer
var current_map:="city"
var music_enabled:=true
var sfx_enabled:=true
var unlocked:=false
var focused:=true
var app_suspended:=false
var started:=false

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	music=AudioStreamPlayer.new()
	music.name="BackgroundMusic"
	music.bus="Music"
	# Stream Ogg on the audio thread rather than decoding both full tracks
	# into Web Audio samples. The Web preset already enables thread support.
	music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	_assign_track()
	set_music_enabled(music_enabled)
	set_sfx_enabled(sfx_enabled)

func _assign_track()->void:
	music.stop()
	started=false
	var track:AudioStreamOggVorbis=TRACKS[current_map].duplicate()
	track.loop=true
	track.loop_offset=0.0
	music.stream=track

func set_map(id:String)->void:
	if not TRACKS.has(id) or id==current_map:return
	current_map=id
	if not is_instance_valid(music):return
	_assign_track()
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
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),not sfx_enabled or not focused or app_suspended)

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_focused(false)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		set_focused(true)
	elif what==NOTIFICATION_APPLICATION_PAUSED:
		set_app_suspended(true)
	elif what==NOTIFICATION_APPLICATION_RESUMED:
		set_app_suspended(false)

func _input(event:InputEvent)->void:
	# Let a mute button finish its GUI callback before deciding to play. In
	# particular, holding MUSIC ON to switch it off must not first start music.
	if event is InputEventScreenTouch and not event.pressed:
		unlock_from_gesture.call_deferred()
	elif event is InputEventMouseButton and not event.pressed:
		unlock_from_gesture.call_deferred()
	elif event is InputEventKey and not event.pressed and not event.echo:
		unlock_from_gesture.call_deferred()

func _process(_delta:float)->void:
	_sync_playback()

func _sync_playback()->void:
	if not is_instance_valid(music) or not is_inside_tree():return
	var suspended:=not music_enabled or not focused or app_suspended or get_tree().paused
	if unlocked and not suspended and not started:
		music.play()
		started=true
	music.stream_paused=suspended
