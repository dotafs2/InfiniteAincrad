extends Node
## Explicit local-only QA; never enabled in ordinary play and never uploaded.
var game:Node3D
var frames_ms:Array[float]=[]
var feedback_events:Array[Dictionary]=[]
var audio_samples:Array[Dictionary]=[]
var captures:Array[Dictionary]=[]
var previous_usec:=0
var clock:=0.0
var next_sample:=0.0
var next_capture:=0
var finished:=false
const MOMENTS:=[1.0,8.0,20.0,40.0,58.0]
var directory:="user://native-qa"
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(directory)
	game.feedback.feedback_triggered.connect(func(details:Dictionary):feedback_events.append(details))
func _process(delta:float)->void:
	if finished:return
	var now:=Time.get_ticks_usec()
	if previous_usec>0 and not get_tree().paused and game.phase=="playing":
		frames_ms.append(float(now-previous_usec)/1000.0)
	previous_usec=now;clock+=delta
	if clock>=next_sample:
		next_sample=clock+1.0
		var bus:=AudioServer.get_bus_index("Music")
		audio_samples.append({"time":clock,"playing":game.audio.music.playing,
			"paused":game.audio.music.stream_paused,"position":game.audio.music.get_playback_position(),
			"peak_db":AudioServer.get_bus_peak_volume_left_db(bus,0),"muted":AudioServer.is_bus_mute(bus)})
	if next_capture<MOMENTS.size() and clock>=MOMENTS[next_capture]:
		var index:=next_capture;next_capture+=1;capture.call_deferred(index)
	if clock>=65.0:
		finished=true;write_report()
func capture(index:int)->void:
	await RenderingServer.frame_post_draw
	var file:="%s/%s-%02d.png"%[directory,game.selected_map,index]
	var error:=get_viewport().get_texture().get_image().save_png(file)
	captures.append({"file":file,"error":error,"elapsed":game.elapsed,"score":game.player.score,
		"level":game.player.level,"position":game.player.position,"phase":game.phase})
func write_report()->void:
	var ordered:=frames_ms.duplicate();ordered.sort()
	var mean:=0.0
	for value in ordered:mean+=value
	mean/=maxi(1,ordered.size())
	var file:=FileAccess.open(directory+"/"+game.selected_map+"-report.json",FileAccess.WRITE)
	if file==null:push_error("Cannot save native QA report");return
	file.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),
		"platform":OS.get_name(),"screen_pixels":DisplayServer.window_get_size(),
		"safe_pixels":DisplayServer.get_display_safe_area(),"viewport":get_viewport().get_visible_rect(),
		"ui_transform":game.ui.get_global_transform_with_canvas(),"captures":captures,
		"audio_samples":audio_samples,"feedback_events":feedback_events,"frame_count":ordered.size(),
		"mean_frame_ms":mean,"p95_frame_ms":ordered[int(ordered.size()*.95)] if not ordered.is_empty() else 0,
		"phase":game.phase,"elapsed":game.elapsed,"score":game.player.score,
		"test_wallet":true,"native_services_initialized":false,
		"scope":"Local gameplay/frame/audio-output state. Human audibility and haptic sensation are not established."},"\t"))
	print("NATIVE_QA_REPORT "+directory+"/"+game.selected_map+"-report.json")
