extends "res://tests/town_materials_acceptance.gd"

# Actual town rules -> durable private fixture -> separate Godot cold process ->
# actual resident brain/C# adapter -> local fake HTTP. No real model decisions.
const OWNER := "fictional:ember"
const WOOD := "fictional:birch"
const SMITH := "fictional:forge"

class PrivacyProbeTown extends "res://core/town_runtime.gd":
	func resident_view(id: String = "") -> Dictionary:
		var view := super.resident_view(id)
		# Add only adversarial incidental keys to the genuine personal projection.
		view.gm_resources = {"private_sentinel": "gm_install_secret"}
		view.hidden_neighbor_wallet = "neighbor_private_secret"
		for key in ["known_skill_notices", "known_skill_referrals", "material_sources"]:
			for record in view[key]:
				record.gm_internal = {"private_sentinel": "nested_gm_secret"}
				record.other_resident_private = {"private_sentinel": "nested_neighbor_secret"}
		return view

func _move(town, path: String, id: String, position: Vector3) -> void:
	check(town.transaction(path, func():
		town.host_move(id, position)
		return {"ok": true}).ok, "fixture host movement saves")

func _seed_history(town, path: String) -> void:
	check(town.transaction(path, func(): return town.install_material_source(spec(3), 1, "development_gm:history-fixture")).ok, "finite fixture material installation")
	execute(town, path, SMITH, "share-skill:" + WOOD + ":metal_repair", "history-direct-metal")
	_move(town, path, SMITH, Vector3(80, 0, 0))
	_move(town, path, OWNER, Vector3.ZERO)
	var referral := ""
	for option in town.trade_options(WOOD):
		if option.action == "refer_skill" and option.counterparty == OWNER:
			referral = option.id
	check(not referral.is_empty(), "actual received notice offers referral")
	execute(town, path, WOOD, referral, "history-referred-metal")
	execute(town, path, WOOD, "share-skill:" + OWNER + ":wood_repair", "history-direct-wood")
	_move(town, path, OWNER, Vector3(0, 0, 3.6))
	elapse(town, path, 0)
	_move(town, path, OWNER, Vector3.ZERO)
	# Another resident really consumes stock while OWNER cannot observe it. The
	# wire must retain OWNER's historical 3, never leak authoritative current 2.
	_move(town, path, WOOD, Vector3(0, 0, 4))
	elapse(town, path, 0)
	execute(town, path, WOOD, "material:recover:fixture:iron-source", "history-other-recovery")
	elapse(town, path, 60)
	_move(town, path, WOOD, Vector3(1, 0, 0))
	check(town.material_sources()[0].stock == 2 and town.resident_view(OWNER).material_sources[0].last_observed_stock == 3,
		"other resident's real consumption does not update distant observer's knowledge")
	# Twenty real personal social events evict all three knowledge sources from
	# the recent-16 experience projection without changing their historical records.
	for index in range(10):
		var command := "history-churn-%d" % index
		var asked: Dictionary = town.transaction(path, func(): return town.communicate(OWNER,
			{"action": "ask_help", "recipient_id": WOOD, "text": "I am considering my next task."}, command, "opengameagent_fixture"))
		check(asked.ok, "new personal question " + str(index))
		check(town.transaction(path, func(): return town.communicate(OWNER,
			{"action": "cancel_help", "recipient_id": WOOD, "request_id": asked.get("request_id", ""), "text": "I will think first."}, command + "-cancel", "opengameagent_fixture")).ok,
			"personal question closed " + str(index))

func _step(turns, town, id: String) -> Dictionary:
	var view: Dictionary = town.resident_view(id)
	if id == OWNER:
		check(view.experiences.size() > 16, "more than sixteen real personal events")
		var recent: Array = view.experiences.slice(-16)
		check(recent.all(func(event): return event.type in ["ask_help", "cancel_help"]), "historical knowledge absent from recent sixteen events")
		check(view.known_skill_notices.size() == 1 and view.known_skill_referrals.size() == 1 and view.material_sources.size() == 1, "actual private historical records retained")
		check(view.known_skill_notices[0].seq < recent[0].seq and view.known_skill_referrals[0].seq < recent[0].seq and view.material_sources[0].observation_event_seq < recent[0].seq, "all knowledge sources predate recent experience window")
	else:
		check(view.known_skill_notices.is_empty() and view.known_skill_referrals.is_empty() and view.material_sources.is_empty(), "uninformed resident has none of another resident's knowledge")
	var result: Dictionary = await turns.step(id)
	check(result.get("ok", false), "actual town turns and gateway accept historical view: " + str(result.get("code", "")))
	check(result.get("record", {}).get("provenance") == "opengameagent_fixture", "HTTP decisions are explicitly fake local transport")
	return result

func run() -> void:
	var path := OS.get_environment("AINCRAD_GATEWAY_HISTORY_SAVE")
	var phase := OS.get_environment("AINCRAD_GATEWAY_HISTORY_PHASE")
	var valid_arguments: bool = path.is_absolute_path() and phase in ["seed", "cold"]
	check(valid_arguments, "isolated history fixture arguments")
	if not valid_arguments:
		quit(1)
		return
	if phase == "seed":
		check(not FileAccess.file_exists(path), "fixture never replaces an existing save")
		if FileAccess.file_exists(path):
			quit(1)
			return
		var initial := material_fixture()
		initial.godot.positions[OWNER] = [50, 0, 0]
		_write_fixture(path, initial)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var town := PrivacyProbeTown.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "actual town runtime loads history fixture")
	if not loaded.ok:
		quit(1)
		return
	if phase == "seed":
		_seed_history(town, path)
	else:
		check(FileAccess.get_file_as_bytes(path) == before_bytes, "cold load preserves exact save bytes")
	var iron_before: int = town._trade_account(OWNER).iron
	var stock_before: int = town.material_sources()[0].stock
	check(stock_before == 2 and town.resident_view(OWNER).material_sources[0].last_observed_stock == 3,
		"cold transport has historical stock differing from authoritative stock")
	var turns := Turns.new()
	root.add_child(turns)
	turns.configure(town, path)
	var result: Dictionary = await _step(turns, town, OWNER)
	if phase == "cold" and result.get("ok", false):
		check(result.record.action == "material:recover:fixture:iron-source", "fake transport selected an actually offered known source")
		_move(town, path, OWNER, Vector3(0, 0, 4)) # Explicit host fixture arrival, not autonomous travel.
		elapse(town, path, 60)
		check(town._trade_account(OWNER).iron == iron_before + 1 and town.material_sources()[0].stock == stock_before - 1, "same-world rule use conserves one finite material")
		await _step(turns, town, SMITH)
	turns.free()
	town.release_writer(path)
	print(JSON.stringify({"suite": "town_gateway_knowledge", "phase": phase, "passed": failures == 0, "failures": failures,
		"checks": checks, "life_sequence": town.snapshot().life.seq, "real_paid_calls": 0, "decision_source": "fake_local_transport"}))
	quit(0 if failures == 0 else 1)
