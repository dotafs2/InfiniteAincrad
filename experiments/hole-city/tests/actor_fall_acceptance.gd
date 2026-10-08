extends SceneTree
var game:Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
 for i in n:await physics_frame
func drop(body:RigidBody3D,label:String)->void:
 body.support_parent=null
 game.player.position=Vector3(body.position.x,0,body.position.z)
 game.player.radius=maxf(3.0,body.footprint*1.5)
 game.player._sync_shape()
 var score:int=game.player.score
 check(body.can_fit(game.player),label+": eligible for the same footprint gate")
 check(body.begin_swallow(game.player),label+": releases to gravity")
 check(not body.freeze and not body.lock_rotation and game.player.score==score,label+": controller relinquishes physics without early scoring")
 for i in 480:
  await physics_frame
  if not is_instance_valid(body):break
 check(not is_instance_valid(body) and game.player.score>score,label+": falls below the floor and awards once")
func run()->void:
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.start_level();game.begin_play()
 game.set_physics_process(false)
 for h in game.holes:
  h.enabled=false
  if h!=game.player:h.active=false
 await frames(3)
 var authored_objects:=0
 for a in game.city.recipe_actors:authored_objects+=a.definition.objects.size()
 check(game.city.foods.size()==504+authored_objects,"all authored objects, including independent loose parts, enter the physical registry")
 check(game.city.citizens.all(func(c):return c.body.can_fit(game.player)),"all 64 living citizens are eligible at the starting radius")
 check(game.city.ambient_actors.filter(func(a):return a.kind in ["StreetBot","TransitBeacon"]).all(func(a):return absf(a.body.position.y-a.body.half_size.y-.04)<.001),"ground robots and beacons stand on the pavement instead of hovering")
 await drop(game.city.citizens[0].body,"citizen")
 var pulled:RigidBody3D=game.city.citizens[1].body
 pulled.position=Vector3(60,pulled.half_size.y+.05,10)
 game.player.position=Vector3(68,0,10);game.player.radius=1;game.player._sync_shape()
 await frames(3)
 pulled.begin_pull(game.player)
 check(pulled.collision_mask==1 and not pulled.freeze,"pull restores ground collision on an animated citizen")
 await frames(90)
 check(is_instance_valid(pulled) and pulled.position.y>0 and not pulled.consumed,"released citizen settles on intact ground instead of falling through the map")
 pulled.queue_free()
 var pulled_car:RigidBody3D=game.city.moving_vehicles[0].body
 pulled_car.position=Vector3(60,pulled_car.half_size.y+.05,10)
 game.player.position=Vector3(72,0,10);game.player.radius=5;game.player._sync_shape()
 check(pulled_car.begin_pull(game.player),"moving car hands skill-pull motion to physics")
 var released_transform:=pulled_car.transform
 game.city._process(0.0)
 check(pulled_car.transform.is_equal_approx(released_transform),"traffic controller does not snap a released car back to its lane")
 pulled_car.queue_free()
 await drop(game.city.ambient_actors[0].body,"hover drone")
 await drop(game.city.ambient_actors[1].body,"street robot")
 var outdoor:Dictionary=game.city.recipe_actors.filter(func(a):return not is_instance_valid(a.body.support_parent))[0]
 await drop(outdoor.body,"authored prop")
 await drop(game.city.signal_nodes[0].body,"beacon")
 var host:Node3D
 for entry in game.city.building_visuals:
  if not entry.body.contents.is_empty():host=entry.body;break
 check(is_instance_valid(host),"overlapping interior props have a real building owner")
 if is_instance_valid(host):
  var inside:Node3D=host.contents[0]
  check(not inside.can_fit(game.player),"intact shell protects its contents until support loss")
  game.player.radius=14;game.player.position=Vector3(host.position.x,0,host.position.z);game.player._sync_shape()
  await frames(3)
  host.begin_swallow(game.player)
  for i in 60:
   await physics_frame
   if not is_instance_valid(host):break
  check(not is_instance_valid(host),"host building fractures")
  check(not is_instance_valid(inside) or (not inside.freeze and not is_instance_valid(inside.support_parent)),"fracture releases actual interior objects")
  for i in 480:
   await physics_frame
   if not is_instance_valid(inside):break
  check(not is_instance_valid(inside),"released contents do not remain suspended after the building vanishes")
 var result:={"checks":checks,"failures":failures}
 print("ACTOR_FALL_ACCEPTANCE "+JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
