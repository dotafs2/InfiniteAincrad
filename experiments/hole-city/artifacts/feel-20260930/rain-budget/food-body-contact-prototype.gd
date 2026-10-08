extends "res://fidelity/rim_body.gd"
## Food tiers release together; collection still requires a complete real fall.
var supported_food:Array[Node3D]=[]
var batch:MultiMesh
var batch_index:=-1
var batch_members:Array[Node3D]=[]
var food_visual:MeshInstance3D
var reveal_weight:=0.0
var is_rain:=false
var rain_landed:=false
var rain_contact_time:=0.0
var rain_age:=0.0
var release_delay:=0.0
var release_hole:Node3D
var collapse_started:=false
var prior_fall_speed:=0.0
var impact_cooldown:=0.0
var terrain_sweep_points:=PackedVector3Array()
var terrain_previous_pose:=Transform3D.IDENTITY
var terrain_pose_ready:=false
var terrain_opening_entered:=false

func terrain_hit(state:PhysicsDirectBodyState3D,at:Vector2,upper:float,lower:float)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,upper,at.y),Vector3(at.x,lower,at.y),1,[get_rid()])
	return state.get_space_state().intersect_ray(query)

func sweep_terrain_support(state:PhysicsDirectBodyState3D)->void:
	if terrain_sweep_points.is_empty() or state.sleeping or cleared_ground or consumed or (collision_mask&1)==0:return
	if not is_instance_valid(game) or not is_instance_valid(game.ground):return
	var pose:=state.transform
	var previous:Transform3D=terrain_previous_pose if terrain_pose_ready else pose
	terrain_previous_pose=pose;terrain_pose_ready=true
	var ground_y:float=game.ground.global_position.y
	# Conservative broad phase: only awake round foods close enough to cross
	# the terrain inspect their shared hull vertices or issue physics queries.
	var bound:float=(absf(pose.basis.x.y)+absf(pose.basis.z.y))*footprint+absf(pose.basis.y.y)*height*.5
	var descent:float=minf(0.0,state.linear_velocity.y)*state.step
	if pose.origin.y-bound+descent>ground_y+.05:
		terrain_opening_entered=false
		return
	var lowest:=Vector3(0,INF,0)
	for point in terrain_sweep_points:
		var at:Vector3=pose*point
		if at.y<lowest.y:lowest=at
	if lowest.y>ground_y+.05:terrain_opening_entered=false
	if terrain_opening_entered or state.linear_velocity.y>.05:return
	var upper:=maxf(previous.origin.y,pose.origin.y)
	var lower:=lowest.y+descent-.025
	var center_hit:=terrain_hit(state,Vector2(pose.origin.x,pose.origin.z),upper,lower)
	if center_hit.is_empty():
		# Once a piece crosses an actual opening, a later moving/closing mouth
		# cannot make this fallback lift it back onto newly restored terrain.
		if lowest.y<ground_y-.015:terrain_opening_entered=true
		return
	if center_hit.rid!=game.ground.body.get_rid() or center_hit.normal.y<.7:return
	# A center over a hole must tip/fall through the usual rim solver. Even
	# with a solid center, require terrain below the actual lowest hull point.
	var foot_hit:=terrain_hit(state,Vector2(lowest.x,lowest.z),upper,lower)
	if foot_hit.is_empty() or foot_hit.rid!=game.ground.body.get_rid() or foot_hit.normal.y<.7:return
	var support_y:float=foot_hit.position.y
	# Ordinary contacts need their penetration slop to generate real torque.
	# Predictively holding every approach above the floor balances tilted food
	# on a point forever. Intervene only after the solver missed a deep crossing.
	if lowest.y>=support_y-.045:return
	# Swept contact prevents a thin lower tier being punched through the slab.
	# Tangential velocity and angular motion remain the physics solver's job.
	pose.origin.y+=support_y-.008-lowest.y
	state.transform=pose
	state.linear_velocity.y=0.0
	terrain_previous_pose=pose

func rain_support_extent(basis:Basis)->float:
	# Ray support must meet the real collider, not an enclosing box corner.
	# Rounded hulls tilted above that corner otherwise sleep in a small air gap
	# with no native support contact to wake them when the platform disappears.
	if terrain_sweep_points.is_empty():
		return absf(basis.x.y)*half_size.x+absf(basis.y.y)*half_size.y+absf(basis.z.y)*half_size.z
	var bottom:=0.0
	for point in terrain_sweep_points:bottom=minf(bottom,(basis*point).y)
	return -bottom

func _integrate_forces(state:PhysicsDirectBodyState3D)->void:
	if (is_rain or collapse_started) and impact_cooldown<=0.0 and prior_fall_speed>1.8 and state.get_contact_count()>0:
		for i in state.get_contact_count():
			if state.get_contact_local_normal(i).y>.45:
				contact_feedback(state.get_contact_local_position(i),prior_fall_speed)
				break
	# Air drag gives thin food a readable descent and prevents a whole collider
	# crossing the zero-thickness terrain surface in one 60 Hz contact step.
	if not is_rain:
		sweep_terrain_support(state)
		return
	state.linear_velocity.y=maxf(state.linear_velocity.y,-5.5)
	if state.linear_velocity.y>.15:
		rain_landed=false;rain_contact_time=0.0
		return
	# A swept foot contact handles sub-centimetre triangle contact loss. Query
	# the actual collision world, so this cannot support food above an open hole.
	var extent:=rain_support_extent(state.transform.basis)
	var from:=state.transform.origin
	var to:=from+Vector3.DOWN*(extent-state.linear_velocity.y*state.step+.025)
	var query:=PhysicsRayQueryParameters3D.create(from,to,collision_mask,[get_rid()])
	var hit:=state.get_space_state().intersect_ray(query)
	if not hit.is_empty() and hit.normal.y>.7:
		if -state.linear_velocity.y>1.8 and impact_cooldown<=0.0:contact_feedback(hit.position,-state.linear_velocity.y)
		var pose:=state.transform
		# Keep a small native-contact slop rather than suspending the hull
		# above the collider. Native contact ownership supplies wake linkage.
		pose.origin.y=hit.position.y+extent-.008
		state.transform=pose
		state.linear_velocity.y=0
		rain_contact_time+=state.step
		rain_landed=rain_contact_time>=.15 and state.linear_velocity.length()<.8
		if rain_contact_time>.65 and state.linear_velocity.length()<.18 and state.angular_velocity.length()<.3 and not is_instance_valid(claimed_by):
			for i in state.get_contact_count():
				if state.get_contact_collider(i)==hit.rid:
					state.sleeping=true
					break
	else:
		rain_contact_time=0.0;rain_landed=false

func contact_feedback(at:Vector3,speed:float)->void:
	if not is_instance_valid(game) or not is_instance_valid(game.city):return
	impact_cooldown=.35
	game.city.queue_food_impact(self,at,speed)

func set_reveal_weight(_value:float)->void:
	# Food stacks are physical collectibles, never ditherable building meshes.
	# Ignore legacy reveal writes as well as keeping the shader path opaque.
	reveal_weight=0.0
	if batch!=null and batch_index>=0 and batch.use_custom_data:
		batch.set_instance_custom_data(batch_index,Color(reveal_weight,0,0,0))

func expose_visual()->void:
	# A released piece is debris, even when it came from a tall food building.
	# It may never re-enter the intact-shell occluder set.
	set_meta("structural_shell",false)
	reveal_weight=0.0
	if batch!=null and batch_index>=0:
		# Compact active instances rather than sending zero-scale consumed slots
		# through the vertex shader for the rest of the round.
		var last:int=batch_members.size()-1
		if batch_index!=last:
			var moved:Node3D=batch_members[last]
			batch.set_instance_transform(batch_index,batch.get_instance_transform(last))
			if batch.use_custom_data:batch.set_instance_custom_data(batch_index,Color(moved.reveal_weight,0,0,0))
			moved.batch_index=batch_index;batch_members[batch_index]=moved
		if batch.use_custom_data:batch.set_instance_custom_data(last,Color(0,0,0,0))
		batch_members.pop_back();batch.visible_instance_count=last
		batch=null;batch_index=-1;batch_members=[]
	if is_instance_valid(food_visual):food_visual.visible=true

func begin_swallow(hole:Node3D)->bool:
	if not super.begin_swallow(hole):return false
	start_fall(hole)
	return true

func begin_pull(hole:Node3D)->bool:
	if not super.begin_pull(hole):return false
	start_fall(hole)
	return true

func start_fall(hole:Node3D)->void:
	max_contacts_reported=4
	rain_landed=false;rain_contact_time=0.0
	expose_visual()
	if is_instance_valid(game) and is_instance_valid(game.city) and game.city.has_method("activate_food"):game.city.activate_food(self)
	collision_layer=2;collision_mask=3
	if not collapse_started:
		collapse_started=true
		if is_instance_valid(game) and is_instance_valid(game.city) and game.city.has_method("record_collapse"):
			game.city.record_collapse(self)
	if not supported_food.is_empty() and release_delay<=0.0:
		release_hole=hole;release_delay=.075

func lose_support(hole:Node3D)->void:
	# Structural support loss is independent of the hole-size admission gate.
	# A large upper tier must tumble onto ground even if it cannot yet be eaten.
	support_parent=null;freeze=false;sleeping=false;lock_rotation=false
	gravity_scale=1.0;collision_layer=2;collision_mask=3
	fall_credit=hole
	var phase:float=float(get_meta("stack_level",0))*1.71+float(name.hash()%31)
	angular_velocity=Vector3(cos(phase)*.34,0.07,sin(phase)*.34)
	# A fixed, small release impulse breaks symmetry; it never tracks the mouth.
	linear_velocity+=Vector3(cos(phase)*.16,0,sin(phase)*.16)
	set_physics_process(true)
	if is_instance_valid(hole) and can_fit(hole) and Vector2(position.x-hole.position.x,position.z-hole.position.z).length()<hole.radius*.9:
		super.begin_swallow(hole)
	start_fall(hole)

func release_tiers(hole:Node3D)->void:
	for item in supported_food:
		if is_instance_valid(item):item.lose_support(hole)
	supported_food.clear()

func finish_swallow()->void:
	# Fast falls cannot disappear before notifying their supported children.
	if not supported_food.is_empty():release_tiers(claimed_by if is_instance_valid(claimed_by) else fall_credit)
	super.finish_swallow()

func _physics_process(delta:float)->void:
	impact_cooldown=maxf(0.0,impact_cooldown-delta)
	prior_fall_speed=maxf(0.0,-linear_velocity.y)
	if is_rain:
		rain_age+=delta
		if batch!=null and not sleeping:expose_visual()
	if release_delay>0.0:
		release_delay=maxf(0.0,release_delay-delta)
		if release_delay<=0.0:release_tiers(release_hole)
	super._physics_process(delta)
	if (is_rain or release_delay>0.0) and not consumed:set_physics_process(true)
	if is_rain and global_position.y < -16 and not is_instance_valid(claimed_by):queue_free()
