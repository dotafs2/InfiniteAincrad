extends SceneTree
var game:Node3D
var receipts:Array[Dictionary]=[]
var levels:Array[Dictionary]=[]
var last_level:=0
var target:Node3D
var waiting:=0.0
func _initialize()->void:run.call_deferred()
func receipt(body:Node3D,hole:Node3D)->void:
 if hole!=game.player:return
 receipts.append({"name":str(body.name),"id":body.get_instance_id(),"time":game.elapsed,"points":body.points,"minimum_level":game.player.level_for_radius(body.footprint*1.08),"top":body.position.y+body.vertical_extent(),"food":body.has_meta("food_kind")})
func choose_target()->Node3D:
 var best:Node3D;var best_value:=INF
 for body in game.city.foods:
  if not is_instance_valid(body) or not body.has_meta("food_kind") or not body.can_fit(game.player):continue
  var distance:float=Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length()
  var minimum:int=game.player.level_for_radius(body.footprint*1.08)
  # A player aims for nearby newly edible objects; lower tiers remain valid.
  var value:float=distance+float(maxi(0,mini(4,game.player.level)-minimum))*9.0
  if value<best_value:best_value=value;best=body
 return best
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.begin_play();game.city.rain_enabled=false
 for hole in game.holes:
  if hole!=game.player:hole.retire()
 game.item_collected.connect(receipt)
 var travelled:=0.0;var previous:Vector3=game.player.position
 for tick in 9000:
  if game.player.level!=last_level:
   last_level=game.player.level
   var next:=INF;var count:=0
   for body in game.city.foods:
    if not is_instance_valid(body) or is_instance_valid(body.support_parent) or body.consumed:continue
    if game.player.level_for_radius(body.footprint*1.08)==last_level+1:
     var distance:float=Vector2(body.position.x-game.player.position.x,body.position.z-game.player.position.z).length();next=minf(next,distance)
     if distance<20:count+=1
   levels.append({"level":last_level,"time":game.elapsed,"score":game.player.score,"at":[game.player.position.x,game.player.position.z],"nearest_next_size":next,"next_size_within20":count})
  if game.player.level>=7:break
  if is_instance_valid(target) and is_instance_valid(target.claimed_by):
   game.player.test_direction=Vector2.ZERO
  else:
   if not is_instance_valid(target) or target.consumed or not target.can_fit(game.player):target=choose_target()
   if is_instance_valid(target):
    var delta:Vector2=Vector2(target.position.x-game.player.position.x,target.position.z-game.player.position.z)
    game.player.test_direction=delta.normalized()*clampf(delta.length()/.25,0,1)
  await physics_frame
  travelled+=game.player.position.distance_to(previous);previous=game.player.position
 var report:={"checks":1,"failures":[],"seconds":game.elapsed,"score":game.player.score,"level":game.player.level,"travelled":travelled,"levels":levels,"receipts":receipts,"policy":"Actual movement, scan, gravity and receipts; guided target choices, solo, authored food only, no awards/score/radius writes."}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FOOD_ROUTE "+JSON.stringify({"checks":1,"failures":[],"seconds":game.elapsed,"score":game.player.score,"level":game.player.level,"travelled":travelled,"levels":levels,"receipts":receipts.size()}))
 game.free();await process_frame;quit(0)
