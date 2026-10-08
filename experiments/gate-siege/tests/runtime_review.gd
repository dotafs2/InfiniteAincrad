extends SceneTree
## Independent integration checks. Run from the standalone project's root.
## Collision fixtures isolate geometry; full-step runs below keep real progression.
const Game = preload("res://scripts/game.gd")
var game: Node3D
var checks := 0
var failures: Array[String] = []
var notes: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		print("FAIL: ", description)

func packet(x: float, z: float, count: int = 1, power: float = 1.0, mask: int = 7) -> Dictionary:
	return {"pos": Vector3(x, 0.66, z), "power": power, "count": count, "width": 0.0, "mask": mask, "tier": 0}

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

func steer_world(x: float) -> void:
	var event: InputEvent
	if not game.dragging:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
	else:
		event = InputEventMouseMotion.new()
	event.position = game.camera.unproject_position(Vector3(x, 0, game.PLAYER_Z))
	game._unhandled_input(event)

func reset() -> void:
	game.restart_game()
	game.auto_demo = false
	game.audio_enabled = false

func step(seconds: float, delta: float = 1.0 / 30.0) -> void:
	var count := ceili(seconds / delta)
	for i in range(count):
		game._physics_process(delta)

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.audio_enabled = false
	await process_frame
	check(game.phase == "ready", "Fresh load waits for DEPLOY")
	key(KEY_SPACE)
	check(game.phase == "playing", "Space starts real gameplay")
	var old_front: float = game.crowd_front
	step(0.3)
	check(game.metrics.shots > 0 and not game.bullets.is_empty(), "Playing creates real projectile packets")
	check(game.crowd_front > old_front, "Enemies advance while firing")
	_test_input_and_pause()
	await _test_gui_input()
	_test_gates()
	_test_recruit()
	_test_collision_depth()
	_test_limits_and_terminal_states()
	await process_frame
	_test_natural_loss()
	await process_frame
	_test_natural_progression()
	await process_frame
	print("RUNTIME_REVIEW ", JSON.stringify({"checks":checks,"failures":failures,"notes":notes}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_input_and_pause() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.camera.unproject_position(Vector3(4.0, 0.5, game.PLAYER_Z))
	game._unhandled_input(click)
	check(game.dragging and game.target_x > 3, "Mouse press projects onto the player aiming plane")
	step(0.4)
	check(game.player_x > 1.0, "Steering changes actual player position")
	click.pressed = false
	game._unhandled_input(click)
	check(not game.dragging, "Mouse release ends drag")
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = game.camera.unproject_position(Vector3(-4.0, 0.5, game.PLAYER_Z))
	game._unhandled_input(touch)
	check(game.touch_id == 2 and game.target_x < -3, "First touch owns steering")
	var other := InputEventScreenDrag.new()
	other.index = 3
	other.position = Vector2(10000, 300)
	var target: float = game.target_x
	game._unhandled_input(other)
	check(game.target_x == target, "A second finger cannot steal aiming")
	key(KEY_P)
	check(game.phase == "paused" and not game.dragging and game.touch_id == -1, "Pause clears active pointer ownership")
	var before := {"elapsed":game.elapsed,"front":game.crowd_front,"shots":game.metrics.shots,"health":game.health}
	step(0.5)
	check(game.elapsed == before.elapsed and game.crowd_front == before.front and game.metrics.shots == before.shots and game.health == before.health, "Paused gameplay and shot clock remain frozen")
	key(KEY_P)
	step(0.1)
	check(game.phase == "playing" and game.elapsed > before.elapsed, "Resume advances the simulation")
	game._unhandled_input(touch)
	key(KEY_R)
	check(game.phase == "playing" and game.wave == 0 and game.tier == 0 and game.health == 100, "R restarts the active run")
	check(not game.dragging and game.touch_id == -1, "Restart clears held touch and drag ownership")
	check(game.bullets.is_empty() and game.sparks.is_empty() and game.kills == 0, "Restart clears transient packets and run kills")
	check(game.metrics.shots == 0 and game.metrics.recruits == 0 and game.metrics.wins == 0 and game.metrics.losses == 0, "Restart resets per-run telemetry")
	game._aim(Vector2(-10000, 900))
	check(game.target_x >= -4.55 and game.target_x <= 4.55, "Offscreen aim is bounded to the runway")

func _test_gui_input() -> void:
	reset()
	game.hud.pause_button.visible = true
	game.hud.mute_button.visible = true
	await process_frame
	var previous_x: float = game.target_x
	var previous_audio: bool = game.audio_enabled
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(438, 40)
	press.global_position = press.position
	press.pressed = true
	root.push_input(press, true)
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release, true)
	await process_frame
	check(game.audio_enabled != previous_audio, "Routed viewport click actually activates the mute Button")
	check(game.target_x == previous_x and not game.dragging, "Clicking a HUD button cannot also steer gameplay")
	game.audio_enabled = false

func _test_gates() -> void:
	reset()
	game.gates[0].position.x = 0
	game.gates[1].position.x = 4.0
	game.gates[2].position.x = 0
	game.bullets.clear(); game.bullets.append(packet(0, game.GATE_Z[0] + 0.1, 1, 1.0, 0))
	game._step_bullets(0.01)
	check(game.bullets.size() == 1 and game.bullets[0].count == 5, "Crossing active times-five creates a five-shot volley")
	game._step_bullets(0.01)
	check(game.bullets[0].count == 5, "A packet multiplies at a gate only once")
	game.bullets[0].pos.z = game.GATE_Z[2] + 0.1
	game._step_bullets(0.01)
	check(game.bullets.size() == 1 and game.bullets[0].count == 10, "Actual times-five then times-two crossing yields ten shots")
	game.gates[1].position.x = 0
	var armor_before: float = game.gold_hp
	game.bullets.clear(); game.bullets.append(packet(0, game.GATE_Z[1] + 0.1, 5, 1.0, 1))
	game._step_bullets(0.01)
	check(game.gold_hp == armor_before - 5 and game.bullets.is_empty(), "Armored gate absorbs shots and loses real shot damage")
	game.gold_hp = 0
	game.bullets.clear(); game.bullets.append(packet(0, game.GATE_Z[1] + 0.1, 5, 1.0, 1))
	game._step_bullets(0.01)
	check(game.bullets.size() == 1 and game.bullets[0].count == 4995, "Uncovered times-999 gate multiplies the real packet")
	game.bullets.clear(); game.bullets.append(packet(-4, game.GATE_Z[0] + 0.1, 1, 1.0, 0))
	game._step_bullets(0.01)
	check(game.bullets.size() == 1 and game.bullets[0].count == 1, "Missing a gate does not multiply shots")

func _test_recruit() -> void:
	reset()
	game.recruit_remaining = 1
	var count_before: int = game.metrics.recruits
	game.bullets.clear(); game.bullets.append(packet(3.2, game.GATE_Z[2] - 0.5))
	game._step_bullets(0.01)
	check(game.tier == 1 and game.metrics.recruits == count_before + 1, "A real statue hit unlocks the next hero once")
	check(game.bullets.is_empty(), "Statue consumes the upgrade-triggering projectile")
	check(game.recruiting and is_instance_valid(game.recruit_flight) and not game.statue.visible, "Unlock starts an actual airborne transfer and empties the pedestal")
	var old_model: Node3D = game.player_model
	game.bullets.append(packet(3.2, game.GATE_Z[2] - 0.5, 9990))
	game._step_bullets(0.01)
	check(game.tier == 1 and game.metrics.recruits == count_before + 1, "Additional packets cannot unlock another hero during airborne transfer")
	step(0.1)
	check(game.metrics.recruits == count_before + 1, "Upgrade does not repeat on following frame")
	check(game.recruit_remaining == game.RECRUIT_COSTS[1], "The next statue starts with its own full counter")
	var remaining: int = game.recruit_remaining
	game.bullets.clear()
	game.shot_clock = 10.0
	game.target_x = -4
	step(0.5)
	check(game.recruit_remaining == remaining, "Statue progress persists without timer-based decay")
	game.toggle_pause()
	var clock_before: float = game.flight_clock
	step(0.3)
	check(game.flight_clock == clock_before, "Pause freezes the visible recruitment flight")
	game.toggle_pause()
	step(0.3)
	check(not game.recruiting and game.recruit_flight == null and game.player_model != old_model, "Landing replaces the player model and frees the flight actor")
	check(game.message == "LEVEL UP" and game.statue.visible, "Landing exposes the next statue and emits level-up feedback")
	game.recruit_remaining = 1
	game.bullets.append(packet(3.2, game.GATE_Z[2] - 0.5))
	game._step_bullets(0.01)
	check(game.recruiting, "A later hero also uses the transfer animation")
	key(KEY_R)
	check(not game.recruiting and game.recruit_flight == null and game.tier == 0, "Restart during transfer discards the flight and restores the recruit")

func _test_collision_depth() -> void:
	reset()
	for c in game.crowd:
		c.alive = false
	var rear: Dictionary = game.crowd[18 * 10]
	rear.alive = true
	rear.x = -2.0
	game.crowd_front = -15.5
	var rear_z: float = game.crowd_front - rear.z
	game.bullets.clear(); game.bullets.append(packet(-2, -15.3))
	game._step_bullets(0.02)
	check(rear.alive, "Projectile crossing an empty front rank cannot remotely kill a rear rank")
	check(game.bullets.size() == 1, "Projectile keeps traveling through a cleared front line")
	game.bullets.clear(); game.bullets.append(packet(-2, rear_z + 0.2))
	game._step_bullets(0.02)
	check(not rear.alive, "Projectile kills a rear troop only when it reaches that troop")
	reset()
	for c in game.crowd:
		c.alive = false
	var behind: Dictionary = game.crowd[18 * 20]
	behind.alive = true
	behind.x = -2.0
	game.boss_z = -17.0
	game.boss.position.z = game.boss_z
	game.crowd_front = -15.5
	var hp: float = game.boss_hp
	game.bullets.clear(); game.bullets.append(packet(-2, -15.8))
	game._step_bullets(0.02)
	check(game.boss_hp < hp and behind.alive, "An exposed boss shields troops that are physically behind it")
	reset()
	for c in game.crowd:
		c.alive = false
	behind = game.crowd[0]
	behind.alive = true
	behind.x = -2.0
	behind.z = 0.65
	game.crowd_front = -15.5
	game.boss_z = -17.0
	hp = game.boss_hp
	game.bullets.clear(); game.bullets.append(packet(-2, -15.8))
	game._step_bullets(0.02)
	check(game.boss_hp < hp and behind.alive, "The nearer boss wins when boss and rear troop are crossed in one step")
	reset()
	for c in game.crowd:
		c.alive = false
	game.crowd[0].alive = true
	game.crowd[0].x = -2.0
	game.crowd[18 * 8].alive = true
	game.crowd[18 * 8].x = -2.0
	game.bullets.clear(); game.bullets.append(packet(-2, game.crowd_front + 0.2, 100))
	game._step_bullets(0.02)
	check(not game.crowd[0].alive and game.crowd[18 * 8].alive and not game.bullets.is_empty(), "Overpowered volley keeps residual damage without teleporting it to the next rank")
	game._step_bullets(0.2)
	check(not game.crowd[18 * 8].alive, "Residual damage hits the rear rank after real projectile travel")

func _test_limits_and_terminal_states() -> void:
	reset()
	game._emit(Vector3.ZERO, Color.WHITE, 99999, 0.1)
	check(game.sparks.size() <= 1400, "Spark pool is bounded under extreme impact")
	game._step_effects(1.0)
	check(game.sparks.is_empty(), "Expired effects are removed")
	for i in range(5): game._damage_crowd(0, 100, 999999, 100, -100)
	game._process(0)
	check(game.kill_flashes.size() <= 256 and game.death_mm.multimesh.visible_instance_count <= 256, "Simultaneous troop defeat effects remain within the allocated pool")
	game._step_effects(1.0)
	check(game.kill_flashes.is_empty(), "Troop defeat effects expire instead of accumulating per kill")
	for i in range(320):
		game.bullets.append(packet(0, -6, 9990))
	game._process(0)
	check(game.bullet_mm.multimesh.visible_instance_count <= game.CAPACITY, "Visible projectile instances stay within allocated capacity")
	game.bullets.clear()
	game.wave = 2
	for c in game.crowd:
		c.alive = false
	game.boss_hp = 1
	game.boss_z = -17
	game.bullets.clear(); game.bullets.append(packet(-2, -15.8))
	step(0.02)
	check(game.phase == "playing" and game.boss_dead and game.boss_death_time > 0, "Killing the last boss preserves its death animation before results")
	step(float(game.boss_death_time) + 0.05)
	check(game.phase == "won" and game.metrics.wins == 1, "Final-wave real projectile kill reaches victory exactly once")
	step(0.2)
	check(game.metrics.wins == 1, "Victory freezes terminal simulation")
	key(KEY_SPACE)
	check(game.phase == "playing" and game.wave == 0 and game.health == 100, "Space restarts from the result screen")
	reset()
	game.wave = 2
	game.boss_dead = true
	game.health = 1
	game.crowd_front = game.PLAYER_Z - 1.49
	for c in game.crowd:
		c.alive = false
	game.crowd[0].alive = true
	game.shot_clock = 10
	step(0.02)
	check(game.phase == "lost" and game.metrics.wins == 0 and game.metrics.losses == 1, "Fatal final troop breach cannot become zero-health victory")

func _test_natural_loss() -> void:
	reset()
	steer_world(4.55)
	var frames := 0
	while game.phase == "playing" and frames < 8800:
		game._physics_process(1.0 / 60.0)
		frames += 1
	check(game.phase == "lost", "Unattended right-side play naturally reaches loss from a fresh run")
	notes.append("Natural loss: %s at %.2fs, health %.0f, breaches %d." % [game.phase, game.elapsed, game.health, game.metrics.breaches])

func _test_natural_progression() -> void:
	reset()
	var frames := 0
	var upgrades := 0
	while game.phase == "playing" and frames < 21600:
		# Actual steering only. No damage, health, progression or enemies are edited.
		if game.tier < 2:
			steer_world(3.2)
		elif game.gold_hp > 0:
			# Lead a shot to the armored gate by its travel time.
			steer_world(2.95 * cos((game.elapsed + (game.PLAYER_Z - 0.6 - game.GATE_Z[1]) / 32.0) * TAU / 5.3))
		elif game.boss_dead or game._alive_crowd() < 100:
			# Clean up the far columns that a centered multiplier fan cannot reach.
			var nearest: Dictionary = {}
			for c in game.crowd:
				if c.alive and (nearest.is_empty() or c.z < nearest.z):
					nearest = c
			if not nearest.is_empty(): steer_world(clampf(nearest.x, -4.55, 4.55))
		else:
			steer_world(2.95 * cos((game.elapsed + (game.PLAYER_Z - 0.6 - game.GATE_Z[1]) / 32.0) * TAU / 5.3))
		game._physics_process(1.0 / 60.0)
		frames += 1
		upgrades = maxi(upgrades, game.tier)
	check(upgrades >= 2, "Normal firing and independent steering can naturally unlock two heroes")
	check(game.phase == "won" and game.health > 0, "Normal pointer input naturally wins all three waves at60Hz")
	notes.append("Natural steering trial at60Hz: %s at %.2fs, wave %d, tier %d, kills %d, health %.0f, gold %.0f, boss %.0f, peak packets %d." % [game.phase, game.elapsed, game.wave + 1, game.tier, game.kills, game.health, game.gold_hp, game.boss_hp, game.metrics.peak_packets])
	if game.phase != "won":
		notes.append("This steering policy did not demonstrate an unmodified full-game victory; final-state fixture is not proof of ordinary win reachability.")
