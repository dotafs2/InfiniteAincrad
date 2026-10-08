extends SceneTree
## Real selection/settlement integration and isolated migration files. This
## suite deliberately does not accept the opt-in later-world fixture flag.
const Game = preload("res://fidelity/game.gd")
const Progression = preload("res://fidelity/map_progression.gd")
const Growth = preload("res://fidelity/hole.gd")
class FaultySaveGame:
	extends "res://fidelity/game.gd"
	var fail_saves := false
	func save_player_progress() -> bool:
		return false if fail_saves else super.save_player_progress()

var checks := 0
var failures: Array[String] = []
var paths: Array[String] = []
var game: Node3D
var metrics: Dictionary = {}
var base := "/tmp/hole-feast-map-unlocks-%d" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func path(label: String) -> String:
	var result := base + "-" + label + ".cfg"
	for suffix in ["", ".tmp", ".pre-coins.cfg"]:
		paths.append(result + suffix)
	return result

func cold_load(saved_path: String) -> Node3D:
	var owner := Game.new()
	owner.test_progress_path = saved_path
	check(owner.load_player_progress(), "Isolated profile restores: " + saved_path.get_file())
	return owner

func write_legacy(label: String, selected: String, best: Variant, receipts: Variant, schema := 0, unlocked: Variant = [], completed: Variant = {}) -> String:
	var saved_path := path(label)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "skin_schema", 3)
	cfg.set_value("progress", "map", selected)
	cfg.set_value("progress", "best_scores", best)
	cfg.set_value("progress", "coins", 321)
	cfg.set_value("progress", "gems", 17)
	cfg.set_value("progress", "completed_runs", 12)
	cfg.set_value("progress", "stage", 13)
	cfg.set_value("progress", "owned_skin_ids", ["tide", "core_shell"])
	cfg.set_value("progress", "selected_skin_id", "core_shell")
	cfg.set_value("progress", "map_unlock_schema", schema)
	cfg.set_value("progress", "unlocked_map_ids", unlocked)
	cfg.set_value("progress", "map_completed_best_scores", completed)
	cfg.set_value("audio", "music_enabled", false)
	cfg.set_value("rewards", "rounds", receipts)
	cfg.set_value("rewards", "purchases", {"legacy-diamond":"sink_city.diamonds_100"})
	cfg.set_value("custom", "preserve", "not owned by this feature")
	check(cfg.save(saved_path) == OK, "Legacy fixture writes atomically isolated data: " + label)
	return saved_path

func inspect_migration() -> void:
	for id in ["food", "toys", "frost"]:
		var scores := {id:1}
		var saved_path := write_legacy("played-" + id, id, scores, {})
		var owner := cold_load(saved_path)
		var expected := Progression.clean_ids([id])
		check(owner.unlocked_map_ids == expected and owner.selected_map == id, id + ": positive legacy best preserves this map and its earlier path")
		check(owner.map_completed_best_scores[id] == 0, id + ": migration does not invent a completed round from a general best")
		check(owner.coins == 321 and owner.gems == 17 and owner.completed_runs == 12 and owner.stage == 13, id + ": currency and existing aggregate progress remain identical")
		check(owner.skin_unlocked("core_shell") and owner.selected_skin_id == "core_shell" and not owner.music_enabled, id + ": ownership, equipment and preferences remain")
		check(owner.redeemed_transactions.has("legacy-diamond"), id + ": transaction history remains")
		check(owner.save_player_progress(), id + ": migrated entitlement persists")
		owner.free()
		owner = cold_load(saved_path)
		check(owner.unlocked_map_ids == expected, id + ": migration is stable after cold reload")
		var cfg := ConfigFile.new()
		cfg.load(saved_path)
		check(cfg.get_value("custom", "preserve", "") == "not owned by this feature", id + ": unrelated config sections survive")
		check(cfg.get_value("progress", "map_unlock_schema", 0) == Progression.SCHEMA, id + ": saved entitlement schema is explicit")
		owner.free()
	var preview_path := write_legacy("preview-only", "frost", {}, {})
	var preview := cold_load(preview_path)
	check(preview.unlocked_map_ids == ["city"] and preview.selected_map == "city", "Selecting an old preview and aggregate runs do not fabricate played-world access")
	preview.free()
	var zero_receipt := {"played":{"id":"played", "map":"toys", "base_coins":0, "settled":true, "score":0}}
	var receipt_path := write_legacy("zero-score-played", "toys", {}, zero_receipt)
	var played := cold_load(receipt_path)
	check(played.map_unlocked("toys") and not played.map_unlocked("frost"), "A valid settled zero-score legacy round proves map use without proving score completion")
	check(played.map_completed_best_scores.toys == 0 and played.reward_receipts.size() == 1, "Legacy zero-score receipt remains intact without fabricated completion")
	played.free()
	var complete_receipts := {"qualified":{"id":"qualified", "map":"food", "base_coins":20, "settled":true, "completion_credited":true, "score":200}}
	var complete_path := write_legacy("completed-evidence", "food", {}, complete_receipts)
	var completed := cold_load(complete_path)
	check(completed.map_unlocked("toys") and completed.map_completed_best_scores.food == 200, "An explicitly completed settled legacy score can qualify the next world")
	completed.free()
	var invalid_receipts := {"unsettled":{"id":"unsettled", "map":"frost", "base_coins":0, "settled":false},
		"wrong":{"id":"another-id", "map":"toys", "base_coins":0, "settled":true}}
	var invalid_path := write_legacy("invalid-evidence", "animals", {}, invalid_receipts)
	var invalid := cold_load(invalid_path)
	check(invalid.unlocked_map_ids == ["city"] and invalid.selected_map == "city", "Unsettled, mismatched and future-map records do not grant access")
	invalid.free()
	var schema_path := write_legacy("current-schema", "frost", {"frost":999}, {}, 1, ["city", "animals", "city", "invalid"], {})
	var current := cold_load(schema_path)
	check(current.unlocked_map_ids == ["city"] and current.selected_map == "city", "Current-schema profiles ignore unknown IDs and cannot repeat permissive legacy inference")
	check(not current.map_unlocked("animals") and not current.map_unlock_status("stars").available, "Unbuilt worlds remain unavailable")
	current.free()
	var future_path := write_legacy("future-schema", "food", {}, {}, 9, ["food"], {})
	var future := cold_load(future_path)
	check(future.map_unlocked("food") and future.map_unlock_schema == 9 and future.save_player_progress(), "Known future-schema entitlements survive without downgrading their schema")
	future.free()

func quiet_world() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	game.city.process_mode = Node.PROCESS_MODE_DISABLED
	for hole in game.holes:
		hole.enabled = false
		hole.set_physics_process(false)

func start_fixture(id: String, score: int) -> void:
	check(game.map_unlocked(id), "Controlled round fixture starts only in an earned world: " + id)
	game.selected_map = id
	game.start_level()
	game.begin_play()
	quiet_world()
	set_fixture_score(score)

func set_fixture_score(score: int) -> void:
	game.player.score = score
	game.player.level = Growth.level_for_score(score)
	game.player.radius = Growth.radius_for_level(game.player.level)
	game.player._sync_shape()

func expire() -> void:
	game.remaining = .01
	game._physics_process(.02)

func inspect_settlement() -> void:
	game = FaultySaveGame.new()
	game.test_progress_path = path("integration")
	root.add_child(game)
	check(game.available_map_ids() == ["city", "food", "toys", "frost"], "Available map IDs exclude unfinished future worlds")
	check(game.unlocked_map_ids == ["city"] and game.selected_map == "city", "Plain test mode starts with only City, like a new player")
	check(game.map_unlock_status("toys").condition == "Score 200 in Snack Garden" and game.map_unlock_status("frost").target == 300, "Short English gate conditions expose exact requirements")
	var before_audio: String = game.audio.current_map
	game.select_map("food")
	check(game.selected_map == "city" and game.audio.current_map == before_audio and not is_instance_valid(game.world), "A locked selection cannot change audio or start a world")
	game.selected_map = "frost"
	game.start_level()
	check(game.selected_map == "city" and game.phase == "title" and not is_instance_valid(game.world), "Launch guard rejects a direct locked ID before constructing gameplay")
	game.selected_map = "animals"
	game.start_level()
	check(game.selected_map == "city" and not is_instance_valid(game.world), "Launch guard also rejects an unavailable future ID")
	start_fixture("city", 1000)
	game.finish("eaten")
	check(not game.map_unlocked("food") and game.map_completed_best_scores.city == 0, "A high-score eaten result does not count as successful City completion")
	var lost := cold_load(game.test_progress_path)
	check(not lost.map_unlocked("food") and lost.best_scores.city == 1000, "Current-schema cold load cannot turn a failed high score into completion")
	lost.free()
	start_fixture("city", 0)
	expire()
	check(not game.map_unlocked("food") and game.completed_runs == 0, "Idle zero-score expiry earns no completion unlock")
	start_fixture("city", 1)
	expire()
	check(game.map_unlocked("food") and not game.map_unlocked("toys") and game.completed_runs == 1, "One positive City completion unlocks exactly the next map")
	var wallet: int = game.coins
	var serial: int = game.round_serial
	game.finish("complete")
	check(game.completed_runs == 1 and game.round_serial == serial and game.coins == wallet, "Repeated completion cannot duplicate a run or reward")
	game.back_home()
	await process_frame
	game.fail_saves = true
	game.select_map("food")
	check(game.selected_map == "city" and game.audio.current_map == "city", "Failed world selection save restores the previous valid map and audio")
	game.fail_saves = false
	game.select_map("food")
	check(game.selected_map == "food", "Earned world selection succeeds after persistence recovers")
	start_fixture("food", 199)
	expire()
	check(not game.map_unlocked("toys") and game.map_completed_best_scores.food == 199 and game.map_unlock_status("toys").current == 199, "Food199 remains below the visible200-point boundary")
	var runs: int = game.completed_runs
	var receipt: String = game.round_receipt.id
	var same_world: Node3D = game.world
	wallet = game.coins
	var gems: int = game.gems
	check(game.request_round_extension_gems().ok, "Real existing continuation offer resumes the same completed round")
	check(game.world == same_world and game.remaining == 30.0 and game.gems == gems - game.EXTENSION_GEM_COST, "Continuation preserves world and charges only its existing price")
	set_fixture_score(200)
	expire()
	check(game.map_unlocked("toys") and not game.map_unlocked("frost") and game.map_completed_best_scores.food == 200, "A completed200-point Food continuation unlocks Toy Town")
	check(game.completed_runs == runs and game.round_receipt.id == receipt and game.coins == wallet + 1, "Unlock after continuation preserves once-only completion and incremental coin reward")
	start_fixture("toys", 299)
	game.finish("timeout")
	check(not game.map_unlocked("frost") and game.map_unlock_status("frost").current == 299, "Toy299 remains below the300-point threshold")
	start_fixture("toys", 300)
	game.fail_saves = true
	expire()
	check(game.map_unlocked("frost") and game.progress_dirty and game.map_completed_best_scores.toys == 300, "Successful play is retained in memory when the atomic save needs retry")
	var pending := cold_load(game.test_progress_path)
	check(not pending.map_unlocked("frost") and pending.map_completed_best_scores.toys == 299, "A failed save never claims the new unlock was already durable")
	pending.free()
	wallet = game.coins
	runs = game.completed_runs
	game.fail_saves = false
	check(game.save_player_progress(), "Retry persists the earned unlock without repeating the round")
	var saved := cold_load(game.test_progress_path)
	check(saved.map_unlocked("frost") and saved.coins == wallet and saved.completed_runs == runs, "The same unlock, wallet and completion count survive recovery and cold load")
	var owned: Array = saved.owned_skin_ids.duplicate()
	for index in 40:
		var id := "prune-%d" % index
		saved.reward_receipts[id] = {"id":id, "map":"city", "base_coins":1, "settled":true, "completion_credited":true, "score":10}
	saved._prune_reward_receipts()
	check(saved.reward_receipts.size() <= 32 and saved.map_unlocked("frost"), "Pruning old receipts never revokes a persisted world entitlement")
	check(saved.save_player_progress(), "Pruned receipts and monotonic access persist together")
	saved.free()
	saved = cold_load(game.test_progress_path)
	check(saved.unlocked_map_ids == game.available_map_ids() and saved.owned_skin_ids == owned and saved.coins == wallet, "Cold reload after pruning retains all earned worlds, skins and currency")
	metrics = {"unlocked":saved.unlocked_map_ids, "completed_best_scores":saved.map_completed_best_scores,
		"completed_runs":saved.completed_runs, "coins":saved.coins, "receipts_after_pruning":saved.reward_receipts.size()}
	saved.free()
	game.free()
	await process_frame

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--test") or OS.get_cmdline_user_args().has("--qa-unlocked-worlds"):
		push_error("Map unlock acceptance requires --test without --qa-unlocked-worlds")
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	inspect_migration()
	await inspect_settlement()
	var result := {"checks":checks, "failures":failures, "metrics":metrics,
		"scope":"Actual progression/selection/settlement API and isolated legacy/cold-save fixtures. Scores are explicit threshold fixtures, not normal-play pacing evidence. No real user save, advertising or purchase."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print("MAP_UNLOCK_ACCEPTANCE " + JSON.stringify(result))
	for value in paths:
		if FileAccess.file_exists(value):
			DirAccess.remove_absolute(value)
	quit(0 if failures.is_empty() else 1)
