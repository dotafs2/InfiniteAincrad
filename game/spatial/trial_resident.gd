extends Node3D

## A small original resident assembled from primitive meshes.  The body is deliberately
## independent of the market asset and keeps its own movement/gesture state.

var _body: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _bucket: Node3D
var _ration: MeshInstance3D
var _right_hand: MeshInstance3D
@export var shirt_color := Color("31506b")
@export var hair_color := Color("4b3629")
var _walking: bool = false
var _motion_time: float = 0.0
var _gesture: String = "idle"

func _ready() -> void:
	_build_body()

func _process(delta: float) -> void:
	_motion_time += delta
	var swing: float = sin(_motion_time * 8.0) * (0.55 if _walking else 0.04)
	if _left_leg != null:
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
	if _left_arm != null:
		_left_arm.rotation.x = -swing * 0.65
		_right_arm.rotation.x = swing * 0.65
		if _gesture in ["drink", "eat"]:
			_right_arm.rotation.x = 2.3
			_left_arm.rotation.x = 1.8 if _gesture == "drink" else 0.15
		elif _gesture in ["bend", "harvest"]:
			_right_arm.rotation.x = 0.6 + sin(_motion_time * 3.0) * 0.12
			_left_arm.rotation.x = 0.5
		elif _gesture == "carry":
			_right_arm.rotation.x = 0.12
		elif _gesture == "work":
			_right_arm.rotation.x = 0.9 + sin(_motion_time * 5.0) * 0.55
			_left_arm.rotation.x = 0.5
	if _gesture in ["bend", "harvest", "rest"] and _body != null:
		_body.rotation.x = lerp(_body.rotation.x, 0.32, minf(delta * 7.0, 1.0))
	elif _body != null:
		_body.rotation.x = lerp(_body.rotation.x, 0.0, minf(delta * 7.0, 1.0))
	if _bucket != null:
		_bucket.visible = _gesture == "carry" or _gesture == "drink" or _gesture == "bend"
		_bucket.position = _body.to_local(_right_hand.global_position) + Vector3(0.0, -0.12, 0.0)
		_bucket.rotation.x = -0.45 if _gesture == "drink" else 0.0
	if _ration != null:
		_ration.visible = _gesture == "eat"

func set_walking(value: bool) -> void:
	_walking = value

func set_gesture(value: String) -> void:
	_gesture = value

func bucket_visible() -> bool:
	return _bucket != null and _bucket.visible

func _build_body() -> void:
	_body = Node3D.new()
	_body.name = "OriginalResidentBody"
	_body.scale = Vector3.ONE * 0.85
	_body.position.y = 0.06
	add_child(_body)

	_torso = MeshInstance3D.new()
	_torso.name = "Torso"
	var torso_mesh: CapsuleMesh = CapsuleMesh.new()
	torso_mesh.radius = 0.23
	torso_mesh.height = 0.86
	_torso.mesh = torso_mesh
	_torso.position = Vector3(0.0, 1.13, 0.0)
	_torso.material_override = _material(shirt_color)
	_body.add_child(_torso)
	_box(_body, "Belt", Vector3(0, 0.9, -0.015), Vector3(0.45, 0.065, 0.38), Color("62492e"))
	_box(_body, "Buckle", Vector3(0, 0.9, -0.21), Vector3(0.085, 0.07, 0.025), Color("c5a361"))
	_box(_body, "Apron", Vector3(0, 0.72, -0.12), Vector3(0.33, 0.3, 0.12), Color("c8b58b"))
	_box(_body, "Hips", Vector3(0, 0.63, 0), Vector3(0.33, 0.22, 0.27), Color("263746"))
	_box(_body, "Collar", Vector3(0, 1.51, -0.045), Vector3(0.23, 0.09, 0.23), Color("e3d4b4"))

	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	_head.mesh = head_mesh
	_head.position = Vector3(0.0, 1.78, 0.0)
	_head.material_override = _material(Color("#d69b72"))
	_body.add_child(_head)
	var hair := MeshInstance3D.new()
	var hair_shape := SphereMesh.new()
	hair_shape.radius = 0.195
	hair_shape.height = 0.22
	hair.mesh = hair_shape
	hair.position = Vector3(0, 1.88, 0.015)
	hair.material_override = _material(hair_color)
	_body.add_child(hair)
	_box(_body, "Fringe", Vector3(0, 1.87, -0.16), Vector3(0.25, 0.1, 0.09), hair_color)
	_box(_body, "Nose", Vector3(0, 1.75, -0.19), Vector3(0.04, 0.06, 0.06), Color("d69b72"))
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_shape := SphereMesh.new()
		eye_shape.radius = 0.022
		eye_shape.height = 0.035
		eye.mesh = eye_shape
		eye.position = Vector3(side * 0.065, 1.78, -0.18)
		eye.material_override = _material(Color("25333a"))
		_body.add_child(eye)

	_left_leg = _limb("LeftLeg", Vector3(-0.11, 0.58, 0.0), Color("#263746"))
	_right_leg = _limb("RightLeg", Vector3(0.11, 0.58, 0.0), Color("#263746"))
	_left_arm = _limb("LeftArm", Vector3(-0.32, 1.2, 0.0), shirt_color)
	_right_arm = _limb("RightArm", Vector3(0.32, 1.2, 0.0), shirt_color)
	for leg in [_left_leg, _right_leg]:
		_box(leg, "Boot", Vector3(0, -0.52, -0.045), Vector3(0.19, 0.17, 0.27), Color("553c2d"))
	_box(_left_arm, "Hand", Vector3(0, -0.59, 0), Vector3(0.15, 0.16, 0.15), Color("d69b72"))
	_right_hand = _box(_right_arm, "Hand", Vector3(0, -0.59, 0), Vector3(0.15, 0.16, 0.15), Color("d69b72"))
	_ration = _box(_right_hand, "Ration", Vector3(0, -0.03, -0.07), Vector3(0.16, 0.09, 0.12), Color("c99245"))
	_ration.visible = false

	_bucket = Node3D.new()
	_bucket.name = "HandBucket"
	_bucket.position = Vector3(0.42, 0.73, -0.02)
	var bucket_mesh: MeshInstance3D = MeshInstance3D.new()
	var bucket_shape: CylinderMesh = CylinderMesh.new()
	bucket_shape.top_radius = 0.13
	bucket_shape.bottom_radius = 0.1
	bucket_shape.height = 0.22
	bucket_mesh.mesh = bucket_shape
	bucket_mesh.material_override = _material(Color("#b87735"))
	_bucket.add_child(bucket_mesh)
	var handle: MeshInstance3D = MeshInstance3D.new()
	var handle_mesh: TorusMesh = TorusMesh.new()
	handle_mesh.inner_radius = 0.095
	handle_mesh.outer_radius = 0.105
	handle_mesh.rings = 8
	handle_mesh.ring_segments = 12
	handle.mesh = handle_mesh
	handle.position.y = 0.12
	handle.rotation.x = PI / 2.0
	handle.material_override = _material(Color("#65431f"))
	_bucket.add_child(handle)
	_body.add_child(_bucket)

func _limb(limb_name: String, limb_position: Vector3, color: Color) -> Node3D:
	var limb: Node3D = Node3D.new()
	limb.name = limb_name
	limb.position = limb_position
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.16, 0.56 if limb_name.contains("Leg") else 0.58, 0.16)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.31 if limb_name.contains("Leg") else -0.27
	mesh_instance.material_override = _material(color)
	limb.add_child(mesh_instance)
	_body.add_child(limb)
	return limb

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = title
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	part.position = pos
	part.material_override = _material(color)
	parent.add_child(part)
	return part

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
