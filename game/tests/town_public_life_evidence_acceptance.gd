extends "res://tests/town_trade_acceptance.gd"

# Offline acceptance for the bounded PUBLIC LIFE EVENT projection in game/core/town_runtime.gd.
# Explicitly labelled fixture: a scripted controller supplies the words and a sentinel private
# reason, no model is called, and a green result is NOT real GM autonomy. It proves only that
# ACTUALLY DELIVERED public speech enters the GM snapshot while undelivered speech, unsupported
# event types and the private deliberation reason never do.

const Turns = preload("res://agents/town_turns.gd")
const Runtime = preload("res://core/town_runtime.gd")

const DELIVERED_SPEECH := "我想找一位愿意教我烤面包的师傅。"
const UNDELIVERED_SPEECH := "这段话不该被任何接收者听到。"
const PRIVATE_REASON_SENTINEL := "PRIVATE_REASON_SENTINEL"
const SYNTHETIC_TEXT := "SYNTHETIC_UNSUPPORTED_EVENT_TEXT"

class Speaker extends Node:
	var turns
	var target_option_id := ""
	var words := ""
	var command := "fixture-life-evidence"
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var offered: Dictionary = turns._record(view.identity.id).offered_actions
		var action := ""
		for key in offered:
			if offered[key] == target_option_id:
				action = key
		return {"ok": true, "command_id": command, "provenance": "opengameagent_fixture",
			"decision": {"action": action, "reason": "PRIVATE_REASON_SENTINEL", "speech": words}}

func _load_runtime(path: String) -> RefCounted:
	var town := Runtime.new()
	check(town.load_from(path).ok, "fictional runtime fixture loads")
	return town
func _public_life_events(entries: Array) -> Array:
	var found: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("evidence_kind", "") == "public_life_event":
			found.append(entry)
	return found

func _delivered_turn(town, path: String, id: String, target: String, words: String, command: String) -> void:
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	var brain := Speaker.new()
	brain.turns = turns
	brain.target_option_id = "ask:" + target
	brain.words = words
	brain.command = command
	check(turns.connect_controller(id, brain, "fixture:life-evidence").ok, "speech controller attaches")
	check((await turns.step(id)).ok, "delivered public ask is accepted")

func run() -> void:
	var path := "user://public-life-evidence-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town = _load_runtime(path)
	var owner := "fictional:ember"
	var wood := "fictional:birch"

	# 1. ACTUALLY DELIVERED public speech enters the snapshot with immutable identity.
	await _delivered_turn(town, path, owner, wood, DELIVERED_SPEECH, "fixture-delivered")
	var events: Array = town.snapshot().life.events
	var delivered_event: Dictionary = events[-1]
	check(delivered_event.get("type", "") == "ask_help", "delivered ask keeps its authoritative type")
	check(delivered_event.get("text", "") == DELIVERED_SPEECH, "delivered event carries the resident own words")
	var delivered_id := str(delivered_event.get("event_id", ""))
	var delivered_seq := int(delivered_event.get("seq", 0))
	var delivered_request := str(delivered_event.get("request_id", ""))
	check(not delivered_id.is_empty() and delivered_seq > 0, "delivered event has an immutable id and sequence")
	check(not delivered_request.is_empty(), "delivered ask carries its original request reference")

	var snapshot: Dictionary = town.background_gm_snapshot()
	check(snapshot.get("kind", "") == "background_gm_evidence_snapshot", "snapshot keeps its existing kind")
	var projected := _public_life_events(snapshot.evidence)
	check(projected.size() == 1, "exactly the delivered public event is projected")
	var entry: Dictionary = projected[0]
	check(entry.get("delivered_text", "") == DELIVERED_SPEECH, "snapshot carries the actually delivered text")
	check(entry.get("event_id", "") == delivered_id and int(entry.get("seq", 0)) == delivered_seq, "immutable event id and world sequence are preserved")
	check(entry.get("world_id", "") == town.snapshot().world_id, "projection is bound to the world id")
	check(entry.get("speaker_id", "") == owner, "delivered speaker is authoritative")
	check(entry.get("recipient_ids", []).has(wood), "delivered recipients are authoritative")
	check(entry.get("request_ref", "") == delivered_request, "original request reference is preserved")
	check(entry.get("status", "") == "observed", "delivered words are labelled observed")
	check(not entry.get("discriminators", {}).has("aspiration_stated"), "no wish semantics are asserted for a delivered utterance")
	check(entry.get("event_source", "") == "opengameagent_fixture", "authoritative event source is carried")
	check(not entry.get("discriminators", {}).get("missing_mechanism_proved", true), "aspiration is not a proven missing mechanism")
	check(not entry.get("discriminators", {}).get("achieved_capability", true), "aspiration is not an achieved capability")
	check(not entry.get("discriminators", {}).get("invented_need", true), "aspiration is not an invented need")

	# 2. The private reply reason and private accepted reply never leak.
	check(not JSON.stringify(snapshot).contains(PRIVATE_REASON_SENTINEL), "private reply reason never enters the snapshot")
	check(not JSON.stringify(snapshot).contains("accepted_reply"), "private accepted reply never enters the snapshot")

	# 3. Read-only and stable: projecting changes no world state and fabricates nothing.
	var before: Dictionary = town.snapshot()
	var again: Dictionary = town.background_gm_snapshot()
	check(town.snapshot() == before, "projection mutates no world state")
	check(again.proposals.is_empty(), "no capability proposal is fabricated from delivered words")
	check(not JSON.stringify(again).contains("capability_id"), "no capability id is fabricated")
	var again_entries := _public_life_events(again.evidence)
	check(again_entries.size() == 1 and again_entries[0].get("event_id", "") == delivered_id, "re-projection is stable and id-stable")
	check(again.source_revision.life_seq == snapshot.source_revision.life_seq, "source revision is stable")

	# 4. Optional speech on an action that cannot deliver it never becomes a public life event.
	var refused: Dictionary = town.submit_trade(owner, "wait", "wait-undelivered", "opengameagent_fixture", UNDELIVERED_SPEECH)
	check(not refused.ok, "speech on a non-delivering action is refused")
	check(not JSON.stringify(town.background_gm_snapshot()).contains(UNDELIVERED_SPEECH), "undelivered accepted speech never enters the snapshot")
	check(_public_life_events(town.background_gm_snapshot().evidence).size() == 1, "a refused delivery adds no public life event")

	# 5. Unsupported event types and empty text are never projected (allowlist, not a dump).
	town._state.life.events.append({"type": "place_learned", "actor_id": owner, "subject_id": owner,
		"recipient_ids": [owner], "event_id": "life_event_synthetic_unsupported", "seq": 9001, "text": SYNTHETIC_TEXT})
	town._state.life.events.append({"type": "ask_help", "actor_id": owner, "subject_id": wood,
		"recipient_ids": [owner, wood], "event_id": "life_event_synthetic_empty", "seq": 9002, "text": "   "})
	check(_public_life_events(town.background_gm_snapshot().evidence).size() == 1, "only allowlisted, non-empty delivered events are projected")
	check(not JSON.stringify(town.background_gm_snapshot()).contains(SYNTHETIC_TEXT), "unsupported event text is never dumped")

	# 6. A normal refusal reply is projected as neutral delivered words, never as a wish or a need.
	var refusal_text := "\u6211\u73b0\u5728\u5e2e\u4e0d\u4e0a\u5fd9\uff0c\u4f60\u95ee\u95ee\u522b\u4eba\u5427\u3002"
	# The delivered reply goes through the world authoritative communicate() path (the same one the
	# turn adapter uses), so the refusal is a real delivered public event on the open request.
	var refusal: Dictionary = town.communicate(wood, {"action": "reply_help", "recipient_id": owner,
		"text": refusal_text, "request_id": delivered_request, "choice": "unavailable"}, "fixture-refusal", "opengameagent_fixture")
	check(refusal.ok, "a delivered refusal reply is accepted")
	var refusal_entry: Dictionary = {}
	for item in _public_life_events(town.background_gm_snapshot().evidence):
		if item.get("event_type", "") == "reply_help" and item.get("delivered_text", "") == refusal_text:
			refusal_entry = item
	check(not refusal_entry.is_empty(), "the delivered refusal is projected")
	check(refusal_entry.get("status", "") == "observed", "the refusal is labelled observed, not a wish")
	check(not refusal_entry.get("discriminators", {}).has("aspiration_stated"), "the refusal carries no wish semantics")
	check(not refusal_entry.get("discriminators", {}).get("missing_mechanism_proved", true), "the refusal proves no missing mechanism")
	check(not refusal_entry.get("discriminators", {}).get("invented_need", true), "the refusal invents no need")

	# 7. H70 regression: background_gm_content_signature must survive entries that have NO
	# physical_facts (public_life_event), stay stable for unchanged content, keep ignoring
	# physical_facts.no_progress_seconds, and never inject a fake physical_facts object.
	var export_path := "user://public-life-signature-%d.json" % Time.get_ticks_usec()
	var signature: String = town.background_gm_content_signature()
	check(not signature.is_empty(), "content signature is non-empty")
	check(town.background_gm_content_signature() == signature, "content signature is stable for unchanged content")
	var signature_payload: Variant = JSON.parse_string(signature)
	var signature_evidence: Array = signature_payload.get("evidence", []) if signature_payload is Dictionary else []
	var public_in_signature := 0
	for item in signature_evidence:
		if not item is Dictionary:
			continue
		if item.get("evidence_kind", "") == "public_life_event":
			public_in_signature += 1
			check(not item.has("physical_facts"), "no fake physical_facts object is injected for a public life event")
		elif item.has("physical_facts"):
			check(not item.physical_facts.has("no_progress_seconds"), "physical_facts.no_progress_seconds stays excluded from the signature")
	check(public_in_signature >= 1, "the delivered public events are part of the signature payload")
	var first_write: Dictionary = town.maybe_write_background_gm_snapshot(export_path)
	check(first_write.get("ok", false), "the first export of changed content succeeds")
	var second_write: Dictionary = town.maybe_write_background_gm_snapshot(export_path)
	check(second_write.get("ok", false) and second_write.get("code", "") == "gm_export_unchanged",
		"unchanged content exports as gm_export_unchanged with no error and no per-frame retry")
	# a NEW delivered public event changes the signature, and the changed content is written again
	var signature_before_event: String = town.background_gm_content_signature()
	town._state.life.events.append({"type": "reply_help", "actor_id": owner, "subject_id": wood,
		"recipient_ids": [owner, wood], "event_id": "life_event_synthetic_signature", "seq": 9100,
		"text": SYNTHETIC_TEXT + "_signature", "source": "opengameagent_fixture", "request_id": delivered_request})
	var signature_after_event: String = town.background_gm_content_signature()
	check(signature_after_event != signature_before_event, "a new delivered event changes the signature")
	var third_write: Dictionary = town.maybe_write_background_gm_snapshot(export_path)
	check(third_write.get("ok", false) and third_write.get("code", "") != "gm_export_unchanged",
		"changed content is written again instead of being reported unchanged")
	# the SAME event with different delivered text must change the signature too
	town._state.life.events[-1].text = SYNTHETIC_TEXT + "_signature_changed"
	check(town.background_gm_content_signature() != signature_after_event, "delivered text change is reflected in the signature")
	# malformed optional shape must not crash the signature
	town._state.life.events.append({"type": "ask_help", "actor_id": owner, "event_id": "life_event_synthetic_no_recipients",
		"seq": 9200, "text": SYNTHETIC_TEXT + "_no_recipients"})
	check(not town.background_gm_content_signature().is_empty(), "a malformed optional shape does not crash the signature")
	check(town.maybe_write_background_gm_snapshot(export_path).get("ok", true), "export still works after a malformed optional shape")
	print(JSON.stringify({"suite": "town_public_life_evidence", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
