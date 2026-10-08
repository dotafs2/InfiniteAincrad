extends SceneTree
## Independent actual-touch and durable-setting review. Disposable save only.
const Game=preload("res://fidelity/game.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var save_path:="/tmp/hole-feast-haptics-%d.cfg"%OS.get_process_id()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=3)->void:
	for _i in count:await process_frame
func target()->Button:
	for button in game.ui.buttons:
		if button.name=="feedback-haptics":return button
	return null
func tap_haptics()->void:
	var button:=target()
	check(button!=null,"The pause menu exposes the real haptic button")
	if button==null:return
	var point:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=0;event.position=point;event.pressed=pressed
		root.push_input(event,true);await frames()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	root.size=Vector2i(540,1174)
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames()
	game.test_progress_path=save_path
	game.music_enabled=false;game.sfx_enabled=true
	check(game.save_player_progress(),"The isolated starting profile saves")
	game.start_level();game.begin_play();game.set_physics_process(false)
	game.toggle_pause();await frames()
	check(paused and target().text=="HAPTIC ON","A real paused run starts with the enabled label")
	await tap_haptics()
	check(not game.haptics_enabled and not game.feedback.haptics_enabled,"Real screen touch disables both persisted choice and feedback driver")
	check(target().text=="HAPTIC OFF","The actual control immediately shows the disabled state")
	check(not game.music_enabled and game.sfx_enabled,"Haptic changes preserve independent music and sound choices")
	var cfg:=ConfigFile.new()
	check(cfg.load(save_path)==OK and not bool(cfg.get_value("audio","haptics_enabled",true)),"The disabled choice reaches disk")
	var restored:=Game.new();restored.test_progress_path=save_path
	check(restored.load_player_progress() and not restored.haptics_enabled and not restored.music_enabled and restored.sfx_enabled,"A cold state restores all three independent preferences")
	restored.free()
	await tap_haptics()
	check(game.haptics_enabled and game.feedback.haptics_enabled and target().text=="HAPTIC ON","A second real touch restores the driver and label")
	game.test_progress_path=save_path+"-missing-parent/settings.cfg"
	await tap_haptics()
	check(game.haptics_enabled and game.feedback.haptics_enabled,"A failed durable write rolls back the choice and driver")
	check(target().text=="HAPTIC ON" and game.ui.toast.contains("Could not save haptic settings"),"Failed saving is visible without a misleading OFF label")
	cfg.load(save_path);cfg.erase_section_key("audio","haptics_enabled");cfg.save(save_path)
	var legacy:=Game.new();legacy.test_progress_path=save_path
	check(legacy.load_player_progress() and legacy.haptics_enabled,"Existing profiles without a haptic key default to enabled")
	legacy.free();paused=false;game.free();await frames()
	for path in [save_path,save_path+".tmp"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("HAPTIC_PREFERENCE_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"actual_touch":true,"disposable_save":true}))
	quit(0 if failures.is_empty() else 1)
