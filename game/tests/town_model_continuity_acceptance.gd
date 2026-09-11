extends "res://tests/town_completion_escrow_acceptance.gd"
## N3 acceptance: the SAME resident keeps identity, personal knowledge, money,
## property, contracts and an unfinished repair chain when its controller is
## replaced, saved and reloaded. Controller A/B below are labelled offline
## fixtures, not evidence about any real language model.
##
## Reuses the existing town_turns controller/epoch fence and the existing
## trade/completion-escrow fixture idioms. The world stays the single author;
## a controller only proposes an option the world already offers.

const Turns = preload("res://agents/town_turns.gd")

const AXE := "fictional:axe-edge"
const STORY := "I apprenticed at a fictional forge and keep my own repair ledger."

var answers: Dictionary = {}


class FixtureController extends Node:
	## One labelled fake controller behind one resident. It maps a desired world
	## option id to the alias the world named in this very turn, so the world,
	## not the controller, decides whether the choice is legal.
	var turns
	var option := ""
	var mode := "decide"
	var delay := 0.0
	var calls := 0
	var captured: Dictionary = {}
	var last_reply: Dictionary = {}

	func propose(view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		captured = view.duplicate(true)
		var alias := "not-offered"
		var offered: Dictionary = turns._record(view.identity.id).get("offered_actions", {})
		for key in offered:
			if offered[key] == option:
				alias = key
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		var reply: Dictionary
		if mode == "timeout":
			reply = {"ok": false, "code": "fixture_provider_timeout"}
		elif mode == "invalid":
			reply = {"ok": true, "decision": {"reason": "fixture decision without a lawful action"}}
		else:
			reply = {"ok": true, "decision": {"action": alias, "reason": "fixture controller decision"},
				"command_id": "fixture-controller-reply", "provenance": "opengameagent_fixture"}
		last_reply = reply.duplicate(true)
		return reply


func drive(turns: Node, id: String, tag: String) -> void:
	answers[tag] = await turns.step(id)


func _facts_only(world) -> Dictionary:
	## World facts only; drop the controller bookkeeping this suite deliberately edits.
	var state: Dictionary = world.snapshot()
	state.godot.erase("resident_turns")
	return state


func _canonical(value: Variant) -> Variant:
	## The world stores live needs as floats; its own JSON save normalizes whole
	## numbers to integers. Compare the persisted shape, not the Variant tag.
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floor(value) else value
		TYPE_DICTIONARY:
			var normalized := {}
			for key in value:
				normalized[key] = _canonical(value[key])
			return normalized
		TYPE_ARRAY:
			var items := []
			for item in value:
				items.append(_canonical(item))
			return items
		_:
			return value


func _reload_matches(town, path: String, contract_id: String, label: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var cold := TownTrade.new()
	check(cold.load_from(path).ok, label + ": save reloads")
	check(cold._serialize_state() == town._serialize_state(), label + ": reloaded world is byte-identical")
	check(FileAccess.get_file_as_bytes(path) == bytes, label + ": cold read does not rewrite the save")
	check(_canonical(cold.resident(SMITH)) == _canonical(town.resident(SMITH)), label + ": identity, story and needs persist exactly")
	check(cold._contract(contract_id) == town._contract(contract_id), label + ": contract persists exactly")
	check(cold._item(AXE) == town._item(AXE), label + ": item custody persists exactly")
	check(cold._trade_account(SMITH) == town._trade_account(SMITH), label + ": money and materials persist exactly")


func run() -> void:
	var private_marker := "OWNER_PRIVATE_LEDGER_MARKER"
	var world := _source_fixture()
	for person in world.residents:
		if person.stable_id == SMITH:
			person.story = STORY
	for item in world.life.items:
		if item.get("id") == AXE:
			item.handle = 100
	for account in world.life.accounts:
		if account.get("resident_id") == OWNER:
			account.wood = 1
			account.kindling = 0
	world.life.events[0].text = private_marker
	world.life.events[0].recipient_ids = [OWNER]
	var initial_total := 0
	for person in world.residents:
		initial_total += int(person.coins_col)

	var path := "user://town-model-continuity-%d.json" % Time.get_ticks_usec()
	_write_temp(path, world)
	var town := TownTrade.new()
	check(town.load_from(path).ok, "fictional continuity fixture loads")
	check(_install(town, path).ok, "a reviewed completion settlement is available before the swap")
	var offer := _completion_option(town, OWNER, "edge", SMITH, 2)
	check(offer != "", "the owner can offer the repair that will outlive both controllers")

	# --- one real, unfinished repair chain: owner offers, smith's controller A accepts, owner delivers.
	execute(town, path, OWNER, offer, "chain-offer")
	var contract: Dictionary = _contract(town, AXE, "proposed")
	var contract_id := str(contract.id)
	check(contract.get("settlement") == "completion" and contract.get("price_col") == 2, "the chain is a completion-settling contract")

	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path

	var controller_a := FixtureController.new()
	controller_a.turns = turns
	controller_a.option = "contract:accept:" + contract_id
	check(turns.connect_controller(SMITH, controller_a, "fixture:model_a").ok, "fixture controller A attaches to the smith")
	await drive(turns, SMITH, "a_accept")
	check(answers["a_accept"].get("ok", false), "controller A's accept is accepted by the world")
	check(_contract(town, AXE, "accepted").get("status", "") == "accepted", "the smith is committed to this repair")
	check(town.resident(OWNER).coins_col == 10 and town._trade_account(OWNER).reserved_col == 2, "escrow is held, nobody is paid yet")

	execute(town, path, OWNER, "contract:deliver:" + contract_id, "chain-deliver")
	arrive(town, OWNER)
	elapse(town, path, 1)
	check(_contract(town, AXE, "delivered").get("status", "") == "delivered", "the axe is delivered into the smith's hands")
	check(town._item(AXE).custodian_id == SMITH, "the smith physically holds the unfinished work")

	var smith_before: Dictionary = town.resident(SMITH).duplicate(true)
	var smith_account_before: Dictionary = town._trade_account(SMITH).duplicate(true)
	var contract_before: Dictionary = town._contract(contract_id).duplicate(true)

	# --- the unfinished work and its settlement survive a save/reload before any controller change.
	_reload_matches(town, path, contract_id, "pre-swap")
	check(town._contract(contract_id).get("status", "") == "delivered" and town._trade_account(OWNER).reserved_col == 2, "reload keeps the work and its escrow pending")

	# --- replace the controller for the SAME resident while A still holds a live request.
	controller_a.option = "contract:work:" + contract_id + ":edge"
	controller_a.delay = 0.25
	drive(turns, SMITH, "a_late_work")
	check(turns.busy, "controller A has a genuine outstanding request")

	var controller_b := FixtureController.new()
	controller_b.turns = turns
	controller_b.option = "contract:work:" + contract_id + ":edge"
	check(turns.connect_controller(SMITH, controller_b, "fixture:model_b").ok, "controller B replaces A for the same resident")
	check(turns.brains[SMITH] == controller_b, "the live controller behind the smith is B")
	check(not turns.inflight.has(SMITH), "A's outstanding request is fenced out of the live turn")
	check(town.resident(SMITH) == smith_before, "replacement leaves identity, story and needs unchanged")
	check(town._trade_account(SMITH) == smith_account_before, "replacement leaves the smith's money and materials unchanged")
	check(town._contract(contract_id) == contract_before, "replacement leaves the contract unchanged")
	check(town._item(AXE).custodian_id == SMITH, "replacement leaves the smith's custody of the item unchanged")
	check(turns._record(SMITH).get("controller_id", "") == "fixture:model_b", "the world records B as the new controller")

	# --- B's valid next action finishes the existing job and settles it exactly once.
	var events_before_b: Array = town.snapshot().life.events
	var own_at_b := 0
	for event in events_before_b:
		if event.get("recipient_ids", []).has(SMITH):
			own_at_b += 1
	await drive(turns, SMITH, "b_work")
	check(answers["b_work"].get("ok", false), "controller B's next action is accepted by the world")
	check(str(turns._record(SMITH).get("action", "")).begins_with("contract:work:"), "B's accepted action is the pre-existing repair job")
	check(town._trade_account(SMITH).iron == 1, "material is still reserved until the job completes")
	arrive(town, SMITH)
	elapse(town, path, 60)
	check(town._item(AXE).edge == 100, "the existing job finishes the repair")
	check(town._trade_account(SMITH).iron == 0, "finishing consumes exactly one iron")
	check(town.resident(SMITH).coins_col == 5 and town._trade_account(OWNER).reserved_col == 0, "the held escrow pays the smith exactly once")
	check(_contract(town, AXE, "completed").get("status", "") == "completed", "the chain completes rather than resetting")

	# --- A's late reply is fenced, and a duplicate reply from B cannot re-settle.
	var settled := town.snapshot()
	await create_timer(0.4).timeout
	check(answers["a_late_work"].get("code", "") == "stale_controller_reply", "A's late reply is rejected as a stale controller")
	check(town.snapshot() == settled, "A's late reply changes no history or world fact")
	var record_b := turns._record(SMITH)
	var replay := turns.apply_reply(SMITH, int(record_b.controller_epoch), str(record_b.request_id), controller_b.last_reply)
	check(replay.get("duplicate", false), "a repeated reply from B is acknowledged as a duplicate")
	check(town.snapshot() == settled, "a duplicate reply from B cannot repair or pay twice")
	check(town.resident(SMITH).coins_col == 5, "the payout stays exactly one escrow")

	_reload_matches(town, path, contract_id, "post-payment")

	# --- the repaired tool is used exactly once, and collection never pays twice.
	check(_option(town, OWNER, "use_tool").is_empty(), "a tool still held by the smith cannot be used")
	execute(town, path, OWNER, "contract:collect:" + contract_id, "collect-once")
	arrive(town, OWNER)
	elapse(town, path, 1)
	check(town._item(AXE).custodian_id == OWNER, "the owner recovers the repaired tool")
	check(town.resident(SMITH).coins_col == 5 and town._trade_account(OWNER).reserved_col == 0, "collection returns the tool without a second payment")
	check(town.submit_trade(OWNER, "contract:collect:" + contract_id, "collect-once", "opengameagent_fixture").get("duplicate", false), "a replayed collection is a no-op")
	check(not town.submit_trade(OWNER, "contract:collect:" + contract_id, "collect-twice", "opengameagent_fixture").ok, "the settled chain offers no second collection")
	var use_option := _option(town, OWNER, "use_tool")
	check(not use_option.is_empty(), "the repaired axe is genuinely usable now")
	execute(town, path, OWNER, use_option, "use-once")
	arrive(town, OWNER)
	elapse(town, path, 60)
	check(town._trade_account(OWNER).wood == 0 and town._trade_account(OWNER).kindling == 1, "the repaired tool is used exactly once")
	check(not town.submit_trade(OWNER, "tool:use", "use-twice", "opengameagent_fixture").ok, "a drained ledger cannot use the tool again")
	check(town.resident(OWNER).coins_col + town.resident(SMITH).coins_col + town.resident(WOODWORKER).coins_col == initial_total, "Col is conserved through the whole replacement")

	# --- the replacement controller's own view carries the preserved personal facts.
	var view: Dictionary = controller_b.captured
	check(view.identity.get("story", "") == STORY, "B sees the preserved identity and story")
	check(view.memory.previous_decisions.any(func(entry): return str(entry.get("action", "")).begins_with("contract:accept:")), "B inherits the smith's own decision history instead of a reset")
	check(view.experiences.size() == mini(own_at_b, 16), "personal knowledge is exactly this resident's own events")
	check(view.experiences.all(func(entry): return entry.get("recipient_ids", []).has(SMITH)), "no other resident's events leak into the view")
	check(view.experiences.any(func(entry): return entry.get("type", "") == "axe_contract_accepted"), "the smith still knows it accepted this repair")
	check(not JSON.stringify(view).contains(private_marker), "the smith's view never carries the owner's private history")
	check(not JSON.stringify(view).contains("historical_coordinate") and not JSON.stringify(view).contains("private_memory"), "legacy private runtime stays out of the model view")

	# --- failing replacement controllers quarantine only their own resident.
	var other_resident_before: Dictionary = town.resident(WOODWORKER).duplicate(true)
	var other_account_before: Dictionary = town.account(WOODWORKER).duplicate(true)
	var facts_before_failure := _facts_only(town)
	var flaky := FixtureController.new()
	flaky.turns = turns
	flaky.mode = "timeout"
	check(turns.connect_controller(SMITH, flaky, "fixture:model_b_timeout").ok, "a replacement controller can attach after a failure")
	await drive(turns, SMITH, "b_timeout")
	check(turns._record(SMITH).get("status", "") == "provider_error" and turns._record(SMITH).get("error", "") == "fixture_provider_timeout", "a provider timeout is recorded, never invented into a success")
	check(_facts_only(town) == facts_before_failure, "a provider timeout changes no world fact")
	check(town.resident(SMITH).get("story", "") == STORY and town.resident(SMITH).get("name", "") == smith_before.get("name") and town.resident(SMITH).get("role", "") == smith_before.get("role"), "a provider timeout never resets the smith's identity")
	check(town.resident(SMITH).coins_col == 5, "a provider timeout never resets the smith's money")
	check(turns.ready_resident() != SMITH, "the failed smith is quarantined, not silently retried")

	var invalid := FixtureController.new()
	invalid.turns = turns
	invalid.mode = "invalid"
	check(turns.connect_controller(SMITH, invalid, "fixture:model_b_invalid").ok, "an explicit host action clears the review boundary")
	var facts_before_invalid := _facts_only(town)
	await drive(turns, SMITH, "b_invalid")
	check(turns._record(SMITH).get("status", "") == "provider_error" and turns._record(SMITH).get("error", "") == "invalid_decision", "a malformed reply is rejected as invalid_decision")
	check(_facts_only(town) == facts_before_invalid, "a malformed reply changes no world fact")

	var rogue := FixtureController.new()
	rogue.turns = turns
	rogue.option = "contract:work:" + contract_id + ":handle"
	check(turns.connect_controller(SMITH, rogue, "fixture:model_b_fabricated").ok, "a controller cannot be refused for its intent alone")
	var facts_before_rogue := _facts_only(town)
	await drive(turns, SMITH, "b_fabricated")
	check(turns._record(SMITH).get("status", "") == "rule_rejection" and turns._record(SMITH).get("result", {}).get("code", "") == "choice_not_offered", "a never-offered action is rejected by the world")
	check(str(turns._record(SMITH).get("action", "")) == "", "a fabricated option never becomes the resident's action")
	check(_facts_only(town) == facts_before_rogue, "a fabricated option changes no world fact")
	check(town.resident(SMITH).coins_col == 5 and town._item(AXE).edge == 100, "no controller failure can pay or repair on its own")
	check(town.resident(WOODWORKER) == other_resident_before and town.account(WOODWORKER) == other_account_before, "another resident is untouched by the smith's controller failures")

	_reload_matches(town, path, contract_id, "final")
	turns.free()
	_cleanup(path, town)
	print(JSON.stringify({"suite": "town_model_continuity", "checks": checks, "failures": failures, "paid_calls": 0,
		"provenance": "scripted_fixture_controllers", "model_claim": "fixture_controllers_only"}))
	quit(0 if failures == 0 else 1)
