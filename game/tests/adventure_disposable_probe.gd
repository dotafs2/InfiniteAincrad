extends SceneTree

const Adventure = preload("res://core/adventure_state.gd")
const TownActions = preload("res://core/town_actions.gd")

var _source := ""
var _out := ""
var checks := 0
var failures := 0

func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with("--town-save="): _source = raw.trim_prefix("--town-save=")
		elif raw.begins_with("--adventure-save="): _out = raw.trim_prefix("--adventure-save=")
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func run() -> void:
	check(not _source.is_empty() and not _out.is_empty(), "probe paths supplied")
	var town := TownActions.new()
	check(town.load_from(_source).ok, "seq323 disposable copy loads through the production validator")
	var town_snapshot: Dictionary = town.snapshot()
	var adventure := Adventure.new()
	var migrated: Dictionary = adventure.create_from_town_snapshot(town_snapshot)
	var ids: Array = migrated.residents.keys()
	ids.sort()
	check(ids.size() == 10, "all ten stable residents migrate into the isolated adventure sidecar")
	check(migrated.migration.combat_authority == "undefined_until_host_seed",
		"migration preserves undefined combat authority instead of inventing stats")
	check(migrated.loot_receipts.is_empty() and migrated.encounters.is_empty(),
		"migration creates no free encounter or loot")
	var actor := str(ids[0])
	check(adventure.set_committed_job(actor, true, "probe-job-hold").ok,
		"probe can represent an existing committed town job")
	check(adventure.enter_wilderness(actor, "probe-entry-blocked").code == "committed_job_must_finish_or_reject",
		"danger entry refuses a committed job")
	check(adventure.set_committed_job(actor, false, "probe-job-release").ok,
		"probe host closes the copied job explicitly")
	check(adventure.enter_wilderness(actor, "probe-enter-wilderness").ok,
		"copied resident enters only through an explicit physical-arrival receipt")
	check(adventure.open_floor_one_gate("probe-open-gate").ok and
		adventure.enter_labyrinth(actor, "probe-enter-labyrinth").ok,
		"copied resident reaches the bounded labyrinth transition")
	check(adventure.attack(actor, "missing:encounter", "probe-unknown-attack").code == "encounter_missing",
		"undefined encounter data is closed and refuses combat")
	check(adventure.flee(actor, "probe-flee").ok and adventure.snapshot().residents[actor].zone == "town",
		"copied resident returns physically to the last safe zone")
	check(adventure.save_to(_out).ok, "disposable adventure sidecar saves")
	var bytes := FileAccess.get_file_as_bytes(_out)
	var restored := Adventure.new()
	check(restored.load_from(_out).ok, "disposable adventure sidecar cold-loads")
	check(restored.snapshot() == JSON.parse_string(JSON.stringify(adventure.snapshot())),
		"migration, receipts and undefined authority survive exact cold restore")
	check(FileAccess.get_file_as_bytes(_out) == bytes, "cold read does not rewrite the sidecar")
	print(JSON.stringify({"suite": "adventure_disposable_probe", "checks": checks, "failures": failures,
		"resident_count": ids.size(), "actor_id": actor, "source_seq": town_snapshot.life.seq,
		"canonical_world_touched": false, "combat_authority": migrated.migration.combat_authority,
		"status": "disposable_probe_ready_for_effect_feedback"}))
	quit(0 if failures == 0 else 1)
