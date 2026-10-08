extends SceneTree
## Deterministic normal-control capture, not real-time performance evidence.
const Game=preload("res://scripts/game.gd")
var game:Node3D
var output:=""
var policy:="sweep"
var capture_frames:=false
var frame:=0
var seen_waves:Array=[]
var milestones:Array=[]
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
  if arg=="--frames":capture_frames=true
 call_deferred("run")
func run() -> void:
 root.size=Vector2i(720,1280);DisplayServer.window_set_size(Vector2i(720,1280))
 game=Game.new();root.add_child(game);game.qa_mode=true;game.audio_enabled=false
 game.set_process(false);game.set_physics_process(false)
 for i in range(10):await process_frame
 game.start_game();game.set_quality("low");Engine.max_fps=0
 for tick in range(8400):
  if game.phase!="playing":break
  control();game._physics_process(1.0/60)
  if tick%60==0:await process_frame
  if tick in [3003,4203,5403,7203]:
   game._process(0);game.hud.queue_redraw()
   for j in range(4):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("time-%05.1f.png"%game.elapsed))
   print("SHOT ",game.elapsed)
 game.queue_free();await process_frame;quit()

func control() -> void:
 var target: float
 if game.squad.members.size()<36 and game.elapsed<38: target=4.55
 elif game.tier<3 and game.elapsed<50: target=2.8
 else: target=-2.4+2.0*sin(game.wave_clock*0.6)
 if policy=="sweep" and game.boss_dead:
  var remaining_x:=0.0;var visible_count:=0
  for c in game.crowd:
   if c.alive and game.camera.is_position_in_frustum(Vector3(c.x,0.55,game.crowd_front-c.z)):
    remaining_x+=c.x;visible_count+=1
  if visible_count==0:
   for elite in game.encounters.enemies:
    if elite.alive and game.camera.is_position_in_frustum(elite.node.position):
     remaining_x+=elite.node.position.x;visible_count+=1
  if visible_count>0:target=remaining_x/visible_count
 if policy in ["variety","sweep"]:
  var unlocked:=mini(5,game.wave+1)
  choose_weapon(game.Campaign.WEAPONS[(unlocked-1+int(game.wave_clock/4.0))%unlocked])
 elif policy not in ["idle","rifle"]:
  if game.wave>=4: choose_weapon("rail" if not game.boss_dead else "arc")
  elif game.wave>=3: choose_weapon("rail" if not game.boss_dead else "rocket")
  elif game.wave>=2: choose_weapon("rail")
  elif game.wave>=1: choose_weapon("scatter")
 # Test policy may read visible hazard positions, but only supplies controls.
 var urgent:=false
 for h in game.encounters.hazards:
  if h.life<0.65: urgent=true
 if urgent and policy!="no-dodge":
  var best_score: float=-INF
  var limit: float=game.squad.center_limit()
  for sample in range(11):
   var candidate:=lerpf(-limit,limit,float(sample)/10)
   var clearance:=5.0
   for h in game.encounters.hazards:
    if h.life>0.65: continue
    var core: Vector3=game.squad.hurtbox_position()
    clearance=minf(clearance,Vector2(candidate-h.x,core.z-h.z).length()-h.radius-game.squad.hurtbox_radius)
   var score: float=clearance-absf(candidate-clampf(target,-limit,limit))*0.01
   if score>best_score: best_score=score;target=candidate
 if policy!="idle": steer_world(target)

func steer_world(x: float) -> void:
 var event: InputEvent
 if not game.dragging:
  event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 else: event=InputEventMouseMotion.new()
 event.position=game.camera.unproject_position(Vector3(x,0,game.PLAYER_Z))
 game._unhandled_input(event)

func choose_weapon(mode: String) -> void:
 if game.weapon_mode==mode: return
 var event:=InputEventKey.new()
 event.pressed=true;event.keycode=KEY_1+game.Campaign.WEAPONS.find(mode)
 game._unhandled_input(event)

