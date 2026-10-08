extends SceneTree
## Rain's swept support can sleep without a native contact island. Losing the
## actual support owner must still release the existing physical and visual body.
const KINDS=["bacon","egg","cake","donut","burger","cookie","berry","sushi","pancake","pizza"]
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var records:Array=[]
var collected:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
 for i in count:await physics_frame
func clear_site()->Vector2:
 var box:=BoxShape3D.new();box.size=Vector3(13,20,9)
 var q:=PhysicsShapeQueryParameters3D.new();q.shape=box;q.collision_mask=3;q.exclude=[game.ground.body.get_rid()]
 for x in [-91.0,91.0,0.0,-45.0,45.0]:
  for z in [-64.0,-40.0,-16.0,16.0,40.0,64.0,88.0,-88.0]:
   q.transform=Transform3D(Basis.IDENTITY,Vector3(x,10.1,z))
   if game.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():return Vector2(x,z)
 return Vector2(INF,INF)
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false);game.set_process(false)
 game.item_collected.connect(func(_body,_owner):collected+=1)
 game.city.set_physics_process(false);game.city.rain_enabled=false
 for h in game.holes:h.enabled=false;h.active=false;h.set_physics_process(false)
 game.ground.sync();await frames(3)
 var at:=clear_site();check(at.is_finite(),"Ten-recipe fixture has an actually clear layer1/2 collision column")
 if not at.is_finite():game.free();await frames(2);quit(1);return
 for mode in ["deleted","moved"]:
  var platform:=StaticBody3D.new();platform.collision_layer=1;platform.collision_mask=3
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12,.5,8);shape.shape=box;platform.add_child(shape)
  game.world.add_child(platform);platform.position=Vector3(at.x,6,at.y);await frames(2)
  var bodies:Array=[];var old_ids:Array=[];var old_heights:Array=[];var old_meshes:Array=[]
  for i in 10:
   var place:Vector2=at+Vector2(-4.8+(i%5)*2.4,-2.5+(i/5)*5.0)
   var b=game.city.spawn_rain(KINDS[i],place,9)
   b.rotation=Vector3(.12,float(i)*.37,.16)
   bodies.append(b);old_ids.append(b.get_instance_id());old_meshes.append(b.food_visual.mesh)
  await frames(420);game.city.batch_settled_rain()
  for i in 10:
   var b=bodies[i];old_heights.append(b.position.y)
   check(b.rain_landed and b.sleeping and b.batch!=null,"All ten rotated recipes naturally settle and batch on elevated support: "+mode+"/"+KINDS[i])
   check(b.rain_support!=null and b.rain_support.get_ref()==platform,"Remembered support is the actual ray collider, not a height or proxy: "+mode+"/"+KINDS[i])
  if mode=="deleted":platform.free()
  else:platform.position.x+=20
  await frames(30)
  for i in 10:
   var b=bodies[i]
   check(is_instance_valid(b) and b.get_instance_id()==old_ids[i] and b.position.y<old_heights[i]-.2 and not b.freeze and not b.rain_landed,"Support change causes genuine gravity descent of the same food: "+mode+"/"+KINDS[i])
   check(b.batch==null and b.food_visual.visible and b.food_visual.mesh==old_meshes[i],"The real moving mesh replaces its retired batch slot: "+mode+"/"+KINDS[i])
  await frames(390)
  for i in 10:
   var b=bodies[i]
   check(is_instance_valid(b) and b.rain_landed and b.position.y-b.vertical_extent()<.08,"Released food reaches real terrain and remains present: "+mode+"/"+KINDS[i])
   records.append({"mode":mode,"kind":KINDS[i],"old_y":old_heights[i],"final_y":b.position.y,"landed":b.rain_landed,"sleeping":b.sleeping})
   b.expose_visual();b.queue_free()
  if is_instance_valid(platform):platform.free()
  await frames(3)
 check(game.player.score==0 and collected==0,"Wake and fall never award points without real swallowing")
 game.audio.music.stop();game.free();await frames(2)
 var report:={"checks":checks,"failures":failures,"records":records,"scope":"Actual ten-recipe rotated collider landing and deleted/moved support; no test wake, no fake scoring, no renderer claim."}
 print("RAIN_SUPPORT_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var path:=arg.trim_prefix("--report=")
   if not path.is_absolute_path() or "://" in path:quit(2);return
   FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
 quit(0 if failures.is_empty() else 1)
