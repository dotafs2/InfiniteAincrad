extends SceneTree
## Independent enlarged-food review: actual authored bodies, collider footprints,
## terrain contact and ordinary hole collection; no runtime or save mutations.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var receipts:Dictionary={}
var metrics:Dictionary={}
var ground_excludes:Array[RID]=[]
var extended:Array[Node3D]=[]
var extension_loose:Array[Node3D]=[]
var extension_towers:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
 for _i in count:await physics_frame
func collision(body:Node3D)->CollisionShape3D:
 for child in body.get_children():
  if child is CollisionShape3D:return child
 return null
func points(body:Node3D)->PackedVector3Array:
 var collider:=collision(body);var result:=PackedVector3Array()
 if collider.shape is ConvexPolygonShape3D:
  for point in collider.shape.points:result.append(collider.global_transform*point)
 elif collider.shape is BoxShape3D:
  var box:=AABB(-collider.shape.size*.5,collider.shape.size)
  for i in 8:result.append(collider.global_transform*box.get_endpoint(i))
 return result
func bounds(body:Node3D)->AABB:
 var values:=points(body);var box:=AABB(values[0],Vector3.ZERO)
 for point in values:box=box.expand(point)
 return box
func polygon(body:Node3D)->PackedVector2Array:
 var projected:=PackedVector2Array()
 for point in points(body):projected.append(Vector2(point.x,point.z))
 return Geometry2D.convex_hull(projected)
func area(poly:PackedVector2Array)->float:
 var sum:=0.0
 for i in poly.size():sum+=poly[i].cross(poly[(i+1)%poly.size()])
 return absf(sum)*.5
func refresh_ground_excludes()->void:
 ground_excludes.clear()
 for body in game.city.foods:
  if is_instance_valid(body):ground_excludes.append(body.get_rid())
func ground_hit(at:Vector2)->Dictionary:
 return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,3,at.y),Vector3(at.x,-3,at.y),1,ground_excludes))
func receipt(body:Node3D,hole:Node3D)->void:
 var id:=body.get_instance_id()
 receipts[id]={"count":int(receipts.get(id,{}).get("count",0))+1,"player":hole==game.player,"top":body.position.y+body.vertical_extent(),"points":body.points}
func inventory()->void:
 refresh_ground_excludes()
 var plan:Dictionary=game.city.urban_plan
 for i in plan.plots.size():
  if not plan.plots[i].get("extension",false):continue
  extension_towers.append(game.city.towers[i])
  extended.append_array(game.city.towers[i].tiers)
 for i in plan.heaps.size():
  if plan.heaps[i].get("extension",false):extended.append_array(game.city.piles[i].pieces)
 var loose:Array=game.city.foods.filter(func(body):return body.has_meta("food_kind") and not body.has_meta("tower_id") and not body.has_meta("pile_id") and not body.get_meta("traffic",false))
 check(loose.size()==plan.snacks.size(),"All loose plan entries map one-to-one to actual independent food bodies")
 for i in mini(loose.size(),plan.snacks.size()):
  if not plan.snacks[i].get("extension",false):continue
  var body:Node3D=loose[i];extension_loose.append(body);extended.append(body)
  check(Vector2(body.position.x,body.position.z).distance_to(Vector2(plan.snacks[i].at[0],plan.snacks[i].at[1]))<.0001,"Extension ingredient uses its authored physical coordinate")
 var max_scale:=0.0;var unsupported:=0;var invalid_bounds:=0;var wrong_size:=0
 for body in extended:
  var extent:Vector3=body.food_visual.mesh.get_aabb().size*body.food_visual.scale
  max_scale=maxf(max_scale,body.food_visual.scale.x)
  if not body.half_size.is_equal_approx(extent*.5) or absf(body.height-extent.y)>.0001:wrong_size+=1
  var box:=bounds(body)
  if box.position.x< -100 or box.end.x>100 or box.position.z< -100 or box.end.z>100:invalid_bounds+=1
  if is_instance_valid(body.support_parent):
   var parent:Node3D=body.support_parent
   var gap:float=body.position.y-body.half_size.y-parent.position.y-parent.half_size.y
   if not parent.supported_food.has(body) or gap< -.002 or gap>.06:unsupported+=1
  else:
   if box.position.y< -.002 or box.position.y>.06:unsupported+=1
   for point in points(body):
    var hit:=ground_hit(Vector2(point.x,point.z))
    if hit.is_empty() or hit.rid!=game.ground.body.get_rid():unsupported+=1
 check(extended.size()>=250 and not extension_towers.is_empty(),"Review covers a populated physical extension with real towers")
 check(max_scale>=2,"Density repair includes genuinely enlarged edible geometry")
 check(wrong_size==0,"Every enlarged visual has a matching physical height and half-size, not visual-only scaling")
 check(invalid_bounds==0,"Every extension collision hull remains within the real 200m terrain")
 check(unsupported==0,"Every extension root has real ground; upper tiers have close reciprocal physical support")
 # Intersect actual convex collider footprints independently of collision
 # masks, rather than treating an empty space query as proof of separation.
 # Only ground-root pairs are relevant to unintended plot overlap.
 var roots:Array=game.city.foods.filter(func(body):return body.has_meta("food_kind") and not is_instance_valid(body.support_parent))
 var boxes:Dictionary={};var polygons:Dictionary={}
 for body in roots:boxes[body.get_instance_id()]=bounds(body);polygons[body.get_instance_id()]=polygon(body)
 var overlaps:Array=[];var pairs:Dictionary={}
 for body in extended:
  if is_instance_valid(body.support_parent):continue
  var a:int=body.get_instance_id();var box_a:AABB=boxes[a]
  for other in roots:
   var b:int=other.get_instance_id()
   if a==b or pairs.has(Vector2i(mini(a,b),maxi(a,b))):continue
   if not box_a.intersects(boxes[b]):continue
   pairs[Vector2i(mini(a,b),maxi(a,b))]=true
   var overlap:=0.0
   for intersection in Geometry2D.intersect_polygons(polygons[a],polygons[b]):overlap+=area(intersection)
   if overlap>.002:overlaps.append({"a":body.name,"b":other.name,"area":overlap})
 check(overlaps.is_empty(),"Actual convex footprints of extension ground foods do not penetrate unrelated ground foods")
 metrics["inventory"]={"extension_bodies":extended.size(),"extension_loose":extension_loose.size(),"maximum_scale":max_scale,"overlap_pairs":overlaps}
func grow_to_fit(body:Node3D,extra_radius:=0.0)->void:
 # All growth comes through ordinary score award; never unlock/equip a skill,
 # edit its footprint, or disable the size gate to make the target collectible.
 var center:=Vector2(body.position.x,body.position.z).clamp(Vector2(-96,-96),Vector2(96,96))
 var required:=maxf(extra_radius,body.footprint*1.12+center.distance_to(Vector2(body.position.x,body.position.z)))
 while game.player.radius<required and game.player.score<100000:game.player.award(250)
 game.player.active=true;game.player.position=Vector3(center.x,0,center.y)
 game.ground.sync()
func enlarged_ground_contact()->void:
 var candidates:Array=extension_loose.filter(func(body):return body.food_visual.scale.x>=2 and collision(body).shape is ConvexPolygonShape3D)
 candidates.sort_custom(func(a,b):return a.footprint>b.footprint)
 check(not candidates.is_empty(),"At least one enlarged round plaza ingredient is physically present")
 if candidates.is_empty():return
 var body:Node3D=candidates[0];var id:=body.get_instance_id();var scale:float=body.food_visual.scale.x
 var initial:Vector3=body.position
 check(game.player.skin_id=="cocoa_square" and not body.can_fit(game.player),"Ordinary gray starting hole cannot bypass the large plaza size gate")
 body.position.y+=3;body.rotation.x=.18;body.lose_support(null)
 var lowest:=INF;var highest_speed:=0.0
 for tick in 480:
  await physics_frame
  if not is_instance_valid(body):break
  lowest=minf(lowest,bounds(body).position.y);highest_speed=maxf(highest_speed,body.linear_velocity.length())
 check(is_instance_valid(body),"Enlarged released plaza ingredient stays a separate live body before collection")
 if not is_instance_valid(body):return
 var settled:=bounds(body)
 check(settled.position.y>-.08 and settled.position.y<.16 and body.linear_velocity.length()<.3,"Large tilted food settles on real ground without tunnelling or hovering")
 check(highest_speed>2 and not receipts.has(id),"Real large-food gravity/contact precedes collection and does not pre-award points")
 grow_to_fit(body)
 var earned_radius:float=game.player.radius
 game.player.radius=body.footprint*1.08-.00001
 check(not body.can_fit(game.player),"Large round ingredient retains the just-too-small admission boundary")
 game.player.radius=earned_radius
 check(body.can_fit(game.player),"Normal score-based growth makes enlarged food eligible without a skin bypass")
 await frames(3)
 check(ground_hit(Vector2(body.position.x,body.position.z)).is_empty(),"The actual enlarged mouth cuts terrain beneath the plaza ingredient")
 game.scan_food()
 check(not body.freeze and body.claimed_by==game.player,"Normal scene scan claims and releases the actual large ingredient")
 for tick in 420:
  await physics_frame
  if tick%6==0:game.scan_food()
  if receipts.has(id):break
 check(receipts.has(id) and receipts[id].count==1 and receipts[id].player and receipts[id].top< -3.5,"Large plaza independently descends completely and awards exactly one player receipt")
 metrics["plaza"]={"scale":scale,"at":str(initial),"minimum_bottom_during_contact":lowest,"maximum_fall_speed":highest_speed,"grown_radius":earned_radius,"receipt":receipts.get(id,{})}
func enlarged_tower_collapse()->void:
 for circular in [true,false]:
  var candidates:Array=extension_towers.filter(func(tower):return is_instance_valid(tower.base) and tower.base.food_visual.scale.x>=2 and (collision(tower.base).shape is ConvexPolygonShape3D)==circular)
  check(not candidates.is_empty(),"Extension has enlarged "+("round" if circular else "rectangular")+" tower tiers")
  if candidates.is_empty():continue
  var tower:Dictionary=candidates[0];var base:Node3D=tower.base
  var tracked:Array=[];var upper:Node3D=tower.tiers[1];var upper_y:float=upper.position.y
  for body in tower.tiers:tracked.append({"id":body.get_instance_id(),"weak":weakref(body)})
  grow_to_fit(base);await frames(3)
  check(not upper.can_fit(game.player) and upper.support_parent==base,"An enlarged upper tier retains its independent parent until support is lost")
  check(base.can_fit(game.player),"Ordinary growth makes the enlarged structural base collectible")
  game.scan_food();await frames(12)
  check(not is_instance_valid(upper) or (not upper.freeze and not is_instance_valid(upper.support_parent) and upper.position.y<upper_y-.02),"Removing the large base wakes and lowers its own upper tier")
  var tilted:=false
  for tick in 600:
   await physics_frame
   if tick%6==0:game.scan_food()
   for record in tracked:
    var body=record.weak.get_ref()
    if is_instance_valid(body) and body.basis.y.dot(Vector3.UP)<.995:tilted=true
   if tracked.all(func(record):return receipts.has(record.id)):break
  for record in tracked:
   check(receipts.has(record.id) and receipts[record.id].count==1 and receipts[record.id].player and receipts[record.id].top< -3.5,"Each enlarged tower piece independently falls and settles exactly once: "+str(record.id))
  check(tilted,"Enlarged food tower physically tips instead of moving as one fused model")
  metrics.get_or_add("towers",[]).append({"kind":tower.kind,"pieces":tracked.size(),"radius":game.player.radius,"tilted":tilted})
func perimeter_rain()->void:
 # Start a clean real map: earlier intentional collapses must not become
 # fixtures that accidentally catch or redirect this independent rain test.
 game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false)
 for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
 var city:Node3D=game.city;city.rain_enabled=false
 game.ground.sync();await frames(3);refresh_ground_excludes()
 var corners:Array[Vector2]=[Vector2(-96,-96),Vector2(96,-96),Vector2(96,96),Vector2(-96,96),Vector2(96,0),Vector2(0,96),Vector2(-96,0),Vector2(0,-96)]
 var distance_max:=0.0;var old_distance_min:=INF;var out_of_ground:=0;var missing_support:=0
 for at in corners:
  game.player.position=Vector3(at.x,0,at.y)
  for sample in 32:
   var point:Vector2=city.rain_spawn_position()
   distance_max=maxf(distance_max,at.distance_to(point))
   # Project this same physical candidate onto the former [-67,67] domain.
   # This records the old clamp's geometric lower bound, not a fake old run.
   old_distance_min=minf(old_distance_min,at.distance_to(point.clamp(Vector2(-67,-67),Vector2(67,67))))
   if absf(point.x)>93.001 or absf(point.y)>93.001:out_of_ground+=1
   if ground_hit(point).is_empty():missing_support+=1
 check(distance_max<16.5 and old_distance_min>=29,"Rain now follows all eight expanded edges/corners; old 67m clamp was at least 29m away")
 check(out_of_ground==0 and missing_support==0,"All sampled edge/corner rain origins retain seven meters of real terrain margin")
 # Ten actual drop recipes at the expanded northeast corner must contact
 # terrain and remain edible; this includes rectangular bacon and sushi.
 game.player.position=Vector3(96,0,96)
 var drops:Array=[]
 for kind in city.Shapes.KINDS:
  var at:Vector2=city.rain_spawn_position();var body:Node3D=city.spawn_rain(kind,at,8)
  var roof_query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,200,at.y),Vector3(at.x,0,at.y),3,[body.get_rid()])
  var roof_hit:=game.get_world_3d().direct_space_state.intersect_ray(roof_query)
  check(roof_hit.is_empty() or body.position.y-body.vertical_extent()>=float(roof_hit.position.y)+.49,"Rain begins above the real supporting collider instead of inside a tall stack: "+kind)
  drops.append({"id":body.get_instance_id(),"weak":weakref(body),"kind":kind,"spawn_height":body.position.y})
 await frames(480);refresh_ground_excludes()
 var landed:=0
 for record in drops:
  var body=record.weak.get_ref()
  if is_instance_valid(body) and body.rain_landed:landed+=1
  check(is_instance_valid(body) and body.rain_landed and body.position.y>-.1 and ground_hit(Vector2(body.position.x,body.position.z)).size()>0,"Perimeter rain has actual supported contact: "+str(record.kind))
 city.batch_settled_rain()
 for record in drops:
  var body=record.weak.get_ref()
  if not is_instance_valid(body):
   # A larger legal mouth may already have eaten adjacent drops. Still bind
   # every original ID to its own complete descent and unique receipt.
   check(absf(game.player.position.x)<=96 and absf(game.player.position.z)<=96,"Perimeter collection uses a legal player center: "+str(record.kind))
   check(receipts.has(record.id) and receipts[record.id].count==1 and receipts[record.id].player and receipts[record.id].top< -3.5,"Perimeter rain stays independently collectible: "+str(record.kind))
   metrics.get_or_add("rain_collection",[]).append({"kind":record.kind,"receipt":receipts.get(record.id,{}),"collected_with_neighbor":true})
   continue
  var initial_drop:Vector3=body.position
  var query:=PhysicsRayQueryParameters3D.create(body.position,body.position+Vector3.DOWN*30,3,[body.get_rid()])
  var support_hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
  var actual_support= support_hit.get("collider")
  var support_info:Dictionary={}
  if is_instance_valid(actual_support):support_info={"name":actual_support.name,"position":str(actual_support.global_position),"food":actual_support.get_meta("food_kind","none"),"footprint":actual_support.get("footprint")}
  # A drop can legitimately rest on a food heap. Cover its actual root
  # support with ordinary growth; do not demand it pass through solid food.
  var support_radius:=0.0
  if is_instance_valid(actual_support) and actual_support.has_meta("food_kind"):
   var base:Node3D=actual_support
   while is_instance_valid(base.support_parent):base=base.support_parent
   var legal_center:=Vector2(body.position.x,body.position.z).clamp(Vector2(-96,-96),Vector2(96,96))
   support_radius=legal_center.distance_to(Vector2(base.position.x,base.position.z))+base.footprint*1.12
   support_info["root"]=str(base.name);support_info["required_radius"]=support_radius
  grow_to_fit(body,support_radius);await frames(3);game.scan_food()
  check(absf(game.player.position.x)<=96 and absf(game.player.position.z)<=96,"Perimeter collection uses a legal player center: "+str(record.kind))
  for tick in 240:
   await physics_frame
   if tick%6==0:game.scan_food()
   if receipts.has(record.id):break
  metrics.get_or_add("rain_collection",[]).append({"kind":record.kind,"initial":str(initial_drop),"support":support_info,"hole_radius":game.player.radius,"receipt":receipts.get(record.id,{}),"final":str(body.position) if is_instance_valid(body) else "freed","velocity":str(body.linear_velocity) if is_instance_valid(body) else "freed","claimed":is_instance_valid(body) and body.claimed_by==game.player})
  check(receipts.has(record.id) and receipts[record.id].count==1 and receipts[record.id].player and receipts[record.id].top< -3.5,"Perimeter rain stays independently collectible: "+str(record.kind))
 # A short steady-state corner run samples budget while waves continue. Full
 # 240-second continuity remains the separate existing rain suite's scope.
 game.player.active=false;game.player.position=Vector3(-96,0,-96);game.ground.sync()
 city.rain_enabled=true;city.rain_clock=0
 var initial_serial:int=city.rain_serial;var maximum_airborne:=0;var maximum_retained:=0
 for tick in 1800:
  city.update_rain(1.0/60.0)
  await physics_frame
  maximum_airborne=maxi(maximum_airborne,city.rain_bodies.filter(func(body):return is_instance_valid(body) and not body.rain_landed).size())
  maximum_retained=maxi(maximum_retained,city.rain_bodies.size())
 check(city.rain_serial>=initial_serial+60,"Repeated real waves continue during thirty seconds at the expanded corner")
 check(maximum_airborne<=24 and maximum_retained<=640,"Perimeter rain retains the unchanged airborne and live-body budgets")
 check(city.rain_retirements.all(func(record):return not record.visible and record.landed and record.distance>=34 and record.age>=12),"Moving between corners retires only distant hidden settled rain")
 metrics["perimeter_rain"]={"max_spawn_distance":distance_max,"former_clamp_min_distance":old_distance_min,"landed_recipes":landed,"waves_spawned":city.rain_serial-initial_serial,"maximum_airborne":maximum_airborne,"maximum_retained":maximum_retained}

func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.begin_play()
 game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false);game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
 game.item_collected.connect(receipt)
 game.ground.sync();await frames(3)
 inventory();await enlarged_ground_contact();await enlarged_tower_collapse();await perimeter_rain()
 var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent actual enlarged food collider/support/contact/collection; no renderer or performance claim"}
 print("FOOD_EXTENSION_COLLISION_REVIEW "+JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
