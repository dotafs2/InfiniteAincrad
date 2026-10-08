extends SceneTree
## Staged composition evidence. Each scenario starts from a fresh game instance.
const Game=preload("res://scripts/game.gd")
var game:Node3D
var output:=""
func _initialize() -> void:
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--out="):output=a.trim_prefix("--out=")
 call_deferred("run")
func fresh(which_wave:int,role:int,count:int) -> void:
 if is_instance_valid(game):
  game.queue_free();await process_frame
 game=Game.new();root.add_child(game);game.qa_mode=true;game.audio_enabled=false
 game.set_process(false);game.set_physics_process(false);game.start_game()
 game.tier=role;game.recruit_remaining=float(game.RECRUIT_COSTS[role]) if role<3 else 0.0;game._set_player_model();game.squad.rebuild()
 for i in range(count-1):game.squad.add_member()
 game.wave=which_wave;game._start_wave();game.player_x=0;game.target_x=0
 game.squad.update_visuals();game._step_recruit_lane(0);game._update_player_shadow();game.message_time=0
 for member in game.squad.members:member.clock=999.0
 for i in range(8):await process_frame
func shot(label:String) -> void:
 game.visual_dirty=true;game._process(0);game.hud.queue_redraw()
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
 print("CAPTURE ",label)
func run() -> void:
 root.size=Vector2i(720,1280);DisplayServer.window_set_size(Vector2i(720,1280))
 await fresh(0,0,1);game._step(.1);await shot("opening")
 await fresh(0,1,12)
 for i in range(40):
  for member in game.squad.members:member.clock=0
  game._step(1.0/60)
 game.message_time=0;await shot("squad12-fire")
 await fresh(3,2,36)
 game.sim_time=PI/12.8;game._step_enemies(0);await shot("dragon36-wings-up")
 game.sim_time=3*PI/12.8;game._step_enemies(0);await shot("dragon36-wings-down")
 await fresh(1,2,24);game._step(.1);await shot("golem")
 await fresh(2,1,24);game._step(.1);await shot("skitter")
 await fresh(3,2,36);game.upgrade_flash=0.6;game.squad.update_visuals();await shot("upgrade36")
 game.queue_free();await process_frame;quit()
