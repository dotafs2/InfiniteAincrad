extends SceneTree

const Presentation = preload("res://spatial/town_life_presentation.gd")

var checks := 0
var failures := 0
var view := Presentation.new()
var names := {"resident:ari": "Ari", "resident:wren": "Wren", "resident:rowan": "Rowan"}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _init() -> void:
	var commanded := {"action": "self_repair", "part": "handle", "duration_seconds": 60.0, "elapsed": 0.0}
	check(view.self_repair_activity(commanded, true) == "Own-tool repair commanded - walking to work point - work 0/60 s",
		"admission is presented as commanded travel, never completion")
	check(view.self_repair_activity(commanded, false) == "Own-tool repair commanded - work 0/60 s",
		"admitted stationary work remains explicitly at zero progress")
	var working := commanded.duplicate(true)
	working.elapsed = 14.5
	check(view.self_repair_activity(working, false) == "Own-tool repair in progress - axe handle - work 14.5/60 s",
		"recorded labor is presented as in progress with bounded progress")
	check(view.self_repair_activity({"action": "approach"}, true).is_empty(),
		"the helper leaves unrelated activities to the established presentation")

	var shared := {"seq": 41, "type": "material_location_shared", "actor_id": "resident:ari",
		"subject_id": "resident:wren", "text": "I can tell you this route: east gate; current stock is unknown.",
		"reason": "PRIVATE_REASON_SENTINEL"}
	var line := view.event_feed_line(shared, "Past AI", names)
	check(line.contains("Ari told Wren") and line.contains("spoken") and line.contains("stock unverified"),
		"route speech identifies speaker, listener and its unverified-stock boundary")
	check(not line.contains("PRIVATE_REASON_SENTINEL"), "private deliberation is never rendered")
	check(view.resident_event_notes([shared], "resident:ari", names) == ["Route #41: shared with Wren (stock unverified)"],
		"speaker roster row attributes the latest route action")
	check(view.resident_event_notes([shared], "resident:wren", names) == ["Route #41: received from Ari (stock unverified)"],
		"listener roster row attributes the received knowledge without claiming stock")
	var gift := {"seq": 42, "type": "material_handed_over", "actor_id": "resident:wren",
		"subject_id": "resident:rowan", "material": "wood", "quantity": 1,
		"text": "Wren gave 1 unit of wood to Rowan in person.", "reason": "PRIVATE_GIFT_REASON"}
	line = view.event_feed_line(gift, "Current AI", names)
	check(line.contains("Wren gave 1 unit of wood to Rowan") and line.contains("gift completed in person")
		and line.contains("no payment or debt"), "material gift displays the exact donor, recipient, quantity and completed status")
	check(not line.contains("PRIVATE_GIFT_REASON") and not line.contains("\"Wren gave"),
		"physical handoff is not rendered as speech or private reasoning")
	check(view.resident_event_notes([gift], "resident:wren", names) == ["Gift #42: gave 1 unit of wood to Rowan"],
		"donor roster row identifies the completed gift")
	check(view.resident_event_notes([gift], "resident:rowan", names) == ["Gift #42: received 1 unit of wood from Wren"],
		"recipient roster row identifies the completed gift")

	var started := {"seq": 43, "type": "self_repair_started", "actor_id": "resident:rowan",
		"part": "handle", "material": "wood", "text": "I completed it in my private thoughts."}
	line = view.event_feed_line(started, "Current AI", names)
	check(line.contains("Own-tool repair commanded") and line.contains("no repair or material spent yet"),
		"start evidence is an admitted command rather than imagined success")
	check(not line.contains("completed it in my private thoughts"), "physical event text is not displayed as resident speech")
	var completed := {"seq": 44, "type": "self_repair_completed", "actor_id": "resident:rowan",
		"part": "handle", "material": "wood", "consumed": 1}
	line = view.event_feed_line(completed, "Current AI", names)
	check(line.contains("Own-tool repair completed") and line.contains("used 1 wood"),
		"terminal success displays only recorded completion and consumption")
	check(view.resident_event_notes([started, completed], "resident:rowan", names) == ["Repair #44: completed - axe handle"],
		"latest terminal outcome replaces the earlier commanded roster note")
	check(view.resident_event_notes([shared, gift, completed], "resident:rowan", names) == [
		"Repair #44: completed - axe handle", "Gift #42: received 1 unit of wood from Wren"],
		"a later category does not hide another attributable outcome from the resident row")

	var blocked := {"seq": 45, "type": "self_repair_blocked", "actor_id": "resident:rowan",
		"part": "handle", "material": "wood", "consumed": 0}
	line = view.event_feed_line(blocked, "Current world", names)
	check(line.contains("failed / unfinished") and line.contains("could not reach") and line.contains("consumed 0"),
		"blocked travel remains a failed unfinished outcome")
	var unavailable := blocked.duplicate(true)
	unavailable.seq = 46
	unavailable.type = "self_repair_unavailable"
	line = view.event_feed_line(unavailable, "Current world", names)
	check(line.contains("prerequisites changed") and not line.contains("completed"),
		"lost prerequisites cannot be presented as completion")

	print(JSON.stringify({"suite": "town_life_presentation", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
