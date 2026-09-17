extends SceneTree
## Presentation capture only: unchanged product scene and existing V overview.
## Product's restore-only capture owns the native PNG, evidence and bounded exit.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if not OS.get_cmdline_user_args().has("--town-restore"):
		quit(2)
		return
	var scene: Node = load("res://scenes/town_street.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.6).timeout
	var press := InputEventKey.new()
	press.keycode = KEY_V
	press.pressed = true
	Input.parse_input_event(press)
