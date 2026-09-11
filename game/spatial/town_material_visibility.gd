extends Node3D
## Real line-of-sight sensing for public material sources on the actual town street.
##
## This component performs synchronous physics ray queries from an observer's eye to
## the actual visual tray target. It is NOT a camera, view cone, image or per-pixel
## proof; it only answers whether an opaque body blocks the straight segment. It
## stores runtime references only and never writes to the save.

var town
var resident_bodies: Dictionary = {}
var source_visuals: Node3D = null

func configure(world, bodies: Dictionary, visuals: Node3D) -> void:
	town = world
	resident_bodies = bodies
	source_visuals = visuals

func can_observe(id: String, source_id: String) -> bool:
	# Official Godot 4.7: intersect_ray is only valid inside a physics callback.
	if not Engine.is_in_physics_frame():
		return false
	if not is_inside_tree():
		return false
	if town == null or source_visuals == null:
		return false
	if not is_instance_valid(source_visuals) or not source_visuals.is_inside_tree():
		return false
	if not source_visuals.has_method("observation_target"):
		return false
	var observer: Variant = resident_bodies.get(id)
	if not is_instance_valid(observer):
		return false
	if not observer is Node3D or not observer.is_inside_tree():
		return false
	if not observer is CollisionObject3D:
		return false
	var target: Variant = source_visuals.observation_target(source_id)
	if not target is Vector3 or not (target as Vector3).is_finite():
		return false
	var start: Vector3 = (observer as Node3D).global_position + Vector3(0, 1.55, 0)
	if not start.is_finite():
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	if space == null:
		return false
	var exclude: Array[RID] = [(observer as CollisionObject3D).get_rid()]
	var query := PhysicsRayQueryParameters3D.create(start, target as Vector3, 0xFFFFFFFF, exclude)
	query.hit_from_inside = true
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()
