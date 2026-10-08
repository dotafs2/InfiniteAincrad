extends SceneTree
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var receipts:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
 for i in n:await physics_frame
func fixture()->Node3D:
 var body:Node3D=game.city.place(game.city.asset("sign",0),Vector2(65,65))
 game.player.position=Vector3(65,0,65);game.player.score=0;game.player.level=1;game.player.radius=.85;game.player._sync_shape()
 return body
func run()->void:
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.start_level();game.begin_play()
 game.set_physics_process(false);game.city.set_process(false)
 for h in game.holes:
  h.enabled=false
  if h!=game.player:h.active=false
 game.item_collected.connect(func(item,hole):receipts.append({"id":item.get_instance_id(),"owner":hole,"top":item.position.y+item.vertical_extent()}))
 var body:Node3D=fixture()
 var id:int=body.get_instance_id()
 await frames(3);game.scan_food();await frames(12)
 check(body.position.y-body.vertical_extent()<-.15 and body.position.y+body.vertical_extent()>0,"actual gravity produces a partially entered lamp")
 game.player.position.x=55
 body._physics_process(1.0/60.0)
 check(not is_instance_valid(body.claimed_by),"departing owner releases a half-submerged lamp before terrain can push it upward")
 var second:Node3D=game.holes[1]
 var at:Vector3=body.interaction_position()
 second.position=Vector3(at.x,0,at.z);second.active=true;second.enabled=false;second.radius=1.2;second.level=2;second.score=10;second._sync_shape()
 await frames(3);game.scan_food()
 check(body.claimed_by==second,"another actual hole claims the released lamp through the normal scan")
 for i in 240:
  await physics_frame
  if not is_instance_valid(body):break
 var own:Array=receipts.filter(func(r):return r.id==id)
 check(own.size()==1 and own[0].owner==second and own[0].top < -3.5,"new owner receives exactly one completed-fall receipt")
 second.active=false
 body=fixture();id=body.get_instance_id()
 await frames(3);game.scan_food()
 for i in 120:
  await physics_frame
  if body.position.y+body.vertical_extent()<-.25:break
 check(body.position.y+body.vertical_extent()<-.25,"second lamp has really passed the surface")
 game.player.position.x=55;body._physics_process(1.0/60.0)
 check(not is_instance_valid(body.claimed_by),"scoring credit is separate from the departed owner's reservation")
 for i in 240:
  await physics_frame
  if not is_instance_valid(body):break
 own=receipts.filter(func(r):return r.id==id)
 check(own.size()==1 and own[0].owner==game.player,"an already-entered fall cannot leak below the world without a scoring receipt")
 body=fixture();await frames(3);game.scan_food();await frames(8)
 body.sleeping=true
 game.player.position.x+=.08
 body._physics_process(1.0/60.0)
 check(not body.sleeping,"a changed opening wakes a sleeping claimed contact without resetting its transform")
 body.queue_free()
 await frames(2)
 body=game.city.place(game.city.asset("traffic_light",2),Vector2(65,65))
 var base:Vector3=body.interaction_position()
 game.player.position=Vector3(base.x,0,base.z);game.player.radius=.85;game.player.level=1;game.player.score=0
 await frames(3);game.scan_food()
 check(body.freeze and not is_instance_valid(body.claimed_by),"an asymmetric long arm is not admitted using an undersized box-center radius")
 check(game.swallow_hint=="GROW TO LVL 3","a genuinely oversized fixture explains its required level in the HUD")
 body.queue_free()
 var report:={"checks":checks,"failures":failures}
 print("CLAIM_RECOVERY_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
