extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
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
 var passed:bool=results.all(func(value):return value.score>0 and value.phase=="complete" and value.seconds>=60.0 and value.seconds<61.0)
 var report:={"passed":passed,"checks":2,"failures":[] if passed else ["Contested or solo food round failed positive-score full one-minute settlement"],"rounds":results}
 print("FOOD_ROUND_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.free();await process_frame;quit(0 if passed else 1)
