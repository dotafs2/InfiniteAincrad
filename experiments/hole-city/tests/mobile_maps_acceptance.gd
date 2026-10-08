extends SceneTree
const Layout=preload("res://fidelity/street_layout.gd")
const FoodMap=preload("res://fidelity/food_city.gd")
var failures:Array[String]=[]
var checks:=0
var game:Node3D
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
 for i in n:await physics_frame
func solid(at:Vector2)->bool:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,2,at.y),Vector3(at.x,-.2,at.y),1)
 return not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func run()->void:
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 await frames(3)
 check(game.selected_map=="city","test saves default to city")
 game.select_map("food")
 check(game.selected_map=="food" and game.ui.map_carousel.current_id()=="food" and game.ui.map_carousel.photos[1].texture!=null and not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Food selection updates its real screenshot card with no live map viewport")
 game.select_map("invalid")
 check(game.selected_map=="food","unknown map IDs cannot enter gameplay")
 for map in ["city","food"]:
  game.selected_map=map;game.start_level();game.begin_play()
  if map=="food":
   check(game.city is FoodMap,"Starting food gameplay still creates the full physical food city")
   game.city.rain_enabled=false
  for h in game.holes:h.enabled=false
  game.set_physics_process(false)
  game.player.position=Vector3(65,0,65)
  await frames(3)
  check(game.city.moving_vehicles.size()==8,map+": eight unique moving vehicles")
  if map=="city":
   check(game.city.used_assets.size()==208,"city retains all 208 original assets")
   var parcels_clear:=true
   for entry in game.city.building_visuals:
    var b:Node3D=entry.body
    var extent:Vector2=entry.half
    if absf(sin(b.rotation.y))>.5:extent=Vector2(extent.y,extent.x)
    var parcel:=Rect2(Vector2(b.position.x,b.position.z)-extent,extent*2)
    for sidewalk in Layout.SIDEWALKS:
     if parcel.intersects(sidewalk):parcels_clear=false
    for corner in [parcel.position,parcel.end,Vector2(parcel.position.x,parcel.end.y),Vector2(parcel.end.x,parcel.position.y)]:
     if Layout.on_road(corner):parcels_clear=false
   check(parcels_clear,"all building footprints clear roads and pedestrian strips")
  var people_safe:=true
  var lanes_safe:=true
  var headings_safe:=true
  var overlapping:=false
  # Exercise one minute of movement including rest, fleeing and intersection crossings.
  for tick in 600:
   game.elapsed=tick*.1
   if tick%120==0:
    var c:Dictionary=game.city.citizens[tick/120]
    game.player.position=c.body.position+Vector3(1.8,0,0)
   game.city._process(.1)
   for c in game.city.citizens:
    var at:=Vector2(c.body.position.x,c.body.position.z)
    if not game.city.pedestrian_contains(c,at):people_safe=false
   for t in game.city.moving_vehicles:
    if map=="food":
     var pose:Dictionary=FoodMap.Neighborhoods.lane_sample(t.progress,int(t.get("route_id",0)))
     if Vector2(t.body.position.x,t.body.position.z).distance_to(pose.at)>.001:lanes_safe=false
     if t.body.basis.z.dot(Vector3(pose.forward.x,0,pose.forward.y))<.999:headings_safe=false
    else:
     var pose:Dictionary=Layout.traffic_sample(t.progress,t.route)
     if Vector2(t.body.position.x,t.body.position.z).distance_to(pose.at)>.001:lanes_safe=false
     if t.body.basis.z.dot(Vector3(pose.forward.x,0,pose.forward.y))<.999:headings_safe=false
   for i in 8:
    for j in range(i+1,8):
     var a:RigidBody3D=game.city.moving_vehicles[i].body;var b:RigidBody3D=game.city.moving_vehicles[j].body
     if game.city.vehicles_overlap(a,b) if map=="food" else game.city.traffic_footprints_overlap(a,b,0.0):overlapping=true
  check(people_safe,map+": people stay on sidewalks during normal and panic movement")
  check(lanes_safe and headings_safe,map+": traffic follows the rendered lanes and points forward")
  check(not overlapping,map+": traffic avoids duplicate positions and crossing overlap")
  if map=="food":
   check(game.city.food_kind_counts.size()==10 and game.city.towers.size()>=90 and game.city.foods.size()>650,"food map has ten shapes, at least 90 layered buildings and dense edible streets")
   check(not game.food_goal_complete(),"food order begins incomplete")
   # Real drops exercise the same collision/award path used by city food.
   # Keep the fixture level and score consistent with a large mouth. Nearby
   # pedestrians can score during setup and must not shrink a level-one hole.
   game.player.score=350
   game.player.level=8
   for kind in ["berry","donut","cake"]:
    var item:RigidBody3D=game.city.foods.filter(func(i):return is_instance_valid(i) and i.get_meta("food_kind","")==kind and not is_instance_valid(i.support_parent))[0]
    game.player.position=Vector3(item.position.x,0,item.position.z)
    game.player.radius=game.player.RADII[game.player.level-1]
    game.player._sync_shape()
    await frames(3)
    var before:int=game.player.score
    check(item.begin_swallow(game.player),kind+": eligible object enters physical fall")
    for i in 360:
     await physics_frame
     if not is_instance_valid(item):break
    check(not is_instance_valid(item) and game.player.score>before and int(game.food_collected.get(kind,0))>=1,kind+": score and order advance only after a complete fall")
   game.food_collected={"berry":10,"donut":4,"cake":1}
   check(game.food_order_complete() and not game.food_goal_complete(),"Completed food order still requires actual city objectives")
   game.city.collection_progress={"buildings":12,"landmarks":1,"heaps":1} # Only boolean-combination fixture; receipt tracking has separate physical QA.
   check(game.food_goal_complete(),"Food order plus city goals meets the full map objective")
  game.start_level()
  check(game.selected_map==map and game.food_collected.is_empty(),map+": restart preserves the map and resets round counters")
 # Moving and overlapping mouths must restore the solid slab behind them.
 for h in game.holes:h.enabled=false;h.active=false
 var a:Node3D=game.holes[0];var b:Node3D=game.holes[1]
 a.active=true;b.active=true;a.radius=2;b.radius=2
 a.position=Vector3(60,0,0);b.position=Vector3(62,0,0)
 await frames(4)
 check(not solid(Vector2(60,0)) and not solid(Vector2(61,0)) and not solid(Vector2(63,0)),"overlapping mouths form a collision-free union")
 check(solid(Vector2(60,3)),"ground beside the mouth remains solid")
 a.position.x=68;b.position.x=70
 await frames(4)
 check(solid(Vector2(60,0)) and not solid(Vector2(69,0)),"moving mouth restores its old surface and opens its new surface")
 var result:={"checks":checks,"failures":failures}
 print("MOBILE_MAPS_ACCEPTANCE "+JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
