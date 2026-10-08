extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 root.size=Vector2i(540,960)
 var game=load("res://fidelity/game.gd").new();root.add_child(game);game.set_physics_process(false)
 for i in 3:await process_frame
 var b=game.ui.get_node("audio-music");b.grab_focus()
 var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true
 root.push_input(key,true)
 for i in 5:await process_frame
 print("KEYBOARD_HOLD ",JSON.stringify({"started":game.audio.started,"unlocked":game.audio.unlocked,"enabled":game.music_enabled,"button_pressed":b.button_pressed}))
 key=key.duplicate();key.pressed=false;root.push_input(key,true)
 for i in 3:await process_frame
 print("KEYBOARD_RELEASE ",JSON.stringify({"started":game.audio.started,"unlocked":game.audio.unlocked,"enabled":game.music_enabled}))
 game.audio.music.stop();OS.delay_msec(100);game.free()
 for i in 2:await process_frame
 quit()
