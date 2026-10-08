extends SceneTree
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var runs:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func percentile(values:Array[float],fraction:float)->float:
 var sorted:=values.duplicate();sorted.sort()
 return sorted[clampi(ceili(fraction*sorted.size())-1,0,sorted.size()-1)]
func sample(label:String)->void:
 var times:Array[float]=[];var controller=game.train_controller
 var before:float=controller.traveled;var blocks:int=controller.blocked_steps
 for i in 600:
  var start:=Time.get_ticks_usec()
  controller.step(1.0/60.0)
  times.append(float(Time.get_ticks_usec()-start)/1000.0)
  await physics_frame
 check(times.size()==600,label+": retain every measured step")
 check(controller.traveled>before+30,label+": real train keeps moving during the sample")
 check(controller.blocked_steps==blocks,label+": sample route remains clear")
 runs.append({"map":game.selected_map,"scenario":label,"samples":600,"median_ms":percentile(times,.5),"p95_ms":percentile(times,.95),"p99_ms":percentile(times,.99),"max_ms":times.max(),"mean_ms":times.reduce(func(a,b):return a+b,0.0)/times.size(),"times_ms":times,"diagnostics":controller.diagnostics()})
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 for map_id in ["city","food"]:
  game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
  game.selected_map=map_id;game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
  game.city.set_process(false)
  if map_id=="food":game.city.rain_enabled=false
  for hole in game.holes:hole.active=false;hole.enabled=false;hole.set_physics_process(false)
  game.ground.sync()
  for i in 3:await physics_frame
  await sample("intact")
  var body:Node3D=game.train_controller.cars[2]
  game.player.active=true;game.player.radius=body.footprint*1.08+.2;game.player._sync_shape();game.player.position=Vector3(body.position.x,0,body.position.z)
  game.ground.sync()
  for i in 3:await physics_frame
  game.scan_food()
  check(body.claimed_by==game.player,map_id+": cut scenario starts through actual scan admission")
  await sample("middle_cut_including_initial_planning")
  check(not is_instance_valid(body),map_id+": sampled admitted section actually completes its physical fall")
  game.free();await process_frame
 print("TRAIN_STEP_PROFILE "+JSON.stringify({"checks":checks,"failures":failures,"runs":runs,"scope":"Isolated native Mac headless controller.step CPU durations; includes actual physics queries and branch-change callbacks, excludes rendering and all remaining game costs. Not iPhone or whole-frame FPS."}))
 quit(0 if failures.is_empty() else 1)
