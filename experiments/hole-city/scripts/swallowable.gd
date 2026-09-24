extends RigidBody3D
## Static until its full footprint fits a hole; then it really falls under gravity.

var game: Node
var category := "prop"
var points := 1
var footprint := 0.3
var height := 0.6
var claimed_by: Node3D
var consumed := false
var spawn_position := Vector3.ZERO

func _ready() -> void:
	freeze = true
	collision_layer = 1
	collision_mask = 1
	linear_damp = 0.3
	angular_damp = 1.5
	set_physics_process(false)
	spawn_position = global_position

func can_fit(hole: Node3D) -> bool:
	return not consumed and not is_instance_valid(claimed_by) and footprint * 1.08 <= hole.radius

func begin_swallow(hole: Node3D) -> bool:
	if not can_fit(hole):
		return false
	claimed_by = hole
	freeze = false
	# Ground support is removed only after the footprint is inside the opening.
	# This also avoids a rebuilt CSG collider catching an already falling body.
	collision_mask = 0
	gravity_scale = 1.5
	linear_velocity = Vector3(0.0, -2.5, 0.0)
	angular_velocity = Vector3(0.1, 0.18, -0.12)
	set_physics_process(true)
	return true

func _physics_process(_delta: float) -> void:
	if consumed or not is_instance_valid(claimed_by):
		return
	var offset := claimed_by.global_position - global_position
	linear_velocity.x = clampf(offset.x * 6.0, -12.0, 12.0)
	linear_velocity.z = clampf(offset.z * 6.0, -12.0, 12.0)
	# Award only when the complete object, including a tall roof, is below ground.
	if global_position.y + height * 0.5 < -3.5:
		finish_swallow()

func finish_swallow() -> void:
	if consumed or not is_instance_valid(claimed_by):
		return
	consumed = true
	set_physics_process(false)
	game.collect(self, claimed_by)
	queue_free()
