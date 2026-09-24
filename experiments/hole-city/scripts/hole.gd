extends CharacterBody3D
## Adapted from mbMayer/Godot-Hole.io (MIT, copyright 2024 mbMayer).
## Keeps the shared CSG subtraction and synchronized controller/hole mechanism.
## Adds bounded controls, footprint-gated collection, continuous growth and CPU play.

const HoleScene = preload("res://Scenes/hole.tscn")
var game: Node
var radius := 1.15
var score := 0
var collected := 0
var is_player := false
var active := true
var enabled := false
var color := Color("57e4d0")
var display_name := "You"
var hole: CSGCylinder3D
var rim: MeshInstance3D
var disk: MeshInstance3D
var label: Label3D
var target: Node3D
var ai_clock := 0.0
var joystick := Vector2.ZERO
var touch_origin := Vector2.ZERO
var touch_index := -1
var dragged := false
var follow_target := Vector3.ZERO
var test_direction := Vector2.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	hole = HoleScene.instantiate()
	hole.sides = 32
	hole.height = 16.0
	# The spawning manager attaches this sibling after this node finishes _ready.
	# Deferred attachment would leak an orphan during an immediate restart.
	var cut_material := StandardMaterial3D.new()
	cut_material.albedo_color = Color("07121c")
	cut_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole.material = cut_material
	rim = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.94
	mesh.outer_radius = 1.045
	mesh.rings = 32
	mesh.ring_segments = 8
	rim.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = mat
	add_child(rim)
	rim.position.y = 0.05
	rim.scale.y = 0.32
	disk = MeshInstance3D.new()
	var bottom := CylinderMesh.new()
	bottom.top_radius = 1.0
	bottom.bottom_radius = 1.0
	bottom.height = 0.08
	bottom.radial_segments = 48
	disk.mesh = bottom
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("07121c")
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disk.material_override = black
	add_child(disk)
	disk.position.y = -3.12
	label = Label3D.new()
	label.text = display_name
	label.font_size = 36
	label.pixel_size = 0.018
	label.modulate = color
	label.outline_modulate = Color("102633")
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	_sync_shape()

func _sync_shape() -> void:
	if is_instance_valid(hole) and hole.is_inside_tree():
		hole.radius = radius
		hole.global_position = global_position + Vector3(0.0, -3.0, 0.0)
	rim.scale = Vector3(radius, 0.32, radius)
	disk.scale = Vector3(radius, 1.0, radius)
	label.position = Vector3(0.0, 0.6, radius + 0.65)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not enabled:
		_sync_shape()
		return
	var direction := Vector2.ZERO
	if is_player:
		direction = _player_direction()
	else:
		ai_clock -= delta
		if ai_clock <= 0.0 or not is_instance_valid(target) or target.consumed or is_instance_valid(target.claimed_by):
			ai_clock = 0.65
			target = game.nearest_food(self)
		if is_instance_valid(target):
			var gap := target.global_position - global_position
			direction = Vector2(gap.x, gap.z).normalized() if gap.length() > 0.2 else Vector2.ZERO
	var speed := (10.5 if is_player else 6.8) / (1.0 + radius * 0.035)
	velocity = Vector3(direction.x, 0.0, direction.y) * speed
	move_and_slide()
	position.x = clampf(position.x, -37.0 + radius * 0.2, 37.0 - radius * 0.2)
	position.z = clampf(position.z, -37.0 + radius * 0.2, 37.0 - radius * 0.2)
	position.y = 0.0
	_sync_shape()

func _player_direction() -> Vector2:
	if test_direction.length_squared() > 0.0:
		return test_direction.limit_length()
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): d.x += 1
	if d.length_squared() > 0.0: return d.normalized()
	if touch_index >= 0: return joystick.limit_length()
	if dragged:
		var camera: Camera3D = game.camera
		var mouse := get_viewport().get_mouse_position()
		var plane := Plane(Vector3.UP, 0.0)
		var hit = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		if hit is Vector3:
			var gap: Vector3 = hit - global_position
			return Vector2(gap.x, gap.z).normalized() * clampf(gap.length() / 1.5, 0.0, 1.0)
	return Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not is_player or not enabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragged = event.pressed
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0:
			touch_index = event.index
			touch_origin = event.position
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
			joystick = Vector2.ZERO
	if event is InputEventScreenDrag and event.index == touch_index:
		joystick = (event.position - touch_origin) / 80.0

func award(value: int) -> void:
	score += value
	collected += 1
	radius = minf(11.0, sqrt(1.15 * 1.15 + float(score) * 0.095))
	_sync_shape()

func retire() -> void:
	active = false
	enabled = false
	hide()
	if is_instance_valid(hole): hole.queue_free()
