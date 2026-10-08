extends SceneTree
## Exact admission arithmetic and synchronous observability. Physical landing,
## waking and consumption are independently exercised by the rain review suite.
var checks:=0
var failures:Array[String]=[]
var game:Node3D
var city:Node3D
var pending:Dictionary={}
var events:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func live()->Array:
 return city.rain_bodies.filter(func(b):return is_instance_valid(b) and not b.is_queued_for_deletion())
func started(event:Dictionary)->void:
 var actual:Array=live();var airborne:int=actual.filter(func(b):return not b.rain_landed).size()
 var expected:int=maxi(0,mini(6,mini(640-actual.size(),24-airborne)))
 pending={"event":event.duplicate(),"ids":actual.map(func(b):return b.get_instance_id()),"expected":expected,"serial":city.rain_serial}
 check(event.airborne_before==airborne and event.retained_before==actual.size(),"Snapshot matches synchronous independent physical-body state")
 check(event.serial_before==city.rain_serial and event.event==city.rain_admission_serial,"Snapshot identifies current serial and monotonic admission")
 check(event.requested==expected,"Requested capacity matches independent fixed 24/640/six-item arithmetic")
 event.requested=99999;event.airborne_before=-100
func finished(event:Dictionary)->void:
 var added:Array=live().filter(func(b):return not pending.ids.has(b.get_instance_id()))
 check(event.spawned==added.size() and added.size()==pending.expected,"Actual newly constructed IDs exactly match admitted capacity")
 check(event.serial_after-event.serial_before==added.size() and event.serial_after==city.rain_serial,"Actual spawn serial difference matches new bodies")
 check(event.requested==pending.expected and event.airborne_before==pending.event.airborne_before,"Mutating an observer copy cannot alter production budget or snapshot")
 check(city.last_rain_admission==event,"Latest diagnostic records the completed admission including zero spawn")
 events.append(event.duplicate());event.spawned=99999
func attempt()->void:
 city.rain_clock=0;city.update_rain(1.0/60)
 check(city.last_rain_admission.spawned!=99999,"Finished observer receives its own dictionary copy")
func spawn_fixture(count:int)->void:
 for i in count:city.spawn_rain("cookie",Vector2(70,70),25)
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false)
 city=game.city;city.set_physics_process(false)
 for h in game.holes:h.enabled=false;h.active=h==game.player
 city.rain_admission_started.connect(started);city.rain_admission_finished.connect(finished)
 check(game.progress_file().is_empty(),"Test cannot access player progress")
 check(city.AIRBORNE_LIMIT==24 and city.RAIN_LIMIT==640,"Original admission and retained limits are unchanged")
 attempt();check(city.rain_serial==6,"Empty scene admits one ordinary six-item wave")
 spawn_fixture(17);attempt();check(city.last_rain_admission.spawned==1 and live().size()==24,"Exactly one remaining airborne slot admits one item")
 attempt();check(city.last_rain_admission.spawned==0,"Twenty-four existing airborne bodies admit nothing")
 spawn_fixture(2);attempt();check(city.last_rain_admission.spawned==0 and live().size()==26,"Already-over-budget physical bodies are neither removed nor frozen")
 check(live().all(func(b):return not b.freeze and b.food_visual.visible),"Quota enforcement does not hide or freeze existing falling food")
 # Synthetic supported-state fixture tests the scheduler contract only.
 # Sleeping is deliberately false: it is not a substitute for support state.
 for i in 10:city.rain_bodies[i].rain_landed=true;city.rain_bodies[i].sleeping=false
 attempt();check(city.last_rain_admission.airborne_before==16 and city.last_rain_admission.spawned==6,"Supported awake food is not mistaken for airborne budget")
 city.rain_bodies[0].queue_free();city.rain_bodies[10].queue_free()
 attempt();check(city.last_rain_admission.retained_before==30 and city.last_rain_admission.airborne_before==21 and city.last_rain_admission.spawned==3,"Queued deletions are excluded from both retained and airborne accounting")
 spawn_fixture(640-live().size())
 for body in live():body.rain_landed=true;body.sleeping=false
 attempt();check(city.last_rain_admission.spawned==0 and live().size()==640,"Retained-food capacity blocks spawning even when everything is supported")
 var serial:int=city.rain_serial;var event_count:int=events.size()
 city.rain_enabled=false;city.rain_clock=0;city.update_rain(3)
 check(city.rain_serial==serial and events.size()==event_count,"Disabled rain emits neither admissions nor new food")
 city.rain_enabled=true
 for phase in ["title","intro","results"]:
  game.phase=phase;city.rain_clock=0;city.update_rain(3)
  check(city.rain_serial==serial and events.size()==event_count,"Non-playing phase cannot admit rain: "+phase)
 game.phase="playing";city.set_physics_process(true);paused=true;city.rain_clock=0
 for i in 6:await physics_frame
 check(city.rain_serial==serial and events.size()==event_count,"Natural paused SceneTree frames do not run rain admissions")
 city.set_physics_process(false);paused=false
 city.rain_admission_started.disconnect(started);city.rain_admission_finished.disconnect(finished)
 game.audio.music.stop();game.free();await process_frame
 var report:={"checks":checks,"failures":failures,"events":events,"scope":"Scheduler state fixtures and real spawned body IDs; no physical landing or all-time motion-cap claim."}
 print("RAIN_ADMISSION_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var path:=arg.trim_prefix("--report=")
   if not path.is_absolute_path() or "://" in path:quit(2);return
   FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
 quit(0 if failures.is_empty() else 1)
