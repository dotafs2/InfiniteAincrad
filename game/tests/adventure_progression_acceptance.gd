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
	var initial := adventure.create_fixture()
	check(initial.floor == 1, "fixture starts on floor one")
	check(not adventure.attack("fixture:adventurer", "fixture:guard", "town-attack").ok,
		"town is a safe zone and refuses combat")
	check(adventure.set_committed_job("fixture:adventurer", true, "job-hold").ok and
		adventure.enter_wilderness("fixture:adventurer", "blocked-entry").code == "committed_job_must_finish_or_reject",
		"danger-zone entry cannot abandon a committed job")
	check(adventure.set_committed_job("fixture:adventurer", false, "job-release").ok,
		"host closes the committed job before departure")
	check(adventure.enter_wilderness("fixture:adventurer", "enter-wilderness").ok,
		"resident explicitly enters wilderness")
	check(adventure.open_floor_one_gate("open-gate").ok, "host opens a bounded floor-one gate")
	check(adventure.enter_labyrinth("fixture:adventurer", "enter-labyrinth").ok,
		"resident physically enters labyrinth")
	check(adventure.enter_wilderness("fixture:guard", "guard-wilderness").ok,
		"second resident enters wilderness")
	check(adventure.enter_labyrinth("fixture:guard", "guard-labyrinth").ok,
		"second resident enters labyrinth")
	check(adventure.guard("fixture:guard", "guard-action").ok, "guard action is offered in danger zone")
	var first_hit := adventure.attack("fixture:adventurer", "fixture:wolf", "attack-1")
	check(first_hit.ok and first_hit.damage == 3 and first_hit.target_hp == 3,
		"damage is deterministic and world-owned")
	var duplicate := adventure.attack("fixture:adventurer", "fixture:wolf", "attack-1")
	check(duplicate.duplicate and duplicate.target_hp == 3, "duplicate command is idempotent")
	check(adventure.attack("fixture:adventurer", "fixture:guard", "resident-attack").code == "hostile_encounter_required",
		"resident-versus-resident damage is refused in v1")
	for index in 10:
		adventure.encounter_attack("fixture:wolf", "fixture:guard", "wolf-attack-%d" % index)
	check(adventure.snapshot().residents["fixture:guard"].status == "defeated",
		"defeat remains in the danger zone until an explicit retreat")
	check(adventure.retreat_after_defeat("fixture:guard", "guard-retreat").ok,
		"defeat retreat requires a separate physical action")
	check(adventure.recover("fixture:guard", "guard-recover").ok and
		adventure.snapshot().residents["fixture:guard"].hp == 1,
		"recovery is explicit and restores only minimum HP")
	check(adventure.flee("fixture:adventurer", "flee-1").ok, "flee requires a reachable route and returns to town")
	check(not adventure.flee("fixture:adventurer", "flee-2").ok, "town cannot flee")
	check(adventure.enter_wilderness("fixture:guard", "guard-wilderness-2").ok and
		adventure.enter_labyrinth("fixture:guard", "guard-labyrinth-2").ok,
		"recovered resident can make a new physical expedition")
	check(adventure.enter_floor_one_boss_arena("fixture:guard", "boss-before-clear", false, true).code == "labyrinth_clearance_required",
		"boss arena rejects missing clearance")
	check(adventure.enter_floor_one_boss_arena("fixture:guard", "enter-boss").ok,
		"boss arena requires labyrinth travel and physical arrival")
	check(adventure.challenge_floor_one_boss("fixture:guard", "challenge-boss").ok,
		"boss challenge is explicit")
	check(adventure.resolve_boss("boss-result", true).victory, "boss result is a durable victory receipt")
	check(adventure.snapshot().floor == 1, "boss victory does not implicitly unlock a floor")
	check(adventure.unlock_floor_two("unlock-floor-two", ["fixture:guard"]).ok,
		"floor unlock requires an explicit durable victory")
	check(adventure.snapshot().floor == 2, "floor two becomes explicit world state")
	var path := "user://adventure-progression-%d.json" % Time.get_ticks_usec()
	check(adventure.save_to(path).ok, "adventure state saves")
	var restored := Adventure.new()
	check(restored.load_from(path).ok, "adventure state reloads")
	check(restored.snapshot() == JSON.parse_string(JSON.stringify(adventure.snapshot())),
		"zone, combat, receipts, loot and floor state survive cold restore")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "adventure_progression", "checks": checks, "failures": failures,
		"paid_calls": 0, "status": "design_disposable_live_install_accepted"}))
	quit(0 if failures == 0 else 1)
