extends RefCounted
## Pure presentation for public life evidence. It never infers a successful outcome
## from an admitted command or turns a physical event's explanatory text into speech.

const MATERIAL_SHARED := "material_location_shared"
const MATERIAL_HANDED_OVER := "material_handed_over"
const SELF_REPAIR_STARTED := "self_repair_started"
const SELF_REPAIR_COMPLETED := "self_repair_completed"
const SELF_REPAIR_BLOCKED := "self_repair_blocked"
const SELF_REPAIR_UNAVAILABLE := "self_repair_unavailable"
const SELF_REPAIR_EVENTS := [SELF_REPAIR_STARTED, SELF_REPAIR_COMPLETED,
	SELF_REPAIR_BLOCKED, SELF_REPAIR_UNAVAILABLE]

func self_repair_activity(job: Dictionary, moving: bool) -> String:
	if str(job.get("action", "")) != "self_repair":
		return ""
	var part := _part_label(str(job.get("part", "")))
	var duration := maxf(0.0, float(job.get("duration_seconds", 0.0)))
	var elapsed := clampf(float(job.get("elapsed", 0.0)), 0.0, duration)
	if elapsed > 0.0:
		return "Own-tool repair in progress - %s - work %s/%s s" % [part, _seconds(elapsed), _seconds(duration)]
	var travel := " - walking to work point" if moving else ""
	return "Own-tool repair commanded%s - work 0/%s s" % [travel, _seconds(duration)]

func event_feed_line(event: Dictionary, source_label: String, names: Dictionary) -> String:
	var kind := str(event.get("type", ""))
	if kind not in [MATERIAL_SHARED, MATERIAL_HANDED_OVER] and kind not in SELF_REPAIR_EVENTS:
		return ""
	var seq := int(event.get("seq", -1))
	var actor_id := str(event.get("actor_id", ""))
	var actor_name := _name(names, actor_id)
	var prefix := "[%s - #%d] %s" % [source_label, seq, actor_name]
	if kind == MATERIAL_SHARED:
		var subject_name := _name(names, str(event.get("subject_id", "")))
		var words := _one_line(str(event.get("text", event.get("speech", ""))))
		if words.length() > 96:
			words = words.left(96) + "..."
		var spoken := "" if words.is_empty() else ": \"%s\"" % words
		return "%s told %s a material route (spoken; stock unverified; no goods transferred)%s" % [prefix, subject_name, spoken]
	if kind == MATERIAL_HANDED_OVER:
		var subject_name := _name(names, str(event.get("subject_id", "")))
		return "%s gave %s %s to %s (gift completed in person; no payment or debt)" % [prefix,
			_quantity(event), str(event.get("material", "material")), subject_name]
	var part := _part_label(str(event.get("part", "")))
	if kind == SELF_REPAIR_STARTED:
		return "%s - Own-tool repair commanded - %s; no repair or material spent yet" % [prefix, part]
	if kind == SELF_REPAIR_COMPLETED:
		return "%s - Own-tool repair completed - %s; used %d %s" % [prefix, part,
			int(event.get("consumed", 0)), str(event.get("material", "material"))]
	var reason := "could not reach the work point" if kind == SELF_REPAIR_BLOCKED else "prerequisites changed"
	return "%s - Own-tool repair failed / unfinished - %s; %s; consumed %d" % [prefix, part,
		reason, int(event.get("consumed", 0))]

func resident_event_notes(events: Array, resident_id: String, names: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var found := {"route": false, "gift": false, "repair": false}
	for offset in range(1, events.size() + 1):
		var candidate: Variant = events[events.size() - offset]
		if not candidate is Dictionary:
			continue
		var event: Dictionary = candidate
		var kind := str(event.get("type", ""))
		var category := "route" if kind == MATERIAL_SHARED else ("gift" if kind == MATERIAL_HANDED_OVER else ("repair" if kind in SELF_REPAIR_EVENTS else ""))
		if category.is_empty() or found[category]:
			continue
		var actor_id := str(event.get("actor_id", ""))
		var seq := int(event.get("seq", -1))
		if kind == MATERIAL_SHARED:
			var subject_id := str(event.get("subject_id", ""))
			if actor_id == resident_id:
				result.append("Route #%d: shared with %s (stock unverified)" % [seq, _name(names, subject_id)])
			elif subject_id == resident_id:
				result.append("Route #%d: received from %s (stock unverified)" % [seq, _name(names, actor_id)])
			else:
				continue
		if kind == MATERIAL_HANDED_OVER:
			var subject_id := str(event.get("subject_id", ""))
			var item := "%s %s" % [_quantity(event), str(event.get("material", "material"))]
			if actor_id == resident_id:
				result.append("Gift #%d: gave %s to %s" % [seq, item, _name(names, subject_id)])
			elif subject_id == resident_id:
				result.append("Gift #%d: received %s from %s" % [seq, item, _name(names, actor_id)])
			else:
				continue
		if kind in SELF_REPAIR_EVENTS:
			if actor_id != resident_id:
				continue
			var part := _part_label(str(event.get("part", "")))
			if kind == SELF_REPAIR_STARTED:
				result.append("Repair #%d: commanded - %s" % [seq, part])
			elif kind == SELF_REPAIR_COMPLETED:
				result.append("Repair #%d: completed - %s" % [seq, part])
			else:
				result.append("Repair #%d: failed / unfinished - %s" % [seq, part])
		found[category] = true
		if found.route and found.gift and found.repair:
			break
	return result

func _part_label(part: String) -> String:
	return "axe " + part if part in ["edge", "handle"] else "own axe"

func _name(names: Dictionary, id: String) -> String:
	return str(names.get(id, id if not id.is_empty() else "unknown resident"))

func _seconds(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value)

func _quantity(event: Dictionary) -> String:
	var quantity := int(event.get("quantity", 0))
	return "%d unit of" % quantity if quantity == 1 else "%d units of" % quantity

func _one_line(value: String) -> String:
	return value.strip_edges().replace("\r", " ").replace("\n", " ")
