extends RefCounted
## Versioned, monotonic access to authored playable worlds. General high scores
## prove legacy play; only completed-round scores satisfy new score gates.
const SCHEMA := 1
const IDS: Array[String] = ["city", "food", "toys", "frost"]
const NAMES := {"city":"Sunny City", "food":"Snack Garden", "toys":"Bubble Toy Town", "frost":"Frostlight Village"}
const GATES := {
	"food":{"map":"city", "score":1, "condition":"Finish Sunny City"},
	"toys":{"map":"food", "score":200, "condition":"Score 200 in Snack Garden"},
	"frost":{"map":"toys", "score":300, "condition":"Score 300 in Bubble Toy Town"},
}

static func available_ids() -> Array[String]:
	return IDS.duplicate()

static func nonnegative_score(value: Variant) -> int:
	if value is int:
		return maxi(0, value)
	if value is float and is_finite(value):
		return maxi(0, int(minf(value, 9223372036854774784.0)))
	return 0

static func clean_scores(raw: Variant) -> Dictionary:
	var result := {}
	for id in IDS:
		result[id] = nonnegative_score(raw.get(id, 0)) if raw is Dictionary else 0
	return result

static func clean_ids(raw: Variant) -> Array[String]:
	# An earned later world also retains the earlier path. Return one stable,
	# duplicate-free order and never admit future/unknown catalog IDs.
	var highest := 0
	if raw is Array or raw is PackedStringArray:
		for id in raw:
			if id is String or id is StringName:
				highest = maxi(highest, IDS.find(str(id)))
	var result: Array[String] = []
	for index in highest + 1:
		result.append(IDS[index])
	return result

static func advance(raw_ids: Variant, raw_completed_scores: Variant) -> Array[String]:
	var unlocked := clean_ids(raw_ids)
	var completed := clean_scores(raw_completed_scores)
	for id in IDS:
		if not GATES.has(id):
			continue
		var gate: Dictionary = GATES[id]
		if unlocked.has(str(gate.map)) and int(completed[gate.map]) >= int(gate.score) and not unlocked.has(id):
			unlocked.append(id)
	return clean_ids(unlocked)

static func restore(schema: int, saved_ids: Variant, saved_completed: Variant, legacy_best: Variant, receipts: Variant) -> Dictionary:
	var unlocked := clean_ids(saved_ids)
	var completed := clean_scores(saved_completed)
	if schema < SCHEMA:
		# Neither the selected thumbnail nor aggregate stage/run counters prove
		# which map was played. Positive bests or valid settled receipts do.
		var played := clean_scores(legacy_best)
		for id in IDS:
			if int(played[id]) > 0:
				unlocked.append(id)
		if receipts is Dictionary:
			for key in receipts:
				var receipt: Variant = receipts[key]
				if not key is String or not receipt is Dictionary:
					continue
				var id := str(receipt.get("map", ""))
				if receipt.get("id", "") != key or not IDS.has(id):
					continue
				var settled: Variant = receipt.get("settled", false)
				var base_coins: Variant = receipt.get("base_coins", -1)
				if not settled is bool or not settled or not base_coins is int or int(base_coins) < 0:
					continue
				unlocked.append(id)
				var credited: Variant = receipt.get("completion_credited", false)
				if credited is bool and credited:
					completed[id] = maxi(int(completed[id]), nonnegative_score(receipt.get("score", 0)))
	unlocked = advance(unlocked, completed)
	return {"schema": maxi(SCHEMA, schema), "unlocked": unlocked, "completed_scores": completed}

static func status(id: String, raw_ids: Variant, raw_completed: Variant) -> Dictionary:
	var available := IDS.has(id)
	var unlocked: bool = available and clean_ids(raw_ids).has(id)
	var result := {"id":id, "available":available, "unlocked":unlocked, "condition":"Ready to play" if unlocked else "Coming soon",
		"progress":"Unlocked" if unlocked else "Coming soon", "current":0, "target":0, "required_map":"", "required_name":""}
	if not available or not GATES.has(id):
		return result
	var gate: Dictionary = GATES[id]
	var scores := clean_scores(raw_completed)
	var current: int = mini(int(gate.score), int(scores[gate.map]))
	result.merge({"condition":str(gate.condition), "current":current, "target":int(gate.score),
		"required_map":str(gate.map), "required_name":str(NAMES[gate.map])}, true)
	if not unlocked:
		result.progress = "%d / 1 RUN" % mini(1, current) if id == "food" else "%d / %d POINTS" % [current, int(gate.score)]
	return result
