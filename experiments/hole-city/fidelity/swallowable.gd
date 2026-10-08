extends "res://fidelity/rim_body.gd"
## The actual building tips and falls as one body; facade cells are not solids.
var fractured:=false
var fracture_piece_count:=0
var contents:Array[Node3D]=[]
# Retain legacy cache fields for existing scene/resources and tooling.
var fracture_cache:Resource
var fracture_material:Material
var collapse_origin:=Vector3.ZERO
var collapse_elapsed:=0.0

func clear_building_reveal()->void:
	if category=="building" and fracture_material is ShaderMaterial:
		fracture_material.set_shader_parameter("visibility",1.0)
		fracture_material.set_shader_parameter("reveal_occluder",0.0)

func begin_pull(hole:Node3D)->bool:
	var was_supported:=freeze
	var admitted:=super.begin_pull(hole)
	if admitted:
		if was_supported:collapse_origin=global_position;collapse_elapsed=0.0
		clear_building_reveal()
		if category=="building":points=48
	return admitted

func begin_swallow(hole:Node3D)->bool:
	var was_supported:=freeze
	var admitted:=super.begin_swallow(hole)
	if admitted:
		if was_supported:collapse_origin=global_position;collapse_elapsed=0.0
		clear_building_reveal()
		# Preserve the former sixteen-piece total, payable only after full fall.
		if category=="building":points=48
	return admitted

func _physics_process(delta:float) -> void:
	super._physics_process(delta)
	if consumed or category!="building" or fractured or freeze:return
	collapse_elapsed+=delta
	var tilt:=acos(clampf(global_basis.y.normalized().dot(Vector3.UP),-1.0,1.0))
	if collapse_elapsed>=.18 and (tilt>deg_to_rad(8.0) or global_position.y<collapse_origin.y-.18):
		# Physical support loss remains real after a pull or a canceled claim.
		var owner:Node3D=claimed_by if is_instance_valid(claimed_by) else fall_credit if is_instance_valid(fall_credit) else pull_owner
		fracture_building(owner)

func finish_swallow()->void:
	if consumed or not is_instance_valid(claimed_by):return
	# A fast complete fall may cross the collection plane before the tilt cue.
	if category=="building" and not fractured:fracture_building(claimed_by)
	super.finish_swallow()

func fracture_building(hole:Node3D) -> void:
	if fractured:return
	fractured=true
	points=48
	clear_building_reveal()
	# Precut facade patches have open edges and empty-volume colliders. Keep
	# every original surface, dressing, pose, collider and velocity instead.
	# Loose contents still lose their structural support with the actual body.
	for item in contents:
		if not is_instance_valid(item) or item.consumed:continue
		item.support_parent=null
		item.notify_moving()
		item.lock_rotation=false
		item.freeze=false
		item.sleeping=false
		item.collision_mask=1
		item.gravity_scale=1.0
		item.set_physics_process(true)
		if is_instance_valid(hole) and not is_instance_valid(item.claimed_by) and Vector2(item.global_position.x-hole.global_position.x,item.global_position.z-hole.global_position.z).length()<hole.radius*.9:item.begin_swallow(hole)
	contents.clear()
	if is_instance_valid(game) and game.get("notice")!=null:
		game.notice="BUILDING COLLAPSE"
		game.notice_time=1.3
