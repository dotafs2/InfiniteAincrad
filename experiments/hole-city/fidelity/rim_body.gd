extends "res://scripts/swallowable.gd"
## Ground contacts and gravity govern motion. Claims assign score, not motion.
var half_size:=Vector3.ZERO
var static_instances:Array[Dictionary]=[]
var cleared_ground:=false
var guiding_tip:=false
var pull_owner:Node3D
var pull_center:=Vector3.ZERO
var pull_time:=0.0
var pull_strength:=0.0
var claim_elapsed:=0.0
var claim_origin:=Vector3.ZERO
var claim_cut_state:=Vector3.ZERO
var fall_credit:Node3D
var support_parent:Node3D
var rim_samples:=PackedVector3Array()
var has_support_anchor:=false
var support_anchor:=Vector3.ZERO

func interaction_position()->Vector3:
	if freeze:return global_transform*support_anchor if has_support_anchor else global_position
	if rim_samples.is_empty():return global_position
	# After a partial fall, the visible lamp head can be far from its buried
	# body origin. Scan and aim at geometry crossing the mouth, not empty space.
	var nearest:=INF
	for local in rim_samples:
		var world:Vector3=global_transform*local
		var distance:=absf(world.y)
		nearest=minf(nearest,distance)
	var point:=Vector3.ZERO
	var count:=0
	for local in rim_samples:
		var world:Vector3=global_transform*local
		if absf(world.y)<=nearest+.12:point+=world;count+=1
	return point/maxi(1,count)

func load_unsupported_rim()->void:
	# A partially entered fixture can hang by its lamp head or roof lip. Apply
	# a bounded vertical load only to real geometry over the opening. It never
	# follows a moving hole or supplies horizontal attraction on intact ground.
	if rim_samples.is_empty() or claim_elapsed<.35 or global_position.y>claim_origin.y-.15:return
	if absf(linear_velocity.y)>.65:return
	var arm:=Vector3.ZERO
	var leverage:=.0025
	for local in rim_samples:
		var point:Vector3=global_transform*local
		if point.y<-.2 or point.y>.45:continue
		if Vector2(point.x-claimed_by.position.x,point.z-claimed_by.position.z).length()>claimed_by.radius*.92:continue
		var offset:Vector3=point-global_position
		var moment:float=Vector2(offset.x,offset.z).length_squared()
		if moment>leverage:leverage=moment;arm=offset
	if not arm.is_zero_approx():
		sleeping=false
		apply_force(Vector3.DOWN*24.0*mass,arm)
# Loose objects on a fixture have separate physics owners. This relationship
# releases support, but deliberately never folds them into its size gate.
var carried_items:Array[Node3D]=[]

func release_carried(hole:Node3D)->void:
	for item in carried_items:
		if not is_instance_valid(item) or item.consumed or is_instance_valid(item.claimed_by):continue
		if is_instance_valid(item.support_parent):continue
		item.notify_moving()
		item.lock_rotation=false
		item.freeze=false
		item.sleeping=false
		item.collision_layer=2
		item.collision_mask=1
		item.gravity_scale=1.0
		item.set_physics_process(true)
		if Vector2(item.position.x-hole.position.x,item.position.z-hole.position.z).length()<hole.radius*.9:
			item.begin_swallow(hole)
	carried_items.clear()

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
	return not is_instance_valid(support_parent) and super.can_fit(hole)

func notify_moving()->void:
	if not static_instances.is_empty():preload("res://fidelity/static_batch.gd").release(static_instances)
	if is_instance_valid(game) and is_instance_valid(game.city) and game.city.has_method("activate_food"):
		game.city.activate_food(self)

func begin_pull(hole:Node3D) -> bool:
	if not can_fit(hole):return false
	notify_moving()
	pull_owner=hole
	lock_rotation=false
	if get_meta("scripted_actor",false):collision_layer=2
	collision_mask=5 if get_meta("building_fragment",false) else 1
	pull_center=hole.global_position
	pull_time=.72
	pull_strength=24.0
	freeze=false
	sleeping=false
	set_physics_process(true)
	release_carried(hole)
	return true

func begin_swallow(hole:Node3D) -> bool:
	if not can_fit(hole):return false
	notify_moving()
	claimed_by=hole
	# Keep only potential credit when admission succeeds. It cannot award until
	# the entire body really falls; a later claimant replaces it immediately.
	fall_credit=hole
	lock_rotation=false
	if get_meta("scripted_actor",false):collision_layer=2
	claim_origin=global_position
	claim_elapsed=0.0
	claim_cut_state=Vector3(hole.position.x,hole.position.z,hole.radius)
	pull_owner=null
	pull_time=0.0
	freeze=false
	sleeping=false
	collision_mask=5 if get_meta("building_fragment",false) else 1
	gravity_scale=1.0
	set_physics_process(true)
	release_carried(hole)
	# Presentation observes admission; it never changes forces or scoring.
	if is_instance_valid(hole.get("skin_visual")) and hole.skin_visual.get("model_id")=="rainfall":
		var visual:Node3D=hole.get("skin_visual")
		if is_instance_valid(visual) and is_instance_valid(visual.rainfall):visual.rainfall.intake.watch(self)
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
		# Releasing a reservation must not orphan a body that already crossed
		# the rim. A later claimant supersedes this credit before collection.
		if is_instance_valid(fall_credit) and global_position.y+vertical_extent()<-3.5:
			claimed_by=fall_credit
			finish_swallow()
			return
		# Let an escaped body settle with real contacts; never freeze it in midair.
		if pull_time<=0.0 and sleeping:set_physics_process(false)
		return
	claim_elapsed+=delta
	var extent:=vertical_extent()
	var bottom:=global_position.y-extent
	var top:=global_position.y+extent
	if bottom<-.15:fall_credit=claimed_by
	var gap:Vector3=claimed_by.global_position-interaction_position()
	gap.y=0.0
	# Once the mouth leaves a supported body, release the score reservation.
	# It can then be swallowed again, including by another hole.
	# Partial entry is not permanent ownership. Otherwise a departed AI leaves
	# a half-sunk lamp reserved forever, and no other hole can pick it up.
	if not cleared_ground and top>=-3.1 and gap.length()>claimed_by.radius+footprint*.25:
		claimed_by=null
		guiding_tip=false
		return
	var cut_state:=Vector3(claimed_by.position.x,claimed_by.position.z,claimed_by.radius)
	if cut_state.distance_squared_to(claim_cut_state)>.0001:
		# Updating the terrain mesh does not reliably wake a sleeping rim contact.
		# Preserve its velocity; only wake it when its supporting cut changes.
		sleeping=false
		claim_cut_state=cut_state
	var tilt:=acos(clampf(global_basis.y.normalized().dot(Vector3.UP),-1.0,1.0))
	guiding_tip=height>claimed_by.radius*1.5 and tilt>deg_to_rad(25.0)
	if guiding_tip:
		var arm:Vector3=global_basis*Vector3(0,-half_size.y*.9,0)
		var anchor:=global_position+arm
		var inside:bool=Vector2(anchor.x-claimed_by.global_position.x,anchor.z-claimed_by.global_position.z).length()<claimed_by.radius*.92
		# A vertical-only load at the unsupported foot helps long props tip.
		# No horizontal attraction or tracking of the moving hole is applied.
		if inside and anchor.y<.4:apply_force(Vector3.DOWN*18.0*mass,arm)
	load_unsupported_rim()
	if top < -3.1:
		cleared_ground=true
		collision_mask=0
	if top < -3.5:finish_swallow()
