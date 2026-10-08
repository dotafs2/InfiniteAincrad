extends SceneTree
## Real size gates and grounded progression targets; no free score or resize.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var receipts:Array[Dictionary]=[]
var levels:Array[Dictionary]=[]
var target:Node3D
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
func receipt(body:Node3D,hole:Node3D)->void:
 if hole!=game.player or not body.has_meta("food_kind"):return
 receipts.append({"id":body.get_instance_id(),"time":game.elapsed,"points":body.points,"minimum_level":game.player.level_for_radius(body.footprint*1.08),"top":body.position.y+body.vertical_extent()})
func choose_target()->Node3D:
 var best:Node3D;var best_value:=INF
 for body in game.city.foods:
  if not is_instance_valid(body) or not body.has_meta("food_kind") or not body.can_fit(game.player):continue
  var distance:float=Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length()
  var minimum:int=game.player.level_for_radius(body.footprint*1.08)
  # Guided input chooses nearby newly edible foods, with older foods as fallback.
  var value:float=distance+float(maxi(0,mini(4,game.player.level)-minimum))*9.0
  if value<best_value:best_value=value;best=body
 return best
func inspect_growth()->void:
 var city:Node3D=game.city;var plan:Dictionary=city.urban_plan
 var loose:Array=city.foods.filter(func(body):return body.has_meta("food_kind") and not body.has_meta("tower_id") and not body.has_meta("pile_id") and not body.get_meta("traffic",false))
 check(loose.size()==plan.snacks.size() and loose.size()==1080,"Growth redistributes existing loose food; it does not add physical bodies")
 check(city.towers.size()==160 and city.piles.size()==17 and city.foods.size()==2930,"The city retains buildings, heaps, actors and eight train cars")
 check(city.mesh_cache.size()==34 and game.train_controller.cars.size()==8,"Growth uses the same shared recipes and preserves Sushi Express")
 var grade_counts:Dictionary={};var district_counts:Dictionary={};var opening:Dictionary={};var ground_counts:Dictionary={}
 var retained_roots:Array[Node3D]=[]
 for body in city.foods:
  if body.has_meta("food_kind") and not is_instance_valid(body.support_parent):
   retained_roots.append(body)
   var grade:int=game.player.level_for_radius(body.footprint*1.08)
   ground_counts[grade]=int(ground_counts.get(grade,0))+1
   if Vector2(body.position.x-1,body.position.z-23).length()<=20:opening[grade]=int(opening.get(grade,0))+1
 var changed:=0;var maximum_nearest_next:=0.0
 for index in plan.snacks.size():
  var record:Dictionary=plan.snacks[index]
  if not record.has("growth_level"):continue
  var body:Node3D=loose[index];var level:int=record.growth_level;var at:=Vector2(body.position.x,body.position.z)
  changed+=1;grade_counts[level]=int(grade_counts.get(level,0))+1
  var district:int=record.growth_district
  if not district_counts.has(district):district_counts[district]={}
  district_counts[district][level]=int(district_counts[district].get(level,0))+1
  check(at.distance_to(Vector2(record.at[0],record.at[1]))<.0001 and not is_instance_valid(body.support_parent),"Growth target is the actual independent ground-root body: "+str(index))
  var extent:Vector3=body.food_visual.mesh.get_aabb().size*body.food_visual.scale
  check(body.half_size.is_equal_approx(extent*.5) and absf(body.height-extent.y)<.0001,"Growth collider and visible food keep identical physical dimensions: "+str(index))
  game.player.radius=game.player.radius_for_level(level-1)
  check(not body.can_fit(game.player),"Earlier mouth genuinely cannot fit the next-size target: "+str(index))
  game.player.radius=game.player.radius_for_level(level)
  check(body.can_fit(game.player),"Ordinary next-level mouth admits the same unchanged body: "+str(index))
  check(body.points==int(record.points),"Resized food preserves its original ordinary receipt value: "+str(index))
  check(absf(body.footprint-float(record.growth_radius))<.00002,"Actual collision footprint matches the authored size step: "+str(index))
  var shape:=collision(body);var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=3;query.exclude=[body.get_rid(),game.ground.body.get_rid()]
  check(game.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),"Full real collider starts clear of retained food, actors and other growth targets: "+str(index))
  var support:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,.1,at.y),Vector3(at.x,-.15,at.y),1,[body.get_rid()]))
  check(absf(body.position.y-body.half_size.y)<.05 and not support.is_empty() and support.rid==game.ground.body.get_rid(),"Intermediate food rests above actual cuttable terrain: "+str(index))
  var route_clear:bool=not city.Neighborhoods.on_road(at,float(record.growth_envelope)+.29)
  for route in plan.routes:
   if city.Neighborhoods.closest(at,route).distance_to(at)<float(record.growth_envelope)+float(route.half_width)+.29:route_clear=false
  check(route_clear,"Whole food envelope leaves vehicle and pedestrian corridors open: "+str(index))
  if level<4:
   var nearest:=INF
   for other in retained_roots:
    if game.player.level_for_radius(other.footprint*1.08)==level+1:nearest=minf(nearest,at.distance_to(Vector2(other.position.x,other.position.z)))
   maximum_nearest_next=maxf(maximum_nearest_next,nearest)
   check(nearest<22,"After this meal's size step, another actual larger ground target is nearby: "+str(index))
 check(changed==182 and grade_counts=={2:98,3:56,4:28},"Existing inner-city snacks supply three substantial intermediate target populations")
 for district in 7:check(district_counts.get(district,{})=={2:14,3:8,4:4},"Every inner district has the complete intermediate progression: "+str(district))
 for level in range(1,8):check(int(ground_counts.get(level,0))>=8,"All seven real unlock-size steps remain represented on the ground: "+str(level))
 check(int(opening.get(1,0))>=60 and int(opening.get(2,0))>=14 and int(opening.get(3,0))>=8 and int(opening.get(4,0))>=4,"Opening retains six first-upgrade budgets of starter food plus successive sizes within 20m")
 metrics["layout"]={"ground_histogram":ground_counts,"opening_20m":opening,"changed":changed,"district_counts":district_counts,"maximum_next_target_distance":maximum_nearest_next}
func inspect_platters()->void:
 var count:=0;var details:=[]
 for index in game.city.piles.size():
  var pile:Dictionary=game.city.piles[index]
  var base=pile.get("growth_platter")
  if not is_instance_valid(base):continue
  count+=1
  check(index in [2,4,6] and pile.pieces.size()==59 and pile.roots.size()==1 and pile.roots[0]==base,"Platter replaces one of the existing 59 pieces, with one real root: "+str(index))
  check(base.get_meta("food_kind")=="cookie" and absf(base.footprint-3.4)<.00001 and base.points==10,"Large cookie has matching authored physical radius and one bounded ten-point reward")
  game.player.radius=game.player.radius_for_level(5);check(not base.can_fit(game.player),"LVL5 cannot falsely admit the large platter")
  game.player.radius=game.player.radius_for_level(6);check(base.can_fit(game.player),"LVL6 can normally admit the large platter")
  var extent:Vector3=base.food_visual.mesh.get_aabb().size*base.food_visual.scale
  check(base.half_size.is_equal_approx(extent*.5) and collision(base).shape is ConvexPolygonShape3D,"Visible large cookie and real round hull use the same dimensions")
  var excludes:Array[RID]=[game.ground.body.get_rid()]
  for piece in pile.pieces:excludes.append(piece.get_rid())
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=collision(base).shape;query.transform=collision(base).global_transform;query.collision_mask=3;query.exclude=excludes
  check(game.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty(),"Broad platter does not overlap any retained external food or actor")
  var children:=0;var maximum_radius:=0.0
  for piece in pile.pieces:
   maximum_radius=maxf(maximum_radius,Vector2(piece.position.x-pile.at.x,piece.position.z-pile.at.y).length()+maxf(piece.half_size.x,piece.half_size.z))
   if piece==base:continue
   var parent:Node3D=piece.support_parent;var gap:float=piece.position.y-piece.half_size.y-parent.position.y-parent.half_size.y
   check(parent!=piece and parent.supported_food.has(piece) and gap>=-.002 and gap<.06,"Every platter snack retains separate contact-height physical support")
   var ancestor:Node3D=piece;var depth:=0
   while is_instance_valid(ancestor.support_parent) and depth<12:ancestor=ancestor.support_parent;depth+=1
   check(ancestor==base and depth<12,"Every upper food support chain reaches this real cookie without a cycle")
   if parent==base:children+=1
  var courses:int=pile.pieces.filter(func(piece):return piece.get_meta("feast_course",false)).size()
  check(children==1 and courses==5 and maximum_radius<=3.7,"Five genuine large courses and separate toppings fit inside the retained heap circle")
  details.append({"heap":index,"at":[pile.at.x,pile.at.y],"pieces":pile.pieces.size(),"ground_radius":base.footprint,"top":pile.height,"maximum_envelope":maximum_radius})
 check(count==3,"Exactly three inner-city later-size targets replace existing heap bases")
 metrics["platters"]=details
func physical_platters()->void:
 game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.active=hole==game.player
 game.player.award(160)
 var prior_receipts:=receipts.size();var results:=[]
 for index in [2,4,6]:
  var pile:Dictionary=game.city.piles[index];var base:Node3D=pile.growth_platter
  var tracked:Dictionary={};var base_id:=base.get_instance_id()
  for piece in pile.pieces:tracked[piece.get_instance_id()]=weakref(piece)
  game.player.position=Vector3(pile.at.x,0,pile.at.y);game.player._sync_shape();game.ground.sync();await frames(2)
  var old_score:int=game.player.score;game.scan_food()
  check(not base.freeze and game.player.score==old_score,"Large platter begins real gravity fall before any score is awarded")
  # Five real courses release successively at the normal 75ms support delay.
  await frames(36)
  var falling:=0
  for ref in tracked.values():
   var piece=ref.get_ref()
   if is_instance_valid(piece) and not piece.freeze:falling+=1
  check(falling>=25,"Removing the platter releases its separately simulated upper food")
  for tick in 900:
   if tick%5==0:game.scan_food()
   await physics_frame
   if tracked.values().all(func(ref):return not is_instance_valid(ref.get_ref())):break
  var found:=[];var only_once:=true;var ids:Dictionary={}
  for row in receipts.slice(prior_receipts):
   if not tracked.has(row.id):continue
   ids[row.id]=int(ids.get(row.id,0))+1;found.append(row)
   if row.top>=-3.5:only_once=false
  for value in ids.values():
   if value!=1:only_once=false
  check(ids.size()==59 and only_once,"All 59 platter pieces individually finish their descent and collect exactly once")
  var base_rows:Array=found.filter(func(row):return row.id==base_id)
  check(base_rows.size()==1 and base_rows[0].points==10,"The broad platter awards exactly its one ten-point physical receipt")
  results.append({"heap":index,"independent_receipts":ids.size(),"platter_receipt":base_rows})
 metrics["platter_falls"]=results
func natural_route()->void:
 game.start_level();game.begin_play();game.city.rain_enabled=false
 for hole in game.holes:
  if hole!=game.player:hole.retire()
 game.item_collected.connect(receipt)
 var last_level:=0;var previous:Vector3=game.player.position;var travelled:=0.0
 check(game.player.score==0 and game.player.level==1,"Natural route starts from the ordinary zero-score mouth")
 for tick in 9000:
  if game.player.level!=last_level:
   last_level=game.player.level
   var nearest_next:=INF;var local_next:=0
   for body in game.city.foods:
    if not is_instance_valid(body) or is_instance_valid(body.support_parent) or body.consumed:continue
    if game.player.level_for_radius(body.footprint*1.08)!=last_level+1:continue
    var distance:float=Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length()
    nearest_next=minf(nearest_next,distance)
    if distance<25:local_next+=1
   levels.append({"level":last_level,"time":game.elapsed,"score":game.player.score,"at":[game.player.position.x,game.player.position.z],"nearest_next_size":nearest_next,"next_size_within25":local_next})
  if game.player.level>=7:break
  # Admission wakes an object at partial rim contact. Keep moving beneath it
  # as the normal controller does; a claim is not a complete descent.
  if not is_instance_valid(target) or target.consumed or (target.claimed_by!=game.player and not target.can_fit(game.player)):target=choose_target()
  if is_instance_valid(target):
   var aim:Vector3=target.interaction_position()
   var gap:=Vector2(aim.x-game.player.position.x,aim.z-game.player.position.z)
   game.player.test_direction=gap.normalized()*clampf(gap.length()/.25,0,1)
  else:game.player.test_direction=Vector2.ZERO
  await physics_frame
  travelled+=game.player.position.distance_to(previous);previous=game.player.position
 var ids:Dictionary={};var counts:Dictionary={};var complete:=true
 for row in receipts:
  ids[row.id]=int(ids.get(row.id,0))+1;counts[row.minimum_level]=int(counts.get(row.minimum_level,0))+1
  if row.top>=-3.5:complete=false
 check(game.player.level>=7 and game.player.score>=240 and game.elapsed<150,"Normal movement and actual collection reach the midgame without direct awards or size writes")
 check(complete and ids.size()==receipts.size(),"Every counted food receipt follows one complete physical descent exactly once")
 check(int(counts.get(2,0))>=3 and int(counts.get(3,0))>=2 and int(counts.get(4,0))>=2,"The natural route actually consumes multiple intermediate-size foods")
 for row in levels:
  if row.level>=2 and row.level<=5:check(row.nearest_next_size<30,"Each early/middle upgrade has an actually reachable next size nearby: "+str(row.level))
 check(travelled>20 and game.train_controller.traveled>0,"Normal scene movement and the original sushi train continue during the route")
 metrics["route"]={"seconds":game.elapsed,"score":game.player.score,"level":game.player.level,"travelled":travelled,"levels":levels,"receipt_grades":counts,"receipts":receipts.duplicate(true)}
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.selected_map="food";game.start_level()
 game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
 game.ground.sync();await frames(2);inspect_growth();inspect_platters()
 game.set_process(true);game.set_physics_process(true);await natural_route();await physical_platters()
 var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Real scene, physical size gates and guided normal movement; not human/browser or device FPS evidence."}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 game.free();await process_frame
 print("FOOD_GROWTH_ACCEPTANCE "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
