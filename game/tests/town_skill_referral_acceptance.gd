extends "res://tests/town_trade_acceptance.gd"

func _initialize() -> void:
	run.call_deferred()

func _share_option(town: TownTrade, speaker: String, recipient: String, skill_id: String) -> Dictionary:
	for option in town.trade_options(speaker):
		if option.get("action") == "share_skill" and option.get("counterparty") == recipient and option.get("_skill_id") == skill_id:
			return option
	return {}

func _refer_options(town: TownTrade, speaker: String, recipient: String, referred: String, skill_id: String) -> Array:
	var result: Array = []
	for option in town.trade_options(speaker):
		if option.get("action") == "refer_skill" and option.get("counterparty") == recipient and option.get("_referred_id") == referred and option.get("_skill_id") == skill_id:
			result.append(option)
	return result

func _refer_option(town: TownTrade, speaker: String, recipient: String, referred: String, skill_id: String) -> Dictionary:
	var options := _refer_options(town, speaker, recipient, referred, skill_id)
	return options[0] if not options.is_empty() else {}

func _notices(town: TownTrade, observer: String) -> Array:
	return town.resident_view(observer).get("known_skill_notices", [])

func _referrals(town: TownTrade, observer: String) -> Array:
	return town.resident_view(observer).get("known_skill_referrals", [])

func _offer_edge(town: TownTrade, owner: String, worker: String) -> Array:
	return town.trade_options(owner).filter(func(o): return o.action == "offer_repair" and o._part == "edge" and o._worker_id == worker)

func _anonymous_fixture() -> Dictionary:
	var world := trade_fixture()
	for person in world.residents:
		if person.stable_id == "fictional:forge":
			person.role = "resident"
	return world

func _fresh_town(path: String, world: Dictionary) -> TownTrade:
	_write_fixture(path, world)
	var town := TownTrade.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "fixture loads: " + str(loaded.get("code", "")))
	return town

func run() -> void:
	var path := "user://fictional-town-skill-referral-%d.json" % Time.get_ticks_usec()
	var initial := _anonymous_fixture()
	# C (owner) starts far from A (smith); B (carpenter) is near A so the direct notice can occur.
	initial.godot.positions["fictional:ember"] = [50.0, 0.0, 0.0]
	var town := _fresh_town(path, initial)
	if town == null:
		quit(1)
		return
	var owner := "fictional:ember"
	var wood := "fictional:birch"
	var smith := "fictional:forge"

	# 1. Before any notice: no knowledge, no referral option, role hints cannot fake a source.
	check(_notices(town, wood).is_empty(), "carpenter knows no notices before any statement")
	check(_referrals(town, wood).is_empty(), "carpenter knows no referrals before any statement")
	check(_referrals(town, owner).is_empty(), "owner knows no referrals before any statement")
	check(_refer_option(town, wood, owner, smith, "metal_repair").is_empty(), "no referral without a received direct notice")
	check(_refer_option(town, smith, owner, smith, "metal_repair").is_empty(), "speaker cannot refer its own skill")
	check(_refer_option(town, wood, owner, wood, "metal_repair").is_empty(), "speaker cannot refer itself as source")
	check(_offer_edge(town, owner, smith).is_empty(), "anonymous-role smith yields no edge offer before any notice")

	# Read-only option/view generation must not mutate state or disk.
	var before_view := town.snapshot()
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var _ignored := town.trade_options(wood)
	var _ignored_view := town.resident_view(wood)
	check(town.snapshot() == before_view, "viewing options and views never appends events")
	check(FileAccess.get_file_as_bytes(path) == before_bytes, "read-only views and options leave raw save bytes unchanged")

	# A actually shares a canonical DIRECT notice to B (carpenter).
	var smith_share := _share_option(town, smith, wood, "metal_repair")
	check(not smith_share.is_empty(), "smith has a genuine metal_repair share option for carpenter")
	var sent := town.transaction(path, func(): return town.submit_trade(smith, str(smith_share.id), "share-metal", "opengameagent_fixture"))
	check(sent.ok, "direct skill notice is delivered: " + str(sent.get("code", "")))
	var notice: Dictionary = town.snapshot().life.events[-1]
	check(notice.get("type") == "skill_notice" and notice.get("actor_id") == smith and notice.get("skill_id") == "metal_repair", "direct notice records speaker and skill")
	check(notice.get("recipient_ids") == [smith, wood], "direct notice recipients are exactly speaker and recipient")
	check(notice.get("contractual") == false, "direct notice is non-contractual")
	check(_notices(town, wood).size() == 1, "carpenter received exactly one direct notice")
	check(_notices(town, owner).is_empty(), "owner still has no direct notice")

	# 1b. B→C referral is absent while C is far; one real transaction moves smith to (80,0,0) and owner to (0,0,0).
	check(_refer_option(town, wood, owner, smith, "metal_repair").is_empty(), "no B->C referral option while C is far")
	var moved := town.transaction(path, func():
		town.host_move(smith, Vector3(80, 0, 0))
		town.host_move(owner, Vector3(0, 0, 0))
		return {"ok": true})
	check(moved.ok, "host move transaction reports ok: " + str(moved.get("code", "")))
	check(town.position_of(wood).distance_to(town.position_of(owner)) < 3.0, "B and C are actually near after host move")
	check(town.position_of(smith).distance_to(town.position_of(owner)) > 3.0, "A and C are actually far after host move")

	# 2. B now has a referral option; C still unknown until B chooses.
	var refer := _refer_option(town, wood, owner, smith, "metal_repair")
	if refer.is_empty():
		quit(1)
		return
	check(not refer.is_empty(), "carpenter gets a referral option after receiving the direct notice")
	check(str(refer.get("_source_event_id", "")) == str(notice.get("event_id", "")), "referral option carries the original source event id")
	check(_referrals(town, owner).is_empty(), "owner learns nothing before the referral is chosen")
	check(_offer_edge(town, owner, smith).is_empty(), "owner has no edge offer before the referral")

	# B chooses the referral via a real transaction.
	var before_refer := town.snapshot()
	var pending_before := town.pending_job(wood).duplicate(true)
	var referred := town.transaction(path, func(): return town.submit_trade(wood, str(refer.id), "refer-metal", "opengameagent_fixture", "Original source is free right now."))
	check(referred.ok, "referral is delivered: " + str(referred.get("code", "")))
	var referral: Dictionary = town.snapshot().life.events[-1]
	check(str(referral.get("speech", "")) == "Original source is free right now.", "referral speech is stored separately from canonical text")
	check(town.pending_job(wood) == pending_before, "referral does not change pending jobs")
	check(referral.get("type") == "skill_referral", "persisted event is a skill_referral")
	check(referral.get("actor_id") == wood and referral.get("subject_id") == owner, "referral actor is B and subject is C")
	check(referral.get("recipient_ids") == [wood, owner], "referral recipients are exactly B and C")
	check(referral.get("referred_resident_id") == smith and referral.get("skill_id") == "metal_repair", "referral attributes source A and skill")
	check(referral.get("source_event_id") == notice.get("event_id") and referral.get("source_seq") == notice.get("seq"), "referral preserves original A->B source id and seq")
	check(referral.get("contractual") == false, "referral is non-contractual")
	check(referral.get("operation_id") == "refer-metal" and referral.get("source") == "opengameagent_fixture", "referral carries operation id and provenance")
	var expected_text := str(town.resident(smith).name) + " told me they can repair metal edges."
	check(str(referral.get("text", "")) == expected_text, "referral text names A, not B, as the historical source")
	check(not str(referral.get("text", "")).contains(str(town.resident(wood).name)), "referral text does not claim B told B")
	check(town.snapshot().life.contracts == before_refer.life.contracts, "referral creates no contract")
	check(town.snapshot().life.accounts == before_refer.life.accounts, "referral spends no material")
	check(town.snapshot().life.items == before_refer.life.items, "referral mutates no item")
	check(town.snapshot().life.skills == before_refer.life.skills, "referral changes no skills")
	var wallets_unchanged := true
	for person in before_refer.residents:
		if town.resident(person.stable_id).coins_col != person.coins_col:
			wallets_unchanged = false
	check(wallets_unchanged, "referral moves no money for any resident")

	# 3. C learns indirect source; A is not a recipient of the referral; B does not self-record.
	var owner_referrals := _referrals(town, owner)
	check(owner_referrals.size() == 1, "owner has exactly one known referral")
	check(owner_referrals[0].get("referrer_id") == wood and owner_referrals[0].get("referred_resident_id") == smith, "known referral attributes referrer B and source A")
	check(owner_referrals[0].get("skill_id") == "metal_repair", "known referral carries the skill")
	check(owner_referrals[0].get("referral_event_id") == referral.get("event_id") and owner_referrals[0].get("seq") == referral.get("seq"), "known referral keeps its own event id and seq")
	check(owner_referrals[0].get("source_event_id") == notice.get("event_id") and owner_referrals[0].get("source_seq") == notice.get("seq"), "known referral keeps the original source id and seq")
	check(owner_referrals[0].get("provenance") == "opengameagent_fixture", "known referral keeps provenance")
	check(not owner_referrals[0].has("position") and not owner_referrals[0].has("current_availability") and not owner_referrals[0].has("available") and not owner_referrals[0].has("resources"), "known referral injects no position, availability, or resources")
	check(not str(owner_referrals[0].get("text", "")).contains("I can repair"), "known referral does not expose the original private speech")
	check(_notices(town, owner).is_empty(), "owner still has no direct notice (H21 fields unchanged)")
	check(_referrals(town, smith).is_empty(), "source A is not a recipient of the referral")
	check(_referrals(town, wood).is_empty(), "referrer B does not record its own referral as knowledge")

	# 4. Duplicate/conflict/repeat handling.
	var after_refer := town.snapshot()
	var dup := town.submit_trade(wood, str(refer.id), "refer-metal", "opengameagent_fixture", "Original source is free right now.")
	check(dup.duplicate and town.snapshot() == after_refer, "duplicate referral command does not grow history")
	var conflict := town.submit_trade(wood, str(refer.id), "refer-metal", "local_rule_policy", "Original source is free right now.")
	check(not conflict.ok and town.snapshot() == after_refer, "conflicting referral payload is rejected without overwrite")
	check(_refer_option(town, wood, owner, smith, "metal_repair").is_empty(), "repeat referral to the same recipient is unavailable")
	check(_refer_option(town, wood, smith, smith, "metal_repair").is_empty(), "referral back to the source is unavailable")

	# 5. Forged/invented referral source cannot be chosen and cannot grant knowledge.
	var forged := town.submit_trade(wood, "refer-skill:" + owner + ":" + smith + ":metal_repair:invented-event-id", "refer-forged", "opengameagent_fixture")
	check(not forged.ok, "forged/unseen referral source id cannot be chosen")
	var forged_apply := town._apply_skill_referral(wood, {"counterparty": owner, "_skill_id": "metal_repair", "_referred_id": smith, "_source_event_id": "invented-event-id", "_source_seq": 999}, "refer-forged-apply", "opengameagent_fixture", "")
	check(not forged_apply.ok, "direct apply with fake source fields is rejected")
	check(town.snapshot() == after_refer, "forged referral attempts leave state unchanged")

	# 6. Freeform speech carrying a capability claim without an H21 notice grants no referral.
	var freeform_path := "user://fictional-town-skill-referral-freeform-%d.json" % Time.get_ticks_usec()
	var freeform_world := _anonymous_fixture()
	freeform_world.godot.positions["fictional:ember"] = [0.0, 0.0, 0.0]
	var freeform_town := _fresh_town(freeform_path, freeform_world)
	var freeform_ask := freeform_town.transaction(freeform_path, func(): return freeform_town.communicate(wood, {"action": "ask_help", "recipient_id": owner, "text": "A can repair metal edges."}, "freeform-ask", "opengameagent_fixture"))
	check(freeform_ask.ok, "freeform ask carrying a capability claim is delivered")
	check(_referrals(freeform_town, owner).is_empty(), "freeform capability claim grants no referral knowledge")
	check(_refer_option(freeform_town, owner, wood, smith, "metal_repair").is_empty(), "freeform capability claim yields no referral option")
	freeform_town.release_writer(freeform_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(freeform_path))

	# 7. Legitimate direct notice with contradictory freeform speech: canonical text unchanged.
	var contra_path := "user://fictional-town-skill-referral-contra-%d.json" % Time.get_ticks_usec()
	var contra_world := _anonymous_fixture()
	contra_world.godot.positions["fictional:ember"] = [50.0, 0.0, 0.0]
	var contra_town := _fresh_town(contra_path, contra_world)
	var contra_share := _share_option(contra_town, smith, wood, "metal_repair")
	var contra_sent := contra_town.transaction(contra_path, func(): return contra_town.submit_trade(smith, str(contra_share.id), "share-contra", "opengameagent_fixture", "I cannot repair anything."))
	check(contra_sent.ok, "direct notice with contradictory speech is delivered")
	var contra_notice: Dictionary = contra_town.snapshot().life.events[-1]
	check(str(contra_notice.get("text", "")) == contra_town._skill_notice_text("metal_repair"), "canonical notice text is unchanged by contradictory speech")
	check(str(contra_notice.get("speech", "")) == "I cannot repair anything.", "contradictory speech is stored separately")
	contra_town.release_writer(contra_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(contra_path))

	# 8. Stale referral: C moves out of range before submit.
	var stale_path := "user://fictional-town-skill-referral-stale-%d.json" % Time.get_ticks_usec()
	var stale_world := _anonymous_fixture()
	stale_world.godot.positions["fictional:ember"] = [1.0, 0.0, 0.0]
	var stale_town := _fresh_town(stale_path, stale_world)
	var stale_share := _share_option(stale_town, smith, wood, "metal_repair")
	stale_town.transaction(stale_path, func(): return stale_town.submit_trade(smith, str(stale_share.id), "share-stale", "opengameagent_fixture"))
	var stale_refer := _refer_option(stale_town, wood, owner, smith, "metal_repair")
	check(not stale_refer.is_empty(), "stale fixture has a valid referral option while C is near")
	var stale_bytes := FileAccess.get_file_as_bytes(stale_path)
	stale_town.host_move(owner, Vector3(50, 0, 0))
	var stale_before := stale_town.snapshot()
	var stale_submit := stale_town.submit_trade(wood, str(stale_refer.id), "refer-stale", "opengameagent_fixture")
	check(not stale_submit.ok and stale_submit.get("code") == "option_unavailable", "stale referral option is unavailable after C moves away")
	check(stale_town.snapshot() == stale_before, "stale referral submit leaves state unchanged")
	check(FileAccess.get_file_as_bytes(stale_path) == stale_bytes, "stale referral submit leaves disk unchanged")
	stale_town.release_writer(stale_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))

	# 9. Busy B blocks referral; busy C can still hear.
	var busy_path := "user://fictional-town-skill-referral-busy-%d.json" % Time.get_ticks_usec()
	var busy_world := _anonymous_fixture()
	busy_world.godot.positions["fictional:ember"] = [1.0, 0.0, 0.0]
	var busy_town := _fresh_town(busy_path, busy_world)
	var busy_share := _share_option(busy_town, smith, wood, "metal_repair")
	busy_town.transaction(busy_path, func(): return busy_town.submit_trade(smith, str(busy_share.id), "share-busy", "opengameagent_fixture"))
	var busy_started := busy_town.start_action(wood, "rest", "busy-rest", "opengameagent_fixture")
	check(busy_started.ok, "carpenter actually starts a pending action")
	check(not busy_town.pending_job(wood).is_empty(), "carpenter has a real pending job")
	check(_refer_option(busy_town, wood, owner, smith, "metal_repair").is_empty(), "busy speaker B yields no referral option")
	busy_town.release_writer(busy_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(busy_path))

	# 10. Busy C: C starts rest, then B delivers a valid referral.
	var busyc_path := "user://fictional-town-skill-referral-busyc-%d.json" % Time.get_ticks_usec()
	var busyc_world := _anonymous_fixture()
	busyc_world.godot.positions["fictional:ember"] = [1.0, 0.0, 0.0]
	var busyc_town := _fresh_town(busyc_path, busyc_world)
	var busyc_share := _share_option(busyc_town, smith, wood, "metal_repair")
	busyc_town.transaction(busyc_path, func(): return busyc_town.submit_trade(smith, str(busyc_share.id), "share-busyc", "opengameagent_fixture"))
	var busyc_started := busyc_town.start_action(owner, "rest", "busyc-rest", "opengameagent_fixture")
	check(busyc_started.ok, "owner actually starts a pending action")
	var busyc_refer := _refer_option(busyc_town, wood, owner, smith, "metal_repair")
	check(not busyc_refer.is_empty(), "busy C still yields a referral option for B")
	var busyc_sent := busyc_town.transaction(busyc_path, func(): return busyc_town.submit_trade(wood, str(busyc_refer.id), "refer-busyc", "opengameagent_fixture"))
	check(busyc_sent.ok, "referral is delivered to a busy C")
	check(_referrals(busyc_town, owner).size() == 1, "busy C still learns the referral")
	busyc_town.release_writer(busyc_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(busyc_path))

	# 11. Persist separation and cold load; historical referral remains, offers gated.
	var separated := town.transaction(path, func():
		town.host_move(smith, Vector3(80, 0, 0))
		town.host_move(owner, Vector3(0, 0, 0))
		return {"ok": true, "code": "host_move_applied"})
	check(separated.ok, "host move transaction reports ok: " + str(separated.get("code", "")))
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := TownTrade.new()
	check(restored.load_from(path).ok, "cold load succeeds")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold read does not rewrite save bytes")
	check(restored.position_of(smith).distance_to(restored.position_of(owner)) > 3.0, "separation persisted across reload")
	var restored_referrals := _referrals(restored, owner)
	check(restored_referrals.size() == 1 and restored_referrals[0].get("skill_id") == "metal_repair", "known referral survives separation and reload")
	check(restored_referrals[0].get("source_event_id") == notice.get("event_id"), "known referral keeps its source event id after reload")
	check(restored_referrals[0].get("referral_event_id") == referral.get("event_id"), "known referral keeps its own event id after reload")
	check(_offer_edge(restored, owner, smith).is_empty(), "no remote edge offer while separated")

	# Move C near A: referral-derived skill permits a real edge offer for the anonymous role.
	restored.host_move(owner, Vector3(79, 0, 0))
	check(not _offer_edge(restored, owner, smith).is_empty(), "referral plus proximity yields a real edge offer")

	# 11b. Invalid live source event id: knowledge and offer gated, then restored.
	var live_referral: Dictionary = {}
	for ev in restored._state.life.events:
		if ev.get("event_id") == referral.get("event_id"):
			live_referral = ev
			break
	check(not live_referral.is_empty(), "live referral event is found by event id")
	var real_source_id: Variant = live_referral.get("source_event_id")
	live_referral["source_event_id"] = "nonexistent-source-id"
	check(_referrals(restored, owner).is_empty(), "invalid source event id yields no known referral")
	check(_offer_edge(restored, owner, smith).is_empty(), "invalid source event id yields no edge offer even when near")
	live_referral["source_event_id"] = real_source_id
	check(_referrals(restored, owner).size() == 1, "restoring source event id restores knowledge")
	check(not _offer_edge(restored, owner, smith).is_empty(), "restoring source event id restores edge offer")

	# 11c. Malformed original notice subject_id: historical referral ignored, restored on undo.
	var live_notice: Dictionary = {}
	for ev in restored._state.life.events:
		if ev.get("event_id") == notice.get("event_id"):
			live_notice = ev
			break
	check(not live_notice.is_empty(), "live original notice is found by event id")
	var real_subject: Variant = live_notice.get("subject_id")
	live_notice["subject_id"] = "fictional:wrong"
	check(_referrals(restored, owner).is_empty(), "malformed original subject_id ignores historical referral")
	live_notice["subject_id"] = real_subject
	check(_referrals(restored, owner).size() == 1, "restoring original subject_id restores knowledge")

	# 12. A inactive: historical referral persists, no current capability asserted.
	var saved_position: Array = restored._state.godot.positions[smith].duplicate(true)
	restored._state.godot.positions.erase(smith)
	check(not restored.active_ids().has(smith), "source A is not active after pool removal")
	check(_referrals(restored, owner).size() == 1, "historical referral persists for an inactive source")
	check(_offer_edge(restored, owner, smith).is_empty(), "no edge offer for an inactive source")
	restored._state.godot.positions[smith] = saved_position
	check(restored.active_ids().has(smith), "source A is restored to the active pool")

	# 13. B inactive: historical referral still resolves (does not require referrer active).
	var saved_wood: Array = restored._state.godot.positions[wood].duplicate(true)
	restored._state.godot.positions.erase(wood)
	check(not restored.active_ids().has(wood), "referrer B is not active after pool removal")
	check(_referrals(restored, owner).size() == 1, "historical referral survives referrer B inactive")
	restored._state.godot.positions[wood] = saved_wood
	check(restored.active_ids().has(wood), "referrer B is restored to the active pool")

	# 14. A actual skill removal: history remains, offers gated by current capability.
	var removed_path := "user://fictional-town-skill-referral-removed-%d.json" % Time.get_ticks_usec()
	var removed_world := _anonymous_fixture()
	removed_world.godot.positions["fictional:ember"] = [1.0, 0.0, 0.0]
	var removed_town := _fresh_town(removed_path, removed_world)
	var removed_share := _share_option(removed_town, smith, wood, "metal_repair")
	removed_town.transaction(removed_path, func(): return removed_town.submit_trade(smith, str(removed_share.id), "share-removed", "opengameagent_fixture"))
	var removed_refer := _refer_option(removed_town, wood, owner, smith, "metal_repair")
	removed_town.transaction(removed_path, func(): return removed_town.submit_trade(wood, str(removed_refer.id), "refer-removed", "opengameagent_fixture"))
	removed_town._state.life.skills = removed_town._state.life.skills.filter(func(s): return not (s.get("resident_id") == smith and s.get("skill_id") == "metal_repair"))
	check(not removed_town._has_skill(smith, "metal_repair"), "source A truly lacks the skill after removal")
	check(_referrals(removed_town, owner).size() == 1, "historical referral persists after source skill removal")
	removed_town.release_writer(removed_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(removed_path))

	# 15. C cannot re-refer its indirect hearsay; move C near B so range is not the cause.
	restored.host_move(owner, Vector3(0, 0, 0))
	check(restored.position_of(owner).distance_to(restored.position_of(wood)) < 3.0, "C is actually near B before re-refer check")
	check(_refer_option(restored, owner, wood, smith, "metal_repair").is_empty(), "owner cannot re-refer indirect hearsay to B")
	check(_refer_option(restored, owner, smith, smith, "metal_repair").is_empty(), "owner cannot re-refer indirect hearsay to A")

	# 16. Cold read preserves identities/history/wallets exactly.
	var final_bytes := FileAccess.get_file_as_bytes(path)
	restored.release_writer(path)
	var cold := TownTrade.new()
	check(cold.load_from(path).ok, "final cold load succeeds")
	check(FileAccess.get_file_as_bytes(path) == final_bytes, "final cold read preserves raw file bytes")
	check(cold.snapshot().residents == restored.snapshot().residents, "resident identities preserved")
	check(cold.snapshot().life.items == restored.snapshot().life.items, "items preserved")
	check(cold.snapshot().life.contracts == restored.snapshot().life.contracts, "contracts preserved")
	check(cold.snapshot().life.accounts == restored.snapshot().life.accounts, "material accounts preserved")
	check(cold.snapshot().life.events == restored.snapshot().life.events, "history preserved")
	check(cold.resident(owner).coins_col == restored.resident(owner).coins_col and cold.resident(wood).coins_col == restored.resident(wood).coins_col and cold.resident(smith).coins_col == restored.resident(smith).coins_col, "all wallets preserved")
	check(_referrals(cold, owner).size() == 1 and _notices(cold, wood).size() == 1, "cold reload preserves both direct notice and referral knowledge")

	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_skill_referral", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
