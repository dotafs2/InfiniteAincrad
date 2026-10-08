extends SceneTree
## Independent actual-map/model/physics review of edible coupled trains.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var receipts:Dictionary={}
const Assets=preload("res://fidelity/train_assets.gd")
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
 for _i in count:await physics_frame
func receipt(body:Node3D,hole:Node3D)->void:
 if not body.get_meta("train_car",false):return
 var id:=body.get_instance_id()
 receipts[id]={"count":int(receipts.get(id,{}).get("count",0))+1,"player":hole==game.player,"top":body.global_position.y+body.vertical_extent(),"points":body.points}
func mesh_nodes(node:Node)->Array[MeshInstance3D]:
 var result:Array[MeshInstance3D]=[]
 if node is MeshInstance3D and node.mesh!=null:result.append(node)
 for child in node.get_children():result.append_array(mesh_nodes(child))
 return result
func collider(body:Node3D)->CollisionShape3D:
 for child in body.get_children():
  if child is CollisionShape3D:return child
 return null
func corners(body:Node3D)->PackedVector2Array:
 var shape_node:=collider(body);var half:Vector3=shape_node.shape.size*.5
 var points:=PackedVector2Array()
 for local in [Vector3(-half.x,0,-half.z),Vector3(half.x,0,-half.z),Vector3(half.x,0,half.z),Vector3(-half.x,0,half.z)]:
  var at:Vector3=shape_node.global_transform*local;points.append(Vector2(at.x,at.z))
 return points
func overlaps(a:Node3D,b:Node3D)->bool:
 var pa:=corners(a);var pb:=corners(b)
 for polygon in [pa,pb]:
  for index in 2:
   var edge:Vector2=polygon[index+1]-polygon[index]
   var axis:=Vector2(-edge.y,edge.x).normalized()
   var alo:=INF;var ahi:=-INF;var blo:=INF;var bhi:=-INF
   for at in pa:alo=minf(alo,axis.dot(at));ahi=maxf(ahi,axis.dot(at))
   for at in pb:blo=minf(blo,axis.dot(at));bhi=maxf(bhi,axis.dot(at))
   if ahi<=blo+.0001 or bhi<=alo+.0001:return false
 return true
func inspect_models(controller)->Dictionary:
 var ids:Dictionary={};var shapes:Dictionary={};var assets:Dictionary={};var triangles:=0;var surfaces:=0;var max_car_triangles:=0
 for index in controller.cars.size():
  var body:Node3D=controller.cars[index];var shape_node:=collider(body)
  check(body is RigidBody3D and shape_node!=null and shape_node.shape is BoxShape3D,"Each train car owns an independent real rigid body and collider")
  check(not ids.has(body.get_instance_id()),"No physical car is duplicated in the coupling list");ids[body.get_instance_id()]=true
  check(not shapes.has(shape_node.shape.get_instance_id()),"Each car keeps an independent collider resource");shapes[shape_node.shape.get_instance_id()]=true
  check(body.get_meta("train_car",false) and int(body.get_meta("train_index",-1))==index,"Actual scene car identity matches its coupling slot")
  check(game.city.foods.count(body)==1,"Each car participates once in the ordinary edible inventory")
  check(body.train.get_ref()==controller,"Each car references the actual integrated controller")
  check(body.collision_layer!=0 and body.collision_mask!=0,"Attached cars retain real collision participation")
  var raw:Node3D=load(str(body.get_meta("train_asset"))).instantiate()
  var original_visual:MeshInstance3D=mesh_nodes(raw)[0]
  var original_material:BaseMaterial3D=original_visual.get_active_material(0)
  var actual_material:BaseMaterial3D=mesh_nodes(body)[0].get_active_material(0)
  check(actual_material.albedo_color.is_equal_approx(original_material.albedo_color) and is_equal_approx(actual_material.roughness,original_material.roughness) and is_equal_approx(actual_material.metallic,original_material.metallic),"Vertex palette opt-in preserves the original imported PBR finish")
  check(original_visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]==mesh_nodes(body)[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR],"Live car retains the exact original imported ingredient-color buffer")
  raw.free()
  var car_triangles:=0;var world_bounds:=AABB();var first:=true;var color_keys:Dictionary={};var all_finite:=true;var degenerate:=0;var wrong_winding:=0
  var nodes:=mesh_nodes(body)
  check(not nodes.is_empty(),"Every edible car has imported render geometry")
  for visual in nodes:
   var box:AABB=body.global_transform.affine_inverse()*visual.global_transform*visual.mesh.get_aabb()
   world_bounds=box if first else world_bounds.merge(box);first=false
   for surface in visual.mesh.get_surface_count():
    var arrays:Array=visual.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var material:Material=visual.get_active_material(surface)
    check(material is StandardMaterial3D and material.vertex_color_use_as_albedo,"Imported train materials actually use the authored vertex palette")
    check(colors.size()==vertices.size() and normals.size()==vertices.size(),"Actual imported buffers retain normals and a color for every vertex")
    for vertex in vertices:all_finite=all_finite and vertex.is_finite()
    for normal in normals:all_finite=all_finite and normal.is_finite() and normal.length()>.5
    for color in colors:
     all_finite=all_finite and is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and color.a>.99
     color_keys[color.to_html()]=true
    for vertex_index in indices:all_finite=all_finite and vertex_index>=0 and vertex_index<vertices.size()
    for triangle in range(0,indices.size(),3):
     var a:=indices[triangle];var b:=indices[triangle+1];var c:=indices[triangle+2]
     var face:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
     if face.length_squared()<1e-18:degenerate+=1
     if face.dot(normals[a]+normals[b]+normals[c])>.000001:wrong_winding+=1
    car_triangles+=indices.size()/3 if not indices.is_empty() else vertices.size()/3;surfaces+=1
  check(all_finite and color_keys.size()>=4,"Imported car geometry and ingredient colors are finite and varied")
  check(degenerate==0 and wrong_winding==0,"Actual Godot buffers retain nondegenerate clockwise faces matching their normals")
  check(world_bounds.size.distance_to(shape_node.shape.size)<.001 and world_bounds.get_center().length()<.001,"Each collider encloses exactly its own imported car, not the whole train")
  check(absf(body.footprint-Vector2(world_bounds.size.x,world_bounds.size.z).length()*.5)<.001,"Swallowing size gate uses only one car's real dimensions")
  check(car_triangles<=1500,"Each actual imported train car stays within the authored mobile geometry cap")
  triangles+=car_triangles;max_car_triangles=maxi(max_car_triangles,car_triangles)
  assets[str(body.get_meta("train_asset",""))]=true
 check(triangles<=controller.cars.size()*1500 and surfaces<=controller.cars.size()*4,"Full train respects per-car geometry and surface limits")
 check(assets.size()>=8 if game.selected_map=="food" else assets.size()>=2,"Map train uses distinct sushi recipes or separate rail cab/car assets")
 return {"cars":ids.size(),"assets":assets.size(),"triangles":triangles,"surfaces":surfaces,"max_car_triangles":max_car_triangles}
func move_loop(controller,distance:float,parked:Dictionary)->Dictionary:
 var target:float=controller.head_distance+distance
 var previous:Dictionary={};var max_jump:=0.0;var intersections:=0;var parked_changes:=0;var blocked_frames:=0;var ticks:=0;var max_history:=0
 for body in controller.cars:
  if is_instance_valid(body):previous[body.get_instance_id()]=body.global_position
 var maximum:int=ceili(distance/maxf(.01,controller.speed*.15))+600
 while controller.head_distance<target and ticks<maximum:
  controller.step(.15);await physics_frame;ticks+=1
  if controller.blocked:blocked_frames+=1
  max_history=maxi(max_history,controller.history.size())
  for i in controller.cars.size():
   var body=controller.cars[i]
   if not is_instance_valid(body) or body.consumed:continue
   var id:int=body.get_instance_id()
   if body.attached:
    max_jump=maxf(max_jump,body.global_position.distance_to(previous[id]));previous[id]=body.global_position
   if parked.has(id) and body.global_transform!=parked[id]:parked_changes+=1
   for j in range(i+1,controller.cars.size()):
    var other=controller.cars[j]
    if not is_instance_valid(other) or other.consumed or not body.freeze or not other.freeze:continue
    if overlaps(body,other):intersections+=1
 check(controller.head_distance>=target,"Surviving head completes the required physical return distance")
 check(max_jump<=controller.speed*.15+.08,"Every attached car advances continuously without a route-change teleport")
 check(intersections==0,"Actual oriented car colliders never intersect, including returning head versus parked tail")
 check(parked_changes==0,"Detached tail world transforms never move during head return laps")
 check(max_history<500,"Actual path-following history remains bounded after repeated route travel")
 return {"requested_distance":distance,"head_distance":controller.head_distance,"ticks":ticks,"blocked_frames":blocked_frames,"max_car_step":max_jump,"collider_overlaps":intersections,"parked_pose_changes":parked_changes,"max_history_samples":max_history}
func fit_player(body:Node3D)->void:
 game.player.active=true;game.player.enabled=false
 var grants:=0
 while game.player.radius<body.footprint*1.08+.03 and grants<400:
  game.player.award(1);grants+=1
 check(grants<400 and body.can_fit(game.player),"Ordinary earned growth reaches the individual train-car admission size")
 game.player.position=Vector3(body.position.x,0,body.position.z);game.ground.sync();await frames(2)
func swallow(body:Node3D,controller)->int:
 var id:=body.get_instance_id();var score_before:int=game.player.score;var points:int=body.points
 game.scan_food()
 check(is_instance_valid(body.claimed_by) and body.claimed_by==game.player and not body.freeze,"Normal gameplay scan admits this car into a real physical fall")
 for _tick in 480:
  if receipts.has(id):break
  controller.step(1.0/60.0);await physics_frame
 check(receipts.has(id) and int(receipts[id].count)==1 and receipts[id].player,"Car produces one unique player collection receipt")
 if receipts.has(id):check(float(receipts[id].top)< -3.5,"Train score is awarded only after the complete car descends below ground")
 check(game.player.score==score_before+points,"A swallowed train car awards exactly its own ordinary points")
 await frames(2)
 return id
func scene_count(node:Node)->int:
 var count:=1 if node.get_meta("train_car",false) else 0
 for child in node.get_children():count+=scene_count(child)
 return count
func map_review(map_id:String)->void:
 receipts.clear();game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await process_frame
 game.selected_map=map_id;game.start_level();game.item_collected.connect(receipt)
 var controller=game.train_controller
 check(controller!=null,"Actual "+map_id+" game integrates a train controller")
 if controller==null:return
 var expected:=8 if map_id=="food" else 4
 check(controller.cars.size()==expected and controller.attached_count==expected,"Actual map creates exactly the intended coupled train length")
 if map_id=="food":game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.active=false
 game.ground.sync()
 var wallet_before:int=game.coins
 var data:=inspect_models(controller);var before:float=controller.traveled
 await frames(12);check(is_equal_approx(controller.traveled,before),"Train remains stopped during the real intro phase")
 game.begin_play()
 for hole in game.holes:hole.enabled=false;hole.active=false
 await frames(24);check(controller.traveled>before+.1,"Natural game physics frames advance the integrated train")
 game.toggle_pause();before=controller.traveled
 for _frame in 12:await process_frame
 controller.step(.5);check(is_equal_approx(controller.traveled,before),"Tree pause stops both natural and explicit train stepping")
 game.toggle_pause();await frames(12);check(controller.traveled>before+.1,"Resuming natural play resumes the existing train")
 game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false)
 data["unbroken_loop"]=await move_loop(controller,controller.route_length+4.0,{})
 var middle:int=controller.cars.size()/2;var target:Node3D=controller.cars[middle]
 check(not target.can_fit(game.player),"Starting mouth cannot bypass the train-car size requirement")
 var before_rejected:int=controller.attached_count
 check(not target.begin_swallow(game.player) and controller.attached_count==before_rejected and target.attached,"Rejected small-mouth admission cannot detach or move any car")
 await fit_player(target)
 var parked:Dictionary={}
 for i in range(middle+1,controller.cars.size()):parked[controller.cars[i].get_instance_id()]=controller.cars[i].global_transform
 var events_before:int=controller.detach_events.size()
 var middle_id:int=await swallow(target,controller)
 check(controller.attached_count==middle and controller.detach_events.size()==events_before+1,"Swallowing a middle car cuts the chain exactly once at that car")
 check(controller.cars[0].attached,"The original head survives a middle cut")
 for i in range(middle+1,controller.cars.size()):
  var body:Node3D=controller.cars[i]
  check(not body.attached and body.freeze and body.collision_layer!=0 and body.collision_mask!=0,"Every downstream car parks as an ordinary collidable edible")
 game.player.active=false;game.player.position=Vector3.ZERO;game.ground.sync();await frames(2)
 data["cut_return"]=await move_loop(controller,controller.route_length*1.15,parked)
 check(controller.detach_events.size()==events_before+1 and controller.attached_count==middle,"Returning past a detached tail never reattaches or duplicates cars")
 check(not is_instance_valid(controller.cars[middle]) and receipts[middle_id].count==1,"The consumed middle car never respawns on a later lap")
 var head:Node3D=controller.cars[0];await fit_player(head)
 var head_id:int=await swallow(head,controller)
 check(controller.attached_count==0,"Swallowing the head parks every remaining upstream car")
 var stopped:float=controller.traveled;controller.step(3.0)
 check(is_equal_approx(controller.traveled,stopped),"An entirely headless train has no scripted movement")
 for body in controller.cars:
  if not is_instance_valid(body):continue
  await fit_player(body);await swallow(body,controller)
 check(receipts.size()==expected,"Every original car is independently collected exactly once")
 check(scene_count(game.world)==0,"No duplicate or ghost train physics body survives complete collection")
 data["receipts"]=receipts.duplicate(true);data["detachment_events"]=controller.detach_events.size()
 game.back_home();await frames(3)
 check(scene_count(game)==0,"Returning home releases every gameplay train body")
 var material_cache_before:int=Assets.palette_materials.size()
 game.start_level();await frames(3)
 check(Assets.palette_materials.size()==material_cache_before,"Restart reuses train palette materials without growing the cache")
 check(game.train_controller!=controller and game.train_controller.cars.size()==expected and scene_count(game.world)==expected,"Restart creates exactly one fresh train without retaining the prior chain")
 var second=game.train_controller
 game.begin_play();game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false)
 if map_id=="food":game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.active=false
 game.ground.sync();await frames(2);receipts.clear()
 data["two_laps_before_cut"]=await move_loop(second,second.route_length*2.0+4.0,{})
 var later_middle:Node3D=second.cars[middle];await fit_player(later_middle)
 var later_parked:Dictionary={}
 for i in range(middle+1,second.cars.size()):later_parked[second.cars[i].get_instance_id()]=second.cars[i].global_transform
 await swallow(later_middle,second)
 game.player.active=false;game.player.position=Vector3.ZERO;game.ground.sync();await frames(2)
 data["two_lap_cut_return"]=await move_loop(second,second.route_length*1.05,later_parked)
 check(second.attached_count==middle and second.detach_events.size()==1,"A cut after two complete laps preserves the same independent coupling rules")
 game.back_home();await frames(3);check(scene_count(game)==0,"Repeated return home leaves no train-body leak")
 check(game.coins==wallet_before,"Train admission and collection do not directly mutate the persistent coin wallet")
 metrics[map_id]=data
 game.audio.music.stop();await create_timer(.12).timeout;game.free();await process_frame
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 await map_review("city");await map_review("food")
 print("TRAIN_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent actual-map/imported-model/physics/coupling checks, no browser, save or performance claim."}))
 quit(0 if failures.is_empty() else 1)
