extends SceneTree
var game:Node3D
func _initialize()->void:run.call_deferred()
func shape(body:Node3D)->Shape3D:
 for child in body.get_children():
  if child is CollisionShape3D:return child.shape
 return null
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.begin_play()
 game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
 game.ground.sync()
 var bodies:Array[Node3D]=[];var before:Array=[];var next_floor:=.6
 for i in 8:
  var kind:="cookie" if i%2==0 or i>=6 else "burger"
  var at:=Vector2(70,24) if i<6 else Vector2(63+(i-6)*14,24)
  var body:Node3D=game.city.food(kind,at,.7,2)
  body.rotation=Vector3(.12*(i%6),.17*(i%6),.2)
  var extent:float=body.vertical_extent()
  body.position.y=(next_floor if i<6 else .6)+extent
  if i<6:next_floor=body.position.y+extent+.16
  body.freeze=false;body.collision_layer=2;body.collision_mask=3
  body.collapse_started=true;body.max_contacts_reported=4;body.set_physics_process(true)
  bodies.append(body)
  before.append({"index":i,"kind":kind,"start":str(body.position),"shape":shape(body).get_class(),"extent":extent,"continuous_cd":body.continuous_cd})
 var trace:Array=[]
 for tick in 540:
  await physics_frame
  if tick%30==29:
   var at:Array=[]
   for b in bodies:at.append({"p":str(b.position),"v":str(b.linear_velocity),"w":str(b.angular_velocity)})
   trace.append({"frame":tick+1,"bodies":at})
 print("FOOD_CONTACT_PROBE "+JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"before":before,"trace":trace}))
 game.free();await process_frame;quit()
