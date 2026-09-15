extends SceneTree
## H86 capability self-test (resident request r5-resident-warm-food).
##
## Offline, local-rule only: no paid model call, no network, no editor, no asset import. It runs
## against a COPY of the real before-phase world save (tmp/r5-evidence/world-before.json, opened
## read-only), plus explicitly labelled host_move steps that stand for the host scene resolving a
## real capsule's collision. Every temporary result is written under the candidate tmp/ directory.
## Paths can be overridden with `-- --r5-tmp=<dir> --r5-world=<save>`.
##
## It checks the real mechanic, not a label: ration accounting, a distinct held item, later
## consumption of that item exactly once, real elapsed work at the resident's own work point, no
## teleport by the runtime, honesty of the arrival gate and of the blocked close, save/load
## durability of the new namespace (a mid-action cold restore makes no catch-up change and cannot
## duplicate), the freshness deadline, fail-closed validation of tampered saves, an untouched
## inherited option surface, and preserved identities, events and reply archive.

const Runtime = preload("res://experiments/r5_gm_runtime.gd")
const PlainTown = preload("res://core/town_places.gd")
const JsonCodec = preload("res://core/TownJsonCodec.cs")
const TownScene := preload("res://scenes/town_street.tscn")

const PREPARE := "warm:prepare"
const EAT_PREFIX := "warm:eat:"
const WORK_RANGE := 2.5
const FRESH_SECONDS := 3600.0
const SPRINT := "warm:test:"
const SCENE_TIME_SCALE := 4.0
const SCENE_WALL_BUDGET_MS := 150000

var failures := 0
var checks := 0
var tmp_dir := ""
var world_source := ""
var phase := "unit"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--r5-tmp="):
			tmp_dir = _resolve(arg.trim_prefix("--r5-tmp="))
		elif arg.begins_with("--r5-world="):
			world_source = _resolve(arg.trim_prefix("--r5-world="))
		elif arg.begins_with("--r5-phase="):
			phase = arg.trim_prefix("--r5-phase=")
	if tmp_dir.is_empty():
		tmp_dir = ProjectSettings.globalize_path("user://r5-warm-food-self-test")
	if world_source.is_empty():
		world_source = _resolve("tmp/r5-evidence/world-before.json")
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	run.call_deferred()

func _resolve(path: String) -> String:
	if path.is_empty() or path.is_absolute_path():
		return path
	var candidate_root: String = ProjectSettings.globalize_path("res://").path_join("..")
	return candidate_root.path_join(path).simplify_path()

func run() -> void:
	print(JSON.stringify({"suite": "r5_gm_capability", "phase": "start", "world": world_source,
		"world_readable": FileAccess.file_exists(world_source), "tmp": tmp_dir, "mode": phase}))
	if phase == "scene":
		if scene_assets_available():
			await part_real_scene_walk_and_work()
		else:
			## The playable scene needs the market's imported GLB scene, and importing assets is
			## outside this candidate's scope. The phase reports the skip instead of pretending to
			## have run; the same command does run the real scene wherever the imports exist.
			print(JSON.stringify({"suite": "r5_gm_capability", "phase": "scene_walk_and_work",
				"skipped": true, "reason": "imported market asset is not present in this candidate",
				"required": "res://assets/market/StartingTown_Market_CraftV5.glb",
				"note": "the unit phase covers the world rules; this phase covers the real capsule walking"}))
	else:
		part_baseline_and_compatibility()
		part_prepare_and_later_eat()
		part_mid_action_cold_restore()
		part_cooled_eat_after_the_freshness_window()
		part_arrival_gate_and_blocked_close()
		part_host_move_explicitly_labelled()
		part_tampered_saves_fail_closed()
	print(JSON.stringify({"suite": "r5_gm_capability", "mode": phase, "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)

func scene_assets_available() -> bool:
	## The playable town needs the market's IMPORTED scene. A source .glb without an import cache
	## (a code-only candidate checkout) cannot be used by the running game, and importing assets is
	## explicitly outside this candidate's scope, so the phase reports the skip instead of failing.
	if not ResourceLoader.exists("res://scenes/town_street.tscn"):
		return false
	var import_path := "res://assets/market/StartingTown_Market_CraftV5.glb.import"
	if not FileAccess.file_exists(import_path):
		return false
	for line in FileAccess.get_file_as_string(import_path).split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("path="):
			var imported: String = trimmed.trim_prefix("path=").strip_edges().trim_prefix("\"").trim_suffix("\"")
			return ResourceLoader.exists(imported)
	return false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func copy_file(source: String, target: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	var text := FileAccess.get_file_as_string(source)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

func decode_state(text: String) -> Variant:
	## The world's own codec, so a re-encoded tamper fixture keeps the exact numeric shapes the
	## runtime reads (an integer stays an integer, a float keeps its full precision).
	var codec = JsonCodec.new()
	var decoded: Variant = codec.Decode(text)
	codec.Release()
	return decoded

func encode_state(state: Dictionary) -> String:
	var codec = JsonCodec.new()
	var text: String = codec.Encode(state)
	codec.Release()
	return text

func fresh_town(name: String) -> Runtime:
	var path := tmp_dir.path_join(name)
	check(copy_file(world_source, path), "world copy written: " + name)
	var town := Runtime.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "world loads under the capability runtime: %s (%s)" % [name, str(loaded.get("code", ""))])
	return town

func pick(town, needs_food: bool, at_home: bool, exclude: String = "") -> String:
	var chosen := ""
	for id in town.active_ids():
		if str(id) == exclude:
			continue
		var foods := int(town.account(id).food)
		var near: bool = town.position_of(id).distance_to(town.home_point(id)) <= WORK_RANGE
		if (foods >= 1) == needs_food and near == at_home:
			if chosen.is_empty() or str(id) < chosen:
				chosen = str(id)
	return chosen

func option_ids(town, id: String) -> Array:
	var ids: Array = []
	for option in town.trade_options(id):
		ids.append(str(option.get("id", "")))
	return ids

func warm_option_ids(town, id: String) -> Array:
	var ids: Array = []
	for id_value in option_ids(town, id):
		if str(id_value).begins_with("warm:"):
			ids.append(str(id_value))
	return ids

func events_of(town, event_type: String) -> Array:
	var result: Array = []
	for event in town.snapshot().life.events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			result.append(event)
	return result

func completion(result: Dictionary, code: String) -> Dictionary:
	for receipt in result.get("completed", []):
		if str(receipt.get("code", "")) == code:
			return receipt
	return {}

func work_steps(town, seconds: float) -> Dictionary:
	## Bounded host stepping of the WORLD CLOCK only; it never moves a body.
	var remaining := seconds
	var merged: Dictionary = {"ok": true, "completed": []}
	while remaining > 0.0:
		var step: float = minf(120.0, remaining)
		var outcome: Dictionary = town.advance(step)
		merged.ok = bool(merged.ok) and bool(outcome.get("ok", false))
		merged.completed.append_array(outcome.get("completed", []))
		remaining -= step
	return merged

func held_report(town, id: String) -> Array:
	return town.resident_view(id).warm_food.held_meals

## ---------------------------------------------------------------------------

func part_baseline_and_compatibility() -> void:
	var town := fresh_town("baseline.json")
	if town.snapshot().is_empty():
		return
	var plain_path := tmp_dir.path_join("baseline-plain.json")
	check(copy_file(world_source, plain_path), "plain comparison copy written")
	var plain_town := PlainTown.new()
	check(plain_town.load_from(plain_path).ok, "plain production runtime still loads the evidence world")
	check(town.active_ids().size() == 10, "ten original identities are active")
	check(not town.snapshot().godot.has("warm_food"), "the source world carries no warm-food state before use")
	var at_home := pick(town, true, true)
	var away := pick(town, true, false)
	var foodless := pick(town, false, true)
	check(not at_home.is_empty() and not away.is_empty() and not foodless.is_empty(),
		"evidence world has a ration holder at its own work point, one away from it, and a resident without a ration")
	check(warm_option_ids(town, at_home) == [PREPARE], "before any use the only warm-food option is the preparation itself")
	check(warm_option_ids(town, foodless).is_empty(), "a resident without a ration is not offered a preparation")
	check(warm_option_ids(plain_town, at_home).is_empty(), "the plain production runtime never offers a warm-food option")
	check(int(town.resident_view(at_home).warm_food.held_meals.size()) == 0, "the view reports zero held warm meals before use")
	check(int(town.resident_view(at_home).warm_food.rations_held) == int(town.account(at_home).food), "the view reports the real ration count")
	check(JSON.stringify(option_ids(town, foodless)) == JSON.stringify(option_ids(plain_town, foodless)),
		"the inherited option surface is unchanged for a resident who cannot prepare anything")
	var added: Array = []
	for id in option_ids(town, at_home):
		if not option_ids(plain_town, at_home).has(id):
			added.append(id)
	check(added == [PREPARE], "with this runtime loaded the only added option for a ration holder is the preparation")
	check(events_of(town, "warm_meal_prepared").is_empty(), "merely loading and listing creates no warm-food event")
	check(str(town.resident_view(away).warm_food.abstraction).contains("工作点"), "the view discloses where the work has to happen")
	check(str(town.resident_view(away).known_rules.warm_food).contains("1份口粮"), "the view discloses the real cost and rule")

func part_prepare_and_later_eat() -> void:
	var town := fresh_town("prepare-eat.json")
	if town.snapshot().is_empty():
		return
	var id := pick(town, true, true)
	var before_positions: Dictionary = town.snapshot().godot.positions.duplicate(true)
	var before_events: Array = town.snapshot().life.events.duplicate(true)
	var before_archive: Dictionary = town.snapshot().godot.resident_archive.duplicate(true)
	var food_before := int(town.account(id).food)
	var seq_before := int(town.snapshot().life.seq)
	var started: Dictionary = town.submit_trade(id, PREPARE, SPRINT + "prepare:1", "local_rule_policy")
	check(started.ok and started.get("code") == "warm_food_preparing", "preparation starts for the ration holder")
	check(bool(started.at_work_point), "the resident really stands inside its own work point at start")
	check(absf(float(started.duration_seconds) - 60.0) < 0.001, "the declared work duration is the stated 60 s")
	check(int(town.account(id).food) == food_before, "no ration is consumed when the job only starts")
	check(int(town.resident_view(id).warm_food.held_meals.size()) == 0, "nothing is held while the work is running")
	check(int(town.snapshot().life.seq) == seq_before, "starting the job appends no event")
	var job: Dictionary = town.pending_job(id)
	check(str(job.get("action", "")) == "prepare_warm_meal" and str(job.get("command_id", "")) == SPRINT + "prepare:1",
		"the pending job is the world-visible preparation")
	check(town.destination(id, str(job.action)).distance_to(town.home_point(id)) <= 0.05,
		"the job's own declared destination is the resident's saved work point")
	check(town.available(id) == ["wait"], "inherited basic actions are not offered while the work runs")
	check(option_ids(town, id) == ["wait"], "the option surface during the work is exactly the inherited wait")
	var busy_repeat: Dictionary = town.submit_trade(id, PREPARE, SPRINT + "prepare:busy", "local_rule_policy")
	check(not busy_repeat.ok and busy_repeat.get("code") == "option_unavailable", "a second preparation cannot start while one runs")
	work_steps(town, 59.0)
	check(int(town.account(id).food) == food_before and events_of(town, "warm_meal_prepared").is_empty(), "59 s of real work consumes nothing yet")
	check(float(town.pending_job(id).elapsed) > 58.0 and float(town.pending_job(id).elapsed) < 60.0, "the recorded work time is the world's own elapsed time")
	var prepared := completion(work_steps(town, 1.0), "warm_food_prepared")
	check(not prepared.is_empty(), "one second more completes the preparation exactly once")
	check(int(town.account(id).food) == food_before - 1, "exactly one ration was consumed at completion")
	var held := held_report(town, id)
	check(held.size() == 1 and town.snapshot().godot.warm_food.held.size() == 1, "exactly one distinct held item exists")
	check(str(held[0].meal_id) == str(prepared.meal_id) and str(prepared.meal_id).begins_with("warm_meal_"),
		"the held item is the one the receipt named")
	check(int(prepared.rations_remaining) == food_before - 1 and int(prepared.ration_consumed) == 1,
		"the receipt states the real ration accounting")
	var prepared_events := events_of(town, "warm_meal_prepared")
	check(prepared_events.size() == 1 and str(prepared_events[0].actor_id) == id and prepared_events[0].recipient_ids == [id] \
		and str(prepared_events[0].operation_id) == SPRINT + "prepare:1" and str(prepared_events[0].source) == "local_rule_policy" \
		and str(prepared_events[0].meal_id) == str(prepared.meal_id),
		"the preparation event carries the real actor, recipient, provenance and item")
	var command: Dictionary = town.snapshot().godot.warm_food.commands[SPRINT + "prepare:1"]
	check(str(command.status) == "completed" and str(command.result.code) == "warm_food_prepared",
		"the command receipt is terminal and authoritative")
	check(not warm_option_ids(town, id).has(PREPARE), "a resident without a ration left is not offered another preparation")
	var frozen: Dictionary = town.snapshot().godot.warm_food.duplicate(true)
	work_steps(town, 30.0)
	check(town.snapshot().godot.warm_food == frozen, "later world time creates no second item and no reset")
	check(bool(held_report(town, id)[0].cooled) == false, "the fresh item is not reported as cooled")
	check(float(held_report(town, id)[0].fresh_remaining_seconds) > 3000.0, "the freshness deadline is reported from world time")
	var eat_option := EAT_PREFIX + str(prepared.meal_id)
	check(option_ids(town, id).has(eat_option), "eating the held item is offered as its own option")
	var label := ""
	for option in town.trade_options(id):
		if str(option.id) == eat_option:
			label = str(option.label)
	check(label.contains("温热") and label.contains("20秒"), "the eat label states the real work and the real item: " + label)
	var eat_start: Dictionary = town.submit_trade(id, eat_option, SPRINT + "eat:1", "local_rule_policy")
	check(eat_start.ok and eat_start.get("code") == "warm_food_eating", "eating starts as a separate action")
	var hunger_before := float(town.resident(id).needs.hunger)
	work_steps(town, 10.0)
	check(int(held_report(town, id).size()) == 1 and absf(float(town.resident(id).needs.hunger) - hunger_before) < 0.001,
		"half the eating time restores nothing and keeps the item")
	var eaten := completion(work_steps(town, 10.0), "warm_food_eaten")
	check(not eaten.is_empty() and int(held_report(town, id).size()) == 0, "the held item is consumed once and is no longer held")
	check(int(town.account(id).food) == food_before - 1, "eating creates no ration back")
	var expected_after: float = minf(100.0, float(eaten.satiety_before) + 50.0)
	check(absf(float(eaten.satiety_after) - expected_after) < 0.001, "fresh warm food restores the stated satiety")
	check(absf(float(town.resident(id).needs.hunger) - float(eaten.satiety_after)) < 0.001, "the world's own satiety matches the receipt")
	check(absf(float(eaten.satiety_gained) - (float(eaten.satiety_after) - float(eaten.satiety_before))) < 0.001,
		"the receipt states the real gain")
	var eaten_events := events_of(town, "warm_meal_eaten")
	check(eaten_events.size() == 1 and str(eaten_events[0].meal_id) == str(prepared.meal_id) \
		and str(eaten_events[0].prepare_command_id) == SPRINT + "prepare:1" and str(eaten_events[0].actor_id) == id \
		and eaten_events[0].recipient_ids == [id],
		"the consumption event keeps the prepared item's provenance")
	var after_eat: Dictionary = town.snapshot()
	check(town.pending_job(id).is_empty() and town.available(id) != ["wait"], "the resident is free again after eating")
	check(not option_ids(town, id).has(eat_option), "a consumed item is not offered again")
	var replay: Dictionary = town.submit_trade(id, eat_option, SPRINT + "eat:1", "local_rule_policy")
	check(bool(replay.get("duplicate", false)), "the same consumption command is acknowledged as a duplicate")
	check(town.snapshot() == after_eat, "a replayed command cannot consume a second time")
	var conflict: Dictionary = town.submit_trade(id, PREPARE, SPRINT + "eat:1", "local_rule_policy")
	check(not conflict.ok and conflict.get("code") == "command_conflict", "one command id can never mean two different options")
	check(town.snapshot().godot.positions == before_positions, "the runtime never moved a body in this flow")
	check(town.snapshot().life.events.slice(0, before_events.size()) == before_events, "original events are preserved in order")
	check(town.snapshot().godot.resident_archive == before_archive, "the resident reply archive is untouched")
	var outsider := pick(town, true, false, id)
	if outsider.is_empty():
		outsider = pick(town, false, true, id)
	check(not JSON.stringify(town.resident_view(outsider)).contains(str(prepared.meal_id)) \
		and not JSON.stringify(town.trade_options(outsider)).contains(str(prepared.meal_id)),
		"another resident's view and options never show this resident's own item")
	var snapshot: Dictionary = town.background_gm_snapshot()
	check(snapshot is Dictionary and not JSON.stringify(snapshot).contains(str(prepared.meal_id)),
		"the existing background-GM projection carries no private warm-food item data")
	var path := tmp_dir.path_join("prepare-eat.json")
	var saved: Dictionary = town.save_to(path)
	check(saved.ok, "the completed flow saves: " + str(saved.get("code", "")))
	var restored := Runtime.new()
	var reloaded: Dictionary = restored.load_from(path)
	check(reloaded.ok, "a save with a finished warm-food flow loads again: " + str(reloaded.get("code", "")))
	check(restored._serialize_state() == town._serialize_state(), "cold restore of the finished flow makes no change")

func part_mid_action_cold_restore() -> void:
	var town := fresh_town("mid-action.json")
	if town.snapshot().is_empty():
		return
	var id := pick(town, true, true)
	var other := pick(town, true, true, id)
	check(not other.is_empty(), "a second ration holder at its own work point exists for the cold-restore path")
	if other.is_empty():
		return
	var food_before := int(town.account(other).food)
	var start: Dictionary = town.submit_trade(other, PREPARE, SPRINT + "prepare:2", "local_rule_policy")
	check(start.ok, "the second resident starts its own preparation")
	work_steps(town, 30.0)
	var path := tmp_dir.path_join("mid-action.json")
	var saved: Dictionary = town.save_to(path)
	check(saved.ok, "mid-action save succeeds: " + str(saved.get("code", "")))
	var restored := Runtime.new()
	var loaded: Dictionary = restored.load_from(path)
	check(loaded.ok, "mid-action cold restore succeeds: " + str(loaded.get("code", "")))
	check(restored._serialize_state() == town._serialize_state(), "cold restore of a running preparation makes no catch-up change")
	var restored_job: Dictionary = restored.pending_job(other)
	check(str(restored_job.get("action", "")) == "prepare_warm_meal" \
		and absf(float(restored_job.elapsed) - float(town.pending_job(other).elapsed)) < 0.0001,
		"the restored job keeps its identity and its real elapsed work")
	check(str(restored_job.command_id) == SPRINT + "prepare:2", "the restored job keeps its own command id")
	check(int(restored.account(other).food) == food_before, "the running preparation still consumed nothing")
	var resumed := work_steps(restored, 30.0)
	check(not completion(resumed, "warm_food_prepared").is_empty(), "the restored job finishes after the remaining work")
	check(int(restored.account(other).food) == food_before - 1, "exactly one ration is consumed across the restore")
	check(events_of(restored, "warm_meal_prepared").size() == 1, "exactly one preparation event exists across the restore")
	check(restored.snapshot().godot.warm_food.held.size() == 1, "exactly one held item exists across the restore")
	var replay: Dictionary = restored.submit_trade(other, PREPARE, SPRINT + "prepare:2", "local_rule_policy")
	check(bool(replay.get("duplicate", false)), "the restored command replay is a duplicate")
	check(int(restored.account(other).food) == food_before - 1 and restored.snapshot().godot.warm_food.held.size() == 1,
		"a duplicate replay cannot create a second item")
	check(int(restored.account(id).food) == int(town.account(id).food), "another resident's ration is untouched")

func part_cooled_eat_after_the_freshness_window() -> void:
	var town := fresh_town("cooled.json")
	if town.snapshot().is_empty():
		return
	var id := pick(town, true, true)
	var start: Dictionary = town.submit_trade(id, PREPARE, SPRINT + "prepare:3", "local_rule_policy")
	if not start.ok:
		check(false, "the cooled-eat path could not start: " + str(start.get("code", "")))
		return
	var prepared := completion(work_steps(town, 60.0), "warm_food_prepared")
	check(not prepared.is_empty(), "an item is prepared for the freshness check")
	var meal_id := str(prepared.meal_id)
	work_steps(town, FRESH_SECONDS + 120.0)
	check(int(held_report(town, id).size()) == 1, "the item is still held after a long idle time")
	check(bool(held_report(town, id)[0].cooled), "after the freshness window the item is honestly reported as cooled")
	check(float(held_report(town, id)[0].fresh_remaining_seconds) <= 0.0, "the freshness deadline really passed in world time")
	var label := ""
	for option in town.trade_options(id):
		if str(option.id) == EAT_PREFIX + meal_id:
			label = str(option.label)
	check(label.contains("放凉"), "the cooled item's own label says it cooled: " + label)
	var eat_start: Dictionary = town.submit_trade(id, EAT_PREFIX + meal_id, SPRINT + "eat:3", "local_rule_policy")
	check(eat_start.ok, "a cooled item can still be eaten instead of silently vanishing")
	var eaten := completion(work_steps(town, 20.0), "warm_food_eaten")
	check(not eaten.is_empty() and bool(eaten.cooled), "the receipt states the item was cooled")
	var expected_after: float = minf(100.0, float(eaten.satiety_before) + 25.0)
	check(absf(float(eaten.satiety_after) - expected_after) < 0.001, "cooled food restores the smaller stated satiety")
	check(absf(float(town.resident(id).needs.hunger) - float(eaten.satiety_after)) < 0.001, "the world agrees with the cooled receipt")
	check(int(held_report(town, id).size()) == 0, "the cooled item is consumed and gone")
	check(events_of(town, "warm_meal_eaten").size() == 1, "exactly one consumption happened")

func part_arrival_gate_and_blocked_close() -> void:
	var town := fresh_town("gate.json")
	if town.snapshot().is_empty():
		return
	var id := pick(town, true, false)
	check(not id.is_empty(), "an away ration holder exists for the arrival gate")
	if id.is_empty():
		return
	var before_positions: Dictionary = town.snapshot().godot.positions.duplicate(true)
	var food_before := int(town.account(id).food)
	var start: Dictionary = town.submit_trade(id, PREPARE, SPRINT + "prepare:4", "local_rule_policy")
	check(start.ok and bool(start.at_work_point) == false, "preparation starts honestly away from the work point")
	work_steps(town, 40.0)
	var job: Dictionary = town.pending_job(id)
	check(not job.is_empty(), "the away resident's preparation is still pending before its own stall window")
	check(float(job.elapsed) == 0.0, "no work time is credited while the body is not at its own work point")
	check(int(town.account(id).food) == food_before and int(held_report(town, id).size()) == 0,
		"a resident away from its work point consumes nothing and holds nothing")
	check(float(job.no_progress_seconds) >= 39.0 and float(job.no_progress_seconds) < 45.0,
		"the world measured the real lack of progress inside its own window")
	check(town.snapshot().godot.positions == before_positions, "the runtime never teleported the resident to its work point")
	var blocked := completion(work_steps(town, 10.0), "warm_food_work_point_blocked")
	check(not blocked.is_empty() and str(blocked.reason) == "work_point_unreachable", "a blocked preparation closes once with a real reason")
	check(str(town.snapshot().godot.warm_food.commands[SPRINT + "prepare:4"].status) == "rejected",
		"the blocked command is terminal and rejected")
	check(town.pending_job(id).is_empty(), "the blocked resident is released instead of staying busy forever")
	check(int(town.account(id).food) == food_before, "the blocked preparation consumed no ration")
	check(int(held_report(town, id).size()) == 0, "the blocked preparation created no item")
	var blocked_events := events_of(town, "warm_meal_blocked")
	check(blocked_events.size() == 1 and str(blocked_events[0].actor_id) == id and blocked_events[0].recipient_ids == [id] \
		and str(blocked_events[0].reason) == "work_point_unreachable",
		"the blocked observation is personal, attributed and says why")
	check(option_ids(town, id).has(PREPARE), "the released resident may honestly try again")
	check(town.resident_view(id).get("pending", {}).is_empty(), "the released resident has no pending job left in its own view")
	## The honest failure has to be durable too: an event without an item must still save and load.
	var blocked_path := tmp_dir.path_join("blocked-save.json")
	var blocked_saved: Dictionary = town.save_to(blocked_path)
	check(blocked_saved.ok, "the blocked world saves: " + str(blocked_saved.get("code", "")))
	var blocked_restored := Runtime.new()
	var blocked_loaded: Dictionary = blocked_restored.load_from(blocked_path)
	check(blocked_loaded.ok, "the blocked world loads again: " + str(blocked_loaded.get("code", "")))
	check(blocked_restored._serialize_state() == town._serialize_state(), "cold restore of a blocked close makes no change")
	check(int(blocked_restored.account(id).food) == food_before, "the restored blocked world still has the ration it never spent")
	check(int(held_report(blocked_restored, id).size()) == 0, "the restored blocked world still holds no item")
	var restored_blocked_events := events_of(blocked_restored, "warm_meal_blocked")
	check(restored_blocked_events.size() == 1 and str(restored_blocked_events[0].reason) == "work_point_unreachable" \
		and not restored_blocked_events[0].has("meal_id") and str(restored_blocked_events[0].actor_id) == id,
		"exactly one attributed blocked observation survived the restore, with no invented item")
	work_steps(blocked_restored, 120.0)
	check(int(blocked_restored.account(id).food) == food_before and int(held_report(blocked_restored, id).size()) == 0 \
		and events_of(blocked_restored, "warm_meal_blocked").size() == 1,
		"a blocked attempt is never replayed or re-charged as world time continues")
	check(blocked_restored.save_to(blocked_path).ok, "the blocked world saves a second time")
	var blocked_twice := Runtime.new()
	check(blocked_twice.load_from(blocked_path).ok, "the twice-saved blocked world still loads")
	check(events_of(blocked_twice, "warm_meal_blocked").size() == 1, "the blocked observation is still exactly one")

func part_host_move_explicitly_labelled() -> void:
	## Explicitly labelled host_move test. The host scene resolves collision and moves the capsule;
	## this runtime never moves a body. It only measures the position the host really reports.
	var town := fresh_town("host-move.json")
	if town.snapshot().is_empty():
		return
	var id := pick(town, true, false)
	if id.is_empty():
		check(false, "host_move flow has no away ration holder")
		return
	var food_before := int(town.account(id).food)
	var home: Vector3 = town.home_point(id)
	var start: Dictionary = town.submit_trade(id, PREPARE, SPRINT + "prepare:5", "local_rule_policy")
	check(start.ok, "host_move flow starts")
	work_steps(town, 20.0)
	check(float(town.pending_job(id).elapsed) == 0.0, "host_move: still no credit before the host moves the body")
	town.host_move(id, home + Vector3(2.0, 0.0, 0.0))
	work_steps(town, 20.0)
	check(float(town.pending_job(id).elapsed) > 19.0,
		"host_move: real elapsed work accrues once the reported body is inside its own work point")
	check(float(town.pending_job(id).no_progress_seconds) == 0.0, "host_move: reaching the point clears the stall clock")
	town.host_move(id, home)
	var done := work_steps(town, 45.0)
	check(not completion(done, "warm_food_prepared").is_empty(),
		"host_move: the job completes with the ration consumed at the declared point")
	check(int(town.account(id).food) == food_before - 1 and int(held_report(town, id).size()) == 1,
		"host_move: one ration became exactly one held item")

func _tamper(kind: String, state: Dictionary, held_id: String, other: String, id: String) -> void:
	match kind:
		"held_item_erased":
			state.godot.warm_food.held.erase(held_id)
		"held_item_duplicated":
			var copy: Dictionary = state.godot.warm_food.held[held_id].duplicate(true)
			copy.meal_id = "warm_meal_999"
			state.godot.warm_food.held["warm_meal_999"] = copy
		"freshness_deadline_rewritten":
			var meal: Dictionary = state.godot.warm_food.held[held_id]
			meal.fresh_until_elapsed = float(meal.prepared_elapsed) + 10.0
		"job_action_renamed":
			state.godot.warm_food.jobs[other].action = "eat_ration"
		"job_moved_off_the_own_work_point":
			state.godot.warm_food.jobs[other].target_position = [12.0, 0.1, 40.0]
		"pending_command_without_its_job":
			state.godot.warm_food.jobs.erase(other)
		"pending_job_without_its_command":
			state.godot.warm_food.commands.erase(SPRINT + "prepare:7")
		"receipt_provenance_cleared":
			state.godot.warm_food.commands[SPRINT + "prepare:6"].payload.provenance = ""
		"work_seconds_rewritten":
			for event in state.life.events:
				if event.get("type", "") == "warm_meal_prepared":
					event.work_seconds = 5.0
		"meal_serial_above_state_serial":
			state.godot.warm_food.seq = 0
		"second_preparation_event_for_one_item":
			for event in state.life.events:
				if event.get("type", "") == "warm_meal_prepared":
					var clone: Dictionary = event.duplicate(true)
					clone.seq = int(state.life.seq) + 1
					clone.event_id = "life_event_%d" % int(clone.seq)
					state.life.seq = int(clone.seq)
					state.life.events.append(clone)
					break
		"foreign_journey_for_the_same_resident":
			state.godot.pending[other] = {"action": "rest", "command_id": SPRINT + "prepare:7",
				"elapsed": 0.0, "provenance": "local_rule_policy"}

func part_tampered_saves_fail_closed() -> void:
	var town := fresh_town("tamper-source.json")
	if town.snapshot().is_empty():
		return
	var id := pick(town, true, true)
	var other := pick(town, true, true, id)
	if other.is_empty():
		check(false, "tamper fixture needs two ration holders at their own work points")
		return
	check(town.submit_trade(id, PREPARE, SPRINT + "prepare:6", "local_rule_policy").ok, "tamper fixture: first preparation started")
	work_steps(town, 60.0)
	check(town.pending_job(id).is_empty() and int(held_report(town, id).size()) == 1, "tamper fixture: first preparation finished with one held item")
	check(town.submit_trade(other, PREPARE, SPRINT + "prepare:7", "local_rule_policy").ok, "tamper fixture: second, unfinished preparation started")
	work_steps(town, 20.0)
	check(not town.pending_job(other).is_empty(), "tamper fixture: a live pending job exists")
	var path := tmp_dir.path_join("tamper-source.json")
	check(town.save_to(path).ok, "tamper fixture saved")
	var control := Runtime.new()
	check(control.load_from(path).ok, "tamper control: the untouched round-trip copy still loads")
	var written: Variant = decode_state(FileAccess.get_file_as_string(path))
	if not written is Dictionary:
		check(false, "tamper source is valid JSON")
		return
	# Control: the untouched round trip through the world's own codec must still load, so a
	# refused tampered save below cannot be an artefact of re-encoding.
	var control_path := tmp_dir.path_join("tamper-round-trip-control.json")
	var control_file := FileAccess.open(control_path, FileAccess.WRITE)
	control_file.store_string(encode_state(written))
	control_file.close()
	var round_trip: Dictionary = Runtime.new().load_from(control_path)
	check(round_trip.ok, "control: the re-encoded untouched state still loads: " + str(round_trip.get("code", "")))
	var held_id := ""
	for meal_key in written.godot.warm_food.held:
		held_id = str(meal_key)
	check(not held_id.is_empty(), "tamper fixture holds an item to attack")
	var cases := ["held_item_erased", "held_item_duplicated", "freshness_deadline_rewritten", "job_action_renamed",
		"job_moved_off_the_own_work_point", "pending_command_without_its_job", "pending_job_without_its_command",
		"receipt_provenance_cleared", "work_seconds_rewritten", "meal_serial_above_state_serial",
		"second_preparation_event_for_one_item", "foreign_journey_for_the_same_resident"]
	var expected := {"held_item_erased": "unbalanced_warm_food_meal",
		"held_item_duplicated": "invalid_warm_food_held_source",
		"freshness_deadline_rewritten": "invalid_warm_food_held_clock",
		"job_action_renamed": "invalid_warm_food_job",
		"job_moved_off_the_own_work_point": "invalid_warm_food_job_placement",
		"pending_command_without_its_job": "orphan_warm_food_command",
		"pending_job_without_its_command": "invalid_warm_food_job_command",
		"receipt_provenance_cleared": "invalid_warm_food_command",
		"work_seconds_rewritten": "invalid_warm_food_event",
		"meal_serial_above_state_serial": "invalid_warm_food_sequence",
		"second_preparation_event_for_one_item": "unbalanced_warm_food_meal",
		"foreign_journey_for_the_same_resident": "invalid_pending"}
	var codes: Dictionary = {}
	for kind in cases:
		var state: Dictionary = written.duplicate(true)
		_tamper(kind, state, held_id, other, id)
		var case_path := tmp_dir.path_join("tampered-%s.json" % kind)
		var file := FileAccess.open(case_path, FileAccess.WRITE)
		if file == null:
			check(false, "could not write tampered case: " + kind)
			continue
		file.store_string(encode_state(state))
		file.close()
		var loaded: Dictionary = Runtime.new().load_from(case_path)
		codes[kind] = str(loaded.get("code", ""))
		check(not loaded.ok, "tampered save is refused (%s): %s" % [kind, str(loaded.get("code", ""))])
		check(str(codes[kind]) == str(expected[kind]), "the refusal names the real defect (%s): %s" % [kind, str(codes[kind])])
	print(JSON.stringify({"suite": "r5_gm_capability", "phase": "tamper_codes", "codes": codes}))

## ---------------------------------------------------------------------------
## Real playable scene phase (`--r5-phase=scene`): the host scene substitutes this runtime before
## its _ready loads the save, and only the physics frame moves bodies. Nothing here teleports:
## the measured per-frame displacement is the evidence for that.

func part_real_scene_walk_and_work() -> void:
	var save_path := tmp_dir.path_join("scene-world.json")
	if not copy_file(world_source, save_path):
		check(false, "scene world copy written")
		return
	Engine.time_scale = SCENE_TIME_SCALE
	var scene: Node = TownScene.instantiate()
	var runtime := Runtime.new()
	scene.set("town", runtime)
	get_root().add_child(scene)
	await process_frame
	await process_frame
	check(scene.get("town") == runtime, "scene: the playable scene runs on this capability runtime")
	check(runtime.active_ids().size() == 10, "scene: the substituted runtime loaded the real save")
	var id := pick(runtime, true, false)
	if id.is_empty():
		check(false, "scene: an away ration holder exists")
		_finish_scene(scene, runtime, save_path)
		return
	var bodies: Dictionary = scene.get("bodies")
	check(bodies.has(id), "scene: the chosen resident has a real body in the scene")
	if not bodies.has(id):
		_finish_scene(scene, runtime, save_path)
		return
	var source_state: Dictionary = decode_state(FileAccess.get_file_as_string(world_source))
	var base_events := int(source_state.life.events.size())
	var base_food := 0
	for account_value in source_state.survival.accounts:
		if str(account_value.resident_id) == id:
			base_food = int(account_value.food)
	check(base_food == 1, "scene: the chosen resident starts with exactly one ration")
	var body: CharacterBody3D = bodies[id]
	var home: Vector3 = runtime.home_point(id)
	var start_position := body.position
	check(start_position.distance_to(home) > 10.0, "scene: the chosen resident starts far from its work point (%.1f m)" % start_position.distance_to(home))
	check(runtime.trade_options(id).any(func(option): return str(option.id) == PREPARE),
		"scene: the preparation option is offered in the real scene")
	var accepted := runtime.transaction(save_path, func(): return runtime.submit_trade(id, PREPARE, SPRINT + "scene:1", "local_rule_policy"))
	check(accepted.ok, "scene: the accepted choice starts the job and saves: " + str(accepted.get("code", "")))
	scene.set("paused", false)
	var walked := 0.0
	var max_step := 0.0
	var last := body.position
	var deadline := Time.get_ticks_msec() + SCENE_WALL_BUDGET_MS
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		var now: Vector3 = body.position
		var moved := now.distance_to(last)
		max_step = maxf(max_step, moved)
		walked += moved
		last = now
		if runtime.pending_job(id).is_empty():
			break
	var prepared_done: bool = runtime.pending_job(id).is_empty()
	var prepared_receipt: Dictionary = runtime.snapshot().godot.get("warm_food", {}).get("commands", {}).get(SPRINT + "scene:1", {}).get("result", {})
	print(JSON.stringify({"suite": "r5_gm_capability", "phase": "scene_walk", "resident": id,
		"start": [start_position.x, start_position.y, start_position.z], "home": [home.x, home.y, home.z],
		"walked_m": snappedf(walked, 0.01), "max_physics_frame_step_m": snappedf(max_step, 0.001),
		"arrived_distance_m": snappedf(body.position.distance_to(home), 0.01), "job_finished": prepared_done,
		"receipt": prepared_receipt, "elapsed_game_seconds": runtime.snapshot().godot.elapsed_seconds}))
	check(prepared_done, "scene: the preparation finished through the scene's own physics and world step")
	check(str(prepared_receipt.get("code", "")) == "warm_food_prepared",
		"scene: the completion is the real preparation receipt: " + str(prepared_receipt.get("code", "")))
	check(max_step < 0.6, "scene: no body was teleported (largest physics-frame step %.3f m)" % max_step)
	check(walked >= (home - start_position).length() * 0.85,
		"scene: the resident really walked its own route (%.1f m walked)" % walked)
	check(int(runtime.account(id).food) == base_food - 1, "scene: exactly the one ration it held was consumed by the preparation")
	check(int(runtime.resident_view(id).warm_food.held_meals.size()) == 1, "scene: exactly one warm meal is held")
	var meal_id := str(runtime.resident_view(id).warm_food.held_meals[0].meal_id)
	var eat_option := EAT_PREFIX + meal_id
	check(runtime.trade_options(id).any(func(option): return str(option.id) == eat_option),
		"scene: the held item can be eaten where it was prepared")
	var eat_accepted := runtime.transaction(save_path, func(): return runtime.submit_trade(id, eat_option, SPRINT + "scene:2", "local_rule_policy"))
	check(eat_accepted.ok, "scene: the accepted eating choice starts: " + str(eat_accepted.get("code", "")))
	var hunger_before := float(runtime.resident(id).needs.hunger)
	deadline = Time.get_ticks_msec() + SCENE_WALL_BUDGET_MS
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		var now: Vector3 = body.position
		max_step = maxf(max_step, now.distance_to(last))
		last = now
		if runtime.pending_job(id).is_empty():
			break
	var eat_receipt: Dictionary = runtime.snapshot().godot.get("warm_food", {}).get("commands", {}).get(SPRINT + "scene:2", {}).get("result", {})
	print(JSON.stringify({"suite": "r5_gm_capability", "phase": "scene_eat", "receipt": eat_receipt,
		"hunger_before": hunger_before, "hunger_after": float(runtime.resident(id).needs.hunger),
		"max_physics_frame_step_m": snappedf(max_step, 0.001)}))
	check(str(eat_receipt.get("code", "")) == "warm_food_eaten", "scene: the held item was eaten in the real scene: " + str(eat_receipt.get("code", "")))
	check(int(runtime.resident_view(id).warm_food.held_meals.size()) == 0, "scene: the item is consumed and no longer held")
	check(float(runtime.resident(id).needs.hunger) > hunger_before, "scene: eating restored the resident's satiety")
	check(max_step < 0.6, "scene: no teleport happened in the second action either")
	var restored := Runtime.new()
	var reloaded: Dictionary = restored.load_from(save_path)
	check(reloaded.ok, "scene: the scene-written save loads under this runtime: " + str(reloaded.get("code", "")))
	check(restored.snapshot().life.events.slice(0, base_events) == source_state.life.events,
		"scene: the original events are still the first events of the saved world")
	_finish_scene(scene, runtime, save_path)

func _finish_scene(scene: Node, runtime, save_path: String) -> void:
	Engine.time_scale = 1.0
	var released: Dictionary = runtime.release_writer(save_path)
	check(released.get("ok", false) or str(released.get("code", "")) == "writer_lock_not_owned",
		"scene: the world writer lock is released again")
	scene.queue_free()
