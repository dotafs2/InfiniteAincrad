extends SceneTree
## Survey every shipped city instance, not only procedural recipes or samples.
var game:Node3D
var receipts:Dictionary={}
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
var initial:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func collect(item:Node3D,_hole:Node3D)->void:
 receipts[item.get_instance_id()]={"top":item.position.y+item.vertical_extent(),"points":item.points}
func frames(n:int)->void:
 for i in n:await physics_frame
func blockers(body:Node3D)->Array:
 var names:Array=[]
 for shape in body.find_children("*","CollisionShape3D",true,false):
  var q:=PhysicsShapeQueryParameters3D.new()
  q.shape=shape.shape;q.transform=shape.global_transform;q.collision_mask=1;q.exclude=[body.get_rid()]
  for hit in body.get_world_3d().direct_space_state.intersect_shape(q):
   var n:String=str(hit.collider.name)
   if hit.collider is RigidBody3D and n not in names:names.append(n)
 return names
func run()->void:
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.start_level();game.begin_play()
 game.item_collected.connect(collect)
 game.set_physics_process(false);game.city.set_process(false)
 for h in game.holes:
  h.enabled=false
  if h!=game.player:h.active=false
 await frames(3)
 for body in game.city.foods:
  initial.append({"body":body,"id":body.get_instance_id(),"name":str(body.name),"asset":body.get_meta("asset_id",""),"category":body.category,"start":str(body.position),"footprint":body.footprint})
 initial.sort_custom(func(a,b):return a.footprint<b.footprint)
 for c in initial:
  if not is_instance_valid(c.body) or is_instance_valid(c.body.support_parent):continue
  var body:Node3D=c.body
  var before_blockers:=blockers(body)
  for i in game.player.RADII.size():
   if game.player.RADII[i]>=body.footprint*1.08:
    game.player.level=i+1;game.player.score=game.player.LEVEL_STARTS[i];game.player.radius=game.player.RADII[i];break
  var at:Vector3=body.interaction_position()
  game.player.position=Vector3(at.x,0,at.z);game.player._sync_shape()
  await frames(3)
  if not is_instance_valid(body):continue
  game.scan_food()
  for i in 360:
   if i%6==0:game.scan_food()
   await physics_frame
   if not is_instance_valid(body):break
  var row:={"name":c.name,"asset":c.asset,"category":c.category,"start":c.start,"radius":game.player.radius,"spawn_blockers":before_blockers}
  if is_instance_valid(body):
   row["result"]="stuck";row["end"]={"position":str(body.position),"frozen":body.freeze,"sleeping":body.sleeping,"claimed":is_instance_valid(body.claimed_by),"blockers":blockers(body)}
  else:row["result"]="collected"
  rows.append(row);print("FULL_CITY_QA_ROW "+JSON.stringify(row))
  check(row.result!="stuck",c.name+": focused drop finishes at its eligible game level")
  # Keep the opening in place for neighboring objects and released contents.
  await frames(90)
 for c in initial:
  if c.category=="building":check(not is_instance_valid(c.body) and receipts.has(c.id) and receipts[c.id].points==48 and receipts[c.id].top < -3.5,c.name+": whole original building pays 48 only after complete gravity fall")
  else:check(receipts.has(c.id),c.name+": actual individual collection callback")
 var remaining:Array=[]
 for c in initial:
  if c.category!="building" and not receipts.has(c.id):remaining.append({"name":c.name,"asset":c.asset,"category":c.category,"position":str(c.body.position) if is_instance_valid(c.body) else "removed without collection"})
 var report:={"checks":checks,"failures":failures,"initial":initial.size(),"collected_initial":initial.filter(func(c):return receipts.has(c.id)).size(),"buildings":initial.filter(func(c):return c.category=="building").size(),"remaining":remaining,"rows":rows}
 print("FULL_CITY_QA_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
