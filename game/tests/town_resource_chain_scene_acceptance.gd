extends "res://tests/town_material_sharing_scene_acceptance.gd"
## Controlled choices in an exact seq148 copy; all travel/work use real town physics.
const OWNER := "shared:carpenter"
const PREFIX := "fixture:resource-chain:"
var chain := ""
var chain_age := 0.0
var contract_id := ""
var receipts: Dictionary = {}
var distances: Dictionary = {}
var previous_positions: Dictionary = {}
var repair_restarted := false
var chain_saved: Dictionary = {}
var final_effects: Dictionary = {}

func _finish() -> void:
	if not chain.is_empty() or not failures.is_empty():
		super._finish()
		return
	chain = "approaching_smith"
	phase = "production"
	for id in [LISTENER, OWNER, DISTANT]:
		distances[id] = 0.0
		previous_positions[id] = scene.town.position_of(id)
	# Separate bodies can work concurrently; these are explicit fixture choices.
	if not _act(OWNER, "ability:self_repair:seed:axe:handle", "own_handle"): return
	if not _act(LISTENER, "approach:" + DISTANT, "bring_iron"): return

func _act(actor: String, option: String, tag: String) -> bool:
	var result: Dictionary = scene.town.perform_action(path, actor, option, PREFIX + tag, "opengameagent_fixture")
	check(result.ok, "admit resource chain step " + tag + ": " + str(result.get("code")))
	receipts[tag] = {"actor": actor, "option": option, "command": PREFIX + tag, "admission": result}
	if not result.ok: _end_chain()
	return result.ok

func _select(actor: String, action: String, criteria: Dictionary = {}) -> String:
	for option in scene.town.action_options(actor):
		if option.action != action: continue
		var matches := true
		for key in criteria:
			if option.get(key) != criteria[key]: matches = false
		if matches: return str(option.id)
	return ""

func _completed(tag: String) -> bool:
	var receipt: Dictionary = scene.town.action_receipt(PREFIX + tag)
	if receipt.get("status") == "rejected":
		check(false, "resource chain step rejected: " + tag)
		_end_chain()
		return false
	return receipt.get("status") == "completed"

func _physics_process(delta: float) -> bool:
	if chain.is_empty(): return super._physics_process(delta)
	if chain in ["done", "restore_work"] or not is_instance_valid(scene): return false
	chain_age += delta
	var world = scene.town
	for id in distances:
		var position: Vector3 = world.position_of(id)
		var prior: Vector3 = previous_positions[id]
		var step := Vector2(position.x - prior.x, position.z - prior.z).length()
		distances[id] += step
		max_step = maxf(max_step, step)
		previous_positions[id] = position
		var body: CharacterBody3D = scene.bodies[id]
		max_speed = maxf(max_speed, Vector2(body.velocity.x, body.velocity.z).length())
	if chain_age > 800:
		check(false, "bounded production chain timed out at " + chain)
		_end_chain()
		return false
	if chain == "approaching_smith":
		if not _completed("bring_iron") or not _completed("own_handle"): return false
		check(world._item("seed:axe").handle == 100 and world._item("seed:axe").edge == 20, "own handle repaired without changing damaged edge")
		check(world.position_of(LISTENER).distance_to(world.position_of(DISTANT)) <= world.FOOD_HANDOFF_RANGE, "collector physically reaches material handoff range")
		if not _act(LISTENER, _select(LISTENER, "give_material", {"counterparty": DISTANT, "material": "iron"}), "give_iron"): return false
		check(world._trade_account(LISTENER).iron == 0 and world._trade_account(DISTANT).iron == 1, "recovered iron changes custody exactly once")
		if not _act(OWNER, "approach:" + DISTANT, "meet_smith"): return false
		chain = "meeting_smith"
	elif chain == "meeting_smith":
		if not _completed("meet_smith"): return false
		var announcement := _select(DISTANT, "share_skill", {"counterparty": OWNER, "_skill_id": "metal_repair"})
		if not announcement.is_empty() and not _act(DISTANT, announcement, "announce_skill"): return false
		if not _act(OWNER, _select(OWNER, "offer_repair", {"counterparty": DISTANT, "_part": "edge", "_price": 2, "_settlement": "collection"}), "offer_edge"): return false
		contract_id = str(world.snapshot().life.contracts[-1].id)
		if not _act(DISTANT, "contract:accept:" + contract_id, "accept_edge"): return false
		if not _act(OWNER, "contract:deliver:" + contract_id, "deliver_axe"): return false
		chain = "delivering"
	elif chain == "delivering":
		if not _completed("deliver_axe"): return false
		check(world._item("seed:axe").custodian_id == DISTANT and world._item("seed:axe").edge == 20, "delivery is not repair completion")
		if not _act(DISTANT, "contract:work:" + contract_id + ":edge", "repair_edge"): return false
		chain = "working"
	elif chain == "working":
		if _completed("repair_edge"):
			check(repair_restarted, "contracted repair resumes through a second cold scene restart")
			check(world._trade_account(DISTANT).iron == 0 and world._item("seed:axe").edge == 100, "real work consumes gifted iron and repairs the edge")
			if not _act(OWNER, "contract:collect:" + contract_id, "collect_axe"): return false
			chain = "collecting"
		elif not repair_restarted and world.pending_job(DISTANT).get("elapsed", 0.0) >= 20.0:
			scene.paused = true
			check(world.save_to(path).ok, "save unfinished contracted repair")
			chain_saved = world.snapshot()
			check(DirAccess.copy_absolute(path, output.get_base_dir().path_join("mid-repair.world.json")) == OK, "keep immutable mid-repair evidence")
			chain = "restore_work"
			scene.queue_free()
			_resume.call_deferred()
	elif chain == "collecting":
		if not _completed("collect_axe"): return false
		check(world._item("seed:axe").owner_id == OWNER and world._item("seed:axe").custodian_id == OWNER, "same repaired axe returns to its original owner")
		if world.position_of(OWNER).distance_to(world.position_of(LISTENER)) <= world.FOOD_HANDOFF_RANGE:
			_start_productive_use()
			return false
		if not _act(OWNER, "approach:" + LISTENER, "meet_supplier"): return false
		chain = "meeting_supplier"
	elif chain == "meeting_supplier":
		if not _completed("meet_supplier"): return false
		_start_productive_use()
	elif chain == "using_axe":
		if not _completed("use_repaired_axe"): return false
		check(world._trade_account(OWNER).kindling == 1 and world._trade_account(OWNER).wood == 0 and world._trade_account(LISTENER).wood == 0, "actual productive use consumes the separately gifted wood and produces one kindling")
		check(world.material_sources()[0].stock == 2 and world.material_sources()[0].recovered == 1, "whole production chain uses exactly one finite iron")
		check(max_speed <= 1.37 and max_step < .6 and distances[LISTENER] > 25 and distances[OWNER] > 30, "independent bodies cover production routes within the existing speed and step bounds")
		final_effects = {"item": world._item("seed:axe").duplicate(true), "owner_account": world._trade_account(OWNER).duplicate(true),
			"supplier_account": world._trade_account(LISTENER).duplicate(true), "smith_account": world._trade_account(DISTANT).duplicate(true), "source": world.material_sources()[0].duplicate(true)}
		check(world.save_to(path).ok, "save complete resource-to-repair outcome")
		var cold := World.new()
		check(cold.load_from(path).ok and _same(cold.snapshot(), world.snapshot()), "complete production history cold-restores exactly")
		_end_chain()
	return false

func _start_productive_use() -> void:
	if not _act(LISTENER, _select(LISTENER, "give_material", {"counterparty": OWNER, "material": "wood"}), "give_wood"): return
	if not _act(OWNER, "tool:use", "use_repaired_axe"): return
	chain = "using_axe"

func _open() -> void:
	if chain != "restore_work":
		super._open()
		return
	scene = Scene.instantiate()
	scene.scripted_trade = true
	scene.paused = true
	root.add_child(scene)
	check(_same(chain_saved, scene.town.snapshot()), "mid-repair cold scene preserves every field")
	check(scene.town.pending_job(DISTANT).command_id == PREFIX + "repair_edge", "same accepted repair command resumes")
	for id in previous_positions: previous_positions[id] = scene.town.position_of(id)
	repair_restarted = true
	chain = "working"
	scene.paused = false

func _end_chain() -> void:
	chain = "done"
	for tag in receipts:
		receipts[tag]["final"] = scene.town.action_receipt(PREFIX + tag)
	super._finish()

func _extra_evidence() -> Dictionary:
	var result := super._extra_evidence()
	result.merge({"suite": "town_resource_chain_scene", "fixture_decisions_not_model_adoption": true,
		"production_chain_seconds": chain_age, "production_travel_metres": distances,
		"repair_restarted": repair_restarted, "contract_id": contract_id,
		"production_receipts": receipts, "final_effects": final_effects}, true)
	return result
