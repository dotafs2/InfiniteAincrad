extends SceneTree
const Falling=preload("res://fidelity/swallowable.gd")
var checks:=0
var failures:Array[String]=[]
var results:Array=[]
class Collector extends Node:
	var awards:=0
	func collect(_body:Node3D,_hole:Node3D) -> void:awards+=1

var collector:=Collector.new()

func _initialize() -> void:run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)

func fixture(title:String,size:Vector3,radius:float,offset:float,angle:float) -> void:
	var world:=Node3D.new()
	root.add_child(world)
	var floor:=CSGCombiner3D.new()
	floor.use_collision=true
	floor.collision_layer=1
	world.add_child(floor)
	var slab:=CSGBox3D.new()
	slab.size=Vector3(50,3,50)
	slab.position.y=-1.5
	floor.add_child(slab)
	var hole:Node3D=load("res://fidelity/hole.gd").new()
	floor.add_child(hole)
	floor.add_child(hole.hole)
	hole.radius=radius
	hole._sync_shape()
	var body:=Falling.new()
	body.game=collector
	body.height=size.y
	body.footprint=Vector2(size.x,size.z).length()*0.5
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	world.add_child(body)
	body.position=Vector3(offset,size.y/2+0.04,0)
	body.rotation.y=angle
	for i in 8:await physics_frame
	var count_before:=collector.awards
	check(body.begin_swallow(hole),title+": body fits the hole diameter")
	check(body.collision_mask==1 and body.angular_velocity.is_zero_approx(),title+": release keeps contact and starts without an artificial spin")
	var max_tilt:=0.0
	var max_visible_tilt:=0.0
	var frames:=0
	var contact_lost_too_early:=false
	while is_instance_valid(body) and frames<900:
		await physics_frame
		frames+=1
		if not is_instance_valid(body):break
		var tilt:=rad_to_deg(acos(clampf(body.global_basis.y.normalized().dot(Vector3.UP),-1,1)))
		max_tilt=maxf(max_tilt,tilt)
		var top:float=body.global_position.y+body.vertical_extent()
		if top>0:max_visible_tilt=maxf(max_visible_tilt,tilt)
		if top>-3.0 and body.collision_mask!=1:contact_lost_too_early=true
	check(not contact_lost_too_early,title+": collision stays enabled through the rim")
	check(collector.awards==count_before+1 and not is_instance_valid(body),title+": complete fall awards exactly once")
	if offset>0:check(max_visible_tilt>15.0,title+": asymmetric support visibly tips the body")
	else:check(max_visible_tilt<5.0,title+": a centered symmetric drop is not forced to rotate")
	results.append({"case":title,"max_tilt_deg":max_tilt,"visible_tilt_deg":max_visible_tilt,"seconds":frames/60.0,"collected":collector.awards-count_before})
	world.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	root.add_child(collector)
	await fixture("car",Vector3(1.65,1.18,3.5),2.2,1.2,0.0)
	await fixture("turned_car",Vector3(1.65,1.18,3.5),2.2,1.2,PI/2)
	await fixture("lamp",Vector3(0.75,3.4,0.4),0.85,0.6,0.0)
	await fixture("building",Vector3(5.1,10,7.3),5.1,3.5,0.0)
	await fixture("centered_box",Vector3(0.6,0.6,0.6),1.2,0.0,0.0)
	var report:={"checks":checks,"failures":failures,"results":results}
	print("RIM_FALL_ACCEPTANCE "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
