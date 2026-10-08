extends SceneTree
## Deterministic 60 Hz CPU trace. Headless timings exclude all GPU work.
var samples:Array[float]=[]
var physics_samples:Array[float]=[]
var game:Node3D
var map_id:="city"
var scenario:="opening"
var measured_reveal_start:=0
func _initialize()->void:run.call_deferred()
func percentile(values:Array[float],q:float)->float:
 return values[mini(values.size()-1,int(values.size()*q))] if not values.is_empty() else 0.0
func run()->void:
 Engine.max_fps=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--map="):map_id=arg.trim_prefix("--map=")
  if arg.begins_with("--scenario="):scenario=arg.trim_prefix("--scenario=")
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 if "selected_map" in game:game.selected_map=map_id
 game.start_level();game.begin_play()
 if scenario=="grown":
  # Preserve level/score so collecting a prop cannot reset a large mouth to
  # level one. Isolate the stress trace from the normal 500-point finish gate.
  game.set_physics_process(false)
  for i in game.holes.size():
   game.holes[i].score=350
   game.holes[i].level=8
   game.holes[i].radius=7.2
   game.holes[i].position=Vector3(-30+(i%4)*20,0,-15+(i/4)*30)
   game.holes[i]._sync_shape()
 if scenario=="rain_soak":
  game.set_physics_process(false)
  for h in game.holes:h.enabled=false;h.active=h==game.player
  for frame in 14400:
   game.elapsed+=1.0/60.0
   await process_frame
 var start:=Time.get_ticks_usec()
 var last:int=start
 for i in 660:
  if scenario=="grown":
   game.elapsed+=1.0/60.0
   if i%6==0:game.scan_food()
  # Constant movement traces exercise moving cuts, crossing mouths and collisions.
  game.player.test_direction=Vector2(cos(i*.018),sin(i*.018))
  await process_frame
  var now:=Time.get_ticks_usec()
  if i==59:measured_reveal_start=game.reveal.update_count
  if i>=60:samples.append(float(now-last)/1000.0)
  last=now
 samples.sort()
 var batch_capacity:=0;var batch_active:=0;var hidden_triangles_avoided:=0
 for node in game.city.find_children("*","MultiMeshInstance3D",true,false):
  var mm:MultiMesh=node.multimesh
  batch_capacity+=mm.instance_count
  var active:int=mm.visible_instance_count if mm.visible_instance_count>=0 else mm.instance_count
  batch_active+=active
  var triangles:=0
  for surface in mm.mesh.get_surface_count():
   var arrays:Array=mm.mesh.surface_get_arrays(surface)
   triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  hidden_triangles_avoided+=(mm.instance_count-active)*triangles
 var rain_count:int=game.city.rain_bodies.size() if "rain_bodies" in game.city else 0
 var result:={"retained_rain":rain_count,"map":map_id,"scenario":scenario,"version":ProjectSettings.get_setting("application/config/version"),"batch_capacity":batch_capacity,"batch_active":batch_active,"hidden_triangles_avoided":hidden_triangles_avoided,"headless":DisplayServer.get_name()=="headless","os":OS.get_name(),"engine":Engine.get_version_info().string,"physics_hz":Engine.physics_ticks_per_second,"samples":samples.size(),"wall_seconds":float(Time.get_ticks_usec()-start)/1e6,"simulation_seconds":game.elapsed,"p50_ms":percentile(samples,.5),"p95_ms":percentile(samples,.95),"p99_ms":percentile(samples,.99),"worst_ms":percentile(samples,1),"over_16_67_ms":samples.filter(func(x):return x>16.667).size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"score":game.player.score,"phase":game.phase}
 # Retain all measured intervals for independent percentile/count validation.
 result["frame_times_ms"]=samples
 result["reveal_updates"]=game.reveal.update_count
 result["measured_reveal_updates"]=game.reveal.update_count-measured_reveal_start
 result["reveal_strength"]=game.reveal.target.w
 result["reveal_per_frame_scene_scans"]=game.reveal.diagnostics().per_frame_scene_scans
 result["registered_structural_occluders"]=game.reveal.diagnostics().registered_occluders
 result["cached_triangle_meshes"]=game.reveal.diagnostics().cached_triangle_meshes
 print("MOBILE_PROFILE "+JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 game.free();await process_frame;quit()
