extends SceneTree
var game:Node
var frames:=0
func _initialize()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	run.call_deferred()
func run()->void:
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	print("NATIVE_CAPTURE_PROBE "+JSON.stringify({"display":DisplayServer.get_name(),"rendering":RenderingServer.get_current_rendering_method(),"version":ProjectSettings.get_setting("application/config/version"),"test_save":game.progress_file()}))
func _process(_delta:float)->bool:
	frames+=1
	if frames>=60:quit()
	return false
