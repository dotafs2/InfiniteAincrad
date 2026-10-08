extends RefCounted
## Cosmetic-only GPU spray. No damage, collision, simulation RNG or moving CPU records.
## All coordinates are world-space; aim is an endpoint, not a direction.
## setup(game) adds the retained batch to game. The caller supplies simulation time
## through update(clock), and calls reset() whenever that clock is restarted.

const MAX_TRAILS := 1600
const Campaign = preload("res://scripts/campaign.gd")
const TRAIL_SHADER = preload("res://assets/shaders/spray_visual.gdshader")
const TRAVEL_BOUNDS := AABB(Vector3(-18.0, -3.0, -65.0), Vector3(36.0, 20.0, 80.0))

var batch: MultiMeshInstance3D
var material: ShaderMaterial
var budget := MAX_TRAILS
var total_emitted := 0
var _game: Node3D
var _clock := 0.0
var _cursor := 0
var _written := 0

func setup(game: Node3D) -> void:
	if is_instance_valid(batch):
		batch.queue_free()
	_game = game
	material = ShaderMaterial.new()
	material.shader = TRAIL_SHADER
	material.set_shader_parameter("clock", _clock)
	batch = MultiMeshInstance3D.new()
	batch.name = "CosmeticSpray"
	batch.multimesh = _make_multimesh(MAX_TRAILS)
	batch.multimesh.visible_instance_count = 0
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(batch)
	# The instance data stores world-space origins. Inheriting a game transform
	# would otherwise transform those origins twice.
	batch.top_level = true
	batch.global_transform = Transform3D.IDENTITY
	reset()

func _make_multimesh(count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Both channels are required by the tested Compatibility instancing layout.
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	mm.custom_aabb = TRAVEL_BOUNDS
	return mm

func set_budget(cap: int) -> void:
	var next := clampi(cap, 0, MAX_TRAILS)
	if next == budget:
		return
	budget = next
	# A budget switch cannot resurrect stale slots from a previous clock/run.
	reset()

func update(clock: float) -> void:
	_clock = clock
	if material:
		# Constant CPU work; every slot advances/fades analytically in the shader.
		material.set_shader_parameter("clock", clock)

func reset() -> void:
	_cursor = 0
	_written = 0
	total_emitted = 0
	if not is_instance_valid(batch):
		return
	batch.multimesh.visible_instance_count = 0
	# Only resets/budget changes clear the fixed storage, never the render loop.
	var empty := PackedFloat32Array()
	empty.resize(MAX_TRAILS * 20)
	batch.multimesh.buffer = empty

func emit_shot(origin: Vector3, aim: Vector3, mode: String, tier: int) -> void:
	if budget == 0 or not is_instance_valid(batch):
		return
	var now := _emission_clock()
	var endpoint := _forward_endpoint(origin, aim)
	var distance := maxf(0.1, origin.distance_to(endpoint))
	var base_direction := (endpoint - origin).normalized()
	if base_direction.length_squared() < 0.5:
		base_direction = Vector3.FORWARD
	var count := 5 if mode == "scatter" else 3
	for i in range(count):
		var direction := base_direction
		var delay := float(i) * 0.016
		if mode == "scatter":
			# Cosmetic fan is bounded by the authored 2.2m coverage width even
			# when the selected endpoint is far away. No implied wider damage.
			var fan_endpoint := endpoint + Vector3(float(i - 2) * 0.55, 0.0, 0.0)
			direction = (fan_endpoint - origin).normalized()
			delay = float(i % 2) * 0.009
		var start := origin
		# Sub-pixel nozzle separation prevents three coincident opaque streaks.
		if mode != "scatter":
			start.x += float(i - 1) * 0.025
		_write(start, direction, mode, tier, now + delay, distance, 0.72 if count == 3 else 0.80)

func emit_gate(origin: Vector3, width: float, mode: String, tier: int, streak_count: int = 0) -> void:
	if budget == 0 or not is_instance_valid(batch):
		return
	var now := _emission_clock()
	var aim := origin + Vector3(0.0, 0.0, -35.0)
	if is_instance_valid(_game) and _game.has_method("projectile_aim"):
		# One lookup, never one crowd scan per cosmetic streak.
		aim = _game.call("projectile_aim", origin)
	aim = _forward_endpoint(origin, aim)
	var count := clampi(streak_count if streak_count > 0 else ceili(absf(width) * 4.0), 6, 18)
	var direction := (aim - origin).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector3.FORWARD
	var distance := maxf(0.1, origin.distance_to(aim))
	for i in range(count):
		var across := (float(i) / float(count - 1) - 0.5) * absf(width)
		var start := origin + Vector3(across, 0.0, 0.0)
		# A three-phase deterministic delay breaks a solid horizontal white wall.
		_write(start, direction, mode, tier, now + float(i % 3) * 0.013, distance, 0.76)

func _emission_clock() -> float:
	# Emissions can occur in physics between rendered updates. Read the simulation
	# clock once per emission call so births never depend on render frame rate.
	if is_instance_valid(_game):
		var value: Variant = _game.get("sim_time")
		if value is float or value is int:
			return float(value)
	return _clock

func _speed(mode: String) -> float:
	return 52.0 if mode == "rail" else (23.0 if mode == "rocket" else 34.0)

func _forward_endpoint(origin: Vector3, aim: Vector3) -> Vector3:
	# A gate can already be beyond the last selected statue/target. Such an aim
	# must never turn cosmetic fire backwards toward the formation.
	if aim.z >= origin.z - 0.05:
		return Vector3(origin.x, aim.y, origin.z - 35.0)
	return aim

func _write(origin: Vector3, direction: Vector3, mode: String, tier: int, born: float, distance: float, opacity: float) -> void:
	var length := 1.7 if tier == 0 else 3.6
	var width := 0.15 if tier == 0 else 0.24
	if mode == "rocket":
		length = 1.0
		width = 0.50
	elif mode == "rail":
		length = 5.0
		width = 0.22
	elif mode == "scatter":
		length = 1.45
		width = 0.20
	# Fixed transform axes encode width and travel direction; the shader derives
	# a camera-facing transverse axis every frame without touching this transform.
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT
	var transform := Transform3D(Basis(side * width, direction, side.cross(direction) * length), origin)
	var color := Campaign.weapon_color(mode, clampi(tier, 0, 3))
	color.a = opacity
	var mm := batch.multimesh
	mm.set_instance_transform(_cursor, transform)
	mm.set_instance_color(_cursor, color)
	# Split time preserves sub-millisecond phase on Compatibility's half-float
	# instance channels throughout a multi-minute campaign. No modulo wrap can
	# resurrect expired slots. Tail length is encoded in transform axis Z.
	var whole_seconds := floorf(born)
	mm.set_instance_custom_data(_cursor, Color(whole_seconds, born - whole_seconds, _speed(mode), minf(65.0, distance)))
	_cursor = (_cursor + 1) % budget
	_written = mini(_written + 1, budget)
	mm.visible_instance_count = _written
	total_emitted += 1

func warm_proxy() -> MultiMeshInstance3D:
	# Caller adds this below the floor but inside the camera frustum for two draws.
	# Uses the exact material and both instance channels used by the real spray.
	var proxy := MultiMeshInstance3D.new()
	var mm := _make_multimesh(1)
	mm.set_instance_transform(0, Transform3D(Basis(Vector3.RIGHT * 0.2, Vector3.FORWARD, Vector3.UP * 0.3), Vector3.ZERO))
	mm.set_instance_color(0, Color.CYAN)
	var born := _clock - 0.015
	var whole_seconds := floorf(born)
	mm.set_instance_custom_data(0, Color(whole_seconds, born - whole_seconds, 34.0, 10.0))
	proxy.multimesh = mm
	proxy.material_override = material
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return proxy
