extends "res://tests/town_trade_acceptance.gd"

func _initialize() -> void:
	run.call_deferred()

func _share_option(town: TownTrade, speaker: String, recipient: String, skill_id: String) -> Dictionary:
	for option in town.trade_options(speaker):
		if option.get("action") == "share_skill" and option.get("counterparty") == recipient and option.get("_skill_id") == skill_id:
			return option
	return {}

func _notices(town: TownTrade, observer: String) -> Array:
	return town.resident_view(observer).get("known_skill_notices", [])

func _offer_edge(town: TownTrade, owner: String, worker: String) -> Array:
	return town.trade_options(owner).filter(func(o): return o.action == "offer_repair" and o._part == "edge" and o._worker_id == worker)

func run() -> void:
	var path := "user://fictional-town-skill-notice-%d.json" % Time.get_ticks_usec()
	var initial := trade_fixture()
	# Anonymous-role speaker: role hints must not be able to fake a genuine notice.
	for person in initial.residents:
		if person.stable_id == "fictional:forge":
			person.role = "resident"
	_write_fixture(path, initial)
	var town := TownTrade.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "skill-notice fixture loads: " + str(loaded.get("code", "")))
	if not loaded.ok:
		quit(1)
		return
	var owner := "fictional:ember"
	var wood := "fictional:birch"
	var smith := "fictional:forge"

	# Unknown before: nobody has received any notice.
	check(_notices(town, owner).is_empty(), "owner knows no skill notices before any statement")
	check(_notices(town, wood).is_empty(), "carpenter knows no skill notices before any statement")

	# Anonymous-role smith yields no metal_repair offer before any announcement.
	check(_offer_edge(town, owner, smith).is_empty(), "anonymous-role smith yields no metal_repair offer before announcement")

	# Proximity alone must not mutate state or seed knowledge.
	var before_view := town.snapshot()
	var before_view_bytes := FileAccess.get_file_as_bytes(path)
	var _ignored := town.trade_options(owner)
	var _ignored_view := town.resident_view(owner)
	check(town.snapshot() == before_view, "viewing options and views never appends events")
	check(FileAccess.get_file_as_bytes(path) == before_view_bytes, "read-only views and options leave raw save bytes unchanged")
	check(_notices(town, owner).is_empty(), "proximity alone seeds no knowledge")

	# Speaker with an actual owned skill gets a specific share option.
	var smith_share := _share_option(town, smith, owner, "metal_repair")
	check(not smith_share.is_empty(), "actual metal_repair owner gets a specific share option")
	check(str(smith_share.get("_decision", {}).get("text", "")) == "I can repair metal edges.", "share option carries explicit truthful text")

	# Non-skilled person cannot announce.
	check(_share_option(town, owner, smith, "metal_repair").is_empty(), "non-skilled owner cannot announce metal_repair")
	check(_share_option(town, owner, smith, "wood_repair").is_empty(), "non-skilled owner cannot announce wood_repair")

	# Self and far recipients absent.
	check(_share_option(town, smith, smith, "metal_repair").is_empty(), "no self share option")
	town.host_move(wood, Vector3(50, 0, 0))
	check(_share_option(town, smith, wood, "metal_repair").is_empty(), "no far-recipient share option")
	town.host_move(wood, Vector3(1, 0, 0))

	# Successful notice: exact recipients, source/id/text, contractual false.
	var before := town.snapshot()
	var sent := town.transaction(path, func(): return town.submit_trade(smith, str(smith_share.id), "share-metal", "opengameagent_fixture"))
	check(sent.ok, "skill notice is delivered: " + str(sent.get("code", "")))
	var notice: Dictionary = town.snapshot().life.events[-1]
	check(notice.get("type") == "skill_notice", "persisted event is a skill_notice")
	check(notice.get("actor_id") == smith and notice.get("skill_id") == "metal_repair", "notice records speaker and true skill")
	check(notice.get("recipient_ids") == [smith, owner], "notice recipients are exactly speaker and recipient")
	check(notice.get("contractual") == false, "notice is non-contractual")
	check(notice.get("operation_id") == "share-metal" and notice.get("source") == "opengameagent_fixture", "notice carries operation id and provenance")
	check(notice.get("text") == "I can repair metal edges.", "notice carries explicit truthful text")
	check(town.snapshot().life.contracts == before.life.contracts, "notice creates no contract")
	check(town.snapshot().life.accounts == before.life.accounts, "notice spends no material")
	check(town.resident(owner).coins_col == before.residents[0].coins_col, "notice moves no money")

	# Recipient-specific sourced notice; third party cannot see.
	var owner_notices := _notices(town, owner)
	check(owner_notices.size() == 1, "recipient has exactly one known notice")
	check(owner_notices[0].get("actor_id") == smith and owner_notices[0].get("skill_id") == "metal_repair", "known notice attributes speaker and skill")
	check(owner_notices[0].get("source_event_id") == notice.get("event_id") and owner_notices[0].get("seq") == notice.get("seq"), "known notice retains source event id and seq")
	check(owner_notices[0].get("source") == "opengameagent_fixture", "known notice retains provenance")
	check(owner_notices[0].get("text") == "I can repair metal edges.", "known notice retains attributable text")
	check(owner_notices[0].keys().size() == 7 and owner_notices[0].has("actor_id") and owner_notices[0].has("skill_id") and owner_notices[0].has("source_event_id") and owner_notices[0].has("seq") and owner_notices[0].has("source") and owner_notices[0].has("provenance") and owner_notices[0].has("text"), "known notice exposes only the allowed key set")
	check(not owner_notices[0].has("position") and not owner_notices[0].has("current_availability") and not owner_notices[0].has("available"), "known notice injects no position or current availability")
	check(_notices(town, wood).is_empty(), "third party learns nothing")

	# Duplicate no growth; conflicting payload no overwrite.
	var after_notice := town.snapshot()
	var dup := town.submit_trade(smith, str(smith_share.id), "share-metal", "opengameagent_fixture")
	check(dup.duplicate and town.snapshot() == after_notice, "duplicate command does not grow history")
	var conflict := town.submit_trade(smith, str(smith_share.id), "share-metal", "local_rule_policy")
	check(not conflict.ok and town.snapshot() == after_notice, "conflicting payload is rejected without overwrite")

	# Already-shared option unavailable.
	check(_share_option(town, smith, owner, "metal_repair").is_empty(), "already-shared skill option is unavailable")

	# Stale after moving: capture a fresh valid unshared option, then move and reject.
	var fresh := _share_option(town, smith, wood, "metal_repair")
	check(not fresh.is_empty(), "fresh unshared recipient offers a share option")
	town.host_move(wood, Vector3(50, 0, 0))
	var frozen_move := town.snapshot()
	var frozen_move_bytes := FileAccess.get_file_as_bytes(path)
	var stale := town.submit_trade(smith, str(fresh.id), "share-stale", "opengameagent_fixture")
	check(not stale.ok and town.snapshot() == frozen_move, "stale out-of-range share is rejected with no mutation")
	check(FileAccess.get_file_as_bytes(path) == frozen_move_bytes, "rejected out-of-range share leaves raw save bytes unchanged")
	town.host_move(wood, Vector3(1, 0, 0))

	# Stale after skill removal: separate fixture load with the skill removed.
	var removed_path := "user://fictional-town-skill-removed-%d.json" % Time.get_ticks_usec()
	var removed_world := trade_fixture()
	for person in removed_world.residents:
		if person.stable_id == "fictional:forge":
			person.role = "resident"
	removed_world.life.skills = removed_world.life.skills.filter(func(s): return not (s.get("resident_id") == "fictional:forge" and s.get("skill_id") == "metal_repair"))
	_write_fixture(removed_path, removed_world)
	var removed_town := TownTrade.new()
	check(removed_town.load_from(removed_path).ok, "skill-removed fixture loads")
	check(not removed_town._has_skill(smith, "metal_repair"), "removed fixture truly lacks the skill")
	check(_share_option(removed_town, smith, owner, "metal_repair").is_empty(), "no share option without the actual skill")
	var frozen_removed := removed_town.snapshot()
	var removed_bytes := FileAccess.get_file_as_bytes(removed_path)
	var removed_attempt := removed_town.submit_trade(smith, "share-skill:" + owner + ":metal_repair", "share-removed", "opengameagent_fixture")
	check(not removed_attempt.ok and removed_town.snapshot() == frozen_removed, "share after skill removal is rejected with no mutation")
	check(FileAccess.get_file_as_bytes(removed_path) == removed_bytes, "rejected skill-removed share leaves disk bytes unchanged")
	removed_town.release_writer(removed_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(removed_path))

	# Separation is persisted explicitly, then reloaded as the same world.
	# The transaction lambda must perform the host move and then return an actual Dictionary result.
	var separated := town.transaction(path, func():
		town.host_move(smith, Vector3(80, 0, 0))
		return {"ok": true, "code": "host_move_applied"})
	check(separated.ok, "host move transaction reports ok: " + str(separated.get("code", "")))
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := TownTrade.new()
	check(restored.load_from(path).ok, "cold load succeeds")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold read does not rewrite save bytes")
	check(restored.position_of(smith).distance_to(restored.position_of(owner)) > 3.0, "separation persisted across reload")
	var restored_notices := _notices(restored, owner)
	check(restored_notices.size() == 1 and restored_notices[0].get("skill_id") == "metal_repair", "known notice survives separation and reload")
	check(restored_notices[0].get("source_event_id") == notice.get("event_id"), "known notice keeps its source event id after reload")
	check(_offer_edge(restored, owner, smith).is_empty(), "no remote repair offer while separated")

	# Actual skill-based repair offer appears after learned notice + back in range.
	restored.host_move(smith, Vector3(2, 0, 0))
	check(not _offer_edge(restored, owner, smith).is_empty(), "learned notice plus proximity yields a real repair offer")

	# Cold read preserves raw bytes and identities/history/items/contracts/wallets/material.
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

	# Optional freeform speech: canonical truthful declaration is persisted; speech is attributed separately.
	var speech_path := "user://fictional-town-skill-speech-%d.json" % Time.get_ticks_usec()
	var speech_world := trade_fixture()
	for person in speech_world.residents:
		if person.stable_id == "fictional:forge":
			person.role = "resident"
	_write_fixture(speech_path, speech_world)
	var speech_town := TownTrade.new()
	check(speech_town.load_from(speech_path).ok, "freeform-speech fixture loads")
	check(not speech_town._has_skill(smith, "wood_repair"), "smith truly lacks wood_repair")
	var speech_share := _share_option(speech_town, smith, wood, "metal_repair")
	check(not speech_share.is_empty(), "smith has a genuine metal_repair share option")
	var speech_before := speech_town.snapshot()
	var speech_bytes := FileAccess.get_file_as_bytes(speech_path)
	var spoken := speech_town.transaction(speech_path, func(): return speech_town.submit_trade(smith, str(speech_share.id), "share-speech", "opengameagent_fixture", "I can repair wooden handles too"))
	check(spoken.ok, "freeform-speech notice is delivered: " + str(spoken.get("code", "")))
	var speech_event: Dictionary = speech_town.snapshot().life.events[-1]
	check(speech_event.get("type") == "skill_notice" and speech_event.get("skill_id") == "metal_repair", "freeform speech does not change the declared skill")
	check(speech_event.get("text") == "I can repair metal edges.", "canonical truthful declaration is persisted, not the freeform speech")
	check(speech_event.get("speech") == "I can repair wooden handles too", "freeform speech is attributed separately on the event")
	check(speech_event.get("recipient_ids") == [smith, wood], "freeform notice recipients are exactly speaker and recipient")
	check(speech_town.snapshot().life.contracts == speech_before.life.contracts, "freeform notice creates no contract")
	check(speech_town.snapshot().life.accounts == speech_before.life.accounts, "freeform notice spends no material")
	check(speech_town.snapshot().life.items == speech_before.life.items, "freeform notice mutates no item")
	var speech_wallets_unchanged := true
	for person in speech_before.residents:
		if speech_town.resident(person.stable_id).coins_col != person.coins_col:
			speech_wallets_unchanged = false
	check(speech_wallets_unchanged, "freeform notice moves no money for any resident")
	var speech_notices := _notices(speech_town, wood)
	check(speech_notices.size() == 1 and speech_notices[0].get("skill_id") == "metal_repair", "recipient learns only the actual metal skill notice")
	check(speech_notices[0].get("text") == "I can repair metal edges.", "known notice keeps the canonical truthful text")
	var wood_skills_before: Array = speech_before.life.skills.filter(func(s): return s.get("resident_id") == wood)
	var wood_skills_after: Array = speech_town.snapshot().life.skills.filter(func(s): return s.get("resident_id") == wood)
	check(wood_skills_after == wood_skills_before, "recipient's own structured skills are unchanged by the notice")
	var wood_claim_notices := speech_notices.filter(func(n): return n.get("skill_id") == "wood_repair")
	check(wood_claim_notices.is_empty(), "no known notice claims the recipient learned wood_repair")
	var all_notices_metal_only := true
	for n in speech_notices:
		if n.get("actor_id") != smith or n.get("skill_id") != "metal_repair":
			all_notices_metal_only = false
	check(all_notices_metal_only, "all learned notices are from smith and concern only the metal skill")
	check(FileAccess.get_file_as_bytes(speech_path) != speech_bytes, "accepted freeform notice is persisted to disk")
	speech_town.release_writer(speech_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(speech_path))

	# Historical source projection: an inactive known speaker's notice persists without current availability.
	var inactive_path := "user://fictional-town-skill-inactive-%d.json" % Time.get_ticks_usec()
	var inactive_world := trade_fixture()
	for person in inactive_world.residents:
		if person.stable_id == "fictional:forge":
			person.role = "resident"
	_write_fixture(inactive_path, inactive_world)
	var inactive_town := TownTrade.new()
	check(inactive_town.load_from(inactive_path).ok, "inactive-speaker fixture loads")
	var inactive_share := _share_option(inactive_town, smith, owner, "metal_repair")
	check(not inactive_share.is_empty(), "inactive-speaker fixture offers a genuine share option")
	var inactive_sent := inactive_town.transaction(inactive_path, func(): return inactive_town.submit_trade(smith, str(inactive_share.id), "share-inactive", "opengameagent_fixture"))
	check(inactive_sent.ok, "inactive-speaker notice is delivered: " + str(inactive_sent.get("code", "")))
	var inactive_notice: Dictionary = inactive_town.snapshot().life.events[-1]
	check(inactive_notice.get("type") == "skill_notice" and inactive_notice.get("actor_id") == smith, "inactive-speaker notice records the speaker")
	# Remove the speaker from the active pool within this test only, then restore.
	# Mutate the actual state dictionary (not a snapshot deepcopy) so active_ids() observes it.
	var saved_position: Array = inactive_town._state.godot.positions[smith].duplicate(true)
	inactive_town._state.godot.positions.erase(smith)
	check(not inactive_town.active_ids().has(smith), "speaker is not active after pool removal")
	var inactive_notices := _notices(inactive_town, owner)
	check(inactive_notices.size() == 1 and inactive_notices[0].get("actor_id") == smith, "historical notice persists for an inactive known speaker")
	check(inactive_notices[0].get("skill_id") == "metal_repair" and inactive_notices[0].get("source_event_id") == inactive_notice.get("event_id"), "inactive-speaker notice keeps skill and source event id")
	check(_share_option(inactive_town, smith, owner, "metal_repair").is_empty(), "no skill options are offered for an inactive speaker")
	inactive_town._state.godot.positions[smith] = saved_position
	check(inactive_town.active_ids().has(smith), "speaker is restored to the active pool")
	inactive_town.release_writer(inactive_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(inactive_path))

	# Busy recipient near canhear: a real pending start_action is not forced into a response or job change.
	var busy_path := "user://fictional-town-skill-busy-%d.json" % Time.get_ticks_usec()
	_write_fixture(busy_path, trade_fixture())
	var busy_town := TownTrade.new()
	check(busy_town.load_from(busy_path).ok, "busy-recipient fixture loads")
	var busy_started := busy_town.start_action(owner, "rest", "busy-rest", "opengameagent_fixture")
	check(busy_started.ok, "recipient actually starts a pending action: " + str(busy_started.get("code", "")))
	check(not busy_town.pending_job(owner).is_empty(), "recipient has a real pending job, not a faked busy flag")
	var busy_before := busy_town.snapshot()
	var busy_share := _share_option(busy_town, smith, owner, "metal_repair")
	check(not busy_share.is_empty(), "busy recipient still yields a share option near canhear")
	var busy_sent := busy_town.transaction(busy_path, func(): return busy_town.submit_trade(smith, str(busy_share.id), "share-busy", "opengameagent_fixture"))
	check(busy_sent.ok, "notice to a busy recipient is delivered: " + str(busy_sent.get("code", "")))
	check(busy_town.pending_job(owner).get("command_id") == "busy-rest", "busy recipient's pending job is unchanged by the notice")
	check(busy_town.snapshot().godot.pending.has(owner), "busy recipient is not forced out of its pending action")
	check(busy_town.snapshot().life.contracts == busy_before.life.contracts, "notice to a busy recipient creates no contract")
	busy_town.release_writer(busy_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(busy_path))

	# Existing role hints unchanged: a role-keyword resident still exposes hints.
	var hint_path := "user://fictional-town-skill-hint-%d.json" % Time.get_ticks_usec()
	_write_fixture(hint_path, trade_fixture())
	var hint_town := TownTrade.new()
	check(hint_town.load_from(hint_path).ok, "role-hint fixture loads")
	check(hint_town._public_skills(owner, smith).has("metal_repair"), "existing role hint for metal smith is unchanged")
	hint_town.release_writer(hint_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hint_path))

	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_skill_notice", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
