extends SceneTree

const KERNEL := preload("res://core/world_kernel.gd")
var failures: Array[String] = []

class ProviderProbeBrain extends "res://agents/resident_brain.gd":
	var runtime_error := ""
	func _on_completed(input_id: String, result_json: String) -> void:
		var result: Variant = JSON.parse_string(result_json)
		if result is Dictionary:
			runtime_error = str(result.get("error", ""))
		super._on_completed(input_id, result_json)
	func _on_failed(input_id: String, error: String) -> void:
		runtime_error = error
		super._on_failed(input_id, error)

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var mode := OS.get_environment("AINCRAD_GATEWAY_TEST_EXPECT")
	var scenario := OS.get_environment("AINCRAD_GATEWAY_TEST_SCENARIO")
	var world: RefCounted = KERNEL.new()
	world.create_fixture()
	var brain := ProviderProbeBrain.new()
	root.add_child(brain)
	brain.configure("gateway")
	var original: Dictionary = world.snapshot()
	var view: Dictionary = world.resident_view()
	if scenario.begins_with("knowledge-"):
		view.known_skill_notices = []
		view.known_skill_referrals = []
		view.material_sources = []
		for index in range(18 if scenario == "knowledge-bounds" else 1):
			view.known_skill_notices.append({"actor_id": "fixture:speaker", "skill_id": "wood_repair", "source_event_id": "notice-" + str(index), "seq": index,
				"source": "opengameagent_fixture", "provenance": "opengameagent_fixture", "text": "I can repair wood.", "hidden_neighbor_wallet": 999})
			view.known_skill_referrals.append({"referrer_id": "fixture:referrer", "referred_resident_id": "fixture:speaker", "skill_id": "metal_repair", "referral_event_id": "referral-" + str(index),
				"seq": index, "source_event_id": "notice-" + str(index), "source_seq": index, "provenance": "opengameagent_fixture", "text": "They told me they can repair metal.", "gm_budget": 999})
		for index in range(9 if scenario == "knowledge-bounds" else 1):
			view.material_sources.append({"id": "fixture:source-" + str(index), "label": "Offcuts", "material": "iron", "access": "public", "position": [0, 0, 4],
				"last_observed_stock": 3, "observed_elapsed": index, "observation_event_seq": index, "knowledge_source": "personal_proximity_observation", "work_seconds_per_unit": 60,
				"stock_may_have_changed": true, "gm_resources": {"secret": "nested_gm_secret"}})
		if scenario == "knowledge-oversize":
			view.known_skill_notices[0].text = "x".repeat(513)
		if scenario == "knowledge-nested":
			view.known_skill_notices[0].text = {"hidden_neighbor_wallet": "private"}
		if scenario == "knowledge-missing-source":
			view.known_skill_notices[0].erase("source_event_id")
		if scenario == "knowledge-context-limit":
			view.observations = ["树".repeat(7500)]
	if mode == "unicode-context":
		view.observations = ["树".repeat(4000) + " 引号\"与反斜线\\仍应正确编码。"]
	if mode == "continuation":
		view.identity.story = "I remember my own life. ".repeat(220)
		view.memory = {"previous_decisions": [{"action": "wait", "reason": "I previously chose to wait."}]}
		for index in range(12):
			var continued: Dictionary = await brain.propose(view, index)
			check(continued.get("ok", false), "bounded personal observation continues: " + str(index))
			check(continued.get("provenance") == "opengameagent_fixture", "continuation remains offline")
		var denied: Dictionary = await brain.propose(view, 12)
		check(denied.get("code") == "brain_session_request_limit", "decision transcript isolation cannot reset call limit")
		check(world.snapshot() == original, "adapter transcript isolation never resets world identity or history")
		brain.free()
		print(JSON.stringify({"suite": "gateway_continuation", "passed": failures.is_empty(), "failures": failures, "real_paid_calls": 0}))
		quit(0 if failures.is_empty() else 1)
		return
	if mode == "town":
		view.identity.story = "I prefer dependable work."
		view.available_actions = ["wait", "accept:fixture-contract"]
		view.contracts = [{"id": "fixture-contract"}]
		view.action_details = [{"id": "accept:fixture-contract", "label": "接受修理委托"}]
		view.known_rules = {"axe_use": "Both parts require 100."}
		view.unavailable_actions = [{"action": "use_tool", "required_each": 100}]
		view.hidden_neighbor_wallet = 999
		view.erase("memory")
		view.erase("actions")
	var proposal: Dictionary = await brain.propose(view, 0)
	check(world.snapshot() == original, "gateway cannot change world directly")
	if mode in ["success", "town", "unicode-context", "knowledge-bounds"]:
		check(proposal.get("ok", false), "gateway returned proposal: " + str(proposal.get("code", "")))
		if proposal.get("ok", false):
			check(proposal.provenance == "opengameagent_fixture", "test HTTP is never live Kimi")
			var applied: Dictionary = world.submit_resident_decision(proposal.decision, proposal.command_id, proposal.provenance)
			check(applied.get("ok", false), "world accepts proposal")
			check(world.snapshot().world == original.world, "chosen wait consumes no resources")
			var once: Dictionary = world.snapshot()
			var repeated: Dictionary = world.submit_resident_decision(proposal.decision, proposal.command_id, proposal.provenance)
			check(repeated.get("duplicate", false) and world.snapshot() == once, "command replay cannot repeat effects")
	else:
		check(not proposal.get("ok", true), "gate must reject: " + mode)
		check(world.snapshot() == original, "rejected request leaves world unchanged")
		if scenario == "knowledge-context-limit":
			check(brain.runtime_error == "The system prompt, tools, and new input leave no context budget for the session transcript.",
				"original upstream context guard rejects oversized knowledge input before provider dispatch")
		elif scenario.begins_with("knowledge-"):
			check(brain.runtime_error.contains("budget_gateway_rejected_or_uncertain"), "invalid knowledge reaches and is rejected by the compiled provider")
	brain.free()
	print(JSON.stringify({"suite":"gateway_adapter", "case":mode, "passed":failures.is_empty(), "failures":failures,
		"proposal_ok":proposal.get("ok", false), "proposal_code":proposal.get("code", ""), "provenance":proposal.get("provenance", ""), "real_paid_calls":0}))
	quit(0 if failures.is_empty() else 1)
