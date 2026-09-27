extends SceneTree
const Body=preload("res://fidelity/rim_body.gd")
var checks:=0
var failures:Array[String]=[]
class Collector extends Node:
	var awards:=0
	func collect(_body:Node3D,_hole:Node3D) -> void:awards+=1
class Mouth extends Node3D:
	var radius:=1.2
var collector:=Collector.new()

func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int) -> void:
	for i in n:await physics_frame
func body_at(parent:Node3D,at:Vector3,fragment:=false) -> RigidBody3D:
	var b:=Body.new()
	b.game=collector
	b.height=.8
	b.footprint=.57
	b.set_meta("building_fragment",fragment)
	var shape:=BoxShape3D.new()
	shape.size=Vector3.ONE*.8
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	b.add_child(collider)
	parent.add_child(b)
	b.position=at
	return b
func run() -> void:
	root.add_child(collector)
	var world:=Node3D.new()
	root.add_child(world)
	var floor:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var slab:=BoxShape3D.new()
	slab.size=Vector3(50,2,50)
	collider.shape=slab
	floor.add_child(collider)
	floor.position.y=-1
	world.add_child(floor)
	var hole:=Mouth.new()
	world.add_child(hole)
	var b:=body_at(world,Vector3(0,.43,0))
	await frames(5)
	b.begin_swallow(hole)
	# Repeated passes used to drag a claimed body along inside radius + 3.
	for i in 60:
		hole.position.x=minf(float(i)*.055,2.0)
		await physics_frame
	check(absf(b.position.x)<.08,"moving mouth cannot drag a supported body horizontally")
	check(not is_instance_valid(b.claimed_by),"escaped body releases its old claim")
	check(collector.awards==0,"grounded body awards no points")
	hole.position.x=0
	check(b.begin_swallow(hole),"returning hole can reclaim the escaped body")
	b.queue_free()
	var fragment:=body_at(world,Vector3(0,2,0),true)
	fragment.begin_swallow(hole)
	hole.position.x=3
	await frames(90)
	check(is_instance_valid(fragment) and fragment.position.y>.35,"fragment lands on intact ground instead of passing through")
	check(absf(fragment.position.x)<.08,"fragment does not inherit the legacy velocity tether")
	check(collector.awards==0,"grounded fragment cannot be collected remotely")
	fragment.queue_free()
	var freefall:=body_at(world,Vector3(0,2,0),true)
	hole.position.x=0
	freefall.begin_swallow(hole)
	freefall.collision_mask=0
	freefall.linear_velocity=Vector3(1,0,0)
	hole.position.x=-4
	await frames(3)
	check(freefall.linear_velocity.x>.8,"release preserves existing inertia instead of assigning target velocity")
	freefall.queue_free()
	var pulsed:=body_at(world,Vector3(1.7,.43,0))
	hole.position.x=0
	pulsed.begin_pull(hole)
	hole.position.x=6
	await frames(12)
	check(pulsed.position.x<1.7,"explicit pulse stays at its activation site when the player leaves")
	await frames(50)
	check(pulsed.pull_time==0 and not is_instance_valid(pulsed.pull_owner),"explicit pulse expires without a persistent owner")
	print("NO_TETHER_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
