extends SceneTree
## Independent controller geometry/lifecycle review; no full scene or GPU claim.
const Reveal=preload("res://fidelity/hole_reveal.gd")
class Structure extends Node3D:
 var category:="building"
 var height:=4.0
 var half_size:=Vector3(1.2,2,1.2)
 var freeze:=true
 var consumed:=false
 var claimed_by:Node3D
class City extends Node3D:
 var foods:Array[Node3D]=[]
class Player extends CharacterBody3D:
 var radius:=1.0
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func ray_hits(body:Node3D,from:Vector3,to:Vector3)->bool:
 # Independent ray-versus-local-box slabs, no silhouette projection or hull.
 var at:Vector3=body.to_local(from);var direction:Vector3=body.to_local(to)-at
 var low:=.00001;var high:=.99999
 for axis in 3:
  if absf(direction[axis])<.000001:
   if absf(at[axis])>body.half_size[axis]:return false
  else:
   var a:float=(-body.half_size[axis]-at[axis])/direction[axis]
   var b:float=(body.half_size[axis]-at[axis])/direction[axis]
   low=maxf(low,minf(a,b));high=minf(high,maxf(a,b))
   if low>high:return false
 return true
func run()->void:
 var city:=City.new();root.add_child(city)
 var body:=Structure.new();city.add_child(body);body.position=Vector3(0,2,3);city.foods.append(body)
 var material:=ShaderMaterial.new();material.shader=load("res://fidelity/palette.gdshader")
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=body.half_size*2.0;mesh.mesh=box;mesh.material_override=material;body.add_child(mesh)
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,10,10);camera.look_at(Vector3.ZERO)
 var player:=Player.new();root.add_child(player)
 var reveal:=Reveal.new();reveal.bind_city(city);reveal.bind_city(city)
 check(reveal.occluders.size()==1 and reveal.bound_meshes==1,"Binding an existing city remains idempotent")
 check(reveal.geometry_cache.size()==1 and reveal.occluders[0].meshes.size()==1,"One actual structural mesh builds one shared triangle BVH")
 for category in ["person","vehicle","building_fragment","lamp","food_cake","ambient_actor"]:
  body.category=category;check(not reveal.is_structural_candidate(body),category+" is never registered just because its bounds are large")
 body.category="building"
 body.height=2.99;check(not reveal.is_structural_candidate(body),"Low structures stay opaque")
 body.height=4;body.half_size=Vector3(1.19,2,1.19);check(not reveal.is_structural_candidate(body),"Narrow structures stay opaque")
 body.half_size=Vector3(1.2,2,1.2)
 var cases:=[
  {"name":"foreground core occluder","at":Vector3(0,2,3),"half":Vector3(1.2,2,1.2),"hit":true},
  {"name":"outside core but inside shoulder","at":Vector3(3,2,3),"half":Vector3(1.2,2,1.2),"hit":false},
  {"name":"only expanded lookahead","at":Vector3(0,2,-3),"half":Vector3(1.2,2,1.2),"hit":false},
  {"name":"past camera","at":Vector3(0,2,13),"half":Vector3(1.2,2,1.2),"hit":false},
  {"name":"above camera","at":Vector3(0,13,5),"half":Vector3(1.2,2,1.2),"hit":false},
  {"name":"below ground","at":Vector3(0,-3,0),"half":Vector3(1.2,2,1.2),"hit":false},
  {"name":"tall structure crosses camera plane","at":Vector3(0,9,5),"half":Vector3(1.2,4,1.2),"hit":true},
  {"name":"far center but edge covers core","at":Vector3(8,2,3),"half":Vector3(10,2,1.2),"hit":true}]
 for case in cases:
  body.position=case.at;body.half_size=case.half;body.rotation=Vector3.ZERO
  check(reveal.blocks_core(body,camera,player)==case.hit,case.name)
 # Random oriented solid boxes are checked against actual sampled rays. A ray
 # hit proves positive coverage; a missed finite sampling grid is not proof of
 # absence, so ambiguous grazing positives are reported rather than mislabeled.
 var rng:=RandomNumberGenerator.new();rng.seed=6092802
 var positive_rays:=0;var ambiguous:=0;var reference_negative:=0
 for i in 180:
  body.height=rng.randf_range(3,15);body.half_size=Vector3(rng.randf_range(1.2,4),body.height*.5,rng.randf_range(1.2,4))
  body.position=Vector3(rng.randf_range(-12,12),body.half_size.y+.2,rng.randf_range(-12,18))
  body.rotation=Vector3(0,rng.randf_range(-PI,PI),0)
  var any_hit:=false
  for x in range(-10,11):
   for z in range(-10,11):
    if x*x+z*z>100:continue
    if ray_hits(body,camera.position,Vector3(float(x)/10,0,float(z)/10)):any_hit=true;break
   if any_hit:break
  var selected:bool=reveal.blocks_core(body,camera,player)
  if any_hit:
   positive_rays+=1;check(selected,"Every sampled real OBB/core ray hit is selected: %d"%i)
  elif selected:ambiguous+=1
  else:reference_negative+=1
 check(positive_rays>=10 and reference_negative>=30,"Independent ray oracle exercises positive and negative geometry")
 body.height=4;body.half_size=Vector3(1.2,2,1.2);body.rotation=Vector3.ZERO;body.position=Vector3(0,2,3)
 reveal.reset();reveal.tick(camera,player,.05,true)
 var initial:float=reveal.body_reveal_weight(body)
 check(initial>0 and initial<1,"Actual blocker fades in over time")
 reveal.tick(camera,player,1,true);check(reveal.body_reveal_weight(body)==1,"Persistent blocker reaches full eligible weight")
 body.position.x=4;reveal.tick(camera,player,.016,true)
 check(reveal.body_reveal_weight(body)>0 and reveal.body_reveal_weight(body)<1,"Unblocking starts a bounded smooth restoration")
 reveal.tick(camera,player,1,true);check(reveal.body_reveal_weight(body)==0,"Unblocked structure restores opacity")
 body.position.x=0;reveal.tick(camera,player,1,true);body.freeze=false;reveal.tick(camera,player,.001,true)
 check(reveal.body_reveal_weight(body)==0,"Physics release restores weight immediately without a fade tail")
 body.freeze=true;body.claimed_by=player;check(not reveal.is_intact(body),"Claimed structure is not intact")
 body.claimed_by=null;body.consumed=true;check(not reveal.is_intact(body),"Consumed structure is not intact")
 body.consumed=false;reveal.tick(camera,player,1,true);reveal.reset()
 check(reveal.body_reveal_weight(body)==0 and reveal.target.w==0,"Reset clears individual eligibility and the aperture")
 reveal.tick(camera,player,1,true);body.free();reveal.tick(camera,player,1,true);reveal.reset();reveal.reset(true)
 check(reveal.occluders.is_empty() and reveal.entries.is_empty(),"Freed active bodies survive tick and both reset paths; strict logs must also be clean")
 city.foods.clear()
 var reset_body:=Structure.new();city.add_child(reset_body);reset_body.position=Vector3(0,2,3);city.foods.append(reset_body)
 var reset_mesh:=MeshInstance3D.new();reset_mesh.mesh=box;reset_mesh.material_override=material;reset_body.add_child(reset_mesh)
 reveal.bind_city(city);reveal.tick(camera,player,1,true)
 check(reveal.body_reveal_weight(reset_body)==1,"Direct free-to-reset fixture starts with an active weight")
 reset_body.free();reveal.reset();reveal.reset(true)
 check(reveal.occluders.is_empty() and reveal.entries.is_empty(),"Reset is safe immediately after active-body deletion, without an intervening tick")
 check(reveal.geometry_cache.is_empty(),"Full scene reset releases the triangle cache")
 print("CONTROLLER_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"ray_cases":180,"positive_ray_cases":positive_rays,"negative_ray_cases":reference_negative,"ambiguous_grazing":ambiguous,"scope":"Controller-only headless geometry/lifecycle, no full scene, renderer readback or GPU/device timing"}))
 camera.free();player.free();city.free();quit(0 if failures.is_empty() else 1)
