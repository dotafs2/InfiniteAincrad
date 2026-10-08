extends SceneTree
## Actual map traversal through production scan_food, colliders and scoring.
## No direct begin_swallow, collision disabling, or forced downward velocity.
const Audit=preload("res://fidelity/scene_audit.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var report:Dictionary={"audits":[],"negative_controls":[],"traversal":[]}
var radius:=.85
var candidates:Array[Dictionary]=[]
var receipts:Dictionary={}
func _initialize()->void:run.call_deferred()
func record_collection(item:Node3D,_hole:Node3D)->void:
 receipts[item.get_instance_id()]={"points":item.points,"top":item.position.y+item.vertical_extent()}
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:int)->void:
 for i in n:await physics_frame
func actor(id:String)->Dictionary:
 for a in game.city.recipe_actors:
  if a.definition.id==id:return a
 return {}
func pin_hole(at:Vector3,size:float)->void:
 radius=size
 for i in game.player.RADII.size():
  if is_equal_approx(size,game.player.RADII[i]):
   game.player.level=i+1
   game.player.score=game.player.LEVEL_STARTS[i]
   break
 game.player.position=Vector3(at.x,0,at.z)
 game.player.radius=radius
 game.player._sync_shape()
func probe(body:Node3D,id:String,size:float=-1)->void:
 if not is_instance_valid(body):return
 var row:={"id":id,"start":[body.position.x,body.position.y,body.position.z],"footprint":body.footprint}
 var instance_id:int=body.get_instance_id()
 if is_instance_valid(body.support_parent):
  row["result"]="protected_by_building";report.traversal.append(row);return
 var required:float=body.footprint*1.08
 if size<0:
  for r in game.player.RADII:
   if r>=required:size=r;break
 row["radius"]=size
 pin_hole(body.position,size)
 var before:int=game.player.score
 await frames(3)
 if not is_instance_valid(body):
  row["result"]="collected_during_previous_fall";report.traversal.append(row);return
 game.scan_food()
 check(is_instance_valid(body.claimed_by) and not body.freeze,id+": normal scan releases its own physics body")
 check(game.player.score==before,id+": release does not award early")
 var released:Transform3D=body.transform
 game.city._process(0.0)
 check(body.transform.is_equal_approx(released),id+": animation/controller leaves released body alone")
 var ticks:=0
 while is_instance_valid(body) and ticks<360:
  if ticks%6==0:game.scan_food()
  await physics_frame
  ticks+=1
 row["seconds"]=ticks/60.0
 row["result"]="collected" if not is_instance_valid(body) else "stuck"
 if is_instance_valid(body):row["end"]={"position":str(body.position),"frozen":body.freeze,"claimed":is_instance_valid(body.claimed_by),"mask":body.collision_mask}
 check(not is_instance_valid(body) and game.player.score>before,id+": complete gravity fall is collected")
 check(receipts.has(instance_id) and receipts[instance_id].top < -3.5,id+": collection receipt occurs only after the entire body clears the ground")
 report.traversal.append(row)
 print("SCENE_QA_PROBE "+JSON.stringify(row))
 # Let nearby objects finish before moving the mouth away from their fall.
 await frames(90)
func setup(map_id:String)->void:
 game.selected_map=map_id;game.start_level();game.begin_play()
 game.set_physics_process(false);game.city.set_process(false)
 for h in game.holes:
  h.enabled=false
  if h!=game.player:h.active=false
func probe_interior(host:Node3D,children:Array)->void:
 if not is_instance_valid(host):return
 var size:=14.0
 for r in game.player.RADII:
  if r>=host.footprint*1.08:size=r;break
 var row:={"id":str(host.name),"radius":size,"children":children.size()}
 var host_id:int=host.get_instance_id()
 pin_hole(host.position,size)
 await frames(3)
 game.scan_food()
 for i in 480:
  if i%6==0:game.scan_food()
  await physics_frame
  if not is_instance_valid(host) and children.all(func(c):return not is_instance_valid(c.body)):break
 check(not is_instance_valid(host) and receipts.has(host_id) and receipts[host_id].points==48 and receipts[host_id].top < -3.5,row.id+": real support loss collects the whole building after full fall")
 var remaining:Array=[]
 for c in children:
  if is_instance_valid(c.body):remaining.append({"id":c.id,"position":str(c.body.position),"frozen":c.body.freeze,"claimed":is_instance_valid(c.body.claimed_by)})
  check(not is_instance_valid(c.body),c.id+": interior piece falls after structural support is released")
 row["remaining"]=remaining
 row["result"]="collected" if remaining.is_empty() else "stuck"
 report.traversal.append(row)
func run()->void:
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 game.item_collected.connect(record_collection)
 setup("city")
 await frames(3)
 var audit:=Audit.inspect(game.city)
 audit["clearance_issues"]=Audit.inspect_clearance(game.city)
 audit["placement_repairs"]=game.city.layout_repairs
 audit["map"]="city";report.audits.append(audit)
 check(audit.issues.is_empty(),"city ownership/geometry/registry audit: "+JSON.stringify(audit.issues))
 check(audit.clearance_issues.is_empty(),"outdoor recipe physics shapes do not start inside other scenery: "+JSON.stringify(audit.clearance_issues))
 check(game.city.recipe_actors.size()==100 and audit.recipe_objects>140,"all 100 recipes expose independently owned scene objects")
 for a in game.city.recipe_actors:
  var ids:Array=a.bodies.keys()
  ids.erase("frame");ids.append("frame")
  for id in ids:
   var b:Node3D=a.bodies[id]
   candidates.append({"id":a.definition.id+"/"+id,"body":b,"instance_id":b.get_instance_id()})
 # Negative controls must be rejected by the same audit, not a special test path.
 var luggage:=actor("luggage_carousel")
 check(luggage.bodies.has("suitcase"),"reported suitcase exists independently of its counter")
 var merged:Dictionary=luggage.duplicate()
 merged.bodies=luggage.bodies.duplicate();merged.bodies.suitcase=merged.bodies.frame
 var bad:=Audit.inspect_recipe(merged,game.city.foods)
 report.negative_controls.append({"fault":"old single-owner luggage fixture","issues":bad})
 check(bad.any(func(i):return i.code=="shared_physics_owner"),"audit detects independently authored pieces merged into one rigid body")
 var globe:=actor("route_globe")
 var globe_body:Node3D=globe.body
 var sphere:MeshInstance3D=globe.motions[0].node
 var original:Vector3=sphere.scale
 sphere.scale*=2
 bad=Audit.inspect_recipe(globe,game.city.foods)
 report.negative_controls.append({"fault":"old diameter-as-radius mesh","issues":bad})
 check(bad.any(func(i):return i.code=="geometry_exceeds_authored_size"),"audit detects the oversized sphere from the old builder")
 sphere.scale=original
 var registry:Array=game.city.foods.duplicate();registry.erase(globe_body)
 bad=Audit.inspect_recipe(globe,registry)
 check(bad.any(func(i):return i.code=="missing_swallow_registration"),"audit detects a visible object omitted from swallowing")
 report.negative_controls.append({"fault":"missing registry owner","issues":bad})
 var original_at:Vector3=globe_body.position
 var blocker:Node3D=game.city.building_visuals[0].body
 globe_body.position=blocker.position
 await frames(2)
 bad=Audit.inspect_clearance(game.city)
 check(bad.any(func(i):return i.code=="spawn_interpenetration" and i.id=="route_globe/frame"),"physics audit detects a prop accidentally spawned inside a solid obstacle")
 report.negative_controls.append({"fault":"spawned in solid obstacle","issues":bad})
 globe_body.position=original_at
 await frames(2)
 await probe(luggage.bodies.suitcase,"luggage_carousel/suitcase",.85)
 check(is_instance_valid(luggage.body) and luggage.body.freeze,"small suitcase falls while its larger counter remains")
 var dock:=actor("bicycle_dock")
 check(dock.bodies.size()==4,"bicycle rack has a base and three independent blue plates")
 await probe(dock.bodies.dock_0,"bicycle_dock/dock_0",.85)
 check(is_instance_valid(dock.bodies.dock_2) and dock.bodies.dock_2.freeze and dock.body.freeze,"far blue plate and larger base remain when a near plate falls")
 await probe(globe_body,"route_globe/frame",.85)
 # Visit every authored object at its actual map position, using real level
 # radii. Neighbors swallowed in the same opening are recorded separately.
 var interiors:Dictionary={}
 for c in candidates:
  if is_instance_valid(c.body) and is_instance_valid(c.body.support_parent):
   var host:Node3D=c.body.support_parent
   var key:int=host.get_instance_id()
   if not interiors.has(key):interiors[key]={"host":host,"children":[]}
   interiors[key].children.append(c)
  if is_instance_valid(c.body):await probe(c.body,c.id)
  else:report.traversal.append({"id":c.id,"result":"already_collected_in_nearby_probe"})
 for group in interiors.values():await probe_interior(group.host,group.children)
 for c in candidates:
  check(receipts.has(c.instance_id),c.id+": individually accounted for by the real collection callback")
 report["recipe_coverage"]={"declared":candidates.size(),"collected":candidates.filter(func(c):return receipts.has(c.instance_id)).size()}
 # A fresh scene tests support loss without first removing its carried item.
 setup("city")
 luggage=actor("luggage_carousel")
 var carried:Node3D=luggage.bodies.suitcase
 await probe(luggage.body,"luggage_carousel/counter_support_loss",1.2)
 await frames(180)
 check(not is_instance_valid(carried),"removing the counter never leaves its suitcase floating")
 # All 16 imported character variants, using their normal initial-size gate.
 for i in 16:
  var citizen:Node3D=game.city.citizens[i].body
  if is_instance_valid(citizen):await probe(citizen,"citizen_variant_%02d"%i,.85)
 setup("food")
 audit=Audit.inspect(game.city);audit["map"]="food";report.audits.append(audit)
 check(audit.issues.is_empty(),"food-map registration/support audit: "+JSON.stringify(audit.issues))
 report["checks"]=checks;report["failures"]=failures
 print("SCENE_QA_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
