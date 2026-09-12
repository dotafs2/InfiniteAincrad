extends "res://tests/town_trade_acceptance.gd"

const Runtime = preload("res://core/town_runtime.gd")
const ModelTurns = preload("res://agents/town_turns.gd")
var outcomes: Dictionary = {}

func _step(turns, id: String) -> void:
	outcomes[id] = await turns.step(id)

func run() -> void:
	var scenario := OS.get_environment("AINCRAD_GATEWAY_TEST_SCENARIO")
	var path := OS.get_environment("AINCRAD_GATEWAY_HISTORY_SAVE")
	var fresh_path: bool = path.is_absolute_path() and not FileAccess.file_exists(path)
	check(fresh_path, "fresh private concurrency fixture")
	if not fresh_path:
		quit(1)
		return
	_write_fixture(path, trade_fixture())
	var town := Runtime.new()
	check(town.load_from(path).ok, "actual town runtime loads concurrency fixture")
	var before := town.snapshot()
	var turns := ModelTurns.new()
	root.add_child(turns)
	turns.configure(town, path)
	check(turns.max_parallel == 2, "explicit same-config two-resident test concurrency")
	_step(turns, "fictional:ember")
	if scenario == "concurrent-cancel":
		var signal_path := OS.get_environment("AINCRAD_GATEWAY_FIRST_POST_SIGNAL")
		var waiting_since := Time.get_ticks_msec()
		while not FileAccess.file_exists(signal_path) and Time.get_ticks_msec() - waiting_since < 5000:
			await process_frame
		check(FileAccess.file_exists(signal_path), "first HTTP request is in flight before cancellation probe")
	_step(turns, "fictional:birch")
	if scenario == "concurrent-cancel":
		await create_timer(0.075).timeout
		turns.brains["fictional:birch"].cancel_pending()
	var started := Time.get_ticks_msec()
	while outcomes.size() < 2 and Time.get_ticks_msec() - started < 40000:
		await process_frame
	check(outcomes.size() == 2, "both independent resident turns finish")
	var successes := 0
	var errors := 0
	for result in outcomes.values():
		if result.get("ok", false):
			successes += 1
			check(result.record.action == "wait" and result.record.provenance == "opengameagent_fixture", "actual settled fake choice is wait")
		else:
			errors += 1
			check(result.get("code") == "provider_error", "uncertain or capacity failure is recorded, never invented success")
	var expected_success := 2 if scenario == "concurrent-success" else 0 if scenario == "concurrent-uncertain" else 1
	check(successes == expected_success and errors == 2 - expected_success, "expected concurrent settled/error counts")
	if scenario == "concurrent-cancel":
		check(outcomes.get("fictional:birch", {}).get("record", {}).get("error") == "controller_disconnected", "queued cancellation is explicitly recorded as disconnected")
	var after := town.snapshot()
	check(after.residents == before.residents and after.life == before.life and after.survival == before.survival, "concurrent choices preserve identity, life history, money and materials")
	check(after.godot.resident_turns.size() == 2, "only requested residents have independently persisted outcomes")
	turns.free()
	town.release_writer(path)
	var cold := Runtime.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	check(cold.load_from(path).ok, "fresh runtime cold-loads independent outcomes")
	check(JSON.parse_string(JSON.stringify(cold.snapshot(), "", true, true)) == JSON.parse_string(JSON.stringify(after, "", true, true)) and FileAccess.get_file_as_bytes(path) == bytes,
		"cold outcomes and exact bytes preserved (canonical numeric JSON)")
	print(JSON.stringify({"suite": "town_gateway_concurrency", "case": scenario, "checks": checks, "failures": failures,
		"settled": successes, "provider_errors": errors, "real_paid_calls": 0}))
	quit(0 if failures == 0 else 1)
