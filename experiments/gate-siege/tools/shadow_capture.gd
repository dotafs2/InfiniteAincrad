extends SceneTree
const Game = preload("res://scripts/game.gd")
var game: Node3D
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shadow-output="): output=arg.trim_prefix("--shadow-output=")
	call_deferred("run")

func shot(label: String) -> void:
	game.visual_dirty=true
	game._process(0)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
	print("SHADOW_CAPTURE ",label)

func run() -> void:
	root.size=Vector2i(486,864)
	DisplayServer.window_set_size(Vector2i(486,864))
	game=Game.new()
	root.add_child(game)
	game.qa_mode=true
	game.audio_enabled=false
	game.set_process(false)
	game.set_physics_process(false)
	game.set_quality("low")
	game.start_game()
	game.message_time=0
	for i in range(10): await process_frame
	for t in range(3):
		game.tier=t
		game._set_player_model()
		game.player_x=-1.8
		game.target_x=-1.8
		game._step(1.0/60.0)
		game.bullets.clear()
		await shot("low-tier-"+str(t))
		game.player_shadow_root.hide()
		await shot("disabled-tier-"+str(t))
		game.player_shadow_root.show()
	game.set_quality("battery")
	await shot("battery-mech")
	game.set_quality("high")
	await shot("high-mech")
	game.set_quality("low")
	game.player_x=4.55
	game.target_x=4.55
	game._step(1.0/60.0)
	await shot("low-right-rail")
	game.restart_game()
	game.message_time=0
	game.player_x=2.5
	game.target_x=2.5
	game._step(1.0/60.0)
	game.tier=1
	game._begin_recruit_flight()
	await shot("flight-takeoff")
	game._step_upgrade(0.425)
	await shot("flight-peak")
	game._step_upgrade(0.35)
	await shot("flight-approach")
	# Cross the completion boundary explicitly; decimal sums may stop just short.
	game._step_upgrade(0.075+1.0/60.0)
	assert(not game.recruiting and game.recruit_flight==null)
	assert(game.player_directional_shadow.material_override.get_shader_parameter("shadow_texture")==game.ShadowFootprints.DATA.gunner.texture)
	await shot("flight-landed")
	var receipt:=FileAccess.open(output.path_join("capture-state.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"flight_finished":not game.recruiting,"tier":game.tier,"shadow_texture":game.player_directional_shadow.material_override.get_shader_parameter("shadow_texture").resource_path,"staged":true},"  "))
	game.queue_free()
	await process_frame
	quit()
