extends "res://tests/town_chain_release_probe.gd"
## The real persistence codec and the chain verifier; no world or model calls.
func _initialize() -> void:
	verify_evidence.call_deferred()

func verify_evidence() -> void:
	var path := "user://chain-evidence-%d.json" % Time.get_ticks_usec()
	var before := {"world_id": "fixture:evidence", "stock": 2, "sequence": 9007199254740993,
		"positions": [2.5216903686523438, 0.059543609619140625], "next_due": 1932.5833333333335}
	write_json(path, before)
	var restored := json_file(path)
	check(restored.positions == before.positions, "coordinate doubles survive evidence decoding exactly")
	check(restored.next_due == before.next_due, "the actual failing next_due double survives exactly")
	check(restored.sequence == before.sequence, "integer identities above the double precision boundary remain exact")
	check(same_saved_value(before, restored), "full nested evidence equals its round trip")
	check(not same_saved_value({"x": 0.1}, {"x": 0.10000000000000002}), "a one-bit numeric change is not hidden by JSON rounding")
	check(same_saved_value({"stock": 2}, {"stock": 2.0}), "equivalent normalized numeric leaves remain accepted")
	var changed := restored.duplicate(true)
	changed.stock = 3
	check(not same_saved_value(before, changed), "inventory differences remain failures")
	changed = restored.duplicate(true)
	changed.world_id = "fixture:other"
	check(not same_saved_value(before, changed), "identity differences remain failures")
	check(not same_saved_value([1, 2], [1]) and not same_saved_value({"value": true}, {"value": 1}),
		"array length and non-numeric type changes remain failures")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_chain_evidence", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures.is_empty() else 1)
