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
	var proposal: Dictionary = await brain.propose(world.resident_view(), 0)
	check(world.snapshot() == original, "gateway cannot change world directly")
	if mode == "success":
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
