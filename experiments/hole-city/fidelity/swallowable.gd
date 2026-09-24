extends "res://scripts/swallowable.gd"
## Keep the physical rim until the entire rotated body clears the ground.
## Gravity and asymmetric ground contacts create the tipping motion.
var half_size:=Vector3.ZERO
var cleared_ground:=false
var guiding_tip:=false

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			half_size=child.shape.size*0.5
	angular_damp=0.25
	linear_damp=0.15
	continuous_cd=true
	var surface:=PhysicsMaterial.new()
	surface.friction=0.55
	surface.bounce=0.0
	physics_material_override=surface

func begin_swallow(hole:Node3D) -> bool:
	if not can_fit(hole):return false
	claimed_by=hole
	freeze=false
	sleeping=false
	collision_mask=1
	gravity_scale=1.0
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	set_physics_process(true)
	return true

func vertical_extent() -> float:
	return absf(global_basis.x.y)*half_size.x+absf(global_basis.y.y)*half_size.y+absf(global_basis.z.y)*half_size.z

func _physics_process(_delta:float) -> void:
	if consumed or not is_instance_valid(claimed_by):return
	# A bounded attraction keeps already claimed objects near a moving hole;
	# it is a force, not a position/velocity override or an artificial spin.
	var gap:Vector3=claimed_by.global_position-global_position
	gap.y=0
	var tilt:float=acos(clampf(global_basis.y.normalized().dot(Vector3.UP),-1,1))
	if height>claimed_by.radius*1.5 and tilt>deg_to_rad(25):guiding_tip=true
	if guiding_tip:
		# Long objects can bridge both sides after tipping. Pull their lower end
		# into the mouth with a force at that point, retaining real contact,
		# inertia and torque instead of rotating or shrinking the mesh by script.
		var arm:Vector3=global_basis*Vector3(0,-half_size.y*0.9,0)
		var anchor:Vector3=global_position+arm
		var throat:=Vector3(claimed_by.global_position.x,minf(anchor.y,-claimed_by.radius),claimed_by.global_position.z)
		var point_velocity:Vector3=linear_velocity+angular_velocity.cross(arm)
		var force:Vector3=(throat-anchor)*24.0-point_velocity*6.0
		apply_force(force.limit_length(110.0)*mass,arm)
	else:
		var desired:Vector3=gap*16.0-Vector3(linear_velocity.x,0,linear_velocity.z)*6.0
		apply_central_force(desired.limit_length(75.0)*mass)
	var top:float=global_position.y+vertical_extent()
	if top < -3.1:
		# Once below the underside, a later moving CSG rebuild cannot trap it.
		cleared_ground=true
		collision_mask=0
	if top < -3.5:finish_swallow()
