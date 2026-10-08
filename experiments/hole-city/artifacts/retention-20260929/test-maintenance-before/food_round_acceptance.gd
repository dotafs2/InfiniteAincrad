extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.demo_mode=true
 var results:=[]
 for contested in [true,false]:
  game.start_level();game.begin_play()
  if not contested:
   for h in game.holes:
    if h!=game.player:h.retire()
  var ticks:=0
  while game.phase=="playing" and ticks<15000:
   await physics_frame;ticks+=1
   if ticks%1800==0:print("FOOD_ROUND_PROGRESS "+JSON.stringify({"contested":contested,"seconds":game.elapsed,"score":game.player.score,"phase":game.phase}))
  results.append({"contested":contested,"phase":game.phase,"score":game.player.score,"food":game.food_collected.duplicate(),"seconds":game.elapsed,"city_goals":game.food_city_progress().duplicate()})
 var passed:bool=results[0].score>0 and results[0].phase in ["complete","timeout","eaten"] and results[1].phase=="complete" and game.food_goal_complete()
 var report:={"passed":passed,"checks":2,"failures":[] if passed else ["Food round failed the contested/solo completion gates"],"rounds":results}
 print("FOOD_ROUND_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.free();await process_frame;quit(0 if passed else 1)
