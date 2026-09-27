extends "res://scripts/swallowable.gd"
## Ground contacts and gravity govern motion. Claims assign score, not motion.
var half_size:=Vector3.ZERO
var cleared_ground:=false
var guiding_tip:=false
var pull_owner:Node3D
var pull_center:=Vector3.ZERO
var pull_time:=0.0
var pull_strength:=0.0
var claim_elapsed:=0.0
var claim_origin:=Vector3.ZERO

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:half_size=child.shape.size*0.5
	angular_damp=0.30
	linear_damp=0.18
	continuous_cd=true
	var surface:=PhysicsMaterial.new()
	surface.friction=0.55
	surface.rough=true
	surface.bounce=0.0
	physics_material_override=surface

func can_fit(hole:Node3D) -> bool:
	return not get_meta("resident",false) and super.can_fit(hole)

func begin_pull(hole:Node3D) -> bool:
	if not can_fit(hole):return false
	pull_owner=hole
	pull_center=hole.global_position
	pull_time=.72
	pull_strength=24.0
	freeze=false
	sleeping=false
	set_physics_process(true)
	return true

func begin_swallow(hole:Node3D) -> bool:
	if not can_fit(hole):return false
	claimed_by=hole
	claim_origin=global_position
	claim_elapsed=0.0
	pull_owner=null
	pull_time=0.0
	freeze=false
	sleeping=false
	collision_mask=5 if get_meta("building_fragment",false) else 1
	gravity_scale=1.0
	set_physics_process(true)
	return true

func vertical_extent() -> float:
	return absf(global_basis.x.y)*half_size.x+absf(global_basis.y.y)*half_size.y+absf(global_basis.z.y)*half_size.z

func _physics_process(delta:float) -> void:
	if consumed:return
	if pull_time>0.0:
		pull_time=maxf(0.0,pull_time-delta)
		if is_instance_valid(pull_owner) and not is_instance_valid(claimed_by):
			var gap:=pull_center-global_position
			gap.y=0.0
			if gap.length()<=pull_owner.radius+3.0:
				var force:Vector3=(gap.normalized()*pull_strength-Vector3(linear_velocity.x,0,linear_velocity.z)*4.0)*mass
				apply_central_force(force.limit_length(45.0*mass))
			else:pull_time=0.0
		else:pull_time=0.0
		if pull_time<=0.0:pull_owner=null
	if not is_instance_valid(claimed_by):
		# Let an escaped body settle with real contacts; never freeze it in midair.
		if pull_time<=0.0 and sleeping:set_physics_process(false)
		return
	claim_elapsed+=delta
	var extent:=vertical_extent()
	var bottom:=global_position.y-extent
	var top:=global_position.y+extent
	var gap:Vector3=claimed_by.global_position-global_position
	gap.y=0.0
	# Once the mouth leaves a supported body, release the score reservation.
	# It can then be swallowed again, including by another hole.
	if not cleared_ground and bottom>=-.15 and gap.length()>claimed_by.radius+footprint*.25:
		claimed_by=null
		guiding_tip=false
		return
	var tilt:=acos(clampf(global_basis.y.normalized().dot(Vector3.UP),-1.0,1.0))
	guiding_tip=height>claimed_by.radius*1.5 and tilt>deg_to_rad(25.0)
	if guiding_tip:
		var arm:Vector3=global_basis*Vector3(0,-half_size.y*.9,0)
		var anchor:=global_position+arm
		var inside:bool=Vector2(anchor.x-claimed_by.global_position.x,anchor.z-claimed_by.global_position.z).length()<claimed_by.radius*.92
		# A vertical-only load at the unsupported foot helps long props tip.
		# No horizontal attraction or tracking of the moving hole is applied.
		if inside and anchor.y<.4:apply_force(Vector3.DOWN*18.0*mass,arm)
	if top < -3.1:
		cleared_ground=true
		collision_mask=0
	if top < -3.5:finish_swallow()
