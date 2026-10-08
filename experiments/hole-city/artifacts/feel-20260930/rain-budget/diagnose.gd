extends SceneTree
var game:Node3D
var prior:Dictionary={}
var transitions:Array=[]
var overflows:Array=[]
var waves:Array=[]
var max_airborne:=0
func snap(b)->Dictionary:
 return {"id":b.get_instance_id(),"kind":b.get_meta("food_kind"),"at":str(b.position),"velocity":str(b.linear_velocity),"omega":str(b.angular_velocity),"sleeping":b.sleeping,"landed":b.rain_landed,"contact_time":b.rain_contact_time,"age":b.rain_age,"batched":b.batch!=null}
func _initialize()->void:run.call_deferred()
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false)
 for h in game.holes:h.enabled=false;h.active=h==game.player
 var city=game.city;var old_serial:int=city.rain_serial
 for tick in 14400:
  await physics_frame
  var count:=0;var active:Array=[];var awake_landed:=0
  for b in city.rain_bodies:
   if not is_instance_valid(b):continue
   var id:int=b.get_instance_id()
   if not b.rain_landed:count+=1;active.append(snap(b))
   elif not b.sleeping:awake_landed+=1
   if prior.has(id) and prior[id].landed and not b.rain_landed:
    var e:={"tick":tick,"before":prior[id],"after":snap(b)}
    if transitions.size()<1500:transitions.append(e)
   prior[id]=snap(b)
  max_airborne=maxi(count,max_airborne)
  if count>24 and overflows.size()<30:overflows.append({"tick":tick,"serial":city.rain_serial,"airborne":count,"awake_landed":awake_landed,"bodies":active})
  if city.rain_serial!=old_serial:waves.append({"tick":tick,"serial":city.rain_serial,"airborne":count,"awake_landed":awake_landed});old_serial=city.rain_serial
 var report:={"checks":1,"failures":[],"max_airborne":max_airborne,"waves":waves,"landed_to_airborne":transitions,"overflows":overflows}
 game.free();await process_frame
 print("RAIN_BUDGET_DIAGNOSE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 quit()
