extends SceneTree
## Frostlight gameplay parity: real swallow admission, point credit and the
## shared round receipt path. This fixture never writes the user's save.

const Game = preload("res://fidelity/game.gd")

var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func wait_frames(count: int) -> void:
	for _index in count:
		await physics_frame

func find_body(city: Node, species: String) -> Node3D:
	for item in city.foods:
		if is_instance_valid(item) and str(item.get_meta("frost_species", "")) == species:
			return item
	return null

func swallow_target(game: Node, target: Node3D) -> Dictionary:
	var hole: Node3D = game.player
	var before_score: int = int(hole.score)
	var before_eaten: int = int(game.eaten)
	var points: int = int(target.points)
	hole.global_position = Vector3(target.global_position.x, 0.0, target.global_position.z)
	var admitted: bool = target.begin_swallow(hole)
	var consumed := false
	for _index in 180:
		if is_instance_valid(game.ground):
			game.ground.sync()
		await physics_frame
		if not is_instance_valid(target):
			consumed = true
			break
	if is_instance_valid(target):
		consumed = bool(target.consumed)
	return {
		"admitted": admitted,
		"consumed": consumed,
		"score_delta": int(hole.score) - before_score,
		"eaten_delta": int(game.eaten) - before_eaten,
		"points": points,
	}

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var game := Game.new()
	game.selected_map = "frost"
	game.test_progress_path = "/tmp/hole-feast-frostlight-gameplay-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	game.start_level()
	game.begin_play()
	await wait_frames(4)
	# Keep this fixture deterministic: the target is tested against the human
	# hole's real admission/physics path, without rival AI collecting unrelated
	# bodies during the observation window.
	for rival in game.holes:
		if rival != game.player:
			rival.enabled = false
			rival.set_physics_process(false)
	var city: Node = game.city
	var rock: Node3D = find_body(city, "ice_rock")
	var glacier: Node3D = find_body(city, "glacier_iceberg")
	check(rock != null and glacier != null, "Frostlight exposes both edible Blender species to the gameplay body list")
	if rock == null or glacier == null:
		game.free()
		quit(1)
		return
	# Remove unrelated collision/physics actors from this deterministic probe;
	# the production map still contains the full 856-body population.
	for item in city.foods:
		if is_instance_valid(item):
			if item == rock or item == glacier:
				continue
			item.collision_layer = 0
			item.collision_mask = 0
			item.set_physics_process(false)
			item.freeze = true
			item.footprint = 999.0
	for item in [rock, glacier]:
		item.collision_layer = 1
		item.collision_mask = 1
	check(int(rock.points) > 0 and int(glacier.points) > 0, "Edible Blender species carry positive rewards")
	# The player earns ordinary progression before attempting a large glacier.
	# This uses the same Hole.award path as swallowed toys; it does not mutate
	# the map's authored points or collider definitions.
	if not rock.can_fit(game.player):
		game.player.award(240)
	var rock_result: Dictionary = await swallow_target(game, rock)
	check(bool(rock_result.get("admitted", false)), "An in-range ice rock is admitted by the shared swallow gate")
	check(bool(rock_result.get("consumed", false)), "An admitted ice rock completes a real physics swallow")
	check(int(rock_result.get("score_delta", 0)) == int(rock_result.get("points", 0)), "Ice-rock score delta equals its authored points")
	check(int(rock_result.get("eaten_delta", 0)) == 1, "Ice-rock swallow increments the shared eaten counter once")
	# Grow through the normal score/radius function before swallowing a landmark.
	if not glacier.can_fit(game.player):
		game.player.award(2400)
	var glacier_result: Dictionary = await swallow_target(game, glacier)
	check(bool(glacier_result.get("admitted", false)), "A grown player is admitted to the glacier body")
	check(bool(glacier_result.get("consumed", false)), "An admitted glacier completes a real physics swallow")
	check(int(glacier_result.get("score_delta", 0)) == int(glacier_result.get("points", 0)), "Glacier score delta equals its authored points")
	check(int(glacier_result.get("eaten_delta", 0)) == 1, "Glacier swallow increments the shared eaten counter once")
	var scored := int(game.player.score)
	game.finish("timeout")
	check(int(game.round_receipt.get("score", -1)) == scored, "Frostlight round receipt records the actual player score")
	check(int(game.round_coins) == int(game.score_coin_reward(scored)), "Frostlight coins use the shared score-to-coin formula")
	metrics = {
		"rock": rock_result,
		"glacier": glacier_result,
		"score": scored,
		"coins": game.round_coins,
		"remaining": game.remaining,
		"scope": "Real Frostlight body admission and score receipt; no production save or SDK claim",
	}
	game.free()
	await process_frame
	var result := {"checks": checks, "failures": failures, "metrics": metrics}
	print("FROSTLIGHT_GAMEPLAY_PARITY " + JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(result, "\t") + "\n")
	quit(0 if failures.is_empty() else 1)
