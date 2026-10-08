extends SceneTree
## Selective architecture acceptance. The independent oracle intersects sampled
## camera-to-mouth segments with oriented boxes; it does not project silhouettes.
class Fixture:
	extends RigidBody3D
	var category:="building"
	var half_size:=Vector3.ONE
	var height:=2.0
	var consumed:=false
	var claimed_by:Node3D
	var batch:MultiMesh
	var batch_index:=0
class FixtureCity:
	extends Node3D
	var foods:Array[Node3D]=[]
var game:Node3D
var scene:FixtureCity
var failures:Array[String]=[]
var checks:=0
var metrics:Dictionary={}
var fixture_serial:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(category:String,at:Vector3,size:Vector3)->Fixture:
	var body:=Fixture.new();body.category=category;body.half_size=size*.5;body.height=size.y
	body.set_meta("dither_building",category=="building")
	body.name="Fixture_%03d_%s"%[fixture_serial,category];fixture_serial+=1
	body.freeze=true;body.collision_layer=4;body.collision_mask=5;body.mass=7.25
	var shape:=BoxShape3D.new();shape.size=size
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box
	var mat:=ShaderMaterial.new();mat.shader=load("res://fidelity/palette.gdshader")
	mat.set_shader_parameter("building_tint",Color("e8bb6d"));mesh.material_override=mat;body.add_child(mesh)
	scene.add_child(body);body.position=at;scene.foods.append(body)
	return body
func camera(at:Vector3)->void:
	game.camera.position=at
	game.camera.look_at(Vector3.ZERO,Vector3.FORWARD if Vector2(at.x,at.z).length()<.001 else Vector3.UP)
func ray_hits_box(body:Fixture,to:Vector3)->bool:
	# Independently solve the three segment/slab intervals in the box's local space.
	var inverse:=body.global_transform.affine_inverse()
	var start:Vector3=inverse*game.camera.global_position
	var finish:Vector3=inverse*to
	var direction:=finish-start
	var lower:=0.0;var upper:=1.0
	for axis in 3:
		if absf(direction[axis])<.0000001:
			if absf(start[axis])>body.half_size[axis]:return false
			continue
		var a:float=(-body.half_size[axis]-start[axis])/direction[axis]
		var b:float=(body.half_size[axis]-start[axis])/direction[axis]
		lower=maxf(lower,minf(a,b));upper=minf(upper,maxf(a,b))
		if lower>upper:return false
	if upper<=0.0 or lower>=1.0:return false
	var hit:Vector3=game.camera.global_position.lerp(to,maxf(0.0,lower))
	return hit.y>.02
func mouth_hits(body:Fixture)->int:
	var count:=1 if ray_hits_box(body,game.player.global_position) else 0
	for ring in range(1,9):
		for step in 96:
			var angle:=float(step)*TAU/96.0
			var distance:float=game.player.radius*float(ring)/8.0
			var point:Vector3=game.player.global_position+Vector3(cos(angle),0,sin(angle))*distance
			if ray_hits_box(body,point):count+=1
	return count
func geometry_case(label:String,body:Fixture,expected:bool)->void:
	var hits:=mouth_hits(body)
	var selected:bool=game.reveal.blocks_core(body,game.camera,game.player)
	check((hits>0)==expected,label+": independent ray/slab fixture has the intended geometry")
	check(selected==expected,label+": structure selection agrees with independent camera-to-mouth geometry")
	metrics.get_or_add("geometry",[]).append({"name":label,"expected":expected,"selected":selected,"mouth_ray_hits":hits,"rays":769})
func geometry_fixture()->void:
	game.player.position=Vector3.ZERO;game.player.radius=1.0;game.player.velocity=Vector3.ZERO
	camera(Vector3(0,12,12))
	geometry_case("Centered large building",fixture("building",Vector3(0,3.025,3),Vector3(4,6,4)),true)
	var edge:=fixture("building",Vector3(3.2,3.025,3),Vector3(4.8,6,3))
	check(not ray_hits_box(edge,Vector3.ZERO),"Wide edge fixture is missed by the single center ray")
	geometry_case("Wide edge without center-ray hit",edge,true)
	geometry_case("Raised roof across camera-to-hole path",fixture("building",Vector3(0,5,3),Vector3(8,3,8)),true)
	geometry_case("Tall facade crossing camera-height plane",fixture("building",Vector3(0,10.025,9),Vector3(4,20,4)),true)
	geometry_case("Complete structure behind ground target",fixture("building",Vector3(0,3.025,-7),Vector3(4,6,3)),false)
	geometry_case("Complete structure above camera plane",fixture("building",Vector3(0,18,8),Vector3(4,4,4)),false)
	geometry_case("Complete structure below ground plane",fixture("building",Vector3(0,-4,0),Vector3(4,4,4)),false)
	var diagonal:=fixture("building",Vector3(3.5,3.025,5.5),Vector3(8,6,.30));diagonal.rotation.y=PI/4
	geometry_case("Rotated empty corner of world AABB",diagonal,false)
	var rotation:=[Vector3(0,0,0),Vector3(0,.35,0),Vector3(0,PI/4,0),Vector3(0,PI/2,0),Vector3(.2,.8,.1)]
	for index in rotation.size():
		var wall:=fixture("building",Vector3(0,3.6,3.6),Vector3(5,4,.5));wall.rotation=rotation[index]
		geometry_case("Oriented wall %d"%index,wall,true)
	var lateral:=fixture("building",Vector3(2.35,1.55,2),Vector3(2.4,3,2.4))
	geometry_case("Nearby building outside actual mouth",lateral,false)
	game.player.velocity=Vector3(5,0,0);game.reveal.tick(game.camera,game.player,1.0,true)
	var shoulder:=Vector3(1.16,.20,1.22)
	check(game.reveal.sample_mask(shoulder,game.camera.position,game.camera.basis.z)>.05,"Nearby nonblocker's surface lies inside expanded movement aperture")
	check(not game.reveal.blocks_core(lateral,game.camera,game.player),"Expanded shoulder and lookahead never activate a nearby nonblocker")
	camera(Vector3(0,18,0))
	geometry_case("Directly overhead camera sees covered mouth",fixture("building",Vector3(0,4,0),Vector3(4,4,4)),true)
	geometry_case("Overhead camera preserves lateral structure",fixture("building",Vector3(5,4,0),Vector3(4,4,4)),false)
	camera(Vector3(0,12,12));game.player.velocity=Vector3.ZERO
func eligibility_fixture()->void:
	var position:=Vector3(0,3.025,3);var size:=Vector3(4,6,4)
	var building:=fixture("building",position,size)
	check(game.reveal.is_structural_candidate(building) and game.reveal.is_intact(building),"Large intact building opts into reveal")
	for kind in ["person","vehicle","food_cake","food_egg","lamp","building_fragment","authored_actor"]:
		var ordinary:=fixture(kind,position,size)
		if kind=="food_egg":ordinary.set_meta("is_rain",true)
		if kind=="building_fragment":ordinary.set_meta("building_fragment",true)
		check(mouth_hits(ordinary)>0,kind+": identical geometry truly blocks the mouth")
		check(not game.reveal.is_structural_candidate(ordinary) and not game.reveal.blocks_core(ordinary,game.camera,game.player),kind+": ordinary category stays opaque despite identical blocking size and position")
	for row in [{"size":Vector3(4,2,4),"label":"Short low building"},{"size":Vector3(1.8,7,1.8),"label":"Tall narrow structure"}]:
		var small:=fixture("building",position,row.size)
		check(not game.reveal.is_structural_candidate(small) and not game.reveal.blocks_core(small,game.camera,game.player),row.label+" remains opaque")
	var floor:=fixture("food_cake",Vector3(0,3,3),Vector3(4,.6,4))
	floor.set_meta("food_building",true);floor.set_meta("structural_shell",true)
	floor.set_meta("structure_width",4.0);floor.set_meta("structure_height",8.0)
	check(not game.reveal.is_structural_candidate(floor) and not game.reveal.blocks_core(floor,game.camera,game.player),"Thin food layer cannot borrow its tall stack's dimensions to qualify as a building")
	floor.set_meta("structural_shell",false)
	check(not game.reveal.is_structural_candidate(floor),"Small topper with tower membership but no shell opt-in stays opaque")
	floor.set_meta("structural_shell",true);floor.set_meta("structure_height",2.0)
	check(not game.reveal.is_structural_candidate(floor),"Low food assembly fails the large structure threshold")
	floor.set_meta("structure_height",8.0);floor.set_meta("structure_width",1.0)
	check(not game.reveal.is_structural_candidate(floor),"Narrow food assembly fails the large structure threshold")
	# The independent suite also checks actual food batches and shader output.
	floor.set_meta("structural_shell",false)
	building.freeze=false
	check(not game.reveal.is_intact(building) and not game.reveal.blocks_core(building,game.camera,game.player),"Released building immediately stops being a reveal blocker")
	building.freeze=true;building.claimed_by=game.player
	check(not game.reveal.is_intact(building),"Claimed building remains opaque during collapse admission")
	building.claimed_by=null;building.consumed=true
	check(not game.reveal.is_intact(building),"Consumed building cannot retain reveal")
	building.consumed=false;building.queue_free()
	check(not game.reveal.is_intact(building),"Queued-for-deletion structure cannot retain reveal")
func physics_snapshot(body:Fixture)->Dictionary:
	return {"transform":body.global_transform,"freeze":body.freeze,"layer":body.collision_layer,"mask":body.collision_mask,"mass":body.mass,"velocity":body.linear_velocity,"angular_velocity":body.angular_velocity,"shape_size":body.get_child(0).shape.size,"children":body.get_child_count()}
func controller_fixture()->void:
	game.reveal.reset(true)
	game.reveal.bind_city(scene)
	var blocker:=fixture("building",Vector3(0,3.025,3),Vector3(4,6,4))
	# A separate small fixture set registers exactly once, as production startup does.
	var controller_city:=FixtureCity.new();game.add_child(controller_city)
	blocker.reparent(controller_city);controller_city.foods=[blocker]
	game.reveal.reset(true);game.reveal.bind_city(controller_city)
	var before:=physics_snapshot(blocker)
	var source_material:ShaderMaterial=blocker.get_child(1).material_override
	var albedo:Color=source_material.get_shader_parameter("building_tint")
	var poses:Array[Vector4]=[]
	var weights:Array[float]=[]
	for hz in [30,60,120]:
		game.reveal.reset();game.player.velocity=Vector3(3,0,-2)
		for tick in hz:game.reveal.tick(game.camera,game.player,1.0/hz,true)
		poses.append(game.reveal.aperture);weights.append(game.reveal.body_reveal_weight(blocker))
		check(weights[-1]>.99,"%d Hz: truly blocking structure smoothly reaches reveal weight"%hz)
	check(poses[0].distance_to(poses[1])<.00001 and poses[1].distance_to(poses[2])<.00001,"Lookahead smoothing is consistent across 30/60/120 Hz")
	check(absf(weights[0]-weights[1])<.001 and absf(weights[1]-weights[2])<.001,"Per-building fade is consistent across 30/60/120 Hz")
	check(physics_snapshot(blocker)==before,"Controller changes no transform, collision shape, mass, freeze or velocities")
	check(source_material.get_shader_parameter("building_tint")==albedo,"Controller preserves original building color")
	check(source_material.get_shader_parameter("reveal_occluder")>.99,"Selection reaches the actual building shader material")
	blocker.position.x=20
	game.reveal.tick(game.camera,game.player,.016,true)
	var retreat:float=game.reveal.body_reveal_weight(blocker)
	check(retreat>0 and retreat<1,"Unblocked structure fades back without an abrupt frame jump")
	game.reveal.tick(game.camera,game.player,1.0,true)
	check(game.reveal.body_reveal_weight(blocker)==0.0,"Unblocked structure returns fully opaque")
	blocker.position=Vector3(0,3.025,3);game.reveal.tick(game.camera,game.player,1.0,true)
	blocker.freeze=false;game.reveal.tick(game.camera,game.player,.001,true)
	check(game.reveal.body_reveal_weight(blocker)==0 and source_material.get_shader_parameter("reveal_occluder")==0,"Physical release immediately clears the material weight")
	blocker.freeze=true;game.phase="playing";game.player.active=true;game.update_reveal(1.0)
	var paused_weight:float=game.reveal.body_reveal_weight(blocker);var paused_target:Vector4=game.reveal.target
	game.toggle_pause();game.update_reveal(1.0)
	check(game.reveal.body_reveal_weight(blocker)==paused_weight and game.reveal.target==paused_target,"Pause freezes current reveal backdrop")
	game.toggle_pause();game.player.active=false;game.update_reveal(.016)
	check(game.reveal.body_reveal_weight(blocker)==0 and game.reveal.target.w==0,"Inactive player clears all selection and aperture state")
	game.player.active=true;game.update_reveal(1);game.finish("timeout")
	check(game.reveal.body_reveal_weight(blocker)==0 and game.reveal.target.w==0,"Settlement clears building material and aperture state")
	game.reveal.reset(true)
	check(game.reveal.entries.is_empty() and game.reveal.occluders.is_empty() and game.reveal.radius==1.85,"World reset clears stale registrations and grown radius")
	controller_city.free()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for hole in game.holes:hole.enabled=false
	scene=FixtureCity.new();game.add_child(scene)
	geometry_fixture();eligibility_fixture();controller_fixture()
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual gameplay controller plus controlled RigidBody3D geometry; independent 769-ray slab oracle. No rendered image or device performance claim."}
	print("SELECTIVE_REVEAL_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
