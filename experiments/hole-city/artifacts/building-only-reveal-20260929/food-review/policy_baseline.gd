extends SceneTree
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 var old_expected:bool=OS.get_cmdline_user_args().has("--expect-old-policy")
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.selected_map="food";game.start_level();game.begin_play();game.city.set_process(false);game.city.set_physics_process(false);game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.set_physics_process(false)
 for item in game.city.foods:item.set_physics_process(false)
 for kind in ["burger","donut"]:
  var tower:Dictionary=game.city.towers.filter(func(t):return t.family=="apartments" and t.kind==kind)[0]
  var body:Node3D=tower.base
  var visual:MeshInstance3D=body.food_visual
  var faces:PackedVector3Array=visual.mesh.get_faces();var point:=Vector3.ZERO;var found:=false
  for i in range(0,faces.size(),3):
   var a:Vector3=visual.global_transform*faces[i];var b:Vector3=visual.global_transform*faces[i+1];var c:Vector3=visual.global_transform*faces[i+2]
   if absf((b-a).cross(c-a).normalized().y)>.5 and (a.y+b.y+c.y)/3.0>.02:point=(a+b+c)/3.0;found=true;break
  game.camera.position=Vector3(point.x,point.y+18,point.z);game.player.position=Vector3(point.x,0,point.z);game.player.radius=.85;game.player.velocity=Vector3.ZERO
  game.camera.look_at(game.player.position,Vector3.FORWARD);game.update_reveal(1)
  var hit:=false
  for i in range(0,faces.size(),3):
   if Geometry3D.segment_intersects_triangle(game.camera.position,game.player.position,visual.global_transform*faces[i],visual.global_transform*faces[i+1],visual.global_transform*faces[i+2])!=null:hit=true;break
  var candidate:bool=game.reveal.is_structural_candidate(body);var weight:float=game.reveal.body_reveal_weight(body)
  check(found and hit,kind+": actual recipe geometry blocks the controlled mouth ray")
  check(candidate==old_expected,kind+": actual tier candidate matches the explicitly selected baseline/current policy")
  check(weight>0.99 if old_expected else weight==0,kind+": actual controller dispatch matches baseline/current policy")
  observations.append({"kind":kind,"at":str(tower.at),"own_height":body.height,"own_width":maxf(body.half_size.x,body.half_size.z)*2,"aggregate_height":body.get_meta("structure_height"),"aggregate_width":body.get_meta("structure_width"),"candidate":candidate,"weight":weight,"actual_mesh_blocks":hit})
 game.free();await process_frame
 print("FOOD_POLICY_BASELINE "+JSON.stringify({"checks":checks,"failures":failures,"expected_old_policy":old_expected,"observations":observations,"scope":"Controlled camera over real food tiers; no browser, saved progress or performance claim"}))
 quit(0 if failures.is_empty() else 1)
