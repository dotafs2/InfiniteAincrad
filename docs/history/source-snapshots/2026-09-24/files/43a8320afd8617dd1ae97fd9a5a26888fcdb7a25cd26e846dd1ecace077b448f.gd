extends SceneTree
## Acceptance gate for production resident-contact projection and dispatch.
## It never calls a paid provider and only mutates explicitly disposable copies.

const TownActions = preload("res://core/town_actions.gd")
const TownTurns = preload("res://agents/town_turns.gd")
const ResidentBrain = preload("res://agents/resident_brain.gd")
const CONTACT_MEMORY_PATH := "res://core/town_contact_memory.gd"
const GARDENER := "shared:gardener"
const WELL_KEEPER := "shared:well-keeper"
const MAX_CONTACTS := 8
const PROMPT_BUDGET_BYTES := 4096

class CapturingBrain:
	extends Node
	var received: Dictionary = {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		received = view.duplicate(true)
		await get_tree().process_frame
		return {"ok": false, "code": "fixture_no_paid_call", "provenance": "opengameagent_fixture"}

var checks := 0
var failures := 0
var contact_memory: Object

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _arg(prefix: String) -> String:
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with(prefix):
			return raw.trim_prefix(prefix)
	return ""

func _direct_events(events: Array, first: String, second: String) -> Array:
	var result: Array = []
	for event in events:
		if event.get("type", "") == "resident_said" and \
				((event.get("actor_id", "") == first and event.get("subject_id", "") == second) or \
				(event.get("actor_id", "") == second and event.get("subject_id", "") == first)):
			result.append(event)
	return result

func _recent_history_mentions_contact(state: Dictionary, resident_id: String,
		counterpart_id: String, event_ids: Array) -> bool:
	var turns: Dictionary = state.get("godot", {}).get("resident_turns", {})
	var record: Dictionary = turns.get(resident_id, {})
	var history: Array = record.get("history", [])
	for decision in history.slice(-6):
		if decision.get("action", "") == "ability:talk:" + counterpart_id:
			return true
		var result: Variant = decision.get("result", {})
		if result is Dictionary and event_ids.has(result.get("event_id", "")):
			return true
	return false

func _project(events: Array, resident_id: String, active: Array, max_contacts: int = MAX_CONTACTS) -> Dictionary:
	if contact_memory == null or not contact_memory.has_method("project"):
		return {"ok": false, "code": "production_api_missing", "contacts": []}
	var result: Variant = contact_memory.call("project", events, resident_id, active, max_contacts)
	return result if result is Dictionary else {"ok": false, "code": "invalid_projection_result", "contacts": []}

func _contact_for(projection: Dictionary, resident_id: String) -> Dictionary:
	for row in projection.get("contacts", []):
		if row.get("resident_id", "") == resident_id:
			return row
	return {}

func _row(event_id: String, seq: Variant, actor: String = GARDENER, subject: String = WELL_KEEPER,
		recipients: Array = [GARDENER, WELL_KEEPER], event_type: String = "resident_said") -> Dictionary:
	return {"event_id": event_id, "seq": seq, "type": event_type, "actor_id": actor,
		"subject_id": subject, "recipient_ids": recipients.duplicate(), "text": "We spoke directly."}

func _statement_for(row: Dictionary, speaker_id: String) -> Dictionary:
	for statement in row.get("latest_direct_statements", []):
		if statement.get("speaker_id", "") == speaker_id:
			return statement
	return {}

func _request_roundtrip(source_path: String, expected_contacts: Variant) -> Dictionary:
	var request_path := source_path + ".request-copy"
	var copied := DirAccess.copy_absolute(source_path, request_path)
	if copied != OK:
		return {"ok": false, "code": "request_copy_failed"}
	var request_town := TownActions.new()
	var load_result: Dictionary = request_town.load_from(request_path)
	if not load_result.get("ok", false):
		return {"ok": false, "code": "request_copy_load_failed"}
	var turns := TownTurns.new()
	root.add_child(turns)
	turns.town = request_town
	turns.save_path = request_path
	var brain := CapturingBrain.new()
	turns.add_child(brain)
	turns.brains[GARDENER] = brain
	var turn_result: Dictionary = await turns.step(GARDENER)
	var received := brain.received.duplicate(true)
	var brain_payload := {"payload": {"resident_view": received}}
	var resident_brain := ResidentBrain.new()
	var bounded_json := resident_brain._bounded_input(brain_payload, received)
	resident_brain.free()
	var decoded: Variant = JSON.parse_string(bounded_json) if not bounded_json.is_empty() else null
	var dispatched: Dictionary = {}
	if decoded is Dictionary:
		dispatched = decoded.get("payload", {}).get("resident_view", {})
	var request_unchanged: bool = dispatched.get("known_contacts", null) == expected_contacts
	var contact_bytes := JSON.stringify(dispatched.get("known_contacts", {})).to_utf8_buffer().size()
	request_town.release_writer(request_path)
	turns.free()
	DirAccess.remove_absolute(request_path)
	return {"ok": turn_result.get("code", "") == "provider_error" and request_unchanged,
		"received": received, "dispatched": dispatched, "contact_bytes": contact_bytes,
		"bounded_json_bytes": bounded_json.to_utf8_buffer().size()}

func run() -> void:
	if ResourceLoader.exists(CONTACT_MEMORY_PATH):
		var api_script: Script = load(CONTACT_MEMORY_PATH)
		if api_script != null and api_script.can_instantiate():
			contact_memory = api_script.new()
	var save_path := _arg("--town-save=")
	check(not save_path.is_empty(), "fixture requires an explicit disposable --town-save copy")
	if save_path.is_empty():
		quit(1)
		return
	var before := FileAccess.get_file_as_bytes(save_path)
	var town := TownActions.new()
	var loaded: Dictionary = town.load_from(save_path)
	check(loaded.get("ok", false), "isolated seq344 copy loads read-only")
	if not loaded.get("ok", false):
		quit(1)
		return
	var state_before: Dictionary = town.snapshot()
	var events: Array = state_before.get("life", {}).get("events", [])
	var pair := _direct_events(events, GARDENER, WELL_KEEPER)
	var expected_seqs: Array[int] = [152, 154, 172]
	var actual_seqs: Array[int] = []
	for event in pair:
		actual_seqs.append(int(event.get("seq", 0)))
	check(actual_seqs == expected_seqs, "seq344 retains the three exact direct Well-keeper/Gardener utterance events")

	var gardener_view: Dictionary = town.resident_view(GARDENER)
	var full_experiences: Array = gardener_view.get("experiences", [])
	var current_tail: Array = full_experiences.slice(-16)
	var no_recent_contact := _direct_events(current_tail, GARDENER, WELL_KEEPER).is_empty()
	check(no_recent_contact,
		"Gardener's actual latest-16 experience page contains no direct Well-keeper contact")
	var no_recent_decision := not _recent_history_mentions_contact(state_before, GARDENER, WELL_KEEPER,
		["life_event_152", "life_event_154", "life_event_172"])
	check(no_recent_decision,
		"Gardener's latest-six decision memory contains no direct Well-keeper contact")
	check(not state_before.get("godot", {}).has("relationships"),
		"the derived projection needs no duplicated canonical relationship namespace")
	check(FileAccess.get_file_as_bytes(save_path) == before, "loading and projecting leaves the disposable save bytes unchanged")

	var active: Array = town.active_ids()
	var original_events := JSON.stringify(events)
	var api_missing := contact_memory == null or not contact_memory.has_method("project")
	check(not api_missing, "production_api_missing: res://core/town_contact_memory.gd with project() is required")
	var gardener_projection: Dictionary = {}
	var keeper_projection: Dictionary = {}
	if not api_missing:
		gardener_projection = _project(events, GARDENER, active)
		keeper_projection = _project(events, WELL_KEEPER, active)
		var gardener_row := _contact_for(gardener_projection, WELL_KEEPER)
		var keeper_row := _contact_for(keeper_projection, GARDENER)
		check(gardener_projection.get("ok", false) and gardener_projection.get("total_contacts", -1) >= gardener_projection.get("contacts", []).size()
			and gardener_projection.get("has_more", null) == (gardener_projection.get("total_contacts", 0) > gardener_projection.get("contacts", []).size())
			and gardener_projection.get("omitted_contact_count", null) == 0
			and gardener_projection.get("omitted_statement_count", null) == 0
			and gardener_projection.get("truncated", null) == false,
			"production API reports complete totals and any byte-cap omissions explicitly")
		var projection_keys := ["ok", "contacts", "total_contacts", "has_more", "truncated",
			"omitted_contact_count", "omitted_statement_count"]
		check(gardener_projection.keys().size() == projection_keys.size(), "projection has explicit bounded-page metadata only")
		for key in gardener_projection.keys():
			check(projection_keys.has(key), "projection excludes uncontracted top-level field: " + str(key))
		check(gardener_row.get("first_contact_seq", 0) == 152 and gardener_row.get("last_contact_seq", 0) == 172
			and gardener_row.get("contact_count", 0) == 3 and gardener_row.get("sent_count", 0) == 1
			and gardener_row.get("received_count", 0) == 2,
			"production Gardener row counts only the three direct utterances with correct direction")
		check(keeper_row.get("sent_count", 0) == 2 and keeper_row.get("received_count", 0) == 1,
			"reciprocal Well-keeper row preserves reverse direction counts")
		var from_gardener := _statement_for(gardener_row, GARDENER)
		var from_ari := _statement_for(gardener_row, WELL_KEEPER)
		check(from_gardener.get("event_id", "") == "life_event_154" and from_gardener.get("seq", 0) == 154
			and from_gardener.get("excerpt", "") == "No, I don't draw water for them. I only watch and try to notice what changes. Have you seen how "
			and from_gardener.get("truncated", false), "Fern's exact bounded quote remains linked to the source event")
		check(from_ari.get("event_id", "") == "life_event_172" and from_ari.get("seq", 0) == 172
			and from_ari.get("excerpt", "") == "Fern, you said you don't draw water for your plants—you only watch. What do you watch for? I'm t"
			and from_ari.get("truncated", false), "Ari's latest direct statement is distinct from Fern's reply")
		var allowed_keys := ["resident_id", "first_contact_seq", "last_contact_seq", "contact_count",
			"sent_count", "received_count", "statement_status", "latest_direct_statements"]
		check(gardener_row.keys().size() == allowed_keys.size(), "contact row exposes only source-linked continuity fields")
		for key in gardener_row.keys():
			check(allowed_keys.has(key), "contact row excludes inferred field: " + str(key))
		check(gardener_row.get("statement_status", "") == "speaker_statement_not_verified_world_fact",
			"utterances remain attributed claims, never established world facts")
		for statement in gardener_row.get("latest_direct_statements", []):
			var statement_keys := ["event_id", "seq", "speaker_id", "excerpt", "truncated"]
			check(statement.keys().size() == statement_keys.size(), "statement excerpt carries only source and truncation fields")
			for key in statement.keys():
				check(statement_keys.has(key), "statement excludes uncontracted attribute: " + str(key))
			check(statement.get("event_id", "") in ["life_event_154", "life_event_172"]
				and statement.get("speaker_id", "") in [GARDENER, WELL_KEEPER]
				and statement.get("excerpt", "").length() <= 96
				and statement.get("truncated", null) == true,
				"each excerpt is short, attributed and source-linked")
		check(JSON.stringify(gardener_projection).to_utf8_buffer().size() <= PROMPT_BUDGET_BYTES,
			"Ari/Fern projection fits the whole 4 KiB UTF-8 budget")
		for resident_id in active:
			var bounded_projection: Dictionary = _project(events, resident_id, active)
			check(bounded_projection.get("contacts", []).size() <= MAX_CONTACTS
				and JSON.stringify(bounded_projection).to_utf8_buffer().size() <= PROMPT_BUDGET_BYTES,
				"each real resident projection respects the contact and byte limits: " + str(resident_id))
		var view_contacts: Dictionary = gardener_view.get("known_contacts", {})
		check(_contact_for(view_contacts, WELL_KEEPER) == gardener_row,
			"resident_view exposes the same derived contact row")
		check(FileAccess.get_file_as_bytes(save_path) == before, "projection leaves the disposable source bytes unchanged")

		# A fresh load must derive the same projection without a persisted side table.
		var cold := TownActions.new()
		var cold_result: Dictionary = cold.load_from(save_path)
		var cold_projection := _project(cold.snapshot().get("life", {}).get("events", []), GARDENER, cold.active_ids())
		check(cold_result.get("ok", false) and cold_projection == gardener_projection,
			"cold restore from the same event log reproduces the exact projection")
		cold.release_writer(save_path)

		var roundtrip := await _request_roundtrip(save_path, view_contacts)
		check(roundtrip.get("ok", false), "TownTurns stubbrain and ResidentBrain prepared request preserve known_contacts without provider calls")
		check(roundtrip.get("contact_bytes", PROMPT_BUDGET_BYTES + 1) <= PROMPT_BUDGET_BYTES,
			"allowlisted contact object remains under the whole-projection budget at request dispatch")
		var provider_source := FileAccess.get_file_as_string("res://agents/BudgetGatewayProvider.cs")
		check(provider_source.contains("\"known_contacts\""),
			"budget gateway's explicit personal-view projection includes the bounded field")

	var synthetic := [
		_row("valid-1", 1), _row("valid-1", 1),
		_row("valid-2", 2, WELL_KEEPER, GARDENER, [WELL_KEEPER, GARDENER]),
		_row("observer-third-party", 3, GARDENER, WELL_KEEPER, [GARDENER, WELL_KEEPER, "shared:healer"]),
		_row("observer-kind", 4, GARDENER, WELL_KEEPER, [GARDENER, WELL_KEEPER], "surroundings_observed"),
		_row("visitor-kind", 5, "visitor:local", GARDENER, ["visitor:local", GARDENER], "visitor_inquiry"),
		_row("self-talk", 6, GARDENER, GARDENER, [GARDENER]),
		_row("bad-recipient", 7, GARDENER, WELL_KEEPER, [GARDENER, "shared:healer"]),
		_row("fractional-seq", 8.5), _row("missing-utterance", 9),
		_row("unknown-actor", 10, "visitor:local", WELL_KEEPER, ["visitor:local", WELL_KEEPER]),
		_row("valid-1", 11)
	]
	synthetic[9].erase("text")
	var synthetic_copy := JSON.stringify(synthetic)
	var synthetic_projection := _project(synthetic, GARDENER, [GARDENER, WELL_KEEPER])
	var synthetic_row := _contact_for(synthetic_projection, WELL_KEEPER)
	if not api_missing:
		check(synthetic_row.get("contact_count", 0) == 2 and synthetic_row.get("first_contact_seq", 0) == 1
			and synthetic_row.get("last_contact_seq", 0) == 2,
			"observers, co-recipients, visitors, invalid sequences, duplicate IDs and malformed utterances are excluded")
		check(synthetic_row.get("latest_direct_statements", []).size() == 2,
			"synthetic pair exposes only the latest direct utterance in each direction")
		check(synthetic_row.get("statement_status", "") == "speaker_statement_not_verified_world_fact",
			"synthetic utterance cannot be elevated to a world fact")
		check(JSON.stringify(synthetic) == synthetic_copy, "synthetic events remain unchanged")
		var nine_people: Array = [GARDENER]
		var many_events: Array = []
		for index in 9:
			var peer := "fixture:peer-%02d" % index
			nine_people.append(peer)
			many_events.append(_row("peer-%02d" % index, index + 1, GARDENER, peer, [GARDENER, peer]))
		var capped := _project(many_events, GARDENER, nine_people, MAX_CONTACTS)
		check(capped.get("contacts", []).size() == MAX_CONTACTS and capped.get("total_contacts", 0) == 9
			and capped.get("has_more", false) and capped.get("omitted_contact_count", 0) == 1
			and capped.get("truncated", false) == false,
			"ninth peer is represented by explicit remaining-contact metadata")
		check(capped.get("contacts", [])[0].get("resident_id", "") == "fixture:peer-08"
			and capped == _project(many_events, GARDENER, nine_people, MAX_CONTACTS),
			"recent rows sort first and repeated projection is deterministic")
		check(JSON.stringify(capped).to_utf8_buffer().size() <= PROMPT_BUDGET_BYTES,
			"synthetic nine-peer contact page respects whole-output UTF-8 cap")
		check(not _project(events, "visitor:local", active).get("ok", false),
			"inactive or visitor identities cannot request a resident contact projection")
	town.release_writer(save_path)

	print(JSON.stringify({"suite": "town_contact_memory_acceptance", "checks": checks,
		"failures": failures, "pair_events": actual_seqs, "production_api_missing": api_missing,
		"production_api_implemented": not api_missing,
		"current_gap_reproduced": actual_seqs == expected_seqs and no_recent_contact and no_recent_decision,
		"source_copy_unchanged": FileAccess.get_file_as_bytes(save_path) == before,
		"paid_calls": 0}))
	quit(0 if failures == 0 else 1)
