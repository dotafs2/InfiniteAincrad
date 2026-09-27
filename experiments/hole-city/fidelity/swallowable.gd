extends "res://fidelity/rim_body.gd"
## Buildings retain their full facade until support loss starts a collapse.
const FragmentBody=preload("res://fidelity/rim_body.gd")
var fractured:=false
var fracture_piece_count:=0

func _physics_process(delta:float) -> void:
	super._physics_process(delta)
	if consumed or category!="building" or fractured or not is_instance_valid(claimed_by):return
	var tilt:=acos(clampf(global_basis.y.normalized().dot(Vector3.UP),-1.0,1.0))
	if claim_elapsed>=.18 and (tilt>deg_to_rad(8.0) or global_position.y<claim_origin.y-.18):
		fracture_building(claimed_by)

func fracture_building(hole:Node3D) -> void:
	fractured=true
	var full_size:=half_size*2.0
	var original_transform:=global_transform
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(str(get_meta("asset_id",name)))
	var tint:Color=get_meta("fracture_tint",Color("b1a594"))
	# Four staggered courses, each split 2 x 2: sixteen compact pieces occupy
	# the complete original volume instead of a flat 4 x 4 slab at its center.
	var heights:=[-half_size.y,-half_size.y+full_size.y*.21,-half_size.y+full_size.y*.47,-half_size.y+full_size.y*.76,half_size.y]
	for course in 4:
		var split_x:float=full_size.x*rng.randf_range(-.15,.15)
		var split_z:float=full_size.z*rng.randf_range(-.15,.15)
		var xs:=[-half_size.x,split_x,half_size.x]
		var zs:=[-half_size.z,split_z,half_size.z]
		for cell in 4:
			var column:int=cell%2
			var row:int=cell/2
			var low:=Vector3(xs[column],heights[course],zs[row])
			var high:=Vector3(xs[column+1],heights[course+1],zs[row+1])
			var size:Vector3=(high-low)*.94
			var offset:Vector3=(high+low)*.5
			var piece:RigidBody3D=FragmentBody.new()
			piece.game=game
			piece.category="building_fragment"
			piece.points=3
			piece.height=size.y
			piece.footprint=Vector2(size.x,size.z).length()*.5
			piece.mass=maxf(.4,size.x*size.y*size.z*.08)
			piece.name="%s_Fragment_%02d"%[name,course*4+cell]
			var collision:=CollisionShape3D.new()
			var shape:=BoxShape3D.new()
			shape.size=size
			collision.shape=shape
			piece.add_child(collision)
			var visual:=MeshInstance3D.new()
			var mesh:=BoxMesh.new()
			mesh.size=size
			visual.mesh=mesh
			var material:=StandardMaterial3D.new()
			material.albedo_color=tint.lightened(rng.randf_range(0,.20))
			material.roughness=.86
			visual.material_override=material
			piece.add_child(visual)
			piece.set_meta("building_fragment",true)
			piece.set_meta("fracture_parent",name)
			get_parent().add_child(piece)
			piece.global_transform=original_transform*Transform3D(Basis.IDENTITY,offset)
			piece.collision_layer=4
			piece.collision_mask=5
			piece.linear_velocity=linear_velocity+angular_velocity.cross(original_transform.basis*offset)
			piece.angular_velocity=angular_velocity
			if is_instance_valid(game) and is_instance_valid(game.get("city")):game.city.foods.append(piece)
			# The parent has passed the size gate. Fragments reserve its credit
			# while gravity and contacts decide which pieces actually fall.
			piece.claimed_by=hole
			piece.claim_origin=piece.global_position
			piece.freeze=false
			piece.sleeping=false
			piece.set_physics_process(true)
			fracture_piece_count+=1
	if is_instance_valid(game) and game.get("notice")!=null:
		game.notice="BUILDING COLLAPSE"
		game.notice_time=1.3
	visible=false
	collision_layer=0
	collision_mask=0
	freeze=true
	consumed=true
	set_physics_process(false)
	queue_free()
