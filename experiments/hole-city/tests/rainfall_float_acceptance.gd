extends "res://tests/rival_combat_acceptance.gd"
## Regression: one exact visual handoff, no post-collection model replay.
var timing:Dictionary={}
func setup(hz:int,skin:String)->void:
 reset_arena();Engine.physics_ticks_per_second=hz;game.player.skin_id=skin
 game.player.skin_visual.build(game.skin_definition(skin))
 configure(game.player,60,Vector3.ZERO);game.ground.sync()
 for i in 4:await physics_frame

func settle(hz:int,skin:String,move:=false)->int:
 await setup(hz,skin)
 var body:=food(Vector3(0,.65,0),7)
 var original_nodes:=body.get_child_count()
 check(body.begin_swallow(game.player),"%d Hz %s: prop admitted"%[hz,skin])
 check(body.get("rainfall_float")==null and body.angular_velocity.is_zero_approx(),"No skin-specific buoyancy or rocking force")
 var score:int=game.player.score;var ticks:=0;var moved:=false
 var intake:Node3D=game.player.skin_visual.rainfall.intake if skin=="rainfall" else null
 while is_instance_valid(body) and ticks<hz*2:
  await physics_frame;ticks+=1
  if is_instance_valid(body) and not body.consumed:
   check(body.get_child_count()==original_nodes,"No new presentation nodes on the physics body")
   if intake!=null and body.get_meta("rainfall_entry_started",false):check(not body.visible,"The original cannot render after handoff")
  if move and intake!=null and intake.active_count()>0 and not moved:
   var slot:Dictionary=intake.slots.filter(func(s):return s.age<intake.DURATION)[0]
   var before:Vector3=slot.node.global_position;var offset:=Vector3(8,0,-3)
   game.player.position+=offset;game.ground.sync();moved=true
   check(slot.node.global_position.is_equal_approx(before+offset),"The single sinking visual moves with its hole")
 check(game.player.score==score+7 and not is_instance_valid(body),"Normal fall scores once and removes the real body")
 check(ticks<=hz,"Small prop still collects within one second")
 if skin=="rainfall":
  var rain:Node3D=game.player.skin_visual.rainfall
  var started:int=intake.started_events
  check(started<=1,"One object can start at most one visible entry")
  check(rain.contact_events==1 and rain.object_events==1,"Collection emits one water response")
  for i in hz/2:await physics_frame
  check(intake.started_events==started and intake.active_count()==0,"Collection never starts a second drop")
  check(intake.views.all(func(v):return v.mesh==null and not v.visible),"Entry meshes release after completion")
  check(game.player.score==score+7,"Presentation cannot award twice")
  if move:check(moved,"Movement case actually exercised the entry animation")
 return ticks

func handoff_fixture()->void:
 await setup(60,"rainfall")
 var rain:Node3D=game.player.skin_visual.rainfall;var intake:Node3D=rain.intake
 var body:=food(Vector3(.2,.15,.1))
 body.rotation=Vector3(.03,.35,-.07)
 var original:MeshInstance3D=body.food_visual
 var transform_before:Transform3D=original.global_transform
 var velocity_before:=body.linear_velocity;var position_before:=body.global_position
 check(intake.start(body),"Visible original can hand off exactly once")
 var slot:Dictionary=intake.slots.filter(func(s):return s.source!=null)[0]
 check(slot.views[0].global_transform.is_equal_approx(transform_before),"First visual frame matches the original transform exactly")
 check(slot.views[0].mesh==original.mesh and slot.views[0].material_override==original.material_override,"Original mesh and materials remain unchanged")
 check(not body.visible and slot.views[0].is_visible_in_tree(),"Atomic handoff leaves only one rendered model")
 check(body.linear_velocity==velocity_before and body.global_position==position_before and body.freeze and not body.consumed,"Presentation changes no physics or scoring")
 check(not intake.start(body),"Same body cannot start a second entry")
 var age:float=slot.age;paused=true
 for i in 4:await process_frame
 check(slot.age==age,"Pause freezes visual time");paused=false
 var last_y:float=slot.node.position.y
 for i in 28:
  intake.advance(1.0/60)
  check(slot.node.position.y<=last_y+.00001,"Visual center never rises or resets")
  last_y=slot.node.position.y
 check(intake.active_count()==0 and not body.visible,"Finishing animation cannot reveal the original again")
 var count:int=intake.started_events
 rain.confirmed_object(body);rain.confirmed_object(body)
 check(intake.started_events==count and intake.active_count()==0,"Late collection callbacks cannot respawn the body mesh")
 game.player.skin_visual.build(game.skin_definition("core_shell"))
 check(body.visible,"Skin replacement restores a still-live source")

func limits_fixture()->void:
 await setup(60,"rainfall")
 var intake:Node3D=game.player.skin_visual.rainfall.intake
 var original_nodes:=intake.find_children("*","Node",true,false).size()
 var score:int=game.player.score;var bodies:Array=[]
 for i in 12:
  var b:=food(Vector3(30+i*.4,.2,30));bodies.append(b)
  var started:bool=intake.start(b)
  check(started==(i<3),"Only three objects get visual slots; others keep normal rendering")
  check(b.visible==not started,"Overflow cannot hide a source or evict another entry")
  check(intake.active_count()<=3 and intake.surface_count()<=6,"Hard pool budget is maintained")
 check(intake.find_children("*","Node",true,false).size()==original_nodes,"Burst load reuses its fixed nodes")
 check(bodies.all(func(b):return b.freeze and not b.consumed and b.claimed_by==null),"Presentation cannot move, consume or claim sources")
 check(game.player.score==score,"Visuals never grant rewards")
 for slot in intake.slots:intake.retire(slot,true)
 var crowded:=food(Vector3(30,.2,35))
 for i in 7:
  var v:=MeshInstance3D.new();v.mesh=BoxMesh.new();crowded.add_child(v)
 check(not intake.start(crowded) and crowded.visible,"Over-budget geometry retains its complete original model")
 var submerged:=food(Vector3(0,-1,0));submerged.claimed_by=game.player
 intake.watch(submerged);intake.advance(0)
 check(intake.active_count()==0 and submerged.visible,"Already submerged bodies are never resurrected")
 check(intake.find_children("*","CollisionObject3D",true,false).is_empty(),"The visual pool has no colliders")
 game.player.skin_visual.build(game.skin_definition("tempest"))
 check(not is_instance_valid(intake),"Changing skin frees the pool")

func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 AudioServer.set_bus_mute(0,true)
 game=load("res://fidelity/main.tscn").instantiate();game.selected_skin_id="rainfall"
 root.add_child(game);game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false)
 game.city.free();game.city=Arena.new();game.world.add_child(game.city)
 for hz in [30,60,120]:
  var baseline:int=await settle(hz,"core_shell")
  var rain:int=await settle(hz,"rainfall")
  check(absi(rain-baseline)<=1,"%d Hz: ordinary collection timing matches within one tick"%hz)
  timing[str(hz)]={"ordinary_ticks":baseline,"rainfall_ticks":rain}
 await settle(60,"rainfall",true)
 await handoff_fixture();await limits_fixture();Engine.physics_ticks_per_second=60
 var result:={"checks":checks,"failures":failures,"timing":timing,"visual_seconds":.42,"max_ghosts":3,"max_surfaces":6}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
 print("RAINFALL_FLOAT_ACCEPTANCE "+JSON.stringify(result));game.free();await process_frame;quit(0 if failures.is_empty() else 1)
