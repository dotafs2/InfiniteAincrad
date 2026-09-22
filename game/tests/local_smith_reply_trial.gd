extends SceneTree
## The carpenter setup is supplied fixture input. Only the Smith produces a Turns record.
const Town = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const Reviewed = preload("res://agents/reviewed_dialogue_fixture_adapter.gd")
const Review = preload("res://agents/dialogue_proposal_review.gd")
const Runner = preload("res://demo/axe_day_demo_runner.gd")
const SOURCE := "res://../worlds/restart-20260918-01/checkpoints/seq000000-22fe742384341a2b.world.json"
const OWNER := "shared:carpenter"
const SMITH := "shared:smith"
const AXE := "seed:axe"
const MAX_RESPONSE_BYTES := 65536
const RESPONSE_TIMEOUT_MS := 120000
var exchange_dir := ""
var mode := ""
var fixture_path := ""
var source_hash := ""
var town
var turns: Node
var checks := 0
var failures: Array[String] = []
var report := {"suite":"local_smith_reply_trial","fixture_only":true,"provider_id":"local:ollama","paid_calls":0,"speech_delivery":"proposal_not_delivered","proposal_not_delivered":true,"model_returned":false,"outcome":"not_started"}

class TrialBrain extends Node:
	var trial
	var stored_aliases := {}
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var record: Dictionary = trial.turns._record(SMITH)
		stored_aliases = record.get("offered_actions", {}).duplicate(true)
		if stored_aliases.is_empty() or view.is_empty(): return {"ok":false,"code":"missing_smith_turn_context"}
		if not trial._write_exclusive(trial._context_path(), JSON.stringify(trial._context_payload(view, stored_aliases), "  ", true, true)): return {"ok":false,"code":"context_write_failed"}
		trial.report["stored_alias_count"] = stored_aliases.size()
		if trial.mode.begins_with("mock_") and not trial._write_mock_response(stored_aliases): return {"ok":false,"code":"mock_response_write_failed"}
		var exchange: Dictionary = await trial._read_complete_response()
		if not exchange.get("ok", false):
			trial.report["response_error"] = exchange.get("code", "response_invalid")
			trial.report["outcome"] = "response_error"
			trial._fail("response_" + str(exchange.get("code", "response_invalid")))
			return {"ok":false,"code":exchange.get("code", "response_invalid")}
		var raw: String = exchange.raw_content
		trial.report["model_returned"] = trial.mode == "live"
		trial.report["raw_sha256"] = raw.sha256_text()
		trial.report["response_metrics"] = exchange.metrics.duplicate(true)
		var prepared: Dictionary = Reviewed.prepare(raw, view, stored_aliases, [OWNER, SMITH], [])
		if not prepared.get("ok", false):
			trial.report["proposal_review"] = prepared.get("review", {})
			trial.report["outcome"] = "review_rejected"
			return {"ok":false,"code":prepared.get("code", "dialogue_review_required")}
		var fresh: Dictionary = trial._fresh_offered(view, stored_aliases)
		if fresh.get("aliases", {}).is_empty():
			trial.report["outcome"] = "stale_action_rejected"
			return {"ok":false,"code":"stale_action_rejected"}
		var approved: Dictionary = Reviewed.authorize(prepared, fresh.view, fresh.aliases, true, "Explicit scripted fixture authorization; final Turns gate remains authoritative.", [OWNER, SMITH], [])
		trial.report["proposal_review"] = approved.get("review", prepared.get("review", {}))
		if not approved.get("ok", false):
			trial.report["outcome"] = "review_rejected"
			return {"ok":false,"code":approved.get("code", "dialogue_review_required")}
		trial.report["review_authorized"] = true
		return {"ok":true,"decision":approved.decision,"command_id":"fixture:smith-reply","provenance":"opengameagent_fixture","provider_id":trial.report.provider_id,"model_returned":trial.report.model_returned}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--exchange-dir="): exchange_dir = arg.trim_prefix("--exchange-dir=")
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	run.call_deferred()

func run() -> void:
	report["mode"] = mode
	report["provider_id"] = "mock:scripted" if mode.begins_with("mock_") else "local:ollama"
	if mode not in ["live", "mock_accept", "mock_mismatch"]: _fail("invalid_mode"); _finish(); return
	if exchange_dir.is_empty(): _fail("exchange_dir_required"); _finish(); return
	DirAccess.make_dir_recursive_absolute(exchange_dir)
	for artifact in ["contexts.json", "response.json", "report.json"]:
		if FileAccess.file_exists(exchange_dir.path_join(artifact)): _fail("preexisting_%s" % artifact); _finish(); return
	source_hash = FileAccess.get_sha256(SOURCE)
	if source_hash.is_empty(): _fail("source_hash_failed"); _finish(); return
	fixture_path = "user://local-smith-reply-%d-%d.world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var runner := Runner.new()
	if not runner._write_fixture(fixture_path): _fail("fixture_write_failed"); _finish(); return
	town = Town.new()
	var loaded: Dictionary = town.load_from(fixture_path)
	if not loaded.get("ok", false): _fail("fixture_load_failed"); _finish(); return
	var notice: Dictionary = town.transaction(fixture_path, func(): return town.submit_trade(SMITH, "share-skill:" + OWNER + ":metal_repair", "fixture:notice", "opengameagent_fixture"))
	_check(notice.get("ok", false), "skill_notice")
	if not notice.get("ok", false): _finish(); return
	var offer := _option(OWNER, "offer_repair", "edge", SMITH, 2)
	_check(not offer.is_empty(), "repair_offer_available")
	if offer.is_empty(): _finish(); return
	var offered: Dictionary = town.transaction(fixture_path, func(): return town.submit_trade(OWNER, offer, "fixture:offer", "opengameagent_fixture"))
	_check(offered.get("ok", false) and offered.get("code", "") == "contract_proposed", "owner_offer")
	if not offered.get("ok", false) or offered.get("code", "") != "contract_proposed": _finish(); return
	turns = Turns.new(); root.add_child(turns); turns.town = town; turns.save_path = fixture_path
	var brain := TrialBrain.new(); brain.trial = self; turns.add_child(brain); turns.brains[SMITH] = brain
	var result: Dictionary = await turns.step(SMITH)
	var receipt: Dictionary = result.get("record", {}).get("result", {})
	report["result_code"] = receipt.get("code", result.get("code", ""))
	report["actual_event"] = _last_trade_event_type()
	report["accepted"] = result.get("ok", false) and report.result_code == "contract_accepted"
	if report.accepted:
		report["outcome"] = "accepted"
		_check(town._trade_account(OWNER).reserved_col == 2, "accepted_escrow_two")
		_check(town.resident(OWNER).get("coins_col", -1) == 8, "accepted_owner_wallet_eight")
		_check(await _cold_acceptance_memory(), "cold_restart_acceptance_memory")
	elif mode == "mock_accept": _fail("mock_accept_not_accepted")
	elif mode == "mock_mismatch":
		_check(report.get("outcome", "") == "review_rejected", "mismatch_review_rejected")
		_check(town._trade_account(OWNER).reserved_col == 0, "mismatch_no_escrow")
		_check(not _contract("proposed").is_empty(), "mismatch_contract_unchanged")
	elif mode == "live" and report.get("outcome", "not_started") == "not_started":
		report["outcome"] = "executed:" + str(report.get("result_code", "unknown"))
	# Live records any lawful acceptance, refusal, stale action, or review rejection without an asserted model failure.
	_finish()

func _context_payload(view: Dictionary, aliases: Dictionary) -> Dictionary:
	var descriptions := _option_descriptions(SMITH)
	var options: Array = []
	for alias in aliases:
		var action_id := str(aliases[alias])
		options.append({"alias":str(alias),"action_id":action_id,"description":str(descriptions.get(action_id, "")),"expected_intents":Review._expected_intents(action_id)})
	var rules: Dictionary = view.get("known_rules", {}).duplicate(true)
	rules.erase("decision_format")
	var observation := {"identity":view.get("identity", {}),"needs":view.get("needs", {}),"inventory":view.get("inventory", {}),"life_account":view.get("life_account", {}),"wallet":view.get("wallet", {}),"contracts":view.get("contracts", []),"skills":view.get("skills", []),"items":view.get("items", []),"unavailable_actions":view.get("unavailable_actions", []),"memory":view.get("memory", {}),"experiences":view.get("experiences", []),"known_rules":rules}
	return {"fixture_only":true,"cases":[{"case_id":"smith_reply","resident_id":SMITH,"context":{"target_ids":[OWNER,SMITH],"claim_ids":[],"action_ids":aliases.keys()},"options":options,"observation":observation}]}

func _write_mock_response(aliases: Dictionary) -> bool:
	var accept_alias := ""
	for alias in aliases:
		if str(aliases[alias]).begins_with("contract:accept:"): accept_alias = str(alias)
	if accept_alias.is_empty(): return false
	var intent := "agree" if mode == "mock_accept" else "offer"
	var envelope := {"speech":"I respond to the supplied repair terms.","intent":intent,"stance":"guarded","target_id":OWNER,"claim_ids":[],"stakes":"Fixture-only repair contract.","next_action":accept_alias,"confidence":0.8}
	var raw := JSON.stringify(envelope)
	var response := {"status":"complete","cases":[{"case_id":"smith_reply","raw_content":raw,"metrics":{"provider":"mock","mode":mode,"raw_bytes":raw.to_utf8_buffer().size()}}]}
	return _write_exclusive(_response_path(), JSON.stringify(response, "  ", true, true))

func _read_complete_response() -> Dictionary:
	var deadline := Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_response_path()):
			var bytes := FileAccess.get_file_as_bytes(_response_path())
			if bytes.size() > MAX_RESPONSE_BYTES: return {"ok":false,"code":"response_too_large"}
			if not bytes.is_empty():
				var parsed := JSON.new()
				if parsed.parse(bytes.get_string_from_utf8()) == OK and parsed.data is Dictionary:
					var payload: Dictionary = parsed.data
					if payload.get("status", "") == "complete" and payload.get("cases") is Array and payload.cases.size() == 1:
						var entry = payload.cases[0]
						if entry is Dictionary and entry.get("case_id", "") == "smith_reply" and entry.get("raw_content") is String:
							if mode == "live" and not str(entry.get("error", "")).is_empty(): return {"ok":false,"code":"request_failed"}
							if mode == "live":
								var status: Variant = entry.get("http_status", null)
								if not (status is int or status is float) or int(status) < 200 or int(status) > 299: return {"ok":false,"code":"response_invalid"}
							var metrics: Dictionary = entry.get("metrics", {}).duplicate(true) if entry.get("metrics", {}) is Dictionary else {}
							for key in ["input_tokens", "output_tokens", "latency_ms", "http_status", "model"]:
								if entry.has(key): metrics[key] = entry[key]
							return {"ok":true,"raw_content":entry.raw_content,"metrics":metrics}
						return {"ok":false,"code":"response_invalid"}
					if payload.get("status", "") == "complete": return {"ok":false,"code":"response_invalid"}
		await create_timer(0.05).timeout
	return {"ok":false,"code":"response_timeout"}

func _fresh_offered(original_view: Dictionary, stored: Dictionary) -> Dictionary:
	var current := _option_descriptions(SMITH)
	var aliases := {}
	for alias in stored:
		var action_id := str(stored[alias])
		if current.has(action_id): aliases[str(alias)] = action_id
	var view := original_view.duplicate(true)
	view["available_actions"] = aliases.keys()
	return {"view":view,"aliases":aliases}
func _option_descriptions(id: String) -> Dictionary:
	var result := {}
	# TownRuntime exposes its current canonical menu through the compatibility
	# action source; Turns uses this same trade_options path when it assigns aliases.
	for option in town.trade_options(id):
		var action_id := str(option.get("id", ""))
		if not action_id.is_empty(): result[action_id] = str(option.get("label", ""))
	return result
func _option(id: String, action: String, part := "", worker := "", price := -1) -> String:
	for option in town.trade_options(id):
		if option.get("action") == action and (part.is_empty() or option.get("_part") == part) and (worker.is_empty() or option.get("_worker_id") == worker) and (price < 0 or option.get("_price") == price): return str(option.get("id", ""))
	return ""
func _contract(status: String) -> Dictionary:
	for contract in town.snapshot().life.contracts:
		if contract.get("item_id") == AXE and contract.get("status") == status: return contract
	return {}
func _last_trade_event_type() -> String:
	var events: Array = town.snapshot().get("life", {}).get("events", [])
	return str(events.back().get("type", "")) if not events.is_empty() else ""
func _cold_acceptance_memory() -> bool:
	if turns != null: turns.free(); turns = null
	if town != null: town.release_writer(fixture_path); town = null
	var cold := Town.new()
	var loaded: Dictionary = cold.load_from(fixture_path)
	if not loaded.get("ok", false): return false
	var cold_turns := Turns.new(); root.add_child(cold_turns); cold_turns.town = cold; cold_turns.save_path = fixture_path
	var feedback: Array = cold_turns._feedback_history(SMITH, cold_turns._record(SMITH))
	var matched := false
	for entry in feedback:
		var recorded: Dictionary = entry.get("result", {})
		if str(entry.get("action", "")) == "contract:accept:trade_contract_fixture:offer" and recorded.get("code", "") == "axe_contract_accepted": matched = true
	report["cold_restart"] = {"owner_wallet":cold.resident(OWNER).get("coins_col", -1),"owner_reserved":cold._trade_account(OWNER).reserved_col,"acceptance_feedback":matched}
	cold_turns.free(); cold.release_writer(fixture_path)
	return matched and cold._trade_account(OWNER).reserved_col == 2 and cold.resident(OWNER).get("coins_col", -1) == 8
func _context_path() -> String: return exchange_dir.path_join("contexts.json")
func _response_path() -> String: return exchange_dir.path_join("response.json")
func _report_path() -> String: return exchange_dir.path_join("report.json")
func _write_exclusive(path: String, text: String) -> bool:
	if FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text); file.close(); return true
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: _fail(label)
func _fail(label: String) -> void:
	if not failures.has(label): failures.append(label)
func _finish() -> void:
	if turns != null: turns.free(); turns = null
	if town != null: town.release_writer(fixture_path); town = null
	var after := FileAccess.get_sha256(SOURCE)
	report["source_sha256"] = source_hash
	report["source_unchanged"] = not source_hash.is_empty() and source_hash == after
	if not report.source_unchanged: _fail("source_changed")
	if not fixture_path.is_empty() and FileAccess.file_exists(fixture_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	if not exchange_dir.is_empty() and not FileAccess.file_exists(_report_path()):
		var file := FileAccess.open(_report_path(), FileAccess.WRITE)
		if file == null: _fail("report_write_failed")
		else:
			report["checks"] = checks; report["failures"] = failures; report["ok"] = failures.is_empty()
			file.store_string(JSON.stringify(report, "  ", true, true)); file.close()
	report["checks"] = checks; report["failures"] = failures; report["ok"] = failures.is_empty()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
