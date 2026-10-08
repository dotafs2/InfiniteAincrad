extends SceneTree
## Exercise the actual imported street furniture through the production scan.
var game:Node3D
var rows:Array=[]
var failures:Array[String]=[]
var checks:=0
var receipts:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
 for i in n:await physics_frame
func collect(item:Node3D,_hole:Node3D)->void:receipts[item.get_instance_id()]=true
func run()->void:
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.start_level();game.begin_play()
 game.item_collected.connect(collect)
 game.set_physics_process(false);game.city.set_process(false)
 for h in game.holes:
  h.enabled=false
  if h!=game.player:h.active=false
 var kinds:Array=["lamp","sign","traffic_light"]
 if OS.get_cmdline_user_args().has("--all-props"):kinds=["bin","cone","lamp","bench","bollard","hydrant","mailbox","bus_stop","kiosk","barrier","planter","bike_rack","traffic_light","sign","dumpster","fence"]
 for kind in kinds:
  for variant in 4:
   for approach in [Vector2.ZERO,Vector2(-.55,0),Vector2(.55,0),Vector2(0,.55)]:
    var body:Node3D=game.city.place(game.city.asset(kind,variant),Vector2(65,65))
    if approach==Vector2.ZERO:
     check(body.get_meta("compound_collision",false) and body.get_meta("collision_source_sha256","")==game.city.asset(kind,variant).file_sha256,kind+str(variant)+": compound hulls match the actual shipped model")
    var id:int=body.get_instance_id()
    var radius:=.85
    for i in game.player.RADII.size():
     radius=game.player.RADII[i]
     if body.footprint*1.08<=radius:
      game.player.level=i+1;game.player.score=game.player.LEVEL_STARTS[i];break
    game.player.radius=radius
    var support:Vector3=body.interaction_position()
    game.player.position=Vector3(support.x+approach.x*radius,0,support.z+approach.y*radius);game.player._sync_shape()
    await frames(3)
    var before:int=game.player.score
    game.scan_food()
    check(is_instance_valid(body.claimed_by),kind+str(variant)+str(approach)+": normal scan releases eligible object")
    check(game.player.score==before,"contact does not score")
    for i in 180:
     await physics_frame
     if not is_instance_valid(body):break
    var row:={"asset":game.city.asset(kind,variant).id,"approach":str(approach),"radius":radius,"collected":receipts.has(id)}
    row["rim_rest"]=is_instance_valid(body)
    if is_instance_valid(body):
     # A supported overhang may rest on the rim. Moving off it must release
     # ownership, and centering the opening must let the same object recover.
     game.player.position=Vector3(55,0,65)
     await frames(3)
     if not is_instance_valid(body):
      check(receipts.has(id),row.asset+": in-flight object may complete collection while the mouth leaves")
     else:
      check(not is_instance_valid(body.claimed_by),row.asset+": partial entry releases a departed owner")
      var at:Vector3=body.interaction_position()
      game.player.position=Vector3(at.x,0,at.z)
      game.player._sync_shape();await frames(3);game.scan_food()
      for i in 240:
       if i%6==0:game.scan_food()
       await physics_frame
       if not is_instance_valid(body):break
     row["collected"]=receipts.has(id)
    if is_instance_valid(body):
     row["end"]={"position":str(body.position),"tilt":rad_to_deg(acos(clampf(body.basis.y.normalized().dot(Vector3.UP),-1,1))),"claimed":is_instance_valid(body.claimed_by),"sleeping":body.sleeping}
     body.free()
    check(receipts.has(id),row.asset+" "+str(approach)+": collection after entry or rim-contact recovery")
    rows.append(row)
    print("STREET_PROP_QA_ROW "+JSON.stringify(row))
    await frames(2)
 var report:={"checks":checks,"failures":failures,"rows":rows}
 print("STREET_PROP_QA_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
