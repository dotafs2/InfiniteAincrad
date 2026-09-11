extends SceneTree

const BRAIN := preload("res://agents/resident_brain.gd")
const KERNEL := preload("res://core/world_kernel.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var mode := OS.get_environment("AINCRAD_GATEWAY_TEST_EXPECT")
	var world: RefCounted = KERNEL.new()
	world.create_fixture()
	var brain: Node = BRAIN.new()
	root.add_child(brain)
	brain.configure("gateway")
	var original: Dictionary = world.snapshot()
	var view: Dictionary = world.resident_view()
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
	if mode in ["success", "town", "unicode-context"]:
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
	brain.free()
	print(JSON.stringify({"suite":"gateway_adapter", "case":mode, "passed":failures.is_empty(), "failures":failures,
		"proposal_ok":proposal.get("ok", false), "provenance":proposal.get("provenance", ""), "real_paid_calls":0}))
	quit(0 if failures.is_empty() else 1)
