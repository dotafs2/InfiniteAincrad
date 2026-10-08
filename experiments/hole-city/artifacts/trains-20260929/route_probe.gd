extends SceneTree
const Layout=preload("res://fidelity/street_layout.gd")
const Neighborhoods=preload("res://fidelity/food_neighborhoods.gd")
var game:Node3D
var result:Dictionary={}
func _initialize()->void:run.call_deferred()
func rounded_ring(edge:float,radius:float)->PackedVector2Array:
 var p:=PackedVector2Array()
 for corner in 4:
  var centers:=[Vector2(edge-radius,-edge+radius),Vector2(edge-radius,edge-radius),Vector2(-edge+radius,edge-radius),Vector2(-edge+radius,-edge+radius)]
  var start:float=-PI*.5+float(corner)*PI*.5
  for i in 13:p.append(centers[corner]+Vector2.from_angle(start+float(i)/12.0*PI*.5)*radius)
 p.append(p[0]);return p
func path_from(points:Array)->PackedVector2Array:
 var path:=PackedVector2Array()
 for point in points:path.append(Vector2(point[0],point[1]))
 return path
func scan(path:PackedVector2Array,offset:float)->Dictionary:
 var names:Dictionary={};var hits:=0;var samples:=0;var roads_out:=0;var walker_intersections:=0;var length:=0.0
 var width:=1.25 if game.selected_map=="food" else 1.45
 var vehicle_length:=1.75 if game.selected_map=="food" else 2.35
 var height:=1.5
 var volume:=BoxShape3D.new();volume.size=Vector3(width,height,vehicle_length)
 var previous_forward:Vector2=Vector2.ZERO
 var sharpest:=0.0
 var footprint_offroad:=0;var footprint_samples:=0;var minimum_food_road_margin:=INF
 for i in path.size()-1:
  var from:=path[i];var to:=path[i+1];var delta:=to-from;var segment:=delta.length()
  if segment<.001:continue
  var forward:=delta/segment;var normal:=Vector2(-forward.y,forward.x)
  if previous_forward!=Vector2.ZERO:sharpest=maxf(sharpest,absf(forward.angle_to(previous_forward)))
  previous_forward=forward;length+=segment
  for j in maxi(1,ceili(segment/.6)):
   var at:Vector2=from.lerp(to,float(j)/float(maxi(1,ceili(segment/.6))))+normal*offset
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=volume;query.collision_mask=3;query.exclude=[game.ground.body.get_rid()]
   query.transform=Transform3D(Basis(Vector3.UP,atan2(forward.x,forward.y)),Vector3(at.x,height*.5+.01,at.y))
   var found:=game.get_world_3d().direct_space_state.intersect_shape(query,32)
   samples+=1
   if not found.is_empty():hits+=1
   for hit in found:
    var body:Node=hit.collider;var category:String="unknown"
    if body.get_meta("traffic",false):category="traffic"
    elif body.get_meta("catalog_group","")=="person":category="person"
    elif body.has_meta("food_kind"):category="food"
    else:category=str(body.get("category"))
    names[str(body.name)]={"category":category,"at":str(body.position),"kind":body.get_meta("food_kind","")}
   for transverse in [-.5,0.0,.5]:
    for longitudinal in [-.5,0.0,.5]:
     var point:Vector2=at+normal*width*transverse+forward*vehicle_length*longitudinal
     footprint_samples+=1
     var on_road:bool=Neighborhoods.on_road(point) if game.selected_map=="food" else Layout.on_road(point)
     if not on_road:footprint_offroad+=1
   if game.selected_map=="food":
    if not Neighborhoods.on_road(at):roads_out+=1
    for walk in game.city.urban_plan.routes:
     if Neighborhoods.closest(at,walk).distance_to(at)<float(walk.half_width)+.8:walker_intersections+=1;break
   else:
    if not Layout.on_road(at):roads_out+=1
    for walk in Layout.walk_clearance_rects():
     if walk.grow(.8).has_point(at):walker_intersections+=1;break
 return {"offset":offset,"samples":samples,"length":length,"footprint_width":width,"footprint_length":vehicle_length,"sample_pitch_max":.6,"blocked_samples":hits,"blockers":names,"center_off_road":roads_out,"pedestrian_corridor_overlap_samples":walker_intersections,"footprint_probe_points":footprint_samples,"footprint_off_road_points":footprint_offroad,"sharpest_polyline_turn_degrees":rad_to_deg(sharpest)}
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 for map_id in ["city","food"]:
  game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await process_frame
  game.selected_map=map_id;game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false)
  if map_id=="food":game.city.rain_enabled=false
  for hole in game.holes:hole.active=false;hole.enabled=false
  game.ground.sync();await physics_frame;await physics_frame
  var routes:Dictionary={}
  if map_id=="city":
   routes["outer_ring_r6"]=rounded_ring(84.0,6.0)
   routes["outer_ring_r4_5"]=rounded_ring(84.0,4.5)
   routes["outer_ring_84_4_r4"]=rounded_ring(84.4,4.0)
   var path:=PackedVector2Array()
   for i in 600:path.append(Layout.traffic_sample(Layout.traffic_length(0)*float(i)/600.0,0).at)
   path.append(path[0]);routes["inner_existing_outer_lane"]=path
  else:
   var plan:Dictionary=Neighborhoods.plan();routes["main_ring"]=path_from(plan.traffic.points)
   var outer:=PackedVector2Array()
   for road in plan.roads:
    if int(road.from)>=12 and int(road.to)>=12:
     var points:=path_from(road.points)
     if not outer.is_empty() and points[0].is_equal_approx(outer[-1]):points.remove_at(0)
     outer.append_array(points)
   routes["outer_food_ring"]=outer
  var data:Dictionary={}
  for key in routes:
   var scans:Array=[]
   var bypass:=1.35 if map_id=="food" else (1.6 if key=="outer_ring_84_4_r4" else 1.8)
   for offset in [-bypass,0.0,bypass]:scans.append(scan(routes[key],offset))
   data[key]=scans
  result[map_id]=data
  game.audio.music.stop();await create_timer(.12).timeout;game.free();await process_frame
 print("TRAIN_ROUTE_PROBE "+JSON.stringify(result));quit()
