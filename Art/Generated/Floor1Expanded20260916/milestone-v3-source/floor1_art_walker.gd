extends CharacterBody3D
## Local art-sample walker. No world kernel, residents, saves or model calls.

@export var walk_speed := 5.0
@export var run_speed := 8.0
@export var mouse_sensitivity := 0.0022
var houses: Array[Node3D] = []
var camera: Camera3D
var pitch: Node3D


func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "WalkerCapsule"
	collision.shape = capsule
	add_child(collision)
	pitch = Node3D.new()
	pitch.name = "CameraPitch"
	pitch.position.y = 0.63
	add_child(pitch)
	camera = Camera3D.new()
	camera.name = "WalkerCamera"
	camera.fov = 70.0
	camera.current = true
	pitch.add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch.rotation.x = clampf(pitch.rotation.x - event.relative.y * mouse_sensitivity, -1.25, 1.15)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_interact(true)
		elif event.keycode == KEY_F:
			_interact(false)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_D): input.x += 1.0
	if Input.is_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_key_pressed(KEY_S): input.y += 1.0
	input = input.normalized()
	var local_direction := Vector3(input.x, 0.0, input.y)
	var direction := global_basis * local_direction
	var speed := run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


func _interact(door: bool) -> void:
	var nearest := nearest_house_for_interaction(door, global_position)
	if nearest != null:
		if door:
			nearest.call("set_door_open", not nearest.call("is_door_open"))
		else:
			# The current modular component operates every sash/shutter in the
			# selected house together; F chooses by the nearest actual window.
			nearest.call("set_window_open", not nearest.call("is_window_open"))


func nearest_house_for_interaction(door: bool, from_world: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := 3.2 if door else 4.2
	for house in houses:
		if not is_instance_valid(house): continue
		if door:
			var opening: Dictionary = house.call("door_opening_godot")
			if opening.is_empty(): continue
			var point: Vector3 = house.global_transform * opening["centre"]
			var distance := from_world.distance_to(point)
			if distance < nearest_distance:
				nearest = house
				nearest_distance = distance
		else:
			var house_record: Variant = house.get("house")
			if not house_record is Dictionary: continue
			for entry: Dictionary in house_record.get("openings", []):
				if String(entry.get("kind", "")) != "window": continue
				var authored: Array = entry.get("centre", [])
				if authored.size() != 3: continue
				# The modular manifest is Blender (X,Y horizontal,Z up); this
				# matches door_opening_godot's conversion to Godot (X,Y up,Z).
				var local_point := Vector3(float(authored[0]), float(authored[2]),
					-float(authored[1]))
				var point: Vector3 = house.global_transform * local_point
				var distance := from_world.distance_to(point)
				if distance < nearest_distance:
					nearest = house
					nearest_distance = distance
	return nearest
