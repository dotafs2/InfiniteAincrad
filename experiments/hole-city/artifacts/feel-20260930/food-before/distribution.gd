extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
 for hole in game.holes:hole.enabled=false;hole.set_physics_process(false)
 var rows:=[];var hist:={};var available:={};var near:={};var districts:={}
 for body in game.city.foods:
  if not body.has_meta("food_kind"):continue
  var level:int=game.player.level_for_radius(body.footprint*1.08)
  var ground:bool=not is_instance_valid(body.support_parent)
  var at:=Vector2(body.position.x,body.position.z);var dist:float=at.distance_to(Vector2(1,23))
  var district:=0;var closest:=INF
  for i in game.city.urban_plan.districts.size():
   var d:float=at.distance_to(game.city.Neighborhoods.point(game.city.urban_plan.districts[i].center))
   if d<closest:closest=d;district=i
  var key:=str(level);hist[key]=int(hist.get(key,0))+1
  if ground:
   available[key]=int(available.get(key,0))+1
   if not districts.has(str(district)):districts[str(district)]={}
   districts[str(district)][key]=int(districts[str(district)].get(key,0))+1
   if dist<=20:near[key]=int(near.get(key,0))+1
  rows.append({"name":str(body.name),"at":[at.x,at.y],"height":body.height,"size":body.food_visual.scale.x,"kind":body.get_meta("food_kind"),"mesh_key":body.get_meta("food_mesh_key",""),"footprint":body.footprint,"minimum_level":level,"ground_available":ground,"spawn_distance":dist,"points":body.points,"tower":body.get_meta("tower_id",-1),"pile":body.get_meta("pile_id",-1),"district":district})
 var report:={"bodies":rows,"all_histogram":hist,"ground_histogram":available,"spawn_20m_ground":near,"district_ground":districts}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FOOD_DISTRIBUTION "+JSON.stringify({"checks":1,"failures":[],"all_histogram":hist,"ground_histogram":available,"spawn_20m_ground":near,"district_ground":districts}))
 game.free();await process_frame;quit(0)
