extends SceneTree

const Adventure = preload("res://core/adventure_state.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func run() -> void:
	var adventure := Adventure.new()
	adventure.create_fixture()
	check(adventure.open_floor_one_gate("").code == "invalid_command_id",
		"empty command IDs are rejected")
	check(adventure.open_floor_one_gate("bad/id").code == "invalid_command_id",
		"malformed command IDs are rejected")
	check(adventure.snapshot().commands.is_empty() and not adventure.snapshot().floor_one_gate_open,
		"invalid commands create no state or cached result")

	var first_gate: Dictionary = adventure.open_floor_one_gate("gate:first")
	check(first_gate.ok and first_gate.code == "gate_opened", "first gate command opens the gate")
	var replay_gate: Dictionary = adventure.open_floor_one_gate("gate:first")
	check(replay_gate.duplicate and replay_gate.receipt_id == first_gate.receipt_id,
		"same gate command returns its original receipt")
	var second_gate: Dictionary = adventure.open_floor_one_gate("gate:second")
	check(second_gate.ok and second_gate.code == "gate_already_open" and not second_gate.has("duplicate"),
		"opening an already-open gate with a fresh command returns a real receipt")
	check(adventure.snapshot().receipts.size() == 2,
		"gate receipts are recorded once per unique command")

	var job_set: Dictionary = adventure.set_committed_job("fixture:adventurer", true, "job:bound")
	check(job_set.ok, "a new host command applies")
	var after_job: Dictionary = adventure.snapshot()
	var matching_replay: Dictionary = adventure.set_committed_job("fixture:adventurer", true, "job:bound")
	check(matching_replay.duplicate and matching_replay.code == job_set.code,
		"matching command replay returns the original result")
	check(adventure.set_committed_job("fixture:adventurer", false, "job:bound").code == "command_conflict",
		"same ID with changed parameters is a command conflict")
	check(adventure.set_committed_job("fixture:guard", true, "job:bound").code == "command_conflict",
		"same ID with a different actor is a command conflict")
	check(adventure.open_floor_one_gate("job:bound").code == "command_conflict",
		"same ID with a different action is a command conflict")
	check(adventure.snapshot().residents["fixture:adventurer"].get("committed_job", false) and
		adventure.snapshot().residents["fixture:guard"].get("committed_job", false) == false,
		"conflicting retries have no state effect")
	check(adventure.snapshot() == after_job,
		"matching and conflicting retries leave the complete state unchanged")

	var save_path := "user://adventure-authority-%d.json" % Time.get_ticks_usec()
	check(adventure.save_to(save_path).ok, "authority state saves for cold-replay check")
	var restored := Adventure.new()
	check(restored.load_from(save_path).ok, "authority state cold-loads")
	var restored_before: Dictionary = restored.snapshot()
	var restored_replay: Dictionary = restored.set_committed_job("fixture:adventurer", true, "job:bound")
	check(restored_replay.duplicate and restored_replay.code == job_set.code,
		"matching replay after cold restore returns original result")
	check(restored.set_committed_job("fixture:adventurer", false, "job:bound").code == "command_conflict",
		"conflicting replay after cold restore is refused")
	check(restored.snapshot() == restored_before,
		"replays after cold restore do not mutate persisted state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var safe_zone := Adventure.new()
	safe_zone.create_fixture()
	safe_zone._state.encounters["fixture:wolf"].zone = "town"
	var safe_zone_before: Dictionary = safe_zone.snapshot()
	var town_attack: Dictionary = safe_zone.encounter_attack("fixture:wolf", "fixture:guard", "counter:town")
	check(not town_attack.ok and town_attack.code == "same_danger_zone_required",
		"encounter attacks cannot damage residents in a safe zone")
	check(safe_zone.snapshot().residents["fixture:guard"].hp == safe_zone_before.residents["fixture:guard"].hp and
		safe_zone.snapshot().residents["fixture:guard"].status == safe_zone_before.residents["fixture:guard"].status,
		"safe-zone rejection leaves resident combat state unchanged")

	var hidden := Adventure.new()
	hidden.create_fixture()
	hidden._state.residents["fixture:guard"].zone = "labyrinth"
	hidden._state.encounters["fixture:wolf"].visible = false
	var hidden_before: Dictionary = hidden.snapshot()
	var hidden_attack: Dictionary = hidden.encounter_attack("fixture:wolf", "fixture:guard", "counter:hidden")
	check(not hidden_attack.ok and hidden_attack.code == "target_not_visible",
		"an invisible encounter cannot attack a resident")
	check(hidden.snapshot().residents["fixture:guard"].hp == hidden_before.residents["fixture:guard"].hp,
		"invisible-target rejection leaves HP unchanged")

	var defeated := Adventure.new()
	defeated.create_fixture()
	defeated._state.residents["fixture:guard"].zone = "labyrinth"
	defeated._state.residents["fixture:guard"].status = "defeated"
	var defeated_attack: Dictionary = defeated.encounter_attack("fixture:wolf", "fixture:guard", "counter:defeated")
	check(not defeated_attack.ok and defeated_attack.code == "encounter_target_not_attackable",
		"a defeated resident cannot be attacked again")

	var migrated := Adventure.new()
	migrated.create_from_town_snapshot({"residents": [{"stable_id": "resident:unknown"}]})
	migrated._state.residents["resident:unknown"].zone = "labyrinth"
	migrated._state.encounters["fixture:wolf"] = {
		"id": "fixture:wolf", "zone": "labyrinth", "hp": 6, "max_hp": 6,
		"attack_power": 3, "defense_power": 1, "status": "ready", "visible": true
	}
	var undefined_before: Dictionary = migrated.snapshot()
	var undefined_attack: Dictionary = migrated.encounter_attack("fixture:wolf", "resident:unknown", "counter:undefined")
	check(not undefined_attack.ok and undefined_attack.code == "combat_values_undefined",
		"encounter attack refuses undefined resident combat values")
	check(migrated.snapshot().residents["resident:unknown"].hp == undefined_before.residents["resident:unknown"].hp and
		migrated.snapshot().residents["resident:unknown"].status == "ready",
		"undefined combat values cannot silently defeat a migrated resident")

	print(JSON.stringify({"suite": "adventure_authority_acceptance", "checks": checks,
		"failures": failures, "paid_calls": 0, "status": "authority_regressions_covered"}))
	quit(0 if failures == 0 else 1)
